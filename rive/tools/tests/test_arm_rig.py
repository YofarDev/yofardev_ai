"""Arm skeleton (M3 Task 7): FK -> target derivation, weights across the elbow, IK emission."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import arm_rig as ar  # noqa: E402
from avatar_kit import ik as solve_arm  # noqa: E402
import ik_check  # noqa: E402
from rig_dsl import auto_weights, two_bone_dirs  # noqa: E402

RML = Path(__file__).resolve().parents[2] / "avatar/avatar.rml"
ARM_GESTURES = {"wave": ("R", "L"), "facepalm": ("R",), "shrug": ("R", "L"), "clap": ("R", "L"), "think": ("R",)}


# ------------------------------------------------------------------ FK -> target

@pytest.mark.parametrize("side,wrist,deg,fs,fs2", [
    (-1, (198.0, 604.0), -94.0, 0.75, 0.9),   # wave
    (-1, (342.0, 476.0), -80.0, 0.55, 1.0),   # facepalm
    (-1, (387.0, 812.0), -100.0, 0.76, 1.0),  # clap contact
    (1, (644.0, 836.0), -32.0, 0.92, 0.5),    # shrug, the other arm
    (-1, (156.0, 836.0), 212.0, 0.92, 0.5),   # shrug
])
def test_target_is_the_wrist_and_the_solver_recovers_the_pose(side: int, wrist: tuple[float, float], deg: float,
                                                              fs: float, fs2: float) -> None:
    r = solve_arm(side, wrist, deg, False, fs, fs2)
    target, bend = ar.ik_target(side, r, fs, fs2)
    sx = ar.shoulder_x(side)
    assert target == pytest.approx((wrist[0] - sx, wrist[1] - ar.SHOULDER_Y), abs=1e-6)
    assert bend in (-1, 1)
    # the runtime's two-bone solve on the keyed target (bend from invertDirection) gives the FK elbow
    elbow_fk, _ = ar.fk(side, r, fs, fs2)
    _, _, elbow = two_bone_dirs(ar.L1 * fs, ar.L2 * fs2, target, ar.BEND_OF_INVERT[bend == 1])
    assert elbow == pytest.approx(elbow_fk, abs=1e-6)


def test_a_straight_arm_target_sits_past_the_reach_along_the_arm() -> None:
    for side, wrist in ((-1, (238.0, 1084.0)), (-1, (240.0, 1070.0)), (1, (554.0, 1078.0))):
        r = solve_arm(side, wrist, 90.0)
        target, bend = ar.ik_target(side, r, 1.0, 1.0)
        assert bend == 0
        assert math.hypot(*target) == pytest.approx(ar.L1 + ar.L2 + ar.REACH_MARGIN)
        _, w = ar.fk(side, r, 1.0, 1.0)
        assert math.atan2(target[1], target[0]) == pytest.approx(math.atan2(w[1], w[0]))
    assert math.hypot(*ar.REST_TARGET) > ar.L1 + ar.L2


def test_rdp_keeps_ends_and_drops_linear_keys() -> None:
    keys = [(f, (f * 2.0, 5.0)) for f in range(0, 20, 2)] + [(20, (40.0, 30.0))]
    kept = ar.rdp(keys, 0.1)
    assert kept[0] == 0 and kept[-1] == len(keys) - 1
    assert len(kept) == 3  # the corner at frame 18 stays, the straight run collapses
    assert ar.rdp(keys[:2], 0.1) == [0, 1]


def test_smoothstep_interpolator_is_exact() -> None:
    e = ar.SMOOTHSTEP.attrs
    for u in (0.1, 0.25, 0.5, 0.8):
        assert ik_check.bezier_ease(e["x1"], e["y1"], e["x2"], e["y2"], u) == pytest.approx(3 * u * u - 2 * u ** 3,
                                                                                              abs=1e-6)


# ------------------------------------------------------------------ weights across the elbow

def test_weights_hand_the_sleeve_from_upper_to_joint_to_forearm() -> None:
    segs = ar.weight_segments(-1)
    w = auto_weights([(240.0, 760.0), (240.0, 900.0), (240.0, 1040.0)], segs, falloff=ar.FALLOFF)
    assert w[0] == {"UpperArtBone": 1.0}
    assert w[1] == {"ElbowArt": 1.0}
    assert w[2] == {"ForeArtBone": 1.0}


def test_weights_along_the_sleeve_edge_are_smooth_and_normalised() -> None:
    segs = ar.weight_segments(-1)
    ys = [720.0 + 5 * i for i in range(71)]
    for x in (197.0, 283.0):  # both sleeve edges
        ws = auto_weights([(x, y) for y in ys], segs, falloff=ar.FALLOFF)
        for a, b in zip(ws, ws[1:]):
            assert sum(a.values()) == pytest.approx(1.0)
            for bone in segs:
                assert abs(a.get(bone, 0.0) - b.get(bone, 0.0)) < 0.2  # no seam: a gradual hand-over
        joint = ws[ys.index(900.0)]
        assert max(joint, key=joint.get) == "ElbowArt"
        assert ws[0]["UpperArtBone"] > ar.RIGID and ws[-1]["ForeArtBone"] > ar.RIGID


def test_the_three_sleeve_paths_share_their_side_heights() -> None:
    up, fore, line = ar.sleeve_outlines(240.0, (50.0, 43.0), (42.0, 35.0), 1066.0)
    right = lambda pts: {p[1]: p[0] for p in pts if p[0] > 240.0}  # noqa: E731
    shared = set(right(up)) & set(right(fore)) & set(right(line))
    assert {905.0, 940.0, 990.0} <= shared  # the contour hand-over vertex and the run below it
    for y in shared:
        assert right(up)[y] == right(fore)[y] == right(line)[y]
    assert ar.radius(880.0, (50.0, 43.0), (42.0, 35.0), 1066.0) > ar.radius(1000.0, (50.0, 43.0), (42.0, 35.0), 1066.0)


# ------------------------------------------------------------------ the generated RML

@pytest.fixture(scope="module")
def board() -> ET.Element:
    return ET.parse(RML).getroot().find("Artboard")


def test_each_arm_is_a_bone_chain_with_ik_toward_its_target(board: ET.Element) -> None:
    ids = {e.get("id"): e for e in board.iter() if e.get("id")}
    for side in ("R", "L"):
        arm = next(e for e in board.iter("Node") if e.get("name") == "Arm" + side)
        shoulder = next(c for c in arm if c.tag == "RootBone")
        assert shoulder.get("name") == "Shoulder"
        upper = next(c for c in shoulder if c.tag == "Bone")
        assert upper.get("name") == "UpperArm"
        fore = next(c for c in upper if c.get("name") == "Forearm")
        assert fore.tag == "Bone"
        (ikc,) = [c for c in fore if c.tag == "IKConstraint"]
        assert ikc.get("parentBoneCount") == "1"
        target = ids[ikc.get("targetId")]
        assert target.get("name") == "HandTarget" + side and target in list(arm)
        names = {c.get("name") for c in fore}
        assert {"Wrist", "ForeArtBone"} <= names
        assert {c.get("name") for c in upper} >= {"Forearm", "ElbowArt", "UpperArtBone"}
        joint = next(c for c in upper if c.get("name") == "ElbowArt")
        (half,) = [c for c in joint if c.tag == "RotationConstraint"]
        assert half.get("targetId") == fore.get("id") and float(half.get("copyFactor")) == 0.5
        hand = next(c for c in next(c for c in fore if c.get("name") == "Wrist") if c.tag == "Node")
        assert hand.get("name") == "Hand"
    assert not [e for e in board.iter("Node") if e.get("name") == "Elbow"]


def test_sleeves_are_skinned_to_the_art_bones(board: ET.Element) -> None:
    ids = {e.get("id"): e for e in board.iter() if e.get("id")}
    skinned = {}
    for arm in (e for e in board.iter("Node") if e.get("name") in ("ArmR", "ArmL")):
        for shape in arm.iter("Shape"):
            skin = shape.find("PointsPath/Skin")
            if skin is not None:
                bones = {ids[t.get("boneId")].get("name") for t in skin.findall("Tendon")}
                assert bones <= {"UpperArtBone", "ElbowArt", "ForeArtBone"}
                skinned.setdefault(arm.get("name"), set()).add(shape.get("name"))
    for names in skinned.values():
        assert {"Sleeve", "SleeveLine", "SkinUp", "SkinFore", "SkinForeLine"} <= names
        assert "RigidShell" not in names


def test_gestures_key_targets_not_shoulder_or_elbow_rotations(board: ET.Element) -> None:
    ids = {e.get("id"): e for e in board.iter() if e.get("id")}
    for anim in board.findall("LinearAnimation"):
        name = anim.get("name")
        if not name.startswith("gesture_"):
            continue
        keyed = {(ids[o.get("objectId")].get("name"), p.get("property")) for o in anim.findall("KeyedObject")
                 for p in o.findall("KeyedProperty")}
        for side in ("R", "L"):
            assert ("HandTarget" + side, "x") in keyed and ("HandTarget" + side, "y") in keyed, name
        assert ("IK", "invertDirection") in keyed
        assert not {k for k in keyed if k[0] in ("Elbow", "UpperArt", "ForeArt")}, name
        gesture = name[len("gesture_"):]
        if gesture in ARM_GESTURES:
            assert ("ArmR", "rotation") not in keyed and ("ArmL", "rotation") not in keyed, name
            assert ("UpperArm", "length") in keyed and ("ForeArtBone", "scaleX") in keyed


def test_the_python_solver_on_the_keyed_values_reaches_the_target(board: ET.Element) -> None:
    arms = ik_check.arms(board)
    for gesture, sides in ARM_GESTURES.items():
        ch = ik_check.channels(board, "gesture_" + gesture)
        for arm in (a for a in arms if a.side in sides):
            for f in range(0, 120, 7):
                _, wrist = ik_check.expected(arm, ch, f)
                tx = ch[(arm.target, "x")].at(f)
                ty = ch[(arm.target, "y")].at(f)
                reach = ch[(arm.upper.get("id"), "length")].at(f) + ch[(arm.fore.get("id"), "length")].at(f)
                if math.hypot(tx, ty) < reach - 1e-6:
                    assert wrist == pytest.approx((tx, ty), abs=1e-6)


def test_the_elbow_side_only_changes_while_the_arm_is_straight(board: ET.Element) -> None:
    """Review Focus 5: invertDirection is keyed once per gesture (frame 0) and every gesture starts and
    ends with the arm straight (target past the reach), so no blend or switch can flip a bent elbow."""
    arms = ik_check.arms(board)
    for anim in board.findall("LinearAnimation"):
        name = anim.get("name")
        if not name.startswith("gesture_"):
            continue
        ch = ik_check.channels(board, name)
        end = float(anim.get("duration"))
        for arm in arms:
            inv = ch[(arm.ik, "invertDirection")]
            assert [k[0] for k in inv.keys] == [0.0], name
            for f in (0.0, end):
                reach = ch[(arm.upper.get("id"), "length")].at(f) + ch[(arm.fore.get("id"), "length")].at(f)
                assert math.hypot(ch[(arm.target, "x")].at(f), ch[(arm.target, "y")].at(f)) > reach, (name, f)
