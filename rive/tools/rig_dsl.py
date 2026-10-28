"""Rig DSL: reusable pieces for formula-driven skinned rigs, authored as Python -> RML.

Extracted from the M0 head spike (rive/spikes/head25d on spike/rive-moonshot-m0) and grown for
the M1 head (rive/tools/gen_head.py). Nothing here knows about a particular character.

Drives. A bone coordinate is a history-free function of view-model numbers:

    value = sum(c_i * f_i(a))      a = k * min(hi, max(lo, input))

with f_i a product of `cos(a)`, `sin(a)`, `sqrt(w2 cos^2 a + d2 sin^2 a)` (the edge of an
elliptic cross-section) and bound tokens (`tok("gaze")`: another view-model number read by a
`FormulaTokenValue` bind, so one bone can follow two inputs additively). A shared angle
converter computes `a` once per axis; each bind chains it (DataConverterGroup) into the bone's
own `DataConverterFormula`. `fit3` turns three authored poses (input -1, 0, +1) into the
`c0 + c1 cos a + c2 sin a` form, which is exactly a rotating material point, so in-betweens
move on a believable arc.

Skin. Weights are dicts {bone: w}; `quantize` keeps the 4 largest as bytes summing to 255.
`Grid` gives bilinear (tent) weights over named bones, `Chain` a 1-D tent along anchors.

Motion. `critically_damped` (exact closed form) and `SecondOrder` (f, zeta, r follower) bake
review timelines; `simplify` reduces a sampled channel to linear keys within a tolerance.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import math
import random
from typing import Callable, Iterable, Sequence, Union

from rml import Doc, El

PI = math.pi

# ------------------------------------------------------------------ polynomials in cos/sin

Factor = tuple[object, ...]  # ("cos",) | ("sin",) | ("sil", w2, d2) | ("tok", prop) | ("tokpos", prop)
Term = tuple[float, tuple[Factor, ...]]
Poly = list[Term]
COS: Factor = ("cos",)
SIN: Factor = ("sin",)
OPS: dict[str, int] = {"+": 0, "-": 1, "*": 2, "/": 3}
FNS: dict[str, int] = {"min": 0, "max": 1, "sqrt": 5, "cos": 9, "sin": 10}
DIGITS: int = 3  # formula literal precision (sub-pixel; keeps the file small)


def tok(prop: str) -> Factor:
    """A factor read from another view-model number (bound FormulaTokenValue)."""
    return ("tok", prop)


def tokpos(prop: str) -> Factor:
    """max(0, another view-model number): a term that only acts on one side (e.g. looking up)."""
    return ("tokpos", prop)


def const(c: float) -> Poly:
    return [(c, ())]


def poly_add(*ps: Poly) -> Poly:
    """Sum of polynomials, like terms merged, zero terms dropped (the constant always kept)."""
    acc: dict[tuple[Factor, ...], float] = {}
    for p in ps:
        for c, fs in p:
            acc[fs] = acc.get(fs, 0.0) + c
    out: Poly = [(acc.pop((), 0.0), ())]
    out += [(c, fs) for fs, c in acc.items() if abs(c) > 1e-9]
    return out


def poly_scale(p: Poly, s: float) -> Poly:
    return [(c * s, fs) for c, fs in p]


def poly_shift(p: Poly, c: float, sign: float = 1.0) -> Poly:
    """c + sign * p."""
    return poly_add(const(c), poly_scale(p, sign))


def eval_factor(f: Factor, a: float, env: dict[str, float] | None = None) -> float:
    if f[0] == "cos":
        return math.cos(a)
    if f[0] == "sin":
        return math.sin(a)
    if f[0] == "tok":
        return (env or {}).get(str(f[1]), 0.0)
    if f[0] == "tokpos":
        return max(0.0, (env or {}).get(str(f[1]), 0.0))
    return math.sqrt(float(f[1]) * math.cos(a) ** 2 + float(f[2]) * math.sin(a) ** 2)  # type: ignore[arg-type]


def eval_poly(p: Poly, a: float, env: dict[str, float] | None = None) -> float:
    """Value of `p` at angle `a` (radians) with bound tokens read from `env`."""
    return sum(round(c, DIGITS) * math.prod(eval_factor(f, a, env) for f in fs) for c, fs in p)


def material_dx(x3: float, z3: float) -> Poly:
    """Screen-x shift of the 3D point (X, Z) under yaw a: X(cos a - 1) + Z sin a."""
    return [(-x3, ()), (x3, (COS,)), (z3, (SIN,))]


def pitch_dy(y3: float, z3: float) -> Poly:
    """Screen-y shift (y down) of (Y, Z) under pitch-up a: Y(cos a - 1) - Z sin a."""
    return [(-y3, ()), (y3, (COS,)), (-z3, (SIN,))]


def silhouette_dx(side: float, w: float, depth: float, z0: float) -> Poly:
    """Shift of the `side` (+1 right, -1 left) edge of an elliptic cross-section (half width w,
    half depth `depth`, centre z0 in front of the axis): side(sqrt(w2c2 + d2s2) - w) + z0 sin."""
    if w == 0:
        return [(0.0, ()), (z0, (SIN,))]
    return [(-side * w, ()), (side, (("sil", w * w, depth * depth),)), (z0, (SIN,))]


def fit3(at_neg: float, at_zero: float, at_pos: float, k: float) -> Poly:
    """Shift poly (0 at a = 0) through three authored poses: input -1, 0, +1 (angle -k, 0, k).

    Solves c0 + c1 cos a + c2 sin a exactly; the result is the path of a material point
    (X = c1, Z = c2) with an offset, so in-betweens follow a rotation arc.
    """
    c2 = (at_pos - at_neg) / (2 * math.sin(k))
    c1 = ((at_pos + at_neg) / 2 - at_zero) / (math.cos(k) - 1)
    c0 = at_zero - c1
    return [(c0 - at_zero, ()), (c1, (COS,)), (c2, (SIN,))]


# ------------------------------------------------------------------ formula tokens


class Formulas:
    """Builds DataConverterFormula token lists; `vm_path(prop)` resolves bound tokens."""

    def __init__(self, d: Doc, vm_path: Callable[[str], str]) -> None:
        self.d = d
        self.vm_path = vm_path

    def val(self, v: float) -> El:
        return self.d("FormulaTokenValue", operationValue=round(float(v), DIGITS))

    def bound(self, prop: str) -> El:
        return self.d("FormulaTokenValue", self.d("DataBindContext", sourcePathIds=self.vm_path(prop),
                                                  propertyKey=777), operationValue=0.0)

    def op(self, o: str) -> El:
        return self.d("FormulaTokenOperation", operationType=OPS[o])

    def fn(self, f: str, *args: list[El]) -> list[El]:
        out: list[El] = [self.d("FormulaTokenFunction", functionType=FNS[f])]
        for i, a in enumerate(args):
            if i:
                out.append(self.d("FormulaTokenArgumentSeparator"))
            out += a
        return out + [self.d("FormulaTokenParenthesisClose")]

    def inp(self) -> list[El]:
        return [self.d("FormulaTokenInput")]

    def factor(self, f: Factor) -> list[El]:
        if f[0] in ("cos", "sin"):
            return self.fn(str(f[0]), self.inp())
        if f[0] == "tok":
            return [self.bound(str(f[1]))]
        if f[0] == "tokpos":
            return self.fn("max", [self.val(0)], [self.bound(str(f[1]))])
        w2, d2 = float(f[1]), float(f[2])  # type: ignore[arg-type]
        inner = [self.val(w2), self.op("*"), *self.fn("cos", self.inp()), self.op("*"), *self.fn("cos", self.inp()),
                 self.op("+"), self.val(d2), self.op("*"), *self.fn("sin", self.inp()), self.op("*"),
                 *self.fn("sin", self.inp())]
        return self.fn("sqrt", inner)

    def poly(self, p: Poly) -> list[El]:
        out: list[El] = []
        terms = [(c, fs) for c, fs in p if fs or abs(c) > 1e-9] or [(0.0, ())]
        for i, (c, fs) in enumerate(terms):
            if i:
                out.append(self.op("+"))
            out.append(self.val(c))
            for f in fs:
                out += [self.op("*"), *self.factor(f)]
        return out

    def angle(self, k: float, lo: float = -1.0, hi: float = 1.0) -> list[El]:
        """k * min(hi, max(lo, input))."""
        return [self.val(k), self.op("*"), *self.fn("min", [self.val(hi)], self.fn("max", [self.val(lo)], self.inp()))]


def poly_key(p: Poly) -> tuple[object, ...]:
    """Hashable identity of a poly at formula precision (dedupes identical converters)."""
    return tuple((round(c, DIGITS), fs) for c, fs in p if fs or abs(round(c, DIGITS)) > 0)


# ------------------------------------------------------------------ bones


@dataclass
class Axis:
    prop: str  # view-model number
    k: float  # radians per unit of input
    lo: float = -1.0
    hi: float = 1.0


@dataclass
class BoneSpec:
    name: str
    x: float  # rest position, art space (absolute)
    y: float
    dx: Poly | None = None  # screen-x shift as a function of the "x" axis angle
    dy: Poly | None = None  # screen-y shift as a function of the "y" axis angle
    rot: float = 0.0  # world rotation at bind
    el: El | None = None


@dataclass
class Rig:
    """Bones nested in a frame `Bone` whose world rotation is -pi/2 (pointing up) at `origin`.

    Each face bone is a RootBone (rotation pi/2, so its world rotation is 0): local x = up,
    local y = right. `x_axis` drives screen x (bind key 91), `y_axis` screen y (key 90).
    `offset` maps art space to artboard space (art is authored in absolute coordinates).
    """

    d: Doc
    vm_path: Callable[[str], str]
    origin: tuple[float, float]
    x_axis: Axis
    y_axis: Axis
    offset: tuple[float, float] = (0.0, 0.0)
    live: bool = True  # False: bones without binds (size baselines)
    bones: dict[str, BoneSpec] = field(default_factory=dict)
    binds: list[El] = field(default_factory=list)
    converters: list[El] = field(default_factory=list)
    _angles: dict[str, El] = field(default_factory=dict)
    _polys: dict[tuple[object, ...], El] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self.f = Formulas(self.d, self.vm_path)

    def angle(self, axis: Axis) -> El:
        if axis.prop not in self._angles:
            conv = self.d("DataConverterFormula", *self.f.angle(axis.k, axis.lo, axis.hi), name=axis.prop + "Angle")
            self._angles[axis.prop] = conv
            self.converters.append(conv)
        return self._angles[axis.prop]

    def chain(self, axis: Axis, p: Poly) -> El:
        """Shared angle -> this poly (identical polys share one group)."""
        key = (axis.prop, poly_key(p))
        if key not in self._polys:
            conv = self.d("DataConverterFormula", *self.f.poly(p))
            group = self.d("DataConverterGroup", self.d("DataConverterGroupItem", converterId=self.angle(axis).ref()),
                           self.d("DataConverterGroupItem", converterId=conv.ref()))
            self.converters += [conv, group]
            self._polys[key] = group
        return self._polys[key]

    def local(self, x: float, y: float) -> tuple[float, float]:
        return -(y - self.origin[1]), x - self.origin[0]

    def bone(self, spec: BoneSpec) -> El:
        lx, ly = self.local(spec.x, spec.y)
        binds: list[El] = []
        if self.live and spec.dx is not None:
            binds.append(self.d("DataBindContext", sourcePathIds=self.vm_path(self.x_axis.prop), propertyKey=91,
                                converterId=self.chain(self.x_axis, poly_shift(spec.dx, ly)).ref()))
        if self.live and spec.dy is not None:
            binds.append(self.d("DataBindContext", sourcePathIds=self.vm_path(self.y_axis.prop), propertyKey=90,
                                converterId=self.chain(self.y_axis, poly_shift(spec.dy, lx, -1.0)).ref()))
        self.binds.extend(binds)
        spec.el = self.d("RootBone", *binds, x=lx, y=ly, rotation=PI / 2, length=4.0, name=spec.name)
        self.bones[spec.name] = spec
        return spec.el

    def add_static(self, name: str, el: El, x: float, y: float, rot: float) -> None:
        self.bones[name] = BoneSpec(name, x, y, rot=rot, el=el)

    def position(self, name: str, ax: float, ay: float, env: dict[str, float] | None = None) -> tuple[float, float]:
        """Predicted art-space position of a bone at axis angles (ax, ay) (no frame roll)."""
        b = self.bones[name]
        x = b.x + (eval_poly(b.dx, ax, env) if b.dx else 0.0)
        y = b.y + (eval_poly(b.dy, ay, env) if b.dy else 0.0)
        return x, y

    def tendon(self, name: str) -> El:
        b = self.bones[name]
        assert b.el is not None
        c, s = math.cos(b.rot), math.sin(b.rot)
        return self.d("Tendon", boneId=b.el.ref(), xx=round(c, 6), xy=round(s, 6), yx=round(-s, 6), yy=round(c, 6),
                      tx=b.x - self.offset[0], ty=b.y - self.offset[1])


# ------------------------------------------------------------------ weights

Weights = dict[str, float]
WeightFn = Callable[[float, float], Weights]


def rigid(name: str) -> WeightFn:
    def f(_x: float, _y: float) -> Weights:
        return {name: 1.0}
    return f


def mix(*parts: tuple[float, Weights]) -> Weights:
    """Weighted sum of weight dicts."""
    out: Weights = {}
    for s, ws in parts:
        for b, w in ws.items():
            out[b] = out.get(b, 0.0) + s * w
    return out


def tent(v: float, axis: Sequence[float]) -> list[tuple[int, float]]:
    """1-D tent weights of v over sorted `axis` (clamped at the ends): [(index, weight)]."""
    if v <= axis[0]:
        return [(0, 1.0)]
    if v >= axis[-1]:
        return [(len(axis) - 1, 1.0)]
    for i in range(len(axis) - 1):
        if v <= axis[i + 1]:
            t = (v - axis[i]) / (axis[i + 1] - axis[i])
            return [(i, 1 - t), (i + 1, t)]
    return [(len(axis) - 1, 1.0)]


@dataclass
class Grid:
    """Bilinear (tent) weights over a lattice of bones named `name(c, r)`."""

    xs: Sequence[float]
    ys: Sequence[float]
    name: Callable[[int, int], str]

    def __call__(self, x: float, y: float) -> Weights:
        out: Weights = {}
        for c, wx in tent(x, self.xs):
            for r, wy in tent(y, self.ys):
                if wx * wy > 0:
                    out[self.name(c, r)] = out.get(self.name(c, r), 0.0) + wx * wy
        return out


@dataclass
class Chain:
    """1-D tent along anchors [(param, bone)] with param = key(x, y) (e.g. an angle)."""

    anchors: Sequence[tuple[float, str]]
    key: Callable[[float, float], float]

    def __call__(self, x: float, y: float) -> Weights:
        params = [a for a, _ in self.anchors]
        out: Weights = {}
        for i, w in tent(self.key(x, y), params):
            b = self.anchors[i][1]
            out[b] = out.get(b, 0.0) + w
        return out


def quantize(ws: Weights) -> list[tuple[str, int]]:
    """Top 4 influences as bytes summing to exactly 255."""
    items = sorted(((w, b) for b, w in ws.items() if w > 1e-6), reverse=True)[:4]
    tot = sum(w for w, _ in items)
    q = [int(w / tot * 255) for w, _ in items]
    q[0] += 255 - sum(q)
    return [(b, v) for (_, b), v in zip(items, q) if v > 0]


def pack(qs: list[tuple[str, int]], index: dict[str, int]) -> tuple[int, int]:
    values = indices = 0
    for slot, (b, v) in enumerate(qs):
        indices |= (index[b] + 1) << (8 * slot)
        values |= v << (8 * slot)
    return values, indices


# ------------------------------------------------------------------ skinned paths

Pt = Union[tuple[float, float], tuple[float, float, str]]


def shoelace(pts: Sequence[Pt]) -> float:
    n = len(pts)
    return sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))


def clockwise(pts: list[Pt]) -> list[Pt]:
    """Same polygon, wound clockwise in y-down space (positive shoelace): feathered fills need it."""
    return pts if shoelace(pts) > 0 else list(reversed(pts))


@dataclass
class Skinner:
    """Catmull-Rom paths through absolute art-space points, skinned to `rig`'s bones."""

    rig: Rig
    weighted: bool = True
    vertices: int = 0

    def path(self, pts: Sequence[Pt], wf: WeightFn | Sequence[WeightFn] | None, closed: bool = True,
             tension: float = 1.0) -> El:
        """`wf=None` writes an unskinned path (art that never moves costs no weights or tendons)."""
        weighted = self.weighted and wf is not None
        if wf is None:
            wf = rigid("")
        d, ox, oy = self.rig.d, self.rig.offset[0], self.rig.offset[1]
        n = len(pts)
        xy = [(float(p[0]), float(p[1])) for p in pts]
        raw: list[tuple[str, tuple[float, ...], list[list[tuple[str, int]]]]] = []
        for i, p in enumerate(pts):
            f = wf if callable(wf) else wf[i]
            x, y = xy[i]
            if len(p) == 3:
                raw.append(("s", (x, y), [quantize(f(x, y))]))
                continue
            if not closed and (i == 0 or i == n - 1):
                prv = xy[i] if i == 0 else xy[i - 1]
                nxt = xy[i] if i == n - 1 else xy[i + 1]
            else:
                prv, nxt = xy[(i - 1) % n], xy[(i + 1) % n]
            tx, ty = (nxt[0] - prv[0]) * tension / 6.0, (nxt[1] - prv[1]) * tension / 6.0
            dn, dp = math.hypot(nxt[0] - x, nxt[1] - y), math.hypot(prv[0] - x, prv[1] - y)
            tl, tot = math.hypot(tx, ty) or 1.0, (dn + dp) or 1.0
            out_d, in_d = tl * 2 * dn / tot, tl * 2 * dp / tot
            ang = math.atan2(ty, tx)
            pin = (x + math.cos(ang + PI) * in_d, y + math.sin(ang + PI) * in_d)
            pout = (x + math.cos(ang) * out_d, y + math.sin(ang) * out_d)
            raw.append(("c", (x, y, ang, in_d, out_d), [quantize(f(x, y)), quantize(f(*pin)), quantize(f(*pout))]))
        index: dict[str, int] = {}
        for _, _, qss in raw:
            for qs in qss:
                for b, _ in qs:
                    index.setdefault(b, len(index))
        verts: list[El] = []
        for kind, g, qss in raw:
            self.vertices += 1
            if kind == "s":
                kids = [d("Weight", values=pack(qss[0], index)[0], indices=pack(qss[0], index)[1])] \
                    if weighted else []
                verts.append(d("StraightVertex", *kids, x=g[0] - ox, y=g[1] - oy))
                continue
            x, y, ang, in_d, out_d = g
            kids = []
            if weighted:
                (v, ix), (iv, iix), (ov, oix) = (pack(q, index) for q in qss)
                kids = [d("CubicWeight", values=v, indices=ix, inValues=iv, inIndices=iix, outValues=ov,
                          outIndices=oix)]
            verts.append(d("CubicDetachedVertex", *kids, x=x - ox, y=y - oy, outRotation=ang, outDistance=out_d,
                           inRotation=ang + PI, inDistance=in_d))
        skin = d("Skin", *[self.rig.tendon(b) for b in index], tx=0.0, ty=0.0) if weighted else None
        return d("PointsPath", *verts, skin, isClosed=closed, isClockwise=shoelace(xy) > 0)


def taper(pts: Sequence[tuple[float, float]], width: float, ends: float = 0.15) -> list[Pt]:
    """Closed outline of an open stroke through `pts`, `width` thick in the middle and
    `ends` x width at both ends (tapered line art drawn as a fill)."""
    n = len(pts)
    left: list[Pt] = []
    right: list[Pt] = []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        t = i / (n - 1)
        w = width / 2 * (ends + (1 - ends) * math.sin(PI * t))
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + list(reversed(right))


# ------------------------------------------------------------------ motion: springs and keys


def critically_damped(x: float, v: float, target: float, omega: float, dt: float) -> tuple[float, float]:
    """Exact step of a critically damped spring (no overshoot from rest): returns (x, v) after dt."""
    e = x - target
    k = v + omega * e
    decay = math.exp(-omega * dt)
    return target + (e + k * dt) * decay, (v - omega * k * dt) * decay


def omega_for_settle(seconds: float, tolerance: float = 0.05) -> float:
    """omega such that a critically damped step from rest is within `tolerance` at `seconds`."""
    lo, hi = 0.1, 500.0
    for _ in range(80):
        mid = (lo + hi) / 2
        t = mid * seconds
        if (1 + t) * math.exp(-t) > tolerance:
            lo = mid
        else:
            hi = mid
    return hi


@dataclass
class SecondOrder:
    """Second-order follower y'' driven by x (frequency f Hz, damping zeta, response r).

    k1 = zeta / (pi f), k2 = 1 / (2 pi f)^2, k3 = r zeta / (2 pi f); semi-implicit Euler with a
    stability clamp on k2 (T. Holmer's formulation). zeta < 1 overshoots, r < 0 anticipates.
    """

    f: float
    zeta: float
    r: float = 0.0
    y: float = 0.0
    yd: float = 0.0
    xp: float = 0.0

    def reset(self, x: float) -> None:
        self.y, self.yd, self.xp = x, 0.0, x

    def step(self, x: float, dt: float) -> float:
        k1 = self.zeta / (PI * self.f)
        k2 = 1 / ((2 * PI * self.f) ** 2)
        k3 = self.r * self.zeta / (2 * PI * self.f)
        xd = (x - self.xp) / dt
        self.xp = x
        k2s = max(k2, dt * dt / 2 + dt * k1 / 2, dt * k1)
        self.y += dt * self.yd
        self.yd += dt * (x + k3 * xd - self.y - k1 * self.yd) / k2s
        return self.y


def simplify(values: Sequence[float], tol: float) -> list[tuple[int, float]]:
    """Linear keys (frame, value) reproducing `values` (one per frame) within `tol` (RDP)."""
    n = len(values)
    if n <= 2:
        return [(i, float(v)) for i, v in enumerate(values)]
    keep = {0, n - 1}
    stack = [(0, n - 1)]
    while stack:
        i0, i1 = stack.pop()
        worst, at = 0.0, -1
        for i in range(i0 + 1, i1):
            lerp = values[i0] + (values[i1] - values[i0]) * (i - i0) / (i1 - i0)
            err = abs(values[i] - lerp)
            if err > worst:
                worst, at = err, i
        if worst > tol:
            keep.add(at)
            stack += [(i0, at), (at, i1)]
    return [(i, float(values[i])) for i in sorted(keep)]


def interp_keys(keys: Sequence[tuple[int, float]], frame: float) -> float:
    """Value of linear keys at `frame` (holds before the first and after the last)."""
    if frame <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if frame <= f1:
            return v0 + (v1 - v0) * (frame - f0) / (f1 - f0)
    return keys[-1][1]


@dataclass
class TurnParams:
    """A performed head turn, built on the art bible's MotionRules (the runtime driver ports the
    same maths to Dart). Times in seconds, angles in view-model units."""

    lead_s: float = 0.08  # the eyes move first; the head starts this much later
    eye_settle_s: float = 0.14  # eye (saccade-like) spring toward the target
    gaze_max: float = 0.8  # eye-in-head rotation saturates softly (tanh)
    antic: float = 0.2  # counter-yaw wind-up fed to the spring (output ~ MOTION.anticipation)
    antic_s: float = 0.13
    ramp_s: float = 0.58  # speed cap: the shaped target travels in ramp_s + ramp_per_unit * |delta|
    ramp_per_unit: float = 0.1
    over: float = 0.11  # overshoot share fed to the spring, settled over settle_s (MOTION.settle_ms)
    settle_s: float = 0.22
    spring_f: float = 2.6  # under-damped head spring (Hz) smoothing the shaped target
    spring_zeta: float = 0.68
    blink_jump: float = 0.5  # |delta yawTarget| that may trigger a blink
    blink_gap_s: float = 2.6  # MOTION.blink_ms lower bound between blinks
    blink_delay_s: float = 0.06  # the eyes visibly lead before the lids close
    blink_kinds: tuple[str, ...] = ("full", "double", "half")
    roll_gain: float = 0.3  # roll = tanh(gain * yaw speed), smoothed
    dip_gain: float = 0.12  # pitch dip = dip_max * tanh(gain * |yaw speed|), smoothed
    dip_max: float = 0.45
    accent_f: float = 2.6  # follower that smooths roll and dip (Hz, critically damped)
    hair_f: float = 2.1  # fringe follower (Hz, zeta)
    hair_zeta: float = 0.5
    side_delay_s: float = 0.04  # side locks and bob trail the fringe by MOTION.part_offset_ms
    tuft_f: float = 1.4  # crown tuft: slower and looser (more trail, a second bounce)
    tuft_zeta: float = 0.35
    look_min: float = 0.15  # |delta| that counts as a "look" (brow raise, mouth shift)
    breath_amp: float = 0.012  # idle: pitch breath, roll drift, micro-saccades
    breath_cycles: int = 2
    drift_amp: float = 0.06
    saccade_amp: float = 0.07
    saccade_every_s: tuple[float, float] = (0.6, 1.2)
    seed: int = 7


def _smoothstep(u: float) -> float:
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def _bump(t: float, attack: float, release: float) -> float:
    """0 -> 1 over `attack` s, back to 0 over `release` s (smooth); 0 outside."""
    if t <= 0 or t >= attack + release:
        return 0.0
    return _smoothstep(t / attack) if t < attack else 1 - _smoothstep((t - attack) / release)


def shaped_target(targets: Sequence[tuple[float, float]], t: float, p: TurnParams) -> float:
    """The head's target with anticipation, a speed cap and overshoot: each step winds up by
    `antic` x delta the other way, travels past the new value by `over` x delta along a
    smoothstep (ramp_s + ramp_per_unit x |delta|), then settles back over `settle_s`."""
    cur = targets[0][1]
    for t0, v in targets[1:]:
        u = t - t0 - p.lead_s
        if u < 0:
            break
        delta = v - cur
        ramp = p.ramp_s + p.ramp_per_unit * abs(delta)
        if u < p.antic_s:
            return cur - p.antic * delta * _smoothstep(u / p.antic_s)
        if u < p.antic_s + ramp:
            return cur - p.antic * delta + (1 + p.antic + p.over) * delta * _smoothstep((u - p.antic_s) / ramp)
        if u < p.antic_s + ramp + p.settle_s:
            return v + p.over * delta * (1 - _smoothstep((u - p.antic_s - ramp) / p.settle_s))
        cur = v
    return cur


CHANNELS: tuple[str, ...] = ("yaw", "pitch", "roll", "gaze", "blink", "hairLag", "sideLag", "tuftLag", "brow",
                             "mouth")


def perform_turn(targets: Sequence[tuple[float, float]], seconds: float, fps: int = 60,
                 p: TurnParams | None = None, pitch: float = 0.0) -> dict[str, list[float]]:
    """Bake a performed turn: `targets` = [(time s, yawTarget)] steps (the last one should
    return to the first value for a loop). Returns per-frame CHANNELS (frames 0..seconds*fps).

    - yaw: an under-damped spring (overshoot) on the shaped target (anticipation, speed cap),
      started `lead_s` after the eyes;
    - gaze: eye-in-head yaw (a fast eye spring minus the head) plus idle micro-saccades;
    - blink: on big steps at least `blink_gap_s` apart, cycling full / double / half;
    - roll and pitch dip: smoothed functions of the head's speed, plus idle breath and drift
      whose cycles divide the loop (seamless);
    - hairLag / sideLag / tuftLag: second-order followers on the head yaw minus the head yaw
      (fringe; side locks 40 ms later; the crown tuft slower and looser);
    - brow, mouth: a raise and a smile shift on every look, scaled by the step.
    """
    p = p or TurnParams()
    n = int(round(seconds * fps)) + 1
    dt = 1.0 / fps
    times = [i * dt for i in range(n)]

    def step_target(t: float) -> float:
        cur = targets[0][1]
        for t0, v in targets:
            if t >= t0 - 1e-9:
                cur = v
        return cur

    def follow(xs: list[float], f: float, zeta: float) -> list[float]:
        fo = SecondOrder(f, zeta)
        fo.reset(xs[0])
        return [fo.step(x, dt) if i else fo.y for i, x in enumerate(xs)]

    def spring(xs: list[float], settle: float) -> list[float]:
        w = omega_for_settle(settle)
        x, v = xs[0], 0.0
        out: list[float] = []
        for tgt in xs:
            out.append(x)
            x, v = critically_damped(x, v, tgt, w, dt)
        return out

    yaw = follow([shaped_target(targets, t, p) for t in times], p.spring_f, p.spring_zeta)
    eye = spring([step_target(t) for t in times], p.eye_settle_s)
    speed = [0.0] + [(yaw[i] - yaw[i - 1]) / dt for i in range(1, n)]
    # idle layer: whole cycles over the loop, so the seam stays clean
    breath = [p.breath_amp * math.sin(2 * PI * p.breath_cycles * t / seconds) for t in times]
    drift = [p.drift_amp * (math.sin(2 * PI * t / seconds + 0.6) - math.sin(0.6)) for t in times]
    rng = random.Random(p.seed)
    sacc_t = 0.0
    sacc: list[tuple[float, float]] = []
    while True:
        sacc_t += rng.uniform(*p.saccade_every_s)
        if sacc_t > seconds - 0.8:
            break
        sacc.append((sacc_t, rng.uniform(-1, 1) * p.saccade_amp))
    sacc.append((seconds - 0.6, 0.0))
    micro = spring([next((v for t0, v in reversed(sacc) if t >= t0), 0.0) for t in times], 0.05)
    roll = follow([math.tanh(p.roll_gain * s) for s in speed], p.accent_f, 1.0)
    dip = follow([p.dip_max * math.tanh(p.dip_gain * abs(s)) for s in speed], p.accent_f, 1.0)
    hair_yaw = follow(yaw, p.hair_f, p.hair_zeta)
    delay = round(p.side_delay_s * fps)
    side_yaw = follow([yaw[max(0, i - delay)] for i in range(n)], p.hair_f, p.hair_zeta)
    tuft_yaw = follow(yaw, p.tuft_f, p.tuft_zeta)

    blink = [0.0] * n
    brow = [0.0] * n
    mouth = [0.0] * n

    def add_blink(start: float, amp: float, close: float = 0.06, hold: float = 0.04, open_: float = 0.1) -> None:
        for i, t in enumerate(times):
            u = t - start
            if 0 <= u < close:
                val = _smoothstep(u / close)
            elif close <= u < close + hold:
                val = 1.0
            elif close + hold <= u < close + hold + open_:
                val = 1 - _smoothstep((u - close - hold) / open_)
            else:
                continue
            blink[i] = max(blink[i], amp * val)

    prev, last_blink, kind = targets[0][1], -1e9, 0
    for t0, v in targets[1:]:
        delta = abs(v - prev)
        if delta > p.blink_jump and t0 - last_blink >= p.blink_gap_s:
            k = p.blink_kinds[kind % len(p.blink_kinds)]
            start = t0 + p.blink_delay_s
            add_blink(start, 0.6 if k == "half" else 1.0)
            if k == "double":
                add_blink(start + 0.3, 0.75, 0.05, 0.02, 0.09)
            last_blink, kind = t0, kind + 1
        if delta > p.look_min:
            amp = min(1.0, 0.35 + 0.45 * delta)
            for i, t in enumerate(times):
                brow[i] = max(brow[i], amp * _bump(t - t0 - 0.02, 0.2, 0.75))
                mouth[i] = max(mouth[i], 0.8 * amp * _bump(t - t0 - 0.14, 0.25, 0.9))
        prev = v
    return {
        "yaw": yaw,
        "pitch": [pitch - dd + b for dd, b in zip(dip, breath)],
        "roll": [r_ + dr for r_, dr in zip(roll, drift)],
        "gaze": [p.gaze_max * math.tanh((e - y) / p.gaze_max) + m for e, y, m in zip(eye, yaw, micro)],
        "blink": blink,
        "hairLag": [h - y for h, y in zip(hair_yaw, yaw)],
        "sideLag": [h - y for h, y in zip(side_yaw, yaw)],
        "tuftLag": [h - y for h, y in zip(tuft_yaw, yaw)],
        "brow": brow,
        "mouth": mouth,
    }


def keyed(d: Doc, target: El, keys: Iterable[tuple[int, float]], prop: str = "propertyValue") -> El:
    """KeyedObject with linear KeyFrameDoubles."""
    kfs = [d("KeyFrameDouble", frame=f, value=round(v, 4), interpolationType="linear") for f, v in keys]
    return d("KeyedObject", d("KeyedProperty", *kfs, property=prop), objectId=target.ref())
