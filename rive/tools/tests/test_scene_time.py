"""Moonshot M7 Task 5: the time-of-day veils (contract v10 `daylight` / `dusk`), on the committed RML."""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import gen_scenes  # noqa: E402

SCENES_DIR = Path(__file__).resolve().parents[2] / "scenes"


def _root(scene: str) -> ET.Element:
    return ET.parse(SCENES_DIR / scene / f"{scene}.rml").getroot()


@pytest.mark.parametrize("scene", ["livingRoom", "campfire", "beach"])
def test_veils_bind_the_clock_in_the_sky_plane(scene: str) -> None:
    root = _root(scene)
    props = {e.get("id"): e.get("name") for e in root.iter() if e.tag.startswith("ViewModelProperty")}
    plane0 = next(e for e in root.iter("Node") if e.get("name") == "Plane0")
    veils = {c.get("name"): c for c in plane0 if c.get("name") in ("SkyDay", "SkyDusk")}
    assert set(veils) == {"SkyDay", "SkyDusk"}
    for name, prop in (("SkyDay", "daylight"), ("SkyDusk", "dusk")):
        v = veils[name]
        assert float(v.get("opacity")) == 0.0
        binds = [(props[b.get("sourcePathIds").split("-")[1]], b.get("propertyKey")) for b in v.findall("DataBindContext")]
        assert binds == [(prop, "18")]
        ids = [int(e.get("id").split(":")[1]) for e in v.iter() if e.get("id")]
        assert all(gen_scenes.M7_ID_START <= i < gen_scenes.M6_ID_START for i in ids)


def test_deep_space_ignores_the_clock() -> None:
    root = _root("deepSpace")
    props = {e.get("id"): e.get("name") for e in root.iter() if e.tag.startswith("ViewModelProperty")}
    used = {props.get(b.get("sourcePathIds", "-").split("-")[1]) for b in root.iter("DataBindContext")}
    assert not used & {"daylight", "dusk"}
