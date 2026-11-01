"""Shared drawing kit for the avatar generator: palette, absolute-coordinate rig, arm IK (the
two-bone solver itself lives in rig_dsl)."""

from __future__ import annotations

from contextlib import contextmanager
import math
from typing import Callable, Iterator

from rig_dsl import two_bone_dirs, wrap_angle
from rml import Doc, El, ellipse, fill, lin, rad, smooth_path, stroke

d = Doc(client=0, start=10)
PI = math.pi

# ---------------------------------------------------------------- palette
INK = "FF3A2622"          # warm line colour, never pure black
SKIN = "FFF6D3BC"
SKIN_SH = "FFE3AE95"
SKIN_SH2 = "FFD0937C"
HAIR = "FF3B2A26"
HAIR_HI = "FF795448"
HAIR_SH = "FF2A1D1A"
IRIS_A = "FFB0702F"
IRIS_B = "FF5A3317"
SCLERA = "FFFFFBF6"
FRAME = "FF2A1E24"          # glasses: the warm ink, never a cool black
HOOD = "FFEBC5D9"
HOOD_SH = "FFBB8FB6"
HOOD_SH2 = "FF986D9B"
HOOD_INK = "FF76546E"
STRING = "FFF3EEF4"
BEANIE = "FF94401F"
BEANIE_SH = "FF73301A"
BEANIE_HI = "FFB15A30"
MOUTH_IN = "FF6B2A2C"
TONGUE = "FFD9706E"
TEETH = "FFFFFAF5"
WHITE = "FFFFFFFF"


# ---------------------------------------------------------------- critic round 2 art (pure geometry)
# Line weights: art_bible LineRules are px on a 1080 px frame; the head (crown..chin ~315 art px) is
# 1/2.6 of the figure, so a 1080 frame shows it ~1.385x larger (the same reasoning as gen_head.py).
LINE_SCALE = 1 / 1.385
FRAME_W = 3.0 * LINE_SCALE  # the glasses rim: the art bible's interior weight (3 px at 1080)
FRAME_INK = "D92A1E24"  # the warm ink at 85 %: the frame stops being the darkest line on the face
PAPER = "FFFBF6"  # paper-white (rgb) for the lens glint

# Clear lenses: a rounded ring (outer rounded rectangle minus an inner one, even-odd), centre
# y LENS_CY, the rim tapering from FRAME_W on top to RIM_BOTTOM on the lower rim.
LENS_W, LENS_H, LENS_CY = 86.0, 58.0, 387.0
LENS_R = 18.0  # >= 30 % of the lens's short side (art bible: no hard corners where the eye rests)
RIM_SIDE, RIM_BOTTOM = 0.85 * FRAME_W, 0.55 * FRAME_W


def lens_ring() -> dict[str, tuple[float, float, float, float, float, float]]:
    """Outer and inner rounded rectangles of a clear lens, relative to the lens centre:
    name -> (dy, width, height, top radius, bottom radius, rim) (rim: the outer one's rim top)."""
    top, side, bot = FRAME_W, RIM_SIDE, RIM_BOTTOM
    return {"outer": (0.0, LENS_W, LENS_H, LENS_R, LENS_R, top),
            "inner": ((top - bot) / 2, LENS_W - 2 * side, LENS_H - top - bot, LENS_R - (top + side) / 2,
                      LENS_R - (bot + side) / 2, 0.0)}


def lens_glint(cx: float) -> list[tuple[float, float]]:
    """One slim diagonal glint in a lens's upper-left (the key light's side), wide end up."""
    return [(cx - 22, LENS_CY - 25), (cx - 16.5, LENS_CY - 25), (cx - 31, LENS_CY - 2), (cx - 34, LENS_CY - 2)]


# Fringe clumps (critic round 2): three length tiers, tips tapered to soft points. A lock is seven
# outline points: base, flank, shoulder, the TIP (a StraightVertex with a small radius), shoulder,
# flank, base. TIP_AT is where the shoulders sit along the lock, TIP_HALF their half width (x the
# base width), TIP_R the point's radius as a fraction of the width at the shoulders.
LOCK_S = 0.3  # second harmonic of the lock's bow: the clump's centre line is a slight S
TIP_AT, TIP_HALF, TIP_R = 0.88, 0.17, 0.24


# (root, tip, base width, bend) per lock (names Lock0..Lock8; the generator's draw order is
# separate). Short tips end ~10 px under the hairline, medium ~50, long past the eyes.
FRINGE_LOCKS: list[tuple[tuple[float, float], tuple[float, float], float, float]] = [
    ((300, 272), (290, 406), 44, -8), ((328, 248), (306, 348), 48, 11), ((356, 238), (342, 310), 40, 9),
    ((404, 230), (396, 348), 58, 12), ((452, 236), (466, 312), 42, 10), ((474, 250), (498, 360), 54, 9),
    ((498, 276), (512, 408), 40, 6), ((380, 236), (360, 304), 28, 6), ((440, 240), (450, 306), 28, 6)]
LOCK_TIERS = {"short": (2, 4, 7, 8), "medium": (1, 3, 5), "long": (0, 6)}
LOCK_CLUMPS = ((0, 1), (2, 7, 3), (8, 4, 5, 6))  # three clumps; the parting splits the front two
# critic round 3: the clumps read as drips; widths vary more (the short pairs are thinner than the
# medium locks) and two medium locks flick their tips outward (px at the tip, + = the lock's left
# normal), so the fringe reads as hair
FRINGE_FLICK: dict[int, float] = {1: 7.0, 5: -7.0}
FLICK_FROM = 0.55  # the flick bends the centre line from here to the tip (quadratic)
PARTING_X = 422.0  # the parting: right of centre, between the centre lock's root and lock 8's


def lock_bow(t: float, bend: float, flick: float = 0.0) -> float:
    """Sideways offset of a lock's centre line at t (0 root .. 1 tip): one bow plus a second
    harmonic (an S that turns the tip back), zero at both ends so root and tip stay put; a flick
    then bends the last stretch sideways (the tip moves by `flick`)."""
    curl = flick * max(0.0, (t - FLICK_FROM) / (1 - FLICK_FROM)) ** 2
    return bend * (math.sin(math.pi * t) + LOCK_S * math.sin(2 * math.pi * t)) + curl


def lock_outline(root_: tuple[float, float], tip: tuple[float, float], w: float, bend: float,
                 flick: float = 0.0) -> tuple[list[tuple], Callable[[float, float], tuple[float, float]]]:
    """(outline points, at(t, offset)) of one fringe lock: a tapered clump ending in a soft point."""
    (rx, ry), (tx, ty) = root_, tip
    dx, dy = tx - rx, ty - ry
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln

    def at(t: float, off: float) -> tuple[float, float]:
        bow = lock_bow(t, bend, flick)
        return (rx + dx * t + nx * (off + bow), ry + dy * t + ny * (off + bow))
    r = round(TIP_R * 1.9 * TIP_HALF * w, 2)  # the shoulders sit at TIP_HALF and 0.9 TIP_HALF
    pts: list[tuple] = [at(0, -w / 2), at(0.45, -w * 0.3), at(TIP_AT, -w * TIP_HALF), (*at(1, 0.0), f"c{r}"),
                        at(TIP_AT, w * TIP_HALF * 0.9), at(0.43, w * 0.32), at(0, w / 2)]
    return pts, at


R2_ID_START = 990000  # elements added in critic round 2 (gen_avatar.py mints them last)
M4_ID_START = 980000  # elements added in moonshot M4 (gen_avatar.py, Doc M4)
# elements added in moonshot M5 (gen_avatar.py, Doc M5). The plan's 970000 is the M3 arm skeleton's range
# (arm_rig.ARM_ID_START); 1,000,000+ is free in avatar.rml (M5 execution ruling 30)
M5_ID_START = 1000000
# moonshot M8 (gen_avatar.py, Doc M8): 1,100,000-1,149,999 for the generator's own elements, 1,150,000+ for the
# arm-rig elements its gestures mint (arm_rig's own document borrows that range); both free in avatar.rml
M8_ID_START = 1100000
M8_ARM_ID_START = 1150000
# moonshot M10 (gen_avatar.py, Doc M10): the wardrobe dedupe's keys, the tints, the mouth anchor and the
# signatures (free in avatar.rml)
M10_ID_START = 1200000
M10_TINT_ID_START = 1210000  # Task 2b: the tint fills, `topTint` / `hatTint` and `MouthAnchor`
M10_SIG_ID_START = 1220000   # Task 2c: the costume signatures (the generator's own elements)
M10_SIG_ARM_ID_START = 1235000  # Task 2c: the arm-rig elements the signatures mint (arm_rig's document)


def footfalls(f0: int, f1: int, distance: float, stride: float, shift: int = 10) -> list[int]:
    """The frames of a gen_avatar walk's footfalls (contract v11 foley `step`): the walk's travel is
    smoothstep over (f0 + shift, f1) (after the weight shift), and a foot lands where the walked distance
    first reaches k x stride, k = 0 (the push-off) .. distance // stride."""
    out = []
    for k in range(int(distance // stride + 1e-9) + 1):
        for f in range(f0 + shift, f1 + 1):
            t = (f - f0 - shift) / (f1 - f0 - shift)
            if distance * t * t * (3 - 2 * t) >= k * stride - 1e-6:
                out.append(f)
                break
    return out


@contextmanager
def minting(src: Doc, dst: Doc) -> Iterator[None]:
    """Elements `src` mints inside the block take `dst`'s ids (src's own counter is untouched), so the
    generator's helpers (bound to the main document) can build late additions in a new id range."""
    saved = src.next
    src.next = dst.next
    try:
        yield
    finally:
        dst.next = src.next
        src.next = saved

# The fringe's cast shadow on the forehead: a band under the hairline (cap edge y ~292-300), skinned
# by the head turn (same 15 points as M2), filled with a fade from FACE_CAST_FADE[0] (alpha at the
# hairline) to clear at FACE_CAST_FADE[2] (above the brows, which start at y ~335).
FACE_CAST_PTS = [(298, 306), (330, 298), (370, 293), (400, 291), (440, 293), (480, 298), (502, 306), (504, 342),
                 (490, 338), (470, 332), (440, 338), (400, 334), (360, 338), (320, 332), (300, 342)]
FACE_CAST_FADE = ("80", 296.0, 334.0)  # alpha (hex) at y0, y0, y1 (alpha 0)


def face_cast_fade() -> tuple[float, float, list[tuple[str, float]]]:
    """(y0, y1, stops) of the cast's linear gradient in the shape's local space (origin: the bbox
    centre, as avatar_kit.S places it)."""
    ys = [p[1] for p in FACE_CAST_PTS]
    oy = (min(ys) + max(ys)) / 2
    a, y0, y1 = FACE_CAST_FADE
    col = SKIN_SH[2:]
    return y0 - oy, y1 - oy, [(a + col, 0.0), ("00" + col, 1.0)]


class Rig:
    """A pivot node (or Solo) that knows its absolute position."""

    def __init__(self, name: str, ax: float, ay: float, parent: "Rig | None" = None, tag: str = "Node",
                 **kw: object) -> None:
        self.ax, self.ay = ax, ay
        px, py = (parent.ax, parent.ay) if parent else (0.0, 0.0)
        self.el = d(tag, x=float(ax - px), y=float(ay - py), name=name, **kw)
        if parent:
            parent.el.add(self.el)

    def node(self, name: str, ax: float | None = None, ay: float | None = None, **kw: object) -> "Rig":
        return Rig(name, self.ax if ax is None else ax, self.ay if ay is None else ay, self, **kw)

    def solo(self, name: str) -> "Rig":
        return Rig(name, self.ax, self.ay, self, tag="Solo")

    def add(self, *els: El | None) -> "Rig":
        self.el.add(*els)
        return self

    def ref(self) -> str:
        return self.el.ref()


def _pa(parent: Rig | tuple[float, float]) -> tuple[float, float]:
    return (parent.ax, parent.ay) if isinstance(parent, Rig) else parent


def S(parent: Rig | tuple[float, float], name: str, pts: list, *paints: El | None,
      origin: tuple[float, float] | None = None, closed: bool = True, tension: float = 1.0,
      clip: El | None = None, **kw: object) -> El:
    """Shape whose points are given in absolute artboard space.

    Nested child shapes render BEHIND their parent's path (rive 1.7.0), so this
    helper never nests art; `clip` adds a ClippingShape from another shape.
    """
    pax, pay = _pa(parent)
    if origin is None:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        origin = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
    ox, oy = origin
    loc = [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts]
    path = smooth_path(d, loc, closed=closed, tension=tension)
    kids = [d("ClippingShape", sourceId=clip.ref(), name="Clip")] if clip is not None else []
    return d("Shape", *kids, path, *[p for p in paints if p is not None],
             x=float(ox - pax), y=float(oy - pay), name=name, **kw)


def E(parent: Rig | tuple[float, float], name: str, cx: float, cy: float, w: float, h: float,
      *paints: El | None, clip: El | None = None, **kw: object) -> El:
    pax, pay = _pa(parent)
    kids = [d("ClippingShape", sourceId=clip.ref(), name="Clip")] if clip is not None else []
    return d("Shape", *kids, ellipse(d, w, h), *[p for p in paints if p is not None],
             x=float(cx - pax), y=float(cy - pay), name=name, **kw)


def R(parent: Rig | tuple[float, float], name: str, cx: float, cy: float, w: float, h: float, r: float,
      *paints: El | None, **kw: object) -> El:
    pax, pay = _pa(parent)
    return d("Shape", d("Rectangle", width=float(w), height=float(h), cornerRadiusTL=float(r),
                        cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
             *[p for p in paints if p is not None], x=float(cx - pax), y=float(cy - pay), name=name, **kw)


def clip_only(shape: El) -> El:
    """Strip paints: geometry used purely as a ClippingShape source."""
    shape.children = [c for c in shape.children if c.tag not in ("Fill", "Stroke")]
    return shape


def F(c: str) -> El:
    return fill(d, c)


def L(c: str = INK, w: float = 3.0) -> El:
    return stroke(d, c, w)


def mirror(pts: list, cx: float = 400) -> list:
    return [(2 * cx - p[0], p[1]) + tuple(p[2:]) for p in reversed(pts)]


def vgrad(y0: float, y1: float, c0: str, c1: str) -> El:
    # Geometry helpers centre their paths. Callers may give artboard-space
    # extents (e.g. torso 600..1000); paints must use the centred local space.
    if y0 >= 100:
        mid = (y0 + y1) / 2
        y0, y1 = y0 - mid, y1 - mid
    return d("Fill", lin(d, 0, y0, 0, y1, [(c0, 0.0), (c1, 1.0)]), name="Fill")


def hgrad(x0: float, x1: float, c0: str, c1: str) -> El:
    return d("Fill", lin(d, x0, 0, x1, 0, [(c0, 0.0), (c1, 1.0)]), name="Fill")


def grad(stops: list[tuple[str, float]], y0: float, y1: float) -> El:
    return d("Fill", lin(d, 0, y0, 0, y1, stops), name="Fill")


def rgrad(r: float, stops: list[tuple[str, float]], cx: float = 0, cy: float = 0) -> El:
    return d("Fill", rad(d, cx, cy, r, stops), name="Fill")


def group(name: str, *kids: El | None) -> El:
    return d("Node", *kids, x=0.0, y=0.0, name=name)


# ---------------------------------------------------------------- arm IK
SHOULDER = (240.0, 720.0)
ELBOW0 = (240.0, 900.0)
WRIST0 = (240.0, 1070.0)
L1 = ELBOW0[1] - SHOULDER[1]
L2 = WRIST0[1] - ELBOW0[1]


def ik(side: int, wrist: tuple[float, float], finger_deg: float, elbow_out: bool = False,
       fs: float = 1.0, fs2: float = 1.0) -> tuple[float, float, float]:
    """Rotations (arm, elbow, hand) that put the wrist at `wrist` (artboard px) with the fingers
    pointing along `finger_deg` (world degrees, y down; 90 = straight down = rest).
    side -1 = viewer-left arm, +1 = viewer-right arm (solved mirrored).
    `fs` foreshortens the upper arm (arm reaching toward the viewer)."""
    tx, ty = wrist
    if side == 1:
        tx, finger_deg = 800 - tx, 180 - finger_deg
    l1 = L1 * fs
    l2 = L2 * fs2
    # rig_dsl.two_bone_dirs projects unreachable targets onto the reach circle (no artificial
    # bend at straight-arm rest). Both elbow sides are solved; the arm picks one.
    best = None
    for bend in (-1, 1):
        up, lo, (ex, ey) = two_bone_dirs(l1, l2, (tx, ty), bend, SHOULDER)
        better = (ex < best[2]) if (best is not None and elbow_out) else (best is None or ey > best[3])
        if best is None or better:            # default: elbow hangs low; elbow_out flares it sideways
            best = (up, lo, ex, ey)
    up, lo, _, _ = best
    t1 = wrap_angle(up - PI / 2)
    t2 = wrap_angle(lo - up)
    if t2 < -PI / 2:
        t2 += 2 * PI                         # fold outward, never across the chest
    t3 = wrap_angle(math.radians(finger_deg) - lo)
    if side == 1:
        return (-t1, -t2, -t3)
    return (t1, t2, t3)


Keys = list[tuple]
Track = Callable[..., El]
