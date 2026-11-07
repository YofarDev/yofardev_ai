"""Generates rive/journeys/journeys.rml (built to assets/rive/journeys/journey.riv): the scene-journey thresholds (contract v10,
`assets/rive/journeys/journey.riv`; moonshot M7 rulings 5-7, 11; v15: the storybook threshold).

One artboard `Journey`, 800 x 1000 (the avatar's), drawn by the app above the avatar with the
avatar's fit. Four thresholds stand on the right of the frame, their occluding edge at x 640 (the
app clips the avatar right of it while it walks through):

- **book** (v15, replaces the v10 door): a standing pop-up storybook; the cover swings open, pages
  riffle and the destination rises as a paper-cut vignette (v16: a gilt corner and title plate on the
  cover, a page face with the story's lines inside);
- **path** (v16): a leafy thicket with a lantern and a tunnel through it, ferns in front; the ferns
  part and the far end of the tunnel lights up in the scene beyond, fireflies drifting in it;
- **portal** (v16): a rift that tears open as a blade of light and widens into a violet ring; behind it
  a vortex turns and irises into a tunnel of rings flying towards the far scene's light;
- **rocket** (v16): a riveted steel rocket with a brass porthole; its hatch opens onto a lit cabin, and
  `lift` flies it: an ignition rumble on the pad with rolling smoke, then the climb on a three-layer
  flame, its shadow shrinking.

Everything is history-free: `JourneyVM` numbers bind opacity, scale, rotation and position through
`c + k x` formula converters (and clamped `min` / `max` ones for the book's cover swing and fades,
the clamp windows of `unfold` that stage its riffle and pop-up, with a `cos` for the riffled pages'
and the cover's foreshortening and a `sin` for the vignette hero's rise, and the rocket's flame and
smoke); one ambient loop turns the portal's swirl, flickers the flame, breathes the book's light,
drifts its motes and flickers its emblems' flames. No listeners, no events. Colours outside `emit*`
nodes are fitted into every scene's colour script, so the file lints clean wherever it is shown.

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

# The vignette's own lights: the scene NOT on screen (the destination before the cut, the origin after it), so the
# vignette glows in the other scene's light while the book's own rim and shade keep `lightKey` / `lightAmbient`. The
# defaults are the living room's, like theirs, so the file draws correctly until the app writes them. Their ids sit
# past the whole drawing, which keeps every drawing id as it was (build() asserts the drawing stops short of them).
V15_LIGHT_START = 20000
VIGNETTE_LIGHTS = {"vignetteKey": SCENES["livingRoom"].key, "vignetteAmbient": SCENES["livingRoom"].ambient}
d15.next = V15_LIGHT_START
for _name, _light in VIGNETTE_LIGHTS.items():
    _after = vm_props["vignetteKey" if _name == "vignetteAmbient" else "lightAmbient"]
    vm_props[_name] = d15("ViewModelPropertyColor", name=_name)
    vm.children.insert(vm.children.index(_after) + 1, vm_props[_name])
    inst.children.insert(1 + next(i for i, v in enumerate(inst.children)
                                  if v.attrs["viewModelPropertyId"] == _after.ref()),
                         d15("ViewModelInstanceColor", propertyValue=_light,
                             viewModelPropertyId=vm_props[_name].ref()))


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
# COVER_REST at open 1 (fully folded back: a stub of |COVER_REST| x COVER_LEN = 15 px left of the gutter, x 625-640
# (fix round 2), clear of the avatar's band and right of the avatar's own jacket at the hook, x <= 619, so the grab
# and hang handoffs show the fist and one whole jacket). Two clamped segments, so the cover keeps moving to open 1:
# one clamp reaching COVER_REST would stop it dead just past edge-on, mid-ramp. The cover is drawn
# closed (pointing right, the outer face as read): past edge-on it shows its inner face, mirrored.
EDGE_ON = 0.5
COVER_REST = -0.035
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
# v16 (the thresholds' polish): the path, the portal and the rocket are redrawn from V16_ID_START; their v10 ids
# (V10_DOOR_END up to V10_FAMILIES_END) stay unused, so the ambient animation and the state machine keep theirs
V10_FAMILIES_END = 1150
V16_ID_START = 30000
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


# ---------------------------------------------------------------- the vignette (v15: riffle, pop-up, emblems, motes)
#
# `unfold` stages all of it. The app ramps the number once per beat; the stagger lives here, in clamp windows of
# it (`window`). Placement keeps the avatar's own beats readable, since the journey draws over the avatar:
# - the supporting panels stand left of the gutter but never left of VIG_LEFT (the avatar's face box is FACE_BOX);
# - their floor is the gutter at VIG_FLOOR, above HOOK_ZONE, where the avatar's `grab` / `hang` fist and its own
#   jacket copy pass (the cover's stub keeps clear of it for the same reason);
# - the hero stands on the right page, where the only free area in portrait is, and keeps out of REACH_ZONE at every
#   step; below HERO_FLOOR the block's face stays plain leather;
# - the riffle flips on the block's face, above the reach zone, and folds away onto the stub.
# All of it is lit by the scene NOT on screen (VIGNETTE_LIGHTS): the contrast with the room is the beat.

UNFOLD_FLAPS = ((0.00, 0.18), (0.06, 0.27), (0.14, 0.38))             # the riffle: three pages, staggered
# No snap at the grab boundary: the open beat ramps `unfold` 850-1600 ms (easeOut) but hands over to the grab at
# 1400 ms, which writes 1. By then `unfold` is 0.895, so everything that would show a jump lands by UNFOLD_LANDED: the
# panels and the floor spill. (The shaft's fade ends at 0.9; the last 0.8 % of it is invisible.)
UNFOLD_LANDED = 0.89
UNFOLD_PANELS = {"Far": (0.10, 0.55), "Mid": (0.22, 0.72), "Near": (0.38, UNFOLD_LANDED)}   # the pop-up, tallest first
UNFOLD_SHAFT = (0.3, 0.9)                                             # the light shaft and its motes
VIG_FLOOR = 500.0           # artboard y of the vignette's floor at the gutter: the panels' pivot, the shaft's mouth
VIG_LEFT = 520.0            # the panels' left extent (artboard x)
FACE_BOX = (260.0, 520.0, 150.0, 450.0)    # the avatar's face at rest (artboard x0, x1, y0, y1): never drawn over
HOOK_ZONE = (500.0, 640.0, 505.0, 770.0)   # the grab / hang reach, fist and held jacket: no vignette art over it
PANEL_FLAT = math.pi / 2    # a panel lies flat behind the block: turned clockwise about its pivot onto the floor line
FLAP_TURN = math.acos(COVER_REST)   # a riffled page turns about the spine until it lies on the cover's stub
FLAP_FADE = 0.35            # a page fades in over this share of its window as it lifts (on the close, out as it lands)
# width, height, artboard centre y: on the page where the hero rises, ending above the reach zone
FLAPS = ((180.0, 226.0, 401.0), (186.0, 222.0, 403.0), (192.0, 218.0, 405.0))
MOTES = ((616.0, 470.0, 8.0), (594.0, 412.0, 6.0), (574.0, 348.0, 10.0), (606.0, 292.0, 7.0), (556.0, 232.0, 9.0),
         (590.0, 172.0, 6.0), (548.0, 112.0, 8.0))   # artboard x, y (at the start of its rise) and size
MOTE_PHASE, MOTE_RISE = 34, 60.0
SHAFT_LEAN = 0.22           # the light shaft leans this far left of vertical (rad), from the gutter's mouth
# The touchdown: a panel's main rise ends SETTLE_SHARE before the end of its window, SETTLE_TURN short of erect, and
# the last of the turn takes the rest of the window, about five times slower, while the panel's scale comes down
# SETTLE_DIP onto 1. Every converter stays monotonic (the rest pose is exact), so it lands, it does not wobble.
SETTLE_SHARE, SETTLE_TURN, SETTLE_DIP = 0.2, 0.069, 0.02    # 0.069 rad = 3.95 degrees
# The hero: the other scene, as a paper-cut card standing on the right page, turned out from the gutter. It stands up
# off the page inside HERO_RISE of `unfold`, showing over the first HERO_FADE of that window.
HERO_RISE, HERO_FOLDED, HERO_FADE = (0.45, 0.85), 0.06, 0.18
HERO_AT = (721.0, 521.0)    # artboard: the middle of the card's foot, its pivot
HERO_HW, HERO_TOP = 69.0, 306.0   # the card, from its foot: half its width and its height at the arch (the shear
                                  # lifts the arch's left shoulder 5 px above this: its top stands at y 210)
HERO_SHEAR = 0.4225         # px down per px right: the turned card's foot, clear of the reach zone left of x 700
HERO_MAT = 7.0              # the paper frame round the card's sky
HERO_FLAT_SHEAR = 0.18      # the nearer flat (the emblem and its back), turned less than the card: objects stay upright
HERO_EMBLEM = (122.0, 226.0)   # the emblem's largest width and height on the flat
HERO_EMBLEM_FOOT = 28.0     # its foot, above the card's at the middle (the ground strip hides it)
HERO_FLOAT = {"deepSpace": 48.0}   # an emblem with no ground under it floats
_C = "c"                    # a hard corner in the back flats' outlines
# Each scene's back flat on the card: the top of its dark layer, left to right (y up from the card's foot). Its rim
# takes the key, so it stands against the sky's glow.
HERO_BACKS: dict[str, list[tuple]] = {
    "livingRoom": [(-64, -108, _C), (64, -108, _C)],                                      # the floor
    "campfire": [(-64, -86, _C), (-56, -114, _C), (-48, -92, _C), (-38, -130, _C), (-28, -96, _C), (-16, -122, _C),
                 (-6, -92, _C), (6, -136, _C), (18, -96, _C), (30, -126, _C), (40, -94, _C), (52, -118, _C),
                 (64, -90, _C)],                                                          # a pine treeline
    "beach": [(-64, -98), (-24, -94), (20, -99), (64, -95)],                              # the sea
    "deepSpace": [(-64, -72), (-40, -86), (-16, -68), (14, -82), (40, -64), (64, -80)],   # a moon's surface
    "cafe": [(-64, -94, _C), (64, -94, _C)],                                              # the counter
    "rooftop": [(-64, -104, _C), (-46, -104, _C), (-46, -122, _C), (-30, -122, _C), (-30, -96, _C), (-8, -96, _C),
                (-8, -132, _C), (10, -132, _C), (10, -108, _C), (34, -108, _C), (34, -140, _C), (50, -140, _C),
                (50, -100, _C), (64, -100, _C)],                                          # the far blocks
    "mountainHut": [(-64, -64), (-48, -92), (-34, -80), (-12, -128), (6, -100), (26, -120), (46, -86), (64, -98)],
    "forestCabin": [(-64, -96, _C), (-54, -128, _C), (-44, -102, _C), (-30, -146, _C), (-18, -106, _C),
                    (-6, -134, _C), (6, -102, _C), (22, -152, _C), (36, -106, _C), (50, -136, _C), (64, -100, _C)],
    "trainCompartment": [(-64, -86, _C), (64, -86, _C)],                                  # the seat's back
    "library": [(-64, -122, _C), (-50, -122, _C), (-50, -134, _C), (-38, -134, _C), (-38, -114, _C), (-26, -114, _C),
                (-26, -142, _C), (-14, -142, _C), (-14, -118, _C), (0, -118, _C), (0, -130, _C), (14, -130, _C),
                (14, -112, _C), (30, -112, _C), (30, -138, _C), (44, -138, _C), (44, -120, _C), (64, -120, _C)],
}
HERO_BACK_FOOT = -20.0      # the back flats' bottom edge: hidden by the ground strip all along the card's foot
REACH_ZONE = (500.0, 700.0, 515.0, 770.0)   # x0, x1, y0, y1: the grab / hang arm and the hook: no hero art, ever
HERO_FLOOR = 560.0          # below this the block's face stays plain leather
EMBLEM_AT = (-68.0, -26.0)  # the emblems' base centre, from the vignette's pivot (artboard (572, 474))
GLYPH_R = MEDALLION_INNER_R - 4   # a medallion glyph's bounding box fits inside this circle
PAPER, PAPER_SHADE, PAPER_TAN = "FFF3EBDD", "FFE0D2BC", "FFD9C7A8"
INSET = "FF5A3E30"          # openings (a tent's door, coffee)
FOIL, FOIL_SHADE, FOIL_INK = "FFDCB46C", "FFB08A48", "FF5A3A1E"
CLEAR = "00FFF4E4"          # a glow's fading end: nearly neutral, so it fades the same in every scene's light
COLOR_BLEND = 27            # Rive's color blend: hue and saturation from the paint, lightness from what is under it
SPILL_PEAK = 0.533          # the floor spill's opacity at `unfold` 1 (0.85 of its v15 stop's alpha 0xA0)
GUTTER_KEY_AT = 0.25        # where the gutter glow reaches the vignette's key
BREATH = [(0, 0.9), (60, 1.0), (120, 0.88), (180, 1.0), (240, 0.9)]   # the v10 door's glow breath

_windows: dict[tuple[object, ...], El] = {}


def window_tokens(a: float, b: float) -> list[El]:
    k = 1 / (b - a)
    return clamp01(F.val(k), F.op("*"), *F.inp(), F.op("+"), F.val(-a * k))


def window(a: float, b: float) -> El:
    """`min(1, max(0, (x - a) / (b - a)))`: 0 up to `a`, 1 from `b`, linear between (one shared converter per
    window)."""
    key = ("window", round(a, 3), round(b, 3))
    if key not in _windows:
        _windows[key] = conv_tokens(*window_tokens(a, b))
    return _windows[key]


def windowed(a: float, b: float, k: float, c: float = 0.0) -> El:
    """`c + k window(a, b)`: from c to c + k over the window (one shared converter per form)."""
    key = ("linear", round(a, 3), round(b, 3), round(k, 3), round(c, 3))
    if key not in _windows:
        head = [] if key[4] == 0 else [F.val(c), F.op("+")]
        _windows[key] = conv_tokens(*head, F.val(k), F.op("*"), *window_tokens(a, b))
    return _windows[key]


def flipped(a: float, b: float, turn: float) -> El:
    """`cos(turn window(a, b))`: the projected width of a page turned `turn` rad about the spine over the
    window (the cover's swing, foreshortened the same way)."""
    key = ("cos", round(a, 3), round(b, 3), round(turn, 3))
    if key not in _windows:
        _windows[key] = conv_tokens(*F.fn("cos", [F.val(turn), F.op("*"), *window_tokens(a, b)]))
    return _windows[key]


def cyclic(points: list[tuple[int, float]], phase: int) -> list[tuple[int, float]]:
    """Ambient keys for a periodic, piecewise-linear curve given by its (frame, value) points over one loop (the
    first at frame 0), running `phase` frames late: keys on 0..AMB_FRAMES whose first and last match."""
    ext = [*points, (AMB_FRAMES, points[0][1])]

    def at(u: float) -> float:
        u %= AMB_FRAMES
        for (u0, v0), (u1, v1) in zip(ext, ext[1:]):
            if u0 <= u <= u1:
                return v0 + (v1 - v0) * (u - u0) / (u1 - u0)
        raise AssertionError(u)

    keys = {(u + phase) % AMB_FRAMES: v for u, v in points}
    keys[0] = keys[AMB_FRAMES] = at(-phase)
    return sorted(keys.items())


def named(root: El, name: str) -> El:
    """The one element called `name` under `root`."""
    found = [e for e in _walk(root) if e.attrs.get("name") == name]
    assert len(found) == 1, (name, len(found))
    return found[0]


def _walk(e: El) -> Iterator[El]:
    yield e
    for c in e.children:
        yield from _walk(c)


def star_path(r: float) -> El:
    """A four-point star's path centred on its shape (as `star4`)."""
    verts = []
    for x, y in [(0.0, -r), (r, 0.0), (0.0, r), (-r, 0.0)]:
        to_c = math.atan2(-y, -x)
        verts.append(d("CubicDetachedVertex", x=x, y=y, inRotation=float(to_c), inDistance=r * 0.62,
                       outRotation=float(to_c), outDistance=r * 0.62))
    return d("PointsPath", *verts, isClosed=True, isClockwise=True, name="Path")


def arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int, tilt: float = 0.0) -> list:
    """`n` points along an ellipse from angle a0 to a1 (rad), the ellipse turned `tilt`."""
    out = []
    for i in range(n):
        a = a0 + (a1 - a0) * i / (n - 1)
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * math.cos(tilt) - y * math.sin(tilt), cy + x * math.sin(tilt) + y * math.cos(tilt)))
    return out


def vignette_fill(prop: str) -> El:
    """A fill in the vignette's light (`vignetteKey` / `vignetteAmbient`)."""
    return bound_fill(prop, VIGNETTE_LIGHTS[prop])


def vignette_line(prop: str, w: float) -> El:
    return bound_line(prop, w, VIGNETTE_LIGHTS[prop])


def light_stop(position: float, prop: str = "vignetteKey") -> El:
    """A gradient stop in the vignette's light."""
    return d("GradientStop", bind(prop, 38), colorValue=fit(VIGNETTE_LIGHTS[prop]), position=float(position))


def stop(c: str, position: float) -> El:
    return d("GradientStop", colorValue=c, position=float(position))


def light_glow(r: float, *stops: El, cx: float = 0.0, cy: float = 0.0) -> El:
    """A radial fill through `stops`, clear at `r`. A bound colour is opaque, so a glow's strength is its shape's
    opacity."""
    return d("Fill", d("RadialGradient", *stops, stop(CLEAR, 1.0), startX=float(cx), startY=float(cy),
                       endX=float(cx + r), endY=float(cy)), name="Fill")


def relit(shape: El, at: int, position: float) -> None:
    """Stop `at` of a glow drawn before the vignette's lights takes `vignetteKey` (its ids stay as they were)."""
    stops = [e for e in _walk(shape) if e.tag == "GradientStop"]
    stops[at].attrs.update(colorValue=fit(VIGNETTE_LIGHTS["vignetteKey"]), position=float(position))
    stops[at].add(bind("vignetteKey", 38))
    stops[-1].attrs["colorValue"] = CLEAR


def tinted(*roots: El) -> None:
    """The paper and the foil under `roots` take the vignette's light: a second fill over a shape's own, under its
    ink (a shape's later paints draw over the earlier ones; M10's tint), color blend, so the shape keeps its
    lightness and its tones and takes the key's hue."""
    tones = {fit(c) for c in (PAPER, PAPER_SHADE, PAPER_TAN, FOIL, FOIL_SHADE)}
    for root in roots:
        for shape in _walk(root):
            own = [c for c in shape.children if c.tag == "Fill"]
            if shape.tag == "Shape" and own and own[0].children[0].attrs.get("colorValue") in tones:
                shape.children.insert(shape.children.index(own[-1]) + 1, d(
                    "Fill", d("SolidColor", bind("vignetteKey", 37), colorValue=fit(VIGNETTE_LIGHTS["vignetteKey"])),
                    blendModeValue=COLOR_BLEND, fillRule=own[-1].attrs.get("fillRule"), name="Tint"))


class Kit:
    """How an emblem is drawn: in the vignette (paper cut-outs, ink, emit lights with their glows) or on the
    medallion (gold foil stamped into the leather: foil, dark debossed lines and insets, no glows)."""

    def __init__(self, scene: str, foil: bool, prefix: str = "Vignette") -> None:
        self.foil = foil
        self.prefix = ("Medallion" if foil else prefix) + scene[0].upper() + scene[1:]

    def n(self, part: str, emit: bool = False) -> str:
        return ("emit" if emit and not self.foil else "") + self.prefix + part

    def paper(self, tone: str = PAPER) -> El:
        if self.foil:
            return fill(FOIL_INK if tone == INSET else FOIL if tone == PAPER else FOIL_SHADE)
        return fill(tone)

    def ink(self, w: float = 3.0) -> El:
        return line(FOIL_INK if self.foil else INK, w)

    def drawn(self, w: float) -> El:
        """A stroke drawn on its own (steam), in the vignette's light."""
        return vignette_line("vignetteKey", w)


def cut(k: Kit, part: str, pts: list, tone: str = PAPER, w: float = 3.0, **kw: object) -> El:
    """A paper (or foil) cut-out with an ink outline."""
    return S(k.n(part), pts, k.paper(tone), k.ink(w), **kw)


def lit(k: Kit, part: str, pts: list, light: El | None, **kw: object) -> El:
    """A glyph part that glows in the vignette (`light`, an emit fill, None on the medallion) and is foil on the
    medallion."""
    if k.foil:
        return S(k.n(part), pts, k.paper(), k.ink(2.5), **kw)
    return S(k.n(part, emit=True), pts, light, **kw)


def lit_disc(k: Kit, part: str, cx: float, cy: float, r: float, light: El | None) -> El:
    """A round `lit` part (a sun, a moon)."""
    paints = [k.paper(), k.ink(2.5)] if k.foil else [light]
    return E(k.n(part, emit=True), cx, cy, 2 * r, 2 * r, *paints)


def multi(k: Kit, part: str, paths: list[El], *paints: El, emit: bool = False) -> El:
    """A shape of several paths (holes with an even-odd fill)."""
    return d("Shape", *paths, *paints, x=0.0, y=0.0, name=k.n(part, emit=emit))


def holed(k: Kit, tone: str = PAPER) -> El:
    """The kit's fill for a shape whose inner paths are holes (even-odd)."""
    f = k.paper(tone)
    f.attrs["fillRule"] = "evenOdd"
    return f


def _living_room(k: Kit) -> list[El]:
    """An armchair and a floor lamp, its light falling on the chair."""
    chair = [(-42, 3, "c"), (-42, -10, "c"), (-47, -14, "c3"), (-48, -42, "c6"), (-40, -46, "c3"), (-39, -76, "c12"),
             (-5, -76, "c12"), (-6, -46, "c3"), (2, -42, "c6"), (1, -14, "c3"), (-4, -10, "c"), (-4, 3, "c"),
             (-11, 3, "c"), (-11, -8, "c"), (-35, -8, "c"), (-35, 3, "c")]
    pole = [(17, 3, "c"), (35, 3, "c"), (35, -1, "c2"), (28, -4, "c"), (28, -102, "c"), (24, -102, "c"), (24, -4, "c"),
            (17, -1, "c2")]
    out = [S(k.n("Seams"), [(-40, -44, "c"), (-40, -24, "c"), (-6, -24, "c"), (-6, -44, "c")], k.ink(2.5),
             closed=False),
           cut(k, "Chair", chair),
           cut(k, "Shade", [(12, -100, "c2"), (40, -100, "c2"), (34, -136, "c4"), (18, -136, "c4")]),
           cut(k, "Lamp", pole, w=2.0)]
    if not k.foil:
        out.append(S(k.n("LampGlow", emit=True), [(14, -100, "c"), (38, -100, "c"), (56, -28, "c"), (-4, -28, "c")],
                     vfill(-100, -28, [("B0FFE7B0", 0), ("00FFE7B0", 1)], emit=True)))
    return out


def _campfire(k: Kit) -> list[El]:
    """A tent and a flame on a log (the flame flickers on the ambient loop)."""
    flame = [(34, 2), (22, -10), (24, -34), (34, -66), (38, -44), (46, -24), (44, -4)]
    out = [cut(k, "Log", [(14, 8, "c3"), (52, -6, "c3"), (54, 1, "c3"), (16, 15, "c3")], PAPER_SHADE, 2.5),
           lit(k, "Flame", flame, None if k.foil else vfill(0, -66, [("FFFFF1C8", 0), ("FFFFC46A", 0.45),
                                                                     ("FFFF8552", 1)], emit=True), x=34.0, y=0.0),
           cut(k, "Door", [(-24, 3, "c"), (-12, -54, "c2"), (0, 3, "c")], INSET, 2.5),
           cut(k, "Tent", [(-46, 3, "c"), (-12, -98, "c4"), (24, 3, "c")])]
    if not k.foil:
        out.append(E(k.n("FireGlow", emit=True), 34, -26, 100, 100,
                     rfill(50, [("90FFB060", 0), ("00FF8A40", 1)], emit=True)))
    return out


def palm_frond(cx: float, cy: float, tx: float, ty: float, arch: float, width: float) -> list:
    """A palm frond's closed outline: a leaf from the crown (cx, cy) to its tip, its spine arching `arch` px up
    at mid-length (the side fronds droop)."""
    length = math.hypot(tx - cx, ty - cy)
    ux, uy = (tx - cx) / length, (ty - cy) / length
    px, py = -uy, ux                                   # the spine turned clockwise on screen
    nx, ny = (px, py) if py < 0 else (-px, -py)        # whichever side is up: the spine arches that way

    def at(t: float, side: float) -> tuple[float, float]:
        bend = 4 * arch * t * (1 - t)
        w = side * width * math.sin(math.pi * t) ** 0.7
        return (cx + t * (tx - cx) + bend * nx + w * px, cy + t * (ty - cy) + bend * ny + w * py)

    return [(cx, cy, "c"), at(0.3, -1), at(0.62, -1), (tx, ty, "c2"), at(0.62, 1), at(0.3, 1)]


def _beach(k: Kit) -> list[El]:
    """A palm (five fronds, the side ones drooping), the sun setting beside it."""
    cx, cy = 4.0, -122.0   # the crown
    tips = [((-46, -84), 22.0), ((-34, -142), 12.0), ((10, -166), 5.0), ((44, -140), 12.0), ((52, -86), 22.0)]
    leaves = [smooth_path(d, palm_frond(cx, cy, tx, ty, arch, 0.15 * math.hypot(tx - cx, ty - cy)))
              for (tx, ty), arch in tips]
    trunk = [(-20, 3, "c"), (-17, -40), (-9, -82), (1, -120, "c3"), (8, -118, "c3"), (0, -80), (-6, -40), (-5, 3, "c")]
    out = [multi(k, "Fronds", leaves, k.paper(), k.ink(2.5)),
           cut(k, "Trunk", trunk, PAPER_SHADE),
           lit_disc(k, "Sun", 30, -60, 19,
                    None if k.foil else rfill(19, [("FFFFF2C2", 0), ("FFFFD27A", 1)], emit=True))]
    if not k.foil:
        out.append(E(k.n("SunGlow", emit=True), 30, -60, 86, 86,
                     rfill(43, [("90FFD88A", 0.3), ("00FFD88A", 1)], emit=True)))
    return out


def _deep_space(k: Kit) -> list[El]:
    """A ringed planet (its ring passing behind and in front of it) and two four-point stars."""
    cx, cy, tilt = -2.0, -80.0, -0.38
    ring = [d("Ellipse", width=92.0, height=24.0, x=cx, y=cy, rotation=tilt, name="Path"),
            d("Ellipse", width=68.0, height=12.0, x=cx, y=cy, rotation=tilt, name="Path")]
    band = (arc(cx, cy, 46, 12, 0, math.pi, 9, tilt) + arc(cx, cy, 34, 6, math.pi, 0, 9, tilt))
    band = [(*p, "c") if i in (0, 8, 9, 17) else p for i, p in enumerate(band)]

    def star(part: str, x: float, y: float, r: float) -> El:
        paints = [k.paper(), k.ink(1.5)] if k.foil else [fill("FFFFF6E0", emit=True)]
        return d("Shape", star_path(r), *paints, x=x, y=y, name=k.n(part, emit=True))

    return [cut(k, "RingFront", band, PAPER_SHADE, 2.5),
            E(k.n("Planet"), cx, cy, 58, 58, k.paper(), k.ink()),
            multi(k, "RingBack", ring, holed(k, PAPER_SHADE), k.ink(2.5)),
            star("Star", 32, -146, 15),
            star("StarSmall", -38, -142, 9)]


def _cafe(k: Kit) -> list[El]:
    """A cup on its saucer, steam curling up."""
    steam = [smooth_path(d, [(-14, -74), (-6, -90), (-16, -106), (-8, -124)], closed=False),
             smooth_path(d, [(4, -76), (12, -94), (2, -112), (10, -132)], closed=False)]
    handle = [d("Ellipse", width=30.0, height=34.0, x=30.0, y=-38.0, name="Path"),
              d("Ellipse", width=14.0, height=18.0, x=30.0, y=-38.0, name="Path")]
    return [multi(k, "Steam", steam, k.drawn(4.5)),
            E(k.n("Coffee"), -5, -64, 58, 11, k.paper(INSET), k.ink(2.5)),
            cut(k, "Cup", [(-31, -10, "c5"), (-35, -64, "c3"), (25, -64, "c3"), (21, -10, "c5")]),
            multi(k, "Handle", handle, holed(k), k.ink(2.5)),
            E(k.n("Saucer"), -4, -6, 86, 14, k.paper(PAPER_SHADE), k.ink(2.5))]


def _rooftop(k: Kit) -> list[El]:
    """A railing before the city's roofs, lit windows, a crescent moon."""
    o, r, c, rc = (-12.0, -132.0), 22.0, (-2.0, -140.0), 19.0
    dx, dy = c[0] - o[0], c[1] - o[1]
    dd = math.hypot(dx, dy)
    base = math.atan2(dy, dx)
    half = math.acos((dd * dd + r * r - rc * rc) / (2 * dd * r))         # the outer circle's crossing half-angle
    half_c = math.acos((dd * dd + rc * rc - r * r) / (2 * dd * rc))      # the cut circle's
    moon = (arc(*o, r, r, base + half, base + math.tau - half, 11)
            + arc(*c, rc, rc, base + math.pi + half_c, base + math.pi - half_c, 9)[1:-1])
    moon = [(*p, "c1") if i in (0, 10) else p for i, p in enumerate(moon)]
    skyline = [(-46, -40, "c"), (-46, -78, "c"), (-30, -78, "c"), (-30, -92, "c"), (-14, -92, "c"), (-14, -70, "c"),
               (0, -70, "c"), (0, -104, "c2"), (10, -114, "c"), (20, -104, "c2"), (20, -66, "c"), (32, -66, "c"),
               (32, -84, "c"), (46, -84, "c"), (46, -40, "c")]
    rails = [d("Rectangle", width=92.0, height=44.0, cornerRadiusTL=3.0, x=0.0, y=-24.0, name="Path"),
             *[d("Rectangle", width=14.0, height=28.0, x=hx, y=-22.0, name="Path")
               for hx in (-30.0, -10.0, 10.0, 30.0)]]
    windows = [d("Rectangle", width=5.0, height=6.0, x=wx, y=wy, name="Path")
               for wx, wy in ((-38, -66), (-22, -82), (-22, -66), (-7, -58), (10, -96), (10, -80), (26, -56),
                              (39, -72))]
    out = [multi(k, "Railing", rails, holed(k), k.ink(2.5)),
           multi(k, "Windows", windows, *([k.paper(INSET)] if k.foil else [fill("FFFFD48A", emit=True)]), emit=True),
           cut(k, "Roofs", skyline, PAPER_TAN, 2.5),
           cut(k, "Moon", moon, w=2.5)]
    if not k.foil:
        out.append(E(k.n("MoonGlow", emit=True), o[0], o[1], 68, 68,
                     rfill(34, [("70FFF3DD", 0.3), ("00FFF3DD", 1)], emit=True)))
    return out


def _mountain_hut(k: Kit) -> list[El]:
    """A hut's gable, its window lit, before a snow-capped peak."""
    window_paint = k.paper(INSET) if k.foil else fill("FFFFD08A", emit=True)
    return [R(k.n("Window", emit=True), -2, -24, 16, 16, 2, window_paint),
            cut(k, "Hut", [(-30, 3, "c"), (-30, -40, "c"), (-36, -40, "c"), (-2, -74, "c3"), (32, -40, "c"),
                           (26, -40, "c"), (26, 3, "c")]),
            cut(k, "Snow", [(-6, -150, "c3"), (-19, -108, "c2"), (-11, -114, "c"), (-4, -102, "c"), (5, -114, "c"),
                            (12, -107, "c2")], w=2.5),
            cut(k, "Peak", [(-46, -22, "c"), (-6, -150, "c3"), (46, -22, "c")], PAPER_TAN)]


def pine(cx: float, tip: float, base: float, hw: float) -> list:
    """A three-tier pine's outline (its trunk to y 3)."""
    right = []
    for i in range(3):
        y = tip + (i + 1) * (base - tip) / 3
        w = hw * (0.45 + 0.55 * (i + 1) / 3)
        right.append((cx + w, y, "c2"))
        if i < 2:
            right.append((cx + w * 0.42, y - 3, "c"))
    trunk = [(cx + 4, base, "c"), (cx + 4, 3, "c"), (cx - 4, 3, "c"), (cx - 4, base, "c")]
    left = [(2 * cx - x, y, *rest) for x, y, *rest in reversed(right)]
    return [(cx, tip, "c2"), *right, *trunk, *left]


def _forest_cabin(k: Kit) -> list[El]:
    """A pair of pines, the near one shorter."""
    return [cut(k, "PineNear", pine(22, -108, -10, 27)),
            cut(k, "PineFar", pine(-14, -164, -12, 33), PAPER_TAN)]


def _train_compartment(k: Kit) -> list[El]:
    """A compartment's arched window (hills and the moon outside) over the rails."""
    frame = [d("Rectangle", width=74.0, height=128.0, linkCornerRadius=False, cornerRadiusTL=37.0, cornerRadiusTR=37.0,
               cornerRadiusBL=4.0, cornerRadiusBR=4.0, x=0.0, y=-100.0, name="Path"),
             d("Rectangle", width=52.0, height=108.0, linkCornerRadius=False, cornerRadiusTL=26.0,
               cornerRadiusTR=26.0, x=0.0, y=-100.0, name="Path")]
    track = [d("Rectangle", width=92.0, height=5.0, x=0.0, y=-28.0, name="Path"),
             d("Rectangle", width=92.0, height=5.0, x=0.0, y=-16.0, name="Path"),
             *[d("Rectangle", width=6.0, height=22.0, x=tx, y=-22.0, name="Path")
               for tx in (-36.0, -18.0, 0.0, 18.0, 36.0)]]
    view = "FF46506E"
    return [multi(k, "Frame", frame, holed(k), k.ink(3)),
            lit_disc(k, "Moon", 11, -128, 6, None if k.foil else fill("FFFFF3DD", emit=True)),
            cut(k, "Hills", [(-28, -44, "c"), (-28, -66), (-12, -76), (4, -68), (28, -82, "c"), (28, -44, "c")],
                PAPER_TAN, 2.0),
            S(k.n("View"), [(-27, -45, "c"), (-27, -127, "c26"), (27, -127, "c26"), (27, -45, "c")],
              k.paper(INSET) if k.foil else fill(view)),
            multi(k, "Track", track, k.paper(PAPER_SHADE), k.ink(2.0))]


def _library(k: Kit) -> list[El]:
    """A stack of books, a candle burning on it (the flame flickers on the ambient loop)."""
    books = [d("Rectangle", width=86.0, height=20.0, cornerRadiusTL=3.0, x=-4.0, y=-12.0, name="Path"),
             d("Rectangle", width=70.0, height=18.0, cornerRadiusTL=3.0, x=-8.0, y=-31.0, name="Path"),
             d("Rectangle", width=58.0, height=16.0, cornerRadiusTL=3.0, x=-2.0, y=-48.0, name="Path")]
    spines = [smooth_path(d, [(sx, y0), (sx, y1)], closed=False)
              for sx, y0, y1 in ((28.0, -21.0, -3.0), (16.0, -39.0, -23.0), (-24.0, -55.0, -41.0))]
    flame = [(5, -100), (-1, -108), (5, -130), (11, -108)]
    out = [multi(k, "Spines", spines, k.ink(2.5)),
           multi(k, "Books", books, k.paper(), k.ink(2.5)),
           lit(k, "Flame", flame, None if k.foil else vfill(0, -30, [("FFFFF1C8", 0), ("FFFFB060", 1)], emit=True),
               x=5.0, y=-100.0),
           cut(k, "Candle", [(-2, -56, "c"), (-2, -100, "c2"), (12, -100, "c2"), (12, -56, "c")], w=2.5)]
    if not k.foil:
        out.append(E(k.n("CandleGlow", emit=True), 5, -112, 76, 76,
                     rfill(38, [("90FFD08A", 0), ("00FFB060", 1)], emit=True)))
    return out


EMBLEMS = {"livingRoom": _living_room, "campfire": _campfire, "beach": _beach, "deepSpace": _deep_space,
           "cafe": _cafe, "rooftop": _rooftop, "mountainHut": _mountain_hut, "forestCabin": _forest_cabin,
           "trainCompartment": _train_compartment, "library": _library}


def glyph_box(shapes: list[El]) -> tuple[float, float, float, float]:
    """(x0, y0, x1, y1) of a glyph's shapes: their path points and parametric paths (turned ones by their
    longer side). The soft glows don't count: an emblem is fitted by its solid art."""
    xs: list[float] = []
    ys: list[float] = []
    for s in shapes:
        name = str(s.attrs.get("name", ""))
        if name.startswith("emit") and name.endswith("Glow"):
            continue
        sx, sy = float(s.attrs.get("x", 0.0)), float(s.attrs.get("y", 0.0))
        for p in s.children:
            if p.tag == "PointsPath":
                for v in p.children:
                    xs.append(sx + float(v.attrs["x"]))
                    ys.append(sy + float(v.attrs["y"]))
            elif p.tag in ("Ellipse", "Rectangle"):
                px, py = sx + float(p.attrs.get("x", 0.0)), sy + float(p.attrs.get("y", 0.0))
                w, h = float(p.attrs["width"]) / 2, float(p.attrs["height"]) / 2
                if p.attrs.get("rotation"):
                    w = h = max(w, h)
                xs += [px - w, px + w]
                ys += [py - h, py + h]
    return min(xs), min(ys), max(xs), max(ys)


def emblem(scene: str, prop: str) -> El:
    """`Emblem<Scene>` in `PanelNear`: the destination's paper cut-outs, standing on the near ground."""
    return N(f"Emblem{scene[0].upper()}{scene[1:]}", *EMBLEMS[scene](Kit(scene, foil=False)), bind(prop, 18),
             x=EMBLEM_AT[0], y=EMBLEM_AT[1], opacity=0.0)


def medallion_glyph(scene: str, prop: str) -> El:
    """`MedallionGlyph<Scene>`: the same emblem small, stamped in foil on the medallion; its bounding box fits
    inside GLYPH_R, centred on the medallion."""
    shapes = EMBLEMS[scene](Kit(scene, foil=True))
    x0, y0, x1, y1 = glyph_box(shapes)
    s = round(GLYPH_R / (0.5 * math.hypot(x1 - x0, y1 - y0)), 4)
    return N(f"MedallionGlyph{scene[0].upper()}{scene[1:]}", *shapes, bind(prop, 18),
             x=round(-s * (x0 + x1) / 2, 3), y=round(-s * (y0 + y1) / 2, 3), scaleX=s, scaleY=s, opacity=0.0)


def riffle() -> El:
    """`BookRiffle`: three printed pages lying on the block's face flick over onto the cover's stub, one after
    another (each turns FLAP_TURN about the spine, projected: scaleX = cos(FLAP_TURN x its window of `unfold`),
    the cover's own foreshortening). A page fades in over the first FLAP_FADE of its window as it lifts (on the
    close, `unfold` falling, it flutters back and fades as it lands) and comes to rest hidden behind the stub, so
    nothing of the riffle stays."""
    flaps = []
    for i, ((a, b), (w, h, cy)) in enumerate(zip(UNFOLD_FLAPS, FLAPS)):
        page = [(0, -h / 2, "c"), (w - 12, -h / 2, "c10"), (w, -h / 2 + 22), (w - 3, 0), (w, h / 2 - 22),
                (w - 12, h / 2, "c10"), (0, h / 2, "c")]
        rows = [(-h / 2 + 52 + 26 * r, w - (40 if r % 3 == 2 else 30)) for r in range(6)]
        text = d("Shape", *[smooth_path(d, [(28.0, y), (x1, y)], closed=False) for y, x1 in rows],
                 line(PAPER_TAN, 3), x=0.0, y=0.0, name=f"RiffleFlap{i}Text")
        flaps.append(N(f"RiffleFlap{i}", text,
                       S(f"RiffleFlap{i}Page", page, hfill(0, w, [(PAPER_TAN, 0), (PAPER, 0.35), ("FFEEE4D3", 1)]),
                         line(INK, 2)),
                       bind("unfold", 16, flipped(a, b, FLAP_TURN)),
                       bind("unfold", 18, window(a, a + FLAP_FADE * (b - a))),
                       x=0.0, y=cy - GROUND_Y, opacity=0.0))
    return N("BookRiffle", *flaps, x=0.0, y=0.0)


def settle_from(a: float, b: float) -> float:
    """Where the touchdown of window (a, b) starts."""
    return b - SETTLE_SHARE * (b - a)


def settle_dip(a: float, b: float) -> El:
    """A panel's scale: 1 + SETTLE_DIP until its touchdown, then down onto 1."""
    return conv_tokens(F.val(1 + SETTLE_DIP), F.op("-"), F.val(SETTLE_DIP), F.op("*"),
                       *window_tokens(settle_from(a, b), b))


def panel(name: str, *kids: El) -> El:
    """`Panel<name>`, pivoting on the vignette's floor at the gutter: flat behind the block (PANEL_FLAT) until its
    window of `unfold` opens, erect at its end. The rise ends SETTLE_TURN short of erect at the touchdown; the second
    term takes the last of the turn over the rest of the window, about five times slower, as its scale dips."""
    a, b = UNFOLD_PANELS[name]
    s, flat, dip = settle_from(a, b), round(PANEL_FLAT, 3), settle_dip(a, b)
    turn = conv_tokens(F.val(flat), F.op("-"), F.val(flat - SETTLE_TURN), F.op("*"), *window_tokens(a, s),
                       F.op("-"), F.val(SETTLE_TURN), F.op("*"), *window_tokens(s, b))
    return N(f"Panel{name}", *kids, bind("unfold", 15, turn), bind("unfold", 16, dip), bind("unfold", 17, dip), x=0.0,
             y=0.0, rotation=PANEL_FLAT, scaleX=1 + SETTLE_DIP, scaleY=1 + SETTLE_DIP)


def motes() -> El:
    """`emitBookMotes`: seven warm motes drifting up the shaft. Each rises MOTE_RISE px and fades in and out over
    the ambient loop, `MOTE_PHASE` frames after the one before (the portal sparks' stagger); it fades out before
    it drops back."""
    dots = []
    for i, (mx, my, size) in enumerate(MOTES):
        ph = i * MOTE_PHASE
        fade = cyclic([(0, 0.0), (40, 0.55), (90, 0.9), (170, 0.25), (228, 0.0)], ph)
        rise = cyclic([(0, 0.0), (228, -MOTE_RISE), (239, -MOTE_RISE)], ph)
        y0 = my - VIG_FLOOR
        dot = E(f"emitBookMote{i}", mx - BLOCK_X0, y0 + rise[0][1], size, size,
                light_glow(size / 2, stop("FFFFF8E6", 0), light_stop(0.45)),
                opacity=round(fade[0][1], 4))
        amb_tracks.append(track(d, dot, {"opacity": [(f, round(v, 4), EASE) for f, v in fade],
                                         "y": [(f, round(y0 + v, 3), "linear") for f, v in rise]}))
        dots.append(dot)
    return N("emitBookMotes", *dots, bind("unfold", 18, window(*UNFOLD_SHAFT)), x=0.0, y=0.0, opacity=0.0)


def vignette() -> El:
    """`BookVignette`, behind the page block (a panel flat behind it is hidden): the pop-up's supporting layers, all
    in the other scene's light. A paper floor slides out of the gutter, then three paper-cut layers rise from it,
    tallest at the gutter and first, each turning up about the floor's gutter end: `PanelFar` (a ridge in the
    vignette's ambient, its edge key-lit), `PanelMid` (hills, their crest key-lit) and `PanelNear` (the near ground
    and the destination's emblem). Behind them the book's light: a soft halo and a shaft rising from the gutter's
    mouth up-left, motes drifting up it."""
    # the ridge keeps right of the avatar's hair (x <= 557) above the hills' crest
    far = [(-116, 2, "c"), (-110, -40), (-96, -72), (-84, -112), (-76, -164), (-66, -194, "c6"), (-56, -184),
           (-46, -222), (-36, -252, "c6"), (-26, -240), (-14, -282), (-4, -304, "c6"), (0, -300, "c"), (0, 2, "c")]
    far_rim = [p[:2] for p in far[1:-2]]
    crest = [(-112, -44), (-98, -80), (-80, -98), (-60, -96), (-42, -118), (-24, -128), (-8, -140)]
    near = [(-118, 2, "c"), (-116, -12), (-98, -22), (-72, -18), (-46, -28), (-22, -26), (0, -34, "c"), (0, 2, "c")]
    floor = N("VignetteFloor",
              S("VignetteFloorSlab", [(0, -6, "c"), (-118, -6, "c3"), (-114, 3, "c3"), (0, 3, "c")], fill(PAPER_SHADE),
                line(INK, 2.5)),
              bind("unfold", 16, window(0.04, 0.2)), x=0.0, y=0.0, scaleX=0.0)
    # the light: a soft ray from the mouth (a radial glow squashed into a beam, leaning SHAFT_LEAN left) and a
    # halo behind the layers; both fade to nothing before the avatar's face box
    ray = N("emitBookShaftRay",
            E("emitBookShaftBeam", 0, 0, 600, 600, light_glow(300, light_stop(0), cy=170), opacity=0.78),
            x=-300 * math.sin(SHAFT_LEAN), y=-300 * math.cos(SHAFT_LEAN), rotation=-SHAFT_LEAN, scaleX=0.13)
    halo = N("emitBookHalo",
             E("emitBookHaloGlow", 0, 0, 380, 380, light_glow(190, light_stop(0)), opacity=0.66),
             x=-46.0, y=-190.0, scaleX=0.37)
    light = N("emitBookShaft", N("emitBookShaftBreath", ray, halo, x=0.0, y=0.0),
              bind("unfold", 18, window(*UNFOLD_SHAFT)), x=0.0, y=0.0, opacity=0.0)
    layers = [panel("Near", S("PanelNearGround", near, fill(PAPER), line(INK, 3)),
                    *[emblem(s, p) for s, p in zip(SCENES, DEST_PROPS)]),
              panel("Mid", S("PanelMidRim", [(x, y + 3) for x, y in crest],
                             vignette_line("vignetteKey", 4), closed=False),
                    S("PanelMidHills", [(-118, 2, "c"), *crest, (0, -138, "c"), (0, 2, "c")], fill(PAPER_TAN),
                      line(INK, 2.5))),
              panel("Far", S("PanelFarRim", far_rim, vignette_line("vignetteKey", 3), closed=False, opacity=0.7),
                    S("PanelFarRidge", far, vignette_fill("vignetteAmbient")))]
    layers[2].attrs["opacity"] = 0.55
    return N("BookVignette", motes(), floor, *layers, light, bind("unfold", 18, window(0.0, 0.05)), x=0.0,
             y=VIG_FLOOR - GROUND_Y, opacity=0.0)


def arch(hw: float, top: float) -> list:
    """A card's outline: from its foot (y 0), half its width `hw`, its arch at y -`top`."""
    return [(-hw, 0, "c"), (-hw, 75 - top), (11 - hw, 39 - top), (37 - hw, 11 - top), (0, -top), (hw - 37, 11 - top),
            (hw - 11, 39 - top), (hw, 75 - top), (hw, 0, "c")]


def sheared(name: str, k: float, *kids: El) -> El:
    """`kids` on a plane sheared y' = y + k x, the one foreshortening that keeps verticals vertical. Rive has no
    skew: a turn, a scale and a turn multiply into one (the 2 x 2 singular value decomposition)."""
    q, r, a0, a1 = math.hypot(1, k / 2), abs(k) / 2, math.atan2(k / 2, 0), math.atan2(k / 2, 1)
    return N(name, N(f"{name}Turn", *kids, rotation=(a1 - a0) / 2), rotation=(a1 + a0) / 2, scaleX=q + r, scaleY=q - r)


def hero_flat(scene: str, prop: str) -> El:
    """`Hero<Scene>`, on `prop`: the scene's emblem large, its foot behind the ground strip, and its back flat."""
    shapes = EMBLEMS[scene](Kit(scene, foil=False, prefix="Hero"))
    x0, y0, x1, y1 = glyph_box(shapes)
    s = round(min(HERO_EMBLEM[0] / (x1 - x0), HERO_EMBLEM[1] / (y1 - y0)), 4)
    cap, top = scene[0].upper() + scene[1:], HERO_BACKS[scene]
    return N(f"Hero{cap}",
             N(f"Hero{cap}Emblem", *shapes, x=round(-s * (x0 + x1) / 2, 3),
               y=round(-HERO_EMBLEM_FOOT - HERO_FLOAT.get(scene, 0.0) - s * y1, 3), scaleX=s, scaleY=s),
             S(f"Hero{cap}BackRim", [(p[0], p[1] + 2, *p[2:]) for p in top], vignette_line("vignetteKey", 3),
               closed=False),
             S(f"Hero{cap}Back", [(top[0][0], HERO_BACK_FOOT, "c"), *top, (top[-1][0], HERO_BACK_FOOT, "c")],
               vignette_fill("vignetteAmbient")),
             bind(prop, 18), x=0.0, y=0.0, opacity=0.0)


def hero() -> El:
    """`VignetteHero`, on the block's face: the other scene as a paper-cut card, the page's own pop-up, turned out
    from the gutter (`sheared`: its right side nearer, its foot falling away from the reach zone). A paper frame, a
    sky from the vignette's ambient down to its key, the scene's flat (nearer, so turned less: its objects stay
    upright) and the ground strip in front of it. It stands up off the page like the cover's swing, foreshortened
    (`HeroRise`: its height, a sine of the fold, about its foot, which keeps the card inside its resting outline, off
    the reach zone at every step), then touches down like the panels. Its light pools on the page behind it and
    breathes."""
    a, b = HERO_RISE
    s, hw = settle_from(a, b), HERO_HW - HERO_MAT
    sky = d("Fill", d("LinearGradient", light_stop(0.0, "vignetteAmbient"), light_stop(1.0), startX=0.0,
                      startY=HERO_MAT - HERO_TOP, endX=0.0, endY=-96.0), name="Fill")
    # the strip's top follows the flat's foot: thin at the card's left (its foot is highest there), deep at its right;
    # its ends are corners, flush with the card's edges (a smooth point would overshoot them)
    ground = [(-HERO_HW, 0, "c"), (-HERO_HW, -13, "c"), (-38, -24), (-4, -28), (32, -42), (HERO_HW, -47, "c"),
              (HERO_HW, 0, "c")]
    window_shape = S("HeroSky", arch(hw, HERO_TOP - HERO_MAT), sky)
    # the sky clips the flat, glows included: the card is a window, its outline bounds all of the hero's art
    rise = N("HeroRise",
             S("HeroGround", ground, fill(PAPER), line(INK, 3)),
             N("HeroClip", d("ClippingShape", sourceId=window_shape.ref(), name="Clip"),
               sheared("HeroFlat", HERO_FLAT_SHEAR - HERO_SHEAR,
                       *[hero_flat(scene, prop) for scene, prop in zip(SCENES, DEST_PROPS)]), x=0.0, y=0.0),
             window_shape,
             S("HeroMat", arch(HERO_HW, HERO_TOP), fill(PAPER), line(INK, 3)),
             bind("unfold", 17, conv_tokens(F.val(HERO_FOLDED), F.op("+"), F.val(1 - HERO_FOLDED), F.op("*"), *F.fn(
                 "sin", [F.val(PANEL_FLAT), F.op("*"), *window_tokens(a, s)]))),
             x=0.0, y=0.0, scaleY=HERO_FOLDED)
    pool = N("emitHeroGlow",
             N("emitHeroGlowBreath",
               E("emitHeroGlowPool", 0, 0, 360, 360, light_glow(180, light_stop(0.0)), opacity=0.6), x=0.0, y=0.0),
             bind("unfold", 18, window(a, b)), x=0.0, y=-191.0, scaleX=0.78, opacity=0.0)
    dip = settle_dip(a, b)
    turn = conv_tokens(F.val(SETTLE_TURN), F.op("-"), F.val(SETTLE_TURN), F.op("*"), *window_tokens(s, b))
    return N("VignetteHero", sheared("HeroPlane", HERO_SHEAR, rise), pool,
             bind("unfold", 18, window(a, a + HERO_FADE * (b - a))), bind("unfold", 15, turn), bind("unfold", 16, dip),
             bind("unfold", 17, dip), x=HERO_AT[0] - BLOCK_X0, y=HERO_AT[1] - GROUND_Y, rotation=SETTLE_TURN,
             scaleX=1 + SETTLE_DIP, scaleY=1 + SETTLE_DIP, opacity=0.0)


def book() -> El:
    """The standing pop-up storybook, its gutter on the threshold. Back to front: the vignette (behind the block,
    so a panel lying flat is hidden), the page block, the interior glow, the hero (on the block's face), the riffle,
    the cover (and its edge light), the floor spill, then the ribbon with the jacket, in front of everything (RML
    paints the first child in front), so the hook stays visible over the resting stub."""
    spill = E("emitBookSpill", 0, 20, 1040, 60, rfill(520, [("A0FFD49A", 0), ("00FFD49A", 1)], emit=True),
              bind("unfold", 18, conv(SPILL_PEAK)), bind("unfold", 16, conv(0.6, 0.4)), opacity=0.0, scaleX=0.4)
    root = N("Book", ribbon(), spill, cover_edge(), cover(), book_glow(), *page_block(),
             bind("book", 18), bind("book", 16, conv(0.08, 0.92)), bind("book", 17, conv(0.08, 0.92)),
             x=BLOCK_X0, y=GROUND_Y, opacity=0.0)
    # the riffle, the vignette, the medallion's glyphs and their ambient tracks mint after the book's own drawing
    # (its ids stay as they were) and slot in
    kids = root.children
    kids.insert(kids.index(named(root, "emitBookGlow")), riffle())
    kids.insert(kids.index(named(root, "BookBlock")) + 1, vignette())
    kids.insert(kids.index(named(root, "emitBookGlow")), hero())
    medal = named(root, "BookMedallion")
    medal.children[:0] = [medallion_glyph(s, p) for s, p in zip(SCENES, DEST_PROPS)]
    # the other scene's light: on the paper, the foil and the glows that come out of the book
    tinted(named(root, "BookVignette"), named(root, "VignetteHero"), medal)
    relit(spill, 0, 0.0)
    relit(named(root, "emitBookGlowCore"), 1, GUTTER_KEY_AT)
    amb_tracks.append(track(d, named(root, "emitBookGlow"), {"opacity": BREATH}, ease=EASE))
    amb_tracks.append(track(d, named(root, "emitBookShaftBreath"), {"opacity": BREATH}, ease=EASE))
    amb_tracks.append(track(d, named(root, "emitHeroGlowBreath"), {"opacity": BREATH}, ease=EASE))
    flicker = [1.0, 1.1, 0.94, 1.08, 0.97, 1.12, 0.95, 1.06]
    for name, k in (("emitVignetteCampfireFlame", 1.0), ("emitVignetteLibraryFlame", 0.6),
                    ("emitHeroCampfireFlame", 1.0), ("emitHeroLibraryFlame", 0.6)):
        amb_tracks.append(track(d, named(root, name), {"scaleY": [
            (f, round(1 + k * (flicker[(f // 8) % len(flicker)] - 1), 4) if f < AMB_FRAMES else 1.0)
            for f in range(0, AMB_FRAMES + 1, 8)]}))
    for name in ("emitVignetteDeepSpaceStar", "emitHeroDeepSpaceStar"):
        amb_tracks.append(track(d, named(root, name), {"opacity": [
            (0, 1.0), (50, 0.5), (110, 1.0), (170, 0.65), (240, 1.0)]}, ease=EASE))
    # The floor spill widens and brightens with the vignette and lands with it, by UNFOLD_LANDED: its two binds take
    # windowed converters (an attribute change on the book's own binds, the converters minted last, like `relit`'s
    # binds, so no id moves; the two linear ones they replace keep their ids, unused).
    binds = {int(b.attrs["propertyKey"]): b for b in spill.children if b.tag == "DataBindContext"}
    binds[18].attrs["converterId"] = windowed(0.0, UNFOLD_LANDED, SPILL_PEAK).ref()
    binds[16].attrs["converterId"] = windowed(0.0, UNFOLD_LANDED, 0.6, 0.4).ref()
    return root


# ---------------------------------------------------------------- book polish (v16; minted after the book, so its ids stay)

PAGE_X0, PAGE_X1, PAGE_TOP = 6.0, BLOCK_W - 14.0, BLOCK_TOP + 12.0   # the page face on the block (local)
# the story's lines on the right page, under the hero's floor and right of the hook zone (local x, y, length)
TEXT_ROWS = tuple((86.0 if i == 0 else 50.0, -404.0 + 36.0 * i, (300.0, 360.0, 352.0, 330.0, 364.0, 210.0, 0.0,
                                                                  340.0, 356.0, 280.0)[i]) for i in range(10))


def book_polish(root: El) -> None:
    """v16: the open book reads as a book. The block's face is a page (paper, the gutter's shadow, a drop cap and the
    story's lines, the fore-edge of the page stack showing past the closed cover), lit by the scene's key; the cover
    gets a gilt corner and a foil title plate."""
    kids = root.children
    slab = named(root, "BookBlock")
    page = S("BookPage", [(PAGE_X0, BLOCK_BOTTOM, "c"), (PAGE_X0, PAGE_TOP, "c"), (PAGE_X1, PAGE_TOP, "c46"),
                          (PAGE_X1, BLOCK_BOTTOM, "c")],
             hfill(PAGE_X0, PAGE_X1, [("FFCDBFA6", 0), (PAPER_SHADE, 0.07), (PAPER, 0.2), ("FFEFE6D6", 0.88),
                                      ("FFE0D3BE", 1)]), line(INK, 3))
    fore = [S(f"BookForeEdge{i}", [(PAGE_X1 - 4 - 5 * i, PAGE_TOP + 30 + 4 * i), (PAGE_X1 - 4 - 5 * i, 30)],
              line("FFC9B79A", 1.5), closed=False) for i in range(4)]
    cap = N("BookDropCap",
            S("BookDropCapLeaf", [(8, 30), (18, 12), (28, 30), (18, 22)], fill(FOIL_INK)),
            R("BookDropCapPlate", 18, 20, 44, 44, 6, fill(FOIL), line(FOIL_INK, 2.5)),
            x=40.0, y=-432.0)
    rows = [S(f"BookTextRow{i}", [(x, y), (x + ln, y)], line("FFB5A286", 6), closed=False)
            for i, (x, y, ln) in enumerate(TEXT_ROWS) if ln]
    tint = S("BookPageKeyTint", [(PAGE_X0, BLOCK_BOTTOM, "c"), (PAGE_X0, PAGE_TOP, "c"), (PAGE_X1, PAGE_TOP, "c46"),
                                 (PAGE_X1, BLOCK_BOTTOM, "c")],
             bound_fill("lightKey", SCENES["livingRoom"].key), blendModeValue=MULTIPLY, opacity=0.22)
    at = kids.index(slab)
    kids[at:at] = [tint, *rows, cap, *fore, page]
    # the cover: gilt corners on its free edge, raised bands on the spine, a title plate
    outer = named(root, "CoverOuter")
    leather = named(root, "CoverLeather")
    corner = S("CoverCorner", [(COVER_LEN - 74, COVER_TOP - 2, "c"), (COVER_LEN - COVER_CORNER, COVER_TOP - 2),
                               (COVER_LEN + 2, COVER_TOP + COVER_CORNER), (COVER_LEN + 2, COVER_TOP + 74, "c"),
                               (COVER_LEN - 30, COVER_TOP + 30, "c")],
               vfill(COVER_TOP, COVER_TOP + 74, [("FFF0D088", 0), (FOIL, 0.5), (FOIL_SHADE, 1)]), line(INK, 3))
    stud = E("CoverCornerStud", COVER_LEN - 22, COVER_TOP + 22, 12, 12, fill(FOIL_SHADE), line(INK, 2))
    tx = (MEDALLION_X + MEDALLION_R - BLOCK_X0 + 15 + COVER_LEN - 40) / 2   # the tooled frame's middle
    plate = N("CoverTitle",
              *[S(f"CoverTitleRow{i}", [(-w / 2, y), (w / 2, y)], line(FOIL, 5), closed=False)
                for i, (w, y) in enumerate(((120.0, -10.0), (80.0, 10.0)))],
              R("CoverTitleInner", 0, 0, 168, 58, 10, line(FOIL, 2)),
              R("CoverTitlePlate", 0, 0, 184, 74, 14, fill("FF4A2C20"), line(FOIL, 3)),
              S("CoverFleuron", [(-30, 70), (0, 58), (30, 70), (0, 82)], fill(FOIL), line(FOIL_INK, 1.5)),
              x=tx, y=COVER_TOP + 130)
    at = outer.children.index(leather)
    outer.children[at:at] = [stud, corner, plate]


# ---------------------------------------------------------------- path (anchor: bottom centre)

PATH_X = THRESHOLD_X + 220.0   # the bush's left edge sits on the threshold


LEAF_DARK, LEAF_MID, LEAF, LEAF_LIGHT, LEAF_TIP = "FF16302A", "FF24483A", "FF356848", "FF4E8A5A", "FF7AB26E"
# the thicket's silhouette (local; the ground is y 0) and the tunnel through it
THICKET = [(-232, 30), (-240, -260), (-214, -470), (-228, -640), (-160, -820), (-40, -905), (90, -880), (196, -780),
           (238, -600), (256, -360), (248, 30)]
TUNNEL = [(-150, 30), (-142, -400), (-96, -620), (-12, -690), (68, -632), (112, -420), (124, 30)]
CLUSTERS = ((-176, -770, 118), (-40, -860, 96), (80, -810, 124), (190, -620, 112), (-200, -560, 104),
            (206, -380, 104), (-210, -330, 96), (214, -150, 96))
FRONDS = (   # base x, length, lean, part, curl (the left ones part only a little: they must not sweep over the avatar)
    (-176, 440, -0.14, -0.06, -0.3), (-112, 540, -0.05, -0.1, -0.25), (-30, 520, 0.06, 0.42, 0.35),
    (60, 560, 0.16, 0.56, 0.45), (150, 500, 0.3, 0.52, 0.55), (226, 420, 0.48, 0.38, 0.6))
LANTERN_AT = (-150.0, -560.0)  # hung from the arch's left bough: artboard (710, 440), inside the portrait band
FIREFLIES = ((-60, -300), (20, -420), (-30, -520), (60, -250), (-90, -180), (40, -560))


def catmull(pts: list, closed: bool, per: int = 8) -> list[tuple[float, float]]:
    """A dense Catmull-Rom curve through `pts`."""
    p = [(float(a), float(b)) for a, b, *_ in pts]
    n = len(p)
    out = []
    segs = n if closed else n - 1
    for i in range(segs):
        p0 = p[(i - 1) % n] if closed else p[max(i - 1, 0)]
        p1, p2 = p[i], p[(i + 1) % n]
        p3 = p[(i + 2) % n] if closed else p[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    if not closed:
        out.append(p[-1])
    return out


def scalloped(pts: list, step: float, height: float, closed: bool = True, seed: float = 0.0,
              ends: bool = False) -> list:
    """A leafy edge along the curve through `pts`: corner notches every `step` px with a rounded lobe pushed
    `height` px outwards (negative: inwards) between them. `ends`: the open curve's ends are kept as corners."""
    dense = catmull(pts, closed)
    seg = list(zip(dense, dense[1:] + ([dense[0]] if closed else [])))
    total = sum(math.dist(a, b) for a, b in seg)
    n = max(2, round(total / step))
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in seg)
    sign = 1.0 if area > 0 else -1.0

    def at(s: float) -> tuple[float, float, float, float]:
        for a, b in seg:
            ln = math.dist(a, b)
            if s <= ln or (a, b) == seg[-1]:
                u = min(1.0, s / ln) if ln else 0.0
                return a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
            s -= ln
        raise AssertionError

    out = []
    for i in range(n if closed else n + 1):
        x, y, _, _ = at(total * i / n)
        out.append((x, y, "c"))
        if i < n:
            mx, my, tx, ty = at(total * (i + 0.5) / n)
            h = height * (1 + 0.25 * math.sin(i * 2.7 + seed))
            out.append((mx + sign * ty * h, my - sign * tx * h))
    return out


def leaf_cluster(name: str, cx: float, cy: float, r: float, i: int) -> El:
    """A rounded clump of leaves, lit from the top left: a scalloped disc, its rim in the scene's key light."""
    ring = [(cx + r * math.cos(a), cy + r * 0.86 * math.sin(a)) for a in (k * math.tau / 7 + i for k in range(7))]
    rim = S(f"{name}Rim", [(cx - r * math.cos(a) * 0.98, cy - r * 0.86 * math.sin(a) * 0.98)
                          for a in (math.radians(v) for v in (-10, 20, 45, 70, 100))],
            bound_line("lightKey", 4, SCENES["campfire"].key), closed=False, opacity=0.5)
    clump = S(f"{name}Clump", scalloped(ring, 54, 16, seed=i),
              vfill(cy - r, cy + r, [(LEAF_LIGHT, 0), (LEAF, 0.5), (LEAF_MID, 1)]), line(INK, 3))
    return N(name, rim, clump, x=0.0, y=0.0)


def leaf(name: str, cx: float, cy: float, length: float, width: float, angle: float, tone: str) -> El:
    ca, sa = math.cos(angle), math.sin(angle)

    def p(u: float, v: float, *c: str) -> tuple:
        return (cx + u * ca - v * sa, cy + u * sa + v * ca, *c)

    return S(name, [p(0, 0, "c"), p(length * 0.45, width / 2), p(length, 0, "c"), p(length * 0.45, -width / 2)],
             fill(tone), line(INK, 2))


def fern(name: str, length: float, curl: float, pinnae: int = 11) -> list[El]:
    """A fern frond (its base at the origin, growing up): a curving rachis with pinnae on both sides, as one
    serrated outline, and the rachis drawn over it."""
    def c(t: float) -> tuple[float, float, float, float]:
        x, y = curl * length * 0.35 * t * t, -length * t
        dx, dy = curl * length * 0.7 * t, -length
        ln = math.hypot(dx, dy)
        return x, y, dx / ln, dy / ln

    left, right = [], []
    for k in range(pinnae):
        t = 0.1 + 0.84 * k / pinnae
        x, y, tx, ty = c(t)
        nx, ny = -ty, tx
        size = length * 0.19 * math.sin(math.pi * (0.3 + 0.7 * t)) ** 0.7 * (1.08 - 0.7 * t)
        for side, out in ((1, left), (-1, right)):
            ux, uy = side * nx * 0.85 + tx * 0.5, side * ny * 0.85 + ty * 0.5   # out and up along the frond
            out.append((x + side * nx * 2, y + side * ny * 2, "c"))
            # the leaflet's rounded tip, a little up the frond from its notch
            out.append((x + ux * size + tx * size * 0.12, y + uy * size + ty * size * 0.12))
    tip = c(1.0)
    base = [(-6, 0, "c"), (6, 0, "c")]
    outline = [base[1], *[(p[0], p[1], *p[2:]) for p in right], (tip[0], tip[1], "c"), *reversed(left), base[0]]
    rach = [c(t)[:2] for t in (0.0, 0.3, 0.6, 0.9, 1.0)]
    return [S(f"{name}Rachis", rach, line("FF6E9A5A", 3), closed=False),
            S(f"{name}Blade", outline, vfill(-length, 0, [(LEAF_TIP, 0), (LEAF_LIGHT, 0.4), (LEAF_MID, 1)]),
              line(INK, 2.5))]


def sway(node: El, amp: float, phase: int, period: int = AMB_FRAMES) -> None:
    """A gentle rotation sway about the node's rest angle on the ambient loop (whole cycles: seamless)."""
    rest = float(node.attrs.get("rotation") or 0.0)
    cycles = AMB_FRAMES // period
    keys = [(f, round(rest + amp * math.sin(math.tau * cycles * f / AMB_FRAMES + phase), 4))
            for f in range(0, AMB_FRAMES, 20)]
    amb_tracks.append(track(d, node, {"rotation": keys + [(AMB_FRAMES, keys[0][1])]}, ease=EASE))


def lantern() -> El:
    """A paper-and-tin lantern hung from the bough: warm whatever the hour, flickering a little."""
    glow = E("emitPathLanternGlow", 0, 10, 380, 380, rfill(190, [("A0FFD08A", 0), ("40FFB060", 0.4), ("00FF9A50", 1)],
                                                         emit=True), blendModeValue=SCREEN)
    amb_tracks.append(track(d, glow, {"opacity": [(0, 0.9), (30, 1.0), (52, 0.82), (90, 1.0), (130, 0.88), (170, 1.0),
                                                  (205, 0.85), (AMB_FRAMES, 0.9)]}, ease=EASE))
    body = N("PathLanternBody",
             S("PathLanternRibs", [(-14, -8), (-14, 30)], line("FF6A4A36", 2), closed=False),
             S("PathLanternRibs2", [(14, -8), (14, 30)], line("FF6A4A36", 2), closed=False),
             R("emitPathLanternPaper", 0, 11, 44, 48, 14,
               rfill(30, [("FFFFF6D8", 0), ("FFFFD48A", 0.6), ("FFF0A060", 1)], emit=True), line(INK, 2.5)),
             S("PathLanternCap", [(-18, -12, "c"), (18, -12, "c"), (10, -24, "c"), (-10, -24, "c")],
               fill("FF5A4636"), line(INK, 2.5)),
             R("PathLanternBase", 0, 38, 30, 8, 3, fill("FF5A4636"), line(INK, 2)),
             S("PathLanternHook", [(0, -24), (0, -70)], line("FF3A2E28", 3), closed=False),
             x=0.0, y=0.0)
    sway(body, 0.05, 1)
    return N("PathLantern", body, glow, x=LANTERN_AT[0], y=LANTERN_AT[1])


def path() -> El:
    """The thicket (v16): a leafy mass with a tunnel through it, clumps lit by the scene's key, a lantern on the
    left bough and ferns in front. `open` parts the ferns (with a little follow-through) and lights the far end
    of the tunnel in the vignette's key (the scene beyond); fireflies drift in the tunnel, the ferns, vines and
    lantern sway on the loop. `path` grows it in: the ferns spring up one after the other."""
    fronds = []
    for i, (bx, length, lean, part, curl) in enumerate(FRONDS):
        inner = N(f"PathFernSway{i}", *fern(f"PathFern{i}", length, curl), x=0.0, y=0.0)
        sway(inner, 0.025 + 0.01 * (i % 3), i * 2)
        a, b = 0.12 * i / len(FRONDS), 0.5 + 0.5 * i / len(FRONDS)
        part_tokens = [F.val(lean), F.op("+"), F.val(part), F.op("*"), *F.inp(), F.op("+"), F.val(0.16 * part),
                       F.op("*"), *bump_tokens(0.0, 1.0)]
        fronds.append(N(f"PathFern{i}Node", N(f"PathFernGrow{i}", inner, bind("path", 17, windowed(a, b, 0.75, 0.25)),
                                               x=0.0, y=0.0, scaleY=0.25),
                        bind("open", 15, conv_tokens(*part_tokens)), x=float(bx), y=6.0, rotation=lean))
    # the leaves the parting ferns knock loose: they flick out and settle back as the ferns pass
    loose = []
    for i, (lx, ly, dx, dy, ang) in enumerate(((-40, -420, -60, -40, -0.8), (60, -500, 90, -30, 0.6),
                                               (20, -300, 70, 50, 1.4), (-10, -560, -30, -70, -1.6))):
        lf = leaf(f"PathLoose{i}", 0, 0, 34, 16, ang, LEAF_LIGHT)
        loose.append(N(f"PathLooseNode{i}", lf, bind("open", 18, bump(0.05, 0.95)),
                       bind("open", 13, conv_tokens(F.val(lx), F.op("+"), F.val(dx), F.op("*"), *bump_tokens(0.05, 0.95))),
                       bind("open", 14, conv_tokens(F.val(ly), F.op("+"), F.val(dy), F.op("*"), *bump_tokens(0.05, 0.95))),
                       bind("open", 15, conv(3.0, ang)), x=float(lx), y=float(ly), opacity=0.0))
    # the far end: the scene beyond glows through the tunnel, its light running along the ground towards us
    far = N("emitPathFar",
            E("emitPathFarLight", -10, -230, 300, 520, light_glow(260, light_stop(0.0), stop("C0FFF4E4", 0.15),
                                                                   stop("50FFF4E4", 0.6), cy=60)),
            S("emitPathTrail", [(-60, -120), (40, -120), (150, 30), (-180, 30)],
              d("Fill", d("LinearGradient", light_stop(0.0), stop("00FFF4E4", 1.0), startX=0.0, startY=-120.0,
                          endX=0.0, endY=30.0), name="Fill"), opacity=0.55),
            *[S(f"emitPathRay{i}", [(x0, -330), (x0 + 30, -330), (x1 + w, 20), (x1, 20)],
                d("Fill", d("LinearGradient", light_stop(0.0), stop("00FFF4E4", 1.0), startX=0.0, startY=-330.0,
                            endX=0.0, endY=20.0), name="Fill"), opacity=0.25)
              for i, (x0, x1, w) in enumerate(((-60, -170, 50), (-10, -40, 60), (30, 90, 50)))],
            bind("open", 18, conv(0.8, 0.2)), x=0.0, y=0.0, opacity=0.2)
    flies = []
    for i, (fx, fy) in enumerate(FIREFLIES):
        fly = E(f"emitPathFirefly{i}", fx, fy, 22, 22, rfill(11, [("FFFFFFD0", 0), ("A0E8FF8A", 0.35), ("00C8F07A", 1)],
                                                             emit=True), opacity=0.0)
        ph = i * 41
        amb_tracks.append(track(d, fly, {
            "x": [(f, round(fx + 18 * math.sin(math.tau * f / AMB_FRAMES + i), 2)) for f in range(0, AMB_FRAMES, 20)]
            + [(AMB_FRAMES, round(fx + 18 * math.sin(i), 2))],
            "y": [(f, round(fy + 14 * math.sin(2 * math.tau * f / AMB_FRAMES + i * 1.7), 2))
                  for f in range(0, AMB_FRAMES, 15)] + [(AMB_FRAMES, round(fy + 14 * math.sin(i * 1.7), 2))],
            "opacity": cyclic([(0, 0.0), (40, 1.0), (80, 0.3), (120, 0.9), (170, 0.0), (AMB_FRAMES - 1, 0.0)], ph)}))
        flies.append(fly)
    tunnel = S("PathTunnel", scalloped(TUNNEL, 52, -16, closed=False),
               vfill(-690, 30, [("FF0A1412", 0), ("FF12201C", 0.6), ("FF1A2C24", 1)]), line(INK, 4))
    vines = []
    for i, (vx, vy, ln) in enumerate(((-100, -610, 150), (-30, -680, 210), (50, -640, 170), (100, -470, 120))):
        lv = [leaf(f"PathVine{i}Leaf{k}", (-1) ** k * 3, ln * (k + 1) / 5, 26, 13, math.pi / 2 + (-1) ** k * 0.9,
                   LEAF if k % 2 else LEAF_LIGHT) for k in range(4)]
        vine = N(f"PathVine{i}", *lv, S(f"PathVine{i}Stem", [(0, 0), (6, ln * 0.5), (0, ln)], line("FF2E5040", 3),
                                        closed=False), x=float(vx), y=float(vy))
        sway(vine, 0.06, i * 3)
        vines.append(vine)
    clumps = [leaf_cluster(f"PathClump{i}", cx, cy, r, i) for i, (cx, cy, r) in enumerate(CLUSTERS)]
    flowers = []
    for i, (fx, fy, tone) in enumerate(((-190, -700, "FFF2B8C6"), (150, -720, "FFF6E2A8"), (-206, -450, "FFF6E2A8"),
                                        (196, -500, "FFF2B8C6"), (-150, -860, "FFF6F0E2"), (220, -260, "FFF6F0E2"))):
        petals = [E(f"PathFlower{i}Petal{k}", fx + 9 * math.cos(k * math.tau / 5), fy + 9 * math.sin(k * math.tau / 5),
                    14, 14, fill(tone), line(INK, 1.5)) for k in range(5)]
        flowers.append(N(f"PathFlower{i}", E(f"PathFlower{i}Heart", fx, fy, 8, 8, fill("FFE0A040")), *petals,
                         x=0.0, y=0.0))
    mass = S("PathThicket", scalloped(THICKET, 70, 22, closed=False),
             vfill(-905, 30, [("FF2A5040", 0), ("FF1E3C30", 0.5), (LEAF_DARK, 1)]), line(INK, 5))
    key_tint = S("PathKeyTint", THICKET, bound_fill("lightKey", SCENES["campfire"].key), blendModeValue=MULTIPLY,
                 opacity=0.18)
    stones = [E(f"PathStone{i}", cx, cy, w, h, vfill(-h / 2, h / 2, [("FF7A7684", 0), ("FF4E4A58", 1)]), line(INK, 2.5))
              for i, (cx, cy, w, h) in enumerate([(-200, 18, 96, 34), (-120, 26, 60, 22), (150, 22, 80, 28)])]
    shadow = E("PathShadow", 0, 18, 560, 60, rfill(280, [("60100C14", 0), ("00100C14", 1)]))
    return N("Path", *fronds, *loose, *stones, lantern(), *flowers, *clumps, key_tint, *vines, *flies, far, tunnel,
             mass, shadow,
             bind("path", 18, window(0.0, 0.5)), bind("path", 16, conv(0.06, 0.94)), bind("path", 17, conv(0.06, 0.94)),
             x=PATH_X, y=GROUND_Y, opacity=0.0)


# ---------------------------------------------------------------- portal (anchor: ring centre)

RING_W, RING_H = 330.0, 900.0
PORTAL_X, PORTAL_Y = THRESHOLD_X - 10.0 + RING_W / 2, GROUND_Y - RING_H / 2 - 30.0


MULTIPLY = 24                # Rive's multiply blend: a wash that only darkens (and tints)
SCREEN = 14                  # Rive's screen blend (native 0.1.11 rejects additive): light that only brightens
PORTAL_R = RING_H / 2 - 9.0  # the mouth's radius in the unsquashed (circle) space of the vortex
SQUASH = RING_W / RING_H     # circle space -> the ring's ellipse
PORTAL_ARMS = 7              # the vortex's broad arms (one turn per loop); the fine ones turn twice as fast
TUNNEL_RINGS = 5             # rings flying into the tunnel, one every AMB_FRAMES / TUNNEL_RINGS
PORTAL_MOTES = 9             # sparks drawn in along the spiral
VIOLET_DEEP, VIOLET, LAVENDER, PALE, HOT = "FF140E2E", "FF3A2A7A", "FFB79CFF", "FFE6DCFF", "FFFFF8FF"


def bump_tokens(a: float, b: float) -> list[El]:
    """`sin(pi window(a, b))`: 0 up to `a` and from `b`, 1 halfway (a flash, a rustle, a puff)."""
    return F.fn("sin", [F.val(math.pi), F.op("*"), *window_tokens(a, b)])


def bump(a: float, b: float, k: float = 1.0) -> El:
    key = ("bump", round(a, 3), round(b, 3), round(k, 3))
    if key not in _windows:
        _windows[key] = conv_tokens(F.val(k), F.op("*"), *bump_tokens(a, b))
    return _windows[key]


def spiral_arm(name: str, a0: float, turn: float, r0: float, r1: float, wmax: float, paint: El, n: int = 12) -> El:
    """A tapered arm of the vortex (circle space): from the rim at angle a0 curling `turn` rad inwards to r0."""
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        r = r1 + (r0 - r1) * t
        th = a0 + turn * t
        w = wmax * math.sin(math.pi * (0.08 + 0.92 * t)) ** 0.75 * (1 - 0.55 * t)
        dx = (r0 - r1) * math.cos(th) - r * turn * math.sin(th)
        dy = (r0 - r1) * math.sin(th) + r * turn * math.cos(th)
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln, dx / ln
        cx, cy = r * math.cos(th), r * math.sin(th)
        left.append((cx + nx * w / 2, cy + ny * w / 2))
        right.append((cx - nx * w / 2, cy - ny * w / 2))
    pts = [left[0] + ("c",), *left[1:-1], (r0 * math.cos(a0 + turn), r0 * math.sin(a0 + turn), "c"), *right[-2:0:-1]]
    return S(name, pts, paint)


def spin(node: El, turns: float) -> None:
    """`turns` whole turns of `node` per ambient loop (negative: anticlockwise), linear, seamless."""
    amb_tracks.append(track(d, node, {"rotation": [(0, float(node.attrs.get("rotation") or 0.0), "linear"),
                                                   (AMB_FRAMES, float(node.attrs.get("rotation") or 0.0)
                                                    + turns * math.tau, "linear")]}))


def portal() -> El:
    """The rift (v16): it tears open as a vertical blade of light and widens into a violet ring (`portal`); behind
    the ring a vortex turns and, with `open`, irises into a tunnel of rings flying away towards the far scene's
    light (the vignette's key, written for every family since v16). Comets run round the rim, sparks are drawn in
    along the spiral, and the ring lights the ground and washes the avatar's side (screen)."""
    sq = dict(scaleX=SQUASH, scaleY=1.0)
    # the vortex, in circle space: broad arms (one turn a loop), fine bright ones (two), anticlockwise inwards
    broad = N("emitPortalArms", *[spiral_arm(f"emitPortalArm{i}", i * math.tau / PORTAL_ARMS, 2.9, 20, PORTAL_R + 40,
                                             150, rfill(PORTAL_R, [("00B79CFF", 0.0), ("489A80F0", 0.35),
                                                                   ("607A5CE0", 0.7), ("205A44C0", 1.0)], emit=True))
                                  for i in range(PORTAL_ARMS)], x=0.0, y=0.0)
    fine = N("emitPortalStreaks", *[spiral_arm(f"emitPortalStreak{i}", 0.6 + i * math.tau / 3, 3.4, 24, PORTAL_R + 20,
                                               26, rfill(PORTAL_R, [("00FFF8FF", 0.0), ("D0E6DCFF", 0.4),
                                                                    ("70D9CCFF", 0.8), ("10B79CFF", 1.0)], emit=True))
                                    for i in range(3)], x=0.0, y=0.0)
    spin(broad, -1)
    spin(fine, -2)
    # open twists the arms a quarter turn further in and swells them: the iris
    vortex = N("emitPortalVortex", fine, broad, bind("open", 15, conv(-1.2)), bind("open", 16, conv(0.18, 1.0)),
               bind("open", 17, conv(0.18, 1.0)), x=0.0, y=0.0)
    # the tunnel: rings that shrink away into the light, one after the other
    rings = []
    for i in range(TUNNEL_RINGS):
        ring_i = E(f"emitPortalTunnel{i}", 0, 0, 2 * PORTAL_R, 2 * PORTAL_R, line("FFD9CCFF", 9, emit=True),
                   scaleX=1.0, scaleY=1.0, opacity=0.0)
        ph = i * AMB_FRAMES // TUNNEL_RINGS
        sizes = [(f, round(0.06 + 0.94 * (1 - f / AMB_FRAMES) ** 2.2, 4)) for f in range(0, AMB_FRAMES, 24)]
        sizes.append((AMB_FRAMES - 1, 0.06))
        alpha = [(0, 0.0), (36, 0.75), (150, 0.55), (220, 0.0), (AMB_FRAMES - 1, 0.0)]
        amb_tracks.append(track(d, ring_i, {"scaleX": cyclic(sizes, ph), "scaleY": cyclic(sizes, ph),
                                            "opacity": cyclic(alpha, ph)}))
        rings.append(ring_i)
    # sparks drawn in along the spiral: each rides a turning arm from the rim to the core
    motes = []
    for i in range(PORTAL_MOTES):
        ph = (i * 97) % AMB_FRAMES
        mote = star4(f"emitPortalMote{i}", 0, 0, 9 + 4 * (i % 3), HOT)
        mote.attrs.update(x=PORTAL_R, scaleX=1 / SQUASH * 0.6, opacity=0.0)
        radius = [(0, PORTAL_R - 20), (120, PORTAL_R * 0.45), (200, PORTAL_R * 0.16), (AMB_FRAMES - 1, 20.0)]
        alpha = [(0, 0.0), (30, 1.0), (170, 0.8), (225, 0.0), (AMB_FRAMES - 1, 0.0)]
        amb_tracks.append(track(d, mote, {"x": cyclic(radius, ph), "opacity": cyclic(alpha, ph)}))
        arm = N(f"emitPortalMoteArm{i}", mote, x=0.0, y=0.0, rotation=i * 2.39996)
        spin(arm, -1)
        motes.append(arm)
    core = E("emitPortalCore", 0, 0, 2 * PORTAL_R, 2 * PORTAL_R,
             light_glow(PORTAL_R, light_stop(0.0), stop("FFF3ECFF", 0.12), stop("C0B79CFF", 0.42), stop("40B79CFF", 0.75)))
    # the light at the end of the tunnel and the rings fly in only as the mouth opens
    tunnel = N("emitPortalTunnel", *motes, *rings, core, bind("open", 18, window(0.1, 0.8)),
               bind("open", 16, conv(0.85, 0.15)), bind("open", 17, conv(0.85, 0.15)),
               x=0.0, y=0.0, opacity=0.0, scaleX=0.15, scaleY=0.15)
    mouth = E("emitPortalMouth", 0, 0, 2 * PORTAL_R * SQUASH, 2 * PORTAL_R,
              rfill(PORTAL_R, [("FF3A2A7A", 0), ("FF241A58", 0.55), (VIOLET_DEEP, 1)], emit=True))
    inside = N("PortalInside", d("ClippingShape", sourceId=mouth.ref(), name="Clip"),
               N("emitPortalSquash", tunnel, vortex, x=0.0, y=0.0, **sq), x=0.0, y=0.0)
    # the rim: an ink edge, a lavender band lit from above, a white-hot inner lip, comets running round it
    ring = E("emitPortalRing", 0, 0, RING_W, RING_H,
             d("Stroke", lin(d, 0, -RING_H / 2, 0, RING_H / 2, [(PALE, 0), (LAVENDER, 0.45), ("FF8E6AF0", 1)]),
               thickness=20.0, cap="round", join="round", name="Line"))
    ink = E("PortalInk", 0, 0, RING_W + 24, RING_H + 24, line(INK, 3), opacity=0.55)
    lip = E("emitPortalRingHi", 0, 0, RING_W - 14, RING_H - 14, line(HOT, 3, emit=True))
    comets = []
    for i, (length, width, start, laps) in enumerate(((0.11, 9, 0.0, 1), (0.06, 6, 0.42, 1), (0.16, 5, 0.7, 2))):
        trim = d("TrimPath", start=0.0, end=length, offset=start, modeValue=1)
        comets.append(E(f"emitPortalComet{i}", 0, 0, RING_W + 2, RING_H + 2,
                        d("Stroke", d("SolidColor", colorValue=HOT), trim, thickness=float(width), cap="round",
                          join="round", name="Line")))
        amb_tracks.append(track(d, trim, {"offset": [(0, start, "linear"), (AMB_FRAMES, start - laps, "linear")]}))
    sparks = []
    for i, ang in enumerate((-2.2, -1.25, -0.4, 0.55, 1.5, 2.45, 3.1)):
        sx, sy = (RING_W / 2 + 18) * math.cos(ang), (RING_H / 2 + 18) * math.sin(ang)
        sp = star4(f"emitPortalSpark{i}", sx, sy, 13 + 6 * (i % 2), HOT)
        ph = (i * 53) % AMB_FRAMES
        amb_tracks.append(track(d, sp, {"opacity": cyclic([(0, 0.0), (18, 1.0), (50, 0.0), (AMB_FRAMES - 1, 0.0)], ph),
                                        "rotation": [(0, 0.0, "linear"), (AMB_FRAMES, math.tau, "linear")]}))
        sparks.append(sp)
    halo = E("emitPortalGlow", 0, 0, RING_W + 220, RING_H + 220,
             rfill((RING_H + 220) / 2, [("00B79CFF", 0.62), ("90B79CFF", 0.82), ("00B79CFF", 1)], emit=True))
    amb_tracks.append(track(d, halo, {"opacity": BREATH}, ease=EASE))
    grow = N("PortalGrow", *sparks, *comets, lip, ring, ink, inside, mouth, halo,
             bind("portal", 16, conv_tokens(*F.inp(), F.op("*"), *F.inp(), F.op("+"), F.val(0.22), F.op("*"),
                                            *bump_tokens(0.35, 1.0))),
             bind("portal", 17, conv_tokens(*clamp01(F.val(1.6), F.op("*"), *F.inp()))),
             x=0.0, y=0.0, scaleX=0.0, scaleY=0.0)
    # the tear: a blade of white light down the middle while the rift opens (and as it collapses)
    blade = E("emitPortalTearBlade", 0, 0, 34, RING_H + 60,
              vfill(-(RING_H + 60) / 2, (RING_H + 60) / 2, [("00FFF8FF", 0), (HOT, 0.2), (HOT, 0.8), ("00FFF8FF", 1)],
                    emit=True))
    bloom = E("emitPortalTearBloom", 0, 0, 260, 260,
              rfill(130, [("E0E6DCFF", 0), ("60B79CFF", 0.55), ("00B79CFF", 1)], emit=True), scaleY=(RING_H + 200) / 260)
    tear = N("emitPortalTear", blade, bloom, bind("portal", 18, bump(0.0, 0.8)),
             bind("portal", 17, conv_tokens(*clamp01(F.val(2.2), F.op("*"), *F.inp()))), x=0.0, y=0.0,
             opacity=0.0, scaleY=0.0)
    # the light it throws: a wash over everything near it (the avatar's right side, the floor) and a pool at its foot
    spill = E("emitPortalSpill", -60, 40, 1500, 1500,
              rfill(750, [("70A88CFF", 0), ("28A88CFF", 0.45), ("00A88CFF", 1)], emit=True),
              bind("open", 18, conv(0.5, 0.5)), blendModeValue=SCREEN, opacity=0.5)
    ground = E("emitPortalGround", 0, GROUND_Y - PORTAL_Y - 6, RING_W + 360, 90,
               rfill(230, [("A0C8B4FF", 0), ("40B79CFF", 0.5), ("00B79CFF", 1)], emit=True), blendModeValue=SCREEN)
    return N("Portal", tear, grow, ground, spill, bind("portal", 18), x=PORTAL_X, y=PORTAL_Y, opacity=0.0)


# ---------------------------------------------------------------- rocket (anchor: bottom centre)

RX, RY = 2.0, 1.15        # the rocket's art is drawn at unit size and stretched to bust scale
ROCKET_HW = 104.0 * RX
ROCKET_X = THRESHOLD_X - 14.0 + ROCKET_HW


def rp(pts: list) -> list:
    return [(p[0] * RX, p[1] * RY) + tuple(p[2:]) for p in pts]


# the lift-off (v16): the app holds `lift` in 0..IGNITION over the first share of its lift-off (the engine lights,
# the hull rumbles, the smoke billows on the pad) before it climbs; the landing passes the band at the end
IGNITION = 0.02
RUMBLE_PX, RUMBLE_CYCLES = 3.0, 6.0     # the shake's amplitude (artboard px) and its cycles over the ignition band
SMOKE_TOP = 0.32                        # every puff has billowed and gone by this lift
# (unit x, unit y above the ground, size, drift in unit px, window): low puffs first, rolling out along the pad
# (unit x, artboard y above the ground, size px, drift in unit px, rise px, window): low puffs first, rolling out along
# the pad, the later ones bigger and higher
PUFFS = ((-50, -30, 230, -150, -20, (0.000, 0.12)), (50, -30, 230, 150, -20, (0.000, 0.12)),
         (-120, -50, 260, -280, -50, (0.003, 0.18)), (120, -50, 260, 280, -50, (0.003, 0.18)),
         (-30, -70, 300, -120, -90, (0.008, 0.24)), (40, -76, 280, 140, -100, (0.008, 0.24)),
         (-190, -40, 240, -360, -70, (0.014, SMOKE_TOP)), (190, -40, 240, 360, -70, (0.014, SMOKE_TOP)),
         (-100, -110, 220, -220, -160, (0.02, SMOKE_TOP)), (110, -110, 220, 230, -160, (0.02, SMOKE_TOP)))
STEEL, STEEL_HI, STEEL_LO, STEEL_DARK = "FFC9C0C4", "FFF1EAE2", "FF9A90A0", "FF6E6678"
RED, RED_HI, RED_LO = "FFC0503F", "FFE07A60", "FF8E3630"
BRASS, BRASS_LO = "FFE2BC72", "FF9C7638"


def hull_x(y: float) -> float:
    """The hull's half width (unit) at unit height y, along its outline."""
    prof = [(-760, 0), (-690, 54), (-560, 92), (-400, 104), (-240, 96), (-140, 82)]
    for (y0, x0), (y1, x1) in zip(prof, prof[1:]):
        if y0 <= y <= y1:
            return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    raise ValueError(y)


def rocket() -> El:
    """The little rocket (v16): a riveted steel hull with a brass porthole (its glass shows the far scene's light)
    and a hatch onto a lit cabin. `lift` flies it: the engine lights in the ignition band (the hull rumbles, smoke
    rolls out over the pad, the ground flares), then it climbs out of frame on a three-layer flame; its shadow
    shrinks and fades as it rises. The app lands it the same way on arrival and before boarding."""
    body_pts = rp([(0, -760), (54, -690), (92, -560), (104, -400), (96, -240), (82, -140, "c"),
                   (-82, -140, "c"), (-96, -240), (-104, -400), (-92, -560), (-54, -690)])
    body = S("RocketHull", body_pts, hfill(-104 * RX, 104 * RX, [(STEEL_LO, 0), (STEEL_HI, 0.3), (STEEL, 0.62),
                                                               ("FF8A8094", 1)]), line(INK, 5))
    # panel seams follow the hull's curve; rivets ride the band
    seams = []
    for i, y in enumerate((-600, -440, -230)):
        hw = hull_x(y) - 3
        seams.append(S(f"RocketSeam{i}", rp([(-hw, y), (0, y + 9), (hw, y)]), line("FF7A7086", 2.5), closed=False))
    rivets = [E(f"RocketRivet{i}", x * RX, -315 * RY, 9, 9, fill(STEEL_HI), line("FF6E6678", 1.5))
              for i, x in enumerate((-80, -48, -16, 16, 48, 80))]
    gloss = S("RocketGloss", rp([(-58, -650), (-40, -662), (-46, -420), (-50, -200), (-66, -190), (-72, -420)]),
              vfill(-662 * RY, -190 * RY, [("00FFFFFF", 0), ("B0FFFFFF", 0.3), ("90FFFFFF", 0.7), ("00FFFFFF", 1)]))
    nose = S("RocketNose", rp([(0, -760), (54, -690), (74, -640, "c"), (-74, -640, "c"), (-54, -690)]),
             vfill(-760 * RY, -640 * RY, [(RED_HI, 0), (RED, 0.5), (RED_LO, 1)]), line(INK, 4))
    nose_hi = S("RocketNoseGloss", rp([(-8, -742), (-34, -702), (-44, -662), (-30, -664), (-16, -706)]),
                fill("90FFE8DC"))
    tip = E("RocketTip", 0, -762 * RY, 22, 22, rfill(11, [(BRASS, 0), (BRASS_LO, 1)]), line(INK, 3))
    band = S("RocketBand", rp([(-100, -330, "c"), (100, -330, "c"), (102, -300, "c"), (-102, -300, "c")]),
             vfill(-330 * RY, -300 * RY, [(RED_HI, 0), (RED, 0.4), (RED_LO, 1)]), line(INK, 3))
    # the porthole: brass ring and bolts, its glass lit by the scene the rocket flies to
    bolts = [E(f"RocketBolt{i}", 54 * math.cos(a), 54 * math.sin(a), 8, 8, fill(BRASS_LO))
             for i, a in enumerate(i * math.tau / 8 + 0.4 for i in range(8))]
    glass = E("emitRocketWindowGlass", 0, 0, 92, 92, light_glow(70, light_stop(0.0), stop("FF7FA6D0", 0.55),
                                                                 stop("FF34507A", 0.9), cx=-14, cy=-16))
    glass.children[-1].children[0].children[-1].attrs["colorValue"] = "FF2A4268"   # the glass's edge stays opaque
    glint = S("RocketWindowGlint", [(-30, -14), (-14, -32), (6, -38), (-10, -24), (-24, -4)], fill("C0FFFFFF"))
    window = N("RocketWindow", glint, *bolts, glass,
               E("RocketWindowRing", 0, 0, 128, 128, rfill(64, [(BRASS, 0.6), (BRASS_LO, 1)]), line(INK, 4)),
               x=0.0, y=-500.0 * RY)
    # the hatch: a door swinging out on its left hinge onto a warm cabin light
    hatch_w, hatch_top, hatch_bottom = 150.0, -290.0 * RY, -150.0 * RY
    hh = hatch_bottom - hatch_top
    door = N("RocketHatch",
             E("RocketHatchPort", hatch_w / 2, hatch_top + 44, 34, 34, rfill(17, [("FF9CC0E0", 0), ("FF4E6A90", 1)]),
               line(INK, 2.5)),
             R("RocketHatchHandle", hatch_w - 22, (hatch_top + hatch_bottom) / 2 + 10, 10, 36, 5, fill(STEEL_DARK),
               line(INK, 2)),
             R("RocketHatchInset", hatch_w / 2, (hatch_top + hatch_bottom) / 2, hatch_w - 26, hh - 26, 20,
               line("FF8A8094", 2.5)),
             R("RocketHatchDoor", hatch_w / 2, (hatch_top + hatch_bottom) / 2, hatch_w, hh, 30,
               hfill(0, hatch_w, [(STEEL_HI, 0), (STEEL, 0.5), ("FF9A90A0", 1)]), line(INK, 3)),
             bind("open", 16, conv(-1.1, 1.0)), x=-hatch_w - 40, y=0.0)
    cx_, cy_ = -hatch_w / 2 - 40, (hatch_top + hatch_bottom) / 2
    cabin = N("emitRocketCabin",
              R("emitRocketCabinShadow", cx_, hatch_top + 18, hatch_w - 6, 30, 14,
                vfill(hatch_top + 3, hatch_top + 33, [("C0302838", 0), ("00302838", 1)], emit=True)),
              *[E(f"emitRocketCabinLamp{i}", cx_ - 40 + 24 * i, cy_ + 26, 9, 9, fill(c, emit=True))
                for i, c in enumerate(("FF7BD88F", "FFFFE08A", "FFFF8552", "FF7FB8FF"))],
              R("emitRocketCabinPanel", cx_, cy_ + 26, 116, 22, 8, fill("FF5A3A30", emit=True)),
              R("emitRocketCabinLight", cx_, cy_, hatch_w - 6, hh - 6, 27,
                rfill(hh, [("FFFFF6DA", 0), ("FFFFD49A", 0.45), ("FFC87A50", 1)], emit=True, cx=20, cy=-hh / 2)),
              bind("open", 18), x=0.0, y=0.0, opacity=0.0)
    hole = R("RocketHatchHole", -hatch_w / 2 - 40, (hatch_top + hatch_bottom) / 2, hatch_w, hh, 30,
             vfill(hatch_top, hatch_bottom, [("FF3A3046", 0), ("FF221C2C", 1)]), line(INK, 3))
    # its light falls out of the hatch onto the ground in front
    door_light = S("emitRocketDoorLight", [(-hatch_w - 34, hatch_bottom), (-46, hatch_bottom), (60, 40), (-hatch_w - 150, 40)],
                   vfill(hatch_bottom, 40, [("90FFD8A0", 0), ("00FFD8A0", 1)], emit=True), bind("open", 18), opacity=0.0)
    fins = [S("RocketFinL", rp([(-90, -280), (-150, -160), (-158, -60, "c"), (-82, -120, "c")]),
              vfill(-280 * RY, -60 * RY, [(RED_HI, 0), (RED_LO, 1)]), line(INK, 4)),
            S("RocketFinR", rp([(90, -280), (150, -160), (158, -60, "c"), (82, -120, "c")]),
              vfill(-280 * RY, -60 * RY, [(RED, 0), ("FF7A2E2A", 1)]), line(INK, 4))]
    fin_hi = S("RocketFinGloss", rp([(-100, -262), (-140, -168), (-146, -96)]), line("A0FFD8C8", 4), closed=False)
    nozzle = S("RocketNozzle", rp([(-50, -142, "c"), (50, -142, "c"), (66, -104, "c"), (-66, -104, "c")]),
               hfill(-66 * RX, 66 * RX, [("FF4A4452", 0), ("FF8A8094", 0.35), ("FF3A3442", 1)]), line(INK, 4))
    legs = [N(f"RocketLeg{'LR'[s > 0]}",
              E(f"RocketFoot{'LR'[s > 0]}", s * 112 * RX, -6, 70, 16, fill(STEEL_DARK), line(INK, 3)),
              S(f"RocketStrut{'LR'[s > 0]}", rp([(s * 62, -150), (s * 112, -6)]), line(STEEL_DARK, 12), closed=False),
              x=0.0, y=0.0) for s in (-1, 1)]
    rim = S("RocketRim", rp([(-100, -260), (-104, -400), (-92, -560), (-54, -690)]),
            bound_line("lightKey", 5, SCENES["livingRoom"].key), closed=False, opacity=0.7)
    shade = S("RocketShade", rp([(40, -700), (92, -560), (104, -400), (96, -240), (82, -140, "c"), (36, -140, "c"),
                                 (60, -400)]), bound_fill("lightAmbient", SCENES["livingRoom"].ambient), opacity=0.45)
    # the flame: outer, mid and a white core with shock diamonds, flickering on the loop; it grows with the thrust
    diamonds = [S(f"emitRocketDiamond{i}", [(0, y - 16), (12, y), (0, y + 16), (-12, y)], fill("E0FFFFFF", emit=True))
                for i, y in enumerate((70, 130, 182))]
    flicker = N("emitRocketFlameFlicker",
                *diamonds,
                S("emitRocketFlameCore", [(0, 0, "c"), (-34, 50), (-14, 190), (0, 250), (14, 190), (34, 50)],
                  vfill(0, 250, [("FFFFFFF4", 0), ("FFFFF1C8", 0.6), ("00FFE7A8", 1)], emit=True)),
                S("emitRocketFlameMid", [(0, 0, "c"), (-62, 60), (-40, 230), (0, 340), (40, 230), (62, 60)],
                  vfill(0, 340, [("FFFFE08A", 0), ("FFFFB060", 0.55), ("00FF9A50", 1)], emit=True)),
                S("emitRocketFlameOuter", [(0, -6, "c"), (-104, 70), (-60, 280), (0, 440), (60, 280), (104, 70)],
                  vfill(0, 440, [("E0FF9A52", 0), ("A0FF6A42", 0.55), ("00E04A3A", 1)], emit=True)),
                x=0.0, y=0.0)
    amb_tracks.append(track(d, flicker, {
        "scaleY": [(f, round(1.0 + 0.14 * math.sin(f * 1.7) * math.sin(f * 0.37), 4)) for f in range(0, AMB_FRAMES, 6)]
        + [(AMB_FRAMES, 1.0)],
        "scaleX": [(f, round(1.0 + 0.06 * math.sin(f * 2.3 + 1.0), 4)) for f in range(0, AMB_FRAMES, 6)]
        + [(AMB_FRAMES, round(1.0 + 0.06 * math.sin(1.0), 4))]}))
    heat = E("emitRocketHeat", 0, 10, 260, 140, rfill(130, [("C0FFC870", 0), ("50FF8A4A", 0.5), ("00FF6A3A", 1)],
                                                         emit=True))
    flame = N("emitRocketFlame", flicker, heat,
              bind("lift", 18, conv_tokens(*F.fn("min", [F.val(1)], [F.val(60), F.op("*"), *F.inp()]))),
              bind("lift", 17, windowed(0.0, 0.08, 0.6, 0.4)), bind("lift", 16, windowed(0.0, 0.05, 0.4, 0.6)),
              x=0.0, y=-104.0 * RY, opacity=0.0, scaleX=0.6, scaleY=0.4)
    # the scene's key light takes the steel (multiply), so the hull sits in the room, the night or the sunset
    key_tint = S("RocketKeyTint", body_pts, bound_fill("lightKey", SCENES["livingRoom"].key), blendModeValue=MULTIPLY,
                 opacity=0.35)
    hull = N("RocketHullArt", rim, window, door, cabin, hole, gloss, *rivets, band, *seams, key_tint, nose_hi, tip,
             nose, shade, body, fin_hi, *fins, nozzle, *legs, x=0.0, y=0.0)
    # the rumble: a fast shake through the ignition band (history-free: a sine of `lift`), gone by the climb
    k = RUMBLE_CYCLES * math.tau / IGNITION
    shake = conv_tokens(F.val(RUMBLE_PX), F.op("*"), *F.fn("sin", [F.val(k), F.op("*"), *F.inp()]), F.op("*"),
                        F.val(1), F.op("-"), F.val(RUMBLE_PX), F.op("*"), *F.fn("sin", [F.val(k), F.op("*"), *F.inp()]),
                        F.op("*"), *window_tokens(IGNITION, 3 * IGNITION))
    body_node = N("RocketBody", N("RocketRumble", hull, bind("lift", 13, shake), x=0.0, y=0.0), flame,
                  bind("lift", 14, conv(LIFT_TRAVEL)), x=0.0, y=0.0)
    # the smoke rolls out over the pad, warm underneath from the flame
    puffs = []
    for i, (px, py, size, drift, rise, (a, b)) in enumerate(PUFFS):
        r = size / 2
        puff = E(f"RocketPuff{i}", 0, 0, size, size * 0.86,
                 rfill(r, [("F4FBF7F2", 0), ("E0E4DCE0", 0.45), ("80D4CCD4", 0.75), ("00D4CCD4", 1)], cy=-r * 0.15))
        puffs.append(N(f"RocketSmoke{i}", N(f"RocketPuffRise{i}", puff, bind("lift", 14, windowed(a, b, rise)),
                                            x=0.0, y=0.0),
                       bind("lift", 18, bump(a, b)), bind("lift", 13, windowed(a, b, drift * RX, px * RX)),
                       bind("lift", 16, windowed(a, b, 1.0, 0.3)), bind("lift", 17, windowed(a, b, 0.85, 0.3)),
                       x=px * RX, y=py, opacity=0.0, scaleX=0.3, scaleY=0.3))
    smoke = N("RocketSmoke", *puffs, x=0.0, y=0.0)
    flare = E("emitRocketGroundFlare", 0, -6, 900, 120, rfill(450, [("C0FFC070", 0), ("50FF8A4A", 0.45),
                                                                    ("00FF6A3A", 1)], emit=True),
              bind("lift", 18, bump(0.0, 0.4)), blendModeValue=SCREEN, opacity=0.0)
    shadow = E("RocketShadow", 0, 2, 560, 60, rfill(280, [("70120E18", 0), ("40120E18", 0.6), ("00120E18", 1)]),
               bind("lift", 18, conv_tokens(*clamp01(F.val(1), F.op("-"), F.val(3), F.op("*"), *F.inp()))),
               bind("lift", 16, windowed(0.0, 0.33, -0.6, 1.0)))
    return N("Rocket", smoke, body_node, flare, shadow, bind("rocket", 18), bind("rocket", 16, conv(0.08, 0.92)),
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
    _windows.clear()
    d.next = V10_APPEAR_CONV_ID
    conv(0.08, 0.92)
    d15.next = V15_DRAW_START
    with minting_in(d15):
        families = [book()]
    assert d15.next < V15_LIGHT_START, d15.next   # the drawing stops short of the vignette's lights
    d16 = Doc(client=0, start=V16_ID_START)
    with minting_in(d16):
        book_polish(families[0])
        families += [path(), portal(), rocket()]
    d.next = V10_FAMILIES_END
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
