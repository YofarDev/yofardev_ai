"""Tiny RML builder shared by the avatar and scene generators.

Every element gets a deterministic numeric id so `rive` never has to write ids
back into the generated .rml (keeps rebuilds byte-stable).
"""

from __future__ import annotations

import math
from typing import Iterable
from xml.sax.saxutils import quoteattr

_NO_ID = {"Rive"}


class El:
    def __init__(self, tag: str, children: Iterable["El | None"] = (), **attrs: object) -> None:
        self.tag = tag
        self.attrs: dict[str, object] = {}
        for k, v in attrs.items():
            if v is None:
                continue
            self.attrs[k.rstrip("_")] = v
        self.children: list[El] = [c for c in children if c is not None]
        self.id: str | None = None

    def add(self, *kids: "El | None") -> "El":
        self.children.extend(k for k in kids if k is not None)
        return self

    def ref(self) -> str:
        assert self.id is not None, f"{self.tag} has no id yet"
        return self.id


class Doc:
    """Assigns ids eagerly so references can be taken before serialising."""

    def __init__(self, client: int = 0, start: int = 10) -> None:
        self.client = client
        self.next = start

    def __call__(self, tag: str, *children: "El | None", **attrs: object) -> El:
        e = El(tag, children, **attrs)
        if tag not in _NO_ID:
            e.id = f"{self.client}:{self.next}"
            self.next += 1
        return e


def _fmt(v: object) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = f"{v:.4f}".rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s
    return str(v)


def render(e: El, indent: int = 0) -> str:
    pad = "  " * indent
    parts = [e.tag]
    for k, v in e.attrs.items():
        parts.append(f"{k}={quoteattr(_fmt(v))}")
    if e.id is not None and "id" not in e.attrs:
        parts.append(f'id="{e.id}"')
    head = " ".join(parts)
    if not e.children:
        return f"{pad}<{head}/>"
    inner = "\n".join(render(c, indent + 1) for c in e.children)
    return f"{pad}<{head}>\n{inner}\n{pad}</{e.tag}>"


# ---------------------------------------------------------------- geometry

Pt = tuple[float, float]


def smooth_path(d: Doc, pts: list[Pt | tuple[float, float, str]], closed: bool = True,
                tension: float = 1.0, name: str = "Path") -> El:
    """Catmull-Rom through pts -> PointsPath of CubicDetachedVertex.

    A point given as (x, y, "c") is a hard corner (StraightVertex);
    (x, y, "c8") rounds that corner with radius 8.
    """
    n = len(pts)
    xy = [(p[0], p[1]) for p in pts]
    verts: list[El] = []
    area = 0.0
    for i in range(n):
        x0, y0 = xy[i]
        x1, y1 = xy[(i + 1) % n]
        area += x0 * y1 - x1 * y0
    for i, p in enumerate(pts):
        x, y = xy[i]
        if len(p) == 3:
            tag = str(p[2])
            r = float(tag[1:]) if len(tag) > 1 else 0.0
            verts.append(d("StraightVertex", x=float(x), y=float(y), radius=r or None))
            continue
        if not closed and (i == 0 or i == n - 1):
            prv = xy[i] if i == 0 else xy[i - 1]
            nxt = xy[i] if i == n - 1 else xy[i + 1]
        else:
            prv = xy[(i - 1) % n]
            nxt = xy[(i + 1) % n]
        tx, ty = (nxt[0] - prv[0]) * tension / 6.0, (nxt[1] - prv[1]) * tension / 6.0
        # scale handles by neighbour distance so uneven spacing stays round
        dn = math.hypot(nxt[0] - x, nxt[1] - y)
        dp = math.hypot(prv[0] - x, prv[1] - y)
        tl = math.hypot(tx, ty) or 1.0
        tot = dn + dp or 1.0
        out_d = tl * 2 * dn / tot
        in_d = tl * 2 * dp / tot
        ang = math.atan2(ty, tx)
        verts.append(d("CubicDetachedVertex", x=float(x), y=float(y),
                       outRotation=float(ang), outDistance=float(out_d),
                       inRotation=float(ang + math.pi), inDistance=float(in_d)))
    return d("PointsPath", *verts, isClosed=closed, isClockwise=area > 0, name=name)


def solid(d: Doc, argb: str) -> El:
    return d("SolidColor", colorValue=argb)


def fill(d: Doc, argb: str | None = None, grad: El | None = None) -> El:
    return d("Fill", grad if grad is not None else solid(d, argb or "FFFF00FF"), name="Fill")


def stroke(d: Doc, argb: str, w: float, cap: str = "round", join: str = "round") -> El:
    return d("Stroke", solid(d, argb), thickness=float(w), cap=cap, join=join, name="Line")


def lin(d: Doc, x0: float, y0: float, x1: float, y1: float, stops: list[tuple[str, float]]) -> El:
    return d("LinearGradient",
             *[d("GradientStop", colorValue=c, position=float(p)) for c, p in stops],
             startX=float(x0), startY=float(y0), endX=float(x1), endY=float(y1))


def rad(d: Doc, cx: float, cy: float, r: float, stops: list[tuple[str, float]]) -> El:
    return d("RadialGradient",
             *[d("GradientStop", colorValue=c, position=float(p)) for c, p in stops],
             startX=float(cx), startY=float(cy), endX=float(cx + r), endY=float(cy))


def shape(d: Doc, name: str, path: El, *paints: El | None, x: float = 0, y: float = 0,
          children: Iterable[El] = (), **kw: object) -> El:
    # first-declared child shapes paint in front of the parent path
    return d("Shape", *children, path, *paints, x=float(x), y=float(y), name=name, **kw)


def ellipse(d: Doc, w: float, h: float) -> El:
    return d("Ellipse", width=float(w), height=float(h), name="Path")


def rect(d: Doc, w: float, h: float, r: float = 0, ox: float | None = None,
         oy: float | None = None) -> El:
    return d("Rectangle", width=float(w), height=float(h),
             cornerRadiusTL=float(r) if r else None, originX=ox, originY=oy, name="Path")


def node(d: Doc, name: str, *kids: El | None, x: float = 0, y: float = 0, **kw: object) -> El:
    return d("Node", *kids, x=float(x), y=float(y), name=name, **kw)


# ---------------------------------------------------------------- animation

def anim(d: Doc, name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
    return d("LinearAnimation", *tracks, duration=frames, fps=60,
             loopValue="loop" if loop else None, name=name)


def track(d: Doc, target: El, props: dict[str, list[tuple[int, float] | tuple[int, float, str]]],
          ease: El | None = None) -> El:
    """props: {"rotation": [(frame, value[, 'hold'|'linear'])...]} -> KeyedObject."""
    kps = []
    for prop, keys in props.items():
        kfs = []
        for k in keys:
            f, v = k[0], k[1]
            mode = k[2] if len(k) > 2 else ("cubic" if ease is not None else "linear")
            if isinstance(v, El):        # reference (e.g. Solo.activeComponentId) -> hold only
                kfs.append(d("KeyFrameId", frame=f, value=v.ref(), interpolationType="hold"))
                continue
            kf_tag = "KeyFrameColor" if isinstance(v, str) else "KeyFrameDouble"
            kfs.append(d(kf_tag, frame=f, value=v if isinstance(v, str) else float(v),
                         interpolationType=mode,
                         interpolatorId=ease.ref() if (ease is not None and mode == "cubic") else None))
        kps.append(d("KeyedProperty", *kfs, property=prop))
    return d("KeyedObject", *kps, objectId=target.ref())


def write(path: str, roots: list[El]) -> None:
    body = "\n\n".join(render(r, 1) for r in roots)
    with open(path, "w") as f:
        f.write(f'<Rive version="1" kind="fragment">\n{body}\n</Rive>\n')
