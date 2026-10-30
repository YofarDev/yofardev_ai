"""Generates rive/journeys/journey.rml: the scene-journey thresholds (contract v10,
`assets/rive/journeys/journey.riv`; moonshot M7 rulings 5-7, 11).

One artboard `Journey`, 800 x 1000 (the avatar's), drawn by the app above the avatar with the
avatar's fit. Four thresholds stand on the right of the frame, their occluding edge at x 640 (the
app clips the avatar right of it while it walks through):

- **door**: a free-standing storybook door; the leaf swings open on its right hinge onto a warm
  light;
- **path**: a leafy bush with ferns in front; the ferns part onto a dark gap in the bush;
- **portal**: a glowing violet ring that grows from a point; its swirling core opens;
- **rocket**: a small round rocket; its hatch opens, and `lift` raises it out of frame on a flame.

Everything is history-free: `JourneyVM` numbers bind opacity, scale, rotation and position through
`c + k x` formula converters (and two clamped ones for the rocket's flame and smoke); one ambient
loop turns the portal's swirl, flickers the flame and breathes the door light. No listeners, no
events. Colours outside `emit*` nodes are fitted into every scene's colour script, so the file
lints clean wherever it is shown.

    uv run rive/tools/gen_journeys.py            # writes rive/journeys/
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from art_bible import SCENES, fit_colour  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, ellipse, lin, rad, rect, smooth_path, track, write  # noqa: E402

W, H = 800, 1000
THRESHOLD_X = 640.0
GROUND_Y = 1000.0
AMB_FRAMES = 240          # 4 s ambient loop (swirl turn, flame flicker, door light)
LIFT_TRAVEL = -1400.0     # the rocket's y offset at lift 1 (out of frame at the top)
INK = "FF2A1E24"          # art bible line colour
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "journeys")
FAMILIES = ("door", "path", "portal", "rocket")

d = Doc(client=0, start=10)


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
    ("door", "number", 0.0), ("path", "number", 0.0), ("portal", "number", 0.0), ("rocket", "number", 0.0),
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


def arch(x0: float, x1: float, top: float, bottom: float, rise: float) -> list:
    """A round-topped doorway outline (left bottom, up, over the arch, down)."""
    cx = (x0 + x1) / 2
    hw = (x1 - x0) / 2
    shoulder = top + rise
    return [(x0, bottom, "c"), (x0, shoulder, "c"), (cx - hw * 0.72, top + rise * 0.18), (cx, top),
            (cx + hw * 0.72, top + rise * 0.18), (x1, shoulder, "c"), (x1, bottom, "c")]


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

# ---------------------------------------------------------------- door (anchor: bottom centre)

DOOR_HW, DOOR_OPEN_HW = 230.0, 196.0   # wide enough for the bust-scale avatar to walk through
DOOR_X = THRESHOLD_X - 16.0 + DOOR_HW   # the frame's left jamb ends at the threshold
DOOR_TOP = -940.0
DOOR_RISE = 300.0


def door() -> El:
    o0, o1 = -DOOR_OPEN_HW, DOOR_OPEN_HW
    leaf_w = o1 - o0
    # the leaf, drawn left of its hinge (x 0 = the right edge of the opening)
    leaf_pts = [(p[0] - o1, p[1]) + tuple(p[2:]) for p in arch(o0, o1, DOOR_TOP + 26, 40, DOOR_RISE - 30)]
    leaf = N("DoorLeaf",
             E("DoorKnob", -leaf_w + 40, -430, 30, 30, rfill(14, [("FFF2D08A", 0), ("FFB98A36", 1)]),
               line(INK, 2)),
             R("DoorPanelLow", -leaf_w / 2, -230, leaf_w - 90, 250, 24, fill("FF6A4330"), line("FF4A2E22", 3)),
             R("DoorPanelHigh", -leaf_w / 2, -610, leaf_w - 90, 360, 60, fill("FF6A4330"), line("FF4A2E22", 3)),
             S("DoorLeafWood", leaf_pts, hfill(-leaf_w, 0, [("FF946446", 0), ("FF7A4E36", 1)]), line(INK, 3)),
             bind("open", 16, conv(-1.25, 1.0)), x=o1, y=0.0)
    light = N("emitDoorLight",
              S("emitDoorLightCore", arch(o0, o1, DOOR_TOP + 26, 40, DOOR_RISE - 30),
                rfill(560, [("FFFFF4DC", 0), ("FFFFD49A", 0.45), ("FFE89A4E", 1)], emit=True, cy=-300)),
              x=0.0, y=0.0)
    spill = E("emitDoorSpill", -60, 8, 520, 60, rfill(260, [("A0FFD49A", 0), ("00FFD49A", 1)], emit=True),
              bind("open", 18, conv(0.85)), opacity=0.0)
    frame_pts = arch(-DOOR_HW, DOOR_HW, DOOR_TOP, 40, DOOR_RISE)
    frame = S("DoorFrame", frame_pts, vfill(DOOR_TOP, 40, [("FF5A3C2C", 0), ("FF3E2A22", 1)]), line(INK, 5))
    rim = S("DoorRim", [(-DOOR_HW + 4, 30), (-DOOR_HW + 4, DOOR_TOP + DOOR_RISE), (-DOOR_HW * 0.62, DOOR_TOP + 60)],
            bound_line("lightKey", 4, SCENES["livingRoom"].key), closed=False, opacity=0.7)
    shade = S("DoorShade", [(DOOR_HW * 0.86, 40, "c"), (DOOR_HW * 0.86, DOOR_TOP + DOOR_RISE * 0.7, "c"),
                            (DOOR_HW * 0.93, DOOR_TOP + DOOR_RISE * 0.55), (DOOR_HW, DOOR_TOP + DOOR_RISE, "c"),
                            (DOOR_HW, 40, "c")],
              bound_fill("lightAmbient", SCENES["livingRoom"].ambient), opacity=0.45)
    step = E("DoorStep", 0, 22, 2 * DOOR_HW + 90, 40, fill("FF4A4250"), line(INK, 3))
    glow = N("emitDoorGlow", light, x=0.0, y=0.0)
    amb_tracks.append(track(d, glow, {"opacity": [(0, 0.9), (60, 1.0), (120, 0.88), (180, 1.0), (240, 0.9)]},
                            ease=EASE))
    return N("Door", rim, leaf, spill, glow, shade, frame, step,
             bind("door", 18), bind("door", 16, conv(0.08, 0.92)), bind("door", 17, conv(0.08, 0.92)),
             x=DOOR_X, y=GROUND_Y, opacity=0.0)


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
    families = [door(), path(), portal(), rocket()]
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
