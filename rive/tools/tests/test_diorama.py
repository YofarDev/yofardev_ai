"""Tests for the shared diorama pass (moonshot M5 Task 3, rulings 2, 3 and 6)."""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from art_bible import lint_colours  # noqa: E402
import gen_scenes  # noqa: E402
from gen_scenes import DioramaSpec, Scene, diorama  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
# The M4 campfire with the v8 `rain` property (Task 1), before the shared pass: the baseline every
# M4 element must survive against.
M4_COMMIT = "5b10b23"
M4_RML = "rive/scenes/campfire/campfire.rml"
# propId -> the top-level art its hit zone covers
PROP_ART = {"fire": "emitFireFlare", "tent": "TentPlace", "owl": "Owl", "sky": "Sky"}


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.campfire()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


def _tree(text: str) -> dict[str, tuple[str, dict[str, str], str | None]]:
    """id -> (tag, attributes without id, parent id) for every element of an RML fragment."""
    out: dict[str, tuple[str, dict[str, str], str | None]] = {}

    def visit(e: ET.Element, parent: str | None) -> None:
        i = e.get("id")
        if i is not None:
            out[i] = (e.tag, {k: v for k, v in e.attrib.items() if k != "id"}, parent)
        for c in e:
            visit(c, i if i is not None else parent)
    visit(ET.fromstring(text), None)
    return out


def _plane_of(rml: str) -> dict[str, int]:
    """Top-level-in-plane element name -> plane index."""
    root = ET.fromstring(rml)
    ab = root.find("Artboard")
    out = {}
    for plane in ab:
        m = re.fullmatch(r"Plane(\d)", plane.get("name", ""))
        if m:
            for c in plane:
                if c.get("name"):
                    out[c.get("name")] = int(m.group(1))
    return out


def _m4() -> str:
    r = subprocess.run(["git", "show", f"{M4_COMMIT}:{M4_RML}"], cwd=ROOT, capture_output=True, text=True)
    if r.returncode:
        pytest.skip(f"git show {M4_COMMIT} unavailable: {r.stderr.strip()}")
    return r.stdout


def test_unknown_top_level_element_raises() -> None:
    sc = Scene("campfire")
    with pytest.raises(KeyError):
        diorama(sc, [sc.node("Mystery", 0, 0)], DioramaSpec(planes={}, emissive=(), veils=()))
    with pytest.raises(KeyError):
        diorama(sc, [sc.node("Hit_mystery", 0, 0)], DioramaSpec(planes={"Hit": 4}, emissive=(), veils=()))


def test_planes_must_be_contiguous_back_to_front() -> None:
    sc = Scene("campfire")
    content = [sc.node("Sky", 0, 0), sc.node("Ground", 0, 0)]  # sky in front of the ground
    with pytest.raises(ValueError):
        diorama(sc, content, DioramaSpec(planes={"Sky": 0, "Ground": 4}, emissive=(), veils=()))


def test_empty_planes_are_skipped() -> None:
    sc = Scene("campfire")
    content = [sc.node("Rain", 0, 0), sc.node("Ground", 0, 0), sc.node("Sky", 0, 0)]
    diorama(sc, content, DioramaSpec(planes={"Rain": None, "Ground": 4, "Sky": 0}, emissive=(), veils=()))
    assert [e.attrs["name"] for e in content] == ["Rain", "Plane4", "Plane0"]


def test_campfire_is_registered_and_planes_paint_back_to_front(rml: str) -> None:
    assert "campfire" in gen_scenes.DIORAMAS
    at = [rml.index(f'name="Plane{k}"') for k in range(5, -1, -1)]
    assert at == sorted(at)
    for overlay in ("RainLoop", "RainFx", "FlareWash"):
        assert rml.index(f'name="{overlay}"') < at[0]


def test_every_hit_zone_rides_the_plane_of_its_art(rml: str) -> None:
    plane = _plane_of(rml)
    for prop, art in PROP_ART.items():
        assert plane[f"Hit_{prop}"] == plane[art], prop
    assert {k for k in plane if k.startswith("Hit_")} == {f"Hit_{p}" for p in PROP_ART}
    # none left at the artboard root
    ab = ET.fromstring(rml).find("Artboard")
    assert not [c for c in ab if str(c.get("name", "")).startswith("Hit_")]


def test_campfire_differs_from_m4_only_by_hit_zones_and_rain(rml: str) -> None:
    old, new = _tree(_m4()), _tree(rml)
    missing = set(old) - set(new)
    assert not missing, sorted(missing)[:10]
    added = set(new) - set(old)
    assert all(gen_scenes.M5_ID_START <= int(i.split(":")[1]) < gen_scenes.M4_ID_START for i in added), \
        sorted(i for i in added if not gen_scenes.M5_ID_START <= int(i.split(":")[1]) < gen_scenes.M4_ID_START)[:10]
    moved = {}
    for i, (tag, attrs, parent) in old.items():
        ntag, nattrs, nparent = new[i]
        assert (ntag, nattrs) == (tag, attrs), (i, tag, attrs.get("name"))
        if nparent != parent:
            moved[attrs.get("name")] = new[nparent][1].get("name")
    # the only re-parented M4 elements: the hit zones (into their planes) and the fire (into the
    # rain damper)
    assert moved == {"Hit_fire": "Plane4", "Hit_tent": "Plane4", "Hit_owl": "Plane3", "Hit_sky": "Plane0",
                     "emitFire": "emitFireDamp"}
    names = {new[i][1].get("name") for i in added}
    for n in ("RainLoop", "GroundWet", "TentWet", "RainSteam", "emitFireDamp", "amb_RainLoop", "amb_RainSteam"):
        assert n in names, n


def _binds(rml: str, name: str) -> list[tuple[str, str, str | None]]:
    """(source property name, propertyKey, converter id) of the binds directly under `name`."""
    root = ET.fromstring(rml)
    props = {e.get("id"): e.get("name") for e in root.iter() if e.tag.startswith("ViewModelProperty")}
    el = next(e for e in root.iter() if e.get("name") == name and e.tag in ("Node", "Shape"))
    return [(props[b.get("sourcePathIds").split("-")[1]], b.get("propertyKey"), b.get("converterId"))
            for b in el if b.tag == "DataBindContext"]


def _formula(rml: str, conv: str) -> list[str]:
    root = ET.fromstring(rml)
    el = next(e for e in root.iter() if e.get("id") == conv)
    return [f"{t.tag}:{t.get('operationValue', t.get('operationType', ''))}" for t in el]


def test_rain_binds_are_history_free(rml: str) -> None:
    assert _binds(rml, "RainLoop") == [("rain", "18", None)]
    assert _binds(rml, "RainSteam") == [("rain", "18", None)]
    (src, key, wet), = _binds(rml, "GroundWet")
    assert (src, key) == ("rain", "18")
    assert _binds(rml, "TentWet") == [("rain", "18", wet)]  # one shared converter
    assert _formula(rml, wet) == ["FormulaTokenValue:0.35", "FormulaTokenOperation:2", "FormulaTokenInput:"]
    damp = _binds(rml, "emitFireDamp")
    assert [(s, k) for s, k, _ in damp] == [("rain", "16"), ("rain", "17")] and damp[0][2] == damp[1][2]
    assert _formula(rml, damp[0][2]) == ["FormulaTokenValue:1", "FormulaTokenOperation:0",
                                         "FormulaTokenValue:-0.15", "FormulaTokenOperation:2", "FormulaTokenInput:"]
    for anim, frames in (("amb_RainLoop", 120), ("amb_RainSteam", 180), ("amb_RainLoopSheet0", 18),
                         ("amb_RainLoopSheet1", 34)):
        assert re.search(rf'<LinearAnimation duration="{frames}" fps="60" loopValue="loop" name="{anim}"', rml), anim
    # each streak sheet moves exactly one tile per loop, so its wrap is seamless at any frame time
    root = ET.fromstring(rml)
    for k in (0, 1):
        anim = next(e for e in root.iter("LinearAnimation") if e.get("name") == f"amb_RainLoopSheet{k}")
        keys = [(int(f.get("frame")), float(f.get("value"))) for f in anim.iter("KeyFrameDouble")]
        assert keys == [(0, 0.0), (int(anim.get("duration")), 480.0)]
    # the shower event is still there on top
    assert 'name="ev_Rain"' in rml and 'name="RainFx"' in rml


def test_steam_loops_seamlessly(rml: str) -> None:
    root = ET.fromstring(rml)
    anim = next(e for e in root.iter("LinearAnimation") if e.get("name") == "amb_RainSteam")
    for obj in anim:
        for prop in obj:
            keys = list(prop)
            first, last = keys[0], keys[-1]
            assert first.get("frame") == "0" and last.get("frame") == "180"
            assert float(first.get("value")) == pytest.approx(float(last.get("value")), abs=1e-3)
            if prop.get("property") == "opacity":
                assert max(float(k.get("value")) for k in keys) <= gen_scenes.STEAM_PEAK + 1e-3
                # every restart (a hold key) happens while the plume is invisible
                for k in keys:
                    if k.get("interpolationType") == "hold":
                        assert float(k.get("value")) < 0.01


def test_lint_clean(rml: str) -> None:
    assert lint_colours(rml, "campfire") == []



def test_contract_check_lints_every_diorama(rml: str) -> None:
    """Review Focus 5: an unfitted colour added to a diorama fails check_contract.py (frive.sh)."""
    import check_contract  # noqa: PLC0415

    assert check_contract.diorama_lint({"campfire": rml}) == []
    bad = rml.replace('<Shape x="540" y="1500" name="Ground"',
                      '<Shape x="540" y="1500" name="Ground"><SolidColor colorValue="FFFF0000"/>', 1)
    assert bad != rml
    (msg,) = check_contract.diorama_lint({"campfire": bad})
    assert msg.startswith("campfire: colour-script lint")
