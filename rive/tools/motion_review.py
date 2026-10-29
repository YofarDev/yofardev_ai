"""Capture avatar gestures, facial phases and presence with the real Rive renderer.

uv run --with pillow python rive/tools/motion_review.py --label after
uv run --with pillow python rive/tools/motion_review.py --ik-check   # runtime IK vs the Python solver
Use --project to review a saved source snapshot; output stays under build/.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from html import escape
import json
import math
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image

import ik_check
from review import ROOT, run, sheet

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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT / "rive/avatar")
    parser.add_argument("--label", default="after")
    parser.add_argument("--dense", action="store_true", help="Capture at 20 fps for playback")
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
