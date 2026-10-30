"""Evidence and gates for the journey thresholds (moonshot M7 Task 7, contract v10).

    uv run --with pillow --with numpy rive/tools/review_journey.py --out=rive/review/m7/journeys
    uv run --with pillow --with numpy rive/tools/review_journey.py --gates-only

The CLI paints every screenshot over its own grey, so each pose is rendered twice in a scratch copy
of `rive/journeys` over a black, then a white, full-frame backdrop added at the back of `Journey`,
and alpha is recovered as 1 - (white - black) / 255 (as M6's `review_diorama.FrontRenderer`).

Writes (unless `--gates-only`): `<family>_strip.png` per family: open 0 / 0.5 / 1 (the rocket adds
lift 0.08 and 1; the door adds open 1 with its v11 jacket on the peg), composited over every scene's poster with the avatar's rest render, in the phone
framing the app uses (the scene `Fit.cover`, the avatar and the journey `Fit.contain` at the
bottom; one row per scene with a poster: the M8 four and each built v12 scene); `sheet.png` (all
four strips); `gates.txt`.

Gates (one line each, `ok` or `FAIL`):
- every number 0, and `open` 1 + `lift` 1 + `jacket` 1 with no family shown: nothing drawn (alpha 0);
- each family shows only through its own number (cover > 2 % with it at 1, the others 0);
- open 1: the threshold covers >= 85 % of the band x 650-790, y 200-990 (the rocket's hull: y
  330-830) with alpha > 0.5: the avatar disappears into something solid;
- door / rocket: `open` changes the pixels inside the threshold (the leaf and hatch move);
- rocket at lift 1: < 0.5 % of the frame drawn (it left; its smoke is gone too);
- the ambient loop is seamless: frame 0 vs 240 identical with every family at 1.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import gen_journeys  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "journeys"
AVATAR = ROOT / "rive" / "avatar"
POSTERS = ROOT / "assets" / "rive" / "posters"
# the M8 scenes, then every v12 scene whose poster exists (world_kit.SCENE_MODULES): the strips
# composite the journeys over each scene's poster
SCENES = (*world_kit.BUILT_IN_SCENES, *(s for s in world_kit.SCENE_MODULES if (POSTERS / f"{s}.webp").exists()))
W, H = gen_journeys.W, gen_journeys.H
BAND = (650, 790, 200, 990)
# the rocket tapers to its nose and stands on legs: its solid hull spans y 330-830
FAMILY_BAND = {"rocket": (650, 790, 330, 830)}


class JourneyRenderer:
    """Renders `Journey` poses with alpha (black / white backdrops in two scratch copies)."""

    def __init__(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="journey_review_"))
        rml = (PROJ / "journeys.rml").read_text()
        self.copies: dict[str, Path] = {}
        for name, colour in (("black", "FF000000"), ("white", "FFFFFFFF")):
            dst = self.tmp / name
            dst.mkdir()
            shutil.copy(PROJ / "rive.yaml", dst / "rive.yaml")
            backdrop = (f'<Shape id="0:9999990" name="ReviewBackdrop" x="{W / 2}" y="{H / 2}">'
                        f'<Rectangle id="0:9999991" name="Path" width="{W * 3}" height="{H * 3}"/>'
                        f'<Fill id="0:9999992" name="Fill"><SolidColor id="0:9999993" colorValue="{colour}"/></Fill>'
                        f'</Shape>')
            # the backdrop paints behind everything: the artboard's last drawable child
            out = re.sub(r'(<LinearAnimation [^>]*name="amb_journey")', backdrop + r"\n\1", rml, count=1)
            (dst / "journeys.rml").write_text(out)
            self.copies[name] = dst

    def render(self, data: dict[str, float], advance: int = 2) -> np.ndarray:
        """RGBA float array (H, W, 4), colours un-premultiplied."""
        shots = {}
        for name, proj in self.copies.items():
            png = self.tmp / f"{name}.png"
            args = ["rive", str(proj), f"--screenshot={png}", f"--advance={advance}"]
            args += [f"--data={k}={v}" for k, v in data.items()]
            subprocess.run(args, check=True, capture_output=True)
            shots[name] = np.asarray(Image.open(png).convert("RGB")).astype(np.float64)
        b, w = shots["black"], shots["white"]
        alpha = np.clip(1 - (w - b).mean(axis=2) / 255.0, 0, 1)
        rgb = np.where(alpha[..., None] > 1e-3, b / np.maximum(alpha[..., None], 1e-3), 0)
        return np.dstack([np.clip(rgb, 0, 255), alpha * 255])

    def close(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)


def avatar_rest(tmp: Path) -> Image.Image:
    """The avatar's rest render with its CLI grey made transparent (a hard key: evidence only)."""
    png = tmp / "avatar.png"
    subprocess.run(["rive", str(AVATAR), f"--screenshot={png}", "--advance=30"], check=True, capture_output=True)
    rgb = np.asarray(Image.open(png).convert("RGB")).astype(np.int32)
    bg = rgb[2, 2]
    alpha = (np.abs(rgb - bg).sum(axis=2) > 24).astype(np.uint8) * 255
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")


def compose(scene: str, avatar: Image.Image, journey: np.ndarray, width: int = 270) -> Image.Image:
    """The phone framing: poster (9:16, cover) + avatar and journey (contain, bottom-centre)."""
    height = width * 16 // 9
    out = Image.open(POSTERS / f"{scene}.webp").convert("RGBA").resize((width, height))
    scale = width / W
    size = (width, round(H * scale))
    top = height - size[1]
    out.alpha_composite(avatar.resize(size), (0, top))
    j = Image.fromarray(journey.astype(np.uint8), "RGBA").resize(size)
    out.alpha_composite(j, (0, top))
    return out


def cover(a: np.ndarray, box: tuple[int, int, int, int] | None = None, thr: float = 0.5) -> float:
    x0, x1, y0, y1 = box or (0, W, 0, H)
    return float((a[y0:y1, x0:x1, 3] > thr * 255).mean())


FAMILY_POSES: dict[str, list[dict[str, float]]] = {
    f: [{"open": 0.0}, {"open": 0.5}, {"open": 1.0}] for f in gen_journeys.FAMILIES
}
# lift-off at 0.08: the composite pastes only the artboard box, and higher the nose leaves it (in the
# app the unclipped artboard keeps drawing above it)
FAMILY_POSES["rocket"] += [{"open": 0.0, "lift": 0.08}, {"open": 0.0, "lift": 1.0}]
# v11 (moonshot M8): the door's jacket column (the coat on the peg, the door open as during the grab)
FAMILY_POSES["door"] += [{"open": 1.0, "jacket": 1.0}]


def gates(r: JourneyRenderer) -> list[str]:
    lines = []
    zero = r.render({})
    lines.append(f"all zero draws nothing: max alpha {zero[..., 3].max():.0f} ({'ok' if zero[..., 3].max() < 1 else 'FAIL'})")
    hidden = r.render({"open": 1.0, "lift": 1.0, "jacket": 1.0})
    lines.append(f"open 1 + lift 1 + jacket 1, no family: max alpha {hidden[..., 3].max():.0f} "
                 f"({'ok' if hidden[..., 3].max() < 1 else 'FAIL'})")
    for fam in gen_journeys.FAMILIES:
        shown = r.render({fam: 1.0})
        c = cover(shown, thr=0.05)
        lines.append(f"{fam} shows through `{fam}`: cover {c * 100:.1f} % ({'ok' if c > 0.02 else 'FAIL'})")
        opened = r.render({fam: 1.0, "open": 1.0})
        band = cover(opened, FAMILY_BAND.get(fam, BAND))
        lines.append(f"{fam} open 1 covers the threshold band: {band * 100:.1f} % ({'ok' if band >= 0.85 else 'FAIL'})")
        if fam in ("door", "rocket"):
            x0, x1, y0, y1 = FAMILY_BAND.get(fam, BAND)
            delta = float(np.abs(opened[y0:y1, x0:x1, :3] - shown[y0:y1, x0:x1, :3]).mean())
            lines.append(f"{fam} `open` moves the threshold: mean delta {delta:.1f}/255 ({'ok' if delta > 4 else 'FAIL'})")
    gone = r.render({"rocket": 1.0, "lift": 1.0})
    c = cover(gone, thr=0.05)
    lines.append(f"rocket at lift 1 has left: cover {c * 100:.2f} % ({'ok' if c < 0.005 else 'FAIL'})")
    every = {f: 1.0 for f in gen_journeys.FAMILIES}
    f0 = r.render(every, advance=1)
    f1 = r.render(every, advance=gen_journeys.AMB_FRAMES + 1)
    seam = float((np.abs(f0 - f1).max(axis=2) > 2).mean())
    lines.append(f"ambient loop seam (frame 0 vs {gen_journeys.AMB_FRAMES}): {seam * 100:.2f} % "
                 f"({'ok' if seam < 0.001 else 'FAIL'})")
    return lines


def strips(r: JourneyRenderer, out: Path) -> None:
    avatar = avatar_rest(r.tmp)
    sheets = []
    for fam, poses in FAMILY_POSES.items():
        renders = [r.render({fam: 1.0, **p}) for p in poses]
        cols = [[compose(s, avatar, j) for j in renders] for s in SCENES]
        cw, ch = cols[0][0].size
        strip = Image.new("RGBA", (cw * len(poses), ch * len(SCENES)), (0, 0, 0, 255))
        for row, scene_cols in enumerate(cols):
            for col, im in enumerate(scene_cols):
                strip.alpha_composite(im, (col * cw, row * ch))
        strip.convert("RGB").save(out / f"{fam}_strip.png")
        sheets.append(strip)
    width = max(s.size[0] for s in sheets) // 2
    sheet = Image.new("RGBA", (width, sum(s.size[1] // 4 for s in sheets)), (0, 0, 0, 255))
    y = 0
    for s in sheets:
        small = s.resize((s.size[0] // 2, s.size[1] // 2)).crop((0, 0, s.size[0] // 2, s.size[1] // 4))
        sheet.alpha_composite(small, (0, y))
        y += small.size[1]
    sheet.convert("RGB").save(out / "sheet.png")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "rive" / "review" / "m7" / "journeys"))
    ap.add_argument("--gates-only", action="store_true")
    args = ap.parse_args()
    r = JourneyRenderer()
    try:
        lines = gates(r)
        print("\n".join(lines))
        if not args.gates_only:
            out = Path(args.out)
            out.mkdir(parents=True, exist_ok=True)
            strips(r, out)
            (out / "gates.txt").write_text("\n".join(lines) + "\n")
    finally:
        r.close()
    return 1 if any(line.endswith("FAIL)") for line in lines) else 0


if __name__ == "__main__":
    sys.exit(main())
