"""The tablet prop (moonshot M4 Task 5, plan rulings 7, 8, 15): `prop` = tablet on its own layer.

Called by gen_avatar.py after the light rig; every element is minted from the M4 id range
(`avatar_kit.M4_ID_START`, after the light rig's last id), so no earlier id moves.

- Art: a landscape slab authored flat (`W` x `H`, corner `CORNER` = 0.2 of the short side, dark
  bezel, `emitScreen` gradient with generated search / weather / result glyphs) and projected by
  two nodes: `TabletPlane` (rotation + non-uniform scale) over `TabletFace` (rotation) are the SVD
  of the 2x2 affine projection of the slab tipped back `TILT`, turned `YAW` toward the face and
  rolled `ROLL` (an orthographic camera), so the rounded corners and glyphs stay exact. The
  slab's thickness is a back copy offset by the projected normal (`TabletEdge`). The tablet hangs
  in `BreathShoulderLPivot` behind the left arm (both hands draw in front of it, the head and
  torso behind), so it follows the torso, `breath` and `lean` like the hand targets do.
- Hands: both arms key their `HandTarget`, chain lengths, art scales, `invertDirection` and hand
  rotation (arm_rig.gesture_tracks on avatar_kit.ik, as the gestures do); every frame the wrist
  sits `HAND_REACH` behind its grip point on the slab, along the hand's finger direction, so the
  hands never leave the slab once they hold it. The `edge` pose grips the side edges.
- Animations: `prop_tablet_out` (the left hand pulls the tablet from the hip: anticipation,
  overshoot and settle from motion_synth.action, the right hand staggered by motion_synth.stagger),
  `prop_tablet_hold` (2 s loop: a slow tilt and a thumb scroll of the result list, seamless: the
  list is periodic), `prop_tablet_away` (the right hand lets go first, the left puts it back to
  the hip, ending exactly in the rest pose with the tablet hidden), `prop_none` (no keys).
- `ScreenGlow`: a cool `emitScreen`-coloured light from below on the face (screen blend, clipped
  by the face, so it follows the head turn), opacity 0 -> `GLOW` in out / hold, back to 0 in
  away; `ScreenReflect<L|R>` on both lenses of both glasses sets.
- Layer `Prop` (after `Gesture`): none -> out (prop = tablet) -> hold (exit time); out / hold ->
  away (prop = none); away -> hold (prop = tablet, first half) or -> out (second half); away ->
  none at its end. Short blends everywhere (Review Focus 1: no pop).
"""

from __future__ import annotations

from dataclasses import dataclass, replace
import math
from typing import Callable, Iterator, Sequence

import arm_rig
from art_bible import EMISSIVE_PREFIX, fit_colour
from avatar_kit import L1, L2, ik
from motion_synth import Beat, action, sample, stagger
from rml import Doc, El

FPS = 60
SCENE = "livingRoom"  # the avatar's neutral-light lint scene (art_bible lint)
SCREEN_BLEND = 14  # Rive BlendMode screen

# ---- the slab, authored flat (px), centred on its origin
W, H = 280.0, 190.0
CORNER = 38.0                 # 0.2 of the short side (art bible: props 18-50 %)
BEZEL = 11.0
SCREEN_R = CORNER - BEZEL + 4.0  # 31: 0.185 of the screen's short side
THICK = 9.0                   # slab depth (px along the normal)
TILT = math.radians(48.0)     # tipped back: the screen faces up toward the eyes
YAW = math.radians(16.0)      # turned toward the face (viewer's left)
ROLL = math.radians(-7.0)     # its top edge leans toward the face

# ---- colours (fit to the scene's script; the screen subtree is emissive)
BEZEL_C = "FF1E1A26"
EDGE_C = "FF2C2636"
EDGE_DEEP = "FF15121B"
RIM_C = "FF4E4760"
SCREEN_TOP = "FFDDF3FF"
SCREEN_BOTTOM = "FF86C6EE"
GLYPH_INK = "FF2D5878"
GLYPH_SOFT = "B04F7FA3"
GLYPH_PILL = "FFF6FCFF"
SUN = "FFFFC65A"
GLOW_C = "FF6CC4F4"           # the screen's light on the face and lenses
GLOW = 0.55                    # ScreenGlow opacity while the tablet is out
REFLECT = 0.6                  # lens reflection opacity while the tablet is out

# ---- the pose (artboard px); BodyGesture's origin is the artboard's (400, 1000)
BODY_ORIGIN = (400.0, 1000.0)
SHOULDER = {-1: (240.0, 720.0), 1: (560.0, 720.0)}
REST_WRIST = {-1: (240.0, 1070.0), 1: (560.0, 1070.0)}
HOLD = (470.0, 812.0)         # the tablet's centre while held: chest height, the viewer's right
# grip points on the slab (flat px) and the hand's finger direction there (flat degrees, y down;
# the slab's rotation adds to it): the edge hands close on the two side edges, low down
GRIP = {-1: (-W / 2 - 2.0, 45.0), 1: (W / 2 - 4.0, 40.0)}
FINGER = {-1: -65.0, 1: -105.0}
HAND_REACH = 52.0             # wrist -> grip (px along the fingers; the edge hand's blade centre)
FS = {-1: (1.0, 0.36), 1: (0.99, 0.25)}  # (upper, fore): elbows at the sides, forearms toward the camera
GRIP_POSE = "edge"
HIP_ROT, HIP_SY = -1.45, 0.7  # at the hip the slab hangs from its right edge (on its side)

# ---- timing (frames at 60 fps)
OUT_BEAT = 13                 # main lift (motion_synth.action adds the 220 ms settle)
AWAY_BEAT = 10
HOLD_FRAMES = 120             # 2 s loop
SCROLL = (44, 58)             # the thumb flick (frames of the hold loop)
LIST_PERIOD = 26.0            # px: one result item (the list repeats, so the loop is seamless)
BLEND_IN, BLEND_AWAY, BLEND_BACK, BLEND_END = 100, 120, 160, 120  # ms


def frames_of(beat_frames: int, lag: int) -> int:
    settle = round(0.220 * FPS)
    return lag + beat_frames + settle


# ------------------------------------------------------------------ projection

def plane() -> tuple[float, float, float, float]:
    """The 2x2 affine projection (a, b, c, d): flat (u, v) -> screen (a u + b v, c u + d v).

    The slab is tipped back about its horizontal axis by TILT (its top goes away from the viewer),
    turned about the vertical by YAW and rolled in the picture plane by ROLL; orthographic."""
    ca, sa = math.cos(TILT), math.sin(TILT)
    cb, sb = math.cos(YAW), math.sin(YAW)
    # flat axes in 3D (x right, y down, z away from the viewer)
    u = (cb, 0.0, -sb)
    v = (-sa * sb, ca, -sa * cb)  # Ry(Rx(0, 1, 0)): the bottom edge comes toward the viewer
    cr, sr = math.cos(ROLL), math.sin(ROLL)
    a, c = cr * u[0] - sr * u[1], sr * u[0] + cr * u[1]
    b, d = cr * v[0] - sr * v[1], sr * v[0] + cr * v[1]
    return a, b, c, d


def normal() -> tuple[float, float, float]:
    """The screen's outward normal (x right, y down, z away): it points up, toward the face and
    toward the viewer (z < 0)."""
    ca, sa = math.cos(TILT), math.sin(TILT)
    cb, sb = math.cos(YAW), math.sin(YAW)
    n = (0.0, -sa, -ca)  # Rx: tipped back, the front face looks up and at the viewer
    n = (cb * n[0] + sb * n[2], n[1], -sb * n[0] + cb * n[2])
    cr, sr = math.cos(ROLL), math.sin(ROLL)
    return (cr * n[0] - sr * n[1], sr * n[0] + cr * n[1], n[2])


def svd2(m: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    """(phi, sx, sy, theta) with m = R(phi) . diag(sx, sy) . R(theta) (closed-form 2x2 SVD)."""
    a, b, c, d = m
    e, f, g, h = (a + d) / 2, (a - d) / 2, (c + b) / 2, (c - b) / 2
    q, r = math.hypot(e, h), math.hypot(f, g)
    a1, a2 = math.atan2(g, f), math.atan2(h, e)
    return (a2 + a1) / 2, q + r, q - r, (a2 - a1) / 2


def apply(m: tuple[float, float, float, float], p: tuple[float, float]) -> tuple[float, float]:
    return m[0] * p[0] + m[1] * p[1], m[2] * p[0] + m[3] * p[1]


def inverse(m: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    a, b, c, d = m
    det = a * d - b * c
    return d / det, -b / det, -c / det, a / det


@dataclass(frozen=True)
class Pose:
    """The tablet node's transform in artboard px: centre, rotation, local scaleY (tips it)."""

    x: float
    y: float
    rot: float = 0.0
    sy: float = 1.0

    def point(self, flat: tuple[float, float]) -> tuple[float, float]:
        px, py = apply(plane(), flat)
        py *= self.sy
        c, s = math.cos(self.rot), math.sin(self.rot)
        return self.x + c * px - s * py, self.y + s * px + c * py


def grip(pose: Pose, side: int) -> tuple[float, float]:
    return pose.point(GRIP[side])


def finger_dir(pose: Pose, side: int) -> float:
    return FINGER[side] + math.degrees(pose.rot)


def wrist_on(pose: Pose, side: int, finger: float | None = None) -> tuple[float, float]:
    """The wrist that puts the hand's blade on its grip point."""
    fd = math.radians(finger_dir(pose, side) if finger is None else finger)
    gx, gy = grip(pose, side)
    return gx - HAND_REACH * math.cos(fd), gy - HAND_REACH * math.sin(fd)


def clamp_reach(side: int, w: tuple[float, float], fs: float, fs2: float) -> tuple[float, float]:
    sx, sy = SHOULDER[side]
    reach = L1 * fs + L2 * fs2  # on the reach circle the solver keeps the arm straight
    dx, dy = w[0] - sx, w[1] - sy
    n = math.hypot(dx, dy)
    if n <= reach:
        return w
    return sx + dx / n * reach, sy + dy / n * reach


def seat(side: int, wrist: tuple[float, float], finger: float, rot: float, sy: float) -> Pose:
    """The tablet pose (rotation `rot`, tip `sy`) whose `side` grip sits on that hand's blade."""
    probe = Pose(0.0, 0.0, rot, sy)
    gx, gy = grip(probe, side)
    fd = math.radians(finger)
    bx, by = wrist[0] + HAND_REACH * math.cos(fd), wrist[1] + HAND_REACH * math.sin(fd)
    return Pose(bx - gx, by - gy, rot, sy)


def hip_pose() -> Pose:
    """The tablet at the hip, hanging from the resting left hand by its grip edge (below the frame)."""
    return seat(1, REST_WRIST[1], FINGER[1] + math.degrees(HIP_ROT), HIP_ROT, HIP_SY)


HOLD_POSE = Pose(*HOLD)


# ------------------------------------------------------------------ timelines

@dataclass
class ArmFrame:
    wrist: tuple[float, float]
    finger: float
    fs: float
    fs2: float
    rest: bool = False


@dataclass
class Clip:
    name: str
    frames: int
    loop: bool
    tablet: dict[int, Pose]
    arms: dict[int, dict[int, ArmFrame]]           # side -> frame -> pose
    pose_scales: dict[int, list[tuple[int, float, float]]]  # side -> smoothstep pose frames
    hand: dict[int, list[tuple[int, str]]]          # side -> [(frame, hand pose)]
    opacity: list[tuple[int, float, str]]            # tablet
    glow: list[tuple[int, float, str]]               # ScreenGlow / lens reflections (x 1 / REFLECT)
    scroll: list[tuple[int, float, str]]             # result list y


def smoothstep(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def scale_at(ps: Sequence[tuple[int, float, float]], f: float) -> tuple[float, float]:
    """fs, fs2 at frame f between smoothstep pose frames (arm_rig.SMOOTHSTEP keys)."""
    if f <= ps[0][0]:
        return ps[0][1], ps[0][2]
    for (f0, a0, b0), (f1, a1, b1) in zip(ps, ps[1:]):
        if f <= f1:
            t = smoothstep((f - f0) / (f1 - f0))
            return a0 + (a1 - a0) * t, b0 + (b1 - b0) * t
    return ps[-1][1], ps[-1][2]


def _lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def _track(beat: Beat) -> Callable[[float], float]:
    keys = action(beat)
    return lambda f: sample(keys, f)


def _settled(f: float, start: float, frames: float) -> float:
    return smoothstep((f - start) / frames)


def out_clip() -> Clip:
    """The left hand reaches to the hip and lifts (anticipation, overshoot, settle); the slab
    hangs from it by its edge and swings up into the reading angle one part offset later; the
    right hand follows 40 ms behind and closes on the left edge."""
    lag = stagger(["handL", "handR"])          # the tablet hand leads, the other follows 40 ms later
    n = frames_of(OUT_BEAT, lag["handR"])
    hold = HOLD_POSE
    w_hold = wrist_on(hold, 1)
    wx = _track(Beat(0, OUT_BEAT, REST_WRIST[1][0], w_hold[0]))
    wy = _track(Beat(0, OUT_BEAT, REST_WRIST[1][1], w_hold[1]))
    # the slab trails the wrist by one part offset (follow-through)
    tr = _track(Beat(lag["handR"], OUT_BEAT, HIP_ROT, hold.rot))
    ts = _track(Beat(lag["handR"], OUT_BEAT, HIP_SY, hold.sy))
    catch = _track(Beat(lag["handR"], OUT_BEAT, 0.0, 1.0))
    ps = {1: [(0, 1.0, 1.0), (OUT_BEAT, *FS[1]), (n, *FS[1])],
          -1: [(0, 1.0, 1.0), (lag["handR"], 1.0, 1.0), (lag["handR"] + OUT_BEAT, *FS[-1]), (n, *FS[-1])]}
    tablet: dict[int, Pose] = {}
    arms: dict[int, dict[int, ArmFrame]] = {-1: {}, 1: {}}
    for f in range(n + 1):
        rot, sy = tr(f), ts(f)
        fs, fs2 = scale_at(ps[1], f)
        if f == 0:
            arms[1][f] = ArmFrame(REST_WRIST[1], 90.0, 1.0, 1.0, rest=True)
            pose = hip_pose()
        else:
            w = clamp_reach(1, (wx(f), wy(f)), fs, fs2)
            # the hand turns from hanging onto the slab's edge while both are below the frame
            rigid = FINGER[1] + math.degrees(rot)
            fd = 90.0 + (rigid - 90.0) * _settled(f, 0, 3)
            arms[1][f] = ArmFrame(w, fd, fs, fs2)
            pose = seat(1, w, rigid, rot, sy)
        tablet[f] = pose
        rs, rs2 = scale_at(ps[-1], f)
        # no wind-up (the free hand goes straight for the edge); once caught it stays on it
        k = 1.0 if f >= lag["handR"] + OUT_BEAT else max(0.0, min(1.0, catch(f)))
        if f <= lag["handR"]:
            arms[-1][f] = ArmFrame(REST_WRIST[-1], 90.0, 1.0, 1.0, rest=True)
        else:
            fd = 90.0 + (finger_dir(pose, -1) - 90.0) * max(0.0, k)
            w = clamp_reach(-1, _lerp(REST_WRIST[-1], wrist_on(pose, -1, fd), k), rs, rs2)
            arms[-1][f] = ArmFrame(w, fd, rs, rs2)
    return Clip("prop_tablet_out", n, False, tablet, arms, ps,
                {1: [(0, "rest"), (2, GRIP_POSE)], -1: [(0, "rest"), (lag["handR"] + 7, GRIP_POSE)]},
                [(0, 0.0, "hold"), (2, 1.0, "hold"), (n, 1.0, "hold")],
                [(0, 0.0, "linear"), (6, 0.0, "easeInOut"), (OUT_BEAT + 6, 1.0, "hold"), (n, 1.0, "hold")],
                [(0, 0.0, "hold"), (n, 0.0, "hold")])


def hold_tilt(f: float) -> Pose:
    t = 2 * math.pi * f / HOLD_FRAMES
    return Pose(HOLD[0] + 1.5 * math.sin(t + 0.6), HOLD[1] + 2.0 * math.sin(t), 0.026 * math.sin(t),
                1.0 + 0.025 * math.sin(t + 1.1))


def thumb(f: float) -> float:
    """The left thumb's flick (0..1..0) around the scroll."""
    a, b = SCROLL
    if f < a - 4 or f > b + 10:
        return 0.0
    if f < a + 4:
        return smoothstep((f - (a - 4)) / 8)
    return 1.0 - smoothstep((f - (a + 4)) / (b + 10 - (a + 4)))


def hold_clip() -> Clip:
    n = HOLD_FRAMES
    tablet: dict[int, Pose] = {}
    arms: dict[int, dict[int, ArmFrame]] = {-1: {}, 1: {}}
    for f in range(n + 1):
        pose = hold_tilt(f % n)
        tablet[f] = pose
        for side in (-1, 1):
            fs, fs2 = FS[side]
            fd = finger_dir(pose, side) - (7.0 * thumb(f % n) if side == 1 else 0.0)
            w = wrist_on(pose, side, finger_dir(pose, side))
            if side == 1:  # the thumb pushes up the screen: the hand rocks up along the slab
                up = math.radians(finger_dir(pose, side))
                w = (w[0] + 4.0 * thumb(f % n) * math.cos(up), w[1] + 4.0 * thumb(f % n) * math.sin(up))
            arms[side][f] = ArmFrame(clamp_reach(side, w, fs, fs2), fd, fs, fs2)
    ps = {s: [(0, *FS[s]), (n, *FS[s])] for s in (-1, 1)}
    a, b = SCROLL
    return Clip("prop_tablet_hold", n, True, tablet, arms, ps, {1: [(0, GRIP_POSE)], -1: [(0, GRIP_POSE)]},
                [(0, 1.0, "hold"), (n, 1.0, "hold")],
                [(0, 1.0, "linear"), (a, 0.94, "linear"), (b, 1.0, "linear"), (n, 1.0, "hold")],
                [(0, 0.0, "linear"), (a, 0.0, "easeInOut"), (b, -LIST_PERIOD, "hold"), (n, -LIST_PERIOD, "hold")])


def away_clip() -> Clip:
    """The right hand lets go first; 40 ms later the left lowers the slab (a small lift first,
    then down past the hip and settle), the slab swinging back onto its edge; ends in the exact
    rest pose with the tablet hidden below the frame."""
    lag = stagger(["handR", "handL"])          # the free hand lets go first, the tablet hand follows
    n = frames_of(AWAY_BEAT, lag["handL"])
    s0 = lag["handL"]
    hold = HOLD_POSE
    w_hold = wrist_on(hold, 1)
    wx = _track(Beat(s0, AWAY_BEAT, w_hold[0], REST_WRIST[1][0]))
    wy = _track(Beat(s0, AWAY_BEAT, w_hold[1], REST_WRIST[1][1]))
    tr, ts = _track(Beat(s0, AWAY_BEAT, hold.rot, HIP_ROT)), _track(Beat(s0, AWAY_BEAT, hold.sy, HIP_SY))
    let_go = _track(Beat(0, AWAY_BEAT, 1.0, 0.0))
    ps = {1: [(0, *FS[1]), (s0, *FS[1]), (s0 + AWAY_BEAT, 1.0, 1.0), (n, 1.0, 1.0)],
          -1: [(0, *FS[-1]), (AWAY_BEAT, 1.0, 1.0), (n, 1.0, 1.0)]}
    tablet: dict[int, Pose] = {}
    arms: dict[int, dict[int, ArmFrame]] = {-1: {}, 1: {}}
    for f in range(n + 1):
        rot, sy = tr(f), ts(f)
        fs, fs2 = scale_at(ps[1], f)
        rigid = FINGER[1] + math.degrees(rot)
        if f >= s0 + AWAY_BEAT:  # the main move ends on the rest pose: the settle stays below the frame
            arms[1][f] = ArmFrame(REST_WRIST[1], 90.0, 1.0, 1.0, rest=True)
            pose = hip_pose()
        else:
            w = clamp_reach(1, (wx(f), wy(f)), fs, fs2)
            # the hand turns back to hanging as it drops below the frame
            fd = rigid + (90.0 - rigid) * smoothstep((w[1] - 990.0) / 45.0)
            arms[1][f] = ArmFrame(w, fd, fs, fs2)
            pose = seat(1, w, rigid, rot, sy)
        tablet[f] = pose
        rs, rs2 = scale_at(ps[-1], f)
        k = max(0.0, min(1.0, let_go(f)))
        if f >= AWAY_BEAT:
            arms[-1][f] = ArmFrame(REST_WRIST[-1], 90.0, 1.0, 1.0, rest=True)
        else:
            fd = 90.0 + (finger_dir(pose, -1) - 90.0) * k
            w = clamp_reach(-1, _lerp(REST_WRIST[-1], wrist_on(pose, -1, fd), k), rs, rs2)
            arms[-1][f] = ArmFrame(w, fd, rs, rs2)
    return Clip("prop_tablet_away", n, False, tablet, arms, ps,
                {-1: [(0, GRIP_POSE), (4, "rest")], 1: [(0, GRIP_POSE), (s0 + AWAY_BEAT, "rest")]},
                [(0, 1.0, "hold"), (s0 + AWAY_BEAT, 0.0, "hold"), (n, 0.0, "hold")],
                [(0, 1.0, "easeInOut"), (12, 0.0, "hold"), (n, 0.0, "hold")],
                [(0, -LIST_PERIOD, "hold"), (n, -LIST_PERIOD, "hold")])


CLIPS: tuple[Callable[[], Clip], ...] = (out_clip, hold_clip, away_clip)


# ------------------------------------------------------------------ the generator side

def walk(e: El) -> Iterator[El]:
    yield e
    for c in e.children:
        yield from walk(c)


def _unwrap(prev: float, v: float) -> float:
    while v - prev > math.pi:
        v -= 2 * math.pi
    while v - prev < -math.pi:
        v += 2 * math.pi
    return v


class Tablet:
    """Builds the art, the clips and the `Prop` layer into the finished avatar tree."""

    KIND = "tablet"  # the `prop` value and the clip names' middle (prop_<KIND>_out ...)
    GLOW_PEAK, REFLECT_PEAK = GLOW, REFLECT  # opacities the face light / lens nodes reach while out

    def __init__(self, d: Doc, prop_path: str, prop_values: dict[str, El], ease_in_out: El) -> None:
        self.d = d
        self.prop_path = prop_path
        self.prop_values = prop_values
        self.ease = ease_in_out
        self.glows: list[El] = []
        self.reflects: list[El] = []
        self.scroll: El | None = None
        self.states: dict[str, El] = {}

    # ---- paints
    def _solid(self, argb: str) -> El:
        return self.d("SolidColor", colorValue=argb)

    def _fill(self, argb: str) -> El:
        return self.d("Fill", self._solid(argb), name="Fill")

    def _stroke(self, argb: str, w: float) -> El:
        return self.d("Stroke", self._solid(argb), thickness=float(w), cap="round", join="round", name="Line")

    def _lin(self, x0: float, y0: float, x1: float, y1: float, stops: Sequence[tuple[str, float]]) -> El:
        return self.d("LinearGradient", *[self.d("GradientStop", colorValue=c, position=float(p)) for c, p in stops],
                      startX=float(x0), startY=float(y0), endX=float(x1), endY=float(y1))

    def _rect(self, name: str, w: float, h: float, r: float, *paints: El, x: float = 0.0, y: float = 0.0,
              radii: tuple[float, float, float, float] | None = None, **kw: object) -> El:
        d = self.d
        if radii is None:
            path = d("Rectangle", width=float(w), height=float(h), cornerRadiusTL=float(r), name="Path")
        else:
            tl, tr, br, bl = radii
            path = d("Rectangle", width=float(w), height=float(h), linkCornerRadius=False, cornerRadiusTL=float(tl),
                     cornerRadiusTR=float(tr), cornerRadiusBR=float(br), cornerRadiusBL=float(bl), name="Path")
        return d("Shape", path, *paints, x=float(x), y=float(y), name=name, **kw)

    def _ellipse(self, name: str, w: float, h: float, *paints: El, x: float = 0.0, y: float = 0.0) -> El:
        return self.d("Shape", self.d("Ellipse", width=float(w), height=float(h), name="Path"), *paints,
                      x=float(x), y=float(y), name=name)

    def _line(self, name: str, pts: Sequence[tuple[float, float]], argb: str, w: float) -> El:
        d = self.d
        verts = [d("StraightVertex", x=float(x), y=float(y)) for x, y in pts]
        return d("Shape", d("PointsPath", *verts, isClosed=False, name="Path"), self._stroke(argb, w), name=name)

    # ---- art
    def screen_glyphs(self) -> El:
        """Search bar, a weather card (sun + temperature bars) and a periodic result list, in the
        screen's flat frame (centre 0, 0); the list scrolls under its own clip."""
        sw, sh = W - 2 * BEZEL, H - 2 * BEZEL
        top, left = -sh / 2, -sw / 2
        search = [
            self._line("SearchHandle", [(left + 30.0, top + 24.0), (left + 34.0, top + 28.0)], GLYPH_INK, 2.6),
            self._ellipse("SearchLens", 10.0, 10.0, self._stroke(GLYPH_INK, 2.2), x=left + 26.0, y=top + 20.0),
            self._rect("SearchText", 64.0, 4.0, 2.0, self._fill(GLYPH_SOFT), x=left + 76.0, y=top + 20.0),
            self._rect("SearchBar", sw - 36.0, 20.0, 10.0, self._fill(GLYPH_PILL), x=0.0, y=top + 20.0),
        ]
        sun_c = (left + 40.0, top + 56.0)
        rays = [self._line(f"SunRay{i}", [(sun_c[0] + 13.0 * math.cos(a), sun_c[1] + 13.0 * math.sin(a)),
                                          (sun_c[0] + 18.0 * math.cos(a), sun_c[1] + 18.0 * math.sin(a))], SUN, 2.4)
                for i, a in enumerate(math.radians(45.0 * k + 22.5) for k in range(8))]
        weather = [
            self._ellipse("Sun", 18.0, 18.0, self._fill(SUN), x=sun_c[0], y=sun_c[1]),
            *rays,
            self._rect("Temp", 36.0, 11.0, 5.5, self._fill(GLYPH_INK), x=left + 92.0, y=top + 50.0),
            self._rect("TempSub", 54.0, 5.0, 2.5, self._fill(GLYPH_SOFT), x=left + 101.0, y=top + 64.0),
            self._rect("Card", sw - 36.0, 40.0, 12.0, self._fill("70FFFFFF"), x=0.0, y=top + 57.0),
        ]
        items = []
        y0 = top + 88.0
        for k in range(5):  # periodic: one title + one body line per LIST_PERIOD
            y = y0 + k * LIST_PERIOD
            items += [self._rect(f"ResultTitle{k}", 92.0, 6.0, 3.0, self._fill(GLYPH_INK), x=left + 64.0, y=y),
                      self._rect(f"ResultBody{k}", 150.0, 4.0, 2.0, self._fill(GLYPH_SOFT), x=left + 93.0, y=y + 10.0),
                      self._rect(f"ResultDot{k}", 10.0, 10.0, 3.0, self._fill(GLYPH_SOFT), x=left + 22.0, y=y + 4.0)]
        mask_top = top + 80.0
        mask_h = sh / 2 - mask_top
        mask = self._rect("ListMask", sw, mask_h, 0.0, x=0.0, y=mask_top + mask_h / 2,
                          radii=(0.0, 0.0, SCREEN_R, SCREEN_R))
        self.scroll = self.d("Node", *items, x=0.0, y=0.0, name="ScrollList")
        clip = self.d("Node", self.d("ClippingShape", sourceId=mask.ref(), name="Clip"), self.scroll, x=0.0, y=0.0,
                      name="ListClip")
        return self.d("Node", clip, *weather, *search, mask, x=0.0, y=0.0, name="emitScreenGlyphs")

    def art(self) -> El:
        d = self.d
        m = plane()
        phi, sx, sy, theta = svd2(m)
        n = normal()
        # the back face: THICK behind the screen, projected, expressed in the flat frame
        back = apply(inverse(m), (-n[0] * THICK, -n[1] * THICK))
        mid = (back[0] / 2, back[1] / 2)
        sw, sh = W - 2 * BEZEL, H - 2 * BEZEL
        screen = self._rect("emitScreen", sw, sh, SCREEN_R,
                            self.d("Fill", self._lin(-sw / 2, -sh / 2, sw / 2, sh / 2,
                                                     [(SCREEN_TOP, 0.0), (SCREEN_BOTTOM, 1.0)]), name="Fill"))
        glare = self._rect("emitScreenGlare", 40.0, sh * 1.4, 0.0,
                           self.d("Fill", self._lin(-20, 0, 20, 0, [("00FFFFFF", 0.0), ("38FFFFFF", 0.5),
                                                                     ("00FFFFFF", 1.0)]), name="Fill"),
                           x=sw * 0.18, y=0.0, rotation=0.5)
        glare_clip = d("Node", d("ClippingShape", sourceId=screen.ref(), name="Clip"), glare, x=0.0, y=0.0,
                       name="emitScreenSheen")
        glyphs = self.screen_glyphs()
        glyph_clip = d("Node", d("ClippingShape", sourceId=screen.ref(), name="Clip"), glyphs, x=0.0, y=0.0,
                       name="emitScreenContent")
        bezel = self._rect("Bezel", W, H, CORNER, self._fill(BEZEL_C), self._stroke(RIM_C, 1.4))
        edge_mid = self._rect("TabletEdgeMid", W, H, CORNER, self._fill(EDGE_C), x=mid[0], y=mid[1])
        edge = self._rect("TabletEdge", W, H, CORNER, self._fill(EDGE_DEEP), self._stroke(EDGE_DEEP, 2.4),
                          x=back[0], y=back[1])
        face = d("Node", glare_clip, glyph_clip, screen, bezel, edge_mid, edge, x=0.0, y=0.0,
                 rotation=round(theta, 5), name="TabletFace")
        plane_n = d("Node", face, x=0.0, y=0.0, rotation=round(phi, 5), scaleX=round(sx, 5), scaleY=round(sy, 5),
                    name="TabletPlane")
        self.tilt = d("Node", plane_n, x=0.0, y=0.0, name="TabletTip")  # keyed scaleY (local tip)
        hip = hip_pose()
        self.node = d("Node", self.tilt, x=hip.x - BODY_ORIGIN[0], y=hip.y - BODY_ORIGIN[1], rotation=hip.rot,
                      opacity=0.0, name="Tablet")
        self.tilt.attrs["scaleY"] = hip.sy
        self._fit(self.node)
        return self.node

    def _fit(self, root: El) -> None:
        """Colour lint by construction (gen_scenes.fit_colours): emissive subtrees name their paints
        `emit`, everything else is fitted to the scene's script."""
        def visit(e: El, emit: bool) -> None:
            emit = emit or str(e.attrs.get("name", "")).startswith(EMISSIVE_PREFIX)
            if e.tag in ("SolidColor", "GradientStop"):
                if emit:
                    e.attrs["name"] = EMISSIVE_PREFIX
                else:
                    e.attrs["colorValue"] = fit_colour(str(e.attrs["colorValue"]), SCENE)
            for c in e.children:
                visit(c, emit)
        visit(root, False)

    def screen_glow(self, face: El, head_frame: tuple[float, float]) -> El:
        """The screen's cool light from below: a radial pool under the chin, toward the tablet."""
        d = self.d
        grad = d("RadialGradient", d("GradientStop", colorValue="E0" + GLOW_C[2:], position=0.0),
                 d("GradientStop", colorValue="60" + GLOW_C[2:], position=0.45),
                 d("GradientStop", colorValue="00" + GLOW_C[2:], position=1.0),
                 startX=0.0, startY=0.0, endX=170.0, endY=0.0)
        shape = d("Shape", d("ClippingShape", sourceId=face.ref(), name="Clip"),
                  d("Ellipse", width=340.0, height=230.0, name="Path"), d("Fill", grad, name="Fill"),
                  x=0.0, y=0.0, blendModeValue=SCREEN_BLEND, name="emitScreenGlowPool")
        node = d("Node", shape, x=436.0 - head_frame[0], y=548.0 - head_frame[1], opacity=0.0, name="ScreenGlow")
        self._fit(node)
        self.glows.append(node)
        return node

    def lens_reflect(self, pivot: El, name: str, lens_x: float, lens_cy: float, head_frame: tuple[float, float]) -> El:
        """The screen mirrored in a lens: a small bright slab low on the lens, toward the tablet."""
        d = self.d
        shape = self._rect("emitReflect", 26.0, 10.0, 4.0,
                           d("Fill", self._lin(-13, 0, 13, 0, [("D0" + GLOW_C[2:], 0.0), ("40" + GLOW_C[2:], 1.0)]),
                             name="Fill"), rotation=-0.22, blendModeValue=SCREEN_BLEND)
        node = d("Node", shape, x=lens_x + 9.0 - head_frame[0], y=lens_cy + 13.0 - head_frame[1], opacity=0.0,
                 name=name)
        self._fit(node)
        pivot.children.insert(0, node)
        self.reflects.append(node)
        return node

    # ---- keys
    def _kf(self, f: int, v: float, mode: str) -> El:
        if mode in ("easeInOut",):
            return self.d("KeyFrameDouble", frame=f, value=float(v), interpolationType="cubic",
                          interpolatorId=self.ease.ref())
        return self.d("KeyFrameDouble", frame=f, value=float(v), interpolationType=mode)

    def _obj(self, target: El, props: dict[str, list[El]]) -> El:
        d = self.d
        return d("KeyedObject", *[d("KeyedProperty", *kfs, property=p) for p, kfs in props.items()],
                 objectId=target.ref())

    def _linear(self, keys: Sequence[tuple[int, float]], tol: float) -> list[El]:
        idx = arm_rig.rdp([(f, (v,)) for f, v in keys], tol)
        return [self._kf(keys[i][0], keys[i][1], "linear") for i in idx]

    def clip_tracks(self, clip: Clip, arms: dict[int, dict]) -> list[El]:
        tracks: list[El] = []
        fr = sorted(clip.tablet)
        tab = clip.tablet
        tracks.append(self._obj(self.node, {
            "x": self._linear([(f, tab[f].x - BODY_ORIGIN[0]) for f in fr], 0.05),
            "y": self._linear([(f, tab[f].y - BODY_ORIGIN[1]) for f in fr], 0.05),
            "rotation": self._linear([(f, tab[f].rot) for f in fr], 0.0005),
            "opacity": [self._kf(f, v, m) for f, v, m in clip.opacity]}))
        tracks.append(self._obj(self.tilt, {"scaleY": self._linear([(f, tab[f].sy) for f in fr], 0.0005)}))
        if self.scroll is not None:
            tracks.append(self._obj(self.scroll, {"y": [self._kf(f, v, m) for f, v, m in clip.scroll]}))
        for g in self.glows:
            tracks.append(self._obj(g, {"opacity": [self._kf(f, v * self.GLOW_PEAK, m) for f, v, m in clip.glow]}))
        for r in self.reflects:
            tracks.append(self._obj(r, {"opacity": [self._kf(f, v * self.REFLECT_PEAK, m) for f, v, m in clip.glow]}))
        for side in (-1, 1):
            tracks += self.arm_tracks(arms[side], side, clip)
        return tracks

    def arm_tracks(self, a: dict, side: int, clip: Clip) -> list[El]:
        samples = []
        prev = (0.0, 0.0, 0.0)
        frames = sorted(clip.arms[side])
        for f in frames:
            af = clip.arms[side][f]
            r = (0.0, 0.0, 0.0) if af.rest else ik(side, af.wrist, af.finger, False, af.fs, af.fs2)
            r = tuple(_unwrap(pv, v) for pv, v in zip(prev, r))
            prev = r
            samples.append((f, r, af.fs, af.fs2))
        ik_tracks, _ = arm_rig.gesture_tracks(a, side, samples, clip.pose_scales[side], doc=self.d)
        hand = self._obj(a["hand"].el, {"rotation": self._linear([(f, r[2]) for f, r, _, _ in samples],
                                                                  arm_rig.HAND_TOL)})
        solos = [self.d("KeyedObject", self.d("KeyedProperty", *[
            self.d("KeyFrameId", frame=f, value=ps[n].ref(), interpolationType="hold") for f, n in clip.hand[side]],
            property="activeComponentId"), objectId=solo.ref()) for solo, ps in a["pose_sets"]]
        return [hand, *solos, *ik_tracks]

    def animations(self, arms: dict[int, dict], with_none: bool = True) -> dict[str, El]:
        d = self.d
        out = {"prop_none": d("LinearAnimation", duration=1, fps=FPS, name="prop_none")} if with_none else {}
        for make in CLIPS:
            clip = make()
            clip = replace(clip, name=clip.name.replace("tablet", self.KIND))
            out[clip.name] = d("LinearAnimation", *self.clip_tracks(clip, arms), duration=clip.frames, fps=FPS,
                               loopValue="loop" if clip.loop else None, name=clip.name)
        return out

    # ---- state machine
    def _is(self, value: str) -> El:
        d = self.d
        return d("TransitionViewModelCondition",
                 d("TransitionPropertyViewModelComparator",
                   d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=self.prop_path, propertyKey=637))),
                 d("TransitionValueEnumComparator", value=self.prop_values[value].ref()))

    def layer(self, anims: dict[str, El]) -> El:
        d = self.d

        def state(name: str, i: int) -> El:
            return d("AnimationState", animationId=anims[name].ref(), x=float(160 * i), y=float(100 + 120 * (i % 2)))

        none, out, hold, away = (state(n, i) for i, n in enumerate(
            ("prop_none", "prop_tablet_out", "prop_tablet_hold", "prop_tablet_away")))
        self.states = {"none": none, "out": out, "hold": hold, "away": away}

        def go(to: El, *conds: El, ms: int = 0, exit_pct: float | None = None) -> El:
            kw: dict[str, object] = {}
            if exit_pct is not None:
                kw = dict(enableExitTime=True, exitTimeIsPercetange=True, exitTime=exit_pct)
            return d("StateTransition", *conds, stateToId=to.ref(), duration=ms or None, **kw)

        none.add(go(out, self._is("tablet"), ms=BLEND_IN))
        out.add(go(away, self._is("none"), ms=BLEND_AWAY), go(hold, exit_pct=100))
        hold.add(go(away, self._is("none"), ms=BLEND_AWAY))
        # tablet again while putting it away: late in the put-away pull it out again, early on go
        # straight back to the hold (the first allowed transition wins)
        away.add(go(out, self._is("tablet"), ms=BLEND_BACK, exit_pct=55),
                 go(hold, self._is("tablet"), ms=BLEND_BACK),
                 go(none, ms=BLEND_END, exit_pct=100))
        return d("StateMachineLayer",
                 d("AnyState", x=100.0, y=-100.0),
                 d("ExitState", x=500.0, y=-100.0),
                 d("EntryState", d("StateTransition", stateToId=none.ref()), x=-100.0, y=-100.0),
                 none, out, hold, away, name="Prop")


# ------------------------------------------------------------------ the newspaper (M5 ruling 9)
# A folded broadsheet on the tablet's footprint (W x H, so the grips, hand targets, timing and the
# out / hold / away clips are the tablet's own), two pages with generated headline bars, column
# lines and a photo block, no emissive glow: a soft page shadow falls on the face instead.

PAPER = "FFF2ECDF"
PAPER_SHADE = "FFE2D9C8"
PAPER_EDGE = "FFCFC5B2"
PAPER_LINE = "FF8A8072"
INK_HEAD = "FF2E2A30"
INK_TEXT = "FF8F8678"
PHOTO = "FFB9AE9C"
FOLD_C = "7A6F60"            # the centre fold's shade (alpha set per stop)
PAGE_THICK = 3.5             # the stacked sheets' depth (px along the normal)
SHADOW_C = "FF7A5C52"        # the page's shadow on the face (multiply)
SHADOW = 0.5                 # its opacity while the paper is out


class Newspaper(Tablet):
    """The newspaper prop: the tablet's clips (renamed prop_newspaper_*) on its own art, minted from
    the M5 id range; its states join the existing `Prop` layer (extend_layer)."""

    KIND = "newspaper"
    GLOW_PEAK, REFLECT_PEAK = SHADOW, 0.0

    def _bars(self, name: str, rects: Sequence[tuple[float, float, float, float]], argb: str) -> El:
        """One shape, one fill, many rectangles (x, y, w, h): cheap columns of type."""
        d = self.d
        paths = [d("Rectangle", width=float(w), height=float(h), cornerRadiusTL=float(min(w, h) / 2), x=float(x),
                   y=float(y), name="Path") for x, y, w, h in rects]
        return d("Shape", *paths, self._fill(argb), x=0.0, y=0.0, name=name)

    def pages(self) -> list[El]:
        """Both pages' print (flat frame, centre 0, 0; the fold at x 0), front to back."""
        pw, top = W / 2, -H / 2
        heads, text, photos = [], [], []
        # left page: a two-line headline over two columns of type
        lx = -pw / 2
        heads += [(lx, top + 20.0, pw - 30.0, 11.0), (lx - 14.0, top + 36.0, pw - 58.0, 8.0)]
        for col, cx in enumerate((lx - 28.0, lx + 30.0)):
            for k in range(9 if col else 8):
                w = 50.0 if k % 4 != 3 else 34.0
                text.append((cx - (50.0 - w) / 2, top + 58.0 + 12.0 * k, w, 3.4))
        # right page: a smaller headline, a photo block and three columns of type under it
        rx = pw / 2
        heads.append((rx, top + 20.0, pw - 44.0, 8.0))
        photos.append((rx - 22.0, top + 54.0, 76.0, 46.0))
        for k in range(4):
            text.append((rx + 46.0, top + 38.0 + 11.0 * k, 34.0, 3.0))
        for col, cx in enumerate((rx - 40.0, rx, rx + 40.0)):
            for k in range(6):
                w = 32.0 if (k + col) % 3 != 2 else 22.0
                text.append((cx - (32.0 - w) / 2, top + 92.0 + 12.0 * k, w, 3.0))
        return [self._bars("NewsHeadlines", heads, INK_HEAD), self._bars("NewsPhoto", photos, PHOTO),
                self._bars("NewsColumns", text, INK_TEXT)]

    def art(self) -> El:
        d = self.d
        m = plane()
        phi, sx, sy, theta = svd2(m)
        n = normal()
        back = apply(inverse(m), (-n[0] * PAGE_THICK, -n[1] * PAGE_THICK))
        pw = W / 2
        fold = self._rect("NewsFold", 28.0, H, 0.0,
                          d("Fill", self._lin(-14, 0, 14, 0, [("00" + FOLD_C, 0.0), ("48" + FOLD_C, 0.5),
                                                               ("00" + FOLD_C, 1.0)]), name="Fill"))
        left = self._rect("NewsPageL", pw, H, 0.0, self._fill(PAPER), self._stroke(PAPER_LINE, 1.0), x=-pw / 2,
                          radii=(4.0, 0.0, 0.0, 4.0))
        right = self._rect("NewsPageR", pw, H, 0.0,
                           d("Fill", self._lin(0, 0, pw, 0, [(PAPER_SHADE, 0.0), (PAPER, 0.35)]), name="Fill"),
                           self._stroke(PAPER_LINE, 1.0), x=pw / 2, radii=(0.0, 4.0, 4.0, 0.0))
        edge = self._rect("NewsEdge", W, H, 4.0, self._fill(PAPER_EDGE), self._stroke(PAPER_LINE, 1.0),
                          x=back[0], y=back[1])
        face = d("Node", fold, *self.pages(), left, right, edge, x=0.0, y=0.0, rotation=round(theta, 5),
                 name="NewspaperFace")
        plane_n = d("Node", face, x=0.0, y=0.0, rotation=round(phi, 5), scaleX=round(sx, 5), scaleY=round(sy, 5),
                    name="NewspaperPlane")
        self.tilt = d("Node", plane_n, x=0.0, y=0.0, name="NewspaperTip")
        hip = hip_pose()
        self.node = d("Node", self.tilt, x=hip.x - BODY_ORIGIN[0], y=hip.y - BODY_ORIGIN[1], rotation=hip.rot,
                      opacity=0.0, name="Newspaper")
        self.tilt.attrs["scaleY"] = hip.sy
        self._fit(self.node)
        return self.node

    def page_shadow(self, face: El, head_frame: tuple[float, float]) -> El:
        """The paper's soft shadow on the face from below (multiply, clipped by the face), opacity
        keyed 0 -> SHADOW while out (the clips' glow track)."""
        d = self.d
        grad = d("RadialGradient", d("GradientStop", colorValue="C0" + SHADOW_C[2:], position=0.0),
                 d("GradientStop", colorValue="00" + SHADOW_C[2:], position=1.0),
                 startX=0.0, startY=0.0, endX=150.0, endY=0.0)
        shape = d("Shape", d("ClippingShape", sourceId=face.ref(), name="Clip"),
                  d("Ellipse", width=300.0, height=300.0, name="Path"), d("Fill", grad, name="Fill"),
                  x=0.0, y=0.0, scaleY=0.62, blendModeValue=24, name="PageShadowPool")
        node = d("Node", shape, x=436.0 - head_frame[0], y=560.0 - head_frame[1], opacity=0.0, name="PageShadow")
        self._fit(node)
        self.glows.append(node)
        return node

    def extend_layer(self, layer: El, tablet: dict[str, El], anims: dict[str, El]) -> None:
        """Add the newspaper's out / hold / away states to the tablet's `Prop` layer (the layer and
        every tablet state keep their ids). The two props never show together: each prop's out and
        hold put it away on any other value, and its put-away only hands over at its end (back to
        none, then the other prop's out)."""
        d = self.d

        def go(to: El, *conds: El, ms: int = 0, exit_pct: float | None = None) -> El:
            kw: dict[str, object] = {}
            if exit_pct is not None:
                kw = dict(enableExitTime=True, exitTimeIsPercetange=True, exitTime=exit_pct)
            return d("StateTransition", *conds, stateToId=to.ref(), duration=ms or None, **kw)

        out, hold, away = (d("AnimationState", animationId=anims[f"prop_newspaper_{c}"].ref(), x=float(160 * i),
                             y=float(400 + 120 * (i % 2))) for i, c in enumerate(("out", "hold", "away"), start=1))
        tablet["none"].add(go(out, self._is("newspaper"), ms=BLEND_IN))
        for st in (out, hold):
            st.add(go(away, self._is("none"), ms=BLEND_AWAY), go(away, self._is("tablet"), ms=BLEND_AWAY))
        out.add(go(hold, exit_pct=100))
        away.add(go(out, self._is("newspaper"), ms=BLEND_BACK, exit_pct=55),
                 go(hold, self._is("newspaper"), ms=BLEND_BACK),
                 go(tablet["none"], ms=BLEND_END, exit_pct=100))
        for st in (tablet["out"], tablet["hold"]):  # the tablet goes away on newspaper too, never both
            st.add(go(tablet["away"], self._is("newspaper"), ms=BLEND_AWAY))
        at = layer.children.index(tablet["away"]) + 1
        layer.children[at:at] = [out, hold, away]
        self.states = {"out": out, "hold": hold, "away": away}
