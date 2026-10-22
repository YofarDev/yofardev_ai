"""Generates rive/avatar/avatar.rml (artboard `Avatar`, see rive/CONTRACT.md).

All art is authored in absolute artboard coordinates (800x1000); `Rig` turns
that into pivot nodes + local shape coordinates so keyed nodes rotate/scale
around sensible joints.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from rml import Doc, El, ellipse, fill, lin, rad, smooth_path, solid, stroke, track, write  # noqa: E402

d = Doc(client=0, start=10)
W, H = 800, 1000
PI = math.pi

# ---------------------------------------------------------------- palette
INK = "FF3A2622"          # warm line colour, never pure black
SKIN = "FFF6D3BC"
SKIN_SH = "FFE3AE95"
SKIN_SH2 = "FFD0937C"
BLUSH = "FFF08F86"
HAIR = "FF3B2A26"
HAIR_HI = "FF5C443B"
HAIR_SH = "FF2A1D1A"
IRIS_A = "FFB0702F"
IRIS_B = "FF5A3317"
SCLERA = "FFFFFBF6"
FRAME = "FF1F1C20"
HOOD = "FFE9C9EA"
HOOD_SH = "FFCDA2D6"
HOOD_SH2 = "FFB487C2"
HOOD_INK = "FF6E4A78"
STRING = "FFF3EEF4"
BEANIE = "FF94401F"
BEANIE_SH = "FF73301A"
BEANIE_HI = "FFB15A30"
MOUTH_IN = "FF6B2A2C"
TONGUE = "FFD9706E"
TEETH = "FFFFFAF5"


class Rig:
    """A pivot node that knows its absolute position."""

    def __init__(self, name: str, ax: float, ay: float, parent: "Rig | None" = None, **kw: object) -> None:
        self.ax, self.ay = ax, ay
        px, py = (parent.ax, parent.ay) if parent else (0.0, 0.0)
        self.el = d("Node", x=float(ax - px), y=float(ay - py), name=name, **kw)
        if parent:
            parent.el.add(self.el)

    def node(self, name: str, ax: float | None = None, ay: float | None = None, **kw: object) -> "Rig":
        return Rig(name, self.ax if ax is None else ax, self.ay if ay is None else ay, self, **kw)

    def add(self, *els: El | None) -> "Rig":
        self.el.add(*els)
        return self


def S(parent: Rig | tuple[float, float], name: str, pts: list, *paints: El | None,
      origin: tuple[float, float] | None = None, closed: bool = True, tension: float = 1.0,
      kids: list[El] | None = None, **kw: object) -> El:
    """Shape whose points are given in absolute artboard space."""
    pax, pay = (parent.ax, parent.ay) if isinstance(parent, Rig) else parent
    if origin is None:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        origin = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
    ox, oy = origin
    loc = [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts]
    path = smooth_path(d, loc, closed=closed, tension=tension)
    return d("Shape", *(kids or []), path, *[p for p in paints if p is not None],
             x=float(ox - pax), y=float(oy - pay), name=name, **kw)


def E(parent: Rig | tuple[float, float], name: str, cx: float, cy: float, w: float, h: float,
      *paints: El | None, kids: list[El] | None = None, **kw: object) -> El:
    pax, pay = (parent.ax, parent.ay) if isinstance(parent, Rig) else parent
    return d("Shape", *(kids or []), ellipse(d, w, h), *[p for p in paints if p is not None],
             x=float(cx - pax), y=float(cy - pay), name=name, **kw)


def F(c: str) -> El:
    return fill(d, c)


def L(c: str = INK, w: float = 3.0) -> El:
    return stroke(d, c, w)


def mirror(pts: list, cx: float = 400) -> list:
    return [(2 * cx - p[0], p[1]) + tuple(p[2:]) for p in reversed(pts)]


def vgrad(y0: float, y1: float, c0: str, c1: str) -> El:
    return d("Fill", lin(d, 0, y0, 0, y1, [(c0, 0.0), (c1, 1.0)]), name="Fill")


EASE = d("CubicEaseInterpolator", x1=0.42, y1=0.0, x2=0.58, y2=1.0)
EASE_OUT = d("CubicEaseInterpolator", x1=0.2, y1=0.0, x2=0.1, y2=1.0)

# ================================================================ RIG
root = Rig("Root", 400, 1000)          # presence moves this
body = root.node("Body", 400, 1000)    # breathing (scaleY)
arm_r = body.node("ArmR", 240, 720)    # character's right = viewer's left
arm_l = body.node("ArmL", 560, 720)
head_base = body.node("HeadBase", 400, 560, scaleX=1.18, scaleY=1.18)
head_mood = head_base.node("HeadMood")
head_g = head_mood.node("HeadGesture")
head = head_g.node("Head", 400, 560)
head.el.attrs["y"] = 22.0   # sit the head lower: art stays authored around y=560


# ---------------------------------------------------------------- arms
def build_arm(rig: Rig, side: int) -> dict[str, Rig]:
    """side=-1 for the viewer-left arm. Rest pose hangs down; wave bends the forearm up."""
    def m(pts: list) -> list:
        # authored for the viewer-left arm; mirror around the centre line for the other
        return mirror(pts) if side == 1 else pts

    def mx(x: float) -> float:
        return 800 - x if side == 1 else x

    elbow = rig.node("Elbow", mx(240), 1030)
    hand = elbow.node("Hand", mx(240), 1350)
    hand_wave = hand.node("HandWave")
    parts: list[El] = []
    # upper sleeve, shoulder cap to below the frame
    up_pts = m([(226, 682), (264, 700), (290, 760), (294, 880), (298, 1070, "c"), (192, 1070, "c"),
                (192, 900), (198, 760)])
    parts.append(S(rig, "UpperArm", up_pts, d("Fill", lin(d, -50, 0, 50, 0, [(HOOD_SH, 0.0), (HOOD, 0.55)]),
                                                 name="Fill"), L(HOOD_INK, 3)))
    parts.insert(0, S(rig, "SleeveFold", m([(214, 820), (236, 860), (226, 940), (220, 900)]), F(HOOD_SH2)))
    parts.insert(0, S(rig, "SleeveFold2", m([(262, 900), (276, 950), (270, 1020), (264, 960)]), F(HOOD_SH2)))
    # forearm: hangs from the elbow at rest (hidden below the frame), folds up for gestures
    fore_pts = m([(198, 1010), (282, 1010), (278, 1200), (276, 1330, "c"), (204, 1330, "c"), (202, 1200)])
    fore = S(elbow, "Forearm", fore_pts, d("Fill", lin(d, -42, 0, 42, 0, [(HOOD_SH, 0.0), (HOOD, 0.6)]),
                                           name="Fill"), L(HOOD_INK, 3))
    cuff = S(elbow, "Cuff", m([(204, 1300), (276, 1300), (274, 1356, "c6"), (206, 1356, "c6")]),
             F(HOOD_SH), L(HOOD_INK, 2.5),
             kids=[S((mx(240), 1328), f"CuffRib{i}", [(mx(214 + i * 13), 1306), (mx(214 + i * 13), 1350)],
                     L(HOOD_SH2, 2), closed=False) for i in range(5)])
    # hand: palm towards the viewer once the forearm is folded up (so fingers point "down" here)
    hp = [(208, 1350), (272, 1350), (282, 1390), (278, 1430), (240, 1442), (204, 1430), (198, 1390)]
    fingers = []
    for i, (fx, ln) in enumerate([(210, 62), (229, 72), (249, 70), (268, 58)]):
        fx2 = mx(fx)
        fingers.append(S(hand_wave, f"Finger{i}", [(fx2 - 9.5, 1416), (fx2 + 9.5, 1416), (fx2 + 9, 1416 + ln - 9),
                                                     (fx2, 1416 + ln), (fx2 - 9, 1416 + ln - 9)],
                         F(SKIN), L(INK, 2.5)))
    thumb = S(hand_wave, "Thumb", m([(270, 1372), (296, 1390), (310, 1420), (302, 1432), (282, 1418),
                                     (268, 1400)]), F(SKIN), L(INK, 2.5))
    palm = S(hand_wave, "Palm", m(hp), F(SKIN), L(INK, 2.5))
    palm_sh = S(hand_wave, "PalmShade", m([(206, 1352), (274, 1352), (276, 1374), (240, 1382), (204, 1374)]),
                F(SKIN_SH))
    crease = S(hand_wave, "PalmCrease", m([(214, 1404), (240, 1396), (262, 1408)]), L(SKIN_SH2, 2), closed=False)
    hand_wave.add(palm_sh, crease, *fingers, thumb, palm)
    elbow.add(cuff, fore)
    rig.add(*parts)
    # front-most first: elbow chain must paint over the upper sleeve
    rig.el.children.sort(key=lambda c: 0 if c is elbow.el else 1)
    return {"arm": rig, "elbow": elbow, "hand": hand, "wave": hand_wave}


ARM_R = build_arm(arm_r, -1)
ARM_L = build_arm(arm_l, 1)

# ---------------------------------------------------------------- torso
torso_pts = [(365, 596), (400, 606), (435, 596), (520, 640), (576, 684), (600, 760), (610, 1010, "c"),
             (190, 1010, "c"), (200, 760), (224, 684), (280, 640)]
torso = S(body, "Torso", torso_pts, vgrad(600, 1000, HOOD, HOOD_SH), L(HOOD_INK, 3.5))
torso_sh = [
    S(body, "ChestShade", [(300, 700), (340, 760), (330, 860), (300, 1000, "c"), (286, 1000, "c"), (296, 860)],
      F(HOOD_SH)),
    S(body, "Fold1", [(352, 880), (366, 930), (360, 1000), (352, 1000), (356, 930)], F(HOOD_SH2)),
    S(body, "Fold2", [(470, 830), (458, 900), (466, 1000), (474, 1000), (466, 900)], F(HOOD_SH2)),
    S(body, "Pocket", [(300, 960), (500, 960)], L(HOOD_SH2, 3), closed=False),
]
# hood: the bunched fabric ring behind the neck + the crossover neckline in front
collar_back = S(body, "HoodBack", [(282, 610), (300, 546), (350, 514), (400, 508), (450, 514), (500, 546),
                                   (518, 610), (470, 604), (400, 598), (330, 604)],
                d("Fill", lin(d, 0, -40, 0, 40, [(HOOD_SH, 0.0), (HOOD_SH2, 1.0)]), name="Fill"), L(HOOD_INK, 3))
band = [(278, 616), (318, 598), (356, 610), (390, 650), (408, 706, "c"), (388, 708), (360, 668), (324, 636),
        (290, 634)]
collar_l = S(body, "CollarL", band, vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3))
collar_r = S(body, "CollarR", mirror(band), vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3))


def string(x0: float, x1: float, name: str) -> El:
    tip = d("Shape", d("Rectangle", width=12.0, height=26.0, cornerRadiusTL=4.0, cornerRadiusTR=4.0,
                       cornerRadiusBL=4.0, cornerRadiusBR=4.0, name="Path"),
            F("FFBFB6C4"), L(HOOD_INK, 2), x=float(x1 - 400), y=float(905 - 1000), name=name + "Tip")
    cord = S(body, name, [(x0, 660), (x0 + (x1 - x0) * 0.4, 760), (x1, 890)], L(HOOD_INK, 9), closed=False)
    cord_in = S(body, name + "In", [(x0, 660), (x0 + (x1 - x0) * 0.4, 760), (x1, 890)], L(STRING, 5.5),
                closed=False)
    return d("Node", tip, cord_in, cord, name=name + "Group")


strings = [string(360, 352, "StringL"), string(440, 452, "StringR")]

neck = S(body, "Neck", [(370, 470), (430, 470), (432, 560), (446, 606), (400, 640), (354, 606), (368, 560)],
         F(SKIN), L(INK, 3))
chin_sh = S(body, "ChinShadow", [(372, 600), (400, 612), (428, 600), (420, 640), (400, 650), (380, 640)], F(SKIN_SH))
neck_sh = S(body, "NeckShade", [(368, 480), (432, 480), (432, 540), (400, 566), (368, 540)], F(SKIN_SH))

# ---------------------------------------------------------------- head
face_pts = [(294, 330), (298, 402), (316, 452), (350, 488), (386, 508), (400, 511), (414, 508), (450, 488),
            (484, 452), (502, 402), (506, 330), (490, 262), (400, 222), (310, 262)]
face = S(head, "Face", face_pts, vgrad(260, 520, SKIN, "FFF3C9AF"), L(INK, 3.2))
# hair casts a soft band of shadow onto the forehead/temples
face_cast = S(head, "FaceCast", [(298, 300), (330, 330), (370, 336), (400, 330), (440, 340), (480, 332),
                                 (502, 300), (504, 352), (490, 360), (470, 352), (440, 362), (400, 356),
                                 (360, 362), (320, 356), (300, 366)], F(SKIN_SH))
jaw_sh = S(head, "CheekShade", [(502, 360), (498, 410), (484, 452), (452, 490), (424, 509), (446, 484),
                                (474, 446), (488, 404)], F(SKIN_SH))
ear_l = S(head, "EarL", [(300, 372), (282, 360), (272, 380), (278, 412), (292, 436), (304, 430)],
          F(SKIN), L(INK, 3))
ear_r = S(head, "EarR", mirror([(300, 372), (282, 360), (272, 380), (278, 412), (292, 436), (304, 430)]),
          F(SKIN), L(INK, 3))
ear_in_l = S(head, "EarInL", [(296, 384), (286, 378), (284, 396), (292, 414)], L(SKIN_SH2, 3), closed=False)
ear_in_r = S(head, "EarInR", mirror([(296, 384), (286, 378), (284, 396), (292, 414)]), L(SKIN_SH2, 3),
             closed=False)
nose = S(head, "Nose", [(406, 446), (400, 454), (392, 452)], L(SKIN_SH2, 3), closed=False)
nose_sh = S(head, "NoseShade", [(404, 408), (410, 440), (406, 450), (402, 430)], F(SKIN_SH))
mole = E(head, "Mole", 456, 432, 5, 5, F("FF5A3A32"))

# ---- eyes (mood/blink/look each key their own node)
eyes = head.node("Eyes", 400, 385)


def build_eye(cx: float, side: int) -> dict[str, El | Rig]:
    eye = eyes.node("Eye" + ("L" if side < 0 else "R"), cx, 388, scaleX=1.06, scaleY=1.06)
    blink = eye.node("Blink", cx, 392)
    look = blink.node("Look", cx, 388)          # joystick moves this
    s = side
    # almond: outer corner (away from nose) slightly lower and sharper
    o = cx + 30 * s
    i = cx - 28 * s
    white_pts = [(i, 390), (cx - 14 * s, 372), (cx + 6 * s, 368), (o - 6 * s, 374), (o, 392, "c"),
                 (cx + 8 * s, 404), (cx - 12 * s, 403)]
    clip_src = S(blink, "EyeClip", white_pts)
    clip_src.children = [c for c in clip_src.children if c.tag not in ("Fill", "Stroke")]
    def clip() -> El:
        return d("ClippingShape", sourceId=clip_src.ref(), name="Clip")
    iris_parts = [
        E(look, "Shine", cx - 7 * s - 1, 379, 10, 8, F("FFFFFFFF"), kids=[clip()]),
        E(look, "Shine2", cx + 7 * s, 397, 5, 5, F("D0FFFFFF"), kids=[clip()]),
        E(look, "Pupil", cx, 389, 14, 17, F("FF1E120C"), kids=[clip()]),
        E(look, "IrisRing", cx, 388, 32, 36, L("FF2B1A12", 2.2), kids=[clip()]),
        E(look, "Iris", cx, 388, 32, 36,
          d("Fill", rad(d, 0, 8, 22, [(IRIS_A, 0.0), (IRIS_B, 1.0)]), name="Fill"), kids=[clip()]),
    ]
    look.add(*iris_parts)
    white = S(blink, "White", white_pts, F(SCLERA))
    upper = S(blink, "Lash", [(i - 3 * s, 393), (cx - 15 * s, 368), (cx + 6 * s, 363), (o - 2 * s, 369),
                              (o + 9 * s, 384, "c"), (o + 1 * s, 381), (cx + 6 * s, 373), (cx - 14 * s, 377),
                              (i + 2 * s, 394, "c")], F("FF2A1B18"))
    lid_sh = S(blink, "Crease", [(cx - 12 * s, 360), (cx + 8 * s, 356), (o + 2 * s, 364)], L(SKIN_SH2, 2),
               closed=False)
    lower = S(blink, "LowerLid", [(i + 6 * s, 403), (cx - 8 * s, 406), (cx + 14 * s, 402)], L("B03A2622", 2),
              closed=False)
    blink.el.children = []
    blink.add(upper, lower, lid_sh, look.el, white, clip_src)
    # happy squint: a cheek-coloured lid that rises over the lower half of the eye
    squint = S(eye, "Squint", [(i - 6 * s, 404), (cx, 386), (o + 6 * s, 400), (o + 8 * s, 420, "c"),
                               (i - 8 * s, 420, "c")], F(SKIN), origin=(cx, 412), scaleY=0.0)
    squint_line = S((cx, 412), "SquintLine", [(i - 2 * s, 402), (cx, 389), (o + 2 * s, 399)], L(INK, 2.2),
                    closed=False)
    squint.children.insert(0, squint_line)
    eye.add(squint)
    eye.el.children.reverse()   # squint in front of the blink rig
    brow = eyes.node("Brow" + ("L" if side < 0 else "R"), cx, 346)
    brow.add(S(brow, "BrowShape", [(cx - 30 * s, 342, "c"), (cx - 8 * s, 335), (cx + 16 * s, 335),
                                   (cx + 36 * s, 344, "c"), (cx + 16 * s, 341), (cx - 8 * s, 341)], F(HAIR)))
    return {"eye": eye, "blink": blink, "look": look, "squint": squint, "brow": brow}


EYE_L = build_eye(355, -1)
EYE_R = build_eye(445, 1)
blush = head.node("Blush", 400, 440, opacity=0.0)
blush.add(E(blush, "BlushL", 340, 438, 48, 18, d("Fill", rad(d, 0, 0, 24, [("AAF08F86", 0.0), ("00F08F86", 1.0)]), name="Fill")),
          E(blush, "BlushR", 460, 438, 48, 18, d("Fill", rad(d, 0, 0, 24, [("AAF08F86", 0.0), ("00F08F86", 1.0)]), name="Fill")))

# ---- mouth: closed lines keyed by mood, opening keyed by the mouth blend
mouth = head.node("Mouth", 400, 478)
lines = mouth.node("Lines")            # mouth layer fades these when open
line_neutral = S(mouth, "LineNeutral", [(382, 479), (400, 477), (418, 479)], L(INK, 3), closed=False)
line_smile = S(mouth, "LineSmile", [(378, 472), (390, 482), (400, 484), (410, 482), (422, 472)], L(INK, 3),
               closed=False, opacity=0.0)
lines.add(line_neutral, line_smile)
open_ = mouth.node("Open", 400, 474, scaleY=0.0, opacity=0.0)
open_mood = open_.node("OpenMood")
mo_pts = [(374, 472), (400, 470), (426, 472), (420, 492), (400, 504), (380, 492)]
mo = S(open_mood, "Inside", mo_pts, F(MOUTH_IN), L(INK, 2.6))
teeth_src = S(open_mood, "InsideClip", mo_pts)
teeth_src.children = [c for c in teeth_src.children if c.tag not in ("Fill", "Stroke")]
teeth = S(open_mood, "Teeth", [(372, 466), (428, 466), (426, 478), (400, 480), (374, 478)], F(TEETH),
          kids=[d("ClippingShape", sourceId=teeth_src.ref(), name="Clip")])
tongue = E(open_mood, "Tongue", 400, 502, 34, 18, F(TONGUE), kids=[d("ClippingShape", sourceId=teeth_src.ref(), name="Clip")])
open_mood.add(teeth, tongue, mo, teeth_src)

# ---- glasses
glasses = head.node("Glasses", 400, 388)


def lens(cx: float, s: int) -> El:
    pts = [(cx - 43, 364, "c12"), (cx + 43, 364, "c12"), (cx + 41, 410, "c14"), (cx - 41, 410, "c14")]
    return S(glasses, "Lens" + ("L" if s < 0 else "R"), pts, F("14B8D8F0"), L(FRAME, 4.2))


glare = S(glasses, "Glare", [(330, 370), (346, 370), (322, 402), (310, 402)], F("40FFFFFF"))
glare2 = S(glasses, "Glare2", [(420, 370), (436, 370), (412, 402), (402, 402)], F("33FFFFFF"))
bridge = S(glasses, "Bridge", [(398, 378), (400, 374), (402, 378)], L(FRAME, 5), closed=False)
temple_l = S(glasses, "TempleL", [(311, 370), (296, 368)], L(FRAME, 6), closed=False)
temple_r = S(glasses, "TempleR", [(489, 370), (504, 368)], L(FRAME, 6), closed=False)
glasses.add(glare, glare2, lens(355, -1), lens(445, 1), bridge, temple_l, temple_r)

# ---- hair


def lock(name: str, root: tuple[float, float], tip: tuple[float, float], w: float, bend: float,
         base: str = HAIR) -> El:
    """A curved hair clump: fat at the root, pointed tip, bowed sideways by `bend`."""
    (rx, ry), (tx, ty) = root, tip
    dx, dy = tx - rx, ty - ry
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln          # normal
    def at(t: float, off: float) -> tuple[float, float]:
        bow = math.sin(math.pi * t) * bend
        return (rx + dx * t + nx * (off + bow), ry + dy * t + ny * (off + bow))
    pts = [at(0, -w / 2), at(0.45, -w * 0.42), at(0.8, -w * 0.2), (tx + nx * bend * 0.1, ty, "c"),
           at(0.78, w * 0.16), at(0.42, w * 0.44), at(0, w / 2)]
    return S(head, name, pts, d("Fill", lin(d, 0, -ln / 2, 0, ln / 2, [(HAIR_HI, 0.0), (base, 0.5), (HAIR_SH, 1.0)]),
                                name="Fill"), L(HAIR_SH, 2.4))


LOCKS = [((300, 272), (292, 404), 44, -8), ((330, 246), (318, 366), 50, 12), ((360, 236), (350, 338), 50, 10),
         ((396, 230), (420, 368), 70, 18), ((436, 234), (452, 334), 52, 10), ((470, 248), (490, 376), 58, 9),
         ((498, 276), (510, 410), 40, 6), ((380, 236), (372, 318), 30, 6), ((452, 242), (474, 322), 28, 6)]
# paint order: centre locks in front of the outer ones, thin accent strands on top
order = [7, 8, 3, 2, 4, 1, 5, 0, 6]
locks = [lock(f"Lock{i}", *LOCKS[i]) for i in order]
cap = S(head, "HairCap", [(290, 340), (294, 270), (330, 232), (400, 214), (470, 232), (506, 270), (510, 340),
                           (470, 300), (400, 292), (330, 300)],
        d("Fill", lin(d, 0, -60, 0, 60, [(HAIR_HI, 0.0), (HAIR, 0.6)]), name="Fill"), L(HAIR_SH, 2.4))
# angel-ring highlight: one band clipped to the hair so it follows every lock
ring_clip = d("Shape", *[d("ClippingShape", sourceId=lk.ref(), name="Clip") for lk in locks],
              smooth_path(d, [(-120, 6), (-60, -12), (0, -16), (60, -12), (120, 6), (60, 4), (0, 0), (-60, 4)]),
              F("55E6C6B2"), x=0.0, y=float(262 - 560), name="HairShine")
shine: list[El] = []   # multi-source clips intersect; lock gradients carry the sheen instead
side_l = S(head, "SideLockL", [(300, 330), (314, 370), (308, 430), (296, 466, "c"), (290, 420), (288, 360)],
           F(HAIR), L(HAIR_SH, 2.5))
side_r = S(head, "SideLockR", mirror([(300, 330), (314, 370), (308, 430), (296, 466, "c"), (290, 420),
                                      (288, 360)]), F(HAIR), L(HAIR_SH, 2.5))
hair_back = S(head, "HairBack", [(286, 430), (272, 340), (284, 262), (334, 212), (400, 196), (466, 212),
                                 (516, 262), (528, 340), (514, 430), (534, 478, "c"), (500, 466), (488, 420),
                                 (312, 420), (300, 466), (266, 478, "c")], F(HAIR_SH), L(HAIR_SH, 2))
# messy top tufts, only visible without a hat
tufts = head.node("Tufts")
tufts.add(S(head, "Cowlick", [(380, 232), (372, 206), (384, 186), (404, 180, "c"), (392, 196), (392, 214),
                              (404, 230)], F(HAIR), L(HAIR_SH, 2.5)),
          S(head, "Cowlick2", [(408, 230), (420, 204), (444, 194, "c"), (434, 210), (428, 232)], F(HAIR), L(HAIR_SH, 2.5)))

# ---- hats
hats = head.node("Hats")
beanie = hats.node("Beanie", 400, 280)
band_pts = [(280, 322, "c8"), (284, 276), (330, 258), (400, 252), (470, 258), (516, 276), (520, 322, "c8"),
            (470, 308), (400, 302), (330, 308)]
dome_pts = [(290, 282), (294, 214), (330, 168), (392, 146), (452, 154), (500, 190), (512, 240), (510, 282)]
ribs = [S(beanie, f"Rib{i}", [(x0, 262 - (x0 - 400) ** 2 / 2600), (x0, 306 - (x0 - 400) ** 2 / 2000)],
          L(BEANIE_SH, 3.2), closed=False) for i, x0 in enumerate(range(298, 506, 16))]
band = S(beanie, "Band", band_pts, d("Fill", lin(d, 0, -30, 0, 30, [(BEANIE_HI, 0.0), (BEANIE, 0.5), (BEANIE_SH, 1.0)]),
                                     name="Fill"), L(INK, 3), origin=(400, 290))
for r_ in ribs:
    r_.children.insert(0, d("ClippingShape", sourceId=band.ref(), name="Clip"))
dome = S(beanie, "Dome", dome_pts, d("Fill", rad(d, -50, -50, 200, [(BEANIE_HI, 0.0), (BEANIE, 0.5), (BEANIE_SH, 1.0)]), name="Fill"),
         L(INK, 3))
fold1 = S(beanie, "Crease1", [(336, 200), (380, 186), (430, 192)], L(BEANIE_SH, 3), closed=False)
fold2 = S(beanie, "Crease2", [(318, 238), (390, 226), (470, 236)], L(BEANIE_SH, 3), closed=False)
beanie.add(*ribs, band, fold1, fold2, dome)

# head paint order (front first)
head.el.children = []
head.add(hats.el, glasses.el, *shine, *locks, cap, side_l, side_r, eyes.el, blush.el, mouth.el, mole, nose,
         nose_sh, jaw_sh, face_cast, face, ear_in_l, ear_in_r, ear_l, ear_r, tufts.el, hair_back)
# brows in front of the eyes, behind the fringe
eyes.el.children.sort(key=lambda c: 0 if c.attrs.get("name", "").startswith("Brow") else 1)

body.el.children = []
body.add(ARM_R["arm"].el, ARM_L["arm"].el, head_base.el, *strings, collar_l, collar_r, chin_sh, neck_sh, neck,
         collar_back, *torso_sh, torso)

# ================================================================ VIEW MODEL
CONTRACT_ENUMS = {
    "Mood": ["neutral", "happy", "sad", "angry", "surprised", "thinking", "embarrassed"],
    "Phase": ["idle", "waiting", "generating", "speaking", "error"],
    "GestureId": ["wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think"],
    "Hat": ["noHat", "beanie", "backwardsCap", "frenchBeret", "swimCap", "santaHat", "redMagaCap"],
    "Top": ["pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie"],
    "Glasses": ["glasses", "sunglasses"],
    "Costume": ["none", "batman", "robocop", "soubrette", "singularity"],
    "Presence": ["onScreen", "outOfScreen", "leaveAndComeBack"],
}
enums: dict[str, El] = {}
evals: dict[str, dict[str, El]] = {}
for en, vals in CONTRACT_ENUMS.items():
    vs = {v: d("DataEnumValue", key=v, value=v) for v in vals}
    enums[en] = d("DataEnumCustom", *vs.values(), name=en)
    evals[en] = vs

vm = d("ViewModel", name="AvatarVM")
props: dict[str, El] = {}


def prop_enum(name: str, en: str) -> None:
    props[name] = d("ViewModelPropertyEnumCustom", enumId=enums[en].ref(), name=name)


prop_enum("mood", "Mood")
props["mouth"] = d("ViewModelPropertyNumber", name="mouth")
prop_enum("phase", "Phase")
prop_enum("gestureId", "GestureId")
props["gesture"] = d("ViewModelPropertyTrigger", name="gesture")
prop_enum("hat", "Hat")
prop_enum("top", "Top")
prop_enum("glasses", "Glasses")
prop_enum("costume", "Costume")
prop_enum("presence", "Presence")
DEFAULTS = {"mood": "neutral", "phase": "idle", "gestureId": "wave", "hat": "noHat", "top": "pinkHoodie",
            "glasses": "glasses", "costume": "none", "presence": "onScreen"}
EN_OF = {"mood": "Mood", "phase": "Phase", "gestureId": "GestureId", "hat": "Hat", "top": "Top",
         "glasses": "Glasses", "costume": "Costume", "presence": "Presence"}
ivals = []
for pn, p in props.items():
    if pn in DEFAULTS:
        ivals.append(d("ViewModelInstanceEnum", propertyValue=evals[EN_OF[pn]][DEFAULTS[pn]].ref(),
                       viewModelPropertyId=p.ref()))
    elif pn == "mouth":
        ivals.append(d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref()))
    else:
        ivals.append(d("ViewModelInstanceTrigger", viewModelPropertyId=p.ref()))
inst = d("ViewModelInstance", *ivals, exports=True, name="Default")
vm.add(*props.values(), inst)
vm.attrs["defaultInstanceId"] = inst.ref()


def vpath(pn: str) -> str:
    return f"{vm.ref()}-{props[pn].ref()}"


def enum_is(pn: str, val: str) -> El:
    return d("TransitionViewModelCondition",
             d("TransitionPropertyViewModelComparator",
               d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=vpath(pn), propertyKey=637))),
             d("TransitionValueEnumComparator", value=evals[EN_OF[pn]][val].ref()))


def trig(pn: str) -> El:
    return d("TransitionViewModelCondition",
             d("TransitionPropertyViewModelComparator",
               d("BindablePropertyTrigger", d("DataBindContext", sourcePathIds=vpath(pn), propertyKey=686))),
             d("TransitionValueTriggerComparator"))


# ================================================================ ANIMATIONS
anims: list[El] = []


def A(name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
    a = d("LinearAnimation", *tracks, duration=frames, fps=60, loopValue="loop" if loop else None, name=name)
    anims.append(a)
    return a


def T(target: El | Rig, ease: El | None = EASE, **props_: list) -> El:
    tgt = target.el if isinstance(target, Rig) else target
    return track(d, tgt, props_, ease=ease)


# ---- idle: breathing + head bob (own nodes, additive to everything else)
idle_head = head_base
breath = A("idle_breath", 240, [
    T(body, scaleY=[(0, 1.0), (120, 1.012), (240, 1.0)], y=[(0, 0.0), (120, -2.0), (240, 0.0)]),
    T(idle_head, y=[(0, -440.0), (120, -446.0), (240, -440.0)], rotation=[(0, 0.0), (120, 0.012), (240, 0.0)]),
], loop=True)

# ---- blink every ~3.7s, double-blink on the second half
bl = [EYE_L["blink"].el, EYE_R["blink"].el]
blink_keys = [(0, 1.0), (150, 1.0), (154, 0.08), (159, 1.0), (196, 1.0), (200, 0.08), (205, 1.0), (222, 1.0)]
blink = A("idle_blink", 222, [T(b, ease=None, scaleY=blink_keys) for b in bl], loop=True)

# ---- look: joystick scrubs these (x: -1..1 -> frames 0..100)
LOOK_X, LOOK_Y = 7.0, 4.5
look_x = A("look_x", 100, [T(EYE_L["look"].el, ease=None, x=[(0, -LOOK_X), (100, LOOK_X)]),
                           T(EYE_R["look"].el, ease=None, x=[(0, -LOOK_X), (100, LOOK_X)]),
                           T(head_g, ease=None, rotation=[(0, -0.035), (100, 0.035)])])
look_y = A("look_y", 100, [T(EYE_L["look"].el, ease=None, y=[(0, -LOOK_Y), (100, LOOK_Y)]),
                           T(EYE_R["look"].el, ease=None, y=[(0, -LOOK_Y), (100, LOOK_Y)])])

# ---- moods (one pose each; layer crossfades)
brows = [EYE_L["brow"], EYE_R["brow"]]
squints = [EYE_L["squint"], EYE_R["squint"]]


def mood_pose(name: str, brow_y: float, brow_rot: float, squint: float, smile: float, blush_o: float,
              tilt: float, open_w: float) -> El:
    tr = []
    for i, b in enumerate(brows):
        s = -1 if i == 0 else 1
        tr.append(T(b, ease=None, y=[(0, -39.0 + brow_y)], rotation=[(0, brow_rot * s)]))
    for sq in squints:
        tr.append(T(sq, ease=None, scaleY=[(0, squint)]))
    tr += [T(line_smile, ease=None, opacity=[(0, smile)]), T(line_neutral, ease=None, opacity=[(0, 1 - smile)]),
           T(blush, ease=None, opacity=[(0, blush_o)]), T(head_mood, ease=None, rotation=[(0, tilt)]),
           T(open_mood, ease=None, scaleX=[(0, open_w)])]
    return A("mood_" + name, 1, tr)


MOODS = {
    "neutral": mood_pose("neutral", 0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
    "happy": mood_pose("happy", -5, -0.08, 1.0, 1.0, 1.0, -0.05, 1.15),
}

# ---- mouth 0..4 (closed, slightly, semi, open, wide)
MOUTH = [(0.0, 0.0, 1.0, 1.0), (0.28, 1.0, 0.0, 0.92), (0.55, 1.0, 0.0, 0.96), (0.85, 1.0, 0.0, 1.0),
         (1.1, 1.0, 0.0, 1.18)]
mouth_anims = [A(f"mouth_{i}", 1, [T(open_, ease=None, scaleY=[(0, sy)], opacity=[(0, op)], scaleX=[(0, sx)]),
                                     T(lines, ease=None, opacity=[(0, lo)])])
               for i, (sy, op, lo, sx) in enumerate(MOUTH)]

# ---- gestures (upper-body layer, own nodes so mood/mouth keep running)
R_EL, R_HAND = ARM_R["elbow"], ARM_R["hand"]
g_idle = A("gesture_none", 1, [T(ARM_R["arm"], ease=None, rotation=[(0, 0.0)]),
                               T(R_EL, ease=None, rotation=[(0, 0.0)]),
                               T(ARM_R["wave"], ease=None, rotation=[(0, 0.0)]),
                               T(head_g, ease=None, y=[(0, 0.0)])])
wave_fore = [(0, 0.0), (16, 2.7), (22, 3.05), (32, 2.86), (42, 3.1), (52, 2.86), (62, 3.1), (72, 2.86),
             (82, 3.0), (100, 0.0)]
g_wave = A("gesture_wave", 104, [
    T(ARM_R["arm"], rotation=[(0, 0.0), (16, 0.22), (84, 0.22), (102, 0.0)]),
    T(R_EL, rotation=wave_fore),
    T(ARM_R["wave"], rotation=[(0, 0.0), (22, 0.0), (32, -0.2), (42, 0.16), (52, -0.2), (62, 0.16),
                               (72, -0.18), (84, 0.0)]),
    T(head_g, y=[(0, 0.0), (20, -4.0), (84, -4.0), (100, 0.0)], rotation=[(0, 0.0), (20, -0.04), (84, -0.04), (100, 0.0)]),
])

# ---- hats
HATS = {"noHat": [], "beanie": [beanie]}
hat_anims = {}
for hn in ["noHat", "beanie"]:
    hat_anims[hn] = A("hat_" + hn, 1, [T(beanie, ease=None, opacity=[(0, 1.0 if hn == "beanie" else 0.0)]),
                                       T(tufts, ease=None, opacity=[(0, 0.0 if hn == "beanie" else 1.0)])])
beanie.el.attrs["opacity"] = 0.0

# ================================================================ STATE MACHINE
EVENTS = {
    "gesture_done": d("Event", d("CustomPropertyString", propertyValue="wave", name="gestureId"),
                      name="gesture_done"),
}


def layer(name: str, entry_to: El, states: list[El], any_trans: list[El] | None = None) -> El:
    return d("StateMachineLayer",
             d("AnyState", *(any_trans or []), x=float(100), y=float(-100)),
             d("ExitState", x=float(500), y=float(-100)),
             d("EntryState", d("StateTransition", stateToId=entry_to.ref()), x=float(-100), y=float(-100)),
             *states, name=name)


def st(a: El, i: int, *kids: El, row: int = 0) -> El:
    return d("AnimationState", *kids, animationId=a.ref(), x=float(160 * i), y=float(100 + 120 * row))


layers = []
s = st(breath, 0)
layers.append(layer("Breath", s, [s]))
s = st(blink, 0)
layers.append(layer("Blink", s, [s]))

mood_states = {m: st(a, i) for i, (m, a) in enumerate(MOODS.items())}
layers.append(layer("Mood", mood_states["neutral"], list(mood_states.values()),
                    [d("StateTransition", enum_is("mood", m), stateToId=s_.ref(), duration=220)
                     for m, s_ in mood_states.items()]))

mouth_conv = d("DataConverterRangeMapper", minInput=0.0, maxInput=4.0, minOutput=0.0, maxOutput=100.0,
               clampLower=True, clampUpper=True, name="MouthToBlend")
mouth_blend = d("BlendState1DViewModel",
                d("BindablePropertyNumber", d("DataBindContext", sourcePathIds=vpath("mouth"), propertyKey=636,
                                              converterId=mouth_conv.ref())),
                *[d("BlendAnimation1D", animationId=a.ref(), value=float(i * 25)) for i, a in enumerate(mouth_anims)],
                x=0.0, y=100.0)
layers.append(layer("Mouth", mouth_blend, [mouth_blend]))

gs_idle = st(g_idle, 0)
gs = {"wave": st(g_wave, 1,
                 d("StateMachineFireEvent", eventId=EVENTS["gesture_done"].ref(), occursValue="atEnd"),
                 d("StateTransition", stateToId=gs_idle.ref(), enableExitTime=True, exitTimeIsPercetange=True,
                   exitTime=100, duration=150))}
for gn, gst in gs.items():
    gs_idle.add(d("StateTransition", trig("gesture"), enum_is("gestureId", gn), stateToId=gst.ref(), duration=120))
layers.append(layer("Gesture", gs_idle, [gs_idle, *gs.values()]))

hat_states = {h: st(a, i) for i, (h, a) in enumerate(hat_anims.items())}
layers.append(layer("Hat", hat_states["noHat"], list(hat_states.values()),
                    [d("StateTransition", enum_is("hat", h), stateToId=s_.ref()) for h, s_ in hat_states.items()]))

# eyes follow the pointer: move/drag anywhere aligns a handle the joystick reads
look_handle = d("Node", x=400.0, y=420.0, name="LookHandle")
hit = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
        F("00000000"), name="HitArea")
listeners = [d("StateMachineListenerSingle", d("ListenerAlignTarget", targetId=look_handle.ref()),
               targetId=hit.ref(), listenerTypeValue=lt, name="Look" + lt.title()) for lt in ("move", "down", "drag")]
sm = d("StateMachine", *listeners, *layers, name="Main")
joy = d("Joystick", posX=400.0, posY=420.0, width=900.0, height=700.0, xId=look_x.ref(), yId=look_y.ref(),
        handleSourceId=look_handle.ref(), name="Look")

style = d("LayoutComponentStyle", name="Artboard Style")
artboard = d("Artboard", style, sm, EASE, EASE_OUT, *EVENTS.values(), joy, look_handle, root.el, hit, *anims,
             width=float(W), height=float(H), name="Avatar", defaultStateMachineId=sm.ref(), viewModelId=vm.ref(),
             viewModelInstanceId=inst.ref(), styleId=style.ref(), clip=True)

out = os.path.join(os.path.dirname(__file__), "..", "avatar", "avatar.rml")
os.makedirs(os.path.dirname(out), exist_ok=True)
write(out, [artboard, *enums.values(), mouth_conv, vm])
print("wrote", os.path.normpath(out), "next id", d.next)
