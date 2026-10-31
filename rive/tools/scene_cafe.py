"""Contract v12 scene `cafe` (moonshot M9, lane S1): a small storybook café on a rainy evening.

    uv run rive/tools/gen_scenes.py cafe      # writes rive/scenes/cafe/cafe.rml (through SCENE_BUILDERS)

Layout (1080 x 1920, the avatar stands at x 330..750 from y 700 down, so the props sit left and right):

- **Plane0** (the view through the window): the night sky (`daylight` / `dusk` through
  `gen_scenes.sky_time`, registered in `TIME_SKY`), the moon (`moonPhase`: `world_kit.moon_rig`; at -1
  the drawn moon, wrapped by `hide_when_phased`), rooftops, the house across the street with its lit
  windows and the neon cup sign (`neonFlicker`).
- **Plane1** (the street in front): the lamp post, the wet street and its reflections (`rain`: the
  reflections and the sheen brighten), a day veil over the street, the fog bank (`fog`, outside only:
  `scene_npc.FOG_BANKS` / `FOG_VEILS` registered for planes 0 and 1, which only show through the
  window).
- **Plane2** (the window): the frame with its six panes, the condensation (always there, thicker on
  the lower panes), the rain on the glass (`rain`: streaks and drips clipped to the panes, the
  `rain` event's shower on top) and the wiped spots of the `wipe` drag (M10: holes in the mist with
  a stepped soft edge, `wipe_holes`: a wipe reads as clear glass). The prop `window`.
- **Plane3** (the back wall, in front of the recessed window): the wall with its opening, the
  festive string lights along the top of the opening (`festive`), the counter with the espresso
  machine (prop + `espresso` event) and the goldfish bowl (the NPC **fish**, prop `fish`), the shelf,
  the door with its bell and wreath (`doorbell` event; the wreath and its lights are `festive`).
- **Plane4** (the room): the checker floor, the round table with the steaming cup (prop `cup`), the
  chair, the pendant lamp (the key light), the door's cold light spilling on the floor.
- **Plane5** (the foreground): a potted plant at the bottom left and a trailing ivy top right.

Everything is history-free (formula converters on view-model numbers); at the contract defaults
(`trailN` 0, `trailFade` 1, `moonPhase` -1, `festive` 0, `rain` / `fog` / `daylight` / `dusk` 0) the
scene shows a dry evening with the drawn moon. The module registers its `DioramaSpec` (`DIORAMAS`), its
sky (`TIME_SKY`) and its fog (`scene_npc.FOG_VEILS` / `FOG_BANKS`) at import, and exports `BINDS`
(the v12 members it binds) and `REVIEW` (the review tools' configuration, see `world_kit`).
"""

from __future__ import annotations

import math
import os
import random
import sys
from typing import Callable
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import gen_scenes  # noqa: E402
from gen_scenes import DioramaSpec, Scene, W, H  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, ellipse, rad, smooth_path  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds  # noqa: E402
import world_kit  # noqa: E402

SCENE_ID = "cafe"
O = (0.0, 0.0)
INK = "FF2A2030"

# ---------------------------------------------------------------- layout (artboard px)
FLOOR_Y = 1226.0
COUNTER_TOP = 996.0
SIT_Y = 1006.0                      # where things stand on the counter
# the window: six panes (the glass, the `wipe` handle's rect), a 30 px frame around them; the wall's
# opening is 12 px inside the frame's outer edge, so the recessed frame shows 18 px of border at rest
# and the wall's 8 px of extra parallax travel never uncovers the frame's edge or covers the glass
GLASS = (330.0, 260.0, 750.0, 760.0)
PANES = ((330.0, 260.0, 464.0, 384.0), (476.0, 260.0, 604.0, 384.0), (616.0, 260.0, 750.0, 384.0),
         (330.0, 396.0, 464.0, 760.0), (476.0, 396.0, 604.0, 760.0), (616.0, 396.0, 750.0, 760.0))
FRAME = (300.0, 230.0, 780.0, 790.0)
OPENING = (312.0, 242.0, 768.0, 778.0)
VIEW = (280.0, 210.0, 800.0, 810.0)  # the outside art runs 20 px past the frame (Plane0 / 1 vs Plane2 travel)
MOON = (400.0, 314.0, 22.0)          # (cx, cy, r)
SKY_AT_MOON = "FF1E2236"             # the sky's colour behind the moon (the rig's dark side at 0.9)
NEON_AT = (540.0, 596.0)
LAMP_POST_X = 700.0
DOOR = (850.0, 596.0, 1030.0, 1250.0)  # the leaf; hinge on the right
DOOR_HINGE = (1030.0, 920.0)
BELL_PIVOT = (866.0, 606.0)
WREATH = (940.0, 672.0, 34.0)
TABLE = (880.0, 1052.0)
CUP = (860.0, 1030.0)
ESPRESSO = (130.0, 945.0)
BOWL = (266.0, 958.0, 52.0)          # (cx, cy, r) of the goldfish bowl
WATER_Y = 922.0
PENDANT = (200.0, 536.0)

# ---------------------------------------------------------------- the fish (contract v12 NPC)
# its anchor (the body's centre) on screen along `npcX` 0 -> 1, scale 1 (a flat path across the bowl)
FISH_WAYPOINTS = [(254.0, 966.0, 1.0), (268.0, 969.0, 1.0), (282.0, 966.0, 1.0)]
FISH_HIT = (44.0, 38.0)
FISH_REST, FISH_IDLE, FISH_MOVE, FISH_NOTICE, FISH_REACT = 240, 240, 40, 120, 72
FISH_FACE_GAIN = 1e5   # `move` / idle face right while npcLook >= 0, left while < 0 (the Dart lane's cue)

# ---------------------------------------------------------------- rain on the glass (`rain`)
GLASS_STREAKS = (30, 250.0, 20)      # (count, tile px, loop frames)
GLASS_DRIPS = (12, 500.0, 240)
GLASS_RAIN_FRAMES = 240              # every glass sheet is back at frame 0 after this many frames
SHOWER_STREAKS = (40, 250.0, 12)     # the `rain` event's heavier sheet (only seen while it plays)
GLASS_WET = ("FF7A8898", 0.18)       # wet tint over the panes at rain 1
STREAK_COLOUR = "80CCD8E4"
REFLECT_REST = 0.3                   # the street's reflections at rain 0 (an evening street is damp)
MIST = "C8D2DC"                      # condensation colour (alpha per gradient stop)
TRAIL_R = 28.0                       # a wiped spot's reach (dots >= 22 px apart: one wiped stroke)
# M10: a wiped spot is a hole in the mist of radius WIPE_R; its edge steps back to the mist through
# thinner mist rings (radius inside which the ring is clear, the mist's opacity in the ring)
WIPE_R = 30.0
WIPE_RINGS = ((26.0, 0.72), (22.0, 0.46), (18.0, 0.24), (14.0, 0.08))

# ---------------------------------------------------------------- events (frames at 60 fps)
CUP_STEAM_FRAMES = 180
EV_FRAMES = {"espresso": 150, "doorbell": 210, "rain": 420, "neonFlicker": 110}

# ---------------------------------------------------------------- planes
PLANES: dict[str, int | None] = {
    **dict.fromkeys(("Plant", "PlantPot", "Ivy"), 5),
    **dict.fromkeys(("GustLeaf", "DoorSpill", "CupSteam", "Cup", "Saucer", "TableTop", "TableEdge", "TableStem",
                     "TableBase", "TableShadow", "Chair", "PendantGlow", "PendantCone", "Pendant", "PendantCord",
                     "FloorPool", "CounterShadow", "DoorShadow", "Baseboard", "FloorShade", "FloorTiles",
                     "Floor"), 4),
    **dict.fromkeys(("FestiveLights", "Bell", "BellBracket", "DoorLeaf", "DoorGap", "DoorCasing", "BowlFront",
                     "FishNpc", "BowlBack", "BowlCoaster", "Steam", "EspLightOn", "Espresso", "Shelf",
                     "CounterRail", "CounterPanel", "CounterTop", "Counter", "Sill", "SillShadow",
                     "WinReveal", "WallWarmth", "Cornice", "Rail", "WainscotPanelHi", "WainscotPanel", "Wainscot",
                     "WallpaperPrint", "Wallpaper", "Wall"), 3),
    **dict.fromkeys(("WipeMistBack", "WipeRing", "WipeClip", "RainGlass", "ShowerGlass", "Mist", "PaneClip", "WinBevel", "WinFrame"), 2),
    **dict.fromkeys(("StreetDay", "ShowerSheen", "StreetReflect", "LampHead", "LampGlow", "LampPost",
                     "StreetSheen", "Street"), 1),
    **dict.fromkeys(("NeonFlick", "LitWin", "DarkWin", "Shopfront", "Awning", "AwningBase", "Kerb",
                     "FacadeCornice", "Facade", "Roofs",
                     "Spire", "MoonArt", "MoonRig", "Star", "Sky"), 0),
    # ruling 3: each hit zone rides the plane of its prop's art
    "Hit_cup": 4, "Hit_espresso": 3, "Hit_fish": 3, "Hit_window": 2,
}
EMISSIVE = ("NeonFlick", "LitWin", "MoonArt", "MoonRig", "Star", "LampHead", "LampGlow", "StreetReflect",
            "PendantGlow", "PendantCone", "EspLightOn", "DoorGap", "DoorSpill", "Shopfront", "WallWarmth")
# a light street haze (`lightFog`) in front of the sky and, thinner, the street: only seen through the glass
VEILS = ((0.3, 380.0, 640.0), (0.15, 560.0, 800.0))
# the wall pool takes `lightKey` (as the living room's lamp): (gradient opacity, share of the radius)
WALL_POOL = ((0.22, 1.0), (0.16, 0.5))
WALL_POOL_AT = (200.0, 700.0, 340.0)

# contract v12: the members this file binds (Scene.check_v12_binds, check_contract.py)
BINDS: set[str] = {"moonPhase", "festive", *world_kit.drag_numbers(SCENE_ID)}


# ====================================================================== small drawing helpers
def _rect_path(d: Doc, x0: float, y0: float, x1: float, y1: float, ox: float = 0.0, oy: float = 0.0,
               r: float = 0.0, name: str = "Path") -> El:
    """A Rectangle path covering artboard (x0, y0)-(x1, y1) in a shape placed at (ox, oy)."""
    rr = float(r) if r else None
    return d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2 - ox),
             y=float((y0 + y1) / 2 - oy), cornerRadiusTL=rr, cornerRadiusTR=rr, cornerRadiusBL=rr,
             cornerRadiusBR=rr, name=name)


def _poly(d: Doc, pts: list[tuple[float, float]], name: str = "Path") -> El:
    """A closed polygon (hard corners) in artboard px, for a shape at the origin."""
    return smooth_path(d, [(float(x), float(y), "c") for x, y in pts], name=name)


def box(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, *paints: El, r: float = 0.0,
        **kw: object) -> El:
    """A rectangle shape centred on its box (gradients: shape-local, y -h/2 .. h/2)."""
    d = sc.d
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return d("Shape", _rect_path(d, x0, y0, x1, y1, cx, cy, r), *paints, x=float(cx), y=float(cy), name=name, **kw)


def multi(sc: Scene, name: str, paths: list[El], *paints: El, **kw: object) -> El:
    """One shape at the origin holding several paths (artboard px) and one set of paints."""
    return sc.d("Shape", *paths, *paints, x=0.0, y=0.0, name=name, **kw)


def hgrad(sc: Scene, x0: float, x1: float, stops: list[tuple[str, float]]) -> El:
    d = sc.d
    return d("Fill", d("LinearGradient", *[d("GradientStop", colorValue=c, position=float(p)) for c, p in stops],
                       startX=float(x0), startY=0.0, endX=float(x1), endY=0.0), name="Fill")


def wave(amp: float, period: int, n: int, phase: float = 0.0, step: int = 2) -> list[tuple[int, float, str]]:
    """A sine sampled every `step` frames (linear keys; rml.write thins them), seamless over `n`."""
    return [(f, round(amp * math.sin(2 * math.pi * f / period + phase), 5), "linear") for f in range(0, n + 1, step)]


def _formula(sc: Scene, toks: list[El]) -> El:
    conv = sc.d("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def _clamp01(f: Formulas, inner: list[El]) -> list[El]:
    return f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], inner))


# ====================================================================== the outside (Plane0, Plane1)
def outside(sc: Scene) -> tuple[list[El], dict[str, El]]:
    """The view through the window, front-most first: Plane1 (street) then Plane0 (sky)."""
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    vx0, vy0, vx1, vy1 = VIEW
    keep: dict[str, El] = {}
    rnd = random.Random(zlib.crc32(b"cafeOutside"))

    # ---- Plane0: sky, stars, moon, rooftops, the house across the street
    sky = box(sc, "Sky", vx0, vy0, vx1, 700, sc.vgrad(-(700 - vy0) / 2, (700 - vy0) / 2,
                                                     [("FF181C30", 0.0), ("FF1E2236", 0.22), ("FF2E2A48", 0.62),
                                                      ("FF4A3A58", 1.0)]))
    stars = []
    for i, (x, y) in enumerate(((356, 280), (452, 352), (508, 300), (566, 340), (646, 286), (724, 336),
                                (590, 272), (700, 368))):
        sz = (2.6, 3.4, 2.4, 3.0)[i % 4]
        stars.append(E(O, f"Star{i}", x, y, sz, sz, F("FFF4EEDC"), opacity=round(rnd.uniform(0.5, 0.95), 2)))
    mx, my, mr = MOON
    craters = [E(O, f"MoonCrater{i}", x, y, w, h, F("FFE2D8BE"))
               for i, (x, y, w, h) in enumerate(((-7, -5, 9, 8), (6, 6, 7, 6), (8, -8, 5, 4)))]
    moon_disc = E(O, "MoonDisc", 0, 0, 2 * mr, 2 * mr, F("FFF4ECD4"))
    glow = E(O, "MoonGlow", 0, 0, 150, 150, sc.rgrad(75, [("40F4ECD4", 0.0), ("00F4ECD4", 1.0)]))
    drawn = d("Node", *craters, moon_disc, glow, x=mx, y=my, name="MoonDrawn")
    moon_art = world_kit.hide_when_phased(sc, sc.d9, "MoonArt", [drawn])
    lit = d("Node", *[E(O, f"MoonLitCrater{i}", float(c.attrs["x"]), float(c.attrs["y"]), 7, 6, F("FFE2D8BE"))
                      for i, c in enumerate(craters[:2])],
            E(O, "MoonLit", 0, 0, 2 * mr, 2 * mr, F("FFF4ECD4")), x=0.0, y=0.0, name="MoonLitArt")
    moon_rig = world_kit.moon_rig(sc, sc.d9, mx, my, mr, lit, "E6" + SKY_AT_MOON[2:])
    # rooftops: a far row of chimneys and a little spire against the city glow
    roofs = S(O, "Roofs", [(vx0, 700, "c"), (vx0, 486, "c"), (330, 486, "c"), (330, 470, "c"), (346, 470, "c"),
                           (346, 486, "c"), (392, 486, "c"), (420, 462, "c"), (448, 486, "c"), (520, 486, "c"),
                           (520, 476, "c"), (600, 476, "c"), (632, 452, "c"), (664, 476, "c"), (700, 476, "c"),
                           (700, 458, "c"), (712, 458, "c"), (712, 476, "c"), (vx1, 476, "c"), (vx1, 700, "c")],
             F("FF282438"))
    spire = S(O, "Spire", [(560, 486, "c"), (560, 430, "c"), (568, 400, "c"), (576, 430, "c"), (576, 486, "c")],
              F("FF282438"))
    facade = box(sc, "Facade", vx0, 500, vx1, 668, sc.vgrad(-84, 84, [("FF3E3040", 0.0), ("FF32283A", 1.0)]))
    cornice = box(sc, "FacadeCornice", vx0, 496, vx1, 508, F("FF4A3A48"))
    wins = [(318, 522), (392, 522), (500, 522), (560, 522), (640, 522), (726, 522)]
    lit_wins, dark_wins = [], []
    for i, (x, y) in enumerate(wins):
        if i in (1, 4):
            dark_wins.append(box(sc, f"DarkWin{len(dark_wins)}", x, y, x + 34, y + 42, F("FF221E2C"), r=3))
        else:
            lit_wins.append(box(sc, f"LitWin{len(lit_wins)}", x, y, x + 34, y + 42,
                                sc.vgrad(-21, 21, [("FFFFDA94", 0.0), ("FFF0B060", 1.0)]), r=3))
    # the neon cup sign (pink tubes and their glow) between the windows and the shop front
    nx, ny = NEON_AT
    pink = "FFFF8CBE"
    tubes = [S((nx, ny), "NeonCupTube", [(nx - 26, ny - 14, "c"), (nx + 18, ny - 14, "c"), (nx + 14, ny + 10),
                                         (nx - 4, ny + 18), (nx - 22, ny + 10)], sc.L(pink, 4.0)),
             S((nx, ny), "NeonHandle", [(nx + 17, ny - 8), (nx + 30, ny - 4), (nx + 28, ny + 6), (nx + 14, ny + 6)],
               sc.L(pink, 3.4), closed=False),
             S((nx, ny), "NeonSaucer", [(nx - 34, ny + 24), (nx + 26, ny + 24)], sc.L(pink, 3.4), closed=False),
             S((nx, ny), "NeonSteamA", [(nx - 14, ny - 22), (nx - 8, ny - 30), (nx - 14, ny - 38), (nx - 8, ny - 46)],
               sc.L("FFFFD0E6", 3.0), closed=False),
             S((nx, ny), "NeonSteamB", [(nx, ny - 22), (nx + 6, ny - 30), (nx, ny - 38), (nx + 6, ny - 46)],
               sc.L("FFFFD0E6", 3.0), closed=False)]
    neon_glow = E((nx, ny), "NeonGlow", nx, ny - 8, 170, 130, sc.rgrad(85, [("70FF8CBE", 0.0), ("00FF8CBE", 1.0)]))
    neon = d("Node", *tubes, neon_glow, x=nx, y=ny, name="NeonSign")
    neon_flick = d("Node", neon, x=0.0, y=0.0, name="NeonFlick")
    keep["neon"] = neon_flick
    awning = multi(sc, "Awning", [_poly(d, [(x, 630), (x + 24, 630), (x + 24, 646), (x, 646)])
                                  for x in range(int(vx0), int(vx1), 48)], F("FF8A4A4E"))
    awning_bg = box(sc, "AwningBase", vx0, 630, vx1, 648, F("FFD8C8B4"))
    shop = box(sc, "Shopfront", vx0, 648, vx1, 664, sc.vgrad(-8, 8, [("FFF0C27A", 0.0), ("FFB87A48", 1.0)]))
    kerb = box(sc, "Kerb", vx0, 664, vx1, 676, F("FF4A4A5A"))
    plane0 = [neon_flick, *lit_wins, *dark_wins, kerb, shop, awning, awning_bg, cornice, facade, roofs, spire,
              moon_rig, moon_art, *stars, sky]

    # ---- Plane1: the street, its reflections, the lamp post
    street = box(sc, "Street", vx0, 672, vx1, vy1, sc.vgrad(-(vy1 - 672) / 2, (vy1 - 672) / 2,
                                                            [("FF2C2E40", 0.0), ("FF1E2030", 1.0)]))
    sheen = box(sc, "StreetSheen", vx0, 676, vx1, vy1, sc.vgrad(-(vy1 - 676) / 2, (vy1 - 676) / 2,
                                                                [("405A6C88", 0.0), ("00405A6C", 1.0)]))
    refl = []
    for i, (x, w, col, a) in enumerate(((nx, 70, "FF8CBE", "90"), (LAMP_POST_X, 50, "FFE2A0", "A0"),
                                        (335, 22, "FFDA94", "60"), (517, 22, "FFDA94", "60"),
                                        (577, 22, "FFDA94", "50"), (743, 22, "FFDA94", "60"))):
        refl.append(d("Shape", _rect_path(d, x - w / 2, 676, x + w / 2, 790, x, 733),
                      sc.vgrad(-57, 57, [(a + col, 0.0), ("00" + col, 1.0)]), x=float(x), y=733.0,
                      name=f"Reflect{i}"))
        # a few horizontal ripples break each reflection up
        for k, yy in enumerate((700, 722, 748, 770)):
            refl.append(box(sc, f"Ripple{i}_{k}", x - w * 0.42, yy, x + w * 0.42, yy + 2, F("30" + col)))
    neon_refl = d("Node", refl[0], *refl[1:5], x=0.0, y=0.0, name="NeonReflect")
    keep["neon_reflect"] = neon_refl
    with sc.minting(sc.d5):
        reflect = d("Node", sc.bind("rain", 18, _rain_reflect_conv(sc)), neon_refl, *refl[5:],
                    x=0.0, y=0.0, opacity=REFLECT_REST, name="StreetReflect")
        sheen.children.insert(0, sc.bind("rain", 18))
        sheen.attrs["opacity"] = 0.0
    shower = box(sc, "ShowerSheen", vx0, 676, vx1, vy1, sc.vgrad(-(vy1 - 676) / 2, (vy1 - 676) / 2,
                                                                 [("507A8CA8", 0.0), ("107A8CA8", 1.0)]), opacity=0.0)
    keep["shower_sheen"] = shower
    lx = LAMP_POST_X
    post = d("Node", box(sc, "PostPole", lx - 5, 444, lx + 5, vy1, F("FF1C1A26")),
             box(sc, "PostFoot", lx - 10, 760, lx + 10, vy1, F("FF1C1A26"), r=3),
             x=0.0, y=0.0, name="LampPost")
    head = d("Node",
             S(O, "LampCap", [(lx - 22, 426, "c"), (lx, 408, "c"), (lx + 22, 426, "c")], F("FF1C1A26")),
             box(sc, "LampFrame", lx - 16, 424, lx + 16, 466, sc.L("FF1C1A26", 3.0), r=2),
             box(sc, "LampGlass", lx - 15, 425, lx + 15, 465, sc.vgrad(-20, 20, [("FFFFF0C4", 0.0), ("FFFFC870", 1.0)])),
             x=0.0, y=0.0, name="LampHead")
    lamp_glow = E(O, "LampGlow", lx, 446, 260, 260, sc.rgrad(130, [("60FFD9A0", 0.0), ("00FFD9A0", 1.0)]))
    day = box(sc, "StreetDay", vx0, 600, vx1, vy1, F(SCENE_TIMES["day"]), opacity=0.0)
    with sc.minting(sc.d7):
        day.children.insert(0, sc.bind("daylight", 18, sc.conv(0.45, doc=sc.d7), doc=sc.d7))
    plane1 = [day, shower, head, lamp_glow, post, reflect, sheen, street]
    return plane1 + plane0, keep


SCENE_TIMES = gen_scenes.SCENES[SCENE_ID].times


def _rain_reflect_conv(sc: Scene) -> El:
    return sc.conv(1.0 - REFLECT_REST, REFLECT_REST)


# ====================================================================== the window (Plane2)
def window(sc: Scene) -> tuple[list[El], dict[str, El]]:
    d = sc.d
    keep: dict[str, El] = {}
    fx0, fy0, fx1, fy1 = FRAME
    cx, cy = (fx0 + fx1) / 2, (fy0 + fy1) / 2
    frame = d("Shape", _rect_path(d, fx0, fy0, fx1, fy1, cx, cy, 4),
              *[_rect_path(d, *p, cx, cy, name="Pane") for p in PANES],
              d("Fill", sc.d("SolidColor", colorValue="FF2E4C48"), fillRule="evenOdd", name="Fill"),
              x=cx, y=cy, name="WinFrame")
    bevel = multi(sc, "WinBevel", [_rect_path(d, p[0] - 3, p[1] - 3, p[2] + 3, p[3] + 3) for p in PANES],
                  sc.L("50D8CFAE", 2.0))
    clip = d("Shape", *[_rect_path(d, *p, name="Pane") for p in PANES], x=0.0, y=0.0, name="PaneClip")
    gx0, gy0, gx1, gy1 = GLASS
    mist = d("Shape", *[_rect_path(d, *p, name="Pane") for p in PANES],
             d("Fill", d("LinearGradient", *[d("GradientStop", colorValue=a + MIST, position=p)
                                             for a, p in (("18", 0.0), ("26", 0.25), ("50", 0.55), ("8C", 1.0))],
                         startX=0.0, startY=gy0, endX=0.0, endY=gy1), name="Fill"),
             x=0.0, y=0.0, name="Mist")
    # rain on the glass: a fast sheet of fine streaks and slow drips, clipped to the panes (the living
    # room's construction); the `rain` event adds a heavier sheet on top
    with sc.minting(sc.d5):
        sheets = _glass_sheets(sc, "Glass", (("Drips", GLASS_DRIPS), ("Streaks", GLASS_STREAKS)), b"cafeGlass")
        wet = sc.d("Shape", *[_rect_path(sc.d, *p, name="Pane") for p in PANES], sc.F(GLASS_WET[0]),
                   x=0.0, y=0.0, opacity=GLASS_WET[1], name="GlassWet")
        rain = sc.d("Node", sc.bind("rain", 18), sc.d("ClippingShape", sourceId=clip.ref(), name="Clip"), *sheets, wet,
                    x=0.0, y=0.0, opacity=0.0, name="RainGlass")
    shower_sheets = _glass_sheets(sc, "Shower", (("Streaks", SHOWER_STREAKS),), b"cafeShower", long=True)
    shower = d("Node", d("ClippingShape", sourceId=clip.ref(), name="Clip"), *shower_sheets, x=0.0, y=0.0,
               opacity=0.0, name="ShowerGlass")
    keep["shower_glass"] = shower
    # the `wipe` drag (M10): 16 wiped spots cut the mist (holes, `clockwise` fill rule), so a wipe
    # reveals the view as clear glass; two thinner mist rings soften each stroke's edge (`wipe_holes`)
    wipe = wipe_holes(sc, mist)
    return [rain, shower, *wipe, mist, clip, bevel, frame], keep


def wipe_holes(sc: Scene, mist: El) -> list[El]:
    """The café's `wipe` drag (contract v12 numbers, M10 art): wiped spot i (shown while i < `trailN`, at
    (`trailX<i>`, `trailY<i>`)) is a hole of radius WIPE_R[0] in the `Mist` (an `Ellipse` with `isHole`,
    the mist's fill on the `clockwise` rule: the union of the holes is clear glass, overlapping spots
    never compound). Each spot's size is s_i = clamp(trailN - i) x (1 - trailFade^4) and the mist comes
    back over the spots at opacity `trailFade` (`WipeMistBack`): the glass hazes over evenly and the
    holes close late, and at the defaults (`trailN` 0, `trailFade` 1) every hole has no area, so
    the mist draws exactly as before. The soft edge: per ring (r, k) of WIPE_RINGS, the mist again at
    opacity k x (1 - trailFade), holed at r and clipped to the union of the previous radius's discs
    (`WipeClip*`), i.e. a band just inside the stroke's edge. Returns the roots for Plane2 (front first)."""
    d10 = sc.d10
    f = Formulas(d10, sc.vpath)
    grow = []
    for i in range(world_kit.TRAIL_DOTS):
        fade4 = [f.bound("trailFade"), f.op("*"), f.bound("trailFade"), f.op("*"), f.bound("trailFade"), f.op("*"),
                 f.bound("trailFade")]
        toks = [*f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [*f.inp(), f.op("-"), f.val(i)])), f.op("*"),
                *f.fn("max", [f.val(0)], [f.val(1), f.op("-"), *fade4])]
        conv = d10("DataConverterFormula", *toks)
        sc.roots.append(conv)
        grow.append(conv)

    def spots(r: float, hole: bool) -> list[El]:
        out = []
        for i in range(world_kit.TRAIL_DOTS):
            out.append(d10("Ellipse", world_kit._bind(sc, d10, f"trailX{i}", world_kit.KEY_X, None),
                           world_kit._bind(sc, d10, f"trailY{i}", world_kit.KEY_Y, None),
                           world_kit._bind(sc, d10, "trailN", 16, grow[i]),
                           world_kit._bind(sc, d10, "trailN", 17, grow[i]),
                           width=2 * r, height=2 * r, x=0.0, y=0.0, scaleX=0.0, scaleY=0.0,
                           isHole=True if hole else None, name=f"Wipe{i}"))
        return out

    def clockwise(shape: El) -> None:
        for c in shape.children:
            if c.tag == "Fill":
                c.attrs["fillRule"] = "clockwise"

    clockwise(mist)
    mist.children[len(PANES):len(PANES)] = spots(WIPE_R, True)
    grad = next(c for c in mist.children if c.tag == "Fill").children[0]
    out: list[El] = []
    clips: list[El] = []
    outer = WIPE_R
    for j, (r, k) in enumerate(WIPE_RINGS):
        src = d10("Shape", *spots(outer, False), x=0.0, y=0.0, name=f"WipeClip{j}")
        stops = [d10("GradientStop", colorValue=g.attrs["colorValue"], position=g.attrs["position"])
                 for g in grad.children]
        ring = d10("Shape", *[_rect_path(d10, *p, name="Pane") for p in PANES], *spots(r, True),
                   d10("Fill", d10("LinearGradient", *stops, **{a: grad.attrs[a] for a in
                                                                 ("startX", "startY", "endX", "endY")}),
                       fillRule="clockwise", name="Fill"), x=0.0, y=0.0, name="Ring")
        # the ring thins as the mist comes back (k x (1 - trailFade)): under the returning haze a full ring
        # would over-mist the stroke's edge into bright beads
        thin = d10("DataConverterFormula", f.val(k), f.op("-"), f.val(k), f.op("*"), *f.inp())
        sc.roots.append(thin)
        out.append(d10("Node", world_kit._bind(sc, d10, "trailFade", world_kit.KEY_OPACITY, thin),
                       d10("ClippingShape", sourceId=src.ref(), name="Clip"), ring, x=0.0, y=0.0,
                       opacity=k, name=f"WipeRing{j}"))
        clips.append(src)
        outer = r
    # misting back: the mist again, clipped to the wiped spots, at opacity `trailFade` (a haze that
    # thickens evenly while the spots shrink only late, so a fading stroke never beads)
    back = d10("Shape", *[_rect_path(d10, *p, name="Pane") for p in PANES],
               d10("Fill", d10("LinearGradient", *[d10("GradientStop", colorValue=g.attrs["colorValue"],
                                                       position=g.attrs["position"]) for g in grad.children],
                               **{a: grad.attrs[a] for a in ("startX", "startY", "endX", "endY")}), name="Fill"),
               x=0.0, y=0.0, name="Haze")
    haze = d10("Node", world_kit._bind(sc, d10, "trailFade", world_kit.KEY_OPACITY, None),
               d10("ClippingShape", sourceId=clips[0].ref(), name="Clip"), back, x=0.0, y=0.0, opacity=1.0,
               name="WipeMistBack")
    return [haze, *out, *clips]


def _glass_sheets(sc: Scene, prefix: str, specs: tuple, seed: bytes, long: bool = False) -> list[El]:
    """Looping sheets of streaks / drips over the glass, one tile per loop (seamless at any frame)."""
    r_ = random.Random(zlib.crc32(seed))
    gx0, gy0, gx1, gy1 = GLASS
    out = []
    for label, (n, tile, period) in specs:
        kids = []
        for i in range(n):
            x, u = r_.uniform(gx0 + 4, gx1 - 4), r_.uniform(0, tile)
            if label == "Streaks":
                ln = r_.uniform(40, 70) if long else r_.uniform(24, 44)
            else:
                ln = r_.uniform(18, 34)
            for k in range(-2, math.ceil((gy1 - gy0) / tile) + 1):
                y = gy0 + u + k * tile
                if y + tile + ln + 8 < gy0 or y > gy1:
                    continue
                if label == "Streaks":
                    kids.append(sc.S(O, f"{prefix}Streak{i}_{k + 2}", [(x, y), (x - ln * 0.16, y + ln)],
                                     sc.L(STREAK_COLOUR if not long else "A0D4DEEA", 1.6 if not long else 2.2),
                                     closed=False))
                else:
                    kids += [sc.E(O, f"{prefix}Drop{i}_{k + 2}", x, y + ln, 5, 7, sc.F("B0DCE4EC")),
                             sc.S(O, f"{prefix}Trail{i}_{k + 2}", [(x, y), (x + 0.6, y + ln - 3)],
                                  sc.L("50DCE4EC", 2.0), closed=False)]
        sheet = sc.d("Node", *kids, x=0.0, y=0.0, name=f"{prefix}{label}")
        sc.ambient(f"Rain{prefix}{label}", sc.A(f"amb_Rain{prefix}{label}", period, [
            sc.T(sheet, ease=None, y=[(0, 0.0, "linear"), (period, tile, "linear")])], loop=True))
        out.append(sheet)
    return out


# ====================================================================== the back wall (Plane3)
def back_wall(sc: Scene) -> tuple[list[El], dict[str, El]]:
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    keep: dict[str, El] = {}
    # ---- the wall with the window's opening, its wallpaper, the wainscot
    wx0, wy0, wx1, wy1 = -60.0, -40.0, W + 60.0, FLOOR_Y + 64
    cx, cy = (wx0 + wx1) / 2, (wy0 + wy1) / 2
    wall = d("Shape", _rect_path(d, wx0, wy0, wx1, wy1, cx, cy), _rect_path(d, *OPENING, cx, cy, name="Opening"),
             d("Fill", d("LinearGradient", d("GradientStop", colorValue="FF3C2A36", position=0.0),
                         d("GradientStop", colorValue="FF5A3C46", position=0.55),
                         d("GradientStop", colorValue="FF4E3440", position=1.0),
                         startX=0.0, startY=wy0 - cy, endX=0.0, endY=960 - cy), fillRule="evenOdd", name="Fill"),
             x=cx, y=cy, name="Wall")
    stripes = []
    ox0, oy0, ox1, oy1 = OPENING
    for x in range(-40, W + 60, 72):
        if x + 18 > ox0 - 8 and x < ox1 + 8:
            stripes += [_poly(d, [(x, -40), (x + 18, -40), (x + 18, oy0 - 6), (x, oy0 - 6)]),
                        _poly(d, [(x, oy1 + 6), (x + 18, oy1 + 6), (x + 18, 960), (x, 960)])]
        else:
            stripes.append(_poly(d, [(x, -40), (x + 18, -40), (x + 18, 960), (x, 960)]))
    paper = multi(sc, "Wallpaper", stripes, F("12FFE2CC"))
    # small diamonds between the stripes (a storybook wallpaper print)
    dia = []
    for row, y in enumerate(range(60, 940, 110)):
        for x in range(-4 + 36 * (row % 2), W + 60, 72):
            if ox0 - 16 < x < ox1 + 16 and oy0 - 16 < y < oy1 + 16:
                continue
            dia.append(_poly(d, [(x, y - 7), (x + 5, y), (x, y + 7), (x - 5, y)]))
    print_ = multi(sc, "WallpaperPrint", dia, F("18FFD8B0"))
    cornice = d("Node", box(sc, "CorniceBand", -60, -40, W + 60, 34, sc.vgrad(-37, 37, [("FF2A1E26", 0.0),
                                                                                         ("FF3E2C34", 1.0)])),
                box(sc, "CorniceLip", -60, 34, W + 60, 42, F("FF6A4A48")),
                box(sc, "CorniceShade", -60, 42, W + 60, 64, sc.vgrad(-11, 11, [("50140C12", 0.0), ("00140C12", 1.0)])),
                x=0.0, y=0.0, name="Cornice")
    rail = box(sc, "Rail", -60, 944, W + 60, 958, sc.vgrad(-7, 7, [("FF8A6448", 0.0), ("FF5A3E30", 1.0)]))
    wains = box(sc, "Wainscot", -60, 958, W + 60, FLOOR_Y + 64, sc.vgrad(-166, 166, [("FF4A3028", 0.0),
                                                                                    ("FF34221E", 1.0)]))
    panels = multi(sc, "WainscotPanel", [_rect_path(d, x, 990, x + 128, 1180, r=4) for x in range(330, 840, 160)],
                   sc.L("38000000", 4.0))
    panel_hi = multi(sc, "WainscotPanelHi", [_rect_path(d, x + 3, 993, x + 125, 1177, r=3)
                                              for x in range(330, 840, 160)], sc.L("18FFE0C0", 2.0))
    # the opening's reveal: a shadow under the lintel and down the left jamb (the key light is up left)
    reveal = d("Node",
               d("Shape", _rect_path(d, ox0, oy0, ox1, oy0 + 16, 0, 0),
                 sc.vgrad(oy0, oy0 + 16, [("80140C14", 0.0), ("00140C14", 1.0)]), x=0.0, y=0.0, name="RevealTop"),
               d("Shape", _rect_path(d, ox0, oy0, ox0 + 12, oy1, 0, 0),
                 hgrad(sc, ox0, ox0 + 12, [("60140C14", 0.0), ("00140C14", 1.0)]), x=0.0, y=0.0, name="RevealLeft"),
               x=0.0, y=0.0, name="WinReveal")
    sill = d("Node", box(sc, "SillTop", 286, 772, 794, 790, sc.vgrad(-9, 9, [("FFD2B28A", 0.0), ("FFA88462", 1.0)]),
                         r=3),
             box(sc, "SillLip", 280, 788, 800, 798, F("FF8A6448"), r=3), x=0.0, y=0.0, name="Sill")
    sill_sh = box(sc, "SillShadow", 280, 798, 800, 816, sc.vgrad(-9, 9, [("60140C12", 0.0), ("00140C12", 1.0)]))
    # the lamp's pool on the wall takes the key light's colour (contract v7 lightKey, as the living room)
    pool = _wall_pool(sc)

    # ---- the counter (left)
    counter = box(sc, "Counter", -60, COUNTER_TOP + 24, 318, FLOOR_Y + 40,
                  sc.vgrad(-128, 128, [("FF5E3C2C", 0.0), ("FF3E2620", 1.0)]))
    cpanels = multi(sc, "CounterPanel", [_rect_path(d, x, 1050, x + 100, 1196, r=4) for x in (-30, 86, 202)],
                    sc.L("40000000", 3.6))
    crail = d("Node", S(O, "RailBar", [(-60, 1172), (300, 1172)], L("FFC89A50", 6.0), closed=False),
              *[box(sc, f"RailPost{i}", x - 3, 1172, x + 3, 1206, F("FFA87A3C")) for i, x in enumerate((40, 180, 290))],
              x=0.0, y=0.0, name="CounterRail")
    ctop = d("Node", box(sc, "CounterSlab", -60, COUNTER_TOP, 326, COUNTER_TOP + 26,
                         sc.vgrad(-13, 13, [("FFE4D4BC", 0.0), ("FFC2AC90", 1.0)]), r=4),
             box(sc, "CounterSlabEdge", -60, COUNTER_TOP + 20, 326, COUNTER_TOP + 30, F("FF9A8068"), r=3),
             x=0.0, y=0.0, name="CounterTop")
    # ---- the shelf above it: coffee jars, stacked cups, a little plant
    items = []
    for i, (x0, h, w_) in enumerate(((36, 58, 40), (86, 44, 36))):
        items += [box(sc, f"ShelfItemBeans{i}", x0 + 3, 786 - h * 0.62, x0 + w_ - 3, 784, F("FF5A3A28"), r=4),
                  box(sc, f"ShelfItemJar{i}", x0, 786 - h, x0 + w_, 786, F("40C8D8E0"), L("90E0E8F0", 2.0), r=6),
                  box(sc, f"ShelfItemLid{i}", x0 + 4, 780 - h, x0 + w_ - 4, 788 - h, F("FFB08048"), r=2)]
    for k in range(3):
        y = 786 - 12 * (k + 1)
        items.append(d("Shape", d("PointsPath", *[d("StraightVertex", x=float(px), y=float(py))
                                                  for px, py in ((144, y), (190, y), (186, y + 12), (148, y + 12))],
                                  isClosed=True, name="Path"),
                       F("FFEEE4D6"), L("FF9A8A7A", 1.4), x=0.0, y=0.0, name=f"ShelfItemCup{k}"))
    items.append(box(sc, "ShelfItemPot", 228, 764, 262, 786, F("FFB8724A"), r=3))
    for k, (ang, ln) in enumerate(((-2.3, 34), (-1.8, 42), (-1.3, 38), (-0.9, 30))):
        tx, ty = 245 + math.cos(ang) * ln, 764 + math.sin(ang) * ln
        items.append(S(O, f"ShelfItemLeaf{k}", [(245, 764), (tx - 4, ty + 6), (tx, ty, "c"), (tx + 6, ty + 4)],
                       F("FF4E8A5A")))
    shelf = d("Node", *items,
              box(sc, "ShelfBoard", 20, 786, 304, 798, sc.vgrad(-6, 6, [("FF8A6448", 0.0), ("FF5E4232", 1.0)])),
              box(sc, "ShelfShade", 20, 798, 304, 812, sc.vgrad(-7, 7, [("50140C12", 0.0), ("00140C12", 1.0)])),
              x=0.0, y=0.0, name="Shelf")

    # ---- the espresso machine (its steam and its light's glow are drawn in front of the bowl)
    machine, light_on, steam, esp_parts = _espresso(sc)
    keep.update(esp_parts)
    # ---- the goldfish bowl (the fish NPC swims between its back and its front)
    bowl_back, bowl_front, coaster = _bowl(sc)

    # ---- the door (right) with its bell and wreath
    door, door_parts = _door(sc)
    keep.update(door_parts)

    # ---- December: string lights along the top of the opening (contract v12 `festive`)
    pts = []
    for i in range(21):
        x = OPENING[0] - 8 + i * (OPENING[2] - OPENING[0] + 16) / 20
        t = (i % 10) / 10
        pts.append((round(x, 1), round(OPENING[1] + 6 + 34 * math.sin(math.pi * t), 1)))
    lights = world_kit.festive_lights(sc, sc.d9, pts, ("FFFFD27A", "FFFF8A7A"))
    content = [lights, steam, light_on, *door, bowl_front, "FISH", bowl_back, coaster, machine, ctop, crail, cpanels,
               counter, shelf, sill, sill_sh, reveal, pool, cornice, rail, panel_hi, panels, wains, print_, paper, wall]
    return content, keep


def _wall_pool(sc: Scene) -> El:
    """The pendant's warm pool on the wall: two key-coloured radial fills fading to clear (bound to
    `lightKey`: a bound colour also sets the alpha, so each fill's falloff is its gradient opacity)."""
    d = sc.d
    key = gen_scenes.SCENES[SCENE_ID].key
    x, y, r = WALL_POOL_AT
    fills = []
    for op, share in WALL_POOL:
        g = rad(d, 0, 0, r * share, [(key, 0.0), ("00" + key[2:], 1.0)])
        g.attrs["opacity"] = op
        with sc.minting(sc.d5):
            g.children[0].children.append(sc.bind("lightKey", 38))
        fills.append(d("Fill", g, name="Fill"))
    return d("Shape", ellipse(d, 2 * r, 2 * r), *fills, x=x, y=y, name="WallWarmth")


def _espresso(sc: Scene) -> tuple[El, El, El, dict[str, El]]:
    """The copper espresso machine (node `Espresso` at its centre, children relative to it), its
    light's glow (`EspLightOn`, the event blinks it) and its steam puffs (`Steam`, at the wand's tip)."""
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    cx, cy = ESPRESSO
    P = (cx, cy)

    def rel(e: El) -> El:
        """A shape drawn at artboard coordinates, moved into the machine's frame."""
        e.attrs["x"] = float(e.attrs["x"]) - cx
        e.attrs["y"] = float(e.attrs["y"]) - cy
        return e

    body = d("Shape", _rect_path(d, 80, 890, 180, SIT_Y - 6, cx, cy, 10),
             sc.vgrad(890 - cy, SIT_Y - 6 - cy, [("FFD8946A", 0.0), ("FFA8623E", 0.6), ("FF7A4630", 1.0)]),
             L("FF4A2A22", 2.0), x=0.0, y=0.0, name="EspBody")
    dome = E(P, "EspDome", cx, 890, 92, 46, sc.vgrad(-23, 23, [("FFE8B080", 0.0), ("FFA8623E", 1.0)]),
             L("FF4A2A22", 2.0))
    finial = [E(P, "EspFinialBall", cx, 858, 14, 14, F("FFE8C890"), L("FF4A2A22", 1.6)),
              rel(box(sc, "EspFinialStem", cx - 3, 860, cx + 3, 872, F("FFC8A070")))]
    gauge = [S(P, "EspNeedle", [(cx, 918), (cx + 7, 912)], L("FFB0303A", 1.8), closed=False),
             E(P, "EspGaugeFace", cx, 918, 26, 26, F("FFF4ECDC"), L("FF4A2A22", 2.0))]
    group = rel(box(sc, "EspGroup", 100, 950, 160, 962, F("FF3A2C2A"), r=3))
    handle = S(P, "EspHandle", [(104, 958), (66, 968)], L("FF3A2420", 7.0), closed=False)
    tray = rel(box(sc, "EspTray", 84, SIT_Y - 14, 176, SIT_Y - 4, F("FF3A3238"), r=2))
    cup = d("Shape", _poly(d, [(119 - cx, 972 - cy), (141 - cx, 972 - cy), (138 - cx, 990 - cy), (122 - cx, 990 - cy)]),
            F("FFF2E8DC"), L("FF9A8A7A", 1.4), x=0.0, y=0.0, name="EspCup")
    wand = S(P, "EspWand", [(180, 924), (196, 930), (202, 954), (206, 978)], L("FFC8CCD4", 4.0), closed=False)
    light = E(P, "EspLight", 166, 904, 9, 9, F("FF8A3A30"), L("FF4A2A22", 1.2))
    machine = d("Node", *finial, *gauge, light, group, handle, cup, wand, tray, dome, body, x=cx, y=cy,
                name="Espresso")
    light_on = d("Node", E(O, "EspLightBulb", 0, 0, 9, 9, F("FFFF5A3C")),
                 E(O, "EspLightHalo", 0, 0, 34, 34, sc.rgrad(17, [("A0FF7A50", 0.0), ("00FF7A50", 1.0)])),
                 x=166.0, y=904.0, opacity=0.0, name="EspLightOn")
    # steam puffs (the event): they rise off the wand's tip and drift up and right as they grow
    puffs = [E(O, f"SteamPuff{i}", 0, 0, 44, 38, sc.rgrad(22, [("F0F6F2EC", 0.0), ("A0F6F2EC", 0.45),
                                                                 ("00F6F2EC", 1.0)]), opacity=0.0)
             for i in range(6)]
    steam = d("Node", *puffs, x=206.0, y=976.0, name="Steam")
    return machine, light_on, steam, {"esp_machine": machine, "esp_light": light_on,
                                      **{f"puff{i}": p for i, p in enumerate(puffs)}}


def _bowl(sc: Scene) -> tuple[El, El, El]:
    """The goldfish bowl on the counter: (its back: water, gravel, weed; its front: glass, rim, shine;
    its coaster). The fish swims between the back and the front."""
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    bx, by, br = BOWL
    inner = br - 2
    dx = math.sqrt(inner * inner - (WATER_Y - by) ** 2)
    # the waterline, then the arc below it from its right end, around the bottom, back to its left end
    pts: list = [(bx - dx, WATER_Y, "c"), (bx + dx, WATER_Y, "c")]
    ang0 = math.atan2(WATER_Y - by, dx)
    span = math.pi - 2 * ang0
    for k in range(1, 12):
        a = ang0 + span * k / 12
        pts.append((round(bx + inner * math.cos(a), 2), round(by + inner * math.sin(a), 2)))
    water = d("Shape", smooth_path(d, [(p[0] - bx, p[1] - by, *p[2:]) for p in pts]),
              sc.vgrad(WATER_Y - by, inner, [("A058A0B8", 0.0), ("C03A6E88", 1.0)]), x=bx, y=by, name="BowlWater")
    gravel = [E(O, f"BowlGravel{i}", bx + gx, by + 40 + gy, 9, 6, F(c))
              for i, (gx, gy, c) in enumerate(((-22, 2, "FFC89A6A"), (-12, 6, "FF8A6A9A"), (-2, 4, "FFD8C08A"),
                                               (9, 6, "FF6A8AA0"), (19, 3, "FFC88A7A"), (-28, -2, "FF8AA06A"),
                                               (26, -2, "FFD8C08A"), (4, 0, "FFA07A5A")))]
    weed = [S(O, f"BowlWeed{i}", [(bx + x0, by + 40), (bx + x0 + 6 * s, by + 22), (bx + x0 - 2 * s, by + 6)],
              L("FF4E8A5A", 3.0), closed=False) for i, (x0, s) in enumerate(((-20, 1), (-14, -1)))]
    back_glass = E(O, "BowlBackGlass", bx, by, 2 * br, 2 * br, F("1CC8E0F0"))
    back = d("Node", *gravel, *weed, water, back_glass, x=0.0, y=0.0, name="BowlBack")
    rim_y = by - math.sqrt(br * br - (br * 0.62) ** 2)
    front = d("Node",
              S(O, "BowlShine", [(bx - 38, by - 20), (bx - 30, by - 36), (bx - 16, by - 44)], L("90FFFFFF", 3.4),
                closed=False),
              E(O, "BowlShineDot", bx + 30, by + 22, 6, 9, F("70FFFFFF"), rotation=-0.5),
              S(O, "BowlWaterline", [(bx - dx + 2, WATER_Y), (bx + dx - 2, WATER_Y)], L("70D8F0F8", 2.0), closed=False),
              E(O, "BowlRim", bx, rim_y, br * 1.24, 12, L("C0E0EEF6", 2.4)),
              E(O, "BowlGlass", bx, by, 2 * br, 2 * br, L("B0D8E8F0", 2.4)),
              x=0.0, y=0.0, name="BowlFront")
    coaster = E(O, "BowlCoaster", bx, SIT_Y - 2, 86, 12, F("FF6A4834"))
    return back, front, coaster


def _door(sc: Scene) -> tuple[list[El], dict[str, El]]:
    """The café door (right): its casing, the cold light behind it (`DoorGap`, shown while it opens),
    the leaf drawn around its hinge (`DoorLeaf`: the event's scaleX < 1 opens a crack at its free left
    edge) with its glass, lace curtain (the gust ruffles it), knob and the December wreath, and the
    bell on its bracket."""
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    x0, y0, x1, y1 = DOOR
    hx, hy = DOOR_HINGE
    Hg = (hx, hy)

    def rel(e: El, ox: float = hx, oy: float = hy) -> El:
        e.attrs["x"] = float(e.attrs["x"]) - ox
        e.attrs["y"] = float(e.attrs["y"]) - oy
        return e

    casing = d("Node", box(sc, "CasingFrame", x0 - 16, y0 - 16, x1 + 16, y1, F("FF3E2A26"), r=3),
               box(sc, "CasingInner", x0 - 4, y0 - 4, x1 + 4, y1, F("FF1A1418")),
               x=0.0, y=0.0, name="DoorCasing")
    gap = box(sc, "DoorGap", x0, y0, x1, y1, hgrad(sc, -(x1 - x0) / 2, (x1 - x0) / 2,
                                                   [("FF9CB8DC", 0.0), ("FF6A88B4", 0.35), ("FF3A4E78", 1.0)]),
              opacity=0.0)
    leaf_body = d("Shape", _rect_path(d, x0, y0, x1, y1, hx, hy, 3),
                  sc.vgrad(y0 - hy, y1 - hy, [("FF34605A", 0.0), ("FF264844", 1.0)]), L("FF1A2A28", 2.0),
                  x=0.0, y=0.0, name="LeafBody")
    gx0, gy0, gx1, gy1 = x0 + 22, y0 + 26, x1 - 22, y0 + 262
    gcx = (gx0 + gx1) / 2
    glass = d("Shape", _rect_path(d, gx0, gy0, gx1, gy1, hx, hy, 4),
              sc.vgrad(gy0 - hy, gy1 - hy, [("FF5A7898", 0.0), ("FF34445E", 1.0)]), L("FF1A2A28", 3.0),
              x=0.0, y=0.0, name="LeafGlass")
    glow = E(Hg, "LeafGlassGlow", gx1 - 30, gy0 + 40, 90, 90, sc.rgrad(45, [("60FFE2A0", 0.0), ("00FFE2A0", 1.0)]))
    bar = d("Shape", _rect_path(d, gcx - 3, gy0, gcx + 3, gy1, hx, hy), F("FF264844"), x=0.0, y=0.0,
            name="LeafGlassBar")
    # a lace café curtain over the lower half of the glass, hung from a rod (its node pivots at the rod)
    cy0 = gy0 + 116
    ch = gy1 - cy0 - 4
    lace: list = [(gx0 + 2 - gcx, 0.0, "c"), (gx1 - 2 - gcx, 0.0, "c")]
    for k in range(6, -1, -1):
        lace.append((gx0 + 2 + (gx1 - gx0 - 4) * k / 6 - gcx, ch - (6 if k % 2 else 0)))
    lace_shape = d("Shape", smooth_path(d, lace), sc.vgrad(0, ch, [("F0EEE4D2", 0.0), ("E0D8CCB8", 1.0)]),
                   L("FFB8A890", 1.2), x=0.0, y=0.0, name="CurtainLace")
    folds = [S(O, f"CurtainFold{k}", [(x, 4), (x + 2, ch - 10)], L("40A89880", 2.0), closed=False)
             for k, x in enumerate((-36, 0, 36))]
    curtain = d("Node", *folds, lace_shape, x=gcx - hx, y=cy0 - hy, name="DoorCurtain")
    rod = rel(box(sc, "CurtainRod", gx0 - 4, cy0 - 4, gx1 + 4, cy0 + 2, F("FFC89A50"), r=2))
    panels = d("Shape", _rect_path(d, x0 + 22, y0 + 290, x1 - 22, y0 + 440, hx, hy, 4),
               _rect_path(d, x0 + 22, y0 + 462, x1 - 22, y1 - 40, hx, hy, 4), L("50000000", 3.4),
               x=0.0, y=0.0, name="LeafPanels")
    knob = d("Node", E(O, "KnobPlate", 0, 4, 14, 40, F("FFA87A3C")),
             E(O, "KnobBall", 0, 0, 18, 18, sc.rgrad(9, [("FFF4D890", 0.0), ("FFB88440", 1.0)], cx=-3, cy=-3)),
             x=x0 + 18 - hx, y=960.0 - hy, name="DoorKnob")
    kick = rel(box(sc, "KickPlate", x0 + 6, y1 - 46, x1 - 6, y1 - 20, F("FFB08848"), r=2))
    # December: the wreath (opacity `festive`) with its little lights (the kit's twinkle)
    wx, wy, wr = WREATH
    Wr = (wx, wy)
    leaves = [E(Wr, f"WreathLeaf{k}", wx + wr * math.cos(a), wy + wr * math.sin(a), 22, 12,
                F("FF3E7A4A" if k % 2 else "FF2E6040"), rotation=round(a + math.pi / 2, 4))
              for k, a in enumerate(2 * math.pi * j / 14 for j in range(14))]
    berries = [E(Wr, f"WreathBerry{k}", wx + (wr - 2) * math.cos(a), wy + (wr - 2) * math.sin(a), 8, 8, F("FFC8384A"))
               for k, a in enumerate((0.4, 1.9, 3.3, 4.6, 5.6))]
    bow = [S(Wr, "BowTails", [(wx - 8, wy + wr + 2), (wx - 12, wy + wr + 26, "c"), (wx, wy + wr + 6),
                              (wx + 12, wy + wr + 26, "c"), (wx + 8, wy + wr + 2)], F("FFA82A3A")),
           S(Wr, "BowLoopL", [(wx, wy + wr), (wx - 18, wy + wr - 10), (wx - 16, wy + wr + 8)], F("FFC8384A")),
           S(Wr, "BowLoopR", [(wx, wy + wr), (wx + 18, wy + wr - 10), (wx + 16, wy + wr + 8)], F("FFC8384A"))]
    ring = E(Wr, "WreathRing", wx, wy, 2 * wr, 2 * wr, L("FF2A5236", 14.0))
    pts = [(round(wx + (wr + 2) * math.cos(a), 1), round(wy + (wr + 2) * math.sin(a), 1))
           for a in (2 * math.pi * k / 6 - math.pi / 2 for k in range(7))]
    wl = world_kit.festive_lights(sc, sc.d9, pts, ("FFFFE08A", "FFFF9A8A"))
    wl.attrs.update(name="WreathLights", x=float(-wx), y=float(-wy))   # its points are artboard px
    sc.anims[-1].attrs["name"] = "amb_festiveWreath"
    sc.layers[-1].attrs["name"] = "FestiveTwinkleWreath"
    wreath = d("Node", sc.bind("festive", 18, doc=sc.d9), wl, *bow, *berries, *leaves, ring,
               x=wx - hx, y=wy - hy, opacity=0.0, name="Wreath")
    leaf = d("Node", wreath, knob, kick, rod, curtain, bar, glow, glass, panels, leaf_body, x=hx, y=hy,
             name="DoorLeaf")
    # the bell on its curly bracket (top left of the casing), pivoting where it hangs
    bpx, bpy = BELL_PIVOT
    bracket = S(O, "BellBracket", [(x0 - 12, y0 - 10), (bpx - 4, y0 - 12), (bpx + 2, y0 - 4), (bpx, bpy - 2)],
                L("FF2A2228", 3.0), closed=False)
    B = (bpx, bpy)
    bell = d("Node",
             E(B, "BellShine", bpx - 4, bpy + 12, 3, 8, F("90FFFFFF")),
             S(B, "BellBody", [(bpx - 3, bpy + 2), (bpx + 3, bpy + 2), (bpx + 9, bpy + 14), (bpx + 12, bpy + 24, "c"),
                               (bpx - 12, bpy + 24, "c"), (bpx - 9, bpy + 14)],
               sc.vgrad(-11, 11, [("FFF0CC70", 0.0), ("FFB8862E", 1.0)]), L("FF5A3A1A", 1.6)),
             E(B, "BellClapper", bpx, bpy + 27, 7, 7, F("FF6A4A2A")),
             x=bpx, y=bpy, name="Bell")
    return [bell, bracket, leaf, gap, casing], {"door_leaf": leaf, "door_gap": gap, "curtain": curtain,
                                                "bell": bell}


# ====================================================================== the room (Plane4) and foreground (Plane5)
def room(sc: Scene) -> tuple[list[El], dict[str, El]]:
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    keep: dict[str, El] = {}
    # ---- the checker floor in perspective (vanishing point at the window's middle)
    vx, vy = 540.0, 640.0
    depth = FLOOR_Y - vy
    tile = 60.0
    rows = [FLOOR_Y]
    i = 1
    while rows[-1] < H + 80:
        rows.append(vy + depth / (1 - i * tile / depth))
        i += 1

    def at(xb: float, y: float) -> float:
        return vx + (xb - vx) * (y - vy) / depth

    tiles = []
    for r_, (ya, yb) in enumerate(zip(rows, rows[1:])):
        for k in range(-30, 31):
            if (k + r_) % 2:
                continue
            xa0, xa1 = vx + k * tile, vx + (k + 1) * tile
            q = [(at(xa0, ya), ya), (at(xa1, ya), ya), (at(xa1, yb), yb), (at(xa0, yb), yb)]
            if max(p[0] for p in q) < -80 or min(p[0] for p in q) > W + 80:
                continue
            tiles.append(_poly(d, [(round(x, 1), round(y, 1)) for x, y in q]))
    floor = box(sc, "Floor", -80, FLOOR_Y - 10, W + 80, H + 80, sc.vgrad(-(H + 90 - FLOOR_Y) / 2, (H + 90 - FLOOR_Y) / 2,
                                                                         [("FFAC9E88", 0.0), ("FFC8BAA2", 1.0)]))
    tiles_s = multi(sc, "FloorTiles", tiles, F("FF76666A"))
    shade = box(sc, "FloorShade", -80, FLOOR_Y - 10, W + 80, H + 80,
                sc.vgrad(-(H + 90 - FLOOR_Y) / 2, (H + 90 - FLOOR_Y) / 2,
                         [("90241820", 0.0), ("30241820", 0.35), ("00241820", 0.7), ("40241820", 1.0)]))
    baseboard = d("Node", box(sc, "BoardL", 318, FLOOR_Y - 18, 838, FLOOR_Y + 2, F("FF2E1E1A")),
                  box(sc, "BoardR", 1046, FLOOR_Y - 18, W + 80, FLOOR_Y + 2, F("FF2E1E1A")),
                  x=0.0, y=0.0, name="Baseboard")
    cshadow = box(sc, "CounterShadow", -80, FLOOR_Y - 4, 340, FLOOR_Y + 26,
                  sc.vgrad(-15, 15, [("70140C10", 0.0), ("00140C10", 1.0)]))
    dshadow = box(sc, "DoorShadow", 830, FLOOR_Y - 4, 1060, FLOOR_Y + 18,
                  sc.vgrad(-11, 11, [("60140C10", 0.0), ("00140C10", 1.0)]))
    pool = E(O, "FloorPool", 230, 1300, 560, 560, sc.rgrad(280, [("40FFD9A0", 0.0), ("00FFD9A0", 1.0)]),
             scaleY=0.24)
    # ---- the pendant lamp (the key light) over the counter
    px, py = PENDANT
    cord = S(O, "PendantCord", [(px, -60), (px, py - 28)], L("FF1E1A1E", 3.0), closed=False)
    shade_ = d("Node",
               E(O, "PendantBulb", px, py + 26, 34, 16, F("FFFFF2CC")),
               S(O, "PendantShade", [(px - 74, py + 24, "c"), (px - 64, py + 2), (px - 30, py - 22), (px, py - 28),
                                     (px + 30, py - 22), (px + 64, py + 2), (px + 74, py + 24, "c")],
                 sc.vgrad(-26, 26, [("FF4E8070", 0.0), ("FF2E5448", 1.0)]), L("FF1A2A24", 2.0)),
               S(O, "PendantRim", [(px - 74, py + 24), (px + 74, py + 24)], L("FFFFE2A8", 3.0), closed=False),
               E(O, "PendantCap", px, py - 30, 18, 10, F("FF1E1A1E")),
               x=0.0, y=0.0, name="Pendant")
    cone = S(O, "PendantCone", [(px - 70, py + 26, "c"), (px + 70, py + 26, "c"), (px + 170, COUNTER_TOP, "c"),
                                (px - 170, COUNTER_TOP, "c")],
             sc.vgrad(-(COUNTER_TOP - py) / 2, (COUNTER_TOP - py) / 2, [("34FFE2A8", 0.0), ("00FFE2A8", 1.0)]))
    glow = E(O, "PendantGlow", px, py + 30, 360, 360, sc.rgrad(180, [("70FFDCA0", 0.0), ("00FFDCA0", 1.0)]))
    # ---- the table, the cup, the chair
    tx, ty = TABLE
    chair = d("Node",
              S(O, "ChairBack", [(1000, 1150), (996, 1010), (1010, 960), (1060, 950), (1092, 990), (1090, 1150)],
                L("FF4A3026", 9.0), closed=False),
              S(O, "ChairSpindle", [(1022, 1140), (1030, 990)], L("FF4A3026", 5.0), closed=False),
              S(O, "ChairSpindle2", [(1060, 1140), (1062, 984)], L("FF4A3026", 5.0), closed=False),
              E(O, "ChairSeat", 1040, 1150, 150, 34, sc.vgrad(-17, 17, [("FF6A4434", 0.0), ("FF4A3026", 1.0)])),
              S(O, "ChairLegs", [(984, 1160), (976, 1330)], L("FF4A3026", 7.0), closed=False),
              S(O, "ChairLegs2", [(1096, 1160), (1104, 1330)], L("FF4A3026", 7.0), closed=False),
              S(O, "ChairLegs3", [(1040, 1166), (1040, 1312)], L("FF3A2420", 6.0), closed=False),
              x=0.0, y=0.0, name="Chair")
    tshadow = E(O, "TableShadow", tx, 1304, 240, 40, F("40140C10"))
    tbase = E(O, "TableBase", tx, 1296, 120, 22, F("FF2A2228"))
    stem = box(sc, "TableStem", tx - 7, ty + 20, tx + 7, 1296, F("FF2A2228"))
    edge = E(O, "TableEdge", tx, ty + 8, 236, 56, F("FFA89880"))
    top = E(O, "TableTop", tx, ty, 236, 56, sc.vgrad(-28, 28, [("FFF2EAE0", 0.0), ("FFD4C8B8", 1.0)]),
            L("FF8A7A6A", 1.6))
    cx, cy = CUP
    saucer = E(O, "Saucer", cx, cy + 16, 74, 16, F("FFF2EADE"), L("FF9A8A7A", 1.4))
    cup = d("Node",
            E(O, "CupCoffee", cx, cy - 18, 40, 9, F("FF4A2A1E")),
            S(O, "CupHandle", [(cx + 20, cy - 10), (cx + 32, cy - 6), (cx + 30, cy + 4), (cx + 18, cy + 6)],
              L("FFF2E8DC", 4.0), closed=False),
            d("Shape", _poly(d, [(cx - 22, cy - 20), (cx + 22, cy - 20), (cx + 18, cy + 4), (cx + 12, cy + 12),
                                 (cx - 12, cy + 12), (cx - 18, cy + 4)]),
              sc.vgrad(cy - 20, cy + 12, [("FFF6EEE2", 0.0), ("FFD8CCBC", 1.0)]), L("FF9A8A7A", 1.4),
              x=0.0, y=0.0, name="CupBody"),
            x=0.0, y=0.0, name="Cup")
    band = d("Shape", _poly(d, [(cx - 20, cy - 8), (cx + 20, cy - 8), (cx + 19, cy - 2), (cx - 19, cy - 2)]),
             F(gen_scenes.SCENES[SCENE_ID].accent), x=0.0, y=0.0, name="CupBand")
    cup.children.insert(2, band)
    wisps = []
    for i, dx in enumerate((-8, 4, 14)):
        wisps.append(S(O, f"CupWisp{i}", [(cx + dx, cy - 24), (cx + dx + 6, cy - 44), (cx + dx - 4, cy - 66),
                                          (cx + dx + 4, cy - 88)], L("70F4F0EA", 4.0), closed=False, opacity=0.0))
    steam = d("Node", *wisps, x=0.0, y=0.0, name="CupSteam")
    n = CUP_STEAM_FRAMES
    tracks = []
    for i, wsp in enumerate(wisps):
        y0 = float(wsp.attrs["y"])
        tracks.append(sc.T(wsp, ease=None, **wisp_keys(y0, i * n // 3, n)))
    sc.ambient("CupSteam", sc.A("amb_cupSteam", n, tracks, loop=True))
    # ---- the door's cold light spilling on the floor, the leaves the gust blows in (doorbell event)
    spill = d("Shape", _poly(d, [(852, FLOOR_Y), (900, FLOOR_Y), (1060, 1640), (700, 1640)]),
              sc.vgrad(FLOOR_Y, 1640, [("4C9CB8DC", 0.0), ("009CB8DC", 1.0)]), x=0.0, y=0.0, opacity=0.0,
              name="DoorSpill")
    gust = []
    for i, (c, sz) in enumerate((("FFC87A3A", 16), ("FFA8622E", 13), ("FFD89A4A", 11))):
        lf = S(O, f"LeafShape{i}", [(-sz, 0), (0, -sz * 0.45), (sz, 0, "c"), (0, sz * 0.45)], F(c), origin=O)
        gust.append(d("Node", lf, x=870.0, y=FLOOR_Y + 4.0, opacity=0.0, name=f"GustLeaf{i}"))
    keep.update(door_spill=spill, **{f"gust{i}": g for i, g in enumerate(gust)})
    content = [*gust, spill, steam, cup, saucer, top, edge, stem, tbase, tshadow, chair, glow, cone, shade_, cord,
               pool, cshadow, dshadow, baseboard, shade, tiles_s, floor]
    return content, keep


def wisp_keys(y0: float, ph: int, n: int) -> dict[str, list]:
    """A steam wisp's loop over `n` frames from frame `ph` on: it rises 30 px in 120 frames, fading in
    then out, and waits hidden for the rest (piecewise linear, keyed at its breaks, seamless at `n`)."""
    def at(u: float) -> tuple[float, float]:
        if u < 40:
            return y0 + 4 - 30 * u / 120, 0.75 * u / 40
        if u < 120:
            return y0 + 4 - 30 * u / 120, 0.75 * (120 - u) / 80
        return y0 - 26, 0.0
    frames = sorted({(ph + u) % n for u in (0, 40, 120)} | {0, n})
    ys, ops = [], []
    for f in frames:
        u = (f - ph) % n
        y, o = at(u)
        mode = "hold" if u >= 120 else "linear"
        ys.append((f, round(y, 3), mode))
        ops.append((f, round(o, 4), mode))
    return {"y": ys, "opacity": ops}


def foreground(sc: Scene) -> list[El]:
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    px, py = 90.0, 1800.0
    leaves = []
    for k, (ang, ln, w) in enumerate(((-2.5, 260, 70), (-2.0, 320, 84), (-1.55, 340, 90), (-1.1, 300, 80),
                                      (-0.7, 230, 64), (-2.9, 190, 56))):
        tx, ty = px + math.cos(ang) * ln, py - 80 + math.sin(ang) * ln
        mx, my = px + math.cos(ang) * ln * 0.55, py - 80 + math.sin(ang) * ln * 0.55
        nx, ny = -math.sin(ang) * w, math.cos(ang) * w
        leaves.append(S(O, f"PlantLeaf{k}", [(px, py - 80), (mx + nx, my + ny), (tx, ty, "c"), (mx - nx, my - ny)],
                        sc.vgrad(-120, 120, [("FF4E8A5E", 0.0), ("FF24503A", 1.0)]), L("FF163222", 3.0)))
        leaves.append(S(O, f"PlantVein{k}", [(px, py - 80), (mx, my), (tx, ty)], L("FF1C3A28", 3.0), closed=False))
    pot = S(O, "PlantPot", [(px - 110, py - 90, "c"), (px + 110, py - 90, "c"), (px + 86, H + 60, "c"),
                            (px - 86, H + 60, "c")], sc.vgrad(-100, 100, [("FFC8784E", 0.0), ("FF8A4A30", 1.0)]),
              L(INK, 3.0))
    pot_rim = box(sc, "PlantPotRim", px - 120, py - 104, px + 120, py - 76, F("FFB06A44"), L(INK, 3.0), r=6)
    plant = d("Node", pot_rim, pot, *leaves[::-1], x=0.0, y=0.0, name="Plant")
    ivy = []
    for s_, (x0, ln) in enumerate(((990, 300), (1040, 380), (1086, 250))):
        pts = [(x0 + 18 * math.sin(t * 2.6 + s_), -60 + t * ln) for t in (0, 0.25, 0.5, 0.75, 1.0)]
        ivy.append(S(O, f"IvyVine{s_}", pts, L("FF2A4A2E", 4.0), closed=False))
        for k in range(1, 5):
            x, y = pts[k]
            side = -1 if k % 2 else 1
            ivy.append(E(O, f"IvyLeaf{s_}_{k}", x + side * 12, y, 30, 20, F("FF3E7448" if k % 2 else "FF2E6040"),
                         L("FF163222", 2.0), rotation=round(0.6 * side, 3)))
    ivy_n = d("Node", *ivy, x=0.0, y=0.0, name="Ivy")
    return [ivy_n, plant]


# ====================================================================== the fish (NPC, contract v12)
def fish_npc(sc: Scene, hit: El) -> El:
    """The goldfish in the bowl: node `FishNpc` at its path (npcX: across the bowl), with every NPC
    state on the `Npc` layer (scene_npc.npc_layer). Faces right while npcLook >= 0, left while < 0
    (`FishFacing`'s scaleX); notice turns it to the viewer (front view) at npcLook 0."""
    d = sc.d
    S, E, F = sc.S, sc.E, sc.F
    L = sc.L
    rig = Rig(sc)
    def body_g() -> El:
        return sc.vgrad(-10, 10, [("FFF7A456", 0.0), ("FFE0702E", 1.0)])
    fin = "E8F8BC7E"
    line = "FF8A3A1C"
    # ---- profile (faces right)
    tail_shape = S((-14.0, 0.0), "FishTailFin", [(-14, 0, "c"), (-26, -12), (-32, -7), (-27, 0, "c"), (-32, 7),
                                                  (-26, 12)], F(fin), L(line, 1.2))
    tail = d("Node", tail_shape, x=-14.0, y=0.0, name="FishTail")
    dorsal_shape = S((-2.0, -8.0), "FishDorsalFin", [(-9, -7, "c"), (-3, -17), (6, -8, "c")], F(fin), L(line, 1.2))
    dorsal = d("Node", dorsal_shape, x=-2.0, y=-8.0, name="FishDorsal")
    pec_shape = E((2.0, 4.0), "FishPecFin", -3, 9, 11, 6, F(fin), L(line, 1.0), rotation=0.5)
    pec = d("Node", pec_shape, x=2.0, y=4.0, name="FishPec")
    body = S(O, "FishBody", [(-16, 0), (-8, -9), (6, -10), (17, -4), (19, 1), (12, 8), (-2, 10), (-12, 6)],
             body_g(), L(line, 1.4))
    profile = d("Node",
                E(O, "FishGlint", 10, -4.5, 2, 2, F("FFFFFFFF")),
                E(O, "FishPupil", 12, -3, 4.6, 4.6, F("FF1A1414")),
                E(O, "FishEye", 11, -3, 9, 9, F("FFFFFFFF"), L(line, 1.0)),
                S(O, "FishMouth", [(18, 2), (15, 3)], L(line, 1.4), closed=False),
                E(O, "FishSheen", 2, -5, 16, 4, F("50FFFFFF"), rotation=-0.1),
                pec, body, dorsal, tail, x=0.0, y=0.0, name="FishProfile")
    # ---- front view (notice at npcLook 0: it faces the viewer)
    fin_l = d("Node", E((-11.0, 2.0), "FishFinLShape", -18, 5, 13, 7, F(fin), L(line, 1.0), rotation=0.45),
              x=-11.0, y=2.0, name="FishFinL")
    fin_r = d("Node", E((11.0, 2.0), "FishFinRShape", 18, 5, 13, 7, F(fin), L(line, 1.0), rotation=-0.45),
              x=11.0, y=2.0, name="FishFinR")
    front = d("Node",
              E(O, "FishFGlint0", -7, -5.5, 2, 2, F("FFFFFFFF")), E(O, "FishFGlint1", 5, -5.5, 2, 2, F("FFFFFFFF")),
              E(O, "FishFPupil0", -5.6, -3.4, 4.6, 4.6, F("FF1A1414")),
              E(O, "FishFPupil1", 5.6, -3.4, 4.6, 4.6, F("FF1A1414")),
              E(O, "FishFEye0", -6, -4, 9, 10, F("FFFFFFFF"), L(line, 1.0)),
              E(O, "FishFEye1", 6, -4, 9, 10, F("FFFFFFFF"), L(line, 1.0)),
              E(O, "FishFMouth", 0, 7, 5, 4, F("FF8A3A1C")),
              E(O, "FishFBody", 0, 0, 27, 26, body_g(), L(line, 1.4)),
              S(O, "FishFDorsal", [(-4, -11, "c"), (0, -20), (4, -11, "c")], F(fin), L(line, 1.0)),
              fin_l, fin_r, x=0.0, y=0.0, opacity=0.0, name="FishFront")
    tilt = d("Node", front, profile, x=0.0, y=0.0, name="FishTilt")
    f = Formulas(d, sc.vpath)
    face = _formula(sc, f.fn("min", [f.val(1)], f.fn("max", [f.val(-1)], [f.val(1), f.op("+"), f.val(FISH_FACE_GAIN),
                                                                           f.op("*"), *f.inp()])))
    facing = d("Node", d("DataBindContext", sourcePathIds=sc.vpath("npcLook"), propertyKey=16,
                         converterId=face.ref()), tilt, x=0.0, y=0.0, name="FishFacing")
    swim = d("Node", facing, x=0.0, y=0.0, name="FishSwim")
    bubbles = [E(O, f"FishBubble{i}", 0, 0, 7, 7, F("30E8F4FF"), L("C0E8F4FF", 1.4), opacity=0.0) for i in range(3)]
    splash = [E(O, f"FishSplash{i}", 0, 0, 5, 8, F("C0D8F0F8"), opacity=0.0) for i in range(2)]
    fx, fy, _ = FISH_WAYPOINTS[0]
    npc = d("Node", *bubbles, *splash, swim, x=fx, y=fy, name="FishNpc")
    surface = WATER_Y - fy
    # ---- the registered properties and their rest values (every state keys all of them)
    rig.reg(npc, opacity=1.0)
    rig.reg(swim, x=0.0, y=0.0)
    rig.reg(tilt, rotation=0.0)
    rig.reg(profile, opacity=1.0)
    rig.reg(front, opacity=0.0)
    rig.reg(tail, rotation=0.0)
    rig.reg(dorsal, scaleY=1.0)
    rig.reg(pec, rotation=0.0)
    rig.reg(fin_l, rotation=0.0)
    rig.reg(fin_r, rotation=0.0)
    bub0 = [(-6.0, -4.0), (4.0, -6.0), (12.0, -2.0)]
    for b, (bx, by) in zip(bubbles, bub0):
        b.attrs.update(x=bx, y=by)
        rig.reg(b, x=bx, y=by, opacity=0.0, scaleX=1.0, scaleY=1.0)
    for i, s_ in enumerate(splash):
        s_.attrs.update(x=-10.0 + 20 * i, y=surface)
        rig.reg(s_, x=-10.0 + 20 * i, y=surface, opacity=0.0)
    # ---- the path across the bowl; the poke zone rides along
    ts = arc_params([(x, y) for x, y, _ in FISH_WAYPOINTS])
    path_binds(sc, npc, ts, [p[0] for p in FISH_WAYPOINTS], [p[1] for p in FISH_WAYPOINTS])
    hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
    path_binds(sc, hit, ts, [x + hx - fx for x, _, _ in FISH_WAYPOINTS], [y + hy - fy for _, y, _ in FISH_WAYPOINTS])

    def rise(b: El, x: float, f0: int, f1: int, top: float, n: int) -> dict[str, list]:
        return {"x": [(0, x), (f0, x), ((f0 + f1) // 2, x + 3), (f1, x - 1), (n, x)],
                "y": [(0, -2.0), (f0, -2.0, "linear"), (f1, top, "hold"), (n, -2.0)],
                "opacity": [(0, 0.0), (f0, 0.0, "linear"), (f0 + 6, 0.9, "linear"), (f1 - 6, 0.9, "linear"),
                            (f1, 0.0, "hold"), (n, 0.0)],
                "scaleX": [(0, 0.6), (f0, 0.6, "linear"), (f1, 1.2, "hold"), (n, 0.6)],
                "scaleY": [(0, 0.6), (f0, 0.6, "linear"), (f1, 1.2, "hold"), (n, 0.6)]}

    anims: dict[str, El | list[El]] = {}
    n = FISH_REST
    anims["rest"] = rig.anim("npc_fish_rest", n, {
        swim: {"y": [(0, 0.0), (60, -3.0), (120, 0.0), (180, -3.0), (n, 0.0)]},
        tail: {"rotation": wave(0.14, 120, n)},
        pec: {"rotation": wave(0.35, 60, n)},
        dorsal: {"scaleY": [(0, 1.0), (120, 0.88), (n, 1.0)]},
    })
    anims["away"] = rig.anim("npc_fish_away", 1, {npc: {"opacity": [(0, 0.0)]}})
    n = FISH_IDLE
    anims["idle"] = rig.anim("npc_fish_idle", n, {
        swim: {"x": [(0, 0.0), (50, 7.0), (110, 7.0), (160, -5.0), (210, -5.0), (n, 0.0)],
               "y": [(0, 0.0), (40, -4.0), (90, 1.0), (140, -3.0), (200, 2.0), (n, 0.0)]},
        tilt: {"rotation": [(0, 0.0), (50, -0.08), (110, 0.05), (160, 0.06), (210, -0.04), (n, 0.0)]},
        tail: {"rotation": wave(0.26, 40, n)},
        pec: {"rotation": wave(0.5, 20, n)},
        dorsal: {"scaleY": [(0, 1.0), (60, 0.8), (120, 1.0), (180, 0.8), (n, 1.0)]},
        bubbles[1]: rise(bubbles[1], bub0[1][0], 70, 150, surface + 6, n),
    })
    n = FISH_MOVE
    anims["move"] = rig.anim("npc_fish_move", n, {
        swim: {"y": [(0, 0.0), (10, -1.5), (20, 0.0), (30, -1.5), (n, 0.0)]},
        tilt: {"rotation": wave(0.05, 20, n, step=2)},
        tail: {"rotation": wave(0.5, 20, n)},
        pec: {"rotation": [(0, 0.7)]},
        dorsal: {"scaleY": [(0, 0.85)]},
    })
    n = FISH_NOTICE

    def notice(s: float) -> El:
        side = s != 0
        return rig.anim(f"npc_fish_notice{'LCR'[int(s) + 1]}", n, {
            profile: {"opacity": [(0, 1.0 if side else 0.0)]},
            front: {"opacity": [(0, 0.0 if side else 1.0)]},
            swim: {"y": [(0, -2.0), (30, -5.0), (60, -2.0), (90, -5.0), (n, -2.0)]},
            tail: {"rotation": wave(0.14, 60, n)},
            pec: {"rotation": wave(0.5, 30, n)},
            fin_l: {"rotation": wave(0.45, 30, n)},
            fin_r: {"rotation": wave(-0.45, 30, n)},
            dorsal: {"scaleY": [(0, 1.0), (30, 0.85), (60, 1.0), (90, 0.85), (n, 1.0)]},
        })
    anims["notice"] = blend3(notice)
    n = FISH_REACT
    react: dict[El, dict[str, list]] = {
        swim: {"x": [(0, 0.0), (6, 0.0), (20, 9.0), (34, 9.0), (52, 0.0), (n, 0.0)],
               "y": [(0, 0.0), (6, 5.0), (20, -62.0, sc.ease_out), (34, -4.0, sc.ease_in), (40, 8.0),
                     (52, 0.0), (n, 0.0)]},
        tilt: {"rotation": [(0, 0.0), (6, 0.15), (14, -0.6), (22, -0.2), (30, 0.5), (38, 0.1), (52, 0.0), (n, 0.0)]},
        tail: {"rotation": wave(0.6, 12, 36) + [(48, 0.0), (n, 0.0)]},
        pec: {"rotation": wave(0.6, 12, 36) + [(48, 0.0), (n, 0.0)]},
        dorsal: {"scaleY": [(0, 1.0), (14, 0.7), (40, 1.0), (n, 1.0)]},
    }
    for i, (b, (bx, _)) in enumerate(zip(bubbles, bub0)):
        react[b] = rise(b, bx, 36 + 4 * i, 66 + 2 * i, surface + 4, n)
    for i, s_ in enumerate(splash):
        x0 = -10.0 + 20 * i
        out = 18 if i == 0 else 30
        react[s_] = {"x": [(0, x0), (out, x0), (out + 12, x0 + (-8 if i == 0 else 8)), (n, x0)],
                     "y": [(0, surface), (out, surface, "linear"), (out + 6, surface - 16), (out + 12, surface, "hold"),
                           (n, surface)],
                     "opacity": [(0, 0.0), (out, 0.0, "linear"), (out + 2, 1.0, "linear"), (out + 12, 0.0, "hold"),
                                 (n, 0.0)]}
    anims["react"] = rig.anim("npc_fish_react", n, react)
    npc_layer(sc, anims)
    return npc


# ====================================================================== events
def events(sc: Scene, k: dict[str, El]) -> None:
    T = sc.T
    # espresso: the machine hisses a steam cloud off its wand, shakes a little, its light blinks
    n = EV_FRAMES["espresso"]
    tracks = [T(k["esp_machine"], ease=None, x=[(0, ESPRESSO[0])] + [(f, ESPRESSO[0] + (1.4 if (f // 3) % 2 else -1.4),
                                                                      "linear") for f in range(6, 54, 3)]
                + [(57, ESPRESSO[0]), (n, ESPRESSO[0])]),
              T(k["esp_light"], ease=None, opacity=[(0, 0.0)] + [(f, 1.0 if (f // 12) % 2 == 0 else 0.15, "hold")
                                                                 for f in range(4, 124, 12)] + [(124, 0.0), (n, 0.0)])]
    for i in range(6):
        p = k[f"puff{i}"]
        f0 = 6 + 9 * i
        f1 = f0 + 80
        dx = 10 + 9 * i
        tracks.append(T(p, ease=None, opacity=[(0, 0.0), (f0, 0.0, "linear"), (f0 + 10, 0.95, "linear"),
                                               (f1, 0.0, "hold"), (n, 0.0)],
                        x=[(0, 0.0), (f0, 0.0, "linear"), (f1, float(dx), "hold"), (n, 0.0)],
                        y=[(0, 0.0), (f0, 0.0, sc.ease_out), (f1, -110.0 - 8 * i, "hold"), (n, 0.0)],
                        scaleX=[(0, 0.5), (f0, 0.5, sc.ease_out), (f1, 2.6, "hold"), (n, 0.5)],
                        scaleY=[(0, 0.5), (f0, 0.5, sc.ease_out), (f1, 2.4, "hold"), (n, 0.5)]))
    sc.one_shot("espresso", sc.A("ev_espresso", n, tracks))

    # doorbell: the door opens a crack, cold blue light, a gust ruffles its curtain, the bell swings
    n = EV_FRAMES["doorbell"]
    bell = [(0, 0.0)] + [(8 + 12 * j, round(0.6 * (0.72 ** j) * (1 if j % 2 == 0 else -1), 4)) for j in range(12)] \
        + [(160, 0.0), (n, 0.0)]
    tracks = [T(k["door_leaf"], scaleX=[(0, 1.0), (14, 0.84), (120, 0.84), (150, 1.0), (n, 1.0)]),
              T(k["door_gap"], ease=None, opacity=[(0, 0.0), (6, 1.0, "linear"), (150, 1.0, "linear"), (152, 0.0),
                                                   (n, 0.0)]),
              T(k["door_spill"], opacity=[(0, 0.0), (16, 1.0), (120, 0.9), (152, 0.0), (n, 0.0)]),
              T(k["bell"], rotation=bell),
              T(k["curtain"], rotation=[(0, 0.0), (12, -0.16), (26, 0.1), (40, -0.12), (56, 0.07), (74, -0.05),
                                        (96, 0.02), (130, 0.0), (n, 0.0)],
                scaleX=[(0, 1.0), (14, 0.9), (30, 1.04), (48, 0.94), (70, 1.0), (n, 1.0)])]
    for i in range(3):
        g = k[f"gust{i}"]
        f0, f1 = 10 + 8 * i, 110 + 14 * i
        tx, ty = 820 - 150 * i - 60, FLOOR_Y + 120 + 70 * i
        tracks.append(T(g, ease=None,
                        x=[(0, 870.0), (f0, 870.0, sc.ease_out), (f1, float(tx), "hold"), (n, 870.0)],
                        y=[(0, FLOOR_Y + 4.0), (f0, FLOOR_Y + 4.0, "linear"), ((f0 + f1) // 2, FLOOR_Y - 30.0 + 20 * i,
                                                                                 "linear"),
                           (f1, float(ty), "hold"), (n, FLOOR_Y + 4.0)],
                        rotation=[(0, 0.0), (f0, 0.0, "linear"), (f1, 5.0 + i, "hold"), (n, 0.0)],
                        opacity=[(0, 0.0), (f0, 0.0, "linear"), (f0 + 6, 1.0, "linear"), (f1 + 30, 1.0, "linear"),
                                 (f1 + 50, 0.0, "hold"), (n, 0.0)]))
    sc.one_shot("doorbell", sc.A("ev_doorbell", n, tracks))

    # rain: a shower on the glass (a heavier sheet) and a brighter sheen on the street
    n = EV_FRAMES["rain"]
    sc.one_shot("rain", sc.A("ev_rain", n, [
        T(k["shower_glass"], ease=None, opacity=[(0, 0.0), (50, 1.0, "linear"), (n - 70, 1.0, "linear"), (n, 0.0)]),
        T(k["shower_sheen"], ease=None, opacity=[(0, 0.0), (60, 1.0, "linear"), (n - 60, 1.0, "linear"), (n, 0.0)]),
    ]))

    # neonFlicker: the sign across the street stutters off and on (its reflection with it)
    n = EV_FRAMES["neonFlicker"]
    seq = [(0, 1.0), (6, 0.1), (10, 0.9), (14, 0.05), (26, 0.05), (30, 0.8), (34, 0.2), (40, 1.0), (58, 1.0),
           (62, 0.1), (66, 0.7), (70, 0.05), (88, 0.05), (96, 1.0), (n, 1.0)]
    keys = [(f, v, "hold") for f, v in seq]
    sc.one_shot("neonFlicker", sc.A("ev_neonFlicker", n, [T(k["neon"], ease=None, opacity=keys),
                                                          T(k["neon_reflect"], ease=None, opacity=keys)]))


# ====================================================================== the scene
def cafe_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """The café's diorama hook: content back to front by plane (draw order kept inside a plane)."""
    def plane(e: El) -> int:
        name = str(e.attrs.get("name", ""))
        k = PLANES[name if name.startswith(gen_scenes.HIT_PREFIX) else name.rstrip("0123456789")]
        return 6 if k is None else k
    content.sort(key=lambda e: -plane(e))


class CafeScene(Scene):
    """`Scene` without the M8 scenes' art pass (`scene_art.refine_scene` knows the four M8 scenes
    only): the café is drawn at its final stroke widths."""

    def write(self, content: list[El], hits: list[El]) -> str:
        saved = gen_scenes.refine_scene
        gen_scenes.refine_scene = lambda sc, c: None
        try:
            return super().write(content, hits)
        finally:
            gen_scenes.refine_scene = saved


def cafe() -> str:
    sc = CafeScene(SCENE_ID)
    keep: dict[str, El] = {}
    plane01, k = outside(sc)
    keep.update(k)
    plane2, k = window(sc)
    keep.update(k)
    plane3, k = back_wall(sc)
    keep.update(k)
    plane4, k = room(sc)
    keep.update(k)
    plane5 = foreground(sc)
    hits = [sc.hit("cup", CUP[0], CUP[1], 110, 90), sc.hit("espresso", ESPRESSO[0], ESPRESSO[1] - 6, 150, 140),
            sc.hit("window", (FRAME[0] + FRAME[2]) / 2, (FRAME[1] + FRAME[3]) / 2, FRAME[2] - FRAME[0],
                   FRAME[3] - FRAME[1]),
            sc.hit("fish", FISH_WAYPOINTS[0][0], FISH_WAYPOINTS[0][1] - 4, *FISH_HIT)]
    for h, pid in zip(hits, ("cup", "espresso", "window", "fish")):
        sc.prop(pid, h)
    fish = fish_npc(sc, hits[3])
    at = plane3.index("FISH")
    plane3[at] = fish
    events(sc, keep)
    content = [*plane5, *plane4, *plane3, *plane2, *plane01]
    return sc.write(content, hits)


# ====================================================================== registries (world kit, M9)
gen_scenes.DIORAMAS[SCENE_ID] = DioramaSpec(PLANES, EMISSIVE, VEILS, cafe_light)
gen_scenes.TIME_SKY[SCENE_ID] = (560.0, 0.35)          # the rooftops' line in the window; the house keeps 35 %
scene_npc.FOG_VEILS[SCENE_ID] = (0, 1)                  # both outside planes thicken (only seen through the glass)
scene_npc.FOG_BANKS[SCENE_ID] = (1, 380.0, 700.0, "FFB4BCC8", 0.7)


# the `wipe` proof: a 16-dot wipe stroke across the lower middle pane and the upper left one
TRAIL_PROOF = [(380.0 + 22 * i, 440.0 + 8 * i) if i < 8 else (520.0 + 24 * (i - 8), 560.0 - 10 * (i - 8))
               for i in range(world_kit.TRAIL_DOTS)]
EVENT_PEAKS = {"espresso": 60, "doorbell": 60, "rain": 200, "neonFlicker": 20}


def trail_args(n: int = world_kit.TRAIL_DOTS, fade: float = 0.0) -> list[str]:
    """`rive` --data args drawing `n` wiped spots of TRAIL_PROOF at `trailFade` = fade."""
    out = [f"--data=trailN={n}", f"--data=trailFade={fade}"]
    for i, (x, y) in enumerate(TRAIL_PROOF):
        out += [f"--data=trailX{i}={x}", f"--data=trailY{i}={y}"]
    return out


def _extras(render: Callable, out: object, gates: list[str]) -> None:
    """review_diorama extras: the four events at their peaks (`events_strip.png`), the wall pool follows
    `lightKey`, and the `wipe` drag's pixel proof (`wipe_strip.png`): 16 wiped spots change pixels only
    inside the handle's rect, and `trailFade` 1 hides them all."""
    import numpy as np  # noqa: PLC0415 (review-only dependencies)
    from PIL import Image  # noqa: PLC0415
    from review_diorama import grid, label  # noqa: PLC0415
    from pathlib import Path  # noqa: PLC0415
    out = Path(str(out))

    def im(a: object) -> Image.Image:
        return Image.fromarray(a).convert("RGB")  # type: ignore[arg-type]

    rest = render("--advance=1")
    cells = [label(im(rest).resize((360, 640)), "rest")]
    for ev, f in EVENT_PEAKS.items():
        cells.append(label(im(render(f"--data=eventId={ev}", "--data=event=1", f"--advance={f}")).resize((360, 640)),
                           f"{ev} +{f}f"))
    grid(cells, 5).save(out / "events_strip.png")
    # the wall pool takes `lightKey` (a blue key turns it blue; back to the default, back to rest)
    box_ = (slice(830, 852), slice(222, 300))
    a0 = rest.astype(int)[box_][..., :3]
    blue = render("--data=lightKey=FF60A0FF", "--advance=1").astype(int)[box_][..., :3]
    back = render("--data=lightKey=FF60A0FF", "--advance=1", f"--data=lightKey={gen_scenes.SCENES[SCENE_ID].key}",
                  "--advance=2").astype(int)[box_][..., :3]
    shift = float((blue[..., 2] - blue[..., 0]).mean() - (a0[..., 2] - a0[..., 0]).mean())
    drift = int(np.abs(back - a0).max())
    gates.append(f"wall pool follows lightKey (blue - red, mean, blue key vs default): {shift:+.1f}/255 "
                 f"({'ok' if shift >= 8 else 'FAIL'}); back to default: max diff {drift}/255 "
                 f"({'ok' if drift <= 2 else 'FAIL'})")
    # the wipe: 16 spots change pixels only inside the handle's rect; trailFade 1 draws nothing
    x0, y0, x1, y1 = (int(v) for v in GLASS)
    wiped = render(*trail_args(), "--advance=1")
    changed = np.abs(wiped.astype(int) - rest.astype(int))[..., :3].max(-1) > 0
    inside = changed[y0:y1, x0:x1].mean()
    outside_ = changed.copy()
    outside_[y0:y1, x0:x1] = False
    gates.append(f"wipe: 16 spots change {inside:.2%} of the handle rect {GLASS}, {int(outside_.sum())} px outside "
                 f"({'ok' if inside > 0.02 and not outside_.any() else 'FAIL'})")
    faded = render(*trail_args(fade=1.0), "--advance=1")
    gone = int((np.abs(faded.astype(int) - rest.astype(int))[..., :3].max(-1) > 0).sum())
    gates.append(f"wipe: trailFade 1 hides every spot: {gone} px differ from rest ({'ok' if gone == 0 else 'FAIL'})")
    crop = (x0 - 40, y0 - 40, x1 + 40, y1 + 40)
    shots = [(rest, "wipe: none (defaults)"), (render(*trail_args(8), "--advance=1"), "trailN 8"),
             (wiped, "trailN 16"), (render(*trail_args(fade=0.5), "--advance=1"), "trailN 16, trailFade 0.5"),
             (render(*trail_args(), "--data=rain=1", "--advance=31"), "trailN 16, rain 1")]
    grid([label(im(a).crop(crop), t) for a, t in shots], 5).save(out / "wipe_strip.png")


REVIEW: dict[str, object] = {
    "diorama": {
        "patches": [("Plane5 plant leaves", (70, 1450, 210, 1560), 40), ("Plane4 table top", (800, 1030, 840, 1066), 28),
                    ("Plane3 espresso body", (96, 960, 120, 990), 20), ("Plane2 mullion", (440, 420, 500, 520), 12),
                    ("Plane1 lamp post", (680, 560, 720, 640), 6), ("Plane0 moon", (380, 294, 420, 334), 0)],
        "wet": ((480, 640, 600, 750), 1.02, 1.8),
        "rain_loops": [("RainGlass streaks + drips", GLASS_RAIN_FRAMES)],
        "seam_box": tuple(int(v) for v in GLASS),
    },
    "extras": _extras,
    "time": {"sky_box": (340, 270, 740, 380), "dusk_box": (340, 400, 740, 560), "noon_gain": 12.0},
    "npc": {"crop": (200, 170, -6), "seam": {"idle": FISH_IDLE, "move": FISH_MOVE, "notice": FISH_NOTICE,
                                             "react": FISH_REACT},
            "prop": "fish", "waypoints": FISH_WAYPOINTS, "fog_box": tuple(int(v) for v in FRAME)},
}
