"""Tests for the v14 scene `library` (moonshot M11 lane S3, rulings 1-3, 7, 8, 13): RML level."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_library as lib  # noqa: E402
import scene_npc  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
COMMITTED = ROOT / "rive" / "scenes" / "library" / "library.rml"
RIV = ROOT / "assets" / "rive" / "scenes" / "library.riv"
POSTER = ROOT / "assets" / "rive" / "posters" / "library.webp"
EVENTS = ["lightning", "bookFlutter", "clockChime", "rain"]
PROPS = {"book": 3, "globe": 4, "clock": 2, "mouse": 4}
X, Y, ROT, SX, OP = "13", "14", "15", "16", "18"


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.SCENE_BUILDERS["library"]()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.fixture(scope="module")
def tree(rml: str) -> ET.Element:
    return ET.fromstring(rml)


def _artboard(tree: ET.Element) -> ET.Element:
    return next(a for a in tree.iter("Artboard") if a.get("name") == "Scene")


def _vm(tree: ET.Element) -> ET.Element:
    return next(v for v in tree.iter("ViewModel") if v.get("name") == "SceneVM")


def _vm_names(tree: ET.Element) -> dict[str, str]:
    return {p.get("id"): p.get("name") for p in _vm(tree) if p.tag.startswith("ViewModelProperty")}


def _bound(e: ET.Element, tree: ET.Element) -> set[str]:
    return world_kit.bound_names(e, _vm(tree).get("id"), _vm_names(tree))


def _own_binds(e: ET.Element, tree: ET.Element) -> dict[str, tuple[str, ET.Element | None]]:
    """propertyKey -> (member, converter) of `e`'s own DataBindContext children."""
    names = _vm_names(tree)
    convs = {c.get("id"): c for c in tree.iter("DataConverterFormula")}
    out = {}
    for b in e:
        if b.tag == "DataBindContext":
            out[b.get("propertyKey")] = (names[b.get("sourcePathIds").split("-", 1)[1]], convs.get(b.get("converterId")))
    return out


def _named(tree: ET.Element, name: str) -> ET.Element:
    """The element named `name` (light sources carry the diorama's `emit` prefix)."""
    return next(e for e in tree.iter() if e.get("name") in (name, "emit" + name))


def _plane(tree: ET.Element, name: str) -> int:
    for p in _artboard(tree):
        if p.get("name", "").startswith("Plane") and any(e.get("name") in (name, "emit" + name) for e in p.iter()):
            return int(p.get("name")[5:])
    raise AssertionError(name)


def test_generator_is_deterministic_and_committed(rml: str) -> None:
    assert rml == COMMITTED.read_text()


def test_registered_in_the_world_kit() -> None:
    assert world_kit.SCENE_MODULES["library"] == "scene_library"
    assert "library" in gen_scenes.DIORAMAS and "library" in gen_scenes.TIME_SKY
    assert lib.BINDS == {"moonPhase", "festive", "ladder"}
    assert world_kit.declared_binds("library") == frozenset(lib.BINDS)
    assert not lib.BINDS14 and "tier" not in world_kit.declared_v14_binds("library") - gen_scenes.V14_BINDS.get(
        "library", frozenset())
    assert scene_npc.FOG_VEILS["library"] == (0,) and scene_npc.FOG_BANKS["library"][0] == 0


def test_tier_gates_name_dense_fx_roots_present_in_the_file(tree: ET.Element) -> None:
    assert set(lib.TIER_GATES) == {"high", "low"}
    names = {e.get("name") for e in tree.iter() if e.get("name")}
    for tier, roots in lib.TIER_GATES.items():
        assert roots, tier
        for r in roots:
            # a root, or (M12: Star, LitWin) the root of a numbered set
            assert r in names or "emit" + r in names or any(world_kit.gate_root(n) == r for n in names), (tier, r)
    # every dense sheet has its first half kept (A) and its second half gated (B)
    for r in lib.TIER_GATES["high"]:
        assert r.endswith("B") and r[:-1] + "A" in names
    # the tier is bound by lane W's shared pass (world_kit.tier_gate), never by this module
    assert "tier" in _bound(_artboard(tree), tree) and "tier" not in lib.BINDS14


def test_artboard_state_machine_and_view_model_in_contract_order(tree: ET.Element) -> None:
    ab = _artboard(tree)
    assert (ab.get("width"), ab.get("height")) == ("1080", "1920")
    assert [s.get("name") for s in ab.iter("StateMachine")] == ["Main"]
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults("library")), "fog", "npc", "npcX",
            "npcLook", *(n for n, _, _ in world_kit.vm_tail("library"))]
    assert list(_vm_names(tree).values()) == want
    assert want[-1] == "ladder"
    events = next(e for e in tree.iter("DataEnumCustom") if e.get("name") == "EventId")
    assert [v.get("key") for v in events] == EVENTS
    assert not any(a.get("name") == "SceneFront" for a in tree.iter("Artboard"))   # the rain is on the glass


def test_defaults_are_the_light_rig_and_the_contract(tree: ET.Element) -> None:
    vm = _vm(tree)
    ids = _vm_names(tree)
    vals = {ids[v.get("viewModelPropertyId")]: v.get("propertyValue") for v in vm.iter()
            if v.tag in ("ViewModelInstanceNumber", "ViewModelInstanceColor")}
    s = gen_scenes.SCENES["library"]
    assert vals["lightKey"] == s.key and vals["lightRim"] == s.rim and float(vals["lightFlicker"]) == s.flicker
    assert float(vals["moonPhase"]) == -1.0 and float(vals["ladder"]) == 0.0 and float(vals["festive"]) == 0.0
    for name in ("rain", "fog", "daylight", "dusk", "npcX", "npcLook", "spring", "autumn", "night"):
        assert float(vals[name]) == 0.0, name


def test_four_events_play_one_shots(tree: ET.Element) -> None:
    ab = _artboard(tree)
    layers = {lay.get("name"): lay for lay in ab.iter("StateMachineLayer")}
    anims = {a.get("name"): a for a in ab.iter("LinearAnimation")}
    for ev in EVENTS:
        assert f"Event_{ev}" in layers
        assert int(anims[f"ev_{ev}"].get("duration")) == lib.EVENT_FRAMES[ev]
        assert lib.EVENT_PEAKS[ev] < lib.EVENT_FRAMES[ev]
    # the chime's idle state is the pendulum's swing loop (no frozen rest pose), two periods long
    by_id = {a.get("id"): a.get("name") for a in anims.values()}
    chime = [by_id[s.get("animationId")] for s in layers["Event_clockChime"] if s.tag == "AnimationState"]
    assert chime == ["amb_pendulum", "ev_clockChime"]
    assert anims["amb_pendulum"].get("loopValue") == "loop"
    assert lib.EVENT_FRAMES["clockChime"] == 2 * lib.PENDULUM_PERIOD


def test_four_props_in_the_plane_of_their_art(tree: ET.Element) -> None:
    ab = _artboard(tree)
    planes = {p.get("name"): p for p in ab if p.get("name", "").startswith("Plane")}
    assert sorted(planes) == [f"Plane{k}" for k in range(6)]
    for prop, k in PROPS.items():
        assert any(c.get("name") == f"Hit_{prop}" for c in planes[f"Plane{k}"]), prop
    fired = sorted(p.get("propertyValue") for e in ab.iter("Event") if e.get("name") == "prop_tapped"
                   for p in e.iter("CustomPropertyString"))
    assert fired == sorted(PROPS)
    art = {"book": "OpenBook", "globe": "Globe", "clock": "Clock", "mouse": "MouseNpc"}
    for prop, name in art.items():
        assert _plane(tree, name) == PROPS[prop], prop


def test_six_parallax_planes_paint_back_to_front(rml: str) -> None:
    at = [rml.index(f'name="Plane{k}"') for k in range(5, -1, -1)]
    assert at == sorted(at)
    assert rml.index('name="emitLightningWash"') < at[0]   # the lightning's wash: a screen overlay


def test_mouse_states_and_path(tree: ET.Element) -> None:
    ab = _artboard(tree)
    npc = next(lay for lay in ab.iter("StateMachineLayer") if lay.get("name") == "Npc")
    anims = {a.get("id"): a.get("name") for a in ab.iter("LinearAnimation")}
    states = [anims[s.get("animationId")] for s in npc if s.tag == "AnimationState"]
    blends = [[anims[b.get("animationId")] for b in s.iter("BlendAnimation1D")] for s in npc
              if s.tag == "BlendState1DViewModel"]
    assert sorted(states) == sorted(f"npc_mouse_{k}" for k in ("rest", "away", "idle", "move", "react"))
    assert blends == [["npc_mouse_noticeL", "npc_mouse_noticeC", "npc_mouse_noticeR"]]
    assert all(int(t.get("duration", "0")) <= scene_npc.NPC_BLEND_MS for t in npc.iter()
               if t.tag in ("StateTransition", "BlendStateTransition"))
    mouse = _named(tree, "MouseNpc")
    assert {"npcX"} <= _bound(mouse, tree)
    assert _bound(_named(tree, "Hit_mouse"), tree) == {"npcX"}
    assert _own_binds(_named(tree, "MouseFace"), tree)[SX][0] == "npcLook"
    lengths = {a.get("name"): int(a.get("duration")) for a in ab.iter("LinearAnimation")}
    assert lengths["npc_mouse_idle"] == lib.MOUSE_IDLE and lengths["npc_mouse_move"] == lib.MOUSE_MOVE
    assert lengths["npc_mouse_rest"] == lib.MOUSE_REST and lengths["npc_mouse_react"] == lib.MOUSE_REACT
    # npcX 0 = by the bottom shelf, 1 = the reading chair's front foot; the path's anchors at the defaults
    x, y = float(mouse.get("x")), float(mouse.get("y"))
    assert (x, y) == lib.MOUSE_WAYPOINTS[0][:2]
    names = _vm_names(tree)
    path = {k: c for k, (m, c) in _own_binds(mouse, tree).items() if m == "npcX"}
    for t, (wx, wy, ws) in zip(lib.mouse_path()[0], lib.MOUSE_WAYPOINTS):
        assert world_kit.eval_formula(path[X], t) == pytest.approx(wx, abs=0.5)
        assert world_kit.eval_formula(path[Y], t) == pytest.approx(wy, abs=0.5)
        assert world_kit.eval_formula(path["16"], t) == pytest.approx(ws, abs=5e-3)
    assert names   # (members resolved)
    cx0, _, cx1, cy1 = lib.CHAIR
    fx, fy, _ = lib.MOUSE_WAYPOINTS[-1]
    assert cx0 - 40 < fx < cx0 + 40 and cy1 - 30 < fy <= cy1   # beside the chair's front-left foot


def test_ladder_drag_is_history_free_and_its_rect_covers_it(tree: ET.Element) -> None:
    ladder = _named(tree, "Ladder")
    binds = _own_binds(ladder, tree)
    assert set(binds) == {X} and binds[X][0] == "ladder"
    assert float(ladder.get("x")) == lib.LADDER_X == world_kit.eval_formula(binds[X][1], 0.0)
    # M12 ruling 8: LADDER_TRAVEL px to the left at -1, LADDER_TRAVEL_R to the right at +1, clamped
    for v, dx in ((-1.0, -lib.LADDER_TRAVEL), (-0.5, -lib.LADDER_TRAVEL / 2), (0.5, lib.LADDER_TRAVEL_R / 2),
                  (1.0, lib.LADDER_TRAVEL_R), (3.0, lib.LADDER_TRAVEL_R), (-3.0, -lib.LADDER_TRAVEL)):
        assert lib.ladder_shift(v) == pytest.approx(dx)
        assert world_kit.eval_formula(binds[X][1], v) == pytest.approx(lib.LADDER_X + dx, abs=0.01)
    for k in range(2):
        wheel = _named(tree, f"LadderWheel{k}")
        wb = _own_binds(wheel, tree)
        assert wb[ROT][0] == "ladder"
        for v in (-1.0, 1.0):   # the wheels turn by the distance rolled
            assert world_kit.eval_formula(wb[ROT][1], v) == pytest.approx(lib.ladder_shift(v) / lib.WHEEL_R, rel=1e-3)
    # only the ladder and its wheels read `ladder` (the rail stays)
    assert _bound(_named(tree, "LadderRail"), tree) == set()
    # the contract's row is the measured rect; it covers the ladder's art at every ladder value
    (h,) = world_kit.DRAGS["library"]
    assert (h.id, h.kind, h.plane, h.numbers) == ("ladder", "aim", lib.LADDER_PLANE, (("ladder", 0.0),))
    assert h.rect == lib.LADDER_RECT
    x0, y0, x1, y1 = h.rect
    assert 0 <= x0 < x1 <= gen_scenes.W and 0 <= y0 < y1 <= gen_scenes.H
    assert h.rect == (671.0, 278.0, 1080.0, 1221.0)   # M12 ruling 8 kept the contract's rect
    for v in (-1.0, 0.0, 0.5, 1.0):
        for px, py in lib.ladder_points():
            px += lib.ladder_shift(v)
            assert x0 <= px <= x1 <= gen_scenes.W, (v, px)   # M12: the whole ladder stays on the artboard
            assert y0 <= py <= y1
    assert _plane(tree, "Ladder") == lib.LADDER_PLANE


def test_moon_rain_fog_festive_time_binds(tree: ET.Element) -> None:
    assert _bound(_named(tree, "MoonRig"), tree) == {"moonPhase"}
    assert "moonPhase" in _bound(_named(tree, "MoonDrawn"), tree)
    for name in ("RainGlass", "ViewRain"):
        assert _own_binds(_named(tree, name), tree)[OP][0] == "rain", name
    assert "festive" in _bound(_named(tree, "FestiveDecor"), tree)
    for name in ("FestiveLights", "FestiveLights1"):
        assert "festive" in _bound(_named(tree, name), tree)
    assert "fog" in _bound(_named(tree, "FogVeil0"), tree) and "fog" in _bound(_named(tree, "FogBank"), tree)
    assert {"daylight"} == _bound(_named(tree, "SkyDay"), tree) and {"dusk"} == _bound(_named(tree, "SkyDusk"), tree)
    pool = _named(tree, "FloorPool")
    assert "lightKey" in _bound(pool, tree)


def test_calm_and_complete_at_the_defaults(tree: ET.Element) -> None:
    """Night, no rain, no fog, the drawn moon: every weather, event and December layer is clear at rest."""
    for name in ("ViewRain", "RainGlass", "ShowerGlass", "GlassFlash", "Bolt", "SkyFlash", "LightningFloor",
                 "LightningWash", "FlyBook", "FestiveDecor", "FestiveLights", "FestiveLights1", "MoonRig",
                 "FogBank", "SkyDay", "SkyDusk", "MouseAwake"):
        assert float(_named(tree, name).get("opacity")) == 0.0, name
    for name in ("SlotBook", "MoonDrawn", "MouseAsleep", "Ladder", "Clock"):
        assert float(_named(tree, name).get("opacity", "1")) == 1.0, name


def test_riv_and_poster_within_budget() -> None:
    assert RIV.exists() and RIV.stat().st_size <= 409_600
    assert POSTER.exists() and POSTER.stat().st_size <= 40_960


def test_mouse_drawing_switch_cuts_on_its_own_layer(tree: ET.Element) -> None:
    """M12 ruling 7: the drawing copies' opacity is keyed only by the `NpcDraw` layer (one 1-frame hold per
    state, every transition 0 ms), so the `Npc` layer's 200 ms pose blend never cross-fades two copies."""
    ab = _artboard(tree)
    ids = {n: _named(tree, n).get("id") for n in ("MouseAsleep", "MouseAwake", "MouseAwake")}
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
    shown = {"away": "MouseAsleep", "rest": "MouseAsleep", "idle": "MouseAwake", "move": "MouseAwake", "notice": "MouseAwake",
             "react": "MouseAwake"}
    by_name = {a.get("name"): a for a in anims_of(draw)}
    assert sorted(by_name) == sorted(f"npc_mouse_draw_{k}" for k in scene_npc.NPC_STATES)
    for k, n in shown.items():
        a = by_name[f"npc_mouse_draw_{k}"]
        assert int(a.get("duration")) == 1
        assert keyed(a) == {i: float(i == ids[n]) for i in ids.values()}, k
    ts = [t for t in draw.iter() if t.tag in ("StateTransition", "BlendStateTransition") and t.get("stateToId")]
    assert len(ts) == 2 * (len(scene_npc.NPC_STATES) - 1) + 1     # AnyState -> 5, 5 -> rest, entry -> rest
    assert all(int(t.get("duration", "0")) == 0 for t in ts)
    # only this layer keys the copies' opacity anywhere in the file
    owners = {a.get("name") for a in anims.values() if set(keyed(a)) & set(ids.values())}
    assert owners == set(by_name)
