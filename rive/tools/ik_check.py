"""IK pose check (moonshot M3 Task 7): the runtime arm pose against the Python two-bone solver.

The avatar's gestures key each arm's `HandTarget<R|L>`, the chain lengths and `invertDirection`;
Rive's IKConstraint poses the bones. This check renders a copy of the avatar in which nothing draws
except small coloured markers (the shoulder frame, the elbow = Forearm origin, the hand = Wrist bone),
finds them in the capture and compares the rendered elbow and hand with `rig_dsl.two_bone_dirs`
solved on the keyed values read back from the RML. The shoulder-frame markers (its origin and two
points 200 px along its axes) absorb every parent transform (body bounce, shrug, presence swing).

    uv run --with pillow python rive/tools/motion_review.py --ik-check
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image

from rig_dsl import two_bone_dirs

BEND_OF_INVERT = {False: -1, True: 1}  # arm_rig.BEND_OF_INVERT (runtime convention)
AXIS = 200.0                           # shoulder-frame marker offset (px)
MARK = 6.0                             # marker size (px)
MARK_ID = 1_990_000                    # review-copy ids, far from every generator range
HEIGHT = 1250.0
COLOURS = {"R": {"O": "FFFF0000", "X": "FF00FF00", "Y": "FF0000FF", "E": "FFFFFF00", "W": "FFFF00FF"},
           "L": {"O": "FFFF8000", "X": "FF00FF80", "Y": "FF0080FF", "E": "FF80FF00", "W": "FF8000FF"}}
PASSES = {"frame": ("O", "X", "Y"), "joints": ("E", "W")}


# ------------------------------------------------------------------ keyframes

def bezier_ease(x1: float, y1: float, x2: float, y2: float, u: float) -> float:
    """Rive CubicEaseInterpolator: y at x = u on the (0,0) (x1,y1) (x2,y2) (1,1) bezier."""
    lo, hi = 0.0, 1.0
    for _ in range(60):
        t = (lo + hi) / 2
        x = 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3
        lo, hi = (t, hi) if x < u else (lo, t)
    t = (lo + hi) / 2
    return 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3


@dataclass
class Channel:
    keys: list[tuple[float, float, str, tuple[float, float, float, float] | None]]

    def at(self, frame: float) -> float:
        k = self.keys
        if frame <= k[0][0]:
            return k[0][1]
        for (f0, v0, mode, ease), (f1, v1, _, _) in zip(k, k[1:]):
            if frame < f1:
                u = (frame - f0) / (f1 - f0)
                if mode == "hold":
                    return v0
                if mode == "cubic" and ease is not None:
                    u = bezier_ease(*ease, u)
                return v0 + (v1 - v0) * u
        return k[-1][1]


def channels(board: ET.Element, animation: str) -> dict[tuple[str, str], Channel]:
    eases = {e.get("id"): tuple(float(e.get(a, 0)) for a in ("x1", "y1", "x2", "y2"))
             for e in board.iter("CubicEaseInterpolator")}
    anim = next(a for a in board.iter("LinearAnimation") if a.get("name") == animation)
    out: dict[tuple[str, str], Channel] = {}
    for obj in anim.findall("KeyedObject"):
        for prop in obj.findall("KeyedProperty"):
            if any(kf.tag not in ("KeyFrameDouble", "KeyFrameBool") for kf in prop):
                continue
            keys = []
            for kf in prop:
                v = kf.get("value", "0")
                val = (1.0 if v == "true" else 0.0) if v in ("true", "false") else float(v)
                keys.append((float(kf.get("frame", 0)), val, kf.get("interpolationType", "hold"),
                             eases.get(kf.get("interpolatorId"))))
            out[(obj.get("objectId"), prop.get("property"))] = Channel(keys)
    return out


# ------------------------------------------------------------------ the arm in the RML

@dataclass
class ArmIds:
    side: str
    arm: ET.Element
    target: str
    upper: ET.Element
    fore: ET.Element
    wrist: ET.Element
    ik: str
    rest: dict[str, float]


def arms(board: ET.Element) -> list[ArmIds]:
    out = []
    for side in ("R", "L"):
        arm = next(e for e in board.iter("Node") if e.get("name") == "Arm" + side)
        byname = {e.get("name"): e for e in arm.iter() if e.get("name")}
        fore = byname["Forearm"]
        ik = next(c for c in fore if c.tag == "IKConstraint")
        tgt = byname["HandTarget" + side]
        out.append(ArmIds(side, arm, tgt.get("id"), byname["UpperArm"], fore, byname["Wrist"], ik.get("id"),
                          {"tx": float(tgt.get("x", 0)), "ty": float(tgt.get("y", 0)),
                           "l1": float(byname["UpperArm"].get("length")), "l2": float(fore.get("length")),
                           "inv": 1.0 if ik.get("invertDirection") == "true" else 0.0}))
    return out


def expected(arm: ArmIds, ch: dict[tuple[str, str], Channel],
             frame: float) -> tuple[tuple[float, float], tuple[float, float]]:
    """(elbow, wrist) in the shoulder frame: the Python two-bone solver on the keyed values."""
    def v(obj: str, prop: str, rest: str) -> float:
        c = ch.get((obj, prop))
        return c.at(frame) if c else arm.rest[rest]
    tx, ty = v(arm.target, "x", "tx"), v(arm.target, "y", "ty")
    l1, l2 = v(arm.upper.get("id"), "length", "l1"), v(arm.fore.get("id"), "length", "l2")
    bend = BEND_OF_INVERT[v(arm.ik, "invertDirection", "inv") > 0.5]
    up, lo, elbow = two_bone_dirs(l1, l2, (tx, ty), bend)
    return elbow, (elbow[0] + l2 * math.cos(lo), elbow[1] + l2 * math.sin(lo))


# ------------------------------------------------------------------ marker copy

def marker_copy(source: Path, dest_dir: Path, which: str) -> None:
    """A review copy of `source` that draws only the `which` pass markers (PASSES)."""
    tree = ET.parse(source)
    root = tree.getroot()
    removed: set[str] = set()
    for shape in root.iter("Shape"):
        for paint in [c for c in shape if c.tag in ("Fill", "Stroke")]:
            removed.update(e.get("id") for e in paint.iter() if e.get("id"))
            shape.remove(paint)
    # keys on a removed paint (M8: the tablet's weather card keys a screen colour) would dangle
    for parent in list(root.iter()):
        for keyed in [c for c in parent if c.tag == "KeyedObject" and c.get("objectId") in removed]:
            parent.remove(keyed)
    board = root.find("Artboard")
    nid = [MARK_ID]

    def el(tag: str, parent: ET.Element | None = None, **attrs: object) -> ET.Element:
        e = ET.Element(tag, {k: str(v) for k, v in attrs.items()})
        e.set("id", f"0:{nid[0]}")
        nid[0] += 1
        if parent is not None:
            parent.append(e)
        return e

    def marker(parent: ET.Element, colour: str, x: float, y: float) -> None:
        shape = ET.Element("Shape", {"x": str(x), "y": str(y), "name": "IKMarker"})
        shape.set("id", f"0:{nid[0]}")
        nid[0] += 1
        el("Rectangle", shape, width=MARK, height=MARK, name="Path")
        fill = el("Fill", shape, name="Fill")
        el("SolidColor", fill, colorValue=colour)
        parent.insert(0, shape)

    for arm in arms(board):
        c = COLOURS[arm.side]
        if which == "frame":
            marker(arm.arm, c["O"], 0.0, 0.0)
            marker(arm.arm, c["X"], AXIS, 0.0)
            marker(arm.arm, c["Y"], 0.0, AXIS)
        else:
            marker(arm.fore, c["E"], 0.0, 0.0)
            marker(arm.wrist, c["W"], 0.0, 0.0)
    board.set("height", str(HEIGHT))          # the resting hands hang below the 1000 px artboard
    dest_dir.mkdir(parents=True, exist_ok=True)
    tree.write(dest_dir / "avatar.rml", encoding="unicode")
    (dest_dir / "rive.yaml").write_text("name: ikcheck\nmain: Avatar\noutput: {dir: build}\n")


def find(image: Image.Image, colours: dict[str, str], tol: int = 40) -> dict[str, tuple[float, float]]:
    """Centroid of the opaque pixels within `tol` of each colour (AARRGGBB), by key."""
    want = {k: tuple(int(c[i:i + 2], 16) for i in (2, 4, 6)) for k, c in colours.items()}
    acc = {k: [0.0, 0.0, 0] for k in colours}
    w = image.width
    for i, (r, g, b, a) in enumerate(image.convert("RGBA").getdata()):
        if a <= 160:
            continue
        for k, (r0, g0, b0) in want.items():
            if abs(r - r0) < tol and abs(g - g0) < tol and abs(b - b0) < tol:
                acc[k][0] += i % w
                acc[k][1] += i // w
                acc[k][2] += 1
    return {k: (sx / n + 0.5, sy / n + 0.5) for k, (sx, sy, n) in acc.items() if n}


def to_image(frame: dict[str, tuple[float, float]], local: tuple[float, float]) -> tuple[float, float]:
    o, x, y = frame["O"], frame["X"], frame["Y"]
    ex = ((x[0] - o[0]) / AXIS, (x[1] - o[1]) / AXIS)
    ey = ((y[0] - o[0]) / AXIS, (y[1] - o[1]) / AXIS)
    return o[0] + local[0] * ex[0] + local[1] * ey[0], o[1] + local[0] * ex[1] + local[1] * ey[1]
