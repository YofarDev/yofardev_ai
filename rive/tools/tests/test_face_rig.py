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
CLOSED_AUS = ("auLipCornerPull", "auLipCornerDepress", "auLipPress", "auDimpler", "auCheekRaise")
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


def test_stretch_parts_the_lips_and_press_seals_them() -> None:
    ss = fr.mouth_pose({"auLipStretch": 0.55})
    assert ss["LowerC"][1] - ss["UpperC"][1] > 5
    # angry: stretch 0.3 + press 0.6 stays one line (the squared mouth is closed)
    angry = fr.mouth_pose({"auLipStretch": 0.3, "auLipPress": 0.6, "auLipCornerDepress": 0.35})
    for up, low in UPPER_LOWER:
        assert angry[up] == pytest.approx(angry[low], abs=1e-9), up


def test_lip_tuck_needs_the_jaw_open() -> None:
    """f / v (tuck with the jaw a little open) is the full tuck; a tuck on a closed jaw rolls the
    lips in: no lift, no gap, the lips stay one line (critic round 1: it showed a pink band)."""
    assert fr.amount(FF, fr.TUCK) == pytest.approx(1.0)
    assert fr.amount({"lipTuck": 1.0}, fr.TUCK) == 0.0
    assert fr.amount({"lipTuck": 0.5, "auJawDrop": 0.03}, fr.TUCK) == pytest.approx(0.24)
    tuck = fr.mouth_pose({"lipTuck": 1.0})
    for up, low in UPPER_LOWER:
        assert tuck[up] == pytest.approx(tuck[low], abs=1e-9), up
    rest = fr.mouth_pose({})
    assert tuck["CornerR"][0] < rest["CornerR"][0] and tuck["CornerL"][0] > rest["CornerL"][0]


def test_nose_wrinkle_lifts_the_upper_lip_a_little() -> None:
    nw, rest = fr.mouth_pose({"auNoseWrinkle": 1.0}), fr.mouth_pose({})
    lift = rest["UpperC"][1] - nw["UpperC"][1]
    assert 2.0 < lift < 4.5
    assert nw["LowerC"] == pytest.approx(rest["LowerC"])
    assert len(fr.NOSE_CREASES) == 3 and fr.NOSE_CREASE_W == 1.8


def test_pseudo_amounts() -> None:
    assert fr.amount({"auLipStretch": 0.55}, fr.PART) == pytest.approx(0.55)
    assert fr.amount({"auLipStretch": 0.3, "auLipPress": 0.6}, fr.PART) == 0.0
    assert fr.amount({"auLipStretch": 0.3, "auLipPress": 0.6}, fr.TENSE) == pytest.approx(0.75)
    assert fr.amount({"auLipPress": 0.75}, fr.TENSE) == 0.0  # p / b / m are not tense
    assert fr.amount({"auBrowLower": 1.0, "auBrowLowerL": 1.0}, "auBrowLower|L") == 1.0
    assert fr.amount({"auBrowLower": 1.0, "auBrowLowerR": -1.0}, "auBrowLower|R") == 0.0
    assert fr.amount({"auBrowLower": 0.2, "auBrowLowerR": 0.3}, "auBrowLower|R") == pytest.approx(0.5)


# ---- f / v vs s (the Dart viseme table, lib/core/models/performance/mouth_shape.dart)

FF = {"auJawDrop": 0.14, "auLipStretch": 0.1, "lipTuck": 1.0}
SS = {"auJawDrop": 0.14, "auLipStretch": 0.55}


def test_ff_lifts_the_lower_lip_onto_the_upper_teeth_edge() -> None:
    ff = fr.mouth_pose(FF)
    for n in ("LowerL", "LowerC", "LowerR"):
        x, y = ff[n]
        edge = fr.teeth_edge_y(x)
        assert edge - 2.0 < y < edge + 0.5, n  # the band's top edge meets the teeth edge
    # the upper lip lifts off the teeth: a strip of upper teeth shows above the band
    assert fr.teeth_edge_y(400.0) - ff["UpperC"][1] > 4.0


def test_ss_shows_both_teeth_rows_with_the_lower_lip_down() -> None:
    ss, ff = fr.mouth_pose(SS), fr.mouth_pose(FF)
    low_top = ss["JawTeeth"][1]  # the lower teeth's top edge at x = 400
    assert fr.teeth_edge_y(400.0) - ss["UpperC"][1] > 4.0  # upper teeth
    assert ss["LowerC"][1] - low_top > 1.5  # lower teeth
    assert 0.5 < low_top - fr.teeth_edge_y(400.0) < 2.5  # teeth together: a thin gap
    assert ss["LowerC"][1] - ff["LowerC"][1] > 4.0  # the lower lip: down for s, up for f
    width = lambda p: p["CornerR"][0] - p["CornerL"][0]  # noqa: E731
    assert width(ss) > width(ff) + 6.0  # s stretches


def test_teeth_edges_are_single_arcs() -> None:
    xs = [366 + k for k in range(69)]
    for edge in (fr.TEETH_EDGE, fr.LOW_TEETH_TOP):
        ys = [fr.teeth_edge_y(x, edge) for x in xs]
        top = ys.index(max(ys))
        assert xs[top] == 400  # one extremum, at the centre: no notch
        assert all(a <= b for a, b in zip(ys[:top], ys[1:top + 1]))
        assert all(a >= b for a, b in zip(ys[top:], ys[top + 1:]))
    # the lower teeth sit just behind the upper edge everywhere (they overlap, never gap)
    for x in xs:
        assert 0.0 < fr.teeth_edge_y(x) - fr.teeth_edge_y(x, fr.LOW_TEETH_TOP) < 1.0


def test_pucker_lips_close_in_not_open_up() -> None:
    rest, k = fr.mouth_pose({}), fr.mouth_pose({"auLipPucker": 1.0})
    assert k["CornerR"][0] - k["CornerL"][0] < 0.5 * (rest["CornerR"][0] - rest["CornerL"][0])
    assert k["LowerC"][1] - k["UpperC"][1] < 3.0  # a small opening; the cushion carries the shape


# ---- per-side (contract v6)

def test_one_sided_corner_pull_is_a_smirk() -> None:
    rest, smirk = fr.mouth_pose({}), fr.mouth_pose({"auLipCornerPullL": 1.0})
    full = fr.mouth_pose({"auLipCornerPull": 1.0})
    assert smirk["CornerL"] == pytest.approx(full["CornerL"])
    assert smirk["CornerR"] == pytest.approx(rest["CornerR"])
    assert smirk["UpperL"] == pytest.approx(full["UpperL"]) and smirk["UpperR"] == pytest.approx(rest["UpperR"])
    # the centre moves halfway, so the lip line runs smoothly from the raised corner to the other
    for n in ("UpperC", "LowerC"):
        assert smirk[n][1] == pytest.approx((rest[n][1] + full[n][1]) / 2)


def _flat(pose: dict) -> list[float]:
    return [v for k in sorted(pose) for v in pose[k]]


SIDE_CASES = [(au, side) for au in sorted(fr.SIDED) for side in ("L", "R")]


@pytest.mark.parametrize("au,side", SIDE_CASES)
def test_the_clamp_case_equals_the_plain_full_side_pose(au: str, side: str) -> None:
    other = "R" if side == "L" else "L"
    clamp = {au: 1.0, au + side: 1.0, au + other: -1.0}
    plain = {au + side: 1.0}
    assert _flat(fr.mouth_pose(clamp)) == pytest.approx(_flat(fr.mouth_pose(plain)))
    for s_ in (-1, 1):
        assert _flat(fr.brow_pose(clamp, s_)) == pytest.approx(_flat(fr.brow_pose(plain, s_)))
        assert _flat(fr.lid_pose(clamp, s_)) == pytest.approx(_flat(fr.lid_pose(plain, s_)))


@pytest.mark.parametrize("au,side", SIDE_CASES)
def test_an_offset_moves_only_its_own_side(au: str, side: str) -> None:
    env = {au + side: 1.0}
    s_own, s_other = (-1, 1) if side == "L" else (1, -1)
    assert _flat(fr.brow_pose(env, s_other)) == pytest.approx(_flat(fr.brow_pose({}, s_other)))
    assert _flat(fr.lid_pose(env, s_other)) == pytest.approx(_flat(fr.lid_pose({}, s_other)))
    moved = _flat(fr.brow_pose(env, s_own)) != pytest.approx(_flat(fr.brow_pose({}, s_own))) or \
        _flat(fr.lid_pose(env, s_own)) != pytest.approx(_flat(fr.lid_pose({}, s_own))) or \
        _flat(fr.mouth_pose(env)) != pytest.approx(_flat(fr.mouth_pose({})))
    assert moved
    m, rest = fr.mouth_pose(env), fr.mouth_pose({})
    far = "R" if side == "L" else "L"  # the other side's mouth bones stay at rest
    for n in ("Corner", "Upper", "Lower"):
        assert m[n + far] == pytest.approx(rest[n + far]), n


def test_no_bone_passes_its_full_pose() -> None:
    for au in fr.SIDED:
        for side in ("L", "R"):
            over = {au: 1.0, au + side: 1.0}
            full = {au: 1.0}
            assert _flat(fr.mouth_pose(over)) == pytest.approx(_flat(fr.mouth_pose(full)))
            for s_ in (-1, 1):
                assert _flat(fr.brow_pose(over, s_)) == pytest.approx(_flat(fr.brow_pose(full, s_)))
            under = {au + side: -1.0}
            assert _flat(fr.mouth_pose(under)) == pytest.approx(_flat(fr.mouth_pose({})))


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
    for name in ("MouthInside", "MouthLine", "MouthTeeth", "MouthTongue", "BreathLift", "HeadRoll", "LowerLipBand",
                 "LipRim", "ChinBulge", "TenseCreaseL", "NoseWrinkle0", "NoseWrinkle1", "BreathShoulderR",
                 "BreathShoulderL", "ChinLightJaw"):
        assert f'name="{name}"' in rml, name
    assert 'name="MouthThroat"' not in rml  # one flat interior colour
    # one lip treatment: no lip cushion cross-fades over the opening (critic round 1)
    assert 'name="PuckerLips"' not in rml and 'name="PuckerShine"' not in rml


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
    p = fr.lid_pose({"auCheekRaise": 1.0}, 1)
    mid, inner, outer = _y(p, "LowerMid"), _y(p, "LowerInner"), _y(p, "LowerOuter")
    assert mid <= inner < _y(p, "CornerIn") and mid <= outer + 1.5 and outer < _y(p, "CornerOut")  # an arch (y down)
    # happy (0.6): the bowl of the rest lid is gone, the lid rises flat to slightly arched
    p = fr.lid_pose(HAPPY, 1)
    mid, inner, outer = _y(p, "LowerMid"), _y(p, "LowerInner"), _y(p, "LowerOuter")
    assert mid <= inner and inner < _y(p, "CornerIn") + 1.0 and outer < _y(p, "CornerOut") + 1.0
    # happy: the lower lid covers the bottom of the iris, the pupil stays clear
    p = fr.lid_pose(HAPPY, 1)
    assert IRIS_BOTTOM - 16.0 < _y(p, "LowerMid") < IRIS_BOTTOM - 8.0
    # its middle rises more than its ends
    rest = fr.lid_pose({}, 1)
    assert rest["LowerMid"][1] - _y(p, "LowerMid") > rest["LowerInner"][1] - _y(p, "LowerInner") + 2.0


@pytest.mark.parametrize("s", (-1, 1))
def test_cheek_raise_narrows_the_eye_from_below_by_at_most_40_percent(s: int) -> None:
    """AU6 is a smile squint, not a wink (critic round 1): its lower-lid push is capped."""
    rest, cr = fr.lid_pose({}, s), fr.lid_pose({"auCheekRaise": 1.0, f"auCheekRaise{'L' if s < 0 else 'R'}": 1.0}, s)
    for col in fr.LID_COLS:
        height = rest["Lower" + col][1] - rest["Upper" + col][1]
        assert rest["Lower" + col][1] - cr["Lower" + col][1] <= fr.CHEEK_RAISE_MAX * height + 1e-9, col
    # the eye stays clearly open (no wink): more than half its height at the middle
    assert cr["LowerMid"][1] - cr["UpperMid"][1] > 0.5 * (rest["LowerMid"][1] - rest["UpperMid"][1])


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
    squash = {e.get("id") for e in root.iter("Node") if e.get("name") == "BlinkSquash"}
    assert len(squash) == 2
    for anim in root.iter("LinearAnimation"):
        if anim.get("name") not in ("idle_blink", "blink_hold", "blink_once"):
            continue
        keyed = {(o.get("objectId"), p.get("property")) for o in anim.iter("KeyedObject") for p in o}
        assert keyed == {(i, "strength") for i in drives} | {(i, "scaleY") for i in squash}, anim.get("name")
        for o in anim.iter("KeyedObject"):
            vals = [float(k.get("value")) for k in o.iter("KeyFrameDouble")]
            if o.get("objectId") in drives:
                assert min(vals) == 0.0 and max(vals) <= 1.0
            else:  # the eyeball squash follows the same keys: 1 open .. 1 - BLINK_SQUASH shut
                assert max(vals) == 1.0 and min(vals) >= 1.0 - fr.BLINK_SQUASH


def test_blink_squash_pivots_on_the_lower_lid_and_wraps_the_gaze() -> None:
    assert fr.blink_squash(0.0) == 1.0 and fr.blink_squash(1.0) == pytest.approx(1.0 - fr.BLINK_SQUASH)
    root = _rml()
    for sq in (e for e in root.iter("Node") if e.get("name") == "BlinkSquash"):
        assert float(sq.get("y")) + fr.EYE_FRAME_DY == pytest.approx(fr.BLINK_SQUASH_Y)
        (pivot,) = list(sq)
        assert pivot.get("name") == "BlinkSquashPivot" and float(pivot.get("y")) == -float(sq.get("y"))
        assert [c.get("name") for c in pivot] == ["GazeM"]


def test_generated_avatar_declares_the_v6_side_numbers() -> None:
    rml = (ROOT / "rive" / "avatar" / "avatar.rml").read_text()
    assert len(fr.SIDE_NUMBERS) == 14
    for name in fr.SIDE_NUMBERS:
        assert re.search(rf'<ViewModelPropertyNumber name="{name}"', rml), name


# ---- the generated file: mouth and brow formulas equal the model (side offsets and clamps included)

FORMULA_POSES = [{}, FF, SS, {"auLipPucker": 0.95, "auJawDrop": 0.34}, ANGRY,
                 {"auLipStretch": 0.3, "auLipPress": 0.6, "auLipCornerDepress": 0.35},
                 {"auLipCornerPullL": 1.0, "auCheekRaiseL": 0.5}, {"auLipCornerPull": 0.3, "auLipCornerPullR": -1.0},
                 {"auBrowLower": 1.0, "auBrowLowerL": 1.0, "auBrowLowerR": -1.0},
                 {"auBrowInnerUp": 0.75, "auBrowOuterUpR": 0.6, "auLipCornerDepressL": 0.4, "mouth": 2.0},
                 {"tongueUp": 1.0, "auJawDrop": 0.34}]


def _bones_by_side(root: "ET.Element") -> dict[str, dict[str, "ET.Element"]]:
    out: dict[str, dict[str, "ET.Element"]] = {"mouth": {}, "L": {}, "R": {}}

    def walk(e: "ET.Element", names: tuple[str, ...]) -> None:
        n = e.get("name") or ""
        if e.tag == "RootBone" and n.startswith("Mouth"):
            out["mouth"][n[5:]] = e
        elif e.tag == "RootBone" and n.startswith("Brow"):
            out["L" if "BrowL" in names else "R"][n[4:]] = e
        for c in e:
            walk(c, (*names, n))

    walk(root, ())
    return out


def _bone_xy(bone: "ET.Element", env: dict, paths: dict, convs: dict) -> tuple[float, float]:
    xy = [float(bone.get("x")), float(bone.get("y"))]
    for ctx in bone.findall("DataBindContext"):
        k = {"90": 0, "91": 1}[ctx.get("propertyKey")]
        src = paths[ctx.get("sourcePathIds")]
        xy[k] = _eval_formula(list(convs[ctx.get("converterId")]), env.get(src, 0.0), env, paths)
    return xy[0], xy[1]


@pytest.mark.parametrize("env", FORMULA_POSES)
def test_generated_mouth_and_brow_formulas_match_the_model(env: dict) -> None:
    root = _rml()
    vm = next(e for e in root if e.tag == "ViewModel")
    paths = {f"{vm.get('id')}-{p.get('id')}": p.get("name") for p in vm if p.tag == "ViewModelPropertyNumber"}
    convs = {c.get("id"): c for c in root if c.tag == "DataConverterFormula"}
    bones = _bones_by_side(root)
    model = fr.mouth_pose(env)
    assert set(model) <= set(bones["mouth"])
    for n, (x, y) in model.items():
        bx, by = _bone_xy(bones["mouth"][n], env, paths, convs)
        assert (bx + fr.MOUTH_FRAME[0], by + fr.MOUTH_FRAME[1]) == pytest.approx((x, y), abs=2e-3), n
    for side, s_ in (("L", -1), ("R", 1)):
        bm = fr.brow_pose(env, s_)
        assert set(bm) == set(bones[side])
        for n, (u, y) in bm.items():
            bx, by = _bone_xy(bones[side][n], env, paths, convs)
            assert (bx, by + 346.0) == pytest.approx((u, y), abs=2e-3), (side, n)


# ------------------------------------------------------------------ critic round 1: jaw, lips, visemes, breath

def test_jaw_drops_the_chin_about_half_the_lower_lip() -> None:
    import head_turn as ht
    lip = fr.mouth_pose({"auJawDrop": 1.0})["LowerC"][1] - fr.mouth_pose({})["LowerC"][1]
    chin = ht.jaw_dy("Chin", {"auJawDrop": 1.0})
    assert 0.5 <= chin / lip <= 0.6
    assert 12.0 <= chin * 1.18 <= 18.0  # artboard px (the head is drawn at 1.18)
    # it fades up the jaw line: chin > V > Q > W > J > nothing at the cheekbone
    drops = [ht.jaw_dy(n, {"auJawDrop": 1.0}) for n in ("Chin", "FVL", "FQR", "FWL", "FJR", "FKL", "FCR")]
    assert drops == sorted(drops, reverse=True) and drops[-2:] == [0.0, 0.0]
    assert ht.jaw_dy("FVR", {"auJawDrop": 1.0}) == ht.jaw_dy("FVL", {"auJawDrop": 1.0})
    assert ht.jaw_dy("Chin", {"mouth": 4.0}) == pytest.approx(ht.jaw_dy("Chin", {"auJawDrop": 4 * fr.JAW_PER_MOUTH}))


def test_the_open_mouth_never_kisses_the_chin() -> None:
    import head_turn as ht
    for j in (0.0, 0.25, 0.5, 0.75, 1.0):
        env = {"auJawDrop": j, "auLipStretch": 0.15}
        lower = fr.mouth_pose(env)["LowerC"][1]
        assert 511.0 + ht.jaw_dy("Chin", env) - lower >= 6.0 / 1.18 + 12, j  # art bible: >= 6 px gap


@pytest.mark.parametrize("jaw", [0.14, 0.25, 0.34, 0.6, 1.0])
@pytest.mark.parametrize("tongue", [0.6, 0.8, 1.0])
def test_the_tongue_tip_stops_just_under_the_upper_teeth(jaw: float, tongue: float) -> None:
    tip = fr.mouth_pose({"auJawDrop": jaw, "tongueUp": tongue})["TongueTip"][1]
    assert 0.9 <= tip - fr.teeth_edge_y(400.0) <= 2.1  # reads at a moderate tongueUp, never hides


def test_nn_shows_the_tongue_tip_and_ss_the_teeth() -> None:
    nn = fr.mouth_pose({"auJawDrop": 0.25, "tongueUp": 0.7})
    ss = fr.mouth_pose(SS)
    assert nn["LowerC"][1] - nn["TongueTip"][1] > 2.5  # a pink tip between the teeth edge and the lip
    assert ss["LowerC"][1] - ss["JawTeeth"][1] > 1.5  # s: the lower teeth instead


def test_pp_presses_a_flat_narrow_line() -> None:
    rest, pp = fr.mouth_pose({}), fr.mouth_pose({"auLipPress": 0.75})
    for up, low in UPPER_LOWER:
        assert pp[up] == pytest.approx(pp[low], abs=1e-9)
    sag = lambda p: p["UpperC"][1] - p["CornerR"][1]  # noqa: E731
    assert abs(sag(pp)) < 0.4 * abs(sag(rest))  # flattened
    width = lambda p: p["CornerR"][0] - p["CornerL"][0]  # noqa: E731
    assert width(pp) < width(rest) - 5.0  # corners in


def test_flare_is_pucker_and_stretch_together() -> None:
    assert fr.amount({"auLipPucker": 0.8}, fr.FLARE) == 0.0  # rr / ou / oh: plain round lips
    assert fr.amount({"auLipStretch": 0.55}, fr.FLARE) == 0.0  # s / e
    assert fr.amount({"auLipPucker": 0.7, "auLipStretch": 0.4}, fr.FLARE) == 1.0  # ch / sh
    assert fr.base_prop(fr.FLARE) == "auLipPucker"


def test_breath_lifts_the_shoulders_more_than_the_head_eased() -> None:
    shoulder, head = fr.breath_lift(1.0)
    assert 15.0 <= shoulder <= 20.0  # 1.5-2 % of the 1000 px artboard
    assert 0 < head < shoulder  # the shoulders rise toward the ears
    assert fr.breath_lift(0.0) == (0.0, 0.0)
    assert fr.breath_lift(0.5)[0] == pytest.approx(shoulder / 2)  # smoothstep: soft at both ends
    assert fr.breath_lift(0.1)[0] < 0.05 * shoulder


# ---- critic round 1b: fringe, brows, dimple (the generated file)

def test_the_fringe_paints_over_the_brows_and_its_clumps_have_round_tips() -> None:
    root = _rml()
    order = [e.get("name") for e in root.iter() if e.get("name") in ("FringeFollowThrough", "TravelBrows")]
    assert order == ["FringeFollowThrough", "TravelBrows"]  # first declared paints in front
    locks = [e for e in root.iter("Shape") if re.fullmatch(r"Lock\d", e.get("name") or "")]
    assert len(locks) == 9
    for lock in locks:
        path = lock.find("PointsPath")
        assert path is not None and path.find("StraightVertex") is None, lock.get("name")  # no hard tip
    # the brows sit on skin now: no outline stroke
    for brow in (e for e in root.iter("Shape") if e.get("name") == "BrowShape"):
        assert brow.find("Stroke") is None


def test_the_dimpler_draws_a_corner_dent() -> None:
    root = _rml()
    dents = [e for e in root.iter("Shape") if e.get("name") in ("DimpleL", "DimpleR")]
    assert len(dents) == 2
    (x0, y0), k = fr.mouth_pose({})["CornerR"], 1
    arc = fr.DIMPLE_ARC(x0, y0, k)
    assert all(x > x0 for x, _ in arc) and arc[0][1] < y0 < arc[-1][1]  # a ")" just outside the corner
