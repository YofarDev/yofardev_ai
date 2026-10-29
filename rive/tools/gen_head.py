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
from rig_dsl import Axis, DriveSpec, Chain, Grid, Pt, Weights, clockwise, fit3, mix, taper, tok, tokpos  # noqa: E402
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
HAIR_BOUNCE_L = grade(_hex(mixc(HR[0], SCENE.key, 0.55)))
HAIR_BOUNCE_R = grade(_hex(mixc(HR[0], SCENE.rim, 0.7)))
HAIR_SIDE = grade(_hex(mixc(HR[0], HR[1], 0.7)))  # side masses one step lighter than HAIR
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
# --- identity: the shipped avatar's own colours (rive/tools/avatar_kit.py), graded into the
# livingRoom script (value <= 0.91, saturation <= 0.60), so lint stays clean
IRIS_A = grade("FFB0702F")  # amber centre
IRIS_B = grade("FF5A3317")  # brown rim
IRIS_RING = grade("FF2B1A12")
AV_PUPIL = grade("FF1E120C")
AV_LASH = grade("FF2A1B18")
FRAME = "FF1F1C20"  # glasses rim
HINGE = grade("FFC8BDAD")
LENS = grade(_hex(mixc("FFB8D8F0", SCENE.rim, 0.3)), 0x16)
GLARE = "40FFFFFF"
MOLE = grade("FF5A3A32")
AV_HAIR_HI = grade("FF795448")
AV_HAIR = grade("FF3B2A26")
AV_HAIR_SH = grade("FF2A1D1A")
KEY_EDGE = grade(_hex(mixc(SCENE.key, "FF795448", 0.15)))  # warm key on the lit hair edge
RIM_EDGE = grade(_hex(mixc(SCENE.rim, "FFFFFFFF", 0.5)))  # cool rim, lifted to read on the teal wall


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
SPECS: list[DriveSpec] = []


def mirror_x(x: float) -> float:
    return 2 * CX - x


def bone(name: str, x: float, y: float, z: float, zp: float | None = None, pose: tuple[float, float] | None = None,
         ddx: r.Poly | None = None, ddy: r.Poly | None = None) -> None:
    """A material point (x, y, depth z). `pose` = (x at yaw -1, x at yaw +1) overrides the yaw
    path (three-pose fit); `zp` is the depth used for pitch; ddx/ddy add token terms."""
    dx = fit3(pose[0] - x, 0.0, pose[1] - x, K_YAW) if pose else r.material_dx(x - CX, z)
    dy = r.pitch_dy(y - CY, (z if zp is None else zp) - ZP)
    SPECS.append(DriveSpec(name, x, y, r.poly_add(dx, ddx or []), r.poly_add(dy, ddy or [])))


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


# --- face contour on ONE surface model: each height is an elliptic section (half width w from
# the avatar outline, half depth 0.82 w + 8 with a soft cheekbone swell, centre z0 moving forward
# toward the chin). Far/near poses are its exact silhouettes, so the jaw stays smooth at |yaw| = 1.
Z0 = [(330.0, 8.0), (366.0, 10.0), (396.0, 14.0), (428.0, 22.0), (458.0, 32.0), (476.0, 40.0), (490.0, 46.0),
      (505.0, 54.0), (511.0, 58.0)]


def _lerp_table(table: list[tuple[float, float]], y: float) -> float:
    if y <= table[0][0]:
        return table[0][1]
    for (y0, v0), (y1, v1) in zip(table, table[1:]):
        if y <= y1:
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
    return table[-1][1]


def contour_pose(x: float, y: float) -> tuple[float, float]:
    """Right-side contour x at yaw -1 (near) and +1 (far) from the section model."""
    w = x - CX
    dd = 0.82 * w + 8 + 8 * math.exp(-(((y - 396) / 22) ** 2))
    e = math.sqrt((w * math.cos(K_YAW)) ** 2 + (dd * math.sin(K_YAW)) ** 2)
    z0 = _lerp_table(Z0, y)
    return CX + e - z0 * math.sin(K_YAW), CX + e + z0 * math.sin(K_YAW)


CONTOUR = {  # name: (front x, y, pitch depth) for the right side (the avatar outline)
    "T": (506.0, 330.0, 10.0), "S": (508.0, 366.0, 15.0), "C": (506.0, 396.0, 30.0), "K": (497.0, 428.0, 40.0),
    "J": (481.0, 458.0, 30.0), "W": (467.0, 476.0, 38.0), "Q": (450.0, 490.0, 45.0), "V": (426.0, 505.0, 55.0),
}
# looking up narrows the jaw (no wide U): x pulls in by max(0, pitch) x px, faded out by
# (1 - 4 sin^2 yaw), so looking up while turned never flattens the chin twice
JAW_NARROW = {"K": 3.0, "J": 7.0, "W": 7.0, "Q": 5.0, "V": 3.0}
for _n, (_x, _y, _z) in CONTOUR.items():
    pair("F" + _n, _x, _y, _z, pose=contour_pose(_x, _y),
         sym=[(-JAW_NARROW[_n], (tokpos("pitch"),)), (4 * JAW_NARROW[_n], (tokpos("pitch"), r.SIN, r.SIN))]
         if _n in JAW_NARROW else None)
_zc = _lerp_table(Z0, 511.0) * math.sin(K_YAW)
bone("Chin", 400.0, 511.0, 60.0, pose=(CX - _zc, CX + _zc))
# under-jaw plane: same yaw model, less depth for pitch (opens when looking up)
for _n, _x, _y, _zp in (("UJ", 478.0, 456.0, 8.0), ("UQ", 448.0, 487.0, 16.0)):
    pair(_n, _x, _y, 0.0, zp=_zp, pose=contour_pose(_x, _y))
bone("UC", 400.0, 508.0, 0.0, zp=8.0, pose=(CX - _lerp_table(Z0, 508.0) * 0.5, CX + _lerp_table(Z0, 508.0) * 0.5))

# --- face grid (lid tops, creases, cheek bloom, mole, forehead)
FGX = [300.0, 336.0, 370.0, 400.0, 430.0, 464.0, 500.0]
FGY = [336.0, 428.0]


def fg_name(c: int, rr: int) -> str:
    return f"G{c}{rr}"


for _r, _y in enumerate(FGY):
    for _c, _x in enumerate(FGX):
        bone(fg_name(_c, _r), _x, _y, surface_z(_x - CX, _y))
FACE_GRID = Grid(FGX, FGY, fg_name)

# --- eyes (the avatar's: centres 355 / 445, drawn at 1.06 about y 388): 3 columns x 3 rows,
# the top row (the lid edge) closes with `blink`
EYE_Y = [376.0, 393.0, 411.0]
EYE_Z = [82.0, 84.0, 50.0]  # inner, middle, outer (the outer canthus is recessed)
BLINK = [32.0, 40.0, 27.0]  # lid travel per column, upper lid -> lower lid
CORNER_DROP = [15.0, 4.0, 8.0]  # the corner row settles into the closed line (per column)
LOWER_RISE = -5.0  # the lower lid rises into the blink
EYE_CX = {"R": 445.0, "L": 355.0}
EYE_S = 1.06  # the avatar's eye scale (gen_avatar.build_eye)


def es(cx: float, x: float, y: float) -> tuple[float, float]:
    """Avatar eye coordinates -> drawn (scaled 1.06 about (cx, 388))."""
    return cx + (x - cx) * EYE_S, 388 + (y - 388) * EYE_S


def eye_cols(t: str) -> list[float]:
    s = 1 if t == "R" else -1
    cx = EYE_CX[t]
    return [es(cx, cx - 28 * s, 0)[0], cx, es(cx, cx + 30 * s, 0)[0]]


# Column x at yaw -1 / +1 for the RIGHT eye (left mirrors), from the eye surface (inner, middle
# and recessed outer canthus): the far eye keeps an almond whose outer half foreshortens most,
# the near eye stays about front width.
EYE_POSE = [(372.0, 454.0), (397.0, 481.0), (434.0, 492.0)]


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
        bone(f"I{_t}{_c}", _x, 388.0, 88.0, pose=eye_pose(_t, _x), ddx=[(13.0, (tok("gaze"),))])
    # brows: own bones so they act (a look raises them 12-14 px; the inner end more = arch)
    for _c, (_x, _y, _dy) in enumerate(((EYE_CX[_t] - 26 * _s, 339.0, -14.0), (EYE_CX[_t] + 30 * _s, 341.0, -12.0))):
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


# --- nose and mouth: material points of the same surface model (bridge, tip, base; mouth
# centre and corners), so all features slide together at 3/4. The anime nose protrudes ~35 px.
bone("NB", 400.0, 410.0, 108.0)
bone("NT", 401.0, 450.0, 134.0, zp=120.0)
bone("NS", 400.0, 454.0, 98.0)
bone("MC", 400.0, 480.0, 100.0, zp=112.0, ddy=[(1.5, (tok("mouth"),))])
pair("M", 417.0, 477.0, 92.0, zp=100.0, ddy=[(-5.0, (tok("mouth"),))],
     sym=[(4.0, (tok("mouth"),))])  # a smile widens the corners by 8 px
# --- ears: front and back edge at different depths (width follows yaw); pitch counter-moves
pair("EaF", 503.0, 396.0, -8.0, zp=-48.0)
pair("EaB", 527.0, 396.0, -44.0, zp=-48.0)
# --- glasses: a rigid frame in front of the eyes (bridge, lens middle, hinge) plus the temple
# end at the ear. The far temple folds onto its hinge (hidden by the head); the near one shows.
pair("GI", 404.0, 387.0, 110.0)
pair("GM", 445.0, 387.0, 104.0)
pair("GO", 488.0, 387.0, 86.0)
_hinge_far = CX + 88 * math.cos(K_YAW) + 86 * math.sin(K_YAW)
pair("GT", 504.0, 369.0, 0.0, zp=-20.0, pose=(CX + 104 * math.cos(K_YAW) + 20 * math.sin(K_YAW), _hinge_far))
GLASSES_CHAIN = Chain([(296.0, "GTL"), (312.0, "GOL"), (355.0, "GML"), (396.0, "GIL"), (404.0, "GIR"),
                       (445.0, "GMR"), (488.0, "GOR"), (504.0, "GTR")], lambda x, y: x)

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
bone("Aho", 422.0, 186.0, 6.0, ddx=[(30.0, (tok("tuftLag"),))])  # cowlick tips: their own looser follower

# --- hair silhouette (the avatar's back hair; three-pose: the away side widens)
SIL_R = [(400.0, 196.0), (466.0, 212.0), (516.0, 262.0), (528.0, 340.0), (514.0, 430.0), (534.0, 478.0)]
SIL_LAG = [0, 0, 0, 0, 6, 16]
for _i, (_x, _y) in enumerate(SIL_R):
    if _i == 0:  # crown top: only the cranium's offset behind the yaw axis moves it
        _zs = HAIR_C[1] * math.sin(K_YAW)
        bone("S0", _x, _y, HAIR_C[1], pose=(CX - _zs, CX + _zs))
        continue
    pair(f"S{_i}", _x, _y, HAIR_C[1], pose=sil_pose(_x, _y, 1.16, HAIR_C[1]),
         ddx=[(float(SIL_LAG[_i]), (tok("sideLag"),))] if SIL_LAG[_i] else None)

# --- side locks (the avatar's, in front of the ears down to the jaw): 2 columns x 3 rows,
# lower rows trail. One lock per side, morphing with yaw: over the near cheek, beside the far
# one and inside the hair silhouette, so the contour shows without any fade.
SLX = [486.0, 512.0]
SLY = [330.0, 400.0, 466.0]
SL_LAG = [0.0, 9.0, 20.0]
SL_POSE = [[(474.0, 514.0), (474.0, 516.0), (478.0, 502.0)], [(528.0, 521.0), (530.0, 521.0), (526.0, 512.0)]]
for _c, _x in enumerate(SLX):
    for _r, _y in enumerate(SLY):
        pair(f"K{_c}{_r}", _x, _y, 0.0, zp=40.0 - 30.0 * _c - 8.0 * _r, pose=SL_POSE[_c][_r],
             ddx=[(SL_LAG[_r], (tok("sideLag"),))] if SL_LAG[_r] else None)


def side_grid(side: str) -> Grid:
    xs = SLX if side == "R" else [mirror_x(SLX[1]), mirror_x(SLX[0])]
    return Grid(xs, SLY, (lambda c, rr: f"K{c}{rr}R") if side == "R" else (lambda c, rr: f"K{1 - c}{rr}L"))


# ------------------------------------------------------------------ weight functions

CONTOUR_ORDER = ["FTL", "FSL", "FCL", "FKL", "FJL", "FWL", "FQL", "FVL", "Chin", "FVR", "FQR", "FWR", "FJR", "FKR",
                 "FCR", "FSR", "FTR"]


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
    t = min(1.0, max(0.0, (y - 410) / 40))
    return {"NB": 1 - t, "NT": t}


def w_mouth(x: float, _y: float) -> Weights:
    """Quadratic falloff centre -> corner, so a pitch bend stays a smooth arc (no kink)."""
    u = min(1.0, abs(x - CX) / 17.0) ** 2
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
    a = [(EYE_CX[t] - 26 * s, f"Bw{t}0"), (EYE_CX[t] + 30 * s, f"Bw{t}1")]
    return Chain(sorted(a), lambda x, y: x)


def eye(t: str) -> dict[str, list[El]]:
    """The avatar's eye (gen_avatar.build_eye) on the eye grid: lash, lid, crease, lower lid,
    amber iris with ring, pupil and two shines, white with a soft lid shadow."""
    s = 1 if t == "R" else -1
    cx = EYE_CX[t]
    i, o = cx - 28 * s, cx + 30 * s

    def P(pts: list[Pt]) -> list[Pt]:
        return [es(cx, p[0], p[1]) + tuple(p[2:]) for p in pts]  # type: ignore[misc]

    g = eye_grid(t)
    ic = iris_chain(t)
    white = part("White" + t, P([(i, 390), (cx - 14 * s, 372), (cx + 6 * s, 368), (o - 6 * s, 374), (o, 392, "c"),
                                 (cx + 8 * s, 404), (cx - 12 * s, 403)]), g, F(SCLERA), tags=("feature",))
    lid_shadow = part("LidShade" + t, clockwise(P([(i - 2 * s, 389), (cx - 14 * s, 369), (cx + 6 * s, 365),
                                                   (o - 4 * s, 371), (o + 2 * s, 388), (o - 8 * s, 382),
                                                   (cx + 6 * s, 376), (cx - 14 * s, 380)])),
                      g, F(SCLERA_SH, 4.0), clip=white)
    top = P([(i - 3 * s, 393), (cx - 15 * s, 368), (cx + 6 * s, 363), (o - 2 * s, 369), (o + 9 * s, 384)])
    bottom = P([(o + 1 * s, 381), (cx + 6 * s, 373), (cx - 14 * s, 377), (i + 2 * s, 394)])
    lash: list[Pt] = [(*top[0][:2], "c"), *top[1:4], (*top[4][:2], "c"), *bottom[:3], (*bottom[3][:2], "c")]
    # eyelid: zero area at rest; its lower edge rides the lash down, its top stays on the skin
    lid_w = [FACE_GRID] * 5 + [g] * 4
    top_layer = [
        part("Lash" + t, lash, g, F(AV_LASH), tags=("feature",)),
        part("Crease" + t, taper(P([(cx - 12 * s, 360), (cx + 8 * s, 356), (o + 2 * s, 364)]), 2.0, 0.15),
             FACE_GRID, F(SKIN_SH2)),
    ]
    lid_el = part("Lid" + t, lash, lid_w, face_fill())
    kids = [
        part("LowLid" + t, taper(P([(i + 6 * s, 403), (cx - 8 * s, 406), (cx + 14 * s, 402)]), 2.0, 0.15), g,
             F(grade("FF3A2622", 0xB0))),
        part("Shine" + t, ell(*es(cx, cx - 7 * s - 1, 379), 10.6, 8.5, 6), ic, F(GLINT), clip=white),
        part("Shine2" + t, ell(*es(cx, cx + 7 * s, 397), 5.3, 5.3, 6), ic, F(_hex(_rgb(GLINT), 0xD0)), clip=white),
        part("Pupil" + t, ell(*es(cx, cx, 389), 14.8, 18.0, 6), ic, F(AV_PUPIL), clip=white),
        part("Iris" + t, ell(cx, 388, 34, 38), ic, rfill(cx, 396.5, 23.3, [(IRIS_A, 0.0), (IRIS_B, 1.0)]),
             L(IRIS_RING, 2.3), clip=white),
        lid_shadow,
        white,
    ]
    brow = part("Brow" + t, [(cx - 30 * s, 342, "c"), (cx - 8 * s, 335), (cx + 16 * s, 335), (cx + 36 * s, 344, "c"),
                             (cx + 16 * s, 341), (cx - 8 * s, 341)], brow_chain(t), F(AV_HAIR), tags=("feature",))
    return {"top": top_layer, "lid": [lid_el], "eye": kids, "brow": [brow]}


def lock(name: str, root: tuple[float, float], tip: tuple[float, float], w: float, bend: float, wf: object) -> list[El]:
    """The avatar's hair lock (gen_avatar.lock): base with a root-to-tip ramp, a satin ribbon
    and a strand, both clipped to the lock."""
    (rx, ry), (tx, ty) = root, tip
    dx, dy = tx - rx, ty - ry
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln

    def at(t: float, off: float) -> tuple[float, float]:
        bow = math.sin(math.pi * t) * bend
        return (rx + dx * t + nx * (off + bow), ry + dy * t + ny * (off + bow))

    pts: list[Pt] = [at(0, -w / 2), at(0.45, -w * 0.42), at(0.8, -w * 0.2), (tx + nx * bend * 0.1, ty, "c"),
                     at(0.78, w * 0.16), at(0.42, w * 0.44), at(0, w / 2)]
    ramp = d("Fill", lin(d, rx - OX, ry - OY, tx - OX, ty - OY, [(AV_HAIR_HI, 0.0), (AV_HAIR, 0.55),
                                                                 (AV_HAIR_SH, 1.0)]))
    base = part(name, pts, wf, ramp, L(AV_HAIR_SH, 1.5), tags=("hair",))
    ribbon = part(name + "Rb", [at(0.12, -w * 0.18), at(0.35, -w * 0.22), at(0.65, -w * 0.1), at(0.48, -w * 0.04),
                                at(0.26, -w * 0.05)], wf, F("35DBA27C"), clip=base)
    strand = part(name + "St", taper([at(0.18, w * 0.15), at(0.43, w * 0.2), at(0.72, w * 0.07)], 1.1, 0.2), wf,
                  F("30E6B28A"), clip=base)
    return [strand, ribbon, base]


# fringe: the avatar's locks (gen_avatar.LOCKS) and their front-to-back order
FRINGE: list[tuple[tuple[float, float], tuple[float, float], float, float]] = [
    ((300, 272), (292, 404), 44, -8), ((330, 246), (318, 366), 50, 12), ((360, 236), (350, 338), 50, 10),
    ((396, 230), (420, 368), 70, 18), ((436, 234), (452, 334), 52, 10), ((470, 248), (490, 376), 58, 9),
    ((498, 276), (510, 410), 40, 6), ((380, 236), (372, 318), 30, 6), ((452, 242), (474, 322), 28, 6)]
FRINGE_ORDER = [7, 8, 3, 2, 4, 1, 5, 0, 6]


def hair_line() -> El:
    """Lock outlines fade out toward the crown, so the crown reads as one mass."""
    return d("Stroke", lin(d, 0.0, 200 - OY, 0.0, 300 - OY, [(_hex(_rgb(HAIR_LINE), 0x20), 0.0),
                                                            (HAIR_LINE, 1.0)]),
             thickness=round(W_DET, 2), cap="round", join="round")


def hair_fill() -> El:
    """One world-space vertical ramp for every front hair shape, so overlaps never seam."""
    return rfill(342, 196, 300, [(HAIR_MID, 0.0), (HAIR_SIDE, 0.55), (HAIR, 1.0)])


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


# soft cast shadow of the fringe: just below the lock tips (avatar LOCKS), feathered
FRINGE_SHADE_PTS: list[Pt] = clockwise([(292, 414), (318, 376), (350, 348), (372, 328), (396, 350), (420, 378),
                                        (452, 344), (474, 332), (490, 386), (510, 420), (512, 300), (290, 300)])


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
    face_pts: list[Pt] = [(310, 262), (400, 222), (490, 262)]  # the avatar's crown (under the hair)
    for n in reversed(CONTOUR_ORDER):
        b = next(s for s in SPECS if s.name == n)
        face_pts.append((b.x, b.y))
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
    # the avatar's cheek bloom (soft, no hatching at rest) and the mole on the cheek surface
    blush = [part("Bloom" + t, clockwise(ell(x, 437, 65, 44)), FACE_GRID, F(grade("FFE99D91", 0x38), 10.0), clip=face)
             for t, x in (("L", 335.0), ("R", 465.0))]
    mole = part("Mole", ell(456, 432, 5, 5, 6), FACE_GRID, F(MOLE))
    chin_light = part("ChinLight", taper([(386, 497), (399, 501), (412, 497)], 2.5, 0.2), FACE_CHAIN,
                      F("40FFF5E1"), clip=face)
    under_jaw = part("UnderJaw", [(318, 456), (350, 488), (400, 510), (450, 488), (482, 456),
                                  (478, 452), (448, 484), (400, 505), (352, 484), (322, 452)],
                     [FACE_CHAIN] * 5 + [UNDER_CHAIN] * 5, F(light(SK[2], -0.55)), tags=("face",))

    # ---- ears (2 bones each: width follows yaw)
    ear: list[Pt] = [(300, 372), (282, 360), (272, 380), (278, 412), (292, 436), (304, 430)]  # the avatar's
    ear_in: list[Pt] = [(296, 384), (286, 378), (284, 396), (292, 414)]
    ears = []
    for t, pts, pin in (("L", ear, ear_in), ("R", mirror(ear), mirror(ear_in))):
        ears += [part("EarIn" + t, taper(pin, W_INT, 0.2), EAR_CHAIN[t], F(LINE_SKIN, None)),
                 part("Ear" + t, pts, EAR_CHAIN[t], rfill(290 if t == "L" else 510, 392, 40,
                                                         [(SKIN, 0.0), (SKIN_SH, 1.0)]), L(INK, W_INT))]

    # ---- features
    eyes = {t: eye(t) for t in ("L", "R")}
    lids = d("Node", *eyes["L"]["lid"], *eyes["R"]["lid"], name="Lids")
    # the lids are skin in front of the eyes: they get the same shading overlays as the face
    # (clipped to the lids) so a closing lid never shows as a light patch
    lid_overlays = [form_layer(t, "LidForm", lids) for t in ("R", "L")]
    lid_overlays.append(part("LidFringeShade", FRINGE_SHADE_PTS, w_hair, F(light(SK[2], -0.5, 0x68), 8.0), clip=lids))
    # the avatar's nose (hook line, shade, light) on bridge / tip / base bones; the base bone
    # opens a shadow-side plane at 3/4 and a profile line fades in along the bridge
    nose = [
        part("NoseLine", taper([(406, 446), (400, 454), (392, 452)], 3.0, 0.3), w_nose, F(SKIN_SH2)),
        part("NoseShade", clockwise([(404, 408), (410, 440), (406, 450), (398, 453), (402, 430)]),
             lambda x, y: {"NS": 1.0} if y > 451 else w_nose(x, y), F(light(SK[1], -0.3, 0xB0), 1.5)),
        part("NoseLight", taper([(397, 415), (395, 433)], 2.8, 0.3), w_nose, F(_hex(_rgb(SKIN_HI), 0xA0))),
    ]
    # the bridge line only reads at 3/4: opacity = clamp(2.2 |yaw| - 1.1)
    bridge_op = d("DataConverterFormula", *RIG.f.fn("min", [RIG.f.val(1)], RIG.f.fn("max", [RIG.f.val(0)], [
        RIG.f.val(2.2), RIG.f.op("*"), *RIG.f.fn("max", RIG.f.inp(), [RIG.f.val(-1), RIG.f.op("*"), *RIG.f.inp()]),
        RIG.f.op("-"), RIG.f.val(1.1)])))
    RIG.converters.append(bridge_op)
    nose.insert(0, part("NoseBridge", taper([(401, 412), (403, 428), (406, 444)], 2.0, 0.25), w_nose,
                        F(light(SK[2], -0.5, 0xB0))).add(
        d("DataBindContext", sourcePathIds=vm_path("yaw"), propertyKey=18, converterId=bridge_op.ref())))
    mouth = [  # the avatar's small neutral mouth
        part("Mouth", taper([(383, 477), (391, 479.4), (400, 480), (409, 479.4), (417, 477)], 2.9, 0.3), MOUTH_CHAIN,
             F(grade("FF3A2622"))),
    ]
    # ---- glasses (the avatar's): lenses, glare, bridge, hinges, temples, on the frame bones
    glasses: list[El] = []
    for t, cx in (("L", 355.0), ("R", 445.0)):
        lens = [(cx - 43, 364, "c12"), (cx + 43, 364, "c12"), (cx + 41, 410, "c14"), (cx - 41, 410, "c14")]
        glasses.append(part("Lens" + t, lens, GLASSES_CHAIN, F(LENS), L(FRAME, 4.2)))
    glasses = [
        part("Glare", [(330, 370, "c"), (346, 370, "c"), (322, 402, "c"), (310, 402, "c")], GLASSES_CHAIN, F(GLARE)),
        part("Glare2", [(420, 370, "c"), (436, 370, "c"), (412, 402, "c"), (402, 402, "c")], GLASSES_CHAIN, F(GLARE)),
        part("Bridge", [(398, 378), (400, 374), (402, 378)], GLASSES_CHAIN, L(FRAME, 5.0), closed=False),
        *[part("Hinge" + t, ell(x, 372, 5, 3, 4), GLASSES_CHAIN, F(HINGE)) for t, x in (("L", 314.0), ("R", 486.0))],
        *glasses,
    ]
    # temples run from the hinge back over the side hair to the ear (as on the avatar, in front of
    # the hair); the far one folds onto its hinge
    temples = [part("Temple" + t, pts, GLASSES_CHAIN, L(FRAME, 6.0), closed=False)
               for t, pts in (("L", [(311, 370), (296, 368)]), ("R", [(489, 370), (504, 368)]))]

    # ---- hair
    locks: list[El] = []
    for k in FRINGE_ORDER:
        locks += lock(f"Fringe{k}", *FRINGE[k], w_hair)
    # the avatar's two cowlick tufts: tips on their own looser follower (tuftLag)
    def w_tuft(x: float, y: float) -> Weights:
        t = min(1.0, max(0.0, (226 - y) / 40))
        return mix((t, {"Aho": 1.0}), (1 - t, HAIR_GRID(x, y)))

    aho: list[El] = [
        part("Cowlick", [(380, 232), (372, 206), (384, 186), (404, 180, "c"), (392, 196), (392, 214), (404, 230)],
             w_tuft, F(AV_HAIR), L(AV_HAIR_SH, 2.5)),
        part("Cowlick2", [(408, 230), (420, 204), (444, 194, "c"), (434, 210), (428, 232)], w_tuft, F(AV_HAIR),
             L(AV_HAIR_SH, 2.5)),
    ]
    # side locks: one lock per side whose bones morph with yaw (see SL_POSE): over the near
    # cheek, beside the far one; nothing fades, so there is never a translucent ghost
    side_locks: list[El] = []
    side: list[Pt] = [(500, 330), (512, 360), (510, 420), (504, 466, "c"), (492, 430), (486, 370)]  # the avatar's
    for t, pts in (("R", side), ("L", mirror(side))):
        g = side_grid(t)
        sx = (lambda x: x) if t == "R" else mirror_x
        base = part("SideLock" + t, pts, g, F(AV_HAIR), L(AV_HAIR_SH, 2.5), tags=("hair",))
        st = part("SideLockSt" + t, taper([(sx(500), 350), (sx(503), 400), (sx(500), 440)], 1.2, 0.2), g,
                  F("30E6B28A"), clip=base)
        side_locks += [st, base]
    cap_pts: list[Pt] = [(290, 340), (294, 270), (330, 232), (400, 214), (470, 232), (506, 270), (510, 340), (470, 300),
                         (400, 292), (330, 300)]  # the avatar's
    cap = part("HairCap", cap_pts, w_cap, vfill(217, 337, [(AV_HAIR_HI, 0.0), (AV_HAIR, 0.6)]), L(AV_HAIR_SH, 2.4),
               tags=("hair",))
    sil = [(b.x, b.y) for b in sorted((s for s in SPECS if s.name.startswith("S")), key=lambda s: _sil_ang(s.x, s.y))]
    # the avatar's back hair, every vertex on the silhouette chain (no static corner to stretch)
    back = [(*sil[0], "c")] + sil[1:-1] + [(*sil[-1], "c"), (500, 466), (488, 420), (312, 420), (300, 466)]
    back_hair = part("BackHair", back, SIL_CHAIN, F(AV_HAIR_SH), L(INK, W_SIL), tags=("hair",))
    # two-tone silhouette edge: a dark ink outline (separates from a lit wall) and, inside it, an
    # edge light (scene key warm on the left, rim cool on the right; separates from a dark window).
    # The light band sits ON the silhouette path and is clipped by the back hair, so it never
    # leaves the hair; it is drawn over the side locks and ear edges it crosses (they are inside
    # the silhouette), which is where a rim light lands
    edge = [(470, 214), (500, 236), (516, 262), (526, 300), (528, 340), (522, 390), (514, 430), (522, 456),
            (534, 478)]
    bounce = [
        part("BounceR", taper(edge, 12.0, 0.5), SIL_CHAIN, F(RIM_EDGE), clip=back_hair),
        part("BounceL", taper([(mirror_x(x), y) for x, y in edge], 12.0, 0.5), SIL_CHAIN, F(KEY_EDGE),
             clip=back_hair),
    ]

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
        *glasses, *temples, *eyes["L"]["brow"], *eyes["R"]["brow"], *locks, *bounce, cap, *side_locks,
        *eyes["L"]["top"], *eyes["R"]["top"], *lid_overlays, lids, *eyes["L"]["eye"], *eyes["R"]["eye"],
        fringe_shadow, *forms, *nose, *mouth, mole, chin_light, rim, *blush, face, under_jaw, *ears, *aho, back_hair, neck_shade, neck, neck_hole, collar_fold, collar,
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

# four looks over an 8 s loop, >= 1.6 s apart (MOTION.max_gesture_rate), then a 3 s listening
# hold across the seam; full blinks on the first and the largest look (3.2 s apart, 4.8 s
# across the seam), the others act with brows and mouth only
TURN_TARGETS: list[tuple[float, float]] = [(0.0, 0.0), (1.0, 0.85), (2.6, 0.3), (4.2, -0.84), (6.0, 0.0)]
TURN_SECONDS = 8.0
# key tolerances in view-model units, each about 0.5 px at that channel's largest lever
# (px per unit: yaw ~50 at the nose, gaze 13, hairLag 11, sideLag 20, tuftLag 34, brow 7, mouth 3.5)
TOLERANCE = {"yaw": 0.01, "pitch": 0.015, "roll": 0.03, "gaze": 0.04, "blink": 0.02, "hairLag": 0.045,
             "sideLag": 0.025, "tuftLag": 0.02, "brow": 0.07, "mouth": 0.12}


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


KEEP_NAMES = ("Face", "Lids", "Glow")


def strip_names(e: El) -> None:
    """Shape and face-bone names are authoring aids (the runtime reads only the view model):
    dropping them buys ~1.2 KB of the 80 KB budget. `Head`/`Neck` bones and nodes keep theirs."""
    if e.tag in ("Shape", "RootBone") and e.attrs.get("name") not in KEEP_NAMES + ("Neck",):
        e.attrs.pop("name", None)
    for c in e.children:
        strip_names(c)


VARIANT = "full"
HAIR_PARTS = ("Fringe", "SideLock", "Aho", "HairCap", "Bounce", "BackHair")


def emit(out: Path = OUT, variant: str = "full") -> int:
    global VARIANT
    VARIANT = variant
    out.mkdir(parents=True, exist_ok=True)
    roots = build()
    for root in roots:
        strip_names(root)
    write(str(out / "head.rml"), roots)
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
