"""Capture avatar gestures, facial phases and presence with the real Rive renderer.

uv run --with pillow python rive/tools/motion_review.py --label after
uv run --with pillow python rive/tools/motion_review.py --ik-check   # runtime IK vs the Python solver
uv run --with pillow python rive/tools/motion_review.py --tablet     # the tablet prop (M4) -> rive/review/m4/tablet
uv run --with pillow python rive/tools/motion_review.py --newspaper  # the newspaper prop (M5) -> rive/review/m5/newspaper
Use --project to review a saved source snapshot; output stays under build/.
"""

from __future__ import annotations

import argparse
import copy
from concurrent.futures import ThreadPoolExecutor
from html import escape
import json
import math
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops

import ik_check
from review import ROOT, make_project, run, sheet

IK_GESTURES = ("wave", "laugh", "facepalm", "shrug", "clap", "think")
IK_TOLERANCE = 2.0  # px: rendered hand vs the Python two-bone solver, per sampled frame


def ik_report(project_src: Path, out: Path, step: int = 4) -> bool:
    """Render the marker copies and compare every sampled frame; writes ik_check.json / .txt."""
    board = ET.parse(project_src / "avatar.rml").getroot().find("Artboard")
    arms = ik_check.arms(board)
    projects = {}
    for which in ik_check.PASSES:
        projects[which] = out / f"ik_{which}"
        ik_check.marker_copy(project_src / "avatar.rml", projects[which], which)
    durations = {a.get("name"): int(a.get("duration")) for a in board.findall("LinearAnimation")}
    jobs = []
    for g in IK_GESTURES:
        for f in range(0, durations["gesture_" + g] + 1, step):
            for which in projects:
                jobs.append((g, f, which))

    def capture(job: tuple[str, int, str]) -> None:
        g, f, which = job
        run(projects[which], out / "ik" / which / g / f"{f:04d}.png", f"--data=gestureId={g}", "--data=gesture=true",
            f"--advance={f + 1}")

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(capture, jobs))
    result: dict = {}
    lines = []
    worst_all = 0.0
    for g in IK_GESTURES:
        ch = ik_check.channels(board, "gesture_" + g)
        frames = range(0, durations["gesture_" + g] + 1, step)
        seen = {}
        for f in frames:
            img = {w: Image.open(out / "ik" / w / g / f"{f:04d}.png") for w in projects}
            seen[f] = {arm.side: {**ik_check.find(img["frame"], {k: ik_check.COLOURS[arm.side][k] for k in "OXY"}),
                                  **ik_check.find(img["joints"], {k: ik_check.COLOURS[arm.side][k] for k in "EW"})}
                       for arm in arms}
        # the capture of --advance=N can sit a frame off the animation clock: pick the best offset
        best = None
        for offset in (-1, 0, 1):
            errs = []
            for f in frames:
                for arm in arms:
                    m = seen[f][arm.side]
                    if not all(k in m for k in "OXYEW"):
                        continue
                    elbow, wrist = ik_check.expected(arm, ch, max(0, f + offset))
                    pe, pw = ik_check.to_image(m, elbow), ik_check.to_image(m, wrist)
                    errs.append((f, arm.side, math.dist(pw, m["W"]), math.dist(pe, m["E"])))
            score = max(e[2] for e in errs)
            if best is None or score < best[0]:
                best = (score, offset, errs)
        score, offset, errs = best
        worst_e = max(e[3] for e in errs)
        worst_all = max(worst_all, score)
        result[g] = {"offset": offset, "hand_max_px": round(score, 2), "elbow_max_px": round(worst_e, 2),
                     "hand_mean_px": round(sum(e[2] for e in errs) / len(errs), 2), "samples": len(errs),
                     "frames": [[f, s_, round(h, 2), round(e, 2)] for f, s_, h, e in errs]}
        lines.append(f"{g:10s} offset {offset:+d}  hand max {score:5.2f} px  mean {result[g]['hand_mean_px']:4.2f}"
                     f"  elbow max {worst_e:5.2f} px  ({len(errs)} arm-frames)")
    ok = worst_all <= IK_TOLERANCE
    lines.append(f"{'PASS' if ok else 'FAIL'}: worst hand error {worst_all:.2f} px (tolerance {IK_TOLERANCE} px)")
    (out / "ik_check.json").write_text(json.dumps(result, indent=1))
    (out / "ik_check.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return ok


# ------------------------------------------------------------------ the tablet prop (M4 Task 5)

TABLET_OUT = ROOT / "rive/review/m4/tablet"
PROP_OUT = {"tablet": TABLET_OUT, "newspaper": ROOT / "rive/review/m5/newspaper"}
READING = ["--data=autoBlink=false", "--data=yaw=0.6", "--data=pitch=-0.5"]  # the director's reading gaze
TABLET_BOX = (100, 160, 700, 1000)  # head to the bottom edge: the face glow, both arms and the slab
HOLD_AT = 40  # hold-loop frame at which the put-away clips are started
STEP = ["--pointer=move@400,420"]  # lets the next --data step mid-run (costs the CLI one frame)


def prop_args(clip: str, f: int, n_out: int, kind: str = "tablet") -> list[str]:
    """CLI args that show frame `f` of `clip` (prop clips are reached through the Prop layer)."""
    if clip == "out":
        return [f"--data=prop={kind}", f"--advance={f + 1}"]
    if clip == "hold":
        return [f"--data=prop={kind}", f"--advance={n_out + 1 + f}"]
    return [f"--data=prop={kind}", f"--advance={n_out + HOLD_AT}", *STEP, "--data=prop=none", f"--advance={f + 1}"]


def tablet_ik(project: Path, out: Path, board: ET.Element, n: dict[str, int],
              kind: str = "tablet") -> tuple[bool, list[str]]:
    """Rendered hands vs the Python solver on the prop clips' keys, outside the blend windows
    (none -> out 100 ms, hold -> away 120 ms: there the runtime mixes two clips' targets)."""
    arms = ik_check.arms(board)
    projects = {}
    for which in ik_check.PASSES:
        projects[which] = out / f"ik_{which}"
        ik_check.marker_copy(project / "avatar.rml", projects[which], which)
    checks = {"out": range(8, n["out"] + 1, 2), "hold": range(0, n["hold"], 6), "away": range(10, n["away"] + 1, 2)}
    jobs = [(c, f, w) for c, fs in checks.items() for f in fs for w in projects]

    def capture(job: tuple[str, int, str]) -> None:
        c, f, which = job
        run(projects[which], out / "ik" / which / c / f"{f:04d}.png", *prop_args(c, f, n["out"], kind))

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(capture, jobs))
    ok, lines = True, []
    for c, fs in checks.items():
        ch = ik_check.channels(board, f"prop_{kind}_{c}")
        seen = {}
        for f in fs:
            img = {w: Image.open(out / "ik" / w / c / f"{f:04d}.png") for w in projects}
            seen[f] = {arm.side: {**ik_check.find(img["frame"], {k: ik_check.COLOURS[arm.side][k] for k in "OXY"}),
                                  **ik_check.find(img["joints"], {k: ik_check.COLOURS[arm.side][k] for k in "EW"})}
                       for arm in arms}
        best = None
        for offset in (-2, -1, 0, 1, 2):
            errs = []
            for f in fs:
                for arm in arms:
                    m = seen[f][arm.side]
                    if not all(k in m for k in "OXYEW"):
                        continue
                    frame = (f + offset) % n["hold"] if c == "hold" else max(0, f + offset)
                    elbow, wrist = ik_check.expected(arm, ch, frame)
                    errs.append((math.dist(ik_check.to_image(m, wrist), m["W"]),
                                 math.dist(ik_check.to_image(m, elbow), m["E"])))
            if errs and (best is None or max(e[0] for e in errs) < best[0]):
                best = (max(e[0] for e in errs), offset, errs)
        worst, offset, errs = best
        ok = ok and worst <= IK_TOLERANCE
        lines.append(f"ik prop_{kind}_{c:5s} offset {offset:+d}  hand max {worst:5.2f} px  "
                     f"elbow max {max(e[1] for e in errs):5.2f} px  ({len(errs)} arm-frames)")
    lines.append(f"{'ok ' if ok else 'BAD'} ik: worst hand error within {IK_TOLERANCE} px" if ok else
                 f"BAD ik: a hand error above {IK_TOLERANCE} px")
    return ok, lines


def _crop(png: Path, scale: float = 0.5) -> Image.Image:
    im = Image.open(png).convert("RGB").crop(TABLET_BOX)
    return im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)


def _steps(frames: list[Image.Image]) -> list[float]:
    """Mean absolute frame-to-frame change (0..255) of a sequence."""
    out = []
    for a, b in zip(frames, frames[1:]):
        hist = ImageChops.difference(a, b).convert("L").histogram()
        out.append(sum(i * v for i, v in enumerate(hist)) / (a.width * a.height))
    return out


def tablet_review(project: Path, out: Path, kind: str = "tablet") -> bool:
    """Contact sheets (out / hold / away, 10 frames each, reading gaze), the out -> hold -> away
    GIF, the hold-loop seam, the Review Focus 1 interruptions (pop check), and the IK check, for
    the `kind` prop (tablet: M4; newspaper: M5, plus the hand-overs to and from the tablet)."""
    dest = PROP_OUT[kind]
    dest.mkdir(parents=True, exist_ok=True)
    board = ET.parse(project / "avatar.rml").getroot().find("Artboard")
    dur = {a.get("name"): int(a.get("duration")) for a in board.findall("LinearAnimation")}
    n = {c: dur[f"prop_{kind}_{c}"] for c in ("out", "hold", "away")}
    shots = out / kind
    jobs: dict[str, list[str]] = {}
    sheets = {c: [round(i * (n[c] - (1 if c == "hold" else 0)) / 9) for i in range(10)] for c in n}
    for c, fs in sheets.items():
        for f in fs:
            jobs[f"{c}_{f:03d}"] = [*READING, *prop_args(c, f, n["out"], kind)]
    # the GIF: every 2nd frame of out, hold and away (30 fps playback = real time)
    gif = [("out", f) for f in range(0, n["out"] + 1, 2)] + [("hold", f) for f in range(2, n["hold"], 2)]
    gif += [("away", f) for f in range(0, n["away"] + 1, 2)] + [("away", n["away"] + 6)] * 1
    for c, f in gif:
        jobs.setdefault(f"{c}_{f:03d}", [*READING, *prop_args(c, f, n["out"], kind)])
    # hold seam: the hold clip alone, played once (no wrap): its first frame vs its last key
    # (the scrolled list must equal the unscrolled one, the tilt must close)
    seam_src = copy.deepcopy(ET.parse(project / "avatar.rml").getroot())
    machine = seam_src.find("Artboard/StateMachine")
    machine[:] = []
    hold_anim = next(a for a in seam_src.iter("LinearAnimation") if a.get("name") == f"prop_{kind}_hold")
    hold_anim.attrib.pop("loopValue", None)
    layer = ET.SubElement(machine, "StateMachineLayer", {"name": "IsolatedHold", "id": "0:1999001"})
    ET.SubElement(layer, "AnyState", {"id": "0:1999002"})
    ET.SubElement(layer, "ExitState", {"id": "0:1999003"})
    entry = ET.SubElement(layer, "EntryState", {"id": "0:1999004"})
    ET.SubElement(entry, "StateTransition", {"stateToId": "0:1999006", "id": "0:1999005"})
    ET.SubElement(layer, "AnimationState", {"animationId": hold_anim.get("id"), "id": "0:1999006"})
    seam_project = out / "hold_seam"
    make_project(seam_project, seam_src, "Avatar")
    run(seam_project, shots / "seam_a.png", "--advance=1")
    run(seam_project, shots / "seam_b.png", f"--advance={n['hold'] + 2}")
    # Review Focus 1: a tool shorter than the pull-out, a tool again early / late in the put-away,
    # a gesture the director starts while the tablet goes away (it surfaces at the put-away's end)
    held = [*READING, f"--data=prop={kind}", f"--advance={n['out'] + HOLD_AT}", *STEP]
    away0 = [*held, "--data=prop=none"]
    cases = {
        "short_tool": ([*READING, f"--data=prop={kind}", "--advance=10", *STEP, "--data=prop=none"], 34),
        "back_early": ([*away0, "--advance=6", *STEP, f"--data=prop={kind}"], 40),
        "back_late": ([*away0, "--advance=17", *STEP, f"--data=prop={kind}"], 40),
        "gesture_under_away": ([*held, "--data=prop=none", "--data=gestureId=wave", "--data=gesture=true"],
                               n["away"] + 16),
    }
    if kind == "newspaper":  # Review Focus 4: the news tool, then a search tool back to back
        tab_out = dur["prop_tablet_out"]
        cases["news_none_tablet"] = ([*away0, "--advance=4", *STEP, "--data=prop=tablet"], n["away"] + tab_out + 20)
        cases["news_to_tablet_direct"] = ([*held, "--data=prop=tablet"], n["away"] + tab_out + 20)
        cases["tablet_to_news_direct"] = ([*READING, "--data=prop=tablet", f"--advance={tab_out + HOLD_AT}", *STEP,
                                           "--data=prop=newspaper"], dur["prop_tablet_away"] + n["out"] + 20)
    for name, (pre, frames) in cases.items():
        for k in range(frames):
            jobs[f"{name}_{k:03d}"] = [*pre, f"--advance={k + 1}"]
    plain = [("out", f) for f in range(n["out"] + 1)] + [("away", f) for f in range(n["away"] + 1)]
    # M5: a hand-over is measured against both props' own clips, a gesture against its own motion
    # (a pop is a step bigger than anything the parts make alone)
    other = "tablet" if kind == "newspaper" else None
    if other:
        n_o = {c: dur[f"prop_{other}_{c}"] for c in ("out", "away")}
        for c in ("out", "away"):
            for f in range(n_o[c] + 1):
                jobs[f"{other}_{c}_{f:03d}"] = [*READING, *prop_args(c, f, n_o["out"], other)]
        n_wave = dur["gesture_wave"] + 4
        # the same gesture under the other prop's put-away (the Prop layer is shared: a step both
        # props make is the layer's, not this prop's)
        o_held = [*READING, f"--data=prop={other}", f"--advance={dur[f'prop_{other}_out'] + HOLD_AT}", *STEP]
        for k in range(n["away"] + 16):
            jobs[f"{other}_gesture_{k:03d}"] = [*o_held, "--data=prop=none", "--data=gestureId=wave",
                                                "--data=gesture=true", f"--advance={k + 1}"]
        for k in range(n_wave):
            jobs[f"wave_{k:03d}"] = [*READING, "--data=gestureId=wave", "--data=gesture=true", f"--advance={k + 1}"]
    for c, f in plain:
        jobs.setdefault(f"{c}_{f:03d}", [*READING, *prop_args(c, f, n["out"], kind)])

    def capture(item: tuple[str, list[str]]) -> None:
        name, args = item
        run(project, shots / f"{name}.png", *args)

    with ThreadPoolExecutor(max_workers=6) as pool:
        for i, _ in enumerate(pool.map(capture, jobs.items()), 1):
            if i % 50 == 0 or i == len(jobs):
                print(f"Captured {i}/{len(jobs)} frames", flush=True)
    for c, fs in sheets.items():
        files = [shots / f"{c}_{f:03d}.png" for f in fs]
        sheet(files, [f"{c} f{f}" for f in fs], dest / f"{c}_sheet.png", width=300, columns=5)
    frames = [_crop(shots / f"{c}_{f:03d}.png", 0.4).quantize(96, dither=Image.Dither.NONE) for c, f in gif]
    frames[0].save(dest / "out_hold_away.gif", save_all=True, append_images=frames[1:], duration=33, loop=0,
                   optimize=True)
    lines = []
    seam = ImageChops.difference(Image.open(shots / "seam_a.png").convert("RGB"),
                                 Image.open(shots / "seam_b.png").convert("RGB")).convert("L")
    worst_px = max(i for i, v in enumerate(seam.histogram()) if v)
    lines.append(f"{'ok ' if worst_px <= 1 else 'BAD'} hold seam: the hold clip alone, first frame vs its last key (scrolled list, closed tilt), max channel delta "
                 f"{worst_px}/255")
    ok = worst_px <= 1
    # pop gate: no frame-to-frame change in an interruption bigger than the largest in the plain clips
    ref = max(max(_steps([_crop(shots / f"{c}_{f:03d}.png") for f in range(n[c] + 1)])) for c in ("out", "away"))
    lines.append(f"    plain clips: largest frame-to-frame change {ref:.2f} (mean abs, 0..255, half-size crop)")
    case_ref = {name: ref for name in cases}
    if other:
        o_ref = max(max(_steps([_crop(shots / f"{other}_{c}_{f:03d}.png") for f in range(n_o[c] + 1)]))
                    for c in ("out", "away"))
        w_ref = max(_steps([_crop(shots / f"wave_{k:03d}.png") for k in range(n_wave)]))
        g_ref = max(_steps([_crop(shots / f"{other}_gesture_{k:03d}.png") for k in range(n["away"] + 16)]))
        lines.append(f"    {other} plain clips: {o_ref:.2f}; the wave alone: {w_ref:.2f}; the wave under the "
                     f"{other}'s put-away: {g_ref:.2f}")
        for name in ("news_none_tablet", "news_to_tablet_direct", "tablet_to_news_direct"):
            case_ref[name] = max(ref, o_ref)
        case_ref["gesture_under_away"] = max(ref, w_ref, g_ref)
    strips = []
    for name, (_, frames_n) in cases.items():
        seq = [_crop(shots / f"{name}_{k:03d}.png") for k in range(frames_n)]
        steps = _steps(seq)
        worst = max(steps)
        good = worst <= case_ref[name] * 1.05
        ok = ok and good
        lines.append(f"{'ok ' if good else 'BAD'} {name}: largest step {worst:.2f} at frame {steps.index(worst) + 1}")
        pick = [round(i * (frames_n - 1) / 9) for i in range(10)]
        strips.append((name, [shots / f"{name}_{k:03d}.png" for k in pick], [f"{name} +{k}" for k in pick]))
    for name, files, labels in strips:
        sheet(files, labels, dest / f"interrupt_{name}.png", width=200, columns=10)
    ik_ok, ik_lines = tablet_ik(project, out, board, n, kind)
    lines += ik_lines
    ok = ok and ik_ok
    (dest / "gates.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return ok


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT / "rive/avatar")
    parser.add_argument("--label", default="after")
    parser.add_argument("--dense", action="store_true", help="Capture at 20 fps for playback")
    parser.add_argument("--tablet", action="store_true",
                        help="Tablet prop evidence (sheets, GIF, seam, interruptions, IK) -> rive/review/m4/tablet/")
    parser.add_argument("--newspaper", action="store_true",
                        help="Newspaper prop evidence (as --tablet, plus the tablet hand-overs) -> rive/review/m5/newspaper/")
    parser.add_argument("--ik-check", action="store_true",
                        help=f"Compare the rendered elbow and hand with the Python solver (hand within {IK_TOLERANCE} px)")
    args = parser.parse_args()
    out = ROOT / "build/avatar-motion-review" / args.label
    project = out / "source"
    project.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.project / "avatar.rml", project / "avatar.rml")
    (project / "rive.yaml").write_text("name: motion\nmain: Avatar\noutput: {dir: build}\n")
    if args.ik_check:
        raise SystemExit(0 if ik_report(project, out) else 1)
    if args.tablet:
        raise SystemExit(0 if tablet_review(project, out) else 1)
    if args.newspaper:
        raise SystemExit(0 if tablet_review(project, out, "newspaper") else 1)
    board = ET.parse(project / "avatar.rml").getroot().find("Artboard")
    durations = {a.get("name"): int(a.get("duration")) for a in board.findall("LinearAnimation")}
    cases = [(g, [f"--data=gestureId={g}", "--data=gesture=true"], durations["gesture_" + g] + 12)
             for g in ("wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think")]
    cases += [("waiting", ["--data=phase=waiting"], 360),
              ("speaking", ["--data=phase=speaking", "--data=mouth=2"], 420),
              ("presence", ["--data=presence=leaveAndComeBack"], 240),
              ("blink", [], 192)]
    frames = {label: list(range(1, duration + 2, 3)) if args.dense else
              [round(i * duration / 9) + 1 for i in range(10)] for label, _, duration in cases}

    def capture(job: tuple[str, list[str], int]) -> None:
        label, data, frame = job
        run(project, out / label / f"{frame:04d}.png", *data, f"--advance={frame}", "--scale=0.5")

    jobs = [(label, data, f) for label, data, _ in cases for f in frames[label]]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for i, _ in enumerate(pool.map(capture, jobs), 1):
            if i % 100 == 0 or i == len(jobs):
                print(f"Captured {i}/{len(jobs)} frames", flush=True)
    for label, _, _ in cases:
        files = [out / label / f"{f:04d}.png" for f in frames[label]]
        selected = [files[round(i * (len(files) - 1) / 9)] for i in range(10)]
        sheet(selected, [f"{label} f{int(p.stem) - 1}" for p in selected], out / f"{label}.png",
              width=200, columns=5)
        if args.dense:
            images = [Image.open(p).convert("RGB") for p in files]
            images[0].save(out / f"{label}.gif", save_all=True, append_images=images[1:], duration=50, loop=0)
    cards = [f'<article><h2>{escape(label)}</h2><img loading="lazy" '
             f'src="{label}.{"gif" if args.dense else "png"}" alt="{escape(label)}"></article>'
             for label, _, _ in cases]
    (out / "index.html").write_text('''<!doctype html><meta charset="utf-8">
<title>Avatar motion review</title><style>
body{background:#17232b;color:#e7dcc9;font:16px system-ui;margin:32px}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px}
img{max-width:100%;max-height:600px;object-fit:contain}h2{font-size:18px}</style>
<h1>Avatar motion review</h1><p>Actual Rive captures. Each clip includes the return to rest;
waiting, speaking and blinking show their own timing.</p><main>'''+"\n".join(cards)+"</main>")
    print(out)


if __name__ == "__main__":
    main()
