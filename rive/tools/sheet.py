"""Dev helper: render several headless captures of a rive project into one labelled contact sheet.

    uv run --with pillow rive/tools/sheet.py <project-dir> <out.png> <crop x0,y0,x1,y1|full> <cell-w> \
        "label|--data=mood=happy --advance=20" ...
"""

from __future__ import annotations

import shlex
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw


def main() -> None:
    proj, out, crop, cw = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    specs = sys.argv[5:]
    cells = []
    with tempfile.TemporaryDirectory() as tmp:
        for i, spec in enumerate(specs):
            label, args = spec.split("|", 1)
            png = f"{tmp}/c{i}.png"
            subprocess.run(["rive", proj, f"--screenshot={png}", *shlex.split(args)], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            im = Image.open(png).convert("RGB")
            if crop != "full":
                im = im.crop(tuple(int(v) for v in crop.split(",")))
            im = im.resize((cw, int(im.height * cw / im.width)))
            ImageDraw.Draw(im).text((6, 4), label, fill=(255, 255, 0))
            cells.append(im)
    cols = min(len(cells), 6)
    rows = (len(cells) + cols - 1) // cols
    ch = max(c.height for c in cells)
    sheet = Image.new("RGB", (cols * cw, rows * ch), (20, 20, 20))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % cols) * cw, (i // cols) * ch))
    sheet.save(out)


if __name__ == "__main__":
    main()
