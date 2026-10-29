"""FACS-lite face rig for the shipped avatar (moonshot M2, contract v5).

Called by gen_avatar.py after the head art, the view model and the animations exist, and before
head_turn.py wraps the head for yaw / pitch. Every AvatarVM number below maps to the art through
history-free formula data binds (value = c0 + sum c_i * [prop_i]), the same mechanism as the head
turn, so a pose depends only on the current numbers:

- `au*` (FACS-lite action units, 0..1): brows are skinned to inner / mid / outer bones; each eye
  is an aperture skinned to upper and lower lid bones (M3, `rig_lids`: blinks slide the upper
  row onto the lower row through `BlinkDrive` constraints); the cheek bloom and the nose bind
  their own transforms; the mouth is ONE continuous skinned shape on corner, upper and lower lip bones.
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

from rig_dsl import Formulas, Skeleton, pack, plain_tendon, quantize, skinned_path
from rml import Doc, El, fill, smooth_path, stroke

ID_START = 950000
LID_ID_START = 960000  # the lid rig and the v6 side numbers (main-doc ids stay unchanged)
KEYS = {"x": 13, "y": 14, "rotation": 15, "scaleX": 16, "scaleY": 17, "opacity": 18, "radius": 26, "thickness": 47,
        "boneX": 90,
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


SIDED = frozenset({"auBrowInnerUp", "auBrowOuterUp", "auBrowLower", "auLidTighten", "auCheekRaise",
                   "auLipCornerPull", "auLipCornerDepress"})  # contract v6: au<Name>L / au<Name>R offsets
SIDE_NUMBERS = tuple(f"{a}{t}" for a in AUS if a in SIDED for t in ("L", "R"))

# Pseudo-terms: a term key is a view-model number, or one of these amounts (each one formula, the
# same in Python and in the generated binds):
#   "<au>|L" / "<au>|R"  clamp01(<au> + <au>L|R): a sided AU on the viewer's left / right (v6)
#   PART                 clamp01(stretch - 2 press): stretched lips part off the teeth (s, e, i);
#                        pressed lips stay sealed (angry is stretch 0.3 + press 0.6)
#   TENSE                min(1, 2.5 min(press, stretch)): pressed AND stretched, the squared mouth
PART = "@part"
TENSE = "@tense"
_SHORT.update(PT=PART, TS=TENSE)


def sided(t: Terms, side: str) -> dict[str, float]:
    """A side's terms: every sided AU reads its clamped side sum (`side` "L" / "R")."""
    return {(f"{p}|{side}" if p in SIDED else p): c for p, c in t.items()}


def centred(t: Terms) -> dict[str, float]:
    """A centre bone's terms: half of each side's clamped sum (equal to the plain AU when the
    offsets are 0), so a one-sided pull moves the lip centre half as far."""
    out: dict[str, float] = {}
    for p, c in t.items():
        for k, v in (((f"{p}|L", c / 2), (f"{p}|R", c / 2)) if p in SIDED else ((p, c),)):
            out[k] = out.get(k, 0.0) + v
    return out


def amount(env: Mapping[str, float], key: str) -> float:
    """The value a term key stands for (see the pseudo-terms above)."""
    if "|" in key:
        au, side = key.split("|")
        return min(1.0, max(0.0, env.get(au, 0.0) + env.get(au + side, 0.0)))
    if key == PART:
        return min(1.0, max(0.0, env.get("auLipStretch", 0.0) - 2 * env.get("auLipPress", 0.0)))
    if key == TENSE:
        return min(1.0, 2.5 * min(env.get("auLipPress", 0.0), env.get("auLipStretch", 0.0)))
    return env.get(key, 0.0)


def base_prop(key: str) -> str:
    """The view-model number a term key's formula reads first (a bind's source path)."""
    if "|" in key:
        return key.split("|")[0]
    return {PART: "auLipStretch", TENSE: "auLipPress"}.get(key, key)


def terms(**kw: float) -> dict[str, float]:
    """Short names -> contract names; a jaw term also reads the legacy `mouth` number."""
    out = {_SHORT[k]: v for k, v in kw.items() if v}
    if "auJawDrop" in out:
        out["mouth"] = out["auJawDrop"] * JAW_PER_MOUTH
    return out


def evaluate(c0: float, t: Terms, env: Mapping[str, float]) -> float:
    return c0 + sum(c * amount(env, p) for p, c in t.items())


# ------------------------------------------------------------------ geometry tables (head art space)

# Brows: bone rest positions per side (s = -1 left, +1 right; the inner end is toward x = 400).
# dx is given toward the face centre for + (mirrored per side); dy is screen y (+ = down).
BROW_BONES = {  # name: (dx from eye centre * s, y, dx terms (toward centre), dy terms)
    "Inner": (-26.0, 341.0, terms(BL=4.5, IU=0.5), terms(IU=-18.0, OU=-4.0, BL=13.0)),
    "Mid": (4.0, 337.0, terms(BL=1.5), terms(IU=-7.0, OU=-10.0, BL=5.0)),
    # AU1 alone tilts the brow (outer end a touch down): the oblique sad brow
    "Outer": (32.0, 342.0, terms(OU=-1.5), terms(IU=3.0, OU=-16.0, BL=-4.0)),
}

MOUTH_FRAME = (400.0, 478.0)
# Mouth bones: rest (x, y) for the RIGHT side / centre; dx terms are toward the viewer's right for the
# right side (mirrored for the left); dy terms are screen y. Sided AUs (corner pull / depress, cheek
# raise) read the side's clamped sum; the centre reads half of each side (`mouth_bones`).
MOUTH_BONES = {
    # TS (the squared angry mouth): the corners turn down and out, sharp, under a flat lip line
    "CornerR": ((417.0, 477.0), terms(P=5.0, S=9.5, J=3.0, K=-10.5, R=-3.0, DM=1.0, D=1.0, TS=1.5),
                terms(P=-7.0, D=8.5, CR=-1.5, J=5.0, S=2.0, DM=-1.0, TS=4.5)),
    # closed-mouth terms (corners, smile, frown, dimpler, press, tension) move the upper and lower
    # lips together so a closed mouth stays one line; jaw, pucker, nose wrinkle, lip tuck and the
    # stretch's lip part (PT, sealed again by press) open it
    "UpperR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0, TS=4.0),
               terms(P=0.3, D=2.0, J=-3.5, NW=-1.0, T=-2.5, K=-0.8, PT=-3.0)),
    "UpperC": ((400.0, 480.0), terms(), terms(P=2.0, D=-1.0, J=-5.0, NW=-1.5, T=-3.0, K=-1.0, PT=-4.0)),
    # lip tuck (f, v) lifts the lower lip onto the upper teeth's edge (TEETH_EDGE) at the f/v jaw
    "LowerR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0, TS=4.0),
               terms(P=0.3, D=2.0, J=19.0, K=1.0, T=-0.8, PT=5.5)),
    "LowerC": ((400.0, 480.0), terms(), terms(P=2.0, D=-1.0, J=23.0, K=1.5, T=-2.0, PT=7.0)),
}
# The upper teeth hang from the skull (they do not move): their edge is one arc, y = TEETH_EDGE[0] -
# TEETH_EDGE[1] (x - 400)^2. The lower teeth ride the jaw only (`JawTeeth`), just behind that edge.
TEETH_EDGE = (482.8, 0.0104)
LOW_TEETH_TOP = (482.2, 0.0104)
JAW_TEETH = 17.0  # px per unit jaw (the lower lip takes 23)


def teeth_edge_y(x: float, edge: tuple[float, float] = TEETH_EDGE) -> float:
    return edge[0] - edge[1] * (x - 400.0) ** 2


def mirror_terms(t: Terms) -> dict[str, float]:
    return {p: -c for p, c in t.items()}


def mouth_bones() -> dict[str, tuple[tuple[float, float], dict[str, float], dict[str, float]]]:
    """All mouth bones (left side mirrored from the right), with sided terms."""
    out: dict[str, tuple[tuple[float, float], dict[str, float], dict[str, float]]] = {}
    for name, ((x, y), dx, dy) in MOUTH_BONES.items():
        if name.endswith("R"):
            out[name] = ((x, y), sided(dx, "R"), sided(dy, "R"))
            out[name[:-1] + "L"] = ((2 * MOUTH_FRAME[0] - x, y), sided(mirror_terms(dx), "L"), sided(dy, "L"))
        else:
            out[name] = ((x, y), centred(dx), centred(dy))
    jaw = {p: c for p, c in terms(J=1.0).items()}
    out["JawTeeth"] = ((400.0, LOW_TEETH_TOP[0]), {}, {p: JAW_TEETH * c for p, c in jaw.items()})
    # the tongue tip rides the jaw (60 %: it lags into an open mouth) and rises to the upper teeth
    out["TongueTip"] = ((400.0, 483.0), {}, {**{p: 13.8 * c for p, c in jaw.items()}, "tongueUp": -12.0})
    return out


def mouth_pose(env: Mapping[str, float]) -> dict[str, tuple[float, float]]:
    """Predicted art-space position of every mouth bone (tests, review overlays)."""
    return {n: (x + evaluate(0.0, dx, env), y + evaluate(0.0, dy, env)) for n, ((x, y), dx, dy) in
            mouth_bones().items()}


# ------------------------------------------------------------------ the rig

class FaceRig:
    def __init__(self, path: Callable[[str], str], start: int = ID_START) -> None:
        self.d = Doc(client=0, start=start)
        self.path = path
        self.f = Formulas(self.d, path)
        self.converters: list[El] = []
        self._conv: dict[tuple[object, ...], El] = {}

    # ---- binds
    def converter(self, c0: float, t: Terms, lo: float | None = None, hi: float | None = None) -> tuple[str, El]:
        """Formula c0 + sum c_i [p_i], optionally clamped; returns (source prop, converter)."""
        items = sorted((p, round(c, 3)) for p, c in t.items() if round(c, 3))
        key = (round(c0, 3), tuple(items), lo, hi)
        src = base_prop(items[0][0]) if items else "auJawDrop"
        if key not in self._conv:
            f = self.f
            expr: list[El] = [f.val(c0)]
            for p, c in items:
                expr += [f.op("+"), f.val(c), f.op("*"), *self.amount(p, src)]
            if hi is not None:
                expr = f.fn("min", [f.val(hi)], expr)
            if lo is not None:
                expr = f.fn("max", [f.val(lo)], expr)
            conv = self.d("DataConverterFormula", *expr)
            self.converters.append(conv)
            self._conv[key] = conv
        return src, self._conv[key]

    def amount(self, key: str, src: str) -> list[El]:
        """Formula tokens of a term key (`amount` in Python); `src` is read through the input."""
        f = self.f

        def ref(p: str) -> list[El]:
            return f.inp() if p == src else [f.bound(p)]

        if "|" in key:
            au, side = key.split("|")
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [*ref(au), f.op("+"), *ref(au + side)]))
        if key == PART:
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [*ref("auLipStretch"), f.op("-"), f.val(2),
                                                                  f.op("*"), *ref("auLipPress")]))
        if key == TENSE:
            return f.fn("min", [f.val(1)], [f.val(2.5), f.op("*"),
                                            *f.fn("min", ref("auLipPress"), ref("auLipStretch"))])
        return ref(key)

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
        n = len(pts)

        def mix(a: Mapping[str, float], b: Mapping[str, float], t: float) -> dict[str, float]:
            out = {k: (1 - t) * v for k, v in a.items()}
            for k, v in b.items():
                out[k] = out.get(k, 0.0) + t * v
            return out

        def vertex_weights(i: int, _at: tuple[float, float],
                           hs: tuple[tuple[float, float], tuple[float, float]] | None) -> list[Mapping[str, float]]:
            w = weights[i]
            if hs is None:
                return [w]
            hw = handles[i] if handles is not None else None
            if hw:
                return [w, hw[0], hw[1]]
            prv = weights[(i - 1) % n] if (closed or i > 0) else w
            nxt = weights[(i + 1) % n] if (closed or i < n - 1) else w
            return [w, mix(w, prv, 0.33), mix(w, nxt, 0.33)]

        path, (ox, oy) = skinned_path(d, pts, frame, vertex_weights,
                                      lambda k: plain_tendon(d, bones[k][1], bones[k][0], frame),
                                      closed=closed, tension=tension)
        kids = [d("ClippingShape", sourceId=clip.ref(), name="Clip")] if clip is not None else []
        return d("Shape", *kids, path, *paints, x=ox - frame[0], y=oy - frame[1], name=name, **kw)

    def fill(self, c: str) -> El:
        return fill(self.d, c)

    def stroke(self, c: str, w: float) -> El:
        return stroke(self.d, c, w)


# ------------------------------------------------------------------ rigging the avatar

def brow_bones(s: int) -> dict[str, tuple[float, float, dict[str, float], dict[str, float]]]:
    """One brow's bones: (x from the eye centre, rest y, dx terms, dy terms); `s` -1 = the viewer's
    left. + dx terms of the table point toward the face centre (at -s from the eye); every sided AU
    reads the side's clamped sum (contract v6)."""
    side = "L" if s < 0 else "R"
    return {nm: (dx0 * s, y, sided({p: -s * c for p, c in tdx.items()}, side), sided(tdy, side))
            for nm, (dx0, y, tdx, tdy) in BROW_BONES.items()}


def brow_pose(env: Mapping[str, float], s: int) -> dict[str, tuple[float, float]]:
    """Predicted (x from the eye centre, y) of a brow's bones (tests, review overlays)."""
    return {nm: (u + evaluate(0.0, tdx, env), y + evaluate(0.0, tdy, env))
            for nm, (u, y, tdx, tdy) in brow_bones(s).items()}


def rig_brow(fr: FaceRig, brow_g: El, shape: El, cx: float, s: int, color: str, outline: str) -> None:
    """Skin the brow shape to inner / mid / outer bones (bones live in BrowG, frame (cx, 346)). The
    brows paint over the fringe in the hair's own colour, so a thin skin-tone outline keeps them
    readable over it (invisible over skin)."""
    frame = (cx, 346.0)
    bones: dict[str, tuple[tuple[float, float], El]] = {}
    for nm, (u, y, tdx, tdy) in brow_bones(s).items():
        art = (cx + u, y)
        el = fr.bone(f"Brow{nm}", (art[0] - frame[0], art[1] - frame[1]), tdx, tdy)
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

    new = fr.skinned("BrowShape", pts, [w(p[0]) for p in pts], bones, frame, fr.stroke(outline, 2.4),
                     fr.fill(color))
    brow_g.children[brow_g.children.index(shape)] = new


# ------------------------------------------------------------------ eyes on lid bones (M3)
#
# Each eye is one aperture (the eye opening) skinned to an upper and a lower row of lid bones. A row
# runs inner corner -> inner -> mid -> outer -> outer corner (u is measured from the eye centre
# toward its outer corner, so "inner" is toward the face centre); each column has a vertex bone and
# two handle bones. A handle bone's formula IS the Catmull-Rom tangent of the current vertex
# formulas (handle = vertex +- k (next - previous), linear in the AUs), so the lids bend smoothly
# into any pose instead of keeping their rest tangents. The white, iris, pupil and catchlights are
# clipped by the aperture; the upper lash and the lower lid line are bands whose inner edge IS the
# aperture's edge on the same bones, so no lid stroke can sit over a visible iris or reach the
# glasses, and since bones only translate the bands keep their line weight.
#
# Every bone's y is one history-free formula of the view-model numbers. A blink is a
# `TranslationConstraint` named `BlinkDrive` on each upper bone (vertices and handles), targeting
# its lower twin: its strength (0 open -> 1 closed, keyed by the blink loop / hold / once
# animations) slides the upper row onto the lower row's CURRENT line, so a blink composes with any
# AU pose and closes exactly (the strength is the blink's only state; there is no blink
# view-model number a formula token could read).

LID_COLS: dict[str, float] = {"Inner": -14.0, "Mid": 3.0, "Outer": 18.0}  # u of each bone column
UPPER_REST: dict[str, float] = {"Inner": 376.5, "Mid": 372.6, "Outer": 374.5}  # rest y
LOWER_REST: dict[str, float] = {"Inner": 401.5, "Mid": 404.0, "Outer": 401.0}
EYE_CORNERS: dict[str, tuple[float, float]] = {"In": (-28.0, 392.0), "Out": (29.0, 391.5)}  # (u, y)
CORNER_RADIUS = 2.5
LID_GAP = 1.5  # px: an AU pose alone never closes the opening further than this (a blink does)
EYE_FRAME_DY = 392.0  # the Blink node's art-space y: the bones' frame is (cx, 392)
LOOK_DOWN = "eyeLeadPitch"  # contract: at - the upper lids drop (~25 % lid coverage at -1)
DOWN = "@down"  # pseudo-term: max(0, -eyeLeadPitch)

# dy per AU (+ = down). Upper: AU5 lifts it, AU7 lowers it a little, AU1 drops the outer end (sad
# droop; AU2 takes it back so the surprise pose stays open), AU4 drops the inner end (anger), AU6
# arches it a little (smiling eyes); looking down drops it.
UPPER_LID: dict[str, dict[str, float]] = {
    "Inner": {**terms(UL=-2.5, LT=2.0, BL=9.0, CR=1.5), DOWN: 8.0},
    "Mid": {**terms(UL=-3.5, LT=2.5, IU=2.5, OU=-1.5, BL=3.5, CR=-2.0), DOWN: 9.5},
    "Outer": {**terms(UL=-3.0, LT=2.0, IU=11.0, OU=-8.0, BL=0.5, CR=1.5), DOWN: 8.5},
}
# Lower: AU7 lifts it; AU6 lifts the middle more than the ends, so the line bows up into a smile
# crescent over the lower iris; AU5 lets it down a little (a surprised eye shows white below).
LOWER_LID: dict[str, dict[str, float]] = {
    "Inner": terms(UL=1.2, LT=-4.0, CR=-19.0),
    "Mid": terms(UL=1.8, LT=-6.0, CR=-26.0),
    "Outer": terms(UL=1.2, LT=-5.0, CR=-19.0),
}
# The corners never move in a blink; AU7 pulls them in a touch.
CORNER_LID: dict[str, dict[str, float]] = {"In": terms(LT=-1.0, CR=0.5), "Out": terms(LT=-1.0, CR=0.5)}
LASH_T: dict[str, float] = {"In": 1.0, "Inner": 2.6, "Mid": 3.8, "Outer": 4.6}  # lash thickness (px)
LOWER_T: dict[str, float] = {"In": 0.2, "Inner": 0.8, "Mid": 1.3, "Outer": 1.8, "Out": 2.0}
SEAM = 0.6  # px the lid bands reach into the aperture (no anti-aliasing seam at the edge)
SHADE_T: dict[str, float] = {"Inner": 3.0, "Mid": 4.2, "Outer": 3.6}  # the upper lid's shadow on the white

Pt2 = tuple[float, float]


def lid_amount(env: Mapping[str, float], au: str, side: str) -> float:
    """A term's factor as the lid binds read it: an AU plus its side offset clamped 0..1 (unsided
    AUs raw), or the look-down amount."""
    if au == DOWN:
        return max(0.0, -env.get(LOOK_DOWN, 0.0))
    if au in SIDED:
        return min(1.0, max(0.0, env.get(au, 0.0) + env.get(au + side, 0.0)))
    return env.get(au, 0.0)


def lid_points(row: str) -> list[tuple[str, float, float, Terms]]:
    """(bone, u, rest y, dy terms) along a row, inner corner -> outer corner."""
    rest, table = (UPPER_REST, UPPER_LID) if row == "Upper" else (LOWER_REST, LOWER_LID)
    (ui, yi), (uo, yo) = EYE_CORNERS["In"], EYE_CORNERS["Out"]
    return [("CornerIn", ui, yi, CORNER_LID["In"]), *[(row + c, LID_COLS[c], rest[c], table[c]) for c in LID_COLS],
            ("CornerOut", uo, yo, CORNER_LID["Out"])]


def lid_bones() -> dict[str, tuple[float, float, Terms]]:
    """Every lid bone: (u, rest y, dy terms). Handles (`<vertex>In` toward the inner corner,
    `<vertex>Out` toward the outer) follow the Catmull-Rom tangent of the rest geometry exactly
    as rml.smooth_path computes it (handle = vertex -+ k (next - previous))."""
    out: dict[str, tuple[float, float, Terms]] = {}
    for row in ("Lower", "Upper"):
        pts = lid_points(row)
        for name, u, y, t in pts:
            out[name] = (u, y, dict(t))
        for i in range(1, len(pts) - 1):
            (name, u, y, t), (_, pu, py, pt), (_, nu, ny, nt) = pts[i], pts[i - 1], pts[i + 1]
            dn, dp = math.hypot(nu - u, ny - y), math.hypot(pu - u, py - y)
            tot = dn + dp
            for tag, k in (("In", -dp / (3 * tot)), ("Out", dn / (3 * tot))):
                out[name + tag] = (u + k * (nu - pu), y + k * (ny - py), add_terms((1.0, t), (k, nt), (-k, pt)))
    return out


def lid_pose(env: Mapping[str, float], s: int, blink: float = 0.0) -> dict[str, Pt2]:
    """Predicted (u, y) of every lid bone: the bind formulas, then the blink (upper -> lower twin)."""
    side = "L" if s < 0 else "R"
    bones = lid_bones()
    raw = {n: (u, y + sum(c * lid_amount(env, p, side) for p, c in t.items())) for n, (u, y, t) in bones.items()}
    out = dict(raw)
    for col in LID_COLS:  # the vertex cap: an AU pose never closes the eye
        u, y = raw["Upper" + col]
        out["Upper" + col] = (u, min(y, raw["Lower" + col][1] - LID_GAP))
    for n in bones:
        if n.startswith("Upper"):
            (u, y), (lu, ly) = out[n], out["Lower" + n[5:]]
            out[n] = (u + blink * (lu - u), y + blink * (ly - y))
    return out


def lid_edge(pose: Mapping[str, Pt2], row: str, samples: int = 8) -> list[Pt2]:
    """Points along a row's curve (inner corner -> outer corner) for a pose: the cubic segments
    the aperture draws (corners are straight vertices)."""
    names = [n for n, *_ in lid_points(row)]
    out: list[Pt2] = []
    for a, b in zip(names, names[1:]):
        p0 = pose[a]
        p1 = pose[a + "Out"] if not a.startswith("Corner") else p0
        p2 = pose[b + "In"] if not b.startswith("Corner") else pose[b]
        p3 = pose[b]
        for k in range(samples):
            t = k / samples
            out.append(tuple(((1 - t) ** 3) * p0[i] + 3 * ((1 - t) ** 2) * t * p1[i] + 3 * (1 - t) * t * t * p2[i]
                             + t ** 3 * p3[i] for i in range(2)))  # type: ignore[misc]
    out.append(pose[names[-1]])
    return out


Vert = dict  # {"at": (x, y), "corner": radius | None, "in": (x, y), "out": (x, y), "w": [...]}


def eye_edges(cx: float, s: int) -> dict[str, list[Vert]]:
    """Art-space vertices of the aperture's upper edge (inner corner -> outer corner) and lower
    edge (outer corner -> inner corner), with handles and skin weights (one bone each)."""
    bones = lid_bones()

    def at(n: str) -> Pt2:
        u, y, _ = bones[n]
        return (cx + s * u, y)

    def vert(n: str, forward: bool) -> Vert:
        if n.startswith("Corner"):
            return {"at": at(n), "corner": CORNER_RADIUS, "w": [{n: 1.0}]}
        a, b = (n + "In", n + "Out") if forward else (n + "Out", n + "In")
        return {"at": at(n), "corner": None, "in": at(a), "out": at(b), "w": [{n: 1.0}, {a: 1.0}, {b: 1.0}]}

    upper = [vert(n, True) for n, *_ in lid_points("Upper")]
    lower = [vert(n, False) for n, *_ in reversed(lid_points("Lower"))]
    return {"upper": upper, "lower": lower}


def shifted(v: Vert, dy: float, corner: float | None | str = "keep") -> Vert:
    out = dict(v)
    for k in ("at", "in", "out"):
        if k in v:
            out[k] = (v[k][0], v[k][1] + dy)
    if corner != "keep":
        out["corner"] = corner
    return out


def reversed_edge(vs: Sequence[Vert]) -> list[Vert]:
    """The same edge traversed the other way (handles and their weights swap)."""
    return [{**v, "in": v["out"], "out": v["in"], "w": [v["w"][0], v["w"][2], v["w"][1]]} if "in" in v else dict(v)
            for v in reversed(vs)]


def explicit_path(d: Doc, verts: Sequence[Vert], frame: Pt2, tendon: Callable[[str], El],
                  closed: bool = True) -> tuple[El, Pt2]:
    """A skinned PointsPath through absolute art-space vertices with explicit handles and weights
    (rig_dsl.skinned_path derives both; the lids' handles ride their own bones)."""
    xs = [v["at"][0] for v in verts]
    ys = [v["at"][1] for v in verts]
    ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    n = len(verts)
    area = sum(verts[i]["at"][0] * verts[(i + 1) % n]["at"][1] - verts[(i + 1) % n]["at"][0] * verts[i]["at"][1]
               for i in range(n))
    index: dict[str, int] = {}
    els: list[El] = []
    for v in verts:
        x, y = v["at"]
        qss = [quantize(dict(w)) for w in v["w"]]
        for qs in qss:
            for b, _ in qs:
                index.setdefault(b, len(index))
        if "in" not in v:
            val, ix = pack(qss[0], index)
            els.append(d("StraightVertex", d("Weight", values=val, indices=ix), x=round(x - ox, 3),
                         y=round(y - oy, 3), radius=v.get("corner") or None))
            continue
        (a, b_), (c, e), (g, h) = (pack(qs, index) for qs in qss)
        (ix_, iy), (ox_, oy_) = v["in"], v["out"]
        els.append(d("CubicDetachedVertex",
                     d("CubicWeight", values=a, indices=b_, inValues=c, inIndices=e, outValues=g, outIndices=h),
                     x=round(x - ox, 3), y=round(y - oy, 3),
                     inRotation=round(math.atan2(iy - y, ix_ - x), 4), inDistance=round(math.hypot(ix_ - x, iy - y), 3),
                     outRotation=round(math.atan2(oy_ - y, ox_ - x), 4),
                     outDistance=round(math.hypot(ox_ - x, oy_ - y), 3)))
    path = d("PointsPath", *els, isClosed=closed, isClockwise=area > 0, name="Path")
    path.add(d("Skin", *[tendon(b) for b in index], tx=ox - frame[0], ty=oy - frame[1]))
    return path, (ox, oy)


def _reshape(target: El, frame: Pt2, path: El, centre: Pt2, *rest: El) -> None:
    """Swap a shape's geometry and paints in place: its id (the animation contract) survives."""
    target.children = [path, *rest]
    target.attrs["x"] = centre[0] - frame[0]
    target.attrs["y"] = centre[1] - frame[1]
    for k in ("origin", "opacity"):
        target.attrs.pop(k, None)


class LidFormula:
    """Token builder for the lid binds: `src` (the bind's source number) is read through the
    formula input, every other number as a bound token."""

    def __init__(self, fr: "FaceRig", src: str, side: str) -> None:
        self.f, self.src, self.side = fr.f, src, side

    def ref(self, p: str) -> list[El]:
        return self.f.inp() if p == self.src else [self.f.bound(p)]

    def amount(self, au: str) -> list[El]:
        f = self.f
        if au == DOWN:
            return f.fn("max", [f.val(0)], [f.val(-1), f.op("*"), *self.ref(LOOK_DOWN)])
        if au in SIDED:
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [*self.ref(au), f.op("+"), *self.ref(au + self.side)]))
        return self.ref(au)

    def linear(self, c0: float, t: Terms) -> list[El]:
        f = self.f
        out: list[El] = [f.val(c0)]
        for p, c in sorted(t.items()):
            if round(c, 3):
                out += [f.op("+"), f.val(c), f.op("*"), *self.amount(p)]
        return out


LID_SRC = "auLidTighten"  # every lid formula reads it, so it is each bind's source


def rig_lids(fr: "FaceRig", eye: Mapping[str, object], cx: float, s: int, ink: str, lower_ink: str,
             crease_ink: str, sclera: str, shade_ink: str) -> list[El]:
    """Rebuild one eye on lid bones inside its Blink node (see the block comment above). Returns the
    `BlinkDrive` constraints the blink animations key (strength 0 open .. 1 closed)."""
    d = fr.d
    side = "L" if s < 0 else "R"
    blink: El = eye["blink"].el  # type: ignore[attr-defined]
    frame = (cx, EYE_FRAME_DY)
    skel = Skeleton(d, "Lids" + side, frame)
    els: dict[str, El] = {"Anchor": skel.root("Anchor", frame)}
    lf = LidFormula(fr, LID_SRC, side)
    f = fr.f
    specs = lid_bones()
    drives: list[El] = []
    for name, (u, y, t) in specs.items():  # lower and corner bones first: the upper ones target them
        expr = lf.linear(y - frame[1], t)
        if name in ("Upper" + c for c in LID_COLS):
            lu, ly, lt = specs["Lower" + name[5:]]
            expr = f.fn("min", expr, lf.linear(ly - frame[1] - LID_GAP, lt))
        conv = d("DataConverterFormula", *expr)
        fr.converters.append(conv)
        bone = skel.root(name, (cx + s * u, y))
        bone.children.insert(0, d("DataBindContext", sourcePathIds=fr.path(LID_SRC), propertyKey=KEYS["boneY"],
                                  converterId=conv.ref()))
        if name.startswith("Upper"):
            drive = d("TranslationConstraint", targetId=els["Lower" + name[5:]].ref(), strength=0.0, name="BlinkDrive")
            bone.add(drive)
            drives.append(drive)
        els[name] = bone

    edges = eye_edges(cx, s)
    up, low = edges["upper"], edges["lower"]
    tendon = skel.tendon
    # aperture: the clip source of the eyeball (white, iris, pupil, catchlights)
    clip: El = eye["clip"]  # type: ignore[assignment]
    path, c = explicit_path(d, [*up, *low[1:-1]], frame, tendon)
    _reshape(clip, frame, path, c)
    # the white: a plain oval behind the eyeball, clipped by the aperture
    white: El = eye["white"]  # type: ignore[assignment]
    white.children = [d("ClippingShape", sourceId=clip.ref(), name="Clip"),
                      d("Ellipse", width=70.0, height=58.0, name="Path"), fill(d, sclera)]
    white.attrs["x"], white.attrs["y"] = s * 1.0, 388.0 - frame[1]

    def at(u: float, y: float) -> Pt2:
        return (cx + s * u, y)

    # upper lash: a tapered band whose lower edge is the aperture's upper edge, flicking out past
    # the outer corner
    out_w = [{"CornerOut": 1.0}]
    lash_bottom = [shifted(v, SEAM, corner=None if "in" not in v else "keep") for v in up]
    tops = reversed_edge([shifted(v, -LASH_T[col] + SEAM) for v, col in zip(up[1:-1], LID_COLS)])
    in_u, in_y = EYE_CORNERS["In"]
    lash_pts = [*lash_bottom, {"at": at(36.0, 384.5), "w": out_w}, {"at": at(29.5, 383.0), "w": out_w}, *tops,
                {"at": at(in_u + 1.0, in_y - LASH_T["In"]), "w": [{"CornerIn": 1.0}]}]
    lash: El = eye["lash"]  # type: ignore[assignment]
    path, c = explicit_path(d, lash_pts, frame, tendon)
    _reshape(lash, frame, path, c, fill(d, ink))
    # lower lid line: a thin tapered band under the aperture's lower edge, meeting the lash at the
    # outer corner (no gap) and fading out toward the inner corner
    low_top = [shifted(v, -SEAM, corner=None if "in" not in v else "keep") for v in low]
    bottoms = reversed_edge([shifted(v, LOWER_T[col] - SEAM) for v, col in zip(low[1:-1], reversed(LID_COLS))])
    lower_pts = [*low_top, shifted(low[-1], LOWER_T["In"], corner=None), *bottoms,
                 shifted(low[0], LOWER_T["Out"], corner=None)]
    lower: El = eye["lower"]  # type: ignore[assignment]
    path, c = explicit_path(d, lower_pts, frame, tendon)
    _reshape(lower, frame, path, c, fill(d, lower_ink))
    # lid crease: rides the upper row a third of the way (a lifted lid folds under it)
    crease: El = eye["crease"]  # type: ignore[assignment]
    cpts = [at(-12.0, 360.0), at(8.0, 356.0), at(32.0, 364.0)]
    cw = [{"UpperInner": 0.3, "Anchor": 0.7}, {"UpperMid": 0.3, "Anchor": 0.7}, {"UpperOuter": 0.3, "Anchor": 0.7}]
    path, c = skinned_path(d, cpts, frame, lambda i, _a, h: [cw[i]] if h is None else [cw[i]] * 3, tendon,
                           closed=False)
    _reshape(crease, frame, path, c, stroke(d, crease_ink, 2.0))
    # the upper lid's soft shadow on the white (behind the iris, clipped by the aperture)
    shade_pts = [*[shifted(v, 0.0, corner=None if "in" not in v else "keep") for v in up],
                 *reversed_edge([shifted(v, SHADE_T[col]) for v, col in zip(up[1:-1], LID_COLS)])]
    path, c = explicit_path(d, shade_pts, frame, tendon)
    shade = d("Shape", d("ClippingShape", sourceId=clip.ref(), name="Clip"), path, fill(d, shade_ink),
              x=c[0] - frame[0], y=c[1] - frame[1], name="LidShade")
    blink.children = [lash, lower, crease, *[ch for ch in blink.children if ch.attrs.get("name") == "GazeM"], shade,
                      white, clip, *els.values()]
    return drives


def add_side_numbers(d: Doc, vm: El, inst: El) -> dict[str, El]:
    """Contract v6 per-side offsets (number, default 0) in the view model, minted from `d` so the
    main document's ids do not move."""
    props = {pn: d("ViewModelPropertyNumber", name=pn) for pn in SIDE_NUMBERS}
    at = vm.children.index(next(c for c in vm.children if c.tag == "ViewModelInstance"))
    vm.children[at:at] = list(props.values())
    inst.children.extend(d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref())
                         for p in props.values())
    return props


def resolve_paths(roots: Sequence[El], paths: Mapping[str, str]) -> None:
    """Fill in bind paths of numbers that did not exist yet when the lids were rigged
    (`@<name>` placeholders; the head turn adds eyeLeadPitch to the view model later)."""
    stack = list(roots)
    while stack:
        e = stack.pop()
        p = e.attrs.get("sourcePathIds")
        if isinstance(p, str) and p.startswith("@"):
            e.attrs["sourcePathIds"] = paths[p[1:]]
        stack.extend(e.children)


LIP_TENSION = 1.3
# the face rig's mouth shapes in the order the head turn minted their face clips in M2 (ids stay put;
# MouthThroat is deleted: its id is burnt); newer shapes clip after every other head-turn id
MOUTH_CLIP_ORDER = ("SmileCreaseL", "SmileCreaseR", "LowerLipShade", "MouthLine", "MouthTeeth", "MouthLowTeeth",
                    "MouthTongue", "MouthThroat", "MouthInside")


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


def tapered(c: Sequence[Pt2], w: float, ends: str = "c") -> list[tuple]:
    """A tapered stroke as a closed lens around the centre line p0 -> pm -> p1 (pointed ends, `w`
    wide at pm): open strokes taper (art bible §4)."""
    (x0, y0), (xm, ym), (x1, y1) = c
    tx, ty = x1 - x0, y1 - y0
    n = math.hypot(tx, ty) or 1.0
    nx, ny = -ty / n * w / 2, tx / n * w / 2
    return [(x0, y0, ends), (xm + nx, ym + ny), (x1, y1, ends), (xm - nx, ym - ny)]


def rig_mouth(fr: FaceRig, host: El, palette: Mapping[str, str]) -> El:
    """Build the continuous mouth inside `host` (a Node at MOUTH_FRAME, x = y = 0).

    The opening (`MouthInside`, one flat dark colour, the clip source) and its outline (`MouthLine`)
    share one skin. Inside it: the upper teeth hang from the skull (static, one smooth arc for an
    edge), the lower teeth ride the jaw only, and a soft tongue dome rides the jaw. Over it: the
    pucker's lip cushion (pushed lips around a smaller opening, behind it),
    the lip tuck's lower-lip band (f, v: a pink band whose top edge meets the upper teeth's edge),
    the smile creases and the tense creases (press + stretch: the squared angry mouth)."""
    F = MOUTH_FRAME
    bones: dict[str, tuple[tuple[float, float], El]] = {}
    for nm, ((x, y), dx, dy) in mouth_bones().items():
        bones[nm] = ((x, y), fr.bone("Mouth" + nm, (x - F[0], y - F[1]), dx, dy))

    def at(n: str) -> tuple[float, float]:
        return bones[n][0]

    one = lambda n: {n: 1.0}  # noqa: E731
    # inside: corners slightly rounded, lips smooth with long handles (round U / D openings); at rest
    # upper == lower, so the outline is the closed mouth line
    order = ["CornerL", "UpperL", "UpperC", "UpperR", "CornerR", "LowerR", "LowerC", "LowerL"]
    pts = [(*at(n), "c2") if n.startswith("Corner") else at(n) for n in order]
    hw = lip_handle_bones(fr, bones, order, F)

    def lip_shape(name: str, paint: El) -> El:
        return fr.skinned(name, pts, [one(n) for n in order], bones, F, paint, tension=LIP_TENSION, handles=hw)

    inside = lip_shape("MouthInside", fr.fill(palette["inside"]))
    line = fr.stroke(palette["ink"], 2.7)
    # pressed lips read as a firmer line; pushed lips thin it (the lips' cushion carries the shape)
    fr.bind_on(line, "thickness", 2.7, terms(R=1.3, K=-0.9))
    outline = lip_shape("MouthLine", line)
    # ... and soften it toward a lip shadow, so the opening reads as one dark hole in the lips
    fr.bind_on(outline, "opacity", 1.15, terms(K=-0.75), lo=0.0, hi=1.0)
    # rounded lips round the mouth's corners (an oh is an oval, not a box); the tense mouth squares them
    for shape in (inside, outline):
        path = next(c for c in shape.children if c.tag == "PointsPath")
        for v in path.children:
            if v.tag == "StraightVertex":
                v.children.insert(0, fr.bind("radius", 2.0, terms(K=9.0, TS=-2.0), lo=0.0))
    # pushed lips (o, u, w, ch): a lip cushion around the opening, behind it (the hole stays dark),
    # pinched at the corners, fuller below, with a shine on the lower lip
    lips = fr.skinned("PuckerLips",
                      [(380.5, 477.0, "c4"), (390.0, 474.2), (400.0, 475.4), (410.0, 474.2), (419.5, 477.0, "c4"),
                       (410.5, 486.8), (400.0, 489.6), (389.5, 486.8)],
                      [one("CornerL"), one("UpperL"), one("UpperC"), one("UpperR"), one("CornerR"), one("LowerR"),
                       one("LowerC"), one("LowerL")], bones, F, fr.stroke(palette["lip_edge"], 1.4),
                      fr.fill(palette["lip_band"]))
    shine = fr.skinned("PuckerShine", [(396.5, 485.9), (400.0, 486.5), (403.5, 485.9)],
                       [one("LowerC")] * 3, bones, F, fr.stroke(palette["shine"], 1.6),
                       closed=False)
    for sh in (lips, shine):
        fr.bind_on(sh, "opacity", -0.3, terms(K=2.5), lo=0.0, hi=1.0)
    # the upper teeth: static, their edge one arc (no notch, whatever the lips do)
    ex = [366.0, 383.0, 400.0, 417.0, 434.0]
    tpts = [(366.0, 455.0, "c"), (434.0, 455.0, "c"),
            *[(x, teeth_edge_y(x), "c" if k in (0, 4) else "") for k, x in enumerate(reversed(ex))]]
    tpts = [p if p[2] else p[:2] for p in tpts]
    ox, oy = 400.0, (455.0 + TEETH_EDGE[0]) / 2
    teeth = fr.d("Shape", fr.d("ClippingShape", sourceId=inside.ref(), name="Clip"),
                 smooth_path(fr.d, [(p[0] - ox, p[1] - oy, *p[2:]) for p in tpts]), fr.fill(palette["teeth"]),
                 x=ox - F[0], y=oy - F[1], name="MouthTeeth")
    # rounded lips (o, u, w) push forward over the teeth (a steep cut: half-faded teeth read as mauve)
    fr.bind_on(teeth, "opacity", 3.4, terms(K=-8.0), lo=0.0, hi=1.0)
    # the lower teeth ride the jaw, their top edge just behind the upper edge (teeth together)
    lpts = [(366.0, 506.0, "c"), (434.0, 506.0, "c"),
            *[(x, teeth_edge_y(x, LOW_TEETH_TOP), "c" if k in (0, 4) else "") for k, x in enumerate(reversed(ex))]]
    lpts = [p if p[2] else p[:2] for p in lpts]
    low_teeth = fr.skinned("MouthLowTeeth", lpts, [one("JawTeeth")] * len(lpts), bones, F,
                           fr.fill(palette["low_teeth"]), clip=inside)
    # lower teeth for a stretch (s, e, i), steeply (half-opaque teeth over the interior read as mauve)
    fr.bind_on(low_teeth, "opacity", -1.2, terms(S=4.0), lo=0.0, hi=1.0)
    # a soft tongue: a dome on the jaw, its tip rising to the teeth for th / l / d / n
    tongue = fr.skinned("MouthTongue", [(400.0, 483.0), (416.0, 491.0), (400.0, 500.0), (384.0, 491.0)],
                        [one("TongueTip"), {"LowerR": 0.5, "JawTeeth": 0.5}, {"LowerC": 0.5, "JawTeeth": 0.5},
                         {"LowerL": 0.5, "JawTeeth": 0.5}], bones, F, fr.fill(palette["tongue"]), clip=inside)
    lower_lip = fr.skinned("LowerLipShade", [(390.0, 486.0), (400.0, 488.5), (410.0, 486.0)],
                           [one("LowerL"), one("LowerC"), one("LowerR")], bones, F, fr.stroke(palette["lip"], 2.6),
                           closed=False)
    # the lip band and the pucker's cushion draw their own lower lip
    fr.bind_on(lower_lip, "opacity", 1.0, terms(T=-1.3, K=-1.3), lo=0.0, hi=1.0)
    # f / v: the lower lip tucks up under the upper teeth as a pink band; its top edge is the lower
    # lip line (on TEETH_EDGE at the f/v jaw) and covers the lower outline (no dark line between the
    # teeth and the lip), its soft bottom edge a lip shadow
    band = fr.skinned("LowerLipBand",
                      [(384.0, 477.4, "c3"), (400.0, 478.2), (416.0, 477.4, "c3"), (409.0, 485.4), (400.0, 487.4),
                       (391.0, 485.4)],
                      [{"CornerL": 0.45, "LowerL": 0.55}, one("LowerC"), {"CornerR": 0.45, "LowerR": 0.55},
                       one("LowerR"), one("LowerC"), one("LowerL")], bones, F, fr.fill(palette["lip_band"]))
    band_edge = fr.skinned("LowerLipBandEdge", [(389.0, 484.0), (400.0, 487.2), (411.0, 484.0)],
                           [one("LowerL"), one("LowerC"), one("LowerR")], bones, F,
                           fr.stroke(palette["lip_edge"], 1.6), closed=False)
    for sh in (band, band_edge):
        fr.bind_on(sh, "opacity", -0.25, terms(T=1.5), lo=0.0, hi=1.0)
    creases = []
    for side, c in (("L", "CornerL"), ("R", "CornerR")):
        x0, y0 = at(c)
        k = -1 if side == "L" else 1
        sh = fr.skinned("SmileCrease" + side, [(x0 + 4 * k, y0 - 5), (x0 + 6.5 * k, y0 - 1), (x0 + 5 * k, y0 + 3.5)],
                        [one(c)] * 3, bones, F, fr.stroke(palette["crease"], 1.8), closed=False)
        fr.bind_on(sh, "opacity", 0.0, sided(terms(DM=1.0, P=0.55, CR=0.2), side), lo=0.0, hi=1.0)
        creases.append(sh)
        # the tense mouth: a short tapered crease out and down from each corner (pressed, stretched lips)
        tk = fr.skinned("TenseCrease" + side,
                        tapered([(x0 + 2.6 * k, y0 + 1.2), (x0 + 4.4 * k, y0 + 3.8), (x0 + 4.6 * k, y0 + 6.8)], 1.5),
                        [one(c)] * 4, bones, F, fr.fill(palette["crease_tense"]))
        fr.bind_on(tk, "opacity", -0.1, terms(TS=1.2), lo=0.0, hi=0.85)
        creases.append(tk)
    group = fr.d("Node", *creases, band_edge, band, shine, lower_lip, outline, teeth, low_teeth, tongue, inside, lips,
                 *[b for _, b in bones.values()], x=0.0, y=0.0, name="FaceMouth")
    host.add(group)
    return group


# the nose wrinkle's two creases: centre lines (art space) from the bridge down and out
NOSE_CREASES = (((395.2, 412.5), (391.9, 416.6), (389.8, 421.8)), ((404.8, 412.5), (408.1, 416.6), (410.2, 421.8)))


def rig_nose(fr: FaceRig, nose_g: El, frame: tuple[float, float], palette: Mapping[str, str]) -> None:
    """Nose wrinkle: the nose lifts and shortens; two short tapered creases appear at the bridge."""
    pivot = (400.0 - frame[0], 452.0 - frame[1])
    kids = list(nose_g.children)
    inner = fr.d("Node", *kids, x=-pivot[0], y=-pivot[1], name="NoseAUPivot")
    outer = fr.d("Node", fr.bind("y", pivot[1], terms(NW=-2.5)), fr.bind("scaleY", 1.0, terms(NW=-0.12)),
                 inner, x=pivot[0], y=pivot[1], name="NoseAU")
    lines = []
    for k, c in enumerate(NOSE_CREASES):
        p = [(q[0] - frame[0], q[1] - frame[1], *q[2:]) for q in tapered(c, 2.2)]
        sh = fr.d("Shape", fr.bind("opacity", -0.05, terms(NW=2.2), lo=0.0, hi=1.0), smooth_path(fr.d, p),
                  fill(fr.d, palette["crease"]), x=0.0, y=0.0, name=f"NoseWrinkle{k}")
        lines.append(sh)
    nose_g.children = [*lines, outer]


def rig_cheeks(fr: FaceRig, parent: El, blooms: Sequence[El]) -> None:
    """Cheek raise lifts and swells the cheek bloom (`CheekBloomL` reads the viewer's-left sum)."""
    for b in blooms:
        x, y = float(b.attrs.get("x", 0.0)), float(b.attrs.get("y", 0.0))
        side = str(b.attrs.get("name"))[-1]
        assert side in "LR", b.attrs.get("name")
        fr.wrap(parent, b, (x, y), str(b.attrs.get("name")) + "AU",
                [(k, c0, sided(t, side)) for k, c0, t in
                 (("y", 0.0, terms(CR=-5.0)), ("scaleX", 1.0, terms(CR=0.12)), ("scaleY", 1.0, terms(CR=0.1)))])


def rig_body(fr: FaceRig, root: El, body: El, body_g: El, head_base: El,
             neck: tuple[float, float]) -> None:
    """`breath` lifts the body from the feet (root frame); `roll` tilts the head about the neck
    (`neck` in body_g's local frame)."""
    fr.wrap(root, body, (0.0, 0.0), "BreathLift",
            [("y", 0.0, {"breath": -2.5}), ("scaleY", 1.0, {"breath": 0.012}), ("scaleX", 1.0, {"breath": 0.004})])
    fr.wrap(body_g, head_base, neck, "HeadRoll",
            [("rotation", 0.0, {"roll": round(math.radians(6), 4)}), ("y", 0.0, {"breath": -1.5})])
