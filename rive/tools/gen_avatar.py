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
                        TEETH, TONGUE, WHITE, E, F, L, R, Rig, S, clip_only, d, grad, group, hgrad, ik, mirror,
                        rgrad, vgrad)
from rml import El, lin, rad, smooth_path, track, write  # noqa: E402

W, H = 800, 1000
rnd = random.Random(42)

EASE = d("CubicEaseInterpolator", x1=0.42, y1=0.0, x2=0.58, y2=1.0)

# ================================================================ RIG
root = Rig("Root", 400, 1000)              # presence walks this
body = root.node("Body", 400, 1000)        # breathing
body_g = body.node("BodyGesture")          # gesture bounce/shrug
arm_r = body_g.node("ArmR", 240, 720)      # character's right = viewer's left
arm_l = body_g.node("ArmL", 560, 720)
head_base = body_g.node("HeadBase", 400, 560, scaleX=1.18, scaleY=1.18)
head_mood = head_base.node("HeadMood")
head_phase = head_mood.node("HeadPhase")
head_look = head_phase.node("HeadLook")
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


ARM_UP = [(226, 682), (264, 700), (290, 760), (294, 880), (298, 1070, "c"), (192, 1070, "c"), (192, 900), (198, 760)]
ARM_FORE = [(198, 1010), (282, 1010), (278, 1200), (276, 1330, "c"), (204, 1330, "c"), (202, 1200)]
BARE_UP = [(230, 690), (262, 704), (278, 760), (280, 900), (282, 1070, "c"), (206, 1070, "c"), (206, 900), (210, 760)]
BARE_FORE = [(210, 1010), (272, 1010), (268, 1200), (264, 1342, "c"), (216, 1342, "c"), (214, 1200)]
STAR_FX: list[El] = []        # singularity specks that twinkle


def build_sleeves(rig: Rig, elbow: Rig, side: int) -> tuple[Rig, Rig, dict[str, El], dict[str, El]]:
    m = (lambda p: mirror(p)) if side == 1 else (lambda p: p)
    mx = (lambda x: 800 - x) if side == 1 else (lambda x: x)
    up_solo = rig.solo("UpperSleeve")
    fore_solo = elbow.solo("ForeSleeve")
    ups: dict[str, El] = {}
    fores: dict[str, El] = {}
    for oid in OUTFITS:
        base, shade, ink, cuff, kind = SLEEVES[oid]
        gu = group("Up_" + oid)
        gf = group("Fore_" + oid)
        sleeve_fill = d("Fill", lin(d, -50, 0, 50, 0, [(shade, 0.0), (base, 0.55)]), name="Fill")
        fore_fill = d("Fill", lin(d, -42, 0, 42, 0, [(shade, 0.0), (base, 0.6)]), name="Fill")
        skin_up = S(rig, "SkinUp", m(BARE_UP), hgrad(-40, 40, SKIN_SH, SKIN), L(INK, 2.6))
        skin_fore = S(elbow, "SkinFore", m(BARE_FORE), hgrad(-30, 30, SKIN_SH, SKIN), L(INK, 2.6))
        if kind == "bare":
            gu.add(S(rig, "Deltoid", m([(232, 700), (250, 720), (244, 780)]), L(SKIN_SH2, 2), closed=False), skin_up)
            gf.add(skin_fore)
        elif kind == "short":
            trim = S(rig, "Trim", m([(196, 846), (300, 846), (302, 866, "c"), (194, 866, "c")]), F(cuff or base),
                     L(ink, 2.5))
            gu.add(trim, S(rig, "TeeSleeve", m([(226, 682), (266, 700), (296, 760), (302, 856, "c"), (194, 856, "c"),
                                                (198, 760)]), sleeve_fill, L(ink, 3)), skin_up)
            gf.add(skin_fore)
        elif kind == "stars":
            gu.add(*starfield(rig, m(ARM_UP), 8, 11 + side, "Up"),
                   S(rig, "Sleeve", m(ARM_UP), grad([("FF181A48", 0.0), (base, 1.0)], -200, 200), L(ink, 3)))
            fs = starfield(elbow, m(ARM_FORE), 6, 21 + side, "Fore")
            STAR_FX.extend(fs[:2])
            gf.add(*fs, S(elbow, "Sleeve", m(ARM_FORE), grad([("FF181A48", 0.0), (base, 1.0)], -160, 160), L(ink, 3)))
        else:
            folds = [S(rig, "Fold", m([(214, 820), (236, 860), (226, 940), (220, 900)]), F(shade)),
                     S(rig, "Fold2", m([(262, 900), (276, 950), (270, 1020), (264, 960)]), F(shade))]
            extra_up: list[El] = []
            if kind == "puff":
                extra_up.append(S(rig, "Puff", m([(212, 676), (262, 680), (304, 730), (300, 800), (250, 812),
                                                   (190, 790), (186, 724)]), rgrad(70, [("FF3A3440", 0.0), (base, 1.0)]),
                                  L(ink, 3)))
            if kind == "armor":
                extra_up += [S(rig, "Pauldron", m([(204, 676), (262, 676), (306, 720), (304, 790), (190, 790),
                                                    (186, 720)]), rgrad(80, [("FFE6EEFF", 0.0), (base, 0.5), (shade, 1.0)],
                                                                         cx=-20, cy=-30), L(ink, 3)),
                             S(rig, "Seam", m([(196, 900), (292, 900)]), L(ink, 3), closed=False)]
            if oid == "christmasSweater":
                extra_up += [S(rig, "Band", m([(194, 930), (296, 930), (297, 980), (193, 980)]), F("FFC8303A"),
                               L(ink, 2)),
                             *[S(rig, f"Zig{i}", m([(198 + i * 20, 955), (208 + i * 20, 943), (218 + i * 20, 955)]),
                                 L(WHITE, 3), closed=False) for i in range(5)]]
            gu.add(*extra_up, *folds, S(rig, "Sleeve", m(ARM_UP), sleeve_fill, L(ink, 3)))
            fore_extra: list[El] = []
            if cuff is not None:
                if kind == "glove":
                    fore_extra += [S(elbow, f"Fin{i}", m([(198, 1180 + i * 40), (176, 1196 + i * 40, "c"),
                                                           (200, 1210 + i * 40)]), F(cuff), L(ink, 2)) for i in range(3)]
                    fore_extra.append(S(elbow, "Glove", m([(200, 1150), (280, 1150), (277, 1340, "c"), (203, 1340, "c")]),
                                        F(cuff), L(ink, 2.5)))
                else:
                    ribs = [S(elbow, f"Rib{i}", [(mx(214 + i * 13), 1306), (mx(214 + i * 13), 1350)], L(shade, 2),
                              closed=False) for i in range(5)] if oid == "pinkHoodie" else []
                    fore_extra += ribs + [S(elbow, "Cuff", m([(204, 1300), (276, 1300), (274, 1356, "c6"),
                                                              (206, 1356, "c6")]), F(cuff), L(ink, 2.5))]
            gf.add(*fore_extra, S(elbow, "Sleeve", m(ARM_FORE), fore_fill, L(ink, 3)))
        up_solo.add(gu)
        fore_solo.add(gf)
        ups[oid] = gu
        fores[oid] = gf
    up_solo.el.attrs["activeComponentId"] = ups["pinkHoodie"].ref()
    fore_solo.el.attrs["activeComponentId"] = fores["pinkHoodie"].ref()
    return up_solo, fore_solo, ups, fores


def build_arm(rig: Rig, side: int) -> dict:
    m = (lambda p: mirror(p)) if side == 1 else (lambda p: p)
    mx = (lambda x: 800 - x) if side == 1 else (lambda x: x)
    elbow = rig.node("Elbow", mx(240), 1030)
    hand = elbow.node("Hand", mx(240), 1350)
    hand_wave = hand.node("HandWave")
    hp = [(208, 1350), (272, 1350), (282, 1390), (278, 1430), (240, 1442), (204, 1430), (198, 1390)]
    fingers = []
    for i, (fx, ln) in enumerate([(210, 62), (229, 72), (249, 70), (268, 58)]):
        fx2 = mx(fx)
        fingers.append(S(hand_wave, f"Finger{i}", [(fx2 - 9.5, 1416), (fx2 + 9.5, 1416), (fx2 + 9, 1416 + ln - 9),
                                                     (fx2, 1416 + ln), (fx2 - 9, 1416 + ln - 9)], F(SKIN), L(INK, 2.5)))
    thumb = S(hand_wave, "Thumb", m([(270, 1372), (296, 1390), (310, 1420), (302, 1432), (282, 1418), (268, 1400)]),
              F(SKIN), L(INK, 2.5))
    palm = S(hand_wave, "Palm", m(hp), F(SKIN), L(INK, 2.5))
    palm_sh = S(hand_wave, "PalmShade", m([(206, 1352), (274, 1352), (276, 1374), (240, 1382), (204, 1374)]), F(SKIN_SH))
    crease = S(hand_wave, "PalmCrease", m([(214, 1404), (240, 1396), (262, 1408)]), L(SKIN_SH2, 2), closed=False)
    hand_wave.add(palm_sh, crease, *fingers, thumb, palm)
    up_solo, fore_solo, ups, fores = build_sleeves(rig, elbow, side)
    # front-most first: hand > forearm sleeve > upper sleeve
    elbow.el.children = [hand.el, fore_solo.el]
    rig.el.children = [elbow.el, up_solo.el]
    return {"arm": rig, "elbow": elbow, "hand": hand, "wave": hand_wave, "up_solo": up_solo,
            "fore_solo": fore_solo, "ups": ups, "fores": fores}


ARM_R = build_arm(arm_r, -1)
ARM_L = build_arm(arm_l, 1)
ARMS = [ARM_R, ARM_L]

# ================================================================ TORSO / TOPS
TORSO = [(365, 596), (400, 606), (435, 596), (520, 640), (576, 684), (600, 760), (610, 1010, "c"), (190, 1010, "c"),
         (200, 760), (224, 684), (280, 640)]
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
    return group(name + "Group", tip, cord_in, cord)


band = [(278, 616), (318, 598), (356, 610), (390, 650), (408, 706, "c"), (388, 708), (360, 668), (324, 636), (290, 634)]
TF["pinkHoodie"] = group("F_pinkHoodie", hood_string(360, 352, "StringL"), hood_string(440, 452, "StringR"),
                         S(body_g, "CollarL", band, vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3)),
                         S(body_g, "CollarR", mirror(band), vgrad(596, 708, HOOD, HOOD_SH), L(HOOD_INK, 3)))
TB["pinkHoodie"] = group("B_pinkHoodie",
                         S(body_g, "ChestShade", [(300, 700), (340, 760), (330, 860), (300, 1000, "c"), (286, 1000, "c"),
                                                  (296, 860)], F(HOOD_SH)),
                         S(body_g, "Fold1", [(352, 880), (366, 930), (360, 1000), (352, 1000), (356, 930)], F(HOOD_SH2)),
                         S(body_g, "Fold2", [(470, 830), (458, 900), (466, 1000), (474, 1000), (466, 900)], F(HOOD_SH2)),
                         S(body_g, "Pocket", [(300, 960), (500, 960)], L(HOOD_SH2, 3), closed=False),
                         S(body_g, "HoodBack", [(282, 610), (300, 546), (350, 514), (400, 508), (450, 514), (500, 546),
                                                (518, 610), (470, 604), (400, 598), (330, 604)],
                           grad([(HOOD_SH, 0.0), (HOOD_SH2, 1.0)], -40, 40), L(HOOD_INK, 3)),
                         torso(vgrad(600, 1000, HOOD, HOOD_SH), HOOD_INK))

# -- longCoat: trench over a white shirt
COAT, COAT_SH, COAT_INK = "FFD9C7A3", "FFB49E78", "FF6A5838"
TF["longCoat"] = group("F_longCoat", *collar_points())
TB["longCoat"] = group("B_longCoat", *lapels(COAT, COAT_SH, COAT_INK),
                       *[E(body_g, f"Button{i}", 400, 800 + i * 70, 10, 10, F("FFEDEEF2"), L("FF8A8C98", 1.5))
                         for i in range(3)],
                       shirt_v(depth=1010),
                       S(body_g, "CoatCollar", [(300, 600), (330, 560), (400, 550), (470, 560), (500, 600), (470, 612),
                                                (400, 604), (330, 612)], F(COAT_SH), L(COAT_INK, 3)),
                       S(body_g, "Belt", [(196, 940), (380, 950), (380, 976), (196, 966)], F(COAT_SH), L(COAT_INK, 2)),
                       S(body_g, "Belt2", mirror([(196, 940), (380, 950), (380, 976), (196, 966)]), F(COAT_SH),
                         L(COAT_INK, 2)),
                       S(body_g, "CoatFold", [(270, 760), (290, 860), (280, 1000), (272, 1000), (280, 860)], F(COAT_SH)),
                       torso(vgrad(600, 1000, COAT, COAT_SH), COAT_INK))

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
TANK = [(300, 650), (330, 720), (400, 740), (470, 720), (500, 650), (540, 700), (560, 1010, "c"), (240, 1010, "c"),
        (260, 700)]
TF["underwear"] = group("F_underwear")
TB["underwear"] = group("B_underwear",
                        S(body_g, "Strap", [(286, 640), (306, 640), (296, 720), (276, 716)], F("FFF6F6F8"), L("FF9A9AA8", 2)),
                        S(body_g, "Strap2", mirror([(286, 640), (306, 640), (296, 720), (276, 716)]), F("FFF6F6F8"),
                          L("FF9A9AA8", 2)),
                        S(body_g, "Tank", TANK, vgrad(650, 1000, "FFFFFFFF", "FFDCDCE6"), L("FF9A9AA8", 2.5)),
                        *collarbones(),
                        torso(vgrad(600, 1000, SKIN, SKIN_SH), INK, "SkinTorso"))

# -- swimsuit: bare chest + a striped towel round the neck
towel = [(330, 596), (360, 640), (372, 760), (360, 900), (318, 900, "c"), (316, 760), (300, 660)]
stripe = [(318, 820), (368, 820), (366, 846), (318, 846)]
TF["swimsuit"] = group("F_swimsuit",
                       S(body_g, "TowelStripeL", stripe, F("FF2A9FB0")),
                       S(body_g, "TowelStripeR", mirror(stripe), F("FF2A9FB0")),
                       S(body_g, "TowelL", towel, vgrad(600, 900, "FFFFFFFF", "FFD8E6EA"), L("FF6A8A92", 2.5)),
                       S(body_g, "TowelR", mirror(towel), vgrad(600, 900, "FFFFFFFF", "FFD8E6EA"), L("FF6A8A92", 2.5)),
                       S(body_g, "TowelBack", [(320, 600), (400, 580), (480, 600), (470, 620), (400, 604), (330, 620)],
                         F("FFE4EEF0"), L("FF6A8A92", 2)))
TB["swimsuit"] = group("B_swimsuit",
                       S(body_g, "Pec", [(320, 780), (380, 800)], L(SKIN_SH2, 2.5), closed=False),
                       S(body_g, "Pec2", mirror([(320, 780), (380, 800)]), L(SKIN_SH2, 2.5), closed=False),
                       S(body_g, "Abs", [(400, 820), (400, 960)], L(SKIN_SH, 2.5), closed=False),
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
TB["christmasSweater"] = group("B_christmasSweater",
                               *flakes,
                               *[S(body_g, f"Zig{i}", [(200 + i * 30, 832), (215 + i * 30, 812), (230 + i * 30, 832)],
                                   L("FFF4F4F4", 4), closed=False) for i in range(14)],
                               *[E(body_g, f"Dot{i}", 214 + i * 30, 858, 8, 8, F("FFF4F4F4")) for i in range(14)],
                               S(body_g, "RedBand", [(196, 796), (604, 796), (606, 874), (194, 874)], F(SW_RED),
                                 L(SW_INK, 2.5)),
                               torso(vgrad(600, 1000, SW, SW_SH), SW_INK))

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
TB["batman"] = group("B_batman",
                     S(body_g, "Bat", [(p[0], p[1]) for p in bat_emblem], F("FF0E0F12")),
                     E(body_g, "EmblemOval", 400, 768, 140, 62, vgrad(-30, 30, "FFFFE066", "FFE0A820"), L(BAT_INK, 3)),
                     S(body_g, "PecL", [(300, 720), (360, 740), (392, 720)], L(BAT_SH, 3), closed=False),
                     S(body_g, "PecR", mirror([(300, 720), (360, 740), (392, 720)]), L(BAT_SH, 3), closed=False),
                     S(body_g, "BeltGold", [(196, 990), (604, 990), (606, 1012), (194, 1012)], F("FFE0A820")),
                     torso(vgrad(600, 1000, BAT, BAT_SH), BAT_INK))
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
SING = [(196, 1010), (200, 760), (224, 684), (300, 630), (360, 596), (440, 596), (500, 630), (576, 684), (600, 760),
        (604, 1010)]
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
face = S(head, "Face", face_pts, vgrad(260, 520, SKIN, "FFF3C9AF"), L(INK, 3.2))
face_cast = S(head, "FaceCast", [(298, 300), (330, 330), (370, 336), (400, 330), (440, 340), (480, 332), (502, 300),
                                 (504, 352), (490, 360), (470, 352), (440, 362), (400, 356), (360, 362), (320, 356),
                                 (300, 366)], F(SKIN_SH))
cheek_sh = S(head, "CheekShade", [(502, 360), (498, 410), (484, 452), (452, 490), (424, 509), (446, 484), (474, 446),
                                  (488, 404)], F(SKIN_SH))
EAR = [(300, 372), (282, 360), (272, 380), (278, 412), (292, 436), (304, 430)]
ears = [S(head, "EarL", EAR, F(SKIN), L(INK, 3)), S(head, "EarR", mirror(EAR), F(SKIN), L(INK, 3)),
        S(head, "EarInL", [(296, 384), (286, 378), (284, 396), (292, 414)], L(SKIN_SH2, 3), closed=False),
        S(head, "EarInR", mirror([(296, 384), (286, 378), (284, 396), (292, 414)]), L(SKIN_SH2, 3), closed=False)]
nose = S(head, "Nose", [(406, 446), (400, 454), (392, 452)], L(SKIN_SH2, 3), closed=False)
nose_sh = S(head, "NoseShade", [(404, 408), (410, 440), (406, 450), (402, 430)], F(SKIN_SH))
mole = E(head, "Mole", 456, 432, 5, 5, F("FF5A3A32"))

# ---- eyes: Eye > [Droop, Squint, EyeMood > Blink > GazeM > GazeP > GazeG > Look(joystick)]
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
             E(look, "Pupil", cx, 389, 14, 17, F("FF1E120C"), clip=clip_src),
             E(look, "IrisRing", cx, 388, 32, 36, L("FF2B1A12", 2.2), clip=clip_src),
             E(look, "Iris", cx, 388, 32, 36, d("Fill", rad(d, 0, 8, 22, [(IRIS_A, 0.0), (IRIS_B, 1.0)]), name="Fill"),
               clip=clip_src))
    white = S(blink, "White", white_pts, F(SCLERA))
    upper = S(blink, "Lash", [(i - 3 * s, 393), (cx - 15 * s, 368), (cx + 6 * s, 363), (o - 2 * s, 369),
                              (o + 9 * s, 384, "c"), (o + 1 * s, 381), (cx + 6 * s, 373), (cx - 14 * s, 377),
                              (i + 2 * s, 394, "c")], F("FF2A1B18"))
    crease = S(blink, "Crease", [(cx - 12 * s, 360), (cx + 8 * s, 356), (o + 2 * s, 364)], L(SKIN_SH2, 2), closed=False)
    lower = S(blink, "LowerLid", [(i + 6 * s, 403), (cx - 8 * s, 406), (cx + 14 * s, 402)], L("B03A2622", 2),
              closed=False)
    blink.el.children = [upper, lower, crease, gaze_m.el, white, clip_src]
    # mood lids: Droop comes down from the top (sad/angry), Squint rises from below (happy)
    droop = eye.node("Droop", cx, 360, scaleY=0.0)
    droop.add(S(droop, "DroopLash", [(i - 6 * s, 392), (cx, 394), (o + 8 * s, 390)], L("FF2A1B18", 4.5), closed=False),
              S(droop, "DroopLid", [(i - 8 * s, 352, "c"), (o + 10 * s, 352, "c"), (o + 10 * s, 392), (cx, 396),
                                    (i - 8 * s, 393)], F(SKIN)))
    squint = S(eye, "Squint", [(i - 6 * s, 404), (cx, 386), (o + 6 * s, 400), (o + 8 * s, 420, "c"),
                               (i - 8 * s, 420, "c")], F(SKIN), origin=(cx, 412), scaleY=0.0)
    squint_line = S(eye, "SquintLine", [(i - 2 * s, 402), (cx, 389), (o + 2 * s, 399)], L(INK, 2.2), closed=False,
                    origin=(cx, 412), scaleY=0.0)
    eye.el.children = [squint_line, squint, droop.el, eye_mood.el]
    brow = eyes.node("Brow" + tag, cx, 346)
    brow_g = brow.node("BrowG")
    brow_g.add(S(brow_g, "BrowShape", [(cx - 30 * s, 342, "c"), (cx - 8 * s, 335), (cx + 16 * s, 335),
                                       (cx + 36 * s, 344, "c"), (cx + 16 * s, 341), (cx - 8 * s, 341)], F(HAIR)))
    return {"eye": eye, "mood": eye_mood, "blink": blink, "gm": gaze_m, "gp": gaze_p, "gg": gaze_g, "look": look,
            "squint": squint, "squint_line": squint_line, "droop": droop, "brow": brow, "brow_g": brow_g}


EYE_L = build_eye(355, -1)
EYE_R = build_eye(445, 1)
EYES = [EYE_L, EYE_R]
eyes.el.children.sort(key=lambda c: 0 if c.attrs.get("name", "").startswith("Brow") else 1)

blush = head.node("Blush", 400, 440, opacity=0.0)
blush.add(*[E(blush, "Blush" + t, x, 438, 54, 20, rgrad(27, [("B0F08F86", 0.0), ("00F08F86", 1.0)]))
            for t, x in (("L", 338), ("R", 462))],
          *[S(blush, f"BlushLine{t}{k}", [(x - 12 + k * 9, 446), (x - 6 + k * 9, 432)], L("90E07070", 2), closed=False)
            for t, x in (("L", 338), ("R", 462)) for k in range(3)])

# ---- mouth: closed lines (mood) / opening (mouth blend)
mouth = head.node("Mouth", 400, 478)
lines = mouth.node("Lines")
LINES = {
    "neutral": S(mouth, "LineNeutral", [(382, 479), (400, 477), (418, 479)], L(INK, 3), closed=False),
    "smile": S(mouth, "LineSmile", [(378, 472), (390, 482), (400, 484), (410, 482), (422, 472)], L(INK, 3), closed=False),
    "frown": S(mouth, "LineFrown", [(380, 486), (390, 479), (400, 477), (410, 479), (420, 486)], L(INK, 3), closed=False),
    "tight": S(mouth, "LineTight", [(386, 482), (400, 479), (414, 482)], L(INK, 4), closed=False),
    "o": E(mouth, "LineO", 400, 482, 14, 17, F(MOUTH_IN), L(INK, 3)),
    "side": S(mouth, "LineSide", [(384, 482), (400, 481), (412, 478), (420, 472)], L(INK, 3), closed=False),
    "wavy": S(mouth, "LineWavy", [(380, 481), (388, 476), (396, 482), (404, 476), (412, 482), (420, 477)], L(INK, 2.8),
              closed=False),
}
lines.add(*LINES.values())
for k, v in LINES.items():
    v.attrs["opacity"] = 1.0 if k == "neutral" else 0.0
open_ = mouth.node("Open", 400, 474, scaleY=0.0, opacity=0.0)
open_mood = open_.node("OpenMood")
mo_pts = [(374, 472), (400, 470), (426, 472), (420, 492), (400, 504), (380, 492)]
teeth_src = clip_only(S(open_mood, "InsideClip", mo_pts))
open_mood.add(S(open_mood, "Teeth", [(372, 466), (428, 466), (426, 478), (400, 480), (374, 478)], F(TEETH), clip=teeth_src),
              E(open_mood, "Tongue", 400, 502, 34, 18, F(TONGUE), clip=teeth_src),
              S(open_mood, "Inside", mo_pts, F(MOUTH_IN), L(INK, 2.6)), teeth_src)

# ---- mood / phase / gesture overlays on the face
sweat_m = head.node("SweatMood", 300, 330, opacity=0.0)
SWEAT = [(0, -26), (8, -6), (10, 6), (0, 14), (-10, 6), (-8, -6)]
sweat_m.add(S(sweat_m, "Drop", [(300 + x, 330 + y) for x, y in SWEAT], vgrad(-20, 14, "FFE6F6FF", "FF8CC8F0"),
              L("FF3A7AB0", 2.5)))
anger = head.node("AngerMark", 490, 270, opacity=0.0)
for k in range(4):
    a = k * PI / 2 + PI / 4
    p0 = (490 + 17 * math.cos(a - 0.5), 270 + 17 * math.sin(a - 0.5))
    p1 = (490 + 8 * math.cos(a), 270 + 8 * math.sin(a))
    p2 = (490 + 17 * math.cos(a + 0.5), 270 + 17 * math.sin(a + 0.5))
    anger.add(S(anger, f"Vein{k}", [p0, p1, p2], L("FFE0303A", 4.5), closed=False))
laugh = head.node("LaughFace", 400, 420, opacity=0.0)
laugh.add(*[S(laugh, f"LaughEye{t}", [(x - 22, 396), (x, 376), (x + 22, 396)], L("FF2A1B18", 5), closed=False)
            for t, x in (("L", 355), ("R", 445))],
          *[E(laugh, f"LaughPatch{t}", x, 388, 82, 54, F(SKIN)) for t, x in (("L", 355), ("R", 445))],
          S(laugh, "LaughTeeth", [(372, 470), (428, 470), (424, 480), (376, 480)], F(TEETH)),
          E(laugh, "LaughTongue", 400, 498, 30, 14, F(TONGUE)),
          S(laugh, "LaughMouth", [(368, 468), (400, 466), (432, 468), (426, 490), (400, 508), (374, 490)], F(MOUTH_IN),
            L(INK, 3)))
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


GLASSES = {"glasses": glasses_set("G_glasses", "14B8D8F0", "40FFFFFF"),
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
    return S(head, name, pts, grad([(HAIR_HI, 0.0), (HAIR, 0.5), (HAIR_SH, 1.0)], -ln / 2, ln / 2), L(HAIR_SH, 2.4))


LOCKS = [((300, 272), (292, 404), 44, -8), ((330, 246), (318, 366), 50, 12), ((360, 236), (350, 338), 50, 10),
         ((396, 230), (420, 368), 70, 18), ((436, 234), (452, 334), 52, 10), ((470, 248), (490, 376), 58, 9),
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
                             S(head, "Bill", [(452, 206), (520, 188), (568, 184), (574, 200), (522, 216)],
                               vgrad(150, 210, CAP, CAP_SH), L(INK, 3)))
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
cowl_outer = [(284, 476), (276, 360), (282, 252), (300, 210), (312, 112, "c"), (342, 196), (400, 186), (458, 196),
              (488, 112, "c"), (500, 210), (518, 252), (524, 360), (516, 476), (480, 446), (452, 432), (420, 432),
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
    laser.add(S(laser, "Beam" + t, [(x, 384), (x + s * 520, 300), (x + s * 520, 330), (x, 394)],
                d("Fill", lin(d, -s * 260, 0, s * 260, 0, [("FFFF4AD8", 0.0), ("00FF4AD8", 1.0)]), name="Fill")))
eyeglow = [E(head, "EyeGlow" + t, x, 388, 46, 18, rgrad(23, [("FFFFFFFF", 0.0), ("FF7CF0FF", 0.5), ("007CF0FF", 1.0)]))
           for t, x in (("L", 355), ("R", 445))]
HATS["singularity"] = group("H_singularity", laser.el, *eyeglow, *sing_stars,
                            S(head, "Void", SING_HEAD, grad([("FF1A1E5A", 0.0), ("FF0A0B24", 0.6), ("FF05060F", 1.0)],
                                                            -160, 160), L("FF3A40A0", 3)))

for hid in HAT_IDS + COSTUMES:
    hat_solo.add(HATS[hid])
hat_solo.el.attrs["activeComponentId"] = HATS["noHat"].ref()

# ---- tap zones
hit_head = E(head, "HitHead", 400, 360, 300, 360, F("00000000"))
hit_body = R(body_g, "HitBody", 400, 820, 460, 380, 0, F("00000000"))

# head paint order (front first)
head.el.children = [hat_solo.el, sweat_m.el, sweat_p.el, anger.el, glasses_solo.el, hair_front.el, laugh.el,
                    eyes.el, blush.el, mouth.el, mole, nose, nose_sh, cheek_sh, face_cast, face, *ears, tufts.el,
                    hair_back.el, hit_head]

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

body_g.el.children = [bubble.el, question.el, clap_fx.el, ARM_R["arm"].el, ARM_L["arm"].el, head_base.el,
                      top_front.el, chin_sh, neck_sh, neck, top_back.el, back_fx.el, hit_body]

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
props: dict[str, El] = {}
for pn in ["mood", "mouth", "phase", "gestureId", "gesture", "hat", "top", "glasses", "costume", "presence"]:
    if pn == "mouth":
        props[pn] = d("ViewModelPropertyNumber", name=pn)
    elif pn == "gesture":
        props[pn] = d("ViewModelPropertyTrigger", name=pn)
    else:
        props[pn] = d("ViewModelPropertyEnumCustom", enumId=enums[EN_OF[pn]].ref(), name=pn)
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


# ================================================================ ANIMATIONS
anims: list[El] = []


def A(name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
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
breath = A("idle_breath", 240, [
    T(body, scaleY=[(0, 1.0), (120, 1.012), (240, 1.0)], y=[(0, 0.0), (120, -2.0), (240, 0.0)]),
    T(head_base, y=[(0, -440.0), (120, -446.0), (240, -440.0)], rotation=[(0, 0.0), (120, 0.012), (240, 0.0)]),
], loop=True)
blink_keys = [(0, 1.0), (150, 1.0), (154, 0.08), (159, 1.0), (196, 1.0), (200, 0.08), (205, 1.0), (222, 1.0)]
blink = A("idle_blink", 222, [T(e["blink"], ease=None, scaleY=blink_keys) for e in EYES], loop=True)
LOOK_X, LOOK_Y = 7.0, 4.5
look_x = A("look_x", 100, [*[T(e["look"], ease=None, x=[(0, -LOOK_X), (100, LOOK_X)]) for e in EYES],
                           T(head_look, ease=None, rotation=[(0, -0.035), (100, 0.035)])])
look_y = A("look_y", 100, [T(e["look"], ease=None, y=[(0, -LOOK_Y), (100, LOOK_Y)]) for e in EYES])

# ---- moods: every pose keys every channel so crossfades blend cleanly
MOOD_DEF = dict(brow=((0, 0.0), (0, 0.0)), droop=(0.0, 0.0), squint=0.0, eye_scale=1.0, gaze=(0, 0), line="neutral",
                blush=0.0, tilt=0.0, head_y=0.0, open_w=1.0, open_rot=0.0, sweat=0.0, anger=0.0)
MOOD_SPEC = {
    "neutral": {},
    "happy": dict(brow=((-6, 0.0), (-6, 0.0)), squint=1.0, line="smile", blush=0.8, tilt=-0.05, open_w=1.15),
    "sad": dict(brow=((-3, -0.24), (-3, -0.24)), droop=(0.38, -0.18), line="frown", tilt=0.05, head_y=6.0,
                gaze=(0, 3), open_w=0.9),
    "angry": dict(brow=((5, 0.28), (5, 0.28)), droop=(0.3, 0.22), line="tight", tilt=-0.02, anger=1.0, open_w=1.1,
                  head_y=2.0),
    "surprised": dict(brow=((-12, -0.04), (-12, -0.04)), eye_scale=1.12, line="o", head_y=-5.0, open_w=0.8),
    "thinking": dict(brow=((-9, -0.08), (2, 0.14)), gaze=(-4, -4), line="side", tilt=0.06, open_rot=-0.12),
    "embarrassed": dict(brow=((-2, -0.18), (-2, -0.18)), droop=(0.14, -0.05), gaze=(4, 3), line="wavy", blush=1.0,
                        sweat=1.0, tilt=0.04, open_w=0.95),
}


def mood_pose(name: str, spec: dict) -> El:
    p = {**MOOD_DEF, **spec}
    tr: list[El] = []
    for i, e in enumerate(EYES):
        s = -1 if i == 0 else 1
        by, br = p["brow"][i]
        tr.append(K(e["brow"], y=-39.0 + by, rotation=-br * s))
        dr, drot = p["droop"]
        tr.append(K(e["droop"], scaleY=dr, rotation=-drot * s))
        tr.append(K(e["squint"], scaleY=p["squint"]))
        tr.append(K(e["squint_line"], scaleY=p["squint"]))
        tr.append(K(e["mood"], scaleX=p["eye_scale"], scaleY=p["eye_scale"]))
        tr.append(K(e["gm"], x=float(p["gaze"][0]), y=float(p["gaze"][1])))
    for k, v in LINES.items():
        tr.append(K(v, opacity=1.0 if k == p["line"] else 0.0))
    tr += [K(blush, opacity=p["blush"]), K(head_mood, rotation=p["tilt"], y=p["head_y"]),
           K(open_mood, scaleX=p["open_w"], rotation=p["open_rot"]), K(sweat_m, opacity=p["sweat"]),
           K(anger, opacity=p["anger"])]
    return A("mood_" + name, 1, tr)


MOODS = {m: mood_pose(m, spec) for m, spec in MOOD_SPEC.items()}

# ---- mouth 0..4 (closed, slightly, semi, open, wide)
MOUTH = [(0.0, 0.0, 1.0, 1.0), (0.28, 1.0, 0.0, 0.92), (0.55, 1.0, 0.0, 0.96), (0.85, 1.0, 0.0, 1.0), (1.1, 1.0, 0.0, 1.18)]
mouth_anims = [A(f"mouth_{i}", 1, [K(open_, scaleY=sy, opacity=op, scaleX=sx), K(lines, opacity=lo)])
               for i, (sy, op, lo, sx) in enumerate(MOUTH)]


# ---- phases (looping poses; all channels keyed in each)
def phase_anim(name: str, frames: int, head_y: list | None = None, head_rot: list | None = None,
               gaze: list | None = None, bubble_on: float = 0.0, dot_bounce: bool = False, q_on: float = 0.0,
               sweat_on: float = 0.0) -> El:
    z = [(0, 0.0), (frames, 0.0)]
    tr = [T(head_phase, y=head_y or z, rotation=head_rot or z, x=z)]
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
    "waiting": phase_anim("waiting", 240, head_rot=[(0, 0.0), (60, 0.025), (150, 0.025), (210, 0.0), (240, 0.0)],
                          gaze=[(0, 0, 0), (40, 5, 1), (140, 5, 1), (180, 0, 0), (240, 0, 0)]),
    "generating": phase_anim("generating", 60, head_rot=[(0, -0.04), (60, -0.04)],
                             gaze=[(0, 5, -5), (60, 5, -5)], bubble_on=1.0, dot_bounce=True),
    "speaking": phase_anim("speaking", 50, head_y=[(0, 0.0), (12, -3.0), (25, 0.0), (37, -2.0), (50, 0.0)],
                           head_rot=[(0, 0.0), (20, 0.012), (40, -0.01), (50, 0.0)]),
    "error": phase_anim("error", 120, head_rot=[(0, 0.06), (120, 0.06)], gaze=[(0, -4, 2), (120, -4, 2)],
                        q_on=1.0, sweat_on=1.0),
}

# ---- gestures (IK-posed arms + head channels; gesture_none keys every gesture channel at rest)
ARM_Y0 = 720.0 - 1000.0


def arm_keys(side: int, poses: list[tuple[int, tuple[float, float] | None, float]], out: bool = False) -> list[El]:
    a = ARMS[0 if side == -1 else 1]
    k1, k2, k3 = [], [], []
    for f, wrist, deg in poses:
        r = (0.0, 0.0, 0.0) if wrist is None else ik(side, wrist, deg, out)
        k1.append((f, r[0]))
        k2.append((f, r[1]))
        k3.append((f, r[2]))
    return [T(a["arm"], rotation=k1), T(a["elbow"], rotation=k2), T(a["hand"], rotation=k3)]


gesture_rest = [T(a[k], ease=None, rotation=[(0, 0.0)]) for a in ARMS for k in ("arm", "elbow", "hand", "wave")]
gesture_rest += [K(a["arm"], y=ARM_Y0) for a in ARMS]
gesture_rest += [K(body_g, y=0.0), K(head_g, x=0.0, y=0.0, rotation=0.0), K(laugh, opacity=0.0), K(clap_fx, opacity=0.0)]
gesture_rest += [K(e["brow_g"], y=0.0) for e in EYES] + [K(e["gg"], x=0.0, y=0.0) for e in EYES]
g_none = A("gesture_none", 1, gesture_rest)

G: dict[str, El] = {}
wave_fore = [(0, 0.0), (16, 2.7), (22, 3.05), (32, 2.86), (42, 3.1), (52, 2.86), (62, 3.1), (72, 2.86), (82, 3.0),
             (100, 0.0)]
G["wave"] = A("gesture_wave", 104, [
    T(ARM_R["arm"], rotation=[(0, 0.0), (16, 0.22), (84, 0.22), (102, 0.0)]),
    T(ARM_R["elbow"], rotation=wave_fore),
    T(ARM_R["wave"], rotation=[(0, 0.0), (22, 0.0), (32, -0.2), (42, 0.16), (52, -0.2), (62, 0.16), (72, -0.18),
                               (84, 0.0)]),
    T(head_g, y=[(0, 0.0), (20, -4.0), (84, -4.0), (100, 0.0)], rotation=[(0, 0.0), (20, -0.04), (84, -0.04), (100, 0.0)]),
])
bounce = [(0, 0.0)] + [(f, -6.0 if (f // 8) % 2 else 0.0) for f in range(8, 72, 8)] + [(96, 0.0)]
G["laugh"] = A("gesture_laugh", 96, [
    T(body_g, y=bounce),
    T(head_g, rotation=[(0, 0.0), (10, -0.08), (80, -0.06), (96, 0.0)], y=[(0, 0.0), (10, -8.0), (80, -6.0), (96, 0.0)]),
    T(laugh, ease=None, opacity=[(0, 0.0), (6, 1.0, "linear"), (84, 1.0), (94, 0.0)]),
])
G["facepalm"] = A("gesture_facepalm", 124, [
    *arm_keys(-1, [(0, None, 90), (24, (322, 486), -66), (96, (322, 486), -66), (120, None, 90)]),
    T(ARM_R["wave"], rotation=[(0, 0.0), (36, 0.0), (52, 0.06), (68, -0.04), (84, 0.05), (100, 0.0)]),
    T(head_g, rotation=[(0, 0.0), (24, 0.08), (96, 0.08), (120, 0.0)], y=[(0, 0.0), (24, 8.0), (96, 8.0), (120, 0.0)]),
])
G["shrug"] = A("gesture_shrug", 92, [
    *arm_keys(-1, [(0, None, 90), (18, (150, 880), -150), (64, (150, 880), -150), (88, None, 90)], out=True),
    *arm_keys(1, [(0, None, 90), (18, (650, 880), -30), (64, (650, 880), -30), (88, None, 90)], out=True),
    *[T(a["arm"], y=[(0, ARM_Y0), (18, ARM_Y0 - 14), (64, ARM_Y0 - 14), (88, ARM_Y0)]) for a in ARMS],
    T(head_g, rotation=[(0, 0.0), (18, 0.1), (64, 0.1), (88, 0.0)], y=[(0, 0.0), (18, 6.0), (64, 6.0), (88, 0.0)]),
    *[T(e["brow_g"], y=[(0, 0.0), (18, -8.0), (64, -8.0), (88, 0.0)]) for e in EYES],
])
G["nod"] = A("gesture_nod", 80, [
    T(head_g, y=[(0, 0.0), (12, 9.0), (24, -2.0), (36, 8.0), (48, -1.0), (60, 5.0), (76, 0.0)],
      rotation=[(0, 0.0), (80, 0.0)]),
    *[T(e["gg"], y=[(0, 0.0), (12, 2.0), (24, 0.0), (36, 2.0), (48, 0.0), (80, 0.0)]) for e in EYES],
])
G["headshake"] = A("gesture_headshake", 84, [
    T(head_g, x=[(0, 0.0), (10, -10.0), (22, 10.0), (34, -10.0), (46, 9.0), (58, -6.0), (72, 0.0)],
      rotation=[(0, 0.0), (10, 0.03), (22, -0.03), (34, 0.03), (46, -0.025), (58, 0.015), (72, 0.0)]),
    *[T(e["gg"], x=[(0, 0.0), (10, 3.0), (22, -3.0), (34, 3.0), (46, -3.0), (58, 2.0), (72, 0.0)]) for e in EYES],
])
claps = [(0, None, 90), (18, (330, 800), -76)]
fx_keys = [(0, 0.0)]
f = 18
for k in range(4):
    claps += [(f + 8, (384, 792), -86), (f + 18, (330, 800), -76)]
    fx_keys += [(f + 7, 0.0), (f + 9, 1.0, "linear"), (f + 15, 0.0)]
    f += 18
claps += [(f + 18, None, 90)]
G["clap"] = A("gesture_clap", f + 20, [
    *arm_keys(-1, claps),
    *arm_keys(1, [(fr, None if w is None else (800 - w[0], w[1]), 180 - dg) for fr, w, dg in claps]),
    T(clap_fx, ease=None, opacity=fx_keys + [(f + 20, 0.0)]),
    T(head_g, y=[(0, 0.0), (18, -3.0), (f, -3.0), (f + 18, 0.0)]),
])
G["think"] = A("gesture_think", 124, [
    *arm_keys(-1, [(0, None, 90), (26, (366, 640), -78), (96, (366, 640), -78), (120, None, 90)]),
    T(head_g, rotation=[(0, 0.0), (26, -0.07), (96, -0.07), (120, 0.0)]),
    *[T(e["gg"], x=[(0, 0.0), (26, -5.0), (96, -5.0), (120, 0.0)], y=[(0, 0.0), (26, -5.0), (96, -5.0), (120, 0.0)])
      for e in EYES],
    T(EYE_L["brow_g"], y=[(0, 0.0), (26, -7.0), (96, -7.0), (120, 0.0)]),
])

# ---- wardrobe switches
hat_hair = {"noHat": (1, 1, 1), "beanie": (1, 1, 0), "backwardsCap": (1, 1, 0), "frenchBeret": (1, 1, 0),
            "swimCap": (0, 0, 0), "santaHat": (1, 1, 0), "redMagaCap": (1, 1, 0),
            "batman": (0, 0, 0), "robocop": (0, 0, 0), "soubrette": (1, 1, 1), "singularity": (0, 0, 0)}


def hat_tracks(hid: str) -> list[El]:
    hf, hb, tu = hat_hair[hid]
    return [K(hat_solo, activeComponentId=HATS[hid]), K(hair_front, opacity=float(hf)), K(hair_back, opacity=float(hb)),
            K(tufts, opacity=float(tu))]


santa_swing = [T(santa_flop, rotation=[(0, 0.0), (60, 0.08), (120, 0.0)])]
HAT_ANIMS = {h: A("hat_" + h, 120 if h == "santaHat" else 1, hat_tracks(h) + (santa_swing if h == "santaHat" else []),
                  loop=h == "santaHat") for h in HAT_IDS}


def top_tracks(oid: str) -> list[El]:
    tr = [K(top_front, activeComponentId=TF[oid]), K(top_back, activeComponentId=TB[oid])]
    for a in ARMS:
        tr += [K(a["up_solo"], activeComponentId=a["ups"][oid]), K(a["fore_solo"], activeComponentId=a["fores"][oid])]
    return tr


TOP_ANIMS = {t: A("top_" + t, 1, top_tracks(t)) for t in TOP_IDS}
GLASS_ANIMS = {g: A("glasses_" + g, 1, [K(glasses_solo, activeComponentId=GLASSES[g])]) for g in ("glasses", "sunglasses")}

# costume extras: soubrette feather duster, held at the viewer-right shoulder
duster = body_g.node("Duster", 640, 780, opacity=0.0)
duster.add(*[E(duster, f"Feather{k}", 640 + 34 * math.cos(-PI / 2 + (k - 3) * 0.32), 570 + 34 * math.sin(-PI / 2 + (k - 3) * 0.32),
               46, 70, rgrad(36, [("FFFFF0F6", 0.0), ("FFF2A8C8", 0.6), ("FFD87AA8", 1.0)]), L("FFB0607E", 2),
               rotation=(k - 3) * 0.32) for k in range(7)],
           R(duster, "Handle", 640, 690, 14, 180, 6, vgrad(-95, 95, "FFB07840", "FF6A4420"), L("FF3A2410", 2)))
body_g.el.children.remove(duster.el)
body_g.el.children.insert(0, duster.el)

none_anim = A("costume_none", 1, [K(back_fx, activeComponentId=fx_none), K(duster, opacity=0.0)])
star_twinkle = [T(s_, ease=None, opacity=[(0, 1.0), (20 + (i * 13) % 80, 0.2), (40 + (i * 13) % 80, 1.0), (120, 1.0)])
                for i, s_ in enumerate(STAR_FX)]
COSTUME_EXTRA = {
    "batman": [K(back_fx, activeComponentId=cape_rig.el),
               T(cape_rig, rotation=[(0, 0.0), (60, 0.02), (120, 0.0)], scaleX=[(0, 1.0), (60, 1.04), (120, 1.0)])],
    "robocop": [K(back_fx, activeComponentId=fx_none),
                T(scan, x=[(0, -86.0), (60, 86.0), (120, -86.0)])],
    "soubrette": [K(back_fx, activeComponentId=fx_none), K(duster, opacity=1.0),
                  T(duster, rotation=[(0, -0.3), (30, 0.4), (60, -0.3), (90, 0.4), (120, -0.3)])],
    "singularity": [K(back_fx, activeComponentId=aura_rig.el),
                    T(aura_rig, scaleX=[(0, 0.92), (60, 1.06), (120, 0.92)], scaleY=[(0, 0.92), (60, 1.06), (120, 0.92)],
                      opacity=[(0, 0.7), (60, 1.0), (120, 0.7)]),
                    T(laser, ease=None, opacity=[(0, 0.0), (70, 0.0), (74, 1.0, "linear"), (100, 1.0), (106, 0.0),
                                                 (120, 0.0)]),
                    *star_twinkle],
}


def costume_tracks(cid: str) -> list[El]:
    tr = hat_tracks(cid) + top_tracks(cid) + COSTUME_EXTRA[cid]
    if cid in ("batman", "robocop", "singularity"):
        tr.append(K(glasses_solo, activeComponentId=GLASSES["none"]))
    if cid != "soubrette":
        tr.append(K(duster, opacity=0.0))
    return tr


COSTUME_ANIMS = {"none": none_anim, **{c: A("costume_" + c, 120, costume_tracks(c), loop=True) for c in COSTUMES}}

# ---- presence: walk off/on to the right (Root x is absolute)
ON_X, OFF_X = 400.0, 1250.0


def walk(frames: int, x0: float, x1: float) -> list[El]:
    bob = [(f, 1000.0 - (10.0 if (f // 10) % 2 else 0.0), "linear") for f in range(0, frames, 10)] + [(frames, 1000.0)]
    sway = [(f, 0.03 if (f // 20) % 2 else -0.03) for f in range(0, frames, 20)] + [(frames, 0.0)]
    return [T(root, x=[(0, x0), (frames, x1)]), T(root, ease=None, y=bob), T(body, ease=None, rotation=sway)]


P_ON = A("presence_onScreen", 1, [K(root, x=ON_X, y=1000.0), K(body, rotation=0.0)])
P_OFF = A("presence_outOfScreen", 1, [K(root, x=OFF_X, y=1000.0), K(body, rotation=0.0)])
P_WALK_OUT = A("presence_walkOut", 80, walk(80, ON_X, OFF_X))
P_WALK_IN = A("presence_walkIn", 80, walk(80, OFF_X, ON_X))
P_LEAVE = A("presence_leaveAndComeBack", 200, [
    T(root, x=[(0, ON_X), (80, OFF_X), (120, OFF_X), (200, ON_X)]),
    T(root, ease=None, y=[(f, 1000.0 - (10.0 if (f // 10) % 2 and not 80 <= f < 120 else 0.0), "linear")
                          for f in range(0, 200, 10)] + [(200, 1000.0)]),
    T(body, ease=None, rotation=[(f, (0.03 if (f // 20) % 2 else -0.03) if not 80 <= f < 120 else 0.0)
                                 for f in range(0, 200, 20)] + [(200, 0.0)]),
])

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
s0 = st(blink, 0)
layers.append(layer("Blink", s0, [s0]))
layers.append(enum_layer("Mood", "mood", MOODS, "neutral", 240))
mouth_conv = d("DataConverterRangeMapper", minInput=0.0, maxInput=4.0, minOutput=0.0, maxOutput=100.0, clampLower=True,
               clampUpper=True, name="MouthToBlend")
mouth_blend = d("BlendState1DViewModel",
                d("BindablePropertyNumber", d("DataBindContext", sourcePathIds=vpath("mouth"), propertyKey=636,
                                              converterId=mouth_conv.ref())),
                *[d("BlendAnimation1D", animationId=a.ref(), value=float(i * 25)) for i, a in enumerate(mouth_anims)],
                x=0.0, y=100.0)
layers.append(layer("Mouth", mouth_blend, [mouth_blend]))
layers.append(enum_layer("Phase", "phase", PHASES, "idle", 250))

gs_idle = st(g_none, 0)
g_states = []
for i, (gn, ga) in enumerate(G.items()):
    gst = st(ga, i + 1,
             d("StateMachineFireEvent", eventId=EV_GESTURE[gn].ref(), occursValue="atEnd"),
             d("StateTransition", stateToId=gs_idle.ref(), enableExitTime=True, exitTimeIsPercetange=True, exitTime=100,
               duration=150), row=1)
    gs_idle.add(d("StateTransition", trig("gesture"), enum_is("gestureId", gn), stateToId=gst.ref(), duration=120))
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
artboard = d("Artboard", style, sm, EASE, *EV_GESTURE.values(), *EV_TAP.values(), *EV_PRESENCE.values(), joy,
             look_handle, root.el, hit_all, *anims,
             width=float(W), height=float(H), name="Avatar", defaultStateMachineId=sm.ref(), viewModelId=vm.ref(),
             viewModelInstanceId=inst.ref(), styleId=style.ref(), clip=True)

out = os.path.join(os.path.dirname(__file__), "..", "avatar", "avatar.rml")
os.makedirs(os.path.dirname(out), exist_ok=True)
write(out, [artboard, *enums.values(), mouth_conv, vm])
print("wrote", os.path.normpath(out), "next id", d.next)
