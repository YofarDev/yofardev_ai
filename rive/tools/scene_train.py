"""Moonshot M11 (contract v14, rulings 1, 2, 7-9, 13): the `trainCompartment` scene, an old sleeper
compartment at night with the landscape running past the window.

    uv run rive/tools/gen_scenes.py trainCompartment   # -> rive/scenes/trainCompartment/trainCompartment.rml

The motion axis of the world: every plane outside the window is a seamless tile loop (one tile per
layer, drawn twice in one shape, the layer's x keyed 0 -> -TILE_W per loop, linear), and every loop of
the file is back at frame 0 after `LOOP_LCM` frames.

- Plane0, far: the night sky (`daylight` / `dusk` through `gen_scenes.sky_time`), stars (two twinkle
  halves), the moon (`moonPhase`: the drawn moon at -1, `world_kit.moon_rig` at 0..1), the far hills
  (`FarHills`, slow) and the middle distance (`MidLand`: rolling fields, tree clumps, a village with lit
  windows and a spire); the `fog` veil.
- Plane1, near: the hedge bank and the trees (`NearTrees`; `spring` blossom / `autumn` colours on the
  canopies), the telegraph poles, wires and fence (`Poles`, fastest), the day lift (`LandDay`), and the
  outside events: `station` (a separate platform layer that slows to a halt, holds and speeds away),
  `tunnel` (a dark tunnel wall with lamps running past) and `whistle` (steam puffs streaming past the
  top of the window); the fog bank.
- Plane2, the window: the frame, the transom, a faint sheen, the rain on the glass (`rain`: slanted
  streaks and beads crawling down and back, two streak sheets, the second past rain 0.4) and the `rain`
  event's shower; the tunnel's reflection of the lamp. Prop `window`.
- Plane3, the compartment wall: mahogany panelling with the window's opening and casing, the sill
  (the ladybug, a glass of tea), the tied-back curtains on their rod, the wall lamp (prop `lamp`, the
  warm key; flicker 0.05), the luggage rack with the suitcase (prop `suitcase`) and a hatbox, the side
  walls and the ceiling, and the whistle chain beside the window (the `chain` pull drag: `chain` 0..1
  draws the chain out of its tube by up to `CHAIN_PULL` px and swings it a little, history-free).
- Plane4, the two facing benches (velvet, in perspective) and the floor with its carpet runner.
- Plane5, a foreground curtain edge (left) and an armrest (bottom right).

The ladybug (`npc`, contract v11 states, ruling 7): rest = still on the sill; idle = antennae twitch, a
few steps; move = walks (a tripod gait); notice = front up, antennae raised; react = wing cases flick
open, a short flutter hop. `npcX` 0 = (`LADYBUG_WAYPOINTS[0]`) left on the sill -> 1 right, along the
sill; it faces right (toward the avatar) while `npcLook` >= 0 and left while < 0. Poke prop `ladybug`.

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
from gen_scenes import DIORAMAS, TIME_SKY, DioramaSpec, Scene, W, H  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, ellipse, lin, rad, smooth_path  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds  # noqa: E402
import world_kit  # noqa: E402

SCENE_ID = "trainCompartment"
O = (0.0, 0.0)
INK = "FF2A1E28"

# ---------------------------------------------------------------- layout (artboard px)
VP = (540.0, 720.0)                         # the room's vanishing point (eye height)
BACK = (60.0, 120.0, 1020.0, 1200.0)        # the window wall's corners (ceiling and floor lines)
FLOOR_Y = BACK[3]
GLASS = (240.0, 456.0, 840.0, 888.0)        # the glass (two panes: the transom bar splits it)
TRANSOM = (532.0, 548.0)
PANES = ((GLASS[0], GLASS[1], GLASS[2], TRANSOM[0]), (GLASS[0], TRANSOM[1], GLASS[2], GLASS[3]))
OPEN = (222.0, 438.0, 858.0, 906.0)         # the opening in the wall (Plane3)
FRAME = (200.0, 416.0, 880.0, 928.0)        # the frame's outer edge (Plane2, 22 px under the wall)
CASING = (196.0, 414.0, 884.0, 906.0)       # the moulding ring round the opening (Plane3)
SILL_TOP = 906.0                            # where things stand on the sill
VIEW = (190.0, 400.0, 890.0, 940.0)         # the outside art covers this (wall travel 20 / 12 px over Plane0)
HORIZON = 720.0
MOON = (720.0, 590.0, 24.0)
SKY = ("FF141C38", "FF1E2A4E", "FF34406C")  # night sky: top, mid, horizon

LAMP = (130.0, 640.0)                       # the wall lamp's shade centre
RACK_Y = (262.0, 296.0)                     # the luggage rack's front and lower rails
SUITCASE = (226.0, 152.0, 466.0, 262.0)
TEA_X = 800.0

# ---------------------------------------------------------------- the landscape loops (frames at 60 fps)
TILE_W = 960.0
SCROLL_LOOPS = {"FarHills": 1800, "MidLand": 600, "NearTrees": 180, "Poles": 90}
LOOP_LCM = 1800                             # every loop of the file is back at frame 0 after this
GLASS_SHEETS = (("StreakSheetA", (-180.0, 150.0), 30), ("StreakSheetB", (-180.0, 150.0), 60),
                ("BeadSheet", (-72.0, 96.0), 360))
SHOWER_SHEET = ("ShowerSheet", (-200.0, 168.0), 20)
TWINKLE = 360
FLICKER = 180
ROCK = 120
LAMP_FLICKER = [(0, 1.0), (24, 0.96), (52, 1.0), (88, 0.95), (110, 0.99), (140, 0.955), (FLICKER, 1.0)]

# ---------------------------------------------------------------- events
EVENT_FRAMES = {"tunnel": 180, "whistle": 120, "station": 480, "rain": 420}
EVENT_PEAKS = {"tunnel": 90, "whistle": 50, "station": 240, "rain": 200}
TUNNEL_SPEED = 20.0                         # px / frame the tunnel wall runs past
TUNNEL_W = 2680.0
STATION_W = 1300.0
STATION_SPEED = 8.0                         # px / frame as it enters and leaves
STATION_HOLD = (165, 315)                   # frames it stands still (2.5 s)

# ---------------------------------------------------------------- the chain (pull drag)
CHAIN_X = 946.0
CHAIN_TOP = 300.0                           # the chain leaves its tube here
CHAIN_LEN = 380.0                           # tube -> the handle's ring at chain 0
CHAIN_PULL = 66.0                           # px the chain comes out at chain 1
CHAIN_SWING = 0.05                          # rad the chain swings at chain 1
CHAIN_SWAY = 0.012                          # rad of the train's rocking (ambient)
HANDLE_H = 58.0                             # ring -> the tassel's tip
CHAIN_PLANE = 3

# ---------------------------------------------------------------- the ladybug (npc)
LADYBUG_WAYPOINTS = [(294.0, SILL_TOP, 1.0), (410.0, SILL_TOP, 1.0)]   # feet on the sill, npcX 0 -> 1
LADYBUG_SCALE = 1.15
LADYBUG_LENGTH = 46.0                       # rig px, wing case tail to the head's front
LADYBUG_HIT = (0.0, -16.0, 76.0, 60.0)      # (dx, dy) from the feet, width, height
LB_IDLE, LB_WALK, LB_NOTICE, LB_REACT = 360, 24, 120, 36
LB_STRIDE = 7.0                             # rig px the body travels per walk cycle

# ---------------------------------------------------------------- v12 / v14 members this file binds
BINDS: set[str] = {"moonPhase", *world_kit.drag_numbers(SCENE_ID)}
BINDS14: set[str] = {"spring", "autumn"}
# The tier gate (lane W's shared pass hides these element names per tier; contract v14 `tier`).
TIER_GATES: dict[str, tuple[str, ...]] = {
    "high": ("GlassStreaksB", "StarTwinkleB", "SteamPuffsB"),   # the second rain sheet, half the twinkle
    "low": ("TeaSteam", "LampDust"),                            # decorative loops that are not light
}


# ====================================================================== helpers
class _TrainScene(Scene):
    """`gen_scenes.Scene` without the M4 art pass (`scene_art.refine_scene` knows the M8 scenes only)."""

    def write(self, content: list[El], hits: list[El]) -> str:
        saved = gen_scenes.refine_scene
        gen_scenes.refine_scene = lambda sc, c: None
        try:
            return super().write(content, hits)
        finally:
            gen_scenes.refine_scene = saved


def conv(sc: Scene, doc: Doc, k: float, c: float = 0.0, lo: float | None = None, hi: float | None = None) -> El:
    """A private `c + k x input` converter (clamped to [lo, hi] when given), minted from `doc`."""
    f = Formulas(doc, sc.vpath)
    toks = ([f.val(c), f.op("+")] if c else []) + [f.val(k), f.op("*"), *f.inp()]
    if lo is not None:
        toks = f.fn("max", [f.val(lo)], toks)
    if hi is not None:
        toks = f.fn("min", [f.val(hi)], toks)
    out = doc("DataConverterFormula", *toks)
    sc.roots.append(out)
    return out


def rect_path(sc: Scene, x0: float, y0: float, x1: float, y1: float, ox: float = 0.0, oy: float = 0.0,
              r: float = 0.0, name: str = "Path") -> El:
    rr = float(r) if r else None
    return sc.d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2 - ox),
                y=float((y0 + y1) / 2 - oy), cornerRadiusTL=rr, cornerRadiusTR=rr, cornerRadiusBL=rr,
                cornerRadiusBR=rr, name=name)


def box(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, *paints: El | None, r: float = 0.0,
        **kw: object) -> El:
    """A rectangle shape centred on its box (gradients are shape-local: y -h/2 .. h/2)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return sc.d("Shape", rect_path(sc, x0, y0, x1, y1, cx, cy, r), *[p for p in paints if p is not None],
                x=float(cx), y=float(cy), name=name, **kw)


def ring(sc: Scene, name: str, outer: tuple[float, ...], inner: tuple[float, ...], paint: El, r: float = 0.0) -> El:
    """A rectangular ring (even-odd): `outer` minus `inner`."""
    ox, oy = (outer[0] + outer[2]) / 2, (outer[1] + outer[3]) / 2
    paint.attrs["fillRule"] = "evenOdd"
    return sc.d("Shape", rect_path(sc, *outer, ox, oy, r=r), rect_path(sc, *inner, ox, oy, name="Opening"), paint,
                x=float(ox), y=float(oy), name=name)


def poly_path(sc: Scene, pts: list[tuple[float, float]], name: str = "Path") -> El:
    """A closed polygon (hard corners) in the coordinates of a shape at the origin."""
    return smooth_path(sc.d, [(float(x), float(y), "c") for x, y in pts], name=name)


def poly(sc: Scene, name: str, pts: list[tuple[float, float]], *paints: El | None, **kw: object) -> El:
    return sc.d("Shape", poly_path(sc, pts), *[p for p in paints if p is not None], x=0.0, y=0.0, name=name, **kw)


def multi(sc: Scene, name: str, paths: list[El], *paints: El | None, **kw: object) -> El:
    """One shape at the origin holding several paths (artboard px) and one set of paints."""
    return sc.d("Shape", *paths, *[p for p in paints if p is not None], x=0.0, y=0.0, name=name, **kw)


def seg(sc: Scene, x0: float, y0: float, x1: float, y1: float) -> El:
    return sc.d("PointsPath", sc.d("StraightVertex", x=float(x0), y=float(y0)),
                sc.d("StraightVertex", x=float(x1), y=float(y1)), isClosed=False, name="Path")


def oval(sc: Scene, cx: float, cy: float, w: float, h: float) -> El:
    return sc.d("Ellipse", width=float(w), height=float(h), x=float(cx), y=float(cy), name="Path")


def vfill(sc: Scene, y0: float, y1: float, stops: list[tuple[str, float]]) -> El:
    """A vertical gradient fill in absolute y (for shapes at the origin)."""
    return sc.d("Fill", lin(sc.d, 0, y0, 0, y1, stops), name="Fill")


def hfill(sc: Scene, x0: float, x1: float, stops: list[tuple[str, float]]) -> El:
    return sc.d("Fill", lin(sc.d, x0, 0, x1, 0, stops), name="Fill")


def periodic(x: float, terms: tuple[tuple[float, int, float], ...]) -> float:
    """Sum of sines periodic over TILE_W: (amplitude, cycles per tile, phase)."""
    return sum(a * math.sin(2 * math.pi * n * x / TILE_W + p) for a, n, p in terms)


def ridge_paths(sc: Scene, base: float, terms: tuple[tuple[float, int, float], ...], bottom: float,
                step: float = 30.0) -> list[El]:
    """Two copies (x 0 and TILE_W) of a closed periodic ridge from `base + periodic(x)` down to `bottom`;
    each copy runs 3 px into the next so the seam never shows."""
    out = []
    for k in (0, 1):
        x0 = k * TILE_W
        top = [(x0 + x, base + periodic(x, terms)) for x in [i * step for i in range(int(TILE_W / step) + 1)]]
        top[-1] = (x0 + TILE_W + 3, top[-1][1])
        pts = [(x0 - 3, bottom, "c"), (x0 - 3, top[0][1], "c"), *top[1:-1], (top[-1][0], top[-1][1], "c"),
               (x0 + TILE_W + 3, bottom, "c")]
        out.append(smooth_path(sc.d, pts, tension=0.8))
    return out


def scroll(sc: Scene, node: El, period: int) -> None:
    """The node's x runs 0 -> -TILE_W over `period` frames, looping (seamless: the second copy takes over)."""
    sc.ambient(node.attrs["name"], sc.A(f"amb_{node.attrs['name']}", period,
                                        [sc.T(node, x=[(0, 0.0, "linear"), (period, -TILE_W, "linear")])], loop=True))


def lin_keys(fn: Callable[[float], float], frames: list[int]) -> list[tuple[int, float, str]]:
    return [(f, round(fn(f), 4), "linear") for f in frames]


# ====================================================================== Plane0: the far view
def plane0(sc: Scene, keep: dict[str, El]) -> list[El]:
    S, E, F, d = sc.S, sc.E, sc.F, sc.d
    rnd = random.Random(1411)
    vx0, vy0, vx1, vy1 = VIEW
    sky = box(sc, "Sky", vx0, vy0, vx1, vy1, sc.vgrad(-(vy1 - vy0) / 2, (vy1 - vy0) / 2,
                                                         [(SKY[0], 0.0), (SKY[1], 0.4), (SKY[2], 0.62), (SKY[2], 1.0)]))
    # stars: some still, two halves twinkle (the second half is a tier gate)
    stars: list[El] = []
    while len(stars) < 18:
        x = rnd.uniform(GLASS[0] + 30, GLASS[2] - 40)
        y = rnd.uniform(GLASS[1] + 10, 680)
        if (math.hypot(x - MOON[0], y - MOON[1]) < MOON[2] + 34 or TRANSOM[0] - 8 < y < TRANSOM[1] + 8
                or x < 270 or x > 806):
            continue
        sz = rnd.choice((2.4, 3.0, 3.6, 4.2))
        stars.append(E(O, f"Star{len(stars)}", x, y, sz, sz, F("FFF2F0E4"), opacity=round(rnd.uniform(0.5, 1.0), 2)))
    halves = []
    for h, part in enumerate((stars[:5], stars[5:10])):
        node = d("Node", *part, x=0.0, y=0.0, name=f"StarTwinkle{'AB'[h]}")
        halves.append(node)
        tw = [sc.T(s, opacity=[(0, float(s.attrs["opacity"])), (50 + 61 * i % 140, 0.22),
                               (150 + 47 * i % 120, float(s.attrs["opacity"])), (TWINKLE, float(s.attrs["opacity"]))])
              for i, s in enumerate(part)]
        sc.ambient(f"StarTwinkle{'AB'[h]}", sc.A(f"amb_StarTwinkle{'AB'[h]}", TWINKLE, tw, loop=True, seam_hold=True))
    still = d("Node", *stars[10:], x=0.0, y=0.0, name="Stars")

    # the drawn moon (moonPhase -1) and the phase rig (0..1)
    mx, my, mr = MOON
    craters = ((-8, 6, 9), (6, -8, 6), (9, 9, 5))
    moon_glow = E(O, "MoonGlow", mx, my, mr * 7, mr * 7, sc.rgrad(mr * 3.5, [("40FFF2D8", 0.0), ("00FFF2D8", 1.0)]))
    moon_disc = E(O, "MoonDisc", mx, my, 2 * mr, 2 * mr, sc.rgrad(mr * 1.6, [("FFFFF8E6", 0.0), ("FFEADFC4", 1.0)],
                                                                   cx=-mr * 0.4, cy=-mr * 0.4))
    moon_craters = [E(O, f"MoonCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A")) for i, (dx, dy, r_) in enumerate(craters)]
    moon_drawn = world_kit.hide_when_phased(sc, sc.d9, "MoonDrawn", [*moon_craters, moon_disc, moon_glow])
    with sc.minting(sc.d9):
        lit = d("Node", *[E((mx, my), f"MoonLitCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A"))
                          for i, (dx, dy, r_) in enumerate(craters)],
                E((mx, my), "MoonLitDisc", mx, my, 2 * mr, 2 * mr, F("FFF6EEDA")),
                E((mx, my), "MoonLitGlow", mx, my, mr * 7, mr * 7,
                  sc.rgrad(mr * 3.5, [("40FFF2D8", 0.0), ("00FFF2D8", 1.0)])), x=0.0, y=0.0, name="MoonLit")
    moon_rig = world_kit.moon_rig(sc, sc.d9, mx, my, mr, lit, "E61E2A4E")

    # far hills: one slow tile
    far = multi(sc, "FarHillsShape", ridge_paths(sc, 664.0, ((22.0, 2, 0.7), (14.0, 3, 2.1), (8.0, 5, 0.3)), vy1 + 10),
                vfill(sc, 620, 760, [("FF323C5E", 0.0), ("FF222A48", 1.0)]))
    far_snow = multi(sc, "FarHillsRim", ridge_paths(sc, 666.0, ((22.0, 2, 0.7), (14.0, 3, 2.1), (8.0, 5, 0.3)), 678.0),
                     F("40A8B4D0"))
    far_hills = d("Node", far_snow, far, x=0.0, y=0.0, name="FarHills")
    scroll(sc, far_hills, SCROLL_LOOPS["FarHills"])

    # the middle distance: rolling fields, tree clumps, a village with lit windows and a spire
    mid_terms = ((8.0, 2, 1.3), (5.0, 4, 0.2))
    ground = multi(sc, "MidGround", ridge_paths(sc, 716.0, mid_terms, vy1 + 10, step=40.0),
                   vfill(sc, 700, 800, [("FF1E2842", 0.0), ("FF141C30", 1.0)]))
    r2 = random.Random(77)
    clumps: list[tuple[float, float, float, float]] = []
    for i in range(16):
        x = r2.uniform(0, TILE_W)
        if 290 < x < 560:
            continue   # the village
        w_ = r2.uniform(18, 36)
        clumps.append((x, 716.0 + periodic(x, mid_terms) - w_ * 0.35, w_, w_ * 0.8))
    clump_paths = [oval(sc, x + k * TILE_W, y, w_, h_) for k in (0, 1) for x, y, w_, h_ in clumps]
    clump_shape = multi(sc, "MidClumps", clump_paths, F("FF16203A"))
    with sc.minting(sc.d11):
        mid_autumn = multi(sc, "MidAutumn", [oval(sc, x + k * TILE_W, y, w_, h_) for k in (0, 1) for x, y, w_, h_ in clumps],
                           F("FF5E3424"), opacity=0.0)
        mid_autumn.children.insert(0, sc.bind("autumn", 18, conv(sc, sc.d11, 0.75, lo=0.0, hi=1.0), doc=sc.d11))
        mid_spring = multi(sc, "MidSpring", [oval(sc, x + k * TILE_W, y - h_ * 0.12, w_ * 0.8, h_ * 0.6)
                                             for k in (0, 1) for x, y, w_, h_ in clumps], F("FF7A6078"), opacity=0.0)
        mid_spring.children.insert(0, sc.bind("spring", 18, conv(sc, sc.d11, 0.7, lo=0.0, hi=1.0), doc=sc.d11))
    houses, roofs, windows = [], [], []
    for hx, hw, hh in ((312.0, 30.0, 22.0), (352.0, 24.0, 18.0), (392.0, 34.0, 24.0), (470.0, 26.0, 20.0),
                       (812.0, 30.0, 20.0)):
        gy = 716.0 + periodic(hx, mid_terms) + 2
        for k in (0, 1):
            x = hx + k * TILE_W
            houses.append(rect_path(sc, x - hw / 2, gy - hh, x + hw / 2, gy + 4))
            roofs.append(poly_path(sc, [(x - hw / 2 - 3, gy - hh), (x, gy - hh - hw * 0.45), (x + hw / 2 + 3, gy - hh)]))
            windows.append(rect_path(sc, x - hw / 4 - 2.5, gy - hh * 0.6, x - hw / 4 + 2.5, gy - hh * 0.6 + 5))
            if hw > 28:
                windows.append(rect_path(sc, x + hw / 4 - 2.5, gy - hh * 0.6, x + hw / 4 + 2.5, gy - hh * 0.6 + 5))
    sx_ = 432.0
    sgy = 716.0 + periodic(sx_, mid_terms)
    for k in (0, 1):
        x = sx_ + k * TILE_W
        houses.append(rect_path(sc, x - 9, sgy - 34, x + 9, sgy + 4))
        roofs.append(poly_path(sc, [(x - 10, sgy - 34), (x, sgy - 76), (x + 10, sgy - 34)]))
        windows.append(rect_path(sc, x - 2.5, sgy - 26, x + 2.5, sgy - 18))
    village = d("Node", multi(sc, "VillageLit", windows, F("FFFFD890")), multi(sc, "VillageRoofs", roofs, F("FF1A1E34")),
                multi(sc, "VillageHouses", houses, F("FF242C46")), x=0.0, y=0.0, name="Village")
    mid = d("Node", mid_spring, mid_autumn, clump_shape, village, ground, x=0.0, y=0.0, name="MidLand")
    scroll(sc, mid, SCROLL_LOOPS["MidLand"])
    keep["mid"] = mid
    return [mid, far_hills, moon_rig, moon_drawn, *halves, still, sky]


# ====================================================================== Plane1: the near view and the outside events
TREES = (  # (x in the tile, trunk height, canopy width, kind)
    (80.0, 70.0, 104.0, "round"), (250.0, 54.0, 80.0, "bush"), (420.0, 84.0, 46.0, "poplar"),
    (560.0, 64.0, 120.0, "round"), (720.0, 76.0, 92.0, "round"), (860.0, 48.0, 64.0, "bush"))
HEDGE_Y = 816.0
HEDGE_TERMS = ((5.0, 3, 0.4), (3.0, 8, 1.1), (2.0, 13, 2.0))


def canopy_blobs(x: float, base: float, trunk: float, w: float, kind: str) -> list[tuple[float, float, float, float]]:
    """(cx, cy, w, h) ellipses of one tree's canopy."""
    top = base - trunk
    if kind == "poplar":
        return [(x, top - 70, w, 150), (x - 4, top - 10, w * 0.9, 70)]
    if kind == "bush":
        return [(x - w * 0.22, base - w * 0.3, w * 0.62, w * 0.5), (x + w * 0.2, base - w * 0.34, w * 0.66, w * 0.56),
                (x, base - w * 0.48, w * 0.58, w * 0.5)]
    return [(x, top - w * 0.32, w, w * 0.78), (x - w * 0.34, top - w * 0.08, w * 0.62, w * 0.5),
            (x + w * 0.32, top - w * 0.12, w * 0.66, w * 0.52)]


def plane1(sc: Scene, keep: dict[str, El]) -> list[El]:
    F, d = sc.F, sc.d
    vx0, vy0, vx1, vy1 = VIEW
    # ---- near trees and the hedge bank (one tile)
    trunks, blobs, lit = [], [], []
    for x, trunk, w, kind in TREES:
        base = HEDGE_Y + periodic(x, HEDGE_TERMS) + 6
        bl = canopy_blobs(x, base, trunk, w, kind)
        for k in (0, 1):
            ox = k * TILE_W
            if kind != "bush":
                tw = 7.0 if kind == "poplar" else 10.0
                trunks.append(rect_path(sc, x + ox - tw / 2, base - trunk - 8, x + ox + tw / 2, base + 4))
            blobs += [(cx + ox, cy, bw, bh) for cx, cy, bw, bh in bl]
            lit += [(cx + ox + bw * 0.14, cy - bh * 0.14, bw * 0.62, bh * 0.56) for cx, cy, bw, bh in bl[:1]]
    hedge = multi(sc, "Hedge", ridge_paths(sc, HEDGE_Y, HEDGE_TERMS, vy1 + 10, step=24.0),
                  vfill(sc, 800, 940, [("FF162230", 0.0), ("FF0E141E", 1.0)]))
    trunk_shape = multi(sc, "Trunks", trunks, F("FF121820"))
    canopy = multi(sc, "Canopy", [oval(sc, *b) for b in blobs], vfill(sc, 560, 820, [("FF20403C", 0.0),
                                                                                      ("FF13282A", 1.0)]))
    canopy_lit = multi(sc, "CanopyLit", [oval(sc, *b) for b in lit], F("50587E80"))
    rnd = random.Random(909)
    dots = []
    for cx, cy, bw, bh in blobs:
        for _ in range(max(2, int(bw // 18))):
            a, rr = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.1, 0.42)
            dots.append(oval(sc, cx + bw * rr * math.cos(a), cy + bh * rr * math.sin(a), 6.0, 5.0))
    with sc.minting(sc.d11):
        autumn = d("Node", sc.bind("autumn", 18, doc=sc.d11),
                   multi(sc, "AutumnLit", [oval(sc, *b) for b in lit], F("90C88440")),
                   multi(sc, "CanopyAutumn", [oval(sc, *b) for b in blobs],
                         vfill(sc, 560, 820, [("FF9A5630", 0.0), ("FF5E2C1E", 1.0)])),
                   x=0.0, y=0.0, opacity=0.0, name="AutumnTrees")
        spring = d("Node", sc.bind("spring", 18, doc=sc.d11),
                   multi(sc, "Blossom", dots, F("FFEAC8DA")),
                   multi(sc, "CanopySpring", [oval(sc, *b) for b in blobs],
                         vfill(sc, 560, 820, [("FF9A7088", 0.0), ("FF4E3A4C", 1.0)])),
                   x=0.0, y=0.0, opacity=0.0, name="SpringTrees")
    near = d("Node", spring, autumn, canopy_lit, canopy, hedge, trunk_shape, x=0.0, y=0.0, name="NearTrees")
    scroll(sc, near, SCROLL_LOOPS["NearTrees"])

    # ---- telegraph poles, wires and a fence (the fastest tile)
    poles, arms, insul, wires, posts, rails = [], [], [], [], [], []
    for px in (120.0, 600.0):
        for k in (0, 1):
            x = px + k * TILE_W
            poles.append(rect_path(sc, x - 5, 470, x + 5, vy1 + 10))
            arms.append(rect_path(sc, x - 36, 484, x + 36, 491))
            for ix in (-30.0, 30.0):
                insul.append(oval(sc, x + ix, 480, 6, 8))
            # wires to the next pole (480 px on): two from the arm, one from a bracket lower down
            for ix, wy, sag in ((-30.0, 478.0, 30.0), (30.0, 478.0, 34.0), (6.0, 530.0, 40.0)):
                a, b = (x + ix, wy), (x + ix + 480, wy)
                wires.append(smooth_path(sc.d, [a, ((a[0] + b[0]) / 2, wy + sag), b], closed=False))
    for k in (0, 1):
        for i in range(20):
            x = i * 48.0 + 10 + k * TILE_W
            posts.append(seg(sc, x, 872, x, 920))
        for ry in (884.0, 902.0):
            rails.append(seg(sc, k * TILE_W - 4, ry, (k + 1) * TILE_W + 4, ry))
    pole_node = d("Node",
                  multi(sc, "Insulators", insul, F("FF8A94A8")),
                  multi(sc, "PoleArms", arms, F("FF10161E")),
                  multi(sc, "PoleShafts", poles, hfill(sc, 0, 10, [("FF10161E", 0.0), ("FF1E2632", 1.0)])),
                  multi(sc, "Wires", wires, sc.L("FF0A0E16", 2.0)),
                  multi(sc, "FenceRails", rails, sc.L("FF141A24", 4.0)),
                  multi(sc, "FencePosts", posts, sc.L("FF141A24", 5.0)),
                  x=0.0, y=0.0, name="Poles")
    scroll(sc, pole_node, SCROLL_LOOPS["Poles"])

    # ---- the day lifts the near landscape (the sky plane has gen_scenes.sky_time)
    day = box(sc, "LandDay", vx0, vy0, vx1, vy1, F(gen_scenes.SCENES[SCENE_ID].times["day"]), opacity=0.0)
    with sc.minting(sc.d7):
        day.children.insert(0, sc.bind("daylight", 18, conv(sc, sc.d7, 0.32), doc=sc.d7))

    station = station_layer(sc)
    tunnel = tunnel_layer(sc)
    steam = whistle_steam(sc)
    keep.update(station=station, tunnel=tunnel, steam=steam)
    return [steam, tunnel, day, station, pole_node, near]


def station_layer(sc: Scene) -> El:
    """The platform (event `station`): its own layer, `STATION_W` wide, x = its left edge."""
    F, E, d = sc.F, sc.E, sc.d
    y0, y1 = VIEW[1] - 10, VIEW[3] + 10
    sw = STATION_W
    wall = box(sc, "StationWall", 0, y0, sw, 850, sc.vgrad(-(850 - y0) / 2, (850 - y0) / 2,
                                                          [("FF2A2430", 0.0), ("FF54464C", 0.4), ("FF463A42", 1.0)]))
    bricks = multi(sc, "StationCourses", [seg(sc, 0, y, sw, y) for y in range(560, 850, 26)], sc.L("30201820", 2.0))
    # lit arched windows, the door between them
    wins, mull = [], []
    for wx in (300.0, 450.0, 860.0, 1010.0):
        wins.append(sc.d("Rectangle", width=70.0, height=120.0, x=wx, y=660.0, cornerRadiusTL=35.0,
                         cornerRadiusTR=35.0, name="Path"))
        mull += [seg(sc, wx, 602, wx, 720), seg(sc, wx - 35, 664, wx + 35, 664)]
    windows = d("Node", multi(sc, "StationMullions", mull, sc.L("FF3A2E30", 4.0)),
                multi(sc, "StationWindows", wins, vfill(sc, 600, 720, [("FFFFE6B0", 0.0), ("FFFFBE6C", 1.0)])),
                x=0.0, y=0.0, name="StationLit")
    door = d("Node", box(sc, "DoorPanel", 612, 640, 692, 846, sc.vgrad(-103, 103, [("FF4A3430", 0.0), ("FF2E2224", 1.0)]),
                         r=4),
             box(sc, "DoorFrame", 604, 632, 700, 850, F("FF3A3036"), r=6), x=0.0, y=0.0, name="StationDoor")
    # the canopy (the roof's underside) with its valance, columns and hanging lamps
    canopy = box(sc, "Canopy", -20, y0, sw + 20, 472, sc.vgrad(-37, 37, [("FF1E1A24", 0.0), ("FF2E2834", 1.0)]))
    val_pts = [(-20.0, 470.0, "c")]
    for i in range(int((sw + 40) // 40)):
        x = -20 + 40 * i
        val_pts += [(x + 20, 488.0), (x + 40, 470.0, "c")]
    valance = sc.S(O, "Valance", val_pts, F("FF3E5A50"), origin=O)
    cols = multi(sc, "Columns", [rect_path(sc, cx - 7, 470, cx + 7, 860) for cx in (120.0, 652.0, 1180.0)],
                 F("FF262A34"))
    lamps = []
    for lx in (420.0, 880.0):
        lamps.append(d("Node",
                       E(O, "Glow", lx, 530, 160, 160, sc.rgrad(80, [("90FFE0A0", 0.0), ("00FFE0A0", 1.0)])),
                       E(O, "Globe", lx, 530, 22, 26, F("FFFFF2C8")),
                       sc.S(O, "Rod", [(lx, 470), (lx, 518)], sc.L("FF1A1C24", 3.0), closed=False),
                       x=0.0, y=0.0, name="StationLamp"))
    # the name board under the canopy, over the door: a winged-wheel railway emblem (no fake letters,
    # M11 defect pass), 11 strokes: a hexagon rim, three spokes, a wing stroke each side; and a clock
    ecx, ecy, er = 653.0, 509.0, 13.0
    rim = [(ecx + er * math.cos(math.pi / 3 * k), ecy + er * math.sin(math.pi / 3 * k)) for k in range(7)]
    letters = [seg(sc, *rim[k], *rim[k + 1]) for k in range(6)] + \
              [seg(sc, *rim[k], *rim[k + 3]) for k in range(3)] + \
              [seg(sc, ecx - er - 6, ecy, ecx - er - 40, ecy - 6), seg(sc, ecx + er + 6, ecy, ecx + er + 40, ecy - 6)]
    board = d("Node", multi(sc, "SignLetters", letters, sc.L("FFF0EEE6", 3.4)),
              box(sc, "SignBoard", 574, 490, 732, 528, F("FF223C5A"), sc.L("FFF0EEE6", 2.0), r=4),
              sc.S(O, "SignHangers", [(590, 472), (590, 490)], sc.L("FF1A1C24", 2.0), closed=False),
              sc.S(O, "SignHangers2", [(716, 472), (716, 490)], sc.L("FF1A1C24", 2.0), closed=False),
              x=0.0, y=0.0, name="StationSign")
    clock = d("Node", sc.S(O, "Hands", [(780, 596), (780, 610), (790, 612)], sc.L("FF1A1C24", 2.4), closed=False),
              E(O, "Face", 780, 610, 34, 34, F("FFF0EAD8"), sc.L("FF2A2428", 3.0)), x=0.0, y=0.0, name="StationClock")
    bench = d("Node", box(sc, "Seat", 330, 800, 450, 812, F("FF6A4A34"), r=3),
              box(sc, "Back", 330, 770, 450, 790, F("FF6A4A34"), r=3),
              multi(sc, "Legs", [seg(sc, 342, 812, 342, 846), seg(sc, 438, 812, 438, 846)], sc.L("FF1A1C24", 4.0)),
              x=0.0, y=0.0, name="StationBench")
    posts = []
    for px in (240.0, 1090.0):
        posts.append(d("Node",
                       E(O, "Glow", px, 600, 150, 150, sc.rgrad(75, [("80FFE0A0", 0.0), ("00FFE0A0", 1.0)])),
                       box(sc, "Lantern", px - 10, 588, px + 10, 616, F("FFFFF0C0"), sc.L("FF1A1C24", 2.5), r=3),
                       sc.S(O, "Post", [(px, 616), (px, 870)], sc.L("FF1A1C24", 6.0), closed=False),
                       x=0.0, y=0.0, name="PlatformLamp"))
    platform = d("Node", box(sc, "EdgeLine", -20, 892, sw + 20, 898, F("FFD8C890")),
                 box(sc, "Lip", -20, 906, sw + 20, y1, F("FF2A262E")),
                 box(sc, "Paving", -20, 846, sw + 20, 906, sc.vgrad(-30, 30, [("FF5A5662", 0.0), ("FF6E6A74", 1.0)])),
                 x=0.0, y=0.0, name="Platform")
    return d("Node", *posts, bench, clock, board, *lamps, cols, valance, canopy, platform, door, windows, bricks, wall,
             x=900.0, y=0.0, opacity=0.0, name="Station")


def station_x(f: float) -> float:
    """The station's left edge at frame f of `ev_station` (enter at speed, ease to a stop, hold, leave)."""
    v = STATION_SPEED
    a_end = 88                       # constant speed until the left edge reaches the view's left side
    x_a = 900.0 - v * a_end          # 196
    t_dec = STATION_HOLD[0] - a_end  # 77
    x_hold = x_a - v * t_dec / 2
    if f <= a_end:
        return 900.0 - v * f
    if f <= STATION_HOLD[0]:
        t = f - a_end
        return x_a - (v * t - v * t * t / (2 * t_dec))
    if f <= STATION_HOLD[1]:
        return x_hold
    t_acc = t_dec
    if f <= STATION_HOLD[1] + t_acc:
        t = f - STATION_HOLD[1]
        return x_hold - v * t * t / (2 * t_acc)
    return x_hold - v * t_acc / 2 - v * (f - STATION_HOLD[1] - t_acc)


def tunnel_layer(sc: Scene) -> El:
    """The tunnel wall (event `tunnel`): `TUNNEL_W` of dark ribbed wall with lamps, stone portals at both
    ends; x = its left edge."""
    F, E, d = sc.F, sc.E, sc.d
    y0, y1 = VIEW[1] - 10, VIEW[3] + 10
    tw = TUNNEL_W
    body = box(sc, "TunnelWall", 0, y0, tw, y1, sc.vgrad(-(y1 - y0) / 2, (y1 - y0) / 2,
                                                         [("FF0E0C12", 0.0), ("FF1A1620", 0.5), ("FF0E0C12", 1.0)]))
    ribs = multi(sc, "TunnelRibs", [seg(sc, x, y0, x, y1) for x in range(70, int(tw), 110)], sc.L("40342E3A", 6.0))
    portals = multi(sc, "Portals", [rect_path(sc, 0, y0, 44, y1), rect_path(sc, tw - 44, y0, tw, y1)],
                    sc.d("Fill", lin(sc.d, 0, y0, 0, y1, [("FF4A4450", 0.0), ("FF2E2A34", 1.0)]), name="Fill"))
    lamps = []
    for i, lx in enumerate(range(240, int(tw) - 100, 330)):
        lamps += [E(O, f"Glow{i}", lx, 600, 120, 120, sc.rgrad(60, [("A0FFB860", 0.0), ("00FFB860", 1.0)])),
                  E(O, f"Bulb{i}", lx, 600, 14, 14, F("FFFFE8B0"))]
    return d("Node", d("Node", *lamps, x=0.0, y=0.0, name="TunnelLamps"), portals, ribs, body,
             x=1010.0, y=0.0, opacity=0.0, name="Tunnel")


def whistle_steam(sc: Scene) -> El:
    """Steam puffs (event `whistle`): two halves (the second is a tier gate), at opacity 0 at rest."""
    d = sc.d
    halves: list[list[El]] = [[], []]
    for i in range(8):
        p = sc.E(O, f"Puff{i}", 0, 0, 120, 84, sc.rgrad(60, [("E8ECEEF2", 0.0), ("90E4E8EE", 0.55), ("00E4E8EE", 1.0)]),
                 opacity=0.0)
        halves[i % 2].append(p)
    return d("Node", *[d("Node", *h, x=0.0, y=0.0, name=f"SteamPuffs{'AB'[k]}") for k, h in enumerate(halves)],
             x=0.0, y=0.0, name="WhistleSteam")


# ====================================================================== Plane2: the window
def sheet_paths(sc: Scene, vec: tuple[float, float], n: int, lengths: tuple[float, float], seed: int,
                beads: bool = False) -> list[El]:
    """Drops on the glass that move by `vec` per loop: each drop is copied at every multiple of `vec`
    that can show over the glass during a loop (so the loop is seamless at any frame)."""
    vx, vy = vec
    ln_v = math.hypot(vx, vy)
    ux, uy = vx / ln_v, vy / ln_v
    nx, ny = -uy, ux
    gx0, gy0, gx1, gy1 = GLASS
    corners = [(gx0, gy0), (gx1, gy0), (gx0, gy1), (gx1, gy1)]
    t_lo = min(x * nx + y * ny for x, y in corners) - 20
    t_hi = max(x * nx + y * ny for x, y in corners) + 20
    s_lo = min(x * ux + y * uy for x, y in corners) - ln_v - 80
    s_hi = max(x * ux + y * uy for x, y in corners) + 20
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        t = rnd.uniform(t_lo, t_hi)
        s0 = rnd.uniform(0, ln_v)
        ln = rnd.uniform(*lengths)
        k = math.floor((s_lo - s0) / ln_v)
        while s0 + k * ln_v <= s_hi:
            s = s0 + k * ln_v
            k += 1
            hx, hy = t * nx + s * ux, t * ny + s * uy
            # keep the copy if its sweep over one loop crosses the glass (with a margin)
            if not any(gx0 - 30 <= hx + ux * q <= gx1 + 30 and gy0 - 30 <= hy + uy * q <= gy1 + 30
                       for q in [ln_v * j / 6 for j in range(7)]):
                continue
            if beads:
                out.append(oval(sc, hx, hy, ln * 0.8, ln))
            else:
                out.append(seg(sc, hx - ux * ln, hy - uy * ln, hx, hy))
    return out


def glass_sheet(sc: Scene, name: str, vec: tuple[float, float], period: int, paths: list[El], *paints: El,
                **kw: object) -> El:
    shape = multi(sc, name, paths, *paints, **kw)
    sc.ambient(name, sc.A(f"amb_{name}", period, [sc.T(shape, x=[(0, 0.0, "linear"), (period, vec[0], "linear")],
                                                       y=[(0, 0.0, "linear"), (period, vec[1], "linear")])],
                          loop=True))
    return shape


def plane2(sc: Scene, keep: dict[str, El]) -> list[El]:
    F, E, d = sc.F, sc.E, sc.d
    gx0, gy0, gx1, gy1 = GLASS
    frame = ring(sc, "WinFrame", FRAME, GLASS, sc.d("Fill", lin(sc.d, 0, -256, 0, 256, [("FF6A4430", 0.0),
                                                                                         ("FF4A2E22", 1.0)]),
                                                     name="Fill"), r=8)
    bead = ring(sc, "WinBead", (gx0 - 5, gy0 - 5, gx1 + 5, gy1 + 5), GLASS, F("FFB08A4C"), r=3)
    transom = d("Node", E(O, "Latch", (gx0 + gx1) / 2, (TRANSOM[0] + TRANSOM[1]) / 2, 22, 12, F("FFD0A85A"),
                          sc.L("FF6A4A24", 1.6)),
                box(sc, "TransomBar", gx0 - 4, TRANSOM[0], gx1 + 4, TRANSOM[1],
                    sc.vgrad(-8, 8, [("FF7A5038", 0.0), ("FF4A2E22", 1.0)])),
                x=0.0, y=0.0, name="Transom")
    sheen = poly(sc, "GlassSheen", [(gx0 + 40, gy0), (gx0 + 150, gy0), (gx0 + 380, gy1), (gx0 + 300, gy1)],
                 sc.d("Fill", lin(sc.d, gx0 + 40, 0, gx0 + 380, 0, [("00FFFFFF", 0.0), ("16FFFFFF", 0.5),
                                                                       ("00FFFFFF", 1.0)]), name="Fill"))
    # rain on the glass (`rain`): two streak sheets and slow beads, all slanting down and back
    (na, va, pa), (nb, vb, pb), (nbd, vbd, pbd) = GLASS_SHEETS
    sheet_a = glass_sheet(sc, na, va, pa, sheet_paths(sc, va, 22, (26.0, 46.0), 31), sc.L("90CCD8E6", 1.8))
    sheet_b = glass_sheet(sc, nb, vb, pb, sheet_paths(sc, vb, 26, (16.0, 30.0), 57), sc.L("68C4D0E0", 1.4))
    beads = glass_sheet(sc, nbd, vbd, pbd, sheet_paths(sc, vbd, 24, (4.0, 7.0), 83, beads=True), F("48C8D4E2"),
                        sc.L("90E4ECF4", 1.0))
    far = d("Node", sc.bind("rain", 18, conv(sc, sc.d, 1.7, -0.7, lo=0.0, hi=1.0)), sheet_b, x=0.0, y=0.0,
            opacity=0.0, name="GlassStreaksB")
    wet = multi(sc, "GlassWet", [rect_path(sc, *p) for p in PANES], F("FF7A8898"), opacity=0.2)
    rain = d("Node", sc.bind("rain", 18), sheet_a, far, beads, wet, x=0.0, y=0.0, opacity=0.0, name="RainGlass")
    # the `rain` event: a heavier shower
    sn, sv, sp = SHOWER_SHEET
    shower_sheet = glass_sheet(sc, sn, sv, sp, sheet_paths(sc, sv, 34, (44.0, 70.0), 101), sc.L("A8D4DEEA", 2.2))
    shower = d("Node", shower_sheet, multi(sc, "ShowerWet", [rect_path(sc, *p) for p in PANES], F("FF6E7C8E"),
                                           opacity=0.28),
               x=0.0, y=0.0, opacity=0.0, name="ShowerGlass")
    # the tunnel's reflection of the compartment lamp in the dark glass
    reflect = d("Node", E(O, "LampMirror", 330, 650, 300, 300, sc.rgrad(150, [("70FFD8A0", 0.0), ("00FFD8A0", 1.0)])),
                multi(sc, "Wash", [rect_path(sc, *p) for p in PANES], F("FF3A2A24"), opacity=0.4),
                x=0.0, y=0.0, opacity=0.0, name="GlassReflect")
    keep.update(shower=shower, reflect=reflect)
    return [frame, bead, transom, reflect, shower, rain, sheen]


# ====================================================================== Plane3: the compartment wall
def plane3(sc: Scene, keep: dict[str, El]) -> list[El]:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    bx0, by0, bx1, by1 = BACK
    # ---- walls and ceiling
    wall = ring(sc, "Wall", (-120.0, -120.0, W + 120.0, by1 + 60), OPEN,
                sc.d("Fill", lin(sc.d, 0, -700, 0, 700, [("FF5A3226", 0.0), ("FF6E3E2C", 0.45), ("FF4A281E", 1.0)]),
                     name="Fill"))
    boards = multi(sc, "Boards", [seg(sc, x, by0, x, by1) for x in (100.0, 160.0, 920.0, 980.0)] +
                   [seg(sc, x, 960, x, by1) for x in range(300, 800, 80)], L("40200E0A", 2.0))
    panels = multi(sc, "Panels", [rect_path(sc, 236, 980, 520, 1160, r=6), rect_path(sc, 560, 980, 844, 1160, r=6),
                                  rect_path(sc, 236, 326, 844, 396, r=6)], L("60A8704C", 2.4))
    panel_shade = multi(sc, "PanelShade", [rect_path(sc, 238, 984, 518, 1164, r=6), rect_path(sc, 562, 984, 842, 1164, r=6),
                                           rect_path(sc, 238, 330, 842, 400, r=6)], L("60200E0A", 2.4))
    rail = box(sc, "WainscotRail", bx0 - 40, 950, bx1 + 40, 962, sc.vgrad(-6, 6, [("FF9A6A48", 0.0), ("FF5A3424", 1.0)]))
    vp = VP

    def away(px: float, py: float, x: float) -> tuple[float, float]:
        """The point on the line from VP through (px, py) at screen x."""
        t = (x - vp[0]) / (px - vp[0])
        return x, vp[1] + (py - vp[1]) * t

    left = poly(sc, "SideWallL", [(bx0, by0), away(bx0, by0, -120), (-120, H + 80), (bx0, H + 80)],
                hfill(sc, -120, bx0, [("FF3A2018", 0.0), ("FF5A3024", 1.0)]))
    right = poly(sc, "SideWallR", [(bx1, by0), (bx1, H + 80), (W + 120, H + 80), away(bx1, by0, W + 120)],
                 hfill(sc, bx1, W + 120, [("FF4A281E", 0.0), ("FF2E1812", 1.0)]))
    corner = multi(sc, "Corners", [seg(sc, bx0, by0, bx0, by1), seg(sc, bx1, by0, bx1, by1)], L("50180A08", 3.0))
    ceil_pts = [(-120.0, -120.0), (W + 120.0, -120.0), away(bx1, by0, W + 120), (bx1, by0), (bx0, by0),
                away(bx0, by0, -120)]
    ceiling = poly(sc, "Ceiling", ceil_pts, vfill(sc, -120, by0, [("FF6A5650", 0.0), ("FF8A7468", 1.0)]))
    ribs = multi(sc, "CeilingRibs", [seg(sc, x, by0, vp[0] + (x - vp[0]) * 1.4, -120) for x in (300.0, 540.0, 780.0)] +
                 [seg(sc, bx0, by0, bx1, by0)], L("50402A24", 3.0))
    # ---- the light on the wall (clipped to the wall: never over the view)
    key = gen_scenes.SCENES[SCENE_ID].key
    with sc.minting(sc.d9):
        pool_grad = rad(sc.d, 0.0, 0.0, 330.0, [(key, 0.0), ("00" + key[2:], 1.0)])
        pool_grad.children[0].children.append(sc.bind("lightKey", 38, doc=sc.d9))
        pool_grad.attrs["opacity"] = 0.4
    wall_pool = d("Shape", ellipse(sc.d, 660, 760), d("Fill", pool_grad, name="Fill"), x=LAMP[0], y=LAMP[1] + 40,
                  name="WallPool")
    cool = E(O, "WindowSpill", 540, 690, 900, 700, sc.rgrad(450, [("2894B4DC", 0.0), ("0094B4DC", 1.0)]))
    shade_top = box(sc, "WallShadeTop", -120, -120, W + 120, 360, sc.vgrad(-240, 240, [("60100808", 0.0),
                                                                                       ("00100808", 1.0)]))
    wall_light = d("Node", d("ClippingShape", sourceId=wall.ref(), fillRule="evenOdd", name="Clip"), cool, wall_pool,
                   shade_top, x=0.0, y=0.0, name="WallLight")
    casing = ring(sc, "Casing", CASING, OPEN, sc.d("Fill", lin(sc.d, -340, -246, 340, 246, [("FFB07E56", 0.0),
                                                                                           ("FF7A4E34", 1.0)]),
                                                         name="Fill"), r=8)
    casing_shadow = ring(sc, "CasingShadow", OPEN, (OPEN[0] + 7, OPEN[1] + 7, OPEN[2] - 3, OPEN[3]), F("70120A08"))
    sill = d("Node", box(sc, "SillLip", 168, 916, 912, 932, F("FF5E3A26"), r=3),
             box(sc, "SillTop", 174, SILL_TOP - 6, 906, 918, sc.vgrad(-9, 9, [("FFC0905E", 0.0), ("FF8E6240", 1.0)]),
                 r=4),
             x=0.0, y=0.0, name="Sill")
    # ---- curtains on their rod, tied back
    curtains = []
    for side in (-1, 1):
        def mx(x: float) -> float:
            return x if side < 0 else W - x
        pts = [(172, 404), (266, 404), (254, 520), (232, 640), (228, 700), (238, 780), (258, 898), (176, 898),
               (180, 780), (194, 700), (188, 600), (174, 500)]
        drape = sc.S(O, "Drape", [(mx(x), y) for x, y in pts],
                     sc.d("Fill", lin(sc.d, -40 * -side, 0, 40 * -side, 0, [("FFC88296", 0.0), ("FF8A4A60", 1.0)]),
                          name="Fill"), L("FF5A2A3C", 1.6), tension=0.7)
        folds = multi(sc, "Folds", [smooth_path(sc.d, [(mx(x0), 410.0), (mx(x1), 560.0), (mx(212.0), 700.0),
                                                       (mx(x2), 890.0)], closed=False)
                                    for x0, x1, x2 in ((196.0, 214.0, 200.0), (226.0, 222.0, 222.0),
                                                       (248.0, 232.0, 244.0))], L("508A4A60", 2.4))
        tie = box(sc, "Tieback", mx(190), 690, mx(234), 706, F("FF7A3A50"), r=6) if side < 0 else \
            box(sc, "Tieback", mx(234), 690, mx(190), 706, F("FF7A3A50"), r=6)
        tx, ty = mx(212.0), 706.0
        tassel = d("Node", sc.S((tx, ty), "TasselFringe", [(tx - 7, ty + 26), (tx + 7, ty + 26), (tx + 9, ty + 44),
                                                           (tx - 9, ty + 44)], F("FFD4A85C")),
                   sc.E((tx, ty), "TasselKnob", tx, ty + 18, 14, 16, F("FFC89A50")),
                   sc.S((tx, ty), "TasselCord", [(tx, ty), (tx, ty + 12)], L("FFC89A50", 2.4), closed=False),
                   x=tx, y=ty, name="Tassel")
        keep[f"tassel{side}"] = tassel
        curtains.append(d("Node", tassel, tie, folds, drape, x=0.0, y=0.0, name=f"Curtain{'L' if side < 0 else 'R'}"))
    rod = d("Node", E(O, "FinialL", 162, 403, 16, 16, F("FFD4AA5C")), E(O, "FinialR", 918, 403, 16, 16, F("FFD4AA5C")),
            box(sc, "Bar", 162, 399, 918, 407, sc.vgrad(-4, 4, [("FFE0BC70", 0.0), ("FF8A6A34", 1.0)]), r=4),
            x=0.0, y=0.0, name="CurtainRod")
    # ---- the luggage rack, the suitcase (prop) and a hatbox
    net = multi(sc, "Net", [seg(sc, x, RACK_Y[0], x + 24, RACK_Y[1]) for x in range(112, 890, 22)] +
                [seg(sc, x + 24, RACK_Y[0], x, RACK_Y[1]) for x in range(112, 890, 22)], L("50D4AA5C", 1.2))
    rack = d("Node",
             multi(sc, "RackRails", [seg(sc, 108, RACK_Y[0], 902, RACK_Y[0])], L("FFD4AA5C", 6.0)),
             multi(sc, "RackRailLow", [seg(sc, 108, RACK_Y[1], 902, RACK_Y[1])], L("FFB08A48", 4.0)),
             multi(sc, "RackBrackets", [seg(sc, x, 250, x, 300) for x in (112.0, 506.0, 898.0)] +
                   [seg(sc, x, 320, x + (14 if x < 500 else -14), RACK_Y[0]) for x in (112.0, 898.0)],
                   L("FF8A6A34", 5.0)),
             net, x=0.0, y=0.0, name="Rack")
    sx0, sy0, sx1, sy1 = SUITCASE
    suitcase = d("Node",
                 E(O, "StickerA", 420, 214, 44, 30, F("FFE0D2AE"), L("FFB04A48", 3.0)),
                 box(sc, "StickerB", 250, 222, 286, 248, F("FF6A8AAA"), r=3),
                 multi(sc, "Buckles", [rect_path(sc, x - 9, 196, x + 9, 210, r=2) for x in (296.0, 396.0)], F("FFD4AA5C")),
                 multi(sc, "Straps", [rect_path(sc, x - 8, sy0, x + 8, sy1) for x in (296.0, 396.0)], F("FF4A2C1C")),
                 multi(sc, "Corners", [rect_path(sc, x, y, x + 16, y + 16, r=4) for x, y in
                                       ((sx0 - 2, sy0 - 2), (sx1 - 14, sy0 - 2), (sx0 - 2, sy1 - 14), (sx1 - 14, sy1 - 14))],
                       F("FFC89A50")),
                 box(sc, "Case", sx0, sy0, sx1, sy1, sc.vgrad(-55, 55, [("FF9A6A44", 0.0), ("FF5E3A26", 1.0)]),
                     L(INK, 2.4), r=10),
                 sc.S(O, "Handle", [(316, sy0), (322, sy0 - 16), (370, sy0 - 16), (376, sy0)], L("FF4A2C1C", 6.0),
                      closed=False),
                 x=0.0, y=0.0, name="Suitcase")
    hatbox = d("Node", E(O, "Lid", 690, 196, 132, 26, F("FFB89A80"), L(INK, 2.0)),
               box(sc, "Band", 624, 232, 756, 240, F("FF8A5A70")),
               box(sc, "Drum", 626, 196, 754, RACK_Y[0], sc.vgrad(-33, 33, [("FFC8AE90", 0.0), ("FF8E7460", 1.0)]),
                   L(INK, 2.0)),
               x=0.0, y=0.0, name="Hatbox")
    # ---- the wall lamp (prop): a brass sconce with a frosted tulip shade
    lx, ly = LAMP
    lamp = d("Node",
             E(O, "Bulb", lx, ly + 18, 14, 10, F("FFFFF6D8")),
             sc.S(O, "Shade", [(lx - 26, ly + 22), (lx - 22, ly - 6), (lx - 10, ly - 22), (lx + 10, ly - 22),
                               (lx + 22, ly - 6), (lx + 26, ly + 22), (lx + 14, ly + 26), (lx - 14, ly + 26)],
                  sc.vgrad(-24, 24, [("FFFFF0D0", 0.0), ("FFF2C890", 1.0)]), L("FFB08A48", 2.0)),
             sc.S(O, "Arm", [(lx, ly - 22), (lx, ly - 34), (lx - 6, ly - 42)], L("FFC89A50", 5.0), closed=False),
             box(sc, "Plate", lx - 12, ly - 64, lx + 12, ly - 26, F("FFC89A50"), L("FF6A4A24", 1.6), r=6),
             x=0.0, y=0.0, name="Lamp")
    lamp_glow = E(O, "LampGlow", lx, ly + 8, 360, 360, sc.rgrad(180, [("80FFDCA0", 0.0), ("28FFC880", 0.45),
                                                                       ("00FFC880", 1.0)]))
    lamp_boost = E(O, "LampBoost", lx, ly + 40, 900, 900, sc.rgrad(450, [("60FFD090", 0.0), ("00FFC880", 1.0)]),
                   opacity=0.0)
    rnd = random.Random(55)
    motes = [E(O, f"Mote{i}", lx + rnd.uniform(-50, 70), ly + rnd.uniform(40, 170), 3.4, 3.4, F("C0FFF0D0"))
             for i in range(6)]
    dust = d("Node", *motes, x=0.0, y=0.0, name="LampDust")
    dust_tracks = []
    for i, m in enumerate(motes):
        x0, y0 = float(m.attrs["x"]), float(m.attrs["y"])
        dust_tracks.append(sc.T(m, ease=None, x=[(f, round(x0 + 9 * math.sin(2 * math.pi * f / 360 + i), 3), "linear")
                                                for f in range(0, 361, 30)],
                                y=[(f, round(y0 + 14 * math.sin(2 * math.pi * f / 180 + 2 * i), 3), "linear")
                                   for f in range(0, 361, 30)],
                                opacity=[(f, round(0.55 + 0.45 * math.sin(2 * math.pi * f / 360 + 1.3 * i), 3), "linear")
                                         for f in range(0, 361, 30)]))
    sc.ambient("LampDust", sc.A("amb_LampDust", 360, dust_tracks, loop=True))
    # ---- a glass of tea in a brass holder on the sill
    tx = TEA_X
    tea = d("Node",
            sc.S(O, "Spoon", [(tx + 8, 844), (tx + 4, 872)], L("FFC8C8CC", 2.4), closed=False),
            sc.S(O, "HolderHandle", [(tx + 15, 880), (tx + 28, 882), (tx + 28, 898), (tx + 15, 900)], L("FFB08A48", 3.2),
                 closed=False),
            sc.S(O, "Holder", [(tx - 17, 878), (tx + 17, 878), (tx + 14, SILL_TOP), (tx - 14, SILL_TOP)],
                 sc.vgrad(-14, 14, [("FFD8B06A", 0.0), ("FF8A6A34", 1.0)]), L("FF6A4A24", 1.6)),
            sc.S(O, "Tea", [(tx - 15, 860), (tx + 15, 860), (tx + 15, 880), (tx - 15, 880)], F("FFB0602E")),
            sc.S(O, "TeaGlass", [(tx - 16, 852), (tx + 16, 852), (tx + 16, 880), (tx - 16, 880)], F("40E8ECF0"),
                 L("80E8ECF0", 1.4)),
            x=0.0, y=0.0, name="TeaGlass")
    steam, steam_tracks = [], []
    for k in range(3):
        p = E(O, f"TeaPuff{k}", tx, 846, 20, 20, sc.rgrad(10, [("48ECEEF2", 0.0), ("00ECEEF2", 1.0)]), opacity=0.0)
        steam.append(p)
        off = k * 60
        fr = sorted({*range(0, 181, 20), 180 - off - 1, 180 - off} & set(range(0, 181)))

        def at(f: int, off: int = off, k: int = k) -> tuple[float, float, float, float]:
            t = ((f + off) % 180) / 180
            return (6 * math.sin(t * 6 + k), -70 * t, 0.6 + 1.4 * t, math.sin(math.pi * t) ** 1.4 * 0.8)
        mode = {f: ("hold" if f == 180 - off - 1 else "linear") for f in fr}
        steam_tracks.append(sc.T(p, ease=None, x=[(f, round(tx + at(f)[0], 3), mode[f]) for f in fr],
                                 y=[(f, round(846 + at(f)[1], 3), mode[f]) for f in fr],
                                 scaleX=[(f, round(at(f)[2], 4), mode[f]) for f in fr],
                                 scaleY=[(f, round(at(f)[2], 4), mode[f]) for f in fr],
                                 opacity=[(f, round(at(f)[3], 4), mode[f]) for f in fr]))
    sc.ambient("TeaSteam", sc.A("amb_TeaSteam", 180, steam_tracks, loop=True))
    tea_steam = d("Node", *steam, x=0.0, y=0.0, name="TeaSteam")
    # ---- the whistle chain (the `chain` pull drag)
    chain = chain_rig(sc)
    keep.update(lamp_glow=lamp_glow, wall_pool=wall_pool, lamp_boost=lamp_boost, chain=chain)
    # the train's rocking: the chain and the curtains' tassels sway a little
    sway = [(f, round(CHAIN_SWAY * math.sin(2 * math.pi * f / ROCK), 5), "linear") for f in range(0, ROCK + 1, 10)]
    sc.ambient("Rocking", sc.A("amb_Rocking", ROCK, [
        sc.T(chain, ease=None, rotation=sway),
        *[sc.T(keep[f"tassel{s}"], ease=None,
               rotation=[(f, round(3 * v, 5), m) for f, v, m in sway]) for s in (-1, 1)]], loop=True))
    return [lamp_boost, tea_steam, tea, dust, lamp_glow, lamp, chain, *curtains, rod, sill, casing, casing_shadow,
            suitcase, hatbox, rack, wall_light, rail, panel_shade, panels, boards, corner, ribs, ceiling, left, right,
            wall]


def chain_rig(sc: Scene) -> El:
    """The whistle chain: a brass tube from the ceiling to `CHAIN_TOP`; the chain slides out of it by
    `CHAIN_PULL` x chain (clipped at the tube's mouth) and swings by `CHAIN_SWING` x chain; the rig
    itself is keyed by the rocking loop only."""
    E, F, L, d = sc.E, sc.F, sc.L, sc.d
    links = []
    n = int((CHAIN_LEN + CHAIN_PULL + 40) // 12)
    for i in range(n):
        y = CHAIN_LEN - 6 - 12 * i      # from the handle's ring up into the tube
        if i % 2 == 0:
            links.append(sc.d("Ellipse", width=8.0, height=14.0, x=0.0, y=float(y), name="Path"))
        else:
            links.append(sc.d("Ellipse", width=3.0, height=14.0, x=0.0, y=float(y), name="Path"))
    chain_shape = d("Shape", *links, L("FFC89A50", 2.2), x=0.0, y=0.0, name="Links")
    handle = d("Node",
               sc.S(O, "Tassel", [(-8, 30), (8, 30), (11, HANDLE_H), (-11, HANDLE_H)], F("FFA83A48")),
               E(O, "TasselKnot", 0, 26, 14, 12, F("FF8A2E3C")),
               E(O, "Ring", 0, 10, 20, 20, L("FFD4AA5C", 4.0)),
               x=0.0, y=CHAIN_LEN, name="Handle")
    with sc.minting(sc.d9):
        slide = d("Node", sc.bind("chain", 14, conv(sc, sc.d9, CHAIN_PULL), doc=sc.d9), handle, chain_shape,
                  x=0.0, y=0.0, name="ChainSlide")
        clip = d("Shape", d("Rectangle", width=240.0, height=CHAIN_LEN + CHAIN_PULL + 120, originX=0.5, originY=0.0,
                            name="Path"), x=0.0, y=0.0, name="ChainClip")
        swing = d("Node", sc.bind("chain", 15, conv(sc, sc.d9, CHAIN_SWING), doc=sc.d9),
                  d("ClippingShape", sourceId=clip.ref(), name="Clip"), slide, x=0.0, y=0.0, name="ChainSwing")
    tube = d("Node", box(sc, "TubeMouth", -9, -6, 9, 6, F("FFB08A48"), r=3),
             box(sc, "TubeBody", -5, BACK[1] - CHAIN_TOP - 10, 5, 0, sc.d("Fill", lin(sc.d, -5, 0, 5, 0, [
                 ("FFE0BC70", 0.0), ("FF8A6A34", 1.0)]), name="Fill")),
             box(sc, "TubeClip", -10, -110, 10, -96, F("FF8A6A34"), r=3),
             x=0.0, y=0.0, name="ChainTube")
    return d("Node", tube, swing, clip, x=CHAIN_X, y=CHAIN_TOP, name="ChainRig")


def chain_box(v: float, pad: float = 2.0) -> tuple[float, float, float, float]:
    """The chain's art box (artboard px, parallax 0) at `chain` = v, over the whole rocking sway."""
    xs, ys = [CHAIN_X - 9, CHAIN_X + 9], [CHAIN_TOP - 6]
    for sway in (-CHAIN_SWAY, 0.0, CHAIN_SWAY):
        th = sway + CHAIN_SWING * v
        c, s = math.cos(th), math.sin(th)
        for px, py in ((-11.0, CHAIN_LEN + HANDLE_H + CHAIN_PULL * v), (11.0, CHAIN_LEN + HANDLE_H + CHAIN_PULL * v),
                       (-11.0, 0.0), (11.0, 0.0)):
            xs.append(CHAIN_X + px * c - py * s)
            ys.append(CHAIN_TOP + px * s + py * c)
    return min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad


def chain_rect(finger: float = 80.0) -> tuple[float, float, float, float]:
    """The drag handle (contract v14 drag table row, Plane3): the chain from its tube to the tassel over
    chain 0 .. 1 and the rocking sway, widened to a finger, whole px."""
    boxes = [chain_box(i / 20) for i in range(21)]
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    if x1 - x0 < finger:
        cx = (x0 + x1) / 2
        x0, x1 = cx - finger / 2, cx + finger / 2
    return float(math.floor(x0)), float(math.floor(y0)), float(math.ceil(x1)), float(math.ceil(y1))


CHAIN_RECT = chain_rect()


# ====================================================================== Plane4: benches and floor
def bench(sc: Scene, side: int) -> El:
    """A velvet bench along the side wall in perspective (computed for the left, mirrored for the right)."""
    F, L, d = sc.F, sc.L, sc.d

    def mx(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0], p[1]) if side < 0 else (W - p[0], p[1])

    def P(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
        out = [mx(p) for p in pts]
        return out if side < 0 else list(reversed(out))
    name = "BenchL" if side < 0 else "BenchR"
    top = poly(sc, "SeatTop", P([(108, 1056), (268, 1056), (-100, 1511), (-100, 1218)]),
               vfill(sc, 1056, 1511, [("FF8A3450", 0.0), ("FF6A2440", 1.0)]))
    piping = multi(sc, "Piping", [seg(sc, *mx((268, 1056)), *mx((-100, 1511)))], L("FFB06A7E", 3.0))
    front = poly(sc, "SeatFront", P([(268, 1056), (268, 1092), (-100, 1600), (-100, 1511)]),
                 vfill(sc, 1056, 1600, [("FF5E2038", 0.0), ("FF4A1830", 1.0)]))
    kick = poly(sc, "Kick", P([(268, 1092), (268, 1200), (-100, 1849), (-100, 1600)]),
                vfill(sc, 1092, 1849, [("FF2E1A1A", 0.0), ("FF1E1214", 1.0)]))
    back = poly(sc, "Backrest", P([(108, 880), (108, 1056), (-100, 1218), (-100, 957)]),
                vfill(sc, 880, 1218, [("FF7A2C46", 0.0), ("FF5A2038", 1.0)]))
    back_top = poly(sc, "BackrestTop", P([(60, 880), (108, 880), (-100, 957), (-100, 933)]), F("FFA05468"))
    buttons = []
    for t in (0.15, 0.4, 0.68):
        for h in (0.35, 0.7):
            x = 108 + (-100 - 108) * t
            y_top = 880 + (957 - 880) * t
            y_bot = 1056 + (1218 - 1056) * t
            bx_, by_ = mx((x, y_top + (y_bot - y_top) * h))
            sz = 5 + 4 * t
            buttons.append(oval(sc, bx_, by_, sz, sz))
    tufts = multi(sc, "Buttons", buttons, F("FF3E1428"))
    return d("Node", tufts, back_top, back, piping, top, front, kick, x=0.0, y=0.0, name=name)


def plane4(sc: Scene, keep: dict[str, El]) -> list[El]:
    F, L, d = sc.F, sc.L, sc.d
    bx0, _, bx1, by1 = BACK
    vp = VP

    def at_y(px: float, py: float, y: float) -> float:
        return vp[0] + (px - vp[0]) * (y - vp[1]) / (py - vp[1])

    floor = poly(sc, "Floor", [(-120, by1 - 8), (W + 120, by1 - 8), (W + 120, H + 80), (-120, H + 80)],
                 vfill(sc, by1, H, [("FF2E2026", 0.0), ("FF1A1216", 1.0)]))
    yb = H + 80
    runner = poly(sc, "Runner", [(320, by1), (760, by1), (at_y(760, by1, yb), yb), (at_y(320, by1, yb), yb)],
                  vfill(sc, by1, H, [("FF4A2E42", 0.0), ("FF3A2234", 1.0)]))
    stripes = [seg(sc, x, by1, at_y(x, by1, yb), yb) for x in (338.0, 350.0, 730.0, 742.0)]
    for s in (3.45, 3.9, 4.5, 5.3, 6.4, 8.0, 10.2):
        y = vp[1] + 150 * s
        stripes.append(seg(sc, at_y(350, by1, y), y, at_y(730, by1, y), y))
    pattern = multi(sc, "RunnerBands", stripes, L("70A86A5A", 3.0))
    key = gen_scenes.SCENES[SCENE_ID].key
    with sc.minting(sc.d9):
        pool_grad = rad(sc.d, 0.0, 0.0, 420.0, [(key, 0.0), ("00" + key[2:], 1.0)])
        pool_grad.children[0].children.append(sc.bind("lightKey", 38, doc=sc.d9))
        pool_grad.attrs["opacity"] = 0.2
    pool = d("Shape", ellipse(sc.d, 840, 840), d("Fill", pool_grad, name="Fill"), x=330.0, y=by1 + 160, scaleY=0.34,
             name="FloorPool")
    shade = box(sc, "FloorShade", -120, by1 - 8, W + 120, by1 + 40, sc.vgrad(-24, 24, [("80100806", 0.0),
                                                                                      ("00100806", 1.0)]))
    keep["floor_pool"] = pool
    return [bench(sc, -1), bench(sc, 1), pool, shade, pattern, runner, floor]


# ====================================================================== Plane5: the foreground
def plane5(sc: Scene) -> list[El]:
    F, L, d = sc.F, sc.L, sc.d
    edge = d("Node",
             sc.S(O, "EdgeTassel", [(18, 1150), (40, 1150), (44, 1196), (14, 1196)], F("FFD4A85C")),
             multi(sc, "EdgeFolds", [smooth_path(sc.d, [(x, -60.0), (x + 6, 500.0), (x - 4, 1140.0)], closed=False)
                                     for x in (-20.0, 14.0, 40.0)], L("608A4A60", 4.0)),
             sc.S(O, "EdgeDrape", [(-80, -80, "c"), (62, -80, "c"), (58, 500), (66, 1000), (54, 1150, "c"),
                                   (-80, 1170, "c")],
                  sc.d("Fill", lin(sc.d, -80, 0, 66, 0, [("FF5A2A3C", 0.0), ("FF9A5A70", 0.7), ("FF7A3E54", 1.0)]),
                       name="Fill"), origin=O),
             x=0.0, y=0.0, name="CurtainEdge")
    arm = d("Node",
            sc.S(O, "ArmCap", [(898, 1470), (1160, 1430, "c"), (1160, 1450, "c"), (904, 1492)], F("FFC89A50")),
            sc.S(O, "ArmPad", [(900, 1480), (1160, 1440, "c"), (1160, 1720, "c"), (936, 1736), (912, 1700)],
                 sc.d("Fill", lin(sc.d, 900, 0, 1160, 0, [("FF8A3450", 0.0), ("FF5A2038", 1.0)]), name="Fill"),
                 L("FF3E1428", 2.4), origin=O),
            x=0.0, y=0.0, name="ArmRest")
    return [edge, arm]


# ====================================================================== the events
def events(sc: Scene, keep: dict[str, El]) -> None:
    T = sc.T
    # ---- tunnel: the wall runs past (lamps flick by), the window goes dark, the lamp takes over
    n = EVENT_FRAMES["tunnel"]
    tun = keep["tunnel"]
    sc.one_shot("tunnel", sc.A("ev_tunnel", n, [
        T(tun, x=[(0, 1010.0, "linear"), (n, 1010.0 - TUNNEL_SPEED * n, "linear")],
          opacity=[(0, 0.0, "hold"), (1, 1.0, "hold"), (n - 1, 1.0, "hold"), (n, 0.0, "hold")]),
        T(keep["lamp_boost"], opacity=[(0, 0.0), (40, 0.75), (140, 0.75), (n, 0.0)]),
        T(keep["reflect"], opacity=[(0, 0.0), (30, 0.0), (48, 1.0), (136, 1.0), (152, 0.0), (n, 0.0)]),
    ]))
    # ---- whistle: steam streams past the top of the window, right to left
    n = EVENT_FRAMES["whistle"]
    tracks = []
    puffs = [p for h in keep["steam"].children for p in h.children]
    puffs.sort(key=lambda p: int(str(p.attrs["name"])[4:]))
    for i, p in enumerate(puffs):
        s0, life = 4 + 9 * i, 52
        y0 = 452.0 + 22 * (i % 3)

        def at(f: int, s0: int = s0, y0: float = y0, i: int = i) -> tuple[float, float, float, float]:
            t = min(1.0, max(0.0, (f - s0) / life))
            return (930 - 15.5 * life * t, y0 - 26 * t + 6 * math.sin(4 * t + i), 0.6 + 1.0 * t,
                    (math.sin(math.pi * t) ** 0.8) * 0.95 if s0 <= f <= s0 + life else 0.0)
        frames = sorted({0, n, s0, *range(s0, min(n, s0 + life) + 1, 4), min(n, s0 + life)})
        tracks.append(T(p, ease=None, x=[(f, round(at(f)[0], 3), "linear") for f in frames],
                        y=[(f, round(at(f)[1], 3), "linear") for f in frames],
                        scaleX=[(f, round(at(f)[2], 4), "linear") for f in frames],
                        scaleY=[(f, round(at(f)[2], 4), "linear") for f in frames],
                        opacity=[(f, round(at(f)[3], 4), "linear") for f in frames]))
    sc.one_shot("whistle", sc.A("ev_whistle", n, tracks))
    # ---- station: the platform slides in, eases to a stop, holds, and speeds away
    n = EVENT_FRAMES["station"]
    frames = sorted({*range(0, n + 1, 4), 88, STATION_HOLD[0], STATION_HOLD[1], STATION_HOLD[1] + 77, n})
    sc.one_shot("station", sc.A("ev_station", n, [
        T(keep["station"], ease=None, x=lin_keys(station_x, frames),
          opacity=[(0, 0.0, "hold"), (1, 1.0, "hold"), (n - 1, 1.0, "hold"), (n, 0.0, "hold")])]))
    # ---- rain: a shower on the glass
    n = EVENT_FRAMES["rain"]
    sc.one_shot("rain", sc.A("ev_rain", n, [
        T(keep["shower"], ease=None, opacity=[(0, 0.0, "linear"), (50, 1.0, "linear"), (n - 70, 1.0, "linear"),
                                              (n, 0.0, "linear")])]))


# ====================================================================== the ladybug
LB_RED, LB_RED_SH, LB_BLACK, LB_WHITE = "FFD8483E", "FF9A2A2A", "FF1A1418", "FFF2EEE6"


def ladybug_npc(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The ladybug on the sill (Plane3): a side view facing right, `LbFace` mirrors it for npcLook < 0.
    Every state keys every registered property (`Rig.anim`)."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rig = Rig(sc)
    Z = O

    def at(x: float, y: float, px: float, py: float) -> tuple[float, float]:
        return float(x - px), float(y - py)

    # ---- legs: hip -> knee -> foot (three near, three far), each a node at its hip
    legs_near, legs_far = [], []
    for k, hx in enumerate((-12.0, 0.0, 11.0)):
        for far in (False, True):
            col = "FF2A2228" if far else LB_BLACK
            ox = 3.0 if far else 0.0
            pts = [(0.0, 0.0), (4.0 + ox * 0.3, 4.5), (6.0 + ox * 0.3, 9.0)] if hx >= 0 else \
                [(0.0, 0.0), (-4.0, 4.5), (-6.0, 9.0)]
            leg = d("Node", S(Z, "LegLine", pts, L(col, 2.0 if not far else 1.7), closed=False, origin=Z),
                    x=hx + ox, y=-9.0, name=f"LbLeg{'F' if far else 'N'}{k}")
            rig.reg(leg, rotation=0.0)
            (legs_far if far else legs_near).append(leg)
    # ---- the wing case (elytra) on its front hinge, the hindwing under it
    hinge = (12.0, -22.0)
    case = d("Node",
             S(hinge, "CaseShine", [(-4, -24), (4, -25.5), (10, -23)], L("B0FFFFFF", 2.2), closed=False),
             *[E(hinge, f"Spot{i}", x, y, w, h, F(LB_BLACK)) for i, (x, y, w, h) in
               enumerate(((-10.0, -16.0, 9.0, 8.0), (2.0, -21.0, 8.0, 7.0), (6.0, -11.0, 7.0, 6.0),
                          (-17.0, -9.0, 5.0, 5.0)))],
             S(hinge, "CaseLine", [(14, -24), (2, -26), (-12, -22), (-20, -12)], L("80601818", 1.4), closed=False),
             S(hinge, "Case", [(-23, -6), (-21, -16), (-13, -25), (0, -28.5), (12, -26), (17, -18), (18, -8),
                               (8, -4.5), (-10, -4)],
               sc.vgrad(-12, 12, [(LB_RED, 0.0), (LB_RED_SH, 1.0)]), L("FF4A1414", 1.4), tension=0.9),
             x=hinge[0], y=hinge[1], name="LbCase")
    rig.reg(case, rotation=0.0)
    # the hindwing stays within ~one body length behind the hinge (M11 defect pass: the longer one reached
    # over the left curtain's edge at npcX 0)
    wing = d("Node", S(hinge, "Wing", [(14, -24), (-4, -32), (-20, -31), (-27, -24), (-18, -18), (0, -20)],
                       F("80E8DCC8"), L("A0B8A890", 1.0), tension=0.8),
             x=hinge[0], y=hinge[1], opacity=0.0, name="LbWing")
    rig.reg(wing, opacity=0.0, rotation=0.0)
    # ---- head with its antennae (pivot at the neck)
    neck = (19.0, -12.0)
    ants = []
    for k, (dx, dy, col) in enumerate(((10.0, -12.0, LB_BLACK), (7.0, -13.0, "FF3A3036"))):
        a = d("Node", E((neck[0] + 6, neck[1] - 4), "Club", neck[0] + 6 + dx, neck[1] - 4 + dy, 4.0, 4.0, F(col)),
              S((neck[0] + 6, neck[1] - 4), "Stalk", [(neck[0] + 6, neck[1] - 4), (neck[0] + 6 + dx * 0.6, neck[1] - 4 + dy * 0.7),
                                                      (neck[0] + 6 + dx, neck[1] - 4 + dy)],
                L(col, 1.4), closed=False),
              x=6.0, y=-4.0, name=f"LbAntenna{k}")
        rig.reg(a, rotation=0.0)
        ants.append(a)
    head = d("Node", ants[0],
             E(neck, "Glint", neck[0] + 9, neck[1] - 1, 3.0, 3.0, F("F0FFFFFF")),
             E(neck, "Cheek", neck[0] + 4, neck[1] + 1, 5.0, 4.0, F(LB_WHITE)),
             E(neck, "HeadShape", neck[0] + 5, neck[1] + 1, 12.0, 11.0, F(LB_BLACK)),
             ants[1], x=neck[0], y=neck[1], name="LbHead")
    rig.reg(head, rotation=0.0)
    pronotum = d("Node", S(Z, "Pronotum", [(13, -21), (20, -17), (23, -9), (19, -5), (12, -6)], F(LB_BLACK)),
                 E(Z, "Patch", 18, -14, 5.0, 6.0, F(LB_WHITE)), x=0.0, y=0.0, name="LbThorax")
    belly = S(Z, "Belly", [(-18, -5), (16, -5), (14, -2), (-16, -2)], F("FF241C22"))
    rear = (-18.0, -4.0)
    body = d("Node", d("Node", wing, x=-rear[0], y=-rear[1], name="LbWingPivot"),
             d("Node", case, head, pronotum, *legs_near, belly, x=-rear[0], y=-rear[1], name="LbBodyPivot"),
             x=rear[0], y=rear[1], name="LbBody")
    # the hindwing draws over the case while it flutters (it is hidden at rest)
    rig.reg(body, y=rear[1], rotation=0.0)
    step = d("Node", body, *legs_far, x=0.0, y=0.0, name="LbStep")
    rig.reg(step, x=0.0)
    shadow = E(Z, "LbShadow", 2, 1, 50, 6, F("50080608"))
    rig.reg(shadow, scaleX=1.0)
    face = d("Node", step, shadow, x=0.0, y=0.0, name="LbFace")
    f = Formulas(sc.d8, sc.vpath)
    flip = scene_npc.formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                                  *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)],
                                                                 [f.val(-1000), f.op("*"), f.bound("npcLook")]))])
    face.children.insert(0, sc.bind("npcLook", 16, flip, doc=sc.d8))
    size = d("Node", face, x=0.0, y=0.0, scaleX=LADYBUG_SCALE, scaleY=LADYBUG_SCALE, name="LbSize")
    x0, y0, _ = LADYBUG_WAYPOINTS[0]
    npc = d("Node", size, x=x0, y=y0, name="LadybugNpc")
    rig.reg(npc, opacity=1.0)
    ts = arc_params([(x, y) for x, y, _ in LADYBUG_WAYPOINTS])
    path_binds(sc, npc, ts, [p[0] for p in LADYBUG_WAYPOINTS], [p[1] for p in LADYBUG_WAYPOINTS])
    hit = next(h for h in hits if h.attrs.get("name") == "Hit_ladybug")
    path_binds(sc, hit, ts, [p[0] + LADYBUG_HIT[0] for p in LADYBUG_WAYPOINTS],
               [p[1] + LADYBUG_HIT[1] for p in LADYBUG_WAYPOINTS])
    content.insert(next(i for i, e in enumerate(content) if e.attrs.get("name") == "TeaGlass"), npc)

    # ---- states (every one keys every registered property)
    tripod_a = [legs_near[0], legs_near[2], legs_far[1]]
    tripod_b = [legs_near[1], legs_far[0], legs_far[2]]
    anims: dict[str, El | list[El]] = {}
    anims["rest"] = rig.anim("npc_ladybug_rest", 1)
    anims["away"] = rig.anim("npc_ladybug_away", 1, {npc: {"opacity": [(0, 0.0)]}})
    n = LB_IDLE

    def shuffle(f0: int, f1: int, swing: float) -> dict[El, list]:
        """Legs stepping between f0 and f1 (6-frame steps), alternating tripods."""
        ka: list = [(0, 0.0)]
        kb: list = [(0, 0.0)]
        for i, fr in enumerate(range(f0, f1, 6)):
            s = swing if i % 2 == 0 else -swing
            ka.append((fr, s))
            kb.append((fr, -s))
        ka += [(f1, 0.0), (n, 0.0)]
        kb += [(f1, 0.0), (n, 0.0)]
        return {**{lg: ka for lg in tripod_a}, **{lg: kb for lg in tripod_b}}

    legs_idle = shuffle(130, 166, 0.4)
    legs_back = shuffle(250, 286, 0.4)
    merged: dict[El, list] = {}
    for lg in [*tripod_a, *tripod_b]:
        merged[lg] = sorted({*legs_idle[lg][:-1], *legs_back[lg][1:]}, key=lambda k: k[0])
    anims["idle"] = rig.anim("npc_ladybug_idle", n, {
        **{lg: {"rotation": merged[lg]} for lg in merged},
        step: {"x": [(0, 0.0), (130, 0.0), (166, 9.0), (250, 9.0), (286, 0.0), (n, 0.0)]},
        ants[0]: {"rotation": [(0, 0.0), (40, 0.0), (46, -0.4), (52, 0.1), (58, -0.3), (66, 0.0), (200, 0.0),
                               (206, 0.35), (214, 0.0), (n, 0.0)]},
        ants[1]: {"rotation": [(0, 0.0), (42, 0.0), (48, -0.3), (54, 0.15), (62, 0.0), (310, 0.0), (316, -0.35),
                               (324, 0.0), (n, 0.0)]},
        head: {"rotation": [(0, 0.0), (90, 0.0), (100, -0.18), (118, -0.18), (126, 0.0), (n, 0.0)]},
        body: {"rotation": [(0, 0.0), (130, 0.0), (148, 0.03), (166, 0.0), (n, 0.0)]},
    })
    m = LB_WALK
    half = m // 2
    anims["move"] = rig.anim("npc_ladybug_move", m, {
        **{lg: {"rotation": [(0, 0.38, "linear"), (half, -0.38, "linear"), (m, 0.38, "linear")]} for lg in tripod_a},
        **{lg: {"rotation": [(0, -0.38, "linear"), (half, 0.38, "linear"), (m, -0.38, "linear")]} for lg in tripod_b},
        body: {"y": [(0, rear[1]), (half // 2, rear[1] - 0.8), (half, rear[1]), (half + half // 2, rear[1] - 0.8),
                     (m, rear[1])]},
        ants[0]: {"rotation": [(0, -0.1), (half, 0.08), (m, -0.1)]},
        ants[1]: {"rotation": [(0, 0.08), (half, -0.1), (m, 0.08)]},
    })
    n = LB_NOTICE

    def notice(s: float) -> El:
        a = abs(s)
        return rig.anim(f"npc_ladybug_notice{'LCR'[int(s) + 1]}", n, {
            body: {"rotation": [(0, -0.1 - 0.06 * a)]},
            head: {"rotation": [(0, -0.22 * a - 0.06), (40, -0.16 * a - 0.08), (80, -0.24 * a - 0.06),
                                (n, -0.22 * a - 0.06)]},
            ants[0]: {"rotation": [(0, -0.45), (24, -0.3), (30, -0.5), (70, -0.4), (76, -0.55), (n, -0.45)]},
            ants[1]: {"rotation": [(0, -0.35), (26, -0.22), (34, -0.4), (72, -0.3), (80, -0.45), (n, -0.35)]},
            legs_near[2]: {"rotation": [(0, 0.12)]},
        })
    anims["notice"] = blend3(notice)
    n = LB_REACT
    flutter = [(0, 0.0)] + [(fr, 0.28 if (fr // 2) % 2 else -0.22, "linear") for fr in range(5, 29, 2)] + \
        [(30, 0.0), (n, 0.0)]
    anims["react"] = rig.anim("npc_ladybug_react", n, {
        case: {"rotation": [(0, 0.0), (4, 0.75), (28, 0.75), (33, 0.0), (n, 0.0)]},
        wing: {"opacity": [(0, 0.0, "hold"), (4, 1.0, "hold"), (30, 0.0, "hold"), (n, 0.0)], "rotation": flutter},
        body: {"y": [(0, rear[1]), (6, rear[1] + 1.5), (12, rear[1] - 7.0), (20, rear[1] - 8.0), (28, rear[1]),
                     (31, rear[1] + 1.0), (n, rear[1])],
               "rotation": [(0, 0.0), (8, -0.08), (24, -0.04), (30, 0.0), (n, 0.0)]},
        shadow: {"scaleX": [(0, 1.0), (12, 0.7), (20, 0.68), (28, 1.0), (n, 1.0)]},
        **{lg: {"rotation": [(0, 0.0), (8, 0.5), (26, 0.4), (30, 0.0), (n, 0.0)]} for lg in legs_near},
        ants[0]: {"rotation": [(0, 0.0), (6, -0.6), (26, -0.5), (32, 0.0), (n, 0.0)]},
        ants[1]: {"rotation": [(0, 0.0), (6, -0.5), (26, -0.4), (32, 0.0), (n, 0.0)]},
    })
    npc_layer(sc, anims)


def ladybug_walk_speed() -> float:
    """npcX per second at which the walk cycle's stride matches its travel along the sill."""
    (x0, y0, _), (x1, y1, _) = LADYBUG_WAYPOINTS[0], LADYBUG_WAYPOINTS[-1]
    return LB_STRIDE * LADYBUG_SCALE * 60 / LB_WALK / math.hypot(x1 - x0, y1 - y0)


# ====================================================================== the scene
def trainCompartment() -> str:  # noqa: N802 (scene ids are contract names)
    sc = _TrainScene(SCENE_ID)
    keep: dict[str, El] = {}
    p0 = plane0(sc, keep)
    p1 = plane1(sc, keep)
    p2 = plane2(sc, keep)
    p3 = plane3(sc, keep)
    p4 = plane4(sc, keep)
    p5 = plane5(sc)
    # the lamp's light flickers a little (the key light loops in the file)
    sc.ambient("LampFlicker", sc.A("amb_LampFlicker", FLICKER, [
        sc.T(keep["lamp_glow"], opacity=LAMP_FLICKER),
        sc.T(keep["wall_pool"], opacity=[(f, round(0.9 + (v - 0.95) * 2, 4)) for f, v in LAMP_FLICKER]),
        sc.T(keep["floor_pool"], opacity=[(f, round(0.9 + (v - 0.95) * 2, 4)) for f, v in LAMP_FLICKER])], loop=True))
    lx0, ly0, _ = LADYBUG_WAYPOINTS[0]
    hits = [sc.hit("window", (GLASS[0] + GLASS[2]) / 2, (GLASS[1] + 830.0) / 2, GLASS[2] - GLASS[0], 830.0 - GLASS[1]),
            sc.hit("lamp", LAMP[0], LAMP[1] - 6, 90, 132),
            sc.hit("suitcase", (SUITCASE[0] + SUITCASE[2]) / 2, (SUITCASE[1] + SUITCASE[3]) / 2 - 6,
                   SUITCASE[2] - SUITCASE[0] + 20, SUITCASE[3] - SUITCASE[1] + 32),
            sc.hit("ladybug", lx0 + LADYBUG_HIT[0], ly0 + LADYBUG_HIT[1], LADYBUG_HIT[2], LADYBUG_HIT[3])]
    for h_ in hits:
        sc.prop(str(h_.attrs["name"])[4:], h_)
    events(sc, keep)
    content = [*p5, *p4, *p3, *p2, *p1, *p0]
    with sc.minting(sc.d8):
        ladybug_npc(sc, content, hits)
    return sc.write(content, hits)


# ====================================================================== the diorama
PLANES: dict[str, int | None] = {
    **dict.fromkeys(("CurtainEdge", "ArmRest"), 5),
    **dict.fromkeys(("BenchL", "BenchR", "FloorPool", "FloorShade", "RunnerBands", "Runner", "Floor"), 4),
    **dict.fromkeys(("LampBoost", "TeaSteam", "LadybugNpc", "TeaGlass", "LampDust", "LampGlow", "Lamp", "ChainRig",
                     "CurtainL", "CurtainR", "CurtainRod", "Sill", "Casing", "CasingShadow", "Suitcase", "Hatbox",
                     "Rack", "WallLight", "WainscotRail", "PanelShade", "Panels", "Boards", "Corners", "CeilingRibs",
                     "Ceiling", "SideWallL", "SideWallR", "Wall"), 3),
    **dict.fromkeys(("WinFrame", "WinBead", "Transom", "GlassReflect", "ShowerGlass", "RainGlass", "GlassSheen"), 2),
    **dict.fromkeys(("WhistleSteam", "Tunnel", "LandDay", "Station", "Poles", "NearTrees"), 1),
    **dict.fromkeys(("MidLand", "FarHills", "MoonRig", "MoonDrawn", "StarTwinkleA", "StarTwinkleB", "Stars",
                     "Sky"), 0),
    "Hit_window": 2, "Hit_lamp": 3, "Hit_suitcase": 3, "Hit_ladybug": 3,
}
EMISSIVE = ("LampBoost", "LampGlow", "WallLight", "FloorPool", "MoonDrawn", "Stars", "StarTwinkleA", "StarTwinkleB",
            "VillageLit", "StationLit", "StationLamp", "PlatformLamp", "TunnelLamps", "GlassReflect")
VEILS = ((0.3, 560.0, 760.0), (0.12, 700.0, 940.0))   # haze toward the horizon (Plane0), the near ground (Plane1)
FOG_BANK = (1, 520.0, 780.0, "FFB8C0D0", 0.7)

DIORAMAS[SCENE_ID] = DioramaSpec(PLANES, EMISSIVE, VEILS)
TIME_SKY[SCENE_ID] = (HORIZON, 0.45)
scene_npc.FOG_VEILS[SCENE_ID] = (0, 1)
scene_npc.FOG_BANKS[SCENE_ID] = FOG_BANK


# ====================================================================== review registry
def review_extras(render: Callable[..., object], out: Path, gates: list[str]) -> None:
    """review_diorama's scene extras: the events at their peaks, the chain drag's pixel proof (chain 0 /
    0.5 / 1 change pixels only inside `CHAIN_RECT`, history-free), the seasons change only the view, the
    moon's phases, and one contact sheet (`contact_sheet.png`) of the brief's states."""
    import numpy as np  # noqa: PLC0415 (review only)
    from PIL import Image, ImageDraw  # noqa: PLC0415

    def im(a: object, label: str, size: tuple[int, int] = (270, 480), box_: tuple[int, ...] | None = None) -> Image.Image:
        img = Image.fromarray(a).convert("RGB")  # type: ignore[arg-type]
        if box_ is not None:
            img = img.crop(box_)
        img = img.resize(size)
        ImageDraw.Draw(img).text((5, 3), label, fill=(255, 255, 0))
        return img

    def grid(cells: list[Image.Image], cols: int) -> Image.Image:
        w, h = cells[0].size
        sheet = Image.new("RGB", (cols * w, ((len(cells) + cols - 1) // cols) * h), (20, 20, 20))
        for i, c in enumerate(cells):
            sheet.paste(c, ((i % cols) * w, (i // cols) * h))
        return sheet

    def changed(a: object, b: object) -> object:
        return np.abs(a.astype(int) - b.astype(int))[..., :3].max(-1) > 0  # type: ignore[union-attr]

    rest = render("--advance=1")
    cells = [im(rest, "rest f0"), im(render("--advance=91"), "f90")]
    for label, args in (("noon", ("--data=daylight=1", "--advance=1")),
                        ("dusk (0.4 / 1)", ("--data=daylight=0.4", "--data=dusk=1", "--advance=1")),
                        ("rain 1 f40", ("--data=rain=1", "--advance=41")),
                        ("fog 1", ("--data=fog=1", "--advance=1")),
                        ("spring 1", ("--data=spring=1", "--advance=1")),
                        ("autumn 1", ("--data=autumn=1", "--advance=1")),
                        ("parallax -1 / -1", ("--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=1")),
                        ("parallax +1 / +1", ("--data=parallaxX=1", "--data=parallaxY=1", "--advance=1"))):
        cells.append(im(render(*args), label))
    ev_cells = []
    for ev, f in EVENT_PEAKS.items():
        ev_cells.append(im(render(f"--data=eventId={ev}", "--data=event=1", f"--advance={f}"), f"{ev} +{f}f"))
    cells += ev_cells
    # the station's run: enters, holds, leaves
    st_cells = [im(render("--data=eventId=station", "--data=event=1", f"--advance={f}"), f"station +{f}f",
                   (360, 210), (180, 390, 900, 950)) for f in (40, 100, 160, 240, 340, 420)]
    grid(st_cells, 3).save(out / "station_strip.png")
    grid(ev_cells, 4).save(out / "events_strip.png")
    # the seasons change the view only
    vx0, vy0, vx1, vy1 = (int(v) for v in OPEN)
    for season in ("spring", "autumn"):
        a = render(f"--data={season}=1", "--advance=1")
        ch = changed(a, rest)
        inside = ch[vy0:vy1, vx0:vx1].mean()
        ch[vy0:vy1, vx0:vx1] = False
        gates.append(f"{season} 1: changes {inside:.2%} of the window, {int(ch.sum())} px outside it "
                     f"({'ok' if inside > 0.02 and not ch.any() else 'FAIL'})")
    # ---- the chain drag: history-free pixels only in the handle's rect
    x0, y0, x1, y1 = (int(v) for v in CHAIN_RECT)
    allowed = np.zeros(rest.shape[:2], bool)  # type: ignore[union-attr]
    allowed[y0:y1, x0:x1] = True
    drag_cells = []
    worst, bbox = 0.0, None
    for v in (0.0, 0.5, 1.0):
        a = render(f"--data=chain={v}", "--advance=1")
        drag_cells.append(im(a, f"chain {v}", (180, 560), (870, 270, 1050, 830)))
        ch = changed(a, rest)
        worst = max(worst, float((ch & ~allowed).mean()))
        if ch.any():
            ys, xs = np.nonzero(ch)
            b = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
            bbox = b if bbox is None else (min(bbox[0], b[0]), min(bbox[1], b[1]), max(bbox[2], b[2]), max(bbox[3], b[3]))
    # (the CLI's mid-run `--data` step takes a frame each: this run ends on frame 4; the chain rocks)
    back = render("--data=chain=1", "--advance=1", "--data=chain=0", "--advance=2")
    region = (slice(y0, y1), slice(x0, x1))
    back_diff = int(np.abs(back.astype(int) - render("--advance=4").astype(int))[region][..., :3].max())  # type: ignore
    grid(drag_cells, 3).save(out / "chain_drag.png")
    gates.append(f"chain drag: pixels changed at chain 0.5 / 1 outside {CHAIN_RECT}: {worst:.4%} (changed bbox {bbox}) "
                 f"({'ok' if worst == 0 and bbox is not None else 'FAIL'})")
    gates.append(f"chain drag history-free: chain 1 -> 0 vs never pulled (rect), max diff {back_diff}/255 "
                 f"({'ok' if back_diff <= 2 else 'FAIL'})")
    # ---- the moon
    moon_box = (int(MOON[0] - 50), int(MOON[1] - 46), int(MOON[0] + 50), int(MOON[1] + 46))
    moon_cells = [im(rest, "-1 (drawn)", (150, 138), moon_box)]
    for ph in (0.0, 0.25, 0.5, 0.75):
        moon_cells.append(im(render(f"--data=moonPhase={ph}", "--advance=1"), f"{ph:.2f}", (150, 138), moon_box))
    grid(moon_cells, 5).save(out / "moon_phases.png")
    # ---- one contact sheet
    w = 270 * 4
    top = grid(cells, 4)
    moons = grid(moon_cells, 5).resize((w, int(138 * w / (150 * 5))))
    drags = grid(drag_cells, 3)
    drags = drags.resize((int(drags.width * 400 / drags.height), 400))
    sts = grid(st_cells, 3).resize((w, int(420 * w / 1080)))
    sheet = Image.new("RGB", (w, top.height + sts.height + moons.height + drags.height), (20, 20, 20))
    yy = 0
    for part in (top, sts, moons, drags):
        sheet.paste(part, (0, yy))
        yy += part.height
    sheet.save(out / "contact_sheet.png")


REVIEW: dict[str, object] = {
    "diorama": {
        "patches": [("Plane5 armrest pad", (920, 1500, 1030, 1600), 40), ("Plane4 bench seat", (130, 1070, 230, 1180), 28),
                    ("Plane3 suitcase", (230, 160, 460, 250), 20), ("Plane2 transom latch", (500, 520, 580, 560), 12),
                    ("Plane0 moon", (696, 566, 744, 614), 0)],
        # glass sheets 30 / 60 / 360 frames, every landscape loop: all back at frame 0 after LOOP_LCM
        "rain_loops": [("Glass streaks + beads (with the landscape)", LOOP_LCM)],
        "seam_box": tuple(int(v) for v in GLASS),
    },
    "extras": review_extras,
    "time": {"sky_box": (250, 460, 830, 530), "dusk_box": (250, 560, 830, 700), "noon_gain": 12.0},
    "npc": {"crop": (180, 110, -22), "seam": {"idle": LOOP_LCM, "move": LOOP_LCM, "notice": LOOP_LCM, "react": LOOP_LCM},
            "prop": "ladybug", "waypoints": LADYBUG_WAYPOINTS, "fog_box": tuple(int(v) for v in OPEN)},
}


if __name__ == "__main__":
    print("wrote", trainCompartment())
