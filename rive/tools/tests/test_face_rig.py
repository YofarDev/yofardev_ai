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


# ------------------------------------------------------------------ eyes on lid bones (M3)

HAPPY = {"auCheekRaise": 0.6, "auLidTighten": 0.5, "auLipCornerPull": 0.7, "auBrowOuterUp": 0.3}
SAD = {"auBrowInnerUp": 0.75, "auBrowLower": 0.2, "auLidTighten": 0.05, "auLipCornerDepress": 0.9}
ANGRY = {"auBrowLower": 0.9, "auLidTighten": 0.7}
SURPRISED = {"auBrowInnerUp": 0.9, "auBrowOuterUp": 0.9, "auUpperLidRaise": 1.0}
LID_POSES = [{}, HAPPY, SAD, ANGRY, SURPRISED, {"auCheekRaise": 1.0, "auLidTighten": 1.0},
             {"auBrowInnerUp": 1.0, "eyeLeadPitch": -1.0, "auLidTightenL": 1.0, "auCheekRaiseR": -0.5}]
IRIS_BOTTOM = 388.0 + 18.0  # the iris is a 32 x 36 ellipse at y 388 (eye art space)


def _y(pose: dict, n: str) -> float:
    return pose[n][1]


@pytest.mark.parametrize("env", LID_POSES)
@pytest.mark.parametrize("s", (-1, 1))
def test_blink_closes_exactly_onto_the_current_lower_lid(env: dict, s: int) -> None:
    closed = fr.lid_pose(env, s, blink=1.0)
    up, low = fr.lid_edge(closed, "Upper"), fr.lid_edge(closed, "Lower")
    for a, b in zip(up, low):
        assert a == pytest.approx(b, abs=1e-9)
    # the lower lid does not move in a blink: the eye closes onto the AU pose and reopens to it
    open_ = fr.lid_pose(env, s)
    for n in open_:
        if not n.startswith("Upper"):
            assert closed[n] == pytest.approx(open_[n])


@pytest.mark.parametrize("env", LID_POSES)
def test_half_blink_is_halfway(env: dict) -> None:
    o, h, c = (fr.lid_pose(env, 1, blink=b) for b in (0.0, 0.5, 1.0))
    for n in o:
        assert _y(h, n) == pytest.approx((_y(o, n) + _y(c, n)) / 2)


@pytest.mark.parametrize("env", LID_POSES)
def test_an_au_pose_alone_never_closes_or_crosses_the_lids(env: dict) -> None:
    p = fr.lid_pose(env, -1)
    for col in fr.LID_COLS:
        assert _y(p, "Upper" + col) <= _y(p, "Lower" + col) - fr.LID_GAP + 1e-9


def test_rest_opening_frames_the_iris() -> None:
    p = fr.lid_pose({}, 1)
    assert 368.0 < _y(p, "UpperMid") < 388.0 - 14.0  # the lid trims the iris top, under the lens frame
    assert 400.0 < _y(p, "LowerMid") <= IRIS_BOTTOM


def test_cheek_raise_bows_the_lower_lid_up_into_a_crescent() -> None:
    p = fr.lid_pose(HAPPY, 1)
    mid, inner, outer = _y(p, "LowerMid"), _y(p, "LowerInner"), _y(p, "LowerOuter")
    assert mid < inner < _y(p, "CornerIn") and mid < outer < _y(p, "CornerOut")  # an arch (y down)
    # the lower lid covers the lower half of the iris and more
    assert max(y for _, y in fr.lid_edge(p, "Lower")) < 392.0
    assert mid < IRIS_BOTTOM - 18.0
    # its middle rises more than its ends
    rest = fr.lid_pose({}, 1)
    assert rest["LowerMid"][1] - mid > rest["LowerInner"][1] - inner + 3.0


def test_sad_droops_the_outer_lid_and_angry_the_inner() -> None:
    rest, sad, angry = fr.lid_pose({}, 1), fr.lid_pose(SAD, 1), fr.lid_pose(ANGRY, 1)
    drop = {n: _y(sad, "Upper" + n) - _y(rest, "Upper" + n) for n in fr.LID_COLS}
    assert drop["Outer"] > 6.0 and drop["Outer"] > 2 * drop["Inner"]
    drop = {n: _y(angry, "Upper" + n) - _y(rest, "Upper" + n) for n in fr.LID_COLS}
    assert drop["Inner"] > 6.0 and drop["Inner"] > 2 * drop["Outer"]


def test_surprise_opens_the_eye_without_the_sad_droop() -> None:
    rest, sur = fr.lid_pose({}, 1), fr.lid_pose(SURPRISED, 1)
    for n in fr.LID_COLS:
        assert _y(sur, "Upper" + n) <= _y(rest, "Upper" + n) + 1e-9
    assert _y(sur, "LowerMid") > _y(rest, "LowerMid")


def test_looking_down_drops_only_the_upper_lids() -> None:
    rest, down, up = fr.lid_pose({}, 1), fr.lid_pose({"eyeLeadPitch": -1.0}, 1), fr.lid_pose({"eyeLeadPitch": 1.0}, 1)
    assert _y(down, "UpperMid") - _y(rest, "UpperMid") > 8.0
    assert _y(down, "LowerMid") == pytest.approx(_y(rest, "LowerMid"))
    assert up == rest


def test_side_offsets_act_on_their_own_side_and_clamp() -> None:
    env = {"auLidTighten": 0.5, "auLidTightenL": 1.0}
    left, right = fr.lid_pose(env, -1), fr.lid_pose(env, 1)
    full = fr.lid_pose({"auLidTighten": 1.0}, -1)
    assert left == full  # 0.5 + 1 clamps at 1
    assert right == fr.lid_pose({"auLidTighten": 0.5}, 1)
    assert fr.lid_pose({"auCheekRaise": 0.3, "auCheekRaiseR": -1.0}, 1) == fr.lid_pose({}, 1)


def test_lid_handles_follow_the_rest_tangent() -> None:
    bones = fr.lid_bones()
    for row in ("Upper", "Lower"):
        for c in fr.LID_COLS:
            (u, y, _), (iu, iy, _), (ou, oy, _) = (bones[row + c + t] for t in ("", "In", "Out"))
            assert iu < u < ou
            # in and out handles are collinear with the vertex (a smooth rest curve)
            assert (iy - y) * (ou - u) == pytest.approx((oy - y) * (iu - u), abs=1e-6)


# ---- the generated file: formulas equal the model, blinks drive the constraints

def _rml() -> "ET.Element":
    import xml.etree.ElementTree as ET
    return ET.parse(ROOT / "rive" / "avatar" / "avatar.rml").getroot()


def _eval_formula(tokens: list, inp: float, env: dict, paths: dict) -> float:
    """A small evaluator of DataConverterFormula tokens (+ - * /, min, max; left to right with
    * and / binding tighter)."""
    pos = 0

    def atom() -> float:
        nonlocal pos
        t = tokens[pos]
        pos += 1
        tag = t.tag
        if tag == "FormulaTokenInput":
            return inp
        if tag == "FormulaTokenValue":
            ctx = t.find("DataBindContext")
            return env.get(paths[ctx.get("sourcePathIds")], 0.0) if ctx is not None else float(t.get("operationValue", 0))
        if tag == "FormulaTokenFunction":
            args = [expr()]
            while tokens[pos].tag == "FormulaTokenArgumentSeparator":
                pos += 1
                args.append(expr())
            assert tokens[pos].tag == "FormulaTokenParenthesisClose"
            pos += 1
            return {"0": min, "1": max}[t.get("functionType")](*args)
        raise AssertionError(tag)

    def term() -> float:
        nonlocal pos
        v = atom()
        while pos < len(tokens) and tokens[pos].tag == "FormulaTokenOperation" and tokens[pos].get("operationType") in ("2", "3"):
            op = tokens[pos].get("operationType")
            pos += 1
            r = atom()
            v = v * r if op == "2" else v / r
        return v

    def expr() -> float:
        nonlocal pos
        v = term()
        while pos < len(tokens) and tokens[pos].tag == "FormulaTokenOperation":
            op = tokens[pos].get("operationType")
            pos += 1
            r = term()
            v = v + r if op == "0" else v - r
        return v

    out = expr()
    assert pos == len(tokens)
    return out


@pytest.mark.parametrize("env", LID_POSES)
def test_generated_lid_formulas_match_the_model(env: dict) -> None:
    root = _rml()
    vm = next(e for e in root if e.tag == "ViewModel")
    paths = {f"{vm.get('id')}-{p.get('id')}": p.get("name") for p in vm if p.tag == "ViewModelPropertyNumber"}
    convs = {c.get("id"): c for c in root if c.tag == "DataConverterFormula"}
    bones = list(fr.lid_bones())
    seen = 0
    for blink in (e for e in root.iter("Node") if e.get("name") == "Blink"):
        bone_els = {b.get("name"): b for b in blink if b.tag == "RootBone"}
        side = -1 if any(float(b.get("x")) > 20 for n, b in bone_els.items() if n == "CornerIn") else 1
        model = fr.lid_pose(env, side)
        for n in bones:
            ctx = bone_els[n].find("DataBindContext")
            assert ctx.get("propertyKey") == "91"
            src = paths[ctx.get("sourcePathIds")]
            y = _eval_formula(list(convs[ctx.get("converterId")]), env.get(src, 0.0), env, paths)
            assert y + fr.EYE_FRAME_DY == pytest.approx(model[n][1], abs=2e-3), (n, side)
            seen += 1
    assert seen == 2 * len(bones)


def test_blinks_key_only_the_blink_drives_and_the_overlays_are_gone() -> None:
    root = _rml()
    rml = (ROOT / "rive" / "avatar" / "avatar.rml").read_text()
    for gone in ("Droop", "DroopLash", "Squint", "SquintLine", "ClosedLash", "LashMove", "LidSkin", "LookDownLid",
                 "LashDrop"):
        assert not re.search(rf'name="{gone}[LR]?"', rml), gone
    drives = {e.get("id") for e in root.iter("TranslationConstraint") if e.get("name") == "BlinkDrive"}
    assert len(drives) == 2 * 3 * 3  # two eyes x three columns x (vertex, in, out)
    for anim in root.iter("LinearAnimation"):
        if anim.get("name") not in ("idle_blink", "blink_hold", "blink_once"):
            continue
        keyed = {(o.get("objectId"), p.get("property")) for o in anim.iter("KeyedObject") for p in o}
        assert keyed == {(i, "strength") for i in drives}, anim.get("name")
        vals = [float(k.get("value")) for k in anim.iter("KeyFrameDouble")]
        assert min(vals) == 0.0 and max(vals) <= 1.0


def test_generated_avatar_declares_the_v6_side_numbers() -> None:
    rml = (ROOT / "rive" / "avatar" / "avatar.rml").read_text()
    assert len(fr.SIDE_NUMBERS) == 14
    for name in fr.SIDE_NUMBERS:
        assert re.search(rf'<ViewModelPropertyNumber name="{name}"', rml), name
