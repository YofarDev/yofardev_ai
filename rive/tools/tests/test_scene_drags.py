"""Moonshot M9 lane E (contract v12, rulings 8, 12, 13): the v12 art of the four M8 scenes, on freshly
generated RML: the drag numbers each scene binds (livingRoom `cord`, campfire `poke` / `pokeX` / `pokeY`,
beach `trail*`, deepSpace `spin`), the moon's phase (livingRoom, campfire), the December lights
(livingRoom), all history-free and drawing nothing at the defaults."""

from __future__ import annotations

import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import world_kit  # noqa: E402

SCENES = ("livingRoom", "campfire", "beach", "deepSpace")
M9_RANGE = (gen_scenes.M9_ID_START, gen_scenes.M8_ID_START)
V12_ROOTS = {"livingRoom": ("LampCord", "MoonPhased", "MoonRig", "FestiveLights"),
             "campfire": ("PokeStick", "MoonPhased", "MoonRig"), "beach": ("TrailDots", "GullsNpc"),
             "deepSpace": ()}


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {sid: ET.fromstring(Path(getattr(gen_scenes, sid)()).read_text()) for sid in SCENES}
    finally:
        gen_scenes.OUT_ROOT = root


def _n(i: str) -> int:
    return int(i.split(":")[1])


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")


def _props(doc: ET.Element) -> dict[str, str]:
    return {p.get("id"): p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")}


def _named(doc: ET.Element, name: str) -> ET.Element:
    return next(e for e in doc.iter() if e.get("name") == name and e.tag in ("Node", "Shape"))


def _parent(doc: ET.Element, el: ET.Element) -> ET.Element:
    return next(p for p in doc.iter() if el in list(p))


def _bind(doc: ET.Element, el: ET.Element, key: int) -> tuple[str, ET.Element | None]:
    """(source property name, converter) of `el`'s bind of property `key`."""
    props = _props(doc)
    b = next(b for b in el if b.tag == "DataBindContext" and b.get("propertyKey") == str(key))
    conv = next((c for c in doc.iter("DataConverterFormula") if c.get("id") == b.get("converterId")), None)
    return props[b.get("sourcePathIds").split("-")[1]], conv


def _at(doc: ET.Element, el: ET.Element, key: int, x: float, env: dict[str, float] | None = None) -> float:
    """The bound value of property `key` of `el` when its source is `x` (other view-model numbers from
    `env`, 0 when absent)."""
    props = _props(doc)
    _, conv = _bind(doc, el, key)
    if conv is None:
        return x
    return world_kit.eval_formula(conv, x, lambda p: (env or {}).get(props[p.split("-")[1]], 0.0))


def _plane(doc: ET.Element, el: ET.Element) -> int:
    p = el
    while not re.fullmatch(r"Plane\d", str(p.get("name", ""))):
        p = _parent(doc, p)
    return int(p.get("name")[5:])


X, Y, ROT, SX, SY, OP = 13, 14, 15, 16, 17, 18


# ---------------------------------------------------------------- binds and ids
@pytest.mark.parametrize("sid", SCENES)
def test_each_scene_binds_exactly_its_v12_members(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    v12 = {i: n for i, n in _props(doc).items() if n in {m for m, _, _ in world_kit.v12_members(sid)}}
    got = world_kit.bound_names(doc, _vm(doc).get("id"), v12)
    assert got == gen_scenes.V12_BINDS[sid] == world_kit.declared_binds(sid)
    assert set(world_kit.drag_numbers(sid)) <= got                      # every drag number draws
    assert ({"npc2", "npc2X", "npc2Look"} <= got) == (sid == "beach")   # ruling 10: only the beach
    assert ("moonPhase" in got) == (sid in ("livingRoom", "campfire"))  # ruling 12: the M8 moons
    assert ("festive" in got) == (sid == "livingRoom")                  # ruling 13: indoor only


@pytest.mark.parametrize("sid", SCENES)
def test_v12_art_mints_from_the_m9_range(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    for name in V12_ROOTS[sid]:
        el = _named(doc, name)
        for e in el.iter():
            if e.get("id") is None or (name == "MoonPhased" and e is not el):
                continue   # the M8 moon `MoonPhased` wraps keeps its ids
            assert M9_RANGE[0] <= _n(e.get("id")) < M9_RANGE[1], (name, e.tag, e.get("name"), e.get("id"))
    if sid == "deepSpace":
        wraps = [e for e in doc.iter("Shape") if str(e.get("name", "")).startswith("PlanetWeatherWrap")]
        assert wraps and all(M9_RANGE[0] <= _n(e.get("id")) < M9_RANGE[1] for w in wraps for e in w.iter())


@pytest.mark.parametrize("sid", SCENES)
def test_drag_rects_sit_on_the_art_and_its_plane(rml: dict[str, ET.Element], sid: str) -> None:
    drag, (x0, y0, x1, y1), plane = gen_scenes.V12_DRAG_RECTS[sid]
    assert drag in {h.id for h in world_kit.DRAGS[sid]}
    assert 0 <= x0 < x1 <= gen_scenes.W and 0 <= y0 < y1 <= gen_scenes.H
    doc = rml[sid]
    art = {"livingRoom": "LampCord", "campfire": "PokeStick", "beach": "TrailDots", "deepSpace": "Planet"}[sid]
    assert _plane(doc, _named(doc, art)) == plane


# ---------------------------------------------------------------- livingRoom: the cord
def test_cord_hangs_visible_at_rest_and_stretches_history_free(rml: dict[str, ET.Element]) -> None:
    """Fix round 1: the cord is the affordance, drawn at `cord` 0 (inside its rest box)."""
    doc = rml["livingRoom"]
    cord = _named(doc, "LampCord")
    assert float(cord.get("opacity", "1")) == 1.0
    assert not any(b.tag == "DataBindContext" and b.get("propertyKey") == str(OP) for b in cord)
    bead, line = _named(doc, "CordBead"), _named(doc, "CordLine")
    for v in (0.0, 0.5, 1.0):
        assert _at(doc, bead, Y, v) == pytest.approx(gen_scenes.CORD_LENGTH + gen_scenes.CORD_PULL * v)
        # the cord's bottom follows the bead's knot, and it thins as it stretches
        assert gen_scenes.CORD_LENGTH * _at(doc, line, SY, v) == pytest.approx(_at(doc, bead, Y, v), abs=0.05)
    assert _at(doc, line, SX, 0.0) == 1.0 and _at(doc, line, SX, 1.0) == pytest.approx(1 - gen_scenes.CORD_THIN)
    # the handle covers the cord at rest and the bead's whole travel; the rest box holds the cord at rest
    _, (x0, y0, x1, y1), _ = gen_scenes.V12_DRAG_RECTS["livingRoom"]
    cx, cy = gen_scenes.LAMP_CORD
    assert x0 < cx < x1 and y0 <= cy + gen_scenes.CORD_LENGTH and cy + gen_scenes.CORD_LENGTH + gen_scenes.CORD_PULL <= y1
    (bx0, by0, bx1, by1), = gen_scenes.V12_REST_AFFORDANCE["livingRoom"]
    assert bx0 < cx < bx1 and by0 <= cy and cy + gen_scenes.CORD_LENGTH + 18 <= by1


def test_festive_lights_hang_in_front_of_the_curtains_and_follow_festive(rml: dict[str, ET.Element]) -> None:
    doc = rml["livingRoom"]
    lights = _named(doc, "FestiveLights")
    assert _plane(doc, lights) == 2
    plane = _parent(doc, lights)
    art = [c for c in plane if c.tag in ("Node", "Shape") and not str(c.get("name")).startswith(("Hit_", "FogVeil"))]
    assert art[0] is lights   # the front of Plane2: over the curtains and the rod
    assert float(lights.get("opacity")) == 0.0 and _at(doc, lights, OP, 0.0) == 0.0 and _at(doc, lights, OP, 1.0) == 1.0


# ---------------------------------------------------------------- campfire: the poke stick
def test_poke_stick_rests_on_the_ground_and_lifts_into_the_fire_box(rml: dict[str, ET.Element]) -> None:
    """Fix round 1: the stick lies on the ground left of the fire at rest (drawn: the affordance) and
    `poke` lifts it into the fire box from the lower left, never into the avatar's band (x 330-750)."""
    doc = rml["campfire"]
    stick, lift = _named(doc, "PokeStick"), _named(doc, "PokeLift")
    assert float(stick.get("opacity", "1")) == 1.0
    (rx, ry), (tx, ty), (ax, ay) = gen_scenes.POKE_REST, gen_scenes.POKE_TIP, gen_scenes.POKE_RANGE
    # the lift: rest -> the fire box, angle rest -> lifted
    assert (_at(doc, lift, X, 0.0), _at(doc, lift, Y, 0.0)) == pytest.approx((rx, ry), abs=0.01)
    assert (_at(doc, lift, X, 1.0), _at(doc, lift, Y, 1.0)) == pytest.approx((tx, ty), abs=0.01)
    assert _at(doc, lift, ROT, 0.0) == pytest.approx(gen_scenes.POKE_REST_ANGLE, abs=1e-3)
    assert _at(doc, lift, ROT, 1.0) == pytest.approx(gen_scenes.POKE_ANGLE, abs=1e-3)
    # the aim: (pokeX, pokeY) x range, times poke (nothing moves while it lies on the ground)
    for v in (-1.0, 1.0):
        assert _at(doc, stick, X, v, {"poke": 1.0}) == pytest.approx(ax * v, abs=0.01)
        assert _at(doc, stick, Y, v, {"poke": 1.0}) == pytest.approx(ay * v, abs=0.01)
        assert _at(doc, stick, X, v, {"poke": 0.0}) == 0.0 and _at(doc, stick, Y, v, {"poke": 0.0}) == 0.0
    turn = _named(doc, "PokeTurn")
    assert _at(doc, turn, ROT, 1.0, {"poke": 0.0, "pokeY": 1.0}) == 0.0
    # from the lower left: the stick runs down-left from its tip in every pose, its far end off the left edge
    for a in (gen_scenes.POKE_REST_ANGLE, gen_scenes.POKE_ANGLE):
        assert math.cos(a) < 0 and math.sin(a) > 0
        for x in (rx, tx + ax):
            assert x + math.cos(a) * gen_scenes.POKE_LENGTH < -60
    # left of the avatar's band: the tip (and its 26 px glow) at its rightmost
    assert max(rx, tx + ax) + 26 <= 330
    # the handle covers the lying stick's visible part and the whole tip box; the rest box holds the lying stick
    _, (x0, y0, x1, y1), _ = gen_scenes.V12_DRAG_RECTS["campfire"]
    assert (x0, y0, x1, y1) == gen_scenes.POKE_HANDLE
    assert x0 <= tx - ax and tx + ax <= x1 and y0 <= ty - ay and ty + ay <= y1 and x1 >= rx and y1 >= ry
    (bx0, by0, bx1, by1), = gen_scenes.V12_REST_AFFORDANCE["campfire"]
    assert bx0 <= 0 and rx < bx1 and by0 < ry < by1


# ---------------------------------------------------------------- the moon's phase
@pytest.mark.parametrize("sid", ("livingRoom", "campfire"))
def test_moon_phases_replace_the_m8_moon(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    old, rig = _named(doc, "MoonPhased"), _named(doc, "MoonRig")
    assert _parent(doc, old) is _parent(doc, rig) and _plane(doc, rig) == 0
    assert any(e.get("name") == "emitMoon" for e in old.iter())          # the M8 disc, untouched inside
    for p, shown in ((-1.0, 1.0), (0.0, 0.0), (0.5, 0.0), (0.99, 0.0)):
        assert _at(doc, old, OP, p) == shown
        assert _at(doc, rig, OP, p) == 1.0 - shown
    cx, cy, r, dark = {"livingRoom": gen_scenes.LIVING_ROOM_MOON, "campfire": gen_scenes.CAMPFIRE_MOON}[sid]
    assert (float(rig.get("x")), float(rig.get("y"))) == (cx, cy)
    assert dark.startswith("E6")   # the night sky at 0.9 (ruling 12)


def test_beach_and_deep_space_have_no_moon_rig(rml: dict[str, ET.Element]) -> None:
    for sid in ("beach", "deepSpace"):
        assert not any(e.get("name") in ("MoonRig", "MoonPhased", "FestiveLights") for e in rml[sid].iter())


# ---------------------------------------------------------------- beach: the trail
def test_trail_dots_sit_at_the_plane_origin(rml: dict[str, ET.Element]) -> None:
    doc = rml["beach"]
    dots = _named(doc, "TrailDots")
    plane = _parent(doc, dots)
    assert plane.get("name") == "Plane4"
    assert float(dots.get("x")) == 0.0 and float(dots.get("y")) == 0.0 and float(dots.get("opacity")) == 0.0
    assert len([c for c in dots if c.tag == "Node"]) == world_kit.TRAIL_DOTS
    # behind every prop on the sand (the last art of Plane4), in front of the sand (Plane3)
    art = [c for c in plane if c.tag in ("Node", "Shape") and not str(c.get("name")).startswith(("Hit_", "FogVeil"))]
    assert art[-1] is dots


# ---------------------------------------------------------------- deepSpace: the spin
def test_spin_wraps_one_period_per_band(rml: dict[str, ET.Element]) -> None:
    doc = rml["deepSpace"]
    planet = next(e for e in doc.iter("Shape") if e.get("name") == "Planet")
    group = _parent(doc, planet)
    r = float(planet.find("Ellipse").get("width")) / 2
    bands = [c for c in group if str(c.get("name", "")).startswith("PlanetWeather")
             and not str(c.get("name")).startswith("PlanetWeatherWrap")]
    assert len(bands) == 14
    for b in bands:
        kids = list(group)
        copy = kids[kids.index(b) + 1]
        assert copy.get("name") == "PlanetWeatherWrap" + b.get("name")[len("PlanetWeather"):]
        x0 = float(b.get("x"))
        assert _at(doc, b, X, 0.0) == pytest.approx(x0)          # spin 0: the M8 band
        period = _at(doc, b, X, 1.0) - x0
        assert _at(doc, copy, X, 1.0) == pytest.approx(x0)       # spin 1: the copy is where the band was
        assert _at(doc, copy, X, 0.0) == pytest.approx(x0 - period)
        # at spin 0 the copy (and at 1 the band) lies wholly outside the disc it is clipped to
        xs = [float(v.get("x")) for v in b.find("PointsPath")]
        ys = [float(v.get("y")) + float(b.get("y")) for v in b.find("PointsPath")]
        cap = float(b.find("Stroke").get("thickness")) / 2
        near = max(0.0, min(abs(y - float(planet.get("y"))) for y in ys) - cap)
        assert (max(xs) - min(xs)) / 2 + cap + math.sqrt(r * r - near * near) < period < 2 * r + 2 * cap + 10
        assert copy.find("ClippingShape").get("sourceId") == planet.get("id")
