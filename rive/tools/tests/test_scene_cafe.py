"""Moonshot M9 lane S1 (contract v12): the new scene `cafe`, on freshly generated RML (rulings 3, 8, 11-13)."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_cafe  # noqa: E402
import scene_npc  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SID = "cafe"
COMMITTED = ROOT / "rive" / "scenes" / SID / f"{SID}.rml"
SCENE_MAX = 409_600


@pytest.fixture(scope="module")
def text(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.SCENE_BUILDERS[SID]()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.fixture(scope="module")
def doc(text: str) -> ET.Element:
    return ET.fromstring(text)


def _board(doc: ET.Element) -> ET.Element:
    return next(a for a in doc.iter("Artboard") if a.get("name") == "Scene")


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")


def _names(doc: ET.Element) -> dict[str, str]:
    """property id -> name."""
    return {p.get("id"): p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")}


def _sm(doc: ET.Element) -> ET.Element:
    return next(s for s in _board(doc).iter("StateMachine") if s.get("name") == "Main")


def test_generator_is_deterministic_and_committed(text: str) -> None:
    assert text == COMMITTED.read_text()


def test_registered_through_the_world_kit() -> None:
    assert world_kit.scene_module(SID) is scene_cafe
    assert gen_scenes.DIORAMAS[SID].planes is scene_cafe.PLANES
    assert world_kit.declared_binds(SID) == frozenset(scene_cafe.BINDS)
    assert set(scene_cafe.REVIEW) == {"diorama", "extras", "time", "npc"}


def test_artboard_state_machine_and_one_artboard(doc: ET.Element) -> None:
    boards = [a.get("name") for a in doc.iter("Artboard")]
    assert boards == ["Scene"]   # indoor: no SceneFront (the weather is outside the window)
    ab = _board(doc)
    assert (float(ab.get("width")), float(ab.get("height"))) == (1080.0, 1920.0)
    assert ab.get("defaultStateMachineId") == _sm(doc).get("id")
    assert ab.get("viewModelId") == _vm(doc).get("id")


def test_scene_vm_holds_every_contract_member_in_order(doc: ET.Element) -> None:
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults(SID)), "fog", "npc", "npcX",
            "npcLook", *(n for n, _, _ in world_kit.vm_tail(SID))]
    assert [p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")] == want
    # the drag numbers are the trail's (contract: `wipe`, kind trail)
    assert world_kit.drag_numbers(SID) == tuple(n for n, _ in world_kit.TRAIL_NUMBERS)
    inst = next(i for i in _vm(doc) if i.tag == "ViewModelInstance")
    vals = {_names(doc)[v.get("viewModelPropertyId")]: v.get("propertyValue") for v in inst}
    assert float(vals["moonPhase"]) == -1 and float(vals["festive"]) == 0
    assert float(vals["trailN"]) == 0 and float(vals["trailFade"]) == 1


def test_four_events_play_one_shots(doc: ET.Element) -> None:
    enum = next(e for e in doc.iter("DataEnumCustom") if e.get("name") == "EventId")
    values = [v.get("key") for v in enum]
    assert values == ["espresso", "doorbell", "rain", "neonFlicker"] == gen_scenes.SCENE_EVENTS[SID]
    layers = {lay.get("name"): lay for lay in _sm(doc).iter("StateMachineLayer")}
    anims = {a.get("id"): a for a in _board(doc).iter("LinearAnimation")}
    for ev in values:
        lay = layers[f"Event_{ev}"]
        played = [anims[s.get("animationId")] for s in lay.iter("AnimationState")]
        main = next(a for a in played if a.get("name") == f"ev_{ev}")
        assert main.get("loopValue") is None    # a one-shot
        assert int(main.get("duration")) == scene_cafe.EV_FRAMES[ev]


def test_four_props_in_the_planes_of_their_art(doc: ET.Element) -> None:
    ab = _board(doc)
    where = {}
    for plane in ab:
        if plane.get("name", "").startswith("Plane"):
            for c in plane:
                if c.get("name", "").startswith("Hit_"):
                    where[c.get("name")[4:]] = int(plane.get("name")[5:])
    assert where == {"cup": 4, "espresso": 3, "window": 2, "fish": 3}
    events = {e.get("id"): e for e in ab.iter("Event")}
    fired = set()
    for lis in _sm(doc).iter("StateMachineListenerSingle"):
        ev = events[lis.find("ListenerFireEvent").get("eventId")]
        assert ev.get("name") == "prop_tapped"
        fired.add(ev.find("CustomPropertyString").get("propertyValue"))
    assert fired == {"cup", "espresso", "window", "fish"}


def test_six_parallax_planes(doc: ET.Element) -> None:
    names = [c.get("name") for c in _board(doc) if c.get("name", "").startswith("Plane")]
    assert names == [f"Plane{k}" for k in range(5, -1, -1)]   # first declared paints in front


def test_the_fish_npc_has_its_six_states(doc: ET.Element) -> None:
    lay = next(lay for lay in _sm(doc).iter("StateMachineLayer") if lay.get("name") == "Npc")
    anims = {a.get("id"): a.get("name") for a in _board(doc).iter("LinearAnimation")}
    plain = {anims[s.get("animationId")] for s in lay.iter("AnimationState")}
    assert plain == {f"npc_fish_{k}" for k in ("rest", "away", "idle", "move", "react")}
    blend = [anims[b.get("animationId")] for b in lay.iter("BlendAnimation1D")]
    assert blend == ["npc_fish_noticeL", "npc_fish_noticeC", "npc_fish_noticeR"]
    enum = next(e for e in doc.iter("DataEnumCustom") if e.get("name") == "NpcState")
    assert [v.get("key") for v in enum] == list(scene_npc.NPC_STATES)


def test_the_fish_and_its_poke_ride_npc_x(doc: ET.Element) -> None:
    names = _names(doc)
    ab = _board(doc)
    vm = _vm(doc).get("id")
    for name in ("FishNpc", "Hit_fish"):
        e = next(x for x in ab.iter() if x.get("name") == name)
        keys = {(names[b.get("sourcePathIds").split("-")[1]], b.get("propertyKey"))
                for b in e.findall("DataBindContext") if b.get("sourcePathIds", "").startswith(vm + "-")}
        assert {("npcX", "13"), ("npcX", "14")} <= keys, name
    facing = next(x for x in ab.iter("Node") if x.get("name") == "FishFacing")
    b = facing.find("DataBindContext")
    assert names[b.get("sourcePathIds").split("-")[1]] == "npcLook" and b.get("propertyKey") == "16"


def test_v12_binds_moon_festive_and_the_wipe(doc: ET.Element) -> None:
    v12 = {pid: n for pid, n in _names(doc).items() if n in {m for m, _, _ in world_kit.v12_members(SID)}}
    got = set()
    for e in (doc, ):
        got |= world_kit.bound_names(e, _vm(doc).get("id"), v12)
    assert got == scene_cafe.BINDS == {"moonPhase", "festive", *world_kit.drag_numbers(SID)}
    assert not got & set(world_kit.NPC2_NAMES)


def test_wipe_cuts_holes_in_the_mist_at_the_planes_origin(doc: ET.Element) -> None:
    # M10 (plan ruling 15): the wiped spots are holes in the `Mist` (no darken marks any more); the
    # holes' formulas and the soft rings are covered by test_m10_notes.py
    plane2 = next(c for c in _board(doc) if c.get("name") == "Plane2")
    assert not [c for c in plane2 if c.get("name") == "TrailDots"]
    mist = next(c for c in plane2 if c.get("name") == "Mist")
    assert (float(mist.get("x")), float(mist.get("y"))) == (0.0, 0.0)
    holes = [e for e in mist if e.tag == "Ellipse"]
    assert len(holes) == world_kit.TRAIL_DOTS and {h.get("isHole") for h in holes} == {"true"}
    assert not [e for e in plane2.iter() if e.get("blendModeValue") == "16"]
    # the proof stroke stays inside the handle rect by a spot's radius
    x0, y0, x1, y1 = scene_cafe.GLASS
    r = scene_cafe.TRAIL_R
    assert all(x0 + r <= x <= x1 - r and y0 + r <= y <= y1 - r for x, y in scene_cafe.TRAIL_PROOF)


def test_moon_rig_and_drawn_moon_share_plane0(doc: ET.Element) -> None:
    plane0 = next(c for c in _board(doc) if c.get("name") == "Plane0")
    kids = [c.get("name", "") for c in plane0]
    assert "emitMoonRig" in kids and "emitMoonArt" in kids


def test_festive_lights_and_wreath(doc: ET.Element) -> None:
    plane3 = next(c for c in _board(doc) if c.get("name") == "Plane3")
    assert any(c.get("name") == "FestiveLights" for c in plane3)
    names = [n.get("name") for n in _board(doc).iter("Node")]
    assert "Wreath" in names and "WreathLights" in names


def test_riv_budget() -> None:
    riv = ROOT / "assets" / "rive" / "scenes" / f"{SID}.riv"
    if not riv.exists():
        pytest.skip("not built")
    assert riv.stat().st_size <= SCENE_MAX
    poster = ROOT / "assets" / "rive" / "posters" / f"{SID}.webp"
    assert poster.exists() and poster.stat().st_size <= 40_960
