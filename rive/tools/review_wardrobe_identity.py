"""Render gate for the M10 wardrobe dedupe (moonshot M10 Task 2a, ruling 3).

    uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py            # gates + evidence
    uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py --quick    # rest + peaks only
    uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py --jobs 6

The reference is the M9 avatar: `git show <BASE>:rive/avatar/avatar.rml` (first proven to build
byte-identical to `<BASE>:assets/rive/avatar.riv`, so its renders are the M9 file's); the candidate is
`rive/avatar/avatar.rml`. Both are rendered on a 1250 px tall copy of the artboard (the resting hands
hang below the 1000 px frame) with the rive CLI, in parallel scratch projects.

Cases (each M9 vs new; ok = at most 1/255 per channel, i.e. renderer noise, or no differing pixel):
- every outfit (7 tops, 4 costumes over the default top; hat noHat) at rest (frame 1) and at the peak
  frame (largest hand-target travel; mid-clip for head-only gestures) and the mid frame of all 11
  gestures; each costume's loop at frames 120, 400 and 640 (singularity's laser flash);
- every hand skin (bare via the default top, black batman, metal robocop, stars singularity, white
  soubrette) in each drawn pose (palm, edge, point, up; review_hands.posed forces it on both files);
- switch-order sequences (`--data` mid-run steps): top A -> costume -> none -> top B and costume ->
  costume -> none; each prefix rendered, and the end state also against the new file rendered directly
  at the same frame (history-free: each mid-run step costs one frame).

Writes `rive/review/m10/wardrobe/gates.txt` and `rest_sheet.png` (the 11 outfits at rest, new file,
each cell labelled with its M9 difference). Exit status 1 if any case fails.
"""

from __future__ import annotations

import argparse
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from review_hands import posed, tall  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "avatar"
BASE = "a429f00"  # the M10 plan's base: the M9 avatar (unchanged since M8's 286f28b)
TOPS = ["pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie"]
COSTUMES = ["batman", "robocop", "soubrette", "singularity"]
GESTURES = ["wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think", "thumbsUp", "count", "grab"]
SKIN_COSTUME = {"bare": "none", "black": "batman", "metal": "robocop", "stars": "singularity", "white": "soubrette"}
DRAWN_POSES = ("palm", "edge", "point", "up")
SEQUENCES = [
    [("top", "pinkHoodie"), ("costume", "singularity"), ("costume", "none"), ("top", "longCoat")],
    [("top", "christmasSweater"), ("costume", "batman"), ("costume", "none"), ("top", "blackSuitAndTie")],
    [("top", "longCoat"), ("costume", "robocop"), ("costume", "soubrette"), ("costume", "none"),
     ("top", "pinkHoodie")],
    [("top", "underwear"), ("costume", "singularity"), ("costume", "none"), ("top", "swimsuit")],
    [("top", "tshirt"), ("costume", "batman"), ("top", "christmasSweater"), ("costume", "none")],
    [("costume", "soubrette"), ("top", "blackSuitAndTie"), ("costume", "none"), ("top", "underwear")],
]
STEP = 3  # frames between sequence steps
LOOP_FRAMES = (120, 400, 640)  # singularity flashes its laser over frames 612-700


def outfit_args(o: str) -> list[str]:
    return [f"--data=costume={o}"] if o in COSTUMES else [f"--data=top={o}"]


def gesture_frames(rml: str) -> dict[str, list[int]]:
    """Peak (largest summed hand-target travel from frame 0) and mid frame of each gesture clip."""
    board = ET.fromstring(rml).find("Artboard")
    targets = {e.get("id") for e in board.iter("Node") if e.get("name") in ("HandTargetR", "HandTargetL")}
    out = {}
    for g in GESTURES:
        anim = next(a for a in board.findall("LinearAnimation") if a.get("name") == f"gesture_{g}")
        n = int(anim.get("duration"))
        chans = []
        for obj in anim.findall("KeyedObject"):
            if obj.get("objectId") not in targets:
                continue
            for prop in obj:
                chans.append([(int(k.get("frame")), float(k.get("value"))) for k in prop])

        def at(keys: list[tuple[int, float]], f: int) -> float:
            if f <= keys[0][0]:
                return keys[0][1]
            for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
                if f0 <= f <= f1:
                    return v0 + (v1 - v0) * (f - f0) / max(1, f1 - f0)
            return keys[-1][1]
        travel = [sum(abs(at(c, f) - at(c, 0)) for c in chans) for f in range(n)]
        peak = int(np.argmax(travel)) if chans and max(travel) > 0 else n // 2
        out[g] = sorted({peak, n // 2})
    return out


def git_show(path: str, binary: bool = False) -> bytes | str:
    r = subprocess.run(["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, check=True)
    return r.stdout if binary else r.stdout.decode()


class Renderer:
    """A pool of scratch project copies per variant (concurrent CLI builds never share a build dir)."""

    def __init__(self, tmp: Path, variants: dict[str, str], jobs: int) -> None:
        self.tmp = tmp
        self.pools: dict[str, queue.Queue] = {}
        for name, rml in variants.items():
            q: queue.Queue = queue.Queue()
            for k in range(jobs):
                dst = tmp / f"{name}_{k}"
                dst.mkdir(parents=True)
                shutil.copy(PROJ / "rive.yaml", dst / "rive.yaml")
                (dst / "avatar.rml").write_text(rml)
                q.put(dst)
            self.pools[name] = q

    def render(self, variant: str, png: Path, args: list[str]) -> np.ndarray:
        proj = self.pools[variant].get()
        try:
            subprocess.run(["rive", str(proj), f"--screenshot={png}", *args], check=True, capture_output=True)
        finally:
            self.pools[variant].put(proj)
        return np.asarray(Image.open(png).convert("RGBA")).astype(np.int16)


def verdict(a: np.ndarray, b: np.ndarray) -> tuple[int, int, bool]:
    d = np.abs(a - b).max(axis=2)
    n, mx = int((d > 0).sum()), int(d.max())
    return n, mx, mx <= 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "rive" / "review" / "m10" / "wardrobe"))
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--quick", action="store_true", help="rest and gesture peaks only")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="wardrobe_identity_"))
    lines: list[str] = []
    ok_all = True
    try:
        old, new = git_show("rive/avatar/avatar.rml"), (PROJ / "avatar.rml").read_text()
        # the M9 RML is the M9 file: build it at its own height and compare bytes
        probe = tmp / "probe"
        probe.mkdir()
        shutil.copy(PROJ / "rive.yaml", probe / "rive.yaml")
        (probe / "avatar.rml").write_text(old)
        subprocess.run(["rive", str(probe), "--once"], check=True, capture_output=True)
        same = (probe / "build" / "avatar.riv").read_bytes() == git_show("assets/rive/avatar.riv", binary=True)
        lines.append(f"M9 RML ({BASE}) builds byte-identical to {BASE}:assets/rive/avatar.riv: "
                     f"{'ok' if same else 'FAIL'}")
        ok_all &= same
        variants = {"m9": tall(old), "new": tall(new)}
        for pose in ([] if args.quick else DRAWN_POSES):
            variants[f"m9_{pose}"], variants[f"new_{pose}"] = posed(old, pose), posed(new, pose)
        r = Renderer(tmp, variants, args.jobs)
        frames = gesture_frames(new)

        cases: list[tuple[str, str, list[str], str | None]] = []  # (label, variant suffix, args, direct-twin args)
        for o in TOPS + COSTUMES:
            cases.append((f"{o} rest f1", "", outfit_args(o) + ["--advance=2"], None))
            for g in GESTURES:
                for f in frames[g]:
                    cases.append((f"{o} {g} f{f}", "", outfit_args(o) + [f"--data=gestureId={g}",
                                                                          "--data=gesture=true", f"--advance={f + 1}"],
                                  None))
        for o in COSTUMES:  # the costume loops (M10 moved the laser's flashes to their own layer)
            for f in LOOP_FRAMES:
                cases.append((f"{o} loop f{f}", "", outfit_args(o) + [f"--advance={f + 1}"], None))
        if not args.quick:
            for skin, costume in SKIN_COSTUME.items():
                for pose in DRAWN_POSES:
                    cases.append((f"hand {skin} {pose}", f"_{pose}", [f"--data=costume={costume}", "--advance=2"],
                                  None))
            for seq in SEQUENCES:
                for k in range(1, len(seq) + 1):
                    a: list[str] = []
                    for i, (p, v) in enumerate(seq[:k]):
                        a += [f"--data={p}={v}", f"--advance={STEP}"]
                    name = " > ".join(f"{p}={v}" for p, v in seq[:k])
                    # the end state rendered directly: the same values from frame 0, same frame count
                    state = {"top": "pinkHoodie", "costume": "none"}
                    for p, v in seq[:k]:
                        state[p] = v
                    direct = [f"--data=top={state['top']}", f"--data=costume={state['costume']}",
                              f"--advance={STEP * k + (k - 1)}"]
                    cases.append((f"seq {name}", "", a, direct))

        def run(i: int) -> tuple[str, list[str], bool, np.ndarray | None]:
            label, suffix, cargs, direct = cases[i]
            a = r.render("m9" + suffix, tmp / f"a{i}.png", cargs)
            b = r.render("new" + suffix, tmp / f"b{i}.png", cargs)
            n, mx, ok = verdict(a, b)
            res = [f"{label}: {n} px differ, max {mx}/255 vs M9 ({'ok' if ok else 'FAIL'})"]
            if direct is not None:
                c = r.render("new" + suffix, tmp / f"c{i}.png", direct)
                n2, mx2, ok2 = verdict(b, c)
                res.append(f"{label}: end state vs direct render {n2} px differ, max {mx2}/255 "
                           f"({'ok' if ok2 else 'FAIL'})")
                ok = ok and ok2
            keep = b if label.endswith("rest f1") else None
            return label, res, ok, keep

        with ThreadPoolExecutor(args.jobs) as ex:
            results = list(ex.map(run, range(len(cases))))
        # the CLI renderer has shown frame-wide 2/255 noise under parallel load (cases that render 0 px apart
        # alone): a failing case is rendered again once with no other render running, and both runs are logged
        for i, (label, res, ok, keep) in enumerate(results):
            if not ok:
                label2, res2, ok2, keep2 = run(i)
                results[i] = (label2, [f"{ln} [parallel run: {old.split(': ', 1)[1]}; re-rendered alone]"
                                       for ln, old in zip(res2, res)], ok2, keep2)
        rest: dict[str, tuple[np.ndarray, str]] = {}
        for label, res, ok, keep in results:
            lines += res
            ok_all &= ok
            if keep is not None:
                rest[label.split()[0]] = (keep, res[0].split(": ", 1)[1].split(" vs")[0])
        fails = sum("FAIL" in ln.split(" [parallel run")[0] for ln in lines)
        retried = sum("re-rendered alone" in ln for ln in lines)
        lines.append(f"TOTAL: {len(cases)} cases, {fails} failing lines, {retried} re-rendered alone after parallel "
                     f"noise ({'ok' if ok_all else 'FAIL'})")
        print("\n".join(lines))
        (out / "gates.txt").write_text("\n".join(lines) + "\n")
        cells = []
        for o in TOPS + COSTUMES:
            im = Image.fromarray(rest[o][0].astype(np.uint8)).convert("RGB").crop((100, 120, 700, 1250))
            im = im.resize((240, 452), Image.LANCZOS)
            ImageDraw.Draw(im).text((6, 4), o, fill=(255, 255, 255))
            ImageDraw.Draw(im).text((6, 436), rest[o][1], fill=(255, 255, 255))
            cells.append(im)
        sheet = Image.new("RGB", (240 * 6, 452 * 2), (20, 20, 20))
        for k, c in enumerate(cells):
            sheet.paste(c, ((k % 6) * 240, (k // 6) * 452))
        sheet.save(out / "rest_sheet.png", optimize=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
