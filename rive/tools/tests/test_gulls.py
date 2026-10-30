"""Moonshot M9 lane E (contract v12, ruling 10): the beach's gulls in the second NPC slot (`npc2`,
`npc2X`, `npc2Look`), on freshly generated RML: the `Npc2` layer starts away (nothing drawn at the
defaults), every state keys every gull property, the flight path is a history-free bind of `npc2X`
that ends off the frame, and only the beach binds the slot."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_npc  # noqa: E402
import world_kit  # noqa: E402

STATES = ["away", "rest", "idle", "move", "notice", "react"]
LOOPS = {"rest": scene_npc.GULL_REST, "idle": scene_npc.GULL_IDLE, "move": scene_npc.GULL_MOVE,
         "notice": scene_npc.GULL_NOTICE, "react": scene_npc.GULL_REACT}
M9_RANGE = (gen_scenes.M9_ID_START, gen_scenes.M8_ID_START)


@pytest.fixture(scope="module")
def beach(tmp_path_factory: pytest.TempPathFactory) -> ET.Element:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return ET.fromstring(Path(gen_scenes.beach()).read_text())
    finally:
        gen_scenes.OUT_ROOT = root


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")


def _props(doc: ET.Element) -> dict[str, str]:
    return {p.get("id"): p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")}


def _named(doc: ET.Element, name: str) -> ET.Element:
    return next(e for e in doc.iter() if e.get("name") == name and e.tag in ("Node", "Shape"))


def _layer(doc: ET.Element, name: str) -> ET.Element:
    return next(e for e in doc.iter("StateMachineLayer") if e.get("name") == name)


def _anims(doc: ET.Element) -> dict[str, ET.Element]:
    return {a.get("id"): a for a in doc.iter("LinearAnimation")}


def _state_anims(doc: ET.Element) -> dict[str, list[ET.Element]]:
    """npc2 value -> the animations of its state (notice: the three blend poses)."""
    props, vm = _props(doc), _vm(doc)
    vals = {v.get("id"): v.get("key") for e in doc.iter("DataEnumCustom") if e.get("name") == "NpcState" for v in e}
    layer, anims = _layer(doc, "Npc2"), _anims(doc)
    by_id = {s.get("id"): s for s in layer}
    out: dict[str, list[ET.Element]] = {}
    states = [s for s in layer if s.tag in ("AnimationState", "BlendState1DViewModel")]
    for t in [*layer.find("AnyState"), *[t for s in states for t in s if "Transition" in t.tag]]:
        cmp = t.find(".//TransitionValueEnumComparator")
        src = t.find(".//BindablePropertyEnum/DataBindContext").get("sourcePathIds")
        assert src.startswith(vm.get("id") + "-") and props[src.split("-")[1]] == "npc2"
        s = by_id[t.get("stateToId")]
        ids = [s.get("animationId")] if s.tag == "AnimationState" else [b.get("animationId") for b in s
                                                                        if b.tag == "BlendAnimation1D"]
        out[vals[cmp.get("value")]] = [anims[i] for i in ids]
    return out


def _keyed(anim: ET.Element, obj: str, prop: str) -> list[float]:
    return [float(k.get("value")) for ko in anim if ko.get("objectId") == obj
            for kp in ko if kp.get("property") == prop for k in kp]


def _at(doc: ET.Element, el: ET.Element, key: int, x: float) -> float:
    props = _props(doc)
    b = next(b for b in el if b.tag == "DataBindContext" and b.get("propertyKey") == str(key))
    conv = next(c for c in doc.iter("DataConverterFormula") if c.get("id") == b.get("converterId"))
    return world_kit.eval_formula(conv, x, lambda p: 0.0)


def test_npc2_layer_starts_away_and_blends_fast(beach: ET.Element) -> None:
    layer = _layer(beach, "Npc2")
    states = _state_anims(beach)
    assert set(states) == set(STATES)
    (entry,) = layer.find("EntryState")
    away = next(s for s in layer if s.get("id") == entry.get("stateToId"))
    assert _anims(beach)[away.get("animationId")] is states["away"][0]
    others = [s for s in layer if s.tag in ("AnimationState", "BlendState1DViewModel") and s is not away]
    # every other state comes from AnyState and goes back to away on its own (never AnyState -> away,
    # which would restart the entry state on the first frame)
    assert sorted(t.get("stateToId") for t in layer.find("AnyState")) == sorted(s.get("id") for s in others)
    for s in others:
        back = [t for t in s if t.tag in ("StateTransition", "BlendStateTransition")]
        assert [t.get("stateToId") for t in back] == [away.get("id")]
    for t in [*layer.find("AnyState"), *[t for s in others for t in s if "Transition" in t.tag]]:
        assert int(t.get("duration", "0")) <= scene_npc.NPC_BLEND_MS
    blend = next(s for s in layer if s.tag == "BlendState1DViewModel")
    b = blend.find("BindablePropertyNumber/DataBindContext")
    assert _props(beach)[b.get("sourcePathIds").split("-")[1]] == "npc2Look"
    assert sorted(float(x.get("value")) for x in blend if x.tag == "BlendAnimation1D") == [-1.0, 0.0, 1.0]


def test_every_state_keys_every_gull_property_and_loops(beach: ET.Element) -> None:
    sets = {}
    for k, anims in _state_anims(beach).items():
        for a in anims:
            sets[(k, a.get("name"))] = {(ko.get("objectId"), kp.get("property")) for ko in a for kp in ko}
            assert a.get("loopValue") == "loop"
            if k in LOOPS:
                assert int(a.get("duration")) == LOOPS[k], (k, a.get("duration"))
    union = set().union(*sets.values())
    for k, s in sets.items():
        assert s == union, (k, sorted(union - s)[:5])


def test_away_draws_nothing_and_the_other_states_show_the_pair(beach: ET.Element) -> None:
    group = _named(beach, "GullsNpc")
    assert float(group.get("opacity")) == 0.0
    states = _state_anims(beach)
    assert _keyed(states["away"][0], group.get("id"), "opacity") == [0.0]
    for k in ("rest", "idle", "move", "react", "notice"):
        for a in states[k]:
            assert set(_keyed(a, group.get("id"), "opacity")) == {1.0}, k
    # flight shows the spread wings and hides the folded ones; standing does the opposite
    for i in range(2):
        near, folded = _named(beach, f"Gull{i}WingNear"), _named(beach, f"Gull{i}Wing")
        for k, flying in (("rest", False), ("idle", False), ("move", True), ("react", True)):
            assert set(_keyed(states[k][0], near.get("id"), "opacity")) == {1.0 if flying else 0.0}, (i, k)
            assert set(_keyed(states[k][0], folded.get("id"), "opacity")) == {0.0 if flying else 1.0}, (i, k)


def test_gulls_stand_in_front_of_the_crab_on_its_plane(beach: ET.Element) -> None:
    plane = next(e for e in beach.iter("Node") if e.get("name") == "Plane4")
    kids = list(plane)
    group, crab = _named(beach, "GullsNpc"), _named(beach, "CrabNpc")
    assert group in kids and kids.index(group) < kids.index(crab)


def test_flight_path_is_a_history_free_bind_of_npc2x_ending_off_the_frame(beach: ET.Element) -> None:
    group = _named(beach, "GullsNpc")
    props = _props(beach)
    for key in ("13", "14", "16", "17"):
        b = next(b for b in group if b.tag == "DataBindContext" and b.get("propertyKey") == key)
        assert props[b.get("sourcePathIds").split("-")[1]] == "npc2X"
    path = scene_npc.GULL_PATH
    assert (_at(beach, group, 13, 0.0), _at(beach, group, 14, 0.0)) == pytest.approx(scene_npc.GULLS_AT, abs=1.0)
    assert (_at(beach, group, 13, 1.0), _at(beach, group, 14, 1.0)) == pytest.approx(path[-1][:2], abs=1.0)
    # at 1 the nearer gull's beak (the leftmost point, ~50 px before its feet) is past the right edge
    # plus Plane4's travel at parallax +1
    x_end, _, s_end = path[-1]
    left = x_end + s_end * (min(dx for dx, _, _ in scene_npc.GULL_FEET) - 50.0)
    assert left > gen_scenes.W + gen_scenes.PARALLAX_GAINS[4] * gen_scenes.PARALLAX_TRAVEL[0]
    # constant speed: npc2X proportional to the distance along the path, never backward in x
    xs = [_at(beach, group, 13, t / 20) for t in range(21)]
    assert all(b >= a for a, b in zip(xs, xs[1:]))


def test_facing_follows_the_sign_of_npc2look(beach: ET.Element) -> None:
    for i in range(2):
        facing = _named(beach, f"Gull{i}Facing")
        assert _at(beach, facing, 16, -1.0) == 1.0 and _at(beach, facing, 16, 0.0) == 1.0
        assert _at(beach, facing, 16, 1.0) == -1.0


def test_gull_ids_mint_from_the_m9_range(beach: ET.Element) -> None:
    group = _named(beach, "GullsNpc")
    for e in [*group.iter(), _layer(beach, "Npc2"), *[a for a in beach.iter("LinearAnimation")
                                                      if a.get("name", "").startswith("npc_gulls")]]:
        if e.get("id") is not None:
            assert M9_RANGE[0] <= int(e.get("id").split(":")[1]) < M9_RANGE[1], (e.tag, e.get("name"))


def test_only_the_beach_draws_the_second_slot() -> None:
    assert {s for s in world_kit.BUILT_IN_SCENES if "npc2" in gen_scenes.V12_BINDS[s]} == {"beach"}
    assert {"npc2", "npc2X", "npc2Look"} <= gen_scenes.V12_BINDS["beach"]
