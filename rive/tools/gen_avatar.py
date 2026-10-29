"""Generates rive/avatar/avatar.rml (artboard `Avatar`, see rive/CONTRACT.md).

Art is authored in absolute artboard coordinates (800x1000); `Rig` turns that
into pivot nodes + local shape coordinates. Every state-machine layer keys its
OWN nodes (HeadMood, HeadPhase, HeadLook, HeadGesture, GazeM/GazeP/GazeG...) so
mood, phase, gestures, blinking and eye-follow compose additively.
Wardrobe/costumes are `Solo` switches: Hat/Top/Glasses layers pick a child, the
later Costume layer overrides them while a costume is on (its `none` state keys
nothing, which hands control back).
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from avatar_kit import (BEANIE, BEANIE_HI, BEANIE_SH, FRAME, HAIR, HAIR_HI, HAIR_SH, HOOD, HOOD_INK, HOOD_SH,  # noqa: E402
                        HOOD_SH2, INK, IRIS_A, IRIS_B, MOUTH_IN, PI, SCLERA, SKIN, SKIN_SH, SKIN_SH2, STRING,
                        TEETH, TONGUE, WHITE, E, F, L, L1, L2, R, Rig, S, clip_only, d, grad, group, hgrad, ik, mirror,
                        rgrad, vgrad)
from rml import Doc, El, lin, rad, smooth_path, track, write  # noqa: E402
from wardrobe_art import Cloth, refine as refine_wardrobe  # noqa: E402
from head_turn import HeadTurn, rig_head  # noqa: E402
import face_rig  # noqa: E402
from face_rig import NUMBERS as FACE_NUMBERS  # noqa: E402


def named_el(root_el: El, name: str) -> El:
    return next(e for e in _walk(root_el) if e.attrs.get("name") == name)


def _walk(e: El):  # type: ignore[no-untyped-def]
    yield e
    for c in e.children:
        yield from _walk(c)

W, H = 800, 1000
rnd = random.Random(42)

EASE = d("CubicEaseInterpolator", x1=0.42, y1=0.0, x2=0.58, y2=1.0)
EASE_OUT = d("CubicEaseInterpolator", x1=0.18, y1=0.7, x2=0.35, y2=1.0)
EASE_IN = d("CubicEaseInterpolator", x1=0.6, y1=0.0, x2=0.85, y2=0.45)

# ================================================================ RIG
root = Rig("Root", 400, 1000)              # presence walks this
body = root.node("Body", 400, 1000)        # breathing
body_g = body.node("BodyGesture")          # gesture bounce/shrug
swing_r = body_g.node("SwingR", 240, 720)  # walk arm swing (presence layer)
swing_l = body_g.node("SwingL", 560, 720)
arm_r = swing_r.node("ArmR", 240, 720)     # character's right = viewer's left
arm_l = swing_l.node("ArmL", 560, 720)
head_base = body_g.node("HeadBase", 400, 560, scaleX=1.18, scaleY=1.18)
head_mood = head_base.node("HeadMood")
head_phase = head_mood.node("HeadPhase")
head_travel = head_phase.node("HeadTravel")
head_look = head_travel.node("HeadLook")
head_g = head_look.node("HeadGesture")
head = head_g.node("Head", 400, 560)
head.el.attrs["y"] = 22.0   # sit the head lower: art stays authored around y=560

TOP_IDS = ["pinkHoodie", "longCoat", "tshirt", "underwear", "swimsuit", "christmasSweater", "blackSuitAndTie"]
COSTUMES = ["batman", "robocop", "soubrette", "singularity"]
HAT_IDS = ["noHat", "beanie", "backwardsCap", "frenchBeret", "swimCap", "santaHat", "redMagaCap"]

# ================================================================ ARMS
# Sleeve style per outfit: (base, shade, ink, cuff colour or None, kind)
#   kind: "long" full sleeve, "short" tee sleeve over a bare arm, "bare", "puff" (puffed shoulder + long)
SLEEVES: dict[str, tuple[str, str, str, str | None, str]] = {
    "pinkHoodie": (HOOD, HOOD_SH, HOOD_INK, HOOD_SH, "long"),
    "longCoat": ("FFD9C7A3", "FFB49E78", "FF6A5838", "FFFFFFFF", "long"),
    "tshirt": ("FF2A2A30", "FF1A1A1E", "FF0E0E12", "FFC0303A", "short"),
    "underwear": (SKIN, SKIN_SH, INK, None, "bare"),
    "swimsuit": (SKIN, SKIN_SH, INK, None, "bare"),
    "christmasSweater": ("FF2E7D4F", "FF1F5C39", "FF123A24", "FFC8303A", "long"),
    "blackSuitAndTie": ("FF34363E", "FF22242A", "FF101116", "FFFFFFFF", "long"),
    "batman": ("FF3A3F4A", "FF262A32", "FF121418", "FF15171C", "glove"),
    "robocop": ("FFB8C4DC", "FF6A7A9C", "FF2A3450", "FF3A4460", "armor"),
    "soubrette": ("FF221E26", "FF141218", "FF0A080C", "FFFFFFFF", "puff"),
    "singularity": ("FF0E1030", "FF070818", "FF2A2E6A", None, "stars"),
}
OUTFITS = TOP_IDS + COSTUMES


def starfield(parent: Rig, poly: list, n: int, seed: int, prefix: str) -> list[El]:
    """Coloured specks inside `poly` (point-in-polygon, no clipping => cheap)."""
    r = random.Random(seed)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]

    def inside(x: float, y: float) -> bool:
        c = False
        j = len(poly) - 1
        for i in range(len(poly)):
            xi, yi = poly[i][0], poly[i][1]
            xj, yj = poly[j][0], poly[j][1]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                c = not c
            j = i
        return c
    out: list[El] = []
    cols = ["FFFFF3B0", "FF7CF0FF", "FFFF6AD5", "FF9CFF8A", "FFFFFFFF", "FFFFA04A"]
    while len(out) < n:
        x, y = r.uniform(min(xs), max(xs)), r.uniform(min(ys), max(ys))
        if inside(x, y):
            sz = r.choice([3, 4, 4, 5, 7])
            out.append(E(parent, f"{prefix}Star{len(out)}", x, y, sz, sz, F(r.choice(cols)),
                         opacity=r.uniform(0.5, 1.0)))
    return out


# Limbs are capsules: each segment ends in a round cap centred on its joint, so
# rotations never expose a square end. The forearm outline is open at the elbow
# (fill-only top) so the joint reads as one continuous sleeve.
def capsule(cx: float, y0: float, r0: float, y1: float, r1: float, open_top: bool = False) -> list:
    top = [(cx + r0 * math.cos(math.radians(a)), y0 + r0 * math.sin(math.radians(a))) for a in (180, 225, 270, 315)]
    bot = [(cx + r1 * math.cos(math.radians(a)), y1 + r1 * math.sin(math.radians(a))) for a in (0, 45, 90, 135, 180)]
    if open_top:
        return [(cx + r0, y0)] + bot + [(cx - r0, y0)]
    return top + [(cx + r0, y0)] + bot


def limb(rig: Rig, name: str, side: int, y0: float, r0: float, y1: float, r1: float, fill_: El, ink: str,
         w: float = 3.0, open_top: bool = False, dx: float = 0.0) -> list[El]:
    """A capsule segment (fill + outline). `dx` nudges the axis outward for tapering silhouettes."""
    m = (lambda p: mirror(p)) if side == 1 else (lambda p: p)
    cx = 240 - dx
    body_ = S(rig, name, m(capsule(cx, y0, r0, y1, r1)), fill_)
    if not open_top:
        body_.add(L(ink, w))
        return [body_]
    outline = S(rig, name + "Line", m(capsule(cx, y0, r0, y1, r1, open_top=True)), L(ink, w), closed=False,
                origin=None)
    return [outline, body_]


# hand poses, authored at the wrist with the fingers pointing DOWN (rest); `t` = thumb side (+1 = +x)
WX, WY = 240.0, 1070.0


# hand colours (bare skin, or a costume glove); swapped while building each skin variant
HAND_SKINS = {"skin": (SKIN, SKIN_SH, SKIN_SH2, INK), "black": ("FF2E323A", "FF17191E", "FF4A505C", "FF0A0B0E"),
              "metal": ("FFC2CDE2", "FF6E7EA0", "FF8C9AB6", "FF2A3450"),
              "stars": ("FF1A1D58", "FF0B0C2A", "FF4A52C0", "FF3A40A0"),
              "white": ("FFFFFFFF", "FFDDDDE8", "FFB8B8C4", "FF7E7E8C")}
HC: dict[str, str] = dict(zip(("fill", "shade", "line", "ink"), HAND_SKINS["skin"]))
COSTUME_HANDS = {"batman": "black", "robocop": "metal", "singularity": "stars", "soubrette": "white"}


def _finger(rig: Rig, name: str, x: float, y: float, ln: float, wd: float = 15.0, lean: float = 0.0) -> El:
    h = wd / 2
    return S(rig, name, [(x - h, y), (x + h, y), (x + h + lean * 0.8, y + ln - h), (x + lean, y + ln, "c"),
                         (x - h + lean * 0.8, y + ln - h)], F(HC["fill"]), L(HC["ink"], 2.3))


def hand_open(rig: Rig, t: int, side: int, palm_side: bool, short: float = 1.0) -> list[El]:
    def X(x: float) -> float:
        v = WX + (x - WX) * t
        return 800 - v if side == 1 else v
    k = short
    fingers = [_finger(rig, f"Finger{i}", X(fx), WY + 46 * k, ln * k, lean=lean * t * -side)
               for i, (fx, ln, lean) in enumerate([(217, 36, -5), (232, 46, -2), (248, 50, 1), (263, 44, 4)])]
    palm = S(rig, "Palm", [(X(213), WY - 4), (X(267), WY - 4), (X(274), WY + 24 * k), (X(268), WY + 54 * k),
                           (X(WX), WY + 60 * k), (X(212), WY + 54 * k), (X(207), WY + 24 * k)], F(HC["fill"]), L(HC["ink"], 2.4))
    thumb = S(rig, "Thumb", [(X(262), WY + 6), (X(284), WY + 18 * k), (X(296), WY + 40 * k), (X(290), WY + 52 * k),
                             (X(276), WY + 42 * k), (X(262), WY + 30 * k)], F(HC["fill"]), L(HC["ink"], 2.3))
    detail = ([S(rig, "Crease", [(X(216), WY + 36 * k), (X(240), WY + 28 * k), (X(262), WY + 38 * k)],
                 L(HC["line"], 2), closed=False),
               S(rig, "Heel", [(X(214), WY + 2), (X(266), WY + 2), (X(262), WY + 18 * k), (X(WX), WY + 22 * k),
                               (X(216), WY + 18 * k)], F(HC["shade"]))] if palm_side else
              [S(rig, f"Knuckle{i}", [(X(x) - 5, WY + 48 * k), (X(x) + 5, WY + 48 * k)], L(HC["line"], 2), closed=False)
               for i, x in enumerate((232, 248, 263))])
    return [thumb, *detail, palm, *fingers]


def hand_edge(rig: Rig, t: int, side: int) -> list[El]:
    def X(x: float) -> float:
        v = WX + (x - WX) * t
        return 800 - v if side == 1 else v
    blade = S(rig, "Blade", [(X(224), WY - 4), (X(258), WY - 4), (X(264), WY + 40), (X(260), WY + 92),
                             (X(246), WY + 108, "c"), (X(232), WY + 98), (X(226), WY + 50)],
              hgrad(-20, 20, HC["shade"], HC["fill"]), L(HC["ink"], 2.4))
    thumb = S(rig, "Thumb", [(X(252), WY + 8), (X(270), WY + 22), (X(276), WY + 48), (X(266), WY + 52),
                             (X(254), WY + 34)], F(HC["fill"]), L(HC["ink"], 2.3))
    lines = [S(rig, f"Seam{i}", [(X(238 + i * 5), WY + 62 + i * 10), (X(250 + i * 4), WY + 64 + i * 10)],
               L(HC["line"], 1.8), closed=False) for i in range(2)]
    return [thumb, *lines, blade]


def hand_point(rig: Rig, t: int, side: int) -> list[El]:
    def X(x: float) -> float:
        v = WX + (x - WX) * t
        return 800 - v if side == 1 else v
    fist = S(rig, "Fist", [(X(214), WY - 4), (X(266), WY - 4), (X(272), WY + 28), (X(266), WY + 58),
                           (X(WX), WY + 64), (X(214), WY + 58), (X(208), WY + 28)], F(HC["fill"]), L(HC["ink"], 2.4))
    curls = [S(rig, f"Curl{i}", [(X(214), WY + 34 + i * 10), (X(232), WY + 38 + i * 10), (X(248), WY + 36 + i * 10)],
               L(HC["line"], 2), closed=False) for i in range(2)]
    index = _finger(rig, "Index", X(258), WY + 40, 58, 15, lean=2 * t * -side)
    thumb = S(rig, "Thumb", [(X(262), WY + 4), (X(276), WY + 22), (X(270), WY + 44), (X(254), WY + 40),
                             (X(250), WY + 20)], F(HC["fill"]), L(HC["ink"], 2.3))
    return [thumb, index, *curls, fist]


HAND_POSES = ("rest", "palm", "back", "edge", "point", "up")
STAR_FX: list[El] = []        # singularity specks that twinkle


def build_sleeves(rig: Rig, elbow: Rig, side: int) -> tuple[Rig, Rig, dict[str, El], dict[str, El]]:
    mx = (lambda x: 800 - x) if side == 1 else (lambda x: x)
    m = (lambda p: mirror(p)) if side == 1 else (lambda p: p)
    up_solo = rig.solo("UpperSleeve")
    fore_solo = elbow.solo("ForeSleeve")
    ups: dict[str, El] = {}
    fores: dict[str, El] = {}
    for oid in OUTFITS:
        base, shade, ink, cuff, kind = SLEEVES[oid]
        gu = group("Up_" + oid)
        gf = group("Fore_" + oid)
        sl_up = hgrad(-50, 50, shade, base) if side == -1 else hgrad(-50, 50, base, shade)
        sl_fore = hgrad(-42, 42, shade, base) if side == -1 else hgrad(-42, 42, base, shade)
        sk_up = hgrad(-40, 40, SKIN_SH, SKIN) if side == -1 else hgrad(-40, 40, SKIN, SKIN_SH)
        sk_fore = hgrad(-34, 34, SKIN_SH, SKIN) if side == -1 else hgrad(-34, 34, SKIN, SKIN_SH)
        skin_up = limb(rig, "SkinUp", side, 720, 40, 900, 35, sk_up, INK, 2.6)
        skin_fore = limb(elbow, "SkinFore", side, 900, 35, 1066, 30, sk_fore, INK, 2.6, open_top=True)
        if kind == "bare":
            gu.add(S(rig, "Deltoid", m([(212, 712), (226, 744), (222, 790)]), L(SKIN_SH2, 2), closed=False), *skin_up)
            gf.add(S(elbow, "ElbowDimple", m([(232, 902), (240, 908), (248, 902)]), L(SKIN_SH2, 1.8), closed=False),
                   *skin_fore)
        elif kind == "short":
            sleeve = [(195, 716), (204, 685), (237, 673), (271, 684), (289, 715),
                      (284, 799, "c4"), (198, 799, "c4")]
            gu.add(S(rig, "TeeHemStitch", m([(202, 792), (280, 792)]), L("70DA827C", 1.1), closed=False),
                   S(rig, "Trim", m([(198, 786, "c2"), (284, 786, "c2"), (284, 799, "c2"), (198, 799, "c2")]),
                     F(cuff or base), L(ink, 1)),
                   S(rig, "TeeUnderarm", m([(264, 720), (280, 716), (281, 784), (267, 784)]), F(shade)),
                   S(rig, "TeeSleeve", m(sleeve), sl_up, L(ink, 2.3)), *skin_up)
            gf.add(*skin_fore)
        elif kind == "stars":
            gu.add(*starfield(rig, m(capsule(240, 720, 44, 900, 38)), 8, 11 + side, "Up"),
                   *limb(rig, "Sleeve", side, 720, 50, 900, 43, grad([("FF181A48", 0.0), (base, 1.0)], -130, 130),
                         ink, 3))
            fs_ = starfield(elbow, m(capsule(240, 900, 36, 1070, 30)), 6, 21 + side, "Fore")
            STAR_FX.extend(fs_[:2])
            gf.add(*fs_, *limb(elbow, "Sleeve", side, 900, 42, 1070, 35,
                               grad([("FF181A48", 0.0), (base, 1.0)], -110, 110), ink, 3, open_top=True))
        else:
            folds = [S(rig, "Fold", m([(214, 800), (230, 830), (224, 872), (218, 846)]), F(shade)),
                     S(rig, "Fold2", m([(262, 840), (272, 868), (266, 900), (262, 874)]), F(shade))]
            extra_up: list[El] = []
            if kind == "puff":
                extra_up.append(S(rig, "Puff", m([(206, 682), (262, 678), (300, 716), (298, 780), (250, 794),
                                                   (186, 776), (182, 716)]), rgrad(70, [("FF3A3440", 0.0), (base, 1.0)]),
                                  L(ink, 3)))
            if kind == "armor":
                extra_up += [S(rig, "Pauldron", m([(200, 676), (262, 672), (304, 712), (300, 776), (186, 776),
                                                    (182, 712)]), rgrad(80, [("FFE6EEFF", 0.0), (base, 0.5), (shade, 1.0)],
                                                                         cx=-20, cy=-30), L(ink, 3)),
                             S(rig, "Seam", m([(196, 850), (286, 850)]), L(ink, 3), closed=False)]
            if oid == "christmasSweater":
                extra_up += [S(rig, "Band", m([(196, 810, "c2"), (284, 810, "c2"), (282, 848, "c2"),
                                               (198, 848, "c2")]), F("FFAD4650"),
                               L(ink, 1.5)),
                             *[S(rig, f"Zig{i}", m([(200 + i * 18, 832), (209 + i * 18, 812), (218 + i * 18, 832)]),
                                 L("FFE8DFCD", 2), closed=False) for i in range(4)]]
            if oid == "pinkHoodie":
                for fold in folds:
                    fold.attrs["opacity"] = 0.55
            gu.add(*extra_up, *folds, *limb(rig, "Sleeve", side, 720, 50, 900, 43, sl_up, ink, 3))
            fore_extra: list[El] = []
            if cuff is not None:
                if kind == "glove":
                    fore_extra += [S(elbow, f"Fin{i}", m([(200, 966 + i * 28), (180, 978 + i * 28, "c"),
                                                           (202, 990 + i * 28)]), F(cuff), L(ink, 2)) for i in range(3)]
                    fore_extra += limb(elbow, "Glove", side, 960, 38, 1066, 35, F(cuff), ink, 2.5)
                else:
                    ribs = [S(elbow, f"Rib{i}", [(mx(216 + i * 12), 1040), (mx(216 + i * 12), 1068)], L(shade, 2),
                              closed=False) for i in range(5)] if oid == "pinkHoodie" else []
                    fore_extra += ribs + [S(elbow, "Cuff", m([(203, 1036), (277, 1036), (276, 1076, "c6"),
                                                              (204, 1076, "c6")]), F(cuff), L(ink, 2.5))]
            fore_extra.append(S(elbow, "ElbowFold", m([(222, 912), (240, 920), (258, 912)]), L(shade, 2.5), closed=False))
            gf.add(*fore_extra, *limb(elbow, "Sleeve", side, 900, 42, 1066, 35, sl_fore, ink, 3, open_top=True))
        up_solo.add(gu)
        fore_solo.add(gf)
        ups[oid] = gu
        fores[oid] = gf
    up_solo.el.attrs["activeComponentId"] = ups["pinkHoodie"].ref()
    fore_solo.el.attrs["activeComponentId"] = fores["pinkHoodie"].ref()
    return up_solo, fore_solo, ups, fores


def build_arm(rig: Rig, side: int) -> dict:
    mx = (lambda x: 800 - x) if side == 1 else (lambda x: x)
    up_art = rig.node("UpperArt")               # scaleY = foreshortening of the upper arm
    elbow = rig.node("Elbow", mx(240), 900)     # y keyed with the foreshortening
    fore_art = elbow.node("ForeArt")            # scaleY = foreshortening of the forearm
    hand = elbow.node("Hand", mx(240), 1070)    # y keyed with the forearm foreshortening
    hand_wave = hand.node("HandWave", scaleX=1.15, scaleY=1.15)
    skin_solo = hand_wave.solo("HandSkin")      # bare hand or costume glove (Top/Costume layers)
    skins: dict[str, El] = {}
    pose_sets: list[tuple[Rig, dict[str, El]]] = []
    for skin, cols in HAND_SKINS.items():
        HC.update(zip(("fill", "shade", "line", "ink"), cols))
        pose_solo = Rig("HandPose", hand_wave.ax, hand_wave.ay, tag="Solo")
        pose_solo.el.attrs.update(x=0.0, y=0.0)
        poses: dict[str, El] = {}
        for name, parts in (("rest", hand_open(hand_wave, 1, side, False)), ("palm", hand_open(hand_wave, -1, side, True)),
                            ("back", hand_open(hand_wave, 1, side, False)), ("edge", hand_edge(hand_wave, -1, side)),
                            ("point", hand_point(hand_wave, 1, side)),
                            ("up", hand_open(hand_wave, -1, side, True, short=0.82))):
            g = group("Hand_" + name, *parts)
            if skin in ("black", "metal", "white") and name in ("rest", "back", "palm", "up"):
                def glove_x(x: float) -> float:
                    thumb = -1 if name in ("palm", "up") else 1
                    value = WX + (x - WX) * thumb
                    return 800 - value if side == 1 else value
                glove_light = {"black": "FF77879F", "metal": "FFDFEDF5", "white": "FFB5C1CC"}[skin]
                for i, x in enumerate((217, 232, 248, 263)):
                    g.children.insert(0, S(hand_wave, f"GloveFingerSeam{i}",
                        [(glove_x(x - 2), WY + 68), (glove_x(x - 2), WY + 83 + i % 2 * 6)],
                        L(glove_light, 1.3 if skin == "white" else 1.8), closed=False))
                if name in ("rest", "back"):
                    for i, x in enumerate((219, 235, 251)):
                        g.children.insert(0, S(hand_wave, f"GloveKnuckle{i}",
                            [(glove_x(x - 4), WY + 36), (glove_x(x), WY + 31), (glove_x(x + 4), WY + 36)],
                            L(glove_light, 1.5), closed=False))
            pose_solo.add(g)
            poses[name] = g
        pose_solo.el.attrs["activeComponentId"] = poses["rest"].ref()
        sk = group("Skin_" + skin, pose_solo.el)
        skin_solo.add(sk)
        skins[skin] = sk
        pose_sets.append((pose_solo, poses))
    HC.update(zip(("fill", "shade", "line", "ink"), HAND_SKINS["skin"]))
    skin_solo.el.attrs["activeComponentId"] = skins["skin"].ref()
    up_solo, fore_solo, ups, fores = build_sleeves(rig, elbow, side)
    up_art.el.children = [up_solo.el]
    rig.el.children.remove(up_solo.el)
    fore_art.el.children = [fore_solo.el]
    # front-most first: hand > forearm sleeve > upper sleeve
    elbow.el.children = [hand.el, fore_art.el]
    rig.el.children = [elbow.el, up_art.el]
    return {"arm": rig, "elbow": elbow, "hand": hand, "wave": hand_wave, "up_solo": up_solo, "up_art": up_art,
            "fore_art": fore_art, "pose_sets": pose_sets, "skin_solo": skin_solo, "skins": skins,
            "fore_solo": fore_solo, "ups": ups, "fores": fores}


ARM_R = build_arm(arm_r, -1)
ARM_L = build_arm(arm_l, 1)
ARMS = [ARM_R, ARM_L]

# ================================================================ TORSO / TOPS
# The torso stops under the resting arms, so a raised arm never leaves a
# sleeve-shaped side behind it.
TORSO = [(365, 596), (400, 606), (435, 596), (520, 640), (568, 676), (588, 736), (578, 860), (566, 1010, "c"),
         (234, 1010, "c"), (222, 860), (212, 736), (232, 676), (280, 640)]
top_front = body_g.solo("TopFront")       # in front of the neck
top_back = body_g.solo("TopBack")         # behind the neck
back_fx = body_g.solo("BackFx")           # capes / auras behind everything
TF: dict[str, El] = {}
TB: dict[str, El] = {}


def torso(fill_: El, ink: str, name: str = "Torso", pts: list | None = None) -> El:
    return S(body_g, name, pts or TORSO, fill_, L(ink, 3.5))


def lapels(base: str, shade: str, ink: str) -> list[El]:
    lap = [(330, 600), (366, 606), (400, 760, "c"), (382, 770), (330, 700), (300, 700, "c"), (318, 660)]
    return [S(body_g, "LapelL", lap, vgrad(600, 770, base, shade), L(ink, 3)),
            S(body_g, "LapelR", mirror(lap), vgrad(600, 770, base, shade), L(ink, 3))]


def shirt_v(col: str = "FFF4F4F6", depth: float = 780) -> El:
    return S(body_g, "Shirt", [(362, 598), (438, 598), (420, 700), (400, depth, "c"), (380, 700)],
             vgrad(600, depth, col, "FFD8DAE2"), L("FF8A8C98", 2))


def collar_points(col: str = "FFF8F8FA") -> list[El]:
    pt = [(366, 596), (398, 640, "c"), (372, 660, "c"), (352, 610)]
    return [S(body_g, "CollarPtL", pt, F(col), L("FF8A8C98", 2)),
            S(body_g, "CollarPtR", mirror(pt), F(col), L("FF8A8C98", 2))]


def collarbones() -> list[El]:
    return [S(body_g, "ClavL", [(300, 650), (340, 660), (378, 650)], L(SKIN_SH2, 2.5), closed=False),
            S(body_g, "ClavR", mirror([(300, 650), (340, 660), (378, 650)]), L(SKIN_SH2, 2.5), closed=False)]


# -- pinkHoodie
def hood_string(x0: float, x1: float, name: str) -> El:
    tip = R(body_g, name + "Tip", x1, 905, 12, 26, 4, F("FFBFB6C4"), L(HOOD_INK, 2))
    cord = S(body_g, name, [(x0, 660), (x0 + (x1 - x0) * 0.4, 760), (x1, 890)], L(HOOD_INK, 9), closed=False)
    cord_in = S(body_g, name + "In", [(x0, 660), (x0 + (x1 - x0) * 0.4, 760), (x1, 890)], L(STRING, 5.5), closed=False)
    pivot = (x0 - body_g.ax, 660 - body_g.ay)
    for part in (tip, cord_in, cord):
        part.attrs["x"] = float(part.attrs["x"]) - pivot[0]
        part.attrs["y"] = float(part.attrs["y"]) - pivot[1]
    return d("Node", tip, cord_in, cord, x=pivot[0], y=pivot[1], name=name + "Group")


band = [(278, 616), (318, 598), (356, 610), (390, 650), (408, 706, "c"), (388, 708), (360, 668), (324, 636), (290, 634)]
TF["pinkHoodie"] = group("F_pinkHoodie", hood_string(360, 352, "StringL"), hood_string(440, 452, "StringR"),
                         S(body_g, "CollarL", band, vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3)),
                         S(body_g, "CollarR", mirror(band), vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3)))
TB["pinkHoodie"] = group("B_pinkHoodie",
                         S(body_g, "EmbroideredOrbit", [(481, 766), (469, 776), (481, 786), (493, 776), (481, 766)],
                           L("FFEAD3B0", 2.4), closed=False),
                         E(body_g, "EmbroideredStar", 481, 776, 6, 6, F("FFFFEBD0")),
                         S(body_g, "ShoulderLight", [(231, 687), (270, 665), (306, 670)], L("80FFF3EC", 3), closed=False),
                         S(body_g, "PocketStitch", [(310, 972), (490, 972)], L("45FFF3EC", 1.4), closed=False),
                         S(body_g, "ChestLight", [(260, 710), (286, 700), (274, 862), (260, 938), (250, 874)], F("16FFF7ED")),
                         S(body_g, "ChestShade", [(300, 700), (340, 760), (330, 860), (300, 1000, "c"), (286, 1000, "c"),
                                                  (296, 860)], F(HOOD_SH)),
                         S(body_g, "Fold1", [(352, 880), (366, 930), (360, 1000), (352, 1000), (356, 930)], F(HOOD_SH2)),
                         S(body_g, "Fold2", [(470, 830), (458, 900), (466, 1000), (474, 1000), (466, 900)], F(HOOD_SH2)),
                         S(body_g, "Pocket", [(300, 960), (500, 960)], L(HOOD_SH2, 3), closed=False),
                         S(body_g, "HoodBack", [(282, 610), (300, 546), (350, 514), (400, 508), (450, 514), (500, 546),
                                                (518, 610), (470, 604), (400, 598), (330, 604)],
                           grad([(HOOD_SH, 0.0), (HOOD_SH2, 1.0)], -40, 40), L(HOOD_INK, 3)),
                         torso(vgrad(600, 1000, HOOD, HOOD_SH), HOOD_INK))
for detail in TB["pinkHoodie"].children:
    if detail.attrs.get("name") in ("Fold1", "Fold2", "ChestShade"):
        detail.attrs["opacity"] = 0.6

# -- longCoat: trench over a white shirt
COAT, COAT_SH, COAT_INK = "FFD9C7A3", "FFB49E78", "FF6A5838"
TF["longCoat"] = group("F_longCoat", *collar_points())
coat_torso = torso(vgrad(600, 1000, COAT, COAT_SH), COAT_INK)
TB["longCoat"] = group("B_longCoat", *lapels(COAT, COAT_SH, COAT_INK),
                       *[E(body_g, f"Button{i}", 400, 800 + i * 70, 10, 10, F("FFEDEEF2"), L("FF8A8C98", 1.5))
                         for i in range(3)],
                       shirt_v(depth=1010),
                       S(body_g, "CoatCollar", [(300, 600), (330, 560), (400, 550), (470, 560), (500, 600), (470, 612),
                                                (400, 604), (330, 612)], F(COAT_SH), L(COAT_INK, 3)),
                       S(body_g, "Belt", [(196, 940), (380, 950), (380, 976), (196, 966)], F(COAT_SH), L(COAT_INK, 2),
                         clip=coat_torso),
                       S(body_g, "Belt2", mirror([(196, 940), (380, 950), (380, 976), (196, 966)]), F(COAT_SH),
                         L(COAT_INK, 2), clip=coat_torso),
                       S(body_g, "CoatFold", [(270, 760), (290, 860), (280, 1000), (272, 1000), (280, 860)], F(COAT_SH)),
                       coat_torso)

# -- tshirt: dark ringer tee
TEE, TEE_SH, TEE_INK = "FF2A2A30", "FF1A1A1E", "FF0E0E12"
TF["tshirt"] = group("F_tshirt", S(body_g, "NeckBand", [(352, 598), (400, 618), (448, 598), (452, 610), (400, 634),
                                                        (348, 610)], F("FFC0303A"), L(TEE_INK, 2.5)))
TB["tshirt"] = group("B_tshirt",
                     S(body_g, "TeeFold", [(320, 760), (340, 860), (330, 1000), (322, 1000), (330, 860)], F(TEE_SH)),
                     S(body_g, "TeeFold2", [(480, 800), (466, 900), (474, 1000), (480, 1000), (474, 900)], F(TEE_SH)),
                     S(body_g, "TeeShine", [(250, 700), (300, 680), (280, 760)], F("22FFFFFF")),
                     torso(vgrad(600, 1000, "FF3A3A44", TEE), TEE_INK))

# -- underwear: white tank top
TANK = [(278, 649), (307, 641), (331, 711), (400, 735), (469, 711), (493, 641),
        (522, 649), (523, 701), (542, 762), (552, 1010, "c"), (248, 1010, "c"),
        (258, 762), (277, 701)]
TF["underwear"] = group("F_underwear")
TB["underwear"] = group("B_underwear",
                        S(body_g, "Tank", TANK, vgrad(650, 1000, "FFFFFFFF", "FFDCDCE6"), L("FF9A9AA8", 2.5)),
                        *collarbones(),
                        torso(vgrad(600, 1000, SKIN, SKIN_SH), INK, "SkinTorso"))

# -- swimsuit: bare chest + a striped towel round the neck
towel = [(330, 596), (360, 640), (372, 760), (360, 900), (318, 900, "c"), (316, 760), (300, 660)]
stripe = [(318, 839, "c2"), (369, 839, "c2"), (366, 850, "c2"), (318, 850, "c2")]
TF["swimsuit"] = group("F_swimsuit",
                       S(body_g, "TowelStripeL", stripe, F("FF2A9FB0")),
                       S(body_g, "TowelStripeR", mirror(stripe), F("FF2A9FB0")),
                       S(body_g, "TowelL", towel, vgrad(600, 900, "FFFFFFFF", "FFD8E6EA"), L("FF6A8A92", 2.5)),
                       S(body_g, "TowelR", mirror(towel), vgrad(600, 900, "FFFFFFFF", "FFD8E6EA"), L("FF6A8A92", 2.5)))
# swimsuit: a sleeveless swim top (teal, white piping) so it reads as swimwear waist-up
SWIM = [(278, 649), (308, 641), (331, 706), (400, 729), (469, 706), (492, 641), (522, 649),
        (523, 701), (542, 762), (552, 1010, "c"), (248, 1010, "c"), (258, 762), (277, 701)]
swim_top = S(body_g, "SwimTop", SWIM, vgrad(640, 1000, "FF2FB3BF", "FF14707E"), L("FF0B4650", 2.5))
TB["swimsuit"] = group("B_swimsuit",
                       S(body_g, "SwimPipingL", [(262, 760), (272, 860), (262, 1000)], L("E6FFFFFF", 5), closed=False,
                         clip=swim_top),
                       S(body_g, "SwimPipingR", mirror([(262, 760), (272, 860), (262, 1000)]), L("E6FFFFFF", 5),
                         closed=False, clip=swim_top),
                       S(body_g, "SwimSheen", [(300, 760), (330, 740), (318, 900), (300, 940)], F("2EFFFFFF"),
                         clip=swim_top),
                       swim_top,
                       *collarbones(),
                       torso(vgrad(600, 1000, SKIN, SKIN_SH), INK, "SkinTorso"))

# -- christmasSweater
SW, SW_SH, SW_INK, SW_RED = "FF2E7D4F", "FF1F5C39", "FF123A24", "FFC8303A"
flakes = []
for i, (fx, fy) in enumerate([(270, 700), (530, 690), (300, 940), (500, 930), (400, 700)]):
    for k in range(3):
        a = k * PI / 3
        flakes.append(S(body_g, f"Flake{i}_{k}", [(fx - 12 * math.cos(a), fy - 12 * math.sin(a)),
                                                  (fx + 12 * math.cos(a), fy + 12 * math.sin(a))],
                        L("FFF4F4F4", 3), closed=False))
TF["christmasSweater"] = group("F_christmasSweater",
                               *[S(body_g, f"KnitRib{i}", [(356 + i * 11, 600 + abs(i - 4) * 1.2),
                                                           (356 + i * 11, 624 + abs(i - 4) * 1.2)], L("FF9A2028", 2.5),
                                   closed=False) for i in range(9)],
                               S(body_g, "KnitCollar", [(348, 596), (400, 612), (452, 596), (456, 616), (400, 636),
                                                        (344, 616)], F(SW_RED), L(SW_INK, 2.5)))
sw_torso = torso(vgrad(600, 1000, SW, SW_SH), SW_INK)
TB["christmasSweater"] = group("B_christmasSweater",
                               *flakes,
                               *[S(body_g, f"Zig{i}", [(200 + i * 30, 832), (215 + i * 30, 812), (230 + i * 30, 832)],
                                   L("FFF4F4F4", 4), closed=False, clip=sw_torso) for i in range(14)],
                               *[E(body_g, f"Dot{i}", 214 + i * 30, 858, 8, 8, F("FFF4F4F4"), clip=sw_torso)
                                 for i in range(14)],
                               S(body_g, "RedBand", [(196, 796), (604, 796), (606, 874), (194, 874)], F(SW_RED),
                                 L(SW_INK, 2.5), clip=sw_torso),
                               sw_torso)

# -- blackSuitAndTie
SUIT, SUIT_SH, SUIT_INK = "FF34363E", "FF22242A", "FF101116"
tie = [(392, 640), (408, 640), (420, 900), (400, 930, "c"), (380, 900)]
TF["blackSuitAndTie"] = group("F_blackSuitAndTie",
                              S(body_g, "Knot", [(388, 612), (412, 612), (408, 642), (392, 642)], F("FF1A1A20"),
                                L("FF000000", 2)),
                              *collar_points())
TB["blackSuitAndTie"] = group("B_blackSuitAndTie",
                              *lapels(SUIT, SUIT_SH, SUIT_INK),
                              S(body_g, "TieShine", [(398, 660), (404, 660), (410, 860), (402, 860)], F("33FFFFFF")),
                              S(body_g, "Tie", tie, vgrad(640, 930, "FF26262E", "FF0C0C10"), L("FF000000", 2)),
                              shirt_v(depth=800),
                              E(body_g, "SuitButton", 400, 880, 12, 12, F("FF15161A")),
                              S(body_g, "Pocket", [(470, 720), (540, 714)], L(SUIT_INK, 3), closed=False),
                              S(body_g, "PocketSquare", [(486, 716), (494, 702), (502, 716)], F("FFF4F4F6")),
                              torso(vgrad(600, 1000, "FF3E4048", SUIT_SH), SUIT_INK))

# -- costume tops
BAT, BAT_SH, BAT_INK = "FF3A3F4A", "FF262A32", "FF121418"
bat_emblem = [(340, 770), (356, 754), (372, 762), (384, 744), (392, 756), (400, 748), (408, 756), (416, 744),
              (428, 762), (444, 754), (460, 770), (440, 772), (428, 786), (412, 778), (400, 792), (388, 778),
              (372, 786), (360, 772)]
TF["batman"] = group("F_batman", S(body_g, "CowlNeck", [(356, 476), (444, 476), (452, 600), (470, 622), (400, 640),
                                                        (330, 622), (348, 600)], vgrad(470, 640, BAT, BAT_SH),
                                   L(BAT_INK, 3)))
bat_torso = torso(vgrad(600, 1000, BAT, BAT_SH), BAT_INK)
TB["batman"] = group("B_batman",
                     S(body_g, "Bat", [(p[0], p[1]) for p in bat_emblem], F("FF0E0F12")),
                     E(body_g, "EmblemOval", 400, 768, 140, 62, vgrad(-30, 30, "FFFFE066", "FFE0A820"), L(BAT_INK, 3)),
                     S(body_g, "PecL", [(300, 720), (360, 740), (392, 720)], L(BAT_SH, 3), closed=False),
                     S(body_g, "PecR", mirror([(300, 720), (360, 740), (392, 720)]), L(BAT_SH, 3), closed=False),
                     S(body_g, "BeltGold", [(196, 990), (604, 990), (606, 1012), (194, 1012)], F("FFE0A820"),
                       clip=bat_torso),
                     bat_torso)
RC, RC_SH, RC_INK = "FFB8C4DC", "FF6A7A9C", "FF2A3450"
TF["robocop"] = group("F_robocop", *[S(body_g, f"NeckRing{i}", [(364, 540 + i * 18), (436, 540 + i * 18),
                                                                (440, 556 + i * 18), (360, 556 + i * 18)],
                                       vgrad(-8, 8, "FF4A5470", "FF1E2436"), L(RC_INK, 1.5)) for i in range(4)])
TB["robocop"] = group("B_robocop",
                      S(body_g, "Plate", [(300, 660), (392, 670), (392, 800), (330, 820, "c"), (290, 760)],
                        rgrad(120, [("FFEFF4FF", 0.0), (RC, 0.5), (RC_SH, 1.0)], cx=-30, cy=-40), L(RC_INK, 3)),
                      S(body_g, "Plate2", mirror([(300, 660), (392, 670), (392, 800), (330, 820, "c"), (290, 760)]),
                        rgrad(120, [("FFEFF4FF", 0.0), (RC, 0.5), (RC_SH, 1.0)], cx=-30, cy=-40), L(RC_INK, 3)),
                      S(body_g, "Abs", [(320, 850), (480, 850), (470, 990), (330, 990)], vgrad(850, 990, RC, RC_SH),
                        L(RC_INK, 3)),
                      S(body_g, "AbsSeam", [(400, 850), (400, 990)], L(RC_INK, 3), closed=False),
                      S(body_g, "AbsSeam2", [(326, 920), (474, 920)], L(RC_INK, 3), closed=False),
                      torso(vgrad(600, 1000, "FF5A6688", "FF2A3248"), RC_INK))
MAID, MAID_INK = "FF221E26", "FF0A080C"
frill = []
for i in range(9):
    a0 = PI * (0.12 + 0.76 * i / 8)
    cx_, cy_ = 400 - math.cos(a0) * 70, 596 + math.sin(a0) * 26
    frill.append(E(body_g, f"Frill{i}", cx_, cy_, 30, 22, F("FFFFFFFF"), L("FFB8B8C4", 2)))
TF["soubrette"] = group("F_soubrette",
                        S(body_g, "Bow", [(400, 628), (370, 610, "c"), (366, 648, "c"), (400, 634), (434, 648, "c"),
                                          (430, 610, "c")], F("FF101014"), L("FF000000", 2)),
                        *frill)
TB["soubrette"] = group("B_soubrette",
                        S(body_g, "ApronStrapL", [(318, 650), (340, 650), (350, 800), (330, 800)], F(WHITE), L("FFB8B8C4", 2)),
                        S(body_g, "ApronStrapR", mirror([(318, 650), (340, 650), (350, 800), (330, 800)]), F(WHITE),
                          L("FFB8B8C4", 2)),
                        S(body_g, "Bib", [(330, 760), (470, 760), (480, 1010, "c"), (320, 1010, "c")],
                          vgrad(760, 1010, "FFFFFFFF", "FFE6E6EE"), L("FFB8B8C4", 2.5)),
                        torso(vgrad(600, 1000, "FF2E2934", MAID), MAID_INK))
SING = TORSO
sing_torso_stars = starfield(body_g, SING, 26, 5, "Torso")
STAR_FX.extend(sing_torso_stars[:8])
TF["singularity"] = group("F_singularity",
                          S(body_g, "VoidNeck", [(362, 470), (438, 470), (446, 606), (400, 640), (354, 606)],
                            F("FF0E1030"), L("FF2A2E6A", 2)))
TB["singularity"] = group("B_singularity", *sing_torso_stars,
                          torso(grad([("FF1A1E5A", 0.0), ("FF0A0B24", 0.6), ("FF05060F", 1.0)], -200, 200), "FF3A40A0"))

for oid in OUTFITS:
    top_front.add(TF[oid])
    top_back.add(TB[oid])
top_front.el.attrs["activeComponentId"] = TF["pinkHoodie"].ref()
top_back.el.attrs["activeComponentId"] = TB["pinkHoodie"].ref()

# back fx: batman cape, singularity aura
fx_none = group("Fx_none")
cape_rig = Rig("Cape", 400, 640, back_fx)
cape = S(cape_rig, "CapeShape", [(270, 630), (400, 610), (530, 630), (690, 760), (760, 1010, "c"), (40, 1010, "c"),
                                 (110, 760)], vgrad(620, 1010, "FF2A2D36", "FF0E0F14"), L("FF08090C", 3))
cape_rig.add(cape)
aura_rig = Rig("Aura", 400, 600, back_fx)
aura = E(aura_rig, "AuraGlow", 400, 600, 900, 900,
         rgrad(450, [("667A5CFF", 0.0), ("334A9CFF", 0.45), ("00303080", 1.0)]))
aura_rig.add(aura)
back_fx.el.children = [fx_none, cape_rig.el, aura_rig.el]
back_fx.el.attrs["activeComponentId"] = fx_none.ref()

neck = S(body_g, "Neck", [(370, 470), (430, 470), (432, 560), (446, 606), (400, 640), (354, 606), (368, 560)],
         F(SKIN), L(INK, 3))
chin_sh = S(body_g, "ChinShadow", [(372, 600), (400, 612), (428, 600), (420, 640), (400, 650), (380, 640)], F(SKIN_SH))
neck_sh = S(body_g, "NeckShade", [(368, 480), (432, 480), (432, 540), (400, 566), (368, 540)], F(SKIN_SH))

# ================================================================ HEAD
face_pts = [(294, 330), (298, 402), (316, 452), (350, 488), (386, 508), (400, 511), (414, 508), (450, 488),
            (484, 452), (502, 402), (506, 330), (490, 262), (400, 222), (310, 262)]
face = S(head, "Face", face_pts, rgrad(235, [("FFFFE6CF", 0.0), (SKIN, 0.6), ("FFE8B299", 1.0)], cx=-48, cy=-62), L(INK, 2.6))
FACE_CAST_PTS = [(298, 300), (330, 330), (370, 336), (400, 330), (440, 340), (480, 332), (502, 300), (504, 352),
                 (490, 360), (470, 352), (440, 362), (400, 356), (360, 362), (320, 356), (300, 366)]
CHEEK_SH_PTS = [(502, 360), (498, 410), (484, 452), (452, 490), (424, 509), (446, 484), (474, 446), (488, 404)]
face_cast = S(head, "FaceCast", FACE_CAST_PTS, F(SKIN_SH))
cheek_sh = S(head, "CheekShade", CHEEK_SH_PTS, F(SKIN_SH))
EAR = [(300, 372), (282, 360), (272, 380), (278, 412), (292, 436), (304, 430)]
ears = [S(head, "EarL", EAR, F(SKIN), L(INK, 3)), S(head, "EarR", mirror(EAR), F(SKIN), L(INK, 3)),
        S(head, "EarInL", [(296, 384), (286, 378), (284, 396), (292, 414)], L(SKIN_SH2, 3), closed=False),
        S(head, "EarInR", mirror([(296, 384), (286, 378), (284, 396), (292, 414)]), L(SKIN_SH2, 3), closed=False)]
nose_g = head.node("NoseTurn")            # gestures shift it with the eyes/mouth to fake yaw/pitch
nose = S(nose_g, "Nose", [(406, 446), (400, 454), (392, 452)], L(SKIN_SH2, 3), closed=False)
nose_sh = S(nose_g, "NoseShade", [(404, 408), (410, 440), (406, 450), (402, 430)], F(SKIN_SH))
nose_light = S(nose_g, "NoseLight", [(397, 415), (395, 433)], L("66FFF4DF", 2.8), closed=False)
nose_g.add(nose, nose_light, nose_sh)
mole = E(head, "Mole", 456, 432, 5, 5, F("FF5A3A32"))
skin_details = [E(head, "CheekBloom" + tag, x, 437, 65, 44,
                  rgrad(33, [("25E99D91", 0.0), ("00E99D91", 1.0)]), clip=face)
                for tag, x in (("L", 335), ("R", 465))]
skin_details += [S(head, "ChinLight", [(386, 497), (399, 501), (412, 497)], L("40FFF5E1", 2.5), closed=False)]

# ---- eyes: Eye > [GestureClosedLash, GestureLid, EyeMood > Blink > [Lash, LowerLid, Crease,
#      GazeM > GazeP > GazeG > Look(joystick), White, EyeClip, lid bones]]
eyes = head.node("Eyes", 400, 385)


def build_eye(cx: float, side: int) -> dict:
    s = side
    tag = "L" if side < 0 else "R"
    eye = eyes.node("Eye" + tag, cx, 388, scaleX=1.06, scaleY=1.06)
    eye_mood = eye.node("EyeMood", cx, 388)
    blink = eye_mood.node("Blink", cx, 392)
    gaze_m = blink.node("GazeM", cx, 388)
    gaze_p = gaze_m.node("GazeP", cx, 388)
    gaze_g = gaze_p.node("GazeG", cx, 388)
    look = gaze_g.node("Look", cx, 388)
    o = cx + 30 * s
    i = cx - 28 * s
    white_pts = [(i, 390), (cx - 14 * s, 372), (cx + 6 * s, 368), (o - 6 * s, 374), (o, 392, "c"), (cx + 8 * s, 404),
                 (cx - 12 * s, 403)]
    clip_src = clip_only(S(blink, "EyeClip", white_pts))
    look.add(E(look, "Shine", cx - 7 * s - 1, 379, 10, 8, F(WHITE), clip=clip_src),
             E(look, "Shine2", cx + 7 * s, 397, 5, 5, F("D0FFFFFF"), clip=clip_src),
             pupil := E(look, "Pupil", cx, 389, 14, 17, F("FF1E120C"), clip=clip_src),
             E(look, "IrisRing", cx, 388, 32, 36, L("FF2B1A12", 2.2), clip=clip_src),
             E(look, "Iris", cx, 388, 32, 36, d("Fill", rad(d, 0, 8, 22, [(IRIS_A, 0.0), (IRIS_B, 1.0)]), name="Fill"),
               clip=clip_src))
    white = S(blink, "White", white_pts, F(SCLERA))
    # blink = a skin lid sliding down inside the eye + the lash travelling with it and
    # flipping into the closed-eye curve (no squashed eyeballs)
    lash_n = blink.node("LashMove", cx, 366)
    upper = S(lash_n, "Lash", [(i - 3 * s, 393), (cx - 15 * s, 368), (cx + 6 * s, 363), (o - 2 * s, 369),
                               (o + 9 * s, 384, "c"), (o + 1 * s, 381), (cx + 6 * s, 373), (cx - 14 * s, 377),
                               (i + 2 * s, 394, "c")], F("FF2A1B18"))
    lash_n.add(upper)
    lid = blink.node("Lid", cx, 360, scaleY=0.0)
    crease = S(blink, "Crease", [(cx - 12 * s, 360), (cx + 8 * s, 356), (o + 2 * s, 364)], L(SKIN_SH2, 2), closed=False)
    lower = S(blink, "LowerLid", [(i + 6 * s, 403), (cx - 8 * s, 406), (cx + 14 * s, 402)], L("B03A2622", 2),
              closed=False)
    lid.add(S(lid, "LidSkin", [(i - 10 * s, 358, "c"), (o + 12 * s, 358, "c"), (o + 12 * s, 412, "c"),
                               (i - 10 * s, 412, "c")], vgrad(358, 412, "FFF3C9B2", SKIN), clip=clip_src),
            S(lid, "LidCrease", [(i - 2 * s, 404), (cx, 409), (o + 4 * s, 403)], L(SKIN_SH2, 2), closed=False,
              clip=clip_src))
    shut = S(blink, "ClosedLash", [(i - 4 * s, 393), (cx - 6 * s, 400), (cx + 12 * s, 400), (o + 9 * s, 391)],
             L("FF2A1B18", 4.2), closed=False, opacity=0.0)
    # M3: the eye is rebuilt on lid bones (face_rig.rig_lids reshapes EyeClip, White, Lash,
    # LowerLid and Crease in place). The v5 blink lid, the lash mover, the closed lash and the
    # mood lids below (droop, squint, squint line) are retired; they are still minted so every
    # later element keeps its id (keyed ids are the animation contract).
    blink.el.children = [upper, lower, crease, gaze_m.el, white, clip_src]
    droop = eye.node("Droop", cx, 360)
    # the lowered lid follows the eyeball: a curve, not a ruler line
    droop.add(S(droop, "DroopLash", [(i - 6 * s, 389), (cx, 397), (o + 8 * s, 388)], L("FF2A1B18", 4.5), closed=False),
              S(droop, "DroopLid", [(i - 8 * s, 352, "c"), (o + 10 * s, 352, "c"), (o + 10 * s, 389), (cx, 398),
                                    (i - 8 * s, 390)], F(SKIN)))
    # happy: the lower lid rises into a crescent that hides most of the iris
    # happy: one smooth upward arc (no waves) in a thin warm ink
    squint = S(eye, "Squint", [(i - 8 * s, 404), (cx + 1 * s, 385), (o + 8 * s, 399), (o + 10 * s, 424, "c"),
                               (i - 10 * s, 424, "c")], F(SKIN), origin=(cx, 412))
    squint_line = S(eye, "SquintLine", [(i - 2 * s, 401.5), (cx + 1 * s, 387), (o + 3 * s, 398.5)],
                    L("D03A2622", 2.2), closed=False, origin=(cx, 412))
    eye.el.children = [eye_mood.el]
    # Gesture lids have their own channels so a facepalm can shut the eyes
    # without stealing the independent mood, blink or pointer-follow tracks.
    gesture_lid = eye.node("GestureLid", cx, 360, scaleY=0.0)
    gesture_lid.add(S(gesture_lid, "GestureLidSkin",
                      [(cx - 42, 354, "c"), (cx + 42, 354, "c"), (cx + 42, 412, "c"), (cx - 42, 412, "c")],
                      F(SKIN), clip=clip_src))
    gesture_shut = S(eye, "GestureClosedLash", [(i, 395), (cx, 401), (o, 394)],
                     L("FF2A1B18", 3.5), closed=False, opacity=0.0)
    eye.el.children.remove(gesture_lid.el)
    eye.el.children[0:0] = [gesture_shut, gesture_lid.el]
    brow = eyes.node("Brow" + tag, cx, 346)
    brow_p = brow.node("BrowP")                # phase accents (speaking brow raises)
    brow_g = brow_p.node("BrowG")
    brow_g.add(S(brow_g, "BrowShape", [(cx - 30 * s, 342, "c"), (cx - 8 * s, 335), (cx + 16 * s, 335),
                                       (cx + 36 * s, 344, "c"), (cx + 16 * s, 341), (cx - 8 * s, 341)], F(HAIR)))
    return {"eye": eye, "mood": eye_mood, "blink": blink, "lash": upper, "lower": lower, "crease": crease,
            "white": white, "clip": clip_src, "pupil": pupil, "brow_p": brow_p, "gm": gaze_m, "gp": gaze_p,
            "gg": gaze_g, "look": look, "brow": brow, "brow_g": brow_g, "gesture_lid": gesture_lid,
            "gesture_shut": gesture_shut, "cx": cx, "s": s,
            "retired": {"lid": lid, "lash": lash_n, "shut": shut, "squint": squint, "squint_line": squint_line,
                        "droop": droop}}


EYE_L = build_eye(355, -1)
EYE_R = build_eye(445, 1)
EYES = [EYE_L, EYE_R]
eyes.el.children.sort(key=lambda c: 0 if c.attrs.get("name", "").startswith("Brow") else 1)

blush = head.node("Blush", 400, 440, opacity=0.0)
blush.add(*[E(blush, "Blush" + t, x, 438, 54, 20, rgrad(27, [("B0F08F86", 0.0), ("00F08F86", 1.0)]), clip=face)
            for t, x in (("L", 338), ("R", 462))],
          *[S(blush, f"BlushLine{t}{k}", [(x - 12 + k * 9, 446), (x - 6 + k * 9, 432)], L("90E07070", 2), closed=False,
              clip=face)
            for t, x in (("L", 338), ("R", 462)) for k in range(3)])

# ---- mouth: one continuous skinned mouth (rive/tools/face_rig.py) inside MouthActing (gesture
# squash) > MouthMood (the thinking skew, keyed by moods). Lines keeps its name for the head rig.
mouth = head.node("Mouth", 400, 478)
lines = mouth.node("Lines")
mouth_mood = d("Node", x=0.0, y=0.0, name="MouthMood")
line_acting = d("Node", mouth_mood, x=0.0, y=0.0, name="MouthActing")
lines.el.children = [line_acting]

# ---- mood / phase / gesture overlays on the face
sweat_m = head.node("SweatMood", 300, 330, opacity=0.0)
SWEAT = [(0, -26), (8, -6), (10, 6), (0, 14), (-10, 6), (-8, -6)]
sweat_m.add(S(sweat_m, "Drop", [(300 + x, 330 + y) for x, y in SWEAT], vgrad(-20, 14, "FFE6F6FF", "FF8CC8F0"),
              L("FF3A7AB0", 2.5)))
# the anger vein sits at the temple, in the palette's error red (#FF6B6B)
AX, AY = 482.0, 292.0
anger = head.node("AngerMark", AX, AY, opacity=0.0)
for k in range(4):
    a = k * PI / 2 + PI / 4
    p0 = (AX + 15 * math.cos(a - 0.5), AY + 15 * math.sin(a - 0.5))
    p1 = (AX + 7 * math.cos(a), AY + 7 * math.sin(a))
    p2 = (AX + 15 * math.cos(a + 0.5), AY + 15 * math.sin(a + 0.5))
    anger.add(S(anger, f"Vein{k}", [p0, p1, p2], L("FFFF6B6B", 4.2), closed=False))
laugh = head.node("LaughFace", 400, 420, opacity=0.0)
laugh.add(*[S(laugh, f"LaughEye{t}", [(x - 22, 396), (x, 376), (x + 22, 396)], L("FF2A1B18", 5), closed=False)
            for t, x in (("L", 355), ("R", 445))],
          *[E(laugh, f"LaughPatch{t}", x, 388, 82, 54, F(SKIN)) for t, x in (("L", 355), ("R", 445))],
          S(laugh, "LaughTeeth", [(372, 470), (428, 470), (424, 480), (376, 480)], F(TEETH)),
          E(laugh, "LaughTongue", 400, 498, 30, 14, F(TONGUE)),
          S(laugh, "LaughMouth", [(368, 468), (400, 466), (432, 468), (426, 490), (400, 508), (374, 490)], F(MOUTH_IN),
            L(INK, 3)))
# Anchor the jaw at the upper lip so chuckles close upward instead of
# scaling the eyes or sliding the whole expression over the face.
laugh_jaw_parts = [part for part in laugh.el.children
                   if part.attrs.get("name") in ("LaughTeeth", "LaughTongue", "LaughMouth")]
for part in laugh_jaw_parts:
    part.attrs["y"] = float(part.attrs.get("y", 0)) - 48
laugh_jaw = d("Node", *laugh_jaw_parts, x=0.0, y=48.0, name="LaughJaw")
laugh.el.children = [part for part in laugh.el.children if part not in laugh_jaw_parts] + [laugh_jaw]
sweat_p = head.node("SweatPhase", 508, 300, opacity=0.0)
sweat_p.add(S(sweat_p, "Drop", [(508 + x, 300 + y) for x, y in SWEAT], vgrad(-20, 14, "FFE6F6FF", "FF8CC8F0"),
              L("FF3A7AB0", 2.5)))

# ---- glasses (Solo: glasses / sunglasses / none)
glasses_solo = head.solo("GlassesSolo")


def glasses_set(name: str, lens_fill: El | str, glare_a: str) -> El:
    def lens(cx: float, t: str) -> El:
        pts = [(cx - 43, 364, "c12"), (cx + 43, 364, "c12"), (cx + 41, 410, "c14"), (cx - 41, 410, "c14")]
        lf = lens_fill if isinstance(lens_fill, str) else None
        paint = F(lf) if lf else d("Fill", lin(d, 0, -24, 0, 24, [("F0181820", 0.0), ("F0383A48", 1.0)]), name="Fill")
        return S(head, "Lens" + t, pts, paint, L(FRAME, 4.2))
    return group(name,
                 S(head, "Glare", [(330, 370), (346, 370), (322, 402), (310, 402)], F(glare_a)),
                 S(head, "Glare2", [(420, 370), (436, 370), (412, 402), (402, 402)], F(glare_a)),
                 lens(355, "L"), lens(445, "R"),
                 S(head, "Bridge", [(398, 378), (400, 374), (402, 378)], L(FRAME, 5), closed=False),
                 S(head, "TempleL", [(311, 370), (296, 368)], L(FRAME, 6), closed=False),
                 S(head, "TempleR", [(489, 370), (504, 368)], L(FRAME, 6), closed=False))


GLASSES = {"glasses": glasses_set("G_glasses", "14B8D8F0", "26FFFFFF"),
           "sunglasses": glasses_set("G_sunglasses", None, "55FFFFFF"),  # type: ignore[arg-type]
           "none": group("G_none")}
glasses_solo.add(*GLASSES.values())
glasses_solo.el.attrs["activeComponentId"] = GLASSES["glasses"].ref()

# ---- hair
hair_front = head.node("HairFront")


def lock(name: str, root_: tuple[float, float], tip: tuple[float, float], w: float, bend: float) -> El:
    (rx, ry), (tx, ty) = root_, tip
    dx, dy = tx - rx, ty - ry
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln

    def at(t: float, off: float) -> tuple[float, float]:
        bow = math.sin(math.pi * t) * bend
        return (rx + dx * t + nx * (off + bow), ry + dy * t + ny * (off + bow))
    pts = [at(0, -w / 2), at(0.45, -w * 0.42), at(0.8, -w * 0.2), (tx + nx * bend * 0.1, ty, "c"),
           at(0.78, w * 0.16), at(0.42, w * 0.44), at(0, w / 2)]
    base = S(head, name, pts, grad([(HAIR_HI, 0.0), (HAIR, 0.55), (HAIR_SH, 1.0)], -ln / 2, ln / 2), L(HAIR_SH, 1.5))
    # Separate tapered ribbons, clipped to each lock, give the hair a satin
    # surface. They travel with the hair rig, including under hats.
    light = S(head, name + "Ribbon", [at(0.12, -w * 0.18), at(0.35, -w * 0.22), at(0.65, -w * 0.1),
                                     at(0.48, -w * 0.04), at(0.26, -w * 0.05)],
              rgrad(ln * 0.3, [("35DBA27C", 0), ("00DBA27C", 1)]), clip=base)
    strand = S(head, name + "Strand", [at(0.18, w * 0.15), at(0.43, w * 0.2), at(0.72, w * 0.07)],
               L("24E6B28A", 1.1), closed=False, clip=base)
    return group(name + "Material", light, strand, base)


# (the centre locks end above the raised-brow line: their tips must not poke out under a lifted brow)
LOCKS = [((300, 272), (292, 404), 44, -8), ((330, 246), (318, 360), 50, 12), ((360, 236), (352, 330), 50, 10),
         ((396, 230), (418, 352), 70, 18), ((436, 234), (452, 334), 52, 10), ((470, 248), (490, 376), 58, 9),
         ((498, 276), (510, 410), 40, 6), ((380, 236), (372, 318), 30, 6), ((452, 242), (474, 322), 28, 6)]
hair_front.add(*[lock(f"Lock{i}", *LOCKS[i]) for i in [7, 8, 3, 2, 4, 1, 5, 0, 6]],
               S(head, "HairCap", [(290, 340), (294, 270), (330, 232), (400, 214), (470, 232), (506, 270), (510, 340),
                                   (470, 300), (400, 292), (330, 300)], grad([(HAIR_HI, 0.0), (HAIR, 0.6)], -60, 60),
                 L(HAIR_SH, 2.4)),
               S(head, "SideLockL", [(300, 330), (314, 370), (308, 430), (296, 466, "c"), (290, 420), (288, 360)],
                 F(HAIR), L(HAIR_SH, 2.5)),
               S(head, "SideLockR", mirror([(300, 330), (314, 370), (308, 430), (296, 466, "c"), (290, 420), (288, 360)]),
                 F(HAIR), L(HAIR_SH, 2.5)))
hair_back = head.node("HairBack")
hair_back.add(S(head, "HairBackShape", [(286, 430), (272, 340), (284, 262), (334, 212), (400, 196), (466, 212),
                                        (516, 262), (528, 340), (514, 430), (534, 478, "c"), (500, 466), (488, 420),
                                        (312, 420), (300, 466), (266, 478, "c")], F(HAIR_SH), L(HAIR_SH, 2)))
tufts = head.node("Tufts")
tufts.add(S(head, "Cowlick", [(380, 232), (372, 206), (384, 186), (404, 180, "c"), (392, 196), (392, 214), (404, 230)],
            F(HAIR), L(HAIR_SH, 2.5)),
          S(head, "Cowlick2", [(408, 230), (420, 204), (444, 194, "c"), (434, 210), (428, 232)], F(HAIR), L(HAIR_SH, 2.5)))

# ================================================================ HATS (+ costume heads)
hat_solo = head.solo("HatSolo")
HATS: dict[str, El] = {"noHat": group("H_noHat")}

def hat_shadow(y_mid: float, y_side: float, depth: float = 16, x0: float = 286, x1: float = 514) -> El:
    """Soft occlusion where a hat sits on hair/forehead (so hats don't read as stickers)."""
    xm = (x0 + x1) / 2
    return S(head, "HatShadow", [(x0, y_side - 4), (xm - 70, y_mid + 2), (xm, y_mid), (xm + 70, y_mid + 2), (x1, y_side - 4),
                                 (x1 - 4, y_side + depth), (xm + 70, y_mid + depth + 2), (xm, y_mid + depth),
                                 (xm - 70, y_mid + depth + 2), (x0 + 4, y_side + depth)], F("4A2A1712"))


# beanie
bn = [(280, 322, "c8"), (284, 276), (330, 258), (400, 252), (470, 258), (516, 276), (520, 322, "c8"), (470, 308),
      (400, 302), (330, 308)]
bn_band = S(head, "Band", bn, grad([(BEANIE_HI, 0.0), (BEANIE, 0.5), (BEANIE_SH, 1.0)], -30, 30), L(INK, 3),
            origin=(400, 290))
HATS["beanie"] = group("H_beanie",
                       *[S(head, f"Rib{i}", [(x0, 262 - (x0 - 400) ** 2 / 2600), (x0, 306 - (x0 - 400) ** 2 / 2000)],
                           L(BEANIE_SH, 3.2), closed=False, clip=bn_band) for i, x0 in enumerate(range(298, 506, 16))],
                       bn_band,
                       S(head, "Crease1", [(336, 200), (380, 186), (430, 192)], L(BEANIE_SH, 3), closed=False),
                       S(head, "Crease2", [(318, 238), (390, 226), (470, 236)], L(BEANIE_SH, 3), closed=False),
                       S(head, "Dome", [(290, 282), (294, 214), (330, 168), (392, 146), (452, 154), (500, 190), (512, 240),
                                        (510, 282)], rgrad(200, [(BEANIE_HI, 0.0), (BEANIE, 0.5), (BEANIE_SH, 1.0)],
                                                           cx=-50, cy=-50), L(INK, 3)))

# backwards cap
CAP, CAP_SH, CAP_HI = "FFC8352B", "FF8E2019", "FFE45A4A"
HATS["backwardsCap"] = group("H_backwardsCap",
                             E(head, "Button", 400, 172, 16, 10, F(CAP_SH), L(INK, 2)),
                             *[S(head, f"Seam{i}", [(400, 172), (400 + k * 0.55, 220), (400 + k, 284)], L(CAP_SH, 2.5),
                                 closed=False) for i, k in enumerate((-70, 70))],
                             S(head, "Strap", [(372, 280), (428, 280)], L("FFD8C8A8", 6), closed=False),
                             S(head, "Opening", [(364, 286, "c"), (370, 254), (400, 244), (430, 254), (436, 286, "c")],
                               F(HAIR), L(INK, 2.5)),
                             S(head, "Crown", [(284, 300), (290, 232), (326, 186), (400, 166), (474, 186), (510, 232),
                                               (516, 300), (470, 290), (400, 284), (330, 290)],
                               rgrad(190, [(CAP_HI, 0.0), (CAP, 0.5), (CAP_SH, 1.0)], cx=-40, cy=-50), L(INK, 3)),
                             S(head, "BillBack", [(356, 176), (392, 150), (440, 146), (470, 160), (452, 176)],
                               vgrad(140, 180, CAP_SH, "FF6A1612"), L(INK, 3)))
# french beret
BER = "FF1E1E26"
HATS["frenchBeret"] = group("H_frenchBeret",
                            S(head, "Stem", [(424, 196), (428, 178), (436, 196)], F(BER), L(INK, 2)),
                            S(head, "BeretShine", [(330, 220), (380, 204), (440, 204), (400, 214), (350, 228)],
                              F("33FFFFFF")),
                            S(head, "Beret", [(280, 272), (298, 228), (356, 200), (440, 194), (522, 210), (562, 240),
                                              (548, 266), (480, 264), (400, 270), (322, 278)],
                              rgrad(180, [("FF3A3A48", 0.0), (BER, 0.7)], cx=-40, cy=-30), L("FF08080C", 3)))
# swim cap
HATS["swimCap"] = group("H_swimCap",
                        S(head, "CapShine", [(320, 250), (360, 212), (420, 198), (380, 224), (336, 262)], F("88FFFFFF")),
                        S(head, "SwimCap", [(280, 336), (280, 250), (316, 200), (400, 176), (484, 200), (520, 250),
                                            (520, 336), (500, 330), (470, 300), (400, 290), (330, 300), (300, 330)],
                          rgrad(220, [("FFEFF1F6", 0.0), ("FFB0B6C4", 0.55), ("FF6A7080", 1.0)], cx=-40, cy=-60),
                          L("FF3A3E4A", 3)))
# santa hat (tip flops; the hat state loop swings it)
santa_flop = Rig("SantaFlop", 520, 220)
santa_flop.el.attrs.update(x=520.0 - head.ax, y=220.0 - head.ay)
santa_flop.add(E(santa_flop, "Pom", 616, 340, 52, 52, rgrad(30, [("FFFFFFFF", 0.0), ("FFDDE2EA", 1.0)]), L("FFB8BECA", 2)),
               S(santa_flop, "Tip", [(500, 196), (560, 216), (604, 270), (622, 330), (604, 336), (574, 284), (520, 250)],
                 vgrad(200, 330, "FFD8302C", "FFA81E1C"), L(INK, 3)))
fur = [(278, 312, "c")]
for k in range(13):
    x = 284 + k * 19
    fur.append((x, 258 - (x - 400) ** 2 / 2600 - (6 if k % 2 else 0)))
fur += [(522, 312, "c")]
for k in range(13, -1, -1):
    x = 284 + k * 19
    fur.append((x, 314 - (x - 400) ** 2 / 3200 + (5 if k % 2 else 0)))
HATS["santaHat"] = group("H_santaHat",
                         S(head, "Fur", fur, rgrad(140, [("FFFFFFFF", 0.0), ("FFE2E6EE", 1.0)]), L("FFB8BECA", 2.5)),
                         santa_flop.el,
                         S(head, "SantaCone", [(290, 276), (310, 214), (360, 172), (430, 160), (500, 180), (540, 220),
                                               (520, 262), (400, 262)],
                           rgrad(190, [("FFE84A42", 0.0), ("FFC8282A", 0.6), ("FF96181A", 1.0)], cx=-40, cy=-50),
                           L(INK, 3)))


# red MAGA cap (front facing, lettering as strokes)
def letters(word: str, x0: float, y0: float, h: float) -> list[El]:
    w = h * 0.62
    out: list[El] = []
    for i, ch in enumerate(word):
        x = x0 + i * (w + 8)
        if ch == "M":
            pts = [(x, y0 + h), (x, y0), (x + w / 2, y0 + h * 0.6), (x + w, y0), (x + w, y0 + h)]
        elif ch == "A":
            pts = [(x, y0 + h), (x + w / 2, y0), (x + w, y0 + h)]
            out.append(S(head, f"Bar{i}", [(x + w * 0.22, y0 + h * 0.62), (x + w * 0.78, y0 + h * 0.62)], L(WHITE, 4.5),
                         closed=False))
        else:  # G
            pts = [(x + w, y0 + h * 0.18), (x + w * 0.5, y0), (x, y0 + h * 0.5), (x + w * 0.5, y0 + h),
                   (x + w, y0 + h * 0.7, "c"), (x + w, y0 + h * 0.52, "c"), (x + w * 0.55, y0 + h * 0.52, "c")]
        out.append(S(head, f"Ch{i}", [p if len(p) == 3 else (p[0], p[1], "c") for p in pts] if ch != "G" else pts,
                     L(WHITE, 4.5), closed=False))
    return out


HATS["redMagaCap"] = group("H_redMagaCap",
                           *letters("MAGA", 346, 210, 34),
                           S(head, "BillUnder", [(276, 300), (400, 292), (524, 300), (540, 316), (400, 322), (260, 316)],
                             F("FF6E1412")),
                           S(head, "Bill", [(270, 290), (400, 280), (530, 290), (548, 306), (400, 300), (252, 306)],
                             vgrad(280, 306, "FFD8352E", "FFA82420"), L(INK, 3)),
                           S(head, "Panel", [(400, 166), (400, 282)], L(CAP_SH, 2.5), closed=False),
                           E(head, "Button", 400, 166, 18, 10, F(CAP_SH), L(INK, 2)),
                           S(head, "MagaCrown", [(286, 292), (292, 222), (330, 178), (400, 162), (470, 178), (508, 222),
                                                 (514, 292), (400, 282)],
                             rgrad(190, [("FFEA4A42", 0.0), ("FFD0312D", 0.5), ("FF9A1E1A", 1.0)], cx=-30, cy=-40),
                             L(INK, 3)))

# -- costume heads
cowl_outer = [(284, 476), (276, 360), (282, 252), (300, 210), (312, 145, "c"), (342, 196), (400, 186), (458, 196),
              (488, 145, "c"), (500, 210), (518, 252), (524, 360), (516, 476), (480, 446), (452, 432), (420, 432),
              (400, 452, "c"), (380, 432), (348, 432), (320, 446)]


def cowl_shape() -> El:
    xs = [p[0] for p in cowl_outer]
    ys = [p[1] for p in cowl_outer]
    ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    outer = smooth_path(d, [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in cowl_outer])
    holes = []
    for cx in (355, 445):
        s = -1 if cx < 400 else 1
        hp = [(cx - 34 * s, 392), (cx - 8 * s, 368), (cx + 26 * s, 372), (cx + 38 * s, 390, "c"), (cx + 4 * s, 406)]
        holes.append(smooth_path(d, [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in hp]))
    return d("Shape", outer, *holes,
             d("Fill", lin(d, -60, -120, 60, 120, [("FF505868", 0.0), ("FF2B2E36", 0.5), ("FF16181E", 1.0)]),
               fillRule="evenOdd", name="Fill"),
             L("FF0A0B0E", 3.5), x=float(ox - head.ax), y=float(oy - head.ay), name="Cowl")


HATS["batman"] = group("H_batman",
                       S(head, "CowlShine", [(330, 230), (380, 206), (420, 204), (372, 222)], F("40FFFFFF")),
                       cowl_shape())
# robocop: helmet + dark visor with a sweeping red scanner
scan = head.node("Scanner", 400, 386)
scan.add(E(scan, "ScanGlow", 400, 386, 70, 30, rgrad(35, [("CCFF3030", 0.0), ("00FF3030", 1.0)])),
         R(scan, "ScanCore", 400, 386, 26, 8, 4, F("FFFFB0A8")))
visor_pts = [(284, 356), (400, 342), (516, 356), (512, 418), (400, 430), (288, 418)]
visor = S(head, "Visor", visor_pts, grad([("FF2A3A5A", 0.0), ("FF0C1020", 0.5), ("FF1A2440", 1.0)], -40, 40),
          L("FF0A0E18", 3))
visor_clip = clip_only(S(head, "VisorClip", visor_pts))
for c in scan.el.children:
    c.children.insert(0, d("ClippingShape", sourceId=visor_clip.ref(), name="Clip"))
HATS["robocop"] = group("H_robocop", scan.el,
                        S(head, "VisorGlare", [(300, 360), (350, 352), (330, 372)], F("40FFFFFF")),
                        visor, visor_clip,
                        S(head, "HelmetShine", [(320, 240), (370, 206), (420, 198), (360, 226)], F("88FFFFFF")),
                        S(head, "Helmet", [(276, 476), (270, 330), (286, 236), (330, 190), (400, 172), (470, 190),
                                           (514, 236), (530, 330), (524, 476), (498, 472), (494, 420), (400, 432),
                                           (306, 420), (302, 472)],
                          rgrad(260, [("FFEFF4FF", 0.0), (RC, 0.45), ("FF4A5A80", 1.0)], cx=-50, cy=-80), L(RC_INK, 3.5)))
# soubrette: frilly maid headband
mf = []
for k in range(9):
    x = 312 + k * 22
    mf.append(E(head, f"MaidFrill{k}", x, 240 - (x - 400) ** 2 / 2400, 28, 24, F(WHITE), L("FFB8B8C4", 2)))
HATS["soubrette"] = group("H_soubrette",
                          S(head, "MaidBand", [(300, 270), (400, 250), (500, 270)], L("FF15151A", 6), closed=False),
                          *mf)
# singularity: the head becomes a starfield silhouette with laser eyes
SING_HEAD = [(286, 440), (272, 340), (284, 262), (334, 212), (400, 196), (466, 212), (516, 262), (528, 340), (514, 440),
             (484, 470), (450, 500), (400, 516), (350, 500), (316, 470)]
sing_stars = starfield(head, SING_HEAD, 30, 9, "Head")
STAR_FX.extend(sing_stars[:10])
laser = head.node("Laser", 400, 388, opacity=0.0)
for t, x in (("L", 355), ("R", 445)):
    s = -1 if x < 400 else 1
    # Fine spectral rays decay before the silhouette edge. Layered lateral
    # falloff avoids the opaque trapezoids of the former artboard-wide beam.
    for i in range(6):
        length, width = 185 - i * 13, 13 - i * 1.9
        laser.add(S(laser, f"Beam{t}{i}",
                    [(x, 388 - width * 0.22), (x + s * length, 360 - width * 0.5),
                     (x + s * length, 360 + width * 0.5), (x, 388 + width * 0.22)],
                    d("Fill", lin(d, -s * length / 2, 0, s * length / 2, 0,
                                  [("306EE9FF", 0.0), ("186F93EC", 0.35), ("006F93EC", 1.0)]), name="Fill")))
eyeglow = [E(head, "EyeGlow" + t, x, 388, 46, 18, rgrad(23, [("FFFFFFFF", 0.0), ("FF7CF0FF", 0.5), ("007CF0FF", 1.0)]))
           for t, x in (("L", 355), ("R", 445))]
HATS["singularity"] = group("H_singularity", laser.el, *eyeglow, *sing_stars,
                            S(head, "Void", SING_HEAD, grad([("FF1A1E5A", 0.0), ("FF0A0B24", 0.6), ("FF05060F", 1.0)],
                                                            -160, 160), L("FF3A40A0", 3)))

for hid, (ym, ys) in {"beanie": (304, 322), "backwardsCap": (288, 302), "frenchBeret": (268, 274),
                     "santaHat": (312, 316), "redMagaCap": (300, 306)}.items():
    HATS[hid].add(hat_shadow(ym, ys))
for hid in HAT_IDS + COSTUMES:
    hat_solo.add(HATS[hid])
hat_solo.el.attrs["activeComponentId"] = HATS["noHat"].ref()

# ---- tap zones
hit_head = E(head, "HitHead", 400, 360, 300, 360, F("00000000"))
hit_body = R(body_g, "HitBody", 400, 820, 460, 380, 0, F("00000000"))

# head paint order (front first)
# Separate spring pivots preserve the idle breathing channels while gestures
# add a delayed response around the crown, rather than rotating the whole wig.
def hair_spring(name: str, rig: Rig) -> El:
    rig.el.attrs["y"] = 310.0
    return d("Node", rig.el, x=0.0, y=-310.0, name=name)


hair_follow = hair_spring("FringeFollowThrough", hair_front)
back_follow = hair_spring("BackHairFollowThrough", hair_back)
tuft_follow = hair_spring("TuftFollowThrough", tufts)
# Brows paint over the fringe (storybook convention: they must read through the bangs), under the
# glasses; same frame as the eyes so the head rig and the gesture travel treat them alike.
brows = d("Node", *[e["brow"].el for e in EYES], x=eyes.el.attrs["x"], y=eyes.el.attrs["y"], name="Brows")
eyes.el.children = [c for c in eyes.el.children if c not in (EYE_L["brow"].el, EYE_R["brow"].el)]
head.el.children = [hat_solo.el, sweat_m.el, sweat_p.el, anger.el, glasses_solo.el, brows, hair_follow, laugh.el,
                    eyes.el, blush.el, mouth.el, mole, nose_g.el, *skin_details, cheek_sh, face_cast, face, *ears, tufts.el,
                    back_follow, hit_head]
head.el.children[head.el.children.index(tufts.el)] = tuft_follow
travel_parts = []
for part in (eyes.el, brows, glasses_solo.el, mouth.el, nose_g.el, blush.el, mole):
    travel_part = d("Node", part, x=0.0, y=0.0, name="Travel" + str(part.attrs["name"]))
    head.el.children[head.el.children.index(part)] = travel_part
    travel_parts.append(travel_part)

# ---- phase props: thought bubble (generating), "?" (error)
bubble = body_g.node("Bubble", 650, 200, opacity=0.0, scaleX=0.6, scaleY=0.6)
cloud = [(570, 210), (580, 168), (620, 146), (660, 140), (704, 152), (732, 182), (736, 222), (712, 252), (670, 262),
         (620, 258), (584, 242)]
dots = [E(bubble, f"Dot{i}", 618 + i * 32, 202, 16, 16, F("FF6A5A7A")) for i in range(3)]
bubble.add(*dots, S(bubble, "Cloud", cloud, F(WHITE), L(INK, 3)),
           E(bubble, "Tail1", 560, 278, 24, 20, F(WHITE), L(INK, 2.5)),
           E(bubble, "Tail2", 540, 306, 14, 12, F(WHITE), L(INK, 2.5)))
question = body_g.node("Question", 200, 220, opacity=0.0)
question.add(E(question, "QDot", 200, 268, 16, 16, F("FFE0503A")),
             S(question, "QHook", [(178, 190), (196, 172), (220, 178), (226, 200), (204, 218), (200, 244)],
               L("FFE0503A", 11), closed=False))
clap_fx = body_g.node("ClapFx", 400, 760, opacity=0.0)
for k in range(5):
    a = -PI / 2 + (k - 2) * 0.45
    clap_fx.add(S(clap_fx, f"Burst{k}", [(400 + 62 * math.cos(a), 760 + 62 * math.sin(a)),
                                         (400 + 92 * math.cos(a), 760 + 92 * math.sin(a))], L("FFFFC24A", 5), closed=False))

body_g.el.children = [bubble.el, question.el, clap_fx.el, swing_r.el, swing_l.el, head_base.el,
                      top_front.el, chin_sh, neck_sh, neck, top_back.el, back_fx.el, hit_body]

cloth_parts = refine_wardrobe(body_g, head, TF, TB, HATS, ARMS, GLASSES, cape_rig)
# The cape's attachment remains on the collar; a separate response pivots it
# while the lower contour ripples. The costume layer only selects visibility.
cape_anchor = (float(cape_rig.el.attrs["x"]), float(cape_rig.el.attrs["y"]))
cape_rig.el.attrs.update(x=0.0, y=0.0)
cape_life = group("CapeLife", cape_rig.el)
cape_response = group("CapeResponse", cape_life)
cape_selection = d(
    "Node", cape_response, x=cape_anchor[0], y=cape_anchor[1], name="CapeAttachment")
back_fx.el.children[back_fx.el.children.index(cape_rig.el)] = cape_selection
# A Solo selects the new attachment rather than the formerly direct cape node.
cloth_parts.append(Cloth(cape_life, cape_response, 1.35, 0.8, 0.009))

# ================================================================ VIEW MODEL
CONTRACT_ENUMS = {
    "Mood": ["neutral", "happy", "sad", "angry", "surprised", "thinking", "embarrassed"],
    "Phase": ["idle", "waiting", "generating", "speaking", "error"],
    "GestureId": ["wave", "laugh", "facepalm", "shrug", "nod", "headshake", "clap", "think"],
    "Hat": HAT_IDS,
    "Top": TOP_IDS,
    "Glasses": ["glasses", "sunglasses"],
    "Costume": ["none"] + COSTUMES,
    "Presence": ["onScreen", "outOfScreen", "leaveAndComeBack"],
}
enums: dict[str, El] = {}
evals: dict[str, dict[str, El]] = {}
for en, vals in CONTRACT_ENUMS.items():
    vs = {v: d("DataEnumValue", key=v, value=v) for v in vals}
    enums[en] = d("DataEnumCustom", *vs.values(), name=en)
    evals[en] = vs
EN_OF = {"mood": "Mood", "phase": "Phase", "gestureId": "GestureId", "hat": "Hat", "top": "Top", "glasses": "Glasses",
         "costume": "Costume", "presence": "Presence"}
DEFAULTS = {"mood": "neutral", "phase": "idle", "gestureId": "wave", "hat": "noHat", "top": "pinkHoodie",
            "glasses": "glasses", "costume": "none", "presence": "onScreen"}
NUMBER_PROPS = {"mouth", *FACE_NUMBERS}  # contract v5: face action units, speech mouth, roll, breath
TRIGGER_PROPS = {"gesture", "blink"}
BOOL_PROPS = {"autoBlink": True}
props: dict[str, El] = {}
for pn in ["mood", "mouth", "phase", "gestureId", "gesture", "hat", "top", "glasses", "costume", "presence",
           *FACE_NUMBERS, "autoBlink", "blink"]:
    if pn in NUMBER_PROPS:
        props[pn] = d("ViewModelPropertyNumber", name=pn)
    elif pn in TRIGGER_PROPS:
        props[pn] = d("ViewModelPropertyTrigger", name=pn)
    elif pn in BOOL_PROPS:
        props[pn] = d("ViewModelPropertyBoolean", name=pn)
    else:
        props[pn] = d("ViewModelPropertyEnumCustom", enumId=enums[EN_OF[pn]].ref(), name=pn)
ivals = []
for pn, p in props.items():
    if pn in DEFAULTS:
        ivals.append(d("ViewModelInstanceEnum", propertyValue=evals[EN_OF[pn]][DEFAULTS[pn]].ref(),
                       viewModelPropertyId=p.ref()))
    elif pn in NUMBER_PROPS:
        ivals.append(d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref()))
    elif pn in BOOL_PROPS:
        ivals.append(d("ViewModelInstanceBoolean", propertyValue=BOOL_PROPS[pn], viewModelPropertyId=p.ref()))
    else:
        ivals.append(d("ViewModelInstanceTrigger", viewModelPropertyId=p.ref()))
inst = d("ViewModelInstance", *ivals, exports=True, name="Default")
vm = d("ViewModel", *props.values(), inst, name="AvatarVM", defaultInstanceId=inst.ref())


def vpath(pn: str) -> str:
    return f"{vm.ref()}-{props[pn].ref()}"


def enum_is(pn: str, val: str) -> El:
    return d("TransitionViewModelCondition",
             d("TransitionPropertyViewModelComparator",
               d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=vpath(pn), propertyKey=637))),
             d("TransitionValueEnumComparator", value=evals[EN_OF[pn]][val].ref()))


def enum_not(pn: str, val: str) -> El:
    c = enum_is(pn, val)
    c.attrs["opValue"] = "notEqual"
    return c


def trig(pn: str) -> El:
    return d("TransitionViewModelCondition",
             d("TransitionPropertyViewModelComparator",
               d("BindablePropertyTrigger", d("DataBindContext", sourcePathIds=vpath(pn), propertyKey=686))),
             d("TransitionValueTriggerComparator"))


# ================================================================ LIDS (M3)
# Each eye's opening on lid bones (rive/tools/face_rig.py rig_lids), minted from its own id range
# with the v6 per-side numbers, so the ids of everything in this document stay put. Built before
# the animations: the blinks key the BlinkDrive constraints.
lids = face_rig.FaceRig(lambda pn: vpath(pn) if pn in props else (
    f"{vm.ref()}-{side_props[pn].ref()}" if pn in side_props else f"@{pn}"), start=face_rig.LID_ID_START)
side_props = face_rig.add_side_numbers(lids.d, vm, inst)
BLINK_DRIVES = {id(e): face_rig.rig_lids(lids, e, e["cx"], e["s"], "FF2A1B18", "B8603A30", SKIN_SH2, SCLERA,
                                           "38B07A68")
                for e in EYES}

# ================================================================ ANIMATIONS
anims: list[El] = []


def seam(tracks: list[El], frames: int, doc: Doc = d) -> None:
    """A one-frame constant segment at either side of a closed loop makes its seam exact even when
    the runtime accumulates fractional frames."""
    if frames <= 4:
        return
    for obj in tracks:
        if obj is None:
            continue
        for prop in obj.children:
            first, last = prop.children[0], prop.children[-1]
            if (len(prop.children) > 1 and first.attrs["frame"] == 0 and last.attrs["frame"] == frames
                    and first.attrs["value"] == last.attrs["value"]):
                if prop.children[1].attrs["frame"] > 1:
                    prop.children.insert(1, doc(first.tag, **{**first.attrs, "frame": 1}))
                if prop.children[-2].attrs["frame"] < frames - 1:
                    prop.children.insert(-1, doc(last.tag, **{**last.attrs, "frame": frames - 1}))


def A(name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
    if loop:
        seam(tracks, frames)
    a = d("LinearAnimation", *[t for t in tracks if t is not None], duration=frames, fps=60,
          loopValue="loop" if loop else None, name=name)
    anims.append(a)
    return a


def T(target: El | Rig, ease: El | None = EASE, **kw: list) -> El:
    tgt = target.el if isinstance(target, Rig) else target
    return track(d, tgt, kw, ease=ease)


def K(target: El | Rig, **vals: object) -> El:
    """Static one-key pose."""
    return T(target, ease=None, **{k: [(0, v)] for k, v in vals.items()})


# ---- idle
breath = A("idle_breath", 360, [
    T(body, scaleY=[(0, 1.0), (142, 1.008), (360, 1.0)], y=[(0, 0.0), (142, -1.4), (360, 0.0)]),
    T(head_base, y=[(0, -440.0), (162, -443.5), (360, -440.0)],
      rotation=[(0, 0.0), (148, 0.008), (270, -0.004), (360, 0.0)]),
    T(hair_front, rotation=[(0, 0.0), (180, -0.006), (300, 0.003), (360, 0.0)]),
    T(tufts, rotation=[(0, 0.0), (192, 0.012), (304, -0.005), (360, 0.0)]),
    *[T(cord, rotation=[(0, 0.0), (164 + i * 16, (-1 if i else 1) * 0.008), (360, 0.0)])
      for i, cord in enumerate(TF["pinkHoodie"].children[:2])],
], loop=True)
wardrobe_life = A("wardrobe_life", 720, [
    T(part.life, rotation=[(f, part.amplitude * (math.sin(2 * math.pi * f / 720 + part.phase)
                                               - math.sin(part.phase))) for f in range(0, 721, 30)])
    for part in cloth_parts], loop=True)
cape_path = next(c for c in cape.children if c.tag == "PointsPath")
cape_ripple_tracks = []
for vertex in cape_path.children:
    vx, vy = float(vertex.attrs["x"]), float(vertex.attrs["y"])
    # Vertices are shape-local; only the lower two-thirds carry a travelling
    # ripple. End values stay exact and all upper attachment points stay fixed.
    influence = max(0.0, min(1.0, (vy + float(cape.attrs["y"]) - 105) / 260))
    if influence == 0:
        continue
    phase = vx * 0.012
    cape_ripple_tracks.append(T(vertex,
        x=[(f, vx + 7 * influence * (math.sin(2 * math.pi * f / 720 + phase) - math.sin(phase)))
           for f in range(0, 721, 30)],
        y=[(f, vy + 5 * influence * (math.sin(2 * math.pi * f / 720 + phase + 0.8) - math.sin(phase + 0.8)))
           for f in range(0, 721, 30)]))
cape_ripple = A("cape_ripple", 720, cape_ripple_tracks, loop=True)
# (frame, closure 0..1): fast close, a beat shut, slower ease-out open; one double blink, one half blink
blink_keys = [(0, 0.0), (168, 0.0), (171, 1.0), (173, 1.0), (181, 0.0),
              (395, 0.0), (398, 1.0), (400, 1.0), (407, 0.0), (418, 0.0), (421, 1.0), (423, 1.0), (431, 0.0),
              (560, 0.0), (563, 0.55), (566, 0.55), (572, 0.0), (660, 0.0)]


def blink_anim(name: str, frames: int, keys: list[tuple[int, float]] | None = None, loop: bool = False) -> El:
    """(M3, contract v6) a blink slides the upper lid bones onto the lower lid line: the keys drive
    each eye's BlinkDrive constraints (0 open .. 1 closed). The v5 tracks are still minted (and
    dropped) so every later id stays unchanged; the new tracks come from the lid rig's id range."""
    ks = [(f, v, EASE_OUT if v > 0.5 else EASE) for f, v in (keys or blink_keys)]
    retired = [t for e in EYES for t in retired_blink_track(e, keys)]
    new = [track(lids.d, c, {"strength": [(f, v, it) for f, v, it in ks]}) for e in EYES for c in BLINK_DRIVES[id(e)]]
    if loop:
        seam(new, frames, lids.d)
    a = A(name, frames, retired + new, loop=loop)
    a.children = [c for c in a.children if c not in retired]
    return a


def retired_blink_track(e: dict, keys: list[tuple[int, float]] | None = None) -> list[El]:
    """The v5 blink (lash cross-fade over a sliding skin lid); its tracks are no longer used."""
    e = {**e, **e["retired"]}
    ks = [(f, v, EASE_OUT if v > 0.5 else EASE) for f, v in (keys or blink_keys)]
    # the closed-lash swap lasts exactly while the eye is shut: switch back one frame after
    shut = []
    for (f, v, _), nxt in zip(ks, ks[1:] + [None]):
        closed = v > 0.99
        shut.append((f, 1.0 if closed else 0.0))
        if closed and nxt is not None and nxt[1] <= 0.99:
            shut.append((f + 1, 0.0))
    # a closing lid hides the smile and sad lid strokes, so a closed eye is one clean lash line
    hide = [(f, max(0.0, 1.0 - 1.6 * v), it) for f, v, it in ks]
    mood_strokes = [T(e["squint_line"], opacity=hide), T(e["squint"], opacity=hide),
                    T(named_el(e["droop"].el, "DroopLash"), opacity=hide)]
    return [*mood_strokes, T(e["lid"], scaleY=[(f, v, it) for f, v, it in ks]),
            T(e["lash"], y=[(f, float(e["lash"].el.attrs["y"]) + 24.0 * v, it) for f, v, it in ks],
              scaleY=[(f, 1.0 - 0.55 * v, it) for f, v, it in ks],
              opacity=[(f, 1.0 - o, "hold") for f, o in shut]),
            T(e["shut"], opacity=[(f, o, "hold") for f, o in shut])]


blink = blink_anim("idle_blink", 660, loop=True)
# contract v5: `autoBlink` false holds the eyes open; the `blink` trigger plays one blink (the app
# moves blinks into speech pauses)
blink_hold = blink_anim("blink_hold", 1, [(0, 0.0)])
blink_once = blink_anim("blink_once", 16, [(0, 0.0), (3, 1.0), (5, 1.0), (14, 0.0), (16, 0.0)])
LOOK_X, LOOK_Y = 7.0, 4.5
look_x = A("look_x", 100, [*[T(e["look"], ease=None, x=[(0, -LOOK_X), (100, LOOK_X)]) for e in EYES],
                           T(head_look, ease=None, rotation=[(0, -0.035), (100, 0.035)])])
look_y = A("look_y", 100, [T(e["look"], ease=None, y=[(0, -LOOK_Y), (100, LOOK_Y)]) for e in EYES])

# ---- moods (contract v5): accents only. Brows, lids, cheeks, nose and the mouth shape follow the
# `au*` numbers (rive/tools/face_rig.py); the app writes each mood's AU preset. Every pose keys
# every accent channel so the 240 ms crossfades blend cleanly.
MOOD_DEF = dict(gaze=(0, 0), blush=0.0, tilt=0.0, head_y=0.0, mouth_rot=0.0, mouth_x=0.0, sweat=0.0, anger=0.0,
                pupil=1.0)
MOOD_SPEC = {
    "neutral": {},
    "happy": dict(blush=0.65, tilt=-0.04),
    "sad": dict(tilt=0.05, head_y=6.0, gaze=(0, 9)),
    "angry": dict(tilt=-0.02, anger=1.0, pupil=0.85, head_y=2.0),
    "surprised": dict(head_y=-6.0, pupil=0.68),
    "thinking": dict(gaze=(-7, -8), tilt=0.085, mouth_rot=-0.12, mouth_x=3.0, head_y=-2.0),
    "embarrassed": dict(gaze=(6, 6), blush=1.0, sweat=1.0, tilt=0.04),
}


def mood_pose(name: str, spec: dict) -> El:
    p = {**MOOD_DEF, **spec}
    tr: list[El] = []
    for e in EYES:
        tr.append(K(e["pupil"], scaleX=p["pupil"], scaleY=p["pupil"]))
        tr.append(K(e["gm"], x=float(p["gaze"][0]), y=float(p["gaze"][1])))
    tr += [K(blush, opacity=p["blush"]), K(head_mood, rotation=p["tilt"], y=p["head_y"]),
           K(mouth_mood, rotation=p["mouth_rot"], x=p["mouth_x"]), K(sweat_m, opacity=p["sweat"]),
           K(anger, opacity=p["anger"])]
    return A("mood_" + name, 1, tr)


MOODS = {m: mood_pose(m, spec) for m, spec in MOOD_SPEC.items()}


# ---- phases (looping poses; all channels keyed in each)
def phase_anim(name: str, frames: int, head_y: list | None = None, head_rot: list | None = None,
               gaze: list | None = None, bubble_on: float = 0.0, dot_bounce: bool = False, q_on: float = 0.0,
               sweat_on: float = 0.0, brow: list | None = None) -> El:
    z = [(0, 0.0), (frames, 0.0)]
    tr = [T(head_phase, y=head_y or z, rotation=head_rot or z, x=z)]
    tr += [T(e["brow_p"], y=brow or z) for e in EYES]
    for e in EYES:
        tr.append(T(e["gp"], x=[(f, gx) for f, gx, gy in gaze] if gaze else z,
                    y=[(f, gy) for f, gx, gy in gaze] if gaze else z))
    tr.append(K(bubble, opacity=bubble_on, scaleX=0.6 + 0.4 * bubble_on, scaleY=0.6 + 0.4 * bubble_on))
    for i, dt in enumerate(dots):
        base = float(dt.attrs["y"])
        if dot_bounce:
            ph = i * 10
            keys = sorted({0: base, (ph + 0) % frames: base, (ph + 10) % frames: base - 14,
                           (ph + 20) % frames: base, frames: base}.items())
            tr.append(T(dt, y=[(f, v) for f, v in keys]))
        else:
            tr.append(K(dt, y=base))
    tr.append(T(question, opacity=[(0, q_on), (frames, q_on)],
                rotation=[(0, 0.0), (frames // 4, 0.12 * q_on), (3 * frames // 4, -0.12 * q_on), (frames, 0.0)]))
    sy = float(sweat_p.el.attrs["y"])
    tr.append(T(sweat_p, opacity=[(0, 0.0), (10, sweat_on), (frames - 20, sweat_on), (frames, 0.0)],
                y=[(0, sy), (frames, sy + 26 * sweat_on)]))
    return A("phase_" + name, frames, tr, loop=True)


PHASES = {
    "idle": phase_anim("idle", 60),
    # waiting: glances off to one side, a small weight shift and a patient breath back
    "waiting": phase_anim("waiting", 360, head_rot=[(0, 0.0), (50, 0.05), (150, 0.045), (200, -0.03), (290, -0.025),
                                                    (340, 0.0), (360, 0.0)],
                          head_y=[(0, 0.0), (50, 3.0), (150, 2.0), (200, -2.0), (290, -1.0), (360, 0.0)],
                          gaze=[(0, 0, 0), (28, 0, 0), (33, 7, 1), (145, 7, 1), (150, 6, 2),
                                (179, 6, 2), (184, -6, -1), (284, -6, -1), (290, -5, 0),
                                (325, -5, 0), (330, 0, 0),
                                (360, 0, 0)],
                          brow=[(0, 0.0), (40, -4.0), (150, -2.0), (200, -5.0), (290, -2.0), (360, 0.0)]),
    "generating": phase_anim("generating", 60, head_rot=[(0, -0.04), (60, -0.04)],
                             gaze=[(0, 5, -5), (60, 5, -5)], bubble_on=1.0, dot_bounce=True),
    # speaking (contract v5): a faint sway only; the app's prosody acting drives brows, nods and blinks
    "speaking": phase_anim("speaking", 420,
                           head_rot=[(0, 0.0), (70, 0.008), (160, -0.006), (250, 0.007), (340, -0.005), (420, 0.0)]),
    "error": phase_anim("error", 120, head_rot=[(0, 0.06), (120, 0.06)], gaze=[(0, -4, 2), (120, -4, 2)],
                        q_on=1.0, sweat_on=1.0),
}

# ---- gestures (IK-posed arms + head channels; gesture_none keys every gesture channel at rest)
ARM_Y0 = 0.0
REST = (240.0, 1070.0)
MOUTH_XY = (float(mouth.el.attrs["x"]), float(mouth.el.attrs["y"]))
Pose = tuple  # (frame, wrist | None, finger_deg, fs=1.0)


def _smooth(t: float) -> float:
    return t * t * (3 - 2 * t)


def _unwrap(prev: float, v: float) -> float:
    while v - prev > math.pi:
        v -= 2 * math.pi
    while v - prev < -math.pi:
        v += 2 * math.pi
    return v


def arm_keys(side: int, poses: list[Pose], out: bool = False, lag: int = 2,
             hand: list[tuple[int, str]] | None = None, step: int = 2) -> list[El]:
    """IK baked along the WRIST path (not joint angles), so the hand travels on a smooth eased
    arc between key poses and never swings wide. Pose = (frame, wrist|None, finger_deg, fs, fs2)
    with fs/fs2 the upper/forearm foreshortening. The hand trails the forearm by `lag` frames;
    `hand` switches the hand drawing [(frame, pose name)]."""
    a = ARMS[0 if side == -1 else 1]
    rest = (800 - REST[0] if side == 1 else REST[0], REST[1])
    P = [(p[0], rest if p[1] is None else p[1], p[2], p[3] if len(p) > 3 else 1.0, p[4] if len(p) > 4 else 1.0)
         for p in poses]

    def sample(f: float) -> tuple[tuple[float, float], float, float, float]:
        f = max(P[0][0], min(P[-1][0], f))
        i = max(k for k in range(len(P) - 1) if P[k][0] <= f) if f < P[-1][0] else len(P) - 2
        p0, p1 = P[i], P[i + 1]
        t = _smooth((f - p0[0]) / max(1e-6, p1[0] - p0[0]))
        pm = P[max(0, i - 1)][1]
        pn = P[min(len(P) - 1, i + 2)][1]
        # centripetal-ish Catmull-Rom through the wrist targets (tension 0.5)
        x0, y0 = p0[1]
        x1, y1 = p1[1]
        m0 = ((x1 - pm[0]) * 0.25, (y1 - pm[1]) * 0.25)
        m1 = ((pn[0] - x0) * 0.25, (pn[1] - y0) * 0.25)
        h00, h10, h01, h11 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t, -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
        wx = h00 * x0 + h10 * m0[0] + h01 * x1 + h11 * m1[0]
        wy = h00 * y0 + h10 * m0[1] + h01 * y1 + h11 * m1[1]
        dd = p1[2] - p0[2]
        while dd > 180:
            dd -= 360
        while dd < -180:
            dd += 360
        return (wx, wy), p0[2] + dd * t, p0[3] + (p1[3] - p0[3]) * t, p0[4] + (p1[4] - p0[4]) * t

    frames = sorted(set(list(range(P[0][0], P[-1][0], step)) + [p[0] for p in P]))
    k1, k2, k3, ey, us, hy, fsy = [], [], [], [], [], [], []
    prev = (0.0, 0.0, 0.0)
    for f in frames:
        rest_pose = any(p[0] == f and p[1] is None for p in poses)
        w, _, fs, fs2 = sample(f)
        _, deg_lag, _, _ = sample(f - lag)
        r = (0.0, 0.0, 0.0) if rest_pose else ik(side, w, deg_lag, out, fs, fs2)
        r = tuple(_unwrap(pv, v) for pv, v in zip(prev, r))
        prev = r
        k1.append((f, r[0], "linear"))
        k2.append((f, r[1], "linear"))
        k3.append((f, r[2], "linear"))
        ey.append((f, L1 * fs, "linear"))
        us.append((f, fs, "linear"))
        hy.append((f, L2 * fs2, "linear"))
        fsy.append((f, fs2, "linear"))
    tr = [T(a["arm"], rotation=k1), T(a["elbow"], rotation=k2, y=ey), T(a["hand"], rotation=k3, y=hy),
          T(a["up_art"], scaleY=us), T(a["fore_art"], scaleY=fsy)]
    if hand:
        for solo, ps in a["pose_sets"]:
            tr.append(T(solo, activeComponentId=[(f, ps[n]) for f, n in hand]))
    return tr


def mirror_poses(poses: list[Pose]) -> list[Pose]:
    return [(p[0], None if p[1] is None else (800 - p[1][0], p[1][1]), 180 - p[2], *p[3:]) for p in poses]


def feat(x: list | None = None, y: list | None = None, gaze: bool = True) -> list[El]:
    """Fake yaw/pitch: shift eyes, nose and mouth together inside the head outline."""
    z = [(0, 0.0)]
    mx_, my_ = MOUTH_XY
    tr = [T(e["gg"], x=x or z, y=y or z) for e in EYES] if gaze else []
    tr.append(T(nose_g, x=x or z, y=y or z))
    tr.append(T(mouth, x=[(f, mx_ + v) for f, v in (x or z)], y=[(f, my_ + v) for f, v in (y or z)]))
    return tr


gesture_rest = [T(a[k], ease=None, rotation=[(0, 0.0)]) for a in ARMS for k in ("arm", "elbow", "hand", "wave")]
gesture_rest += [K(a["arm"], y=ARM_Y0) for a in ARMS]
gesture_rest += [K(a["elbow"], y=L1) for a in ARMS] + [K(a["up_art"], scaleY=1.0) for a in ARMS]
gesture_rest = [t for t in gesture_rest if not (t.attrs.get("objectId") in {a["hand"].ref() for a in ARMS}
                                                and t.children[0].attrs.get("property") == "rotation")]
gesture_rest += [T(a["hand"], ease=None, rotation=[(0, 0.0)]) for a in ARMS]
gesture_rest += [K(solo, activeComponentId=ps["rest"]) for a in ARMS for solo, ps in a["pose_sets"]]
gesture_rest += [K(a["hand"], y=L2) for a in ARMS] + [K(a["fore_art"], scaleY=1.0) for a in ARMS]
gesture_rest += [K(body_g, y=0.0, rotation=0.0), K(head_g, x=0.0, y=0.0, rotation=0.0), K(laugh, opacity=0.0),
                 K(clap_fx, opacity=0.0, scaleX=1.0, scaleY=1.0), K(nose_g, x=0.0, y=0.0),
                 K(mouth, x=MOUTH_XY[0], y=MOUTH_XY[1])]
gesture_rest += [K(e["brow_g"], y=0.0) for e in EYES] + [K(e["gg"], x=0.0, y=0.0) for e in EYES]
gesture_rest += [K(spring, rotation=0.0, y=-310.0) for spring in (hair_follow, back_follow, tuft_follow)]
gesture_rest += [K(part.response, rotation=0.0) for part in cloth_parts]
gesture_rest += [K(e["gesture_lid"], scaleY=0.0) for e in EYES]
gesture_rest += [K(e["gesture_shut"], opacity=0.0) for e in EYES] + [K(line_acting, scaleY=1.0, rotation=0.0)]
g_none = A("gesture_none", 1, gesture_rest)

G: dict[str, El] = {}

# wave: anticipation dip, overshooting raise, a lively wave with forearm sway, eased drop with settle
wave_sway = [(26, (198, 604), -94, 0.75), (36, (186, 610), -104, 0.75), (46, (208, 602), -86, 0.75),
             (56, (188, 610), -102, 0.75), (66, (206, 602), -88, 0.75), (76, (190, 608), -100, 0.75),
             (86, (198, 604), -94, 0.75)]
G["wave"] = A("gesture_wave", 120, [
    *arm_keys(-1, [(0, None, 90), (6, (238, 1084), 94), (12, (205, 930), 40, 0.95, 0.55),
                   (18, (205, 790), -60, 0.8, 0.5), (24, (194, 620), -102, 0.75, 0.9), *wave_sway,
                   (96, (205, 790), -40, 0.8, 0.5), (103, (205, 930), 60, 0.95, 0.55),
                   (110, (238, 1082), 94), (120, None, 90)],
              lag=3, hand=[(0, "rest"), (13, "palm"), (99, "rest")]),
    T(ARM_R["wave"], rotation=[(0, 0.0), (28, 0.0), (35, -0.3), (45, 0.24), (55, -0.3), (65, 0.24), (75, -0.26),
                               (86, 0.06), (96, 0.0), (120, 0.0)]),
    *arm_keys(1, mirror_poses([(0, None, 90), (14, (246, 1078), 96), (94, (246, 1078), 96), (120, None, 90)])),
    T(head_g, y=[(0, 0.0), (8, 2.0), (22, -6.0), (90, -4.0), (110, 0.0), (120, 0.0)],
      rotation=[(0, 0.0), (22, -0.07), (60, -0.05), (90, -0.06), (112, 0.0), (120, 0.0)]),
    T(body_g, rotation=[(0, 0.0), (20, -0.012), (90, -0.01), (112, 0.0), (120, 0.0)]),
])

# Laugh starts with an inhale, breaks into unequal pulses and runs out of
# breath. The ribcage rolls against the head; shoulders catch up separately.
bounce = [(0, 0.0), (7, 3.0), (15, -8.0), (22, 1.0), (34, -6.0), (43, 1.5),
          (59, -4.0), (70, 0.5), (84, 1.0), (96, 0.0)]
G["laugh"] = A("gesture_laugh", 96, [
    T(body_g, y=bounce,
      rotation=[(0, 0.0), (8, -0.012), (17, 0.024), (27, -0.017), (38, 0.018),
                (49, -0.011), (64, 0.009), (76, -0.004), (90, 0.002), (96, 0.0)]),
    *[T(a["arm"], y=[(f if f in (0, 96) else f + i * 3, v * (0.72 - i * 0.27))
                       for f, v in bounce],
        rotation=[(0, 0.0), (8 + i * 2, -0.012 * (1 if i == 0 else -1)),
                  (19 + i * 3, 0.027 * (1 if i == 0 else -1)),
                  (31 + i * 3, -0.013 * (1 if i == 0 else -1)),
                  (44 + i * 3, 0.018 * (1 if i == 0 else -1)),
                  (66 + i * 3, 0.009 * (1 if i == 0 else -1)), (88, -0.003), (96, 0.0)])
      for i, a in enumerate(ARMS)],
    T(head_g, rotation=[(0, 0.0), (6, 0.03), (18, -0.10), (30, -0.055),
                        (41, -0.085), (54, -0.045), (67, -0.065), (83, -0.02), (96, 0.0)],
      x=[(0, 0.0), (9, -1.0), (20, -3.0), (32, 1.5), (43, -2.0),
         (56, 1.0), (70, -0.8), (88, 0.3), (96, 0.0)],
      y=[(0, 0.0), (7, 3.0), (18, -10.0), (26, -5.0), (37, -8.0), (47, -4.0),
         (62, -6.0), (74, -3.0), (88, 1.0), (96, 0.0)]),
    T(laugh, opacity=[(0, 0.0, "hold"), (5, 1.0, "hold"), (86, 0.0, "hold"), (96, 0.0, "hold")]),
    T(laugh_jaw, scaleY=[(0, 0.62), (5, 0.62), (15, 1.0), (24, 0.46),
                         (36, 0.90), (47, 0.50), (62, 0.77), (74, 0.52), (85, 0.60), (96, 0.62)],
      scaleX=[(0, 0.98), (15, 1.03), (24, 0.96), (36, 1.02), (47, 0.97),
              (62, 1.01), (74, 0.98), (96, 0.98)]),
    *feat(y=[(0, 0.0), (16, -3.0), (80, -2.0), (96, 0.0)]),
])

# facepalm: hand comes to the eye (back of hand to camera), the head sinks INTO it, a slow disbelieving shake
G["facepalm"] = A("gesture_facepalm", 132, [
    *arm_keys(-1, [(0, None, 90), (8, (238, 1082), 94), (14, (286, 870), 10, 0.8), (19, (330, 650), -60, 0.65),
                   (24, (348, 466), -76, 0.55), (30, (342, 476), -80, 0.55),
                   (96, (344, 474), -80, 0.55), (104, (330, 650), -60, 0.65), (111, (286, 870), 30, 0.8),
                   (120, (242, 1080), 92), (132, None, 90)],
              lag=3, hand=[(0, "rest"), (12, "back"), (106, "rest")]),
    T(ARM_R["wave"], rotation=[(0, 0.0), (40, 0.0), (52, 0.05), (66, -0.04), (80, 0.05), (96, 0.0), (132, 0.0)]),
    T(head_g, rotation=[(0, 0.0), (26, 0.0), (36, 0.12), (52, 0.09), (66, 0.13), (80, 0.09), (98, 0.11), (118, 0.0),
                        (132, 0.0)],
      y=[(0, 0.0), (26, 0.0), (36, 12.0), (98, 10.0), (118, 0.0), (132, 0.0)]),
    *feat(x=[(0, 0.0), (36, -4.0), (52, 3.0), (66, -4.0), (80, 3.0), (98, 0.0), (132, 0.0)],
          y=[(0, 0.0), (36, 5.0), (98, 5.0), (118, 0.0), (132, 0.0)]),
    T(body_g, y=[(0, 0.0), (36, 4.0), (98, 4.0), (118, 0.0), (132, 0.0)]),
    *[T(e["brow_g"], y=[(0, 0.0), (30, 4.0), (100, 4.0), (118, 0.0), (132, 0.0)]) for e in EYES],
    *[T(e["gesture_lid"], scaleY=[(0, 0.0), (21, 0.0), (27, 1.0), (96, 1.0), (108, 0.0), (132, 0.0)]) for e in EYES],
    *[T(e["gesture_shut"], opacity=[(0, 0.0), (25, 0.0), (28, 1.0), (96, 1.0), (102, 0.0), (132, 0.0)]) for e in EYES],
    T(line_acting, scaleY=[(0, 1.0), (24, 0.65), (100, 0.65), (120, 1.0), (132, 1.0)],
      rotation=[(0, 0.0), (24, 0.12), (100, 0.12), (120, 0.0), (132, 0.0)]),
])

# shrug: shoulders rise, elbows stay at the sides, forearms open outward with palms up; head sinks between shoulders
# shrug: elbows stay near the ribs, forearms come forward toward the camera (foreshortened), palms up
shrug_poses = [(0, None, 90), (6, (238, 1078), 92), (18, (156, 836), 212, 0.92, 0.5), (26, (164, 846), 202, 0.92, 0.52),
               (60, (160, 842), 200, 0.92, 0.52), (74, (214, 990), 110, 0.97, 0.85), (84, (242, 1078), 92),
               (92, None, 90)]
shoulder = [(0, ARM_Y0), (6, ARM_Y0 + 4), (18, ARM_Y0 - 20), (26, ARM_Y0 - 15), (60, ARM_Y0 - 16), (78, ARM_Y0 + 3),
            (86, ARM_Y0), (92, ARM_Y0)]
shrug_other = [(f if f in (0, 92) else f + 3,
                None if wrist is None else (wrist[0] + 9, wrist[1] + 7), deg, *scales)
               for f, wrist, deg, *scales in mirror_poses(shrug_poses)]
G["shrug"] = A("gesture_shrug", 92, [
    *arm_keys(-1, shrug_poses, lag=2, hand=[(0, "rest"), (9, "up"), (72, "rest")]),
    *arm_keys(1, shrug_other, lag=3, hand=[(0, "rest"), (12, "up"), (75, "rest")]),
    T(ARM_R["arm"], y=shoulder),
    T(ARM_L["arm"], y=[(f if f in (0, 92) else f + 3, v * 0.8) for f, v in shoulder]),
    T(head_g, rotation=[(0, 0.0), (20, 0.09), (60, 0.07), (82, 0.0), (92, 0.0)],
      y=[(0, 0.0), (6, -2.0), (20, 10.0), (60, 9.0), (82, 0.0), (92, 0.0)]),
    *[T(e["brow_g"], y=[(0, 0.0), (16, -10.0), (60, -9.0), (80, 0.0), (92, 0.0)]) for e in EYES],
    T(body_g, y=[(0, 0.0), (6, 3.0), (20, -3.0), (60, -2.0), (82, 0.0), (92, 0.0)]),
])

# nod: two decaying nods with fake pitch (features drop) and a breath of overshoot
G["nod"] = A("gesture_nod", 72, [
    T(head_g, y=[(0, 0.0), (10, 16.0), (20, -3.0), (30, 12.0), (40, -2.0), (50, 4.0), (62, 0.0), (72, 0.0)],
      rotation=[(0, 0.0), (10, 0.02), (20, -0.01), (30, 0.015), (40, 0.0), (72, 0.0)]),
    *feat(y=[(0, 0.0), (11, 7.0), (21, -2.0), (31, 5.0), (41, -1.0), (51, 2.0), (62, 0.0), (72, 0.0)]),
    T(body_g, y=[(0, 0.0), (12, 2.5), (22, 0.0), (32, 2.0), (42, 0.0), (72, 0.0)]),
])

# headshake: the outline turns a little, the features turn a lot (yaw), hair trails
shake_x = [(0, 0.0), (9, -13.0), (22, 13.0), (35, -11.0), (48, 8.0), (60, -4.0), (72, 0.0), (84, 0.0)]
G["headshake"] = A("gesture_headshake", 84, [
    T(head_g, x=shake_x, rotation=[(f, -v * 0.008) for f, v in shake_x]),
    *feat(x=[(f, v * 1.8) for f, v in shake_x]),
    T(body_g, rotation=[(f, v * 0.0012) for f, v in shake_x]),
])

# Three applause beats: a readable open silhouette, quick palm contact,
# two-frame compression and a slower, progressively smaller rebound.
# Fingers lean OUT at contact; leaning them in makes a prayer triangle.
clap_l = [(0, None, 90), (7, (238, 1080), 92), (15, (294, 878), -55, 0.78),
          (23, (286, 814), -105, 0.76)]
clap_hits = (30, 53, 78)
for k, hit in enumerate(clap_hits):
    clap_l += [(hit, (387, 812), -100, 0.76),
               (hit + 2, (389, 814), -99, 0.75),
               (hit + 16, (302 + 10 * k, 819), -108, 0.77)]
clap_l += [(105, (298, 904), -25, 0.88), (116, (242, 1078), 92), (124, None, 90)]
clap_fx_on = [(0, 0.0, "hold")]
clap_fx_scale = [(0, 0.6)]
for hit in clap_hits:
    clap_fx_on += [(hit - 1, 0.0, "hold"), (hit, 0.9, "linear"), (hit + 8, 0.0, "hold")]
    clap_fx_scale += [(hit - 1, 0.55), (hit + 8, 1.18)]
clap_r = [(p[0], None if p[1] is None else (800 - p[1][0], p[1][1] + 5), 180 - p[2], *p[3:])
          for p in clap_l]
G["clap"] = A("gesture_clap", 124, [
    *arm_keys(-1, clap_l, lag=0, hand=[(0, "rest"), (17, "edge"), (108, "rest")], step=1),
    *arm_keys(1, clap_r, lag=1, hand=[(0, "rest"), (17, "edge"), (108, "rest")], step=1),
    T(clap_fx, opacity=clap_fx_on + [(124, 0.0, "hold")],
      scaleX=clap_fx_scale + [(124, 1.0)], scaleY=clap_fx_scale + [(124, 1.0)]),
    T(head_g, y=[(0, 0.0), (18, -5.0)] +
      [(f, v) for hit in clap_hits for f, v in ((hit + 2, 3.0), (hit + 11, -4.0))] + [(112, 0.0), (124, 0.0)],
      rotation=[(0, 0.0), (22, -0.025), (78, -0.018), (112, 0.0), (124, 0.0)]),
    T(body_g, y=[(0, 0.0), (22, -1.0)] +
      [(f, v) for hit in clap_hits for f, v in ((hit, 5.0), (hit + 9, -2.5))] + [(112, 0.0), (124, 0.0)],
      rotation=[(0, 0.0), (20, -0.008), (32, 0.012), (48, -0.007), (55, 0.009),
                (72, -0.005), (80, 0.007), (112, 0.0), (124, 0.0)]),
])

# think: index finger to the chin, head tilts, eyes drift up and away; the finger taps while thinking
G["think"] = A("gesture_think", 132, [
    *arm_keys(-1, [(0, None, 90), (8, (238, 1080), 92), (16, (296, 850), 10, 0.8), (21, (346, 700), -50, 0.72),
                   (26, (370, 598), -62, 0.7), (32, (364, 606), -68, 0.7),
                   (96, (366, 604), -66, 0.7), (104, (346, 700), -40, 0.72), (111, (296, 850), 30, 0.8),
                   (120, (242, 1078), 92), (132, None, 90)],
              lag=3, hand=[(0, "rest"), (22, "point"), (99, "rest")]),
    T(ARM_R["wave"], rotation=[(0, 0.0), (44, 0.0), (48, 0.07), (52, 0.0), (70, 0.0), (74, 0.07), (78, 0.0),
                               (132, 0.0)]),
    T(head_g, rotation=[(0, 0.0), (28, -0.08), (96, -0.06), (118, 0.0), (132, 0.0)],
      y=[(0, 0.0), (28, -3.0), (96, -2.0), (118, 0.0), (132, 0.0)]),
    *feat(x=[(0, 0.0), (30, 4.0), (96, 3.0), (118, 0.0), (132, 0.0)], gaze=False),
    *[T(e["gg"], x=[(0, 0.0), (5, 0.0), (11, -7.0), (56, -7.0), (61, -5.0),
                   (90, -5.0), (97, 0.0), (132, 0.0)],
        y=[(0, 0.0), (5, 0.0), (11, -7.0), (90, -6.0), (97, 0.0), (132, 0.0)]) for e in EYES],
    T(EYE_L["brow_g"], y=[(0, 0.0), (17, -8.0), (96, -7.0), (118, 0.0), (132, 0.0)]),
    T(EYE_R["brow_g"], y=[(0, 0.0), (21, 2.0), (96, 1.0), (118, 0.0), (132, 0.0)]),
])


def head_channel(animation: El, prop: str) -> list[tuple[float, float]]:
    for obj in animation.children:
        if obj.attrs.get("objectId") == head_g.ref():
            for channel in obj.children:
                if channel.attrs["property"] == prop:
                    return [(float(k.attrs["frame"]), float(k.attrs["value"])) for k in channel.children]
    return [(0.0, 0.0)]


def channel_at(keys: list[tuple[float, float]], frame: float) -> float:
    if frame <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if frame <= f1:
            return v0 + (v1 - v0) * _smooth((frame - f0) / (f1 - f0))
    return keys[-1][1]


for animation in G.values():
    duration = int(animation.attrs["duration"])
    turns, rises = head_channel(animation, "rotation"), head_channel(animation, "y")
    for spring, delay, strength in ((hair_follow, 4, 0.65), (back_follow, 6, 0.48), (tuft_follow, 5, 1.15)):
        samples = sorted(set(range(0, duration, 3)) | {duration})
        animation.add(T(spring, ease=None,
            rotation=[(f, strength * (channel_at(turns, f - delay) - channel_at(turns, f))
                       * min(1.0, (duration - f) / 8), "linear") for f in samples],
            y=[(f, -310 + 0.35 * (channel_at(rises, f - delay) - channel_at(rises, f))
                * min(1.0, (duration - f) / 8), "linear") for f in samples]))
    # Suspended cloth trails torso motion; head-only gestures have a much
    # smaller shoulder response. Ambient movement owns a different node.
    for part in cloth_parts:
        samples = sorted(set(range(0, duration, 3)) | {duration})
        keys = []
        for f in samples:
            impulse = (channel_at(turns, f - 7) - channel_at(turns, f)) * 0.55
            impulse += (channel_at(rises, f - 5) - channel_at(rises, f)) * 0.003
            if animation.attrs["name"] in ("gesture_wave", "gesture_clap", "gesture_shrug", "gesture_laugh"):
                impulse += 0.025 * math.sin(f * 0.23 + part.phase) * math.sin(math.pi * f / duration)
            keys.append((f, impulse * part.strength * min(1.0, (duration - f) / 10), "linear"))
        animation.add(T(part.response, ease=None, rotation=keys))

# ---- wardrobe switches
hat_hair = {"noHat": (1, 1, 1), "beanie": (1, 1, 0), "backwardsCap": (1, 1, 0), "frenchBeret": (1, 1, 0),
            "swimCap": (0, 0, 0), "santaHat": (1, 1, 0), "redMagaCap": (1, 1, 0),
            "batman": (0, 0, 0), "robocop": (0, 0, 0), "soubrette": (1, 1, 1), "singularity": (0, 0, 0)}


def hat_tracks(hid: str) -> list[El]:
    hf, hb, tu = hat_hair[hid]
    return [K(hat_solo, activeComponentId=HATS[hid]), K(hair_front, opacity=float(hf)), K(hair_back, opacity=float(hb)),
            K(tufts, opacity=float(tu))]


santa_swing = [T(santa_flop, rotation=[(0, 0.0), (130, 0.025), (310, -0.018), (470, 0.01), (600, 0.0)])]
HAT_ANIMS = {h: A("hat_" + h, 600 if h == "santaHat" else 1, hat_tracks(h) + (santa_swing if h == "santaHat" else []),
                  loop=h == "santaHat") for h in HAT_IDS}


def top_tracks(oid: str) -> list[El]:
    tr = [K(top_front, activeComponentId=TF[oid]), K(top_back, activeComponentId=TB[oid])]
    for a in ARMS:
        tr += [K(a["up_solo"], activeComponentId=a["ups"][oid]), K(a["fore_solo"], activeComponentId=a["fores"][oid]),
               K(a["skin_solo"], activeComponentId=a["skins"][COSTUME_HANDS.get(oid, "skin")])]
    return tr


TOP_ANIMS = {t: A("top_" + t, 1, top_tracks(t)) for t in TOP_IDS}
GLASS_ANIMS = {g: A("glasses_" + g, 1, [K(glasses_solo, activeComponentId=GLASSES[g])]) for g in ("glasses", "sunglasses")}

none_anim = A("costume_none", 1, [K(back_fx, activeComponentId=fx_none),
                                *[K(part, opacity=1.0) for part in (neck, chin_sh, neck_sh)]])
star_twinkle = [T(s_, opacity=[(0, 1.0), (110 + (i * 37) % 370, 0.4), (340 + (i * 37) % 370, 1.0), (960, 1.0)])
                for i, s_ in enumerate(STAR_FX)]
COSTUME_EXTRA = {
    "batman": [K(back_fx, activeComponentId=cape_selection)],
    "robocop": [K(back_fx, activeComponentId=fx_none),
                T(scan, x=[(0, -86.0), (40, -86.0), (180, 86.0), (240, 86.0), (410, -86.0), (480, -86.0)])],
    "soubrette": [K(back_fx, activeComponentId=fx_none)],
    "singularity": [K(back_fx, activeComponentId=aura_rig.el),
                    T(aura_rig, scaleX=[(0, 0.96), (380, 1.04), (710, 0.99), (960, 0.96)],
                      scaleY=[(0, 0.96), (420, 1.03), (770, 0.98), (960, 0.96)],
                      opacity=[(0, 0.75), (390, 0.95), (760, 0.82), (960, 0.75)]),
                    T(laser, opacity=[(0, 0.0), (612, 0.0), (630, 0.65), (674, 0.55), (700, 0.0), (960, 0.0)]),
                    *star_twinkle],
}


def costume_tracks(cid: str) -> list[El]:
    tr = hat_tracks(cid) + top_tracks(cid) + COSTUME_EXTRA[cid]
    tr += [K(part, opacity=0.0 if cid in ("batman", "robocop", "singularity") else 1.0)
           for part in (neck, chin_sh, neck_sh)]
    if cid in ("batman", "robocop", "singularity"):
        tr.append(K(glasses_solo, activeComponentId=GLASSES["none"]))
    return tr


COSTUME_FRAMES = {"batman": 720, "robocop": 480, "soubrette": 720, "singularity": 960}
COSTUME_ANIMS = {"none": none_anim, **{c: A("costume_" + c, COSTUME_FRAMES[c], costume_tracks(c), loop=True)
                                      for c in COSTUMES}}

# ---- presence: walk off/on to the right (Root x is absolute)
ON_X, OFF_X = 400.0, 1250.0


STRIDE = 170.0                # artboard pixels travelled per footfall


def walk_tracks(frames: int, moves: list[tuple[int, int, float, float]]) -> list[El]:
    """Weight shift, distance-driven steps, head lead and a delayed settling beat."""
    def pose(f: float) -> tuple[float, float, float, float, float, float, float]:
        x, bob, roll, swing, turn, width, shoulder = moves[0][2], 0.0, 0.0, 0.0, 0.0, 1.0, 0.0
        for f0, f1, x0, x1 in moves:
            if f < f0:
                break
            direction = 1.0 if x1 > x0 else -1.0
            x = x1
            if f <= f1:
                elapsed = f - f0
                if elapsed < 10:
                    weight = math.sin(math.pi * elapsed / 10)
                    x = x0 - direction * 7 * weight
                    bob, roll = 2 * weight, -direction * 0.014 * weight
                    turn = direction * 17 * _smooth(min(1.0, elapsed / 7))
                    width = 1 - 0.085 * _smooth(elapsed / 10)
                else:
                    t = (elapsed - 10) / (f1 - f0 - 10)
                    travel = _smooth(t)
                    speed = 4 * t * (1 - t)
                    distance = abs(x1 - x0) * travel
                    phase = math.pi * distance / STRIDE
                    # Subtle unequal footfalls keep the implied gait alive.
                    beat = phase + 0.13 * math.sin(phase * 0.63)
                    x = x0 + (x1 - x0) * travel
                    bob = 5.5 * speed * math.cos(beat * 2)
                    roll = direction * speed * 0.024 + 0.025 * speed * math.sin(beat)
                    swing = direction * 0.20 * speed * math.sin(beat)
                    shoulder = 3.2 * speed * math.sin(beat)
                    turn = direction * 17 * min(1.0, (1 - t) / 0.22)
                    width = 1 - 0.085 * min(1.0, (1 - t) / 0.25)
                break
            if f < f1 + 16:
                settle = (f - f1) / 16
                roll = direction * 0.017 * math.sin(math.pi * settle) * (1 - settle)
                bob = 2.0 * math.sin(math.pi * settle) * (1 - settle)
        return x, bob, roll, swing, turn, width, shoulder

    channels: list[list] = [[] for _ in range(10)]
    samples = sorted(set(range(0, frames, 2)) | {frames} |
                     {f for f0, f1, _, _ in moves for f in (f0, f0 + 10, f1)})
    for f in samples:
        x, bob, roll, swing, turn, width, shoulder = pose(f)
        _, prior_bob, prior_roll, _, _, _, _ = pose(max(0, f - 3))
        settle_weight = min(1.0, (frames - f) / 4)
        values = (x, 1000 + bob, roll, swing, turn, width, shoulder,
                  (-0.45 * prior_bob) * settle_weight,
                  (-0.42 * prior_roll) * settle_weight, -swing)
        for keys, value in zip(channels, values):
            keys.append((f, value, "linear"))
    xs, ys, lean, sw_r, turns, widths, shoulders, head_y, head_roll, sw_l = channels
    return [T(root, x=xs, y=ys, scaleX=widths), T(body, rotation=lean),
            T(swing_r, rotation=sw_r, y=[(f, -280 + v, mode) for f, v, mode in shoulders]),
            T(swing_l, rotation=sw_l, y=[(f, -280 - v, mode) for f, v, mode in shoulders]),
            T(head_travel, y=head_y, rotation=head_roll), *[T(part, x=turns) for part in travel_parts]]


def still() -> list[El]:
    return [K(swing_r, rotation=0.0, y=-280.0), K(swing_l, rotation=0.0, y=-280.0),
            K(head_travel, y=0.0, rotation=0.0), K(body, rotation=0.0),
            K(root, scaleX=1.0), *[K(part, x=0.0) for part in travel_parts]]


P_ON = A("presence_onScreen", 1, [K(root, x=ON_X, y=1000.0), *still()])
P_OFF = A("presence_outOfScreen", 1, [K(root, x=OFF_X, y=1000.0), *still()])
P_WALK_OUT = A("presence_walkOut", 96, walk_tracks(96, [(0, 80, ON_X, OFF_X)]))
P_WALK_IN = A("presence_walkIn", 96, walk_tracks(96, [(0, 80, OFF_X, ON_X)]))
P_LEAVE = A("presence_leaveAndComeBack", 216, walk_tracks(216, [(0, 80, ON_X, OFF_X), (120, 200, OFF_X, ON_X)]))

# ================================================================ EVENTS + STATE MACHINE


def event(name: str, prop: str, value: str) -> El:
    return d("Event", d("CustomPropertyString", propertyValue=value, name=prop), name=name)


EV_GESTURE = {g: event("gesture_done", "gestureId", g) for g in G}
EV_TAP = {z: event("avatar_tapped", "zone", z) for z in ("head", "body")}
EV_PRESENCE = {p: event("presence_done", "presence", p) for p in ("onScreen", "outOfScreen", "leaveAndComeBack")}


def layer(name: str, entry: El | list[El], states: list[El], any_t: list[El] | None = None) -> El:
    entry_ts = [d("StateTransition", stateToId=entry.ref())] if isinstance(entry, El) else entry
    return d("StateMachineLayer",
             d("AnyState", *(any_t or []), x=100.0, y=-100.0),
             d("ExitState", x=500.0, y=-100.0),
             d("EntryState", *entry_ts, x=-100.0, y=-100.0),
             *states, name=name)


def st(a: El, i: int, *kids: El, row: int = 0) -> El:
    return d("AnimationState", *kids, animationId=a.ref(), x=float(160 * i), y=float(100 + 120 * row))


def enum_layer(name: str, pn: str, anims_: dict[str, El], default: str, blend_ms: int = 0) -> El:
    states = {k: st(a, i, row=i % 2) for i, (k, a) in enumerate(anims_.items())}
    return layer(name, states[default], list(states.values()),
                 [d("StateTransition", enum_is(pn, k), stateToId=s_.ref(), duration=blend_ms or None)
                  for k, s_ in states.items()])


layers: list[El] = []
s0 = st(breath, 0)
layers.append(layer("Breath", s0, [s0]))
s0 = st(wardrobe_life, 0)
layers.append(layer("WardrobeLife", s0, [s0]))
s0 = st(cape_ripple, 0)
layers.append(layer("CapeRipple", s0, [s0]))


def auto_blink(on: bool) -> El:
    return d("TransitionViewModelCondition",
             d("TransitionPropertyViewModelComparator",
               d("BindablePropertyBoolean", d("DataBindContext", sourcePathIds=vpath("autoBlink"), propertyKey=634))),
             d("TransitionValueBooleanComparator", value=on))


b_auto, b_hold, b_once = st(blink, 0), st(blink_hold, 1), st(blink_once, 2, row=1)
b_auto.add(d("StateTransition", auto_blink(False), stateToId=b_hold.ref()))
b_hold.add(d("StateTransition", auto_blink(True), stateToId=b_auto.ref()))
b_once.add(d("StateTransition", auto_blink(True), stateToId=b_auto.ref(), enableExitTime=True,
             exitTimeIsPercetange=True, exitTime=100),
           d("StateTransition", auto_blink(False), stateToId=b_hold.ref(), enableExitTime=True,
             exitTimeIsPercetange=True, exitTime=100))
layers.append(layer("Blink", b_auto, [b_auto, b_hold, b_once],
                    [d("StateTransition", trig("blink"), stateToId=b_once.ref())]))
layers.append(enum_layer("Mood", "mood", MOODS, "neutral", 240))
layers.append(enum_layer("Phase", "phase", PHASES, "idle", 250))

gs_idle = st(g_none, 0)
g_states = []
for i, (gn, ga) in enumerate(G.items()):
    gst = st(ga, i + 1,
             d("StateMachineFireEvent", eventId=EV_GESTURE[gn].ref(), occursValue="atEnd"),
             d("StateTransition", stateToId=gs_idle.ref(), enableExitTime=True, exitTimeIsPercetange=True, exitTime=100),
             row=1)
    gs_idle.add(d("StateTransition", trig("gesture"), enum_is("gestureId", gn), stateToId=gst.ref()))
    g_states.append(gst)
layers.append(layer("Gesture", gs_idle, [gs_idle, *g_states]))

layers.append(enum_layer("Hat", "hat", HAT_ANIMS, "noHat"))
layers.append(enum_layer("Top", "top", TOP_ANIMS, "pinkHoodie"))
layers.append(enum_layer("Glasses", "glasses", GLASS_ANIMS, "glasses"))
layers.append(enum_layer("Costume", "costume", COSTUME_ANIMS, "none"))

# presence graph (no AnyState: leaveAndComeBack must not retrigger itself)
ps_on = st(P_ON, 0)
ps_off = st(P_OFF, 1)
ps_wout = st(P_WALK_OUT, 2, row=1)
ps_win = st(P_WALK_IN, 3, row=1)
ps_leave = st(P_LEAVE, 4, row=1)
ps_back = st(P_ON, 5)            # "returned" — on screen, waiting for presence to change


def go(to: El, *conds: El, ms: int = 0) -> El:
    return d("StateTransition", *conds, stateToId=to.ref(), duration=ms or None)


def after(to: El, ev: El) -> list[El]:
    return [d("StateMachineFireEvent", eventId=ev.ref(), occursValue="atEnd"),
            d("StateTransition", stateToId=to.ref(), enableExitTime=True, exitTimeIsPercetange=True, exitTime=100)]


ps_on.add(go(ps_wout, enum_is("presence", "outOfScreen")), go(ps_leave, enum_is("presence", "leaveAndComeBack")))
ps_off.add(go(ps_win, enum_is("presence", "onScreen")), go(ps_leave_in := st(P_WALK_IN, 6, row=2),
                                                          enum_is("presence", "leaveAndComeBack")))
ps_wout.add(*after(ps_off, EV_PRESENCE["outOfScreen"]))
ps_win.add(*after(ps_on, EV_PRESENCE["onScreen"]))
ps_leave.add(*after(ps_back, EV_PRESENCE["leaveAndComeBack"]))
ps_leave_in.add(*after(ps_back, EV_PRESENCE["leaveAndComeBack"]))
ps_back.add(go(ps_wout, enum_is("presence", "outOfScreen")), go(ps_on, enum_is("presence", "onScreen")))
layers.append(layer("Presence",
                    [go(ps_off, enum_is("presence", "outOfScreen")), go(ps_on)],
                    [ps_on, ps_off, ps_wout, ps_win, ps_leave, ps_back, ps_leave_in]))

# eye-follow + tap listeners
look_handle = d("Node", x=400.0, y=420.0, name="LookHandle")
hit_all = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
            F("00000000"), name="HitArea")
listeners = [d("StateMachineListenerSingle", d("ListenerAlignTarget", targetId=look_handle.ref()),
               targetId=hit_all.ref(), listenerTypeValue=lt, name="Look" + lt.title()) for lt in ("move", "down", "drag")]
listeners += [d("StateMachineListenerSingle", d("ListenerFireEvent", eventId=EV_TAP[z].ref()), targetId=h.ref(),
                listenerTypeValue="click", name="Tap" + z.title()) for z, h in (("head", hit_head), ("body", hit_body))]
sm = d("StateMachine", *listeners, *layers, name="Main")
joy = d("Joystick", posX=400.0, posY=420.0, width=900.0, height=700.0, xId=look_x.ref(), yId=look_y.ref(),
        handleSourceId=look_handle.ref(), name="Look")

style = d("LayoutComponentStyle", name="Artboard Style")
artboard = d("Artboard", style, sm, EASE, EASE_OUT, EASE_IN, *EV_GESTURE.values(), *EV_TAP.values(), *EV_PRESENCE.values(), joy,
             look_handle, root.el, hit_all, *anims,
             width=float(W), height=float(H), name="Avatar", defaultStateMachineId=sm.ref(), viewModelId=vm.ref(),
             viewModelInstanceId=inst.ref(), styleId=style.ref(), clip=True)

# ================================================================ FACE (contract v5 action units)
# Runs before the head turn so the turn wrappers enclose the face rig. Own id range (face_rig.py).
face_au = face_rig.FaceRig(lids.path)  # the same paths as the lids (v6 side numbers included)
for i, e in enumerate(EYES):
    s_ = -1 if i == 0 else 1
    face_rig.rig_brow(face_au, e["brow_g"].el, named_el(e["brow_g"].el, "BrowShape"), 355.0 if i == 0 else 445.0, s_,
                      HAIR, SKIN)
face_rig.rig_mouth(face_au, mouth_mood, {"inside": "FF5A2630", "throat": "FF4A1E28", "teeth": TEETH,
                                      "low_teeth": "FFF1E6E0", "tongue": "FFD9737A", "ink": INK, "lip": "60D0937C",
                                      "crease": "A0D0937C"})
face_rig.rig_nose(face_au, nose_g.el, (nose_g.ax, nose_g.ay), {"crease": "E0B8786A"})
face_rig.rig_cheeks(face_au, head.el, skin_details[:2])
face_rig.rig_body(face_au, root.el, body.el, body_g.el, head_base.el, (0.0, 610.0 - 1000.0))

# ================================================================ HEAD TURN (yaw / pitch)
# The head art above follows AvatarVM `yaw` / `pitch` on one surface model (rive/tools/head_turn.py):
# features, glasses, ears and hair ride pivot wrappers, the face outline is skinned. New elements
# take their own id range, so every id above (and every keyed reference) is unchanged.
turn = HeadTurn(vm, inst, head.el, root.el)
rig_head(turn, face_pts, FACE_CAST_PTS, CHEEK_SH_PTS, [(f"Lock{i}Material", LOCKS[i]) for i in range(len(LOCKS))],
         {"Face": face, "FaceCast": face_cast, "CheekShade": cheek_sh, "EyeL": EYE_L["eye"].el, "EyeR": EYE_R["eye"].el,
          "BrowL": EYE_L["brow"].el, "BrowR": EYE_R["brow"].el, "NoseTurn": nose_g.el, "Mouth": mouth.el, "Mole": mole,
          "Blush": blush.el, "CheekBloomL": skin_details[0], "CheekBloomR": skin_details[1],
          "ChinLight": skin_details[2], "EarL": ears[0], "EarR": ears[1], "EarInL": ears[2], "EarInR": ears[3],
          "glassesByName": GLASSES, "GlassesSolo": glasses_solo.el, "HairFollow": hair_follow,
          "LookL": EYE_L["look"].el, "LookR": EYE_R["look"].el,
          "HairCap": named_el(hair_front.el, "HairCap"),
          "SideLockL": named_el(hair_front.el, "SideLockL"), "SideLockR": named_el(hair_front.el, "SideLockR"),
          "HairBackShape": named_el(hair_back.el, "HairBackShape"), "Cowlick": named_el(tufts.el, "Cowlick"),
          "Cowlick2": named_el(tufts.el, "Cowlick2"), "HatSolo": hat_solo.el,
          **{f"Lock{i}Material": named_el(hair_front.el, f"Lock{i}Material") for i in range(len(LOCKS))}}, anims)

out = os.path.join(os.path.dirname(__file__), "..", "avatar", "avatar.rml")
os.makedirs(os.path.dirname(out), exist_ok=True)
# the lids read eyeLeadPitch (contract: looking down drops the upper lids), which the head turn adds
face_rig.resolve_paths([artboard, *face_au.converters, *lids.converters], {"eyeLeadPitch": turn.path("eyeLeadPitch")})
write(out, [artboard, *enums.values(), vm, *face_au.converters, *lids.converters, *turn.converters])
print("wrote", os.path.normpath(out), "next id", d.next)
