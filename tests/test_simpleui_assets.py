"""Validate every exported mood and render an inspectable asset contact sheet."""
import io
import pathlib
import sys
import zipfile

from lupa.luajit21 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

REPO = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'tools'))
from build_simpleui_assets import build
from package_release import add, files

ROOT = REPO / 'pokepal.koplugin/assets/simpleui'
for name, data in build().items():
    assert (ROOT / name).read_bytes() == data, f'Regenerate {name}'
lua = LuaRuntime(unpack_returned_tuples=True)
index = lua.execute(f'return dofile("{ROOT.as_posix()}/index.lua")')
spec = lua.execute(f'return dofile("{REPO.as_posix()}/pokepal.koplugin/simpleui_critter.lua")')
moods = list(spec.moods.values())
packed = (ROOT / 'sprites.bin').read_bytes()


def picture(species, mood):
    offset, length = index[species][mood][1], index[species][mood][2]
    assert 0 <= offset < len(packed) and offset + length <= len(packed)
    image = Image.open(io.BytesIO(packed[offset:offset + length]))
    image.load()
    assert image.mode == 'LA' and image.size == (64, 64)
    assert image.getchannel('A').getbbox()[3] == 64
    assert set(image.getchannel('L').tobytes()) <= {0, 85, 170, 255}
    assert set(image.getchannel('A').tobytes()) <= {0, 255}
    return image


for species in range(1, 387):
    assert set(index[species].keys()) == set(moods)
    for mood in moods:
        picture(species, mood)

samples = [(1, 'Bulbasaur'), (6, 'Charizard'), (7, 'Squirtle'), (25, 'Pikachu'),
           (133, 'Eevee'), (143, 'Snorlax'), (201, 'Unown'), (386, 'Deoxys')]
sheet = Image.new('RGB', (12 * 100 + 120, len(samples) * 155 + 65), '#f5f3eb')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
for col, mood in enumerate(moods):
    draw.text((120 + col * 100, 18), mood, fill='black', font=font)
for row, (species, name) in enumerate(samples):
    draw.text((8, 65 + row * 155 + 55), name, fill='black', font=font)
    for col, mood in enumerate(moods):
        image = picture(species, mood).resize((96, 96), Image.Resampling.NEAREST)
        x, y = 120 + col * 100, 65 + row * 155
        draw.rectangle((x, y, x + 96, y + 110), fill='white')
        sheet.paste(image.convert('RGB'), (x, y + 10), image.getchannel('A'))
out = REPO / 'tests/rendered'
out.mkdir(exist_ok=True)
sheet.save(out / 'simpleui-moods.png')
print('SIMPLEUI ASSETS: all 4,632 mood PNGs decode, retain transparency and fit 64px; generation is reproducible')

# Use the release packager's file rules, with no device settings or saves.
prefix = 'koreader/plugins/pokepal.koplugin/'
archive = out / 'PokePal-SimpleUI-preview.zip'
with zipfile.ZipFile(archive, 'w') as package:
    for path, relative in files(REPO / 'pokepal.koplugin'):
        add(package, path, prefix + relative)
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    names = package.namelist()
    assert all(name.startswith(prefix) for name in names)
    for name in ('main.lua', 'simpleui_critter.lua', 'simpleui_menu.lua',
                 'assets/simpleui/index.lua', 'assets/simpleui/sprites.bin', 'SPRITE-LICENSE.md'):
        assert prefix + name in names
    assert not any(name.endswith(('.dat', '.old', '.tmp', '.log')) for name in names)
    assert package.read(prefix + 'assets/simpleui/sprites.bin') == packed
print('SIMPLEUI PACKAGE: install paths, required files, sprite licences, CRCs and absence of saves verified')
