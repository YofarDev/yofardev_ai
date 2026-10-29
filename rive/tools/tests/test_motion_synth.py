"""Tests for rive/tools/motion_synth.py (moonshot M4 ruling 15)."""

from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from motion_synth import EASES, Beat, action, sample, shifted, stagger, to_track_keys


def test_action_anticipates_overshoots_and_settles() -> None:
    keys = action(Beat(0, 30, 0, 100))
    values: list[float] = [sample(keys, f / 4) for f in range(0, 60 * 4)]
    assert abs(min(values) + 18) <= 1
    assert abs(max(values) - 112) <= 1
    assert keys[-1][0] <= 30 + 13
    assert keys[-1][1] == 100
    assert keys[-1][2] == "hold"
    assert all(sample(keys, f) == 100 for f in range(keys[-1][0], 80))


def test_action_extremes_are_the_keys() -> None:
    keys = action(Beat(10, 24, 50, -30))
    values: list[float] = [sample(keys, 10 + f / 8) for f in range(0, 60 * 8)]
    lo: float = min(k[1] for k in keys)
    hi: float = max(k[1] for k in keys)
    assert min(values) >= lo - 1e-9 and max(values) <= hi + 1e-9
    assert keys[0] == (10, 50.0, "easeInOut")


def test_zero_travel_beat_is_two_keys() -> None:
    keys = action(Beat(5, 20, 3, 3))
    assert len(keys) == 2
    assert [k[1] for k in keys] == [3, 3]


def test_stagger_rounds_cumulative_offsets() -> None:
    assert stagger(["head", "torso", "hair"]) == {"head": 0, "torso": 2, "hair": 5}


def test_shift_and_track_mapping() -> None:
    keys = action(Beat(0, 30, 0, 1))
    moved = shifted(keys, 4)
    assert [k[0] for k in moved] == [k[0] + 4 for k in keys]
    mapped = to_track_keys(keys, lambda name: f"<{name}>")
    assert all(m[2] in ("hold", "linear") or m[2].strip("<>") in EASES for m in mapped)
