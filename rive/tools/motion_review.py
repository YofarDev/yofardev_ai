"""Capture avatar gestures, facial phases and presence with the real Rive renderer.

uv run --with pillow python rive/tools/motion_review.py --label after
Use --project to review a saved source snapshot; output stays under build/.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from html import escape
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image

from review import ROOT, run, sheet


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT / "rive/avatar")
    parser.add_argument("--label", default="after")
    parser.add_argument("--dense", action="store_true", help="Capture at 20 fps for playback")
    args = parser.parse_args()
    out = ROOT / "build/avatar-motion-review" / args.label
    project = out / "source"
    project.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.project / "avatar.rml", project / "avatar.rml")
    (project / "rive.yaml").write_text("name: motion\nmain: Avatar\noutput: {dir: build}\n")
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
