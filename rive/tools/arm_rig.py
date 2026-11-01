"""Arm skeleton (moonshot M3, plan ruling 5): bones, skinned sleeves and a Rive IKConstraint.

Per arm (`ArmR` / `ArmL`, the shoulder pivots that the presence swing and the shrug/laugh keys move):

    Shoulder (RootBone, at the shoulder)
      UpperArm (Bone, length keyed = L1 * fs)            <- IK chain (parentBoneCount 1)
        Forearm (Bone, length keyed = L2 * fs2)          <- IKConstraint toward HandTarget<R|L>
          Wrist (Bone, length 0)        -> Hand (keyed rotation: the hand trails the forearm)
          ForeArtBone (wrist -> elbow, scaleX keyed = fs2) -> ForeArt (forearm sleeve frame)
        ElbowArt (at the elbow, RotationConstraint: half the forearm's bend, scaleX keyed (fs+fs2)/2)
        UpperArtBone (elbow -> shoulder, scaleX keyed = fs) -> UpperArt (upper sleeve frame)
    HandTarget<R|L> (Node, keyed x/y in the shoulder's frame)

The chain bones are never scaled (a scaled parent would skew its child): foreshortening keys the
chain lengths (the IK reads them) and the art bones' scaleX, which squeeze the skinned sleeves
toward the moving elbow / wrist exactly like the old `UpperArt` / `ForeArt` scaleY did toward the
shoulder / elbow. Sleeves are skinned with `auto_weights` to UpperArtBone, ElbowArt and ForeArtBone:
the elbow zone rides the half-bend joint bone, so a sharp bend keeps its volume (plain two-bone
blending collapses a 90 degree elbow to cos 45 = 71 % of its width) and the upper and forearm
sleeves deform with one weight field (no seam where they overlap).

Runtime convention (rive 1.8.0, verified headless and in the Task 1 runtime check): with
`invertDirection` false the elbow takes `rig_dsl.two_bone_dirs(..., bend=-1)`, true takes `bend=+1`.

Every new element takes its own id range (`AD`), so no main-document id moves.
"""

from __future__ import annotations

import math
from typing import Sequence

from rig_dsl import BoneSpec, Skeleton, auto_weights, ik, pack, quantize, wrap_angle
from rml import Doc, El, smooth_path

ARM_ID_START = 970000
AD = Doc(client=0, start=ARM_ID_START)
PI = math.pi

SHOULDER_Y, ELBOW_Y, WRIST_Y = 720.0, 900.0, 1070.0
L1 = ELBOW_Y - SHOULDER_Y
L2 = WRIST_Y - ELBOW_Y
JOINT = 30.0          # half-length (art px along the arm) of the zone skinned to the elbow joint bone
FALLOFF = 8.0         # auto_weights power: blends over about one sleeve radius around the joint zone
RIGID = 0.99          # a shape whose every weight is >= this on its own bone stays rigid (no skin)
REACH_MARGIN = 12.0   # straight-arm targets sit this far past the reach: chords between keys stay out
REST_TARGET = (0.0, L1 + L2 + REACH_MARGIN)
TARGET_TOL = 0.05     # px: target keys dropped while linear in-betweens stay this close
HAND_TOL = 0.0005     # rad: hand-rotation keys likewise
BEND_OF_INVERT = {False: -1, True: 1}

# smoothstep 3t^2 - 2t^3 is exactly this cubic ease: the foreshortening channels interpolate between
# pose frames with it, so they are keyed at the pose frames only
SMOOTHSTEP = AD("CubicEaseInterpolator", x1=1 / 3, y1=0.0, x2=2 / 3, y2=1.0)


def shoulder_x(side: int) -> float:
    return 240.0 if side == -1 else 560.0


def suffix(side: int) -> str:
    return "R" if side == -1 else "L"


def rig_arm(a: dict, side: int) -> None:
    """Re-parent the arm built by gen_avatar.build_arm onto a bone chain (adds `sk`, `bones`,
    `target`, `ik` to `a`). `a["elbow"]` is retired (its node is no longer in the tree)."""
    sx = shoulder_x(side)
    s0, e0, w0 = (sx, SHOULDER_Y), (sx, ELBOW_Y), (sx, WRIST_Y)
    sk = Skeleton(AD, "Arm" + suffix(side), frame=s0)
    shoulder = sk.root("Shoulder", s0)
    upper = sk.add(BoneSpec("UpperArm", s0, e0, "Shoulder"))
    fore = sk.add(BoneSpec("Forearm", e0, w0, "UpperArm"))
    wrist = sk.add(BoneSpec("Wrist", w0, w0, "Forearm"))
    fore_art = sk.add(BoneSpec("ForeArtBone", w0, e0, "Forearm"))
    joint = sk.add(BoneSpec("ElbowArt", e0, (sx, ELBOW_Y + 1.0), "UpperArm"))
    up_art = sk.add(BoneSpec("UpperArtBone", e0, s0, "UpperArm"))
    # sleeve frames: their world transform at bind is the old node's (no rotation, same origin)
    a["up_art"].el.attrs.update(x=L1, y=0.0, rotation=PI / 2)
    a["fore_art"].el.attrs.update(x=L2, y=0.0, rotation=PI / 2)
    a["hand"].el.attrs.update(x=0.0, y=0.0)
    up_art.children = [a["up_art"].el]
    fore_art.children = [a["fore_art"].el]
    wrist.children = [a["hand"].el]
    target = AD("Node", x=REST_TARGET[0], y=REST_TARGET[1], name="HandTarget" + suffix(side))
    constraint = ik(AD, fore, target, parent_bone_count=1)
    joint.add(AD("RotationConstraint", targetId=fore.ref(), sourceSpaceValue="local", destSpaceValue="local",
                 copyFactor=0.5, offset=True, name="HalfBend"))
    # front-most first: hand > forearm sleeve > upper sleeve
    fore.children = [constraint, wrist, fore_art]
    upper.children = [fore, joint, up_art]
    a["arm"].el.children = [shoulder, target]
    a.update(sk=sk, target=target, ik=constraint,
             bones={"Shoulder": shoulder, "UpperArm": upper, "Forearm": fore, "Wrist": wrist,
                    "ForeArtBone": fore_art, "ElbowArt": joint, "UpperArtBone": up_art})


# ------------------------------------------------------------------ continuous sleeves

# (upper fill, forearm fill, forearm outline) per sleeve kind, and the capsule radii
# (shoulder, elbow) / (elbow, wrist) of gen_avatar.build_sleeves
SLEEVE_NAMES = {"cloth": ("Sleeve", "Sleeve", "SleeveLine"), "skin": ("SkinUp", "SkinFore", "SkinForeLine")}
SLEEVE_RADII = {"cloth": ((50.0, 43.0), (42.0, 35.0)), "skin": ((40.0, 35.0), (35.0, 30.0))}
RIGID_PARTS = {"RigidShell", "Pauldron", "ForePanel", "ForePlateRim", "Puff"}  # armour stays hard
# side heights shared by the three paths; few in the joint zone, so the inner side of a sharp bend
# folds as one smooth crossing instead of looping through bunched-up vertices. The upper fill's own
# stroke draws the contour down to the shared 905 vertex, where the forearm fill (in front) and the
# open outline take over: one unbroken contour.
UP_SIDE = (780.0, 840.0, 875.0, 905.0)
FORE_SIDE = (905.0, 940.0, 990.0, 1035.0)
UP_END, FORE_TOP, LINE_TOP = 1010.0, 905.0, 905.0


def radius(y: float, up: tuple[float, float], fore: tuple[float, float], wrist_y: float) -> float:
    """One sleeve profile: the upper capsule's taper, then the forearm's (their 1 px step at the elbow
    is spread over 40 px)."""
    ru = up[0] + (up[1] - up[0]) * (y - SHOULDER_Y) / L1
    rf = fore[0] + (fore[1] - fore[0]) * (y - ELBOW_Y) / (wrist_y - ELBOW_Y)
    t = min(1.0, max(0.0, (y - (ELBOW_Y - 20.0)) / 40.0))
    return ru + (rf - ru) * t


def sleeve_outlines(cx: float, up: tuple[float, float], fore: tuple[float, float],
                    wrist_y: float) -> tuple[list, list, list]:
    """Absolute art-space points of the upper fill (shoulder cap -> UP_END), the forearm fill
    (FORE_TOP -> wrist cap) and the outline (LINE_TOP -> wrist cap -> LINE_TOP, open). Every side
    point the three share sits at the same height, so they skin to the same contour."""
    def r(y: float) -> float:
        return radius(y, up, fore, wrist_y)
    cap_top = [(cx + up[0] * math.cos(math.radians(a)), SHOULDER_Y + up[0] * math.sin(math.radians(a)))
               for a in (180, 225, 270, 315)]
    cap_bot = [(cx + fore[1] * math.cos(math.radians(a)), wrist_y + fore[1] * math.sin(math.radians(a)))
               for a in (0, 45, 90, 135, 180)]
    right = lambda ys: [(cx + r(y), y) for y in ys]  # noqa: E731
    left = lambda ys: [(cx - r(y), y) for y in reversed(ys)]  # noqa: E731
    # the upper fill runs on down the shared forearm contour (behind the forearm fill), so on the inside
    # of a bend both fills trace one edge and no notch opens between them
    up_ys = (*UP_SIDE, *[y for y in FORE_SIDE if UP_SIDE[-1] < y < UP_END])
    upper = [*cap_top, (cx + up[0], SHOULDER_Y), *right(up_ys), (cx + r(UP_END), UP_END, "c"),
             (cx - r(UP_END), UP_END, "c"), *left(up_ys)]
    below = [y for y in FORE_SIDE if y > FORE_TOP]
    fore_fill = [(cx - r(FORE_TOP), FORE_TOP, "c"), (cx + r(FORE_TOP), FORE_TOP, "c"), *right(below),
                 *cap_bot, *left(below)]
    line_ys = (LINE_TOP, *[y for y in FORE_SIDE if y > LINE_TOP])
    outline = [*right(line_ys), *cap_bot, *left(line_ys)]
    return upper, fore_fill, outline


def _replace_path(shape: El, pts: list, closed: bool, frame: tuple[float, float]) -> None:
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    path = smooth_path(AD, [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts], closed=closed)
    i = next(i for i, c in enumerate(shape.children) if c.tag == "PointsPath")
    shape.children[i] = path
    # paints are authored around the old shape centre: keep their x origin on the arm axis
    shape.attrs.update(x=ox - frame[0], y=oy - frame[1])


def _clone(el: El) -> El:
    return AD(el.tag, *[_clone(k) for k in el.children], **el.attrs)


WEB_INSET = 2.0            # px inside the contour, so a straight arm hides the web completely
WEB_UP, WEB_FORE = 820.0, 985.0


def elbow_web(fill_shape: El, cx: float, r_up: float, r_fore: float, sk: Skeleton) -> El:
    """The crease web: a quad whose upper corners ride the upper arm and lower corners the forearm.
    Drawn behind the sleeve; on the inside of a bend its edge is the chord that closes the V between
    the two sleeve edges (the torso stops short of the elbow, so the V would show the background)."""
    corners = [(cx - r_up + WEB_INSET, WEB_UP, "UpperArtBone"), (cx + r_up - WEB_INSET, WEB_UP, "UpperArtBone"),
               (cx + r_fore - WEB_INSET, WEB_FORE, "ForeArtBone"), (cx - r_fore + WEB_INSET, WEB_FORE, "ForeArtBone")]
    index = {"UpperArtBone": 0, "ForeArtBone": 1}
    verts = []
    for x, y, bone in corners:
        val, ix = pack([(bone, 255)], index)
        verts.append(AD("StraightVertex", AD("Weight", values=val, indices=ix), x=x - cx, y=y - ELBOW_Y))
    path = AD("PointsPath", *verts, AD("Skin", sk.tendon("UpperArtBone"), sk.tendon("ForeArtBone"),
                                      tx=cx - sk.frame[0], ty=ELBOW_Y - sk.frame[1]), isClosed=True,
              isClockwise=True, name="Path")
    paints = [_clone(c) for c in fill_shape.children if c.tag == "Fill"]
    # same origin as the upper fill, so the copied gradient lines up (the skin places the geometry)
    return AD("Shape", path, *paints, x=float(fill_shape.attrs["x"]), y=float(fill_shape.attrs["y"]),
              name="ElbowWeb")


def continuous_sleeves(a: dict, side: int, kinds: dict[str, str]) -> None:
    """Rebuild each outfit's sleeve capsule pair as one profile (see sleeve_outlines). `kinds` maps
    an outfit to gen_avatar.SLEEVES' kind; armour (robocop) keeps its hard shells and hinge."""
    sx = shoulder_x(side)
    for oid, kind in kinds.items():
        if kind == "armor":
            continue
        family = "skin" if kind in ("bare", "short") else "cloth"
        n_up, n_fore, n_line = SLEEVE_NAMES[family]
        up_r, fore_r = SLEEVE_RADII[family]
        wrist_y = WRIST_Y if kind == "stars" else 1066.0
        upper, fore_fill, outline = sleeve_outlines(sx, up_r, fore_r, wrist_y)
        named = lambda g, n: next(c for c in g.children if c.attrs.get("name") == n)  # noqa: E731
        up_fill = named(a["ups"][oid], n_up)
        _replace_path(up_fill, upper, True, (sx, SHOULDER_Y))
        group = a["ups"][oid]
        group.children.append(elbow_web(up_fill, sx, radius(WEB_UP, up_r, fore_r, wrist_y),
                                        radius(WEB_FORE, up_r, fore_r, wrist_y), a["sk"]))  # back-most
        _replace_path(named(a["fores"][oid], n_fore), fore_fill, True, (sx, ELBOW_Y))
        _replace_path(named(a["fores"][oid], n_line), outline, False, (sx, ELBOW_Y))


# ------------------------------------------------------------------ skinning

def weight_segments(side: int) -> dict[str, tuple[tuple[float, float], tuple[float, float]]]:
    """The weight field: upper arm, the elbow joint zone, forearm (art space, rest pose)."""
    sx = shoulder_x(side)
    return {"UpperArtBone": ((sx, SHOULDER_Y), (sx, ELBOW_Y - JOINT)),
            "ElbowArt": ((sx, ELBOW_Y - JOINT), (sx, ELBOW_Y + JOINT)),
            "ForeArtBone": ((sx, ELBOW_Y + JOINT), (sx, WRIST_Y))}


def _vertex_points(v: El, at: tuple[float, float]) -> list[tuple[float, float]]:
    x, y = at[0] + float(v.attrs["x"]), at[1] + float(v.attrs["y"])
    if v.tag != "CubicDetachedVertex":
        return [(x, y)]
    ri, di = float(v.attrs["inRotation"]), float(v.attrs["inDistance"])
    ro, do = float(v.attrs["outRotation"]), float(v.attrs["outDistance"])
    return [(x, y), (x + math.cos(ri) * di, y + math.sin(ri) * di), (x + math.cos(ro) * do, y + math.sin(ro) * do)]


def skin_shape(shape: El, at: tuple[float, float], own: str, sk: Skeleton,
               segs: dict[str, tuple[tuple[float, float], tuple[float, float]]]) -> bool:
    """Skin `shape` (art-space origin `at`) if any of its points leans off its own bone. Returns
    whether it was skinned."""
    path = next((c for c in shape.children if c.tag == "PointsPath"), None)
    if path is None or any(c.tag == "Skin" for c in path.children) or shape.attrs.get("name") in RIGID_PARTS:
        return False
    verts = [v for v in path.children if v.tag in ("StraightVertex", "CubicDetachedVertex")]
    groups = [_vertex_points(v, at) for v in verts]
    weights = [auto_weights(g, segs, falloff=FALLOFF) for g in groups]
    if all(w.get(own, 0.0) >= RIGID for ws in weights for w in ws):
        return False
    index: dict[str, int] = {}
    qss = [[quantize(w) for w in ws] for ws in weights]
    for qs in qss:
        for q in qs:
            for b, _ in q:
                index.setdefault(b, len(index))
    for v, qs in zip(verts, qss):
        if v.tag == "StraightVertex":
            val, ix = pack(qs[0], index)
            v.add(AD("Weight", values=val, indices=ix))
        else:
            (va, ia), (vi, ii), (vo, io) = (pack(q, index) for q in qs)
            v.add(AD("CubicWeight", values=va, indices=ia, inValues=vi, inIndices=ii, outValues=vo, outIndices=io))
    path.add(AD("Skin", *[sk.tendon(b) for b in index], tx=at[0] - sk.frame[0], ty=at[1] - sk.frame[1]))
    return True


def skin_sleeves(a: dict, side: int) -> int:
    """Skin every sleeve / bare-arm path of every outfit across the elbow. Ellipses and paths that
    sit wholly on one bone stay rigid in their frame (UpperArt / ForeArt follow their art bones)."""
    sx = shoulder_x(side)
    segs = weight_segments(side)
    count = 0

    def visit(el: El, off: tuple[float, float], own: str) -> None:
        nonlocal count
        for c in el.children:
            if c.tag == "Shape":
                at = (off[0] + float(c.attrs.get("x", 0.0)), off[1] + float(c.attrs.get("y", 0.0)))
                assert not c.attrs.get("rotation") and c.attrs.get("scaleX", 1.0) == 1.0, c.attrs.get("name")
                count += skin_shape(c, at, own, a["sk"], segs)
            elif c.tag in ("Node", "Solo"):
                assert not c.attrs.get("rotation") and c.attrs.get("scaleX", 1.0) == 1.0 \
                    and c.attrs.get("scaleY", 1.0) == 1.0, c.attrs.get("name")
                visit(c, (off[0] + float(c.attrs.get("x", 0.0)), off[1] + float(c.attrs.get("y", 0.0))), own)

    for g in a["ups"].values():
        visit(g, (sx, SHOULDER_Y), "UpperArtBone")
    for g in a["fores"].values():
        visit(g, (sx, ELBOW_Y), "ForeArtBone")
    return count


# ------------------------------------------------------------------ keys

def fk(side: int, r: Sequence[float], fs: float, fs2: float) -> tuple[tuple[float, float], tuple[float, float]]:
    """Elbow and wrist in the shoulder's frame for joint rotations `r` (avatar_kit.ik's (arm, elbow,
    hand); 0 = hanging straight down) and foreshortening `fs`, `fs2`."""
    up = PI / 2 + r[0]
    lo = up + r[1]
    ex, ey = L1 * fs * math.cos(up), L1 * fs * math.sin(up)
    return (ex, ey), (ex + L2 * fs2 * math.cos(lo), ey + L2 * fs2 * math.sin(lo))


def ik_target(side: int, r: Sequence[float], fs: float, fs2: float) -> tuple[tuple[float, float], int]:
    """The keyed target for a pose and its bend (0 = straight). A straight arm's target is pushed
    REACH_MARGIN past the reach so the runtime keeps it straight between keys."""
    _, w = fk(side, r, fs, fs2)
    bend = wrap_angle(r[1])
    if abs(bend) < 1e-6:
        reach = L1 * fs + L2 * fs2 + REACH_MARGIN
        n = math.hypot(*w) or 1.0
        return (w[0] / n * reach, w[1] / n * reach), 0
    return w, 1 if bend > 0 else -1


def rdp(keys: Sequence[tuple[int, tuple[float, ...]]], tol: float) -> list[int]:
    """Indices of `keys` [(frame, value vector)] to keep so linear in-betweens stay within `tol`
    (euclidean) of every dropped key."""
    n = len(keys)
    if n <= 2:
        return list(range(n))
    keep = {0, n - 1}
    stack = [(0, n - 1)]
    while stack:
        i0, i1 = stack.pop()
        (f0, v0), (f1, v1) = keys[i0], keys[i1]
        worst, at = 0.0, -1
        for i in range(i0 + 1, i1):
            f, v = keys[i]
            t = (f - f0) / (f1 - f0)
            err = math.hypot(*[v[k] - (v0[k] + (v1[k] - v0[k]) * t) for k in range(len(v))])
            if err > worst:
                worst, at = err, i
        if worst > tol:
            keep.add(at)
            stack += [(i0, at), (at, i1)]
    return sorted(keep)


def _kf(frame: int, value: float, ease: El | None, doc: Doc = AD) -> El:
    return doc("KeyFrameDouble", frame=frame, value=float(value),
              interpolationType="cubic" if ease is not None else "linear",
              interpolatorId=ease.ref() if ease is not None else None)


def _obj(target: El, props: dict[str, list[El]], doc: Doc = AD) -> El:
    return doc("KeyedObject", *[doc("KeyedProperty", *kfs, property=p) for p, kfs in props.items()],
              objectId=target.ref())


def invert_track(a: dict, invert: bool, doc: Doc = AD) -> El:
    return _obj(a["ik"], {"invertDirection": [doc("KeyFrameBool", frame=0, value=invert, interpolationType="hold")]},
                doc)


def rest_tracks(a: dict) -> list[El]:
    """The rest pose of every channel the arm keys own (gesture_none and gestures that leave the arm
    alone, so every gesture is history-free)."""
    b = a["bones"]
    return [_obj(a["target"], {"x": [_kf(0, REST_TARGET[0], None)], "y": [_kf(0, REST_TARGET[1], None)]}),
            _obj(b["UpperArm"], {"length": [_kf(0, L1, None)]}), _obj(b["Forearm"], {"length": [_kf(0, L2, None)]}),
            _obj(b["UpperArtBone"], {"scaleX": [_kf(0, 1.0, None)]}),
            _obj(b["ForeArtBone"], {"scaleX": [_kf(0, 1.0, None)]}),
            _obj(b["ElbowArt"], {"scaleX": [_kf(0, 1.0, None)]}), invert_track(a, False)]


def gesture_tracks(a: dict, side: int, samples: list[tuple[int, tuple[float, float, float], float, float]],
                   pose_scales: list[tuple[int, float, float]], doc: Doc = AD) -> tuple[list[El], bool]:
    """Target, foreshortening and bend tracks for one arm of one gesture.

    samples: (frame, joint rotations from avatar_kit.ik, fs, fs2) every `step` frames;
    pose_scales: (pose frame, fs, fs2), interpolated with SMOOTHSTEP. Returns (tracks, invert).
    `doc` mints the elements (M4: the tablet clips take the M4 id range)."""
    keys: list[tuple[int, tuple[float, float]]] = []
    bends: set[int] = set()
    for f, r, fs, fs2 in samples:
        tgt, bend = ik_target(side, r, fs, fs2)
        keys.append((f, tgt))
        if bend:
            bends.add(bend)
    if len(bends) > 1:
        raise ValueError(f"arm {suffix(side)}: a gesture bends the elbow both ways; key invertDirection per span")
    invert = bends == {1}
    assert BEND_OF_INVERT[invert] == (bends.pop() if bends else -1)
    kept = [keys[i] for i in rdp(keys, TARGET_TOL)]
    tracks = [_obj(a["target"], {"x": [_kf(f, v[0], None, doc) for f, v in kept],
                                 "y": [_kf(f, v[1], None, doc) for f, v in kept]}, doc)]
    # foreshortening: pose frames only (drop keys inside constant runs)
    ps = [p for i, p in enumerate(pose_scales)
          if i in (0, len(pose_scales) - 1) or not (pose_scales[i - 1][1:] == p[1:] == pose_scales[i + 1][1:])]
    b = a["bones"]
    for bone, prop, fn in (("UpperArm", "length", lambda s, s2: L1 * s), ("Forearm", "length", lambda s, s2: L2 * s2),
                           ("UpperArtBone", "scaleX", lambda s, s2: s), ("ForeArtBone", "scaleX", lambda s, s2: s2),
                           ("ElbowArt", "scaleX", lambda s, s2: (s + s2) / 2)):
        tracks.append(_obj(b[bone], {prop: [_kf(f, fn(s, s2), SMOOTHSTEP, doc) for f, s, s2 in ps]}, doc))
    tracks.append(invert_track(a, invert, doc))
    return tracks, invert


def simplify_track(obj: El, tol: float) -> None:
    """Drop linear keyframes of every KeyedProperty of `obj` that in-betweens reproduce within `tol`
    (the surviving keyframes keep their ids)."""
    for prop in obj.children:
        kfs = prop.children
        keys = [(int(k.attrs["frame"]), (float(k.attrs["value"]),)) for k in kfs]
        prop.children = [kfs[i] for i in rdp(keys, tol)]
