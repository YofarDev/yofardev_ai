"""Yaw / pitch rig for the shipped avatar's own head art (moonshot M1, Task 9 -> 10).

Called by gen_avatar.py after the head, wardrobe and view model exist. It adds AvatarVM numbers
`yaw` and `pitch` (-1..1; yaw +1 = the character turns toward the viewer's right, 30 deg;
pitch +1 = looks up, 15 deg) and makes the head art follow them on ONE surface model (the
round-4 head v2 model: an ellipsoid cranium, elliptic face sections, features as points on that
surface). Every pose is a history-free formula of the two numbers (rig_dsl drives).

Two mechanisms, chosen so every existing animation keeps working untouched:

- Pivot sandwich (features, glasses, ears, hair layers, hats): the element is wrapped in
  W1(W2(element)). W1 sits at a pivot and binds x / y / scaleX (and rotation / scaleY for hair
  locks) to yaw / pitch; W2 sits at minus the pivot, so at rest the wrapper is the identity and
  the element keeps its own (possibly keyed) transform. Moods, mouth shapes, blinks, gaze,
  gestures, the hair spring and the wardrobe Solos all still play inside the wrapper.
- Skin (the face outline and the two shading shapes that hug it): skinned to RootBones placed
  under the `Head` node, so head gestures (nod, shake, think) carry the bones and the turn
  composes underneath them. Contour bones take their yaw poses from the exact silhouettes of the
  head sections (M3: superellipse fronts and backs, so the far cheekbone bulges and the near jaw
  corner holds while the chin swings: the outline changes shape at 3/4); bind transforms are
  expressed in the Head frame. M3 extras (`three_quarter`): per-side blush, face-clipped lenses,
  the far temple fade.

New elements use their own id range (ID_START), so no existing component id moves.
"""

from __future__ import annotations

import math
from typing import Callable, Sequence

import rig_dsl as r
from rig_dsl import (Axis, Chain, Grid, Poly, Weights, fit3, material_dx, pitch_dy, plain_tendon, poly_add,
                     poly_scale, sampled, skinned_path, tokabs)
from rml import Doc, El, smooth_path  # noqa: F401

ID_START = 900000
PI = math.pi
CX, CY = 400.0, 380.0  # yaw axis x, pitch pivot y (art space)
ZP = -20.0  # pitch axis depth
K_YAW = round(math.radians(30), 4)
K_PITCH = round(math.radians(15), 4)
HEAD_FRAME = (400.0, 560.0)  # the Head rig's art-space origin (children are authored against it)
KEYS = {"x": 13, "y": 14, "rotation": 15, "scaleX": 16, "scaleY": 17, "opacity": 18}
PROPS = ("yaw", "pitch", "hairLagYaw", "hairLagPitch", "eyeLeadYaw", "eyeLeadPitch")
# eye lead, in the Look node's units (the eye is drawn at 1.06 inside a 1.18 head): 15.5 -> ~19
# artboard px, about 30 % of the eye-white width; 7.6 -> ~9.5 px, about 25 % of its height
EYE_LEAD_PX = 15.5
EYE_LEAD_PITCH_PX = 7.6  # looking up
EYE_LEAD_DOWN_PX = 12.2  # looking down: ~15 artboard px, about 40 % of the eye-white height
# far eye (|yaw| > 0.4): the lead is cut by up to FAR_EYE_CUT, so >= ~60 % of the iris stays in
# the foreshortened white
FAR_EYE_CUT = 0.7
BROW_LIFT_PX = 3.0  # brows lift ~3.5 artboard px at eyeLeadPitch -1 (attentive, on top of moods)
# fringe follow-through: tip travel per unit of lag is boosted at small lags and saturates at
# +-1 (gain 1.7 - 0.7 |lag|: 1.42x at 0.4, unchanged at 1)
FRINGE_LAG_GAIN = (1.7, 0.7)
# fringe parallax (critic round 1: the fringe barely moved at 3/4): a clump hangs in front of the
# forehead, so its tip travels FRINGE_PARALLAX x its own depth's yaw travel further than the art
# does (root pinned under the cap): ~ +20 px at the centre tips at yaw +-1, little at the temples
FRINGE_PARALLAX = 0.4
# looking down (eyeLeadPitch < 0) drops the upper lid bones (M3: face_rig.LOOK_DOWN_PX)
# hair follow-through: px of tip travel per unit of lag (the roots stay with the head)
SIDE_LAG_PX, SIDE_LAG_PITCH_PX = 45.0, 20.0
TUFT_LAG_PX = 20.0
BACK_LAG_PX, BACK_LAG_PITCH_PX = 40.0 * 1.3, 20.0 * 1.3


# ------------------------------------------------------------------ the surface model (head v2)

def surface_z(x3: float, y: float) -> float:
    """Depth in front of the yaw axis of the face surface at (X, y)."""
    yy = y - CY
    if yy <= 0:
        return 100.0 * math.sqrt(max(0.0, 1 - (x3 / 108) ** 2 - (yy / 160) ** 2))
    pts = [(380, 108), (410, 104), (440, 95), (462, 83), (484, 63), (500, 38), (511, 1)]
    w = pts[-1][1]
    for (y0, w0), (y1, w1) in zip(pts, pts[1:]):
        if y <= y1:
            w = w0 + (w1 - w0) * (y - y0) / (y1 - y0)
            break
    w *= 1 + 0.17 * min(1.0, yy / 60)
    depth = 100 - 25 * min(1.0, yy / 131)
    return depth * math.sqrt(max(0.0, 1 - (x3 / w) ** 2))


HAIR_C = (338.0, -20.0)  # hair shell centre (y, z)
HAIR_A = (127.0, 146.0, 130.0)


def shell_z(x3: float, y: float) -> float:
    q = 1 - (x3 / HAIR_A[0]) ** 2 - ((y - HAIR_C[0]) / HAIR_A[1]) ** 2
    return HAIR_C[1] + HAIR_A[2] * math.sqrt(max(0.0, q))


# critic round 3: the lower face is a volume that projects forward (the jaw sections' centres move
# toward the chin's front), so at 3/4 the chin and the jaw line swing with the turn (the y 505 jaw
# midpoint travels ~45 artboard px, was ~26) while the near jaw corner holds
Z0 = [(330.0, 8.0), (366.0, 10.0), (396.0, 14.0), (428.0, 22.0), (458.0, 32.0), (476.0, 46.0), (490.0, 70.0),
      (505.0, 84.0), (511.0, 88.0)]


def _lerp(table: Sequence[tuple[float, float]], y: float) -> float:
    if y <= table[0][0]:
        return table[0][1]
    for (y0, v0), (y1, v1) in zip(table, table[1:]):
        if y <= y1:
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
    return table[-1][1]


# Face contour sections (M3). Each contour height is a cross-section of the head: half width w (the
# rest outline), half depth dd (0.82 w + 8, plus a soft cheekbone swell) about a centre z0 (Z0,
# moving forward toward the chin). Its front half is a superellipse of exponent SECTION_FRONT_N:
# above 2 the face plane flattens and the cheekbone sits out at its corner, so at yaw +1 the far
# (right) cheekbone bulges past the old outline. Its back half takes SECTION_BACK_N: the jaw angle,
# so on the near side the jaw corner stays out while the chin swings toward the turn (the near
# cheek flattens into one jaw line). The yaw +-1 poses are the sections' exact silhouettes; fit3
# carries the in-betweens on arcs. All exponents 2 give the M1 ellipse model (ellipse_contour_pose).
SECTION_FRONT_N = [(330.0, 2.0), (366.0, 2.3), (396.0, 2.7), (428.0, 2.9), (458.0, 2.4), (476.0, 2.1),
                   (490.0, 2.0)]
SECTION_BACK_N = [(330.0, 2.0), (366.0, 2.0), (396.0, 2.0), (428.0, 2.8), (458.0, 4.0), (476.0, 3.4),
                  (490.0, 2.6), (505.0, 2.0)]


# The far and near cheeks (critic round 3: the 3/4 turn slid the features over a face that kept its
# shape). Storybook 3/4 is drawn, not measured: below the cheekbone the far cheek flattens (its
# section loses FAR_FLAT of its width and depth at the far pose, so the far contour dips in under
# the cheekbone and the nose tip breaks over it), and the near cheek fills out (the section gains
# NEAR_FULL of its width at the near pose). Rest poses are unchanged; fit3 carries the in-betweens.
FAR_FLAT = [(396.0, 0.0), (428.0, 0.237), (458.0, 0.326), (476.0, 0.15), (490.0, 0.15), (505.0, 0.0)]
NEAR_FULL = [(366.0, 0.0), (396.0, 0.06), (428.0, 0.09), (458.0, 0.09), (476.0, 0.05), (490.0, 0.0)]


def section(x: float, y: float, round_: bool = False) -> tuple[float, float, float, float, float]:
    """(w, z0, dd, n_front, n_back) of the right-side contour section through (x, y)."""
    w = x - CX
    dd = 0.82 * w + 8 + 8 * math.exp(-(((y - 396) / 22) ** 2))
    if round_:
        return w, _lerp(Z0, y), dd, 2.0, 2.0
    return w, _lerp(Z0, y), dd, _lerp(SECTION_FRONT_N, y), _lerp(SECTION_BACK_N, y)


def contour_pose(x: float, y: float) -> tuple[float, float]:
    """Right-side face contour x at yaw -1 (the near side) / +1 (the far side): the silhouettes of
    the section through (x, y). The left side mirrors it."""
    w, z0, dd, nf, nb = section(x, y)
    q, g = _lerp(FAR_FLAT, y), _lerp(NEAR_FULL, y)
    return (CX + r.section_silhouette(w * (1 + g), z0, dd, nf, nb, -K_YAW),
            CX + r.section_silhouette(w * (1 - q), z0, dd * (1 - q), nf, nb, K_YAW))


def ellipse_contour_pose(x: float, y: float) -> tuple[float, float]:
    """The M1 contour (round elliptic sections): every height slides, none changes shape."""
    sec = section(x, y, round_=True)
    return CX + r.section_silhouette(*sec, -K_YAW), CX + r.section_silhouette(*sec, K_YAW)


# Features on ONE surface (M3): nose, mouth, chin, mole, cheeks and blush all take their depth from
# surface_z (+ a relief for the nose tip and the lips), so the mouth leads with the nose and the
# chin, instead of lagging behind them.
NOSE_RELIEF = 30.0  # the nose (bridge) stands off the face surface: it rides under the glasses' bridge
NOSE_TIP_RELIEF = 56.0  # the nose tip stands further out (round 3: at 3/4 it breaks over the far cheek)
LIP_RELIEF = 14.0  # the lips ride a little ahead of the chin (the mouth trails the nose by <= 15)
CHIN_RELIEF = 8.0  # the chin's point stands off the jaw surface (it swings with the jaw sections)


def face_z(x: float, y: float, relief: float = 0.0) -> float:
    return surface_z(x - CX, y) + relief


MOUTH_Z = face_z(400.0, 478.0, LIP_RELIEF)
NOSE_Z = face_z(400.0, 440.0, NOSE_RELIEF)
NOSE_TIP_Z = face_z(400.0, 440.0, NOSE_TIP_RELIEF)
NOSE_SHADE_LEN = 42.0  # the nose shade's top (y 408) to the tip (y 450)
NOSE_TIP_RIGHT = 6.0  # extra tip travel at yaw +1 (see nose_tip_and_mole)
NOSE_SHADE_FOLLOW = 0.45  # share of the tip's extra travel the nose shade's bottom takes
CHIN_Z = face_z(400.0, 505.0, CHIN_RELIEF)  # the chin's front: the jaw outline's lowest point swings with it


def foreshorten(x: float, y: float, a: float) -> float:
    """Width factor of a flat mark (blush, cheek light) lying on the face surface at (x, y) when the
    head turns by `a`: cos(normal + a) / cos(normal), the normal's angle from the surface slope. The
    near side's widening is capped at NEAR_WIDEN (a mark turning to face the viewer should not
    balloon)."""
    h = 0.5
    slope = (surface_z(x - CX + h, y) - surface_z(x - CX - h, y)) / (2 * h)
    n = math.atan(-slope)
    return min(NEAR_WIDEN, math.cos(n + a) / math.cos(n))


NEAR_WIDEN = 1.12
EAR_Z, EAR_NEAR_WIDEN = -12.0, 1.18  # ear depth (behind the yaw axis) and its near-side widening


# Glasses: the frame plane wraps back from the bridge to the temples (inner end z 110, outer end
# z 70), so the far lens foreshortens like the far eye does and stays inside the far cheekbone.
LENS_Z = (110.0, 70.0)


def lens_ends(cx: float, a: float) -> tuple[float, float]:
    """Screen x of a lens's inner and outer frame ends at yaw angle `a` (lens centre cx)."""
    sgn = 1.0 if cx > CX else -1.0
    xin, xout = CX + sgn * 2, CX + sgn * 88
    return (CX + (xin - CX) * math.cos(a) + LENS_Z[0] * math.sin(a),
            CX + (xout - CX) * math.cos(a) + LENS_Z[1] * math.sin(a))


def face_point(x: float, y: float, z: float) -> Poly:
    """Shift poly of a mark on the face surface at (x, y), depth z, that rides the far cheek's
    flattening and the near cheek's fullness (FAR_FLAT, NEAR_FULL): on the far pose its section is
    scaled about the section centre like the contour's, on the near pose it moves out with the
    widened section. Equal to `mat(x, z)` where both tables are 0."""
    side = 1.0 if x >= CX else -1.0
    q, g = _lerp(FAR_FLAT, y), _lerp(NEAR_FULL, y)
    z0 = _lerp(Z0, y)
    xx = x - CX
    # far pose: yaw toward this side's sign; near: the other way
    far = CX + xx * (1 - q) * math.cos(K_YAW) + side * (z0 + (z - z0) * (1 - q)) * math.sin(K_YAW)
    near = CX + xx * (1 + g) * math.cos(K_YAW) - side * z * math.sin(K_YAW)
    return poses(*((near, x, far) if side > 0 else (far, x, near)))


def mat(x: float, z: float) -> Poly:
    return material_dx(x - CX, z)


def pit(y: float, z: float) -> Poly:
    return pitch_dy(y - CY, z - ZP)


def side(right: tuple[float, float, float], x: float) -> tuple[float, float, float]:
    """Mirror a right-side (yaw -1, 0, +1) triple for an element at x (left side swaps ends)."""
    return right if x >= CX else (right[2], right[1], right[0])


def poses(m: float, z: float, p: float) -> Poly:
    """Shift poly through three authored values (yaw -1, 0, +1) minus the rest value."""
    return fit3(m - z, 0.0, p - z, K_YAW)


def factor(m: float, p: float) -> Poly:
    """Scale poly: m at yaw -1, 1 at rest, p at yaw +1."""
    return poly_add([(1.0, ())], fit3(m - 1, 0.0, p - 1, K_YAW))


# ------------------------------------------------------------------ the rig

class HeadTurn:
    def __init__(self, vm: El, inst: El, head: El, root: El) -> None:
        self.d = Doc(client=0, start=ID_START)
        d = self.d
        self.props = {pn: d("ViewModelPropertyNumber", name=pn) for pn in PROPS}
        inst_vals = [d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref())
                     for p in self.props.values()]
        at = vm.children.index(next(c for c in vm.children if c.tag == "ViewModelInstance"))
        vm.children[at:at] = list(self.props.values())
        inst.children.extend(inst_vals)
        self.vm = vm
        self.rig = r.Rig(d, self.path, origin=(0.0, 0.0), x_axis=Axis("yaw", K_YAW), y_axis=Axis("pitch", K_PITCH))
        self.axes = {
            "yaw": self.rig.x_axis, "pitch": self.rig.y_axis,
            "eyeLead": Axis("eyeLeadYaw", 1.0),
            "eyeLeadPitch": Axis("eyeLeadPitch", 1.0),
        }
        self.head, self.root = head, root
        self.frames: dict[int, tuple[float, float]] = {}
        self._index(head, HEAD_FRAME)
        self.bones: dict[str, tuple[float, float, El]] = {}

    def path(self, pn: str) -> str:
        return f"{self.vm.ref()}-{self.props[pn].ref()}"

    @property
    def converters(self) -> list[El]:
        return self.rig.converters

    # ---- frames and tree surgery
    def _index(self, el: El, frame: tuple[float, float]) -> None:
        self.frames[id(el)] = frame
        for c in el.children:
            if c.tag in ("Node", "Solo", "Shape"):
                self._index(c, (frame[0] + float(c.attrs.get("x", 0.0)), frame[1] + float(c.attrs.get("y", 0.0))))

    def parent_of(self, target: El) -> El:
        stack = [self.head]
        while stack:
            e = stack.pop()
            for c in e.children:
                if c is target:
                    return e
                stack.append(c)
        raise KeyError(target.attrs.get("name"))

    def bind(self, axis: str, key: str, poly: Poly) -> El:
        ax = self.axes[axis]
        return self.d("DataBindContext", sourcePathIds=self.path(ax.prop), propertyKey=KEYS[key],
                      converterId=self.rig.chain(ax, poly).ref())

    def wrap(self, target: El, pivot: tuple[float, float], dx: Poly | None = None, dy: Poly | None = None,
             sx: Poly | None = None, rot: Poly | None = None, sy: Poly | None = None, name: str = "",
             xa: str = "yaw", ya: str = "pitch", opacity: Poly | None = None) -> El:
        """W1(at pivot, bound) -> W2(at -pivot) -> target. Identity at rest. `xa` / `ya` pick the
        yaw / pitch axes (e.g. the hair axes that add the follow-through lag)."""
        parent = self.parent_of(target)
        frame = self.frames[id(parent)]
        lx, ly = pivot[0] - frame[0], pivot[1] - frame[1]
        binds = []
        if dx is not None:
            binds.append(self.bind(xa, "x", r.poly_shift(dx, lx)))
        if dy is not None:
            binds.append(self.bind(ya, "y", r.poly_shift(dy, ly)))
        if sx is not None:
            binds.append(self.bind(xa, "scaleX", sx))
        if rot is not None:
            binds.append(self.bind(xa, "rotation", rot))
        if sy is not None:
            binds.append(self.bind(ya, "scaleY", sy))
        if opacity is not None:
            binds.append(self.bind(xa, "opacity", opacity))
        nm = name or str(target.attrs.get("name", "Part"))
        inner = self.d("Node", target, x=-lx, y=-ly, name=nm + "Pivot")
        outer = self.d("Node", *binds, inner, x=lx, y=ly, name=nm + "Turn")
        parent.children[parent.children.index(target)] = outer
        self.frames[id(outer)] = (frame[0] + lx, frame[1] + ly)
        self.frames[id(inner)] = frame  # so a target can be wrapped again (nested wrappers compose)
        return outer

    def raw(self, prop: str, key: str, tokens: list[El]) -> El:
        """Bind `key` through a one-off formula over `prop` (for piecewise terms like max(0, -x))."""
        conv = self.d("DataConverterFormula", *tokens)
        self.rig.converters.append(conv)
        return self.d("DataBindContext", sourcePathIds=self.path(prop), propertyKey=KEYS[key], converterId=conv.ref())

    def neg_part(self, c0: float, c1: float) -> list[El]:
        """Tokens of c0 + c1 * max(0, -min(1, input))."""
        f = self.rig.f
        return [f.val(c0), f.op("+"), f.val(c1), f.op("*"),
                *f.fn("max", [f.val(0)], [f.val(-1), f.op("*"), *f.fn("min", [f.val(1)], f.inp())])]

    # ---- bones and skin (Head frame)
    def bone(self, name: str, x: float, y: float, dx: Poly, dy: Poly) -> None:
        lx, ly = x - HEAD_FRAME[0], y - HEAD_FRAME[1]
        binds = [self.d("DataBindContext", sourcePathIds=self.path("yaw"), propertyKey=90,
                        converterId=self.rig.chain(self.rig.x_axis, r.poly_shift(dx, lx)).ref()),
                 self.d("DataBindContext", sourcePathIds=self.path("pitch"), propertyKey=91,
                        converterId=self.rig.chain(self.rig.y_axis, r.poly_shift(dy, ly)).ref())]
        el = self.d("RootBone", *binds, x=lx, y=ly, rotation=0.0, length=4.0, name=name)
        self.bones[name] = (x, y, el)

    def skin(self, shape: El, pts: list, wf: Callable[[float, float], Weights], closed: bool = True,
             tension: float = 1.0) -> None:
        """Replace `shape`'s path with the same Catmull-Rom path, skinned to the turn bones."""
        d = self.d

        def tendon(n: str) -> El:
            x, y, el = self.bones[n]
            return plain_tendon(d, el, (x, y), HEAD_FRAME)

        plain, _ = skinned_path(d, pts, HEAD_FRAME, sampled(wf), tendon, closed=closed, tension=tension)
        shape.children = [plain if c.tag in ("PointsPath", "Path") else c for c in shape.children]

    def finish(self) -> None:
        self.head.children.extend(el for _, _, el in self.bones.values())


# ------------------------------------------------------------------ rigging the avatar's head

def named(root: El, name: str) -> list[El]:
    out, stack = [], [root]
    while stack:
        e = stack.pop()
        if e.attrs.get("name") == name:
            out.append(e)
        stack.extend(e.children)
    return out


CONTOUR = {"T": (506.0, 330.0, 10.0), "S": (508.0, 366.0, 15.0), "C": (506.0, 396.0, 30.0), "K": (497.0, 428.0, 40.0),
           "J": (481.0, 458.0, 30.0), "W": (467.0, 476.0, 38.0), "Q": (450.0, 490.0, 45.0), "V": (426.0, 505.0, 55.0)}


# The jaw (M3 critic round): `auJawDrop` (+ 0.22 x the legacy `mouth`) drops the chin and the lower
# jaw contour, about 0.55 x the lower lip's 23 px at the chin, fading up the jaw line to nothing at
# the cheekbone. Art px per unit jaw, added to the contour bones' pitch formulas (screen y in the Head
# frame), so it composes with every yaw / pitch pose of the 3/4 outline and stays history-free.
JAW_CONTOUR = {"Chin": 13.0, "V": 11.5, "Q": 7.5, "W": 4.0, "J": 1.5}
JAW_PER_MOUTH = 0.22


def jaw_dy(bone: str, env: dict[str, float]) -> float:
    """The jaw's screen-y shift of a contour bone ("Chin", "FVL", "FQR", ...)."""
    px = JAW_CONTOUR.get(bone if bone == "Chin" else bone[1:-1], 0.0)
    return px * (env.get("auJawDrop", 0.0) + JAW_PER_MOUTH * env.get("mouth", 0.0))


def _bone_pitch(name: str) -> Poly:
    """The pitch poly a contour bone was built with (rig_head)."""
    if name == "Chin":
        return pit(511, 60)
    x, y, zp = CONTOUR[name[1:-1]]
    return pit(y, zp)


def rig_jaw(ht: "HeadTurn", d: Doc, path: Callable[[str], str]) -> list[El]:
    """Add the jaw drop to the contour bones' pitch binds. The new converters are minted from `d`
    (the face rig's unkeyed id range) after every head-turn id, so no head-turn id moves; the
    replaced pitch chains are removed when nothing else reads them. Returns the new converters."""
    f = r.Formulas(d, path)
    angle = ht.rig.angle(ht.rig.y_axis)
    made: dict[tuple[object, ...], El] = {}
    replaced: set[str] = set()
    for name, (_x, y, el) in ht.bones.items():
        if not (name == "Chin" or (name[0] == "F" and name[1:-1] in JAW_CONTOUR and name[-1] in "LR")):
            continue
        px = JAW_CONTOUR[name if name == "Chin" else name[1:-1]]
        poly = r.poly_add(r.poly_shift(_bone_pitch(name), y - HEAD_FRAME[1]),
                          [(px, (r.tok("auJawDrop"),)), (px * JAW_PER_MOUTH, (r.tok("mouth"),))])
        key = r.poly_key(poly)
        if key not in made:
            conv = d("DataConverterFormula", *f.poly(poly))
            made[key] = d("DataConverterGroup", d("DataConverterGroupItem", converterId=angle.ref()),
                          d("DataConverterGroupItem", converterId=conv.ref()))
            ht.rig.converters += [conv, made[key]]
        bind = next(c for c in el.children if c.tag == "DataBindContext" and c.attrs.get("propertyKey") == 91)
        replaced.add(str(bind.attrs["converterId"]))
        bind.attrs["converterId"] = made[key].ref()
    used: set[str] = set()
    stack = [ht.root, *ht.rig.converters]
    while stack:
        e = stack.pop()
        if "converterId" in e.attrs:
            used.add(str(e.attrs["converterId"]))
        stack.extend(e.children)
    dead = {c for c in ht.rig.converters if c.ref() in replaced and c.ref() not in used}
    dead |= {ht_conv for g in dead for item in g.children[1:] for ht_conv in ht.rig.converters
             if ht_conv.ref() == item.attrs.get("converterId")}
    ht.rig.converters[:] = [c for c in ht.rig.converters if c not in dead]
    return list(made.values())


def _face_ang(x: float, y: float) -> float:
    a = math.degrees(math.atan2(y - 400, x - 400))
    return a + 360 if a < -90 else a


def fringe_parallax(z_tip: float) -> Poly:
    """Extra screen-x travel of a fringe lock's tip under yaw (on top of the surface model)."""
    return [(FRINGE_PARALLAX * z_tip, (r.SIN,))]


# far-cheek shade (critic round 1): at 3/4 the cheek turning away darkens, a soft radial wash clipped
# by the face that rides the cheek surface and fades in with the turn (0 at rest and on the near
# side). Critic round 2: the cool violet read as a bruise; it is the skin-shadow ramp's terracotta
# now (over the lit skin at its peak it lands between SKIN_SH and SKIN_SH2)
FAR_SHADE = ("40B0583C", (497.0, 452.0), 40.0, 0.8)  # colour, art-space centre (right cheek), radius, peak


def far_cheek_opacity(yaw: float, side: float) -> float:
    """Cheek shade opacity (side -1 left, +1 right): peak x max(0, side x yaw) (the bind's formula)."""
    return FAR_SHADE[3] * max(0.0, min(1.0, side * yaw))


def far_cheek_shade(ht: HeadTurn, face: El, cheek_shade: El) -> list[El]:
    """Mint both cheek shades last (no head-turn id moves), in front of CheekShade."""
    colour, (x, y), rad_, _ = FAR_SHADE
    d = ht.d
    out = []
    f = ht.rig.f
    for t, cx, sgn in (("L", 2 * CX - x, -1.0), ("R", x, 1.0)):
        sh = d("Shape", d("ClippingShape", sourceId=face.ref(), name="Clip"),
               d("Ellipse", width=2 * rad_, height=2.8 * rad_, name="Path"),
               d("Fill", d("RadialGradient", d("GradientStop", colorValue=colour, position=0.0),
                           d("GradientStop", colorValue="00" + colour[2:], position=1.0),
                           startX=0.0, startY=0.0, endX=rad_ * 1.2, endY=0.0), name="Fill"),
               x=cx - HEAD_FRAME[0], y=y - HEAD_FRAME[1], name="FarCheekShade" + t)
        ht.head.children.insert(ht.head.children.index(cheek_shade), sh)
        ht.frames[id(sh)] = (cx, y)
        w = ht.wrap(sh, (cx, y), face_point(cx, y, face_z(cx, y)), pit(y, face_z(cx, y)))
        w.add(ht.raw("yaw", "opacity", [f.val(0), f.op("+"), f.val(FAR_SHADE[3]), f.op("*"),
                                        *f.fn("max", [f.val(0)], [f.val(sgn), f.op("*"),
                                                                  *f.fn("min", [f.val(1)], f.inp())])]))
        out.append(sh)
    return out


def rig_head(ht: HeadTurn, face_pts: list, cast_pts: list, cheek_pts: list, lock_specs: list,
             parts: dict[str, object], anims: list[El]) -> None:
    # ---- bones: contour (section silhouettes), chin, forehead / crown, face interior grid
    for n, (x, y, zp) in CONTOUR.items():
        for s, sgn in (("R", 1.0), ("L", -1.0)):
            m, p = contour_pose(x, y)
            xx = x if sgn > 0 else 2 * CX - x
            pose = (m, x, p) if sgn > 0 else (2 * CX - p, xx, 2 * CX - m)
            ht.bone("F" + n + s, xx, y, poses(*pose), pit(y, zp))
    zc = CHIN_Z * math.sin(K_YAW)
    ht.bone("Chin", 400.0, 511.0, poses(400 - zc, 400, 400 + zc), pit(511, 60))
    for n, x, y in (("FHL", 310.0, 262.0), ("FHC", 400.0, 222.0), ("FHR", 490.0, 262.0)):
        z = shell_z(x - CX, y)
        ht.bone(n, x, y, mat(x, z), pit(y, z))
    gx, gy = [330.0, 400.0, 470.0], [300.0, 360.0]
    for c, x in enumerate(gx):
        for rr, y in enumerate(gy):
            z = surface_z(x - CX, y)
            ht.bone(f"FG{c}{rr}", x, y, mat(x, z), pit(y, z))
    grid = Grid(gx, gy, lambda c, rr: f"FG{c}{rr}")
    order = ["FTL", "FSL", "FCL", "FKL", "FJL", "FWL", "FQL", "FVL", "Chin", "FVR", "FQR", "FWR", "FJR", "FKR", "FCR",
             "FSR", "FTR"]
    chain = Chain(sorted((_face_ang(ht.bones[n][0], ht.bones[n][1]), n) for n in order), _face_ang)
    top = Chain([(310.0, "FHL"), (400.0, "FHC"), (490.0, "FHR")], lambda x, y: x)

    def w_face(x: float, y: float) -> Weights:
        if y >= 330:
            return chain(x, y)
        t = min(1.0, (330 - y) / 40)
        return r.mix((1 - t, chain(x, y)), (t, top(x, y)))

    def w_inner(x: float, y: float) -> Weights:
        t = min(1.0, max(0.0, (abs(x - CX) - 70) / 30))
        return r.mix((t, w_face(x, y)), (1 - t, grid(x, y)))

    ht.skin(parts["Face"], face_pts, w_face)  # type: ignore[arg-type]
    ht.skin(parts["CheekShade"], cheek_pts, w_face)  # type: ignore[arg-type]
    ht.skin(parts["FaceCast"], cast_pts, w_inner)  # type: ignore[arg-type]
    # the two shading shapes hug the outline; clipped to the face they can never overhang the
    # turned jaw (at rest they already lie inside it, so the shipped look is unchanged)
    for nm in ("CheekShade", "FaceCast"):
        parts[nm].children.insert(0, ht.d("ClippingShape", sourceId=parts["Face"].ref()))  # type: ignore[union-attr]

    # ---- features (pivot sandwiches): eyes, brows, nose, mouth, mole, blush, cheek light, ears
    for t, cx in (("L", 355.0), ("R", 445.0)):
        sx = factor(*side((1.0, 1, 0.58), cx)[::2])
        ht.wrap(parts["Eye" + t], (cx, 388.0), mat(cx, 84), pit(388, 104), sx=sx)  # type: ignore[arg-type]
        ht.wrap(parts["Brow" + t], (cx, 346.0), mat(cx, 80), pit(346, 66), sx=factor(*side((1.0, 1, 0.6), cx)[::2]))  # type: ignore[arg-type]
    ht.wrap(parts["NoseTurn"], (400.0, 440.0), mat(400, NOSE_Z), pit(440, 118))  # type: ignore[arg-type]
    # mouth (every mood and open shape lives in this node): it rides the face surface (MOUTH_Z, a
    # little behind the nose tip and just ahead of the chin, which swings with the outline), its
    # pitch travel is 60 % of the chin's, and every mouth shape is clipped by the face
    ht.wrap(parts["Mouth"], (400.0, 478.0), mat(400, MOUTH_Z), pit(478, 28), sx=factor(0.88, 0.88))  # type: ignore[arg-type]
    # each face clip keeps its id: the shapes named in `MouthClipOrder` (the face rig's id order; a
    # deleted shape burns its id) clip here, shapes added since clip after every other head-turn id
    mouth_shapes = _shapes(parts["Mouth"])  # type: ignore[arg-type]
    clip_order: list[str] = list(parts.get("MouthClipOrder") or [str(e.attrs.get("name")) for e in mouth_shapes])  # type: ignore[call-overload]
    by_name = {str(e.attrs.get("name")): e for e in mouth_shapes}
    for nm in clip_order:
        if nm in by_name:
            by_name[nm].children.insert(0, ht.d("ClippingShape", sourceId=parts["Face"].ref()))  # type: ignore[union-attr]
        else:
            ht.d.next += 1
    late_clips = [e for e in mouth_shapes if str(e.attrs.get("name")) not in clip_order]
    # (round 3: the mole and the cheek blooms take `face_point` poses, rebound last: nose_tip_and_mole)
    ht.wrap(parts["Mole"], (456.0, 432.0), mat(456, face_z(456, 432)), pit(432, 80))  # type: ignore[arg-type]
    ht.wrap(parts["Blush"], (400.0, 440.0), mat(400, 90), pit(440, 90), sx=factor(0.82, 0.82))  # type: ignore[arg-type]
    for nm, x, y in (("CheekBloomL", 335.0, 437.0), ("CheekBloomR", 465.0, 437.0), ("ChinLight", 400.0, 499.0)):
        z = face_z(x, y)
        sx = factor(foreshorten(x, y, -K_YAW), foreshorten(x, y, K_YAW)) if nm != "ChinLight" else None
        ht.wrap(parts[nm], (x, y), mat(x, z), pit(y, z), sx=sx)  # type: ignore[arg-type]
    # critic round 2: the near ear (3/4) sat out past the side lock, detached; it now seats on the
    # skull contour with its front under the side lock (EAR_Z: less depth behind the yaw axis, so
    # it travels with the cheek; EAR_NEAR_WIDEN: it turns toward the viewer, but less)
    for t, x in (("L", 288.0), ("R", 512.0)):
        sx = factor(*side((EAR_NEAR_WIDEN, 1, 0.5), x)[::2])
        for nm in ("Ear" + t, "EarIn" + t):
            ht.wrap(parts[nm], (x, 398.0), mat(x, EAR_Z), pit(398, -48), sx=sx)  # type: ignore[arg-type]

    # ---- glasses: lenses foreshorten on the frame plane, the near temple unfolds, the far folds
    def lens_poses(cx: float) -> tuple[Poly, Poly]:
        ends = {a: lens_ends(cx, a) for a in (-K_YAW, K_YAW)}
        cen = {a: (e[0] + e[1]) / 2 for a, e in ends.items()}
        wid = {a: abs(e[1] - e[0]) / 86 for a, e in ends.items()}
        return poses(cen[-K_YAW], cx, cen[K_YAW]), factor(wid[-K_YAW], wid[K_YAW])

    # glare: the same slim glint on both lenses once turned (half width, 70 % of its 25 % alpha
    # at |yaw| = 1), so neither lens turns into a grey sheet when it foreshortens
    glare_op = factor(0.7, 0.7)
    groups: dict[str, El] = parts["glassesByName"]  # type: ignore[assignment]
    for grp in (groups["glasses"], groups["sunglasses"]):
        for t, cx, glare in (("L", 355.0, "Glare"), ("R", 445.0, "Glare2")):
            dx, sx = lens_poses(cx)
            for el in named(grp, "Lens" + t):
                ht.wrap(el, (cx, 387.0), dx, pit(387, 104), sx=sx)
            m, p = r.eval_poly(sx, -K_YAW), r.eval_poly(sx, K_YAW)
            for el in named(grp, glare):
                ht.wrap(el, (cx, 387.0), dx, pit(387, 104), sx=factor(m * 0.5, p * 0.5), opacity=glare_op)
        for el in named(grp, "Bridge"):
            ht.wrap(el, (400.0, 376.0), mat(400, 110), pit(376, 110))
        for t, hx in (("L", 311.0), ("R", 489.0)):
            for el in named(grp, "Hinge" + t):
                ht.wrap(el, (hx + (3 if t == "L" else -3), 372.0), mat(hx, LENS_Z[1]), pit(372, 86))
    temples(ht, groups, parts["GlassesSolo"], parts["HairFollow"], anims)  # type: ignore[arg-type]

    # ---- hair: locks turn about their roots (tips sit further forward than roots), the cap and
    # hat ride the crown, side locks slide over the near cheek and beside the far one, the back
    # hair shifts back and widens (more of the back of the head shows on the away side)
    for name, (root, tip, _w, _b) in lock_specs:
        rx, ry = root
        tx, ty = tip
        zr = shell_z(rx - CX, ry)
        zt = max(surface_z(tx - CX, ty), shell_z(tx - CX, ty) - 30) + 10
        d_root, d_tip = mat(rx, zr), mat(tx, zt)
        ln = ty - ry
        # head turn: the lock rotates about its root so the tip (further forward) travels more;
        # follow-through: hairLagYaw adds the tip's own travel for that much extra yaw (root pinned)
        rot = poly_scale(poly_add(d_tip, poly_scale(d_root, -1.0)), -1.0 / ln)
        g0, g1 = FRINGE_LAG_GAIN
        c = -zt * K_YAW / ln
        rot = poly_add(rot, [(c * g0, (r.tok("hairLagYaw"),)), (-c * g1, (r.tok("hairLagYaw"), tokabs("hairLagYaw")))])
        rot = poly_add(rot, poly_scale(fringe_parallax(zt), -1.0 / ln))
        sy = poly_add([(1.0, ())], poly_scale(poly_add(pit(ty, zt), poly_scale(pit(ry, zr), -1.0)), 1.0 / ln))
        sy = poly_add(sy, [(-(zt - ZP) * K_PITCH / ln, (r.tok("hairLagPitch"),))])
        ht.wrap(parts[name], (rx, ry), d_root, pit(ry, zr), rot=rot, sy=sy)  # type: ignore[arg-type]
    crown_dx, crown_sx = mat(400, 30), factor(0.94, 0.94)
    ht.wrap(parts["HairCap"], (400.0, 277.0), crown_dx, pit(277, 40), sx=crown_sx)  # type: ignore[arg-type]
    ht.wrap(parts["HatSolo"], (400.0, 250.0), crown_dx, pit(250, 30), sx=crown_sx)  # type: ignore[arg-type]
    for t, x in (("L", 288.0), ("R", 512.0)):
        # critic round 3: on the near side the lock moves out over the ear's front (it slid onto the
        # cheek and left the whole ear standing out); SIDE_LOCK_SWING then tucks its tip back in
        near_x = 512.0 + SIDE_LOCK_NEAR_OUT
        ox = (near_x, 512.0, 522.0) if x > CX else (2 * CX - 522.0, 288.0, 2 * CX - near_x)
        sc = side((1.0, 1.0, 0.38), x)
        ht.wrap(parts["SideLock" + t], (x, 398.0), poses(*ox), pit(398, 10), sx=factor(sc[0], sc[2]))  # type: ignore[arg-type]
        side_lock_lag(ht, parts["SideLock" + t], 1.0 if t == "R" else -1.0)  # type: ignore[arg-type]
    widen = math.sqrt(math.cos(K_YAW) ** 2 + (1.16 * math.sin(K_YAW)) ** 2)
    # the back hair moves with the crown for pitch (as the cap does), so looking down never lifts
    # it above the crown outline
    ht.wrap(parts["HairBackShape"], (400.0, 337.0), mat(400, HAIR_C[1]), pit(337, 40),  # type: ignore[arg-type]
            sx=factor(widen, widen))
    lag_bend(ht, parts["HairBackShape"], (400.0, 205.0), 478.0 - 205.0, BACK_LAG_PX, BACK_LAG_PITCH_PX)  # type: ignore[arg-type]
    for nm, x, y in (("Cowlick", 392.0, 230.0), ("Cowlick2", 418.0, 230.0)):
        z = shell_z(x - CX, y)
        ht.wrap(parts[nm], (x, y), mat(x, z), pit(y, z))  # type: ignore[arg-type]
        lag_bend(ht, parts[nm], (x, y), -48.0, TUFT_LAG_PX, TUFT_LAG_PX / 2)  # type: ignore[arg-type]
    # eye lead: extra iris / pupil shift on top of the pointer follow (the Look node keeps its keys);
    # the irises stay clipped by the eye whites
    for t in ("L", "R"):
        s = 1.0 if t == "R" else -1.0
        look: El = parts["Look" + t]  # type: ignore[assignment]
        frame = ht.frames[id(ht.parent_of(look))]
        outer = ht.wrap(look, (frame[0] + float(look.attrs.get("x", 0.0)), frame[1] + float(look.attrs.get("y", 0.0))),
                        name="EyeLead" + t)
        lx, ly = float(outer.attrs["x"]), float(outer.attrs["y"])
        outer.add(ht.raw("eyeLeadYaw", "x", eye_lead_x(ht, lx, s)), ht.raw("eyeLeadPitch", "y", eye_lead_y(ht, ly)))
        brow: El = parts["Brow" + t]  # type: ignore[assignment]
        bframe = ht.frames[id(ht.parent_of(brow))]
        bw = ht.wrap(brow, (bframe[0] + float(brow.attrs.get("x", 0.0)), bframe[1] + float(brow.attrs.get("y", 0.0))),
                     name="BrowLift" + t)
        bw.add(ht.raw("eyeLeadPitch", "y", ht.neg_part(float(bw.attrs["y"]), -BROW_LIFT_PX)))
    far_cheek_shade(ht, parts["Face"], parts["CheekShade"])  # type: ignore[arg-type]
    ht.finish()
    for el in late_clips:  # last, so no earlier head-turn id moves
        el.children.insert(0, ht.d("ClippingShape", sourceId=parts["Face"].ref()))  # type: ignore[union-attr]
    three_quarter(ht, parts)  # M3, after every M1/M2 element so none of their ids moves


BLUSH_Y = 438.0


def three_quarter(ht: HeadTurn, parts: dict[str, object]) -> None:
    """The 3/4 extras (M3): each blush rides its own cheek (surface depth, foreshortened on the far
    side), the lenses and glares are clipped by the face silhouette, and the far temple arm fades
    out as it swings behind the head."""
    face: El = parts["Face"]  # type: ignore[assignment]
    # ---- blush: the Blush node keeps its M1 wrap (pivot 400, z 90, x0.82); a wrap per side inside
    # it turns that into the side's own surface point and width (exact at yaw -1, 0, +1)
    blush: El = parts["Blush"]  # type: ignore[assignment]
    outer_dx, outer_sx = mat(400, 90), factor(0.82, 0.82)
    frame = ht.frames[id(blush)]
    for t, bx in (("L", 338.0), ("R", 462.0)):
        kids = [c for c in blush.children
                if c.attrs.get("name") == "Blush" + t or str(c.attrs.get("name", "")).startswith("BlushLine" + t)]
        group = ht.d("Node", *kids, x=0.0, y=0.0, name="Blush" + t + "Side")
        blush.children = [c for c in blush.children if c not in kids]
        blush.children.insert(0 if t == "L" else 1, group)
        ht.frames[id(group)] = frame
        z = face_z(bx, BLUSH_Y)
        dxi, sxi = {}, {}
        for a in (-K_YAW, K_YAW):
            so, do = r.eval_poly(outer_sx, a), r.eval_poly(outer_dx, a)
            target = bx + r.eval_poly(face_point(bx, BLUSH_Y, z), a)  # rides the far cheek's flattening
            dxi[a] = (target - CX - do) / so - bx + CX
            sxi[a] = foreshorten(bx, BLUSH_Y, a) / so
        ht.wrap(group, (bx, BLUSH_Y), fit3(dxi[-K_YAW], 0.0, dxi[K_YAW], K_YAW), sx=factor(sxi[-K_YAW], sxi[K_YAW]),
                name="Blush" + t + "Side")
    # ---- glasses: lenses, glares and hinges never draw past the face silhouette (looking up while
    # turned, the far lens's outer rim slips behind the temple instead of hanging over the hair)
    groups: dict[str, El] = parts["glassesByName"]  # type: ignore[assignment]
    for g in ("glasses", "sunglasses"):
        for nm in ("LensL", "LensR", "Glare", "Glare2", "HingeL", "HingeR"):
            for el in named(groups[g], nm):
                el.children.insert(0, ht.d("ClippingShape", sourceId=face.ref()))
    # ---- the far temple arm swings behind the head: opacity max(0, 1 - TEMPLE_FADE max(0, s yaw)),
    # one converter per side shared by the glasses and sunglasses arms
    f = ht.rig.f
    for t, s in (("L", -1.0), ("R", 1.0)):
        conv = ht.d("DataConverterFormula", *f.fn("max", [f.val(0)], [
            f.val(1), f.op("-"), f.val(TEMPLE_FADE), f.op("*"), *f.fn("max", [f.val(0)], [f.val(s), f.op("*"), *f.inp()])]))
        ht.rig.converters.append(conv)
        for el in named(ht.head, "Temple" + t):
            el.add(ht.d("DataBindContext", sourcePathIds=ht.path("yaw"), propertyKey=KEYS["opacity"],
                        converterId=conv.ref()))
    nose_tip_and_mole(ht)


TEMPLE_FADE = 3.0


def rebind_x(ht: HeadTurn, target: El, dx: Poly) -> None:
    """Point the yaw (x) bind of `target`'s pivot wrapper at a new shift poly (a chain minted now:
    the wrapper and its bind keep their ids)."""
    outer = ht.parent_of(ht.parent_of(target))
    bind = next(c for c in outer.children if c.tag == "DataBindContext" and c.attrs.get("propertyKey") == KEYS["x"])
    bind.attrs["converterId"] = ht.rig.chain(ht.rig.x_axis, r.poly_shift(dx, float(outer.attrs["x"]))).ref()


def prune_converters(ht: HeadTurn) -> None:
    """Drop the turn's converters nothing reads any more (rebound binds leave their old chains)."""
    while True:
        used: set[str] = set()
        stack = [ht.root, *ht.rig.converters]
        while stack:
            e = stack.pop()
            if "converterId" in e.attrs:
                used.add(str(e.attrs["converterId"]))
            stack.extend(e.children)
        dead = [c for c in ht.rig.converters if c.ref() not in used]
        if not dead:
            return
        ht.rig.converters[:] = [c for c in ht.rig.converters if c not in dead]
        ht.rig._polys = {k: v for k, v in ht.rig._polys.items() if v not in dead}
SIDE_LOCK_NEAR_OUT = 14.0  # art px the near side lock moves out at |yaw| 1 (over the ear's front)
SIDE_LOCK_SWING = 0.2  # rad the near side lock swings its tip back toward the cheek about its root
SIDE_LOCK_ROOT_Y = 330.0
MOLE_FADE = (0.6, 0.9)  # yaw: the mole on the right cheek turns behind the nose (full .. gone)


def nose_tip_and_mole(ht: HeadTurn) -> None:
    """Critic round 3 (minted last, so no earlier head-turn id moves): the nose tip stands further
    out than the bridge (NOSE_TIP_RELIEF vs NOSE_RELIEF), so at 3/4 it breaks over the flattened far
    cheek while the bridge stays under the glasses' bridge: the nose line slides the extra depth, the
    shade swings about its top to follow it. The mole on the right cheek fades out as that cheek
    turns behind the nose (MOLE_FADE)."""
    f = ht.rig.f
    # the nose art is drawn turned a touch to the viewer's left (its nostril hooks left), so its right
    # end needs NOSE_TIP_RIGHT more travel to break over the right cheek by as much as the hook does
    # over the left one
    dz = (NOSE_TIP_Z - NOSE_Z) * math.sin(K_YAW)
    nose, shade = named(ht.head, "Nose")[0], named(ht.head, "NoseShade")[0]
    tip = fit3(-dz, 0.0, dz + NOSE_TIP_RIGHT, K_YAW)
    ht.wrap(nose, (400.0, 450.0), dx=tip, name="NoseTip")
    # (y down: a clockwise turn by t moves the shade's bottom by -LEN sin t); the shade follows the
    # tip only NOSE_SHADE_FOLLOW of the way, so it never crosses the far contour's shading band
    k = NOSE_SHADE_FOLLOW / NOSE_SHADE_LEN
    swing = fit3(math.asin(k * dz), 0.0, -math.asin(k * (dz + NOSE_TIP_RIGHT)), K_YAW)
    ht.wrap(shade, (404.0, 408.0), rot=swing, name="NoseTipShade")
    # the near side lock: its tip swings back toward the cheek (the ear's lower half shows below
    # the hair, its top half stays under it); nothing on the far side or at rest
    for t, sgn in (("R", 1.0), ("L", -1.0)):
        lock = named(ht.head, "SideLock" + t)[0]
        near = SIDE_LOCK_SWING * sgn  # R is near at yaw -1, L at +1
        rot = fit3(near, 0.0, 0.0, K_YAW) if sgn > 0 else fit3(0.0, 0.0, near, K_YAW)
        ht.wrap(lock, (CX + sgn * 100.0, SIDE_LOCK_ROOT_Y), rot=rot, name="SideLockTuck" + t)
    lo, hi = MOLE_FADE
    g = 1.0 / (hi - lo)
    for nm, x, y in (("Mole", 456.0, 432.0), ("CheekBloomL", 335.0, 437.0), ("CheekBloomR", 465.0, 437.0)):
        rebind_x(ht, named(ht.head, nm)[0], face_point(x, y, face_z(x, y)))
    prune_converters(ht)
    mole = named(ht.head, "Mole")[0]
    mole.add(ht.raw("yaw", "opacity", f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [
        f.val(1 + g * lo), f.op("-"), f.val(g), f.op("*"), *f.inp()]))))


def _clamp(ht: HeadTurn, toks: list[El]) -> list[El]:
    f = ht.rig.f
    return f.fn("min", [f.val(1)], f.fn("max", [f.val(-1)], toks))


def eye_lead_x(ht: HeadTurn, c0: float, s: float) -> list[El]:
    """c0 + EYE_LEAD_PX * x * (1 - FAR_EYE_CUT * min(1, max(0, 2 (s*yaw - 0.4)))): the far eye's
    lead is cut as the eye foreshortens, so the iris never clips to a crescent."""
    f = ht.rig.f
    far = f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(2 * s), f.op("*"), f.bound("yaw"), f.op("-"),
                                                          f.val(0.8)]))
    return [f.val(c0), f.op("+"), f.val(EYE_LEAD_PX), f.op("*"), *_clamp(ht, f.inp()), f.op("-"),
            f.val(EYE_LEAD_PX * FAR_EYE_CUT), f.op("*"), *_clamp(ht, f.inp()), f.op("*"), *far]


def eye_lead_y(ht: HeadTurn, c0: float) -> list[El]:
    """c0 - UP * x for looking up, + DOWN * |x| for looking down (clamped to -1..1)."""
    f = ht.rig.f
    neg = f.fn("max", [f.val(0)], [f.val(-1), f.op("*"), *_clamp(ht, f.inp())])
    return [f.val(c0), f.op("-"), f.val(EYE_LEAD_PITCH_PX), f.op("*"), *_clamp(ht, f.inp()), f.op("+"),
            f.val(EYE_LEAD_DOWN_PX - EYE_LEAD_PITCH_PX), f.op("*"), *neg]


def side_lock_lag(ht: HeadTurn, target: El, s: float) -> None:
    """Side-lock follow-through about its root. A swing toward the face (the tip crossing the
    cheek) is removed on the far side (s * yaw > 0) as the head turns, so the far lock never
    sweeps over the far cheek and lens: rot = -c lag + c s min(0, s lag) min(1, 1.5 max(0, s yaw))."""
    f = ht.rig.f
    root = (500.0 if s > 0 else 300.0, 330.0)
    length = 466.0 - 330.0
    c = SIDE_LAG_PX / length
    inward = f.fn("min", [f.val(0)], [f.val(s), f.op("*"), *_clamp(ht, f.inp())])
    far = f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(1.5 * s), f.op("*"), f.bound("yaw")]))
    toks = [f.val(-c), f.op("*"), *_clamp(ht, f.inp()), f.op("+"), f.val(c * s), f.op("*"), *inward, f.op("*"), *far]
    outer = ht.wrap(target, root, sy=[(1.0, ()), (-SIDE_LAG_PITCH_PX / length, (r.tok("hairLagPitch"),))],
                    name=str(target.attrs.get("name", "Hair")) + "Lag")
    outer.add(ht.raw("hairLagYaw", "rotation", toks))


def lag_bend(ht: HeadTurn, target: El, root: tuple[float, float], length: float, px: float, px_pitch: float) -> None:
    """Follow-through for a hanging hair mass: an inner wrapper pinned at `root` rotates by the
    tip's lag travel (hairLagYaw) and stretches by its pitch travel (hairLagPitch). The root never
    moves, so there is no gap; the tip takes the full offset. Identity at zero lag."""
    rot = [(0.0, ()), (-px / length, (r.tok("hairLagYaw"),))]
    sy = [(1.0, ()), (-px_pitch / abs(length), (r.tok("hairLagPitch"),))]
    ht.wrap(target, root, rot=rot, sy=sy, name=str(target.attrs.get("name", "Hair")) + "Lag")


def _shapes(e: El) -> list[El]:
    out = [e] if e.tag == "Shape" else []
    for c in e.children:
        out += _shapes(c)
    return out


def temples(ht: HeadTurn, groups: dict[str, El], glasses_solo: El, hair_follow: El, anims: list[El]) -> None:
    """Temple arms in their own Solo, drawn under the front hair (over the face): skinned to a
    hinge bone and an end bone, so the arm keeps its stroke width (blunt butt cap). Near side:
    the end bone runs back to the ear root; far side: it folds onto the hinge. The Solo follows
    every key of the glasses Solo (glasses, sunglasses, costumes hiding them)."""
    d = ht.d
    for t, hx, ex in (("L", 311.0, 296.0), ("R", 489.0, 504.0)):
        sgn = 1.0 if t == "R" else -1.0
        hinge = mat(hx, LENS_Z[1])  # the hinge sits on the lens's outer frame end
        hinge_far = hx + r.eval_poly(hinge, sgn * K_YAW)
        near_root = CX + sgn * 66.0  # the near ear's root (front edge of the widened ear)
        m, p = (near_root, hinge_far) if sgn > 0 else (hinge_far, near_root)
        ht.bone("GH" + t, hx, 370.0, hinge, pit(370, 86))
        ht.bone("GE" + t, ex, 368.0, poses(m, ex, p), pit(368, -20))
    tgroups: dict[str, El] = {}
    for g, grp in groups.items():
        tg = d("Node", x=0.0, y=0.0, name="Temples_" + g)
        for t, pts in (("L", [(311, 370), (296, 368)]), ("R", [(489, 370), (504, 368)])):
            for el in named(grp, "Temple" + t):
                ht.parent_of(el).children.remove(el)
                ht.skin(el, pts, Chain(sorted([(float(pts[0][0]), "GH" + t), (float(pts[1][0]), "GE" + t)]),
                                       lambda x, y: x), closed=False)
                for st in (c for c in el.children if c.tag == "Stroke"):
                    st.attrs["cap"] = "butt"
                tg.add(el)
        tgroups[g] = tg
    solo = d("Solo", *tgroups.values(), activeComponentId=tgroups["glasses"].ref(), x=0.0, y=0.0, name="TempleSolo")
    ht.head.children.insert(ht.head.children.index(hair_follow) + 1, solo)
    remap = {groups[g].ref(): tgroups[g].ref() for g in groups}
    target = glasses_solo.ref()
    for anim in anims:
        for ko in [c for c in anim.children if c.tag == "KeyedObject" and c.attrs.get("objectId") == target]:
            kps = []
            for kp in ko.children:
                kfs = [d(kf.tag, **{k: (remap.get(str(v), v) if k == "value" else v) for k, v in kf.attrs.items()})
                       for kf in kp.children]
                kps.append(d("KeyedProperty", *kfs, property=kp.attrs["property"]))
            anim.add(d("KeyedObject", *kps, objectId=solo.ref()))
