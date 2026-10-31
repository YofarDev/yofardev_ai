"""Tests for the v12 scene `mountainHut` (moonshot M9 Task 3c, rulings 1, 3, 8, 11-13): RML level."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_mountain_hut as hut  # noqa: E402
import scene_npc  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
COMMITTED = ROOT / "rive" / "scenes" / "mountainHut" / "mountainHut.rml"
RIV = ROOT / "assets" / "rive" / "scenes" / "mountainHut.riv"
EVENTS = ["snowfall", "flare", "aurora", "bell"]
PROPS = {"stove": 3, "window": 1, "dog": 4, "bell": 3}


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(hut.mountainHut()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.fixture(scope="module")
def tree(rml: str) -> ET.Element:
    return ET.fromstring(rml)


def _artboard(tree: ET.Element) -> ET.Element:
    return next(a for a in tree.iter("Artboard") if a.get("name") == "Scene")


def _vm_names(tree: ET.Element) -> dict[str, str]:
    vm = next(v for v in tree.iter("ViewModel") if v.get("name") == "SceneVM")
    return {p.get("id"): p.get("name") for p in vm if p.tag.startswith("ViewModelProperty")}


def _bound(e: ET.Element, tree: ET.Element) -> set[str]:
    vm = next(v for v in tree.iter("ViewModel") if v.get("name") == "SceneVM")
    names = _vm_names(tree)
    out = set()
    for b in e.iter("DataBindContext"):
        path = b.get("sourcePathIds", "")
        if path.startswith(vm.get("id") + "-"):
            out.add(names.get(path.split("-", 1)[1], "?"))
    return out


def _named(tree: ET.Element, name: str) -> ET.Element:
    """The element named `name` (light sources carry the diorama's `emit` prefix)."""
    return next(e for e in tree.iter() if e.get("name") in (name, "emit" + name))


def test_generator_is_deterministic_and_committed(rml: str) -> None:
    assert rml == COMMITTED.read_text()


def test_registered_in_the_world_kit() -> None:
    assert world_kit.SCENE_MODULES["mountainHut"] == "scene_mountain_hut"
    assert "mountainHut" in gen_scenes.DIORAMAS and "mountainHut" in gen_scenes.TIME_SKY
    assert hut.BINDS == {"moonPhase", "festive", "rope"}
    assert world_kit.declared_binds("mountainHut") == frozenset(hut.BINDS)


def test_artboard_state_machine_and_view_model_in_contract_order(tree: ET.Element) -> None:
    ab = _artboard(tree)
    assert (ab.get("width"), ab.get("height")) == ("1080", "1920")
    assert [s.get("name") for s in ab.iter("StateMachine")] == ["Main"]
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults("mountainHut")), "fog", "npc", "npcX",
            "npcLook", *(n for n, _, _ in world_kit.vm_tail("mountainHut"))]
    assert list(_vm_names(tree).values()) == want
    assert want[-1] == "rope"
    events = next(e for e in tree.iter("DataEnumCustom") if e.get("name") == "EventId")
    assert [v.get("key") for v in events] == EVENTS
    assert not any(a.get("name") == "SceneFront" for a in tree.iter("Artboard"))   # the weather is outside


def test_four_events_play_one_shots(tree: ET.Element) -> None:
    layers = {lay.get("name") for lay in _artboard(tree).iter("StateMachineLayer")}
    anims = {a.get("name"): int(a.get("duration")) for a in _artboard(tree).iter("LinearAnimation")}
    for ev in EVENTS:
        assert f"Event_{ev}" in layers
        assert anims[f"ev_{ev}"] == hut.EVENT_FRAMES[ev]


def test_four_props_in_the_plane_of_their_art(tree: ET.Element) -> None:
    ab = _artboard(tree)
    planes = {p.get("name"): p for p in ab if p.get("name", "").startswith("Plane")}
    assert sorted(planes) == [f"Plane{k}" for k in range(6)]
    for prop, k in PROPS.items():
        assert any(c.get("name") == f"Hit_{prop}" for c in planes[f"Plane{k}"]), prop
    fired = sorted(p.get("propertyValue") for e in ab.iter("Event") if e.get("name") == "prop_tapped"
                   for p in e.iter("CustomPropertyString"))
    assert fired == sorted(PROPS)


def test_six_parallax_planes_paint_back_to_front(rml: str) -> None:
    at = [rml.index(f'name="Plane{k}"') for k in range(5, -1, -1)]
    assert at == sorted(at)
    assert rml.index('name="emitFlareWash"') < at[0]   # the flare's wash: a screen overlay


def test_dog_states_and_path(tree: ET.Element) -> None:
    ab = _artboard(tree)
    npc = next(lay for lay in ab.iter("StateMachineLayer") if lay.get("name") == "Npc")
    anims = {a.get("id"): a.get("name") for a in ab.iter("LinearAnimation")}
    states = [anims[s.get("animationId")] for s in npc if s.tag == "AnimationState"]
    blends = [[anims[b.get("animationId")] for b in s.iter("BlendAnimation1D")] for s in npc
              if s.tag == "BlendState1DViewModel"]
    assert sorted(states) == sorted(f"npc_dog_{k}" for k in ("rest", "away", "idle", "move", "react"))
    assert blends == [["npc_dog_noticeL", "npc_dog_noticeC", "npc_dog_noticeR"]]
    assert scene_npc.NPC_STATES == ("away", "rest", "idle", "move", "notice", "react")
    dog = _named(tree, "DogNpc")
    assert {"npcX"} <= _bound(dog, tree)
    hit = _named(tree, "Hit_dog")
    assert "npcX" in _bound(hit, tree)
    lengths = {a.get("name"): int(a.get("duration")) for a in ab.iter("LinearAnimation")}
    assert lengths["npc_dog_idle"] == hut.DOG_IDLE and lengths["npc_dog_move"] == hut.DOG_WALK
    assert lengths["npc_dog_rest"] == hut.DOG_REST_LOOP


def test_rope_drag_binds_the_rope_the_toggle_and_the_bell_tilt(tree: ET.Element) -> None:
    # RopeSwing itself is keyed by the bell event only (its own binds; the rope and toggle inside bind `rope`)
    assert not [c for c in _named(tree, "RopeSwing") if c.tag == "DataBindContext"]
    for name in ("Rope", "RopeToggle", "BellTilt"):
        assert _bound(_named(tree, name), tree) == {"rope"}, name
    # at the default (rope 0) the art is at rest: the static values are the converters' at 0
    assert float(_named(tree, "RopeToggle").get("y")) == pytest.approx(4 + hut.ROPE_LEN)   # in RopeSwing's frame
    assert (float(_named(tree, "RopeSwing").get("x")), float(_named(tree, "RopeSwing").get("y"))) == hut.PULLEY
    x0, y0, x1, y1 = hut.ROPE_RECT
    assert x0 < hut.PULLEY[0] < x1 and y0 <= hut.PULLEY[1] and hut.PULLEY[1] + 4 + hut.ROPE_LEN + hut.ROPE_PULL \
        + hut.TOGGLE_H + 4 <= y1


def test_moon_snow_fog_festive_binds(tree: ET.Element) -> None:
    assert _bound(_named(tree, "MoonRig"), tree) == {"moonPhase"}
    assert "moonPhase" in _bound(_named(tree, "MoonDrawn"), tree)
    assert _bound(_named(tree, "SnowNear"), tree) == {"rain"} and _bound(_named(tree, "SnowFar"), tree) == {"rain"}
    assert "festive" in _bound(_named(tree, "FestiveDecor"), tree)
    assert "festive" in _bound(_named(tree, "FestiveLights"), tree)
    assert "fog" in _bound(_named(tree, "FogVeil0"), tree) and "fog" in _bound(_named(tree, "FogBank"), tree)
    assert {"daylight"} == _bound(_named(tree, "SkyDay"), tree) and {"dusk"} == _bound(_named(tree, "SkyDusk"), tree)
    # snow, never rain: no rain streak sheets in this scene
    assert not any(e.get("name", "").startswith(("RainSheet", "RainLoop", "GlassStreak")) for e in tree.iter())


def test_riv_within_budget() -> None:
    assert RIV.exists()
    assert RIV.stat().st_size <= 409_600
