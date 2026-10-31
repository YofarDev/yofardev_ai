"""Moonshot M11 (contract v14, ruling 1): the `library` scene, a tall old library at night, a storm outside.

    uv run rive/tools/gen_scenes.py library       # -> rive/scenes/library/library.rml

Storybook night: the green-shaded reading lamp on the desk at the left is the warm key (from low left,
`art_bible.SCENES["library"]`), the tall arched window's storm light the cold rim.

- Plane0, the view through the arched window: the night sky (`daylight` / `dusk` through
  `gen_scenes.sky_time`), storm clouds, stars, the moon (`moonPhase`: the drawn moon at -1,
  `world_kit.moon_rig` at 0..1), the town's roofs and a spire with a few lit windows, the rain beyond the
  glass (`rain`), the `fog` veil and bank (`scene_npc.scene_fog`), the `lightning` event's bolt.
- Plane1, the window: the arched frame, the mullion, the transom and the oculus, the glass sheen, the rain
  on the panes (`rain`: streaks and drips clipped to the glass), the `rain` event's heavier burst, the
  `lightning` flash on the glass.
- Plane2, the back wall: the wallpaper with the arched opening, its casing and sill, two bookcases to the
  ceiling (generated rows of books, one shape per spine colour), the grandfather clock (prop `clock`, its
  pendulum swings in a loop; the `clockChime` event swings it wider for 3 s), the lamp's warm glow and the
  window's cold spill, the `bookFlutter` book (it slides off a high shelf, flutters across like a bird and
  slots back), `festive`: a pine garland with small lights along a shelf of each bookcase.
- Plane3: the reading desk at the left with the green banker's lamp, an open book (prop `book`) and a
  candle; the brass rail along the right bookcase and the rolling ladder on it (the `ladder` aim drag:
  -1..1 slides it by +-`LADDER_TRAVEL` px, history-free; its wheels turn with it); dust motes in the
  lamp's light.
- Plane4, the floor: planks, the rug, the lamp's pool (`lightKey`), the globe on its stand (prop `globe`),
  the reading chair, the mouse (NPC `mouse`), the `lightning` event's window light thrown on the floor.
- Plane5, the foreground: a stack of books with a candle.

The mouse (`npc`, contract v11 states, M11 ruling 7): rest = asleep, curled by the bottom shelf (a
breathing loop, Zzz); idle = sniffs, whiskers twitch; move = scurries (a fast bob and pattering feet);
notice = up on its haunches toward the avatar (`npcLook` aims the head); react = a jump. It faces the
room's centre (left) for `npcLook` <= 0 and turns right for `npcLook` > 0. `npcX` 0 = by the right
bookcase's bottom shelf, 1 = at the reading chair's front foot (`MOUSE_WAYPOINTS`). Poke prop `mouse`
follows `npcX`.

`TIER_GATES` names the element roots lane W's tier pass hides (high: the second half of every dense rain
sheet; low: also the dust motes). This module never binds `tier`.

Built through gen_scenes.Scene; mints its own scene document (each scene is its own document).
"""

from __future__ import annotations

import math
import os
from pathlib import Path
import random
import sys
from typing import Callable

sys.path.insert(0, os.path.dirname(__file__))
import gen_scenes  # noqa: E402
from gen_scenes import DIORAMAS, TIME_SKY, DioramaSpec, Scene, W, H, uniq  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import El, ellipse, lin, rad, smooth_path  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds  # noqa: E402
import world_kit  # noqa: E402

SCENE_ID = "library"
O = (0.0, 0.0)
Z = (0.0, 0.0)
INK = "FF2A2026"

# ---------------------------------------------------------------- layout (artboard px)
FLOOR_Y = 1220.0                            # where the back wall meets the floor
ARCH_CY = 300.0                             # the window's arch springs at this y (semicircular head)
GLASS = (400.0, 994.0)                      # the glass: x 400..680 (r 140), bottom y
GLASS_X = (400.0, 680.0)
OPEN_X, OPEN_BOT = (392.0, 688.0), 1000.0   # the wall's opening (Plane2)
FRAME_X, FRAME_BOT = (384.0, 696.0), 1004.0  # the frame's outer edge (Plane1, 8 px under the wall)
CASING_X = (368.0, 712.0)
VIEW = (350.0, 110.0, 730.0, 1030.0)        # the view (Plane0) runs past the opening by more than its travel
MULL_X, MULL_W = 540.0, 12.0
TRANSOM_Y = 640.0
OCULUS = (540.0, 236.0, 34.0)               # the round tracery in the arch: centre, outer radius
MOON = (612.0, 318.0, 24.0)                 # the drawn moon in the view: centre, radius
HORIZON = 860.0
SKY_TOP, SKY_MID, SKY_LOW = "FF141A2C", "FF20283E", "FF363A56"

BOARDS = (100.0, 260.0, 420.0, 580.0, 740.0, 900.0, 1060.0)   # shelf boards (their top), the last = plinth
BOARD_T = 16.0
CASE_L, CASE_R = (-80.0, 250.0), (730.0, 1160.0)              # the two bookcases (x)
CASE_SIDE = 22.0
SLOT = (196.0, 2, 24.0, 118.0)                # the bookFlutter book: x, row (board 420 -> 580), width, height
GARLAND_BOARD = 740.0
FLY_SCALE = 1.5                               # the flying book, in flight (it leaves the shelf at 1)

CLOCK_X = 317.0                               # the grandfather clock (Plane2): centre line
CLOCK_FACE = (317.0, 700.0, 40.0)
CLOCK_TRUNK = (262.0, 760.0, 372.0, 1110.0)
CLOCK_GLASS = (279.0, 790.0, 355.0, 1070.0)   # the trunk's door glass (the pendulum shows through it)
PENDULUM_PIVOT = (317.0, 772.0)
PENDULUM_LEN = 214.0
SWING = 0.07                                  # rad, the pendulum's idle amplitude
CHIME_SWING = 0.19                            # rad, at the chime's peak
PENDULUM_PERIOD = 90                          # frames per full swing (1.5 s)

DESK = (-70.0, 1088.0, 345.0)                 # x0, top y, x1 (Plane3)
DESK_FOOT_Y = 1214.0
LAMP = (150.0, 1086.0)                        # the lamp's base on the desk
SHADE_Y = (982.0, 1022.0)
BOOK_AT = (270.0, 1080.0)                     # the open book on the desk (centre of the spine's foot)
DESK_CANDLE = (24.0, 1088.0)

RAIL_Y = 300.0                                # the ladder's brass rail (Plane3)
RAIL_X = (700.0, 1160.0)
LADDER_X = 905.0                              # the ladder's centre at ladder 0
LADDER_TRAVEL = 140.0                         # px at ladder +-1
LADDER_HW = (44.0, 58.0)                      # half widths at the top and the feet (stile centres)
LADDER_FOOT_Y = 1186.0
STILE_W = 14.0
WHEEL_R = 12.0

GLOBE = (172.0, 1290.0, 64.0)                 # the globe on its floor stand (Plane4): centre, radius
GLOBE_BASE_Y = 1494.0
CHAIR = (850.0, 1300.0, 1130.0, 1610.0)       # the reading chair (Plane4): its box; front-left foot at (884, 1610)
RUG = (540.0, 1500.0, 820.0, 300.0)

# ---------------------------------------------------------------- the mouse (npc)
# (paw line x, y, scale) along its path: by the bottom shelf (0) -> at the reading chair's front foot (1)
# (around the chair's left side: never in front of its arm or back while it is behind the chair's front)
MOUSE_WAYPOINTS = [(790.0, 1238.0, 1.0), (756.0, 1340.0, 1.07), (736.0, 1462.0, 1.16), (836.0, 1600.0, 1.28)]
MOUSE_ART_SCALE = 1.5
MOUSE_IDLE, MOUSE_MOVE, MOUSE_NOTICE, MOUSE_REACT, MOUSE_REST = 240, 12, 120, 36, 240
MOUSE_HIT = (790.0, 1214.0, 110.0, 72.0)      # Hit_mouse at npcX 0 (cx, cy, w, h)
MOUSE_REACT_MS = MOUSE_REACT * 1000 // 60
FUR, FUR_SH, BELLY, PINK, TAIL = "FF9C8E86", "FF6E625E", "FFDCD0C4", "FFE0A4A0", "FFC49C96"

# ---------------------------------------------------------------- loops and events (frames at 60 fps)
LAMP_FLICKER = [(0, 1.0), (17, 0.93), (31, 0.99), (52, 0.92), (70, 1.0), (88, 0.94), (104, 0.98), (120, 1.0)]
FLICKER_FRAMES = 120
GLASS_STREAKS = (30, 240.0, 20)               # (count, tile px, loop frames): one tile per loop, seamless
GLASS_DRIPS = (12, 480.0, 240)
VIEW_RAIN = (36, 240.0, 24)
SHOWER_STREAKS = (40, 240.0, 12)
GLASS_RAIN_FRAMES = 240                       # every rain sheet is back at frame 0 after this many frames
GLASS_WET = ("FF6A7890", 0.2)
STREAK_COLOUR = "80C8D4E4"
EVENT_FRAMES = {"lightning": 72, "bookFlutter": 240, "clockChime": 2 * PENDULUM_PERIOD, "rain": 420}
EVENT_PEAKS = {"lightning": 4, "bookFlutter": 110, "clockChime": 68, "rain": 200}

# ---------------------------------------------------------------- v12 members this file binds
BINDS: set[str] = {"moonPhase", "festive", *world_kit.drag_numbers(SCENE_ID)}
BINDS14: set[str] = set()   # `tier` is bound by lane W's shared pass; no seasons here (contract v14)

# Element roots lane W's tier pass hides (contract v14 `tier`): "high" at high and low (the second half
# of every dense rain sheet), "low" at low only (decorative ambient loops that are not light).
TIER_GATES: dict[str, tuple[str, ...]] = {
    "high": ("GlassStreaksB", "GlassDripsB", "ViewRainB", "ShowerStreaksB"),
    "low": ("DustMotes",),
}


# ====================================================================== helpers
class _LibraryScene(Scene):
    """`gen_scenes.Scene` without the M4 art pass (`scene_art.refine_scene` knows the four M8 scenes
    only): this file's art is final as drawn."""

    def write(self, content: list[El], hits: list[El]) -> str:
        saved = gen_scenes.refine_scene
        gen_scenes.refine_scene = lambda sc, c: None
        try:
            return super().write(content, hits)
        finally:
            gen_scenes.refine_scene = saved


def lin_conv(sc: Scene, k: float, c: float = 0.0, lo: float | None = None, hi: float | None = None) -> El:
    """A private `c + k x input` converter (clamped to [lo, hi] when given), minted from `d9`."""
    f = Formulas(sc.d9, sc.vpath)
    toks = ([f.val(c), f.op("+")] if c else []) + [f.val(k), f.op("*"), *f.inp()]
    if lo is not None:
        toks = f.fn("max", [f.val(lo)], toks)
    if hi is not None:
        toks = f.fn("min", [f.val(hi)], toks)
    conv = sc.d9("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def rect_path(sc: Scene, x0: float, y0: float, x1: float, y1: float, ox: float = 0.0, oy: float = 0.0,
              name: str = "Path", r: float = 0.0) -> El:
    return sc.d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2 - ox),
                y=float((y0 + y1) / 2 - oy), cornerRadiusTL=float(r) or None, cornerRadiusTR=float(r) or None,
                cornerRadiusBL=float(r) or None, cornerRadiusBR=float(r) or None, name=name)


def rect_shape(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, paint: El | None, r: float = 0.0,
               **kw: object) -> El:
    d = sc.d
    return d("Shape", d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), cornerRadiusTL=float(r),
                        cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
             paint, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), name=name, **kw)


def multi(sc: Scene, name: str, paths: list[El], paint: El, **kw: object) -> El:
    """One shape of many paths (positioned in artboard px: the shape sits at the origin)."""
    return sc.d("Shape", *paths, paint, x=0.0, y=0.0, name=name, **kw)


def arch_pts(x0: float, x1: float, cy: float, ybot: float, n: int = 14) -> list[tuple]:
    """A round-headed arch: square bottom corners at `ybot`, sides up to `cy`, a semicircle over them."""
    r, cx = (x1 - x0) / 2, (x0 + x1) / 2
    pts: list[tuple] = [(x1, ybot, "c"), (x0, ybot, "c")]
    for i in range(n + 1):
        a = math.pi + math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def arch_path(sc: Scene, x0: float, x1: float, ybot: float, ox: float, oy: float, name: str = "Path",
              cy: float = ARCH_CY) -> El:
    return smooth_path(sc.d, [(p[0] - ox, p[1] - oy, *p[2:]) for p in arch_pts(x0, x1, cy, ybot)], name=name)


def arch_ring(sc: Scene, name: str, outer: tuple[float, float, float], inner: tuple[float, float, float],
              paint: El, outer_cy: float = ARCH_CY) -> El:
    """`outer` arch (x0, x1, ybot) minus `inner` arch (even-odd), both springing at ARCH_CY."""
    paint.attrs["fillRule"] = "evenOdd"
    ox, oy = 540.0, 600.0
    return sc.d("Shape", arch_path(sc, outer[0], outer[1], outer[2], ox, oy, cy=outer_cy),
                arch_path(sc, inner[0], inner[1], inner[2], ox, oy, name="Opening"), paint, x=ox, y=oy, name=name)


def glass_clip(sc: Scene, name: str = "GlassClip") -> El:
    return sc.d("Shape", arch_path(sc, GLASS_X[0], GLASS_X[1], GLASS[1], 540.0, 600.0, name="Glass"),
                x=540.0, y=600.0, name=name)


def fluff(cx: float, cy: float, rx: float, ry: float, n: int, amp: float, a0: float = 0.0) -> list[tuple[float, float]]:
    """A soft scalloped outline: 2n points around an ellipse, every other one pushed out by `amp`."""
    pts = []
    for i in range(2 * n):
        a = a0 + math.pi * i / n
        k = 1 + (amp if i % 2 == 0 else -amp * 0.35)
        pts.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    return pts


def sine_keys(frames: int, amp: Callable[[int], float], period: int, step: int = 3) -> list[tuple]:
    """Linear keys of amp(f) x sin(2 pi f / period) every `step` frames, the last at `frames`."""
    fs = sorted(set(range(0, frames, step)) | {frames})
    return [(f, round(amp(f) * math.sin(2 * math.pi * f / period), 5), "linear") for f in fs]


def rain_sheets(sc: Scene, prefix: str, label: str, spec: tuple[int, float, int], box: tuple[float, float, float, float],
                seed: int, colour: str, width: float, length: tuple[float, float], slant: float,
                drips: bool = False) -> list[El]:
    """A looping sheet of streaks (or drips) over `box`, one tile per loop (seamless at any frame), split into
    two halves `<prefix><label>A` / `B` (the tier pass hides B at high); one ambient layer moves both."""
    n, tile, period = spec
    r_ = random.Random(seed)
    x0, y0, x1, y1 = box
    halves: list[list[El]] = [[], []]
    for i in range(n):
        x, u = r_.uniform(x0 + 4, x1 - 4), r_.uniform(0, tile)
        ln = r_.uniform(*length)
        for k in range(-2, math.ceil((y1 - y0) / tile) + 1):
            y = y0 + u + k * tile
            if y + tile + ln + 8 < y0 or y > y1:
                continue
            if drips:
                halves[i % 2] += [sc.E(O, f"{prefix}Drop{i}_{k + 2}", x, y + ln, 5, 7, sc.F("B0D8E2EC")),
                                  sc.S(O, f"{prefix}Trail{i}_{k + 2}", [(x, y), (x + 0.6, y + ln - 3)],
                                       sc.L("50D8E2EC", 2.0), closed=False)]
            else:
                halves[i % 2].append(sc.S(O, f"{prefix}Streak{i}_{k + 2}", [(x, y), (x - ln * slant, y + ln)],
                                          sc.L(colour, width), closed=False))
    nodes = [sc.d("Node", *kids, x=0.0, y=0.0, name=f"{prefix}{label}{'AB'[h]}") for h, kids in enumerate(halves)]
    sc.ambient(f"Rain{prefix}{label}", sc.A(f"amb_Rain{prefix}{label}", period, [
        sc.T(nd, ease=None, y=[(0, 0.0, "linear"), (period, tile, "linear")]) for nd in nodes], loop=True))
    return nodes


# ====================================================================== the scene
def library() -> str:
    sc = _LibraryScene(SCENE_ID)
    hits: list[El] = []
    plane0 = view(sc)
    plane1 = window(sc)
    plane2, clock_box = back_wall(sc)
    plane3 = desk_and_ladder(sc)
    plane4 = floor(sc)
    plane5 = foreground(sc)
    wash = lightning(sc, plane0, plane1, plane4)

    hits += [sc.hit("mouse", *MOUSE_HIT), sc.hit("clock", *clock_box),
             sc.hit("book", BOOK_AT[0], BOOK_AT[1] - 4, 150, 56),
             sc.hit("globe", GLOBE[0], (GLOBE[1] - GLOBE[2] - 12 + GLOBE_BASE_Y) / 2, 2 * GLOBE[2] + 40,
                    GLOBE_BASE_Y - GLOBE[1] + GLOBE[2] + 12)]
    for h_ in hits:
        sc.prop(str(h_.attrs["name"])[4:], h_)

    content = [wash, *plane5, *plane4, *plane3, *plane2, *plane1, *plane0]
    _flicker_tracks(sc, content)
    with sc.minting(sc.d8):
        mouse_npc(sc, content, hits)
    return sc.write(content, hits)


# ---------------------------------------------------------------- Plane0: the view
def view(sc: Scene) -> list[El]:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rnd = random.Random(4417)
    vx0, vy0, vx1, vy1 = VIEW
    sky = rect_shape(sc, "Sky", vx0, vy0, vx1, vy1, sc.vgrad(-(vy1 - vy0) / 2, (vy1 - vy0) / 2,
                                                               [(SKY_TOP, 0.0), (SKY_MID, 0.5), (SKY_LOW, 0.82),
                                                                ("FF2A2C44", 1.0)]))
    stars = []
    while len(stars) < 12:
        x, y = rnd.uniform(GLASS_X[0] + 10, GLASS_X[1] - 10), rnd.uniform(200, 600)
        if (math.hypot(x - MOON[0], y - MOON[1]) < MOON[2] + 24 or abs(x - MULL_X) < 14
                or math.hypot(x - OCULUS[0], y - OCULUS[1]) < OCULUS[2] + 8 or abs(y - TRANSOM_Y) < 14):
            continue
        if math.hypot(x - 540, y - ARCH_CY) > 132 and y < ARCH_CY:
            continue
        sz = rnd.choice((2.4, 3.0, 3.6))
        stars.append(E(O, f"Star{len(stars)}", x, y, sz, sz, F("FFF0EEE4"), opacity=round(rnd.uniform(0.45, 0.95), 2)))
    tw = [sc.T(s, opacity=[(0, float(s.attrs["opacity"])), (50 + 31 * i % 110, 0.2),
                           (130 + 29 * i % 90, float(s.attrs["opacity"])), (240, float(s.attrs["opacity"]))])
          for i, s in enumerate(stars) if i % 3 == 0]
    sc.ambient("Stars", sc.A("amb_stars", 240, tw, loop=True, seam_hold=True))

    # storm clouds (calm at the defaults: dark banks drifting very slowly)
    clouds = []
    for i, (cx, cy, rx, ry, col) in enumerate(((470.0, 420.0, 110.0, 34.0, "FF283048"),
                                               (640.0, 470.0, 90.0, 26.0, "FF2C344C"),
                                               (520.0, 560.0, 150.0, 30.0, "FF262C44"))):
        clouds.append(S(O, f"Cloud{i}", fluff(cx, cy, rx, ry, 7, 0.12, a0=0.3 * i), F(col)))
    cloud_node = d("Node", *clouds, x=0.0, y=0.0, name="Clouds")
    sc.ambient("CloudDrift", sc.A("amb_CloudDrift", 960, [
        sc.T(cloud_node, ease=None, x=[(0, 0.0), (480, 14.0), (960, 0.0)])], loop=True, seam_hold=True))

    # the drawn moon (moonPhase -1) and the phase rig (0..1)
    mx, my, mr = MOON
    craters = [E(O, f"MoonCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A"))
               for i, (dx, dy, r_) in enumerate(((-7, 6, 8), (6, -7, 6), (8, 8, 5)))]
    moon_drawn = world_kit.hide_when_phased(sc, sc.d9, "MoonDrawn", [
        *craters, E(O, "MoonDisc", mx, my, 2 * mr, 2 * mr, sc.rgrad(mr * 1.6, [("FFFFF8E6", 0.0), ("FFE6DCC2", 1.0)],
                                                                   cx=-mr * 0.4, cy=-mr * 0.4)),
        E(O, "MoonGlow", mx, my, mr * 7, mr * 7, sc.rgrad(mr * 3.5, [("3CFFF2D8", 0.0), ("00FFF2D8", 1.0)]))])
    with sc.minting(sc.d9):
        lit = d("Node", *[E((mx, my), f"MoonLitCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A"))
                          for i, (dx, dy, r_) in enumerate(((-7, 6, 8), (6, -7, 6), (8, 8, 5)))],
                E((mx, my), "MoonLitDisc", mx, my, 2 * mr, 2 * mr, F("FFF6EEDA")),
                E((mx, my), "MoonLitGlow", mx, my, mr * 7, mr * 7,
                  sc.rgrad(mr * 3.5, [("3CFFF2D8", 0.0), ("00FFF2D8", 1.0)])), x=0.0, y=0.0, name="MoonLit")
    moon_rig = world_kit.moon_rig(sc, sc.d9, mx, my, mr, lit, "E61A2034")

    # the town: roofs, chimneys and a spire, a few lit windows; trees in front
    roof_pts = [(vx0 - 10, vy1 + 10, "c"), (vx0 - 10, 900, "c"), (380, 900, "c"), (380, 870, "c"), (410, 840, "c"),
                (440, 870, "c"), (452, 870, "c"), (452, 820, "c"), (462, 820, "c"), (462, 800, "c"), (468, 800, "c"),
                (468, 820, "c"), (474, 820, "c"), (474, 862, "c"), (500, 862, "c"), (522, 836, "c"), (544, 862, "c"),
                (560, 862, "c"), (560, 740, "c"), (570, 720, "c"), (577, 640, "c"), (584, 720, "c"),
                (594, 740, "c"), (594, 862, "c"), (612, 862, "c"), (640, 830, "c"), (668, 856, "c"),
                (680, 856, "c"), (680, 848, "c"), (690, 848, "c"), (690, 880, "c"), (vx1 + 10, 880, "c"),
                (vx1 + 10, vy1 + 10, "c")]
    town = S(O, "Town", roof_pts, sc.vgrad(-200, 200, [("FF1C2236", 0.0), ("FF121626", 1.0)]))
    lit_wins = [rect_shape(sc, f"LitWin{i}", x, y, x + w, y + h, F("FFE8BC6A"))
                for i, (x, y, w, h) in enumerate(((396, 900, 9, 12), (424, 922, 9, 12), (510, 884, 8, 11),
                                                  (604, 900, 9, 12), (650, 870, 9, 12), (573, 760, 7, 12)))]
    trees = [S(O, f"Tree{i}", fluff(x, y, rx, ry, 6, 0.14, a0=0.2 * i), F("FF0E1420"))
             for i, (x, y, rx, ry) in enumerate(((372.0, 960.0, 48.0, 54.0), (706.0, 950.0, 44.0, 60.0),
                                                 (486.0, 990.0, 60.0, 40.0)))]

    # the rain beyond the glass (scene `rain`): a slanted sheet over the view
    view_box = (GLASS_X[0] - 20, 140.0, GLASS_X[1] + 30, GLASS[1] + 10)
    view_rain = rain_sheets(sc, "View", "Rain", VIEW_RAIN, view_box, 9121, "70A8B8D0", 1.4, (28.0, 52.0), 0.18)
    rain_node = d("Node", sc.bind("rain", 18, lin_conv(sc, 0.85, lo=0.0, hi=0.85), doc=sc.d9), *view_rain,
                  x=0.0, y=0.0, opacity=0.0, name="ViewRain")
    return [rain_node, *trees, *lit_wins, town, moon_rig, moon_drawn, cloud_node, *stars, sky]


# ---------------------------------------------------------------- Plane1: the window
def window(sc: Scene) -> list[El]:
    d, F = sc.d, sc.F
    frame = arch_ring(sc, "WinFrame", (FRAME_X[0], FRAME_X[1], FRAME_BOT), (GLASS_X[0], GLASS_X[1], GLASS[1]),
                      sc.F("FF3A2A22"))
    ox, oy, orr = OCULUS
    mull = rect_shape(sc, "MullionV", MULL_X - MULL_W / 2, oy + orr - 4, MULL_X + MULL_W / 2, GLASS[1], F("FF3A2A22"))
    transom = rect_shape(sc, "Transom", GLASS_X[0], TRANSOM_Y - 6, GLASS_X[1], TRANSOM_Y + 6, F("FF3A2A22"))
    oculus = sc.E(O, "Oculus", ox, oy, 2 * orr - 9, 2 * orr - 9, sc.L("FF3A2A22", 9.0))
    spokes = multi(sc, "OculusSpoke", [smooth_path(d, [(ox + (orr - 4) * math.cos(a), oy + (orr - 4) * math.sin(a), "c"),
                                                       (ox - (orr - 4) * math.cos(a), oy - (orr - 4) * math.sin(a), "c")],
                                                   closed=False) for a in (math.pi / 4, 3 * math.pi / 4)],
                   sc.L("FF3A2A22", 5.0))
    lead = multi(sc, "Leading", [smooth_path(d, [(x, TRANSOM_Y, "c"), (x, GLASS[1], "c")], closed=False)
                                 for x in (470.0, 610.0)], sc.L("A02A2026", 2.4))   # the lower panes only
    hi = rect_shape(sc, "MullionHi", MULL_X - MULL_W / 2, oy + orr, MULL_X - MULL_W / 2 + 3, GLASS[1], F("40C8D4E8"))
    sheen = d("Shape", arch_path(sc, GLASS_X[0], GLASS_X[1], GLASS[1], 540.0, 600.0),
              d("Fill", lin(d, -140, -440, 140, 400, [("18C8D8F0", 0.0), ("00C8D8F0", 0.35), ("10C8D8F0", 0.6),
                                                       ("00C8D8F0", 1.0)]), name="Fill"),
              x=540.0, y=600.0, name="GlassSheen")

    clip = glass_clip(sc)
    gbox = (GLASS_X[0], 160.0, GLASS_X[1], GLASS[1])
    sheets = [*rain_sheets(sc, "Glass", "Drips", GLASS_DRIPS, gbox, 7301, "", 2.0, (18.0, 34.0), 0.0, drips=True),
              *rain_sheets(sc, "Glass", "Streaks", GLASS_STREAKS, gbox, 7302, STREAK_COLOUR, 1.6, (24.0, 44.0), 0.16)]
    wet = d("Shape", arch_path(sc, GLASS_X[0], GLASS_X[1], GLASS[1], 540.0, 600.0), sc.F(GLASS_WET[0]),
            x=540.0, y=600.0, opacity=GLASS_WET[1], name="GlassWet")
    rain = d("Node", sc.bind("rain", 18, lin_conv(sc, 1.0, lo=0.0, hi=1.0), doc=sc.d9),
             d("ClippingShape", sourceId=clip.ref(), name="Clip"), *sheets, wet, x=0.0, y=0.0, opacity=0.0,
             name="RainGlass")
    shower_sheets = rain_sheets(sc, "Shower", "Streaks", SHOWER_STREAKS, gbox, 7303, "A0D0DCEA", 2.2, (40.0, 70.0),
                                0.16)
    shower = d("Node", d("ClippingShape", sourceId=clip.ref(), name="Clip"), *shower_sheets, x=0.0, y=0.0,
               opacity=0.0, name="ShowerGlass")
    n = EVENT_FRAMES["rain"]
    sc.one_shot("rain", sc.A("ev_rain", n, [
        sc.T(shower, ease=None, opacity=[(0, 0.0), (50, 1.0, "linear"), (n - 70, 1.0, "linear"), (n, 0.0)])]))
    sc._library_keep = {"clip": clip}   # type: ignore[attr-defined]
    return [hi, spokes, oculus, transom, mull, frame, lead, "FLASH", shower, rain, sheen, clip]  # type: ignore[list-item]


# ---------------------------------------------------------------- Plane2: the back wall
BOOK_COLOURS = ("FF6E2A28", "FF2C4638", "FF2A3654", "FF5E4228", "FF8A6A38", "FF46304C", "FF3A5656", "FFB0946A",
                "FF52221E")


def bookcase(sc: Scene, name: str, x0: float, x1: float, seed: int, slot: bool) -> tuple[El, El | None]:
    """A bookcase to the ceiling: sides, boards, a plinth with two doors, rows of books (one shape per spine
    colour), gold bands, the shadow under each board. With `slot`, the SLOT book is left out of its row
    and returned on its own (the bookFlutter book)."""
    d, F = sc.d, sc.F
    rnd = random.Random(seed)
    by_col: dict[str, list[El]] = {c: [] for c in BOOK_COLOURS}
    bands: list[El] = []
    tops: list[El] = []
    slot_book = None
    for row, (top, bot) in enumerate(zip(BOARDS, BOARDS[1:])):
        top += BOARD_T
        x = x0 + CASE_SIDE + 4 + rnd.uniform(0, 8)
        end = x1 - CASE_SIDE - 4
        while True:
            w = rnd.uniform(15.0, 30.0)
            if x + w > end:
                break
            if slot and row == SLOT[1] and x + w > SLOT[0] - 4 and x < SLOT[0] + SLOT[2] + 4:
                x = SLOT[0] + SLOT[2] + 3
                continue
            if rnd.random() < 0.06:
                x += rnd.uniform(10, 26)
                continue
            h = rnd.uniform(0.66, 0.94) * (bot - top)
            col = rnd.choice(BOOK_COLOURS)
            by_col[col].append(rect_path(sc, x, bot - h, x + w, bot))
            tops.append(rect_path(sc, x, bot - h, x + w, bot - h + 3))
            if rnd.random() < 0.55:
                yb = bot - h + rnd.uniform(10, 16)
                bands += [rect_path(sc, x + 2, yb, x + w - 2, yb + 3), rect_path(sc, x + 2, yb + 7, x + w - 2, yb + 9)]
            x += w + rnd.uniform(0.5, 2.0)
    books = [multi(sc, f"{name}Books{i}", paths, F(c)) for i, (c, paths) in enumerate(by_col.items()) if paths]
    if slot:
        sx, row, sw, sh = SLOT
        bot = BOARDS[row + 1]
        slot_book = d("Node",
                      multi(sc, "SlotBand", [rect_path(sc, sx + 2, bot - sh + 12, sx + sw - 2, bot - sh + 15),
                                             rect_path(sc, sx + 2, bot - sh + 19, sx + sw - 2, bot - sh + 21),
                                             rect_path(sc, sx + 2, bot - 18, sx + sw - 2, bot - 15)],
                            F("FFD6AE5A")),
                      rect_shape(sc, "SlotSpine", sx, bot - sh, sx + sw, bot,
                                 d("Fill", lin(d, -sw / 2, 0, sw / 2, 0, [("FF8A3A30", 0.0), ("FF5E2420", 1.0)]),
                                   name="Fill"), r=2),
                      x=0.0, y=0.0, name="SlotBook")
    band_shape = multi(sc, f"{name}Bands", bands, F("FFC8A052"))
    top_shape = multi(sc, f"{name}Tops", tops, F("30FFF0D8"))
    shade = multi(sc, f"{name}Shade", [rect_path(sc, x0 + CASE_SIDE, b + BOARD_T, x1 - CASE_SIDE, b + BOARD_T + 22)
                                       for b in BOARDS[:-1]], F("66100806"))
    boards = multi(sc, f"{name}Boards", [rect_path(sc, x0, b, x1, b + BOARD_T) for b in BOARDS],
                   sc.F("FF5A3A26"))
    lips = multi(sc, f"{name}Lips", [rect_path(sc, x0, b, x1, b + 3) for b in BOARDS], sc.F("FF8A6040"))
    plinth = rect_shape(sc, f"{name}Plinth", x0, BOARDS[-1] + BOARD_T, x1, FLOOR_Y + 4,
                        sc.vgrad(-80, 80, [("FF4E3220", 0.0), ("FF34200F", 1.0)]))
    mid = (x0 + x1) / 2
    doors = multi(sc, f"{name}Doors", [rect_path(sc, a + 12, BOARDS[-1] + BOARD_T + 14, b - 12, FLOOR_Y - 14, r=4)
                                       for a, b in ((x0 + CASE_SIDE, mid - 2), (mid + 2, x1 - CASE_SIDE))],
                  sc.L("FF24160C", 3.0))
    knobs = multi(sc, f"{name}Knobs", [sc.d("Ellipse", width=8.0, height=8.0, x=float(mid + s * 12),
                                            y=float((BOARDS[-1] + FLOOR_Y) / 2), name="Path") for s in (-1, 1)],
                  sc.F("FFC8A052"))
    sides = [rect_shape(sc, f"{name}Side{k}", a, -60, a + CASE_SIDE, FLOOR_Y + 4,
                        d("Fill", lin(d, -CASE_SIDE / 2, 0, CASE_SIDE / 2, 0, [("FF7A5236", 0.0), ("FF4A3020", 1.0)]),
                          name="Fill"))
             for k, a in enumerate((x0, x1 - CASE_SIDE))]
    back = rect_shape(sc, f"{name}Back", x0, -60, x1, FLOOR_Y, sc.vgrad(-640, 640, [("FF2A1A12", 0.0),
                                                                                     ("FF20140E", 1.0)]))
    node = d("Node", *sides, knobs, doors, plinth, lips, boards, shade, top_shape, band_shape, *books, back,
             x=0.0, y=0.0, name=name)
    return node, slot_book


def back_wall(sc: Scene) -> tuple[list[El], tuple[float, float, float, float]]:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    # the wall with the arched opening; its paper's stripes; the wainscot under the window
    wall = d("Shape", rect_path(sc, -80, -60, W + 80, FLOOR_Y + 40, 540.0, 600.0),
             arch_path(sc, OPEN_X[0], OPEN_X[1], OPEN_BOT, 540.0, 600.0, name="Opening"),
             d("Fill", lin(d, 0, -660, 0, 660, [("FF3A2222", 0.0), ("FF4A2C28", 0.6), ("FF2E1C1A", 1.0)]),
               fillRule="evenOdd", name="Fill"),
             x=540.0, y=600.0, name="Wall")
    stripes = multi(sc, "WallStripe", [rect_path(sc, x, -60, x + 6, FLOOR_Y)
                                       for x in (262.0, 300.0, 338.0, 718.0)], F("30140A08"))
    wainscot = d("Node",
                 rect_shape(sc, "WainscotRail", 250, 1012, 730, 1026, F("FF6A4630")),
                 rect_shape(sc, "WainscotBody", 250, 1012, 730, FLOOR_Y + 4,
                            sc.vgrad(-100, 100, [("FF4A3020", 0.0), ("FF2E1C10", 1.0)])),
                 x=0.0, y=0.0, name="Wainscot")
    casing = arch_ring(sc, "Casing", (CASING_X[0], CASING_X[1], OPEN_BOT), (OPEN_X[0], OPEN_X[1], OPEN_BOT),
                       sc.d("Fill", lin(d, -170, 0, 170, 0, [("FF7A5438", 0.0), ("FF5A3C28", 1.0)]), name="Fill"))
    keystone = S(O, "Keystone", [(524, 118, "c"), (556, 118, "c"), (550, 146, "c"), (530, 146, "c")], F("FF8A6444"),
                 L(INK, 2))
    reveal = arch_ring(sc, "Reveal", (OPEN_X[0], OPEN_X[1], OPEN_BOT), (OPEN_X[0] + 9, OPEN_X[1] - 9, OPEN_BOT),
                       sc.F("70100808"), outer_cy=ARCH_CY)
    sill = d("Node", rect_shape(sc, "SillLip", CASING_X[0] - 16, OPEN_BOT + 14, CASING_X[1] + 16, OPEN_BOT + 22,
                                F("FF4E3422"), r=3),
             rect_shape(sc, "SillTop", CASING_X[0] - 16, OPEN_BOT - 8, CASING_X[1] + 16, OPEN_BOT + 16,
                        sc.vgrad(-12, 12, [("FFA27A54", 0.0), ("FF7A5638", 1.0)]), r=5),
             x=0.0, y=0.0, name="Sill")
    crown = rect_shape(sc, "Crown", -80, -20, W + 80, 30, sc.vgrad(-25, 25, [("FF6A4630", 0.0), ("FF3A2618", 1.0)]))

    left, slot_book = bookcase(sc, "CaseL", *CASE_L, 5101, True)
    right, _ = bookcase(sc, "CaseR", *CASE_R, 5102, False)

    # the lamp's warm glow on the wall (flickers) and the window's cold spill
    wall_glow = E(O, "WallGlow", LAMP[0] + 40, 1000, 900, 760, sc.rgrad(450, [("50FFC870", 0.0), ("20FFA850", 0.5),
                                                                           ("00FFA850", 1.0)]))
    spill = d("Shape", arch_path(sc, CASING_X[0] - 60, CASING_X[1] + 60, OPEN_BOT + 60, 540.0, 600.0, cy=ARCH_CY - 20),
              sc.rgrad(420, [("249CB4E0", 0.0), ("009CB4E0", 1.0)], cy=60.0), x=540.0, y=600.0, name="WindowSpill")

    clock, clock_box = grandfather_clock(sc)
    flutter = book_flutter(sc, slot_book)
    # festive (December): a pine garland with lights along one board of each bookcase
    garlands, light_nodes = [], []
    for k, (a, b) in enumerate(((CASE_L[0] + 30, CASE_L[1] - 6), (CASE_R[0] + 6, CASE_R[1] - 30))):
        swag, bulbs = [], []
        hooks = [a + (b - a) * i / 3 for i in range(4)]
        for p, q in zip(hooks, hooks[1:]):
            for t in (0.0, 0.25, 0.5, 0.75):
                swag.append((p + (q - p) * t, GARLAND_BOARD + 10 + 34 * math.sin(math.pi * t)))
        swag.append((hooks[-1], GARLAND_BOARD + 10))
        bulbs = [(x, y + 8) for i, (x, y) in enumerate(swag) if i % 2 == 1]
        with sc.minting(sc.d9):
            garlands.append(d("Node",
                              *[E(O, f"GarlandBow{k}{i}", x, GARLAND_BOARD + 10, 22, 14, F("FFA8383E"))
                                for i, x in enumerate(hooks)],
                              S(O, f"GarlandTips{k}", swag, L("FF4E8A5A", 9), closed=False),
                              S(O, f"GarlandBody{k}", swag, L("FF2A5A3C", 20), closed=False),
                              x=0.0, y=0.0, name=f"GarlandRun{k}"))
        lights = world_kit.festive_lights(sc, sc.d9, bulbs, ("FFFFD27A", "FFFF8A6A"))
        if k:
            lights.attrs["name"] = "FestiveLights1"
            sc.layers[-1].attrs["name"] = "FestiveTwinkle1"
            sc.anims[-1].attrs["name"] = "amb_festive1"
        light_nodes.append(lights)
    with sc.minting(sc.d9):
        festive_decor = d("Node", sc.bind("festive", 18, lin_conv(sc, 1.0, lo=0.0, hi=1.0), doc=sc.d9), *garlands,
                          x=0.0, y=0.0, opacity=0.0, name="FestiveDecor")
    plane2 = [flutter, *light_nodes, festive_decor, clock, crown, sill, keystone, casing, reveal, spill, wall_glow,
              right, left, wainscot, stripes, wall]
    return plane2, clock_box


def grandfather_clock(sc: Scene) -> tuple[El, tuple[float, float, float, float]]:
    """The clock: hood, face (10 past 10), trunk with a glass door, the pendulum swinging behind it in an
    idle loop (the `clockChime` layer's idle state, `PENDULUM_PERIOD`); the chime swings it wider for two
    periods and rings three arcs off the hood. Returns the node and the clock's hit box (cx, cy, w, h)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    cx = CLOCK_X
    fx, fy, fr = CLOCK_FACE
    tx0, ty0, tx1, ty1 = CLOCK_TRUNK
    gx0, gy0, gx1, gy1 = CLOCK_GLASS
    wood = [("FF6A3E26", 0.0), ("FF4A2A18", 1.0)]
    hood = d("Node",
             S(O, "Finial", [(cx - 6, 588, "c"), (cx, 566), (cx + 6, 588, "c")], F("FFC8A052")),
             S(O, "Pediment", [(cx - 66, 640, "c"), (cx - 66, 622, "c"), (cx - 40, 604), (cx, 590), (cx + 40, 604),
                               (cx + 66, 622, "c"), (cx + 66, 640, "c")],
               sc.vgrad(-25, 25, [("FF7A4A2E", 0.0), ("FF4E2C1A", 1.0)]), L(INK, 2)),
             rect_shape(sc, "HoodBox", cx - 58, 636, cx + 58, 754, d("Fill", lin(d, -58, 0, 58, 0, wood), name="Fill"),
                        r=4),
             x=0.0, y=0.0, name="ClockHood")
    ticks = multi(sc, "FaceTicks", [smooth_path(d, [(fx + (fr - 4) * math.cos(a), fy + (fr - 4) * math.sin(a), "c"),
                                                    (fx + (fr - 10) * math.cos(a), fy + (fr - 10) * math.sin(a), "c")],
                                                closed=False)
                                    for a in (2 * math.pi * i / 12 for i in range(12))], L("FF2A2026", 2.2))
    hands = d("Node",
              E(O, "HandHub", fx, fy, 6, 6, F("FF2A2026")),
              S(O, "HandMinute", [(fx, fy), (fx + 27 * math.cos(-1.05), fy + 27 * math.sin(-1.05))], L("FF2A2026", 2.4),
                closed=False),
              S(O, "HandHour", [(fx, fy), (fx + 18 * math.cos(-2.6), fy + 18 * math.sin(-2.6))], L("FF2A2026", 3.4),
                closed=False),
              x=0.0, y=0.0, name="ClockHands")
    face = d("Node", hands, ticks,
             E(O, "FaceDisc", fx, fy, 2 * fr, 2 * fr, sc.rgrad(fr, [("FFF2E8D2", 0.0), ("FFD8CAAA", 1.0)])),
             E(O, "FaceBezel", fx, fy, 2 * fr + 10, 2 * fr + 10, F("FFC8A052"), L(INK, 2)),
             x=0.0, y=0.0, name="ClockFace")
    # the pendulum behind the door glass
    px, py = PENDULUM_PIVOT
    bob_y = PENDULUM_LEN
    swing = d("Node",
              E(O, "BobShine", -5, bob_y - 5, 9, 7, F("90FFF0C8")),
              E(O, "Bob", 0, bob_y, 34, 34, sc.rgrad(17, [("FFE8C670", 0.0), ("FFA87A2C", 1.0)]), L("FF5A3E16", 2)),
              rect_shape(sc, "Rod", -2.5, 0, 2.5, bob_y, F("FFB89048")),
              x=px, y=py, name="PendulumSwing")
    door_clip = rect_shape(sc, "DoorGlassClip", gx0, gy0, gx1, gy1, None, r=6)
    pendulum = d("Node", d("ClippingShape", sourceId=door_clip.ref(), name="Clip"), swing,
                 rect_shape(sc, "TrunkInside", gx0, gy0, gx1, gy1, sc.vgrad(-140, 140, [("FF1C100A", 0.0),
                                                                                        ("FF2A1A10", 1.0)])),
                 x=0.0, y=0.0, name="Pendulum")
    glass_hi = S(O, "DoorGlassHi", [(gx0 + 10, gy0 + 20), (gx0 + 18, gy0 + 120)], L("40E8F0F8", 4), closed=False)
    door_frame = d("Shape", rect_path(sc, gx0 - 9, gy0 - 9, gx1 + 9, gy1 + 9, cx, (gy0 + gy1) / 2, r=8),
                   rect_path(sc, gx0, gy0, gx1, gy1, cx, (gy0 + gy1) / 2, name="Opening", r=6),
                   d("Fill", lin(d, -40, 0, 40, 0, [("FF8A5A38", 0.0), ("FF5A3620", 1.0)]), fillRule="evenOdd",
                     name="Fill"), x=cx, y=(gy0 + gy1) / 2, name="DoorFrame")
    trunk = rect_shape(sc, "Trunk", tx0, ty0, tx1, ty1, d("Fill", lin(d, -55, 0, 55, 0, wood), name="Fill"))
    base = d("Node",
             rect_shape(sc, "BaseCap", tx0 - 10, ty1 - 4, tx1 + 10, ty1 + 10, F("FF7A4A2E"), r=3),
             rect_shape(sc, "BaseBox", tx0 - 6, ty1, tx1 + 6, FLOOR_Y + 4,
                        d("Fill", lin(d, -60, 0, 60, 0, wood), name="Fill")),
             x=0.0, y=0.0, name="ClockBase")
    rings = [S(O, f"ChimeRing{k}", [(-16, -20), (0, -27 - 3 * k), (16, -20)], L("C0FFE8B8", 3.2), closed=False,
               origin=O, opacity=0.0) for k in range(3)]
    ring_nodes = [d("Node", r_k, x=cx + sx * 74, y=640.0 + 14 * k, rotation=sx * 1.2, name=f"ChimeRingSide{k}")
                  for k, (r_k, sx) in enumerate(zip(rings, (-1, 1, 1)))]
    clock = d("Node", *ring_nodes, face, hood, glass_hi, door_frame, pendulum, door_clip, trunk, base,
              E(O, "ClockShadow", cx + 30, 900, 150, 640, sc.rgrad(75, [("50100806", 0.0), ("00100806", 1.0)])),
              x=0.0, y=0.0, name="Clock")

    # the idle swing loop and the chime: one layer, idle <-> chime, both crossing 0 at their frame 0
    n = PENDULUM_PERIOD
    idle = sc.A("amb_pendulum", n, [sc.T(swing, ease=None, rotation=sine_keys(n, lambda f: SWING, n))], loop=True)
    m = EVENT_FRAMES["clockChime"]

    def amp(f: int) -> float:
        t = f / m
        return SWING + (CHIME_SWING - SWING) * math.sin(math.pi * min(1.0, t * 1.15)) ** 1.2

    ring_tracks = []
    for r_k, f0 in zip(rings, (8, 50, 96)):
        ring_tracks.append(sc.T(r_k, ease=None, opacity=[(0, 0.0), (f0, 0.0, "hold"), (f0 + 1, 1.0), (f0 + 40, 0.0),
                                                         (m, 0.0)],
                                scaleX=[(0, 0.6), (f0, 0.6, "hold"), (f0 + 1, 0.6), (f0 + 40, 1.8), (m, 1.8)],
                                scaleY=[(0, 0.6), (f0, 0.6, "hold"), (f0 + 1, 0.6), (f0 + 40, 1.8), (m, 1.8)]))
    chime = sc.A("ev_clockChime", m, [sc.T(swing, ease=None, rotation=sine_keys(m, amp, n)), *ring_tracks])
    # the rings rest invisible while idle: the idle loop keys them at their rest values
    idle.children += [sc.T(r_k, ease=None, opacity=[(0, 0.0)], scaleX=[(0, 0.6)], scaleY=[(0, 0.6)]) for r_k in rings]
    st_idle = d("AnimationState", animationId=idle.ref(), x=0.0, y=100.0)
    st_play = d("AnimationState",
                d("StateTransition", stateToId=st_idle.ref(), enableExitTime=True, exitTimeIsPercetange=True,
                  exitTime=100, duration=100),
                animationId=chime.ref(), x=200.0, y=260.0)
    st_idle.add(d("StateTransition", *sc.cond("clockChime"), stateToId=st_play.ref(), duration=100))
    sc.layers.append(sc._layer("Event_clockChime", st_idle, [st_idle, st_play]))
    return clock, (cx, 836.0, 150.0, 420.0)


def book_flutter(sc: Scene, slot_book: El | None) -> El:
    """`bookFlutter`: the slot book slides off its shelf, opens and flutters across the room like a bird
    (covers beating), loops back and slots in again. Returns the node (`FlutterBook`)."""
    assert slot_book is not None
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    sx, row, sw, sh = SLOT
    bot = BOARDS[row + 1]
    home = (sx + sw / 2, bot - sh / 2)
    # the flying book: two covers hinged on the spine, pages inside; scaleX beats them like wings
    covers = []
    for k, s_ in enumerate((-1.0, 1.0)):
        page = S(O, f"FlyPage{k}", [(0, -26), (s_ * 34, -30), (s_ * 40, -24, "c"), (s_ * 40, 26, "c"), (s_ * 34, 30),
                                    (0, 26)], F("FFEDE2CA"), L("FFB8A888", 1.4), origin=O)
        lines = S(O, f"FlyLines{k}", [(s_ * 8, -14), (s_ * 30, -16)], L("60806848", 1.6), closed=False, origin=O)
        cover = S(O, f"FlyCover{k}", [(0, -32, "c"), (s_ * 44, -34, "c"), (s_ * 46, 34, "c"), (0, 32, "c")],
                  F("FF7A3028"), L(INK, 2), origin=O)
        covers.append(d("Node", lines, page, cover, x=0.0, y=0.0, scaleX=0.1, name=f"FlyWing{k}"))
    spine = rect_shape(sc, "FlySpine", -4, -33, 4, 33, F("FF5E2420"), r=2)
    fly_inner = d("Node", covers[0], covers[1], spine, x=0.0, y=0.0, name="FlyTilt")
    fly = d("Node", fly_inner, x=home[0], y=home[1], opacity=0.0, name="FlyBook")
    flutter = d("Node", fly, slot_book, x=0.0, y=0.0, name="FlutterBook")

    n = EVENT_FRAMES["bookFlutter"]
    path = [(0, home), (22, (home[0] + 26, home[1] - 4)), (60, (330.0, 360.0)), (100, (520.0, 270.0)),
            (140, (660.0, 380.0)), (175, (520.0, 520.0)), (205, (330.0, 520.0)), (226, (home[0] + 26, home[1] - 4)),
            (236, home), (n, home)]
    xs = [(f, p[0]) for f, p in path]
    ys = [(f, p[1]) for f, p in path]
    beat = []
    f = 26
    while f < 204:
        beat += [(f, 1.0), (f + 7, 0.25)]
        f += 14
    wing_keys = uniq([(0, 0.1), (22, 0.1), *beat, (212, 0.85), (224, 0.1), (n, 0.1)])
    tilt = [(0, 0.0), (22, 0.0), (60, -0.25), (100, 0.15), (140, 0.4), (175, 0.2), (205, -0.15), (226, 0.0), (n, 0.0)]
    tracks = [sc.T(fly, x=xs, y=ys, opacity=[(0, 0.0), (21, 0.0, "hold"), (22, 1.0, "hold"), (226, 1.0, "hold"),
                                              (227, 0.0, "hold"), (n, 0.0)],
                   scaleX=[(0, 0.6), (22, 0.6), (40, FLY_SCALE), (205, FLY_SCALE), (226, 0.6), (n, 0.6)],
                   scaleY=[(0, 1.0), (22, 1.0), (40, FLY_SCALE), (205, FLY_SCALE), (226, 1.0), (n, 1.0)]),
              sc.T(fly_inner, rotation=tilt, y=[(0, 0.0)] + [(k, -6.0 if (k // 7) % 2 else 0.0) for k in range(28, 204, 7)]
                   + [(212, 0.0), (n, 0.0)]),
              *[sc.T(c, ease=None, scaleX=[(f_, v, "linear") for f_, v in wing_keys]) for c in covers],
              sc.T(slot_book, opacity=[(0, 1.0), (21, 1.0, "hold"), (22, 0.0, "hold"), (226, 0.0, "hold"),
                                       (227, 1.0, "hold"), (n, 1.0)],
                   x=[(0, 0.0), (20, 18.0), (22, 18.0), (227, 18.0), (n, 0.0)])]
    sc.one_shot("bookFlutter", sc.A("ev_bookFlutter", n, tracks))
    return flutter


# ---------------------------------------------------------------- Plane3: the desk, the lamp, the ladder
def desk_and_ladder(sc: Scene) -> list[El]:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    x0, top, x1 = DESK
    desk = d("Node",
             rect_shape(sc, "DeskTopEdge", x0, top + 14, x1, top + 24, F("FF3E2414")),
             rect_shape(sc, "DeskTop", x0 - 6, top, x1 + 6, top + 16,
                        sc.vgrad(-8, 8, [("FF9A6A44", 0.0), ("FF6A4228", 1.0)]), r=3),
             multi(sc, "DeskDrawer", [rect_path(sc, a, top + 34, b, top + 86, r=4) for a, b in ((20, 150), (176, 306))],
                   sc.L("FF2A1A0E", 3)),
             multi(sc, "DeskPull", [d("Ellipse", width=22.0, height=6.0, x=float(x), y=float(top + 60), name="Path")
                                    for x in (85.0, 241.0)], F("FFC8A052")),
             rect_shape(sc, "DeskApron", x0, top + 22, x1, top + 100,
                        sc.vgrad(-40, 40, [("FF6A4228", 0.0), ("FF4A2C18", 1.0)])),
             *[rect_shape(sc, f"DeskLeg{k}", x - 11, top + 96, x + 11, DESK_FOOT_Y, sc.vgrad(-60, 60, [
                 ("FF5A3820", 0.0), ("FF3A2414", 1.0)]), r=3) for k, x in enumerate((6.0, x1 - 18))],
             rect_shape(sc, "DeskUnder", x0, top + 96, x1, DESK_FOOT_Y - 6, F("FF1A100A")),
             x=0.0, y=0.0, name="Desk")
    # the banker's lamp: brass base and stem, green glass shade, its glow under the shade
    lx, ly = LAMP
    s0, s1 = SHADE_Y
    lamp = d("Node",
             S(O, "LampChain", [(lx + 30, s1 - 2), (lx + 32, s1 + 22)], L("FFC8A052", 1.6), closed=False),
             E(O, "LampChainBead", lx + 32, s1 + 24, 6, 6, F("FFC8A052")),
             S(O, "LampShade", [(lx - 74, s1, "c"), (lx - 70, s0 + 18), (lx - 50, s0 + 2), (lx, s0 - 2), (lx + 50, s0 + 2),
                                (lx + 70, s0 + 18), (lx + 74, s1, "c")],
               sc.vgrad(-20, 20, [("FF4E8A62", 0.0), ("FF2A5A40", 0.6), ("FF1E4430", 1.0)]), L("FF1A2A1E", 2)),
             S(O, "LampShadeHi", [(lx - 50, s0 + 10), (lx, s0 + 4), (lx + 40, s0 + 8)], L("70D8F0D8", 3), closed=False),
             rect_shape(sc, "LampStem", lx - 4, s1, lx + 4, ly - 6, F("FFB88A3C")),
             S(O, "LampBase", [(lx - 40, ly + 4, "c"), (lx - 34, ly - 8), (lx, ly - 14), (lx + 34, ly - 8),
                               (lx + 40, ly + 4, "c")], sc.vgrad(-9, 9, [("FFE0B866", 0.0), ("FF9A6A28", 1.0)]),
               L("FF4A3010", 1.6)),
             x=0.0, y=0.0, name="Lamp")
    lamp_glow = E(O, "LampGlow", lx, s1 + 40, 260, 120, sc.rgrad(130, [("90FFE6A0", 0.0), ("30FFC870", 0.5),
                                                                       ("00FFC870", 1.0)]))
    lamp_bulb = E(O, "LampBulb", lx, s1 + 2, 100, 10, F("FFFFF0C0"))
    # the open book on the desk
    bx, by = BOOK_AT
    book = d("Node",
             S(O, "BookLines", [(bx - 52, by - 12), (bx - 12, by - 14)], L("50806848", 1.4), closed=False),
             S(O, "BookLines2", [(bx + 12, by - 14), (bx + 52, by - 12)], L("50806848", 1.4), closed=False),
             S(O, "BookPageL", [(bx, by, "c"), (bx - 30, by - 20), (bx - 64, by - 14, "c"), (bx - 64, by + 4, "c"),
                                (bx - 30, by - 2)], F("FFF0E6CE"), L("FFB8A888", 1.4)),
             S(O, "BookPageR", [(bx, by, "c"), (bx + 30, by - 20), (bx + 64, by - 14, "c"), (bx + 64, by + 4, "c"),
                                (bx + 30, by - 2)], F("FFE6DAC0"), L("FFB8A888", 1.4)),
             S(O, "BookCover", [(bx - 68, by - 8, "c"), (bx, by + 6), (bx + 68, by - 8, "c"), (bx + 68, by + 8, "c"),
                                (bx, by + 12, "c"), (bx - 68, by + 8, "c")], F("FF6E2A28")),
             x=0.0, y=0.0, name="OpenBook")
    candle = candle_art(sc, "DeskCandle", DESK_CANDLE[0], DESK_CANDLE[1], 60.0)
    # dust motes drifting in the lamp's light (decorative: hidden at tier low)
    motes, mote_tracks = [], []
    r_ = random.Random(3307)
    n = 240
    for k in range(8):
        x0_, y0_ = r_.uniform(40, 290), r_.uniform(900, 1060)
        p = E(O, f"Mote{k}", x0_, y0_, 4, 4, F("C0FFE8C0"), opacity=0.0)
        motes.append(p)
        off = (k * 30) % n
        fr = sorted({0, n, *range(0, n + 1, 20), (n - off - 1) % n, (n - off) % n})

        def at(f: int, off: int = off, k: int = k) -> tuple[float, float, float]:
            t = ((f + off) % n) / n
            return (14 * math.sin(2 * math.pi * t + k), -60 * t, math.sin(math.pi * t) ** 1.5 * 0.8)

        mode = {f: ("hold" if f == (n - off - 1) % n and off else "linear") for f in fr}
        mote_tracks.append(sc.T(p, ease=None, x=[(f, x0_ + at(f)[0], mode[f]) for f in fr],
                                y=[(f, y0_ + at(f)[1], mode[f]) for f in fr],
                                opacity=[(f, at(f)[2], mode[f]) for f in fr]))
    sc.ambient("DustMotes", sc.A("amb_DustMotes", n, mote_tracks, loop=True))
    dust = d("Node", *motes, x=0.0, y=0.0, name="DustMotes")

    # the rail and the rolling ladder (the `ladder` aim drag)
    rail = d("Node",
             *[rect_shape(sc, f"RailBracket{k}", x - 5, RAIL_Y - 4, x + 5, RAIL_Y + 18, F("FF8A6428"), r=2)
               for k, x in enumerate((726.0, 1060.0))],
             S(O, "RailRod", [(RAIL_X[0], RAIL_Y), (RAIL_X[1], RAIL_Y)], L("FFD0A858", 7), closed=False),
             S(O, "RailShadow", [(RAIL_X[0], RAIL_Y + 6), (RAIL_X[1], RAIL_Y + 6)], L("50100806", 6), closed=False),
             x=0.0, y=0.0, name="LadderRail")
    plane3 = [dust, lamp_bulb, lamp, lamp_glow, book, candle, ladder(sc), rail, desk]
    return plane3


def candle_art(sc: Scene, name: str, x: float, base: float, h: float) -> El:
    """A candle in a brass holder at (x, base): the stick `h` tall, a flame that flickers (its own loop)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    top = base - 8 - h
    flame = d("Node",
              S(O, f"{name}FlameCore", [(0, 0, "c"), (-4, -8), (0, -20, "c"), (4, -8)], F("FFFFF6D0"), origin=O),
              S(O, f"{name}Flame", [(0, 2, "c"), (-7, -9), (0, -30, "c"), (7, -9)], F("FFFFC860"), origin=O),
              x=x, y=top - 2, name=f"{name}FlameNode")
    glow = E(O, f"{name}Glow", x, top - 14, 120, 120, sc.rgrad(60, [("60FFD080", 0.0), ("00FFC060", 1.0)]))
    stick = d("Node",
              S(O, f"{name}Wick", [(x, top), (x, top - 4)], L("FF2A2026", 1.6), closed=False),
              S(O, f"{name}Drip", [(x + 5, top + 2), (x + 8, top + 12), (x + 6, top + 18)], L("FFEDE4D2", 3), closed=False),
              rect_shape(sc, f"{name}Stick", x - 8, top, x + 8, base - 6,
                         sc.d("Fill", lin(sc.d, -8, 0, 8, 0, [("FFF2EADA", 0.0), ("FFC8BCA4", 1.0)]), name="Fill"), r=2),
              S(O, f"{name}Holder", [(x - 24, base, "c"), (x - 18, base - 8), (x + 18, base - 8), (x + 24, base, "c")],
                F("FFC8A052"), L("FF4A3010", 1.4)),
              x=0.0, y=0.0, name=f"{name}Body")
    per = 40
    r_ = random.Random(len(name) * 31 + int(x))
    fs = [0, 9, 17, 26, 33, per]
    sc.ambient(f"{name}Flicker", sc.A(f"amb_{name}Flicker", per, [
        sc.T(flame, scaleY=[(f, 1.0 if f in (0, per) else round(r_.uniform(0.84, 1.14), 3)) for f in fs],
             rotation=[(f, 0.0 if f in (0, per) else round(r_.uniform(-0.1, 0.1), 3)) for f in fs]),
        sc.T(glow, opacity=[(f, 1.0 if f in (0, per) else round(r_.uniform(0.82, 1.0), 3)) for f in fs])],
        loop=True))
    return d("Node", flame, glow, stick, x=0.0, y=0.0, name=name)


def ladder_points() -> list[tuple[float, float]]:
    """The ladder's art outline at ladder 0 (artboard px): hooks, stiles, wheels."""
    hw0, hw1 = LADDER_HW
    out = []
    for s in (-1, 1):
        out += [(LADDER_X + s * (hw0 + STILE_W / 2 + 10), RAIL_Y - 16), (LADDER_X + s * (hw0 - STILE_W / 2), RAIL_Y - 16),
                (LADDER_X + s * (hw1 + STILE_W / 2), LADDER_FOOT_Y),
                (LADDER_X + s * (hw1 + WHEEL_R + 1), LADDER_FOOT_Y + 8 + WHEEL_R + 1),
                (LADDER_X + s * (hw1 + 30), LADDER_FOOT_Y + 22 + 7)]   # its shadow on the floor
    return out


def ladder_rect(pad: float = 6.0) -> tuple[float, float, float, float]:
    """The ladder's art box over every `ladder` in -1..1 (artboard px at parallax 0), clamped to the
    artboard: the drag handle's rect (contract v12 drag table, library `ladder`)."""
    xs = [x for x, _ in ladder_points()]
    ys = [y for _, y in ladder_points()]
    return (float(math.floor(min(xs) - LADDER_TRAVEL - pad)), float(math.floor(min(ys) - pad)),
            float(min(W, math.ceil(max(xs) + LADDER_TRAVEL + pad))), float(math.ceil(max(ys) + pad)))


def ladder(sc: Scene) -> El:
    """The rolling ladder: two stiles hooked over the rail, eleven rungs, two wheels. Its node's x is
    `LADDER_X + LADDER_TRAVEL x ladder` (clamped), its wheels turn by the distance rolled (history-free)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    hw0, hw1 = LADDER_HW
    y0, y1 = RAIL_Y + 2, LADDER_FOOT_Y

    def hw(y: float) -> float:
        return hw0 + (hw1 - hw0) * (y - y0) / (y1 - y0)

    wood = [("FFA8784C", 0.0), ("FF6E4A2C", 1.0)]
    stiles = [S(O, f"Stile{k}", [(s * (hw0 - STILE_W / 2), y0, "c"), (s * (hw0 + STILE_W / 2), y0, "c"),
                                 (s * (hw1 + STILE_W / 2), y1, "c"), (s * (hw1 - STILE_W / 2), y1, "c")],
                d("Fill", lin(d, -STILE_W / 2, 0, STILE_W / 2, 0, wood if s < 0 else wood[::-1]), name="Fill"),
                L("FF3A2414", 1.6))
              for k, s in enumerate((-1, 1))]
    rung_ys = [y for y in (y0 + 70 + 84 * i for i in range(14)) if y < y1 - 40]
    rungs = multi(sc, "Rungs", [rect_path(sc, -hw(y) + 4, y - 5, hw(y) - 4, y + 5, r=3) for y in rung_ys],
                  d("Fill", lin(d, 0, -5, 0, 5, [("FFB88A5A", 0.0), ("FF7A5232", 1.0)]), name="Fill"))
    rung_shadow = multi(sc, "RungShadow", [rect_path(sc, -hw(y) + 6, y + 5, hw(y) - 6, y + 11) for y in rung_ys],
                        F("50100806"))
    hooks = multi(sc, "Hooks", [smooth_path(d, [(s * hw0, y0 + 6), (s * hw0, RAIL_Y - 8), (s * (hw0 + 6), RAIL_Y - 14),
                                                (s * (hw0 + 12), RAIL_Y - 6)], closed=False) for s in (-1, 1)],
                  sc.L("FF3A3440", 5))
    wheels = []
    for k, s in enumerate((-1, 1)):
        spin = d("Node", sc.bind("ladder", 15, lin_conv(sc, LADDER_TRAVEL / WHEEL_R), doc=sc.d9),
                 multi(sc, f"WheelSpoke{k}", [smooth_path(d, [(-WHEEL_R + 3, 0, "c"), (WHEEL_R - 3, 0, "c")], closed=False),
                                              smooth_path(d, [(0, -WHEEL_R + 3, "c"), (0, WHEEL_R - 3, "c")], closed=False)],
                       sc.L("FF8A8490", 2)),
                 E(O, f"WheelHub{k}", 0, 0, 6, 6, F("FFC8A052")),
                 E(O, f"WheelRim{k}", 0, 0, 2 * WHEEL_R, 2 * WHEEL_R, F("FF2E2A32"), L("FF141018", 2)),
                 x=float(s * hw1), y=float(y1 + 8), name=f"LadderWheel{k}")
        wheels.append(spin)
    brackets = multi(sc, "FootBrackets", [rect_path(sc, s * hw1 - 8, y1 - 10, s * hw1 + 8, y1 + 6, r=2) for s in (-1, 1)],
                     F("FF8A6428"))
    shadow = E(O, "LadderShadow", 0, y1 + 22, 2 * hw1 + 60, 14, F("50100806"))
    lo, hi = LADDER_X - LADDER_TRAVEL, LADDER_X + LADDER_TRAVEL
    return d("Node", sc.bind("ladder", 13, lin_conv(sc, LADDER_TRAVEL, LADDER_X, lo=lo, hi=hi), doc=sc.d9),
             *wheels, brackets, hooks, rung_shadow, rungs, *stiles, shadow, x=LADDER_X, y=0.0, name="Ladder")


# ---------------------------------------------------------------- Plane4: the floor
def floor(sc: Scene) -> list[El]:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    fl = rect_shape(sc, "Floor", -90, FLOOR_Y - 10, W + 90, H + 60,
                    sc.vgrad(-(H + 70 - FLOOR_Y) / 2, (H + 70 - FLOOR_Y) / 2, [("FF4E3222", 0.0), ("FF2A1A10", 1.0)]))
    planks = multi(sc, "Plank", [smooth_path(d, [(x0, FLOOR_Y, "c"), (x0 + (x0 - 540) * 1.9, H + 60, "c")], closed=False)
                                 for x0 in range(-240, 1340, 110)], L("50140A04", 3))
    seams = multi(sc, "PlankJoint", [smooth_path(d, [(x, y_, "c"), (x + 60 + (x - 540) * 0.08, y_, "c")], closed=False)
                                     for x, y_ in ((60, 1290), (380, 1380), (700, 1260), (180, 1640), (930, 1700),
                                                   (520, 1840))], L("40140A04", 2.5))
    shade = rect_shape(sc, "FloorShade", -90, FLOOR_Y - 10, W + 90, FLOOR_Y + 50,
                       sc.vgrad(-30, 30, [("90100806", 0.0), ("00100806", 1.0)]))
    rx, ry, rw, rh = RUG
    rug = d("Node",
            *[E(O, f"RugMotif{k}", rx + dx, ry + dy, 46, 18, F("FFC89A50")) for k, (dx, dy) in
              enumerate(((-200, 0), (200, 0), (0, -84), (0, 84)))],
            E(O, "RugMedallion", rx, ry, 200, 70, F("FF2C3A5A"), L("FFC89A50", 3)),
            E(O, "RugField", rx, ry, rw - 90, rh - 50, F("FF7A2A26")),
            E(O, "RugBorder", rx, ry, rw - 40, rh - 18, F("FF2C3A5A")),
            E(O, "RugEdge", rx, ry, rw, rh, F("FFB8884A")),
            x=0.0, y=0.0, name="Rug")
    key = gen_scenes.SCENES[SCENE_ID].key
    with sc.minting(sc.d9):
        pool_grad = rad(sc.d, 0.0, 0.0, 380.0, [(key, 0.0), ("00" + key[2:], 1.0)])
        pool_grad.children[0].children.append(sc.bind("lightKey", 38, doc=sc.d9))
        pool_grad.attrs["opacity"] = 0.36
    pool = d("Shape", ellipse(d, 760, 760), d("Fill", pool_grad, name="Fill"), x=200.0, y=FLOOR_Y + 120,
             scaleY=0.34, name="FloorPool")
    # the globe on its stand
    gx, gy, gr = GLOBE
    gb = GLOBE_BASE_Y
    globe = d("Node",
              S(O, "GlobeMeridian", [(gx - 8, gy - gr - 10), (gx + gr * 0.7, gy - gr * 0.72), (gx + gr + 10, gy + 8),
                                     (gx + gr * 0.62, gy + gr * 0.8), (gx + 8, gy + gr + 10)], L("FFC8A052", 5),
                closed=False),
              E(O, "GlobeShine", gx - 22, gy - 24, 30, 20, F("50FFFFFF")),
              *[S(O, f"GlobeLand{k}", fluff(gx + dx, gy + dy, rx_, ry_, 5, 0.18, a0=k), F("FFB89A62"))
                for k, (dx, dy, rx_, ry_) in enumerate(((-18, -14, 22, 16), (20, 14, 18, 24), (-10, 34, 14, 10)))],
              E(O, "GlobeBall", gx, gy, 2 * gr, 2 * gr, sc.rgrad(gr, [("FF5E8496", 0.0), ("FF2E4A5A", 1.0)],
                                                                 cx=-gr * 0.3, cy=-gr * 0.3), L(INK, 2)),
              S(O, "GlobePost", [(gx, gy + gr + 4), (gx, gb - 40)], L("FF5A3820", 8), closed=False),
              S(O, "GlobeLegs", [(gx - 60, gb, "c"), (gx, gb - 46, "c"), (gx + 60, gb, "c")], L("FF5A3820", 8),
                closed=False),
              E(O, "GlobeShadow", gx, gb + 4, 170, 20, F("50100806")),
              x=0.0, y=0.0, name="Globe")
    chair = reading_chair(sc)
    floor_light = d("Node", x=0.0, y=0.0, name="LightningFloor", opacity=0.0)
    sc._library_keep["floor_light"] = floor_light   # type: ignore[attr-defined]
    return [chair, globe, floor_light, pool, rug, shade, seams, planks, fl]


def reading_chair(sc: Scene) -> El:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    x0, y0, x1, y1 = CHAIR
    cx = (x0 + x1) / 2
    leather = [("FF7A3028", 0.0), ("FF4E1C18", 1.0)]
    back = S(O, "ChairBack", [(x0 + 40, y0 + 190, "c"), (x0 + 34, y0 + 60), (x0 + 60, y0 + 6), (cx, y0 - 6),
                              (x1 - 60, y0 + 6), (x1 - 34, y0 + 60), (x1 - 40, y0 + 190, "c")],
             sc.vgrad(-100, 100, leather), L(INK, 2.4))
    buttons = multi(sc, "ChairButton", [d("Ellipse", width=7.0, height=7.0, x=float(cx + dx), y=float(y0 + dy),
                                          name="Path") for dx, dy in ((-50, 60), (0, 54), (50, 60), (-25, 110),
                                                                      (25, 110))], F("FF3A1410"))
    seat = S(O, "ChairSeat", [(x0 + 44, y0 + 200), (cx, y0 + 186), (x1 - 44, y0 + 200), (x1 - 40, y0 + 228, "c"),
                              (x0 + 40, y0 + 228, "c")], sc.vgrad(-20, 20, [("FF8A3A30", 0.0), ("FF5E2420", 1.0)]),
             L(INK, 2))
    arms = [S(O, f"ChairArm{k}", [(a - 24, y0 + 120), (a, y0 + 106), (a + 24, y0 + 120), (a + 22, y0 + 250, "c"),
                                  (a - 22, y0 + 250, "c")], sc.vgrad(-70, 70, leather), L(INK, 2.2))
            for k, a in enumerate((x0 + 28, x1 - 28))]
    skirt = rect_shape(sc, "ChairSkirt", x0 + 10, y0 + 226, x1 - 10, y0 + 280,
                       sc.vgrad(-27, 27, [("FF5E2420", 0.0), ("FF3A1410", 1.0)]), r=6)
    legs = multi(sc, "ChairLegs", [rect_path(sc, x - 7, y0 + 278, x + 7, y1, r=2) for x in (x0 + 34, x1 - 34)],
                 F("FF2A1A10"))
    shadow = E(O, "ChairShadow", cx, y1 + 2, x1 - x0 + 40, 26, F("50100806"))
    return d("Node", *arms, seat, buttons, back, skirt, legs, shadow, x=0.0, y=0.0, name="ReadingChair")


# ---------------------------------------------------------------- Plane5: the foreground
def foreground(sc: Scene) -> list[El]:
    F, L, d = sc.F, sc.L, sc.d
    slabs = []
    for k, (x0, x1, y, h, col) in enumerate(((-20, 250, 1870, 60, "FF2C3A5A"), (0, 228, 1820, 50, "FF6E2A28"),
                                             (-10, 236, 1778, 42, "FF2C4638"), (18, 206, 1744, 34, "FF8A6A38"))):
        slabs.append(d("Node",
                       rect_shape(sc, f"StackPages{k}", x1 - 10, y + 4, x1 - 2, y + h - 4, F("FFE6DAC0")),
                       rect_shape(sc, f"StackBand{k}", x0 + 30, y + 6, x0 + 36, y + h - 6, F("FFC8A052")),
                       rect_shape(sc, f"StackBook{k}", x0, y, x1, y + h, F(col), r=4),
                       x=0.0, y=0.0, name=f"StackSlab{k}"))
    candle = candle_art(sc, "StackCandle", 112.0, 1744.0, 84.0)
    return [candle, d("Node", *slabs, x=0.0, y=0.0, name="BookStack")]


# ---------------------------------------------------------------- the lightning event
def lightning(sc: Scene, plane0: list[El], plane1: list[El], plane4: list[El]) -> El:
    """`lightning`: two flashes on the window (the glass, a bolt in the view), the window's light and the
    bookcases' shadows thrown across the floor for a few frames, a dim afterglow. Returns the full-frame
    wash (a screen overlay)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    n = EVENT_FRAMES["lightning"]
    bolt_pts = [(486, 150), (500, 250), (476, 330), (512, 430), (494, 500), (530, 590), (516, 640)]
    branch = [(476, 330), (446, 400), (452, 452)]
    bolt = d("Node",
             S(O, "BoltCore", bolt_pts, L("FFF4F8FF", 4.5), closed=False, tension=0.0),
             S(O, "BoltBranch", branch, L("FFE4ECFF", 2.6), closed=False, tension=0.0),
             S(O, "BoltGlow", bolt_pts, L("60A8C4FF", 18), closed=False, tension=0.0),
             x=0.0, y=0.0, opacity=0.0, name="Bolt")
    sky_flash = rect_shape(sc, "SkyFlash", VIEW[0], VIEW[1], VIEW[2], VIEW[3], F("FF9CB0D8"), opacity=0.0)
    # the bolt and the flash behind the town (the roofs show as silhouettes), over the moon and clouds
    at = next(i for i, e in enumerate(plane0) if e.attrs.get("name") == "Town") + 1
    plane0[at:at] = [bolt, sky_flash]
    glass_flash = d("Shape", arch_path(sc, GLASS_X[0], GLASS_X[1], GLASS[1], 540.0, 600.0), F("FFE2EAFF"),
                    x=540.0, y=600.0, opacity=0.0, name="GlassFlash")
    plane1[plane1.index("FLASH")] = glass_flash   # type: ignore[arg-type]
    # the floor: the window's light (its mullion and transom as dark bars) and the bookcases' shadows
    fl = sc._library_keep["floor_light"]   # type: ignore[attr-defined]
    cold = "FFC8D6F4"
    fl.children += [
        S(O, "FloorBar", [(536, FLOOR_Y, "c"), (548, FLOOR_Y, "c"), (640, 1760, "c"), (600, 1760, "c")], F("C0181820")),
        S(O, "FloorTransom", [(450, 1420, "c"), (690, 1420, "c"), (720, 1460, "c"), (430, 1460, "c")], F("A0181820")),
        S(O, "FloorWindow", [(400, FLOOR_Y, "c"), (680, FLOOR_Y, "c"), (900, 1780, "c"), (300, 1780, "c")],
          sc.vgrad(-280, 280, [(cold, 0.0), ("00" + cold[2:], 1.0)])),
        S(O, "ShelfShadowL", [(250, FLOOR_Y, "c"), (300, FLOOR_Y, "c"), (60, 1920, "c"), (-160, 1920, "c")],
          F("90080608")),
        S(O, "ShelfShadowR", [(730, FLOOR_Y, "c"), (780, FLOOR_Y, "c"), (1240, 1920, "c"), (1000, 1920, "c")],
          F("90080608")),
        S(O, "FloorFlood", [(-90, FLOOR_Y, "c"), (W + 90, FLOOR_Y, "c"), (W + 90, H + 60, "c"), (-90, H + 60, "c")],
          sc.vgrad(-400, 400, [("50" + cold[2:], 0.0), ("0C" + cold[2:], 1.0)])),
    ]
    wash = d("Shape", d("Rectangle", width=float(W + 40), height=float(H + 40), originX=0.0, originY=0.0, name="Path"),
             sc.vgrad(0, H, [("FFD8E2FF", 0.0), ("FFB8C8F0", 1.0)]), x=-20.0, y=-20.0, opacity=0.0, name="LightningWash")

    def flash(peaks: list[tuple[int, float]]) -> list[tuple]:
        return [(f, v, "hold") for f, v in peaks]

    sc.one_shot("lightning", sc.A("ev_lightning", n, [
        sc.T(glass_flash, ease=None, opacity=[(0, 0.0, "hold"), (2, 0.6), (5, 0.22), (8, 0.55), (13, 0.1, "linear"),
                                              (22, 0.22, "linear"), (n, 0.0)]),
        sc.T(sky_flash, ease=None, opacity=[(0, 0.0, "hold"), (2, 0.9), (5, 0.3), (8, 0.85), (13, 0.1, "linear"),
                                            (22, 0.18, "linear"), (n, 0.0)]),
        sc.T(bolt, ease=None, opacity=flash([(0, 0.0), (2, 1.0), (5, 0.0), (8, 1.0), (12, 0.0), (n, 0.0)])),
        sc.T(fl, ease=None, opacity=flash([(0, 0.0), (2, 0.85), (5, 0.15), (8, 0.7), (11, 0.0), (n, 0.0)])),
        sc.T(wash, ease=None, opacity=[(0, 0.0, "hold"), (2, 0.2), (5, 0.04), (8, 0.16), (13, 0.0, "linear"),
                                       (22, 0.05, "linear"), (n, 0.0)]),
    ]))
    return wash


# ---------------------------------------------------------------- flicker (the key light loops in the file)
def _flicker_tracks(sc: Scene, content: list[El]) -> None:
    def named(name: str) -> El:
        return next(e for e in gen_scenes.walk(content) if e.attrs.get("name") in (name, "emit" + name))
    glow, wall, pool = named("LampGlow"), named("WallGlow"), named("FloorPool")
    sc.ambient("LampFlicker", sc.A("amb_LampFlicker", FLICKER_FRAMES, [
        sc.T(glow, opacity=LAMP_FLICKER),
        sc.T(wall, opacity=[(f, round(0.85 + 1.0 * (v - 0.85), 4)) for f, v in LAMP_FLICKER]),
        sc.T(pool, opacity=[(f, round(0.9 + 1.0 * (v - 0.9), 4)) for f, v in LAMP_FLICKER])], loop=True))


# ====================================================================== the mouse
def mouse_path() -> tuple[list[float], list[float], list[float], list[float]]:
    """(npcX at each waypoint, x, y, scale) of the mouse's paw line along its path."""
    ts = arc_params([(x, y) for x, y, _ in MOUSE_WAYPOINTS])
    return ts, [x for x, _, _ in MOUSE_WAYPOINTS], [y for _, y, _ in MOUSE_WAYPOINTS], [s for _, _, s in MOUSE_WAYPOINTS]


def mouse_npc(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The mouse: two drawings (asleep curled; awake in profile, a torso that rears up on its haunches) in
    one path node `MouseNpc` (Plane4, in front of the chair), the `Npc` layer and the poke zone riding
    `npcX`. Drawn facing right in its own frame, mirrored to face the room's centre (left)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rig = Rig(sc)

    # ---- asleep, curled up (right-facing frame; mirrored below)
    sleep_body = d("Node",
                   S(Z, "SleepTail", [(-22, -6), (-20, 2), (-4, 5), (14, 4), (26, 0)], L(TAIL, 2.6), closed=False),
                   E(Z, "SleepNose", 27, -7, 4.5, 3.6, F(PINK)),
                   S(Z, "SleepEye", [(14, -11), (18, -9), (22, -11)], L(INK, 1.6), closed=False),
                   E(Z, "SleepEarIn", 9, -22, 8, 9, F(PINK)),
                   E(Z, "SleepEar", 9, -22, 13, 14, F(FUR), L(INK, 1.4)),
                   E(Z, "SleepHead", 15, -11, 25, 19, F(FUR), L(INK, 1.6)),
                   E(Z, "SleepBody", -2, -16, 50, 32, sc.vgrad(-16, 16, [(FUR, 0.0), (FUR_SH, 1.0)]), L(INK, 1.8)),
                   x=0.0, y=0.0, name="SleepCurl")
    rig.reg(sleep_body, scaleY=1.0)
    zzz = []
    for k in range(3):
        zx, zy = 18 + 9 * k, -40 - 13 * k
        s_ = 3.2 + k
        z = S(Z, f"MouseZ{k}", [(zx - s_, zy - s_, "c"), (zx + s_, zy - s_, "c"), (zx - s_, zy + s_, "c"),
                                (zx + s_, zy + s_, "c")], L("C0FFFFFF", 1.8), closed=False, opacity=0.0)
        zzz.append(rig.reg(z, opacity=0.0, y=float(z.attrs["y"])))
    asleep = d("Node", *zzz, d("Node", sleep_body, x=0.0, y=0.0, scaleX=-1.0, name="SleepMirror"),
               E(Z, "SleepShadow", 0, 1, 64, 8, F("50100806")), x=0.0, y=0.0, name="MouseAsleep")
    rig.reg(asleep, opacity=1.0)

    # ---- awake, in profile (right-facing frame): bob > torso (pivot at the hips) > head
    hips = (-10.0, -9.0)
    whiskers = d("Node", multi(sc, "Whisker", [smooth_path(d, [(0, 0), (13, -5)], closed=False),
                                               smooth_path(d, [(0, 1), (15, 1)], closed=False),
                                               smooth_path(d, [(0, 2), (12, 7)], closed=False)],
                               sc.L("D0F2ECE4", 1.0)),
                 x=15.0, y=2.0, name="MouseWhiskers")
    rig.reg(whiskers, rotation=0.0)
    ear = d("Node", E(Z, "EarIn", -1, -8, 8, 10, F(PINK)), E(Z, "EarOut", -1, -8, 15, 17, F(FUR), L(INK, 1.4)),
            x=-4.0, y=-4.0, name="MouseEar")
    rig.reg(ear, rotation=0.0)
    eye = d("Node", E(Z, "EyeGlint", 1, -1, 1.6, 1.6, F("FFFFFFFF")), E(Z, "Eye", 0, 0, 4.4, 5.0, F(INK)),
            x=5.0, y=-3.0, name="MouseEye")
    rig.reg(eye, scaleY=1.0)
    head = d("Node", whiskers, E(Z, "Nose", 17, 2, 5, 4, F(PINK)), eye, ear,
             E(Z, "Snout", 9, 2, 18, 12, F(FUR)),
             E(Z, "Skull", 0, 0, 26, 21, F(FUR), L(INK, 1.6)),
             x=32.0, y=-11.0, name="MouseHead")
    rig.reg(head, rotation=0.0)
    feet = {}

    def foot(name: str, x: float, y: float, w: float, col: str = FUR_SH) -> El:
        n_ = d("Node", E(Z, name + "Shape", 0, 0, w, 5, F(col), L(INK, 1.0)), x=x, y=y, name=name)
        feet[name] = rig.reg(n_, x=x)
        return n_

    torso = d("Node", head, foot("FootFrontNear", 26.0, 8.0, 9.0, BELLY),
              E(Z, "Belly", 16, 1, 30, 13, F(BELLY)),
              E(Z, "Body", 12, -5, 50, 29, sc.vgrad(-15, 15, [(FUR, 0.0), (FUR_SH, 1.0)]), L(INK, 1.6)),
              foot("FootFrontFar", 32.0, 8.0, 8.0),
              x=hips[0], y=hips[1], name="MouseTorso")
    rig.reg(torso, rotation=0.0)
    tail = d("Node", S(Z, "TailShape", [(0, 0), (-14, 6), (-30, 4), (-40, -6), (-42, -18)], L(TAIL, 2.6), closed=False),
             x=-24.0, y=-8.0, name="MouseTail")
    rig.reg(tail, rotation=0.0)
    bob = d("Node", foot("FootHindNear", -12.0, -2.0, 13.0, BELLY),
            E(Z, "Haunch", -9, -10, 22, 20, F(FUR), L(INK, 1.4)), torso, tail,
            foot("FootHindFar", -4.0, -2.0, 12.0),
            x=0.0, y=0.0, name="MouseBob")
    rig.reg(bob, y=0.0, scaleX=1.0, scaleY=1.0)
    f = Formulas(sc.d8, sc.vpath)
    flip = scene_npc.formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                                  *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)],
                                                                 [f.val(1000), f.op("*"), f.bound("npcLook")]))])
    face = d("Node", sc.bind("npcLook", 16, flip, doc=sc.d8),
             d("Node", bob, x=0.0, y=0.0, scaleX=-1.0, name="MouseMirror"), x=0.0, y=0.0, name="MouseFace")
    awake = d("Node", face, E(Z, "AwakeShadow", 0, 1, 60, 7, F("50100806")), x=0.0, y=0.0, opacity=0.0,
              name="MouseAwake")
    rig.reg(awake, opacity=0.0)

    # ---- the path node and the poke zone
    npc = d("Node", d("Node", awake, asleep, x=0.0, y=0.0, scaleX=MOUSE_ART_SCALE, scaleY=MOUSE_ART_SCALE,
                      name="MouseArt"), x=MOUSE_WAYPOINTS[0][0], y=MOUSE_WAYPOINTS[0][1], name="MouseNpc")
    rig.reg(npc, opacity=1.0)
    ts, xs, ys, ss = mouse_path()
    path_binds(sc, npc, ts, xs, ys, ss)
    hit = next(h for h in hits if h.attrs.get("name") == "Hit_mouse")
    hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
    path_binds(sc, hit, ts, [x + (hx - xs[0]) * s for x, s in zip(xs, ss)], [y + (hy - ys[0]) * s for y, s in zip(ys, ss)],
               ss)
    at = next(i for i, e in enumerate(content) if e.attrs.get("name") == "ReadingChair")
    content.insert(at, npc)

    # ---- states (every state keys every registered property)
    on = {asleep: {"opacity": [(0, 0.0)]}, awake: {"opacity": [(0, 1.0)]}}
    anims: dict[str, El | list[El]] = {}
    n = MOUSE_REST
    anims["rest"] = rig.anim("npc_mouse_rest", n, {
        sleep_body: {"scaleY": [(0, 1.0), (n // 2, 1.06), (n, 1.0)]},
        **{z: {"opacity": [(0, 0.0), (30 + 34 * k, 0.0), (64 + 34 * k, 0.9), (170 + 20 * k, 0.0), (n, 0.0)],
               "y": [(0, float(z.attrs["y"])), (30 + 34 * k, float(z.attrs["y"])),
                     (170 + 20 * k, float(z.attrs["y"]) - 16), (n, float(z.attrs["y"]) - 16)]}
           for k, z in enumerate(zzz)},
    })
    anims["away"] = rig.anim("npc_mouse_away", 1, {npc: {"opacity": [(0, 0.0)]}})
    n = MOUSE_IDLE
    twitch = [(0, 0.0)]
    for a, b in ((12, 60), (150, 186)):
        twitch += [(fr, 0.16 if (fr // 4) % 2 else -0.1) for fr in range(a, b, 4)] + [(b, 0.0)]
    anims["idle"] = rig.anim("npc_mouse_idle", n, {
        **on,
        head: {"rotation": [(0, 0.0), (14, -0.1), (22, 0.03), (30, -0.1), (38, 0.03), (46, -0.1), (56, 0.0), (140, 0.0),
                            (152, 0.12), (184, 0.12), (196, 0.0), (n, 0.0)]},
        whiskers: {"rotation": uniq(twitch + [(n, 0.0)])},
        ear: {"rotation": [(0, 0.0), (100, 0.0), (104, -0.3), (110, 0.0), (n, 0.0)]},
        tail: {"rotation": [(0, 0.0), (80, 0.12), (160, -0.08), (n, 0.0)]},
        eye: {"scaleY": [(0, 1.0), (118, 1.0), (121, 0.1), (125, 1.0), (n, 1.0)]},
        bob: {"scaleY": [(0, 1.0), (40, 1.03), (80, 1.0), (120, 1.03), (160, 1.0), (200, 1.03), (n, 1.0)]},
    })
    m = MOUSE_MOVE
    anims["move"] = rig.anim("npc_mouse_move", m, {
        **on,
        bob: {"y": [(0, 0.0), (3, -3.0), (6, 0.0), (9, -3.0), (m, 0.0)], "scaleX": [(0, 1.06), (m, 1.06)],
              "scaleY": [(0, 0.96), (m, 0.96)]},
        torso: {"rotation": [(0, 0.05), (6, 0.02), (m, 0.05)]},
        tail: {"rotation": [(0, 0.12), (6, -0.12), (m, 0.12)]},
        head: {"rotation": [(0, 0.08), (m, 0.08)]},
        feet["FootFrontNear"]: {"x": [(0, 21.0), (6, 31.0), (m, 21.0)]},
        feet["FootFrontFar"]: {"x": [(0, 37.0), (6, 27.0), (m, 37.0)]},
        feet["FootHindNear"]: {"x": [(0, -6.0), (6, -18.0), (m, -6.0)]},
        feet["FootHindFar"]: {"x": [(0, -10.0), (6, 2.0), (m, -10.0)]},
    })
    n = MOUSE_NOTICE

    def notice(s: float) -> El:
        return rig.anim(f"npc_mouse_notice{'LCR'[int(s) + 1]}", n, {
            **on,
            torso: {"rotation": [(0, -0.95), (60, -0.98), (n, -0.95)]},
            head: {"rotation": [(0, 0.78 + 0.12 * s), (60, 0.72 + 0.12 * s), (n, 0.78 + 0.12 * s)]},
            ear: {"rotation": [(0, 0.25)]},
            whiskers: {"rotation": [(0, 0.0), (20, 0.14), (24, -0.08), (28, 0.0), (80, 0.0), (84, 0.14), (88, 0.0),
                                    (n, 0.0)]},
            tail: {"rotation": [(0, 0.3), (60, 0.36), (n, 0.3)]},
        })
    anims["notice"] = blend3(notice)
    n = MOUSE_REACT
    anims["react"] = rig.anim("npc_mouse_react", n, {
        **on,
        bob: {"y": [(0, 0.0), (4, 3.0), (13, -44.0), (19, -48.0), (28, 0.0), (31, 2.0), (n, 0.0)],
              "scaleY": [(0, 1.0), (4, 0.8), (12, 1.14), (19, 1.04), (28, 0.84), (32, 1.02), (n, 1.0)],
              "scaleX": [(0, 1.0), (4, 1.14), (12, 0.9), (19, 0.98), (28, 1.12), (32, 0.99), (n, 1.0)]},
        torso: {"rotation": [(0, 0.0), (12, -0.4), (24, -0.1), (30, 0.04), (n, 0.0)]},
        tail: {"rotation": [(0, 0.0), (10, -0.7), (24, -0.3), (n, 0.0)]},
        ear: {"rotation": [(0, 0.0), (12, -0.35), (26, 0.0), (n, 0.0)]},
        eye: {"scaleY": [(0, 1.0), (10, 1.25), (26, 1.25), (n, 1.0)]},
    })
    npc_layer(sc, anims)


# ====================================================================== the diorama
PLANES: dict[str, int | None] = {
    "LightningWash": None,
    **dict.fromkeys(("StackCandle", "BookStack"), 5),
    **dict.fromkeys(("MouseNpc", "ReadingChair", "Globe", "LightningFloor", "FloorPool", "Rug", "FloorShade",
                     "PlankJoint", "Plank", "Floor"), 4),
    **dict.fromkeys(("DustMotes", "LampBulb", "Lamp", "LampGlow", "OpenBook", "DeskCandle", "Ladder", "LadderRail",
                     "Desk"), 3),
    **dict.fromkeys(("FlutterBook", "FestiveLights", "FestiveDecor", "Clock", "Crown", "Sill", "Keystone", "Casing",
                     "Reveal", "WindowSpill", "WallGlow", "CaseR", "CaseL", "Wainscot", "WallStripe", "Wall"), 2),
    **dict.fromkeys(("MullionHi", "OculusSpoke", "Oculus", "Transom", "MullionV", "WinFrame", "Leading", "GlassFlash",
                     "ShowerGlass", "RainGlass", "GlassSheen", "GlassClip"), 1),
    **dict.fromkeys(("ViewRain", "Bolt", "Tree", "LitWin", "Town", "SkyFlash", "MoonRig", "MoonDrawn", "Clouds", "Star",
                     "Sky"), 0),
    "Hit_mouse": 4, "Hit_globe": 4, "Hit_book": 3, "Hit_clock": 2,
}
EMISSIVE = ("LightningWash", "LightningFloor", "StackCandleFlameNode", "StackCandleGlow", "DeskCandleFlameNode",
            "DeskCandleGlow", "LampGlow", "LampBulb", "WallGlow", "WindowSpill", "FloorPool", "Bolt", "SkyFlash",
            "GlassFlash", "LitWin", "MoonDrawn", "Star", "DustMotes")
VEILS = ((0.3, 700.0, 960.0),)          # a town haze in front of the roofs (Plane0) at fog 0
FOG_BANK = (0, 600.0, 880.0, "FF8C92A6", 0.75)

DIORAMAS[SCENE_ID] = DioramaSpec(PLANES, EMISSIVE, VEILS)
TIME_SKY[SCENE_ID] = (HORIZON, 0.45)
scene_npc.FOG_VEILS[SCENE_ID] = (0,)
scene_npc.FOG_BANKS[SCENE_ID] = FOG_BANK


# ====================================================================== review registry
# The ladder's drag handle as built (contract v12 drag table, library row): the ladder at ladder -1 .. 1,
# hooks to wheels, clamped to the artboard, in Plane3.
LADDER_RECT = ladder_rect()
LADDER_PLANE = 3


def review_extras(render: Callable[..., object], out: Path, gates: list[str]) -> None:
    """review_diorama's scene extras: the events at their peaks, the world (rain, day, dusk, fog, festive,
    parallax), the ladder drag's pixel proof (ladder -1 / 0.5 / 1 change pixels only inside `LADDER_RECT`;
    history-free), the moon at four phases, the mouse's states, one contact sheet (`contact_sheet.webp`)."""
    import numpy as np  # noqa: PLC0415 (review only)
    from PIL import Image, ImageDraw  # noqa: PLC0415

    def im(a: object, label: str, size: tuple[int, int] = (270, 480), box: tuple[int, ...] | None = None) -> Image.Image:
        img = Image.fromarray(a).convert("RGB")  # type: ignore[arg-type]
        if box is not None:
            img = img.crop(box)
        img = img.resize(size)
        ImageDraw.Draw(img).text((5, 3), label, fill=(255, 255, 0))
        return img

    def grid(cells: list[Image.Image], cols: int) -> Image.Image:
        w, h = cells[0].size
        sheet = Image.new("RGB", (cols * w, ((len(cells) + cols - 1) // cols) * h), (20, 20, 20))
        for i, c in enumerate(cells):
            sheet.paste(c, ((i % cols) * w, (i // cols) * h))
        return sheet

    rest = render("--advance=1")
    cells = [im(rest, "rest"), im(render("--advance=91"), "f90")]
    for ev, f in EVENT_PEAKS.items():
        a = render(f"--data=eventId={ev}", "--data=event=1", f"--advance={f}")
        cells.append(im(a, f"{ev} +{f}f"))
    for label, args in (("rain 1 f40", ("--data=rain=1", "--advance=41")),
                        ("noon", ("--data=daylight=1", "--advance=1")),
                        ("dusk (0.4 / 1)", ("--data=daylight=0.4", "--data=dusk=1", "--advance=1")),
                        ("fog 1", ("--data=fog=1", "--advance=1")),
                        ("festive 1", ("--data=festive=1", "--advance=1")),
                        ("parallax -1 / -1", ("--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=1")),
                        ("parallax +1 / +1", ("--data=parallaxX=1", "--data=parallaxY=1", "--advance=1"))):
        cells.append(im(render(*args), label))
    top = grid(cells, 7)

    # ---- the ladder drag: history-free pixels only in the handle's rect
    x0, y0, x1, y1 = (int(v) for v in LADDER_RECT)
    allowed = np.zeros(rest.shape[:2], bool)  # type: ignore[union-attr]
    allowed[y0:y1, x0:x1] = True
    drag_cells = []
    worst, bbox, inside = 0.0, None, 1.0
    for v in (-1.0, -0.5, 0.0, 0.5, 1.0):
        a = render(f"--data=ladder={v}", "--advance=1")
        drag_cells.append(im(a, f"ladder {v:+}", (220, 300), (600, 200, 1080, 1340)))
        if v == 0.0:
            continue
        changed = np.abs(a.astype(int) - rest.astype(int))[..., :3].max(-1) > 0  # type: ignore[union-attr]
        worst = max(worst, float((changed & ~allowed).mean()))
        inside = min(inside, float(changed[y0:y1, x0:x1].mean()))
        ys, xs = np.nonzero(changed)
        b = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        bbox = b if bbox is None else (min(bbox[0], b[0]), min(bbox[1], b[1]), max(bbox[2], b[2]), max(bbox[3], b[3]))
    back = render("--data=ladder=1", "--advance=1", "--data=ladder=0", "--advance=2")
    region = (slice(y0, y1), slice(x0, x1))
    back_diff = int(np.abs(back.astype(int) - render("--advance=2").astype(int))[region][..., :3].max())  # type: ignore
    gates.append(f"ladder drag: pixels changed at ladder -1 / -0.5 / 0.5 / 1 outside {LADDER_RECT}: {worst:.4%} "
                 f"(changed bbox {bbox}; least share of the rect changed {inside:.2%}) "
                 f"({'ok' if worst == 0 and inside > 0.02 else 'FAIL'})")
    gates.append(f"ladder drag history-free: ladder 1 -> 0 vs never moved (the rect), max diff {back_diff}/255 "
                 f"({'ok' if back_diff <= 2 else 'FAIL'})")

    # ---- the moon at four phases
    moon_box = (int(MOON[0] - 50), int(MOON[1] - 46), int(MOON[0] + 50), int(MOON[1] + 46))
    moon_cells = [im(rest, "-1 (drawn)", (150, 138), moon_box)]
    for ph in (0.0, 0.25, 0.5, 0.75):
        moon_cells.append(im(render(f"--data=moonPhase={ph}", "--advance=1"), f"{ph:.2f}", (150, 138), moon_box))

    # ---- the mouse's states and a move
    box = (640, 1110, 940, 1310)
    npc_cells = []
    for label, args in (("rest", ("--advance=151",)), ("idle", ("--data=npc=idle", "--advance=31")),
                        ("move", ("--data=npc=move", "--advance=16")),
                        ("notice -1", ("--data=npc=notice", "--data=npcLook=-1", "--advance=31")),
                        ("notice +1", ("--data=npc=notice", "--data=npcLook=1", "--advance=31")),
                        ("react", ("--data=npc=react", "--advance=24")),
                        ("away", ("--data=npc=away", "--advance=31"))):
        npc_cells.append(im(render(*args), f"mouse {label}", (270, 180), box))
    path_cells = [im(render("--data=npc=move", f"--data=npcX={x}", "--advance=8"), f"move npcX {x}", (270, 300),
                     (600, 1100, 1080, 1640)) for x in (0.0, 0.5, 1.0)]
    w = 270 * 7
    mid = grid(npc_cells, 7)
    paths = grid(path_cells, 3)
    moons = grid(moon_cells, 5)
    drags = grid(drag_cells, 5)
    bottom = Image.new("RGB", (w, max(paths.height, drags.height) + moons.height), (20, 20, 20))
    bottom.paste(paths, (0, 0))
    bottom.paste(drags, (paths.width + 10, 0))
    bottom.paste(moons, (0, max(paths.height, drags.height)))
    sheet = Image.new("RGB", (w, top.height + mid.height + bottom.height), (20, 20, 20))
    yy = 0
    for part in (top, mid, bottom):
        sheet.paste(part, (0, yy))
        yy += part.height
    sheet.save(out / "contact_sheet.webp", quality=82)


REVIEW: dict[str, object] = {
    "diorama": {
        "patches": [("Plane5 stack candle", (70, 1700, 160, 1790), 40), ("Plane4 chair back", (900, 1340, 1040, 1420), 28),
                    ("Plane3 desk drawer", (20, 1120, 140, 1172), 20), ("Plane2 clock face", (290, 672, 344, 728), 12),
                    ("Plane1 oculus", (496, 196, 584, 276), 6), ("Plane0 moon", (590, 296, 634, 340), 0)],
        "wet": ((560, 660, 670, 860), 1.0, 1.8),
        # glass streaks 20, drips 240, view rain 24 frames: all back at frame 0 after 240
        "rain_loops": [("RainGlass streaks + drips + ViewRain", GLASS_RAIN_FRAMES)],
        "seam_box": (int(GLASS_X[0]), 300, int(GLASS_X[1]), int(GLASS[1])),
    },
    "extras": review_extras,
    "time": {"sky_box": (420, 200, 660, 600), "dusk_box": (410, 660, 670, 860), "noon_gain": 12.0},
    "npc": {"crop": (200, 150, -40), "seam": {"idle": MOUSE_IDLE, "move": MOUSE_MOVE, "notice": MOUSE_NOTICE,
                                              "react": MOUSE_REACT},
            "prop": "mouse", "waypoints": MOUSE_WAYPOINTS,
            "fog_box": (int(OPEN_X[0]), 140, int(OPEN_X[1]), int(OPEN_BOT))},
}


if __name__ == "__main__":
    print("wrote", library())
