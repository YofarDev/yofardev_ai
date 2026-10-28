# /// script
# requires-python = ">=3.11"
# ///
"""2.5D head v2 (moonshot M1, Task 9): Python -> RML -> Rive CLI.

Writes rive/head/head.rml (+ rive.yaml):

  - artboard `Head` (400x480): the skinned head, every bone a history-free formula of the
    view model `HeadVM`: `yaw`, `pitch` (+-1 = +-30 deg / +-15 deg) and the performance
    channels `roll` (+-1 = +-5 deg), `gaze` (eye-in-head yaw), `blink` (0..1), `hairLag`
    (fringe), `sideLag` (side locks, bob), `tuftLag` (crown tuft), all in yaw units, and `brow`,
    `mouth` (0..1 raise / smile). Defaults are all 0 (front, eyes open, neutral).
  - artboard `PerformedTurn`: the same head nested (stateful) with a looping timeline that keys
    those numbers from rig_dsl.perform_turn (MotionRules: anticipation, overshoot, a speed cap,
    eyes leading by 80 ms, spaced and varied blinks, roll and dip, phased hair followers, brow
    and mouth acting, an idle layer).

Rig (see rive/tools/rig_dsl.py): `Neck` (RootBone) -> `Head` (Bone, rotation = roll) -> face
RootBones. Material points of a 3D head model drive features; silhouette bones are authored at
three poses (yaw -1, 0, +1) so the 3/4 contour gets a far cheekbone, a socket notch and a near
jaw angle; the far eye and nose use authored poses too (almond eye, nose tip to the far cheek
line). The hair shell, crown and bob are skinned, the locks and bob with lag. Each side lock
morphs with yaw: over the near cheek, beside the far one, so the far contour reads with no fade.

    uv run rive/tools/gen_head.py                 # write rive/head/head.rml
    uv run rive/tools/gen_head.py --build         # + rive --once (size printed)
    uv run rive/tools/gen_head.py --variant hair --out DIR   # check variant (hair over a flat face)
"""

from __future__ import annotations

import argparse
import colorsys
import math
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "rive" / "head"
sys.path.insert(0, str(HERE))

import art_bible as ab  # noqa: E402
import rig_dsl as r  # noqa: E402
from rig_dsl import Axis, BoneSpec, Chain, Grid, Pt, Weights, clockwise, fit3, mix, taper, tok, tokpos  # noqa: E402
from rml import Doc, El, lin, rad, write  # noqa: E402

d = Doc(client=0, start=10)
PI = math.pi

# ------------------------------------------------------------------ frame and model

OX, OY = 200.0, 172.0  # art space (absolute) -> artboard
ART_W, ART_H = 400.0, 480.0
CX, CY = 400.0, 380.0  # yaw axis x, pitch pivot y
ZP = -20.0  # pitch axis depth (behind the yaw axis: the neck)
K_YAW = round(math.radians(30), 4)
K_PITCH = round(math.radians(15), 4)
K_ROLL = round(math.radians(5), 4)
NECK_BASE = (400.0, 600.0)
HEAD_ORIGIN = (400.0, 470.0)  # roll pivot (top of the neck)
SCENE = ab.SCENES["livingRoom"]

# Lines: LineRules are px on a 1080 px frame; this head (crown..chin ~300 px) is 1/2.6 of a
# figure 780 px tall, so a 1080 frame shows it 1.385x larger.
LS = 1 / 1.385
W_SIL = ab.LINES.silhouette * LS  # 3.6
W_INT = ab.LINES.interior * LS  # 2.2
W_DET = ab.LINES.detail * LS  # 1.3


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
HAIR_A = (127.0, 146.0, 130.0)  # half axes x, y, z


def shell_z(x3: float, y: float) -> float:
    q = 1 - (x3 / HAIR_A[0]) ** 2 - ((y - HAIR_C[0]) / HAIR_A[1]) ** 2
    return HAIR_C[1] + HAIR_A[2] * math.sqrt(max(0.0, q))


# ------------------------------------------------------------------ colour (light rig)


def _rgb(c: str) -> tuple[float, float, float]:
    c = c[-6:]
    return tuple(int(c[i : i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def _hex(rgb: tuple[float, float, float], alpha: int = 255) -> str:
    return f"{alpha:02X}" + "".join(f"{max(0, min(255, round(v * 255))):02X}" for v in rgb)


def grade(c: str, alpha: int = 255) -> str:
    """Clamp a colour into the scene's value range and saturation cap (neutral highlights may
    stay bright)."""
    h, s, v = colorsys.rgb_to_hsv(*_rgb(c))
    lo, hi = SCENE.value
    s = min(s, SCENE.sat_cap - 0.02)
    if s > ab.HIGHLIGHT_SAT_MAX:
        v = min(v, hi - 0.01)
    v = max(v, lo + 0.01)
    return _hex(colorsys.hsv_to_rgb(h, s, v), alpha)


def mixc(a: str, b: str, t: float) -> tuple[float, float, float]:
    ra, rb = _rgb(a), _rgb(b)
    return tuple(x + (y - x) * t for x, y in zip(ra, rb))  # type: ignore[return-value]


def light(c: str, t: float, alpha: int = 255) -> str:
    """t > 0: toward the warm key light; t < 0: shadow, shifted toward the ambient hue."""
    if t >= 0:
        k = _rgb(SCENE.key)
        base = _rgb(c)
        rgb = tuple(min(1.0, x * (1 + 0.18 * t) * (1 - 0.35 * t + 0.35 * t * kk)) for x, kk in zip(base, k))
    else:
        u = -t
        rgb = tuple(x * (1 - 0.22 * u) for x in mixc(c, SCENE.ambient, 0.38 * u))
    return grade(_hex(rgb), alpha)  # type: ignore[arg-type]


SK = ab.CHARACTER["skin"]
HR = ab.CHARACTER["hair"]
SKIN_HI = light(SK[0], 0.35)
SKIN = grade(SK[0])
SKIN_SH = light(SK[1], -0.3)
SKIN_SH2 = light(SK[2], -0.45)
HAIR_HI = light(HR[0], 0.45)
HAIR_MID = grade(_hex(mixc(HR[0], HR[1], 0.55)))
HAIR = grade(HR[1])
HAIR_SH = light(HR[2], -0.25)
HAIR_LINE = grade("FF24181A", 0xD0)
HAIR_BOUNCE_L = grade(_hex(mixc(HR[0], SCENE.key, 0.6)), 0xE0)
HAIR_BOUNCE_R = grade(_hex(mixc(HR[0], SCENE.rim, 0.75)), 0xE8)
SHEEN = light(_hex(mixc(HR[0], "FFE8D2C2", 0.55)), 0.4)
IRIS_TOP = grade(ab.CHARACTER["iris"][1])
IRIS_MID = grade(ab.CHARACTER["iris"][0])
IRIS_BOT = light(ab.CHARACTER["iris"][0], 1.0)
PUPIL = grade("FF1C1424")
SCLERA = ab.CHARACTER["eyeWhite"][0]
SCLERA_SH = grade(_hex(mixc(ab.CHARACTER["eyeWhite"][1], SCENE.ambient, 0.25)))
INK = ab.CHARACTER["lineInk"][0]
LASH = grade("FF22171D")
LINE_SKIN = light(SK[2], -0.7)
CHEEK = grade(ab.CHARACTER["cheek"][0][2:], 0x48)
RIM = SCENE.rim
GLINT = "FFFFFBF2"
HOOD = light("FFE0B8CC", -0.05)
HOOD_SH = light("FFB98FB0", -0.3)
HOOD_INK = grade("FF6E4E66")
BG = ab.TOKENS["surface"]
BG_GLOW = grade(_hex(mixc(ab.TOKENS["surface"], SCENE.key, 0.16)))


def solid(c: str) -> El:
    return d("SolidColor", colorValue=c)


def F(c: str, feather: float | None = None) -> El:
    if feather:
        return d("Fill", solid(c), d("Feather", strength=float(feather)), fillRule="clockwise")
    return d("Fill", solid(c))


def L(c: str, w: float) -> El:
    return d("Stroke", solid(c), thickness=round(w, 2), cap="round", join="round")


def vfill(y0: float, y1: float, stops: list[tuple[str, float]], x: float = 0.0) -> El:
    return d("Fill", lin(d, x - OX, y0 - OY, x - OX, y1 - OY, stops))


def rfill(cx: float, cy: float, rr: float, stops: list[tuple[str, float]]) -> El:
    return d("Fill", rad(d, cx - OX, cy - OY, rr, stops))


# ------------------------------------------------------------------ rig

PROPS = r.CHANNELS  # yaw pitch roll gaze blink hairLag sideLag tuftLag brow mouth
VM_PROPS = {pn: d("ViewModelPropertyNumber", name=pn) for pn in PROPS}
VM_DEFAULT = d("ViewModelInstance",
               *[d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref()) for p in VM_PROPS.values()],
               exports=True, name="Default")
VM = d("ViewModel", *VM_PROPS.values(), VM_DEFAULT, name="HeadVM", defaultInstanceId=VM_DEFAULT.ref())


def vm_path(pn: str) -> str:
    return f"{VM.ref()}-{VM_PROPS[pn].ref()}"


RIG = r.Rig(d, vm_path, origin=HEAD_ORIGIN, x_axis=Axis("yaw", K_YAW), y_axis=Axis("pitch", K_PITCH),
            offset=(OX, OY))
SPECS: list[BoneSpec] = []


def mirror_x(x: float) -> float:
    return 2 * CX - x


def bone(name: str, x: float, y: float, z: float, zp: float | None = None, pose: tuple[float, float] | None = None,
         ddx: r.Poly | None = None, ddy: r.Poly | None = None) -> None:
    """A material point (x, y, depth z). `pose` = (x at yaw -1, x at yaw +1) overrides the yaw
    path (three-pose fit); `zp` is the depth used for pitch; ddx/ddy add token terms."""
    dx = fit3(pose[0] - x, 0.0, pose[1] - x, K_YAW) if pose else r.material_dx(x - CX, z)
    dy = r.pitch_dy(y - CY, (z if zp is None else zp) - ZP)
    SPECS.append(BoneSpec(name, x, y, r.poly_add(dx, ddx or []), r.poly_add(dy, ddy or [])))


def pair(name: str, x: float, y: float, z: float, zp: float | None = None,
         pose: tuple[float, float] | None = None, ddx: r.Poly | None = None, ddy: r.Poly | None = None,
         sym: r.Poly | None = None) -> None:
    """Right-side bone `name+R` at x (>= CX) and its mirror `name+L`. `pose` is for the right
    side; the left side mirrors it (its yaw -1 pose is the mirror of the right's yaw +1). `ddx`
    terms shift both sides the same way (lag); `sym` terms are mirrored (e.g. narrowing)."""
    bone(name + "R", x, y, z, zp, pose, r.poly_add(ddx or [], sym or []), ddy)
    lp = (mirror_x(pose[1]), mirror_x(pose[0])) if pose else None
    bone(name + "L", mirror_x(x), y, z, zp, lp, r.poly_add(ddx or [], r.poly_scale(sym or [], -1.0)), ddy)


def sil_pose(x: float, y: float, depth_ratio: float, zc: float) -> tuple[float, float]:
    """Yaw -1/+1 poses of the right silhouette of an elliptic cross-section (centre zc)."""
    w = x - CX
    dd = depth_ratio * w
    e = math.sqrt(w * w * math.cos(K_YAW) ** 2 + dd * dd * math.sin(K_YAW) ** 2)
    return CX + e - zc * math.sin(K_YAW), CX + e + zc * math.sin(K_YAW)


# --- face contour: three-pose silhouette (yaw -1 = this side near, +1 = this side far)
CONTOUR = {  # name: (front x, y, pitch depth, x at yaw -1, x at yaw +1) for the right side
    "T": (506.0, 330.0, 10.0, 504.0, 507.0),
    "S": (508.0, 366.0, 15.0, 505.0, 503.0),
    "C": (506.0, 396.0, 30.0, 502.0, 513.0),
    "K": (497.0, 428.0, 40.0, 491.0, 505.0),
    "J": (481.0, 458.0, 30.0, 477.0, 491.0),
    "W": (467.0, 476.0, 38.0, 456.0, 484.0),  # mid jaw: keeps the near jaw line convex
    "Q": (450.0, 490.0, 45.0, 424.0, 471.0),
}
# looking up narrows the jaw (no wide U): x pulls in by max(0, pitch) x px
JAW_NARROW = {"K": 3.0, "J": 7.0, "W": 7.0, "Q": 5.0}
for _n, (_x, _y, _z, _m, _p) in CONTOUR.items():
    pair("F" + _n, _x, _y, _z, pose=(_m, _p),
         sym=[(-JAW_NARROW[_n], (tokpos("pitch"),))] if _n in JAW_NARROW else None)
bone("Chin", 400.0, 511.0, 60.0, pose=(400.0 - 37.5, 400.0 + 37.5))
# under-jaw plane: same yaw path as the jaw, less depth for pitch (opens when looking up)
for _n, _x, _y, _zp, _src in (("UJR", 478.0, 456.0, 8.0, "J"), ("UQR", 448.0, 487.0, 16.0, "Q")):
    _c = CONTOUR[_src]
    bone(_n, _x, _y, 0.0, zp=_zp, pose=(_c[3] - (_c[0] - _x), _c[4] - (_c[0] - _x)))
    bone("U" + _n[1] + "L", mirror_x(_x), _y, 0.0, zp=_zp,
         pose=(mirror_x(_c[4] - (_c[0] - _x)), mirror_x(_c[3] - (_c[0] - _x))))
bone("UC", 400.0, 508.0, 0.0, zp=8.0, pose=(400.0 - 37.0, 400.0 + 37.0))

# --- face grid (brows, blush, chin light, forehead)
FGX = [300.0, 336.0, 370.0, 400.0, 430.0, 464.0, 500.0]
FGY = [316.0, 408.0]


def fg_name(c: int, rr: int) -> str:
    return f"G{c}{rr}"


for _r, _y in enumerate(FGY):
    for _c, _x in enumerate(FGX):
        # the brow row pitches with less depth than the lids, so looking down never frowns
        bone(fg_name(_c, _r), _x, _y, surface_z(_x - CX, _y), zp=66.0 if _r == 0 else None)
FACE_GRID = Grid(FGX, FGY, fg_name)

# --- eyes: 3 columns x 3 rows per eye; the top row (the lid edge) closes with `blink`
EYE_Y = [356.0, 374.0, 392.0]
EYE_Z = [82.0, 84.0, 50.0]  # inner, middle, outer (the outer canthus is recessed)
BLINK = [31.0, 38.0, 26.0]  # lid travel per column, upper lid -> lower lid
CORNER_DROP = [15.0, 4.0, 8.0]  # the corner row settles into the closed line (per column)
LOWER_RISE = -5.0  # the lower lid rises into the blink
EYE_CX = {"R": 448.0, "L": 352.0}


def eye_cols(t: str) -> list[float]:
    s = 1 if t == "R" else -1
    cx = EYE_CX[t]
    return [cx - 27 * s, cx, cx + 31 * s]


# Column x at yaw -1 / +1 for the RIGHT eye (left mirrors): the far eye keeps an almond whose
# outer half foreshortens most (cos of its longitude), the near eye stays about front width.
EYE_POSE = [(377.0, 459.0), (401.5, 481.5), (436.0, 494.0)]


def eye_pose(t: str, x: float) -> tuple[float, float]:
    """Yaw -1/+1 x of any point on eye `t` (piecewise linear between the authored columns)."""
    s = 1 if t == "R" else -1
    xr = x if s > 0 else mirror_x(x)
    cols = eye_cols("R")
    k = 0 if xr <= cols[1] else 1
    u = (xr - cols[k]) / (cols[k + 1] - cols[k])
    m = EYE_POSE[k][0] + u * (EYE_POSE[k + 1][0] - EYE_POSE[k][0])
    p = EYE_POSE[k][1] + u * (EYE_POSE[k + 1][1] - EYE_POSE[k][1])
    return (m, p) if s > 0 else (mirror_x(p), mirror_x(m))


for _t in ("R", "L"):
    _s = 1 if _t == "R" else -1
    for _c, _x in enumerate(eye_cols(_t)):
        for _r, _y in enumerate(EYE_Y):
            ddy = [((BLINK[_c], CORNER_DROP[_c], LOWER_RISE)[_r], (tok("blink"),))]
            bone(f"E{_t}{_c}{_r}", _x, _y, EYE_Z[_c], pose=eye_pose(_t, _x), ddy=ddy)
    for _c, _x in enumerate((EYE_CX[_t] - 17 * _s, EYE_CX[_t] + 17 * _s)):
        bone(f"I{_t}{_c}", _x, 371.0, 88.0, pose=eye_pose(_t, _x), ddx=[(13.0, (tok("gaze"),))])
    # brows: own bones so they can act (raise on a look)
    for _c, (_x, _y, _dy) in enumerate(((EYE_CX[_t] - 26 * _s, 321.0, -7.0), (EYE_CX[_t] + 28 * _s, 323.0, -4.0))):
        bone(f"Bw{_t}{_c}", _x, _y, surface_z(_x - CX, _y) - 4, zp=66.0, ddy=[(_dy, (tok("brow"),))])


def eye_grid(t: str) -> Grid:
    cols = eye_cols(t)
    order = sorted(range(3), key=lambda i: cols[i])
    xs = [cols[i] for i in order]
    return Grid(xs, EYE_Y, lambda c, rr: f"E{t}{order[c]}{rr}")


def iris_chain(t: str) -> Chain:
    s = 1 if t == "R" else -1
    a = [(EYE_CX[t] - 17 * s, f"I{t}0"), (EYE_CX[t] + 17 * s, f"I{t}1")]
    return Chain(sorted(a), lambda x, y: x)


# --- nose, mouth
# the tip drifts out to the far cheek line at |yaw| = 1 (anime 3/4), the bridge and base less
bone("NB", 400.0, 404.0, 0.0, zp=surface_z(0, 404) + 6, pose=(329.0, 471.0))
bone("NT", 401.0, 430.0, 0.0, zp=112.0, pose=(309.0, 493.0))
bone("NS", 400.0, 434.0, 0.0, zp=surface_z(0, 434) - 2, pose=(322.0, 480.0))
bone("MC", 400.0, 470.0, 96.0, zp=114.0, ddy=[(1.0, (tok("mouth"),))])
pair("M", 421.0, 463.0, 86.0, zp=96.0, ddy=[(-3.5, (tok("mouth"),))])
# --- ears: front and back edge at different depths (width follows yaw); pitch counter-moves
pair("EaF", 503.0, 378.0, -8.0, zp=-48.0)
pair("EaB", 527.0, 378.0, -44.0, zp=-48.0)

# --- hair shell grid (material points), fringe-tip row trails with `hairLag`
HGX = [276.0, 338.0, 400.0, 462.0, 524.0]
HGY = [196.0, 250.0, 300.0, 350.0]


def hg_name(c: int, rr: int) -> str:
    return f"H{c}{rr}"


for _r, _y in enumerate(HGY):
    for _c, _x in enumerate(HGX):
        if _r < 3:
            _z = shell_z(_x - CX, _y)
            bone(hg_name(_c, _r), _x, _y, _z)
        else:
            _z = max(surface_z(_x - CX, _y), shell_z(_x - CX, _y) - 30) + 10
            bone(hg_name(_c, _r), _x, _y, _z, ddx=[(11.0, (tok("hairLag"),))])
HAIR_GRID = Grid(HGX, HGY, hg_name)
bone("Aho", 412.0, 156.0, 4.0, ddx=[(34.0, (tok("tuftLag"),))])  # crown tuft: its own looser follower

# --- hair silhouette (three-pose: the away side widens, the toward side narrows)
SIL_R = [(400.0, 192.0), (472.0, 205.0), (515.0, 244.0), (531.0, 300.0), (532.0, 362.0), (525.0, 420.0),
         (512.0, 470.0)]
SIL_LAG = [0, 0, 0, 0, 3, 9, 16]
for _i, (_x, _y) in enumerate(SIL_R):
    if _i == 0:  # crown top: only the cranium's offset behind the yaw axis moves it
        _zs = HAIR_C[1] * math.sin(K_YAW)
        bone("S0", _x, _y, HAIR_C[1], pose=(CX - _zs, CX + _zs))
        continue
    pair(f"S{_i}", _x, _y, HAIR_C[1], pose=sil_pose(_x, _y, 1.16, HAIR_C[1]),
         ddx=[(float(SIL_LAG[_i]), (tok("sideLag"),))] if SIL_LAG[_i] else None)

# --- side locks: 2 columns x 3 rows per side, lower rows trail
SLX = [492.0, 522.0]
SLY = [300.0, 386.0, 462.0]
SL_LAG = [0.0, 9.0, 20.0]
# One lock per side, morphing with yaw: on the near side it covers more cheek, on the far side
# it slides out beyond the cheek contour (6+ px clear), so the contour shows without any fade.
SL_POSE = [[(480.0, 520.0), (480.0, 520.0), (484.0, 514.0)], [(542.0, 521.0), (542.0, 521.0), (538.0, 516.0)]]
for _c, _x in enumerate(SLX):
    for _r, _y in enumerate(SLY):
        pair(f"K{_c}{_r}", _x, _y, 0.0, zp=40.0 - 30.0 * _c - 8.0 * _r, pose=SL_POSE[_c][_r],
             ddx=[(SL_LAG[_r], (tok("sideLag"),))] if SL_LAG[_r] else None)


def side_grid(side: str) -> Grid:
    xs = SLX if side == "R" else [mirror_x(SLX[1]), mirror_x(SLX[0])]
    return Grid(xs, SLY, (lambda c, rr: f"K{c}{rr}R") if side == "R" else (lambda c, rr: f"K{1 - c}{rr}L"))


# ------------------------------------------------------------------ weight functions

CONTOUR_ORDER = ["FTL", "FSL", "FCL", "FKL", "FJL", "FWL", "FQL", "Chin", "FQR", "FWR", "FJR", "FKR", "FCR", "FSR",
                 "FTR"]


def _face_ang(x: float, y: float) -> float:
    a = math.degrees(math.atan2(y - 400, x - 400))
    return a + 360 if a < -90 else a


def _anchor_param(name: str) -> float:
    b = next(s for s in SPECS if s.name == name)
    return _face_ang(b.x, b.y)


FACE_CHAIN = Chain(sorted((_anchor_param(n), n) for n in CONTOUR_ORDER), lambda x, y: _face_ang(x, y))
UNDER_CHAIN = Chain(sorted((_face_ang(b.x, b.y), b.name) for b in SPECS if b.name in ("UJL", "UQL", "UC", "UQR", "UJR")),
                    lambda x, y: _face_ang(x, y))


def _sil_ang(x: float, y: float) -> float:
    return math.degrees(math.atan2(x - CX, -(y - HAIR_C[0])))  # 0 at the top, +right, -left


SIL_ANCHORS = sorted([(_sil_ang(b.x, b.y), b.name) for b in SPECS if b.name.startswith("S")])
SIL_CHAIN = Chain(SIL_ANCHORS, _sil_ang)


def w_face(x: float, y: float) -> Weights:
    """Face outline: contour chain below the temples, hair shell grid above (under the hair)."""
    if y >= 330:
        return FACE_CHAIN(x, y)
    t = min(1.0, (330 - y) / 30)
    return mix((1 - t, FACE_CHAIN(x, y)), (t, HAIR_GRID(x, y)))


def w_head(_x: float, _y: float) -> Weights:
    return {"Head": 1.0}


w_neck = None  # the neck and collar never move: unskinned


def w_nose(x: float, y: float) -> Weights:
    t = min(1.0, max(0.0, (y - 402) / 26))
    return {"NB": 1 - t, "NT": t}


def w_mouth(x: float, _y: float) -> Weights:
    """Quadratic falloff centre -> corner, so a pitch bend stays a smooth arc (no kink)."""
    u = min(1.0, abs(x - CX) / 21.0) ** 2
    return {"MC": 1 - u, ("MR" if x >= CX else "ML"): u}


MOUTH_CHAIN = w_mouth
EAR_CHAIN = {"R": Chain([(503.0, "EaFR"), (527.0, "EaBR")], lambda x, y: x),
             "L": Chain([(mirror_x(527.0), "EaBL"), (mirror_x(503.0), "EaFL")], lambda x, y: x)}


# ------------------------------------------------------------------ parts

SKIN_R = r.Skinner(RIG)


class Part:
    def __init__(self, shape: El, tags: tuple[str, ...]) -> None:
        self.shape, self.tags = shape, tags


PARTS: list[Part] = []


def part(name: str, pts: list[Pt], wf: object, *paints: El | None, closed: bool = True, tension: float = 1.0,
         clip: El | None = None, tags: tuple[str, ...] = ()) -> El:
    kids = [d("ClippingShape", sourceId=clip.ref())] if clip is not None else []
    path = SKIN_R.path(pts, wf, closed, tension)  # type: ignore[arg-type]
    shape = d("Shape", *kids, path, *[p for p in paints if p is not None], x=0.0, y=0.0, name=name)
    PARTS.append(Part(shape, tags))
    return shape


def ell(cx: float, cy: float, w: float, h: float, n: int = 8) -> list[Pt]:
    return [(cx + w / 2 * math.cos(2 * PI * k / n), cy + h / 2 * math.sin(2 * PI * k / n)) for k in range(n)]


def mirror(pts: list[Pt]) -> list[Pt]:
    return [(mirror_x(p[0]), p[1]) + tuple(p[2:]) for p in reversed(pts)]  # type: ignore[misc]


FACE_FILL_STOPS: list[tuple[str, float]] = [(SKIN_HI, 0.0), (SKIN, 0.45), (light(SK[1], -0.05), 1.0)]


def face_fill() -> El:
    """The face's world-space radial light (shared by the face and the eyelids)."""
    return rfill(352, 326, 250, FACE_FILL_STOPS)


def brow_chain(t: str) -> Chain:
    s = 1 if t == "R" else -1
    a = [(EYE_CX[t] - 26 * s, f"Bw{t}0"), (EYE_CX[t] + 28 * s, f"Bw{t}1")]
    return Chain(sorted(a), lambda x, y: x)


def eye(t: str) -> dict[str, list[El]]:
    s = 1 if t == "R" else -1
    cx = EYE_CX[t]
    i, o = cx - 27 * s, cx + 31 * s
    g = eye_grid(t)
    ic = iris_chain(t)
    white_pts: list[Pt] = [(i + 2 * s, 375), (cx - 15 * s, 354), (cx + 6 * s, 349), (o - 8 * s, 354), (o - 2 * s, 370),
                           (cx + 14 * s, 388), (cx - 8 * s, 391)]
    white = part("White" + t, white_pts, g, F(SCLERA), tags=("feature",))
    lid_shadow = part("LidShade" + t, clockwise([(i - 2 * s, 372), (cx - 15 * s, 351), (cx + 6 * s, 346),
                                                 (o - 4 * s, 351), (o + 2 * s, 368), (o - 8 * s, 364),
                                                 (cx + 6 * s, 357), (cx - 15 * s, 361)]),
                      g, F(SCLERA_SH, 4.0), clip=white)
    top: list[tuple[float, float]] = [(i - 1 * s, 375), (cx - 17 * s, 349), (cx + 5 * s, 342), (o - 1 * s, 347),
                                      (o + 9 * s, 361)]
    bottom: list[tuple[float, float]] = [(o + 1 * s, 359), (cx + 6 * s, 352), (cx - 15 * s, 357), (i + 4 * s, 376)]
    lash: list[Pt] = [(*top[0], "c"), *top[1:4], (*top[4], "c"), *bottom[:3], (*bottom[3], "c")]
    # eyelid: zero area at rest; its lower edge rides the lash down, its top stays on the skin
    lid: list[Pt] = [(*top[0], "c"), *top[1:4], (*top[4], "c"), *bottom[:3], (*bottom[3], "c")]
    lid_w = [FACE_GRID] * 5 + [g] * 4
    top_layer = [
        part("Lash" + t, lash, g, F(LASH), tags=("feature",)),
        part("Crease" + t, taper([(cx - 15 * s, 337), (cx + 6 * s, 332), (o + 2 * s, 340)], W_DET * 1.15, 0.1),
             FACE_GRID, F(light(SK[2], -0.4, 0xA8))),
    ]
    lid_el = part("Lid" + t, lid, lid_w, face_fill())
    kids = [
        part("LowLid" + t, taper([(cx - 1 * s, 394), (cx + 15 * s, 392), (o - 1 * s, 382)], W_DET * 1.3, 0.1), g,
             F(light(SK[2], -0.6, 0xC0))),
        part("Glint" + t, ell(cx - 8, 358, 11, 10, 6), ic, F(GLINT), clip=white),
        part("Glint2" + t, ell(cx + 9, 383, 5, 5, 6), ic, F(_hex(_rgb(GLINT), 0xC8)), clip=white),
        part("Pupil" + t, ell(cx, 372, 14, 18, 6), ic, F(PUPIL), clip=white),
        part("IrisGlow" + t, clockwise(ell(cx + 1, 383, 26, 12, 6)), ic, F(_hex(_rgb(IRIS_BOT), 0xB0), 4.0),
             clip=white),
        part("Iris" + t, ell(cx, 371, 36, 42), ic,
             vfill(350, 392, [(IRIS_TOP, 0.0), (IRIS_TOP, 0.28), (IRIS_MID, 0.62), (IRIS_BOT, 1.0)]),
             L(grade("FF1E1626"), 1.8), clip=white),
        lid_shadow,
        white,
    ]
    brow = part("Brow" + t, [(cx - 30 * s, 327, "c"), (cx - 8 * s, 318.5), (cx + 16 * s, 318), (cx + 34 * s, 326, "c"),
                             (cx + 16 * s, 322), (cx - 8 * s, 322.5)], brow_chain(t), F(HAIR_MID), tags=("feature",))
    return {"top": top_layer, "lid": [lid_el], "eye": kids, "brow": [brow]}


def lock(name: str, root: tuple[float, float], tip: tuple[float, float], w: float, bend: float, wf: object) -> list[El]:
    """A hair lock from a rounded root (tucked into the crown) to a pointed tip, with a strand."""
    (rx, ry), (tx, ty) = root, tip
    dx, dy = tx - rx, ty - ry
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln

    def at(t: float, off: float) -> tuple[float, float]:
        bow = math.sin(math.pi * t) * bend
        return (rx + dx * t + nx * (off + bow), ry + dy * t + ny * (off + bow))

    pts: list[Pt] = [at(-0.05, 0), at(0.04, -w * 0.46), at(0.42, -w * 0.48), at(0.78, -w * 0.26),
                     (tx + nx * bend * 0.12, ty, "c"), at(0.8, w * 0.14), at(0.46, w * 0.46), at(0.04, w * 0.46)]
    base = part(name, pts, wf, hair_fill(), hair_line(), tags=("hair",))
    # sheen: a leaf of light on every lock where the crown turns toward the key light; together
    # they read as the broken "angel ring"
    lit = max(0.25, 1.0 - max(0.0, (rx - 360) / 160))
    glint = part(name + "Gl", taper([at(0.1, -w * 0.08), at(0.24, -w * 0.12), at(0.42, -w * 0.1)], w * 0.2, 0.1),
                 wf, F(_hex(_rgb(SHEEN), int(0xA8 * lit)), 1.5), clip=base)
    return [glint, base]


def hair_line() -> El:
    """Lock outlines fade out toward the crown, so the crown reads as one mass."""
    return d("Stroke", lin(d, 0.0, 200 - OY, 0.0, 300 - OY, [(_hex(_rgb(HAIR_LINE), 0x20), 0.0),
                                                            (HAIR_LINE, 1.0)]),
             thickness=round(W_DET, 2), cap="round", join="round")


def hair_fill() -> El:
    """One world-space vertical ramp for every front hair shape, so overlaps never seam."""
    return rfill(342, 196, 300, [(HAIR_MID, 0.0), (HAIR, 0.5), (HAIR_SH, 1.0)])


# fringe: (root, tip, width, bend) - near-symmetric so yaw 0 reads frontal; roots fan out
# from the crown, so the whole crown is made of skinned locks
FRINGE: list[tuple[tuple[float, float], tuple[float, float], float, float]] = [
    ((394, 206), (380, 348), 46, -9), ((406, 206), (424, 340), 44, 8),
    ((372, 210), (338, 330), 50, -12), ((428, 210), (463, 338), 52, 11),
    ((350, 220), (309, 356), 44, -13), ((450, 220), (490, 346), 42, 10),
    ((328, 238), (292, 374), 34, -8), ((472, 238), (508, 368), 34, 9),
]
FRINGE_ORDER = [0, 1, 2, 3, 4, 5, 6, 7]


def w_hair(x: float, y: float) -> Weights:
    return HAIR_GRID(x, y)


def w_cap(x: float, y: float) -> Weights:
    """Hair cap: silhouette chain on the outer rim, shell grid inside."""
    dxn = (x - CX) / HAIR_A[0]
    dyn = (y - HAIR_C[0]) / HAIR_A[1]
    rr = math.hypot(dxn, dyn)
    t = min(1.0, max(0.0, (rr - 0.80) / 0.15))
    return mix((t, SIL_CHAIN(x, y)), (1 - t, HAIR_GRID(x, y)))


def w_side(side: str) -> object:
    g = side_grid(side)

    def f(x: float, y: float) -> Weights:
        return g(x, y)
    return f


def w_back(x: float, y: float) -> Weights:
    if y > 440 and abs(x - CX) < 90:
        return {"Head": 1.0}
    return SIL_CHAIN(x, y)


FRINGE_SHADE_PTS: list[Pt] = clockwise([(296, 374), (314, 358), (340, 344), (360, 342), (382, 354), (400, 348),
                                        (420, 354), (440, 342), (462, 344), (486, 358), (506, 374), (506, 292),
                                        (296, 292)])


def build() -> list[El]:
    # ---- skeleton
    face_bones = [RIG.bone(s) for s in SPECS]
    roll_conv = RIG.angle(Axis("roll", K_ROLL))
    head_el = d("Bone", *face_bones,
                d("DataBindContext", sourcePathIds=vm_path("roll"), propertyKey=15, converterId=roll_conv.ref()),
                length=HEAD_ORIGIN[1] - 200.0, rotation=0.0, name="Head")
    neck_el = d("RootBone", head_el, x=NECK_BASE[0] - OX, y=NECK_BASE[1] - OY, rotation=-PI / 2,
                length=NECK_BASE[1] - HEAD_ORIGIN[1], name="Neck")
    RIG.add_static("Head", head_el, *HEAD_ORIGIN, rot=-PI / 2)
    RIG.add_static("Neck", neck_el, *NECK_BASE, rot=-PI / 2)

    # ---- face
    face_pts: list[Pt] = [(306, 300), (334, 254), (400, 238), (466, 254), (494, 300)]
    for n in reversed(CONTOUR_ORDER):
        b = next(s for s in SPECS if s.name == n)
        face_pts.append((b.x, b.y))
    face_pts = face_pts[:5] + face_pts[5:]
    face = part("Face", face_pts, w_face,
                *((F("FF00FF00"),) if VARIANT == "hair" else (face_fill(), L(INK, W_SIL * 0.85))), tags=("face",))
    # form light: a terminator on the side away from the key (right) that deepens as that cheek
    # turns away, and an ambient-tinted one on the left cheek when it becomes the far side
    form_pts: list[Pt] = [(482, 300), (510, 330), (520, 400), (500, 470), (452, 520), (420, 520), (470, 462),
                          (488, 400), (476, 336)]
    terminator = {
        "R": (clockwise(form_pts), light(SK[1], -0.45, 0xB0),
              [0.3, "+", 0.7, "*"], (0.3, 1.0)),
        "L": (clockwise(mirror(form_pts)), grade(_hex(mixc(SK[1], SCENE.ambient, 0.35)), 0x90),
              [0.0, "-", 0.85, "*"], (0.0, 0.85)),
    }

    def form_layer(t: str, name: str, clip: El) -> El:
        pts, col, (c0, op, c1, _), (lo, hi) = terminator[t]
        conv = d("DataConverterFormula", *RIG.f.fn("min", [RIG.f.val(hi)], RIG.f.fn(
            "max", [RIG.f.val(lo)], [RIG.f.val(c0), RIG.f.op(op), RIG.f.val(c1), RIG.f.op("*"), *RIG.f.inp()])))
        RIG.converters.append(conv)
        shp = part(name + t, pts, w_face, F(col, 14.0), clip=clip)
        shp.add(d("DataBindContext", sourcePathIds=vm_path("yaw"), propertyKey=18, converterId=conv.ref()))
        return shp

    forms = [form_layer(t, "FormShade", face) for t in ("R", "L")]
    rim = part("Rim", taper([(504, 334), (507, 366), (505, 396), (496, 427), (480, 456)], 2.6, 0.12), w_face,
               F(_hex(_rgb(RIM), 0xA0)), clip=face)
    fringe_shadow = part("FringeShade", FRINGE_SHADE_PTS, w_hair, F(light(SK[2], -0.5, 0x68), 8.0), clip=face)
    blush = [part("Blush" + t, clockwise(ell(x, 404, 54, 22)), FACE_GRID, F(CHEEK, 6.0), clip=face)
             for t, x in (("L", 340.0), ("R", 460.0))]
    blush += [part(f"Hatch{t}{k}", taper([(x + 8 * k - 4, 410), (x + 8 * k + 3, 398)], 1.8, 0.2), FACE_GRID,
                   F(grade(_hex(mixc(ab.CHARACTER["cheek"][0][2:], SK[2], 0.7)), 0xD0)))
              for t, x in (("L", 334.0), ("R", 454.0)) for k in range(2)]
    chin_light = part("ChinLight", taper([(388, 499), (400, 502), (412, 499)], 2.0, 0.2), FACE_CHAIN,
                      F(_hex(_rgb(SKIN_HI), 0x90)), clip=face)
    under_jaw = part("UnderJaw", [(318, 456), (350, 488), (400, 510), (450, 488), (482, 456),
                                  (478, 452), (448, 484), (400, 505), (352, 484), (322, 452)],
                     [FACE_CHAIN] * 5 + [UNDER_CHAIN] * 5, F(light(SK[2], -0.55)), tags=("face",))

    # ---- ears (2 bones each: width follows yaw)
    ear: list[Pt] = [(301, 356), (284, 344), (273, 362), (276, 392), (290, 414), (303, 408)]
    ear_in: list[Pt] = [(297, 370), (287, 362), (284, 380), (292, 396)]
    ears = []
    for t, pts, pin in (("L", ear, ear_in), ("R", mirror(ear), mirror(ear_in))):
        ears += [part("EarIn" + t, taper(pin, W_INT, 0.2), EAR_CHAIN[t], F(LINE_SKIN, None)),
                 part("Ear" + t, pts, EAR_CHAIN[t], rfill(290 if t == "L" else 510, 370, 40,
                                                         [(SKIN, 0.0), (SKIN_SH, 1.0)]), L(INK, W_INT))]

    # ---- features
    eyes = {t: eye(t) for t in ("L", "R")}
    lids = d("Node", *eyes["L"]["lid"], *eyes["R"]["lid"], name="Lids")
    # the lids are skin in front of the eyes: they get the same shading overlays as the face
    # (clipped to the lids) so a closing lid never shows as a light patch
    lid_overlays = [form_layer(t, "LidForm", lids) for t in ("R", "L")]
    lid_overlays.append(part("LidFringeShade", FRINGE_SHADE_PTS, w_hair, F(light(SK[2], -0.5, 0x68), 8.0), clip=lids))
    nose = [
        part("NoseTip", taper([(395, 431), (401, 434), (407, 431)], 2.6, 0.25), w_nose, F(LINE_SKIN)),
        part("NoseShade", clockwise([(401, 404), (406, 424), (402, 433), (400, 431), (399, 414)]),
             lambda x, y: mix((0.5, w_nose(x, y)), (0.5, {"NS": 1.0})) if x < 401 and y > 420 else w_nose(x, y),
             F(light(SK[1], -0.4, 0x40), 2.5)),
        part("NoseLight", taper([(396, 410), (395, 421)], 2.2, 0.3), w_nose, F(_hex(_rgb(SKIN_HI), 0xB0))),
    ]
    mouth = [
        part("Mouth", taper([(379, 462), (389, 469), (400, 471), (411, 469), (421, 462)], W_INT * 1.2, 0.2),
             MOUTH_CHAIN, F(light(SK[2], -0.85))),
        part("Lip", taper([(394, 478), (400, 479.5), (406, 478)], 1.6, 0.2), MOUTH_CHAIN,
             F(light(SK[2], -0.3, 0x90))),
    ]

    # ---- hair
    locks: list[El] = []
    for k in FRINGE_ORDER:
        locks += lock(f"Fringe{k}", *FRINGE[k], w_hair)
    aho: list[El] = [
        part("Aho" + str(k), taper(pts, wdt, 0.12), lambda x, y: mix((min(1.0, (196 - y) / 36), {"Aho": 1.0}),
                                                                    (1 - min(1.0, (196 - y) / 36), HAIR_GRID(x, y)))
             if y < 196 else HAIR_GRID(x, y), F(HAIR_MID), L(HAIR_LINE, W_DET))
        for k, (pts, wdt) in enumerate([([(397, 210), (394, 186), (402, 164), (420, 152), (438, 154)], 8.0),
                                        ([(405, 210), (410, 192), (404, 176), (390, 170)], 5.5)])
    ]
    # side locks: one lock per side whose bones morph with yaw (see SL_POSE): over the near
    # cheek, beside the far one; nothing fades, so there is never a translucent ghost
    side_locks: list[El] = []
    side: list[Pt] = [(492, 288), (514, 296), (524, 350), (526, 412), (521, 452), (513, 478, "c"), (505, 446),
                      (499, 392), (494, 340)]
    for t, pts in (("R", side), ("L", mirror(side))):
        g = side_grid(t)
        sx = (lambda x: x) if t == "R" else mirror_x
        base = part("SideLock" + t, pts, g, hair_fill(), L(HAIR_LINE, W_DET), tags=("hair",))
        st = part("SideLockSt" + t, taper([(sx(509), 320), (sx(514), 380), (sx(512), 432)], 1.7, 0.1), g,
                  F(light(HR[0], 0.7, 0x68)), clip=base)
        side_locks += [st, base]
    cap_outer = [(280, 330), (285, 270), (318, 222), (400, 194), (482, 222), (515, 270), (520, 330)]
    cap_inner = [(500, 300), (470, 262), (400, 246), (330, 262), (300, 300)]
    cap = part("HairCap", cap_outer + cap_inner, w_cap, hair_fill(), L(HAIR_LINE, W_DET), tags=("hair",))
    hair_rim = part("HairRim", taper([(508, 250), (523, 290), (528, 340), (526, 390)], 2.2, 0.15), w_cap,
                    F(_hex(_rgb(RIM), 0x88)))
    # silhouette edge light so the side masses separate from the night background: warm key
    # bounce on the left, cool rim on the right (both from the scene script)
    edge = [(519, 244), (531, 300), (532, 362), (525, 420), (513, 462)]
    bounce = [
        part("BounceR", taper([(x - 1.5, y) for x, y in edge], 5.0, 0.15), SIL_CHAIN, F(HAIR_BOUNCE_R, 1.5)),
        part("BounceL", taper([(mirror_x(x) + 1.5, y) for x, y in edge], 5.0, 0.15), SIL_CHAIN,
             F(HAIR_BOUNCE_L, 1.5)),
    ]
    sil = [(b.x, b.y) for b in sorted((s for s in SPECS if s.name.startswith("S")), key=lambda s: _sil_ang(s.x, s.y))]
    back = [(288, 470, "c")] + sil[1:-1] + [(512, 470, "c"), (496, 458), (484, 470, "c"), (468, 452), (400, 446),
                                             (332, 452), (316, 470, "c"), (304, 458)]
    back_hair = part("BackHair", back, w_back, vfill(192, 470, [(HAIR, 0.0), (HAIR_SH, 0.5),
                                                                (light(HR[2], -0.5), 1.0)]),
                     L(INK, W_SIL * 0.8), tags=("hair",))

    # ---- neck + collar (static), chin shadow follows the jaw
    neck = part("Neck", [(371, 468), (429, 468), (431, 526), (446, 560), (400, 572), (354, 560), (369, 526)], w_neck,
                vfill(468, 566, [(light(SK[1], -0.45), 0.0), (SKIN_SH, 0.45), (light(SK[0], -0.12), 1.0)]),
                L(INK, W_INT), tags=("body",))
    neck_shade = part("NeckShade", clockwise([(360, 482), (440, 482), (440, 506), (400, 532), (360, 506)]),
                      lambda x, y: FACE_CHAIN(x, y - 18), F(light(SK[2], -0.5, 0xC0), 4.0), clip=neck)
    neck_hole = part("NeckHole", ell(400, 566, 104, 26), w_neck, F(light("FF8E6A88", -0.5)))
    collar = part("Collar", [(276, 652, "c"), (292, 598), (342, 562), (400, 578), (458, 562), (508, 598),
                             (524, 652, "c")], w_neck, vfill(560, 652, [(HOOD, 0.0), (HOOD_SH, 1.0)]),
                  L(HOOD_INK, W_INT), tags=("body",))
    collar_fold = part("CollarFold", taper([(318, 612), (350, 596), (372, 590)], 3.2, 0.2), w_neck,
                       F(_hex(_rgb(HOOD_SH), 0xA0)))

    front_to_back: list[El] = [
        *locks, *bounce, *side_locks, *aho, hair_rim, cap, *eyes["L"]["brow"], *eyes["R"]["brow"],
        *eyes["L"]["top"], *eyes["R"]["top"], *lid_overlays, lids, *eyes["L"]["eye"], *eyes["R"]["eye"],
        fringe_shadow, *forms, *nose, *mouth, chin_light, rim, *blush, face, under_jaw, *ears, neck_shade, neck,
        neck_hole, collar_fold, collar, back_hair,
    ]
    glow = d("Shape", d("Ellipse", width=520.0, height=520.0),
             d("Fill", rad(d, 0.0, 0.0, 260.0, [(BG_GLOW, 0.0), (_hex(_rgb(BG_GLOW), 0), 1.0)])),
             x=150.0, y=150.0, name="Glow")
    bg = d("Fill", solid("FFFF00FF" if VARIANT == "hair" else BG))
    if VARIANT == "hair":  # check variant: hair over a flat green face on magenta (translucency sweep)
        for p in PARTS:
            nm = str(p.shape.attrs.get("name", ""))
            if not nm.startswith(HAIR_PARTS + ("Face",)) or nm.startswith("FringeShade"):
                p.shape.attrs["hidden"] = True
        glow.attrs["hidden"] = True
    sm = d("StateMachine", d("StateMachineLayer", d("AnyState", x=200.0, y=-120.0), d("ExitState", x=400.0, y=-120.0),
                             d("EntryState"), name="Pose"), name="Main")
    head_ab = d("Artboard", bg, *front_to_back, glow, neck_el, sm, isComponent=True, defaultStateMachineId=sm.ref(),
                viewModelId=VM.ref(), width=ART_W, height=ART_H, name="Head")
    return [head_ab, performed_turn(head_ab), *RIG.converters, VM]


# ------------------------------------------------------------------ performed turn

# five looks over a 7.2 s loop: blinks land on the first and the largest (2.8 s apart, then
# 4.4 s across the seam), the others act with brows and mouth only
TURN_TARGETS: list[tuple[float, float]] = [(0.0, 0.0), (0.6, 0.85), (2.0, 0.35), (3.4, -0.86), (4.7, -0.3),
                                           (5.6, 0.0)]
TURN_SECONDS = 7.2
# key tolerances in view-model units, each about 0.5 px at that channel's largest lever
# (px per unit: yaw ~50 at the nose, gaze 13, hairLag 11, sideLag 20, tuftLag 34, brow 7, mouth 3.5)
TOLERANCE = {"yaw": 0.01, "pitch": 0.015, "roll": 0.02, "gaze": 0.04, "blink": 0.02, "hairLag": 0.045,
             "sideLag": 0.025, "tuftLag": 0.015, "brow": 0.07, "mouth": 0.12}


def performed_turn(head_ab: El) -> El:
    ch = r.perform_turn(TURN_TARGETS, TURN_SECONDS)
    nums = {pn: d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=VM_PROPS[pn].ref(), name=pn)
            for pn in PROPS}
    inst = d("ViewModelInstance", *nums.values(), viewModelId=VM.ref(), exports=True, name="Turn")
    nested = d("NestedArtboard", inst, artboardId=head_ab.ref(), isStateful=True, x=0.0, y=0.0, name="Head")
    frames = len(ch["yaw"]) - 1
    tracks = [r.keyed(d, nums[pn], r.simplify(ch[pn], TOLERANCE[pn])) for pn in PROPS]
    anim = d("LinearAnimation", *tracks, duration=frames, fps=60, loopValue="loop", name="Turn")
    state = d("AnimationState", animationId=anim.ref(), x=0.0, y=120.0)
    sm = d("StateMachine", d("StateMachineLayer", d("AnyState", x=200.0, y=-120.0), d("ExitState", x=400.0, y=-120.0),
                             d("EntryState", d("StateTransition", stateToId=state.ref(), duration=0)), state,
                             name="Turn"), name="Main")
    return d("Artboard", d("Fill", solid(BG)), nested, anim, sm, defaultStateMachineId=sm.ref(), x=500.0, y=0.0,
             width=ART_W, height=ART_H, name="PerformedTurn")


RIVE_YAML = """name: head
main: Head
output: {dir: build}
logs: {file: build/rive.log, problems: build/problems.log}
exclude: ["review/**"]
"""


VARIANT = "full"
HAIR_PARTS = ("Fringe", "SideLock", "Aho", "HairCap", "HairRim", "Bounce", "BackHair")


def emit(out: Path = OUT, variant: str = "full") -> int:
    global VARIANT
    VARIANT = variant
    out.mkdir(parents=True, exist_ok=True)
    write(str(out / "head.rml"), build())
    (out / "rive.yaml").write_text(RIVE_YAML)
    return SKIN_R.vertices


def main(argv: list[str]) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--variant", default="full", choices=("full", "hair"))
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args(argv)
    n = emit(args.out, args.variant)
    if args.out != OUT:
        return
    print(f"wrote {OUT / 'head.rml'}: {len(RIG.bones)} bones, {len(RIG.binds)} binds, "
          f"{len(RIG.converters)} converters, {n} vertices")
    if args.build:
        res = subprocess.run(["rive", str(OUT), "--once"], capture_output=True, text=True)
        print((res.stdout + res.stderr).strip().splitlines()[-1])
        riv = OUT / "build" / "head.riv"
        if riv.exists():
            print(f"{riv.stat().st_size} B")


if __name__ == "__main__":
    main(sys.argv[1:])
