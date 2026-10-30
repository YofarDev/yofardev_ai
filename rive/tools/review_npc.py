"""Evidence and gates for the scene NPCs and fog (moonshot M8 Task 4, contract v11): real CLI renders
of `rive/scenes/<sceneId>`, 1080x1920, `--fit=contain`.

    uv run --with pillow --with numpy rive/tools/review_npc.py [sceneId ...] [--same-as=<rev>]
        [--out=<dir>] [--gates-only]

Writes to rive/review/m8/ (or --out):
- `npc/<sceneId>/sheet.png`: the NPC cropped around where it is: rest, away, idle x 3 frames, move x 3
  frames at npcX 0 / 0.5 / 1, notice at npcLook -1 / 0 / +1, react x 3 frames;
- `npc/<sceneId>/crop2x.png`: rest, idle, notice, react at 2x;
- `npc/<sceneId>/path.png` (scenes with a path): the full frame at npcX 0 / 0.25 / 0.5 / 0.75 / 1 (move);
- `fog/<sceneId>.png`: fog 0 / 0.5 / 1, plus rain 1 + fog 1 with `SceneFront` composited (campfire,
  beach);
- `npc/<sceneId>/gates.txt`: rest frames (f0, f1, f30, f60) and the SceneFront at rain 1 identical to
  `--same-as` (default 927a606), away draws nothing of the NPC, every state moves and loops back,
  `prop_tapped` fires on the NPC wherever its path takes it (and not where it left), fog changes the
  fog veils only (deepSpace: nothing), budgets.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import scene_npc  # noqa: E402
from review_diorama import FrontRenderer, Renderer, grid, label, taps  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCENES = ("livingRoom", "campfire", "beach", "deepSpace")
SCENE_MAX = 409_600
NPC_MAX = 30 * 1024
SAME_AS = "927a606"
# crop (w, h) around the NPC and the offset of its centre above its anchor point
CROP = {"livingRoom": (260, 200, -48), "campfire": (220, 220, -10), "beach": (240, 200, -36),
        "deepSpace": (300, 240, -20)}
# frames after which a state's loop and every other loop inside its crop are back at frame 0
SEAM = {"livingRoom": {"idle": 360, "move": 30, "notice": 120, "react": 60},
        "campfire": {"idle": 1800, "move": 600, "notice": 600, "react": 300},
        "beach": {"idle": 240, "move": 240, "notice": 240, "react": 240},
        "deepSpace": {"idle": 720, "move": 720, "notice": 720, "react": 720}}
# the region fog may change (x0, y0, x1, y1): livingRoom only through the window
FOG_BOX = {"livingRoom": (346, 216, 734, 714)}


def anchor(scene: str, t: float) -> tuple[float, float]:
    """Where the NPC is on screen at npcX `t` (its paws / feet / the ufo's centre)."""
    if scene == "campfire":
        return scene_npc.OWL_AT
    if scene == "livingRoom":
        pts = [(x, y) for x, y, _ in scene_npc.CAT_WAYPOINTS]
    elif scene == "beach":
        pts = [(x, y) for x, y, _ in scene_npc.CRAB_WAYPOINTS]
    else:
        pts = scene_npc.ufo_waypoints()
    ts = scene_npc.arc_params(pts)
    return float(np.interp(t, ts, [p[0] for p in pts])), float(np.interp(t, ts, [p[1] for p in pts]))


def hit_at(scene: str, t: float, hit0: tuple[float, float]) -> tuple[float, float]:
    """The NPC's hit zone centre at npcX `t` (it follows the art, scaled with it)."""
    if scene == "livingRoom":
        w = scene_npc.CAT_WAYPOINTS
        s0 = scene_npc.TV_SCALE
    elif scene == "beach":
        w = scene_npc.CRAB_WAYPOINTS
        s0 = 1.0
    else:
        w = [(x, y, 1.0) for x, y in scene_npc.ufo_waypoints()]
        s0 = 1.0
    ts = scene_npc.arc_params([(x, y) for x, y, _ in w])
    x, y, s = (float(np.interp(t, ts, [p[i] for p in w])) for i in range(3))
    return x + (hit0[0] - w[0][0]) * s / s0, y + (hit0[1] - w[0][1]) * s / s0


def crop(img: np.ndarray, scene: str, t: float = 0.0, k: float = 1.0) -> Image.Image:
    cw, ch, dy = CROP[scene]
    x, y = anchor(scene, t)
    y += dy
    # kept inside the artboard (the crab's far end sits at its right edge)
    x0 = int(min(max(x - cw / 2, 0), 1080 - cw))
    y0 = int(min(max(y - ch / 2, 0), 1920 - ch))
    im = Image.fromarray(img).convert("RGB").crop((x0, y0, x0 + cw, y0 + ch))
    return im.resize((int(cw * k), int(ch * k))) if k != 1 else im


def box_of(scene: str, t: float = 0.0, pad: int = 0) -> tuple[int, int, int, int]:
    cw, ch, dy = CROP[scene]
    x, y = anchor(scene, t)
    y += dy
    return (max(0, int(x - cw / 2) - pad), max(0, int(y - ch / 2) - pad), min(1080, int(x + cw / 2) + pad),
            min(1920, int(y + ch / 2) + pad))


def diff_frac(a: np.ndarray, b: np.ndarray, thr: int = 0) -> float:
    return float((np.abs(a.astype(int) - b.astype(int))[..., :3].max(-1) > thr).mean())


def old_project(scene: str, rev: str, tmp: Path) -> Path:
    d = tmp / "old" / scene
    d.mkdir(parents=True)
    text = subprocess.run(["git", "show", f"{rev}:rive/scenes/{scene}/{scene}.rml"], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout
    (d / f"{scene}.rml").write_text(text)
    (d / "rive.yaml").write_text((ROOT / "rive" / "scenes" / scene / "rive.yaml").read_text())
    return d


NPC_PROP = {"livingRoom": "cat", "beach": "crab", "deepSpace": "ufo", "campfire": "owl"}


def hit_zones(scene: str) -> dict[str, tuple[float, float, float, float]]:
    """propId -> (cx, cy, w, h) of every hit zone at rest (parallax 0)."""
    root = ET.fromstring((ROOT / "rive" / "scenes" / scene / f"{scene}.rml").read_text())
    out = {}
    for e in root.find("Artboard").iter("Shape"):
        if e.get("name", "").startswith("Hit_"):
            r = e.find("Rectangle")
            out[e.get("name")[4:]] = (float(e.get("x")), float(e.get("y")), float(r.get("width")),
                                      float(r.get("height")))
    return out


def alone(zone: tuple[float, float, float, float], others: list[tuple[float, float, float, float]]
          ) -> tuple[float, float] | None:
    """A point inside `zone` and outside every other zone (centre first, then a grid)."""
    cx, cy, w, h = zone
    for fy in (0.0, 0.3, -0.3, 0.42, -0.42):
        for fx in (0.0, 0.3, -0.3, 0.42, -0.42):
            x, y = cx + fx * w, cy + fy * h
            if not any(abs(x - ox) < ow / 2 and abs(y - oy) < oh / 2 for ox, oy, ow, oh in others):
                return x, y
    return None


def run(scene: str, out: Path, same_as: str) -> list[str]:
    proj = ROOT / "rive" / "scenes" / scene
    npc_dir, fog_dir = out / "npc" / scene, out / "fog"
    npc_dir.mkdir(parents=True, exist_ok=True)
    fog_dir.mkdir(parents=True, exist_ok=True)
    gates: list[str] = []
    rml = (proj / f"{scene}.rml").read_text()
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        render = Renderer(proj, t)
        # ---- rest at the defaults: identical to the M7 file
        old = old_project(scene, same_as, t)
        worst = max(diff_frac(render(f"--advance={f}"), render(f"--advance={f}", proj=old)) for f in (1, 2, 31, 61))
        gates.append(f"rest frames (f0, f1, f30, f60) at the defaults identical to {same_as}: {worst:.4%} differ "
                     f"({'ok' if worst == 0 else 'FAIL'})")
        if 'name="SceneFront"' in rml:
            fw = max(diff_frac(render("--artboard=SceneFront", "--data=rain=1", f"--advance={f}"),
                               render("--artboard=SceneFront", "--data=rain=1", f"--advance={f}", proj=old))
                     for f in (1, 2, 61))
            gates.append(f"SceneFront at rain 1 / fog 0 (f0, f1, f60) identical to {same_as}: {fw:.4%} differ "
                         f"({'ok' if fw == 0 else 'FAIL'})")

        # ---- the state sheet
        rest = render("--advance=31")
        away = render("--data=npc=away", "--advance=31")
        cells = [label(crop(rest, scene), "rest"), label(crop(away, scene), "away")]
        x0, y0, x1, y1 = box_of(scene, 0.0, pad=30)
        outside = np.ones(rest.shape[:2], bool)
        outside[y0:y1, x0:x1] = False
        inside = diff_frac(rest[y0:y1, x0:x1], away[y0:y1, x0:x1])
        leak = float((np.abs(rest.astype(int) - away.astype(int))[..., :3].max(-1)[outside] > 0).mean())
        gates.append(f"away: the NPC's crop changes ({inside:.2%} of it), nothing else does ({leak:.4%}): "
                     f"{'ok' if inside > 0.003 and leak == 0 else 'FAIL'}")
        two_x = [label(crop(rest, scene, k=2), "rest")]
        for st, frames in (("idle", (31, 151, 271)), ("react", (7, 15, 25))):
            shots = [render(f"--data=npc={st}", f"--advance={f}") for f in frames]
            cells += [label(crop(a, scene), f"{st} f{f - 1}") for a, f in zip(shots, frames)]
            two_x.append(label(crop(shots[1], scene, k=2), f"{st} f{frames[1] - 1}"))
        for tx in (0.0, 0.5, 1.0):
            a = render("--data=npc=move", f"--data=npcX={tx}", "--advance=16")
            cells.append(label(crop(a, scene, tx), f"move npcX {tx}"))
        for look in (-1, 0, 1):
            a = render("--data=npc=notice", f"--data=npcLook={look}", "--advance=31")
            cells.append(label(crop(a, scene), f"notice look {look:+d}"))
            if look == -1:
                two_x.append(label(crop(a, scene, k=2), "notice look -1"))
        grid(cells, 4).save(npc_dir / "sheet.png")
        grid(two_x, 4).save(npc_dir / "crop2x.png")

        # ---- every state moves, and loops back
        for st, n in SEAM[scene].items():
            # at its v10 spot (along the path the crop would pick up the scene's own longer loops)
            bx = box_of(scene, 0.0)
            sl = (slice(bx[1], bx[3]), slice(bx[0], bx[2]))
            args = [f"--data=npc={st}"]
            # from frame 31: the 200 ms blend into the state is over
            a = render(*args, "--advance=31")[sl]
            moved = max(diff_frac(a, render(*args, f"--advance={f}")[sl], 2) for f in (38, 46, 54))
            seam = diff_frac(a, render(*args, f"--advance={n + 31}")[sl], 8)
            gates.append(f"{st}: moves ({moved:.2%} of the crop) and its loop is back after {n} frames "
                         f"({seam:.4%} differ): {'ok' if moved > 0.005 and seam <= 0.001 else 'FAIL'}")
        # rest at the far end of its path (asleep on the rug, the crab still, the ufo moved)
        if scene in scene_npc.NPC_PATHS:
            cells = []
            for tx in (0.0, 0.25, 0.5, 0.75, 1.0):
                a = render("--data=npc=move", f"--data=npcX={tx}", "--advance=16")
                im = Image.fromarray(a).convert("RGB")
                x, y = anchor(scene, tx)
                ImageDraw.Draw(im).ellipse((x - 10, y - 10, x + 10, y + 10), outline=(255, 255, 0), width=3)
                cells.append(label(im.resize((360, 640)), f"move npcX {tx}"))
            a = render("--data=npcX=1", "--advance=31")
            cells.append(label(Image.fromarray(a).convert("RGB").resize((360, 640)), "rest at npcX 1"))
            grid(cells, 6).save(npc_dir / "path.png")
            # ---- pointer: the poke follows the NPC
            zones = hit_zones(scene)
            prop = NPC_PROP[scene]
            cx0, cy0, w0, h0 = zones.pop(prop)
            s0 = scene_npc.TV_SCALE if scene == "livingRoom" else 1.0
            ws = {"livingRoom": scene_npc.CAT_WAYPOINTS, "beach": scene_npc.CRAB_WAYPOINTS}
            for tx in (0.0, 0.5, 1.0):
                hx, hy = hit_at(scene, tx, (cx0, cy0))
                w = ws.get(scene)
                k = float(np.interp(tx, scene_npc.arc_params([(x, y) for x, y, _ in w]), [p[2] for p in w])) / s0 \
                    if w else 1.0
                p = alone((hx, hy, w0 * k, h0 * k), list(zones.values()))
                if p is None:
                    gates.append(f"pointer {prop} at npcX {tx}: no point inside it alone: FAIL")
                    continue
                n = taps(proj, f"--data=npcX={tx}", f"--pointer=click@{p[0]:.0f},{p[1]:.0f}", "--advance=3")
                line = f"pointer {prop} at npcX {tx}: click@{p[0]:.0f},{p[1]:.0f} fires {n}"
                ok = n == 1
                if tx == 1.0:
                    q = alone((cx0, cy0, w0, h0), list(zones.values()))
                    m = taps(proj, f"--data=npcX={tx}", f"--pointer=click@{q[0]:.0f},{q[1]:.0f}", "--advance=3")
                    line += f", its v10 spot click@{q[0]:.0f},{q[1]:.0f} fires {m}"
                    ok &= m == 0
                gates.append(f"{line}: {'ok' if ok else 'FAIL'}")
        else:
            hx, hy, _, _ = hit_zones(scene)["owl"]
            n = taps(proj, "--data=npc=react", f"--pointer=click@{hx:.0f},{hy:.0f}", "--advance=3")
            gates.append(f"pointer owl (no path) while reacting: click@{hx:.0f},{hy:.0f} fires {n}: "
                         f"{'ok' if n == 1 else 'FAIL'}")

        # ---- fog
        shots = {f: render(f"--data=fog={f}", "--advance=31") for f in (0, 0.5, 1)}
        cells = [label(Image.fromarray(shots[f]).convert("RGB").resize((360, 640)), f"fog {f}") for f in (0, 0.5, 1)]
        # (> 2/255: the artboard's outermost column shows the sky plane's veils at 1/255)
        changed = np.abs(shots[1].astype(int) - shots[0].astype(int))[..., :3].max(-1) > 2
        if scene == "deepSpace":
            gates.append(f"fog: deepSpace ignores it, fog 1 vs 0: {changed.mean():.4%} differ "
                         f"({'ok' if not changed.any() else 'FAIL'})")
        else:
            box = FOG_BOX.get(scene)
            if box is not None:
                out_box = changed.copy()
                out_box[box[1]:box[3], box[0]:box[2]] = False
                leak = float(out_box.mean())
                gates.append(f"fog: changes {changed.mean():.2%} of the frame, {leak:.4%} outside the window "
                             f"({'ok' if changed.mean() > 0.02 and leak == 0 else 'FAIL'})")
            else:
                gates.append(f"fog: changes {changed.mean():.2%} of the frame ({'ok' if changed.mean() > 0.02 else 'FAIL'})")
        if 'name="SceneFront"' in rml:
            front = FrontRenderer(proj, t)
            back = Image.fromarray(render("--data=rain=1", "--data=fog=1", "--advance=31")).convert("RGBA")
            lay = Image.fromarray(front("--data=rain=1", "--data=fog=1", "--advance=31"), "RGBA")
            cells.append(label(Image.alpha_composite(back, lay).convert("RGB").resize((360, 640)),
                               "rain 1 + fog 1, SceneFront over"))
            f0 = front("--data=rain=1", "--advance=31")[..., 3].astype(int)
            f1 = front("--data=rain=1", "--data=fog=1", "--advance=31")[..., 3].astype(int)
            gain = float((f1[-200:] - f0[-200:]).mean())
            gates.append(f"SceneFront fog joins the mist: bottom 200 rows alpha +{gain:.1f}/255 at fog 1 "
                         f"({'ok' if gain > 10 else 'FAIL'})")
        grid(cells, len(cells)).save(fog_dir / f"{scene}.png")

    riv = ROOT / "assets" / "rive" / "scenes" / f"{scene}.riv"
    size = riv.stat().st_size
    old_size = int(subprocess.run(["git", "cat-file", "-s", f"{same_as}:assets/rive/scenes/{scene}.riv"], cwd=ROOT,
                                  check=True, capture_output=True, text=True).stdout)
    gates.append(f"{scene}.riv {size:,} B ({size - old_size:+,} B vs {same_as}; budget {SCENE_MAX:,}, NPC + fog "
                 f"<= {NPC_MAX + 1024:,}): {'ok' if size <= SCENE_MAX and size - old_size <= NPC_MAX + 1024 else 'FAIL'}")
    poster = f"assets/rive/posters/{scene}.webp"
    same = subprocess.run(["git", "diff", "--quiet", same_as, "--", poster], cwd=ROOT).returncode == 0
    gates.append(f"{poster} unchanged since {same_as}: {'ok' if same else 'FAIL'}")
    (npc_dir / "gates.txt").write_text("\n".join(gates) + "\n")
    return gates


def main(argv: list[str]) -> int:
    opts = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in argv if a.startswith("--") and "=" in a}
    scenes = [a for a in argv if not a.startswith("--")] or list(SCENES)
    same_as = opts.get("--same-as", SAME_AS)
    failed = False
    for scene in scenes:
        if "--gates-only" in argv:
            with tempfile.TemporaryDirectory() as scratch:
                gates = run(scene, Path(scratch), same_as)
        else:
            gates = run(scene, Path(opts.get("--out", ROOT / "rive" / "review" / "m8")), same_as)
        print("\n".join(f"{scene}: {g}" for g in gates))
        failed |= any("FAIL" in g for g in gates)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
