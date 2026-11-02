"""Moonshot M8 Task 2: articulated hands and three gestures (rulings 2-4), on hand_rig.py and the
generated avatar RML."""

from __future__ import annotations

import math
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_kit as kit  # noqa: E402
import hand_rig as hr  # noqa: E402
import ik_check  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
RML = ROOT / "rive" / "avatar" / "avatar.rml"
BASE = "927a606"  # M7: the ids and the rest pose M8 must keep
OLD_GESTURES = ["wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think"]
NEW_GESTURES = ["thumbsUp", "count", "grab"]
HOOK = (628.0, 560.0)
CONTACT = 23
SKINS = 5         # hand skins drawn per side in M7 / M8
HAND_COPIES = 1   # M10 (ruling 3): one hand drawing per side, the five skins keyed in the costume clips
WARDROBE_SOLOS = ("UpperSleeve", "ForeSleeve", "HandSkin")


# ------------------------------------------------------------------ the pose table

def test_every_pose_drives_every_digit() -> None:
    assert set(hr.NEW_POSES) <= set(hr.HAND_POSE_DRIVERS)
    for name, pose in hr.HAND_POSE_DRIVERS.items():
        assert set(pose) == set(hr.DIGITS), name
    assert all(v == (0.0, 1.0) for v in hr.HAND_POSE_DRIVERS["rest"].values())


def test_curled_fingers_follow_the_cartoon_front_view() -> None:
    """A curled finger shortens toward its knuckle (scaleY 0.22-0.6; 0.6-0.9 is a relaxed finger) and tips in
    by 0.35 rad or less."""
    for name, pose in hr.HAND_POSE_DRIVERS.items():
        for dg, (rot, sy) in pose.items():
            if dg == "Thumb":
                continue
            assert abs(rot) <= 0.35, (name, dg)
            assert sy >= 0.22, (name, dg)
    fist = hr.HAND_POSE_DRIVERS["fist"]
    assert all(fist[f"Finger{i}"][1] <= 0.5 for i in range(4))


def test_counting_raises_index_then_middle_then_ring() -> None:
    up = {n: {d for d, (_, sy) in hr.HAND_POSE_DRIVERS[n].items() if d != "Thumb" and sy >= 0.95}
          for n in ("fist", "one", "two", "three", "four")}
    assert up == {"fist": set(), "one": {"Finger3"}, "two": {"Finger3", "Finger2"},
                  "three": {"Finger3", "Finger2", "Finger1"}, "four": {"Finger3", "Finger2", "Finger1", "Finger0"}}


def test_the_right_hand_mirrors_the_left() -> None:
    for name in hr.HAND_POSE_DRIVERS:
        left, right = hr.values(name, -1), hr.values(name, 1)
        for dg in hr.DIGITS:
            assert right[dg] == (-left[dg][0], left[dg][1])
            lx, ly = hr.tip(-1, dg, name)
            rx, ry = hr.tip(1, dg, name)
            assert math.isclose(lx, 800 - rx, abs_tol=1e-9) and math.isclose(ly, ry, abs_tol=1e-9)


def test_pinch_brings_thumb_and_index_tips_together() -> None:
    for side in (-1, 1):
        assert math.dist(hr.tip(side, "Thumb", "pinch"), hr.tip(side, "Finger3", "pinch")) < 4.0
        assert math.dist(hr.tip(side, "Thumb", "rest"), hr.tip(side, "Finger3", "rest")) > 40.0


def test_thumbs_up_stands_up_when_the_fingers_point_at_the_body() -> None:
    """thumbsUp turns the hand so the fingers point at the body (90 degrees from hanging): the thumb is up."""
    for side in (-1, 1):
        px, py = hr.pivot_at(side, "Thumb")
        tx, ty = hr.tip(side, "Thumb", "thumbsUp")
        turn = math.radians(-90 if side == -1 else 90)  # fingers down -> toward the body
        dx = math.cos(turn) * (tx - px) - math.sin(turn) * (ty - py)
        dy = math.sin(turn) * (tx - px) + math.cos(turn) * (ty - py)
        assert dy / math.hypot(dx, dy) < -0.9, side


# ------------------------------------------------------------------ the generated avatar

@pytest.fixture(scope="module")
def root() -> ET.Element:
    return ET.parse(RML).getroot()


@pytest.fixture(scope="module")
def board(root: ET.Element) -> ET.Element:
    return root.find("Artboard")


def _parent_map(root: ET.Element) -> dict[ET.Element, ET.Element]:
    return {c: p for p in root.iter() for c in p}


def _arm_of(el: ET.Element, parents: dict[ET.Element, ET.Element]) -> str:
    while el in parents:
        el = parents[el]
        if el.get("name") in ("ArmR", "ArmL"):
            return el.get("name")[-1]
    raise AssertionError("not in an arm")


def test_every_hand_copy_has_five_pivots_on_its_sides_drivers(root: ET.Element) -> None:
    parents = _parent_map(root)
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    rests = [e for e in root.iter("Node") if e.get("name") == "Hand_rest"]
    assert len(rests) == 2 * HAND_COPIES
    for g in rests:
        side = _arm_of(g, parents)
        pivots = [c for c in g if c.tag == "Node" and c.get("name", "").startswith("Pv")]
        assert g[0].get("name") == "PvThumb"  # the thumb crosses the back of the hand in front of everything
        assert sorted(p.get("name") for p in pivots) == sorted("Pv" + d for d in hr.DIGITS)
        for p in pivots:
            (con,) = [c for c in p if c.tag.endswith("Constraint")]
            assert con.tag == "TransformConstraint"
            assert (con.get("sourceSpaceValue"), con.get("destSpaceValue")) == ("local", "local")
            drv = ids[con.get("targetId")]
            assert drv.get("name") == f"Drive{p.get('name')[2:]}{side}"
            assert parents[drv].get("name") == "HandWave" and _arm_of(drv, parents) == side
            # the driver sits where the pivot sits, so the copied translation is the pivot's own
            assert (float(drv.get("x")), float(drv.get("y"))) == (float(p.get("x")), float(p.get("y")))
            digit = p.get("name")[2:]
            shapes = [c.get("name") for c in p if c.tag == "Shape"]
            assert digit in shapes and all(s == digit or s.startswith(hr.SEAM) for s in shapes)


def test_back_is_dropped_and_no_reference_dangles(root: ET.Element) -> None:
    assert not [e for e in root.iter() if e.get("name") == "Hand_back"]
    ids = {e.get("id") for e in root.iter() if e.get("id")}
    for e in root.iter():
        for k, v in e.attrib.items():
            if k != "id" and re.fullmatch(r"0:\d+", v):
                assert v in ids, (e.tag, k, v)


@pytest.fixture(scope="module")
def base_root() -> ET.Element:
    try:
        text = subprocess.run(["git", "show", f"{BASE}:rive/avatar/avatar.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {BASE} not available")
    return ET.fromstring(text)


def m10_dedupe_dropped(base_root: ET.Element, new_ids: set[str]) -> set[str]:
    """Ids the M10 wardrobe dedupe drops (ruling 3): the wardrobe copies that did not survive (a sleeve set
    per outfit, a hand per skin; their unique pieces moved into the survivor and keep their ids) and the
    keys that targeted them (duplicates of the survivor's keys)."""
    copies = {e.get("id") for s in base_root.iter("Solo") if s.get("name") in WARDROBE_SOLOS for g in s
              if g.get("id") not in new_ids for e in g.iter()} - new_ids
    keys = {e.get("id") for o in base_root.iter("KeyedObject") if o.get("objectId") in copies for e in o.iter()}
    return copies | keys


def test_existing_ids_never_move(root: ET.Element, base_root: ET.Element) -> None:
    """Every M7 element keeps its id, tag and name; only the dropped `back` groups are gone; every new
    element takes the M8 range. M10: the wardrobe dedupe drops the copies that did not survive and renames
    the survivors (`Up_long`, `Skin_shared`, ...); its keys take the M10 range."""
    new = {e.get("id"): e for e in root.iter() if e.get("id")}
    old = {e.get("id"): e for e in base_root.iter() if e.get("id")}
    dropped = {e.get("id") for g in base_root.iter("Node") if g.get("name") == "Hand_back" for e in g.iter()}
    assert len([g for g in base_root.iter("Node") if g.get("name") == "Hand_back"]) == 2 * SKINS
    deduped = m10_dedupe_dropped(base_root, set(new))
    renamed = {g.get("id") for s in base_root.iter("Solo") if s.get("name") in WARDROBE_SOLOS for g in s}
    # The tablet grip pass replaces these timelines' keys in a new id range.
    # Their animation, state machine and every original drawing component keep their ids.
    tablet_keys = {e.get("id") for a in base_root.iter("LinearAnimation")
                   if a.get("name", "").startswith("prop_tablet_") for o in a for e in o.iter()}
    assert not tablet_keys & new.keys()  # retired key ids must never become different components
    for i, e in old.items():
        if i in tablet_keys:
            continue
        if i in dropped or i in deduped:
            assert i not in new
            continue
        assert i in new, (e.tag, e.get("name"), i)
        assert new[i].tag == e.tag, i
        assert i in renamed or new[i].get("name") == e.get("name"), i
    for i in set(new) - set(old):
        assert int(i.split(":")[1]) >= kit.M8_ID_START, (new[i].tag, new[i].get("name"), i)


def _anim(board: ET.Element, name: str) -> ET.Element:
    return next(a for a in board.findall("LinearAnimation") if a.get("name") == name)


def _layer(board: ET.Element, name: str) -> ET.Element:
    return next(la for la in board.iter("StateMachineLayer") if la.get("name") == name)


def test_gesture_ids_events_and_states(root: ET.Element, board: ET.Element) -> None:
    enum = next(e for e in root.iter("DataEnumCustom") if e.get("name") == "GestureId")
    assert [v.get("key") for v in enum] == OLD_GESTURES + NEW_GESTURES + ["signature"]  # v13 appends signature
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    layer = _layer(board, "Gesture")
    for g in NEW_GESTURES:
        anim = _anim(board, f"gesture_{g}")
        (state,) = [s for s in layer.iter("AnimationState") if s.get("animationId") == anim.get("id")]
        (fire,) = state.findall("StateMachineFireEvent")
        ev = ids[fire.get("eventId")]
        assert ev.get("name") == "gesture_done" and fire.get("occursValue") == "atEnd"
        assert [(p.get("name"), p.get("propertyValue")) for p in ev] == [("gestureId", g)]
        assert any(t.get("stateToId") == state.get("id") for t in layer.iter("StateTransition"))


def test_hand_rest_runs_before_the_gesture_layer(board: ET.Element) -> None:
    names = [la.get("name") for la in board.iter("StateMachineLayer")]
    assert names.index("HandRest") < names.index("Gesture")
    anim = _anim(board, "hand_rest")
    ids = {e.get("id"): e for e in board.iter() if e.get("id")}
    keyed = {ids[o.get("objectId")].get("name"): {p.get("property"): [float(k.get("value")) for k in p] for p in o}
             for o in anim.findall("KeyedObject")}
    assert set(keyed) == {f"Drive{d}{s}" for d in hr.DIGITS for s in "RL"}
    assert all(v == {"rotation": [0.0], "scaleY": [1.0]} for v in keyed.values())


def test_gesture_lengths(board: ET.Element) -> None:
    ms = {g: int(_anim(board, f"gesture_{g}").get("duration")) * 1000 / 60 for g in NEW_GESTURES}
    assert 1300 <= ms["thumbsUp"] <= 1500
    assert 1900 <= ms["count"] <= 2100
    assert ms["grab"] == 900


def _driver_channels(board: ET.Element, anim: str, side: str) -> dict[tuple[str, str], ik_check.Channel]:
    ids = {e.get("id"): e.get("name") for e in board.iter() if e.get("id")}
    ch = ik_check.channels(board, anim)
    return {(ids[o][5:-1], p): c for (o, p), c in ch.items() if str(ids.get(o, "")).startswith("Drive")
            and ids[o].endswith(side)}


def _scale(ch: dict, digit: str, frame: float) -> float:
    c = ch.get((digit, "scaleY"))
    return c.at(frame) if c else 1.0


def test_count_shows_one_two_three(board: ET.Element) -> None:
    ch = _driver_channels(board, "gesture_count", "L")
    step = 25
    for n, frame in ((1, 20 + step - 2), (2, 20 + 2 * step - 2), (3, 94)):
        up = {d for d in ("Finger3", "Finger2", "Finger1", "Finger0") if _scale(ch, d, frame) >= 0.95}
        assert up == set(["Finger3", "Finger2", "Finger1"][:n]), (n, up)
    assert all(_scale(ch, d, 18) <= 0.5 for d in ("Finger3", "Finger2", "Finger1", "Finger0"))  # a fist first
    assert all(abs(_scale(ch, d, 120) - 1.0) < 1e-6 for d in hr.DIGITS)


def test_thumbs_up_holds_the_pose(board: ET.Element) -> None:
    ch = _driver_channels(board, "gesture_thumbsUp", "R")
    want = hr.values("thumbsUp", -1)
    for d in hr.DIGITS:
        for i, prop in enumerate(("rotation", "scaleY")):
            c = ch.get((d, prop))
            got = c.at(40) if c else (0.0, 1.0)[i]
            assert math.isclose(got, want[d][i], abs_tol=1e-3), (d, prop)


def test_grab_closes_on_the_hook_at_contact(board: ET.Element) -> None:
    """The viewer's-right grip point (GRIP_REACH along the fingers from the wrist) is within 6 px of the
    hook at the contact frame (380 ms), and the hand is in its grip pose there."""
    arm = next(a for a in ik_check.arms(board) if a.side == "L")
    ch = ik_check.channels(board, "gesture_grab")
    hand = next(e for e in arm.wrist.iter("Node") if e.get("name") == "Hand")
    for frame in (CONTACT - 1, CONTACT, CONTACT + 1):
        elbow, wrist = ik_check.expected(arm, ch, frame)
        lo = math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0])
        finger = lo + ch[(hand.get("id"), "rotation")].at(frame)
        gx = 560.0 + wrist[0] + hr.GRIP_REACH * math.cos(finger)
        gy = 720.0 + wrist[1] + hr.GRIP_REACH * math.sin(finger)
        assert math.dist((gx, gy), HOOK) < 6.0, (frame, gx, gy)
    drv = _driver_channels(board, "gesture_grab", "L")
    grip = hr.values("grip", 1)
    for d in hr.DIGITS:
        for i, prop in enumerate(("rotation", "scaleY")):
            assert math.isclose(drv[(d, prop)].at(CONTACT), grip[d][i], abs_tol=1e-3), (d, prop)
    assert _scale(drv, "Finger2", CONTACT - 4) > 0.95  # open on the way in


def test_m8_budget() -> None:
    riv = ROOT / "assets" / "rive" / "avatar.riv"
    assert riv.stat().st_size <= 590_000
