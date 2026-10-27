"""Scene posters: each scene's rest pose rendered headlessly, saved as WebP (see rive/CONTRACT.md).

    uv run --with pillow rive/tools/gen_posters.py [sceneId ...]   # default: every scene project

Renders `rive/scenes/<id>` at 1080x1920 (`--advance=1`, the rest pose, no avatar), downsizes to
540x960 and picks the highest WebP quality that fits the 40 KB budget. Deterministic for a given
CLI + Pillow version. Called by scripts/frive.sh after the scene builds.
"""

from __future__ import annotations

import io
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "rive" / "posters"
SIZE = (540, 960)
MAX_BYTES = 40 * 1024


def poster(scene: str) -> tuple[Path, int, int]:
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / f"{scene}.png"
        r = subprocess.run(["rive", str(ROOT / "rive" / "scenes" / scene), f"--screenshot={png}", "--advance=1",
                            "--viewport=1080x1920", "--fit=contain"], capture_output=True, text=True)
        if r.returncode:
            raise SystemExit(f"✗ poster {scene}: rive failed\n{r.stderr}")
        im = Image.open(png).convert("RGB").resize(SIZE, Image.LANCZOS)
    for q in range(90, 20, -4):
        buf = io.BytesIO()
        im.save(buf, "WEBP", quality=q, method=6)
        if buf.tell() <= MAX_BYTES:
            break
    else:
        raise SystemExit(f"✗ poster {scene}: does not fit {MAX_BYTES} B even at low quality")
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{scene}.webp"
    dest.write_bytes(buf.getvalue())
    return dest, buf.tell(), q


def main() -> None:
    scenes = sys.argv[1:] or sorted(p.name for p in (ROOT / "rive" / "scenes").iterdir() if p.is_dir())
    for s in scenes:
        dest, size, q = poster(s)
        print(f"✓ {dest.name}  {size} B (q{q})")


if __name__ == "__main__":
    main()
