"""Add four genuine walking directions from the pinned SpriteCollab sheets.

Run after import_kanto.py, with the same download-cache argument. Existing
frames are preserved; directional frames use one scale and baseline per species.
"""
import concurrent.futures
import hashlib
import io
import json
import re
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops
import import_kanto as source
import pack_sprites

ROOT = source.ROOT / 'assets'
# SpriteCollab's eight rows run clockwise from down; these are cardinal rows.
DIRECTIONS = {'down': 0, 'left': 2, 'up': 4, 'right': 6}


def frames(species):
    base = f'sprite/{species:04d}/'
    metadata, metadata_url = source.fetch('PMDCollab/SpriteCollab', source.PMD, base + 'AnimData.xml')
    animations = {a.findtext('Name'): a for a in ET.fromstring(metadata).findall('Anims/Anim')}
    name = 'Walk'
    visited = set()
    while animations[name].findtext('CopyOf'):
        assert name not in visited, 'Animation alias cycle'
        visited.add(name)
        name = animations[name].findtext('CopyOf')
    a = animations[name]
    data, url = source.fetch('PMDCollab/SpriteCollab', source.PMD, base + name + '-Anim.png')
    sheet = Image.open(io.BytesIO(data)).convert('RGBA')
    width, height = int(a.findtext('FrameWidth')), int(a.findtext('FrameHeight'))
    assert sheet.height == height * 8 and sheet.width % width == 0, (species, sheet.size)
    count = sheet.width // width
    selected = list(range(count)) if count <= 4 else [round(i * (count - 1) / 3) for i in range(4)]
    cells = {direction: [sheet.crop((i * width, row * height, (i + 1) * width, (row + 1) * height)) for i in selected]
             for direction, row in DIRECTIONS.items()}
    mask = Image.new('L', (width, height))
    for group in cells.values():
        for frame in group:
            assert frame.getchannel('A').getbbox(), (species, 'empty walking frame')
            mask = ImageChops.lighter(mask, frame.getchannel('A'))
    box = mask.getbbox()
    scale = 80 / max(box[2] - box[0], box[3] - box[1])
    size = (max(1, round((box[2] - box[0]) * scale)), max(1, round((box[3] - box[1]) * scale)))
    result = {}
    for direction, group in cells.items():
        for number, frame in enumerate(group, 1):
            frame = frame.crop(box).resize(size, Image.Resampling.NEAREST)
            gray = frame.convert('L').point(lambda value: min(255, ((value + 42) // 85) * 85))
            tile = Image.new('LA', (96, 96), (255, 0))
            tile.paste(Image.merge('LA', (gray, frame.getchannel('A'))), ((96 - size[0]) // 2, 90 - size[1]))
            stream = io.BytesIO()
            tile.save(stream, format='PNG', optimize=True)
            result[f'{species}-walk_{direction}-{number}.png'] = stream.getvalue()
    return species, result, {'species': species, 'source': url, 'source_sha256': hashlib.sha256(data).hexdigest(),
        'metadata': metadata_url, 'rows': DIRECTIONS, 'frames': selected, 'count': len(selected), 'credits': f'credits/{species:03d}.txt'}


def main():
    index = json.loads((ROOT / 'sprite-index.json').read_text())
    records = []
    with tempfile.TemporaryDirectory() as directory:
        staging = Path(directory)
        # Pack through the existing checked packer, without changing old PNG bytes.
        packs = {}
        for name, (species, offset, length) in index.items():
            if '-walk_' in name:
                continue
            if species not in packs:
                packs[species] = (ROOT / f'{species:03d}.bin').read_bytes()
            (staging / name).write_bytes(packs[species][offset:offset + length])
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            for species, images, record in pool.map(frames, range(1, 387)):
                records.append(record)
                for name, data in images.items():
                    (staging / name).write_bytes(data)
                if species % 25 == 0:
                    print(f'Directional walking: {species}/386', flush=True)
        pack_sprites.ROOT = staging
        pack_sprites.pack()
        for path in staging.iterdir():
            if path.suffix != '.png':
                (ROOT / path.name).write_bytes(path.read_bytes())
    poses = (ROOT / 'poses.lua').read_text()
    poses = re.sub(r',walk_(?:up|down|left|right)=\d+', '', poses)
    for record in records:
        species, count = record['species'], record['count']
        poses = re.sub(r'( \[' + str(species) + r'\]=\{[^}]+)(\})',
                       lambda match: match[1] + ''.join(f',walk_{direction}={count}' for direction in DIRECTIONS) + match[2], poses)
    (ROOT / 'poses.lua').write_text(poses)
    (ROOT / 'walk-sources.json').write_text(json.dumps(records, indent=2) + '\n')
    print('Verified directional frames for all 386 Pokemon.', flush=True)


if __name__ == '__main__':
    main()
