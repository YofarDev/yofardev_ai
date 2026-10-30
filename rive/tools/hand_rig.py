"""Articulated hands (moonshot M8 Task 2, plan rulings 2-3): poses as digit rotation + scale.

Every hand copy (5 skins x 2 sides) keeps its `rest` drawing; `articulate` wraps each digit of that
`rest` group (the thumb, `Finger0` little .. `Finger3` index, and a glove's finger seam) in a pivot
node at its knuckle. Each pivot carries one `TransformConstraint` (local -> local) toward that side's
**driver** node for the digit: the drivers sit in `HandWave`, at the pivots' own local position, so
the constraint copies the driver's rotation and scale while the translation it copies is the
pivot's own. A pose is therefore ~10 keyed numbers per side (the drivers), whatever the skin, and
the rest pose is pixel-identical (drivers at identity).

A curled finger is the cartoon front view (the rest drawing shows the back of the hand): the digit
shortens toward its knuckle (`scaleY` 0.22-0.5 about the pivot, so the stubs under the palm read as
a fist's knuckle row) and tips in a little (|rotation| <= 0.35 rad); the thumb swings across the
palm or up. Rotations are given for the viewer's-left hand (side -1, the thumb toward +x); the
viewer's-right hand (side +1) is drawn mirrored, so its rotations flip sign.

New elements are minted by the caller's document (gen_avatar's M8 range).
"""

from __future__ import annotations

import math
from typing import Mapping, Sequence, Union

from rml import Doc, El

WX, WY = 240.0, 1070.0          # gen_avatar's hand authoring frame: the wrist, fingers pointing down
DIGITS = ("Thumb", "Finger0", "Finger1", "Finger2", "Finger3")
FINGER_X = {"Finger0": 217.0, "Finger1": 232.0, "Finger2": 248.0, "Finger3": 263.0}  # gen_avatar.hand_open
FINGER_LEN = {"Finger0": 36.0, "Finger1": 46.0, "Finger2": 50.0, "Finger3": 44.0}
FINGER_LEAN = {"Finger0": -5.0, "Finger1": -2.0, "Finger2": 1.0, "Finger3": 4.0}
FINGER_TOP = 46.0               # the fingers start under the palm (WY + 46)
KNUCKLE_DY = 52.0               # finger pivots: the palm's lower edge (WY + 52)
THUMB_PIVOT = (266.0, 16.0)     # the thumb's root (x, dy below WY)
THUMB_TIP = (293.0, 47.0)
HAND_SCALE = 1.15               # HandWave's scale about the wrist
# the hand's grip point (the hook / collar inside a closed hand) below the wrist along the fingers,
# in the Hand node's frame (HandWave scale included): the jacket hangs here
GRIP_REACH = 58.0
SEAM = "GloveFingerSeam"        # a glove's seam on finger i (gen_avatar.build_arm)

Pose = Mapping[str, tuple[float, float]]  # digit -> (rotation rad for side -1, scaleY)

_CURL = {"Finger0": (-0.16, 0.40), "Finger1": (-0.08, 0.42), "Finger2": (0.0, 0.44), "Finger3": (0.06, 0.42)}
_THUMB_ACROSS = (1.1, 0.8)      # the thumb pinned over the curled fingers (fist, counting)


def _pose(thumb: tuple[float, float], **fingers: tuple[float, float]) -> dict[str, tuple[float, float]]:
    out = {"Thumb": thumb, **_CURL}
    out.update({f"Finger{k[-1]}": v for k, v in fingers.items()})
    return out


# pose -> per-digit (rotation, scaleY); the thumb rotation + is across the palm, - is up / out
HAND_POSE_DRIVERS: dict[str, dict[str, tuple[float, float]]] = {
    "rest": {d: (0.0, 1.0) for d in DIGITS},
    "spread": {"Thumb": (-0.3, 1.0), "Finger0": (0.22, 1.02), "Finger1": (0.08, 1.04), "Finger2": (-0.04, 1.04),
               "Finger3": (-0.16, 1.0)},
    "fist": _pose(_THUMB_ACROSS),
    "grip": {"Thumb": (0.45, 0.9), "Finger0": (-0.12, 0.52), "Finger1": (-0.06, 0.55), "Finger2": (0.0, 0.56),
             "Finger3": (0.05, 0.55)},
    # thumb and index tips meet under the palm (an "OK" from the back); the others relax
    "pinch": {"Thumb": (0.56, 1.2), "Finger0": (-0.05, 0.72), "Finger1": (-0.03, 0.75), "Finger2": (-0.02, 0.76),
              "Finger3": (-0.17, 0.36)},
    "thumbsUp": _pose((-0.95, 1.0)),
    "one": _pose(_THUMB_ACROSS, f3=(0.0, 1.0)),
    "two": _pose(_THUMB_ACROSS, f3=(-0.06, 1.0), f2=(0.06, 1.0)),
    "three": _pose(_THUMB_ACROSS, f3=(-0.08, 1.0), f2=(0.0, 1.0), f1=(0.08, 1.0)),
    "four": _pose(_THUMB_ACROSS, f3=(-0.1, 1.0), f2=(-0.03, 1.0), f1=(0.04, 1.0), f0=(0.12, 1.0)),
}
NEW_POSES = ("fist", "grip", "pinch", "thumbsUp", "one", "two", "three")


def side_x(side: int, x: float) -> float:
    """gen_avatar.hand_open's X() for the rest drawing (t = 1): mirrored for side +1."""
    return 800.0 - x if side == 1 else x


def pivot_at(side: int, digit: str) -> tuple[float, float]:
    """The digit's knuckle pivot in artboard space (the authoring frame, HandWave's scale aside)."""
    if digit == "Thumb":
        return side_x(side, THUMB_PIVOT[0]), WY + THUMB_PIVOT[1]
    return side_x(side, FINGER_X[digit]), WY + KNUCKLE_DY


def values(pose: str | Pose, side: int) -> dict[str, tuple[float, float]]:
    """The drivers' (rotation, scaleY) for `pose` on `side` (rotation mirrored for side +1)."""
    p = HAND_POSE_DRIVERS[pose] if isinstance(pose, str) else pose
    return {d: (-p[d][0] if side == 1 else p[d][0], p[d][1]) for d in DIGITS}


def mix(a: str | Pose, b: str | Pose, t: float) -> dict[str, tuple[float, float]]:
    """A blend of two poses (canonical side -1 values); t may overshoot (motion_synth)."""
    pa = HAND_POSE_DRIVERS[a] if isinstance(a, str) else a
    pb = HAND_POSE_DRIVERS[b] if isinstance(b, str) else b
    return {d: (pa[d][0] + (pb[d][0] - pa[d][0]) * t, pa[d][1] + (pb[d][1] - pa[d][1]) * t) for d in DIGITS}


def _xf(p: tuple[float, float], pivot: tuple[float, float], rot: float, sy: float) -> tuple[float, float]:
    """A point under the pivot's rotation + scaleY (Rive order: scale, then rotate, about the pivot)."""
    dx, dy = p[0] - pivot[0], (p[1] - pivot[1]) * sy
    c, s = math.cos(rot), math.sin(rot)
    return pivot[0] + c * dx - s * dy, pivot[1] + s * dx + c * dy


def tip(side: int, digit: str, pose: str | Pose) -> tuple[float, float]:
    """Where the digit's tip lands in `pose` (artboard px, authoring frame)."""
    rot, sy = values(pose, side)[digit]
    if digit == "Thumb":
        raw = (side_x(side, THUMB_TIP[0]), WY + THUMB_TIP[1])
    else:
        lean = FINGER_LEAN[digit] * -side  # hand_open: lean * t * -side (t = 1)
        raw = (side_x(side, FINGER_X[digit]) + lean, WY + FINGER_TOP + FINGER_LEN[digit])
    return _xf(raw, pivot_at(side, digit), rot, sy)


# ------------------------------------------------------------------ the generator side

def drivers(doc: Doc, side: int, frame: tuple[float, float]) -> dict[str, El]:
    """One driver node per digit, at the pivots' local position in `frame` (HandWave's origin)."""
    sfx = "R" if side == -1 else "L"
    out = {}
    for dg in DIGITS:
        x, y = pivot_at(side, dg)
        out[dg] = doc("Node", x=float(x - frame[0]), y=float(y - frame[1]), name=f"Drive{dg}{sfx}")
    return out


def _digit_of(shape: El) -> str | None:
    name = str(shape.attrs.get("name", ""))
    if name == "Thumb" or name in FINGER_X:
        return name
    if name.startswith(SEAM):
        return f"Finger{name[len(SEAM):]}"
    return None


def articulate(doc: Doc, group: El, side: int, frame: tuple[float, float], drive: Mapping[str, El]) -> dict[str, El]:
    """Wrap the digits of a `Hand_rest` group in pivot nodes constrained to `drive`. Each finger pivot
    takes the place of its finger's shape (a seam joins its finger's pivot, in front of the finger); the
    thumb's pivot goes first (in front of a glove's knuckle chevrons, which it crosses in a fist). The
    draw order is unchanged wherever shapes overlap at rest. Returns digit -> pivot."""
    pivots: dict[str, El] = {}
    kids: list[El] = []
    pending: dict[str, list[El]] = {}
    for c in group.children:  # seams come first (front-most): hold them for their finger
        dg = _digit_of(c)
        if dg is not None and str(c.attrs.get("name")).startswith(SEAM):
            pending.setdefault(dg, []).append(c)
    for c in group.children:
        dg = _digit_of(c)
        if dg is None:
            kids.append(c)
            continue
        if str(c.attrs.get("name")).startswith(SEAM):
            continue
        px, py = pivot_at(side, dg)
        lx, ly = px - frame[0], py - frame[1]
        parts = [*pending.get(dg, []), c]
        for p in parts:
            p.attrs["x"] = float(p.attrs.get("x", 0.0)) - lx
            p.attrs["y"] = float(p.attrs.get("y", 0.0)) - ly
        pv = doc("Node", doc("TransformConstraint", targetId=drive[dg].ref(), sourceSpaceValue="local",
                             destSpaceValue="local"), *parts, x=float(lx), y=float(ly), name="Pv" + dg)
        pivots[dg] = pv
        kids.append(pv)
    # the thumb goes in front of everything (a glove's knuckle chevrons included): it swings across the back of
    # the hand; at rest nothing else overlaps it, so the rest drawing is unchanged
    kids.remove(pivots["Thumb"])
    group.children = [pivots["Thumb"], *kids]
    return pivots


Key = tuple[int, Union[str, Pose]]


def pose_tracks(doc: Doc, drive: Mapping[str, El], side: int, keys: Sequence[Key], ease: El | None,
                hold_rest: bool = False) -> list[El]:
    """KeyedObjects for `drive` through `keys` [(frame, pose)]: every key eases (cubic `ease`) into
    the next. A digit that stays at rest throughout is not keyed (the HandRest layer holds it),
    unless `hold_rest`."""
    out = []
    vals = [(f, values(p, side)) for f, p in keys]
    for dg in DIGITS:
        props = []
        for i, prop in enumerate(("rotation", "scaleY")):
            series = [(f, v[dg][i]) for f, v in vals]
            rest = 0.0 if i == 0 else 1.0
            if not hold_rest and all(abs(x - rest) < 1e-9 for _, x in series):
                continue
            # inside a constant run a key adds nothing (its neighbours hold the same value), nor does a leading
            # or trailing run's outer key (a property holds its first / last key's value outside them)
            def same(j: int, k: int) -> bool:
                return 0 <= k < len(series) and abs(series[j][1] - series[k][1]) < 1e-9
            series = [series[j] for j in range(len(series))
                      if not ((same(j, j - 1) and same(j, j + 1)) or (j == 0 and same(j, 1))
                              or (j == len(series) - 1 and same(j, j - 1)))]
            kfs = [doc("KeyFrameDouble", frame=f, value=round(float(x), 4),
                       interpolationType="cubic" if ease is not None else "linear",
                       interpolatorId=ease.ref() if ease is not None else None) for f, x in series]
            props.append(doc("KeyedProperty", *kfs, property=prop))
        if props:
            out.append(doc("KeyedObject", *props, objectId=drive[dg].ref()))
    return out
