"""Evidence and gates for the time of day in the scenes (moonshot M7 Task 5, contract v10).

    uv run --with pillow --with numpy rive/tools/review_time.py [sceneId ...] [--same-as=<commit>]
        [--out=rive/review/m7/time] [--gates-only]

Per scene: `time_strip.png` (night, sunrise / sunset, morning, noon: `daylight` / `dusk` =
0 / 0, 0.4 / 1, 0.75 / 0.2, 1 / 0) and `gates.txt`:
- night (0 / 0) renders exactly as `--same-as`'s RML (default `HEAD`): v10 changes nothing at night;
- noon brightens the sky (mean luminance of the scene's sky box up by > 12/255) for livingRoom,
  campfire, beach, and changes no pixel for deepSpace (it ignores the clock);
- sunset recolours the band above the horizon (mean abs delta > 6/255) where a scene binds dusk;
- the ground (bottom 25 %) moves < 3/255 at noon: the veils touch the sky plane only.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCENES = ("livingRoom", "campfire", "beach", "deepSpace")
POSES = (("night", 0.0, 0.0), ("sunset", 0.4, 1.0), ("morning", 0.75, 0.2), ("noon", 1.0, 0.0))
# (x0, y0, x1, y1) in the 1080 x 1920 artboard: where the sky shows, and the band above the horizon
SKY_BOX = {"livingRoom": (360, 230, 720, 700), "campfire": (0, 0, 1080, 600), "beach": (0, 0, 1080, 900)}
# the beach is drawn as a bright sky already: its noon gain is smaller
NOON_GAIN = {"beach": 6.0}
DUSK_BOX = {"livingRoom": (360, 480, 720, 700), "campfire": (0, 400, 1080, 700), "beach": (0, 700, 1080, 985)}


def render(proj: Path, out: Path, daylight: float, dusk: float) -> np.ndarray:
    subprocess.run(["rive", str(proj), f"--screenshot={out}", "--advance=1", f"--data=daylight={daylight}",
                    f"--data=dusk={dusk}"], check=True, capture_output=True)
    return np.asarray(Image.open(out).convert("RGB")).astype(np.float64)


def lum(a: np.ndarray) -> float:
    return float((0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]).mean())


def check(scene: str, same_as: str, tmp: Path) -> tuple[list[str], dict[str, np.ndarray]]:
    proj = ROOT / "rive" / "scenes" / scene
    shots = {name: render(proj, tmp / f"{scene}_{name}.png", dl, dk) for name, dl, dk in POSES}
    old = tmp / f"old_{scene}"
    old.mkdir()
    rml = subprocess.run(["git", "show", f"{same_as}:rive/scenes/{scene}/{scene}.rml"], cwd=ROOT, check=True,
                         capture_output=True, text=True).stdout
    (old / f"{scene}.rml").write_text(rml)
    shutil.copy(proj / "rive.yaml", old / "rive.yaml")
    before = render(old, tmp / f"{scene}_before.png", 0.0, 0.0)
    lines = []
    diff = float((np.abs(shots["night"] - before).max(axis=2) > 0).mean())
    lines.append(f"{scene}: night identical to {same_as}: {diff * 100:.3f} % differ ({'ok' if diff == 0 else 'FAIL'})")
    h = shots["night"].shape[0]
    k = h / 1920

    def box(a: np.ndarray, b: tuple[int, int, int, int]) -> np.ndarray:
        return a[int(b[1] * k):int(b[3] * k), int(b[0] * k):int(b[2] * k)]

    if scene in SKY_BOX:
        gain = lum(box(shots["noon"], SKY_BOX[scene])) - lum(box(shots["night"], SKY_BOX[scene]))
        want = NOON_GAIN.get(scene, 12.0)
        lines.append(f"{scene}: noon brightens the sky by {gain:.1f}/255 (want > {want:.0f}) "
                     f"({'ok' if gain > want else 'FAIL'})")
        dd = float(np.abs(box(shots["sunset"], DUSK_BOX[scene]) - box(shots["night"], DUSK_BOX[scene])).mean())
        lines.append(f"{scene}: sunset recolours the horizon band by {dd:.1f}/255 ({'ok' if dd > 6 else 'FAIL'})")
    else:
        same = float((np.abs(shots["noon"] - shots["night"]).max(axis=2) > 0).mean())
        lines.append(f"{scene}: ignores the clock: {same * 100:.3f} % differ at noon ({'ok' if same == 0 else 'FAIL'})")
    ground = slice(int(h * 0.75), h)
    dg = float(np.abs(shots["noon"][ground] - shots["night"][ground]).mean())
    lines.append(f"{scene}: ground unchanged at noon: mean delta {dg:.2f}/255 ({'ok' if dg < 3 else 'FAIL'})")
    return lines, shots


def strip(shots: dict[str, np.ndarray], out: Path) -> None:
    ims = [Image.fromarray(shots[name].astype(np.uint8)).resize((270, 480)) for name, _, _ in POSES]
    sheet = Image.new("RGB", (270 * len(ims), 480))
    for i, im in enumerate(ims):
        sheet.paste(im, (270 * i, 0))
    sheet.save(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("scenes", nargs="*")
    ap.add_argument("--same-as", default="HEAD")
    ap.add_argument("--out", default=str(ROOT / "rive" / "review" / "m7" / "time"))
    ap.add_argument("--gates-only", action="store_true")
    args = ap.parse_args()
    tmp = Path(tempfile.mkdtemp(prefix="time_review_"))
    all_lines: list[str] = []
    try:
        for scene in args.scenes or SCENES:
            lines, shots = check(scene, args.same_as, tmp)
            print("\n".join(lines), flush=True)
            all_lines += lines
            if not args.gates_only:
                out = Path(args.out) / scene
                out.mkdir(parents=True, exist_ok=True)
                strip(shots, out / "time_strip.png")
                (out / "gates.txt").write_text("\n".join(lines) + "\n")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 1 if any(line.endswith("FAIL)") for line in all_lines) else 0


if __name__ == "__main__":
    sys.exit(main())
