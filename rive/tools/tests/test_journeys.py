"""Moonshot M7 Task 7: the journey thresholds (contract v10; v15: the storybook threshold replaces the
door), checked on the generated RML."""

from __future__ import annotations

import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import art_bible  # noqa: E402
import gen_journeys  # noqa: E402
import jacket_art  # noqa: E402
from rml import render, write  # noqa: E402

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
                     **{n: "ViewModelPropertyColor" for n in ("lightKey", "lightAmbient", "vignetteKey",
                                                              "vignetteAmbient")}}
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
    """A DataConverterFormula's value for input `x` (+ - * /, min / max / cos / sin, standard precedence)."""
    toks, pos = list(conv), 0
    fns = {"0": min, "1": max, "9": lambda a: math.cos(a[0]), "10": lambda a: math.sin(a[0])}

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
        assert t.tag == "FormulaTokenFunction" and t.get("functionType") in fns, t.tag
        args = [expr()]
        while toks[pos].tag == "FormulaTokenArgumentSeparator":
            pos += 1
            args.append(expr())
        assert toks[pos].tag == "FormulaTokenParenthesisClose"
        pos += 1
        return fns[t.get("functionType")](args)

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
    v15 = {e.get("name"): e for e in vm if e.get("name") in ("book", "unfold", *DEST, *gen_journeys.VIGNETTE_LIGHTS)}
    assert len(v15) == 14 and all(_num(e) >= gen_journeys.V15_ID_START for e in v15.values())
    book = next(e for e in root.iter("Node") if e.get("name") == "Book")
    hang = next(e for e in book.iter("Node") if e.get("name") == "RibbonJacketHang")
    kept = {e for e in hang.iter() if gen_journeys.M8_ID_START <= _num(e) < gen_journeys.V15_ID_START}
    assert {_num(e) for e in kept} == set(range(gen_journeys.V11_JACKET_ID, gen_journeys.V11_JACKET_ID + 62))
    assert all(_num(e) >= gen_journeys.V15_ID_START for e in book.iter() if e not in kept)
    shared = {b.get("converterId") for b in book.iter("DataBindContext") if b.get("converterId")}
    assert {c for c in shared if int(c.split(":")[1]) < gen_journeys.V15_ID_START} == {"0:151"}


def _redrawn_ids(old: ET.Element, families: tuple[str, ...]) -> set[str]:
    """The ids of an older file's `families` (redrawn since: v15 the door, v16 the path, portal and rocket): their
    subtrees, the converters only they used and their ambient tracks."""
    redrawn = [e for e in old.iter("Node") if e.get("name") in families]
    gone = {e.get("id") for r in redrawn for e in r.iter()}
    used_elsewhere = {b.get("converterId") for b in old.iter("DataBindContext") if b.get("id") not in gone}
    own_convs = {b.get("converterId") for r in redrawn for b in r.iter("DataBindContext")} - used_elsewhere
    for conv in old.findall("DataConverterFormula"):
        if conv.get("id") in own_convs:
            gone |= {e.get("id") for e in conv.iter()}
    for ko in old.iter("KeyedObject"):
        if ko.get("objectId") in gone:
            gone |= {e.get("id") for e in ko.iter()}
    return gone


def test_v15_keeps_every_earlier_id(root: ET.Element) -> None:
    """Every element of the v11 file outside the door and the thresholds v16 redrew (their subtrees, their own
    converters and ambient tracks, the `door` number) keeps its id and tag."""
    try:
        text = subprocess.run(["git", "show", f"{V11}:rive/journeys/journeys.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {V11} not available")
    old = ET.fromstring(text)
    gone = _redrawn_ids(old, ("Door", "Path", "Portal", "Rocket"))
    number = next(e for e in old.iter("ViewModelPropertyNumber") if e.get("name") == "door")
    gone |= {number.get("id")} | {e.get("id") for e in old.iter("ViewModelInstanceNumber")
                                  if e.get("viewModelPropertyId") == number.get("id")}
    new = {e.get("id"): e.tag for e in root.iter() if e.get("id")}
    moved = [(e.get("id"), e.tag, e.get("name")) for e in old.iter()
             if e.get("id") and e.get("id") not in gone and new.get(e.get("id")) != e.tag]
    assert not moved, moved[:10]


# ------------------------------------------------------------------ the vignette (v15: riffle, pop-up, emblems, motes)

TASK1 = "76bdeb8"   # the book before its vignette
SCENE_OF = dict(zip(DEST, art_bible.SCENES))


def _node(root: ET.Element, name: str) -> ET.Element:
    (el,) = [e for e in root.iter() if e.get("name") == name]
    return el


def _binds(el: ET.Element, props: dict[str, str]) -> list[tuple[str, int]]:
    return [(props[b.get("sourcePathIds").split("-")[1]], int(b.get("propertyKey")))
            for b in el.findall("DataBindContext")]


def test_v15_keeps_the_books_ids(root: ET.Element) -> None:
    """The vignette only adds: every element of the book before it (Task 1) keeps its id and tag (and so does every
    element outside the thresholds v16 redrew)."""
    try:
        text = subprocess.run(["git", "show", f"{TASK1}:rive/journeys/journeys.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {TASK1} not available")
    old = ET.fromstring(text)
    gone = _redrawn_ids(old, ("Path", "Portal", "Rocket"))   # v16 redrew them
    new = {e.get("id"): e.tag for e in root.iter() if e.get("id")}
    moved = [(e.get("id"), e.tag, e.get("name")) for e in old.iter()
             if e.get("id") and e.get("id") not in gone and new.get(e.get("id")) != e.tag]
    assert not moved, moved[:10]


def test_the_unfold_windows(root: ET.Element) -> None:
    """Every staged part moves only inside its clamp window of `unfold`, monotonically, from its hidden pose at the
    window's start to its rest pose at its end: the riffle pages fold over onto the cover's stub (projected,
    cos of the turn), the panels turn up from flat, tallest first."""
    grid = [i / 200 for i in range(201)]
    assert gen_journeys.UNFOLD_FLAPS == ((0.00, 0.18), (0.06, 0.27), (0.14, 0.38))
    assert gen_journeys.UNFOLD_PANELS == {"Far": (0.10, 0.55), "Mid": (0.22, 0.72), "Near": (0.38, 0.89)}
    assert gen_journeys.UNFOLD_SHAFT == (0.3, 0.9)
    for i, (a, b) in enumerate(gen_journeys.UNFOLD_FLAPS):
        width = [_eval(_converter(root, f"RiffleFlap{i}", 16), x) for x in grid]
        assert all(w == pytest.approx(1) for x, w in zip(grid, width) if x <= a)
        assert all(w == pytest.approx(gen_journeys.COVER_REST, abs=2e-3) for x, w in zip(grid, width) if x >= b)
        assert all(q <= p + 1e-9 for p, q in zip(width, width[1:]))
        shown = [_eval(_converter(root, f"RiffleFlap{i}", 18), x) for x in grid]
        assert shown[0] == 0
        assert all(s == pytest.approx(1, abs=2e-3) for x, s in zip(grid, shown)
                   if x >= a + gen_journeys.FLAP_FADE * (b - a))
    for name, (a, b) in gen_journeys.UNFOLD_PANELS.items():
        turn = [_eval(_converter(root, f"Panel{name}", 15), x) for x in grid]
        assert all(t == pytest.approx(math.pi / 2, abs=2e-3) for x, t in zip(grid, turn) if x <= a), name
        assert all(t == pytest.approx(0, abs=2e-3) for x, t in zip(grid, turn) if x >= b), name
        assert all(q <= p + 1e-9 for p, q in zip(turn, turn[1:])), name
    # the riffle has landed before the near panel (the emblem) starts to rise: Task 6's riffle-before-panels gate
    near_start = gen_journeys.UNFOLD_PANELS["Near"][0]
    for i in range(3):
        landed = _eval(_converter(root, f"RiffleFlap{i}", 16), near_start)
        assert landed == pytest.approx(gen_journeys.COVER_REST, abs=2e-3)
    for name in ("emitBookShaft", "emitBookMotes"):
        assert [_eval(_converter(root, name, 18), x) for x in (0, 0.3, 0.6, 0.9, 1)] == pytest.approx(
            [0, 0, 0.5, 1, 1], abs=2e-3)
    assert [_eval(_converter(root, "VignetteFloor", 16), x) for x in (0, 0.04, 0.12, 0.2, 1)] == pytest.approx(
        [0, 0, 0.5, 1, 1], abs=2e-3)


HANDOVER = 0.895   # `unfold` when the grab beat takes over: the plan's open ramp(850, 750, easeOut) at 1400 ms


def test_nothing_snaps_at_the_grab(root: ET.Element) -> None:
    """The grab beat writes `unfold` 1 while the open beat's ramp is at HANDOVER, so every staged part has landed by
    UNFOLD_LANDED (below it): what it draws there is what it draws at 1 (the panels, the floor spill — opacity and
    width — and the rest). Only the shaft and the motes still fade in (their window ends at 0.9): from 0.992, unseen."""
    props = _props(root)
    landed = gen_journeys.UNFOLD_LANDED
    assert landed == gen_journeys.UNFOLD_PANELS["Near"][1] == 0.89 < HANDOVER
    convs = {c.get("id"): c for c in root.findall("DataConverterFormula")}
    for el in _node(root, "Book").iter():
        for b in el.findall("DataBindContext"):
            if props[b.get("sourcePathIds").split("-")[1]] != "unfold":
                continue
            conv = convs[b.get("converterId")]
            if el.get("name") in ("emitBookShaft", "emitBookMotes"):
                assert abs(_eval(conv, 1.0) - _eval(conv, HANDOVER)) < 0.01, el.get("name")
            else:
                assert _eval(conv, 1.0) == pytest.approx(_eval(conv, landed), abs=1e-6), (el.get("name"),
                                                                                          b.get("propertyKey"))
    spill = {int(b.get("propertyKey")): convs[b.get("converterId")] for b in _node(root, "emitBookSpill")
             .findall("DataBindContext")}
    assert [_eval(spill[18], x) for x in (0, landed / 2, landed, 1)] == pytest.approx(
        [0, gen_journeys.SPILL_PEAK / 2, gen_journeys.SPILL_PEAK, gen_journeys.SPILL_PEAK], abs=1e-3)
    assert [_eval(spill[16], x) for x in (0, landed / 2, landed, 1)] == pytest.approx([0.4, 0.7, 1, 1], abs=1e-3)


def test_the_touchdown(root: ET.Element) -> None:
    """Inside the last fifth of its window a panel takes the last few degrees of its turn, much slower than it rose,
    while its scale comes down onto 1: the only spring the eye gets, since the app's curve never overshoots into
    the file. Every converter is monotonic and the rest pose is exact (erect, scale 1)."""
    turn_limit, dip_limit = math.radians(4), 0.02
    assert gen_journeys.SETTLE_SHARE == 0.2 and gen_journeys.SETTLE_TURN <= turn_limit
    assert gen_journeys.SETTLE_DIP <= dip_limit
    for name, (a, b) in gen_journeys.UNFOLD_PANELS.items():
        s = gen_journeys.settle_from(a, b)
        assert b - s == pytest.approx(0.2 * (b - a))
        grid = [a + (b - a) * i / 100 for i in range(101)]
        node = f"Panel{name}"
        turn = [_eval(_converter(root, node, 15), x) for x in grid]
        assert all(q <= p + 1e-9 for p, q in zip(turn, turn[1:])), name
        assert _eval(_converter(root, node, 15), s) == pytest.approx(gen_journeys.SETTLE_TURN, abs=1e-3), name
        rise_rate = (turn[0] - gen_journeys.SETTLE_TURN) / (s - a)
        settle_rate = gen_journeys.SETTLE_TURN / (b - s)
        assert rise_rate > 4 * settle_rate, name   # a soft touchdown: the landing is much slower than the rise
        for key in (16, 17):
            dip = [_eval(_converter(root, node, key), x) for x in grid]
            assert all(q <= p + 1e-9 for p, q in zip(dip, dip[1:])), name
            assert _eval(_converter(root, node, key), s) == pytest.approx(1.02, abs=1e-3), name
            assert dip[-1] == pytest.approx(1, abs=1e-3), name


def test_the_hero_rises_off_the_page(root: ET.Element) -> None:
    """The hero stands up inside HERO_RISE: it shows early in the window, its height (a sine of the fold) goes from
    folded to full by the touchdown, and it touches down like the panels; every converter is monotonic, the rest
    pose exact. Its rise starts while the near panel is rising and after the riffle has landed."""
    a, b = gen_journeys.HERO_RISE
    s = gen_journeys.settle_from(a, b)
    grid = [i / 400 for i in range(401)]
    assert b < gen_journeys.UNFOLD_PANELS["Near"][1] and a > gen_journeys.UNFOLD_FLAPS[2][1]
    rise = [_eval(_converter(root, "HeroRise", 17), x) for x in grid]
    assert all(q >= p - 1e-9 for p, q in zip(rise, rise[1:]))
    assert all(h == pytest.approx(gen_journeys.HERO_FOLDED, abs=2e-3) for x, h in zip(grid, rise) if x <= a)
    assert all(h == pytest.approx(1, abs=2e-3) for x, h in zip(grid, rise) if x >= s)
    # the sine lands softly: most of the height is won in the first half of the rise
    assert _eval(_converter(root, "HeroRise", 17), (a + s) / 2) > 0.7
    turn = [_eval(_converter(root, "VignetteHero", 15), x) for x in grid]
    assert all(q <= p + 1e-9 for p, q in zip(turn, turn[1:]))
    assert all(t == pytest.approx(gen_journeys.SETTLE_TURN, abs=2e-3) for x, t in zip(grid, turn) if x <= s)
    assert all(t == pytest.approx(0, abs=2e-3) for x, t in zip(grid, turn) if x >= b)
    for key in (16, 17):
        dip = [_eval(_converter(root, "VignetteHero", key), x) for x in grid]
        assert all(q <= p + 1e-9 for p, q in zip(dip, dip[1:]))
        assert all(v == pytest.approx(1.02, abs=2e-3) for x, v in zip(grid, dip) if x <= s)
        assert all(v == pytest.approx(1, abs=2e-3) for x, v in zip(grid, dip) if x >= b)
    shown = a + gen_journeys.HERO_FADE * (b - a)
    assert [_eval(_converter(root, "VignetteHero", 18), x) for x in (0, a, shown, 1)] == pytest.approx(
        [0, 0, 1, 1], abs=2e-3)
    assert [_eval(_converter(root, "emitHeroGlow", 18), x) for x in (0, a, (a + b) / 2, b, 1)] == pytest.approx(
        [0, 0, 0.5, 1, 1], abs=2e-3)


def test_nothing_of_the_vignette_shows_at_unfold_0(root: ET.Element) -> None:
    """At `unfold` 0 the vignette's gate, the riffle pages, the shaft, the motes and the floor are all at nothing
    (and the panels lie flat behind the block); every converter bound to `unfold` is one of the shared windows."""
    props = _props(root)
    book = _node(root, "Book")
    for name in ("BookVignette", "VignetteHero", "emitHeroGlow", "RiffleFlap0", "RiffleFlap1", "RiffleFlap2",
                 "emitBookShaft", "emitBookMotes"):
        assert _eval(_converter(root, name, 18), 0) == 0, name
        assert float(_node(root, name).get("opacity")) == 0, name
    assert _eval(_converter(root, "VignetteFloor", 16), 0) == 0
    users = [e for e in book.iter() if any(p == "unfold" for p, _ in _binds(e, props))]
    assert {e.get("name") for e in users} == {
        "emitBookSpill", "BookVignette", "VignetteFloor", "PanelNear", "PanelMid", "PanelFar", "emitBookShaft",
        "emitBookMotes", "RiffleFlap0", "RiffleFlap1", "RiffleFlap2", "VignetteHero", "HeroRise", "emitHeroGlow"}


def test_each_destination_erects_its_own_emblem_and_glyph(root: ET.Element) -> None:
    """Ten emblem groups in `PanelNear`, ten foil glyphs on the medallion and ten hero flats, each shown only by its
    own `dest*` number (its root's opacity, starting at 0); each emblem has 2 to 5 shapes; each hero emblem is the
    same drawing, large; nothing else reads a `dest*`."""
    props = _props(root)
    near, medal, flat = _node(root, "PanelNear"), _node(root, "BookMedallion"), _node(root, "HeroFlatTurn")
    for prop, scene in SCENE_OF.items():
        cap = scene[0].upper() + scene[1:]
        emblem, glyph = _node(root, f"Emblem{cap}"), _node(root, f"MedallionGlyph{cap}")
        hero = _node(root, f"Hero{cap}")
        assert emblem in list(near) and glyph in list(medal) and hero in list(flat), scene
        for el in (emblem, glyph, hero):
            assert _binds(el, props) == [(prop, 18)] and float(el.get("opacity")) == 0, el.get("name")
        assert 2 <= len(emblem.findall("Shape")) <= 5, scene
        assert len(glyph.findall("Shape")) >= 2, scene
        big = _node(root, f"Hero{cap}Emblem")
        assert len(big.findall("Shape")) == len(emblem.findall("Shape")) and float(big.get("scaleX")) > 1, scene
        assert _node(root, f"Hero{cap}Back") in list(hero) and _node(root, f"Hero{cap}BackRim") in list(hero), scene
    readers = {e.get("name") for e in root.iter() if any(p in DEST for p, _ in _binds(e, props))}
    caps = [s[0].upper() + s[1:] for s in art_bible.SCENES]
    assert readers == {f"{kind}{cap}" for cap in caps for kind in ("Emblem", "MedallionGlyph", "Hero")}
    # the glyphs draw on top of the medallion's disc and rings
    kids = [e.get("name") for e in medal]
    assert max(kids.index(f"MedallionGlyph{cap}") for cap in caps) < kids.index("MedallionBevel")


def test_the_medallion_glyphs_fit_inside_its_inner_ring(root: ET.Element) -> None:
    """Each glyph (the emblem's foil copy) is scaled so its bounding box fits inside GLYPH_R, centred on the
    medallion, which sits at artboard (MEDALLION_X, MEDALLION_Y) with the cover closed."""
    assert gen_journeys.GLYPH_R < gen_journeys.MEDALLION_INNER_R
    # the medallion copies stay as the small closed-cover hint (the hero carries the full emblem now)
    chain = ("Book", "BookCover", "CoverOuter", "BookMedallion")
    at = tuple(sum(float(_node(root, n).get(k, 0)) for n in chain) for k in ("x", "y"))
    assert at == (gen_journeys.MEDALLION_X, gen_journeys.MEDALLION_Y)
    for scene in art_bible.SCENES:
        glyph = _node(root, f"MedallionGlyph{scene[0].upper()}{scene[1:]}")
        s = float(glyph.get("scaleX"))
        assert float(glyph.get("scaleY")) == s
        x0, y0, x1, y1 = gen_journeys.glyph_box(gen_journeys.EMBLEMS[scene](gen_journeys.Kit(scene, foil=True)))
        cx, cy = float(glyph.get("x")) + s * (x0 + x1) / 2, float(glyph.get("y")) + s * (y0 + y1) / 2
        assert (cx, cy) == pytest.approx((0, 0), abs=0.01), scene
        assert s * math.hypot(x1 - x0, y1 - y0) / 2 <= gen_journeys.GLYPH_R + 0.01, scene


def _matrix(el: ET.Element, over: dict[str, float] | None = None) -> tuple[float, ...]:
    """A node's local transform (a, b, c, d, tx, ty): translate, rotate (clockwise, y down), scale."""
    o = over or {}
    r = o.get("rotation", float(el.get("rotation", 0)))
    sx, sy = o.get("scaleX", float(el.get("scaleX", 1))), o.get("scaleY", float(el.get("scaleY", 1)))
    return (math.cos(r) * sx, math.sin(r) * sx, -math.sin(r) * sy, math.cos(r) * sy, float(el.get("x", 0)),
            float(el.get("y", 0)))


def _times(m: tuple[float, ...], n: tuple[float, ...]) -> tuple[float, ...]:
    a, b, c, d, tx, ty = m
    a2, b2, c2, d2, tx2, ty2 = n
    return (a * a2 + c * b2, b * a2 + d * b2, a * c2 + c * d2, b * c2 + d * d2, a * tx2 + c * ty2 + tx,
            b * tx2 + d * ty2 + ty)


def _apply(m: tuple[float, ...], x: float, y: float) -> tuple[float, float]:
    a, b, c, d, tx, ty = m
    return a * x + c * y + tx, b * x + d * y + ty


def _outline(path: ET.Element) -> list[tuple[float, float]]:
    """A conservative outline of a path in its shape's space: the vertices and their Bézier handles (the curve
    stays inside their hull), or a parametric path's own outline."""
    if path.tag == "PointsPath":
        pts = []
        for v in path:
            x, y = float(v.get("x")), float(v.get("y"))
            pts.append((x, y))
            for side in ("in", "out"):
                if v.get(f"{side}Distance"):
                    dist, rot = float(v.get(f"{side}Distance")), float(v.get(f"{side}Rotation"))
                    pts.append((x + dist * math.cos(rot), y + dist * math.sin(rot)))
        return pts
    w, h = float(path.get("width")) / 2, float(path.get("height")) / 2
    m = _matrix(path)
    if path.tag == "Ellipse":
        return [_apply(m, w * math.cos(t * math.tau / 72), h * math.sin(t * math.tau / 72)) for t in range(72)]
    return [_apply(m, sx * w, sy * h) for sx in (-1, 1) for sy in (-1, 1)]


def _drawn(root: ET.Element, top: str, over: dict[str, dict[str, float]]) -> list[tuple[str, float, float, float]]:
    """(shape name, artboard x, y, half stroke) of every outline point of every shape under `top` (`over` sets
    bound transform values by node name)."""
    parents = {c: p for p in root.iter() for c in p}
    out = []
    for shape in _node(root, top).iter("Shape"):
        chain, el = [], shape
        while el.tag != "Artboard":
            chain.append(el)
            el = parents[el]
        m = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        for node in reversed(chain):
            m = _times(m, _matrix(node, over.get(node.get("name"))))
        half = max((float(s.get("thickness")) / 2 for s in shape.findall("Stroke")), default=0.0)
        for path in shape:
            if path.tag in ("PointsPath", "Ellipse", "Rectangle"):
                out += [(shape.get("name"), *_apply(m, x, y), half) for x, y in _outline(path)]
    return out


POSE_GRID = (0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.86, 0.9, 1.0)
"""Sample unfolds through the staging, with each touchdown inside (Far 0.47-0.55, Mid 0.62-0.72, Near 0.79-0.89,
the hero's fold 0.45-0.77 and touchdown 0.77-0.85)."""


def _bound_at(root: ET.Element, node: str, keys: dict[int, str], u: float) -> dict[str, float]:
    """`node`'s bound transforms (property key -> attribute) at `unfold` u, through its converters."""
    return {attr: _eval(_converter(root, node, key), u) for key, attr in keys.items()}


def _panel_poses(root: ET.Element) -> list[dict[str, dict[str, float]]]:
    """The panels' and floor's bound transforms at each sample unfold, read through `_eval` — the converters
    themselves are the only model of the motion, so a converter change cannot outrun these tests."""
    panel = {15: "rotation", 16: "scaleX", 17: "scaleY"}
    return [{**{f"Panel{n}": _bound_at(root, f"Panel{n}", panel, u) for n in ("Far", "Mid", "Near")},
             "VignetteFloor": _bound_at(root, "VignetteFloor", {16: "scaleX"}, u)}
            for u in POSE_GRID]


def _flap_poses(root: ET.Element, i: int) -> list[dict[str, dict[str, float]]]:
    """The riffle page's projected width at each sample unfold."""
    return [{f"RiffleFlap{i}": _bound_at(root, f"RiffleFlap{i}", {16: "scaleX"}, u)} for u in (0.0, *POSE_GRID)]


def test_the_vignette_keeps_off_the_avatar(root: ET.Element) -> None:
    """The journey draws over the avatar, so the vignette stays clear of it at every step of its rise: never over
    the face box, never below its floor at the gutter (VIG_FLOOR, above the hook zone where the `grab` / `hang` fist
    and the avatar's own jacket copy pass), the panels (and the emblems on them) never left of VIG_LEFT, the motes
    over their whole drift."""
    fx0, fx1, fy0, fy1 = gen_journeys.FACE_BOX
    hook_top = gen_journeys.HOOK_ZONE[2]
    assert gen_journeys.VIG_FLOOR < hook_top and gen_journeys.VIG_LEFT == fx1
    for over in _panel_poses(root):
        for name, x, y, half in _drawn(root, "BookVignette", over):
            if name.startswith("emitBookMote"):
                continue
            assert x - half >= fx1 or y + half <= fy0 or y - half >= fy1, (name, over, x, y)
            # right of the gutter it is behind the page block (and, at the rest pose, the cover's stub)
            assert x - half >= gen_journeys.HOOK_ZONE[1] or y + half < hook_top, (name, over, x, y)
            # VIG_LEFT guards the face box's band; below it (the ground strip) the rise's 2 % inflation may lean 2 px
            if not name.startswith("emit") and y - half < fy1:
                assert x - half >= gen_journeys.VIG_LEFT - 0.5, (name, over, x, y)
    # each mote drifts MOTE_RISE px up from its MOTES position, right of the face box and above the hook zone
    for i, (mx, my, size) in enumerate(gen_journeys.MOTES):
        mote = _node(root, f"emitBookMote{i}")
        assert float(mote.get("x")) + gen_journeys.BLOCK_X0 == mx
        assert my - gen_journeys.MOTE_RISE <= float(mote.get("y")) + gen_journeys.VIG_FLOOR <= my
        assert mx - size / 2 >= fx1 and my + size / 2 < hook_top
    # the riffle stays right of the cover's resting stub edge (it folds onto the stub, never over the avatar) and
    # above the reach zone
    for i, (w, _, _) in enumerate(gen_journeys.FLAPS):
        for over in _flap_poses(root, i):
            pts = _drawn(root, f"RiffleFlap{i}", over)
            assert min(x - half for _, x, _, half in pts) >= gen_journeys.BLOCK_X0 + w * gen_journeys.COVER_REST - 1.5
            assert max(y + half for _, _, y, half in pts) <= gen_journeys.REACH_ZONE[2]


def _hero_poses(root: ET.Element) -> list[dict[str, dict[str, float]]]:
    """The hero's bound transforms at each sample unfold, read through `_eval` (see `_panel_poses`)."""
    return [{"HeroRise": _bound_at(root, "HeroRise", {17: "scaleY"}, u),
             "VignetteHero": _bound_at(root, "VignetteHero", {15: "rotation", 16: "scaleX", 17: "scaleY"}, u)}
            for u in POSE_GRID]


def test_the_hero_keeps_off_the_reach_zone(root: ET.Element) -> None:
    """Every step of its rise and touchdown: no hero art in the reach zone (the grab / hang arm and the hook), none
    over the avatar's face box, none below HERO_FLOOR (the block's face stays plain leather there). This holds for
    every destination's flat, and for the light pooling behind the card."""
    x0, x1, y0, _ = gen_journeys.REACH_ZONE
    clip = _node(root, "HeroClip").find("ClippingShape")
    assert clip.get("sourceId") == _node(root, "HeroSky").get("id")   # the flats' glows stop at the card's sky
    for over in _hero_poses(root):
        for name, x, y, half in _drawn(root, "VignetteHero", over):
            assert x - half >= x1 or y + half <= y0, (name, over, x, y)
            assert x - half >= gen_journeys.FACE_BOX[1], (name, over, x, y)
            if not (name.startswith("emitHero") and name.endswith("Glow")):   # clipped, see above
                assert y + half <= gen_journeys.HERO_FLOOR, (name, over, x, y)


def test_the_hero_occupies_the_upper_right_page(root: ET.Element) -> None:
    """At rest the card stands in x 645-795, y 205-560 (inside the portrait band), rising above the block's top edge,
    its foot falling away to the right; each emblem stands inside the card's width and is 100 pt or more tall or wide
    on a phone (the artboard's 800 px fill about 390 pt), or as large as the card lets it be."""
    rest = _hero_poses(root)[-1]   # unfold 1, read from the converters like every other pose
    card = _drawn(root, "HeroMat", rest)
    xs, ys = [x for _, x, _, _ in card], [y for _, _, y, _ in card]
    assert 645 <= min(xs) - 1.5 and max(xs) + 1.5 <= 795
    assert 207 <= min(ys) - 1.5 and max(ys) + 1.5 <= gen_journeys.HERO_FLOOR
    assert min(ys) < gen_journeys.GROUND_Y + gen_journeys.BLOCK_TOP   # it rises above the book's top edge
    hx0, hx1 = gen_journeys.HERO_AT[0] - gen_journeys.HERO_HW, gen_journeys.HERO_AT[0] + gen_journeys.HERO_HW
    px_per_pt = 800 / 390
    for scene in art_bible.SCENES:
        cap = scene[0].upper() + scene[1:]
        pts = [(x, y) for n, x, y, _ in _drawn(root, f"Hero{cap}Emblem", rest) if not n.endswith("Glow")]
        ex, ey = [p[0] for p in pts], [p[1] for p in pts]
        assert hx0 < min(ex) and max(ex) < hx1, scene
        assert max(max(ex) - min(ex), max(ey) - min(ey)) >= 100 * px_per_pt or max(ex) - min(ex) >= 115, scene


def test_the_hero_stands_on_sheared_planes(root: ET.Element) -> None:
    """Rive has no skew: each plane's two nested nodes multiply into exactly the shear y' = y + k x (verticals stay
    vertical, so the card reads turned, not tipped)."""
    def shear_of(name: str) -> tuple[float, ...]:
        return _times(_matrix(_node(root, name)), _matrix(_node(root, f"{name}Turn")))

    def close(m: tuple[float, ...], k: float) -> None:
        assert m[:4] == pytest.approx((1, k, 0, 1), abs=2e-3)   # (a, b, c, d): x' = a x + c y, y' = b x + d y

    close(shear_of("HeroPlane"), gen_journeys.HERO_SHEAR)
    close(_times(shear_of("HeroPlane"), shear_of("HeroFlat")), gen_journeys.HERO_FLAT_SHEAR)


def test_the_vignette_glows_in_the_other_scenes_light(root: ET.Element) -> None:
    """`vignetteKey` / `vignetteAmbient` default to the living room's, like `lightKey` / `lightAmbient`, so the file
    draws correctly unwritten. The vignette (panels, shaft, halo, motes, the hero), the medallion's foil and the
    light that comes out of the book (the gutter glow, the spill) take them; the book's own rim, shade and bevel stay
    on `lightKey` / `lightAmbient`. Outside the book (v16) only the far scene's light through the other thresholds
    takes the vignette's key: the portal's core, the path's far end, the rocket's porthole."""
    props = _props(root)
    vm = root.find("ViewModel")
    inst = vm.find("ViewModelInstance")
    living = art_bible.SCENES["livingRoom"]
    for name, default in (("vignetteKey", living.key), ("vignetteAmbient", living.ambient)):
        prop = next(c for c in vm if c.get("name") == name)
        value = next(c for c in inst if c.get("viewModelPropertyId") == prop.get("id"))
        assert value.tag == "ViewModelInstanceColor" and value.get("propertyValue") == default
    parents = {c: p for p in root.iter() for c in p}

    def owner(paint: ET.Element) -> str:
        while paint.tag not in ("Shape", "Node"):
            paint = parents[paint]
        return paint.get("name")

    colours: dict[str, set[str]] = {}
    for tag, key in (("SolidColor", 37), ("GradientStop", 38)):
        for paint in root.iter(tag):
            for prop, k in _binds(paint, props):
                assert k == key, (prop, k)
                colours.setdefault(owner(paint), set()).add(prop)
    for shape in ("BookRim", "BookShade", "CoverRim", "MedallionBevel", "RocketRim", "RocketShade", "PathClump0Rim",
                  "RocketKeyTint", "PathKeyTint", "BookPageKeyTint"):
        assert colours[shape] <= {"lightKey", "lightAmbient"}, shape
    for shape, prop in (("PanelFarRidge", "vignetteAmbient"), ("PanelFarRim", "vignetteKey"),
                        ("PanelMidRim", "vignetteKey"), ("PanelMidHills", "vignetteKey"),
                        ("PanelNearGround", "vignetteKey"), ("VignetteFloorSlab", "vignetteKey"),
                        ("emitBookShaftBeam", "vignetteKey"), ("emitBookHaloGlow", "vignetteKey"),
                        ("emitBookMote0", "vignetteKey"), ("emitBookGlowCore", "vignetteKey"),
                        ("emitBookSpill", "vignetteKey"), ("HeroMat", "vignetteKey"), ("HeroGround", "vignetteKey"),
                        ("emitHeroGlowPool", "vignetteKey"), ("HeroBeachBack", "vignetteAmbient"),
                        ("HeroBeachBackRim", "vignetteKey"), ("MedallionBeachTrunk", "vignetteKey")):
        assert colours[shape] == {prop}, shape
    assert colours["HeroSky"] == {"vignetteKey", "vignetteAmbient"}
    far = {"emitPortalCore", "emitPathFarLight", "emitPathTrail", "emitPathRay0", "emitPathRay1", "emitPathRay2",
           "emitRocketWindowGlass"}
    for shape in far:
        assert colours[shape] == {"vignetteKey"}, shape
    book = {e.get("name") for e in _node(root, "Book").iter()}
    assert all(name in book or name in far for name, used in colours.items() if used & set(gen_journeys.VIGNETTE_LIGHTS))


def test_paper_and_foil_keep_their_tones_under_the_light(root: ET.Element) -> None:
    """The light on paper and foil is a tint (a color-blend second fill over the shape's own, under its ink), so each
    keeps its lightness: a key-lit stamp stays a two-tone stamp, on any leather, in any scene. A holed shape's tint
    keeps its holes."""
    tinted = 0
    for shape in _node(root, "Book").iter("Shape"):
        kids = list(shape)
        tints = [c for c in kids if c.tag == "Fill" and c.get("name") == "Tint"]
        if not tints:
            continue
        tinted += 1
        (tint,) = tints
        own = kids[kids.index(tint) - 1]
        assert own.tag == "Fill" and own.get("name") == "Fill", shape.get("name")
        assert tint.get("blendModeValue") == str(gen_journeys.COLOR_BLEND)
        assert tint.get("fillRule") == own.get("fillRule"), shape.get("name")
        strokes = [i for i, c in enumerate(kids) if c.tag == "Stroke"]
        assert all(kids.index(tint) < i for i in strokes), shape.get("name")
    assert tinted > 60


def test_the_vignette_paints_behind_the_block_and_the_riffle_over_it(root: ET.Element) -> None:
    """The vignette is the book's back-most child (a panel lying flat is hidden behind the block); the riffle pages
    and the hero lie on the block's face, under the cover and the ribbon; inside the vignette, front to back: motes,
    floor, near, mid, far, the light (RML paints the first child in front). Every root of the vignette system (the
    vignette, the hero, each medallion glyph) reads only the vignette's lights, never the scene's."""
    kids = [e.get("name") for e in _node(root, "Book")]
    assert kids.index("Ribbon") < kids.index("BookCover") < kids.index("BookRiffle") < kids.index("VignetteHero")
    assert kids.index("VignetteHero") < kids.index("emitBookGlow") < kids.index("BookBlock")
    assert kids.index("BookBlock") < kids.index("BookVignette") == max(i for i, e in enumerate(_node(root, "Book"))
                                                                       if e.tag == "Node")
    order = [e.get("name") for e in _node(root, "BookVignette") if e.tag == "Node"]
    assert order == ["emitBookMotes", "VignetteFloor", "PanelNear", "PanelMid", "PanelFar", "emitBookShaft"]
    assert float(_node(root, "PanelFar").get("opacity")) == 0.55
    props = _props(root)
    vignette_lights = set(gen_journeys.VIGNETTE_LIGHTS)
    caps = [s[0].upper() + s[1:] for s in art_bible.SCENES]
    for name in ("BookVignette", "VignetteHero", *(f"MedallionGlyph{cap}" for cap in caps)):
        lights = {p for e in _node(root, name).iter() for p, k in _binds(e, props) if k in (37, 38)}
        assert lights and lights <= vignette_lights, (name, lights)
        if name in ("BookVignette", "VignetteHero"):
            assert lights == vignette_lights, name
    hero = [e.get("name") for e in _node(root, "HeroRise") if e.tag != "DataBindContext"]
    assert hero == ["HeroGround", "HeroClip", "HeroSky", "HeroMat"]


def test_the_ambient_loop_is_seamless(root: ET.Element) -> None:
    """Every ambient track ends where it starts (frame 0 == frame AMB_FRAMES; a full turn counts as no turn), and
    the book's breath and motes are on it."""
    (amb,) = [a for a in root.iter("LinearAnimation") if a.get("name") == "amb_journey"]
    assert int(amb.get("duration")) == gen_journeys.AMB_FRAMES
    ids = {e.get("id"): e.get("name") for e in root.iter() if e.get("id")}
    keyed = set()
    for ko in amb.findall("KeyedObject"):
        keyed.add(ids[ko.get("objectId")])
        for kp in ko.findall("KeyedProperty"):
            frames = [(int(k.get("frame")), float(k.get("value"))) for k in kp]
            assert frames[0][0] == 0 and frames[-1][0] == gen_journeys.AMB_FRAMES, (ids[ko.get("objectId")], frames)
            gap = frames[-1][1] - frames[0][1]
            if kp.get("property") == "rotation":
                gap = math.remainder(gap, math.tau)
            if kp.get("property") == "offset":       # a trim path's offset: whole laps (v16, the portal's comets)
                gap = math.remainder(gap, 1.0)
            assert gap == pytest.approx(0, abs=1e-4), (ids[ko.get("objectId")], kp.get("property"))   # RML: 4 decimals
    assert {"emitBookGlow", "emitBookShaftBreath", "emitHeroGlowBreath", "emitHeroCampfireFlame",
            "emitHeroLibraryFlame", "emitHeroDeepSpaceStar", *(f"emitBookMote{i}" for i in range(7))} <= keyed
    assert len(gen_journeys.MOTES) == 7


needs_rive = pytest.mark.skipif(shutil.which("rive") is None, reason="rive CLI not on PATH")


def _project(tmp: Path, hidden: tuple[str, ...] = ()) -> Path:
    """A scratch journeys project from a fresh `gen_journeys.build()`, so a stale RML on disk cannot flatter a run.
    `hidden` zero the opacity of named emit shapes (soft light that would haze a measured box)."""
    tmp.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "rive" / "journeys" / "rive.yaml", tmp / "rive.yaml")
    rml = tmp / "journeys.rml"
    write(str(rml), gen_journeys.build())   # exactly as `gen_journeys.main()` writes it (key decimation included)
    body = rml.read_text()
    for name in hidden:
        body, count = re.subn(rf'(<Shape [^>]*name="{name}"[^>]*?)opacity="[\d.]+"', r'\1opacity="0"', body)
        assert count == 1, name
    rml.write_text(body)
    return tmp


def _shot(proj: Path, png: Path, *args: str) -> np.ndarray:
    """The data writes come before the advance: after it, each is a step with a frame of its own, so two poses with
    different numbers of writes would land on different frames of the ambient loop."""
    subprocess.run(["rive", str(proj), f"--screenshot={png}", *args, "--advance=2"], check=True, capture_output=True)
    return np.asarray(Image.open(png).convert("RGB")).astype(np.int16)


def _data(**numbers: object) -> list[str]:
    return [f"--data={k}={v}" for k, v in numbers.items()]


@needs_rive
def test_the_vignette_draws_off_the_face_and_the_reach_zone() -> None:
    """Rendered, for all ten flats, through the rise (0.7 and 0.8 are Mid's touchdown): no change on the face box,
    the hook zone or the reach zone, none on the leather below HERO_FLOOR down to the floor spill, and the vignette
    and the hero show."""
    with tempfile.TemporaryDirectory() as t:
        proj = _project(Path(t) / "proj")
        base = _shot(proj, Path(t) / "base.png", *_data(book=1, open=1, unfold=0))
        for dest in DEST:
            for unfold in (0.47, 0.6, 0.7, 0.8, 0.85, 1):
                full = _shot(proj, Path(t) / "full.png", *_data(book=1, open=1, unfold=unfold, **{dest: 1}))
                diff = np.abs(full - base).max(axis=2)
                for x0, x1, y0, y1 in (gen_journeys.FACE_BOX, gen_journeys.HOOK_ZONE, gen_journeys.REACH_ZONE):
                    assert diff[int(y0):int(y1), int(x0):int(x1)].max() == 0, (dest, unfold)
                assert diff[int(gen_journeys.HERO_FLOOR):960, 640:800].max() == 0, (dest, unfold)
                assert diff[:, :640].any(), dest
            assert diff[300:500, 660:780].max() > 40, dest   # the hero shows on the page


@needs_rive
def test_the_card_stands_in_its_box() -> None:
    """Rendered, its soft light hidden: the card's real pixels stand in x 645-795, y 205-560, for flats with and
    without a glow (the sky clips the flats' glows, so all of them share the card's outline)."""
    with tempfile.TemporaryDirectory() as t:
        bare = _project(Path(t) / "bare",
                        hidden=("emitHeroGlowPool", "emitBookShaftBeam", "emitBookHaloGlow"))

        def shot(png: str, *args: str) -> np.ndarray:
            return _shot(bare, Path(t) / png, *args)

        base = shot("base.png", *_data(book=1, open=1, unfold=0))
        for dest in ("destBeach", "destCampfire", "destLivingRoom", "destCafe"):
            diff = np.abs(shot("full.png", *_data(book=1, open=1, unfold=1, **{dest: 1})) - base).max(axis=2)
            ys, xs = np.nonzero(diff[:980, 641:] > 8)   # right of the gutter, above the floor spill
            assert 645 <= xs.min() + 641 and xs.max() + 641 <= 795, (dest, xs.min() + 641, xs.max() + 641)
            assert 205 <= ys.min() and ys.max() <= gen_journeys.HERO_FLOOR, (dest, ys.min(), ys.max())


@needs_rive
def test_the_lights_render_unwritten_and_written() -> None:
    """Unwritten, `vignetteKey` / `vignetteAmbient` draw exactly the living room's light; written, they change the
    hero and not the book's own rim; `lightKey` changes the rim and not the hero; closed, the medallion is all they
    touch."""
    living = art_bible.SCENES["livingRoom"]
    pose = _data(book=1, open=1, unfold=1, destBeach=1)
    box = (300, 480, 665, 775)      # y0, y1, x0, x1: inside the card
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        proj = _project(tmp / "proj")
        plain = _shot(proj, tmp / "a.png", *pose)
        same = _shot(proj, tmp / "b.png", *pose, *_data(vignetteKey=living.key, vignetteAmbient=living.ambient))
        assert (plain == same).all()   # unwritten draws the instance's defaults, the living room's light
        lit = _shot(proj, tmp / "c.png", *pose, *_data(vignetteKey="FF60A0FF", vignetteAmbient="FF102040"))
        assert np.abs(lit - plain)[box[0]:box[1], box[2]:box[3]].max() > 40
        rim = _shot(proj, tmp / "d.png", *pose, *_data(lightKey="FF60A0FF", lightAmbient="FF102040"))
        assert np.abs(rim - plain)[box[0]:box[1], box[2]:box[3]].max() == 0
        assert np.abs(rim - plain).max() > 40   # the book's own rim and shade did change
        closed = _data(book=1, destBeach=1)
        shut = _shot(proj, tmp / "e.png", *closed)
        relit = _shot(proj, tmp / "f.png", *closed, *_data(vignetteKey="FF60A0FF", vignetteAmbient="FF102040"))
        delta = np.abs(relit - shut).max(axis=2)
        ys, xs = np.nonzero(delta)
        mx, my, r = gen_journeys.MEDALLION_X, gen_journeys.MEDALLION_Y, gen_journeys.MEDALLION_R
        assert len(xs) and ((xs - mx) ** 2 + (ys - my) ** 2 <= r * r).all()


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
