"""M9 lane E evidence: the v12 art of the four M8 scenes (drags, gulls, moon, December).

    uv run --with pillow --with numpy rive/review/m9/make_lane_e.py [identity|drags|gulls|moon|festive ...]

Renders the built projects in rive/scenes/<id> (build them first: `rive rive/scenes/<id> --once`)
headless at 1080x1920 and writes contact sheets to rive/review/m9/{drags,gulls,moon,festive}/. The
drag proofs print, per drag value, the bounding box of the pixels that differ from the rest frame:
it must lie inside the handle's art box (`ART_BOX`). `identity` is the M8 render gate (f0 / f1 / f30 /
f60, and SceneFront at rain 1) against `--same-as` (default HEAD), outside the rest affordances
`gen_scenes.V12_REST_AFFORDANCE` (M9 fix round 1: the cord and the poke stick draw at rest).
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "rive" / "tools"))
from gen_scenes import V12_REST_AFFORDANCE, rest_masked  # noqa: E402
OUT = Path(__file__).resolve().parent
# the region each drag's art may touch (artboard px, parallax 0): the handle's reach plus its art
ART_BOX = {"livingRoom": (290, 750, 350, 945), "campfire": (0, 1010, 350, 1600),
           "beach": (800, 1200, 1010, 1730), "deepSpace": (145, 435, 455, 745)}


def render(scene: str, *args: str, proj: Path | None = None) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "s.png"
        r = subprocess.run(["rive", str(proj or ROOT / "rive/scenes" / scene), f"--screenshot={png}", *args],
                           capture_output=True, text=True)
        if r.returncode != 0 or not png.exists():
            raise RuntimeError(f"{scene} {args}: {r.stderr[-400:]}")
        return np.array(Image.open(png).convert("RGB"))


def many(jobs: list[tuple[str, tuple[str, ...]]]) -> list[np.ndarray]:
    with ThreadPoolExecutor(6) as ex:
        return list(ex.map(lambda j: render(j[0], *j[1]), jobs))


def cell(img: np.ndarray, box: tuple[int, int, int, int], label: str, w: int) -> Image.Image:
    im = Image.fromarray(img).crop(box)
    im = im.resize((w, round(w * im.height / im.width)), Image.LANCZOS)
    out = Image.new("RGB", (im.width, im.height + 22), (20, 20, 24))
    out.paste(im, (0, 22))
    ImageDraw.Draw(out).text((4, 4), label, fill=(235, 235, 235))
    return out


def sheet(cells: list[Image.Image], cols: int, path: Path) -> None:
    w, h = max(c.width for c in cells), max(c.height for c in cells)
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols - 1) * 4, rows * h + (rows - 1) * 4), (60, 60, 64))
    for i, c in enumerate(cells):
        out.paste(c, ((i % cols) * (w + 4), (i // cols) * (h + 4)))
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    print("wrote", path.relative_to(ROOT))


def diff_box(a: np.ndarray, b: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.nonzero(np.abs(a.astype(int) - b.astype(int)).max(axis=2) > 0)
    return None if len(xs) == 0 else (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def inside(box: tuple[int, int, int, int] | None, outer: tuple[int, int, int, int]) -> bool:
    return box is None or (box[0] >= outer[0] and box[1] >= outer[1] and box[2] <= outer[2] and box[3] <= outer[3])


def trail_points(n: int = 16) -> list[tuple[float, float]]:
    """A finger's S-curve down the sand patch right of the avatar (gen_scenes.TRAIL_PATCH), dots about
    28 px apart (>= 22, ruling 8)."""
    import math
    return [(905.0 + 45.0 * math.sin(i / 2.0), 1262.0 + 27.0 * i) for i in range(n)]


def identity(same_as: str = "HEAD") -> list[str]:
    gates = []
    with tempfile.TemporaryDirectory() as tmp:
        for scene in ("livingRoom", "campfire", "beach", "deepSpace"):
            old = Path(tmp) / scene
            old.mkdir()
            text = subprocess.run(["git", "show", f"{same_as}:rive/scenes/{scene}/{scene}.rml"], cwd=ROOT,
                                  capture_output=True, text=True, check=True).stdout
            (old / f"{scene}.rml").write_text(text)
            (old / "rive.yaml").write_text((ROOT / "rive/scenes" / scene / "rive.yaml").read_text())
            runs = [(f"f{f}", (f"--advance={f}",)) for f in (0, 1, 30, 60)]
            if scene in ("campfire", "beach"):
                runs += [(f"front f{f}", ("--artboard=SceneFront", "--data=rain=1", f"--advance={f}")) for f in (0, 60)]
            with ThreadPoolExecutor(6) as ex:
                new = list(ex.map(lambda r: render(scene, *r[1]), runs))
                ref = list(ex.map(lambda r: render(scene, *r[1], proj=old), runs))
            boxes = V12_REST_AFFORDANCE.get(scene, ())
            for (lab, _), a, b in zip(runs, new, ref):
                out = float((np.abs(rest_masked(scene, a, b).astype(int) - b.astype(int)).max(-1) > 0).mean())
                inner = diff_box(a, b)
                ok = out == 0 and all(inside(inner, bx) for bx in boxes[:1]) if inner else out == 0
                gates.append(f"{'ok' if ok else 'FAIL'} {scene} {lab} vs {same_as}: outside {list(boxes) or 'nothing'} "
                             f"{out:.4%} differ; diff box {inner}")
    return gates


def drags() -> list[str]:
    gates = []
    f = "--advance=1"
    # ---- livingRoom cord
    vals = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
    imgs = many([("livingRoom", (f"--data=cord={v}", f)) for v in vals])
    sheet([cell(im, (200, 640, 440, 980), f"cord {v}", 240) for v, im in zip(vals, imgs)], 6,
          OUT / "drags/livingRoom_cord.png")
    for v, im in zip(vals[1:], imgs[1:]):
        b = diff_box(im, imgs[0])
        gates.append(f"{'ok' if inside(b, ART_BOX['livingRoom']) else 'FAIL'} livingRoom cord={v}: diff box {b}")
    # ---- campfire poke
    cases = [(0.0, 0, 0), (0.3, 0, 0), (0.6, 0, 0), (1.0, 0, 0), (1.0, -1, -1), (1.0, 1, -1), (1.0, -1, 1), (1.0, 1, 1)]
    imgs = many([("campfire", (f"--data=poke={p}", f"--data=pokeX={x}", f"--data=pokeY={y}", f)) for p, x, y in cases])
    sheet([cell(im, (0, 900, 760, 1600), f"poke {p} x {x} y {y}", 330) for (p, x, y), im in zip(cases, imgs)], 4,
          OUT / "drags/campfire_poke.png")
    for c, im in zip(cases[1:], imgs[1:]):
        b = diff_box(im, imgs[0])
        gates.append(f"{'ok' if inside(b, ART_BOX['campfire']) else 'FAIL'} campfire poke/x/y={c}: diff box {b}")
    # ---- beach trail
    pts = trail_points()
    args = [f"--data=trailX{i}={x}" for i, (x, _) in enumerate(pts)] + \
           [f"--data=trailY{i}={y}" for i, (_, y) in enumerate(pts)]
    cases = [("trailN 0 fade 1", ("--data=trailN=0", "--data=trailFade=1")),
             ("trailN 5 fade 0", ("--data=trailN=5", "--data=trailFade=0")),
             ("trailN 16 fade 0", ("--data=trailN=16", "--data=trailFade=0")),
             ("trailN 16 fade 0.5", ("--data=trailN=16", "--data=trailFade=0.5"))]
    imgs = many([("beach", (*args, *a, f)) for _, a in cases])
    # left: the patch at 1:1; right of each pair: the same frame at a phone's scale (~0.55)
    sheet([cell(im, (700, 1150, 1080, 1760), lab, 380) for (lab, _), im in zip(cases, imgs)]
          + [cell(im, (0, 900, 1080, 1800), lab + " (phone scale 0.5)", 540) for (lab, _), im in zip(cases[2:3], imgs[2:3])],
          5, OUT / "drags/beach_sand.png")
    rest = render("beach", f)
    for (lab, _), im in zip(cases, imgs):
        b = diff_box(im, rest)
        gates.append(f"{'ok' if inside(b, ART_BOX['beach']) else 'FAIL'} beach {lab}: diff box {b}")
    # ---- deepSpace spin
    vals = [0.0, 0.125, 0.25, 0.5, 0.75, 0.99, 1.0]
    imgs = many([("deepSpace", (f"--data=spin={v}", f)) for v in vals])
    sheet([cell(im, (130, 420, 470, 760), f"spin {v}", 240) for v, im in zip(vals, imgs)], 7,
          OUT / "drags/deepSpace_spin.png")
    for v, im in zip(vals[1:], imgs[1:]):
        b = diff_box(im, imgs[0])
        ok = inside(b, ART_BOX["deepSpace"]) and (v != 1.0 or b is None)
        gates.append(f"{'ok' if ok else 'FAIL'} deepSpace spin={v}: diff box {b}")
    return gates


def gulls() -> list[str]:
    box = (760, 1340, 1080, 1600)
    cases = [("away (default)", ("--advance=40",)),
             ("rest", ("--data=npc2=rest", "--advance=40")),
             ("idle f40", ("--data=npc2=idle", "--advance=40")),
             ("idle f70 (peck)", ("--data=npc2=idle", "--advance=70")),
             ("idle f130", ("--data=npc2=idle", "--advance=130")),
             ("notice look -1", ("--data=npc2=notice", "--data=npc2Look=-1", "--advance=40")),
             ("notice look 0", ("--data=npc2=notice", "--advance=40")),
             ("notice look +1", ("--data=npc2=notice", "--data=npc2Look=1", "--advance=40")),
             ("react f20", ("--data=npc2=react", "--advance=20")),
             ("react f28", ("--data=npc2=react", "--advance=28")),
             ("move x0 look+1 f20", ("--data=npc2=move", "--data=npc2Look=1", "--advance=20")),
             ("move x0 look+1 f26", ("--data=npc2=move", "--data=npc2Look=1", "--advance=26")),
             ("move x0 look-1 f20", ("--data=npc2=move", "--data=npc2Look=-1", "--advance=20"))]
    imgs = many([("beach", a) for _, a in cases])
    sheet([cell(im, box, lab, 320) for (lab, _), im in zip(cases, imgs)], 5, OUT / "gulls/states.png")
    # the flight path, npc2X 0 -> 1 (full frame, right half)
    xs = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
    path_imgs = many([("beach", ("--data=npc2=move", "--data=npc2Look=1", f"--data=npc2X={x}", "--advance=20"))
                      for x in xs])
    sheet([cell(im, (540, 1000, 1080, 1620), f"move npc2X {x}", 270) for x, im in zip(xs, path_imgs)], 6,
          OUT / "gulls/path.png")
    gates = []
    rest = render("beach", "--advance=40")
    b = diff_box(imgs[0], rest)
    rest = render("beach", "--advance=20")
    gates.append(f"{'ok' if b is None else 'FAIL'} gulls away = no pixel: {b}")
    off = path_imgs[-1]
    b = diff_box(off, rest)
    gates.append(f"{'ok' if b is None else 'FAIL'} gulls at npc2X 1 off the frame: diff box {b}")
    # seamless loops: frame f and f + loop identical (from inside the state, past the blend)
    for state, n in (("rest", 240), ("idle", 180), ("move", 24), ("notice", 120), ("react", 36)):
        # the crab away: its own loops (240 f) share the crop
        a, c = many([("beach", ("--data=npc=away", f"--data=npc2={state}", f"--advance={k}")) for k in (40, 40 + n)])
        b = diff_box(a, c)
        crop = a[1340:1600, 760:1080].astype(int) - c[1340:1600, 760:1080].astype(int)
        frac = float((np.abs(crop).max(axis=2) > 0).mean())
        gates.append(f"{'ok' if frac < 0.002 else 'FAIL'} gulls {state} loop {n}f seam: {frac:.4%} of the crop differs")
    return gates


def moon() -> list[str]:
    phases = [-1.0, 0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 0.99]
    gates = []
    for scene, (cx, cy, r) in (("livingRoom", (640, 320, 30)), ("campfire", (800, 690, 60))):
        imgs = many([(scene, (f"--data=moonPhase={p}", "--advance=1")) for p in phases])
        k = int(r * 2.2)
        sheet([cell(im, (cx - k, cy - k, cx + k, cy + k), f"p {p}", 160) for p, im in zip(phases, imgs)], 10,
              OUT / f"moon/{scene}.png")
        for p, im in zip(phases[1:], imgs[1:]):
            b = diff_box(im, imgs[0])
            ok = inside(b, (cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2))
            gates.append(f"{'ok' if ok else 'FAIL'} {scene} moonPhase={p}: diff box {b}")
    return gates


def festive() -> list[str]:
    cases = [("festive 0", ("--advance=1",)), ("festive 1 f1", ("--data=festive=1", "--advance=1")),
             ("festive 1 f120", ("--data=festive=1", "--advance=120")),
             ("festive 1 f241", ("--data=festive=1", "--advance=241")),
             ("festive 0.5", ("--data=festive=0.5", "--advance=1")),
             ("festive 1, lightsOff", ("--data=festive=1", "--data=eventId=lightsOff", "--data=event=1",
                                       "--advance=60"))]
    imgs = many([("livingRoom", a) for _, a in cases])
    sheet([cell(im, (240, 150, 840, 520), lab, 360) for (lab, _), im in zip(cases, imgs)], 3,
          OUT / "festive/livingRoom.png")
    b = diff_box(imgs[1], imgs[0])
    gates = [f"{'ok' if inside(b, (240, 150, 840, 320)) else 'FAIL'} festive 1 diff box {b}"]
    # (the twinkle's seam is proven on the kit alone, rive/review/m9/world_kit: the room's own loops
    # of 300 / 420 / 540 / 600 frames share every crop here)
    return gates


def main(argv: list[str]) -> int:
    which = argv or ["identity", "drags", "gulls", "moon", "festive"]
    gates: list[str] = []
    for w in which:
        gates += {"identity": identity, "drags": drags, "gulls": gulls, "moon": moon, "festive": festive}[w]()
    print("\n".join(gates))
    return 1 if any(g.startswith("FAIL") for g in gates) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
