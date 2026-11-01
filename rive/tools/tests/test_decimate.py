"""Tests for the error-bounded key decimation in rive/tools/rml.py (M4 ruling 1)."""

from __future__ import annotations

import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from rml import TOLERANCES, Doc, El, decimate, decimate_property, decimate_tree, track  # noqa: E402


def _lerp_error(keys: list[tuple[int, float]], kept: list[tuple[int, float]]) -> float:
    worst = 0.0
    for f, v in keys:
        for (f0, v0), (f1, v1) in zip(kept, kept[1:]):
            if f0 <= f <= f1:
                worst = max(worst, abs(v - (v0 + (v1 - v0) * (f - f0) / (f1 - f0))))
                break
    return worst


def test_tolerances_match_the_plan() -> None:
    assert TOLERANCES == {"rotation": 0.002, "x": 0.25, "y": 0.25, "scaleX": 0.002, "scaleY": 0.002,
                          "opacity": 0.002}


def test_a_straight_ramp_keeps_its_two_ends() -> None:
    keys = [(f, 3.0 + 0.5 * f) for f in range(60)]
    assert decimate(keys, 0.002) == [keys[0], keys[-1]]


def test_a_sine_keeps_every_peak_within_tolerance() -> None:
    keys = [(f, math.sin(2 * math.pi * f / 60)) for f in range(121)]
    tol = TOLERANCES["rotation"]
    kept = decimate(keys, tol)
    frames = {f for f, _ in kept}
    assert {15, 45, 75, 105} <= frames
    assert kept[0] == keys[0] and kept[-1] == keys[-1]
    assert len(kept) < len(keys)
    assert _lerp_error(keys, kept) <= tol


def test_zero_tolerance_keeps_everything() -> None:
    keys = [(f, 0.1 * f) for f in range(10)]
    assert decimate(keys, 0.0) == keys


def _prop(d: Doc, prop: str, keys: list[tuple[int, float, str]]) -> El:
    obj = track(d, d("Node", name="N"), {prop: keys})
    return obj.children[0]


def test_hold_and_cubic_keys_inside_a_run_survive() -> None:
    d = Doc()
    keys = [(f, 2.0 * f, "linear") for f in range(20)]
    keys[8] = (8, 16.0, "hold")
    keys[14] = (14, 28.0, "cubic")
    prop = _prop(d, "x", keys)
    decimate_property(prop)
    frames = [k.attrs["frame"] for k in prop.children]
    # runs 0..8 and 9..14 and 15..19 are straight: only their ends (and the hold/cubic keys) stay
    assert frames == [0, 8, 9, 14, 15, 19]


def test_untoleranced_properties_keep_every_key() -> None:
    d = Doc()
    prop = _prop(d, "inDistance", [(f, 1.0, "linear") for f in range(10)])
    assert decimate_property(prop) == 0
    assert len(prop.children) == 10


def test_kept_keys_keep_their_ids_and_output_is_deterministic() -> None:
    def build() -> tuple[El, dict[int, str]]:
        d = Doc(start=500)
        obj = track(d, d("Node", name="N"), {"rotation": [(f, 0.3 * math.sin(f / 9)) for f in range(90)]})
        before = {k.attrs["frame"]: k.ref() for k in obj.children[0].children}
        return obj, before

    a, ids_a = build()
    b, _ = build()
    assert decimate_tree(a) == decimate_tree(b) > 0
    kept_a = [(k.attrs["frame"], k.ref()) for k in a.children[0].children]
    kept_b = [(k.attrs["frame"], k.ref()) for k in b.children[0].children]
    assert kept_a == kept_b
    assert all(ids_a[f] == i for f, i in kept_a)
