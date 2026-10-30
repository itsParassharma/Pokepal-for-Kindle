"""Package actual KOReader card renders for the guide; no simulated UI."""
import sys
from pathlib import Path
from PIL import Image, ImageChops

root = Path(__file__).resolve().parents[1]
prefix = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'tests/rendered/simpleui-card'
frames = [Image.open(f'{prefix}-animation-{n}.png').convert('RGB') for n in (1, 2, 3)]
assert frames[0].size == (560, 290)
assert frames[0].tobytes() == frames[2].tobytes(), 'Animation did not return to rest'
bounds = ImageChops.difference(frames[0], frames[1]).getbbox()
assert bounds and 10 <= bounds[0] < bounds[2] <= 138, 'Animation altered content outside the sprite'
frames[0].save(root / 'docs/simpleui-card.png')
frames[0].save(root / 'docs/simpleui-card-animation.gif', save_all=True,
               append_images=frames[1:], duration=[800, 800, 2400], loop=0, disposal=2)
with Image.open(root / 'docs/simpleui-card-animation.gif') as preview:
    assert preview.n_frames == 3
print('SIMPLEUI PREVIEW: actual Eco frames differ only in the sprite and return to rest')
