"""Moonshot M8 Task 3: the jacket (ruling 5, contract v11 `AvatarVM.jacket`, `JourneyVM.jacket`), on the
generated avatar and journey RML; the render gates run when the `rive` CLI is on PATH."""

from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_journeys  # noqa: E402
import hand_rig  # noqa: E402
import jacket_art  # noqa: E402
from rml import render  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
AVATAR_RML = ROOT / "rive" / "avatar" / "avatar.rml"
BASE = "927a606"


@pytest.fixture(scope="module")
def avatar() -> ET.Element:
    return ET.parse(AVATAR_RML).getroot()


@pytest.fixture(scope="module")
def journey() -> ET.Element:
    body = "\n".join(render(r, 1) for r in gen_journeys.build())
    return ET.fromstring(f"<Rive>{body}</Rive>")


def _named(root: ET.Element, name: str, tag: str = "Node") -> ET.Element:
    (el,) = [e for e in root.iter(tag) if e.get("name") == name]
    return el


def _vm_prop(root: ET.Element, vm: str, prop: str) -> tuple[str, str | None]:
    model = next(v for v in root.iter("ViewModel") if v.get("name") == vm)
    p = next(c for c in model if c.get("name") == prop)
    inst = next(c for c in model if c.tag == "ViewModelInstance")
    val = next(c for c in inst if c.get("viewModelPropertyId") == p.get("id"))
    return p.tag, val.get("propertyValue")


def _drawing(el: ET.Element) -> list[tuple]:
    """The drawing without ids: (tag, attributes) in tree order."""
    return [(e.tag, tuple(sorted((k, v) for k, v in e.attrib.items() if k not in ("id", "name") and "Id" not in k)),
             e.get("name") if e.tag == "Shape" else None) for e in el.iter()]


def test_names_and_defaults(avatar: ET.Element, journey: ET.Element) -> None:
    assert _vm_prop(avatar, "AvatarVM", "jacket") == ("ViewModelPropertyBoolean", "false")
    assert _vm_prop(journey, "JourneyVM", "jacket") == ("ViewModelPropertyNumber", "0")


def test_one_drawing_in_both_files(avatar: ET.Element, journey: ET.Element) -> None:
    held = _named(avatar, "Jacket")
    hung = _named(journey, "DoorJacket")
    assert _drawing(held) == _drawing(hung)
    assert 3 <= len([e for e in held.iter("Shape")]) <= 5


def test_the_jacket_never_crosses_the_threshold() -> None:
    x0, x1, y0, y1 = jacket_art.extent()
    assert jacket_art.HOOK[0] + x1 <= gen_journeys.THRESHOLD_X  # the app clips the avatar right of it
    # the jamb (journey, drawn over the avatar) never covers the avatar's copy: left of its outer edge + stroke
    jamb = gen_journeys.DOOR_X - gen_journeys.DOOR_HW - 2.5
    assert jacket_art.HOOK[0] + x1 + 1.5 <= jamb
    assert x1 <= jacket_art.RIGHT_LIMIT and y1 - y0 >= 150


def test_the_avatar_holds_it_upright_at_the_grip_point(avatar: ET.Element) -> None:
    parents = {c: p for p in avatar.iter() for c in p}
    hang = _named(avatar, "JacketHang")
    hand = parents[hang]
    assert hand.get("name") == "Hand"
    arm = hand
    while arm.get("name") not in ("ArmR", "ArmL"):
        arm = parents[arm]
    assert arm.get("name") == "ArmL"  # the viewer's-right hand
    assert (float(hang.get("x")), float(hang.get("y"))) == (0.0, hand_rig.GRIP_REACH)
    assert float(hang.get("opacity")) == 0.0
    ids = {e.get("id"): e for e in avatar.iter() if e.get("id")}
    cons = {c.tag: c for c in hang if c.tag.endswith("Constraint")}
    assert set(cons) == {"RotationConstraint", "ScaleConstraint"}
    for c in cons.values():
        assert (c.get("sourceSpaceValue"), c.get("destSpaceValue")) == ("world", "world")
        tgt = ids[c.get("targetId")]
        assert tgt.get("name") == "JacketUpright" and parents[tgt].tag == "Artboard"
        assert all(float(tgt.get(k, d)) == d for k, d in (("rotation", 0.0), ("scaleX", 1.0), ("scaleY", 1.0)))
    # behind the hand's drawing: the fist closes in front of the collar
    kids = list(hand)
    assert kids.index(next(k for k in kids if k.get("name") == "HandWave")) < kids.index(hang)


def test_the_jacket_layer(avatar: ET.Element) -> None:
    board = avatar.find("Artboard")
    names = [la.get("name") for la in board.iter("StateMachineLayer")]
    assert names.index("Gesture") < names.index("Jacket") < names.index("Prop")
    ids = {e.get("id"): e for e in avatar.iter() if e.get("id")}
    anims = {a.get("name"): a for a in board.findall("LinearAnimation")}

    def keyed(name: str) -> dict[str, dict[str, str]]:
        return {ids[o.get("objectId")].get("name"): {p.get("property"): p[0].get("value") for p in o}
                for o in anims[name].findall("KeyedObject")}

    none, held = keyed("jacket_none"), keyed("jacket_held")
    assert none == {"JacketHang": {"opacity": "0"}}
    assert held["JacketHang"] == {"opacity": "1"}
    grip = hand_rig.values("grip", 1)
    for dg in hand_rig.DIGITS:
        got = held.get(f"Drive{dg}L", {})
        assert float(got.get("rotation", 0)) == pytest.approx(grip[dg][0], abs=1e-4)
        assert float(got.get("scaleY", 1)) == pytest.approx(grip[dg][1], abs=1e-4)
    assert not any(k.endswith("R") and k.startswith("Drive") for k in held)
    layer = next(la for la in board.iter("StateMachineLayer") if la.get("name") == "Jacket")
    conds = [c for c in layer.iter("TransitionValueBooleanComparator")]
    assert sorted(c.get("value") for c in conds) == ["false", "true"]


def test_the_door_peg_and_its_jacket(journey: ET.Element) -> None:
    door = _named(journey, "Door")
    kids = list(door)
    peg, coat = _named(journey, "DoorPeg"), _named(journey, "DoorJacketHang")
    assert kids.index(peg) < kids.index(coat)  # the peg in front of the collar loop
    hook = (jacket_art.HOOK[0] - gen_journeys.DOOR_X, jacket_art.HOOK[1] - gen_journeys.GROUND_Y)
    for n in (peg, coat):
        assert (float(n.get("x")), float(n.get("y"))) == hook
    assert float(coat.get("opacity")) == 0.0
    props = {e.get("id"): e.get("name") for e in journey.iter() if e.tag.startswith("ViewModelProperty")}
    binds = [(props[b.get("sourcePathIds").split("-")[1]], b.get("propertyKey")) for b in coat.findall("DataBindContext")]
    assert binds == [("jacket", "18")]
    assert all(int(e.get("id").split(":")[1]) >= gen_journeys.M8_ID_START for e in [peg, coat, *peg.iter(), *coat.iter()]
               if e.get("id"))


# ------------------------------------------------------------------ renders (need the rive CLI)

needs_rive = pytest.mark.skipif(shutil.which("rive") is None, reason="rive CLI not on PATH")


def _base(tmp: Path, rel: str, yaml: Path) -> Path:
    try:
        text = subprocess.run(["git", "show", f"{BASE}:{rel}"], cwd=ROOT, capture_output=True, text=True,
                              check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {BASE} not available")
    tmp.mkdir(parents=True, exist_ok=True)
    (tmp / Path(rel).name).write_text(text)
    shutil.copy(yaml, tmp / "rive.yaml")
    return tmp


def _shot(proj: Path, png: Path, *args: str) -> np.ndarray:
    subprocess.run(["rive", str(proj), f"--screenshot={png}", *args], check=True, capture_output=True)
    return np.asarray(Image.open(png).convert("RGB")).astype(np.int16)


@needs_rive
def test_the_door_at_jacket_0_draws_as_in_m7_but_its_peg() -> None:
    """jacket 0: the door draws exactly as M7's except inside the peg's box (the peg is new door art)."""
    proj = ROOT / "rive" / "journeys"
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        ref = _base(tmp / "ref", "rive/journeys/journeys.rml", proj / "rive.yaml")
        hx, hy = jacket_art.HOOK
        for args in (["--data=door=1"], ["--data=door=1", "--data=open=1"], ["--data=door=1", "--data=open=0.5"]):
            a = _shot(ref, tmp / "a.png", *args, "--advance=2")
            b = _shot(proj, tmp / "b.png", *args, "--advance=2")
            diff = np.abs(a - b).max(axis=2) > 0
            diff[int(hy) - 12:int(hy) + 12, int(hx) - 24:int(hx) + 8] = False
            assert not diff.any(), args
        for fam in ("path", "portal", "rocket"):
            a = _shot(ref, tmp / "a.png", f"--data={fam}=1", "--advance=2")
            b = _shot(proj, tmp / "b.png", f"--data={fam}=1", "--advance=2")
            assert not (np.abs(a - b) > 0).any(), fam
