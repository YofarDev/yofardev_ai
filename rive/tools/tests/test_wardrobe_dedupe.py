"""Moonshot M10 Task 2a (ruling 3): the wardrobe dedupe, on wardrobe_dedupe.py and the generated avatar RML.

The render identity with M9 is gated by rive/tools/review_wardrobe_identity.py (rive/review/m10/wardrobe/)."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_kit as kit  # noqa: E402
from rml import Doc  # noqa: E402
import wardrobe_dedupe as wd  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
RML = ROOT / "rive" / "avatar" / "avatar.rml"
BASE = "a429f00"  # the M9 avatar
KINDS = ["long", "short", "bare", "glove", "armor", "puff", "stars"]
LONG = ["pinkHoodie", "longCoat", "christmasSweater", "blackSuitAndTie"]
TOPS = ["pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie"]
COSTUMES = ["none", "batman", "robocop", "soubrette", "singularity"]
WARDROBE_LAYERS = ("Hat", "Top", "Glasses", "Costume")


# ------------------------------------------------------------------ the pass itself (synthetic trees)

def _tree(doc: Doc, colour_b: str = "FF0000FF", extra: bool = True, x_b: float = 0.0):  # type: ignore[no-untyped-def]
    def member(name: str, colour: str, with_extra: bool, x: float = 0.0):  # type: ignore[no-untyped-def]
        shape = doc("Shape", doc("Ellipse", width=10.0, height=10.0, name="Path"),
                    doc("Fill", doc("SolidColor", colorValue=colour), name="Fill"), x=x, name="Body")
        kids = [doc("Shape", doc("Ellipse", width=2.0, height=2.0, name="Path"), name="Stitch")] if with_extra else []
        return doc("Node", *kids, shape, name=name)
    a, b = member("A", "FFFF0000", False), member("B", colour_b, extra, x_b)
    solo = doc("Solo", a, b, activeComponentId=a.ref(), name="Switch")
    clip_a = doc("LinearAnimation", doc("KeyedObject", doc("KeyedProperty", doc(
        "KeyFrameId", frame=0, value=a.ref(), interpolationType="hold"), property="activeComponentId"),
        objectId=solo.ref()), name="pick_a", duration=1)
    clip_b = doc("LinearAnimation", doc("KeyedObject", doc("KeyedProperty", doc(
        "KeyFrameId", frame=0, value=b.ref(), interpolationType="hold"), property="activeComponentId"),
        objectId=solo.ref()), name="pick_b", duration=1)
    root = doc("Artboard", solo, clip_a, clip_b, name="Board")
    return root, solo, a, b, clip_a, clip_b


def _keys(clip) -> dict[tuple[str, str], object]:  # type: ignore[no-untyped-def]
    return {(o.attrs["objectId"], p.attrs["property"]): p.children[0].attrs["value"]
            for o in clip.children for p in o.children}


def test_a_merge_keeps_the_survivor_moves_extras_and_keys_every_member() -> None:
    doc = Doc(start=10)
    root, solo, a, b, clip_a, clip_b = _tree(doc)
    stitch = b.children[0]
    body_a = a.children[0]
    fill_a = body_a.children[1].children[0]
    wd.dedupe(Doc(start=1000), root, [wd.Merge(solo, {"a": a, "b": b}, "Shared", {"a": [clip_a], "b": [clip_b]})])
    assert solo.children == [a] and a.attrs["name"] == "Shared"
    assert a.children == [stitch, body_a]                 # the extra keeps its id and its place in front
    assert stitch.attrs["opacity"] == 0.0                 # static = the survivor's member, which lacks it
    ka, kb = _keys(clip_a), _keys(clip_b)
    assert ka[(solo.ref(), "activeComponentId")] == kb[(solo.ref(), "activeComponentId")] == a.ref()
    assert ka[(fill_a.ref(), "colorValue")] == "FFFF0000" and kb[(fill_a.ref(), "colorValue")] == "FF0000FF"
    assert ka[(stitch.ref(), "opacity")] == 0.0 and kb[(stitch.ref(), "opacity")] == 1.0
    assert set(ka) == set(kb)                              # history-free: both clips key every varying value
    assert all(int(o.ref().split(":")[1]) >= 1000 for c in (clip_a, clip_b) for o in c.children[1:])


def test_identical_members_need_no_keys() -> None:
    doc = Doc(start=10)
    root, solo, a, b, clip_a, clip_b = _tree(doc, colour_b="FFFF0000", extra=False)
    wd.dedupe(Doc(start=1000), root, [wd.Merge(solo, {"a": a, "b": b}, "Shared", {"a": [clip_a], "b": [clip_b]})])
    assert len(clip_a.children) == len(clip_b.children) == 1


def test_geometry_that_differs_is_refused() -> None:
    doc = Doc(start=10)
    root, solo, a, b, clip_a, clip_b = _tree(doc, x_b=3.0)
    with pytest.raises(ValueError, match="x"):
        wd.dedupe(Doc(start=1000), root, [wd.Merge(solo, {"a": a, "b": b}, "S", {"a": [clip_a], "b": [clip_b]})])


def test_a_key_on_a_dropped_copy_that_differs_is_refused() -> None:
    doc = Doc(start=10)
    root, solo, a, b, clip_a, clip_b = _tree(doc, colour_b="FFFF0000", extra=False)
    other = doc("LinearAnimation", doc("KeyedObject", doc("KeyedProperty", doc(
        "KeyFrameDouble", frame=0, value=0.5, interpolationType="hold"), property="opacity"),
        objectId=b.children[0].ref()), name="wobble", duration=1)
    root.add(other)
    with pytest.raises(ValueError, match="wobble"):
        wd.dedupe(Doc(start=1000), root, [wd.Merge(solo, {"a": a, "b": b}, "S", {"a": [clip_a], "b": [clip_b]})])


# ------------------------------------------------------------------ the generated avatar

@pytest.fixture(scope="module")
def root() -> ET.Element:
    return ET.parse(RML).getroot()


@pytest.fixture(scope="module")
def board(root: ET.Element) -> ET.Element:
    return root.find("Artboard")


@pytest.fixture(scope="module")
def base_root() -> ET.Element:
    try:
        text = subprocess.run(["git", "show", f"{BASE}:rive/avatar/avatar.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {BASE} not available")
    return ET.fromstring(text)


def _solos(root: ET.Element, name: str) -> list[ET.Element]:
    return [s for s in root.iter("Solo") if s.get("name") == name]


def _clip(board: ET.Element, name: str) -> ET.Element:
    return next(a for a in board.findall("LinearAnimation") if a.get("name") == name)


def _clip_keys(clip: ET.Element) -> dict[tuple[str, str], str]:
    return {(o.get("objectId"), p.get("property")): p[0].get("value") for o in clip.findall("KeyedObject")
            for p in o}


def test_one_sleeve_set_per_kind_and_one_hand(root: ET.Element) -> None:
    for name, prefix in (("UpperSleeve", "Up_"), ("ForeSleeve", "Fore_")):
        solos = _solos(root, name)
        assert len(solos) == 2
        for s in solos:
            assert sorted(c.get("name") for c in s) == sorted(prefix + k for k in KINDS)
    hands = _solos(root, "HandSkin")
    assert len(hands) == 2
    for h in hands:
        assert [c.get("name") for c in h] == ["Skin_shared"]
        assert len([s for s in h.iter("Solo") if s.get("name") == "HandPose"]) == 1
        # the glove seams moved in and are hidden on the bare hand (the default)
        seams = [e for e in h.iter("Shape") if e.get("name", "").startswith("Glove")]
        assert seams and all(e.get("opacity") == "0" for e in seams)


def _inside(root: ET.Element, group_name: str) -> set[str]:
    return {e.get("id") for g in root.iter("Node") if g.get("name") == group_name for e in g.iter()}


def test_long_sleeve_colours_key_in_every_long_top_clip(root: ET.Element, board: ET.Element) -> None:
    inside = _inside(root, "Up_long") | _inside(root, "Fore_long")
    keyed = {t: {k: v for k, v in _clip_keys(_clip(board, "top_" + t)).items() if k[0] in inside} for t in TOPS}
    sets = {t: set(k) for t, k in keyed.items()}
    assert sets["pinkHoodie"] and all(sets[t] == sets["pinkHoodie"] for t in LONG)  # history-free
    assert not any(sets[t] for t in TOPS if t not in LONG)                          # other tops hide the set
    for a, b in ((x, y) for x in LONG for y in LONG if x < y):
        assert keyed[a] != keyed[b], (a, b)
    # the static drawing is the default outfit's
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    for (oid, prop), v in keyed["pinkHoodie"].items():
        static = ids[oid].get(prop, "1")
        assert static == v or float(static) == float(v), (ids[oid].get("name"), prop)
    # the christmas band is drawn by the sweater only
    band = [e.get("id") for g in root.iter("Node") if g.get("name") == "Up_long" for e in g if e.get("name") == "Band"]
    assert len(band) == 2
    for t in LONG:
        assert {float(keyed[t][(b, "opacity")]) for b in band} == {1.0 if t == "christmasSweater" else 0.0}


def test_hand_paint_keys_in_every_costume_clip_only(root: ET.Element, board: ET.Element) -> None:
    inside = _inside(root, "Skin_shared")
    keyed = {c: {k: v for k, v in _clip_keys(_clip(board, "costume_" + c)).items() if k[0] in inside}
             for c in COSTUMES}
    assert keyed["none"] and all(set(keyed[c]) == set(keyed["none"]) for c in COSTUMES)
    assert len({tuple(sorted(k.items())) for k in keyed.values()}) == len(COSTUMES)
    for t in TOPS:
        assert not [k for k in _clip_keys(_clip(board, "top_" + t)) if k[0] in inside and k[1] != "activeComponentId"]
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    for (oid, prop), v in keyed["none"].items():
        static = ids[oid].get(prop, "1")
        assert static == v or float(static) == float(v), (ids[oid].get("name"), prop)


def test_every_wardrobe_clip_keys_an_object_once(board: ET.Element) -> None:
    for clip in board.findall("LinearAnimation"):
        if not clip.get("name").startswith(("top_", "costume_")):
            continue
        objs = [o.get("objectId") for o in clip.findall("KeyedObject")]
        assert len(objs) == len(set(objs)), clip.get("name")


def test_wardrobe_layers_are_unchanged(board: ET.Element, base_root: ET.Element) -> None:
    def layers(b: ET.Element) -> dict[str, list[tuple[str, list[str]]]]:
        anims = {a.get("id"): a.get("name") for a in b.findall("LinearAnimation")}
        return {la.get("name"): [(anims[s.get("animationId")], [t.get("stateToId") for t in s.iter("StateTransition")])
                                 for s in la.iter("AnimationState")]
                for la in b.iter("StateMachineLayer") if la.get("name") in WARDROBE_LAYERS}
    assert layers(board) == layers(base_root.find("Artboard"))
    names = [la.get("name") for la in board.iter("StateMachineLayer")]
    assert [n for n in names if n in WARDROBE_LAYERS] == list(WARDROBE_LAYERS)


def test_m9_ids_survive_and_new_ids_take_the_m10_range(root: ET.Element, base_root: ET.Element) -> None:
    new = {e.get("id"): e for e in root.iter() if e.get("id")}
    old = {e.get("id"): e for e in base_root.iter() if e.get("id")}
    solos = ("UpperSleeve", "ForeSleeve", "HandSkin")
    copies = {e.get("id") for s in base_root.iter("Solo") if s.get("name") in solos for g in s
              if g.get("id") not in new for e in g.iter()} - set(new)
    keys = {e.get("id") for o in base_root.iter("KeyedObject") if o.get("objectId") in copies for e in o.iter()}
    for i, e in old.items():
        if i in copies or i in keys:
            continue
        assert i in new and new[i].tag == e.tag, (e.tag, e.get("name"), i)
    # what was dropped: every per-outfit sleeve copy of a shared kind and four of the five hand skins
    dropped_groups = {e.get("name") for s in base_root.iter("Solo") if s.get("name") in solos for e in s
                      if e.get("id") in copies}
    assert dropped_groups == {"Up_longCoat", "Up_christmasSweater", "Up_blackSuitAndTie", "Up_swimsuit",
                              "Fore_longCoat", "Fore_christmasSweater", "Fore_blackSuitAndTie", "Fore_swimsuit",
                              "Skin_black", "Skin_metal", "Skin_stars", "Skin_white"}
    added = set(new) - set(old)
    assert added and all(int(i.split(":")[1]) >= kit.M10_ID_START for i in added), sorted(added)[:5]
