"""Render real wardrobe motion and create a local playback gallery.

    python rive/tools/wardrobe_review.py
    python rive/tools/wardrobe_review.py --full

Requires Rive CLI and Pillow; ffmpeg adds MP4 playback when available.
The full pass includes every costume x gesture; the default uses wave/clap.
Writes only under build/ and snapshots the avatar before rendering.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from html import escape
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image

from review import ROOT, run, sheet

TOPS = ("pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie")
COSTUMES = ("batman", "robocop", "soubrette", "singularity")
GESTURES = ("wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think")
HATS = ("noHat", "beanie", "backwardsCap", "frenchBeret", "swimCap", "santaHat", "redMagaCap")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full", action="store_true", help="Include all 32 costume/gesture combinations")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--only", action="append", help="Restrict to a clip label prefix; repeatable (e.g. robocop-facepalm)")
    args = parser.parse_args()
    if args.workers < 1:
        parser.error("--workers must be positive")
    out = ROOT / "build/wardrobe-playback"
    project = out / "avatar"
    project.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "rive/avatar/avatar.rml", project / "avatar.rml")
    (project / "rive.yaml").write_text("name: wardrobe\nmain: Avatar\noutput: {dir: build}\n")
    # Always recapture; a gallery must not silently mix revisions.
    cases: list[tuple[str, list[str], int]] = []
    for prop, values in (("top", TOPS), ("costume", COSTUMES)):
        for value in values:
            gestures = GESTURES if prop == "costume" and args.full else ("wave", "clap")
            for gesture in gestures:
                cases.append((f"{value}-{gesture}", [f"--data={prop}={value}",
                              f"--data=gestureId={gesture}", "--data=gesture=true"], 165))
    board = ET.parse(project / "avatar.rml").getroot().find("Artboard")
    durations = {a.get("name"): int(a.get("duration")) for a in board.findall("LinearAnimation")}
    for costume in COSTUMES:
        cases.append((f"{costume}-ambient", [f"--data=costume={costume}"], durations[f"costume_{costume}"] + 60))
    for hat in HATS:
        cases.append((f"{hat}-headshake", [f"--data=hat={hat}", "--data=gestureId=headshake",
                      "--data=gesture=true"], 135))
    for glasses in ("glasses", "sunglasses"):
        cases.append((f"{glasses}-nod", [f"--data=glasses={glasses}", "--data=gestureId=nod",
                      "--data=gesture=true"], 105))
    if args.only:
        cases = [case for case in cases if any(case[0].startswith(prefix) for prefix in args.only)]
        if not cases:
            parser.error("--only does not match any clip labels; use --full to include every costume gesture")
    for label, _, _ in cases:
        directory = out / "frames" / label
        if directory.exists():
            for old_frame in directory.glob("[0-9][0-9][0-9][0-9].png"):
                old_frame.unlink()

    jobs = [(label, data, frame) for label, data, duration in cases for frame in range(1, duration + 1, 5)]

    def capture(job: tuple[str, list[str], int]) -> None:
        label, data, frame = job
        run(project, out / "frames" / label / f"{frame:04d}.png", *data, f"--advance={frame}", "--scale=0.5")

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for i, _ in enumerate(pool.map(capture, jobs), 1):
            if i % 100 == 0 or i == len(jobs):
                print(f"Captured {i}/{len(jobs)} real Rive frames", flush=True)
    ffmpeg = shutil.which("ffmpeg")
    cards = []
    for label, _, duration in cases:
        files = [out / "frames" / label / f"{f:04d}.png" for f in range(1, duration + 1, 5)]
        images = [Image.open(p).convert("RGB") for p in files]
        images[0].save(out / f"{label}.gif", save_all=True, append_images=images[1:], duration=83, loop=0)
        chosen = [files[round(i * (len(files) - 1) / 9)] for i in range(10)]
        sheet(chosen, [f"{label} f{int(p.stem) - 1}" for p in chosen], out / f"{label}.png", width=200, columns=5)
        if ffmpeg:
            subprocess.run([ffmpeg, "-v", "error", "-y", "-framerate", "12", "-pattern_type", "glob", "-i",
                            str(out / "frames" / label / "*.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                            str(out / f"{label}.mp4")], check=True)
            media = f'<video controls loop muted playsinline preload="none" poster="{label}.png" src="{label}.mp4"></video>'
        else:
            media = f'<img loading="lazy" src="{label}.gif" alt="{escape(label)} animation">'
        cards.append(f'<article><h2>{escape(label)}</h2>{media}</article>')
    (out / "index.html").write_text('''<!doctype html><meta charset="utf-8"><title>Wardrobe playback</title>
<style>body{background:#17232b;color:#e7dcc9;font:16px system-ui;margin:32px}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}
video,img{width:100%;max-height:600px;object-fit:contain}h2{font-size:16px}</style>
<h1>Actual Rive wardrobe playback</h1><p>12 fps captures; controls allow pausing and scrubbing.
Play clips to judge timing, attachments and transitions. Contact sheets alone are insufficient.</p><main>'''
                                    + "\n".join(cards) + "</main>")
    print(f"Playback gallery: {out / 'index.html'}")


if __name__ == "__main__":
    main()
