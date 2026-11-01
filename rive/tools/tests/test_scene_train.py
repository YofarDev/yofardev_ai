"""Tests for the v14 scene `trainCompartment` (moonshot M11 lane S2, rulings 1, 2, 7, 8, 9, 13): RML level."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import art_bible  # noqa: E402
import gen_scenes  # noqa: E402
import scene_npc  # noqa: E402
import scene_train as train  # noqa: E402
import world_kit  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SID = "trainCompartment"
COMMITTED = ROOT / "rive" / "scenes" / SID / f"{SID}.rml"
RIV = ROOT / "assets" / "rive" / "scenes" / f"{SID}.riv"
POSTER = ROOT / "assets" / "rive" / "posters" / f"{SID}.webp"
EVENTS = ["tunnel", "whistle", "station", "rain"]
PROPS = {"window": 2, "lamp": 3, "suitcase": 3, "ladybug": 3}
X, Y, ROT, SX, SY, OP = "13", "14", "15", "16", "17", "18"


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(train.trainCompartment()).read_text()
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


def _path(tree: ET.Element, name: str) -> str:
    return f"{_vm(tree).get('id')}-{next(i for i, n in _vm_names(tree).items() if n == name)}"


def _bound(e: ET.Element, tree: ET.Element) -> set[str]:
    vm = _vm(tree)
    names = _vm_names(tree)
    out = set()
    for b in e.iter("DataBindContext"):
        path = b.get("sourcePathIds", "")
        if path.startswith(vm.get("id") + "-"):
            out.add(names.get(path.split("-", 1)[1], "?"))
    return out


def _own_binds(e: ET.Element, tree: ET.Element) -> dict[str, tuple[str, ET.Element | None]]:
    """propertyKey -> (view-model member, converter) of `e`'s own binds."""
    names = _vm_names(tree)
    convs = {c.get("id"): c for c in tree.iter("DataConverterFormula")}
    return {b.get("propertyKey"): (names[b.get("sourcePathIds").split("-", 1)[1]], convs.get(b.get("converterId")))
            for b in e if b.tag == "DataBindContext"}


def _at(tree: ET.Element, e: ET.Element, key: str, x: float) -> float:
    _, conv = _own_binds(e, tree)[key]
    return x if conv is None else world_kit.eval_formula(conv, x, lambda _p: x)   # a bound token reads the same member


def _named(tree: ET.Element, name: str) -> ET.Element:
    """The element named `name` (light sources carry the diorama's `emit` prefix)."""
    return next(e for e in tree.iter() if e.get("name") in (name, "emit" + name) and e.tag in ("Node", "Shape"))


def _anims(tree: ET.Element) -> dict[str, ET.Element]:
    return {a.get("name"): a for a in _artboard(tree).iter("LinearAnimation")}


def _keys(tree: ET.Element, anim: str, target: str, prop: str) -> list[tuple[int, float]]:
    el = _named(tree, target)
    a = _anims(tree)[anim]
    ko = next(k for k in a if k.get("objectId") == el.get("id"))
    kp = next(p for p in ko if p.get("property") == prop)
    return [(int(k.get("frame")), float(k.get("value"))) for k in kp]


# ---------------------------------------------------------------- registry and document
def test_generator_is_deterministic_and_committed(rml: str) -> None:
    assert rml == COMMITTED.read_text()


def test_registered_in_the_world_kit() -> None:
    assert world_kit.SCENE_MODULES[SID] == "scene_train"
    assert SID in gen_scenes.DIORAMAS and SID in gen_scenes.TIME_SKY
    assert SID in scene_npc.FOG_VEILS and SID in scene_npc.FOG_BANKS
    assert train.BINDS == {"moonPhase", "chain"} == set(world_kit.declared_binds(SID))
    assert train.BINDS14 == {"spring", "autumn"}
    assert "tier" not in train.BINDS14   # lane W's shared pass binds it
    assert world_kit.declared_v14_binds(SID) >= {"spring", "autumn"}


def test_artboard_state_machine_and_view_model_in_contract_order(tree: ET.Element) -> None:
    ab = _artboard(tree)
    assert (ab.get("width"), ab.get("height")) == ("1080", "1920")
    assert [s.get("name") for s in ab.iter("StateMachine")] == ["Main"]
    want = ["eventId", "event", *(n for n, _, _ in gen_scenes.scene_vm_defaults(SID)), "fog", "npc", "npcX",
            "npcLook", *(n for n, _, _ in world_kit.vm_tail(SID))]
    assert list(_vm_names(tree).values()) == want
    assert want[-1] == "chain"
    events = next(e for e in tree.iter("DataEnumCustom") if e.get("name") == "EventId")
    assert [v.get("key") for v in events] == EVENTS
    assert not any(a.get("name") == "SceneFront" for a in tree.iter("Artboard"))   # rain is on the glass


def test_light_rig_defaults_are_the_art_bibles(tree: ET.Element) -> None:
    s = art_bible.SCENES[SID]
    vals = {}
    names = _vm_names(tree)
    inst = next(i for i in _vm(tree) if i.tag == "ViewModelInstance")
    for v in inst:
        vals[names[v.get("viewModelPropertyId")]] = v.get("propertyValue")
    assert vals["lightKey"] == s.key and vals["lightRim"] == s.rim and vals["lightFog"] == s.fog
    assert float(vals["lightFlicker"]) == pytest.approx(0.05)
    lo, hi = s.value
    assert lo <= 0.10 and hi >= 0.92 and s.sat_cap >= 0.55   # at least as lenient as the prep commit


# ---------------------------------------------------------------- events and props
def test_four_events_play_one_shots(tree: ET.Element) -> None:
    layers = {lay.get("name") for lay in _artboard(tree).iter("StateMachineLayer")}
    anims = {k: int(a.get("duration")) for k, a in _anims(tree).items()}
    for ev in EVENTS:
        assert f"Event_{ev}" in layers
        assert anims[f"ev_{ev}"] == train.EVENT_FRAMES[ev]
        assert 0 < train.EVENT_PEAKS[ev] < train.EVENT_FRAMES[ev]
    # roughly the brief's lengths: tunnel 3 s, whistle 2 s, station 8 s
    assert train.EVENT_FRAMES["tunnel"] == 180 and train.EVENT_FRAMES["whistle"] == 120
    assert train.EVENT_FRAMES["station"] == 480


def test_four_props_in_the_plane_of_their_art(tree: ET.Element) -> None:
    ab = _artboard(tree)
    planes = {p.get("name"): p for p in ab if p.get("name", "").startswith("Plane")}
    assert sorted(planes) == [f"Plane{k}" for k in range(6)]
    for prop, k in PROPS.items():
        assert any(c.get("name") == f"Hit_{prop}" for c in planes[f"Plane{k}"]), prop
    fired = sorted(p.get("propertyValue") for e in ab.iter("Event") if e.get("name") == "prop_tapped"
                   for p in e.iter("CustomPropertyString"))
    assert fired == sorted(PROPS)


def test_six_parallax_planes_paint_back_to_front(tree: ET.Element) -> None:
    ab = _artboard(tree)
    assert [c.get("name") for c in ab if c.get("name", "").startswith("Plane")] == [f"Plane{k}" for k in range(5, -1, -1)]
    px = _path(tree, "parallaxX")
    convs = {c.get("id"): c for c in tree.iter("DataConverterFormula")}
    for k in range(1, 6):
        plane = next(c for c in ab if c.get("name") == f"Plane{k}")
        (b,) = [b for b in plane if b.tag == "DataBindContext" and b.get("sourcePathIds") == px]
        assert world_kit.eval_formula(convs[b.get("converterId")], 1.0) == pytest.approx(
            gen_scenes.PARALLAX_GAINS[k] * gen_scenes.PARALLAX_TRAVEL[0])


def test_plane_table_covers_every_top_level_element(tree: ET.Element) -> None:
    spec = gen_scenes.DIORAMAS[SID]
    ab = _artboard(tree)
    for plane in (c for c in ab if c.get("name", "").startswith("Plane")):
        k = int(plane.get("name")[5:])
        for e in plane:
            name = e.get("name", "")
            if e.tag == "DataBindContext" or name.startswith(("FogVeil", "FogBank", "SkyDay", "SkyDusk")):
                continue
            assert gen_scenes.plane_of(spec, name) == k, (name, k)
    # the landscape is outside (planes 0, 1), the glass plane 2, the room 3..5
    for name, k in (("FarHills", 0), ("MidLand", 0), ("NearTrees", 1), ("Poles", 1), ("Station", 1), ("Tunnel", 1),
                    ("RainGlass", 2), ("WinFrame", 2), ("ChainRig", 3), ("Lamp", 3), ("Suitcase", 3),
                    ("BenchL", 4), ("BenchR", 4), ("CurtainEdge", 5)):
        assert spec.planes[name] == k, name


# ---------------------------------------------------------------- the landscape loops
def test_landscape_tiles_loop_seamlessly_in_a_common_period(tree: ET.Element) -> None:
    for name, period in train.SCROLL_LOOPS.items():
        a = _anims(tree)[f"amb_{name}"]
        assert int(a.get("duration")) == period and a.get("loopValue") == "loop"
        keys = _keys(tree, f"amb_{name}", name, "x")
        assert keys[0] == (0, 0.0) and keys[-1] == (period, -train.TILE_W)
        assert train.LOOP_LCM % period == 0, name
    # the tile is wider than the view, so two copies always cover it
    assert train.TILE_W >= train.VIEW[2] - train.VIEW[0] + 2 * 40
    # every ambient loop of the scene is back at frame 0 after LOOP_LCM (the NPC and rain seams use it)
    for a in _anims(tree).values():
        if a.get("loopValue") == "loop":
            assert train.LOOP_LCM % int(a.get("duration")) == 0, a.get("name")


def test_seasons_tint_the_trees_only(tree: ET.Element) -> None:
    spring = _path(tree, "spring")
    autumn = _path(tree, "autumn")
    spring_binders = [e for e in _artboard(tree).iter() if e.tag in ("Node", "Shape")
                      and any(b.get("sourcePathIds") == spring for b in e if b.tag == "DataBindContext")]
    autumn_binders = [e for e in _artboard(tree).iter() if e.tag in ("Node", "Shape")
                      and any(b.get("sourcePathIds") == autumn for b in e if b.tag == "DataBindContext")]
    assert spring_binders and autumn_binders
    for e in spring_binders + autumn_binders:
        assert float(e.get("opacity")) == 0.0                     # 0 / 0 is the v13 (green night) look
        assert _own_binds(e, tree)[OP][0] in ("spring", "autumn")
    near = _named(tree, "NearTrees")
    assert any(e in list(near.iter()) for e in spring_binders) and any(e in list(near.iter()) for e in autumn_binders)


# ---------------------------------------------------------------- weather, sky, moon
def test_rain_slants_on_the_glass(tree: ET.Element) -> None:
    rain = _named(tree, "RainGlass")
    assert _own_binds(rain, tree)[OP][0] == "rain" and float(rain.get("opacity")) == 0.0
    far = _named(tree, "GlassStreaksB")
    assert _own_binds(far, tree)[OP][0] == "rain"
    assert _at(tree, far, OP, 0.3) == pytest.approx(0.0) and _at(tree, far, OP, 1.0) == pytest.approx(1.0)
    for name, (vx, vy), period in train.GLASS_SHEETS:
        keys_x = _keys(tree, f"amb_{name}", name, "x")
        keys_y = _keys(tree, f"amb_{name}", name, "y")
        assert keys_x == [(0, 0.0), (period, vx)] and keys_y == [(0, 0.0), (period, vy)]
        assert vx < 0 < vy          # down and back (to the left): the train runs to the right
        assert train.LOOP_LCM % period == 0
    assert not any(e.get("name", "").startswith(("RainSheet", "RainLoop")) for e in tree.iter())


def test_moon_fog_sky_binds(tree: ET.Element) -> None:
    assert _bound(_named(tree, "MoonRig"), tree) == {"moonPhase"}
    assert "moonPhase" in _bound(_named(tree, "MoonDrawn"), tree)
    assert "fog" in _bound(_named(tree, "FogVeil0"), tree) and "fog" in _bound(_named(tree, "FogVeil1"), tree)
    assert "fog" in _bound(_named(tree, "FogBank"), tree)
    assert {"daylight"} == _bound(_named(tree, "SkyDay"), tree) and {"dusk"} == _bound(_named(tree, "SkyDusk"), tree)
    assert _own_binds(_named(tree, "LandDay"), tree)[OP][0] == "daylight"
    text = ET.tostring(tree, encoding="unicode")
    assert f'sourcePathIds="{_path(tree, "lightKey")}"' in text
    # festive, npc2, night are declared and ignored
    for name in ("festive", "npc2", "npc2X", "npc2Look", "night"):
        assert f'sourcePathIds="{_path(tree, name)}"' not in text, name


# ---------------------------------------------------------------- the chain drag
def test_chain_drag_slides_and_swings_history_free(tree: ET.Element) -> None:
    slide, swing = _named(tree, "ChainSlide"), _named(tree, "ChainSwing")
    assert _bound(slide, tree) == {"chain"} and _bound(swing, tree) == {"chain"}
    y0 = float(slide.get("y"))
    assert _at(tree, slide, Y, 0.0) == pytest.approx(y0)                       # rest is the default
    assert _at(tree, slide, Y, 1.0) - y0 == pytest.approx(train.CHAIN_PULL)
    assert 0 < train.CHAIN_PULL <= 70
    assert _at(tree, swing, ROT, 0.0) == pytest.approx(0.0) and 0 < abs(_at(tree, swing, ROT, 1.0)) <= 0.1
    # the rig's sway is keyed on its own node, never on a bound one
    assert not [c for c in _named(tree, "ChainRig") if c.tag == "DataBindContext"]


@pytest.mark.parametrize("v", [0.0, 0.5, 1.0])
def test_chain_rect_covers_the_chain(v: float) -> None:
    x0, y0, x1, y1 = train.CHAIN_RECT
    gx0, gy0, gx1, gy1 = train.chain_box(v)
    assert x0 <= gx0 and gx1 <= x1 and y0 <= gy0 and gy1 <= y1, (train.chain_box(v), train.CHAIN_RECT)
    row = next(h for h in world_kit.DRAGS[SID] if h.id == "chain")
    assert row.kind == "pull" and row.plane == train.CHAIN_PLANE == 3 and row.rect == train.CHAIN_RECT


def test_chain_hangs_clear_of_the_window_and_the_other_props() -> None:
    x0, _, _, _ = train.CHAIN_RECT
    assert x0 > train.CASING[2]
    assert train.CHAIN_RECT[2] < 1000            # inside a phone's crop


# ---------------------------------------------------------------- the ladybug
def test_ladybug_states_path_and_poke(tree: ET.Element) -> None:
    ab = _artboard(tree)
    npc = next(lay for lay in ab.iter("StateMachineLayer") if lay.get("name") == "Npc")
    anims = {a.get("id"): a.get("name") for a in ab.iter("LinearAnimation")}
    states = [anims[s.get("animationId")] for s in npc if s.tag == "AnimationState"]
    blends = [[anims[b.get("animationId")] for b in s.iter("BlendAnimation1D")] for s in npc
              if s.tag == "BlendState1DViewModel"]
    assert sorted(states) == sorted(f"npc_ladybug_{k}" for k in ("rest", "away", "idle", "move", "react"))
    assert blends == [["npc_ladybug_noticeL", "npc_ladybug_noticeC", "npc_ladybug_noticeR"]]
    # state changes blend in <= 200 ms
    assert all(int(t.get("duration", "0")) <= 200 for t in npc.iter() if t.tag in ("StateTransition", "BlendStateTransition"))
    lengths = {a.get("name"): int(a.get("duration")) for a in ab.iter("LinearAnimation")}
    assert lengths["npc_ladybug_idle"] == train.LB_IDLE and lengths["npc_ladybug_move"] == train.LB_WALK
    assert lengths["npc_ladybug_react"] == train.LB_REACT
    for name in ("LadybugNpc", "Hit_ladybug"):
        b = _own_binds(_named(tree, name), tree)
        assert b[X][0] == "npcX" and b[Y][0] == "npcX", name
    lb = _named(tree, "LadybugNpc")
    (x_0, y_0, _), (x_1, y_1, _) = train.LADYBUG_WAYPOINTS[0], train.LADYBUG_WAYPOINTS[-1]
    assert (_at(tree, lb, X, 0.0), _at(tree, lb, X, 1.0)) == pytest.approx((x_0, x_1))
    assert x_0 < x_1 and y_0 == y_1 == train.SILL_TOP           # left to right along the sill
    # its poke zone leaves its rest spot by more than its width at npcX 1
    assert x_1 - x_0 > train.LADYBUG_HIT[2]
    # facing follows the sign of npcLook (+ = right, toward the avatar), history-free
    face = _named(tree, "LbFace")
    assert _own_binds(face, tree)[SX][0] == "npcLook"
    assert _at(tree, face, SX, 0.0) == pytest.approx(1.0) and _at(tree, face, SX, -1.0) == pytest.approx(-1.0)


def test_ladybug_reads_at_phone_size() -> None:
    w = train.LADYBUG_LENGTH * train.LADYBUG_SCALE
    assert 40 <= w <= 60


def test_every_npc_state_keys_the_same_properties(tree: ET.Element) -> None:
    anims = _anims(tree)
    sets = []
    for name, a in anims.items():
        if name.startswith("npc_ladybug_"):
            sets.append({(k.get("objectId"), p.get("property")) for k in a for p in k})
    assert sets and all(s == sets[0] for s in sets)


# ---------------------------------------------------------------- tiers
def test_tier_gates_name_real_nodes(tree: ET.Element) -> None:
    assert set(train.TIER_GATES) == {"high", "low"}
    names = {gen_scenes._root(str(e.get("name", "")).removeprefix("emit")) for e in tree.iter() if e.get("name")}
    full = {str(e.get("name", "")).removeprefix("emit") for e in tree.iter() if e.get("name")}
    assert not {r for rs in train.TIER_GATES.values() for r in rs} - full   # each is a whole element name too
    for tier, roots in train.TIER_GATES.items():
        assert roots, tier
        for r in roots:
            assert r in names, (tier, r)
    assert "GlassStreaksB" in train.TIER_GATES["high"]
    assert not set(train.TIER_GATES["high"]) & set(train.TIER_GATES["low"])
    # nothing the tier gate hides is a prop, the NPC or the landscape loops
    for r in (*train.TIER_GATES["high"], *train.TIER_GATES["low"]):
        assert r not in ("Lamp", "Suitcase", "LadybugNpc", "RainGlass", *train.SCROLL_LOOPS)


# ---------------------------------------------------------------- budgets
def test_ids_are_unique(tree: ET.Element) -> None:
    ids = [e.get("id") for e in tree.iter() if e.get("id")]
    assert len(ids) == len(set(ids))


def test_riv_and_poster_within_budget() -> None:
    assert RIV.exists() and RIV.stat().st_size <= 409_600
    assert POSTER.exists() and POSTER.stat().st_size <= 40_960


def test_colours_lint_clean(rml: str) -> None:
    assert art_bible.lint_colours(rml, SID) == []


def test_station_slows_holds_and_leaves(tree: ET.Element) -> None:
    keys = _keys(tree, "ev_station", "Station", "x")
    xs = dict(keys)
    frames = [f for f, _ in keys]
    # monotonic: the platform only ever runs to the left; it holds still in the middle
    assert all(b[1] <= a[1] + 1e-6 for a, b in zip(keys, keys[1:]))
    hold = [f for f in frames if train.STATION_HOLD[0] <= f <= train.STATION_HOLD[1]]
    assert hold and len({round(xs[f], 3) for f in hold}) == 1
    x_hold = xs[hold[0]]
    # at the hold the platform covers the whole view
    assert x_hold <= train.VIEW[0] and x_hold + train.STATION_W >= train.VIEW[2]
    # it enters and leaves at the running speed (no jump from the landscape's pace)
    assert (keys[0][1] - keys[1][1]) / (keys[1][0] - keys[0][0]) == pytest.approx(train.STATION_SPEED, rel=0.05)
    op = _keys(tree, "ev_station", "Station", "opacity")
    assert op[0][1] == 0.0 and op[-1][1] == 0.0
    assert math.isclose(dict(op).get(train.EVENT_PEAKS["station"], 1.0), 1.0)
