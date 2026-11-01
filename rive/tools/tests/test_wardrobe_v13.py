"""Moonshot M10 Tasks 2b-2c (rulings 5, 6, 12; contract v13) on the generated avatar RML: the tints, the mouth
anchor and the costume signatures. Renders: rive/tools/review_wardrobe_v13.py (rive/review/m10/wardrobe/)."""

from __future__ import annotations

from pathlib import Path
import xml.etree.ElementTree as ET

import pytest

ROOT = Path(__file__).resolve().parents[3]
RML = ROOT / "rive" / "avatar" / "avatar.rml"
RIV = ROOT / "assets" / "rive" / "avatar.riv"
M10_LINE = 564_776  # ruling 3: the avatar ends M10 no bigger than M9
TOPS = ["pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie"]
HATS = ["beanie", "backwardsCap", "frenchBeret", "swimCap", "santaHat", "redMagaCap"]
COSTUMES = ["batman", "robocop", "soubrette", "singularity"]
TOP_SLEEVES = {"Up_long", "Fore_long", "Up_short"}
COLOR_BLEND = "27"


@pytest.fixture(scope="module")
def root() -> ET.Element:
    return ET.parse(RML).getroot()


@pytest.fixture(scope="module")
def board(root: ET.Element) -> ET.Element:
    return root.find("Artboard")


@pytest.fixture(scope="module")
def parents(root: ET.Element) -> dict[ET.Element, ET.Element]:
    return {c: p for p in root.iter() for c in p}


def _ancestors(el: ET.Element, parents: dict[ET.Element, ET.Element]) -> list[str]:
    out = []
    while el in parents:
        el = parents[el]
        out.append(el.get("name") or el.tag)
    return out


def _vm(root: ET.Element) -> tuple[ET.Element, dict[str, ET.Element]]:
    vm = next(v for v in root.iter("ViewModel") if v.get("name") == "AvatarVM")
    return vm, {p.get("name"): p for p in vm if p.tag.startswith("ViewModelProperty")}


# ------------------------------------------------------------------ tints (ruling 5)

def test_tint_colours_follow_tablet_temp_and_default_to_clear(root: ET.Element) -> None:
    vm, props = _vm(root)
    names = [p.get("name") for p in vm if p.tag.startswith("ViewModelProperty")]
    assert names[names.index("tabletTemp") + 1:names.index("tabletTemp") + 3] == ["topTint", "hatTint"]
    assert all(props[n].tag == "ViewModelPropertyColor" for n in ("topTint", "hatTint"))
    inst = next(i for i in vm.iter("ViewModelInstance"))
    for n in ("topTint", "hatTint"):
        (val,) = [v for v in inst if v.get("viewModelPropertyId") == props[n].get("id")]
        assert val.tag == "ViewModelInstanceColor" and val.get("propertyValue") == "00000000"


def _tints(root: ET.Element) -> list[tuple[ET.Element, ET.Element]]:
    return [(sh, f) for sh in root.iter("Shape") for f in sh if f.tag == "Fill" and f.get("name") == "Tint"]


def test_every_tint_is_a_clear_color_blend_fill_over_its_own_fill_under_its_ink(root: ET.Element) -> None:
    vm, props = _vm(root)
    paths = {f"{vm.get('id')}-{props[n].get('id')}": n for n in ("topTint", "hatTint")}
    tints = _tints(root)
    assert len(tints) > 40
    for sh, fill in tints:
        assert fill.get("blendModeValue") == COLOR_BLEND, sh.get("name")
        (sc,) = list(fill)
        assert sc.tag == "SolidColor" and sc.get("colorValue") == "00000000"
        (bind,) = list(sc)
        assert bind.tag == "DataBindContext" and bind.get("propertyKey") == "37"
        assert bind.get("sourcePathIds") in paths
        kids = list(sh)
        at = kids.index(fill)
        # right over the garment's own fill: an ink stroke declared after that fill stays on top (the swim cap
        # declares its fill after its stroke, so its tint, like its fill, covers the stroke's inner half)
        assert kids[at - 1].tag == "Fill" and kids[at - 1].get("name") != "Tint"
        assert [k.tag for k in kids[at + 1:]] == [k.tag for k in kids[at + 1:] if k.tag == "Stroke"]


def test_tints_reach_every_top_and_hat_and_nothing_else(root: ET.Element,
                                                         parents: dict[ET.Element, ET.Element]) -> None:
    vm, props = _vm(root)
    top_path = f"{vm.get('id')}-{props['topTint'].get('id')}"
    seen_tops: set[str] = set()
    seen_hats: set[str] = set()
    for sh, fill in _tints(root):
        chain = _ancestors(sh, parents)
        group = next(n for n in chain if n.startswith(("F_", "B_", "H_", "Up_", "Fore_")))
        is_top = next(fill.iter("DataBindContext")).get("sourcePathIds") == top_path
        assert "Skin" not in (sh.get("name") or "")
        assert not any(n in chain for n in ("HairFront", "HairBack", "Tufts"))
        if group.startswith(("F_", "B_")):
            assert is_top and group[2:] in TOPS, group
            seen_tops.add(group[2:])
        elif group.startswith("H_"):
            assert not is_top and group[2:] in HATS, group  # never a costume head
            seen_hats.add(group[2:])
        else:
            assert is_top and group in TOP_SLEEVES, group     # never a sleeve kind a costume wears, never skin
    assert seen_tops == set(TOPS) and seen_hats == set(HATS)


# ------------------------------------------------------------------ the mouth anchor (ruling 12)

def test_mouth_anchor_rides_the_lips_inside_the_head_turn(root: ET.Element,
                                                          parents: dict[ET.Element, ET.Element]) -> None:
    (anchor,) = [e for e in root.iter() if e.get("name") == "MouthAnchor"]
    assert anchor.tag == "Node" and not list(anchor.iter("Shape"))  # draws nothing
    assert parents[anchor].get("name") == "MouthUpperC"
    chain = _ancestors(anchor, parents)
    assert "MouthTurn" in chain and "Head" in chain and "HeadGesture" in chain and "Root" in chain
    (con,) = [c for c in anchor if c.tag.endswith("Constraint")]
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    assert con.tag == "TranslationConstraint" and float(con.get("strength")) == 0.5
    assert ids[con.get("targetId")].get("name") == "MouthLowerC"   # halfway to the lower lip: mid-opening
    assert con.get("sourceSpaceValue") in (None, "world") and con.get("destSpaceValue") in (None, "world")


# ------------------------------------------------------------------ the signatures (ruling 6)

def _layer(board: ET.Element, name: str) -> ET.Element:
    return next(la for la in board.iter("StateMachineLayer") if la.get("name") == name)


def test_signature_is_the_last_gesture_id(root: ET.Element) -> None:
    enum = next(e for e in root.iter("DataEnumCustom") if e.get("name") == "GestureId")
    keys = [v.get("key") for v in enum]
    assert keys[-1] == "signature" and keys[:-1] == ["wave", "laugh", "facepalm", "shrug", "nod", "headshake",
                                                    "clap", "think", "thumbsUp", "count", "grab"]


def test_each_costume_has_its_signature_state(root: ET.Element, board: ET.Element) -> None:
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    layer = _layer(board, "Gesture")
    anims = {a.get("id"): a for a in board.findall("LinearAnimation")}
    idle = next(s for s in layer.iter("AnimationState") if anims[s.get("animationId")].get("name") == "gesture_none")
    for costume in ["none", *COSTUMES]:
        (state,) = [s for s in layer.iter("AnimationState")
                    if anims[s.get("animationId")].get("name") == f"gesture_signature_{costume}"]
        clip = anims[state.get("animationId")]
        assert int(clip.get("duration")) == 6 if costume == "none" else 60 <= int(clip.get("duration")) <= 72
        (fire,) = state.findall("StateMachineFireEvent")
        ev = ids[fire.get("eventId")]
        assert ev.get("name") == "gesture_done" and fire.get("occursValue") == "atEnd"
        assert [(p.get("name"), p.get("propertyValue")) for p in ev] == [("gestureId", "signature")]
        (back,) = state.findall("StateTransition")
        assert back.get("stateToId") == idle.get("id") and back.get("exitTime") == "100"
        (into,) = [t for t in idle.findall("StateTransition") if t.get("stateToId") == state.get("id")]
        conds = into.findall("TransitionViewModelCondition")
        assert len(conds) == 3
        values = {ids[c.find("TransitionValueEnumComparator").get("value")].get("key")
                  for c in conds if c.find("TransitionValueEnumComparator") is not None}
        assert values == {"signature", costume}
        assert any(c.find("TransitionValueTriggerComparator") is not None for c in conds)
        for c in conds:  # both comparators on every condition (the rive skill's guarded-transition rule)
            assert c.find("TransitionPropertyViewModelComparator") is not None


ALLOWED = {"BodyGesture", "HeadGesture", "CapeResponse", "ApronBibResponse", "ScanSweep", "AuraSwell", "Laser",
           # the arm rig: IK targets and constraint, chain bones, art bones, the hand's lag and drawn pose
           "HandTargetR", "HandTargetL", "IK", "UpperArm", "Forearm", "UpperArtBone", "ForeArtBone", "ElbowArt",
           "Hand", "HandPose"}


def test_signatures_key_only_the_rig(root: ET.Element, board: ET.Element) -> None:
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    for costume in COSTUMES:
        clip = next(a for a in board.findall("LinearAnimation") if a.get("name") == f"gesture_signature_{costume}")
        keyed = {ids[o.get("objectId")] for o in clip.findall("KeyedObject")}
        names = {e.get("name") for e in keyed}
        odd = {n for n in names if n not in ALLOWED and not n.startswith("Drive")}  # Drive*: the digit drivers
        assert not odd, (costume, odd)
        n_keys = sum(1 for _ in clip.iter() if _.tag.startswith("KeyFrame"))
        assert n_keys <= 300, (costume, n_keys)  # ~15 B a key: inside the 5 KB a signature may cost


def test_the_laser_loop_runs_before_the_gesture_layer(root: ET.Element, board: ET.Element) -> None:
    names = [la.get("name") for la in board.iter("StateMachineLayer")]
    assert names.index("LaserLoop") < names.index("Gesture") < names.index("Costume")
    laser = next(e for e in root.iter("Node") if e.get("name") == "Laser")
    keyers = {a.get("name") for a in board.findall("LinearAnimation")
              for o in a.findall("KeyedObject") if o.get("objectId") == laser.get("id")}
    assert keyers == {"laser_loop", "gesture_signature_singularity"}


def test_the_avatar_stays_inside_the_m10_line() -> None:
    assert RIV.stat().st_size <= M10_LINE
