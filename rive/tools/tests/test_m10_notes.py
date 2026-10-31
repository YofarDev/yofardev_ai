"""Moonshot M10 Task 3 (plan ruling 15, contract v13): the four M9 scene notes, on freshly generated RML.

- every scene declares `night` (0) after `festive` and before its drag numbers, minted from the M10 range;
  only the beach binds it (`gen_scenes.V13_BINDS`), and only through opacity / formula binds;
- the café wipe cuts holes in the mist (clockwise fill rule, `isHole` ellipses) sized
  clamp(trailN - i) x (1 - trailFade^4), softened by mist rings clipped to the previous radius, and the
  mist comes back over the spots at opacity `trailFade`;
- the beach's night: a night sky over the sky plane, stars in front of it, the sun's glow at 1 - night,
  a multiply shade over the frame; all invisible at night 0;
- the rooftop's day lift: a screen overlay at opacity `daylight` over the parapet and the roof only;
- the render gates (spin seam, identity, wipe clarity) live in `rive/tools/review_m10_notes.py`; its
  pure helpers are checked here.
"""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import review_m10_notes  # noqa: E402
import scene_cafe  # noqa: E402
import scene_rooftop  # noqa: E402
import world_kit  # noqa: E402

ALL = ("livingRoom", "campfire", "beach", "deepSpace", "cafe", "rooftop", "mountainHut")
M10_RANGE = (gen_scenes.M10_ID_START, gen_scenes.M9_ID_START)


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {sid: ET.fromstring(Path(gen_scenes.SCENE_BUILDERS[sid]()).read_text()) for sid in ALL}
    finally:
        gen_scenes.OUT_ROOT = root


def _n(i: str | None) -> int:
    return int(str(i).split(":")[1])


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")


def _props(doc: ET.Element) -> dict[str, str]:
    return {p.get("id"): p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")}


def _named(doc: ET.Element, name: str) -> ET.Element:
    return next(e for e in doc.iter() if e.get("name") == name and e.tag in ("Node", "Shape"))


def _binds(doc: ET.Element, el: ET.Element, key: int) -> list[tuple[str, ET.Element | None]]:
    props = _props(doc)
    convs = {c.get("id"): c for c in doc.iter("DataConverterFormula")}
    return [(props[b.get("sourcePathIds").split("-")[1]], convs.get(b.get("converterId")))
            for b in el if b.tag == "DataBindContext" and b.get("propertyKey") == str(key)]


def _value(doc: ET.Element, el: ET.Element, key: int, env: dict[str, float]) -> float:
    """The bound value of `el`'s property `key` with the view model at `env` (absent numbers 0)."""
    props = _props(doc)
    ((name, conv),) = _binds(doc, el, key)
    x = env.get(name, 0.0)
    if conv is None:
        return x
    return world_kit.eval_formula(conv, x, lambda p: env.get(props[p.split("-")[1]], 0.0))


# ====================================================================== contract v13 `night`
def test_m10_range_sits_below_m9() -> None:
    assert gen_scenes.M10_ID_START == 910000 < gen_scenes.M9_ID_START


@pytest.mark.parametrize("sid", ALL)
def test_every_scene_declares_night_after_festive_before_its_drags(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    names = list(_props(doc).values())
    drags = list(world_kit.drag_numbers(sid))
    v14 = [n for n, _, _ in world_kit.v14_members(sid)]   # contract v14 (M11) follows `night`
    assert names[names.index("festive") + 1:] == ["night", *v14, *drags]
    vm = _vm(doc)
    night = next(p for p in vm if p.get("name") == "night")
    assert night.tag == "ViewModelPropertyNumber" and M10_RANGE[0] <= _n(night.get("id")) < M10_RANGE[1]
    (val,) = [v for v in vm.iter("ViewModelInstanceNumber") if v.get("viewModelPropertyId") == night.get("id")]
    assert float(val.get("propertyValue")) == 0.0


@pytest.mark.parametrize("sid", ALL)
def test_only_the_beach_binds_night(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    vm = _vm(doc)
    night = {p.get("id"): p.get("name") for p in vm if p.get("name") == "night"}
    got = world_kit.bound_names(doc, vm.get("id"), night)
    assert got == world_kit.declared_v13_binds(sid) == ({"night"} if sid == "beach" else set())
    assert gen_scenes.V13_BINDS == {"beach": frozenset({"night"})}


@pytest.mark.parametrize("sid", ALL)
def test_m10_art_mints_from_the_m10_range_only(rml: dict[str, ET.Element], sid: str) -> None:
    ids = [_n(e.get("id")) for e in rml[sid].iter() if e.get("id")]
    assert len(ids) == len(set(ids))
    m10 = [i for i in ids if M10_RANGE[0] <= i < M10_RANGE[1]]
    # below the M10 range only M11's own range (contract v14, `Scene.d11`) may appear
    assert m10 and not [i for i in ids if i < M10_RANGE[0] and i >= 890000 and i < gen_scenes.M11_ID_START]


# ====================================================================== café: the wipe clears the glass
def test_cafe_mist_holes_and_their_size(rml: dict[str, ET.Element]) -> None:
    doc = rml["cafe"]
    mist = _named(doc, "Mist")
    assert {f.get("fillRule") for f in mist.iter("Fill")} == {"clockwise"}
    holes = [e for e in mist if e.tag == "Ellipse"]
    assert len(holes) == world_kit.TRAIL_DOTS
    for i, h in enumerate(holes):
        assert h.get("isHole") == "true" and float(h.get("width")) == 2 * scene_cafe.WIPE_R
        assert (float(h.get("scaleX")), float(h.get("scaleY"))) == (0.0, 0.0)   # the default: no area
        assert [n for n, _ in _binds(doc, h, 13)] == [f"trailX{i}"] and [n for n, _ in _binds(doc, h, 14)] == [f"trailY{i}"]
        for key in (16, 17):
            size = [_value(doc, h, key, {"trailN": n, "trailFade": f})
                    for n, f in ((0, 0.0), (i + 1, 0.0), (i + 0.5, 0.0), (16, 1.0), (16, 0.5), (16, 0.0))]
            assert size == pytest.approx([0.0, 1.0, 0.5, 0.0, 1 - 0.5 ** 4, 1.0])
    # the M9 darken marks are gone
    assert not [e for e in doc.iter() if e.get("name") in ("TrailDots", "Mark")]


def test_cafe_soft_rings_and_the_mist_back(rml: dict[str, ET.Element]) -> None:
    doc = rml["cafe"]
    plane2 = _named(doc, "Plane2")
    kids = [c.get("name") for c in plane2 if c.tag != "DataBindContext"]
    rings = [f"WipeRing{j}" for j in range(len(scene_cafe.WIPE_RINGS))]
    clips = [f"WipeClip{j}" for j in range(len(scene_cafe.WIPE_RINGS))]
    # front first: rain, shower, the mist coming back, the rings, the mist (the clip sources draw nothing)
    assert kids.index("RainGlass") < kids.index("WipeMistBack") < kids.index(rings[0]) < kids.index("Mist")
    outer = scene_cafe.WIPE_R
    for (r, k), ring, clip in zip(scene_cafe.WIPE_RINGS, rings, clips):
        node, src = _named(doc, ring), _named(doc, clip)
        assert float(node.get("opacity")) == k and node.find("ClippingShape").get("sourceId") == src.get("id")
        assert [_value(doc, node, 18, {"trailFade": f}) for f in (0.0, 0.5, 1.0)] == pytest.approx([k, k / 2, 0.0])
        assert {float(e.get("width")) for e in src if e.tag == "Ellipse"} == {2 * outer}
        assert not src.findall("Fill")                     # a clip source draws nothing
        shape = node.find("Shape")
        holes = [e for e in shape if e.tag == "Ellipse"]
        assert {float(e.get("width")) for e in holes} == {2 * r} and {e.get("isHole") for e in holes} == {"true"}
        assert shape.find("Fill").get("fillRule") == "clockwise"
        assert r < outer and 0 < k < 1
        outer = r
    back = _named(doc, "WipeMistBack")
    assert [n for n, c in _binds(doc, back, 18)] == ["trailFade"] and _binds(doc, back, 18)[0][1] is None
    assert back.find("ClippingShape").get("sourceId") == _named(doc, clips[0]).get("id")
    # the same mist gradient in the mist, every ring and the mist coming back
    def stops(e: ET.Element) -> list[tuple[str, str]]:
        g = e.find("Fill/LinearGradient")
        return [(s.get("colorValue"), s.get("position")) for s in g]
    want = stops(_named(doc, "Mist"))
    assert all(stops(_named(doc, ring).find("Shape")) == want for ring in rings)
    assert stops(back.find("Shape")) == want


# ====================================================================== beach: the night
def test_beach_night_sky_stars_and_shade(rml: dict[str, ET.Element]) -> None:
    doc = rml["beach"]
    plane0 = _named(doc, "Plane0")
    kids = [c.get("name") for c in plane0 if c.tag != "DataBindContext"]
    # in front of the sky plane's haze veil, clouds and sun; the stars in front of the night sky
    assert kids.index("emitNightStars") < kids.index("SkyNight") < kids.index("FogVeil0") < kids.index("emitSun")
    for name in ("emitNightStars", "SkyNight", "NightTint"):
        el = _named(doc, name)
        assert float(el.get("opacity")) == 0.0
        assert [(n, c) for n, c in _binds(doc, el, 18)] == [("night", None)]
    tint = _named(doc, "NightTint")
    assert tint.get("blendModeValue") == "24"     # multiply, screen space, in front of every plane
    ab = next(a for a in doc.findall("Artboard") if a.get("name") == "Scene")
    tops = [c.get("name") for c in ab if c.tag in ("Node", "Shape")]
    assert tops.index("NightTint") < min(i for i, n in enumerate(tops) if str(n).startswith("Plane"))
    for name in ("emitSunGlow", "emitSunDisc"):   # the sun goes out by half night
        part = _named(doc, name)
        assert [_value(doc, part, 18, {"night": v}) for v in (0.0, 0.25, 0.5, 1.0)] == pytest.approx([1.0, 0.5, 0.0, 0.0])
    stars = [e for e in _named(doc, "emitNightStars") if e.tag == "Shape"]
    assert len(stars) == len(gen_scenes.NIGHT_STARS) and all(float(s.get("y")) < 900 for s in stars)


def test_beach_night_is_formula_only(rml: dict[str, ET.Element]) -> None:
    """History-free: nothing keys or transitions on `night` (only DataBindContexts read it)."""
    doc = rml["beach"]
    vm = _vm(doc)
    night = next(p.get("id") for p in vm if p.get("name") == "night")
    readers = [e for e in doc.iter() if str(e.get("sourcePathIds", "")).endswith("-" + night)]
    assert readers and all(e.tag == "DataBindContext" and e.get("propertyKey") == "18" for e in readers)


# ====================================================================== rooftop: the day lifts the roof
def test_rooftop_day_lift(rml: dict[str, ET.Element]) -> None:
    doc = rml["rooftop"]
    lift = _named(doc, "RoofDay")
    assert lift.get("blendModeValue") == "14" and float(lift.get("opacity")) == 0.0
    assert _binds(doc, lift, 18) == [("daylight", None)]
    plane4 = _named(doc, "Plane4")
    kids = [c.get("name") for c in plane4 if c.tag != "DataBindContext"]
    at = kids.index("RoofDay")
    assert kids[at + 1] == "ParapetCapLight" and kids[at - 1] == "ParapetRain"
    for prop in ("Telescope", "PigeonNpc", "Antenna"):
        assert kids.index(prop) < at                       # the props stay in front, unlifted
    rect = lift.find("Rectangle")
    top = float(lift.get("y")) - float(rect.get("height")) / 2
    assert top == pytest.approx(scene_rooftop.CAP_TOP - 4)   # never over the skyline


# ====================================================================== the render gates' helpers
def test_runs_counts_the_widest_true_run() -> None:
    assert review_m10_notes.runs(np.array([0, 1, 1, 0, 1, 1, 1, 0], bool)) == 3
    assert review_m10_notes.runs(np.zeros(5, bool)) == 0


def test_band_cover_reads_yellow_and_the_ring() -> None:
    a = np.zeros((1920, 1080, 3), np.int16)
    y0, y1 = review_m10_notes.BAND_ROWS[2]
    a[y0 + 4, 200:260] = (255, 255, 0)      # a painted band
    a[y0 + 6, 300:310] = (230, 220, 200)    # the ring over it
    cover, ring = review_m10_notes.band_cover(a)
    assert cover[2, 200:260].all() and not cover[2, 260:].any() and not cover[1].any()
    assert ring[2, 300:310].all() and not ring[2, :300].any()
