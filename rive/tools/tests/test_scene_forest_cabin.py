"""Tests for the v14 scene `forestCabin` (moonshot M11 Task 2, lane S1, rulings 1, 2, 7, 8, 9, 13): RML level."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_forest_cabin as cab  # noqa: E402
import scene_npc  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SID = "forestCabin"
COMMITTED = ROOT / "rive" / "scenes" / SID / f"{SID}.rml"
RIV = ROOT / "assets" / "rive" / "scenes" / f"{SID}.riv"
POSTER = ROOT / "assets" / "rive" / "posters" / f"{SID}.webp"
EVENTS = ["gust", "fireflies", "rain", "lanternFlicker"]
PROPS = {"lantern": 3, "pinwheel": 3, "squirrel": 3, "woodpile": 4}


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.SCENE_BUILDERS[SID]()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.fixture(scope="module")
def tree(rml: str) -> ET.Element:
    return ET.fromstring(rml)


def _artboard(tree: ET.Element, name: str = "Scene") -> ET.Element:
    return next(a for a in tree.iter("Artboard") if a.get("name") == name)


def _vm(tree: ET.Element) -> ET.Element:
    return next(v for v in tree.iter("ViewModel") if v.get("name") == "SceneVM")


def _vm_names(tree: ET.Element) -> dict[str, str]:
    return {p.get("id"): p.get("name") for p in _vm(tree) if p.tag.startswith("ViewModelProperty")}


def _bound(e: ET.Element, tree: ET.Element) -> set[str]:
    """Every view-model member a bind under `e` reads (converter tokens included)."""
    vm_id = _vm(tree).get("id")
    names = _vm_names(tree)
    convs = {c.get("id"): c for c in tree.iter("DataConverterFormula")}
    out = set()
    for b in e.iter("DataBindContext"):
        path = b.get("sourcePathIds", "")
        if path.startswith(vm_id + "-"):
            out.add(names.get(path.split("-", 1)[1], "?"))
        conv = convs.get(b.get("converterId", ""))
        if conv is not None:
            for t in conv.iter("DataBindContext"):
                out.add(names.get(t.get("sourcePathIds", "").split("-", 1)[1], "?"))
    return out


def _named(tree: ET.Element, name: str) -> ET.Element:
    """The element named `name` (light sources carry the diorama's `emit` prefix)."""
    return next(e for e in tree.iter() if e.get("name") in (name, "emit" + name) and e.tag in ("Node", "Shape"))


def _bind(tree: ET.Element, el: ET.Element, key: int) -> tuple[str, ET.Element | None]:
    names = _vm_names(tree)
    b = next(b for b in el if b.tag == "DataBindContext" and b.get("propertyKey") == str(key))
    conv = next((c for c in tree.iter("DataConverterFormula") if c.get("id") == b.get("converterId")), None)
    return names[b.get("sourcePathIds").split("-")[1]], conv


def _at(tree: ET.Element, el: ET.Element, key: int, x: float) -> float:
    _, conv = _bind(tree, el, key)
    return x if conv is None else world_kit.eval_formula(conv, x, lambda p: 0.0)


# ---------------------------------------------------------------- registry and contract
def test_generator_is_deterministic_and_committed(rml: str) -> None:
    assert rml == COMMITTED.read_text()


def test_registered_in_the_world_kit() -> None:
    assert world_kit.SCENE_MODULES[SID] == "scene_forest_cabin"
    assert SID in gen_scenes.DIORAMAS and SID in gen_scenes.TIME_SKY
    assert SID in scene_npc.FOG_VEILS and SID in scene_npc.FOG_BANKS
    assert cab.BINDS == {"moonPhase", "festive", "pinwheel"}
    assert world_kit.declared_binds(SID) == frozenset(cab.BINDS)
    assert cab.BINDS14 == {"spring", "autumn"} and "tier" not in cab.BINDS14
    assert set(cab.TIER_GATES) == {"high", "low"}
    assert not set(cab.TIER_GATES["high"]) & set(cab.TIER_GATES["low"])


def test_artboard_state_machine_and_view_model_in_contract_order(tree: ET.Element) -> None:
    ab = _artboard(tree)
    assert (ab.get("width"), ab.get("height")) == ("1080", "1920")
    assert [s.get("name") for s in ab.iter("StateMachine")] == ["Main"]
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults(SID)), "fog", "npc", "npcX",
            "npcLook", *(n for n, _, _ in world_kit.vm_tail(SID))]
    assert list(_vm_names(tree).values()) == want
    assert want[-1] == "pinwheel"
    events = next(e for e in tree.iter("DataEnumCustom") if e.get("name") == "EventId")
    assert [v.get("key") for v in events] == EVENTS


def test_defaults_are_the_calm_night(tree: ET.Element) -> None:
    ids = _vm_names(tree)
    nums = {ids[v.get("viewModelPropertyId")]: float(v.get("propertyValue")) for v in _vm(tree).iter("ViewModelInstanceNumber")}
    assert nums["moonPhase"] == -1.0 and nums["pinwheel"] == 0.0 and nums["festive"] == 0.0
    assert nums["spring"] == nums["autumn"] == nums["rain"] == nums["fog"] == nums["daylight"] == 0.0
    # every season / weather / December layer is invisible at its default
    for name in ("MapleAutumn", "MapleBlossom", "PathFlowers", "GroundLeaves", "PorchLeaves", "Pumpkin",
                 "LeafDrift", "PetalDrift", "Wreath", "FestiveLights", "RainLoop", "YardWet", "SkyOvercast",
                 "DayLift", "MoonRig"):
        assert float(_named(tree, name).get("opacity", "1")) == 0.0, name


def test_four_events_play_one_shots(tree: ET.Element) -> None:
    layers = {lay.get("name") for lay in _artboard(tree).iter("StateMachineLayer")}
    anims = {a.get("name"): int(a.get("duration")) for a in _artboard(tree).iter("LinearAnimation")}
    for ev in EVENTS:
        assert f"Event_{ev}" in layers
    assert anims["ev_gust"] == cab.EVENT_FRAMES["gust"] == 180
    assert anims["ev_fireflies"] == cab.EVENT_FRAMES["fireflies"] == 360
    assert anims["ev_Shower"] == cab.EVENT_FRAMES["rain"]
    assert anims["ev_lanternFlicker"] == cab.EVENT_FRAMES["lanternFlicker"] == 90
    # the gust spins the pinwheel on its own wrapper, never the drag-bound node
    gust = next(a for a in _artboard(tree).iter("LinearAnimation") if a.get("name") == "ev_gust")
    keyed = {k.get("objectId") for k in gust}
    assert _named(tree, "PinwheelGust").get("id") in keyed
    assert _named(tree, "PinwheelSpin").get("id") not in keyed
    # its extra spin ends on whole turns (a hold to 0 at the last frame: no backward blend)
    kp = next(k for k in gust if k.get("objectId") == _named(tree, "PinwheelGust").get("id"))
    vals = [float(f.get("value")) for f in kp.iter("KeyFrameDouble")]
    assert vals[0] == vals[-1] == 0.0 and max(vals) == pytest.approx(cab.GUST_SPIN, abs=1e-4)
    assert cab.GUST_SPIN / (math.pi / 2) == pytest.approx(round(cab.GUST_SPIN / (math.pi / 2)))


def test_four_props_in_the_plane_of_their_art(tree: ET.Element) -> None:
    ab = _artboard(tree)
    planes = {p.get("name"): p for p in ab if p.get("name", "").startswith("Plane")}
    assert sorted(planes) == [f"Plane{k}" for k in range(6)]
    for prop, k in PROPS.items():
        assert any(c.get("name") == f"Hit_{prop}" for c in planes[f"Plane{k}"]), prop
    fired = sorted(p.get("propertyValue") for e in ab.iter("Event") if e.get("name") == "prop_tapped"
                   for p in e.iter("CustomPropertyString"))
    assert fired == sorted(PROPS)


def test_six_parallax_planes_paint_back_to_front(rml: str, tree: ET.Element) -> None:
    at = [rml.index(f'name="Plane{k}"') for k in range(5, -1, -1)]
    assert at == sorted(at)
    ab = _artboard(tree)
    tops = [c.get("name") for c in ab if c.tag in ("Node", "Shape")]
    # the screen overlays first (rain, the shower, gust leaves, drifts, the day lift), then Plane5 .. Plane0
    assert tops[-6:] == [f"Plane{k}" for k in range(5, -1, -1)]
    assert {"RainLoop", "ShowerFx", "GustLeaves", "LeafDrift", "PetalDrift", "DayLift"} <= set(tops[:-6])
    for k in range(1, 6):
        plane = next(c for c in ab if c.get("name") == f"Plane{k}")
        assert _bound(plane, tree) >= {"parallaxX", "parallaxY"}


def test_light_rig_defaults_and_the_lantern_flicker(tree: ET.Element) -> None:
    from art_bible import SCENES  # noqa: PLC0415
    s = SCENES[SID]
    ids = _vm_names(tree)
    cols = {ids[v.get("viewModelPropertyId")]: v.get("propertyValue") for v in _vm(tree).iter("ViewModelInstanceColor")}
    assert cols["lightKey"] == s.key and cols["lightRim"] == s.rim and cols["lightFog"] == s.fog
    assert "lightKey" in _bound(_named(tree, "LanternPool"), tree)
    flick = next(a for a in _artboard(tree).iter("LinearAnimation") if a.get("name") == "amb_LanternFlicker")
    vals = [float(f.get("value")) for f in flick.iter("KeyFrameDouble")]
    assert min(vals) == pytest.approx(1 - s.flicker, abs=0.02) and max(vals) == pytest.approx(1.0)


def test_squirrel_states_and_path(tree: ET.Element) -> None:
    ab = _artboard(tree)
    npc = next(lay for lay in ab.iter("StateMachineLayer") if lay.get("name") == "Npc")
    anims = {a.get("id"): a.get("name") for a in ab.iter("LinearAnimation")}
    states = [anims[s.get("animationId")] for s in npc if s.tag == "AnimationState"]
    blends = [[anims[b.get("animationId")] for b in s.iter("BlendAnimation1D")] for s in npc
              if s.tag == "BlendState1DViewModel"]
    assert sorted(states) == sorted(f"npc_squirrel_{k}" for k in ("rest", "away", "idle", "move", "react"))
    assert blends == [["npc_squirrel_noticeL", "npc_squirrel_noticeC", "npc_squirrel_noticeR"]]
    durations = [int(t.get("duration")) for t in npc.iter()
                 if t.tag in ("StateTransition", "BlendStateTransition") and t.get("duration") is not None]
    assert durations and max(durations) <= 200
    sq = _named(tree, "SquirrelNpc")
    assert {"npcX"} <= _bound(sq, tree)
    hit = _named(tree, "Hit_squirrel")
    assert "npcX" in _bound(hit, tree)
    lengths = {a.get("name"): int(a.get("duration")) for a in ab.iter("LinearAnimation")}
    assert lengths["npc_squirrel_idle"] == cab.SQ_IDLE and lengths["npc_squirrel_move"] == cab.SQ_RUN
    assert lengths["npc_squirrel_rest"] == cab.SQ_REST
    # npcX 0 = the rail spot, 1 = the maple (left), partly up it
    (x0, y0, _), (x1, y1, _) = cab.SQ_WAYPOINTS[0], cab.SQ_WAYPOINTS[-1]
    assert _at(tree, sq, 13, 0.0) == pytest.approx(x0) and _at(tree, sq, 14, 0.0) == pytest.approx(y0)
    assert _at(tree, sq, 13, 1.0) == pytest.approx(x1, abs=3) and _at(tree, sq, 14, 1.0) == pytest.approx(y1, abs=3)
    assert x1 < 330 and y1 < cab.GROUND_Y - 60   # the maple is left of the avatar; it sits up the tree
    # the rest pose sits on the rail
    assert y0 == cab.RAIL_TOP


def test_pinwheel_drag_spins_history_free(tree: ET.Element) -> None:
    spin = _named(tree, "PinwheelSpin")
    assert _bound(spin, tree) == {"pinwheel"}
    for v in (0.0, 0.25, 0.5, 1.0):
        assert _at(tree, spin, 15, v) == pytest.approx(2 * math.pi * v, abs=2e-3)
    assert float(spin.get("rotation", "0")) == 0.0
    # the handle covers the blades at every turn and the stick
    x0, y0, x1, y1 = cab.PINWHEEL_RECT
    hx, hy = cab.PINWHEEL_HUB
    r = cab.PINWHEEL_R
    assert x0 <= hx - r and x1 >= hx + r and y0 <= hy - r and y1 >= cab.RAIL_TOP
    assert x1 <= 990   # inside a phone's crop
    rect = world_kit.DRAGS[SID][0]
    assert (rect.id, rect.kind, rect.plane) == ("pinwheel", "spin", 3)
    assert rect.rect == cab.PINWHEEL_RECT


def test_moon_rain_fog_seasons_festive_binds(tree: ET.Element) -> None:
    assert _bound(_named(tree, "MoonRig"), tree) == {"moonPhase"}
    assert "moonPhase" in _bound(_named(tree, "MoonDrawn"), tree)
    for name in ("RainLoop", "YardWet", "SkyOvercast"):
        assert "rain" in _bound(_named(tree, name), tree), name
    assert "fog" in _bound(_named(tree, "FogVeil0"), tree) and "fog" in _bound(_named(tree, "FogBank"), tree)
    assert {"daylight"} == _bound(_named(tree, "SkyDay"), tree) and {"dusk"} == _bound(_named(tree, "SkyDusk"), tree)
    assert "daylight" in _bound(_named(tree, "DayLift"), tree)
    # (M11: the drifts' later copies also carry the shared tier gate, world_kit.tier_gate)
    for name in ("MapleBlossom", "PathFlowers", "PetalDrift"):
        assert _bound(_named(tree, name), tree) - {"tier"} == {"spring"}, name
    for name in ("MapleAutumn", "GroundLeaves", "PorchLeaves", "LeafDrift", "Pumpkin"):
        assert _bound(_named(tree, name), tree) - {"tier"} == {"autumn"}, name
    for name in ("Wreath", "FestiveLights"):
        assert "festive" in _bound(_named(tree, name), tree), name
    # the gust's leaves: green at 0 / 0, petals in spring, red-gold in autumn
    assert _bound(_named(tree, "GustLeaves"), tree) >= {"spring", "autumn"}
    # bound v14 members: exactly the module's declaration and the shared tier gate (lane W)
    vm = _vm(tree)
    v14 = {p.get("id"): p.get("name") for p in vm if p.get("name") in ("tier", "spring", "autumn")}
    got = set()
    for root in [*tree.findall("Artboard"), *tree.findall("DataConverterFormula")]:
        got |= world_kit.bound_names(root, vm.get("id"), v14)
    assert got == cab.BINDS14 | {"tier"} == world_kit.declared_v14_binds(SID)


def test_scene_front(tree: ET.Element) -> None:
    assert SID in gen_scenes.FRONT_SCENES
    front = _artboard(tree, "SceneFront")
    assert [e.get("name") for e in front if e.tag in ("Node", "Shape")] == ["FrontRain", "FrontFog", "FrontMist"]


def test_tier_gates_name_real_elements(tree: ET.Element) -> None:
    roots = {gen_scenes._root(str(e.get("name", "")).removeprefix("emit")) for e in _artboard(tree).iter()
             if e.tag in ("Node", "Shape")}
    for tier, names in cab.TIER_GATES.items():
        for n in names:
            assert n in roots, (tier, n)


def test_riv_and_poster_within_budget() -> None:
    assert RIV.exists() and RIV.stat().st_size <= 409_600
    assert POSTER.exists() and POSTER.stat().st_size <= 40_960
