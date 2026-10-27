"""Tests for rive/tools/motion_metrics.py, using synthetic 64x64 frames."""

from __future__ import annotations

from pathlib import Path
import math
import subprocess
import sys
from typing import Any

from PIL import Image, ImageDraw
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import motion_metrics
from motion_metrics import frame_diffs, jerk, loop_seam, motion_centroids, pops, render_sequence, score

SIZE: int = 64
BOX: int = 8


def blank() -> Image.Image:
    return Image.new("RGB", (SIZE, SIZE), (0, 0, 0))


def square_at(x: int, y: int = 28) -> Image.Image:
    image: Image.Image = blank()
    ImageDraw.Draw(image).rectangle((x, y, x + BOX - 1, y + BOX - 1), fill=(255, 255, 255))
    return image


def square_moving_linearly(n: int) -> list[Image.Image]:
    return [square_at(i) for i in range(n)]


def square_teleports_at(k: int, n: int) -> list[Image.Image]:
    return [square_at(2 if i < k else 50) for i in range(n)]


def loop_frames() -> list[Image.Image]:
    return [square_at(10), square_at(14), square_at(18), square_at(14), square_at(10)]


def test_linear_motion_has_no_pops() -> None:
    assert pops(frame_diffs(square_moving_linearly(30))) == []


def test_teleport_is_a_pop() -> None:
    # Frame 14 is the last one before the jump, so the diff 14 -> 15 sits at index 14.
    assert pops(frame_diffs(square_teleports_at(15, n=30)), k=4.0) == [14]


def test_identical_loop_has_zero_seam() -> None:
    assert loop_seam(loop_frames()) == pytest.approx(0.0, abs=1e-6)


def test_loop_seam_zero_median_nonzero_seam_is_inf() -> None:
    frames: list[Image.Image] = [square_at(10)] * 5 + [square_at(40)]
    assert loop_seam(frames) == math.inf


def test_loop_seam_zero_median_zero_seam_is_zero() -> None:
    assert loop_seam([square_at(10)] * 6) == 0.0


def test_pops_empty_or_all_zero_is_empty() -> None:
    assert pops([]) == []
    assert pops([0.0, 0.0, 0.0]) == []


def test_linear_path_has_near_zero_jerk() -> None:
    assert jerk([(float(i), 0.0) for i in range(30)]) < 1e-6


def test_eased_path_has_less_jerk_than_snapping() -> None:
    n: int = 30
    eased: list[tuple[float, float]] = []
    for i in range(n):
        t: float = i / (n - 1)
        eased.append((100.0 * (3 * t * t - 2 * t**3), 0.0))
    snapped: list[tuple[float, float]] = [(0.0 if i < n // 2 else 100.0, 0.0) for i in range(n)]
    assert jerk(eased) < jerk(snapped)


def test_jerk_short_path_is_zero() -> None:
    assert jerk([(0.0, 0.0), (1.0, 1.0), (3.0, 3.0)]) == 0.0


def test_centroids_track_the_square() -> None:
    rest: Image.Image = blank()
    points: list[tuple[float, float]] = motion_centroids([square_at(10), square_at(20)], rest)
    assert points[0] == pytest.approx((10 + (BOX - 1) / 2, 28 + (BOX - 1) / 2))
    assert points[1][0] - points[0][0] == pytest.approx(10.0)


def test_centroid_without_motion_reuses_previous_then_image_centre() -> None:
    rest: Image.Image = blank()
    frames: list[Image.Image] = [blank(), square_at(10), blank()]
    points: list[tuple[float, float]] = motion_centroids(frames, rest)
    assert points[0] == (SIZE / 2, SIZE / 2)
    assert points[1] == pytest.approx((13.5, 31.5))
    assert points[2] == points[1]


def test_score_has_expected_keys() -> None:
    frames: list[Image.Image] = square_moving_linearly(20)
    result: dict[str, float] = score(frames, blank())
    assert set(result) == {"pops", "jerk", "seam"}
    assert result["pops"] == 0.0


def test_render_sequence_builds_args(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    calls: list[tuple[list[str], dict[str, Any]]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, kwargs))
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(motion_metrics.subprocess, "run", fake_run)
    project: Path = tmp_path / "proj"
    project.mkdir()
    out_dir: Path = tmp_path / "out" / "nested"
    paths: list[Path] = render_sequence(project, out_dir, 3, {"stiffness": "120"})

    assert out_dir.is_dir()
    assert [p.name for p in paths] == ["f000.png", "f001.png", "f002.png"]
    assert len(calls) == 3
    first_args, first_kwargs = calls[0]
    assert first_args[0] == "rive"
    assert f"--screenshot={out_dir.resolve() / 'f000.png'}" in first_args
    assert "--advance=1" in first_args
    assert "--data=stiffness=120" in first_args
    assert calls[2][0].count("--advance=3") == 1
    assert first_kwargs["cwd"] == project


def test_render_sequence_resolves_relative_project(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    calls: list[tuple[list[str], dict[str, Any]]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, kwargs))
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(motion_metrics.subprocess, "run", fake_run)
    (tmp_path / "rive" / "avatar").mkdir(parents=True)
    monkeypatch.chdir(tmp_path)
    render_sequence(Path("rive/avatar"), tmp_path / "out", 1)

    args, kwargs = calls[0]
    expected: Path = (tmp_path / "rive" / "avatar").resolve()
    assert Path(args[1]).is_absolute()
    assert Path(args[1]) == expected
    assert kwargs["cwd"] == expected


def test_render_sequence_raises_on_cli_failure(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        raise subprocess.CalledProcessError(1, args, "", "boom")

    monkeypatch.setattr(motion_metrics.subprocess, "run", fake_run)
    with pytest.raises(subprocess.CalledProcessError):
        render_sequence(tmp_path, tmp_path / "out", 2)
