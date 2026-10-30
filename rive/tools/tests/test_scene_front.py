"""Tests for the `SceneFront` artboard: the weather in front of the avatar (moonshot M6 ruling 8,
contract v9)."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
from gen_scenes import FRONT_GAIN, FRONT_SCENES, M6_ID_START, PARALLAX_TRAVEL  # noqa: E402


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        # v12: rooftop (its own module, scene_rooftop.py) carries a front too
        return {sid: ET.fromstring(Path(gen_scenes.SCENE_BUILDERS[sid]()).read_text())
                for sid in ("campfire", "beach", "livingRoom", "deepSpace", "rooftop")}
    finally:
        gen_scenes.OUT_ROOT = root


def _front(doc: ET.Element) -> ET.Element | None:
    boards = [a for a in doc.findall("Artboard") if a.get("name") == "SceneFront"]
    assert len(boards) <= 1
    return boards[0] if boards else None


def _vm_paths(doc: ET.Element) -> dict[str, str]:
    """`SceneVM` property name -> its `sourcePathIds`."""
    vm = next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")
    return {p.get("name"): f"{vm.get('id')}-{p.get('id')}" for p in vm if p.tag.startswith("ViewModelProperty")}


def _converter_k(doc: ET.Element, conv_id: str) -> float:
    """The `k` of a `k x input` formula converter."""
    conv = next(c for c in doc.iter("DataConverterFormula") if c.get("id") == conv_id)
    values = [float(t.get("operationValue")) for t in conv if t.tag == "FormulaTokenValue"]
    return values[-1]


def test_front_only_in_outdoor_scenes(rml: dict[str, ET.Element]) -> None:
    assert set(FRONT_SCENES) == {"campfire", "beach", "rooftop"}
    for sid, doc in rml.items():
        assert (_front(doc) is not None) == (sid in FRONT_SCENES), sid
        # the main artboard stays first, so `rive.yaml main: Scene` and every render keep working
        assert doc.find("Artboard").get("name") == "Scene"


@pytest.mark.parametrize("sid", FRONT_SCENES)
def test_front_artboard_shape(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    front = _front(doc)
    vm = next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")
    assert front.get("viewModelId") == vm.get("id")
    assert (front.get("width"), front.get("height")) == ("1080", "1920")
    sms = [s for s in front.iter("StateMachine")]
    assert [s.get("name") for s in sms] == ["Main"]
    assert front.get("defaultStateMachineId") == sms[0].get("id")
    assert not [e for e in front.iter() if e.tag.startswith("StateMachineListener") or e.tag == "Event"]
    # M6's range, plus M8's fog veil (contract v11, scene_npc.front_fog) and everything under it
    fog = {id(x) for f in front if f.get("name") == "FrontFog" for x in f.iter()}
    for e in front.iter():
        if e.get("id") is not None and id(e) not in fog:
            assert int(e.get("id").split(":")[1]) >= M6_ID_START, (e.tag, e.get("name"))
    assert all(gen_scenes.M8_ID_START <= int(x.get("id").split(":")[1]) < gen_scenes.M7_ID_START
               for f in front if f.get("name") == "FrontFog" for x in f.iter() if x.get("id"))


@pytest.mark.parametrize("sid", FRONT_SCENES)
def test_front_binds_rain_and_parallax(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    paths = _vm_paths(doc)
    front = _front(doc)
    tops = [e for e in front if e.tag in ("Node", "Shape")]
    assert [e.get("name") for e in tops] == ["FrontRain", "FrontFog", "FrontMist"]
    # M8 (contract v11): the fog veil follows `fog` (and shows only while the app draws the front)
    (fog,) = [b for b in tops.pop(1) if b.tag == "DataBindContext"]
    assert (fog.get("sourcePathIds"), fog.get("propertyKey")) == (paths["fog"], "18")
    for e in tops:
        # opacity (key 18) follows `rain`, so the layer draws nothing dry
        opacity = [b for b in e if b.tag == "DataBindContext" and b.get("propertyKey") == "18"]
        assert [b.get("sourcePathIds") for b in opacity] == [paths["rain"]], e.get("name")
        assert float(e.get("opacity")) == 0.0
    near = tops[0]
    travel = {b.get("propertyKey"): _converter_k(doc, b.get("converterId")) for b in near
              if b.tag == "DataBindContext" and b.get("propertyKey") in ("13", "14")}
    assert travel == pytest.approx({"13": FRONT_GAIN * PARALLAX_TRAVEL[0], "14": FRONT_GAIN * PARALLAX_TRAVEL[1]})
    mist_fog = [b for b in tops[1].iter("DataBindContext") if b.get("sourcePathIds") == paths["lightFog"]]
    assert len(mist_fog) == gen_scenes.FOG_FILLS
