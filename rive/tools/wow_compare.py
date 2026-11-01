"""The final re-shoot's side-by-side (moonshot M12 ruling 10): each wow's earlier beats sheet above the
M12 one, labelled, as one WebP per wow.

    uv run --with pillow rive/tools/wow_compare.py rive/review/m12/wow

Earlier sheets: wow1 and wow3 from M7 (the last full shoot of each), wow2 from M6. Each sheet is scaled
to the same width (the narrower of the two, at most 1600 px).
"""

from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
EARLIER = {
    "wow1": ("M7", ROOT / "rive/review/m7/wow/wow1_beats.png"),
    "wow2": ("M6", ROOT / "rive/review/m6/wow/wow2_beats.png"),
    "wow3": ("M7", ROOT / "rive/review/m7/wow/wow3_beats.png"),
}
MAX_W = 1600
BAND = 30


def compare(before: Path, after: Path, labels: tuple[str, str], out: Path) -> None:
    a, b = Image.open(before).convert("RGB"), Image.open(after).convert("RGB")
    w = min(a.width, b.width, MAX_W)
    a = a.resize((w, round(a.height * w / a.width)), Image.LANCZOS)
    b = b.resize((w, round(b.height * w / b.width)), Image.LANCZOS)
    sheet = Image.new("RGB", (w, a.height + b.height + 2 * BAND), (10, 10, 10))
    d = ImageDraw.Draw(sheet)
    y = 0
    for im, label in ((a, labels[0]), (b, labels[1])):
        d.text((8, y + 8), label, fill=(244, 184, 96))
        sheet.paste(im, (0, y + BAND))
        y += BAND + im.height
    sheet.save(out, quality=80, method=6)


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__)
        return 2
    out_dir = Path(argv[0])
    for wow, (milestone, before) in EARLIER.items():
        after = out_dir / f"{wow}_beats.png"
        if not after.exists() or not before.exists():
            print(f"{wow}: skipped (missing {after if not after.exists() else before})")
            continue
        out = out_dir / f"{wow}_then_now.webp"
        compare(before, after, (f"{wow} - {milestone}", f"{wow} - M12 (final re-shoot)"), out)
        print(f"{out.name} {out.stat().st_size} B")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
