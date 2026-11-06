"""Moonshot M7 Task 7: the journey thresholds (contract v10; v15: the storybook threshold replaces the
door), checked on the generated RML."""

from __future__ import annotations

import math
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import art_bible  # noqa: E402
import gen_journeys  # noqa: E402
import jacket_art  # noqa: E402
from rml import render  # noqa: E402

FAMILY_ROOT = {"book": "Book", "path": "Path", "portal": "Portal", "rocket": "Rocket"}
DEST = ("destLivingRoom", "destCampfire", "destBeach", "destDeepSpace", "destCafe", "destRooftop", "destMountainHut",
        "destForestCabin", "destTrainCompartment", "destLibrary")
ROOT = Path(__file__).resolve().parents[3]
V11 = "42114e9"   # the last commit with the v10 door (and the v11 jacket on its peg)


@pytest.fixture(scope="module")
def root() -> ET.Element:
    body = "\n".join(render(r, 1) for r in gen_journeys.build())
    return ET.fromstring(f"<Rive>{body}</Rive>")


def _props(root: ET.Element) -> dict[str, str]:
    return {e.get("id"): e.get("name") for e in root.iter() if e.tag.startswith("ViewModelProperty")}


def _bound(el: ET.Element, props: dict[str, str]) -> set[tuple[str, int]]:
    """(property name, property key) of the binds directly under `el`."""
    out = set()
    for b in el.findall("DataBindContext"):
        prop_id = b.get("sourcePathIds").split("-")[1]
        out.add((props[prop_id], int(b.get("propertyKey"))))
    return out


def test_names_and_view_model(root: ET.Element) -> None:
    (ab,) = root.findall("Artboard")
    assert ab.get("name") == "Journey"
    assert (float(ab.get("width")), float(ab.get("height"))) == (800.0, 1000.0)
    sms = {s.get("id"): s.get("name") for s in ab.iter("StateMachine")}
    assert sms[ab.get("defaultStateMachineId")] == "Main"
    (vm,) = root.findall("ViewModel")
    assert vm.get("name") == "JourneyVM" and ab.get("viewModelId") == vm.get("id")
    props = {e.get("name"): e.tag for e in vm if e.tag.startswith("ViewModelProperty")}
    assert props == {**{n: "ViewModelPropertyNumber" for n in ("book", "path", "portal", "rocket", "open", "lift",
                                                               "jacket", "unfold", *DEST)},  # v11 jacket, v15 book
                     "lightKey": "ViewModelPropertyColor", "lightAmbient": "ViewModelPropertyColor"}
    assert gen_journeys.DEST_PROPS == DEST  # one per scene, in `AvatarScene` order
    # draws outside its bounds: the thresholds run past the frame's right edge (landscape windows)
    assert ab.get("clip") == "false"


def test_no_listeners_no_events(root: ET.Element) -> None:
    tags = {e.tag for e in root.iter()}
    assert "Event" not in tags
    assert not any(t.startswith("StateMachineListener") for t in tags)


def test_each_family_root_is_bound_to_its_number(root: ET.Element) -> None:
    props = _props(root)
    nodes = {e.get("name"): e for e in root.iter("Node")}
    for number, name in FAMILY_ROOT.items():
        el = nodes[name]
        assert (number, 18) in _bound(el, props), name
        assert float(el.get("opacity")) == 0.0, name
        # nothing of the family is bound to another family's number
        others = set(FAMILY_ROOT) - {number}
        for sub in el.iter():
            assert not {p for p, _ in _bound(sub, props)} & others, (name, sub.get("name"))


def test_open_and_lift_drive_only_their_parts(root: ET.Element) -> None:
    props = _props(root)
    lift_users = []
    for fam_name in FAMILY_ROOT.values():
        fam = next(e for e in root.iter("Node") if e.get("name") == fam_name)
        opens = [e.get("name") for e in fam.iter() if any(p == "open" for p, _ in _bound(e, props))]
        assert opens, f"{fam_name} has nothing that opens"
        lift_users += [fam_name for e in fam.iter() if any(p == "lift" for p, _ in _bound(e, props))]
    assert set(lift_users) == {"Rocket"}


def test_the_threshold_is_at_x_640(root: ET.Element) -> None:
    assert gen_journeys.THRESHOLD_X == 640.0
    nodes = {e.get("name"): e for e in root.iter("Node")}
    # each family's left edge sits within 20 px of the threshold (the book's gutter is on it)
    assert float(nodes["Book"].get("x")) == gen_journeys.BLOCK_X0 == 640.0
    assert abs(float(nodes["Rocket"].get("x")) - gen_journeys.ROCKET_HW - 640) <= 20
    assert abs(float(nodes["Portal"].get("x")) - gen_journeys.RING_W / 2 - 640) <= 20
    assert abs(float(nodes["Path"].get("x")) - 220 - 640) <= 20


def _num(e: ET.Element) -> int:
    return int(e.get("id").split(":")[1])


def _eval(conv: ET.Element, x: float) -> float:
    """A DataConverterFormula's value for input `x` (+ - * /, min / max, standard precedence)."""
    toks, pos = list(conv), 0

    def peek(*ops: str) -> bool:
        return pos < len(toks) and toks[pos].tag == "FormulaTokenOperation" and toks[pos].get("operationType") in ops

    def expr() -> float:
        nonlocal pos
        v = term()
        while peek("0", "1"):
            op = toks[pos].get("operationType")
            pos += 1
            v = v + term() if op == "0" else v - term()
        return v

    def term() -> float:
        nonlocal pos
        v = atom()
        while peek("2", "3"):
            op = toks[pos].get("operationType")
            pos += 1
            v = v * atom() if op == "2" else v / atom()
        return v

    def atom() -> float:
        nonlocal pos
        t = toks[pos]
        pos += 1
        if t.tag == "FormulaTokenValue":
            return float(t.get("operationValue"))
        if t.tag == "FormulaTokenInput":
            return x
        assert t.tag == "FormulaTokenFunction" and t.get("functionType") in ("0", "1"), t.tag
        args = [expr()]
        while toks[pos].tag == "FormulaTokenArgumentSeparator":
            pos += 1
            args.append(expr())
        assert toks[pos].tag == "FormulaTokenParenthesisClose"
        pos += 1
        return (min if t.get("functionType") == "0" else max)(args)

    v = expr()
    assert pos == len(toks)
    return v


def _converter(root: ET.Element, node: str, key: int) -> ET.Element:
    """The converter of `node`'s bind to property `key` (16 scaleX, 13 x, 15 rotation, 18 opacity)."""
    el = next(e for e in root.iter("Node") if e.get("name") == node)
    (b,) = [b for b in el.findall("DataBindContext") if b.get("propertyKey") == str(key)]
    return next(c for c in root.findall("DataConverterFormula") if c.get("id") == b.get("converterId"))


def test_the_cover_swing(root: ET.Element) -> None:
    """Fix rounds 1-2: closed at open 0, edge-on at open 0.5, a stub of COVER_REST (-0.035: x 625-640, clear of
    the avatar's band and of its jacket at the hook) at open 1, monotonic and still moving until open 1; the edge
    light rides the free edge and peaks edge-on; the faces swap there."""
    grid = [i / 100 for i in range(101)]
    swing = [_eval(_converter(root, "BookCover", 16), x) for x in grid]
    assert swing[0] == 1 and swing[50] == pytest.approx(0, abs=1e-9) and swing[-1] == pytest.approx(-0.035)
    assert gen_journeys.EDGE_ON == 0.5 and swing[-1] == pytest.approx(gen_journeys.COVER_REST)
    assert all(b < a for a, b in zip(swing, swing[1:]))   # it never stops before open 1
    assert 620 <= gen_journeys.BLOCK_X0 + gen_journeys.COVER_LEN * swing[-1] <= 630
    edge = _converter(root, "emitCoverEdge", 13)
    assert all(_eval(edge, x) == pytest.approx(gen_journeys.COVER_LEN * s) for x, s in zip(grid, swing))
    glint = _converter(root, "emitCoverEdge", 18)
    assert [_eval(glint, x) for x in (0, 0.25, 0.5, 0.75, 1)] == pytest.approx([0, 0.5, 1, 0.5, 0])
    outer, inner = _converter(root, "CoverOuter", 18), _converter(root, "CoverInner", 18)
    assert (_eval(outer, 0.5), _eval(inner, 0.5)) == pytest.approx((0.5, 0.5))
    assert (_eval(outer, 0.45), _eval(inner, 0.45), _eval(outer, 0.55), _eval(inner, 0.55)) == pytest.approx((1, 0, 0, 1))


def test_the_crack_glow(root: ET.Element) -> None:
    """Fix round 1: the gutter light opens at open 0.02, inside the crack (Task 3: open 0 to 0.03), full from its
    end, and is gone before the cover rests."""
    glow = _converter(root, "emitBookGlowWindow", 18)
    assert [_eval(glow, x) for x in (0, 0.02, 0.025, 0.03, 0.5, 0.85, 0.95, 1)] == pytest.approx(
        [0, 0, 0.5, 1, 1, 1, 0, 0])


def test_the_ribbon_and_jacket_paint_over_the_cover(root: ET.Element) -> None:
    """Fix round 1: the ribbon and the jacket on it are in front of the cover (its stub rests under the hook),
    the edge light and the spill (RML paints the first child in front)."""
    kids = [e.get("name") for e in next(e for e in root.iter("Node") if e.get("name") == "Book")]
    assert kids.index("Ribbon") == 0
    assert kids.index("Ribbon") < kids.index("BookCover") < kids.index("emitBookGlow") < kids.index("BookBlock")


def test_the_medallion_shows_in_portrait_and_clear_of_the_closed_jacket() -> None:
    """Fix round 1: the medallion (artboard, cover closed) sits at x about 705, whole inside the portrait band
    (x < 800) and on the cover; the jacket on the closed ribbon (swung RIBBON_SWING right) never covers it."""
    mx, my, r = gen_journeys.MEDALLION_X, gen_journeys.MEDALLION_Y, gen_journeys.MEDALLION_R + 2   # + its outline
    assert abs(mx - 705) <= 5 and gen_journeys.BLOCK_X0 + 12 < mx - r and mx + r < 800 and my + r < 1000
    px, py = gen_journeys.BLOCK_X0 + gen_journeys.RIBBON_PIVOT[0], gen_journeys.GROUND_Y + gen_journeys.RIBBON_PIVOT[1]
    tx, ty = jacket_art.HOOK[0] - px, jacket_art.HOOK[1] - py   # the tail, knob to tip at open 1 (the hook)
    a = -gen_journeys.RIBBON_SWING   # closed (Rive turns clockwise for +, y down)
    tip = (px + tx * math.cos(a) - ty * math.sin(a), py + tx * math.sin(a) + ty * math.cos(a))
    x0, x1, y0, y1 = jacket_art.extent()
    assert tip[0] + x1 < mx - r or tip[1] + y1 < my - r   # the hanging jacket ends left of or above the disc


def test_v15_mints_only_from_its_range(root: ET.Element) -> None:
    """v15: the book's numbers and drawing take ids from V15_ID_START, except what it keeps: the v11 jacket
    (with its opacity bind and hang node) and the appear converter the v10 door shared with the rocket."""
    vm = root.find("ViewModel")
    v15 = {e.get("name"): e for e in vm if e.get("name") in ("book", "unfold", *DEST)}
    assert len(v15) == 12 and all(_num(e) >= gen_journeys.V15_ID_START for e in v15.values())
    book = next(e for e in root.iter("Node") if e.get("name") == "Book")
    hang = next(e for e in book.iter("Node") if e.get("name") == "RibbonJacketHang")
    kept = {e for e in hang.iter() if gen_journeys.M8_ID_START <= _num(e) < gen_journeys.V15_ID_START}
    assert {_num(e) for e in kept} == set(range(gen_journeys.V11_JACKET_ID, gen_journeys.V11_JACKET_ID + 62))
    assert all(_num(e) >= gen_journeys.V15_ID_START for e in book.iter() if e not in kept)
    shared = {b.get("converterId") for b in book.iter("DataBindContext") if b.get("converterId")}
    assert {c for c in shared if int(c.split(":")[1]) < gen_journeys.V15_ID_START} == {"0:151"}


def test_v15_keeps_every_earlier_id(root: ET.Element) -> None:
    """Every element of the v11 file outside the door (its subtree, its own converters and ambient track,
    the `door` number) keeps its id and tag."""
    try:
        text = subprocess.run(["git", "show", f"{V11}:rive/journeys/journeys.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {V11} not available")
    old = ET.fromstring(text)
    door = next(e for e in old.iter("Node") if e.get("name") == "Door")
    gone = {e.get("id") for e in door.iter()}
    used_elsewhere = {b.get("converterId") for b in old.iter("DataBindContext") if b.get("id") not in gone}
    door_convs = {b.get("converterId") for b in door.iter("DataBindContext")} - used_elsewhere
    for conv in old.findall("DataConverterFormula"):
        if conv.get("id") in door_convs:
            gone |= {e.get("id") for e in conv.iter()}
    for ko in old.iter("KeyedObject"):
        if ko.get("objectId") in gone:
            gone |= {e.get("id") for e in ko.iter()}
    number = next(e for e in old.iter("ViewModelPropertyNumber") if e.get("name") == "door")
    gone |= {number.get("id")} | {e.get("id") for e in old.iter("ViewModelInstanceNumber")
                                  if e.get("viewModelPropertyId") == number.get("id")}
    new = {e.get("id"): e.tag for e in root.iter() if e.get("id")}
    moved = [(e.get("id"), e.tag, e.get("name")) for e in old.iter()
             if e.get("id") and e.get("id") not in gone and new.get(e.get("id")) != e.tag]
    assert not moved, moved[:10]


def _strip_emissive(el: ET.Element) -> None:
    for child in list(el):
        if str(child.get("name", "")).startswith(art_bible.EMISSIVE_PREFIX):
            el.remove(child)
        else:
            _strip_emissive(child)


@pytest.mark.parametrize("scene", sorted(art_bible.SCENES))
def test_lints_clean_in_every_scene(root: ET.Element, scene: str) -> None:
    tree = ET.fromstring(ET.tostring(root))
    _strip_emissive(tree)
    text = ET.tostring(tree, encoding="unicode").replace("><", ">\n<")
    assert art_bible.lint_colours(text, scene) == []
