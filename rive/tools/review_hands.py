"""Evidence and gates for the articulated hands and the M8 gestures (moonshot M8 Task 2, rulings 2-4).

    uv run --with pillow --with numpy rive/tools/review_hands.py                # gates + evidence
    uv run --with pillow --with numpy rive/tools/review_hands.py --gates-only

Writes to `rive/review/m8/hands/` (unless `--gates-only`):
- `poses_<skin>.png`: the 12 hand poses (rest, palm, edge, point, up and the articulated fist, grip, pinch,
  thumbsUp, one, two, three), both hands at 2x, for each skin (bare, black, metal, stars, white: forced
  through the costume that wears that glove). Rendered from a scratch copy of the avatar whose artboard
  is taller (the resting hands hang below the 1000 px frame) and whose `hand_rest` keys (articulated
  poses) or `gesture_none` hand-pose keys (drawn poses) hold the pose.
- `<gesture>_strip.png`: 8 evenly spaced frames of `thumbsUp`, `count` and `grab`.
- `gates.txt`.

Gates (one line each, `ok` or `FAIL`):
- the rest frames (`--advance=1` and 60, every default) are pixel-identical to the M7 avatar
  (`git show 927a606:rive/avatar/avatar.rml`, built in a scratch project), and so is the tablet held
  (`prop=tablet`, frame 60: `tabletWeather` none keeps the generic card);
- the hands under the frame (taller copies of both): at most 1/255 on at most 0.01 % of the pixels per skin
  (the constraint's transform recomposition is renderer noise, as review_face's history gates allow);
- `grab`: the grip point at the contact frame within 6 px of the hook (offline, ik_check on the RML).
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
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import hand_rig  # noqa: E402
import ik_check  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "avatar"
BASE = "927a606"
SKIN_COSTUME = {"bare": "none", "black": "batman", "metal": "robocop", "stars": "singularity", "white": "soubrette"}
SHEET_POSES = ("rest", "palm", "edge", "point", "up", "fist", "grip", "pinch", "thumbsUp", "one", "two", "three")
DRAWN_POSES = ("palm", "edge", "point", "up")
GESTURES = {"thumbsUp": 84, "count": 120, "grab": 54}
HOOK, CONTACT = (628.0, 560.0), 23
TALL = 1250
HAND_BOX = {-1: (165, 1035, 335, 1205), 1: (465, 1035, 635, 1205)}  # viewer's left / right hand, tall frame


def rive(proj: Path, png: Path, *args: str) -> None:
    subprocess.run(["rive", str(proj), f"--screenshot={png}", *args], check=True, capture_output=True)


def load(png: Path) -> np.ndarray:
    return np.asarray(Image.open(png).convert("RGB")).astype(np.int16)


def project(dst: Path, rml: str) -> Path:
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy(PROJ / "rive.yaml", dst / "rive.yaml")
    (dst / "avatar.rml").write_text(rml)
    return dst


def tall(rml: str) -> str:
    return re.sub(r'(<Artboard width="800" height=")1000(" name="Avatar")', rf"\g<1>{TALL}\2", rml, count=1)


def base_rml() -> str:
    return subprocess.run(["git", "show", f"{BASE}:rive/avatar/avatar.rml"], cwd=ROOT, capture_output=True, text=True,
                          check=True).stdout


def posed(rml: str, pose: str) -> str:
    """The avatar with `pose` on both hands at rest (tall artboard)."""
    root = ET.fromstring(tall(rml))
    board = root.find("Artboard")
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    anims = {a.get("name"): a for a in board.findall("LinearAnimation")}
    if pose in DRAWN_POSES:
        for obj in anims["gesture_none"].findall("KeyedObject"):
            solo = ids[obj.get("objectId")]
            if solo.get("name") != "HandPose":
                continue
            child = next(c for c in solo if c.get("name") == "Hand_" + pose)
            for kf in obj.iter("KeyFrameId"):
                kf.set("value", child.get("id"))
    else:
        for obj in anims["hand_rest"].findall("KeyedObject"):
            name = ids[obj.get("objectId")].get("name")  # Drive<Digit><R|L>
            vals = hand_rig.values(pose, -1 if name.endswith("R") else 1)[name[5:-1]]
            for prop in obj:
                for kf in prop:
                    kf.set("value", str(vals[0] if prop.get("property") == "rotation" else vals[1]))
    return '<Rive version="1" kind="fragment">\n' + "\n".join(ET.tostring(c, encoding="unicode") for c in root) + \
        "\n</Rive>\n"


def label(im: Image.Image, text: str, at: tuple[int, int] = (8, 6)) -> Image.Image:
    ImageDraw.Draw(im).text(at, text, fill=(255, 255, 255))
    return im


def pose_sheets(tmp: Path, out: Path) -> None:
    rml = (PROJ / "avatar.rml").read_text()
    cells: dict[str, list[Image.Image]] = {s: [] for s in SKIN_COSTUME}
    for i, pose in enumerate(SHEET_POSES):
        proj = project(tmp / f"pose_{pose}", posed(rml, pose))
        for skin, costume in SKIN_COSTUME.items():
            png = tmp / f"pose_{pose}_{skin}.png"
            rive(proj, png, "--advance=2", f"--data=costume={costume}")
            im = Image.open(png).convert("RGB")
            pair = [im.crop(HAND_BOX[s]).resize((300, 300), Image.LANCZOS) for s in (-1, 1)]
            cell = Image.new("RGB", (600, 300))
            cell.paste(pair[0], (0, 0))
            cell.paste(pair[1], (300, 0))
            cells[skin].append(label(cell, pose))
    for skin, row in cells.items():
        sheet = Image.new("RGB", (600 * 4, 300 * 3), (20, 20, 20))
        for k, cell in enumerate(row):
            sheet.paste(cell, ((k % 4) * 600, (k // 4) * 300))
        label(sheet, f"skin: {skin}", (8, 300 * 3 - 18)).save(out / f"poses_{skin}.png")


def gesture_strips(tmp: Path, out: Path) -> None:
    for g, n in GESTURES.items():
        frames = [round(k * n / 7) for k in range(8)]
        cells = []
        for f in frames:
            png = tmp / f"{g}_{f}.png"
            rive(PROJ, png, f"--data=gestureId={g}", "--data=gesture=true", f"--advance={f + 1}")
            im = Image.open(png).convert("RGB").crop((60, 160, 760, 1000)).resize((350, 420), Image.LANCZOS)
            cells.append(label(im, f"{g} f{f} ({f * 1000 // 60} ms)"))
        strip = Image.new("RGB", (350 * len(cells), 420))
        for k, c in enumerate(cells):
            strip.paste(c, (k * 350, 0))
        strip.save(out / f"{g}_strip.png")


def grip_error() -> float:
    board = ET.parse(PROJ / "avatar.rml").getroot().find("Artboard")
    arm = next(a for a in ik_check.arms(board) if a.side == "L")
    ch = ik_check.channels(board, "gesture_grab")
    hand = next(e for e in arm.wrist.iter("Node") if e.get("name") == "Hand")
    elbow, wrist = ik_check.expected(arm, ch, CONTACT)
    finger = math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0]) + ch[(hand.get("id"), "rotation")].at(CONTACT)
    grip = (560.0 + wrist[0] + hand_rig.GRIP_REACH * math.cos(finger),
            720.0 + wrist[1] + hand_rig.GRIP_REACH * math.sin(finger))
    return math.dist(grip, HOOK)


def gates(tmp: Path) -> list[str]:
    lines = []
    old = base_rml()
    ref = project(tmp / "ref", old)
    for name, args in (("rest frame 1", ["--advance=1"]), ("rest frame 60", ["--advance=60"]),
                       ("tablet held, frame 60", ["--data=prop=tablet", "--advance=60"])):
        a, b = tmp / "gate_ref.png", tmp / "gate_new.png"
        rive(ref, a, *args)
        rive(PROJ, b, *args)
        n = int((np.abs(load(a) - load(b)).max(axis=2) > 0).sum())
        lines.append(f"{name} vs {BASE}: {n} px differ ({'ok' if n == 0 else 'FAIL'})")
    ref_t = project(tmp / "ref_tall", tall(old))
    new_t = project(tmp / "new_tall", tall((PROJ / "avatar.rml").read_text()))
    for skin, costume in SKIN_COSTUME.items():
        a, b = tmp / "tall_ref.png", tmp / "tall_new.png"
        rive(ref_t, a, "--advance=30", f"--data=costume={costume}")
        rive(new_t, b, "--advance=30", f"--data=costume={costume}")
        d = np.abs(load(a) - load(b)).max(axis=2)
        n, mx = int((d > 0).sum()), int(d.max())
        ok = mx <= 1 and n <= 0.0001 * d.size
        lines.append(f"hands under the frame ({skin}): {n} px differ, max {mx}/255 ({'ok' if ok else 'FAIL'})")
    err = grip_error()
    lines.append(f"grab: grip point {err:.2f} px from the hook at frame {CONTACT} ({'ok' if err < 6 else 'FAIL'})")
    return lines


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "rive" / "review" / "m8" / "hands"))
    ap.add_argument("--gates-only", action="store_true")
    args = ap.parse_args()
    tmp = Path(tempfile.mkdtemp(prefix="hands_review_"))
    try:
        lines = gates(tmp)
        print("\n".join(lines))
        if not args.gates_only:
            out = Path(args.out)
            out.mkdir(parents=True, exist_ok=True)
            pose_sheets(tmp, out)
            gesture_strips(tmp, out)
            (out / "gates.txt").write_text("\n".join(lines) + "\n")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 1 if any(line.endswith("FAIL)") for line in lines) else 0


if __name__ == "__main__":
    sys.exit(main())
