"""M3 critic round 3 (face): hidden lid creases, tapered lash ends, the wing off the lens rim, steep
lower teeth, fringe flicks, and the 3/4 near lock over the ear.

    uv run --with pytest pytest rive/tools/tests/test_critic_round3.py
"""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_kit as kit  # noqa: E402
import face_rig as fr  # noqa: E402
import head_turn as ht  # noqa: E402
import rig_dsl as r  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]


def _rml() -> ET.Element:
    return ET.parse(ROOT / "rive" / "avatar" / "avatar.rml").getroot()


# ---- 1. the lid crease hides at rest and fades in with a brow raise

@pytest.mark.parametrize("side", ["L", "R"])
def test_crease_hidden_at_rest_and_with_small_raises(side: str) -> None:
    assert fr.crease_opacity({}, side) == 0.0
    assert fr.crease_opacity({"auBrowOuterUp": 0.3, "auCheekRaise": 0.6}, side) == 0.0  # happy
    assert fr.crease_opacity({"auBrowLower": 1.0}, side) == 0.0
    assert fr.crease_opacity({"auBrowInnerUp": 0.35}, side) == 0.0


@pytest.mark.parametrize("side", ["L", "R"])
def test_crease_full_from_a_strong_raise_of_either_brow_end(side: str) -> None:
    assert fr.crease_opacity({"auBrowInnerUp": 0.8}, side) == pytest.approx(1.0)
    assert fr.crease_opacity({"auBrowOuterUp": 1.0}, side) == 1.0
    assert 0.0 < fr.crease_opacity({"auBrowOuterUp": 0.6}, side) < 1.0


def test_crease_reads_the_side_offsets() -> None:
    env = {"auBrowInnerUp": 0.2, "auBrowInnerUpL": 0.8}
    assert fr.crease_opacity(env, "L") == 1.0
    assert fr.crease_opacity(env, "R") == 0.0


def test_crease_shapes_bind_opacity_and_rest_hidden() -> None:
    creases = [e for e in _rml().iter("Shape") if e.get("name") == "Crease" and e.get("opacity") is not None]
    assert len(creases) == 2
    for c in creases:
        assert float(c.get("opacity")) == 0.0
        assert any(b.get("propertyKey") == "18" for b in c.findall("DataBindContext"))
        assert c.find("Fill") is not None and c.find("Stroke") is None  # a band, not a capped stroke


# ---- 3. open strokes taper to the legibility floor

def test_crease_band_tapers_to_the_floor_at_both_ends() -> None:
    band = fr.crease_band(445.0, 1)
    ends = [(band[0], band[5]), (band[2], band[3])]
    for a, b in ends:
        assert math.dist(a[:2], b[:2]) == pytest.approx(fr.END_W / 1.06, abs=0.01)
    assert math.dist(band[1][:2], band[4][:2]) == pytest.approx(fr.CREASE_W, abs=0.01)


def test_lash_inner_end_is_a_tapered_point() -> None:
    assert fr.LASH_T["In"] <= fr.END_W  # the band at the inner corner: the floor, not a square cut
    assert fr.LASH_IN_BACK >= 1.5  # its top point sits back along the line


# ---- 4. the wing stays off the lens rim

def test_lash_wing_keeps_clear_of_the_lens_side_rim() -> None:
    # the eye is drawn at 1.06 about its centre; the clear lens's inner side edge (art space)
    wing_x = 445.0 + fr.WING[0] * 1.06
    inner_side = 445.0 + kit.LENS_W / 2 - kit.RIM_SIDE
    # round 3 pulled the flick in 1 px (eye space): the rendered closed-lid gap to the rim went from
    # 4.5 to 5.5-6 artboard px (~6 px at 1080); this flat estimate ignores the eye's mood transforms
    assert fr.WING[0] <= 35.0
    assert inner_side - wing_x >= 3.5


# ---- 5. the lower teeth are shown or hidden, not half

def test_lower_teeth_ramp_is_steep() -> None:
    lo, hi = fr.LOW_TEETH_RAMP
    assert hi - lo <= 0.12
    assert hi <= 0.45 and lo >= 0.2  # ih (stretch 0.45) shows them fully, dd (0.2) not at all


# ---- 6. fringe flicks

def test_two_locks_flick_their_tips_outward() -> None:
    assert len(kit.FRINGE_FLICK) == 2
    for i, f in kit.FRINGE_FLICK.items():
        root_, tip, w, bend = kit.FRINGE_LOCKS[i]
        _, at = kit.lock_outline(root_, tip, w, bend, f)
        _, plain = kit.lock_outline(root_, tip, w, bend)
        moved = at(1.0, 0.0)[0] - plain(1.0, 0.0)[0]
        outward = -1 if tip[0] < 400 else 1
        assert moved * outward >= 5  # the tip flicks away from the face's centre
        assert at(0.5, 0.0) == pytest.approx(plain(0.5, 0.0))  # the lock's upper half is unchanged


def test_tip_radius_in_the_bible_band() -> None:
    assert 0.18 <= kit.TIP_R <= 0.24


def test_fringe_widths_vary() -> None:
    ws = [w for _, _, w, _ in kit.FRINGE_LOCKS]
    assert max(ws) / min(ws) >= 1.8
    assert len(set(ws)) >= 6


# ---- 2. 3/4: the near side lock covers the ear's front, the far side features ride the flat cheek

def test_near_side_lock_moves_out_over_the_ear() -> None:
    assert ht.SIDE_LOCK_NEAR_OUT >= 8
    ear_shift = r.eval_poly(ht.mat(512.0, ht.EAR_Z), -ht.K_YAW)  # the right ear at yaw -1 (near)
    assert ht.SIDE_LOCK_NEAR_OUT > ear_shift  # the lock no longer slides inward off the ear


@pytest.mark.parametrize("x", [456.0, 465.0, 335.0])
def test_far_cheek_marks_ride_in_with_the_flattening(x: float) -> None:
    y = 434.0
    z = ht.face_z(x, y)
    a = ht.K_YAW if x > ht.CX else -ht.K_YAW
    plain, flat = r.eval_poly(ht.mat(x, z), a), r.eval_poly(ht.face_point(x, y, z), a)
    side = 1 if x > ht.CX else -1
    assert side * (plain - flat) >= 8  # pulled in toward the nose on the far side
    assert r.eval_poly(ht.face_point(x, y, z), 0.0) == pytest.approx(0.0, abs=1e-3)


def test_face_point_equals_material_where_nothing_flattens() -> None:
    z = ht.face_z(445.0, 360.0)
    for a in (-ht.K_YAW, ht.K_YAW):
        assert r.eval_poly(ht.face_point(445.0, 360.0, z), a) == pytest.approx(r.eval_poly(ht.mat(445.0, z), a), abs=0.01)
