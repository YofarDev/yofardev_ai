"""Tests for the v12 scene `rooftop` (moonshot M9 Task 3b, scene_rooftop.py): RML-level checks of the
contract (artboard, state machine, SceneVM order and defaults, events, props), the diorama planes,
the pigeon's states, the `aim` drag and `moonPhase` binds, the front layer and the budget."""

from __future__ import annotations

from pathlib import Path
import math
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_npc  # noqa: E402
import scene_rooftop  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
COMMITTED = ROOT / "rive" / "scenes" / "rooftop" / "rooftop.rml"
RIV = ROOT / "assets" / "rive" / "scenes" / "rooftop.riv"


@pytest.fixture(scope="module")
def text(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.SCENE_BUILDERS["rooftop"]()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.fixture(scope="module")
def doc(text: str) -> ET.Element:
    return ET.fromstring(text)


def _scene(doc: ET.Element) -> ET.Element:
    return next(a for a in doc.findall("Artboard") if a.get("name") == "Scene")


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.findall("ViewModel") if v.get("name") == "SceneVM")


def _path(doc: ET.Element, name: str) -> str:
    vm = _vm(doc)
    p = next(p for p in vm if p.get("name") == name)
    return f"{vm.get('id')}-{p.get('id')}"


def test_generator_is_deterministic_and_committed(text: str) -> None:
    assert text == COMMITTED.read_text()


def test_artboard_and_state_machine(doc: ET.Element) -> None:
    ab = doc.find("Artboard")
    assert ab.get("name") == "Scene"
    assert (ab.get("width"), ab.get("height")) == ("1080", "1920")
    sms = [s for s in ab if s.tag == "StateMachine"]
    assert [s.get("name") for s in sms] == ["Main"]
    assert ab.get("defaultStateMachineId") == sms[0].get("id")
    assert ab.get("viewModelId") == _vm(doc).get("id")


def test_scene_vm_members_in_contract_order(doc: ET.Element) -> None:
    got = [p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")]
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults("rooftop")),
            "fog", "npc", "npcX", "npcLook", *(n for n, _, _ in world_kit.v12_members("rooftop"))]
    assert got == want
    assert world_kit.drag_numbers("rooftop") == ("aim",)
    defaults = {}
    vm = _vm(doc)
    ids = {p.get("id"): p.get("name") for p in vm if p.tag.startswith("ViewModelProperty")}
    for v in vm.iter("ViewModelInstanceNumber"):
        defaults[ids[v.get("viewModelPropertyId")]] = float(v.get("propertyValue"))
    assert defaults["moonPhase"] == -1.0 and defaults["aim"] == 0.0 and defaults["festive"] == 0.0


def test_four_events_are_one_shots(doc: ET.Element) -> None:
    enum = next(e for e in doc.findall("DataEnumCustom") if e.get("name") == "EventId")
    assert [v.get("key") for v in enum] == ["fireworks", "plane", "shootingStar", "windowsLit"]
    layers = {lay.get("name") for lay in _scene(doc).iter("StateMachineLayer")}
    for ev in ("fireworks", "plane", "shootingStar", "windowsLit"):
        assert f"Event_{ev}" in layers
    anims = {a.get("name"): int(a.get("duration")) for a in _scene(doc).iter("LinearAnimation")}
    assert anims["ev_fireworks"] == scene_rooftop.FIREWORKS_FRAMES
    assert anims["ev_plane"] == scene_rooftop.PLANE_FRAMES
    assert anims["ev_windowsLit"] == scene_rooftop.WINDOWS_LIT_FRAMES
    assert anims["ev_ShootingStar"] == scene_rooftop.SHOOTING_STAR_FRAMES   # gen_scenes.streak_fx names it


def test_four_props_ride_their_planes(doc: ET.Element) -> None:
    ab = _scene(doc)
    want = {"telescope": 4, "antenna": 4, "pigeon": 4, "moon": 0}
    got = {}
    for plane in ab:
        if plane.get("name", "").startswith("Plane"):
            for c in plane:
                if c.get("name", "").startswith("Hit_"):
                    got[c.get("name")[4:]] = int(plane.get("name")[5:])
    assert got == want
    props = sorted(p.get("propertyValue") for e in ab.iter("Event") if e.get("name") == "prop_tapped"
                   for p in e if p.get("name") == "propId")
    assert props == sorted(want)
    assert {lst.get("name") for lst in ab.iter("StateMachineListenerSingle")} == {f"Tap_{p}" for p in want}


def test_six_parallax_planes(doc: ET.Element) -> None:
    ab = _scene(doc)
    planes = [c.get("name") for c in ab if c.get("name", "").startswith("Plane")]
    assert planes == [f"Plane{k}" for k in range(5, -1, -1)]
    px = _path(doc, "parallaxX")
    convs = {c.get("id"): c for c in doc.findall("DataConverterFormula")}
    for k in range(1, 6):
        plane = next(c for c in ab if c.get("name") == f"Plane{k}")
        (b,) = [b for b in plane if b.tag == "DataBindContext" and b.get("sourcePathIds") == px]
        assert world_kit.eval_formula(convs[b.get("converterId")], 1.0) == pytest.approx(
            gen_scenes.PARALLAX_GAINS[k] * gen_scenes.PARALLAX_TRAVEL[0])


def test_pigeon_has_the_six_states(doc: ET.Element) -> None:
    layer = next(lay for lay in _scene(doc).iter("StateMachineLayer") if lay.get("name") == "Npc")
    states = [s for s in layer if s.tag in ("AnimationState", "BlendState1DViewModel")]
    assert len(states) == 6
    assert sum(s.tag == "BlendState1DViewModel" for s in states) == 1   # notice, aimed by npcLook
    enum = next(e for e in doc.findall("DataEnumCustom") if e.get("name") == "NpcState")
    assert [v.get("key") for v in enum] == list(scene_npc.NPC_STATES)
    anims = {a.get("name"): int(a.get("duration")) for a in _scene(doc).iter("LinearAnimation")}
    assert anims["npc_pigeon_idle"] == scene_rooftop.PIGEON_IDLE
    assert anims["npc_pigeon_move"] == scene_rooftop.PIGEON_WALK
    assert anims["npc_pigeon_react"] == scene_rooftop.PIGEON_REACT
    assert {f"npc_pigeon_notice{s}" for s in "LCR"} <= set(anims)
    # its node and its poke zone follow npcX
    npcx = _path(doc, "npcX")
    for name in ("PigeonNpc", "Hit_pigeon"):
        el = next(e for e in _scene(doc).iter() if e.get("name") == name)
        assert {b.get("propertyKey") for b in el if b.tag == "DataBindContext" and b.get("sourcePathIds") == npcx} \
            == {"13", "14"}


def test_aim_swivels_the_tube_and_moon_phase_is_bound(doc: ET.Element) -> None:
    aim = _path(doc, "aim")
    convs = {c.get("id"): c for c in doc.findall("DataConverterFormula")}
    tube = next(e for e in _scene(doc).iter("Node") if e.get("name") == "TubeAim")
    (b,) = [b for b in tube if b.tag == "DataBindContext"]
    assert (b.get("sourcePathIds"), b.get("propertyKey")) == (aim, "15")
    assert world_kit.eval_formula(convs[b.get("converterId")], 1.0) == pytest.approx(math.radians(35), abs=1e-3)
    assert float(tube.get("rotation", 0)) == 0.0   # at the default the tube rests
    vm = _vm(doc)
    v12 = {p.get("id"): p.get("name") for p in vm if p.get("name") in {n for n, _, _ in world_kit.v12_members("rooftop")}}
    bound = set()
    for ab in doc.findall("Artboard"):
        bound |= world_kit.bound_names(ab, vm.get("id"), v12)
    for c in doc.findall("DataConverterFormula"):
        bound |= world_kit.bound_names(c, vm.get("id"), v12)
    assert bound == scene_rooftop.BINDS == {"moonPhase", "aim"}
    assert any(e.get("name") == "MoonRig" for e in _scene(doc).iter("Node"))


def test_aim_rect_holds_the_telescope() -> None:
    x0, y0, x1, y1 = scene_rooftop.aim_rect()
    px, py = scene_rooftop.TELESCOPE_PIVOT
    assert 0 <= x0 < px < x1 <= 1080 and 0 <= y0 < py < y1 <= 1920
    # clear of the pigeon's poke zone on the cap and of the avatar's band (x 330..750) but its edge
    hx, hy, _, hh = scene_rooftop.PIGEON_HIT
    assert y0 > scene_rooftop.PIGEON_WAYPOINTS[0][1] + hy + hh / 2
    assert x0 > 700


def test_scene_front_and_rain(doc: ET.Element) -> None:
    assert "rooftop" in gen_scenes.FRONT_SCENES
    fronts = [a for a in doc.findall("Artboard") if a.get("name") == "SceneFront"]
    assert len(fronts) == 1
    rain = _path(doc, "rain")
    ab = _scene(doc)
    for name in ("RainLoop", "ParapetRain", "RoofWet", "SkyOvercast"):
        el = next(e for e in ab.iter() if e.get("name") == name and e.tag in ("Node", "Shape"))
        assert any(b.get("sourcePathIds") == rain for b in el if b.tag == "DataBindContext"), name


def test_fog_daylight_and_light_rig_binds(doc: ET.Element) -> None:
    text = ET.tostring(doc, encoding="unicode")
    for name in ("fog", "daylight", "dusk", "lightRim", "lightKey", "lightFog"):
        assert f'sourcePathIds="{_path(doc, name)}"' in text, name
    assert "FogBank" in text and all(f"FogVeil{k}" in text for k in range(3))


def test_pigeon_walk_matches_the_dart_walk() -> None:
    # NpcDirector.pigeonWalkLength is 3 s for the whole path: the cycle's travel is within 15 % of it
    assert 1 / scene_rooftop.pigeon_walk_speed() == pytest.approx(3.0, rel=0.15)


def test_budget() -> None:
    assert RIV.stat().st_size <= 409_600
    assert (ROOT / "assets" / "rive" / "posters" / "rooftop.webp").stat().st_size <= 40_960
