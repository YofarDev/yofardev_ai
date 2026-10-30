"""Evidence for the jacket handoff and the tablet's weather card (moonshot M8 Task 3, rulings 5, 14).

    uv run --with pillow --with numpy rive/tools/review_jacket_tablet.py            # both
    uv run --with pillow --with numpy rive/tools/review_jacket_tablet.py --jacket   # one of them
    uv run --with pillow --with numpy rive/tools/review_jacket_tablet.py --tablet

Writes:
- `rive/review/m8/jacket/grab_strip.png`: the `grab` gesture, 8 frames, with the journey's open door composited
  over the avatar as the app draws it (the avatar's `jacket` turns true at the contact, the door's `jacket`
  goes 1 -> 0 in the same frame); `hang_strip.png`: the reverse (the jacket goes back on the peg);
  `contact.png`: both copies at the contact frame side by side and overlaid; `gates.txt` (the two copies'
  bounding boxes at the contact; the avatar copy is measured as the jacket true / false difference, so its top
  is where the fist covers the collar).
- `rive/review/m8/tablet/glyphs.png`: each `tabletWeather` at three temperatures; `digits.png`: a run of
  temperatures that shows every digit in both slots, the minus in both slots and the generic card.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import avatar_tablet as tb  # noqa: E402
from review_journey import JourneyRenderer  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
AVATAR = ROOT / "rive" / "avatar"
CONTACT, FRAMES = 23, 54
STEP = ["--pointer=move@400,420"]  # lets the next --data step mid-run (motion_review's trick)
CROP = (300, 300, 800, 1000)
TABLET_CROP = (330, 690, 620, 900)


def shot(png: Path, *args: str) -> Image.Image:
    subprocess.run(["rive", str(AVATAR), f"--screenshot={png}", *args], check=True, capture_output=True)
    return Image.open(png).convert("RGB")


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((6, 6), text, fill=(255, 255, 255))
    return im


def avatar_at(tmp: Path, frame: int, before: bool, after: bool) -> Image.Image:
    """The grab at `frame` (render frame `frame`), `jacket` = `before` until the contact, then `after`."""
    args = ["--data=gestureId=grab", "--data=gesture=true", f"--data=jacket={str(before).lower()}"]
    if frame < CONTACT or before == after:
        args.append(f"--advance={frame + 1}")
    else:
        args += [f"--advance={CONTACT}", *STEP, f"--data=jacket={str(after).lower()}", f"--advance={frame - CONTACT + 1}"]
    return shot(tmp / "av.png", *args)


def composite(av: Image.Image, door: np.ndarray) -> Image.Image:
    out = av.convert("RGBA")
    out.alpha_composite(Image.fromarray(door.astype(np.uint8), "RGBA"))
    return out.convert("RGB")


def bbox(a: np.ndarray, b: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2) > 8)
    return int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())


def jacket(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="jacket_review_"))
    jr = JourneyRenderer()
    try:
        door = {j: jr.render({"door": 1.0, "open": 1.0, "jacket": float(j)}) for j in (0, 1)}
        frames = [round(k * FRAMES / 7) for k in range(8)]
        frames[3] = CONTACT
        for name, before in (("grab", False), ("hang", True)):
            cells = []
            for f in frames:
                held = before if f < CONTACT else not before
                av = avatar_at(tmp, f, before, not before)
                im = composite(av, door[0 if held else 1]).crop(CROP).resize((300, 420), Image.LANCZOS)
                cells.append(label(im, f"{name} f{f} ({f * 1000 // 60} ms) {'hand' if held else 'peg'}"))
            strip = Image.new("RGB", (300 * len(cells), 420))
            for k, c in enumerate(cells):
                strip.paste(c, (k * 300, 0))
            strip.save(out / f"{name}_strip.png")
        # the two copies at the contact (frame 24: the hand is closed from the contact on either way)
        on = np.asarray(avatar_at(tmp, CONTACT + 1, True, True))
        off = np.asarray(avatar_at(tmp, CONTACT + 1, False, False))
        a_box = bbox(on, off)
        d_box = bbox(door[1][..., :3] * (door[1][..., 3:] / 255), door[0][..., :3] * (door[0][..., 3:] / 255))
        lines = [f"avatar jacket at the contact (x0, x1, y0, y1): {a_box} (top: under the closed fist)",
                 f"door jacket on the peg (x0, x1, y0, y1): {d_box}",
                 f"left / right / bottom edges differ by {abs(a_box[0] - d_box[0])} / {abs(a_box[1] - d_box[1])} / "
                 f"{abs(a_box[3] - d_box[3])} px "
                 f"({'ok' if max(abs(a_box[i] - d_box[i]) for i in (0, 1, 3)) <= 6 else 'FAIL'})"]
        side = Image.new("RGB", (1500, 700))
        av_on = Image.fromarray(on).crop(CROP)
        side.paste(label(av_on.copy(), "avatar: jacket true at the contact"), (0, 0))
        side.paste(label(composite(Image.fromarray(off), door[1]).crop(CROP), "door: jacket 1 (hand open)"), (500, 0))
        side.paste(label(Image.blend(av_on, composite(Image.fromarray(off), door[1]).crop(CROP), 0.5),
                         "both, 50 % each"), (1000, 0))
        side.save(out / "contact.png")
        (out / "gates.txt").write_text("\n".join(lines) + "\n")
        print("\n".join(lines))
    finally:
        jr.close()
        shutil.rmtree(tmp, ignore_errors=True)


def tablet(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="tablet_review_"))

    def card(w: str, t: float) -> Image.Image:
        im = shot(tmp / "t.png", "--data=prop=tablet", f"--data=tabletWeather={w}", f"--data=tabletTemp={t}",
                  "--advance=60")
        return label(im.crop(TABLET_CROP).resize((435, 315), Image.LANCZOS), f"{w} {t:g} -> {tb.shown(t)}")

    try:
        temps = (-7, 12, 38)
        sheet = Image.new("RGB", (435 * 3, 315 * 6))
        for r, w in enumerate(tb.WEATHER[1:]):
            for c, t in enumerate(temps):
                sheet.paste(card(w, t), (c * 435, r * 315))
        sheet.save(out / "glyphs.png")
        runs = [("none", 0), ("clear", -40), ("clear", -9), ("clear", 10), ("clear", 21), ("clear", 32), ("clear", 43),
                ("clear", 54), ("clear", 65), ("clear", 76), ("clear", 87), ("clear", 98)]
        sheet = Image.new("RGB", (435 * 4, 315 * 3))
        for k, (w, t) in enumerate(runs):
            sheet.paste(card(w, t), ((k % 4) * 435, (k // 4) * 315))
        sheet.save(out / "digits.png")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jacket", action="store_true")
    ap.add_argument("--tablet", action="store_true")
    args = ap.parse_args()
    both = not (args.jacket or args.tablet)
    if both or args.jacket:
        jacket(ROOT / "rive" / "review" / "m8" / "jacket")
    if both or args.tablet:
        tablet(ROOT / "rive" / "review" / "m8" / "tablet")
    return 0


if __name__ == "__main__":
    sys.exit(main())
