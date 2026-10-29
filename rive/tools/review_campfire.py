"""Evidence for the campfire diorama (moonshot M4 Task 6): real CLI renders of `rive/scenes/campfire`.

    uv run --with pillow --with numpy rive/tools/review_campfire.py [before_poster.webp]

Writes to rive/review/m4/campfire/:
- `parallax_sheet.png`: parallaxX -1/0/1 (columns) x parallaxY -1/0/1 (rows), the full frame;
- `parallax_edges.png`: the same nine renders at half size, only the outer 32 px of the left and
  right edges (columns) and the bottom 32 px (rows), where a plane's bleed would run out;
- `fire_strip.png`: 10 frames across one 89-frame `amb_firelight` loop, cropped to the fire, the
  light pool and the tree glow;
- `poster_before_after.png` (when the M3 poster is given): the M3 poster beside the new one;
- `gates.txt`: the objective gates (opaque frame at every parallax corner, firelight seam, sizes).
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "scenes" / "campfire"
OUT = ROOT / "rive" / "review" / "m4" / "campfire"
FIRE_CROP = (0, 760, 760, 1400)  # the fire, its light pool and the tree glow above it
# (plane, artboard patch, expected x travel at |parallaxX| = 1): opaque art of one plane only
PATCHES = [("Plane5 BushL", (100, 1620, 260, 1720), 40), ("Plane4 tent", (700, 920, 860, 1080), 28),
           ("Plane3 near pine", (1000, 600, 1060, 760), 20), ("Plane1 snow peak", (330, 600, 460, 700), 6)]


def render(png: Path, *args: str) -> np.ndarray:
    r = subprocess.run(["rive", str(PROJ), f"--screenshot={png}", "--viewport=1080x1920", "--fit=contain", *args],
                       capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"rive failed: {r.stderr}")
    return np.asarray(Image.open(png).convert("RGBA"))


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((6, 4), text, fill=(255, 255, 0))
    return im


def grid(cells: list[Image.Image], cols: int) -> Image.Image:
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % cols) * w, (i // cols) * h))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    gates: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        full: list[Image.Image] = []
        sides: list[Image.Image] = []
        bottoms: list[Image.Image] = []
        shots: dict[tuple[int, int], np.ndarray] = {}
        opaque = True
        for py in (-1, 0, 1):
            for px in (-1, 0, 1):
                a = render(t / f"p{px}{py}.png", f"--data=parallaxX={px}", f"--data=parallaxY={py}", "--advance=1")
                ok = bool((a[..., 3] == 255).all())
                opaque &= ok
                gates.append(f"parallax ({px:+d}, {py:+d}): every pixel opaque: {ok}")
                im = Image.fromarray(a).convert("RGB")
                shots[(px, py)] = a
                full.append(label(im.resize((270, 480)), f"x{px:+d} y{py:+d}"))
                half = im.resize((540, 960))
                side = Image.new("RGB", (68, 960), (90, 0, 90))
                side.paste(half.crop((0, 0, 32, 960)), (0, 0))
                side.paste(half.crop((508, 0, 540, 960)), (36, 0))
                sides.append(side)
                bottoms.append(half.crop((0, 928, 540, 960)))
        grid(full, 3).save(OUT / "parallax_sheet.png")
        edges = Image.new("RGB", (9 * 72, 960 + 9 * 36), (20, 20, 20))
        for i, (side, bottom) in enumerate(zip(sides, bottoms)):
            edges.paste(side, (i * 72, 0))
            edges.paste(bottom, (0, 960 + i * 36))
        edges.save(OUT / "parallax_edges.png")
        # travel: where a patch of each plane's art lands at parallaxX = +-1 (best horizontal shift)
        for plane, (x0, y0, x1, y1), want in PATCHES:
            ref = shots[(0, 0)][y0:y1, x0:x1, :3].astype(int)
            got = []
            for px in (-1, 1):
                img = shots[(px, 0)][..., :3].astype(int)
                errs = {dx: np.abs(img[y0:y1, x0 + dx:x1 + dx] - ref).mean() for dx in range(-48, 49)
                        if 0 <= x0 + dx and x1 + dx <= 1080}
                got.append(min(errs, key=errs.get))
            ok = got == [-want, want]
            gates.append(f"{plane} travel at parallaxX -1/+1: {got[0]:+d}/{got[1]:+d} px (want -/+{want}): "
                         f"{'ok' if ok else 'FAIL'}")
        gates.append(f"parallax gate (no transparent pixel at any corner): {'ok' if opaque else 'FAIL'}")

        frames = [1 + round(i * 89 / 10) for i in range(10)]
        cells = []
        for f in frames:
            a = render(t / f"f{f}.png", f"--advance={f}")
            cells.append(label(Image.fromarray(a).convert("RGB").crop(FIRE_CROP).resize((380, 320)), f"f{f - 1}"))
        grid(cells, 5).save(OUT / "fire_strip.png")
        # seam: the pool/tree-glow tracks loop with amb_firelight (89 frames); compare the pool region
        # (fire tongues excluded: they loop on their own prime periods)
        a0 = render(t / "s0.png", "--advance=1").astype(int)
        a1 = render(t / "s1.png", "--advance=90").astype(int)
        box = (slice(1230, 1380), slice(300, 440))  # light pool right of the stones, clear of fireflies
        diff = np.abs(a0[box][..., :3] - a1[box][..., :3]).max()
        gates.append(f"firelight seam (pool region, frame 0 vs 89): max channel diff {diff}/255 "
                     f"({'ok' if diff <= 2 else 'FAIL'})")

    riv = ROOT / "assets" / "rive" / "scenes" / "campfire.riv"
    poster = ROOT / "assets" / "rive" / "posters" / "campfire.webp"
    gates.append(f"campfire.riv {riv.stat().st_size} B (budget 409,600): "
                 f"{'ok' if riv.stat().st_size <= 409600 else 'FAIL'}")
    gates.append(f"campfire.webp {poster.stat().st_size} B (budget 40,960): "
                 f"{'ok' if poster.stat().st_size <= 40960 else 'FAIL'}")
    if len(sys.argv) > 1:
        before = Image.open(sys.argv[1]).convert("RGB")
        after = Image.open(poster).convert("RGB")
        pair = Image.new("RGB", (before.width + after.width + 8, max(before.height, after.height)), (20, 20, 20))
        pair.paste(label(before, "M3"), (0, 0))
        pair.paste(label(after, "M4 diorama"), (before.width + 8, 0))
        pair.save(OUT / "poster_before_after.png")
    (OUT / "gates.txt").write_text("\n".join(gates) + "\n")
    print("\n".join(gates))


if __name__ == "__main__":
    main()
