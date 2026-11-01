"""Moonshot M11 ruling 9 (contract v14 `spring`, `autumn`): the seasons in two old scenes, livingRoom (tulips
/ a pumpkin and leaves on the sill) and campfire (spring flowers, autumn leaves and rust grass in the
clearing). History-free opacity binds, static 0 (at 0 / 0 the scene is v13: the render identity is in
rive/review/m11/tiers/gates.txt), minted from the M11 range."""

from __future__ import annotations

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import world_kit  # noqa: E402

NODES = {"livingRoom": {"SpringSill": ("spring", 2), "AutumnSill": ("autumn", 2)},
         "campfire": {"SpringGround": ("spring", 4), "AutumnGround": ("autumn", 4), "AutumnFerns": ("autumn", 4)}}


@pytest.fixture(scope="module")
def built(tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {sid: ET.parse(gen_scenes.SCENE_BUILDERS[sid]()).getroot() for sid in NODES}
    finally:
        gen_scenes.OUT_ROOT = root


@pytest.mark.parametrize("sid", sorted(NODES))
def test_season_nodes_bind_their_number_and_sit_in_their_plane(built: dict, sid: str) -> None:
    root = built[sid]
    vm = root.find("ViewModel")
    ids = {p.get("name"): p.get("id") for p in vm}
    assert {"spring", "autumn"} <= world_kit.declared_v14_binds(sid)
    ab = root.find("Artboard")
    for name, (season, plane) in NODES[sid].items():
        (node,) = [e for e in ab.iter("Node") if e.get("name") == name]
        planes = [p for p in ab if p.get("name") == f"Plane{plane}"]
        assert planes and node in list(planes[0]), (name, plane)
        (b,) = node.findall("DataBindContext")
        assert b.get("sourcePathIds") == f"{vm.get('id')}-{ids[season]}" and b.get("propertyKey") == "18"
        assert b.get("converterId") is None                  # the number is the opacity: 0..1, history-free
        assert node.get("opacity") == "0" and len([c for c in node if c.tag in ("Node", "Shape")]) >= 3
        # every element of the dressing mints from the M11 range (no older id moves)
        for e in node.iter():
            if e.get("id"):
                assert gen_scenes.M11_ID_START <= int(e.get("id").split(":")[1]) < gen_scenes.M10_ID_START, e.tag


def test_living_room_dressing_stands_on_the_sill_in_front_of_the_ledge(built: dict) -> None:
    plane = next(p for p in built["livingRoom"].find("Artboard") if p.get("name") == "Plane2")
    names = [c.get("name", "") for c in plane]
    # in front of the ledge (first-declared paints in front), behind the walking cat and the curtains
    assert names.index("WalkingCat") < names.index("SpringSill") < names.index("AutumnSill") < names.index("Sill")
    assert gen_scenes.SILL_TOP == 708.0 and 360 < gen_scenes.TULIPS_AT < 720   # on the window's ledge


def test_campfire_dressing_lies_on_the_ground_and_rusts_every_tuft(built: dict) -> None:
    plane = next(p for p in built["campfire"].find("Artboard") if p.get("name") == "Plane4")
    names = [c.get("name", "") for c in plane]
    grass = [n for n in names if n.startswith("Grass")]
    assert names.index("AutumnFerns") == names.index(grass[0]) - 1      # in front of the tufts
    assert names.index("GroundWet") < names.index("AutumnGround") < names.index("SpringGround") < names.index("Ground")
    ferns = next(c for c in plane if c.get("name") == "AutumnFerns")
    assert sorted(c.get("name") for c in ferns if c.tag == "Shape") == sorted("Rust" + g for g in grass)
