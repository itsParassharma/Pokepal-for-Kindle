"""Convert downloaded Gen V GIFs (152.gif through 160.gif) for PokePal.

Download from the pinned URLs in assets/sources.json, then run:
    python tools/import_johto_sprites.py /path/to/downloaded/gifs
Only these nine species are updated. Runtime gameplay remains offline.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageSequence

ROOT = Path(__file__).resolve().parents[1] / "pokepal.koplugin" / "assets"
REVISION = "8491ffde1b247e4de574d4bb8e24b7bd9fa876fa"
IDS = tuple(range(152, 161))


def convert(path):
    with Image.open(path) as source:
        frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(source)]
    # One crop and scale across the animation prevents frame-to-frame jitter.
    mask = Image.new("L", frames[0].size)
    for frame in frames:
        mask = ImageChops.lighter(mask, frame.getchannel("A"))
    box = mask.getbbox()
    if box is None:
        raise ValueError(f"Empty sprite: {path}")
    width, height = box[2] - box[0], box[3] - box[1]
    scale = 80 / max(width, height)
    size = (round(width * scale), round(height * scale))
    unique, seen = [], set()
    for index, frame in enumerate(frames):
        rgba = frame.crop(box).resize(size, Image.Resampling.NEAREST)
        gray = rgba.convert("L").point(lambda value: ((value + 42) // 85) * 85)
        sprite = Image.merge("LA", (gray, rgba.getchannel("A")))
        canvas = Image.new("LA", (96, 96), (255, 0))
        canvas.paste(sprite, ((96 - size[0]) // 2, 90 - size[1]))
        data = canvas.tobytes()
        if data not in seen:
            seen.add(data)
            unique.append((index, canvas))
    if len(unique) < 4:
        raise ValueError(f"Expected at least four distinct frames: {path}")
    return len(frames), [unique[i * len(unique) // 4] for i in range(4)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    args = parser.parse_args()
    records = json.loads((ROOT / "sources.json").read_text())
    records = [record for record in records if record["id"] not in IDS]
    for species in IDS:
        path = args.source_dir / f"{species}.gif"
        count, frames = convert(path)
        for number, (_, frame) in enumerate(frames, 1):
            frame.save(ROOT / f"{species}-{number}.png", optimize=True)
        records.append({
            "id": species,
            "source": f"https://raw.githubusercontent.com/PokeAPI/sprites/{REVISION}/"
                      f"sprites/pokemon/versions/generation-v/black-white/animated/{species}.gif",
            "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "original_frames": count,
            "sampled": [index for index, _ in frames],
            "count": len(frames),
        })
        print(f"{species}: {len(frames)} grayscale frames from {count} source frames")
    (ROOT / "sources.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
