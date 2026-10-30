"""Moonshot M9 Task 2 (contract v12): the world kit (moon phase, December lights, trail dots), the v12
SceneVM members, the drag table and the scene registry. Pure: the helpers' formulas are evaluated on
the generated XML (world_kit.eval_formula, the runtime's precedence)."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import types
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import art_bible  # noqa: E402
import check_contract  # noqa: E402
import gen_scenes  # noqa: E402
from rml import El, render  # noqa: E402
import world_kit  # noqa: E402
from world_kit import DRAGS, TRAIL_DOTS, eval_formula  # noqa: E402

ALL = ("livingRoom", "campfire", "beach", "deepSpace", "cafe", "rooftop", "mountainHut")
R = 80.0


def _xml(sc: gen_scenes.Scene, *els: El) -> tuple[ET.Element, dict[str, ET.Element]]:
    """The elements and the scene's root converters as parsed XML, plus converters by id."""
    root = ET.fromstring("<Rive>" + "".join(render(e) for e in (*els, *sc.roots)) + "</Rive>")
    convs = {c.get("id"): c for c in root.iter("DataConverterFormula")}
    return root, convs


def _bind(e: ET.Element, prop: str, key: int, sc: gen_scenes.Scene) -> ET.Element:
    (b,) = [b for b in e.findall("DataBindContext") if b.get("propertyKey") == str(key)]
    assert b.get("sourcePathIds") == sc.vpath(prop)
    return b


def _value(e: ET.Element, prop: str, key: int, sc: gen_scenes.Scene, convs: dict, x: float,
           bound: dict[str, float] | None = None) -> float:
    b = _bind(e, prop, key, sc)
    conv = b.get("converterId")
    if conv is None:
        return x
    paths = {sc.vpath(n): v for n, v in (bound or {}).items()}
    return eval_formula(convs[conv], x, paths.__getitem__)


# ====================================================================== moon (ruling 12)
@pytest.fixture(scope="module")
def moon() -> tuple[gen_scenes.Scene, ET.Element, dict, ET.Element]:
    sc = gen_scenes.Scene("rooftop")
    lit = sc.E((300.0, 200.0), "MoonLit", 300.0, 200.0, 2 * R, 2 * R, sc.F("FFF4ECD8"))
    rig = world_kit.moon_rig(sc, sc.d9, 300.0, 200.0, R, lit, "E60E1630")
    old = world_kit.hide_when_phased(sc, sc.d9, "M8Moon", [sc.E((0.0, 0.0), "Moon", 300.0, 200.0, 150.0, 150.0,
                                                                sc.F("FFFFFFFF"))])
    root, convs = _xml(sc, rig, old)
    return sc, root, convs, root.find("Node[@name='M8Moon']")


def _moon(moon: tuple, p: float) -> dict[str, float]:
    sc, root, convs, old = moon
    rig = root.find("Node[@name='MoonRig']")
    dark = rig.find("Shape[@name='MoonDark']")
    term = dark.find("PointsPath[@name='Terminator']")
    return {"show": _value(rig, "moonPhase", 18, sc, convs, p), "mirror": _value(dark, "moonPhase", 16, sc, convs, p),
            "term": _value(term, "moonPhase", 16, sc, convs, p), "m8": _value(old, "moonPhase", 18, sc, convs, p)}


@pytest.mark.parametrize("p", [0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.999])
def test_moon_terminator_half_width_and_colour_per_quadrant(moon: tuple, p: float) -> None:
    v = _moon(moon, p)
    assert v["show"] == 1.0 and v["m8"] == 0.0
    # the terminator is a half ellipse of half-width R x |scaleX| = R |cos 2 pi p|
    assert math.isclose(R * abs(v["term"]), R * abs(math.cos(2 * math.pi * p)), abs_tol=0.05)
    crescent = p < 0.25 or p > 0.75
    gibbous = 0.25 < p < 0.75
    # scaleX > 0: on the lit side of the diameter, added to the dark half (dark terminator);
    # scaleX < 0: mirrored into the dark half, cut out by even-odd (lit terminator)
    if crescent:
        assert v["term"] > 0
    if gibbous:
        assert v["term"] < 0
    # waxing (p < 0.5) is dark on the left, lit on the right (northern view); waning mirrored; at the
    # full moon exactly the (empty) dark region is squashed to nothing
    assert v["mirror"] == (1.0 if p < 0.5 else 0.0 if p == 0.5 else -1.0)


def test_moon_quarters_and_new_and_full(moon: tuple) -> None:
    new, first, full, last = (_moon(moon, p) for p in (0.0, 0.25, 0.5, 0.75))
    assert math.isclose(new["term"], 1.0, abs_tol=1e-3)        # dark half + dark full-width terminator: a dark disc
    assert abs(first["term"]) < 1e-3 and abs(last["term"]) < 1e-3   # straight terminators
    assert math.isclose(full["term"], -1.0, abs_tol=1e-3)       # the dark half is cut out entirely
    assert first["mirror"] == 1.0 and last["mirror"] == -1.0
    # continuous through the new moon (0.99 -> 0.01): the region is the whole disc on both sides
    assert math.isclose(_moon(moon, 0.999)["term"], _moon(moon, 0.001)["term"], abs_tol=1e-3)


def test_moon_at_minus_one_draws_nothing_and_keeps_the_m8_moon(moon: tuple) -> None:
    v = _moon(moon, -1.0)
    assert v["show"] == 0.0 and v["m8"] == 1.0
    sc, root, _, old = moon
    rig = root.find("Node[@name='MoonRig']")
    assert float(rig.get("opacity")) == 0.0            # the static value is the default's
    assert old.get("opacity") is None                  # 1: the M8 moon at identity
    dark = rig.find("Shape[@name='MoonDark']")
    assert dark.find("Fill").get("fillRule") == "evenOdd"
    paths = [p.get("name") for p in dark.findall("PointsPath")]
    assert paths == ["DarkHalf", "Terminator"]
    half = dark.find("PointsPath[@name='DarkHalf']")
    # the dark side bleeds MOON_DARK_BLEED px past the lit disc (no lit hairline at its limb)
    assert max(float(v.get("x")) for v in half) == 0.0
    assert min(float(v.get("x")) for v in half) == -(R + world_kit.MOON_DARK_BLEED)
    assert [c.get("name") for c in rig if c.tag != "DataBindContext"] == ["MoonDark", "MoonLit"]  # dark in front


def test_moon_mints_from_the_m9_range(moon: tuple) -> None:
    _, root, _, _ = moon
    callers = {e.get("id") for name in ("MoonLit", "Moon") for s in root.iter("Shape") if s.get("name") == name
               for e in s.iter()}   # the caller's own art (minted from the scene's main document here)
    ids = [int(e.get("id").split(":")[1]) for e in root.iter() if e.get("id") and e.get("id") not in callers]
    assert ids and all(gen_scenes.M9_ID_START <= i < gen_scenes.M8_ID_START for i in ids)


# ====================================================================== festive (ruling 13)
def test_festive_lights_are_invisible_at_0_and_twinkle_in_two_colours() -> None:
    sc = gen_scenes.Scene("cafe")
    pts = [(100.0, 300.0), (200.0, 330.0), (300.0, 340.0), (400.0, 330.0), (500.0, 300.0)]
    node = world_kit.festive_lights(sc, sc.d9, pts, ("FFFFD27A", "FFFF6B6B"))
    root, convs = _xml(sc, node)
    fl = root.find("Node[@name='FestiveLights']")
    assert float(fl.get("opacity")) == 0.0
    for x, want in ((0.0, 0.0), (0.5, 0.5), (1.0, 1.0)):
        assert _value(fl, "festive", 18, sc, convs, x) == want
    a, b = fl.find("Node[@name='emitBulbsA']"), fl.find("Node[@name='emitBulbsB']")
    assert len(a.findall("Shape")) == 2 * 3 and len(b.findall("Shape")) == 2 * 2   # bulb + glow per point
    cols = {s.find("Fill/SolidColor").get("colorValue") for s in a.findall("Shape") if s.find("Fill/SolidColor") is not None}
    assert cols == {"FFFFD27A"}
    anim = next(x for x in sc.anims if x.attrs["name"] == "amb_festive")
    assert anim.attrs["duration"] == world_kit.FESTIVE_TWINKLE_FRAMES and anim.attrs["loopValue"] == "loop"
    keyed = {ko.attrs["objectId"]: [float(k.attrs["value"]) for k in ko.children[0].children] for ko in anim.children}
    ka, kb = keyed[a.get("id")], keyed[b.get("id")]
    assert ka[0] == ka[-1] == 1.0 and kb[0] == kb[-1] == world_kit.FESTIVE_LOW   # counter-phase, seamless
    assert any(l.attrs["name"] == "FestiveTwinkle" for l in sc.layers)


# ====================================================================== trail dots (ruling 8)
def test_trail_dots_show_the_first_trail_n_and_fade() -> None:
    sc = gen_scenes.Scene("beach")
    node = world_kit.trail_dots(sc, sc.d9, "FF6E6656", "FFB8AC94", 14.0)
    root, convs = _xml(sc, node)
    td = root.find("Node[@name='TrailDots']")
    assert float(td.get("opacity")) == 0.0 and (float(td.get("x")), float(td.get("y"))) == (0.0, 0.0)
    assert [_value(td, "trailFade", 18, sc, convs, f) for f in (1.0, 0.25, 0.0)] == [0.0, 0.75, 1.0]
    dots = td.findall("Node")
    assert [d.get("name") for d in dots] == [f"TrailDot{i}" for i in range(TRAIL_DOTS)]
    for i, d in enumerate(dots):
        assert float(d.get("opacity")) == 0.0
        _bind(d, f"trailX{i}", 13, sc)
        _bind(d, f"trailY{i}", 14, sc)
        for n in (0, 1, 5, 15, 16):
            assert _value(d, "trailN", 18, sc, convs, float(n)) == (1.0 if i < n else 0.0), (i, n)


# ====================================================================== v12 members and drags
def test_drags_parse_the_contract_table() -> None:
    assert set(DRAGS) == set(ALL)
    kinds = {sid: [h.kind for h in hs] for sid, hs in DRAGS.items()}
    assert kinds == {"livingRoom": ["pull"], "campfire": ["poke"], "beach": ["trail"], "deepSpace": ["spin"],
                     "cafe": ["trail"], "rooftop": ["aim"], "mountainHut": ["pull"]}
    assert DRAGS["campfire"][0].numbers == (("poke", 0.0), ("pokeX", 0.0), ("pokeY", 0.0))
    assert DRAGS["cafe"][0].numbers == DRAGS["beach"][0].numbers == world_kit.TRAIL_NUMBERS
    assert world_kit.TRAIL_NUMBERS[0] == ("trailN", 0.0) and world_kit.TRAIL_NUMBERS[-1] == ("trailFade", 1.0)
    assert len(world_kit.TRAIL_NUMBERS) == 2 + 2 * TRAIL_DOTS
    for sid, hs in DRAGS.items():
        for h in hs:
            x0, y0, x1, y1 = h.rect
            assert 0 <= x0 < x1 <= 1080 and 0 <= y0 < y1 <= 1920 and 0 <= h.plane <= 5, (sid, h)


@pytest.mark.parametrize("sid", ALL)
def test_v12_members_follow_the_v11_ones_in_contract_order(sid: str) -> None:
    names = world_kit.drag_numbers(sid)
    assert len(names) == len(set(names)), sid
    sc = gen_scenes.Scene(sid)
    props = [p.attrs["name"] for p in sc.vm.children if p.tag.startswith("ViewModelProperty")]
    c = check_contract.parse_contract()
    assert props == [*c["scene_vm_props"], *names]
    assert props[-5 - len(names):] == ["npc2", "npc2X", "npc2Look", "moonPhase", "festive", *names][-5 - len(names):]
    dflt = {sc.v7[n].ref(): n for n, _, _ in world_kit.v12_members(sid)}
    vals = {dflt[v.attrs["viewModelPropertyId"]]: v.attrs["propertyValue"] for v in sc.inst.children
            if v.attrs.get("viewModelPropertyId") in dflt}
    assert vals["moonPhase"] == -1.0 and vals["festive"] == 0.0 and vals["npc2X"] == vals["npc2Look"] == 0.0
    assert vals["npc2"] == sc.npc_vals["away"].ref()
    assert all(vals[n] == v for h in DRAGS[sid] for n, v in h.numbers)
    for n, _, _ in world_kit.v12_members(sid):
        assert gen_scenes.M9_ID_START <= int(sc.v7[n].ref().split(":")[1]) < gen_scenes.M8_ID_START


def test_v12_binds_must_match_the_declaration() -> None:
    sc = gen_scenes.Scene("rooftop")
    rig = world_kit.moon_rig(sc, sc.d9, 0.0, 0.0, R, sc.E((0.0, 0.0), "MoonLit", 0, 0, 2 * R, 2 * R, sc.F("FFFFFFFF")),
                             "E6000000")
    sc.binds = set()
    with pytest.raises(ValueError, match="moonPhase"):
        sc.check_v12_binds([rig, *sc.roots])
    sc.binds = {"moonPhase"}
    sc.check_v12_binds([rig, *sc.roots])
    sc.binds = {"moonPhase", "festive"}
    with pytest.raises(ValueError, match="festive"):
        sc.check_v12_binds([rig, *sc.roots])


def test_contract_says_who_binds_the_v12_members() -> None:
    c = check_contract.parse_contract()
    assert c["v12_binders"] == {
        "npc2": {"beach"}, "npc2X": {"beach"}, "npc2Look": {"beach"},
        "moonPhase": {"livingRoom", "campfire", "cafe", "rooftop", "mountainHut"},
        "festive": {"livingRoom", "cafe", "mountainHut"}}
    assert c["scene_vm_props"]["npc2"] == "enum" and c["scene_vm_props"]["npc2X"] == "number"
    assert set(c["scenes"]) == set(ALL)
    for sid in world_kit.BUILT_IN_SCENES:
        assert world_kit.declared_binds(sid) <= ({n for n, who in c["v12_binders"].items() if sid in who}
                                                 | set(world_kit.drag_numbers(sid)))


# ====================================================================== the registry
def test_scene_builders_cover_every_scene() -> None:
    c = check_contract.parse_contract()
    assert set(gen_scenes.SCENE_BUILDERS) == set(gen_scenes.SCENE_EVENTS) == set(ALL)
    assert {sid: evs for sid, (evs, _) in c["scenes"].items()} == gen_scenes.SCENE_EVENTS
    assert set(world_kit.SCENE_MODULES) | set(world_kit.BUILT_IN_SCENES) == set(ALL)
    assert gen_scenes.M9_ID_START == 920000
    assert set(art_bible.SCENES) == set(ALL)


@pytest.fixture
def fake_scene(monkeypatch: pytest.MonkeyPatch) -> str:
    """A v12-style scene id whose module does not exist."""
    monkeypatch.setitem(world_kit.SCENE_MODULES, "nowhere", "scene_nowhere_m9_test")
    monkeypatch.setitem(gen_scenes.SCENE_BUILDERS, "nowhere", gen_scenes._lazy("nowhere"))
    return "nowhere"


def test_a_scene_whose_module_is_missing_fails_clearly(fake_scene: str, capsys: pytest.CaptureFixture) -> None:
    with pytest.raises(world_kit.SceneNotWritten, match="scene_nowhere_m9_test.py does not exist yet"):
        gen_scenes.SCENE_BUILDERS[fake_scene]()
    assert gen_scenes.main([fake_scene]) == 1
    assert "does not exist yet" in capsys.readouterr().err
    assert gen_scenes.main(["noSuchScene"]) == 1
    assert world_kit.review(fake_scene) == {} and world_kit.declared_binds(fake_scene) == frozenset()


def test_review_tools_read_a_scene_modules_review_dict(monkeypatch: pytest.MonkeyPatch) -> None:
    pytest.importorskip("numpy")
    import review_diorama  # noqa: PLC0415
    import review_npc  # noqa: PLC0415
    import review_time  # noqa: PLC0415

    def extras(render: object, out: Path, gates: list[str]) -> None:
        gates.append("extra ok")

    mod = types.ModuleType("scene_fake_m9_test")
    mod.REVIEW = {"diorama": {"patches": [("Plane4 cup", (10, 20, 30, 40), 28)], "seam_box": (1, 2, 3, 4)},
                  "extras": extras,
                  "time": {"sky_box": (0, 0, 10, 10), "dusk_box": (0, 5, 10, 10)},
                  "npc": {"crop": (200, 180, -20), "seam": {"idle": 120}, "prop": "fish",
                          "waypoints": [(500.0, 900.0, 1.0), (600.0, 900.0, 1.0)]}}
    mod.BINDS = {"moonPhase"}
    monkeypatch.setitem(sys.modules, "scene_fake_m9_test", mod)
    monkeypatch.setitem(world_kit.SCENE_MODULES, "fake", "scene_fake_m9_test")
    cfg = review_diorama.cfg_of("fake")
    assert cfg.patches == [("Plane4 cup", (10, 20, 30, 40), 28)] and cfg.seam_box == (1, 2, 3, 4) and cfg.wet is None
    assert review_diorama.extras_of("fake") is extras
    assert review_diorama.cfg_of("campfire") is review_diorama.CFG["campfire"]
    assert review_time.time_cfg("fake") == ((0, 0, 10, 10), (0, 5, 10, 10), 12.0)
    assert review_time.time_cfg("deepSpace") is None
    assert review_npc.anchor("fake", 0.5) == (550.0, 900.0)
    assert review_npc.npc_cfg("fake")["fog"] is True
    assert review_npc.npc_cfg("livingRoom")["waypoints"][0][2] == review_npc.scene_npc.TV_SCALE
    assert world_kit.declared_binds("fake") == frozenset({"moonPhase"})


def test_eval_formula_follows_runtime_precedence() -> None:
    sc = gen_scenes.Scene("beach")
    conv = sc.conv(2.0, 3.0)      # 3 + 2 x input
    assert eval_formula(conv, 5.0) == 13.0
