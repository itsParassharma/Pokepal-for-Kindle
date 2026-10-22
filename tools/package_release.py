"""Package both editions and the native runtime's corresponding source."""
import argparse
import hashlib
from pathlib import Path
import re
import zipfile
from build_native import SOURCES

REPO=Path(__file__).resolve().parents[1]
PLUGIN=REPO/'pokepal.koplugin'
VERSION=re.search(r'version\s*=\s*"([\d.]+)"',(PLUGIN/'_meta.lua').read_text()).group(1)
STAMP=(2026,10,22,0,0,0)

def add(package,path,name,executable=False):
    info=zipfile.ZipInfo(name,STAMP)
    info.compress_type=zipfile.ZIP_DEFLATED
    info.create_system=3
    info.external_attr=(0o100755 if executable else 0o100644)<<16
    package.writestr(info,path.read_bytes(),compresslevel=9)

def files(root):
    for path in sorted(root.rglob('*')):
        relative=path.relative_to(root)
        if path.is_file() and not any(part.startswith('.') or part=='__pycache__' for part in relative.parts):
            if path.suffix not in {'.pyc','.tmp','.dat','.old','.log','.pgm','.exe'}:
                yield path,relative.as_posix()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deps',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=REPO/'dist')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    archives=[]
    plugin=out/f'PokePal-v{VERSION}-koreader.zip'
    with zipfile.ZipFile(plugin,'w') as z:
        for path,relative in files(PLUGIN):add(z,path,'koreader/plugins/pokepal.koplugin/'+relative)
    archives.append(plugin)
    standalone=out/f'PokePal-v{VERSION}-kual.zip'
    binary=REPO/'native/build/pokepal'
    assert binary.is_file(),'Build the native host first.'
    with zipfile.ZipFile(standalone,'w') as z:
        prefix='extensions/pokepal/'
        add(z,binary,prefix+'pokepal',True)
        add(z,REPO/'native/runtime.lua',prefix+'runtime.lua')
        add(z,REPO/'native/LICENSE-GPL-3.0.txt',prefix+'LICENSE-GPL-3.0.txt')
        add(z,REPO/'native/README.md',prefix+'BUILD-AND-SOURCE.md')
        for path,relative in files(REPO/'native/kual'):add(z,path,prefix+relative,path.suffix=='.sh')
        for path,relative in files(REPO/'native/fonts'):add(z,path,prefix+'fonts/'+relative)
        for path,relative in files(REPO/'native/licenses'):add(z,path,prefix+'licenses/'+relative)
        for path,relative in files(PLUGIN):add(z,path,prefix+'game/'+relative)
        z.writestr(prefix+'data/',b'')
    archives.append(standalone)
    source=out/f'PokePal-v{VERSION}-corresponding-source.zip'
    with zipfile.ZipFile(source,'w') as z:
        for path,relative in files(REPO):
            if relative.startswith(('native/build/','tests/rendered/','dist/')):continue
            add(z,path,'PokePal/'+relative,path.suffix=='.sh')
        for dependency in SOURCES:
            root=args.deps.resolve()/dependency
            assert root.is_dir(),root
            for path,relative in files(root):add(z,path,f'dependencies/{dependency}/'+relative)
            z.writestr(f'dependencies/{dependency}/POKEPAL_REVISION.txt',SOURCES[dependency][1]+'\n')
    archives.append(source)
    checks=out/f'PokePal-v{VERSION}-SHA256.txt'
    checks.write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in archives))
    for archive in archives:
        with zipfile.ZipFile(archive) as z:assert z.testzip() is None
        print(f'{archive.name}: {archive.stat().st_size:,} bytes')
    with zipfile.ZipFile(standalone) as z:
        names=z.namelist()
        assert 'extensions/pokepal/pokepal' in names
        assert not any(n.endswith(('.dat','.old','.log','.exe','.pgm')) for n in names)
        assert z.getinfo('extensions/pokepal/pokepal').external_attr>>16 & 0o111
    print('Archives, executable permissions, clean saves and checksums verified.')

if __name__=='__main__':main()
