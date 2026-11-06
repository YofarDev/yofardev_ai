"""Moonshot M7 Task 7: the journey thresholds (contract v10; v15: the storybook threshold replaces the
door), checked on the generated RML."""

from __future__ import annotations

import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
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
    """The vignette only adds: every element of the book before it (Task 1) keeps its id and tag."""
    try:
        text = subprocess.run(["git", "show", f"{TASK1}:rive/journeys/journeys.rml"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip(f"git history with {TASK1} not available")
    new = {e.get("id"): e.tag for e in root.iter() if e.get("id")}
    moved = [(e.get("id"), e.tag, e.get("name")) for e in ET.fromstring(text).iter()
             if e.get("id") and new.get(e.get("id")) != e.tag]
    assert not moved, moved[:10]


def test_the_unfold_windows(root: ET.Element) -> None:
    """Every staged part moves only inside its clamp window of `unfold`, monotonically, from its hidden pose at the
    window's start to its rest pose at its end: the riffle pages fold over onto the cover's stub (projected,
    cos of the turn), the panels turn up from flat, tallest first."""
    grid = [i / 200 for i in range(201)]
    assert gen_journeys.UNFOLD_FLAPS == ((0.00, 0.18), (0.06, 0.27), (0.14, 0.38))
    assert gen_journeys.UNFOLD_PANELS == {"Far": (0.10, 0.55), "Mid": (0.22, 0.72), "Near": (0.38, 1.0)}
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


def test_nothing_of_the_vignette_shows_at_unfold_0(root: ET.Element) -> None:
    """At `unfold` 0 the vignette's gate, the riffle pages, the shaft, the motes and the floor are all at nothing
    (and the panels lie flat behind the block); every converter bound to `unfold` is one of the shared windows."""
    props = _props(root)
    book = _node(root, "Book")
    for name in ("BookVignette", "RiffleFlap0", "RiffleFlap1", "RiffleFlap2", "emitBookShaft", "emitBookMotes"):
        assert _eval(_converter(root, name, 18), 0) == 0, name
        assert float(_node(root, name).get("opacity")) == 0, name
    assert _eval(_converter(root, "VignetteFloor", 16), 0) == 0
    users = [e for e in book.iter() if any(p == "unfold" for p, _ in _binds(e, props))]
    assert {e.get("name") for e in users} == {
        "emitBookSpill", "BookVignette", "VignetteFloor", "PanelNear", "PanelMid", "PanelFar", "emitBookShaft",
        "emitBookMotes", "RiffleFlap0", "RiffleFlap1", "RiffleFlap2"}


def test_each_destination_erects_its_own_emblem_and_glyph(root: ET.Element) -> None:
    """Ten emblem groups in `PanelNear` and ten foil glyphs on the medallion, each shown only by its own `dest*`
    number (its root's opacity, starting at 0); each emblem has 2 to 5 shapes; nothing else reads a `dest*`."""
    props = _props(root)
    near, medal = _node(root, "PanelNear"), _node(root, "BookMedallion")
    for prop, scene in SCENE_OF.items():
        cap = scene[0].upper() + scene[1:]
        emblem, glyph = _node(root, f"Emblem{cap}"), _node(root, f"MedallionGlyph{cap}")
        assert emblem in list(near) and glyph in list(medal), scene
        for el in (emblem, glyph):
            assert _binds(el, props) == [(prop, 18)] and float(el.get("opacity")) == 0, el.get("name")
        assert 2 <= len(emblem.findall("Shape")) <= 5, scene
        assert len(glyph.findall("Shape")) >= 2, scene
    readers = {e.get("name") for e in root.iter() if any(p in DEST for p, _ in _binds(e, props))}
    caps = [s[0].upper() + s[1:] for s in art_bible.SCENES]
    assert readers == {f"{kind}{cap}" for cap in caps for kind in ("Emblem", "MedallionGlyph")}
    # the glyphs draw on top of the medallion's disc and rings
    kids = [e.get("name") for e in medal]
    assert max(kids.index(f"MedallionGlyph{cap}") for cap in caps) < kids.index("MedallionBevel")


def test_the_medallion_glyphs_fit_inside_its_inner_ring(root: ET.Element) -> None:
    """Each glyph (the emblem's foil copy) is scaled so its bounding box fits inside GLYPH_R, centred on the
    medallion, which sits at artboard (MEDALLION_X, MEDALLION_Y) with the cover closed."""
    assert gen_journeys.GLYPH_R < gen_journeys.MEDALLION_INNER_R
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


def test_the_vignette_keeps_off_the_avatar(root: ET.Element) -> None:
    """The journey draws over the avatar, so the vignette stays clear of it at every step of its rise: never over
    the face box, never below its floor at the gutter (VIG_FLOOR, above the hook zone where the `grab` / `hang` fist
    and the avatar's own jacket copy pass), the panels (and the emblems on them) never left of VIG_LEFT, the motes
    over their whole drift."""
    fx0, fx1, fy0, fy1 = gen_journeys.FACE_BOX
    hook_top = gen_journeys.HOOK_ZONE[2]
    assert gen_journeys.VIG_FLOOR < hook_top and gen_journeys.VIG_LEFT == fx1
    for k in range(9):   # the panels turning up, flat (k 0) to erect (k 8)
        turn = gen_journeys.PANEL_FLAT * (1 - k / 8)
        over = {f"Panel{n}": {"rotation": turn} for n in ("Far", "Mid", "Near")}
        over["VignetteFloor"] = {"scaleX": 1.0}
        for name, x, y, half in _drawn(root, "BookVignette", over):
            if name.startswith("emitBookMote"):
                continue
            assert x - half >= fx1 or y + half <= fy0 or y - half >= fy1, (name, k, x, y)
            # right of the gutter it is behind the page block (and, at the rest pose, the cover's stub)
            assert x - half >= gen_journeys.HOOK_ZONE[1] or y + half < hook_top, (name, k, x, y)
            if not name.startswith("emit"):
                assert x - half >= gen_journeys.VIG_LEFT - 0.5, (name, k, x, y)
    # each mote drifts MOTE_RISE px up from its MOTES position, right of the face box and above the hook zone
    for i, (mx, my, size) in enumerate(gen_journeys.MOTES):
        mote = _node(root, f"emitBookMote{i}")
        assert float(mote.get("x")) + gen_journeys.BLOCK_X0 == mx
        assert my - gen_journeys.MOTE_RISE <= float(mote.get("y")) + gen_journeys.VIG_FLOOR <= my
        assert mx - size / 2 >= fx1 and my + size / 2 < hook_top
    # the riffle stays right of the cover's resting stub edge (it folds onto the stub, never over the avatar)
    for i, (w, _, _) in enumerate(gen_journeys.FLAPS):
        for sx in (1.0, 0.5, 0.0, gen_journeys.COVER_REST):
            pts = _drawn(root, f"RiffleFlap{i}", {f"RiffleFlap{i}": {"scaleX": sx}})
            assert min(x - half for _, x, _, half in pts) >= gen_journeys.BLOCK_X0 + w * gen_journeys.COVER_REST - 1.5


def test_the_vignette_paints_behind_the_block_and_the_riffle_over_it(root: ET.Element) -> None:
    """The vignette is the book's back-most child (a panel lying flat is hidden behind the block); the riffle pages
    lie on the block's face, under the cover; inside the vignette, front to back: motes, floor, near, mid, far,
    the light (RML paints the first child in front)."""
    kids = [e.get("name") for e in _node(root, "Book")]
    assert kids.index("BookCover") < kids.index("BookRiffle") < kids.index("emitBookGlow")
    assert kids.index("BookBlock") < kids.index("BookVignette") == max(i for i, e in enumerate(_node(root, "Book"))
                                                                       if e.tag == "Node")
    order = [e.get("name") for e in _node(root, "BookVignette") if e.tag == "Node"]
    assert order == ["emitBookMotes", "VignetteFloor", "PanelNear", "PanelMid", "PanelFar", "emitBookShaft"]
    assert float(_node(root, "PanelFar").get("opacity")) == 0.55
    props = _props(root)
    lights = {(e.tag, p) for e in _node(root, "BookVignette").iter() for p, k in _binds(e, props) if k == 37}
    assert lights == {("SolidColor", "lightAmbient"), ("SolidColor", "lightKey")}


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
            assert gap == pytest.approx(0, abs=1e-4), (ids[ko.get("objectId")], kp.get("property"))   # RML: 4 decimals
    assert {"emitBookGlow", "emitBookShaftBreath", *(f"emitBookMote{i}" for i in range(7))} <= keyed
    assert len(gen_journeys.MOTES) == 7


needs_rive = pytest.mark.skipif(shutil.which("rive") is None, reason="rive CLI not on PATH")


@needs_rive
def test_the_vignette_draws_off_the_face_and_the_hook_zone() -> None:
    """Rendered: at `unfold` 1 the widest emblems change no pixel of the face box or the hook zone, and at `unfold`
    0 the open book draws exactly what it drew before the vignette."""
    import numpy as np
    from PIL import Image

    proj = ROOT / "rive" / "journeys"

    def shot(png: Path, **data: float) -> np.ndarray:
        subprocess.run(["rive", str(proj), f"--screenshot={png}", "--advance=2",
                        *[f"--data={k}={v}" for k, v in data.items()]], check=True, capture_output=True)
        return np.asarray(Image.open(png).convert("RGB")).astype(np.int16)

    with tempfile.TemporaryDirectory() as t:
        base = shot(Path(t) / "base.png", book=1, open=1, unfold=0)
        for dest in ("destDeepSpace", "destRooftop", "destLivingRoom", "destBeach"):
            full = shot(Path(t) / "full.png", book=1, open=1, unfold=1, **{dest: 1})
            diff = np.abs(full - base).max(axis=2)
            for x0, x1, y0, y1 in (gen_journeys.FACE_BOX, gen_journeys.HOOK_ZONE):
                assert diff[int(y0):int(y1), int(x0):int(x1)].max() == 0, dest
            assert diff[:, :640].any(), dest   # the vignette shows


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
