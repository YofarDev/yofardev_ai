"""Evidence and gates for the journey thresholds (contract v10-15; re-aimed at the storybook, v15).

    uv run --with pillow --with numpy rive/tools/review_journey.py --out=rive/review/book-threshold
    uv run --with pillow --with numpy rive/tools/review_journey.py --gates-only
    uv run --with pillow --with numpy rive/tools/review_journey.py --out=... --beat

The CLI paints every screenshot over its own grey, so each pose is rendered twice in a scratch copy
of `rive/journeys` over a black, then a white, full-frame backdrop added at the back of `Journey`,
and alpha is recovered as 1 - (white - black) / 255 (as M6's `review_diorama.FrontRenderer`). Renders
are cached per pose, and the data writes go before the advance, so two poses land on the same frame
of the ambient loop and diffs are pose-only.

Strips (`<family>_strip.png`, one row per scene with a poster): the book's keyboard columns (v15) -
the closed medallion, edge-on at open 0.5, the open stub, the riffle at unfold 0.3, erected at
unfold 1 with destBeach, and the jacket on the ribbon - over every scene's poster with the avatar's
rest render, in the phone framing the app uses (the scene `Fit.cover`, the avatar and the journey
`Fit.contain` at the bottom); the other families keep their columns (the rocket adds lift 0.08 and
1). Plus `sheet.png`, `gates.txt`, and with `--beat` the open and close beats at the app's curves
(`JourneyChoreography`, mirrored here; every `out` ease is Flutter's `Curves.easeOut` =
Cubic(0, 0, 0.58, 1), evaluated on its bezier) as sheets of 1:1 crops: `beat_open.png`, `beat_close.png`.

Gates (one line each, `ok` or `FAIL`):
- every number 0 draws nothing, and so does every staged number at 1 with no family shown;
- each family shows only through its own number (cover > 2 % with it at 1, the others 0);
- book: the static block covers >= 85 % of the band x 650-790, y 200-990 at alpha > 0.5, closed AND
  open; `open` lands in-frame (the left band x 260-640 changes); `unfold` changes the left band, the
  riffle moves pixels at unfold 0.2 while the hero has not risen (changed pixels inside the hero
  card's box stay inside the riffle pages' own footprint) and PanelNear is still flat (the emblem's
  zone is unchanged at 0.2, changed at 0.6); every `dest*` erects alone (>= 1 % pairwise pixel
  difference between every pair of destinations inside the hero card's box at unfold 1, rendered
  through the hero's clipping shape); unfold 0.89 vs 1 changes < 1 % of the left band (the grab
  handover snaps nothing); a dest on the closed cover lights only its foil glyph inside the
  medallion; the crack glow is visible at open 0.03 (coverage is recorded for open 0.02-0.1 with the
  default rig and a cool key, deepSpace's);
- path / portal: open 1 covers the band;
- rocket: `open` moves the hatch (its hull band, y 330-830), and at lift 1 it has left (< 0.5 % of
  the frame drawn);
- the ambient loop is seamless (frame 0 vs 240 with every family shown and the book fully erected).
"""

from __future__ import annotations

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import art_bible  # noqa: E402
import gen_journeys  # noqa: E402
import world_kit  # noqa: E402
from ik_check import bezier_ease  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "journeys"
AVATAR = ROOT / "rive" / "avatar"
POSTERS = ROOT / "assets" / "rive" / "posters"
# the M8 scenes, then every later scene whose poster exists (world_kit.SCENE_MODULES): the strips
# composite the journeys over each scene's poster
SCENES = (*world_kit.BUILT_IN_SCENES, *(s for s in world_kit.SCENE_MODULES if (POSTERS / f"{s}.webp").exists()))
W, H = gen_journeys.W, gen_journeys.H
BAND = (650, 790, 200, 990)        # the standing block's band (alpha > 0.5): the avatar vanishes into it
LEFT_BAND = (260, 640, 200, 990)   # in frame, left of the gutter: where the staged beats must land
RIGHT_PAGE = (645, 795, 210, 551)  # the hero card's box (the card stands x 649-792, y 210-551)
# the crack glow's lens is a ~80 px wide vertical at the gutter; this window sits under the ribbon
# tail's sweep (its tip ends at y ~553) and over the medallion (its top at y 772), so a glow count is
# the glow's alone (the cover's own sliding art there moves under 2 px, under the count threshold)
GLOW_ZONE = (600, 680, 570, 760)
# where the erected emblem draws (base at (572, 474)): clear of the Far panel's wedge at unfold 0.2
# (its ridge's smooth outline bulges to x 590 at y 389-414; nothing of it passes left of 585), the
# floor slab (y >= 494) and the landed page stubs (x >= 633)
EMBLEM_ZONE = (515, 585, 290, 490)
MEDALLION_ZONE = (651, 759, 766, 874)   # MEDALLION_X/Y +/- MEDALLION_R + 4
RIFFLE_BOX = (260, 800, 200, 990)       # in frame: both bands the riffle pages may cross at 0.2
# rocket tapers to its nose and stands on legs: its solid hull spans y 330-830
FAMILY_BAND = {"rocket": (650, 790, 330, 830)}

FAMILY_POSES: dict[str, list[dict[str, float]]] = {
    f: [{"open": 0.0}, {"open": 0.5}, {"open": 1.0}] for f in gen_journeys.FAMILIES
}
# v15: the book's keyboard columns - closed medallion, edge-on, the stub, the riffle, erected
# (beach), and the v11 jacket column (the coat on the ribbon, the book open as during the grab)
FAMILY_POSES["book"] += [{"open": 1.0, "unfold": 0.3}, {"open": 1.0, "unfold": 1.0, "destBeach": 1.0},
                         {"open": 1.0, "jacket": 1.0}]
# lift-off at 0.08: the composite pastes only the artboard box, and higher the nose leaves it (in the
# app the unclipped artboard keeps drawing above it)
FAMILY_POSES["rocket"] += [{"open": 0.0, "lift": 0.08}, {"open": 0.0, "lift": 1.0}]


class JourneyRenderer:
    """Renders `Journey` poses with alpha (black / white backdrops in two scratch copies), cached."""

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
        self.cache: dict[tuple, np.ndarray] = {}

    def render(self, data: dict[str, float], advance: int = 2) -> np.ndarray:
        """RGBA float array (H, W, 4), colours un-premultiplied."""
        key = (tuple(sorted((k, str(v)) for k, v in data.items())), advance)
        if key in self.cache:
            return self.cache[key]
        shots = {}
        for name, proj in self.copies.items():
            png = self.tmp / f"{name}.png"
            args = ["rive", str(proj), f"--screenshot={png}"]
            # the writes come before the advance: after it, each write would be a step with a frame
            # of its own, and poses with different write counts would land on different frames
            args += [f"--data={k}={v}" for k, v in data.items()]
            args += [f"--advance={advance}"]
            subprocess.run(args, check=True, capture_output=True)
            shots[name] = np.asarray(Image.open(png).convert("RGB")).astype(np.float64)
        b, w = shots["black"], shots["white"]
        alpha = np.clip(1 - (w - b).mean(axis=2) / 255.0, 0, 1)
        rgb = np.where(alpha[..., None] > 1e-3, b / np.maximum(alpha[..., None], 1e-3), 0)
        out = np.dstack([np.clip(rgb, 0, 255), alpha * 255])
        self.cache[key] = out
        return out

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


def changed(a: np.ndarray, b: np.ndarray, box: tuple[int, int, int, int], thr: float = 2.0) -> tuple[float, int, float]:
    """(changed fraction, changed px, mean abs delta) of the RGB diff inside `box`."""
    x0, x1, y0, y1 = box
    d = np.abs(a[y0:y1, x0:x1, :3] - b[y0:y1, x0:x1, :3]).max(axis=2)
    n = int((d > thr).sum())
    return n / d.size, n, float(d.mean())


def riffle_rows(u: float) -> tuple[float, float]:
    """(y0, y1) the riffle pages occupy on the right page at `unfold` u, + 4 px of outline: each
    flap's window and foreshortening evaluated exactly as the file's converters compute them. A
    landed page lies on the stub, left of the gutter, and reaches no right-page pixel; (0, 0) when
    no flap is airborne."""
    rows = [(cy - h / 2, cy + h / 2)
            for (a, b), (_, h, cy) in zip(gen_journeys.UNFOLD_FLAPS, gen_journeys.FLAPS)
            if min(1.0, max(0.0, (u - a) / (gen_journeys.FLAP_FADE * (b - a)))) > 0
            and math.cos(gen_journeys.FLAP_TURN * min(1.0, max(0.0, (u - a) / (b - a)))) > 0]
    if not rows:
        return 0.0, 0.0
    return min(r0 for r0, _ in rows) - 4, max(r1 for _, r1 in rows) + 4


def gates(r: JourneyRenderer) -> list[str]:
    lines = []
    zero = r.render({})
    lines.append(f"all zero draws nothing: max alpha {zero[..., 3].max():.0f} "
                 f"({'ok' if zero[..., 3].max() < 1 else 'FAIL'})")
    hidden = r.render({"open": 1.0, "lift": 1.0, "jacket": 1.0, "unfold": 1.0, "destBeach": 1.0})
    lines.append(f"open + lift + jacket + unfold + dest at 1, no family: max alpha {hidden[..., 3].max():.0f} "
                 f"({'ok' if hidden[..., 3].max() < 1 else 'FAIL'})")
    shown = {}
    opened = {}
    for fam in gen_journeys.FAMILIES:
        shown[fam] = r.render({fam: 1.0})
        c = cover(shown[fam], thr=0.05)
        lines.append(f"{fam} shows through `{fam}`: cover {c * 100:.1f} % ({'ok' if c > 0.02 else 'FAIL'})")
        opened[fam] = r.render({fam: 1.0, "open": 1.0})

    # the book: the static block, then the staged beats
    shut, opn = shown["book"], opened["book"]
    for label, value, pose in (("closed", 0, shut), ("open", 1, opn)):
        c = cover(pose, BAND)
        lines.append(f"book band at open {value} ({label}): {c * 100:.1f} % ({'ok' if c >= 0.85 else 'FAIL'})")
    frac, n, mean = changed(opn, shut, LEFT_BAND)
    lines.append(f"book `open` lands in-frame: left band changed {frac * 100:.1f} % ({n} px, mean {mean:.1f}/255) "
                 f"({'ok' if frac >= 0.02 else 'FAIL'})")
    erect = r.render({"book": 1.0, "open": 1.0, "unfold": 1.0, "destBeach": 1.0})
    frac, n, mean = changed(erect, opn, LEFT_BAND)
    lines.append(f"book `unfold` changes the left band (0 -> 1): {frac * 100:.1f} % ({n} px, mean {mean:.1f}/255) "
                 f"({'ok' if frac >= 0.02 else 'FAIL'})")
    early = r.render({"book": 1.0, "open": 1.0, "unfold": 0.2, "destBeach": 1.0})
    mid = r.render({"book": 1.0, "open": 1.0, "unfold": 0.6, "destBeach": 1.0})
    frac, n, _ = changed(early, opn, RIFFLE_BOX)
    lines.append(f"book riffle moves pixels at unfold 0.2 in x {RIFFLE_BOX[0]}-{RIFFLE_BOX[1]}: "
                 f"{frac * 100:.1f} % ({n} px) ({'ok' if frac >= 0.01 else 'FAIL'})")
    ry0, ry1 = riffle_rows(0.2)
    _, n_hero, _ = changed(early, opn, RIGHT_PAGE)
    d = np.abs(early[RIGHT_PAGE[2]:RIGHT_PAGE[3], RIGHT_PAGE[0]:RIGHT_PAGE[1], :3]
               - opn[RIGHT_PAGE[2]:RIGHT_PAGE[3], RIGHT_PAGE[0]:RIGHT_PAGE[1], :3]).max(axis=2)
    ys = np.nonzero(d > 2)[0] + RIGHT_PAGE[2]
    # with no flap airborne (0, 0) every changed pixel would stray
    strayed = int(((ys < ry0) | (ys > ry1)).sum()) if ry1 > ry0 else n_hero
    lines.append(f"book hero not risen at unfold 0.2 (starts 0.45): {n_hero} px changed in the card's box, all "
                 f"inside the riffle's rows y {ry0:.0f}-{ry1:.0f}: {strayed} strayed "
                 f"({'ok' if strayed == 0 else 'FAIL'})")
    _, n_zone, _ = changed(early, opn, EMBLEM_ZONE)
    lines.append(f"book PanelNear flat at unfold 0.2: emblem zone changed {n_zone} px "
                 f"({'ok' if n_zone == 0 else 'FAIL'})")
    frac, n, _ = changed(mid, opn, EMBLEM_ZONE)
    lines.append(f"book emblem erects by unfold 0.6: emblem zone changed {frac * 100:.1f} % ({n} px) "
                 f"({'ok' if frac >= 0.01 else 'FAIL'})")
    dests = {}
    assert len(SCENES) == len(gen_journeys.DEST_PROPS), (SCENES, gen_journeys.DEST_PROPS)
    for scene, prop in zip(SCENES, gen_journeys.DEST_PROPS):
        dests[scene] = r.render({"book": 1.0, "open": 1.0, "unfold": 1.0, prop: 1.0})
    worst = (1.0, "")
    for i, s0 in enumerate(SCENES):
        for s1 in SCENES[i + 1:]:
            f, _, _ = changed(dests[s0], dests[s1], RIGHT_PAGE)
            if f < worst[0]:
                worst = (f, f"{s0} vs {s1}")
    lines.append(f"book dest* erect alone: worst pairwise diff in the card's box {worst[0] * 100:.2f} % "
                 f"({worst[1]}) ({'ok' if worst[0] >= 0.01 else 'FAIL'})")
    landed = r.render({"book": 1.0, "open": 1.0, "unfold": 0.89, "destBeach": 1.0})
    frac, n, _ = changed(landed, erect, LEFT_BAND, thr=4)   # visible change (~1.6 % of a channel)
    _, n_soft, _ = changed(landed, erect, LEFT_BAND)        # everything over 2/255, recorded raw
    lines.append(f"book no snap at the grab handover (unfold 0.89 vs 1): left band changed {frac * 100:.2f} % "
                 f"visible ({n} px; {n_soft} px over 2/255 - the shaft's fade tail) "
                 f"({'ok' if frac < 0.01 else 'FAIL'})")
    glyph = r.render({"book": 1.0, "destBeach": 1.0})
    _, n_in, _ = changed(glyph, shut, MEDALLION_ZONE)
    d = np.abs(glyph[:, :, :3] - shut[:, :, :3]).max(axis=2)
    ys, xs = np.nonzero(d > 2)
    inside = (xs >= MEDALLION_ZONE[0]) & (xs < MEDALLION_ZONE[1]) & (ys >= MEDALLION_ZONE[2]) & (ys < MEDALLION_ZONE[3])
    lines.append(f"book closed medallion: dest lights {n_in} px inside it, {int((~inside).sum())} outside "
                 f"({'ok' if n_in > 200 and inside.all() else 'FAIL'})")

    # the crack glow re-judge: recorded for open 0.02-0.1 with the default rig and a cool key; the
    # gate is the default rig at 0.03 (full from the crack's end at GLOW_WINDOW[0] + GLOW_RISE)
    deep = art_bible.SCENES["deepSpace"]
    cool = {"vignetteKey": deep.key, "vignetteAmbient": deep.ambient, "lightKey": deep.key,
            "lightAmbient": deep.ambient}
    glow_gate = 0
    for o in (0.02, 0.03, 0.05, 0.07, 0.1):
        row = []
        poses = {}
        for rig, extra in (("default", {}), ("cool", cool)):
            pose = poses[rig] = r.render({"book": 1.0, "open": o, **extra})
            _, n_glow, _ = changed(pose, shut, GLOW_ZONE, thr=30)
            row.append(f"{rig} {n_glow} px")
            if rig == "default" and o == 0.03:
                glow_gate = n_glow
        _, n_relit, _ = changed(poses["cool"], poses["default"], GLOW_ZONE)
        lines.append(f"book crack glow at open {o}: {', '.join(row)}; the cool key re-lights it: "
                     f"{n_relit} px change")
    lines.append(f"book crack glow visible at open 0.03 (default rig): {glow_gate} px near the gutter "
                 f"({'ok' if glow_gate > 1000 else 'FAIL'})")

    # path and portal keep their band gate; rocket keeps its two
    for fam in ("path", "portal"):
        band = cover(opened[fam], BAND)
        lines.append(f"{fam} open 1 covers the threshold band: {band * 100:.1f} % ({'ok' if band >= 0.85 else 'FAIL'})")
    band = cover(opened["rocket"], FAMILY_BAND["rocket"])
    lines.append(f"rocket open 1 covers the threshold band: {band * 100:.1f} % ({'ok' if band >= 0.85 else 'FAIL'})")
    x0, x1, y0, y1 = FAMILY_BAND["rocket"]
    delta = float(np.abs(opened["rocket"][y0:y1, x0:x1, :3] - shown["rocket"][y0:y1, x0:x1, :3]).mean())
    lines.append(f"rocket `open` moves the threshold: mean delta {delta:.1f}/255 ({'ok' if delta > 4 else 'FAIL'})")
    gone = r.render({"rocket": 1.0, "lift": 1.0})
    c = cover(gone, thr=0.05)
    lines.append(f"rocket at lift 1 has left: cover {c * 100:.2f} % ({'ok' if c < 0.005 else 'FAIL'})")

    every = {**{f: 1.0 for f in gen_journeys.FAMILIES}, "open": 1.0, "unfold": 1.0, "destBeach": 1.0}
    f0 = r.render(every, advance=1)
    f1 = r.render(every, advance=gen_journeys.AMB_FRAMES + 1)
    seam = float((np.abs(f0 - f1).max(axis=2) > 2).mean())
    lines.append(f"ambient loop seam (frame 0 vs {gen_journeys.AMB_FRAMES}, book erected): {seam * 100:.2f} % "
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


# ---------------------------------------------------------------- the beats (--beat): the app's curves

BEAT_CROP = (500, 800, 200, 760)   # x0, x1, y0, y1 of the 1:1 crops: the swing, the riffle, the vignette
APPEAR_MS, SWING_END_MS, UNFOLD_START_MS, UNFOLD_LEN_MS = 300, 1010, 850, 750
FALL_START_MS, CLOSE_MS, FOLD_LEN_MS = 200, 640, 200


def _ease(t: float, kind: str) -> float:
    """The Flutter curves the choreography uses: `out` = `Curves.easeOut` = Cubic(0, 0, 0.58, 1),
    evaluated on its bezier (the app's own curve, not easeOutCubic), `io` easeInOutCubic, `in` easeInCubic."""
    t = min(1.0, max(0.0, t))
    if kind == "out":
        return bezier_ease(0.0, 0.0, 0.58, 1.0, t)
    if kind == "in":
        return t ** 3
    return 4 * t ** 3 if t < 0.5 else 1 - 4 * (1 - t) ** 3


def _swing(t: float) -> float:
    """`_SwingCurve`: the crack (0 -> 0.03 over the first 15 %), then easeInOutCubic to 1."""
    if t <= 0:
        return 0.0
    if t >= 1:
        return 1.0
    if t <= 0.15:
        return 0.03 * t / 0.15
    return 0.03 + 0.97 * _ease((t - 0.15) / 0.85, "io")


def _fall(t: float) -> float:
    """`_FallCurve`: 1 - easeInCubic, landed at 380/440 of the span, then the 0.04 sine rebound."""
    land = 380 / 440
    if t >= 1:
        return 0.0
    if t <= 0:
        return 1.0
    if t <= land:
        return 1 - _ease(t / land, "in")
    return 0.04 * math.sin(math.pi * (t - land) / (1 - land))


def open_pose(ms: float) -> dict[str, float]:
    """The open beat's numbers at ms (`JourneyChoreography`, JourneyPhase.open): show eases out over
    the appear, the cover swings staged from its end, the riffle ramps from 850 ms."""
    return {"book": round(_ease(ms / APPEAR_MS, "out"), 4),
            "open": round(_swing((ms - APPEAR_MS) / (SWING_END_MS - APPEAR_MS)), 4),
            "unfold": round(_ease((ms - UNFOLD_START_MS) / UNFOLD_LEN_MS, "out"), 4),
            "destBeach": 1.0}


def close_pose(ms: float) -> dict[str, float]:
    """The close beat's numbers: the fold (unfold) eases out over the first 200 ms, the cover holds
    open until the fall starts, lands at 580 ms and rebounds to the beat's end."""
    return {"book": 1.0, "open": round(1.0 if ms <= FALL_START_MS else _fall((ms - FALL_START_MS) /
            (CLOSE_MS - FALL_START_MS)), 4),
            "unfold": round(1 - _ease(ms / FOLD_LEN_MS, "out"), 4),
            "destBeach": 1.0}


def beats(r: JourneyRenderer, out: Path) -> None:
    """`beat_open.png` / `beat_close.png`: one 1:1 crop of the threshold per sample (labelled in ms),
    the open beat at 50 ms with the contested 650-1060 ms stretch at 20 ms, the close at 25 ms."""
    for name, pose_of, samples in (("beat_open", open_pose, sorted({*range(0, 1651, 50), *range(650, 1061, 20)})),
                                   ("beat_close", close_pose, list(range(0, CLOSE_MS + 61, 25)))):
        cw, ch = BEAT_CROP[1] - BEAT_CROP[0], BEAT_CROP[3] - BEAT_CROP[2]
        cols, pad = 8, 6
        rows = math.ceil(len(samples) / cols)
        sheet = Image.new("RGB", (cols * (cw + pad) + pad, rows * (ch + 22) + pad), (10, 8, 14))
        draw = ImageDraw.Draw(sheet)
        for i, ms in enumerate(samples):
            j = r.render(pose_of(ms))
            cell = Image.fromarray(j.astype(np.uint8), "RGBA").crop(
                (BEAT_CROP[0], BEAT_CROP[2], BEAT_CROP[1], BEAT_CROP[3]))
            x = pad + (i % cols) * (cw + pad)
            y = pad + (i // cols) * (ch + 22)
            sheet.paste(cell, (x, y))
            draw.text((x + 2, y + ch + 4), f"{ms} ms", fill=(244, 184, 96))
        sheet.convert("RGB").save(out / f"{name}.png")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "rive" / "review" / "book-threshold"))
    ap.add_argument("--gates-only", action="store_true")
    ap.add_argument("--beat", action="store_true", help="also write the open and close beats' sheets")
    args = ap.parse_args()
    r = JourneyRenderer()
    try:
        lines = gates(r)
        print("\n".join(lines))
        if not args.gates_only:
            out = Path(args.out)
            out.mkdir(parents=True, exist_ok=True)
            strips(r, out)
            if args.beat:
                beats(r, out)
            (out / "gates.txt").write_text("\n".join(lines) + "\n")
    finally:
        r.close()
    return 1 if any(line.endswith("FAIL)") for line in lines) else 0


if __name__ == "__main__":
    sys.exit(main())
