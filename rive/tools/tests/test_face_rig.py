"""Tests for rive/tools/face_rig.py (pure Python: no Rive CLI needed).

    uv run --with pytest pytest rive/tools/tests/test_face_rig.py
"""

from __future__ import annotations

from pathlib import Path
import re
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import face_rig as fr  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CLOSED_AUS = ("auLipCornerPull", "auLipCornerDepress", "auLipStretch", "auLipPress", "auDimpler", "auCheekRaise")
UPPER_LOWER = (("UpperL", "LowerL"), ("UpperC", "LowerC"), ("UpperR", "LowerR"))


def test_rest_mouth_is_the_old_neutral_line() -> None:
    pose = fr.mouth_pose({})
    # the v4 neutral line: (383, 477) (400, 480) (417, 477)
    assert pose["CornerL"] == pytest.approx((383.0, 477.0))
    assert pose["CornerR"] == pytest.approx((417.0, 477.0))
    assert pose["UpperC"] == pytest.approx((400.0, 480.0))


@pytest.mark.parametrize("au", CLOSED_AUS)
def test_closed_mouth_aus_keep_the_lips_together(au: str) -> None:
    pose = fr.mouth_pose({au: 1.0})
    for up, low in UPPER_LOWER:
        assert pose[up] == pytest.approx(pose[low], abs=1e-9), (au, up)


def test_jaw_opens_and_legacy_mouth_is_an_alias() -> None:
    open_ = fr.mouth_pose({"auJawDrop": 1.0})
    assert open_["LowerC"][1] - open_["UpperC"][1] > 20
    legacy = fr.mouth_pose({"mouth": 4.0})
    expected = fr.mouth_pose({"auJawDrop": 4 * fr.JAW_PER_MOUTH})
    assert legacy["LowerC"] == pytest.approx(expected["LowerC"])


def test_smile_lifts_and_frown_drops_the_corners() -> None:
    rest = fr.mouth_pose({})
    smile = fr.mouth_pose({"auLipCornerPull": 1.0})
    frown = fr.mouth_pose({"auLipCornerDepress": 1.0})
    for c in ("CornerL", "CornerR"):
        assert smile[c][1] < rest[c][1] - 5
        assert frown[c][1] > rest[c][1] + 5
    # the frown is an arch: the centre sits above the corners and the mids
    assert frown["UpperC"][1] < frown["UpperR"][1] < frown["CornerR"][1]


def test_pucker_narrows_and_rounds() -> None:
    rest = fr.mouth_pose({})
    ou = fr.mouth_pose({"auLipPucker": 0.95, "auJawDrop": 0.25})
    width = ou["CornerR"][0] - ou["CornerL"][0]
    assert width < (rest["CornerR"][0] - rest["CornerL"][0]) * 0.7
    height = ou["LowerC"][1] - ou["UpperC"][1]
    assert height > 0.5 * width  # a round opening, not a slit


def test_mouth_is_mirror_symmetric() -> None:
    for env in ({"auLipCornerPull": 0.7, "auJawDrop": 0.4}, {"auLipPucker": 1.0}, {"auLipStretch": 1.0}):
        pose = fr.mouth_pose(env)
        for a, b in (("CornerL", "CornerR"), ("UpperL", "UpperR"), ("LowerL", "LowerR")):
            assert pose[a][0] - 400 == pytest.approx(400 - pose[b][0])
            assert pose[a][1] == pytest.approx(pose[b][1])


def test_lip_handles_follow_the_catmull_rom_tangent() -> None:
    order = ["CornerL", "UpperL", "UpperC", "UpperR", "CornerR", "LowerR", "LowerC", "LowerL"]
    h = fr.lip_handles(order)
    assert set(h) == {"UpperL", "UpperC", "UpperR", "LowerR", "LowerC", "LowerL"}
    k_in, k_out, prv, nxt = h["UpperC"]
    assert (prv, nxt) == ("UpperL", "UpperR")
    assert k_in == pytest.approx(k_out)  # symmetric neighbours
    assert k_out == pytest.approx(fr.LIP_TENSION / 6)


def test_generated_avatar_declares_every_v5_property() -> None:
    rml = (ROOT / "rive" / "avatar" / "avatar.rml").read_text()
    for name in (*fr.NUMBERS, "autoBlink", "blink"):
        assert re.search(rf'name="{name}"', rml), name
    # the old mouth Solos are gone; the continuous mouth exists
    assert 'name="OpenShape"' not in rml and 'name="LineShape"' not in rml
    for name in ("MouthInside", "MouthLine", "MouthTeeth", "MouthTongue", "BreathLift", "HeadRoll"):
        assert f'name="{name}"' in rml, name
