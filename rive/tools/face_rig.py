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

from art_bible import LINES
from head_turn import JAW_CONTOUR
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
Floor = "float | tuple[float, Terms] | None"  # a bind's lower clamp: a number or a formula (c0, terms)

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
#   FLARE                clamp01(4 min(pucker, stretch) - 0.5): pushed AND stretched lips (from a
#                        stretch ~0.13 up: round 3, a kk -> ou blend half-showed the teeth), the flared
#                        ch / sh funnel (a squarer opening with the teeth together behind it)
#   TUCK                 min(1, 3 lipTuck, 30 jaw): the f / v pose, full from lipTuck 0.33 at any jaw
#                        >= 0.033 (critic round 2: a lipTuck ramp read as p / b / m until its peak);
#                        a lip tuck on a closed jaw rolls the lips in instead (T - TUCK, <= 0 at f / v)
#   JOPEN                clamp01(10 jaw + 2.2 mouth - 10 lipTuck): the jaw's first tenth parts the lips
#                        at once (critic round 2: jaw 0.08 read as a closed line); a lip tuck keeps the
#                        lower lip under the f / v band instead
# (below, "jaw" is auJawDrop + 0.22 mouth, the jaw the art opens by)
#   KJ                   min(pucker, auJawDrop) (no legacy `mouth`: CONTRACT says write one or the
#                        other, and only the AU path writes pucker): rounded lips on an open jaw (oh, ou) arch the upper lip and
#                        bow the lower one, so the opening is an oval, not a cup (critic round 3)
#   PJ                   min(press, 2.5 jaw): a residual press on an open jaw (in-between frames): the
#                        pressed line's extra weight goes, the upper lip lifts off the teeth and the
#                        interior lightens (critic round 3: they read as a dark grimace blob)
#   TH                   clamp01(10 tongueUp - 7): th, the tongue tip out past the upper teeth's edge
#                        (tongueUp 0.8+; nn at 0.7 keeps it behind them)
#   RIMJ                 min(1, 3.1 jaw): the lip rim's share of the opening (full from jaw ~0.32)
PART = "@part"
TENSE = "@tense"
FLARE = "@flare"
TUCK = "@tuck"
JOPEN = "@jopen"
KJ = "@kj"
PJ = "@pj"
TH = "@th"
RIMJ = "@rimj"
TUCK_GAIN = 3.0
TUCK_JAW = 30.0
JOPEN_GAIN = 10.0
FLARE_GAIN, FLARE_FROM = 4.0, 0.5
PJ_GAIN = 2.5
TH_GAIN, TH_FROM = 10.0, 0.7
_SHORT.update(PT=PART, TS=TENSE, FL=FLARE, TK=TUCK, JO=JOPEN, KJ=KJ, PJ=PJ, TH=TH, RJ=RIMJ)


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
    if key == FLARE:
        return min(1.0, max(0.0, FLARE_GAIN * min(env.get("auLipPucker", 0.0), env.get("auLipStretch", 0.0))
                            - FLARE_FROM))
    if key == TUCK:
        return max(0.0, min(1.0, TUCK_GAIN * env.get("lipTuck", 0.0), TUCK_JAW * env.get("auJawDrop", 0.0)))
    jaw = env.get("auJawDrop", 0.0) + JAW_PER_MOUTH * env.get("mouth", 0.0)
    if key == JOPEN:
        return min(1.0, max(0.0, JOPEN_GAIN * (jaw - env.get("lipTuck", 0.0))))
    if key == KJ:
        return min(env.get("auLipPucker", 0.0), env.get("auJawDrop", 0.0))
    if key == PJ:
        return min(env.get("auLipPress", 0.0), PJ_GAIN * jaw)
    if key == TH:
        return min(1.0, max(0.0, TH_GAIN * (env.get("tongueUp", 0.0) - TH_FROM)))
    if key == RIMJ:
        return min(1.0, RIMJ_GAIN * jaw)
    return env.get(key, 0.0)


def base_prop(key: str) -> str:
    """The view-model number a term key's formula reads first (a bind's source path)."""
    if "|" in key:
        return key.split("|")[0]
    return {PART: "auLipStretch", TENSE: "auLipPress", FLARE: "auLipPucker", TUCK: "lipTuck",
            JOPEN: "auJawDrop", KJ: "auLipPucker", PJ: "auLipPress", TH: "tongueUp",
            RIMJ: "auJawDrop"}.get(key, key)


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
    # critic round 2: raise travel 1.5x (surprise must read); AU2 lifts the middle almost as much as
    # the outer end, so a raised brow arches instead of tilting
    "Inner": (-26.0, 341.0, terms(BL=4.5, IU=0.5), terms(IU=-27.0, OU=-6.0, BL=13.0)),
    "Mid": (4.0, 337.0, terms(BL=1.5), terms(IU=-10.5, OU=-21.0, BL=5.0)),
    # AU1 alone tilts the brow (outer end a touch down): the oblique sad brow
    "Outer": (32.0, 342.0, terms(OU=-1.5), terms(IU=3.0, OU=-24.0, BL=-4.0)),
}

MOUTH_FRAME = (400.0, 478.0)
# Mouth bones: rest (x, y) for the RIGHT side / centre; dx terms are toward the viewer's right for the
# right side (mirrored for the left); dy terms are screen y. Sided AUs (corner pull / depress, cheek
# raise) read the side's clamped sum; the centre reads half of each side (`mouth_bones`).
MOUTH_BONES = {
    # TS (the squared angry mouth): the corners turn down and out, sharp, under a flat lip line
    # R (p, b, m): the pressed line flattens (corners down, middles up) and the corners come in
    # T - TK (a lip tuck on a closed jaw): the lips roll in to a thin flat line, the corners come in
    # K (o, u, w): the corners sit at the round opening's middle height, not on its top (round 3:
    # a cup); DM: the corner sinks back into its dimple; NW: the sneer lifts the corners a little
    "CornerR": ((417.0, 477.0), terms(P=5.0, S=9.5, J=3.0, K=-7.6, R=-4.5, DM=3.0, D=1.0, TS=1.5, T=-2.5, TK=2.5),
                terms(P=-7.0, D=8.5, CR=-1.5, J=8.0, S=2.0, DM=-1.0, TS=4.5, R=1.6, K=3.5, KJ=10.0, NW=-1.0)),
    # closed-mouth terms (corners, smile, frown, dimpler, press, tension) move the upper and lower
    # lips together so a closed mouth stays one line; jaw, pucker, nose wrinkle, lip tuck and the
    # stretch's lip part (PT, sealed again by press) open it. JO: the jaw's first tenth drops the lower
    # lip (a dark gap at jaw 0.08); TK (f, v): the upper lip lifts off the teeth and the lower lip drops
    # a little under the tuck band, so the opening reaches under the band's top edge at any jaw.
    # KJ (oh, ou): the side columns sit on an oval through the centre and the corners (round 3: a
    # flat top and bottom read as a box); NW: the sneer lifts the upper lip ~4 art px
    "UpperR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0, TS=4.0, R=-2.0),
               terms(P=0.3, D=2.0, J=-2.5, NW=-3.2, TK=-2.4, K=-0.4, KJ=3.5, PT=-2.2, R=0.3, T=-0.6)),
    "UpperC": ((400.0, 480.0), terms(), terms(P=2.0, D=-1.0, J=-3.5, NW=-4.2, TK=-2.6, K=-2.6, PT=-3.0,
                                              R=-0.9, T=-1.2)),
    "LowerR": ((410.5, 479.0), terms(P=3.0, S=4.0, J=2.0, K=-5.0, TS=4.0, R=-2.0),
               terms(P=0.3, D=2.0, J=16.6, JO=4.3, K=3.7, KJ=3.5, TK=1.9, PT=5.5, R=0.3, TU=2.0, T=-0.6)),
    "LowerC": ((400.0, 480.0), terms(), terms(P=2.0, D=-1.0, J=20.0, JO=5.5, K=3.4, TK=2.8, PT=7.0, R=-0.9, TU=2.6,
                                              T=-1.2)),
}
# The upper teeth hang from the skull (they do not move): their edge is one arc, y = TEETH_EDGE[0] -
# TEETH_EDGE[1] (x - 400)^2. The lower teeth ride the jaw only (`JawTeeth`), just behind that edge.
TEETH_EDGE = (482.8, 0.0104)
LOW_TEETH_RAMP = (0.28, 0.38)  # lipStretch: lower teeth hidden .. fully shown
LOW_TEETH_TOP = (482.2, 0.0104)
JAW_TEETH = 17.0  # px per unit jaw (the lower lip takes 23)
# the tongue tip rises to the back of the upper teeth and stops just under their edge, so it reads
# (a pink tip under the white) from tongueUp ~0.5 at any jaw, not only at 1
# (it rests low: a jaw 0.08 gap shows the dark mouth, not the tongue)
TONGUE_TIP = (486.0, 13.8, -25.0)  # rest y, px per unit jaw, px per unit tongueUp
TONGUE_STOP = TEETH_EDGE[0] + 1.0
# critic round 3: the tongue is a broad mound whose top is always a convex arc (a raised tip alone
# made an "M" with two dark triangles beside it): its shoulders rise with the tip, 64 % as far, and
# stop TONGUE_SHOULDER_DROP under it; its base rides the jaw beyond the mouth's corners
TONGUE_SHOULDER = (14.0, 489.5, -16.0)  # dx from the centre, rest y, px per unit tongueUp
TONGUE_SHOULDER_DROP = 2.6
# th: the tongue paints over the upper teeth (under their edge it covers only the interior), and TH
# (tongueUp 0.7 -> 0.8) lowers the tip's floor TH_LIFT past their edge: the tip between the teeth;
# nn (0.7) keeps it behind them
TH_LIFT = 3.6
TH_SHOULDER = 2.0  # the shoulders follow the th tip part way (a round tip, still under the teeth's edge)


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
    # (clamped at TONGUE_STOP: BONE_LO)
    y0, kj, ku = TONGUE_TIP
    out["TongueTip"] = ((400.0, y0), {}, {**{p: kj * c for p, c in jaw.items()}, "tongueUp": ku})
    u, ys, ks = TONGUE_SHOULDER
    for side, k in (("L", -1), ("R", 1)):
        out["TongueSide" + side] = ((400.0 + k * u, ys), {}, {**{p: kj * c for p, c in jaw.items()}, "tongueUp": ks})
    return out


# art-space y floor of a bone (a max() in its formula)
SHOULDER_LO = (TONGUE_STOP + TONGUE_SHOULDER_DROP, {TH: -TH_SHOULDER})
BONE_LO: dict[str, float | tuple[float, Terms]] = {"TongueTip": (TONGUE_STOP, {TH: -TH_LIFT}),
                                                  "TongueSideL": SHOULDER_LO, "TongueSideR": SHOULDER_LO}


def mouth_pose(env: Mapping[str, float]) -> dict[str, tuple[float, float]]:
    """Predicted art-space position of every mouth bone (tests, review overlays)."""
    return {n: (x + evaluate(0.0, dx, env), max(bone_floor(n, env), y + evaluate(0.0, dy, env)))
            for n, ((x, y), dx, dy) in mouth_bones().items()}


def bone_floor(n: str, env: Mapping[str, float]) -> float:
    lo = BONE_LO.get(n, -1e9)
    return evaluate(lo[0], lo[1], env) if isinstance(lo, tuple) else lo


# ------------------------------------------------------------------ the rig

class FaceRig:
    def __init__(self, path: Callable[[str], str], start: int = ID_START) -> None:
        self.d = Doc(client=0, start=start)
        self.path = path
        self.f = Formulas(self.d, path)
        self.converters: list[El] = []
        self._conv: dict[tuple[object, ...], El] = {}

    # ---- binds
    def converter(self, c0: float, t: Terms, lo: "Floor" = None, hi: float | None = None) -> tuple[str, El]:
        """Formula c0 + sum c_i [p_i], optionally clamped (`lo` a number, or a (c0, terms) formula
        of its own); returns (source prop, converter)."""
        items = sorted((p, round(c, 3)) for p, c in t.items() if round(c, 3))
        lo_items = sorted((p, round(c, 3)) for p, c in lo[1].items()) if isinstance(lo, tuple) else None
        key = (round(c0, 3), tuple(items), lo if lo_items is None else (round(lo[0], 3), tuple(lo_items)), hi)  # type: ignore[index]
        src = base_prop(items[0][0]) if items else "auJawDrop"
        if key not in self._conv:
            f = self.f

            def linear(k0: float, its: Sequence[tuple[str, float]]) -> list[El]:
                out: list[El] = [f.val(k0)]
                for p, c in its:
                    out += [f.op("+"), f.val(c), f.op("*"), *self.amount(p, src)]
                return out

            expr = linear(c0, items)
            if hi is not None:
                expr = f.fn("min", [f.val(hi)], expr)
            if lo_items is not None:
                expr = f.fn("max", linear(lo[0], lo_items), expr)  # type: ignore[index]
            elif lo is not None:
                expr = f.fn("max", [f.val(lo)], expr)  # type: ignore[arg-type]
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
        if key == TUCK:
            return f.fn("min", [f.val(1)], f.fn("min", [f.val(TUCK_GAIN), f.op("*"), *ref("lipTuck")],
                                                [f.val(TUCK_JAW), f.op("*"), *ref("auJawDrop")]))
        if key == JOPEN:
            g = JOPEN_GAIN
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [
                f.val(g), f.op("*"), *ref("auJawDrop"), f.op("+"), f.val(g * JAW_PER_MOUTH), f.op("*"), *ref("mouth"),
                f.op("-"), f.val(g), f.op("*"), *ref("lipTuck")]))
        def jaw(k: float) -> list[El]:  # k (jaw + 0.22 mouth)
            return [f.val(k), f.op("*"), *ref("auJawDrop"), f.op("+"), f.val(k * JAW_PER_MOUTH), f.op("*"),
                    *ref("mouth")]

        if key == KJ:
            return f.fn("min", ref("auLipPucker"), ref("auJawDrop"))
        if key == PJ:
            return f.fn("min", ref("auLipPress"), jaw(PJ_GAIN))
        if key == TH:
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(TH_GAIN), f.op("*"), *ref("tongueUp"),
                                                                  f.op("-"), f.val(TH_GAIN * TH_FROM)]))
        if key == RIMJ:
            return f.fn("min", [f.val(1)], jaw(RIMJ_GAIN))
        if key == TENSE:
            return f.fn("min", [f.val(1)], [f.val(2.5), f.op("*"), *f.fn("min", ref("auLipPress"), ref("auLipStretch"))])
        if key == FLARE:
            return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [
                f.val(FLARE_GAIN), f.op("*"), *f.fn("min", ref("auLipPucker"), ref("auLipStretch")), f.op("-"),
                f.val(FLARE_FROM)]))
        return ref(key)

    def bind(self, key: str, c0: float, t: Terms, lo: "Floor" = None, hi: float | None = None) -> El:
        src, conv = self.converter(c0, t, lo, hi)
        return self.d("DataBindContext", sourcePathIds=self.path(src), propertyKey=KEYS[key],
                      converterId=conv.ref())

    def bind_on(self, el: El, key: str, c0: float, t: Terms, lo: "Floor" = None,
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
    def bone(self, name: str, local: tuple[float, float], dx: Terms, dy: Terms, lo_y: "Floor" = None) -> El:
        binds = [*([self.bind("boneX", local[0], dx)] if dx else []),
                 *([self.bind("boneY", local[1], dy, lo=lo_y)] if dy or lo_y is not None else [])]
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


def rig_brow(fr: FaceRig, brow_g: El, shape: El, cx: float, s: int, color: str, outline: str | None = None) -> None:
    """Skin the brow shape to inner / mid / outer bones (bones live in BrowG, frame (cx, 346)). The
    brows paint under the fringe (M3), so they need no outline; `outline` adds a thin one."""
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

    paints = ([fr.stroke(outline, 2.4)] if outline else []) + [fr.fill(color)]
    new = fr.skinned("BrowShape", pts, [w(p[0]) for p in pts], bones, frame, *paints)
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

# dy per AU (+ = down). Upper: AU5 lifts it clear of the iris (critic round 2: sclera shows above
# the iris at 1), AU7 lowers it a little, AU1 drops the outer end (sad droop; AU2 takes it back so
# the surprise pose stays open), AU4 drops the inner end (anger); AU6 leaves it at rest and lifts its
# middle a touch (critic round 2: a smile pushes the lower lid up, it never drops the upper one into
# bedroom eyes); looking down drops it.
UPPER_LID: dict[str, dict[str, float]] = {
    "Inner": {**terms(UL=-6.5, LT=2.0, BL=9.0, CR=0.5), DOWN: 8.0},
    "Mid": {**terms(UL=-9.0, LT=2.5, IU=2.5, OU=-1.5, BL=3.5, CR=-1.0), DOWN: 9.5},
    "Outer": {**terms(UL=-7.5, LT=2.0, IU=11.0, OU=-8.0, BL=0.5, CR=0.3), DOWN: 8.5},
}
# Lower: AU7 lifts it; AU6 lifts the middle more than the ends, so the line bows up into a smile
# crescent over the lower iris, by at most CHEEK_RAISE_MAX of the eye's height (critic round 1: a
# full cheek raise had closed the eye, a wink); AU5 lets it down a little (a surprised eye shows
# white below).
CHEEK_RAISE_MAX = 0.4
LOWER_LID: dict[str, dict[str, float]] = {
    "Inner": terms(UL=1.2, LT=-4.0, CR=-10.0),
    "Mid": terms(UL=1.8, LT=-6.0, CR=-12.5),
    "Outer": terms(UL=1.2, LT=-5.0, CR=-10.5),
}
# The corners never move in a blink; AU7 pulls them in a touch, AU6 lowers them a little (the lower
# lid's ends: with its capped push it then arches over the iris instead of rising flat; less than
# M3's 2.5 px, which dragged the upper lid's ends down with them).
CORNER_LID: dict[str, dict[str, float]] = {"In": terms(LT=-1.0, CR=1.7), "Out": terms(LT=-1.0, CR=1.7)}
LASH_T: dict[str, float] = {"In": 0.7, "Inner": 2.6, "Mid": 3.8, "Outer": 4.6}  # lash thickness (px)
LASH_IN_BACK = 2.0  # u the lash's inner top point sits inside the corner (a tapered end)
WING = (35.0, 384.5)  # the lash's outer flick (u, y)
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
    # critic round 3: the inner end tapers to the legibility floor (a closed lid's line ended square
    # there), its top point set back along the line so the end is a point, not a cut
    lash_pts = [*lash_bottom, {"at": at(WING[0], WING[1]), "w": out_w}, {"at": at(29.5, 383.0), "w": out_w}, *tops,
                {"at": at(in_u + LASH_IN_BACK, in_y + SEAM - LASH_T["In"]), "w": [{"CornerIn": 1.0}]}]
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
    # (critic round 3: `rig_crease` replaces this stroke with a tapered band minted later; this
    # one keeps its id count, so no later lid id moves)
    crease: El = eye["crease"]  # type: ignore[assignment]
    cpts = [at(-12.0, 354.0), at(8.0, 350.0), at(32.0, 357.5)]
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


# A closing lid squashes the eyeball toward the lower lid (critic round 1: mid-blink, the bare
# sliver of iris under the lid read as two brown tabs with cut sides, like teeth): GazeM sits in a
# `BlinkSquash` node pivoting on the lower lid line, whose scaleY the blink animations key with the
# BlinkDrive strength (blink_squash(strength)), so a partly closed eye shows the rounded bottom of a
# flattened iris (a curved edge), not a slice through the middle of a round one.
BLINK_SQUASH = 0.5  # scaleY lost at strength 1
BLINK_SQUASH_Y = 404.0  # art-space pivot: the lower lid line


def blink_squash(strength: float) -> float:
    return round(1.0 - BLINK_SQUASH * strength, 4)


def add_blink_squash(fr: "FaceRig", eye: Mapping[str, object]) -> El:
    """Wrap the eye's GazeM (keyed by the gaze layers: its id and transform stay) in the squash node
    (identity at rest). Minted after both eyes' lid rigs, so no BlinkDrive id moves."""
    d = fr.d
    blink: El = eye["blink"].el  # type: ignore[attr-defined]
    gm: El = eye["gm"].el  # type: ignore[attr-defined]
    dy = BLINK_SQUASH_Y - EYE_FRAME_DY
    inner = d("Node", gm, x=0.0, y=-dy, name="BlinkSquashPivot")
    outer = d("Node", inner, x=0.0, y=dy, name="BlinkSquash")
    blink.children[blink.children.index(gm)] = outer
    return outer


# The lid crease (critic round 3): at rest the fold above each eye read as forehead wrinkles and
# added lines between the brows and the glasses, so it is hidden until the brows lift: opacity
# clamp01((max(inner up, outer up) - CREASE_FADE[0]) / (CREASE_FADE[1] - CREASE_FADE[0])) per side
# (the v6 side sums). It is a band tapering to the legibility floor at both ends (no round-capped
# stroke), and it no longer rides the upper lid: a closing lid dragged it onto the lens's top rim.
CREASE_FADE = (0.35, 0.8)
CREASE_PTS = ((-12.0, 353.0), (8.0, 349.0), (32.0, 356.5))  # centre line (u, y), eye-local
CREASE_W = 1.5  # px at its middle (eye-local: the eye is drawn at 1.06)


def crease_opacity(env: Mapping[str, float], side: str) -> float:
    """The lid crease's opacity on one side ("L" / "R"): the bind's formula."""
    a = max(lid_amount(env, "auBrowInnerUp", side), lid_amount(env, "auBrowOuterUp", side))
    lo, hi = CREASE_FADE
    return min(1.0, max(0.0, (a - lo) / (hi - lo)))


def crease_band(cx: float, s: int) -> list[tuple]:
    """The crease band's outline (art space, eye frame units): `blunt` around CREASE_PTS."""
    return blunt([(cx + s * u, y) for u, y in CREASE_PTS], CREASE_W, END_W / 1.06)


def rig_crease(fr: "FaceRig", eye: Mapping[str, object], cx: float, s: int) -> El:
    """Replace the eye's crease stroke (its Shape id stays) with a tapered band, hidden at rest and
    fading in with the brow raise (`crease_opacity`). Minted from `fr` (the face rig's unkeyed
    range) after the lids, so no lid id moves. Returns the crease."""
    d, f = fr.d, fr.f
    side = "L" if s < 0 else "R"
    crease: El = eye["crease"]  # type: ignore[assignment]
    band = crease_band(cx, s)
    xs, ys = [q[0] for q in band], [q[1] for q in band]
    c = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
    path = smooth_path(d, [(round(q[0] - c[0], 3), round(q[1] - c[1], 3), *q[2:]) for q in band])
    paint = next(ch for ch in crease.children if ch.tag == "Stroke")
    colour = next(ch for ch in paint.children if ch.tag == "SolidColor").attrs["colorValue"]
    _reshape(crease, (cx, EYE_FRAME_DY), path, c, fill(d, str(colour)))
    amt = f.fn("max", fr.amount("auBrowInnerUp|" + side, "auBrowInnerUp"),
               fr.amount("auBrowOuterUp|" + side, "auBrowInnerUp"))
    lo, hi = CREASE_FADE
    g = 1.0 / (hi - lo)
    conv = d("DataConverterFormula", *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [
        f.val(g), f.op("*"), *amt, f.op("-"), f.val(g * lo)])))
    fr.converters.append(conv)
    crease.children.insert(0, d("DataBindContext", sourcePathIds=fr.path("auBrowInnerUp"), propertyKey=KEYS["opacity"],
                                converterId=conv.ref()))
    crease.attrs["opacity"] = 0.0
    return crease


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


LIP_TENSION = 1.0  # critic round 3: 1.3's long handles flattened the lips into a trapezoid
# Line weights (art bible §4: px on a 1080 frame, LINE_SCALE art px each; critic round 3: the mouth
# outline was as heavy as the chin's silhouette): the mouth contour is an interior line, the tuck line
# a detail line, and open strokes (creases, dimples, the lip shade) taper to the legibility floor
# The face's silhouette line (gen_avatar `Face`, 2.6 art px) is the bible's 5 px; the mouth's lines
# keep the bible's ratios to it (critic round 3 measured the old 2.7 px mouth line as heavy as the chin)
SILHOUETTE_ART = 2.6
PX = SILHOUETTE_ART / LINES.silhouette  # art px per bible px
MOUTH_INK = round(LINES.interior * PX, 2)  # 1.56 art px: 3 px
DETAIL_W = round(LINES.detail * PX, 2)  # 0.94: 1.8 px
END_W = round(LINES.min_visible * PX, 2)  # 0.73: 1.4 px
PRESS_INK = 1.0  # art px pressed lips (p, b, m) add to the line: as heavy as the silhouette, no more
# The mouth's corners are smooth vertices whose handles run straight up / down, as long as a share
# of the opening's height at that side (`corner_handles`): an open mouth has round ends at every
# jaw / pucker / stretch (critic round 3: near-sharp corners read as trapezoids); a closed mouth
# (no opening) keeps zero-length handles, the plain line end
CORNER_UP, CORNER_DOWN = 0.45, 0.4
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
    for i, n in enumerate(order):
        h = lip_handles(order).get(n)
        if h is None:
            # a handle bone rides its corner through a local, offset TranslationConstraint, so its own
            # formula is only the opening term (the same for both sides: one shared converter)
            names = []
            corner = bones[n][1]
            for tag, k in zip(("In", "Out"), corner_handles(n, order[i - 1])):
                name = f"Mouth{n}{tag}"
                el = fr.d("RootBone", fr.bind("boneY", 0.0, scale_terms(k, opening_terms("R"))),
                          fr.d("TranslationConstraint", targetId=corner.ref(), sourceSpaceValue="local",
                               destSpaceValue="local", offset=True, name="RideCorner"),
                          x=0.0, y=0.0, rotation=0.0, length=2.0, name=name)
                bones[name] = (bones[n][0], el)
                names.append(name)
            hw.append(({names[0]: 1.0}, {names[1]: 1.0}))
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


def opening_terms(side: str) -> dict[str, float]:
    """The opening's height at a side column (Lower - Upper dy): 0 for every closed-mouth pose."""
    b = mouth_bones()
    return add_terms((1.0, b["Lower" + side][2]), (-1.0, b["Upper" + side][2]))


def corner_handles(corner: str, prv: str) -> tuple[float, float]:
    """The opening-height factors of a corner's (in, out) handles: the handle toward the upper lip
    rises CORNER_UP x the opening's height off the corner, the other drops CORNER_DOWN x it."""
    return (-CORNER_UP, CORNER_DOWN) if prv.startswith("Upper") else (CORNER_DOWN, -CORNER_UP)


def scale_terms(k: float, t: Terms) -> dict[str, float]:
    return {p: k * c for p, c in t.items()}


def corner_handle_pose(env: Mapping[str, float], corner: str) -> tuple[Pt2, Pt2]:
    """Predicted (upper handle, lower handle) of a corner (tests)."""
    (x, y), dx, dy = mouth_bones()[corner]
    h = evaluate(0.0, opening_terms(corner[-1]), env)
    cx, cy = x + evaluate(0.0, dx, env), y + evaluate(0.0, dy, env)
    return (cx, cy - CORNER_UP * h), (cx, cy + CORNER_DOWN * h)


def tapered(c: Sequence[Pt2], w: float, ends: str = "c") -> list[tuple]:
    """A tapered stroke as a closed lens around the centre line p0 -> pm -> p1 (pointed ends, `w`
    wide at pm): open strokes taper (art bible §4)."""
    (x0, y0), (xm, ym), (x1, y1) = c
    tx, ty = x1 - x0, y1 - y0
    n = math.hypot(tx, ty) or 1.0
    nx, ny = -ty / n * w / 2, tx / n * w / 2
    return [(x0, y0, ends), (xm + nx, ym + ny), (x1, y1, ends), (xm - nx, ym - ny)]


def blunt(c: Sequence[Pt2], w: float, end: float = END_W) -> list[tuple]:
    """An open stroke as a closed band around the centre line p0 -> pm -> p1: `w` wide at pm,
    tapering to `end` (the legibility floor) at round-capped ends (art bible §4)."""
    (x0, y0), (xm, ym), (x1, y1) = c
    tx, ty = x1 - x0, y1 - y0
    n = math.hypot(tx, ty) or 1.0
    nx, ny = -ty / n, tx / n
    e, h = end / 2, w / 2
    cap = f"c{round(e, 2)}"
    return [(x0 + nx * e, y0 + ny * e, cap), (xm + nx * h, ym + ny * h), (x1 + nx * e, y1 + ny * e, cap),
            (x1 - nx * e, y1 - ny * e, cap), (xm - nx * h, ym - ny * h), (x0 - nx * e, y0 - ny * e, cap)]


BLUNT_W = ("L", "C", "R", "R", "C", "L")  # which centre-line point each blunt() vertex follows
DIMPLE_W = 2.4  # art px: the dimple's crescent at its widest (critic round 3: a 1.8 px dent was lost)


def DIMPLE_ARC(x0: float, y0: float, k: int) -> list[Pt2]:  # noqa: N802
    """The dimple's centre line beside a mouth corner (x0, y0); k -1 left, +1 right."""
    return [(x0 + 1.6 * k, y0 - 4.4), (x0 + 4.4 * k, y0 + 0.2), (x0 + 2.0 * k, y0 + 4.6)]


DIMPLE_POCKET = (1.4, 0.4, 3.4, 4.6)  # the corner pocket's shadow: dx, dy from the corner, width, height
ROLL_THIN = 0.45  # art px the mouth line loses when a lip tuck rolls the lips in (pressed lips gain 1.0)
RIM_PER_JAW = 13.0  # rim stroke px per unit jaw (the full rim from jaw ~0.32)
RIM_MAX = 2.1  # art px of lip rim from the jaw at most (aa)
RIMJ_GAIN = round(RIM_PER_JAW / (2 * RIM_MAX), 2)
RIM_PUCKER = 1.3  # art px of lip rim pucker adds (o, u, w: fuller lips; round 3: ou read as a dot)
LIFT_MAX = 0.55  # the residual-press interior lift's opacity at most
LIP_SHADE_REST = 0.6  # the lower-lip shade's opacity at rest (its colour carries a stronger alpha)
PUCKER_SHINE = ((396.5, 477.2), (400.0, 477.9), (403.5, 477.2))  # centre line, on the lower lip's rim
PUCKER_SHINE_W = 1.6
# the f / v band: its top edge runs from the mouth corners through the static tuck line, just over
# the upper teeth's edge (the teeth show above it whatever the jaw); its bottom edge rides the lower lip
TUCK_LINE = (400.0, 479.8)
BAND_RIDE = 0.6  # the band's bottom edge follows the lower lip this much (the rest: the tuck line)
BAND_PTS = [(383.0, 477.0, "c3"), TUCK_LINE, (417.0, 477.0, "c3"), (409.0, 484.6), (400.0, 486.0), (391.0, 484.6)]
BAND_EDGE_PTS = [(389.5, 483.4), (400.0, 484.8), (410.5, 483.4)]


def ride(n: str) -> dict[str, float]:
    return {n: BAND_RIDE, "TuckLine": 1.0 - BAND_RIDE}


def band_weights() -> list[dict[str, float]]:
    """Skin weights of BAND_PTS: the top corners on the mouth corners (no dark wedge beside them)."""
    return [{"CornerL": 1.0}, {"TuckLine": 1.0}, {"CornerR": 1.0},
            ride("LowerR"), ride("LowerC"), ride("LowerL")]


def band_pose(env: Mapping[str, float]) -> list[tuple[float, float]]:
    """Predicted art-space BAND_PTS (tests): each vertex moves by its weighted bones' offsets."""
    pose = mouth_pose(env)
    rest = {n: b[0] for n, b in mouth_bones().items()}
    out = []
    for p, w in zip(BAND_PTS, band_weights()):
        dx = sum(c * (pose[n][0] - rest[n][0]) for n, c in w.items() if n != "TuckLine")
        dy = sum(c * (pose[n][1] - rest[n][1]) for n, c in w.items() if n != "TuckLine")
        out.append((p[0] + dx, p[1] + dy))
    return out


def rig_mouth(fr: FaceRig, host: El, palette: Mapping[str, str]) -> El:
    """Build the continuous mouth inside `host` (a Node at MOUTH_FRAME, x = y = 0).

    The opening (`MouthInside`, one flat dark colour, the clip source) and its outline (`MouthLine`)
    share one skin; its corners are smooth vertices on vertical handle bones (round ends whenever it
    is open). Inside it: the upper teeth hang from the skull (static, one smooth arc for an edge), the
    lower teeth ride the jaw only, a residual-press lift (`MouthInsideLift`) lightens the interior,
    and a broad tongue mound rides the jaw, painted over the upper teeth so its th tip shows past
    their edge. Every open shape has one lip treatment, a lip-colour rim (`LipRim`) inside the ink
    line, fuller under pucker: no shape cross-fades a second set of lips over another (round lips are
    the opening's own shape: corners in and at mid height, rounded). Over it: the lip tuck's
    lower-lip band (f, v: a pink band whose top edge meets the upper teeth's edge, switched on hard),
    the chin fold (pressed or rolled-in lips), the smile creases, the dimples and the tense creases
    (press + stretch: the squared angry mouth), each a band tapering to the line floor."""
    F = MOUTH_FRAME
    bones: dict[str, tuple[tuple[float, float], El]] = {}
    for nm, ((x, y), dx, dy) in mouth_bones().items():
        b = BONE_LO.get(nm)
        lo = (b[0] - F[1], b[1]) if isinstance(b, tuple) else (b - F[1] if b is not None else None)
        bones[nm] = ((x, y), fr.bone("Mouth" + nm, (x - F[0], y - F[1]), dx, dy, lo_y=lo))

    def at(n: str) -> tuple[float, float]:
        return bones[n][0]

    one = lambda n: {n: 1.0}  # noqa: E731
    # inside: round corners (smooth vertices on vertical handle bones), lips smooth with long handles
    # (round U / D openings); at rest upper == lower, so the outline is the closed mouth line
    order = ["CornerL", "UpperL", "UpperC", "UpperR", "CornerR", "LowerR", "LowerC", "LowerL"]
    pts = [at(n) for n in order]
    hw = lip_handle_bones(fr, bones, order, F)

    def lip_shape(name: str, paint: El) -> El:
        sh = fr.skinned(name, pts, [one(n) for n in order], bones, F, paint, tension=LIP_TENSION, handles=hw)
        path = next(c for c in sh.children if c.tag == "PointsPath")
        for k, n in enumerate(order):  # a corner's handles rest on it (their bones open them)
            if n.startswith("Corner"):
                path.children[k].attrs.update(inDistance=0.0, outDistance=0.0)
        return sh

    inside = lip_shape("MouthInside", fr.fill(palette["inside"]))
    line = fr.stroke(palette["ink"], MOUTH_INK)
    # pressed lips (p, b, m) read as a firmer line, but only while the jaw is shut (PJ: an in-between
    # frame of a press and an open jaw is no grimace); lips rolled in (a tuck on a closed jaw: T - TK)
    # as a thinner one (critic round 2: the two read alike)
    fr.bind_on(line, "thickness", MOUTH_INK, terms(R=PRESS_INK, PJ=-PRESS_INK, T=-ROLL_THIN, TK=ROLL_THIN))
    outline = lip_shape("MouthLine", line)
    # every open shape has the same lips: a lip-colour rim inside the ink line (the inner half of a
    # stroke on the opening's own path, clipped by the opening). It grows with the opening (a jaw 0.08
    # gap stays dark, not lip-coloured) and with rounded lips pushed forward (o, u, w: fuller lips)
    rim_stroke = fr.stroke(palette["lip_rim"], MOUTH_INK)
    fr.bind_on(rim_stroke, "thickness", MOUTH_INK, terms(RJ=2 * RIM_MAX, K=2 * RIM_PUCKER))
    rim = lip_shape("LipRim", rim_stroke)
    rim.children.insert(0, fr.d("ClippingShape", sourceId=inside.ref(), name="Clip"))
    # a residual press on an open jaw lifts the interior (round 3: in-between frames read as a dark
    # grimace blob): a lighter wash over the dark, behind the rim, teeth and tongue
    lift = fr.d("Shape", fr.d("ClippingShape", sourceId=inside.ref(), name="Clip"),
                fr.d("Ellipse", width=72.0, height=52.0, name="Path"), fr.fill(palette["inside_lift"]),
                x=0.0, y=14.0, name="MouthInsideLift")
    fr.bind_on(lift, "opacity", -0.8, terms(PJ=4.0), lo=0.0, hi=LIFT_MAX)
    # the upper teeth: static, their edge one arc (no notch, whatever the lips do)
    ex = [366.0, 383.0, 400.0, 417.0, 434.0]
    tpts = [(366.0, 455.0, "c"), (434.0, 455.0, "c"),
            *[(x, teeth_edge_y(x), "c" if k in (0, 4) else "") for k, x in enumerate(reversed(ex))]]
    tpts = [p if p[2] else p[:2] for p in tpts]
    ox, oy = 400.0, (455.0 + TEETH_EDGE[0]) / 2
    teeth = fr.d("Shape", fr.d("ClippingShape", sourceId=inside.ref(), name="Clip"),
                 smooth_path(fr.d, [(p[0] - ox, p[1] - oy, *p[2:]) for p in tpts]), fr.fill(palette["teeth"]),
                 x=ox - F[0], y=oy - F[1], name="MouthTeeth")
    # rounded lips (o, u, w) push forward over the teeth (a steep cut: half-faded teeth read as mauve);
    # the flared ch / sh funnel shows them again
    fr.bind_on(teeth, "opacity", 3.4, terms(K=-8.0, FL=10.0), lo=0.0, hi=1.0)
    # the lower teeth ride the jaw, their top edge just behind the upper edge (teeth together)
    lpts = [(366.0, 506.0, "c"), (434.0, 506.0, "c"),
            *[(x, teeth_edge_y(x, LOW_TEETH_TOP), "c" if k in (0, 4) else "") for k, x in enumerate(reversed(ex))]]
    lpts = [p if p[2] else p[:2] for p in lpts]
    low_teeth = fr.skinned("MouthLowTeeth", lpts, [one("JawTeeth")] * len(lpts), bones, F,
                           fr.fill(palette["low_teeth"]), clip=inside)
    # lower teeth for a stretch (s, e, i) and the flared ch / sh funnel, steeply (half-opaque teeth
    # over the interior read as mauve; critic round 3: ih at stretch 0.45 still showed them at 65 %):
    # hidden up to stretch LOW_TEETH_RAMP[0], full from LOW_TEETH_RAMP[1] (dd 0.2 none, ih 0.45 full)
    lo_s, hi_s = LOW_TEETH_RAMP
    fr.bind_on(low_teeth, "opacity", -lo_s / (hi_s - lo_s), terms(S=1 / (hi_s - lo_s), FL=3.0), lo=0.0, hi=1.0)
    # a soft tongue: a broad mound on the jaw whose shoulders rise with its tip (a convex top at any
    # tongueUp, no peak), its base past the corners (critic round 3: a raised tip made an "M")
    u = TONGUE_SHOULDER[0]
    base = lambda n: {n: 0.5, "JawTeeth": 0.5}  # noqa: E731
    tw = [base("LowerL"), one("TongueSideL"), one("TongueTip"), one("TongueSideR"), base("LowerR"), base("LowerC")]
    tongue = fr.skinned("MouthTongue", [(400.0 - 2 * u, 498.0), (400.0 - u, TONGUE_SHOULDER[1]), (400.0, 486.0),
                                        (400.0 + u, TONGUE_SHOULDER[1]), (400.0 + 2 * u, 498.0), (400.0, 507.0)],
                        tw, bones, F, fr.fill(palette["tongue"]), clip=inside,
                        handles=[(w, w) for w in tw])  # rigid handles: a raised tip keeps its flat top (no peak)
    lower_lip = fr.skinned("LowerLipShade", blunt([(390.0, 486.0), (400.0, 488.5), (410.0, 486.0)], 2.6),
                           [one("Lower" + c) for c in BLUNT_W], bones, F, fr.fill(palette["lip"]))
    # the closed mouth's lip shadow (the only mark under the mouth at rest): once the jaw opens it
    # would be a second lower lip under the opening, and the lip band draws its own lower lip; a lip
    # tuck (rolled in or f / v) hides it at once, pressed lips mostly, rounded lips too (pulled in
    # with the lower lip it read as a chin crease under ou)
    fr.bind_on(lower_lip, "opacity", LIP_SHADE_REST, terms(T=-4.0, J=-2.1, K=-1.5, R=-0.5), lo=0.0, hi=1.0)
    # rounded lips (o, u, w) push the lower lip forward: a small highlight on its inner rim, inside
    # the opening (critic round 2: ou read flat)
    shine = fr.skinned("LowerLipGloss", tapered(PUCKER_SHINE, PUCKER_SHINE_W), [one("LowerC")] * 4, bones, F,
                       fr.fill(palette["shine"]), clip=inside)
    fr.bind_on(shine, "opacity", -0.6, terms(K=1.6), lo=0.0, hi=1.0)
    # pressed or rolled-in lips push the chin up: a fold under the lower lip (critic round 3: the
    # rolled-in tuck must show it at phone size)
    bulge = fr.skinned("ChinBulge", blunt([(388.0, 492.0), (400.0, 495.8), (412.0, 492.0)], 2.4),
                       [one("Lower" + c) for c in BLUNT_W], bones, F, fr.fill(palette["bulge"]))
    fr.bind_on(bulge, "opacity", -0.45, terms(R=2.2, T=2.0, TK=-2.0), lo=0.0, hi=1.0)
    # f / v: the lower lip tucks up under the upper teeth as a pink band. Its top edge is the tuck
    # line (`TUCK_LINE`, a static bone just over the upper teeth's edge, so the teeth show above it
    # whatever the jaw), its bottom edge rides the lower lip (BAND_RIDE) and covers the lower outline
    # (no dark line between the teeth and the lip), with a soft lip shadow along it
    bones["TuckLine"] = (TUCK_LINE, fr.d("RootBone", x=TUCK_LINE[0] - F[0], y=TUCK_LINE[1] - F[1], rotation=0.0,
                                         length=2.0, name="MouthTuckLine"))
    band = fr.skinned("LowerLipBand", BAND_PTS, band_weights(), bones, F, fr.fill(palette["lip_band"]))
    band_edge = fr.skinned("LowerLipBandEdge", BAND_EDGE_PTS, [ride(n) for n in ("LowerL", "LowerC", "LowerR")],
                           bones, F, fr.stroke(palette["lip_edge"], DETAIL_W), closed=False)
    # a quick switch (TK 0.3 -> 0.55, lipTuck 0.1 -> 0.18): a half-faded band over the open mouth
    # reads as a second lip; only with the jaw a hair open (TK): a lip tuck alone rolls the lips in
    for sh in (band, band_edge):
        fr.bind_on(sh, "opacity", -1.2, terms(TK=4.0), lo=0.0, hi=1.0)
    creases = []
    for side, c in (("L", "CornerL"), ("R", "CornerR")):
        x0, y0 = at(c)
        k = -1 if side == "L" else 1
        sh = fr.skinned("SmileCrease" + side,
                        blunt([(x0 + 4 * k, y0 - 5), (x0 + 6.5 * k, y0 - 1), (x0 + 5 * k, y0 + 3.5)], 1.4),
                        [one(c)] * 6, bones, F, fr.fill(palette["crease"]))
        fr.bind_on(sh, "opacity", 0.0, sided(terms(DM=0.4, P=0.55, CR=0.2), side), lo=0.0, hi=1.0)
        creases.append(sh)
        # the dimpler (AU14): the corner sinks into a pocket (a soft shadow) under a crescent just
        # outside it (critic round 3: the 1.8 px dent was barely visible)
        dm = fr.skinned("Dimple" + side, blunt(DIMPLE_ARC(x0, y0, k), DIMPLE_W), [one(c)] * 6, bones, F,
                        fr.fill(palette["dimple"]))
        px, py, pw, ph = DIMPLE_POCKET
        pocket = fr.skinned("DimplePocket" + side, [(x0 + (px - pw / 2) * k, y0 + py), (x0 + px * k, y0 + py - ph / 2),
                                                    (x0 + (px + pw / 2) * k, y0 + py), (x0 + px * k, y0 + py + ph / 2)],
                            [one(c)] * 4, bones, F, fr.fill(palette["pocket"]))
        for e in (dm, pocket):
            fr.bind_on(e, "opacity", -0.1, terms(DM=1.4), lo=0.0, hi=1.0)
        creases += [dm, pocket]
        # the tense mouth: a short tapered crease out and down from each corner (pressed, stretched lips)
        tk = fr.skinned("TenseCrease" + side,
                        blunt([(x0 + 2.6 * k, y0 + 1.2), (x0 + 4.4 * k, y0 + 3.8), (x0 + 4.6 * k, y0 + 6.8)], 1.4),
                        [one(c)] * 6, bones, F, fr.fill(palette["crease_tense"]))
        fr.bind_on(tk, "opacity", -0.1, terms(TS=1.2), lo=0.0, hi=0.85)
        creases.append(tk)
    # the lower teeth paint over the tongue (s: it rests behind them), the tongue over the upper teeth
    # (th: its tip out past their edge)
    group = fr.d("Node", *creases, band_edge, band, bulge, lower_lip, outline, shine, low_teeth, tongue, teeth,
                 rim, lift, inside, *[b for _, b in bones.values()], x=0.0, y=0.0, name="FaceMouth")
    host.add(group)
    return group


# the nose wrinkle's creases (AU9; critic round 3: three faint ones read as a nose bump): one across
# the bridge and two bunny lines down and out on each side of it, the upper pair from beside the
# glasses' bridge; centre lines in art space, each a NOSE_CREASE_W band tapering to the line floor
NOSE_CREASES = (((395.0, 413.6), (400.5, 412.2), (406.0, 413.6)),
                ((394.4, 416.4), (391.0, 419.8), (388.8, 424.6)), ((406.6, 416.4), (410.0, 419.8), (412.2, 424.6)),
                ((396.2, 404.0), (393.4, 407.6), (391.4, 412.2)), ((404.8, 404.0), (407.6, 407.6), (409.6, 412.2)))
NOSE_CREASE_W = 1.8


def rig_nose(fr: FaceRig, nose_g: El, frame: tuple[float, float], palette: Mapping[str, str]) -> None:
    """Nose wrinkle: the nose lifts and shortens; short tapered creases appear on the bridge (the
    upper lip lifts with it: MOUTH_BONES)."""
    pivot = (400.0 - frame[0], 452.0 - frame[1])
    kids = list(nose_g.children)
    inner = fr.d("Node", *kids, x=-pivot[0], y=-pivot[1], name="NoseAUPivot")
    outer = fr.d("Node", fr.bind("y", pivot[1], terms(NW=-2.5)), fr.bind("scaleY", 1.0, terms(NW=-0.12)),
                 inner, x=pivot[0], y=pivot[1], name="NoseAU")
    lines = []
    for k, c in enumerate(NOSE_CREASES):
        p = [(q[0] - frame[0], q[1] - frame[1], *q[2:]) for q in blunt(c, NOSE_CREASE_W)]
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


# breath = 0..1 (an inhale): eased by smoothstep (the response starts and lands softly whatever the
# app's ramp), the body lifts and lengthens from the feet, the chest widens a touch and the shoulders
# rise a little further (toward the ears). The head rides the neck but does not stretch (it is
# scaled back about the neck) and sinks a little into the shoulders, so it rises ~60 % as far as
# the shoulders (critic round 2: it rose more than them and read as perking up, not inhaling).
BREATH_BODY = {"y": -2.0, "scaleY": 0.024, "scaleX": 0.005}  # per unit of eased breath (root frame)
BREATH_SHOULDER = -3.0  # px: both arm swings, on top of the body lift
BREATH_HEAD_SINK = 4.5  # px the head sinks back toward the neck (head frame, + = down)
SHOULDER_ABOVE_FEET = 375.0  # the hoodie's shoulder line (y 625 on the 1000 px artboard, feet at 1000)
ARM_ABOVE_FEET = 330.0  # the sleeve tops
NECK_ABOVE_FEET = 390.0  # the head's roll / breath pivot


def smoothstep(b: float) -> float:
    return b * b * (3 - 2 * b)


def breath_lift(b: float) -> tuple[float, float, float]:
    """(shoulder line, sleeve top, head) lift in artboard px at breath `b` (+ = up); the head is rigid
    (every head point rises as far as the neck, less the sink)."""
    e = smoothstep(b)
    body = -BREATH_BODY["y"] * e
    stretch = BREATH_BODY["scaleY"] * e
    return (body + stretch * SHOULDER_ABOVE_FEET, body + stretch * ARM_ABOVE_FEET - BREATH_SHOULDER * e,
            body + stretch * NECK_ABOVE_FEET - BREATH_HEAD_SINK * e)


def eased_breath(fr: FaceRig, key: str, c0: float, c: float) -> El:
    """Bind `key` to c0 + c * smoothstep(breath) (min(3, ...) only groups 3 - 2 b)."""
    f = fr.f
    conv = fr.d("DataConverterFormula", f.val(c0), f.op("+"), f.val(c), f.op("*"), *f.inp(), f.op("*"), *f.inp(),
                f.op("*"), *f.fn("min", [f.val(3)], [f.val(3), f.op("-"), f.val(2), f.op("*"), *f.inp()]))
    fr.converters.append(conv)
    return fr.d("DataBindContext", sourcePathIds=fr.path("breath"), propertyKey=KEYS[key], converterId=conv.ref())


def breath_wrap(fr: FaceRig, parent: El, target: El, name: str, binds: Mapping[str, tuple[float, float]]) -> El:
    inner = fr.d("Node", target, x=0.0, y=0.0, name=name + "Pivot")
    outer = fr.d("Node", *[eased_breath(fr, k, c0, c) for k, (c0, c) in binds.items()], inner, x=0.0, y=0.0,
                 name=name)
    parent.children[parent.children.index(target)] = outer
    return outer


def rig_body(fr: FaceRig, root: El, body: El, body_g: El, head_base: El,
             neck: tuple[float, float], swings: Sequence[El] = ()) -> None:
    """`breath` lifts the body from the feet (root frame) and the arm swings a little more (the
    shoulders); `roll` tilts the head about the neck (`neck` in body_g's local frame)."""
    breath_wrap(fr, root, body, "BreathLift", {"y": (0.0, BREATH_BODY["y"]), "scaleY": (1.0, BREATH_BODY["scaleY"]),
                                                "scaleX": (1.0, BREATH_BODY["scaleX"])})
    for sw in swings:
        breath_wrap(fr, body_g, sw, "BreathShoulder" + str(sw.attrs.get("name", ""))[-1],
                    {"y": (0.0, BREATH_SHOULDER)})
    roll = fr.wrap(body_g, head_base, neck, "HeadRoll", [("rotation", 0.0, {"roll": round(math.radians(6), 4)})])
    # the head undoes the body's stretch about the neck (rigid) and sinks a little (BREATH_HEAD_SINK)
    roll.children[1:1] = [eased_breath(fr, "y", neck[1], BREATH_HEAD_SINK),
                          eased_breath(fr, "scaleY", 1.0, round(1 / (1 + BREATH_BODY["scaleY"]) - 1, 4))]


def rig_chin(fr: FaceRig, parent: El, chin_light: El) -> None:
    """The chin's light rides the dropping jaw (`head_turn.JAW_CONTOUR`: the chin bone's drop). It
    shows only when pressed or rolled-in lips push the chin up (critic round 2: at rest it read, with
    the lower-lip shade, as a goatee / double chin)."""
    w = fr.wrap(parent, chin_light, (0.0, 0.0), "ChinLightJaw", [("y", 0.0, terms(J=JAW_CONTOUR["Chin"] * 0.9))])
    fr.bind_on(w, "opacity", 0.0, CHIN_LIGHT_ON, lo=0.0, hi=1.0)


CHIN_LIGHT_ON = terms(R=1.4, T=1.4, TK=-1.4)  # the chin light's opacity terms (0 at rest)
