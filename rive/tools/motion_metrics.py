"""Pixel-level motion metrics for rendered Rive frame sequences.

Render a clip with `render_sequence`, load the PNGs with Pillow, then call `score`:

    paths = render_sequence(Path("rive/avatar"), Path("build/seq"), 132,
                            {"gestureId": "wave", "gesture": "true"})
    frames = [Image.open(p).convert("RGB") for p in paths]
    rest = Image.open(render_sequence(Path("rive/avatar"), Path("build/rest"), 1)[0]).convert("RGB")
    print(score(frames, rest))

Metrics (Pillow and the standard library only):
  pops  - frames whose change from the previous frame is far above the typical change
  jerk  - RMS third derivative of the moving-pixel centroid, in px/s^3
  seam  - last-to-first change relative to the typical frame-to-frame change
"""

from __future__ import annotations

from array import array
import math
from pathlib import Path
import statistics
import subprocess

from PIL import Image, ImageChops, ImageStat

MOTION_THRESHOLD: int = 8  # of 255: luminance change that counts as "moving"


def _luma_diff(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.difference(a.convert("L"), b.convert("L"))


def frame_diffs(frames: list[Image.Image]) -> list[float]:
    """Mean absolute luminance difference between consecutive frames, 0 to 1."""
    return [ImageStat.Stat(_luma_diff(a, b)).mean[0] / 255.0 for a, b in zip(frames, frames[1:])]


def pops(diffs: list[float], k: float = 4.0, floor: float = 0.01) -> list[int]:
    """Indices where the diff exceeds `k * median(diffs)` and also `floor`.

    Index i is the change from frame i to frame i + 1. Empty or all-zero input gives [].
    """
    if not diffs or not any(diffs):
        return []
    median: float = statistics.median(diffs)
    return [i for i, d in enumerate(diffs) if d > k * median and d > floor]


def loop_seam(frames: list[Image.Image]) -> float:
    """Diff(last, first) divided by the median frame-to-frame diff.

    A perfect loop returns 0. If the median diff is 0 (a mostly still clip), returns 0.0 when
    the seam diff is also 0, else math.inf, instead of dividing by zero.
    """
    seam: float = ImageStat.Stat(_luma_diff(frames[-1], frames[0])).mean[0] / 255.0
    median: float = statistics.median(frame_diffs(frames))
    if median == 0:
        return 0.0 if seam == 0 else math.inf
    return seam / median


def _centroid(mask: Image.Image) -> tuple[float, float] | None:
    """Centroid of the non-zero pixels of an L mask holding 0 or 255, or None if empty."""
    w, h = mask.size
    # BOX-resizing a float image to one row / column gives exact per-column / per-row means.
    columns: array[float] = array("f", mask.convert("F").resize((w, 1), Image.Resampling.BOX).tobytes())
    rows: array[float] = array("f", mask.convert("F").resize((1, h), Image.Resampling.BOX).tobytes())
    total: float = sum(columns)
    if total <= 0:
        return None
    return (sum(i * v for i, v in enumerate(columns)) / total,
            sum(i * v for i, v in enumerate(rows)) / sum(rows))


def motion_centroids(frames: list[Image.Image], rest: Image.Image) -> list[tuple[float, float]]:
    """Centroid of the pixels that differ from `rest` by more than 8/255.

    A frame with no differing pixels reuses the previous centroid (the image centre for the
    first frame), so `jerk` does not spike from missing data.
    """
    points: list[tuple[float, float]] = []
    previous: tuple[float, float] = (rest.width / 2, rest.height / 2)
    for frame in frames:
        mask: Image.Image = _luma_diff(frame, rest).point(lambda v: 255 if v > MOTION_THRESHOLD else 0)
        previous = _centroid(mask) or previous
        points.append(previous)
    return points


def jerk(points: list[tuple[float, float]], fps: float = 60.0) -> float:
    """RMS magnitude of the third finite difference of `points`, in px/s^3.

    Fewer than 4 points give 0.0.
    """
    if len(points) < 4:
        return 0.0
    xs: list[float] = [p[0] for p in points]
    ys: list[float] = [p[1] for p in points]
    squares: list[float] = []
    for i in range(len(points) - 3):
        jx: float = xs[i + 3] - 3 * xs[i + 2] + 3 * xs[i + 1] - xs[i]
        jy: float = ys[i + 3] - 3 * ys[i + 2] + 3 * ys[i + 1] - ys[i]
        squares.append(jx * jx + jy * jy)
    return math.sqrt(sum(squares) / len(squares)) * fps**3


def render_sequence(project: Path, out_dir: Path, frames: int,
                    data: dict[str, str] | None = None) -> list[Path]:
    """Render `frames` frames of a Rive project, one `rive` run per frame, in frame order.

    Frame i is `--advance={i + 1}` (the CLI renders frame N - 1), saved as `f{i:03}.png`.
    Each `data` entry is passed as `--data=k=v` before the advance, i.e. as a starting value,
    which is how rive/tools/motion_review.py fires a gesture. `project` may be relative; it is
    resolved first, because the CLI runs with `cwd=project`. Raises
    subprocess.CalledProcessError only if the CLI exits non-zero: a runtime error that the CLI
    prints to stderr but exits 0 on is NOT detected, so callers (e.g. a search loop) must scan
    the output or guard against a static clip themselves.
    """
    project = project.resolve()
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for i in range(frames):
        path: Path = out_dir / f"f{i:03}.png"
        args: list[str] = ["rive", str(project), f"--screenshot={path}"]
        args += [f"--data={k}={v}" for k, v in (data or {}).items()]
        args.append(f"--advance={i + 1}")
        subprocess.run(args, cwd=project, check=True, capture_output=True, text=True)
        paths.append(path)
    return paths


def score(frames: list[Image.Image], rest: Image.Image) -> dict[str, float]:
    """Pop count (as a float), centroid jerk and loop seam of a sequence."""
    return {
        "pops": float(len(pops(frame_diffs(frames)))),
        "jerk": jerk(motion_centroids(frames, rest)),
        "seam": loop_seam(frames),
    }
