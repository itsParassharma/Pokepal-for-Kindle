"""Exercise publishing against a fake GitHub CLI; no network or releases changed."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHA = 'a' * 40


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ['tools/publish_release.sh', 'pokepal.koplugin/_meta.lua',
                     'pokepal.koplugin/INSTALL.txt', 'native/kual/config.xml']:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        import re
        self.tag = 'v' + re.search(r'version\s*=\s*"([\d.]+)"',
                                  (self.root/'pokepal.koplugin/_meta.lua').read_text()).group(1)
        (self.root/'docs').mkdir()
        (self.root/f'docs/release-{self.tag}.md').write_text('Release notes\n')
        dist = self.root/'dist'
        dist.mkdir()
        sums = []
        for kind in ['koreader', 'kual', 'corresponding-source']:
            name = f'PokePal-{self.tag}-{kind}.zip'
            data = kind.encode()
            (dist/name).write_bytes(data)
            sums.append(f'{hashlib.sha256(data).hexdigest()}  {name}\n')
        (dist/f'PokePal-{self.tag}-SHA256.txt').write_text(''.join(sums))
        bins = self.root/'bin'
        bins.mkdir()
        git = bins/'git'
        git.write_text(f'#!/bin/sh\nprintf "%s\\n" "{SHA}"\n')
        git.chmod(0o755)
        gh = bins/'gh'
        gh.write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
a = sys.argv[1:]
with open(os.environ['GH_LOG'], 'a') as log: log.write(json.dumps(a)+'\\n')
mode = os.environ['SCENARIO']
tag = os.environ['RELEASE_TAG']
if a[0] == 'api':
    if mode == 'api-error': sys.exit(1)
    if '/releases?' in a[1]:
        print(tag if mode in ('existing-release', 'existing-draft') else 'v0.0.1')
    elif mode == 'existing-tag': print('refs/tags/'+tag)
elif a[:2] == ['release', 'create']:
    if mode == 'create-race': sys.exit(1)
elif a[:2] == ['release', 'upload']:
    if mode == 'upload-error': sys.exit(1)
elif a[:2] == ['release', 'download']:
    out = pathlib.Path(a[a.index('--dir')+1])
    for p in pathlib.Path('dist').iterdir(): shutil.copy2(p, out/p.name)
    if mode == 'remote-corruption':
        (out/('PokePal-'+tag+'-kual.zip')).write_bytes(b'corrupt')
elif a[:2] != ['release', 'edit']:
    sys.exit('Unexpected command')
''')
        gh.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bins)+os.pathsep+os.environ['PATH'],
                        GITHUB_REPOSITORY='test/pokepal', GITHUB_SHA=SHA,
                        GH_LOG=str(self.root/'gh.log'), RELEASE_TAG=self.tag)

    def run_release(self, scenario='new', *args):
        self.env['SCENARIO'] = scenario
        result = subprocess.run(['bash', str(self.root/'tools/publish_release.sh'), *args],
                                env=self.env, text=True, capture_output=True)
        log = self.root/'gh.log'
        commands = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        return result, [a for a in commands if a[0] == 'release']

    def test_new_release_verifies_download_before_publication(self):
        result, commands = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([a[1] for a in commands], ['create', 'upload', 'download', 'edit'])
        self.assertTrue(all(a[2] == self.tag for a in commands))
        self.assertIn('--draft', commands[0])
        self.assertIn(SHA, commands[0])
        self.assertNotIn('--clobber', commands[1])
        self.assertEqual(sum(a.startswith('dist/') for a in commands[1]), 4)
        self.assertIn('--draft=false', commands[-1])

    def test_preflight_does_not_write(self):
        result, writes = self.run_release('new', '--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(writes)

    def test_existing_release_draft_or_tag_and_api_errors_never_write(self):
        for scenario in ['existing-release', 'existing-draft', 'existing-tag', 'api-error']:
            with self.subTest(scenario=scenario):
                result, writes = self.run_release(scenario)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(writes)

    def test_creation_race_does_not_upload_or_edit(self):
        result, commands = self.run_release('create-race')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([a[1] for a in commands], ['create'])

    def test_upload_failure_leaves_draft_unpublished(self):
        result, commands = self.run_release('upload-error')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([a[1] for a in commands], ['create', 'upload'])

    def test_corrupt_remote_download_is_not_published(self):
        result, commands = self.run_release('remote-corruption')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('edit', [a[1] for a in commands])

    def test_corrupt_local_package_never_creates_release(self):
        (self.root/f'dist/PokePal-{self.tag}-kual.zip').write_bytes(b'bad')
        result, commands = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(commands)

    def test_missing_source_never_creates_release(self):
        (self.root/f'dist/PokePal-{self.tag}-corresponding-source.zip').unlink()
        result, commands = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(commands)

    def test_mismatched_version_never_creates_release(self):
        (self.root/'native/kual/config.xml').write_text('<extension><information><version>0.0.1</version></information></extension>')
        result, commands = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(commands)

    def test_wrong_commit_never_creates_release(self):
        self.env['GITHUB_SHA'] = 'b' * 40
        result, commands = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(commands)


if __name__ == '__main__':
    unittest.main()
