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
  elliptic sections (smooth jaw at |yaw| = 1); bind transforms are expressed in the Head frame.

New elements use their own id range (ID_START), so no existing component id moves.
"""

from __future__ import annotations

import math
from typing import Callable, Sequence

import rig_dsl as r
from rig_dsl import Axis, Chain, Grid, Poly, Weights, fit3, material_dx, pitch_dy, poly_add, poly_scale, quantize, pack
from rml import Doc, El, smooth_path

ID_START = 900000
PI = math.pi
CX, CY = 400.0, 380.0  # yaw axis x, pitch pivot y (art space)
ZP = -20.0  # pitch axis depth
K_YAW = round(math.radians(30), 4)
K_PITCH = round(math.radians(15), 4)
HEAD_FRAME = (400.0, 560.0)  # the Head rig's art-space origin (children are authored against it)
KEYS = {"x": 13, "y": 14, "rotation": 15, "scaleX": 16, "scaleY": 17}


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


Z0 = [(330.0, 8.0), (366.0, 10.0), (396.0, 14.0), (428.0, 22.0), (458.0, 32.0), (476.0, 40.0), (490.0, 46.0),
      (505.0, 54.0), (511.0, 58.0)]


def _lerp(table: Sequence[tuple[float, float]], y: float) -> float:
    if y <= table[0][0]:
        return table[0][1]
    for (y0, v0), (y1, v1) in zip(table, table[1:]):
        if y <= y1:
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
    return table[-1][1]


def contour_pose(x: float, y: float) -> tuple[float, float]:
    """Right-side face contour x at yaw -1 / +1: the silhouette of the elliptic section."""
    w = x - CX
    dd = 0.82 * w + 8 + 8 * math.exp(-(((y - 396) / 22) ** 2))
    e = math.sqrt((w * math.cos(K_YAW)) ** 2 + (dd * math.sin(K_YAW)) ** 2)
    z0 = _lerp(Z0, y)
    return CX + e - z0 * math.sin(K_YAW), CX + e + z0 * math.sin(K_YAW)


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
        self.props = {pn: d("ViewModelPropertyNumber", name=pn) for pn in ("yaw", "pitch")}
        inst_vals = [d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref())
                     for p in self.props.values()]
        at = vm.children.index(next(c for c in vm.children if c.tag == "ViewModelInstance"))
        vm.children[at:at] = list(self.props.values())
        inst.children.extend(inst_vals)
        self.vm = vm
        self.rig = r.Rig(d, self.path, origin=(0.0, 0.0), x_axis=Axis("yaw", K_YAW), y_axis=Axis("pitch", K_PITCH))
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
        ax = self.rig.x_axis if axis == "yaw" else self.rig.y_axis
        return self.d("DataBindContext", sourcePathIds=self.path(axis), propertyKey=KEYS[key],
                      converterId=self.rig.chain(ax, poly).ref())

    def wrap(self, target: El, pivot: tuple[float, float], dx: Poly | None = None, dy: Poly | None = None,
             sx: Poly | None = None, rot: Poly | None = None, sy: Poly | None = None, name: str = "") -> El:
        """W1(at pivot, bound) -> W2(at -pivot) -> target. Identity at rest."""
        parent = self.parent_of(target)
        frame = self.frames[id(parent)]
        lx, ly = pivot[0] - frame[0], pivot[1] - frame[1]
        binds = []
        if dx is not None:
            binds.append(self.bind("yaw", "x", r.poly_shift(dx, lx)))
        if dy is not None:
            binds.append(self.bind("pitch", "y", r.poly_shift(dy, ly)))
        if sx is not None:
            binds.append(self.bind("yaw", "scaleX", sx))
        if rot is not None:
            binds.append(self.bind("yaw", "rotation", rot))
        if sy is not None:
            binds.append(self.bind("pitch", "scaleY", sy))
        nm = name or str(target.attrs.get("name", "Part"))
        inner = self.d("Node", target, x=-lx, y=-ly, name=nm + "Pivot")
        outer = self.d("Node", *binds, inner, x=lx, y=ly, name=nm + "Turn")
        parent.children[parent.children.index(target)] = outer
        return outer

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
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        plain = smooth_path(d, [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts], closed=closed, tension=tension)
        index: dict[str, int] = {}
        verts = []
        for v, p in zip(plain.children, pts):
            ax, ay = float(p[0]), float(p[1])
            if v.tag == "StraightVertex":
                q = [quantize(wf(ax, ay))]
            else:
                rot_o, dist_o = float(v.attrs["outRotation"]), float(v.attrs["outDistance"])
                rot_i, dist_i = float(v.attrs["inRotation"]), float(v.attrs["inDistance"])
                q = [quantize(wf(ax, ay)), quantize(wf(ax + math.cos(rot_i) * dist_i, ay + math.sin(rot_i) * dist_i)),
                     quantize(wf(ax + math.cos(rot_o) * dist_o, ay + math.sin(rot_o) * dist_o))]
            for qs in q:
                for b, _ in qs:
                    index.setdefault(b, len(index))
            if v.tag == "StraightVertex":
                val, ix = pack(q[0], index)
                v.add(d("Weight", values=val, indices=ix))
            else:
                (a, b_), (c, e), (f, g) = (pack(x, index) for x in q)
                v.add(d("CubicWeight", values=a, indices=b_, inValues=c, inIndices=e, outValues=f, outIndices=g))
            verts.append(v)
        tendons = [d("Tendon", boneId=self.bones[n][2].ref(), tx=self.bones[n][0] - HEAD_FRAME[0],
                     ty=self.bones[n][1] - HEAD_FRAME[1]) for n in index]
        plain.add(d("Skin", *tendons, tx=ox - HEAD_FRAME[0], ty=oy - HEAD_FRAME[1]))
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


def _face_ang(x: float, y: float) -> float:
    a = math.degrees(math.atan2(y - 400, x - 400))
    return a + 360 if a < -90 else a


def rig_head(ht: HeadTurn, face_pts: list, cast_pts: list, cheek_pts: list, lock_specs: list,
             parts: dict[str, El | list[El]]) -> None:
    # ---- bones: contour (section silhouettes), chin, forehead / crown, face interior grid
    for n, (x, y, zp) in CONTOUR.items():
        for s, sgn in (("R", 1.0), ("L", -1.0)):
            m, p = contour_pose(x, y)
            xx = x if sgn > 0 else 2 * CX - x
            pose = (m, x, p) if sgn > 0 else (2 * CX - p, xx, 2 * CX - m)
            ht.bone("F" + n + s, xx, y, poses(*pose), pit(y, zp))
    zc = _lerp(Z0, 511.0) * math.sin(K_YAW)
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
    ht.wrap(parts["NoseTurn"], (400.0, 440.0), mat(400, 122), pit(440, 118))  # type: ignore[arg-type]
    ht.wrap(parts["Mouth"], (400.0, 478.0), mat(400, 98), pit(478, 100), sx=factor(0.88, 0.88))  # type: ignore[arg-type]
    ht.wrap(parts["Mole"], (456.0, 432.0), mat(456, 80), pit(432, 80))  # type: ignore[arg-type]
    ht.wrap(parts["Blush"], (400.0, 440.0), mat(400, 90), pit(440, 90), sx=factor(0.82, 0.82))  # type: ignore[arg-type]
    for nm, x, y, z in (("CheekBloomL", 335.0, 437.0, 72.0), ("CheekBloomR", 465.0, 437.0, 72.0),
                        ("ChinLight", 400.0, 499.0, 78.0)):
        sx = factor(*side((1.05, 1, 0.55), x)[::2]) if nm != "ChinLight" else None
        ht.wrap(parts[nm], (x, y), mat(x, z), pit(y, z), sx=sx)  # type: ignore[arg-type]
    for t, x in (("L", 288.0), ("R", 512.0)):
        sx = factor(*side((1.35, 1, 0.5), x)[::2])
        for nm in ("Ear" + t, "EarIn" + t):
            ht.wrap(parts[nm], (x, 398.0), mat(x, -25), pit(398, -48), sx=sx)  # type: ignore[arg-type]

    # ---- glasses: lenses foreshorten on the frame plane, the near temple unfolds, the far folds
    def lens_poses(cx: float) -> tuple[Poly, Poly]:
        sgn = 1.0 if cx > CX else -1.0
        xin, xout = CX + sgn * 2, CX + sgn * 88

        def proj(x: float, z: float, a: float) -> float:
            return CX + (x - CX) * math.cos(a) + z * math.sin(a)
        ends = {a: (proj(xin, 110, a), proj(xout, 86, a)) for a in (-K_YAW, K_YAW)}
        cen = {a: (e[0] + e[1]) / 2 for a, e in ends.items()}
        wid = {a: abs(e[1] - e[0]) / 86 for a, e in ends.items()}
        return poses(cen[-K_YAW], cx, cen[K_YAW]), factor(wid[-K_YAW], wid[K_YAW])

    for grp in parts["glassesGroups"]:  # type: ignore[union-attr]
        for t, cx, glare in (("L", 355.0, "Glare"), ("R", 445.0, "Glare2")):
            dx, sx = lens_poses(cx)
            for nm in ("Lens" + t, glare):
                for el in named(grp, nm):
                    ht.wrap(el, (cx, 387.0), dx, pit(387, 104), sx=sx)
        for el in named(grp, "Bridge"):
            ht.wrap(el, (400.0, 376.0), mat(400, 110), pit(376, 110))
        for t, hx in (("L", 311.0), ("R", 489.0)):
            fold = side((4.4, 1, 0.0), hx)  # near: the arm runs back to the ear; far: folded
            for el in named(grp, "Temple" + t):
                ht.wrap(el, (hx, 370.0), mat(hx, 86), pit(370, 86), sx=factor(fold[0], fold[2]))
            for el in named(grp, "Hinge" + t):
                ht.wrap(el, (hx + (3 if t == "L" else -3), 372.0), mat(hx, 86), pit(372, 86))

    # ---- hair: locks turn about their roots (tips sit further forward than roots), the cap and
    # hat ride the crown, side locks slide over the near cheek and beside the far one, the back
    # hair shifts back and widens (more of the back of the head shows on the away side)
    for name, (root, tip, _w, _b) in lock_specs:
        rx, ry = root
        tx, ty = tip
        zr = shell_z(rx - CX, ry)
        zt = max(surface_z(tx - CX, ty), shell_z(tx - CX, ty) - 30) + 10
        d_root, d_tip = mat(rx, zr), mat(tx, zt)
        rot = poly_scale(poly_add(d_tip, poly_scale(d_root, -1.0)), -1.0 / (ty - ry))
        sy = poly_add([(1.0, ())], poly_scale(poly_add(pit(ty, zt), poly_scale(pit(ry, zr), -1.0)), 1.0 / (ty - ry)))
        ht.wrap(parts[name], (rx, ry), d_root, pit(ry, zr), rot=rot, sy=sy)  # type: ignore[arg-type]
    crown_dx, crown_sx = mat(400, 30), factor(0.94, 0.94)
    ht.wrap(parts["HairCap"], (400.0, 277.0), crown_dx, pit(277, 40), sx=crown_sx)  # type: ignore[arg-type]
    ht.wrap(parts["HatSolo"], (400.0, 250.0), crown_dx, pit(250, 30), sx=crown_sx)  # type: ignore[arg-type]
    for t, x in (("L", 288.0), ("R", 512.0)):
        ox = side((500.0, 512.0, 522.0), x) if x > CX else (2 * CX - 522.0, 288.0, 2 * CX - 500.0)
        sc = side((1.0, 1.0, 0.38), x)
        ht.wrap(parts["SideLock" + t], (x, 398.0), poses(*ox), pit(398, 10), sx=factor(sc[0], sc[2]))  # type: ignore[arg-type]
    widen = math.sqrt(math.cos(K_YAW) ** 2 + (1.16 * math.sin(K_YAW)) ** 2)
    ht.wrap(parts["HairBackShape"], (400.0, 337.0), mat(400, HAIR_C[1]), pit(337, HAIR_C[1]),  # type: ignore[arg-type]
            sx=factor(widen, widen))
    for nm, x, y in (("Cowlick", 392.0, 230.0), ("Cowlick2", 418.0, 230.0)):
        z = shell_z(x - CX, y)
        ht.wrap(parts[nm], (x, y), mat(x, z), pit(y, z))  # type: ignore[arg-type]
    ht.finish()
