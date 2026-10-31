"""Evidence and gates for contract v13 on the avatar (moonshot M10 Tasks 2b-2c, rulings 5, 6, 12).

    uv run --with pillow --with numpy rive/tools/review_wardrobe_v13.py tints
    uv run --with pillow --with numpy rive/tools/review_wardrobe_v13.py anchor
    uv run --with pillow --with numpy rive/tools/review_wardrobe_v13.py signatures

Writes to `rive/review/m10/wardrobe/`:
- `tints.png`: the nine tints (`TINTS`, the values the app's `WardrobeTints` mirrors) on three tops with two
  hats (pinkHoodie + beanie, longCoat + santaHat, swimsuit + no hat), row 0 untinted.
- `anchor.png` + `anchor.txt`: `MouthAnchor` against the lips under the head turn, roll, the jaw, lean,
  breath and the walk. A scratch copy of the avatar hangs a magenta dot on `MouthAnchor` and paints the
  lip outline (`MouthLine`) pure green; the gate: the dot's centroid lies within 6 px of the centre of the
  green outline's bounding box (the lips' visual centre) in every frame.
- `signature_<costume>.png`: 8 evenly spaced frames of `gestureId` signature for each costume, and
  `signatures.txt` (clip lengths, the frame-to-frame motion of the rig's keyed channels).
"""

from __future__ import annotations

import argparse
import queue
from concurrent.futures import ThreadPoolExecutor
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import motion_metrics  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROJ = ROOT / "rive" / "avatar"
OUT = ROOT / "rive" / "review" / "m10" / "wardrobe"
# the nine v13 tints (alpha FF = full amount); storybook values, mirrored by the app's WardrobeTints
TINTS = {"red": "FFD64545", "orange": "FFE8873A", "yellow": "FFE8C547", "green": "FF4FA65B", "teal": "FF2FA3A0",
         "blue": "FF4A78D0", "purple": "FF8A5CC4", "pink": "FFE06AA8", "grey": "FF8A8A90"}
TINT_LOOKS = [("pinkHoodie", "beanie"), ("longCoat", "santaHat"), ("swimsuit", "noHat")]
ANCHOR_FRAMES = [
    ("rest", []), ("yaw -1", ["--data=yaw=-1"]), ("yaw +1", ["--data=yaw=1"]),
    ("pitch -1", ["--data=pitch=-1"]), ("pitch +1", ["--data=pitch=1"]),
    ("roll -1", ["--data=roll=-1"]), ("roll +1", ["--data=roll=1"]),
    ("jaw open", ["--data=auJawDrop=1"]), ("lean 1", ["--data=lean=1"]), ("breath 1", ["--data=breath=1"]),
    ("speech mouth 1", ["--data=mouth=1"]),
    ("yaw 1 pitch -1 roll 1 jaw 1 lean 1", ["--data=yaw=1", "--data=pitch=-1", "--data=roll=1", "--data=auJawDrop=1",
                                            "--data=lean=1"]),
    ("walk f30", ["--data=presence=leaveAndComeBack", "--advance=30"]),
    ("walk f40", ["--data=presence=leaveAndComeBack", "--advance=40"]),
]
ANCHOR_TOL = 6.0
COSTUMES = ["batman", "robocop", "soubrette", "singularity"]


def rive(proj: Path, png: Path, *args: str) -> None:
    subprocess.run(["rive", str(proj), f"--screenshot={png}", *args], check=True, capture_output=True)


def project(dst: Path, rml: str) -> Path:
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy(PROJ / "rive.yaml", dst / "rive.yaml")
    (dst / "avatar.rml").write_text(rml)
    return dst


def label(im: Image.Image, text: str, at: tuple[int, int] = (6, 4)) -> Image.Image:
    ImageDraw.Draw(im).text(at, text, fill=(255, 255, 255))
    return im


def tints(tmp: Path) -> None:
    rows = [("none", None), *TINTS.items()]
    cells: list[Image.Image] = []
    for name, value in rows:
        for top, hat in TINT_LOOKS:
            png = tmp / f"tint_{name}_{top}.png"
            extra = [] if value is None else [f"--data=topTint={value}", f"--data=hatTint={value}"]
            rive(PROJ, png, "--advance=2", f"--data=top={top}", f"--data=hat={hat}", *extra)
            im = Image.open(png).convert("RGB").crop((140, 60, 660, 1000)).resize((208, 376), Image.LANCZOS)
            cells.append(label(im, f"{name} {value or ''}"))
    cols = len(TINT_LOOKS)
    sheet = Image.new("RGB", (208 * cols * 2, 376 * ((len(rows) + 1) // 2)), (20, 20, 20))
    for k, c in enumerate(cells):
        row, col = divmod(k, cols)
        sheet.paste(c, ((col + cols * (row % 2)) * 208, (row // 2) * 376))
    sheet.quantize(256).save(OUT / "tints.png", optimize=True)
    print("wrote", OUT / "tints.png")


def probed(rml: str) -> str:
    """The avatar with a magenta dot in front of everything, held on MouthAnchor's world translation (what the
    app reads) by a world translation constraint, and the lip outline painted pure green."""
    root = ET.fromstring(rml)
    board = root.find("Artboard")
    anchor_ = next(e for e in root.iter("Node") if e.get("name") == "MouthAnchor")
    body = next(e for e in board if e.get("name") == "Root")
    dot = ET.Element("Shape", {"x": "0", "y": "0", "name": "Probe", "id": "0:9999990"})
    ET.SubElement(dot, "TranslationConstraint", {"targetId": anchor_.get("id"), "name": "Follow", "id": "0:9999994"})
    ET.SubElement(dot, "Ellipse", {"width": "7", "height": "7", "name": "Path", "id": "0:9999991"})
    fill = ET.SubElement(dot, "Fill", {"name": "Fill", "id": "0:9999992"})
    ET.SubElement(fill, "SolidColor", {"colorValue": "FFFF00FF", "id": "0:9999993"})
    board.insert(list(board).index(body), dot)
    line = next(e for e in root.iter("Shape") if e.get("name") == "MouthLine")
    for sc in line.iter("SolidColor"):
        sc.set("colorValue", "FF00FF00")
    return '<Rive version="1" kind="fragment">\n' + "\n".join(ET.tostring(c, encoding="unicode") for c in root) + \
        "\n</Rive>\n"


def anchor(tmp: Path) -> bool:
    proj = project(tmp / "probe", probed((PROJ / "avatar.rml").read_text()))
    lines, cells, ok_all = [], [], True
    for name, args in ANCHOR_FRAMES:
        png = tmp / f"anchor_{len(cells)}.png"
        rive(proj, png, *(args if any(a.startswith("--advance") for a in args) else [*args, "--advance=2"]))
        im = np.asarray(Image.open(png).convert("RGB")).astype(int)
        r, g, b = im[..., 0], im[..., 1], im[..., 2]
        mag = (r > 200) & (g < 60) & (b > 200)
        grn = (g > 200) & (r < 60) & (b < 60)
        if not mag.any() or not grn.any():
            lines.append(f"{name}: probe not visible (FAIL)")
            ok_all = False
            continue
        my, mx = (float(v.mean()) for v in np.nonzero(mag))
        gy, gx = np.nonzero(grn)
        cx, cy = (gx.min() + gx.max()) / 2, (gy.min() + gy.max()) / 2
        err = float(np.hypot(mx - cx, my - cy))
        ok = err <= ANCHOR_TOL
        ok_all &= ok
        lines.append(f"{name}: anchor ({mx:.1f}, {my:.1f}), lips' centre ({cx:.1f}, {cy:.1f}), "
                     f"{err:.2f} px ({'ok' if ok else 'FAIL'})")
        pil = Image.open(png).convert("RGB")
        x0, y0 = int(max(0, mx - 110)), int(max(0, my - 120))
        cell = pil.crop((x0, y0, x0 + 220, y0 + 220)).resize((330, 330), Image.LANCZOS)
        dr = ImageDraw.Draw(cell)
        k = 330 / 220
        dr.ellipse(((cx - x0) * k - 5, (cy - y0) * k - 5, (cx - x0) * k + 5, (cy - y0) * k + 5), outline=(255, 255, 255))
        cells.append(label(cell, f"{name} {err:.1f} px"))
    sheet = Image.new("RGB", (330 * 7, 330 * ((len(cells) + 6) // 7)), (20, 20, 20))
    for k_, c in enumerate(cells):
        sheet.paste(c, ((k_ % 7) * 330, (k_ // 7) * 330))
    sheet.quantize(256).save(OUT / "anchor.png", optimize=True)
    lines.append("magenta = MouthAnchor (probe dot), green = the lip outline, white ring = its bounding-box centre")
    lines.append(f"TOTAL: {'ok' if ok_all else 'FAIL'}")
    (OUT / "anchor.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return ok_all


def signature_frames(board: ET.Element, costume: str) -> int:
    anim = next(a for a in board.findall("LinearAnimation") if a.get("name") == f"gesture_signature_{costume}")
    return int(anim.get("duration"))


def signatures(tmp: Path, jobs: int = 8) -> bool:
    """Contact sheets, and every frame of each clip for the motion metrics (motion_metrics.pops: a frame whose
    change from the previous one is over 4 x the clip's median change; robocop's held keys step on purpose)."""
    board = ET.parse(PROJ / "avatar.rml").getroot().find("Artboard")
    pool: queue.Queue = queue.Queue()
    for k in range(jobs):
        pool.put(project(tmp / f"sig_proj{k}", (PROJ / "avatar.rml").read_text()))

    def shot(job: tuple[str, int], fire: bool = True) -> Path:
        costume, f = job
        png = tmp / f"sig_{costume}_{f:03}{'' if fire else '_twin'}.png"
        proj = pool.get()
        try:  # the twin sets a value instead of firing the trigger: the same number of mid-run steps
            rive(proj, png, f"--data=costume={costume}", "--advance=2", "--data=gestureId=signature",
                 "--data=gesture=true" if fire else "--data=gestureId=signature", f"--advance={f + 1}")
        finally:
            pool.put(proj)
        return png

    lines = []
    for costume in COSTUMES:
        n = signature_frames(board, costume)
        with ThreadPoolExecutor(jobs) as ex:
            pngs = list(ex.map(shot, [(costume, f) for f in range(n + 2)]))
        frames = [Image.open(p).convert("RGB") for p in pngs]
        diffs = motion_metrics.frame_diffs(frames)
        popped = motion_metrics.pops(diffs)
        rest = Image.open(pngs[0]).convert("RGB")
        jerk = motion_metrics.jerk(motion_metrics.motion_centroids(frames, rest))
        twin = Image.open(shot((costume, n + 1), fire=False)).convert("RGB")
        delta = np.abs(np.asarray(frames[-1], dtype=np.int16) - np.asarray(twin, dtype=np.int16)).max(axis=2)
        end = f"{int((delta > 0).sum())} px differ, max {int(delta.max())}/255"
        cells = []
        for f in [round(k * (n - 1) / 7) for k in range(8)]:
            im = frames[f].crop((0, 60, 800, 1000)).resize((300, 352), Image.LANCZOS)
            cells.append(label(im, f"{costume} f{f} ({f * 1000 // 60} ms)"))
        strip = Image.new("RGB", (300 * 4, 352 * 2))
        for k, c in enumerate(cells):
            strip.paste(c, ((k % 4) * 300, (k // 4) * 352))
        strip.quantize(256).save(OUT / f"signature_{costume}.png", optimize=True)
        lines.append(f"signature_{costume}: {n} frames ({n * 1000 // 60} ms); pops at {popped or 'none'}; "
                     f"centroid jerk {jerk:.0f} px/s^3; max frame step {max(diffs):.4f} (median "
                     f"{sorted(diffs)[len(diffs) // 2]:.4f}); the frame after the clip vs the costume never gestured: {end}")
    (OUT / "signatures.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=["tints", "anchor", "signatures"])
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="wardrobe_v13_"))
    try:
        ok = {"tints": lambda: tints(tmp) or True, "anchor": lambda: anchor(tmp),
              "signatures": lambda: signatures(tmp)}[args.what]()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
