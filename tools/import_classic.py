"""Build the Game Boy field and battle art. No downloads occur in the game.

python tools/import_classic.py /path/to/pokecrystal /path/to/download-cache
Uses Pillow and Lupa from requirements-dev.txt. Sources are pinned and hashed.
"""
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import urllib.request
from PIL import Image, ImageChops, ImageDraw
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'pokepal.koplugin'
CRYSTAL = '5c877ef55197039c9676e8e3eec6d254b1c40fe8'
EMERALD = '731ad5bfd6e6f265508d0efcca0ba42f9dcf5881'
source, cache = map(Path, sys.argv[1:3])
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip() == CRYSTAL
out = ROOT / 'assets/classic'
out.mkdir(parents=True, exist_ok=True)
manifest, assets = {}, {}


def read(path):
    data = (source / path).read_bytes()
    manifest[path] = hashlib.sha256(data).hexdigest()
    return data


def png(path):
    return Image.open(io.BytesIO(read(path)))


def gray(im):
    alpha = im.convert('RGBA').getchannel('A')
    result = im.convert('L').point(lambda v: round(v / 85) * 85).convert('LA')
    result.putalpha(alpha)
    return result


def add(name, im):
    im = gray(im)
    assert im.getchannel('A').getbbox(), name
    stream = io.BytesIO()
    im.save(stream, format='PNG', optimize=True)
    assets[name + '.png'] = stream.getvalue()


def transparent_border(im):
    im = im.convert('RGBA')
    # Preserve white eyes and clothing; only flood-fill the outside background.
    for x in range(im.width):
        for y in (0, im.height - 1):
            if im.getpixel((x, y)) == (255, 255, 255, 255):
                ImageDraw.floodfill(im, (x, y), (255, 255, 255, 0))
    for y in range(im.height):
        for x in (0, im.width - 1):
            if im.getpixel((x, y)) == (255, 255, 255, 255):
                ImageDraw.floodfill(im, (x, y), (255, 255, 255, 0))
    return im


def block(tileset, number):
    sheet = png(f'gfx/tilesets/{tileset}.png')
    data = read(f'data/tilesets/{tileset}_metatiles.bin')[number * 16:number * 16 + 16]
    assert len(data) == 16
    im = Image.new('L', (32, 32), 255)
    for j, tile in enumerate(data):
        if tile >= 128:
            tile -= 32  # Crystal's second VRAM bank starts at source tile 96.
        x, y = tile % 16 * 8, tile // 16 * 8
        assert y + 8 <= sheet.height, (tileset, number, tile)
        im.paste(sheet.crop((x, y, x + 8, y + 8)), (j % 4 * 8, j // 4 * 8))
    return im


lua = LuaRuntime(unpack_returned_tuples=True)
world = lua.execute(f'return dofile("{ROOT.as_posix()}/world.lua")')
for name, data in world.maps.items():
    rows = list(data.rows.values())
    im = Image.new('L', (352, 256), 255)
    indoor = name in ('centre', 'dojo', 'shop', 'tower')
    tileset = {'centre': 'pokecenter', 'shop': 'mart', 'dojo': 'house', 'tower': 'battle_tower_inside'}.get(name, 'johto_modern')
    for y, row in enumerate(rows):
        for x, tile in enumerate(row):
            if indoor:
                floor = {'centre': 4, 'shop': 4, 'dojo': 0x0F, 'tower': 1}[name]
                b = floor
                if tile == 'W':
                    b = {'centre': 0x13, 'shop': 0x11, 'dojo': 0x12, 'tower': 2}[name]
                if tile == 'C':
                    b = {'centre': {3: 5, 4: 6, 5: 7, 6: 5}.get(x, 5), 'shop': 0x16, 'dojo': 0x1A, 'tower': {3: 3, 4: 4, 5: 3, 6: 2}.get(x, 2)}[name]
                cell = block(tileset, b)
                if tile == '=' and y >= 6:
                    cell = cell.copy()
                    d = ImageDraw.Draw(cell)
                    d.rectangle((4, 12, 27, 31), fill=170, outline=0)
                    d.line((7, 16, 24, 16), fill=255, width=2)
                if tile == 'W' and (x == 0 or x == 10 or y == 7):
                    cell = Image.new('L', (32, 32), 85)
            else:
                b = {'T': 5, '~': 0x35, ',': 3, ':': 0, '=': 0, '?': 0x45, 'B': 0x45}.get(tile, 1)
                if name == 'cave':
                    cell = block('cave', 0x2D if tile == '#' else 9)
                else:
                    cell = block('johto_modern', b)
                if tile == 'K':
                    cell = cell.copy()
                    d = ImageDraw.Draw(cell)
                    for i in range(3):
                        d.rectangle((9 + i * 3, 5 + i * 7, 11 + i * 3, 7 + i * 7), fill=85)
                        d.rectangle((16 + i * 3, 8 + i * 7, 18 + i * 3, 10 + i * 7), fill=85)
            im.paste(cell, (x * 32, y * 32))
    if name == 'town':
        buildings = [(2, 2, [[0x18, 0x1F, 0x19], [0x20, 0x1A, 0x1B]]),
                     (2, 5, [[0x18, 0x19], [0x14, 0x15]]),
                     (7, 5, [[0x18, 0x19], [0x33, 0x17]]),
                     (9, 5, [[0x08, 0x0F], [0x15, 0x16]])]
        for x, y, cells in buildings:
            for dy, line in enumerate(cells):
                for dx, b in enumerate(line):
                    im.paste(block('battle_tower_outside' if x == 9 else 'johto_modern', b), ((x + dx - 1) * 32, (y + dy - 1) * 32))
    add('map-' + name, im)

for name in ('chris', 'champion', 'ranger', 'nurse', 'youngster', 'scientist', 'clerk', 'sage', 'lass'):
    source_name = {'ranger': 'cooltrainer_m', 'champion': 'lance'}.get(name, name)
    sheet = png(f'gfx/sprites/{source_name}.png')
    for direction, row in [('down', 0), ('up', 1), ('left', 2), ('right', 2)]:
        for step in range(2):
            frame = row + (3 if step and sheet.height >= 96 else 0)
            im = transparent_border(sheet.crop((0, frame * 16, 16, frame * 16 + 16)))
            if direction == 'right':
                im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            add(f'trainer-{name}-{direction}-{step}', im)

species = {int(i): name for i, name in re.findall(r'\[(\d+)\]=\{"([^"]+)"', (ROOT / 'species.lua').read_text())}
special = {29: 'nidoran_f', 32: 'nidoran_m', 83: 'farfetch_d', 122: 'mr__mime', 201: 'unown_a', 351: 'castform/normal'}


def battle_species(item):
    id, name = item
    slug = special.get(id, name.lower().replace(' ', '_').replace('-', '_').replace('.', '').replace("'", ''))
    for pose in ('front', 'back'):
        if id <= 251:
            im = png(f'gfx/pokemon/{slug}/{pose}.png')
        else:
            path = f'graphics/pokemon/{slug}/{pose}.png'
            dest = cache / EMERALD / path
            if not dest.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                try:
                    data = urllib.request.urlopen(f'https://raw.githubusercontent.com/pret/pokeemerald/{EMERALD}/{path}', timeout=45).read()
                except OSError as ex:
                    raise RuntimeError(path) from ex
                dest.write_bytes(data)
            data = dest.read_bytes()
            manifest['emerald/' + path] = hashlib.sha256(data).hexdigest()
            im = Image.open(io.BytesIO(data))
        im = im.crop((0, 0, im.width, im.width))
        assert im.mode == 'P', (id, pose, im.mode)
        alpha = Image.frombytes('L', im.size, bytes(0 if p == 0 else 255 for p in im.tobytes()))
        im = im.convert('RGBA');im.putalpha(alpha)
        canvas = Image.new('RGBA', (64, 64), (255, 255, 255, 0))
        canvas.paste(im, ((64 - im.width) // 2, 64 - im.height))
        add(f'{id}-{pose}', canvas)


with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    list(pool.map(battle_species, species.items()))

# Retain the imported species-specific walking directions, reduced to field scale.
packed = json.loads((ROOT / 'assets/sprite-index.json').read_text())
for id in species:
    frames = []
    mask = Image.new('L', (96, 96))
    for direction in ('down', 'up', 'left', 'right'):
        for step in range(2):
            key = f'{id}-walk_{direction}-{step + 1}.png'
            part, offset, length = packed[key]
            with (ROOT / 'assets' / f'{part:03d}.bin').open('rb') as f:
                f.seek(offset);im = Image.open(io.BytesIO(f.read(length))).convert('LA')
            mask = ImageChops.lighter(mask, im.getchannel('A'))
            frames.append((direction, step, im))
    box = mask.getbbox()
    scale = 20 / max(box[2] - box[0], box[3] - box[1])
    size = (max(1, round((box[2] - box[0]) * scale)), max(1, round((box[3] - box[1]) * scale)))
    for direction, step, im in frames:
        im = im.crop(box).resize(size, Image.Resampling.NEAREST)
        canvas = Image.new('LA', (24, 24), (255, 0))
        canvas.paste(im, ((24 - im.width) // 2, 24 - im.height))
        add(f'{id}-walk-{direction}-{step}', canvas)

index, part, data = {}, 1, bytearray()
for name, image in sorted(assets.items()):
    if len(data) + len(image) > 250000:
        (out / f'{part:03d}.bin').write_bytes(data);part += 1;data = bytearray()
    index[name] = [part, len(data), len(image)]
    data.extend(image)
(out / f'{part:03d}.bin').write_bytes(data)
reader = (ROOT / 'assets/sprites.lua').read_text().split('function S.read', 1)[1]
lines = ['-- Generated by tools/import_classic.py.', 'local S={index={']
lines += [f' ["{name}"]={{{",".join(map(str, value))}}},' for name, value in index.items()]
lines += ['}}', 'function S.read' + reader]
(out / 'sprites.lua').write_text('\n'.join(lines), encoding='utf-8')
(out / 'index.json').write_text(json.dumps(index, sort_keys=True, separators=(',', ':')) + '\n')
(out / 'sources.json').write_text(json.dumps({'crystal': CRYSTAL, 'emerald': EMERALD, 'followers': 'Existing SpriteCollab directions; see ../walk-sources.json and CREDITS.txt', 'sha256': dict(sorted(manifest.items()))}, indent=2) + '\n')
print(f'Classic art: {len(index)} images in {part} packs')
