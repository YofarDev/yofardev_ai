"""FACS-lite face rig for the shipped avatar (moonshot M2, contract v5).

Called by gen_avatar.py after the head art, the view model and the animations exist, and before
head_turn.py wraps the head for yaw / pitch. Every AvatarVM number below maps to the art through
history-free formula data binds (value = c0 + sum c_i * [prop_i]), the same mechanism as the head
turn, so a pose depends only on the current numbers:

- `au*` (FACS-lite action units, 0..1): brows are skinned to inner / mid / outer bones; the eye
  opening, the mood lids (droop, squint crescent), the cheek bloom and the nose bind their own
  transforms; the mouth is ONE continuous skinned shape on corner, upper and lower lip bones.
  Its stroke is the closed mouth line, its fill the open mouth; teeth and tongue ride the lip
  bones, clipped by it.
- `lipTuck` / `tongueUp` (speech): the upper lip lifts off the teeth for f / v; the tongue tip
  rises to the teeth.
- `mouth` (legacy 0..4): adds 0.22 per step to the jaw.
- `breath` lifts the body from the feet; `roll` tilts the head about the neck.

The `mood` enum keeps only accents (blush, sweat, anger mark, tilt, gaze offset, pupils, the
thinking mouth skew); those stay keyed in gen_avatar.py. New elements take their own id range.
"""

from __future__ import annotations

import math
from typing import Callable, Mapping, Sequence

from rig_dsl import Formulas, pack, quantize
from rml import Doc, El, fill, smooth_path, stroke

ID_START = 950000
KEYS = {"x": 13, "y": 14, "rotation": 15, "scaleX": 16, "scaleY": 17, "opacity": 18, "thickness": 47, "boneX": 90,
        "boneY": 91}
AUS = ("auBrowInnerUp", "auBrowOuterUp", "auBrowLower", "auLidTighten", "auUpperLidRaise", "auCheekRaise",
       "auNoseWrinkle", "auLipCornerPull", "auLipCornerDepress", "auLipStretch", "auLipPucker", "auLipPress",
       "auJawDrop", "auDimpler")
NUMBERS = (*AUS, "lipTuck", "tongueUp", "roll", "breath")
JAW_PER_MOUTH = 0.22  # legacy `mouth` 0..4 -> jaw

Terms = Mapping[str, float]  # prop -> coefficient (art px, radians or scale per unit)

# short names used in the tables below
_SHORT = {"IU": "auBrowInnerUp", "OU": "auBrowOuterUp", "BL": "auBrowLower", "LT": "auLidTighten",
          "UL": "auUpperLidRaise", "CR": "auCheekRaise", "NW": "auNoseWrinkle", "P": "auLipCornerPull",
          "D": "auLipCornerDepress", "S": "auLipStretch", "K": "auLipPucker", "R": "auLipPress", "J": "auJawDrop",
          "DM": "auDimpler", "T": "lipTuck", "TU": "tongueUp"}


def terms(**kw: float) -> dict[str, float]:
    """Short names -> contract names; a jaw term also reads the legacy `mouth` number."""
    out = {_SHORT[k]: v for k, v in kw.items() if v}
    if "auJawDrop" in out:
        out["mouth"] = out["auJawDrop"] * JAW_PER_MOUTH
    return out


def evaluate(c0: float, t: Terms, env: Mapping[str, float]) -> float:
    return c0 + sum(c * env.get(p, 0.0) for p, c in t.items())


# ------------------------------------------------------------------ geometry tables (head art space)

# Brows: bone rest positions per side (s = -1 left, +1 right; the inner end is toward x = 400).
# dx is given toward the face centre for + (mirrored per side); dy is screen y (+ = down).
BROW_BONES = {  # name: (dx from eye centre * s, y, dx terms (toward centre), dy terms)
    "Inner": (-26.0, 341.0, terms(BL=3.0, IU=0.5), terms(IU=-12.0, OU=-3.0, BL=7.0)),
    "Mid": (4.0, 337.0, terms(BL=1.5), terms(IU=-6.0, OU=-7.0, BL=3.5)),
    "Outer": (32.0, 342.0, terms(OU=-1.5), terms(IU=-1.5, OU=-12.0, BL=-1.0)),
}

MOUTH_FRAME = (400.0, 478.0)
# Mouth bones: rest (x, y) for the RIGHT side / centre; dx terms are toward the viewer's right for the
# right side (mirrored for the left); dy terms are screen y.
MOUTH_BONES = {
    "CornerR": ((417.0, 477.0), terms(P=5.0, S=7.0, J=3.0, K=-8.0, R=-1.5, DM=1.0, D=1.0),
                terms(P=-7.0, D=9.5, CR=-1.5, J=3.0, S=1.0, DM=-1.0)),
    # closed-mouth terms (corners, smile, frown, dimpler, press) move the upper and lower lips
    # together so a closed mouth stays one line; only jaw, pucker, nose wrinkle and lip tuck open it
    "UpperR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0),
               terms(P=0.3, D=1.0, J=-2.0, NW=-3.0, T=-3.0, K=-3.0)),
    "UpperC": ((400.0, 480.0), terms(), terms(P=2.0, D=-4.0, J=-2.5, NW=-4.0, T=-3.5, K=-4.0)),
    "LowerR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0),
               terms(P=0.3, D=1.0, J=19.0, K=5.0, T=0.5)),
    "LowerC": ((400.0, 480.0), terms(), terms(P=2.0, D=-4.0, J=23.0, K=7.0, T=1.0)),
}


def mirror_terms(t: Terms) -> dict[str, float]:
    return {p: -c for p, c in t.items()}


def mouth_bones() -> dict[str, tuple[tuple[float, float], dict[str, float], dict[str, float]]]:
    """All mouth bones (left side mirrored from the right)."""
    out: dict[str, tuple[tuple[float, float], dict[str, float], dict[str, float]]] = {}
    for name, ((x, y), dx, dy) in MOUTH_BONES.items():
        out[name] = ((x, y), dict(dx), dict(dy))
        if name.endswith("R"):
            out[name[:-1] + "L"] = ((2 * MOUTH_FRAME[0] - x, y), mirror_terms(dx), dict(dy))
    # the tongue tip rides the lower lip and rises to the upper teeth
    lc = out["LowerC"]
    out["TongueTip"] = ((400.0, 472.5), {}, {**lc[2], "tongueUp": -12.0})
    return out


def mouth_pose(env: Mapping[str, float]) -> dict[str, tuple[float, float]]:
    """Predicted art-space position of every mouth bone (tests, review overlays)."""
    return {n: (x + evaluate(0.0, dx, env), y + evaluate(0.0, dy, env)) for n, ((x, y), dx, dy) in
            mouth_bones().items()}


# ------------------------------------------------------------------ the rig

class FaceRig:
    def __init__(self, path: Callable[[str], str]) -> None:
        self.d = Doc(client=0, start=ID_START)
        self.path = path
        self.f = Formulas(self.d, path)
        self.converters: list[El] = []
        self._conv: dict[tuple[object, ...], El] = {}

    # ---- binds
    def converter(self, c0: float, t: Terms, lo: float | None = None, hi: float | None = None) -> tuple[str, El]:
        """Formula c0 + sum c_i [p_i], optionally clamped; returns (source prop, converter)."""
        items = sorted((p, round(c, 3)) for p, c in t.items() if round(c, 3))
        key = (round(c0, 3), tuple(items), lo, hi)
        src = items[0][0] if items else "auJawDrop"
        if key not in self._conv:
            f = self.f
            expr: list[El] = [f.val(c0)]
            for i, (p, c) in enumerate(items):
                expr += [f.op("+"), f.val(c), f.op("*"), *(f.inp() if i == 0 else [f.bound(p)])]
            if hi is not None:
                expr = f.fn("min", [f.val(hi)], expr)
            if lo is not None:
                expr = f.fn("max", [f.val(lo)], expr)
            conv = self.d("DataConverterFormula", *expr)
            self.converters.append(conv)
            self._conv[key] = conv
        return src, self._conv[key]

    def bind(self, key: str, c0: float, t: Terms, lo: float | None = None, hi: float | None = None) -> El:
        src, conv = self.converter(c0, t, lo, hi)
        return self.d("DataBindContext", sourcePathIds=self.path(src), propertyKey=KEYS[key],
                      converterId=conv.ref())

    def bind_on(self, el: El, key: str, c0: float, t: Terms, lo: float | None = None,
                hi: float | None = None) -> None:
        el.children.insert(0, self.bind(key, c0, t, lo, hi))

    def wrap(self, parent: El, target: El, pivot: tuple[float, float], name: str,
             binds: Sequence[tuple[str, float, Terms]]) -> El:
        """parent -> W1(at pivot, bound) -> W2(at -pivot) -> target: identity at rest. `pivot` is
        in the parent's local frame."""
        lx, ly = pivot
        inner = self.d("Node", target, x=-lx, y=-ly, name=name + "Pivot")
        outer = self.d("Node", *[self.bind(k, (lx if k == "x" else ly if k == "y" else c0), t)
                                 for k, c0, t in binds], inner, x=lx, y=ly, name=name)
        parent.children[parent.children.index(target)] = outer
        return outer

    # ---- bones and skin (in the frame of the node the bones live in)
    def bone(self, name: str, local: tuple[float, float], dx: Terms, dy: Terms) -> El:
        binds = [self.bind("boneX", local[0], dx), self.bind("boneY", local[1], dy)]
        return self.d("RootBone", *binds, x=local[0], y=local[1], rotation=0.0, length=2.0, name=name)

    def skinned(self, name: str, pts: Sequence[tuple], weights: Sequence[Mapping[str, float]],
                bones: Mapping[str, tuple[tuple[float, float], El]], frame: tuple[float, float],
                *paints: El, closed: bool = True, clip: El | None = None, tension: float = 1.0,
                handles: Sequence[tuple[Mapping[str, float], Mapping[str, float]] | None] | None = None,
                **kw: object) -> El:
        """A shape whose vertices follow `bones` (art-space rest positions); `weights[i]` belongs
        to pts[i]; a smooth vertex's handles lean a third toward its neighbours' weights, unless
        `handles[i]` gives their (in, out) weights explicitly."""
        d = self.d
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        path = smooth_path(d, [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts], closed=closed,
                           tension=tension)
        index: dict[str, int] = {}
        n = len(pts)

        def mix(a: Mapping[str, float], b: Mapping[str, float], t: float) -> dict[str, float]:
            out = {k: (1 - t) * v for k, v in a.items()}
            for k, v in b.items():
                out[k] = out.get(k, 0.0) + t * v
            return out

        def q(w: Mapping[str, float]) -> list[tuple[str, int]]:
            qs = quantize(dict(w))
            for k, _ in qs:
                index.setdefault(k, len(index))
            return qs

        for i, v in enumerate(path.children):
            w = weights[i]
            if v.tag == "StraightVertex":
                val, ix = pack(q(w), index)
                v.add(d("Weight", values=val, indices=ix))
            else:
                prv = weights[(i - 1) % n] if (closed or i > 0) else w
                nxt = weights[(i + 1) % n] if (closed or i < n - 1) else w
                a, b = pack(q(w), index)
                hw = handles[i] if handles is not None else None
                c, e = pack(q(hw[0] if hw else mix(w, prv, 0.33)), index)
                g, h = pack(q(hw[1] if hw else mix(w, nxt, 0.33)), index)
                v.add(d("CubicWeight", values=a, indices=b, inValues=c, inIndices=e, outValues=g, outIndices=h))
        tendons = [d("Tendon", boneId=bones[k][1].ref(), tx=bones[k][0][0] - frame[0], ty=bones[k][0][1] - frame[1])
                   for k in index]
        path.add(d("Skin", *tendons, tx=ox - frame[0], ty=oy - frame[1]))
        kids = [d("ClippingShape", sourceId=clip.ref(), name="Clip")] if clip is not None else []
        return d("Shape", *kids, path, *paints, x=ox - frame[0], y=oy - frame[1], name=name, **kw)

    def fill(self, c: str) -> El:
        return fill(self.d, c)

    def stroke(self, c: str, w: float) -> El:
        return stroke(self.d, c, w)


# ------------------------------------------------------------------ rigging the avatar

def rig_brow(fr: FaceRig, brow_g: El, shape: El, cx: float, s: int, color: str) -> None:
    """Skin the brow shape to inner / mid / outer bones (bones live in BrowG, frame (cx, 346))."""
    frame = (cx, 346.0)
    bones: dict[str, tuple[tuple[float, float], El]] = {}
    for nm, (dx0, y, tdx, tdy) in BROW_BONES.items():
        art = (cx + dx0 * s, y)
        # + dx terms point toward the face centre: the centre is at -s from the eye
        el = fr.bone(f"Brow{nm}", (art[0] - frame[0], art[1] - frame[1]), {p: -s * c for p, c in tdx.items()}, tdy)
        bones[nm] = (art, el)
        brow_g.children.insert(0, el)
    pts = [(cx - 30 * s, 342, "c"), (cx - 8 * s, 335), (cx + 16 * s, 335), (cx + 36 * s, 344, "c"),
           (cx + 16 * s, 341), (cx - 8 * s, 341)]

    def w(x: float) -> dict[str, float]:
        u = (x - cx) * s  # along the brow, inner (-) to outer (+)
        anchors = [(-26.0, "Inner"), (4.0, "Mid"), (32.0, "Outer")]
        if u <= anchors[0][0]:
            return {"Inner": 1.0}
        if u >= anchors[-1][0]:
            return {"Outer": 1.0}
        for (u0, a), (u1, b) in zip(anchors, anchors[1:]):
            if u <= u1:
                t = (u - u0) / (u1 - u0)
                return {a: 1 - t, b: t}
        return {"Outer": 1.0}

    new = fr.skinned("BrowShape", pts, [w(p[0]) for p in pts], bones, frame, fr.fill(color))
    brow_g.children[brow_g.children.index(shape)] = new


def rig_eye(fr: FaceRig, eye: Mapping[str, object], s: int) -> None:
    """Eye opening, mood lids and squint crescent follow the lid / brow / cheek AUs."""
    mood_el: El = eye["mood"].el  # type: ignore[attr-defined]
    fr.bind_on(mood_el, "scaleY", 1.0, terms(UL=0.16, LT=-0.08))
    fr.bind_on(mood_el, "scaleX", 1.0, terms(UL=0.1, LT=-0.02))
    droop: El = eye["droop"].el  # type: ignore[attr-defined]
    # a dead zone: a lid scaled to ~0.01 still draws a dashed sliver of lash
    fr.bind_on(droop, "scaleY", -0.04, terms(IU=0.4, BL=0.3, LT=0.15, UL=-0.8), lo=0.0, hi=1.0)
    fr.bind_on(droop, "rotation", 0.0, {"auBrowInnerUp": 0.25 * s, "auBrowLower": -0.28 * s})
    for k in ("squint", "squint_line"):
        el: El = eye[k]  # type: ignore[assignment]
        fr.bind_on(el, "scaleY", -0.03, terms(CR=0.78, LT=0.37), lo=0.0, hi=1.0)


LIP_TENSION = 1.3


def add_terms(*parts: tuple[float, Mapping[str, float]]) -> dict[str, float]:
    out: dict[str, float] = {}
    for k, t in parts:
        for p, c in t.items():
            out[p] = out.get(p, 0.0) + k * c
    return {p: c for p, c in out.items() if abs(c) > 1e-9}


def lip_handles(order: Sequence[str]) -> dict[str, tuple[float, float, str, str]]:
    """Catmull-Rom handle factors (k_in, k_out, prev, next) of every smooth lip vertex, from the
    rest geometry exactly as rml.smooth_path computes them (handle = p -+ k * (next - prev))."""
    rest = {n: b[0] for n, b in mouth_bones().items()}
    out: dict[str, tuple[float, float, str, str]] = {}
    m = len(order)
    for i, n in enumerate(order):
        if n.startswith("Corner"):
            continue
        prv, nxt = order[(i - 1) % m], order[(i + 1) % m]
        (px, py), (x, y), (nx, ny) = rest[prv], rest[n], rest[nxt]
        dn, dp = math.hypot(nx - x, ny - y), math.hypot(px - x, py - y)
        tot = dn + dp or 1.0
        out[n] = (LIP_TENSION / 6 * 2 * dp / tot, LIP_TENSION / 6 * 2 * dn / tot, prv, nxt)
    return out


def lip_handle_bones(fr: FaceRig, bones: dict[str, tuple[tuple[float, float], El]], order: Sequence[str],
                     frame: tuple[float, float]) -> list[tuple[dict[str, float], dict[str, float]] | None]:
    """Skin weights cannot be negative, so a handle blended from its neighbours' weights never turns
    as far as the Catmull-Rom tangent does (the lip waves). Each lip handle gets its own bone whose
    formula IS that tangent: d_handle = d_vertex -+ k * (d_next - d_prev), linear in the AUs."""
    specs = mouth_bones()
    hw: list[tuple[dict[str, float], dict[str, float]] | None] = []
    for n in order:
        h = lip_handles(order).get(n)
        if h is None:
            hw.append(None)
            continue
        k_in, k_out, prv, nxt = h
        (x, y), dx, dy = specs[n]
        (px, py), pdx, pdy = specs[prv]
        (nx, ny), ndx, ndy = specs[nxt]
        names = []
        for tag, k in (("In", -k_in), ("Out", k_out)):
            name = f"Mouth{n}{tag}"
            if name not in bones:
                art = (x + k * (nx - px), y + k * (ny - py))
                tdx = add_terms((1.0, dx), (k, ndx), (-k, pdx))
                tdy = add_terms((1.0, dy), (k, ndy), (-k, pdy))
                bones[name] = (art, fr.bone(name, (art[0] - frame[0], art[1] - frame[1]), tdx, tdy))
            names.append(name)
        hw.append(({names[0]: 1.0}, {names[1]: 1.0}))
    return hw


def rig_mouth(fr: FaceRig, host: El, palette: Mapping[str, str]) -> El:
    """Build the continuous mouth inside `host` (a Node at MOUTH_FRAME, x = y = 0)."""
    F = MOUTH_FRAME
    bones: dict[str, tuple[tuple[float, float], El]] = {}
    for nm, ((x, y), dx, dy) in mouth_bones().items():
        bones[nm] = ((x, y), fr.bone("Mouth" + nm, (x - F[0], y - F[1]), dx, dy))

    def at(n: str) -> tuple[float, float]:
        return bones[n][0]

    one = lambda n: {n: 1.0}  # noqa: E731
    # inside: corners slightly rounded, lips smooth with long handles (round U / D openings); at rest
    # upper == lower, so the outline is the closed mouth line. Fill (clip source, back) and outline
    # (front) are two shapes on the same skin so teeth and tongue sit between them.
    order = ["CornerL", "UpperL", "UpperC", "UpperR", "CornerR", "LowerR", "LowerC", "LowerL"]
    pts = [(*at(n), "c2") if n.startswith("Corner") else at(n) for n in order]
    hw = lip_handle_bones(fr, bones, order, F)
    inside = fr.skinned("MouthInside", pts, [one(n) for n in order], bones, F, fr.fill(palette["inside"]),
                        tension=LIP_TENSION, handles=hw)
    line = fr.stroke(palette["ink"], 2.7)
    fr.bind_on(line, "thickness", 2.7, terms(R=1.3, K=0.3))  # pressed lips read as a firmer line
    outline = fr.skinned("MouthLine", pts, [one(n) for n in order], bones, F, line,
                         tension=LIP_TENSION, handles=hw)
    # a darker throat toward the lower jaw gives the opening depth
    throat = fr.skinned("MouthThroat", [(389.0, 479.0), (400.0, 475.0), (411.0, 479.0), (400.0, 484.0)],
                        [{"LowerL": 0.6, "UpperL": 0.4}, {"UpperC": 0.35, "LowerC": 0.65},
                         {"LowerR": 0.6, "UpperR": 0.4}, one("LowerC")], bones, F,
                        fr.fill(palette["throat"]), clip=inside)
    teeth = fr.skinned("MouthTeeth",
                       [(377.0, 472.0, "c"), (400.0, 473.0, "c"), (423.0, 472.0, "c"), (419.0, 485.0),
                        (400.0, 487.0), (381.0, 485.0)],
                       [{"CornerL": 0.6, "UpperL": 0.4}, one("UpperC"), {"CornerR": 0.6, "UpperR": 0.4},
                        {"CornerR": 0.3, "UpperR": 0.7}, one("UpperC"), {"CornerL": 0.3, "UpperL": 0.7}],
                       bones, F, fr.fill(palette["teeth"]), clip=inside)
    low_teeth = fr.skinned("MouthLowTeeth",
                           [(381.0, 482.0), (400.0, 484.0), (419.0, 482.0), (421.0, 491.0, "c"),
                            (400.0, 492.0, "c"), (379.0, 491.0, "c")],
                           [{"LowerL": 0.7, "CornerL": 0.3}, one("LowerC"), {"LowerR": 0.7, "CornerR": 0.3},
                            one("LowerR"), one("LowerC"), one("LowerL")],
                           bones, F, fr.fill(palette["low_teeth"]), clip=inside)
    fr.bind_on(low_teeth, "opacity", 0.0, terms(S=1.4, J=0.25, K=-1.0), lo=0.0, hi=1.0)
    # rounded lips (o, u, w) push forward over the teeth
    fr.bind_on(teeth, "opacity", 1.0, terms(K=-1.1), lo=0.0, hi=1.0)
    tongue = fr.skinned("MouthTongue", [(386.0, 478.0), (400.0, 472.5), (414.0, 478.0), (400.0, 484.0)],
                        [{"LowerL": 0.5, "LowerC": 0.5}, one("TongueTip"), {"LowerR": 0.5, "LowerC": 0.5},
                         one("LowerC")], bones, F, fr.fill(palette["tongue"]), clip=inside)
    lower_lip = fr.skinned("LowerLipShade", [(390.0, 486.0), (400.0, 488.5), (410.0, 486.0)],
                           [one("LowerL"), one("LowerC"), one("LowerR")], bones, F,
                           fr.stroke(palette["lip"], 2.6), closed=False)
    creases = []
    for side, c in (("L", "CornerL"), ("R", "CornerR")):
        x0, y0 = at(c)
        k = -1 if side == "L" else 1
        sh = fr.skinned("SmileCrease" + side, [(x0 + 4 * k, y0 - 5), (x0 + 6.5 * k, y0 - 1), (x0 + 5 * k, y0 + 3.5)],
                        [one(c)] * 3, bones, F, fr.stroke(palette["crease"], 1.8), closed=False)
        fr.bind_on(sh, "opacity", 0.0, terms(DM=1.0, P=0.55, CR=0.2), lo=0.0, hi=1.0)
        creases.append(sh)
    group = fr.d("Node", *creases, lower_lip, outline, tongue, teeth, low_teeth, throat, inside,
                 *[b for _, b in bones.values()], x=0.0, y=0.0, name="FaceMouth")
    host.add(group)
    return group


def rig_nose(fr: FaceRig, nose_g: El, frame: tuple[float, float], palette: Mapping[str, str]) -> None:
    """Nose wrinkle: the nose lifts and shortens; wrinkle lines appear at the bridge."""
    pivot = (400.0 - frame[0], 452.0 - frame[1])
    kids = list(nose_g.children)
    inner = fr.d("Node", *kids, x=-pivot[0], y=-pivot[1], name="NoseAUPivot")
    outer = fr.d("Node", fr.bind("y", pivot[1], terms(NW=-2.5)), fr.bind("scaleY", 1.0, terms(NW=-0.12)),
                 inner, x=pivot[0], y=pivot[1], name="NoseAU")
    lines = []
    for k, (x, y) in enumerate(((394.0, 414.0), (405.0, 413.0))):
        p = [(x - 4 - frame[0], y + 1 - frame[1]), (x - frame[0], y - 1.5 - frame[1]),
             (x + 4 - frame[0], y + 1 - frame[1])]
        path = smooth_path(fr.d, p, closed=False)
        sh = fr.d("Shape", fr.bind("opacity", 0.0, terms(NW=1.0), lo=0.0, hi=1.0), path,
                  fr.stroke(palette["crease"], 1.8), x=0.0, y=0.0, name=f"NoseWrinkle{k}")
        lines.append(sh)
    nose_g.children = [*lines, outer]


def rig_cheeks(fr: FaceRig, parent: El, blooms: Sequence[El]) -> None:
    """Cheek raise lifts and swells the cheek bloom."""
    for b in blooms:
        x, y = float(b.attrs.get("x", 0.0)), float(b.attrs.get("y", 0.0))
        fr.wrap(parent, b, (x, y), str(b.attrs.get("name")) + "AU",
                [("y", 0.0, terms(CR=-5.0)), ("scaleX", 1.0, terms(CR=0.12)), ("scaleY", 1.0, terms(CR=0.1))])


def rig_body(fr: FaceRig, root: El, body: El, body_g: El, head_base: El,
             neck: tuple[float, float]) -> None:
    """`breath` lifts the body from the feet (root frame); `roll` tilts the head about the neck
    (`neck` in body_g's local frame)."""
    fr.wrap(root, body, (0.0, 0.0), "BreathLift",
            [("y", 0.0, {"breath": -2.5}), ("scaleY", 1.0, {"breath": 0.012}), ("scaleX", 1.0, {"breath": 0.004})])
    fr.wrap(body_g, head_base, neck, "HeadRoll",
            [("rotation", 0.0, {"roll": round(math.radians(6), 4)}), ("y", 0.0, {"breath": -1.5})])
