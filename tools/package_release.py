"""Build the installable ZIP and checksum from the current plugin folder."""
import hashlib
from pathlib import Path
import re
import zipfile

REPO = Path(__file__).resolve().parents[1]
PLUGIN = REPO / "pokepal.koplugin"
version = re.search(r'version\s*=\s*"([\d.]+)"', (PLUGIN / "_meta.lua").read_text()).group(1)
destination = REPO / "dist"
destination.mkdir(exist_ok=True)
archive = destination / f"PokePal-v{version}-kindle.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in sorted(PLUGIN.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(PLUGIN)
        if path.suffix in {".pyc", ".tmp", ".dat", ".old"} or any(part.startswith(".") for part in relative.parts):
            continue
        info = zipfile.ZipInfo(f"koreader/plugins/pokepal.koplugin/{relative.as_posix()}", (2026, 10, 7, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        package.writestr(info, path.read_bytes(), compresslevel=9)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(destination / f"PokePal-v{version}-SHA256.txt").write_text(f"{checksum}  {archive.name}\n")
print(f"Built {archive.name} ({archive.stat().st_size} bytes)")
print(f"SHA-256: {checksum}")
