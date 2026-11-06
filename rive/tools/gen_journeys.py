"""Generates rive/journeys/journeys.rml (built to assets/rive/journeys/journey.riv): the scene-journey thresholds (contract v10,
`assets/rive/journeys/journey.riv`; moonshot M7 rulings 5-7, 11; v15: the storybook threshold).

One artboard `Journey`, 800 x 1000 (the avatar's), drawn by the app above the avatar with the
avatar's fit. Four thresholds stand on the right of the frame, their occluding edge at x 640 (the
app clips the avatar right of it while it walks through):

- **book** (v15, replaces the v10 door): a standing pop-up storybook; the cover swings open, pages
  riffle and the destination rises as a paper-cut vignette;
- **path**: a leafy bush with ferns in front; the ferns part onto a dark gap in the bush;
- **portal**: a glowing violet ring that grows from a point; its swirling core opens;
- **rocket**: a small round rocket; its hatch opens, and `lift` raises it out of frame on a flame.

Everything is history-free: `JourneyVM` numbers bind opacity, scale, rotation and position through
`c + k x` formula converters (and clamped `min` / `max` ones for the book's cover swing and fades
and the rocket's flame and smoke); one ambient loop turns the portal's swirl and flickers the
flame. No listeners, no events. Colours outside `emit*` nodes are fitted into every scene's colour
script, so the file lints clean wherever it is shown.

    uv run rive/tools/gen_journeys.py            # writes rive/journeys/
"""

from __future__ import annotations

from contextlib import contextmanager
import math
import os
import sys
from typing import Iterator

sys.path.insert(0, os.path.dirname(__file__))
from art_bible import SCENES, fit_colour  # noqa: E402
import jacket_art  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, ellipse, lin, rad, rect, smooth_path, track, write  # noqa: E402

W, H = 800, 1000
THRESHOLD_X = 640.0
GROUND_Y = 1000.0
AMB_FRAMES = 240          # 4 s ambient loop (swirl turn, flame flicker)
LIFT_TRAVEL = -1400.0     # the rocket's y offset at lift 1 (out of frame at the top)
INK = "FF2A1E24"          # art bible line colour
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "journeys")
FAMILIES = ("book", "path", "portal", "rocket")

# v15: the v10 `door` number is gone; its ids (0:10, 0:11) stay unused, so every other id keeps its value
d = Doc(client=0, start=12)


def fit(c: str) -> str:
    """A colour inside every scene's colour script (value range and saturation cap)."""
    out = c.upper()
    for _ in range(4):
        before = out
        for sid in SCENES:
            out = fit_colour(out, sid)
        if out == before:
            break
    return out


# ---------------------------------------------------------------- view model

PROPS: list[tuple[str, str, object]] = [
    ("path", "number", 0.0), ("portal", "number", 0.0), ("rocket", "number", 0.0),
    ("open", "number", 0.0), ("lift", "number", 0.0),
    ("lightKey", "color", SCENES["livingRoom"].key), ("lightAmbient", "color", SCENES["livingRoom"].ambient),
]
vm_props: dict[str, El] = {}
vm_vals: list[El] = []
for _name, _typ, _default in PROPS:
    if _typ == "color":
        _p = d("ViewModelPropertyColor", name=_name)
        vm_vals.append(d("ViewModelInstanceColor", propertyValue=_default, viewModelPropertyId=_p.ref()))
    else:
        _p = d("ViewModelPropertyNumber", name=_name)
        vm_vals.append(d("ViewModelInstanceNumber", propertyValue=float(_default), viewModelPropertyId=_p.ref()))
    vm_props[_name] = _p
inst = d("ViewModelInstance", *vm_vals, exports=True, name="Default")
vm = d("ViewModel", *vm_props.values(), inst, name="JourneyVM", defaultInstanceId=inst.ref())


# v11 (moonshot M8 ruling 5): new elements take their own id range, after the M7 file's last id (1159)
M8_ID_START = 5000
d8 = Doc(client=0, start=M8_ID_START)
vm_props["jacket"] = d8("ViewModelPropertyNumber", name="jacket")
vm.children.insert(vm.children.index(inst), vm_props["jacket"])
inst.add(d8("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=vm_props["jacket"].ref()))


# v15 (the storybook threshold): new elements take their own id range, after the M8 one (the v11 file's
# last id is 5076). The book's numbers follow `lift`: `book` (how much of it shows), `unfold` (the riffle
# and the pop-up vignette) and one `dest<Scene>` per scene (the vignette and medallion shown; the app
# keeps at most one nonzero), in the scenes' order (= `AvatarScene`).
V15_ID_START = 6000
d15 = Doc(client=0, start=V15_ID_START)
DEST_PROPS: tuple[str, ...] = tuple(f"dest{s[0].upper()}{s[1:]}" for s in SCENES)
_prop_at = vm.children.index(vm_props["lift"]) + 1
_val_at = 1 + next(i for i, v in enumerate(inst.children) if v.attrs["viewModelPropertyId"] == vm_props["lift"].ref())
for _i, _name in enumerate(("book", "unfold", *DEST_PROPS)):
    vm_props[_name] = d15("ViewModelPropertyNumber", name=_name)
    vm.children.insert(_prop_at + _i, vm_props[_name])
    inst.children.insert(_val_at + _i, d15("ViewModelInstanceNumber", propertyValue=0.0,
                                           viewModelPropertyId=vm_props[_name].ref()))
V15_DRAW_START = d15.next   # the book's drawing mints from here (build())


def vpath(name: str) -> str:
    return f"{vm.ref()}-{vm_props[name].ref()}"


converters: list[El] = []
_convs: dict[tuple[float, float], El] = {}
F = Formulas(d, vpath)


def conv(k: float, c: float = 0.0) -> El:
    """One shared `c + k x input` formula converter per (k, c)."""
    key = (round(k, 3), round(c, 3))
    if key not in _convs:
        head = [] if key[1] == 0 else [F.val(key[1]), F.op("+")]
        _convs[key] = d("DataConverterFormula", *head, F.val(key[0]), F.op("*"), *F.inp())
        converters.append(_convs[key])
    return _convs[key]


def conv_tokens(*tokens: El) -> El:
    c = d("DataConverterFormula", *tokens)
    converters.append(c)
    return c


def clamp01(*expr: El) -> list[El]:
    """`min(1, max(0, expr))` as formula tokens."""
    return F.fn("min", [F.val(1)], F.fn("max", [F.val(0)], list(expr)))


@contextmanager
def minting_in(doc: Doc) -> Iterator[None]:
    """Mint through the shared builders (`d`, `F`, the drawing helpers) in `doc`'s id range: the two
    counters swap in, then back out with `doc`'s advanced."""
    assert doc.client == d.client
    d.next, doc.next = doc.next, d.next
    try:
        yield
    finally:
        d.next, doc.next = doc.next, d.next


def bind(prop: str, key: int, converter: El | None = None) -> El:
    """`DataBindContext`: JourneyVM `prop` -> property `key` (13 x, 14 y, 15 rotation, 16 scaleX,
    17 scaleY, 18 opacity, 37 SolidColor colour)."""
    return d("DataBindContext", sourcePathIds=vpath(prop), propertyKey=key,
             converterId=converter.ref() if converter is not None else None)


# ---------------------------------------------------------------- drawing helpers


def S(name: str, pts: list, *paints: El | None, closed: bool = True, tension: float = 1.0,
      x: float = 0.0, y: float = 0.0, **kw: object) -> El:
    """A shape whose points are given in its parent's space; the shape sits at (x, y)."""
    loc = [((p[0] - x, p[1] - y) + tuple(p[2:])) for p in pts]
    return d("Shape", smooth_path(d, loc, closed=closed, tension=tension), *[p for p in paints if p is not None],
             x=float(x), y=float(y), name=name, **kw)


def E(name: str, cx: float, cy: float, w: float, h: float, *paints: El | None, **kw: object) -> El:
    return d("Shape", ellipse(d, w, h), *[p for p in paints if p is not None], x=float(cx), y=float(cy),
             name=name, **kw)


def R(name: str, cx: float, cy: float, w: float, h: float, r: float, *paints: El | None, **kw: object) -> El:
    return d("Shape", rect(d, w, h, r), *[p for p in paints if p is not None], x=float(cx), y=float(cy),
             name=name, **kw)


def N(name: str, *kids: El | None, x: float = 0.0, y: float = 0.0, **kw: object) -> El:
    return d("Node", *[k for k in kids if k is not None], x=float(x), y=float(y), name=name, **kw)


def fill(c: str, emit: bool = False) -> El:
    return d("Fill", d("SolidColor", colorValue=c if emit else fit(c)), name="Fill")


def vfill(y0: float, y1: float, stops: list[tuple[str, float]], emit: bool = False) -> El:
    return d("Fill", lin(d, 0, y0, 0, y1, [(c if emit else fit(c), p) for c, p in stops]), name="Fill")


def hfill(x0: float, x1: float, stops: list[tuple[str, float]], emit: bool = False) -> El:
    return d("Fill", lin(d, x0, 0, x1, 0, [(c if emit else fit(c), p) for c, p in stops]), name="Fill")


def rfill(r: float, stops: list[tuple[str, float]], emit: bool = False, cx: float = 0, cy: float = 0) -> El:
    return d("Fill", rad(d, cx, cy, r, [(c if emit else fit(c), p) for c, p in stops]), name="Fill")


def line(c: str, w: float, emit: bool = False) -> El:
    return d("Stroke", d("SolidColor", colorValue=c if emit else fit(c)), thickness=float(w), cap="round",
             join="round", name="Line")


def bound_line(prop: str, w: float, default: str) -> El:
    """A stroke whose colour is the scene's light (`lightKey` / `lightAmbient`)."""
    return d("Stroke", d("SolidColor", bind(prop, 37), colorValue=fit(default)), thickness=float(w), cap="round",
             join="round", name="Line")


def bound_fill(prop: str, default: str) -> El:
    return d("Fill", d("SolidColor", bind(prop, 37), colorValue=fit(default)), name="Fill")


def star4(name: str, cx: float, cy: float, r: float, c: str) -> El:
    tips = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    verts = []
    for x, y in tips:
        to_c = math.atan2(cy - y, cx - x)
        dist = math.hypot(cx - x, cy - y) * 0.62
        verts.append(d("CubicDetachedVertex", x=float(x - cx), y=float(y - cy), inRotation=float(to_c),
                       inDistance=float(dist), outRotation=float(to_c), outDistance=float(dist)))
    path = d("PointsPath", *verts, isClosed=True, isClockwise=True, name="Path")
    return d("Shape", path, fill(c, emit=True), x=float(cx), y=float(cy), name=name)


amb_tracks: list[El] = []

# ---------------------------------------------------------------- book (v15; anchor: the gutter at the ground)

BLOCK_X0 = THRESHOLD_X          # the gutter (artboard x): the spine hinge, on the clip line
BLOCK_W = 480.0                 # the right page block runs to artboard x 1120, past the frame edge
BLOCK_TOP, BLOCK_BOTTOM = -720.0, 40.0   # local y (the ground is 0): artboard y 280-1040
BLOCK_CORNER = 60.0             # the block's top corners
COVER_LEN = 430.0               # the front cover, hinge to free edge
COVER_TOP = BLOCK_TOP - 8.0     # the board stands proud of the pages
COVER_CORNER = 24.0             # the board's free-edge top corner
# The swing (fix round 1): the cover's scaleX around the hinge falls from 1 at open 0 (closed on the block, the
# free edge at artboard x 1070) to 0 at open EDGE_ON (edge-on, at the gutter; slope x span = 2) and on to
# COVER_REST at open 1 (standing open just past perpendicular: a stub of |COVER_REST| x COVER_LEN = 64.5 px
# left of the gutter, x 575-640, clear of the avatar's band). Two clamped segments, so the cover keeps moving
# to open 1: one clamp reaching COVER_REST would stop it dead at open 0.575, mid-ramp. The cover is drawn
# closed (pointing right, the outer face as read): past edge-on it shows its inner face, mirrored.
EDGE_ON = 0.5
COVER_REST = -0.15
FACE_FADE = 0.05                # the outer and inner faces cross over open EDGE_ON -/+ FACE_FADE
GLOW_WINDOW = (0.02, 0.95)      # the interior glow shows only between these opens (the crack and the passage)
GLOW_RISE = 0.01                # ... full from GLOW_WINDOW[0] + this (open 0.03, the end of the crack) ...
GLOW_FALL = 0.1                 # ... to GLOW_WINDOW[1] - this
# the medallion's centre in artboard space with the cover closed (inside the portrait band, x < 800, and below
# the jacket hanging from the closed ribbon, x 595-700, y 545-754), its radius and its inner ring's
MEDALLION_X, MEDALLION_Y = 705.0, 820.0
MEDALLION_R, MEDALLION_INNER_R = 48.0, 38.0
RIBBON_PIVOT = (8.0, -700.0)    # the ribbon's knob on the block's top edge: artboard (648, 300)
RIBBON_SWING = math.radians(18.0)   # the tail's turn from open (open 1, its tip on the hook) to closed
# ids kept from the files before v15 (see build() and ribbon())
V10_APPEAR_CONV_ID, V10_DOOR_END = 146, 155
V11_JACKET_ID = 5015


def page_block() -> list[El]:
    """The right page block, the static occluder (artboard x 640-1120, y 280 to below the ground, open or
    closed), front first: the key rim, the ambient shade, the page fore-edge stripes at the gutter, the
    leather slab."""
    c = f"c{BLOCK_CORNER:g}"
    slab = S("BookBlock", [(0, BLOCK_BOTTOM, "c"), (0, BLOCK_TOP, c), (BLOCK_W, BLOCK_TOP, c),
                           (BLOCK_W, BLOCK_BOTTOM, "c")],
             hfill(0, BLOCK_W, [("FF4E3024", 0), ("FF6A4330", 0.3), ("FF5E3C2C", 1)]), line(INK, 5))
    pages = [S(f"BookPageEdge{i}", [(x, BLOCK_TOP + 40), (x, 28)], line("FFE8DCC8", 2), closed=False)
             for i, x in enumerate((12.0, 21.0, 30.0))]
    r = BLOCK_CORNER - 3   # the rim runs 3 px inside the outline, round the gutter-side corner
    rim = S("BookRim", [(3, -520), (3, BLOCK_TOP + BLOCK_CORNER),
                        (BLOCK_CORNER - r * math.sqrt(0.5), BLOCK_TOP + BLOCK_CORNER - r * math.sqrt(0.5)),
                        (BLOCK_CORNER, BLOCK_TOP + 3), (260, BLOCK_TOP + 3)],
            bound_line("lightKey", 4, SCENES["livingRoom"].key), closed=False, opacity=0.6)
    shade = S("BookShade", [(400, BLOCK_BOTTOM, "c"), (400, -712), (440, -712), (470, -690), (476, -670, "c"),
                            (476, BLOCK_BOTTOM, "c")],
              bound_fill("lightAmbient", SCENES["livingRoom"].ambient), opacity=0.45)
    return [rim, shade, *pages, slab]


def book_glow() -> El:
    """`emitBookGlow`: a soft warm lens along the gutter (x 600-680), shown only inside GLOW_WINDOW of
    `open` (full from the end of the crack until GLOW_FALL before the window closes); the bind sits on
    `emitBookGlowWindow`, leaving `emitBookGlow` free for an ambient key."""
    a, b = GLOW_WINDOW
    up, down = 1 / GLOW_RISE, 1 / GLOW_FALL
    window = conv_tokens(*F.fn("max", [F.val(0)], F.fn("min", [F.val(1)], F.fn(
        "min", [F.val(-up * a), F.op("+"), F.val(up), F.op("*"), *F.inp()],
        [F.val(down * b), F.op("+"), F.val(-down), F.op("*"), *F.inp()]))))
    core = E("emitBookGlowCore", 0, 0, 720, 720,
             rfill(360, [("FFFFF4DC", 0), ("B0FFD49A", 0.4), ("00E89A4E", 1)], emit=True))
    lens = N("emitBookGlowWindow", core, bind("open", 18, window), x=0.0, y=(BLOCK_TOP + BLOCK_BOTTOM) / 2,
             scaleX=80 / 720, opacity=0.0)
    return N("emitBookGlow", lens, x=0.0, y=0.0)


def medallion(*glyphs: El) -> El:
    """`BookMedallion`, embossed on the cover's outer face at artboard (MEDALLION_X, MEDALLION_Y) when closed:
    a stamped leather disc with a double ink ring and a key-lit bevel; the destination emblem glyphs (one per
    `dest*` number, inside MEDALLION_INNER_R) draw on top of it."""
    r, ri = MEDALLION_R, MEDALLION_INNER_R
    rb = (r + ri) / 2   # the bevel runs between the two rings
    bevel = S("MedallionBevel", [(rb * math.cos(math.radians(a)), rb * math.sin(math.radians(a)))
                                 for a in (195, 215, 235, 255, 275)],
              bound_line("lightKey", 3, SCENES["livingRoom"].key), closed=False, opacity=0.55)
    ring = E("MedallionRing", 0, 0, 2 * ri, 2 * ri, line(INK, 2.5))
    disc = E("MedallionDisc", 0, 0, 2 * r, 2 * r, rfill(r, [("FF5A3424", 0), ("FF472A1C", 0.7), ("FF3A2218", 1)]),
             line(INK, 4))
    return N("BookMedallion", *glyphs, bevel, ring, disc, x=MEDALLION_X - BLOCK_X0, y=MEDALLION_Y - GROUND_Y)


def swing_tokens(scale: float) -> list[El]:
    """`scale` x the cover's scaleX as formula tokens on `open`: scale (1 - clamp01(open / EDGE_ON)
    + COVER_REST clamp01((open - EDGE_ON) / (1 - EDGE_ON)))."""
    a, b = 1 / EDGE_ON, 1 / (1 - EDGE_ON)
    return [F.val(scale), F.op("-"), F.val(scale), F.op("*"), *clamp01(F.val(a), F.op("*"), *F.inp()),
            F.op("+"), F.val(scale * COVER_REST), F.op("*"),
            *clamp01(F.val(b), F.op("*"), *F.inp(), F.op("+"), F.val(-b * EDGE_ON))]


def cover() -> El:
    """`BookCover`, hinged at the gutter (x 0), its scaleX the swing. `CoverOuter` (leather, the medallion in
    the spine-side band, left of the tooled frame) crossfades into `CoverInner` (paper, an ink margin frame)
    while it passes edge-on."""
    board = [(0, BLOCK_BOTTOM, "c"), (0, COVER_TOP, "c"), (COVER_LEN, COVER_TOP, f"c{COVER_CORNER:g}"),
             (COVER_LEN, BLOCK_BOTTOM, "c")]
    g = 0.5 / FACE_FADE
    tool_x0 = MEDALLION_X + MEDALLION_R - BLOCK_X0 + 15   # the frame's spine-side rail clears the medallion
    outer = N("CoverOuter",
              medallion(),
              S("CoverTooling", [(tool_x0, COVER_TOP + 40, "c14"), (COVER_LEN - 40, COVER_TOP + 40, "c14"),
                                 (COVER_LEN - 40, -44, "c14"), (tool_x0, -44, "c14")], line("FF4A2E22", 3)),
              S("CoverRim", [(26, COVER_TOP + 5), (220, COVER_TOP + 5), (COVER_LEN - 28, COVER_TOP + 6)],
                bound_line("lightKey", 4, SCENES["livingRoom"].key), closed=False, opacity=0.6),
              S("CoverGroove", [(9, COVER_TOP + 6), (9, 30)], line("FF3E2418", 3), closed=False),
              S("CoverLeather", board, hfill(0, COVER_LEN, [("FF5E3A2A", 0), ("FF7A4E36", 0.35), ("FF6A4330", 1)]),
                line(INK, 5)),
              bind("open", 18, conv_tokens(*clamp01(F.val(0.5 + g * EDGE_ON), F.op("+"), F.val(-g), F.op("*"),
                                                    *F.inp()))),
              x=0.0, y=0.0)
    inner = N("CoverInner",
              S("CoverInnerFrame", [(30, COVER_TOP + 30, "c10"), (COVER_LEN - 30, COVER_TOP + 30, "c10"),
                                    (COVER_LEN - 30, -30, "c10"), (30, -30, "c10")], line(INK, 3)),
              S("CoverPaper", board, hfill(0, COVER_LEN, [("FFE0D2BC", 0), ("FFF3EBDD", 0.22), ("FFEEE4D3", 1)]),
                line(INK, 5)),
              bind("open", 18, conv_tokens(*clamp01(F.val(0.5 - g * EDGE_ON), F.op("+"), F.val(g), F.op("*"),
                                                    *F.inp()))),
              x=0.0, y=0.0, opacity=0.0)
    swing = conv_tokens(*swing_tokens(1.0))
    return N("BookCover", outer, inner, bind("open", 16, swing), x=0.0, y=0.0)


def cover_edge() -> El:
    """`emitCoverEdge`: a 6 px light stroke riding the cover's free edge (x = COVER_LEN x the swing's scaleX),
    outside the scaled cover so it keeps its width edge-on, where it is brightest: its opacity is
    1 - |1 - 2 open| (EDGE_ON 0.5), from 0 at open 0 to 1 edge-on and back to 0 as the cover comes to rest."""
    free_x = conv_tokens(*swing_tokens(COVER_LEN))
    glint = conv_tokens(*F.fn("max", [F.val(0)], F.fn(
        "min", [F.val(1 / EDGE_ON), F.op("*"), *F.inp()],
        [F.val(1 / (1 - EDGE_ON)), F.op("+"), F.val(-1 / (1 - EDGE_ON)), F.op("*"), *F.inp()])))
    stroke = S("emitCoverEdgeLine", [(0, COVER_TOP + COVER_CORNER), (0, 24)], line("FFFFF4DC", 6, emit=True),
               closed=False)
    return N("emitCoverEdge", stroke, bind("open", 13, free_x), bind("open", 18, glint), x=COVER_LEN, y=0.0,
             opacity=0.0)


def ribbon() -> El:
    """The ribbon bookmark (v15, replaces the v11 peg): a knob on the block's top edge and a tail draped to
    the hook point (628, 560), the jacket hanging from its tip (the avatar's own drawing, jacket_art; opacity
    `jacket`). The tail turns with `open`: its tip exactly on the hook at open 1 (where the grab and hang
    contacts fire), swung RIBBON_SWING right over the closed cover at open 0 (it lifts with the opening
    cover and whips back as it falls shut). The jacket counter-turns, so it always hangs plumb and matches
    the avatar's held copy at the contact."""
    px, py = RIBBON_PIVOT
    tx, ty = jacket_art.HOOK[0] - BLOCK_X0 - px, jacket_art.HOOK[1] - GROUND_Y - py   # the tip, from the knob
    length = math.hypot(tx, ty)
    ux, uy = tx / length, ty / length   # along the tail
    nx, ny = uy, -ux                    # across it, to the viewer's right
    hw = 9.0

    def at(s: float, q: float, *corner: str) -> tuple:
        return (s * ux + q * nx, s * uy + q * ny, *corner)

    tail = S("RibbonTail", [at(-6, -hw, "c"), at(-6, hw, "c"), at(length * 0.5, hw + 2), at(length + 10, hw, "c"),
                            at(length - 5, 0, "c"), at(length + 10, -hw, "c"), at(length * 0.5, 2 - hw)],
             fill("FFA63A40"), line(INK, 2.5))
    knob = E("RibbonKnob", 0, 0, 24, 24, rfill(12, [("FFF2D08A", 0), ("FFB98A36", 1)]), line(INK, 2.5))
    # the v11 jacket keeps its ids (5015-5076); the v11 peg's (5002-5014) stay unused
    d8.next = V11_JACKET_ID
    coat = d8("Node", jacket_art.jacket(d8, "RibbonJacket"),
              d8("DataBindContext", sourcePathIds=vpath("jacket"), propertyKey=18),
              bind("open", 15, conv(-RIBBON_SWING, RIBBON_SWING)),
              x=tx, y=ty, rotation=RIBBON_SWING, opacity=0.0, name="RibbonJacketHang")
    return N("Ribbon", coat, knob, tail, bind("open", 15, conv(RIBBON_SWING, -RIBBON_SWING)), x=px, y=py,
             rotation=-RIBBON_SWING)


def book() -> El:
    """The standing pop-up storybook, its gutter on the threshold. Back to front: the page block, the
    interior glow, the cover (and its edge light), the floor spill, then the ribbon with the jacket, in front
    of everything (RML paints the first child in front), so the hook stays visible over the resting stub."""
    spill = E("emitBookSpill", 0, 20, 1040, 60, rfill(520, [("A0FFD49A", 0), ("00FFD49A", 1)], emit=True),
              bind("unfold", 18, conv(0.85)), bind("unfold", 16, conv(0.6, 0.4)), opacity=0.0, scaleX=0.4)
    return N("Book", ribbon(), spill, cover_edge(), cover(), book_glow(), *page_block(),
             bind("book", 18), bind("book", 16, conv(0.08, 0.92)), bind("book", 17, conv(0.08, 0.92)),
             x=BLOCK_X0, y=GROUND_Y, opacity=0.0)


# ---------------------------------------------------------------- path (anchor: bottom centre)

PATH_X = THRESHOLD_X + 220.0   # the bush's left edge sits on the threshold


def frond(name: str, base_x: float, length: float, lean: float, part: float, shade: str) -> El:
    """One fern frond growing up from its base, leaning `lean` rad, parting by `part` x open."""
    hw = length * 0.11
    pts = [(0, 0), (-hw * 0.6, -length * 0.25), (-hw, -length * 0.55), (-hw * 0.5, -length * 0.85), (0, -length),
           (hw * 0.5, -length * 0.85), (hw, -length * 0.55), (hw * 0.6, -length * 0.25)]
    leaflets = [S(f"{name}Leaflet{i}", [(0, -length * f), (s * hw * 1.9, -length * (f + 0.07)),
                                        (s * hw * 0.4, -length * (f + 0.05))],
                  fill(shade), closed=True)
                for i, (f, s) in enumerate([(0.2, -1), (0.3, 1), (0.42, -1), (0.52, 1), (0.64, -1), (0.74, 1)])]
    rib = S(f"{name}Rib", [(0, -6), (0, -length * 0.95)], line("FF2C4A34", 2.2), closed=False)
    blade = S(f"{name}Blade", pts, vfill(-length, 0, [("FF5E8E5E", 0), ("FF345E40", 1)]), line(INK, 3))
    return N(name, rib, *leaflets, blade, bind("open", 15, conv(part, lean)), x=base_x, y=0.0, rotation=lean)


def path() -> El:
    # the left fronds part only a little: they must not sweep over the avatar standing left of them
    fronds = [frond("FernA", -150, 520, -0.08, -0.14, "FF3E6A48"),
              frond("FernB", -90, 640, -0.03, -0.12, "FF467454"),
              frond("FernC", -40, 600, 0.04, 0.3, "FF3E6A48"),
              frond("FernD", 50, 680, 0.14, 0.42, "FF467454"),
              frond("FernE", 140, 520, 0.3, 0.5, "FF3E6A48"),
              frond("FernF", 220, 460, 0.42, 0.5, "FF467454")]
    gap = S("PathGap", [(-150, 20, "c"), (-136, -560), (-20, -700), (110, -560), (126, 20, "c")],
            vfill(-700, 20, [("FF141C1C", 0), ("FF1E2A26", 1)]), bind("open", 18), opacity=0.0)
    bush_pts = [(-228, 30, "c"), (-236, -260), (-206, -470), (-226, -640), (-150, -820), (-40, -900), (80, -880),
                (190, -780), (230, -600), (250, -360), (244, 30, "c")]
    bush = S("PathBush", bush_pts, vfill(-900, 30, [("FF2E5640", 0), ("FF1E3A2E", 1)]), line(INK, 5))
    bush_lit = S("PathBushRim", [(-222, -160), (-232, -300), (-202, -470), (-222, -620), (-150, -800)],
                 bound_line("lightKey", 4, SCENES["campfire"].key), closed=False, opacity=0.55)
    clumps = [E(f"PathLeafClump{i}", cx, cy, w, h, fill(c), line(INK, 2.5))
              for i, (cx, cy, w, h, c) in enumerate([(-120, -760, 210, 130, "FF386A4C"),
                                                     (90, -680, 230, 140, "FF325E44"),
                                                     (-150, -470, 220, 140, "FF386A4C"),
                                                     (150, -420, 200, 130, "FF2E5640"),
                                                     (10, -840, 180, 110, "FF325E44")])]
    post = N("PathSign",
             S("PathSignBoardA", [(-8, -520, "c4"), (-150, -520, "c4"), (-176, -490, "c"), (-150, -460, "c4"),
                                  (-8, -460, "c4")], fill("FF8A6044"), line(INK, 3)),
             S("PathSignBoardB", [(8, -436, "c4"), (130, -436, "c4"), (156, -406, "c"), (130, -376, "c4"),
                                  (8, -376, "c4")], fill("FF7A543C"), line(INK, 3)),
             R("PathSignPost", 0, -260, 20, 560, 8, fill("FF6A4A36"), line(INK, 3)),
             x=300.0, y=0.0)
    stones = [E(f"PathStone{i}", cx, cy, w, h, fill("FF5A5664"), line(INK, 2.5))
              for i, (cx, cy, w, h) in enumerate([(-200, 20, 90, 30), (-90, 30, 60, 20)])]
    return N("Path", *fronds, *stones, gap, *clumps, bush_lit, bush, post,
             bind("path", 18), bind("path", 16, conv(0.1, 0.9)), bind("path", 17, conv(0.1, 0.9)),
             x=PATH_X, y=GROUND_Y, opacity=0.0)


# ---------------------------------------------------------------- portal (anchor: ring centre)

RING_W, RING_H = 420.0, 900.0
PORTAL_X, PORTAL_Y = THRESHOLD_X - 10.0 + RING_W / 2, GROUND_Y - RING_H / 2 - 30.0


def portal() -> El:
    swirl_arcs = []
    for i in range(3):
        a0 = i * math.tau / 3
        pts = [(math.cos(a0 + t * 2.2) * (60 + 380 * t), math.sin(a0 + t * 2.2) * (60 + 380 * t))
               for t in [k / 6 for k in range(7)]]
        swirl_arcs.append(S(f"emitPortalSwirl{i}", pts, line("C0D9CCFF", 10, emit=True), closed=False))
    swirl = N("emitPortalSwirl", *swirl_arcs, x=0.0, y=0.0)
    amb_tracks.append(track(d, swirl, {"rotation": [(0, 0.0, "linear"), (AMB_FRAMES, math.tau, "linear")]}))
    squash = N("emitPortalSwirlSquash", swirl, x=0.0, y=0.0, scaleX=RING_W / RING_H, scaleY=1.0)
    core = E("emitPortalCore", 0, 0, RING_W - 16, RING_H - 16,
             rfill(RING_H / 2, [("FF2A1E48", 0), ("FF4A3486", 0.7), ("FF8C74D8", 1)], emit=True))
    core_node = N("emitPortalAperture", squash, core, bind("open", 16, conv(0.95, 0.05)),
                  bind("open", 17, conv(0.95, 0.05)), x=0.0, y=0.0, scaleX=0.05, scaleY=0.05)
    ring = E("emitPortalRing", 0, 0, RING_W, RING_H, line("FFB79CFF", 18, emit=True))
    ring_hi = E("emitPortalRingHi", 0, 0, RING_W - 16, RING_H - 16, line("FFF3EBDD", 3, emit=True))
    glow = E("emitPortalGlow", 0, 0, RING_W + 170, RING_H + 170,
             rfill((RING_H + 170) / 2, [("00B79CFF", 0.55), ("70B79CFF", 0.8), ("00B79CFF", 1)], emit=True))
    sparks = []
    for i, (sx, sy) in enumerate([(-236, -330), (234, -200), (-246, 70), (240, 270), (-200, 370), (190, -410)]):
        sp = star4(f"emitPortalSpark{i}", sx, sy, 14 + 5 * (i % 2), "FFF3EBDD")
        sparks.append(sp)
        ph = i * 37
        keys = sorted({(0, 0.2), ((ph) % AMB_FRAMES, 0.2), ((ph + 30) % AMB_FRAMES, 1.0),
                       ((ph + 60) % AMB_FRAMES, 0.2), (AMB_FRAMES, 0.2)})
        amb_tracks.append(track(d, sp, {"opacity": [(f, v) for f, v in keys]}, ease=EASE))
    ground = E("emitPortalGround", 0, GROUND_Y - PORTAL_Y - 6, RING_W + 160, 50,
               rfill(140, [("80B79CFF", 0), ("00B79CFF", 1)], emit=True))
    grow = N("PortalGrow", *sparks, ring_hi, ring, core_node, glow, bind("portal", 16), bind("portal", 17),
             x=0.0, y=0.0, scaleX=0.0, scaleY=0.0)
    return N("Portal", grow, ground, bind("portal", 18), x=PORTAL_X, y=PORTAL_Y, opacity=0.0)


# ---------------------------------------------------------------- rocket (anchor: bottom centre)

RX, RY = 2.0, 1.15        # the rocket's art is drawn at unit size and stretched to bust scale
ROCKET_HW = 104.0 * RX
ROCKET_X = THRESHOLD_X - 14.0 + ROCKET_HW


def rp(pts: list) -> list:
    return [(p[0] * RX, p[1] * RY) + tuple(p[2:]) for p in pts]


def rocket() -> El:
    body_pts = rp([(0, -760), (54, -690), (92, -560), (104, -400), (96, -240), (82, -140, "c"),
                   (-82, -140, "c"), (-96, -240), (-104, -400), (-92, -560), (-54, -690)])
    body = S("RocketHull", body_pts, hfill(-104 * RX, 104 * RX, [("FFB8AEB8", 0), ("FFE6DDD2", 0.35),
                                                               ("FFC9BCB6", 0.8), ("FF8E8494", 1)]), line(INK, 5))
    nose = S("RocketNose", rp([(0, -760), (54, -690), (74, -640, "c"), (-74, -640, "c"), (-54, -690)]),
             vfill(-760 * RY, -640 * RY, [("FFD8705A", 0), ("FFB04A3E", 1)]), line(INK, 4))
    band = S("RocketBand", rp([(-100, -330, "c"), (100, -330, "c"), (102, -300, "c"), (-102, -300, "c")]),
             fill("FFB04A3E"), line(INK, 3))
    window = N("RocketWindow",
               E("emitRocketWindowGlass", 0, 0, 96, 96, rfill(54, [("FFB8D4EA", 0), ("FF5A7EA8", 1)], emit=True)),
               E("RocketWindowRing", 0, 0, 120, 120, fill("FF8E8494"), line(INK, 4)), x=0.0, y=-500.0 * RY)
    hatch_w, hatch_top, hatch_bottom = 150.0, -290.0 * RY, -150.0 * RY
    hatch_leaf = N("RocketHatch",
                   R("RocketHatchDoor", hatch_w / 2, (hatch_top + hatch_bottom) / 2, hatch_w, hatch_bottom - hatch_top,
                     30, hfill(0, hatch_w, [("FFD8CFC6", 0), ("FFA89EA8", 1)]), line(INK, 3)),
                   bind("open", 16, conv(-1.1, 1.0)), x=-hatch_w - 40, y=0.0)
    hatch_hole = R("RocketHatchHole", -hatch_w / 2 - 40, (hatch_top + hatch_bottom) / 2, hatch_w,
                   hatch_bottom - hatch_top, 30, fill("FF2A2236"), line(INK, 3))
    fins = [S("RocketFinL", rp([(-90, -280), (-150, -160), (-158, -60, "c"), (-82, -120, "c")]),
              vfill(-280 * RY, -60 * RY, [("FFD8705A", 0), ("FF9C4038", 1)]), line(INK, 4)),
            S("RocketFinR", rp([(90, -280), (150, -160), (158, -60, "c"), (82, -120, "c")]),
              vfill(-280 * RY, -60 * RY, [("FFC85E4E", 0), ("FF8A3632", 1)]), line(INK, 4))]
    legs = [S(f"RocketLeg{s}", rp([(s * 60, -140), (s * 96, 0), (s * 120, 0)]), line("FF5A5664", 10), closed=False)
            for s in (-1, 1)]
    rim = S("RocketRim", rp([(-100, -260), (-104, -400), (-92, -560), (-54, -690)]),
            bound_line("lightKey", 4, SCENES["livingRoom"].key), closed=False, opacity=0.65)
    shade = S("RocketShade", rp([(40, -700), (92, -560), (104, -400), (96, -240), (82, -140, "c"), (36, -140, "c"),
                                 (60, -400)]), bound_fill("lightAmbient", SCENES["livingRoom"].ambient), opacity=0.4)
    flame_inner = N("emitRocketFlameFlicker",
                    S("emitRocketFlameCore", [(0, 10), (-50, 70), (0, 230), (50, 70)],
                      fill("FFFFF1C8", emit=True)),
                    S("emitRocketFlameOuter", [(0, 0), (-100, 80), (-44, 240), (0, 360), (44, 240), (100, 80)],
                      vfill(0, 360, [("FFFFC46A", 0), ("FFFF8552", 0.6), ("00FF8552", 1)], emit=True)),
                    x=0.0, y=0.0)
    amb_tracks.append(track(d, flame_inner, {"scaleY": [(f, 1.0 + 0.12 * ((f // 6) % 2))
                                                        for f in range(0, AMB_FRAMES + 1, 6)]}))
    flame = N("emitRocketFlame", flame_inner,
              bind("lift", 18, conv_tokens(*F.fn("min", [F.val(1)], [F.val(12), F.op("*"), *F.inp()]))),
              x=0.0, y=-140.0 * RY, opacity=0.0)
    body_node = N("RocketBody", rim, window, hatch_leaf, hatch_hole, band, nose, shade, body, *fins, *legs, flame,
                  bind("lift", 14, conv(LIFT_TRAVEL)), x=0.0, y=0.0)
    smoke = N("RocketSmoke",
              *[E(f"RocketPuff{i}", cx, cy, w, h, fill("FF9C94A4"), line("FF6A6474", 3))
                for i, (cx, cy, w, h) in enumerate([(-250, -24, 220, 150), (-80, -14, 280, 180), (110, -30, 240, 170),
                                                    (290, -14, 180, 130)])],
              bind("lift", 18, conv_tokens(*F.fn("max", [F.val(0)], [*F.fn("min", [F.val(1)],
                                                                             [F.val(6), F.op("*"), *F.inp()]),
                                                                   F.op("-"), F.val(1.6), F.op("*"), *F.inp()]))),
              x=0.0, y=0.0, opacity=0.0)
    pad = E("RocketPad", 0, 4, 520, 50, fill("FF3E3A48"), line(INK, 3))
    return N("Rocket", smoke, body_node, pad, bind("rocket", 18), bind("rocket", 16, conv(0.08, 0.92)),
             bind("rocket", 17, conv(0.08, 0.92)), x=ROCKET_X, y=GROUND_Y, opacity=0.0)


# ---------------------------------------------------------------- assemble

EASE = d("CubicEaseInterpolator", x1=0.42, y1=0.0, x2=0.58, y2=1.0)


def build() -> list[El]:
    # Every build mints the same ids (the tests build more than once in one process): the shared lists start
    # empty and each id range at its start. v15: the book replaced the v10 door, the first family built from
    # the base range (ids 29-154). Those ids stay unused, except the appear converter the door shared with
    # the rocket (now with the book too), which keeps 0:146-0:151; path, portal and rocket keep theirs.
    amb_tracks.clear()
    converters.clear()
    _convs.clear()
    d.next = V10_APPEAR_CONV_ID
    conv(0.08, 0.92)
    d.next = V10_DOOR_END
    others = [path(), portal(), rocket()]
    d15.next = V15_DRAW_START
    with minting_in(d15):
        families = [book(), *others]
    amb = d("LinearAnimation", *amb_tracks, duration=AMB_FRAMES, fps=60, loopValue="loop", name="amb_journey")
    state = d("AnimationState", animationId=amb.ref(), x=160.0, y=100.0)
    layer = d("StateMachineLayer", d("AnyState", x=100.0, y=-100.0), d("ExitState", x=500.0, y=-100.0),
              d("EntryState", d("StateTransition", stateToId=state.ref()), x=-100.0, y=-100.0), state,
              name="Ambient")
    sm = d("StateMachine", layer, name="Main")
    style = d("LayoutComponentStyle", name="Artboard Style")
    ab = d("Artboard", style, sm, EASE, *families, amb, width=float(W), height=float(H), name="Journey",
           defaultStateMachineId=sm.ref(), viewModelId=vm.ref(), viewModelInstanceId=inst.ref(),
           styleId=style.ref(), clip=False)
    return [ab, vm, *converters]


def main() -> None:
    roots = build()
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, "journeys.rml")
    write(out, roots)
    with open(os.path.join(OUT_DIR, "rive.yaml"), "w") as f:
        f.write("name: journeys\nmain: Journey\noutput: {dir: build}\n"
                "logs: {file: build/rive.log, problems: build/problems.log}\n")
    print(os.path.normpath(out))


if __name__ == "__main__":
    main()
