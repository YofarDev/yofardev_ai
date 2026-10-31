"""Moonshot M11 Task 7 (ruling 13, contract v14 `tier`): the shared tier gate pass (`world_kit.tier_gate`,
run by `Scene.write` for every scene). Pure: the gates' converters are evaluated on the generated XML at the
enum's index (`DataConverterToNumber`: low 0, high 1, ultra 2)."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
from rml import El, render  # noqa: E402
import world_kit  # noqa: E402
from world_kit import TIER_LEVELS, eval_formula, gate_root  # noqa: E402

ALL = ("livingRoom", "campfire", "beach", "deepSpace", "cafe", "rooftop", "mountainHut",
       "forestCabin", "trainCompartment", "library")
TIER_INDEX = {"low": 0, "high": 1, "ultra": 2}


def _opacity(bind: ET.Element, groups: dict, formulas: dict, tier: str) -> float:
    """The opacity a tier bind gives at `tier`: the group's ToNumber (the enum index) into its formula."""
    items = [i.get("converterId") for i in groups[bind.get("converterId")]]
    assert len(items) == 2 and items[0] not in formulas, "ToNumber first, then the clamp formula"
    return eval_formula(formulas[items[1]], float(TIER_INDEX[tier]))


def _parse(sc: gen_scenes.Scene, *els: El) -> tuple[ET.Element, dict, dict]:
    root = ET.fromstring("<Rive>" + "".join(render(e) for e in (*els, *sc.roots)) + "</Rive>")
    groups = {g.get("id"): list(g) for g in root.iter("DataConverterGroup")}
    formulas = {c.get("id"): c for c in root.iter("DataConverterFormula")}
    return root, groups, formulas


def _tier_binds(e: ET.Element, sc: gen_scenes.Scene) -> list[ET.Element]:
    return [b for b in e.findall("DataBindContext") if b.get("sourcePathIds") == sc.vpath("tier")]


def _toy() -> tuple[gen_scenes.Scene, list[El], El]:
    sc = gen_scenes.Scene("campfire")
    d = sc.d
    spark = [d("Shape", d("Ellipse", width=4.0, height=4.0, name="Path"), name=f"emitSpark{i}") for i in range(3)]
    keyed = d("Node", d("Shape", d("Ellipse", width=4.0, height=4.0, name="Path"), name="Mote"), name="Dust0")
    dim = d("Node", name="Steam", opacity=0.5)
    inner = d("Node", name="Splash1")
    outer = d("Node", inner, name="Splash0")
    fills = [d("Fill", d("SolidColor", colorValue="33FFFFFF"), name="Fill") for _ in range(4)]
    veil = d("Shape", sc.bind("fog", 18, doc=sc.d8), d("Rectangle", width=10.0, height=10.0, name="Path"), *fills,
             x=-60.0, y=700.0, opacity=0.9, name="FogVeil0")
    plane = d("Node", veil, *spark, keyed, dim, outer, d("Node", name="Tree"), name="Plane0")
    anim = d("LinearAnimation", sc.T(keyed, opacity=[(0, 1.0), (10, 0.0)]), duration=10, name="amb_dust")
    return sc, [plane], anim


def test_gate_root_strips_emit_and_digits() -> None:
    assert gate_root("emitSplash12") == "Splash"
    assert gate_root("GlassStreaksB") == "GlassStreaksB"
    assert gate_root("FireflyB3") == "FireflyB"


def test_high_gates_draw_at_ultra_only_and_low_gates_at_high_and_ultra() -> None:
    sc, content, anim = _toy()
    start = sc.d11.next
    before = {e.get("id") for e in _parse(sc, *content)[0].iter()}
    rep = world_kit.tier_gate(sc, sc.d11, [content], [anim], {"high": ("Spark", "Splash"), "low": ("Dust", "Steam")})
    assert rep.gated == {"high": ["emitSpark0", "emitSpark1", "emitSpark2", "Splash0"], "low": ["Dust0", "Steam"]}
    root, groups, formulas = _parse(sc, *content)
    plane = root.find("Node")
    by_name = {e.get("name"): e for e in plane}
    # a free element carries the bind itself (its id and place unchanged)
    for i in range(3):
        (b,) = _tier_binds(by_name[f"emitSpark{i}"], sc)
        assert [_opacity(b, groups, formulas, t) for t in ("low", "high", "ultra")] == [0.0, 0.0, 1.0]
    # keyed opacity / an authored opacity below 1: an identity wrapper takes the bind, in place
    for wrapped, level, want in (("Dust0", "low", [0.0, 1.0, 1.0]), ("Steam", "low", [0.0, 1.0, 1.0])):
        wrap = by_name[f"Tier{wrapped}"]
        assert (wrap.get("x"), wrap.get("y")) == ("0", "0") and wrap.get("opacity") is None
        assert [c.get("name") for c in wrap if c.tag == "Node"] == [wrapped]
        assert not _tier_binds(wrap.find("Node"), sc)
        (b,) = _tier_binds(wrap, sc)
        assert [_opacity(b, groups, formulas, t) for t in ("low", "high", "ultra")] == want
    # nested matches: only the outer one is gated
    (b,) = _tier_binds(by_name["Splash0"], sc)
    assert not _tier_binds(by_name["Splash0"].find("Node"), sc)
    # draw order kept (the wrappers sit where their element was)
    assert [e.get("name") for e in plane if e.tag in ("Node", "Shape")] == [
        "FogVeil0", "emitSpark0", "emitSpark1", "emitSpark2", "TierDust0", "TierSteam", "Splash0",
        "Tree"]
    # every new element mints from the doc it was given
    new = [e.get("id") for e in root.iter() if e.get("id") not in before]
    assert new and all(start <= int(i.split(":")[1]) < sc.d11.next < gen_scenes.M10_ID_START for i in new)


def test_fog_veils_keep_one_fill_at_low_and_all_of_them_above() -> None:
    sc, content, anim = _toy()
    veil_fills = [c.id for c in content[0].children[0].children if c.tag == "Fill"]
    rep = world_kit.tier_gate(sc, sc.d11, [content], [anim], {})
    assert rep.veils == ["FogVeil0"] and rep.gated == {"high": [], "low": []}
    root, groups, formulas = _parse(sc, *content)
    veil = next(e for e in root.iter("Shape") if e.get("name") == "FogVeil0")
    (thick,) = veil.findall("Shape")
    assert thick.get("name") == "TierFogFills0"
    # the veil keeps its first fill (same id) and its fog bind; its child holds the others (same ids), at
    # the veil's origin with the same rectangle (it inherits the veil's frame and opacity)
    assert [f.get("id") for f in veil.findall("Fill")] == veil_fills[:1]
    assert [f.get("id") for f in thick.findall("Fill")] == veil_fills[1:]
    assert (thick.get("x"), thick.get("y"), thick.get("opacity")) == ("0", "0", None)
    assert thick.find("Rectangle").attrib | {"id": ""} == veil.find("Rectangle").attrib | {"id": ""}
    assert [b.get("sourcePathIds") for b in veil.findall("DataBindContext")] == [sc.vpath("fog")]
    (b,) = _tier_binds(thick, sc)
    assert [_opacity(b, groups, formulas, t) for t in ("low", "high", "ultra")] == [0.0, 1.0, 1.0]


def test_a_feathered_shape_is_hidden_at_low() -> None:
    sc, content, anim = _toy()
    d = sc.d
    soft = d("Shape", d("Ellipse", width=4.0, height=4.0, name="Path"),
             d("Fill", d("SolidColor", colorValue="FFFFFFFF"), d("Feather", strength=8.0), name="Fill"), name="Halo")
    content[0].children.append(soft)
    rep = world_kit.tier_gate(sc, sc.d11, [content], [anim], {})
    assert rep.gated["low"] == ["Halo"]


def test_unknown_and_doubled_names_fail() -> None:
    sc, content, anim = _toy()
    with pytest.raises(KeyError, match="NoSuch"):
        world_kit.tier_gate(sc, sc.d11, [content], [anim], {"high": ("NoSuch",)})
    sc, content, anim = _toy()
    with pytest.raises(ValueError, match="both"):
        world_kit.tier_gate(sc, sc.d11, [content], [anim], {"high": ("Steam",), "low": ("Steam",)})


# ====================================================================== the built scenes
@pytest.fixture(scope="module")
def built(tmp_path_factory: pytest.TempPathFactory) -> dict[str, tuple[ET.Element, gen_scenes.Scene | None]]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {sid: ET.parse(gen_scenes.SCENE_BUILDERS[sid]()).getroot() for sid in ALL}
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.mark.parametrize("sid", ALL)
def test_every_scene_declares_and_binds_the_tier(sid: str) -> None:
    assert "tier" in gen_scenes.V14_BINDS[sid]
    assert "tier" in world_kit.declared_v14_binds(sid)
    gates = world_kit.tier_gates(sid)
    assert set(gates) == set(TIER_LEVELS) and gates["high"], sid   # low may name nothing (the veils still thin)


@pytest.mark.parametrize("sid", ALL)
def test_every_gate_name_is_gated_at_its_level_in_the_file(sid: str, built: dict) -> None:
    root = built[sid]
    vm = root.find("ViewModel")
    tier_id = next(p.get("id") for p in vm if p.get("name") == "tier")
    path = f"{vm.get('id')}-{tier_id}"
    groups = {g.get("id"): list(g) for g in root.iter("DataConverterGroup")}
    formulas = {c.get("id"): c for c in root.iter("DataConverterFormula")}
    level_of: dict[str, str] = {}
    for g, items in groups.items():
        f = formulas.get(items[-1].get("converterId"))
        if f is not None:
            vals = [eval_formula(f, float(i)) for i in range(3)]
            level_of[g] = {(0.0, 0.0, 1.0): "high", (0.0, 1.0, 1.0): "low"}.get(tuple(vals), "?")
    gated: dict[str, set[str]] = {"high": set(), "low": set()}
    for e in root.iter():
        if e.tag not in ("Node", "Shape"):
            continue
        for b in e.findall("DataBindContext"):
            if b.get("sourcePathIds") == path:
                assert b.get("propertyKey") == "18"
                lvl = level_of[b.get("converterId")]
                wrapper = e.tag == "Node" and str(e.get("name")).startswith(world_kit.TIER_WRAP_PREFIX)
                targets = list(e.iter())[1:] if wrapper else [e]
                gated[lvl] |= {n for t in targets if t.tag in ("Node", "Shape")
                               for n in (gate_root(t.get("name", "")), t.get("name", "").removeprefix("emit"))}
    for lvl, names in world_kit.tier_gates(sid).items():
        assert set(names) <= gated[lvl], (sid, lvl, set(names) - gated[lvl])
    # the fog veils keep one fill each; their other fills sit in the low-gated child
    for veil in (e for e in root.iter("Shape") if world_kit.FOG_VEIL.fullmatch(e.get("name", ""))):
        assert len(veil.findall("Fill")) == 1, (sid, veil.get("name"))
        (thick,) = veil.findall("Shape")
        assert len(thick.findall("Fill")) == 3 and "TierFogFills" in gated["low"], (sid, veil.get("name"))


def test_a_full_name_gates_one_copy_of_a_numbered_set() -> None:
    sc, content, anim = _toy()
    rep = world_kit.tier_gate(sc, sc.d11, [content], [anim], {"high": ("Spark2",), "low": ("Spark",)})
    # the full name wins over the root: Spark2 at high, the other copies at low
    assert rep.gated == {"high": ["emitSpark2"], "low": ["emitSpark0", "emitSpark1"]}


@pytest.mark.parametrize("sid", ALL)
def test_old_and_new_scenes_name_their_gates_where_the_contract_says(sid: str) -> None:
    gates = world_kit.tier_gates(sid)
    mod = world_kit.written_scene_modules().get(sid)
    # the module scenes keep their own table; the four M8 scenes are in gen_scenes
    assert (gates == {k: tuple(v) for k, v in mod.TIER_GATES.items()}) if mod is not None else (
        gates == gen_scenes.TIER_GATES[sid])
