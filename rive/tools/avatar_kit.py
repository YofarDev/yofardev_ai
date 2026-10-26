"""Shared drawing kit for the avatar generator: palette, absolute-coordinate rig, IK."""

from __future__ import annotations

import math
from typing import Callable

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
FRAME = "FF1F1C20"
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


def _norm(a: float) -> float:
    while a > PI:
        a -= 2 * PI
    while a <= -PI:
        a += 2 * PI
    return a


def ik(side: int, wrist: tuple[float, float], finger_deg: float, elbow_out: bool = False,
       fs: float = 1.0, fs2: float = 1.0) -> tuple[float, float, float]:
    """Rotations (arm, elbow, hand) that put the wrist at `wrist` (artboard px) with the fingers
    pointing along `finger_deg` (world degrees, y down; 90 = straight down = rest).
    side -1 = viewer-left arm, +1 = viewer-right arm (solved mirrored).
    `fs` foreshortens the upper arm (arm reaching toward the viewer)."""
    tx, ty = wrist
    if side == 1:
        tx, finger_deg = 800 - tx, 180 - finger_deg
    sx, sy = SHOULDER
    l1 = L1 * fs
    l2 = L2 * fs2
    phi = math.atan2(ty - sy, tx - sx)
    dist = math.hypot(tx - sx, ty - sy)
    dist = max(abs(l1 - l2) + 1e-6, min(l1 + l2, dist))
    # Project unreachable targets onto the reach circle. The old one-pixel
    # outer margin forced an 8.6-degree elbow bend even at straight-arm rest,
    # then the gesture's explicit rest key snapped it back to zero.
    tx, ty = sx + dist * math.cos(phi), sy + dist * math.sin(phi)
    cosine = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    alpha = math.acos(max(-1.0, min(1.0, cosine)))
    best = None
    for up in (phi + alpha, phi - alpha):
        ex, ey = sx + l1 * math.cos(up), sy + l1 * math.sin(up)
        better = (ex < best[1]) if (best is not None and elbow_out) else (best is None or ey > best[2])
        if best is None or better:            # default: elbow hangs low; elbow_out flares it sideways
            best = (up, ex, ey)
    up, ex, ey = best
    lo = math.atan2(ty - ey, tx - ex)
    t1 = _norm(up - PI / 2)
    t2 = _norm(lo - up)
    if t2 < -PI / 2:
        t2 += 2 * PI                         # fold outward, never across the chest
    t3 = _norm(math.radians(finger_deg) - lo)
    if side == 1:
        return (-t1, -t2, -t3)
    return (t1, t2, t3)


Keys = list[tuple]
Track = Callable[..., El]
