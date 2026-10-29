"""Tests for rive/tools/avatar_light.py and the v7 view-model defaults (moonshot M4 Task 4)."""

from __future__ import annotations

from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_light as al
from art_bible import SCENES
import check_contract
import gen_scenes


def test_avatar_light_defaults_are_the_living_room_rig() -> None:
    s = SCENES["livingRoom"]
    want = {"lightKey": s.key, "lightKeyIntensity": s.key_intensity, "lightKeyX": -0.737, "lightKeyY": 0.675,
            "lightRim": s.rim, "lightRimIntensity": 0.35, "lightAmbient": s.ambient,
            "lightAmbientAmount": 0.35, "lightFlicker": 0.15}
    assert {k: v for k, (_, v) in al.LIGHT_DEFAULTS.items()} == want


def test_flicker_loops_seamlessly_inside_its_range() -> None:
    vals = [al.flicker(f) for f in range(al.FLICKER_FRAMES + 1)]
    assert vals[0] == vals[-1]
    lo, hi = al.FLICKER_RANGE
    assert min(vals) >= lo - 1e-3 and max(vals) <= hi + 1e-3
    assert max(vals) - min(vals) > 0.3  # it does flicker
    # the step across the seam is no bigger than any other step (no pop)
    steps = [abs(b - a) for a, b in zip(vals, vals[1:])]
    seam = abs(al.flicker(1) - al.flicker(al.FLICKER_FRAMES - 1 + 1))
    assert seam <= max(steps)
    assert all(k in (2, 3, 5, 7, 11, 13) for k, _, _ in al.FLICKER_HARMONICS)


def test_lean_tips_at_most_four_degrees_and_drops_the_head_up_to_ten_px() -> None:
    assert al.lean_head_drop(0) == 0
    assert 6.0 <= al.lean_head_drop(1) <= 10.0
    assert 0 < al.lean_tip_degrees(1) <= 4.0
    assert al.lean_head_drop(0.5) < al.lean_head_drop(1)


def test_rim_band_is_the_interior_weight() -> None:
    assert math.isclose(al.RIM_W, 1.56)


def test_contract_scene_vm_matches_the_scene_generator() -> None:
    c = check_contract.parse_contract()
    names = [n for n in c["scene_vm_props"] if n not in ("eventId", "event")]
    for sid in SCENES:
        gen = gen_scenes.scene_vm_defaults(sid)
        assert [n for n, _, _ in gen] == names
        assert {n: t for n, t, _ in gen} == {n: c["scene_vm_props"][n] for n in names}
        want = {**check_contract.scene_light_defaults(sid), "rain": 0.0}
        assert {n: v for n, _, v in gen} == want
