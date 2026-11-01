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
    assert _bound(_named(tree, "SnowNear"), tree) == {"rain"}
    assert _bound(_named(tree, "SnowFar"), tree) == {"rain", "tier"}   # M11: its sheet is the high tier's gate
    assert "festive" in _bound(_named(tree, "FestiveDecor"), tree)
    assert "festive" in _bound(_named(tree, "FestiveLights"), tree)
    assert "fog" in _bound(_named(tree, "FogVeil0"), tree) and "fog" in _bound(_named(tree, "FogBank"), tree)
    assert {"daylight"} == _bound(_named(tree, "SkyDay"), tree) and {"dusk"} == _bound(_named(tree, "SkyDusk"), tree)
    # snow, never rain: no rain streak sheets in this scene
    assert not any(e.get("name", "").startswith(("RainSheet", "RainLoop", "GlassStreak")) for e in tree.iter())


def test_riv_within_budget() -> None:
    assert RIV.exists()
    assert RIV.stat().st_size <= 409_600


def test_dog_drawing_switch_cuts_on_its_own_layer(tree: ET.Element) -> None:
    """M12 ruling 7: the drawing copies' opacity is keyed only by the `NpcDraw` layer (one 1-frame hold per
    state, every transition 0 ms), so the `Npc` layer's 200 ms pose blend never cross-fades two copies."""
    ab = _artboard(tree)
    ids = {n: _named(tree, n).get("id") for n in ("DogAsleep", "DogSit", "DogWalk")}
    layers = {lay.get("name"): lay for lay in ab.iter("StateMachineLayer")}
    anims = {a.get("id"): a for a in ab.iter("LinearAnimation")}

    def keyed(anim: ET.Element) -> dict[str, float]:
        return {ko.get("objectId"): float(kf.get("value")) for ko in anim if ko.tag == "KeyedObject"
                for kp in ko if kp.get("property") == "opacity" for kf in kp}

    def anims_of(layer: ET.Element) -> list[ET.Element]:
        return [anims[s.get("animationId")] for s in layer.iter() if s.tag in ("AnimationState", "BlendAnimation1D")]
    pose = anims_of(layers["Npc"])
    assert len(pose) == 8 and not any(set(keyed(a)) & set(ids.values()) for a in pose)
    draw = layers["NpcDraw"]
    shown = {"away": "DogAsleep", "rest": "DogAsleep", "idle": "DogSit", "move": "DogWalk", "notice": "DogSit",
             "react": "DogSit"}
    by_name = {a.get("name"): a for a in anims_of(draw)}
    assert sorted(by_name) == sorted(f"npc_dog_draw_{k}" for k in scene_npc.NPC_STATES)
    for k, n in shown.items():
        a = by_name[f"npc_dog_draw_{k}"]
        assert int(a.get("duration")) == 1
        assert keyed(a) == {i: float(i == ids[n]) for i in ids.values()}, k
    ts = [t for t in draw.iter() if t.tag in ("StateTransition", "BlendStateTransition") and t.get("stateToId")]
    assert len(ts) == 2 * (len(scene_npc.NPC_STATES) - 1) + 1     # AnyState -> 5, 5 -> rest, entry -> rest
    assert all(int(t.get("duration", "0")) == 0 for t in ts)
    # only this layer keys the copies' opacity anywhere in the file
    owners = {a.get("name") for a in anims.values() if set(keyed(a)) & set(ids.values())}
    assert owners == set(by_name)
