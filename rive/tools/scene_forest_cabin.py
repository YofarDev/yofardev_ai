"""Moonshot M11 (contract v14, rulings 1, 2, 7, 8, 9): the `forestCabin` scene, a log cabin's porch at the
forest's edge, seen from the yard. The seasons' showcase.

    uv run rive/tools/gen_scenes.py forestCabin      # -> rive/scenes/forestCabin/forestCabin.rml

Storybook night by default (the lantern's warm key from the right, the open sky's blue rim, forest-green
shadows). Layout (1080 x 1920; the avatar stands at x 330..750 from y ~700 down, so the props sit right on
the porch and left in the yard; phones crop x < ~97 and x > ~983):

- Plane0, the sky: the night gradient (`daylight` / `dusk` through `gen_scenes.sky_time`), stars (a few
  twinkle), the moon (`moonPhase`: the drawn moon at -1, `world_kit.moon_rig` at 0..1), the far ridge;
  the overcast at `rain`.
- Plane1, the forest wall: two rows of pines, two birches, a drifting mist; the fog bank (`fog`).
- Plane2, the big maple (left; its crown sways in the `gust`; green at the defaults, pink-white blossom at
  `spring`, red-gold at `autumn`) with the low branch the squirrel climbs to, the cabin's main roof and
  its chimney (a slow smoke), the forest floor.
- Plane3, the cabin: the log wall with a lit window and the door (a wreath at `festive`), the porch roof
  (string lights along its fascia at `festive`), the posts, the rail with the **pinwheel** on its stick
  (prop `pinwheel`; the `pinwheel` spin drag turns its blades 2 pi x `pinwheel`, history-free; the `gust`
  spins a wrapper above it), the **lantern** on its bracket (prop `lantern`; the warm key: its glow and
  the pool on the wall loop a 0.2 flicker; event `lanternFlicker`), the deck and the steps (leaves at
  `autumn`), and the **squirrel** (NPC, prop `squirrel`).
- Plane4, the yard: the grass, the path to the step (flowers at `spring`), the **woodpile** (prop
  `woodpile`), a pumpkin by the step and fallen leaves (`autumn`), the wet film (`rain`), the `fireflies`.
- Plane5, the foreground: ferns in both corners (they sway in the `gust`), grass, a few fallen leaves.
- Screen overlays: the steady rain (`rain`), the `rain` event's shower, the gust's flying leaves, the
  autumn leaf drift and the spring petal drift, the day lift (a screen veil at `daylight`).
- `SceneFront` (contract v9 / v14): the near rain sheet, splashes, the rain mist (`gen_scenes.front_weather`).

The squirrel (`npc`, contract v14, ruling 7): rest = sits on the rail, tail curled (breathing, a blink);
idle = nibbles an acorn, tail flicks; move = scampers (a gallop in profile, facing left while `npcLook`
<= 0, right while > 0); notice = sits up tall, its head toward the avatar (`npcLook` -1 / 0 / +1); react =
a startled hop with its tail puffed. `npcX` 0 = the rail spot, 1 = on the maple's low branch, partly up the
trunk (`SQ_WAYPOINTS`: along the rail, a jump down, across the yard behind the avatar, up the trunk). Its
poke zone `Hit_squirrel` follows `npcX`.

Built through gen_scenes.Scene (without the M4 refine pass, like the M9 modules); this scene is its own
document: the main art mints from the scene's main doc, the rain binds from `d5`, the v12 art (moon,
December, the drag) from `d9`, the squirrel from `d8`, the v14 seasons from `d11`.
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
from gen_scenes import DIORAMAS, TIME_SKY, DioramaSpec, Scene, H, W, front_weather, uniq  # noqa: E402
from art_bible import fit_colour  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, lin, rad, smooth_path  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds, pw_tokens  # noqa: E402
import world_kit  # noqa: E402

SCENE_ID = "forestCabin"
O = (0.0, 0.0)
Z = (0.0, 0.0)
INK = "FF2A2024"
TAU = 2 * math.pi

# ---------------------------------------------------------------- layout (artboard px)
MOON = (640.0, 210.0, 40.0)                 # centre, radius
HORIZON = 700.0                             # the sky veils' horizon (the dusk band peaks just above the forest)
GROUND_Y = 1252.0                           # the yard's top edge (Plane4)
WALL = (520.0, 572.0, 1180.0, 1150.0)       # the cabin's log wall (Plane3)
WINDOW = (590.0, 680.0, 740.0, 840.0)       # the lit window's frame (left of the lantern post)
DOOR = (840.0, 740.0, 960.0, 1150.0)        # the door
POSTS = (528.0, 780.0, 1111.0)              # porch post centres (corner, by the lantern, right)
POST_W = 26.0
FASCIA = (638.0, 664.0)
RAIL_TOP = 1060.0                           # the top rail's top: the squirrel sits on it
DECK = (1140.0, 1158.0, 1214.0)             # deck top, deck front face top, bottom
STEPS = ((584.0, 1206.0, 776.0, 1232.0), (576.0, 1230.0, 784.0, 1258.0))
LANTERN_HOOK = (822.0, 756.0)
LANTERN_C = (822.0, 816.0)                  # the lantern's glass centre
WREATH = (900.0, 868.0, 28.0)
PINWHEEL_HUB = (935.0, 960.0)
PINWHEEL_R = 46.0
TRUNK_BASE = (175.0, 1250.0)
CROWN_PIVOT = (190.0, 790.0)
BRANCH_SEAT = (262.0, 1108.0)               # the squirrel's seat on the maple's low branch (npcX 1)
WOODPILE = (36.0, 1290.0, 304.0, 1452.0)
PUMPKIN = (826.0, 1268.0)
RAIN_COL = "88B4C4D8"

# ---------------------------------------------------------------- the pinwheel (drag `pinwheel`, spin)
# the handle (contract v14 drag table): the blades at every turn (hub +- radius, a finger's pad) and the
# stick down to the rail, at parallax 0, in Plane3
PINWHEEL_PAD = 6.0
PINWHEEL_RECT = (float(math.floor(PINWHEEL_HUB[0] - PINWHEEL_R - PINWHEEL_PAD)),
                 float(math.floor(PINWHEEL_HUB[1] - PINWHEEL_R - PINWHEEL_PAD)),
                 float(math.ceil(PINWHEEL_HUB[0] + PINWHEEL_R + PINWHEEL_PAD)),
                 float(RAIL_TOP + 8.0))
PINWHEEL_PLANE = 3
PINWHEEL_COLOURS = ("FFE8705E", "FFF2C650", "FF62A4DA", "FF86C872")   # four colours: a half turn reads
GUST_SPIN = 4 * math.pi        # the gust's extra spin (whole turns: it snaps back to 0 unseen)

# ---------------------------------------------------------------- the squirrel (npc)
# (feet x, y, scale) along its path: the rail spot (0) -> the rail's end by the lantern post -> mid-jump ->
# the ground in front of the steps -> across the yard (behind the avatar) -> the maple's foot -> up the
# trunk -> its low branch (1)
SQ_WAYPOINTS = [(850.0, RAIL_TOP, 1.0), (804.0, RAIL_TOP, 1.0), (790.0, 1150.0, 1.0), (786.0, 1244.0, 1.0),
                (560.0, 1246.0, 0.97), (330.0, 1248.0, 0.94), (222.0, 1248.0, 0.92), (212.0, 1176.0, 0.9),
                (BRANCH_SEAT[0], BRANCH_SEAT[1], 0.9)]
# its rotation there (rad; + = nose up when facing left): level, nose down mid-jump, nose up on the trunk
SQ_ROTATIONS = [0.0, 0.0, -0.9, 0.0, 0.0, 0.0, 0.0, 1.35, 0.0]
SQ_DEPTH = (4, 6)              # between these waypoints it steps from the porch (Plane3) onto the maple's (Plane2)
SQ_SCALE = 1.3                 # the rig is drawn ~70 px tall sitting
SQ_STRIDE = 54.0               # rig px a gallop cycle covers (the run pose's bound)
SQ_REST, SQ_IDLE, SQ_RUN, SQ_NOTICE, SQ_REACT = 240, 240, 24, 120, 60
SQ_HIT = (0.0, -44.0, 100.0, 96.0)   # the poke zone: (dx, dy) from the feet, width, height
SQ_REACT_MS = SQ_REACT * 1000 // 60

# ---------------------------------------------------------------- loops and events (frames at 60 fps)
FLICKER_FRAMES = 120
LANTERN_FLICKER = [(0, 1.0), (14, 0.86), (26, 0.97), (40, 0.8), (58, 1.0), (72, 0.84), (88, 0.95), (104, 0.82),
                   (120, 1.0)]
STARS_LOOP = 240
SMOKE_LOOP = 240
MIST_LOOP = 480
DRIFT_LOOP = 600
RAIN_LOOP_FRAMES = 120          # splash loops; the streak sheets loop on 18 / 34 frames (seam: 6120)
EVENT_FRAMES = {"gust": 180, "fireflies": 360, "rain": 420, "lanternFlicker": 90}
EVENT_PEAKS = {"gust": 70, "fireflies": 200, "rain": 200, "lanternFlicker": 22}
WET = ("FF0A120E", 0.36)        # the yard's wet film and its opacity at rain 1
OVERCAST = ("FF3A4656", 0.4)    # the sky clouds over at rain 1
DAY_LIFT = "FF242A30"           # a screen veil over the whole scene at daylight 1 (the yard is not a night yard by day)

# ---------------------------------------------------------------- what this file binds
BINDS: set[str] = {"moonPhase", "festive", *world_kit.drag_numbers(SCENE_ID)}   # v12
BINDS14: set[str] = {"spring", "autumn"}                                          # v14 (the tier: lane W)
# M11 ruling 13: element roots (without the diorama's `emit` prefix) the shared tier pass hides.
# "high": hidden at high and low (the second rain sheet, splashes, the second half of particle / twinkle
# copies); "low": hidden at low only (decorative ambient loops that are not light).
TIER_GATES: dict[str, tuple[str, ...]] = {
    "high": ("RainSheetFar", "ShowerSheetFar", "Splash", "FireflyB", "GustLeafB", "StarTwinkleB", "LeafDriftC", "PetalDriftC"),
    "low": ("ChimneySmoke", "MistDrift", "LeafDriftB", "PetalDriftB"),
}


# ====================================================================== helpers
class _CabinScene(Scene):
    """`gen_scenes.Scene` without the M4 art pass (`scene_art.refine_scene` knows the four M8 scenes only)."""

    def write(self, content: list[El], hits: list[El]) -> str:
        saved = gen_scenes.refine_scene
        gen_scenes.refine_scene = lambda sc, c: None
        try:
            return super().write(content, hits)
        finally:
            gen_scenes.refine_scene = saved


def conv(sc: Scene, doc: Doc, k: float, c: float = 0.0, lo: float | None = None, hi: float | None = None) -> El:
    """A private `c + k x input` converter minted from `doc` (clamped to [lo, hi] when given)."""
    f = Formulas(doc, sc.vpath)
    toks = ([f.val(c), f.op("+")] if c else []) + [f.val(k), f.op("*"), *f.inp()]
    if lo is not None:
        toks = f.fn("max", [f.val(lo)], toks)
    if hi is not None:
        toks = f.fn("min", [f.val(hi)], toks)
    out = doc("DataConverterFormula", *toks)
    sc.roots.append(out)
    return out


def bind(sc: Scene, doc: Doc, prop: str, key: int, cv: El | None = None) -> El:
    return doc("DataBindContext", sourcePathIds=sc.vpath(prop), propertyKey=key,
               converterId=cv.ref() if cv is not None else None)


def rect(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, paint: El | None, r: float = 0.0,
         **kw: object) -> El:
    d = sc.d
    return d("Shape", d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), cornerRadiusTL=float(r),
                        cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
             paint, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), name=name, **kw)


def vfill(sc: Scene, y0: float, y1: float, cy: float, stops: list[tuple[str, float]]) -> El:
    """A vertical gradient spanning artboard y0..y1 in a shape whose origin is at artboard y `cy`."""
    return sc.vgrad(y0 - cy, y1 - cy, stops)


def rects(sc: Scene, name: str, rs: list[tuple[float, float, float, float]], *paints: El, r: float = 0.0,
          **kw: object) -> El:
    """One shape of many rectangles (artboard px), at the origin."""
    d = sc.d
    paths = [d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2),
               y=float((y0 + y1) / 2), cornerRadiusTL=float(r) or None, cornerRadiusTR=float(r) or None,
               cornerRadiusBL=float(r) or None, cornerRadiusBR=float(r) or None, name="Path")
             for x0, y0, x1, y1 in rs]
    return d("Shape", *paths, *paints, x=0.0, y=0.0, name=name, **kw)


def dots(sc: Scene, name: str, pts: list[tuple[float, float, float, float]], *paints: El, **kw: object) -> El:
    """One shape of many ellipses (cx, cy, w, h), at the origin."""
    d = sc.d
    paths = [d("Ellipse", width=float(w), height=float(h), x=float(x), y=float(y), name="Path") for x, y, w, h in pts]
    return d("Shape", *paths, *paints, x=0.0, y=0.0, name=name, **kw)


def polys(sc: Scene, name: str, ps: list[list[tuple]], *paints: El, closed: bool = True, tension: float = 1.0,
          **kw: object) -> El:
    """One shape of many smooth paths (artboard px, ("c") corners as smooth_path), at the origin."""
    return sc.d("Shape", *[smooth_path(sc.d, p, closed=closed, tension=tension) for p in ps], *paints,
                x=0.0, y=0.0, name=name, **kw)


def lines(sc: Scene, name: str, segs: list[tuple[float, float, float, float]], colour: str, w: float,
          **kw: object) -> El:
    d = sc.d
    paths = [d("PointsPath", d("StraightVertex", x=float(x0), y=float(y0)), d("StraightVertex", x=float(x1), y=float(y1)),
               isClosed=False, name="Path") for x0, y0, x1, y1 in segs]
    return d("Shape", *paths, sc.L(colour, w), x=0.0, y=0.0, name=name, **kw)


def pivot(sc: Scene, name: str, x: float, y: float, kids: list[El], **kw: object) -> El:
    """A node `name` at (x, y) holding `name`Pivot at (-x, -y) -> kids: a transform handle at (x, y) that
    leaves the kids' artboard coordinates untouched (its rotation pivots there)."""
    inner = sc.d("Node", *kids, x=float(-x), y=float(-y), name=name + "Pivot")
    return sc.d("Node", inner, x=float(x), y=float(y), name=name, **kw)


def leaf_pts(cx: float, cy: float, ln: float, wd: float, ang: float) -> list[tuple]:
    """A leaf (tip, side, stem, side) centred at (cx, cy), `ln` long, `wd` wide, pointing at `ang`."""
    c, s = math.cos(ang), math.sin(ang)

    def at(u: float, v: float) -> tuple[float, float]:
        return (round(cx + u * c - v * s, 2), round(cy + u * s + v * c, 2))
    return [(*at(ln / 2, 0), "c"), at(0, wd / 2), (*at(-ln / 2, 0), "c"), at(0, -wd / 2)]


def maple_leaf_pts(cx: float, cy: float, r: float, ang: float) -> list[tuple]:
    """A small five-lobed maple leaf of radius `r` centred at (cx, cy), turned by `ang`."""
    pts = []
    for i in range(10):
        a = ang - math.pi / 2 + math.pi * i / 5
        rr = r if i % 2 == 0 else r * 0.48
        pts.append((round(cx + rr * math.cos(a), 2), round(cy + rr * math.sin(a), 2), "c"))
    return pts


def wrap_keys(period: int, off: int, step: int, fn: Callable[[float], dict[str, float]]) -> dict[str, list]:
    """Seamless keys of a particle that loops over `period` frames starting `off` frames in: `fn(t)` gives
    its properties at loop time t (0..1); the wrap (t 1 -> 0) is a hold, never a sweep back."""
    w = period - off
    frames = sorted({*range(0, period + 1, step), period, *(f for f in (w - 1, w) if 0 <= f <= period)})
    out: dict[str, list] = {}
    for fr in frames:
        t = ((fr + off) % period) / period
        mode = "hold" if fr == w - 1 else "linear"
        for p, v in fn(t).items():
            out.setdefault(p, []).append((fr, round(v, 3), mode))
    return out


def mix(a: str, b: str, t: float) -> str:
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4, 6)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4, 6)]
    return "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ca, cb))


SKY_STOPS = [("FF0E1830", 0.0), ("FF182644", 0.5), ("FF2C3C5E", 1.0)]   # artboard y 0 .. 900


def sky_at(y: float) -> str:
    t = min(1.0, max(0.0, y / 900.0))
    for (c0, p0), (c1, p1) in zip(SKY_STOPS, SKY_STOPS[1:]):
        if t <= p1:
            return mix(c0, c1, (t - p0) / (p1 - p0))
    return SKY_STOPS[-1][0]


# ====================================================================== the scene
def forestCabin() -> str:  # noqa: N802 (scene ids are contract names)
    sc = _CabinScene(SCENE_ID)
    d, E, F, L, S = sc.d, sc.E, sc.F, sc.L, sc.S
    d9, d11 = sc.d9, sc.d11
    rnd = random.Random(1411)

    # ------------------------------------------------------------ Plane0: the sky
    sky = rect(sc, "Sky", -80, -80, W + 80, 1400, vfill(sc, 0, 900, 660, SKY_STOPS))
    mx, my, mr = MOON
    star_pts = []
    while len(star_pts) < 46:
        x, y = rnd.uniform(-20, W + 20), rnd.uniform(24, 660)
        if math.hypot(x - mx, y - my) < mr + 40:
            continue
        s = rnd.choice((2.2, 2.6, 3.0, 3.6))
        star_pts.append((round(x, 1), round(y, 1), s, s))
    stars = dots(sc, "Stars", star_pts, F("D8F4F0E0"))
    tw_nodes, tw_tracks = [], []
    tw_at = [(470, 120), (840, 90), (980, 520), (330, 60), (760, 330), (60, 90), (520, 420), (900, 250)]
    for i, (x, y) in enumerate(tw_at):
        half = "A" if i < 4 else "B"
        st = d("Node", S((x, y), "H", [(x - 9, y), (x + 9, y)], L("D0FFF6E0", 1.8), closed=False),
               S((x, y), "V", [(x, y - 9), (x, y + 9)], L("D0FFF6E0", 1.8), closed=False),
               E((x, y), "Core", x, y, 4.4, 4.4, F("FFFFF8E8")),
               x=float(x), y=float(y), name=f"StarTwinkle{half}{i % 4}")
        tw_nodes.append(st)
        a, b = 30 + 47 * i % 150, 80 + 47 * i % 150
        tw_tracks.append(sc.T(st, scaleX=[(0, 1.0), (a, 0.35), (b, 1.0), (STARS_LOOP, 1.0)],
                              scaleY=[(0, 1.0), (a, 0.35), (b, 1.0), (STARS_LOOP, 1.0)]))
    sc.ambient("Stars", sc.A("amb_stars", STARS_LOOP, tw_tracks, loop=True, seam_hold=True))
    moon_glow = E(O, "MoonGlow", mx, my, mr * 7, mr * 7, sc.rgrad(mr * 3.5, [("44FFF2D8", 0.0), ("00FFF2D8", 1.0)]))
    craters = ((-12, 8, 13), (10, -12, 9), (14, 12, 7), (-6, -16, 6))

    def moon_parts(parent: tuple[float, float], tag: str) -> list[El]:
        return [*[E(parent, f"{tag}Crater{i}", mx + dx, my + dy, r_, r_, F("2C9C9080")) for i, (dx, dy, r_) in
                  enumerate(craters)],
                E(parent, f"{tag}Disc", mx, my, 2 * mr, 2 * mr,
                  sc.rgrad(mr * 1.2, [("FFFFF8E8", 0.0), ("FFEADFC6", 1.0)], cx=-mr * 0.3, cy=-mr * 0.3))]
    moon_drawn = world_kit.hide_when_phased(sc, d9, "MoonDrawn", [*moon_parts(O, "Moon"), moon_glow])
    with sc.minting(d9):
        lit = d9("Node", *moon_parts((mx, my), "MoonLit"), x=0.0, y=0.0, name="MoonLit")
    moon_rig = world_kit.moon_rig(sc, d9, mx, my, mr, lit, "E6" + fit_colour(sky_at(my), SCENE_ID)[2:])
    ridge_pts: list[tuple] = [(-80, 1400, "c"), (-80, 800)]
    for i, x in enumerate(range(40, W + 120, 140)):
        ridge_pts.append((x, 780 + 40 * math.sin(i * 1.3) + rnd.uniform(-10, 10)))
    ridge_pts += [(W + 80, 800), (W + 80, 1400, "c")]
    far_ridge = S(O, "FarRidge", ridge_pts, vfill(sc, 740, 1000, 1070, [("FF243450", 0.0), ("FF1A2638", 1.0)]),
                  tension=0.7, origin=(W / 2, 1070.0))
    with sc.minting(sc.d5):
        overcast = rect(sc, "SkyOvercast", -80, -80, W + 80, 1400, F(OVERCAST[0]), opacity=0.0)
        overcast.children.insert(0, bind(sc, sc.d5, "rain", 18, conv(sc, sc.d5, OVERCAST[1])))
    plane0 = [overcast, moon_rig, moon_drawn, far_ridge, *tw_nodes[4:], *tw_nodes[:4], stars, sky]

    # ------------------------------------------------------------ Plane1: the forest wall
    def tree_row(name: str, y_tip: tuple[float, float], step: float, drop: float, seed: int,
                 stops: list[tuple[str, float]]) -> El:
        r = random.Random(seed)
        pts: list[tuple] = [(-80, 1320, "c")]
        x = -100.0
        while x < W + 120:
            tip = r.uniform(*y_tip)
            pts += [(x - step * 0.42, tip + drop, "c"), (x - step * 0.2, tip + drop * 0.45, "c"),
                    (x - step * 0.3, tip + drop * 0.5, "c"), (x, tip, "c"), (x + step * 0.3, tip + drop * 0.5, "c"),
                    (x + step * 0.2, tip + drop * 0.45, "c")]
            x += step * r.uniform(0.85, 1.15)
        pts += [(x - step * 0.42, y_tip[1] + drop, "c"), (W + 120, 1320, "c")]
        top = min(p[1] for p in pts)
        return S(O, name, pts, vfill(sc, top, 1320, (top + 1320) / 2, stops))

    forest_far = tree_row("ForestFar", (585, 660), 46, 96, 7, [("FF1E3438", 0.0), ("FF16262A", 0.6), ("FF132022", 1.0)])
    forest_near = tree_row("ForestNear", (690, 760), 60, 120, 11, [("FF17282A", 0.0), ("FF101C1C", 1.0)])
    birches = []
    for i, (x, w_, top) in enumerate(((462.0, 15.0, 700.0), (500.0, 11.0, 752.0))):
        marks = [(x - w_ / 2 + 1, y_, x + w_ * (0.1 if k % 2 else -0.05), y_ + 2)
                 for k, y_ in enumerate(range(int(top) + 30, 1130, 46))]
        birches.append(d("Node", lines(sc, "BirchMarks", marks, "C0262224", 3),
                         rect(sc, "BirchTrunk", x - w_ / 2, top, x + w_ / 2, 1150, sc.d("Fill", lin(
                             sc.d, -w_ / 2, 0, w_ / 2, 0, [("FFD8D2C4", 0.0), ("FFA8A498", 1.0)]), name="Fill"),
                              r=w_ / 2),
                         x=0.0, y=0.0, name=f"Birch{i}"))
    mist_kids = [E(O, f"MistPuff{k}", x, 1080 + 16 * (k % 2), 640, 110,
                   sc.rgrad(320, [("38C8D4C4", 0.0), ("00C8D4C4", 1.0)]), scaleY=1.0)
                 for k, x in enumerate((140.0, 560.0, 980.0))]
    mist = d("Node", *mist_kids, x=0.0, y=0.0, name="MistDrift")
    sc.ambient("MistDrift", sc.A("amb_MistDrift", MIST_LOOP, [sc.T(mist, x=[(0, -30.0), (MIST_LOOP // 2, 30.0),
                                                                             (MIST_LOOP, -30.0)])],
                                 loop=True, seam_hold=True))
    mist.attrs["x"] = -30.0
    forest_mist = d("Node", mist, x=0.0, y=0.0, name="ForestMist")
    plane1 = [forest_mist, *birches, forest_near, forest_far]

    # ------------------------------------------------------------ Plane2: maple, roof, chimney, forest floor
    floor_pts: list[tuple] = [(-80, 1600, "c"), (-80, 1118)]
    for i, x in enumerate(range(0, W + 81, 90)):
        floor_pts.append((x, 1112 + 8 * math.sin(i * 1.7)))
    floor_pts.append((W + 80, 1600, "c"))
    forest_floor = S(O, "ForestFloor", floor_pts, vfill(sc, 1100, 1600, 1350, [("FF2A3C24", 0.0), ("FF1E2C1A", 1.0)]),
                     origin=(W / 2, 1350.0))
    roof_poly = [(498, 606, "c"), (588, 372, "c"), (W + 90, 372, "c"), (W + 90, 606, "c")]
    roof = d("Node",
             lines(sc, "Shingles", [(498 + (606 - y) * 90 / 234 + 4, y, W + 90, y) for y in range(398, 600, 26)],
                   "60140A10", 3),
             rect(sc, "RidgeCap", 584, 362, W + 90, 378, F("FF2C2228"), r=4),
             S(O, "RoofSlope", roof_poly, vfill(sc, 372, 606, 489, [("FF4A3A42", 0.0), ("FF2E2430", 1.0)])),
             x=0.0, y=0.0, name="CabinRoof")
    chimney = d("Node",
                rect(sc, "ChimneyCap", 978, 282, 1048, 298, F("FF4A423E"), r=3),
                lines(sc, "ChimneyMortar", [(986, y, 1040, y) for y in (312, 332, 352)] +
                      [(1004 + 14 * (k % 2), y, 1004 + 14 * (k % 2), y + 20) for k, y in enumerate((298, 312, 332, 352))],
                      "50201814", 2),
                rect(sc, "ChimneyStack", 986, 296, 1040, 384, sc.d("Fill", lin(sc.d, -27, 0, 27, 0, [
                    ("FF7A6E64", 0.0), ("FF5A5048", 1.0)]), name="Fill")),
                x=0.0, y=0.0, name="Chimney")
    puffs, puff_tracks = [], []
    for k in range(3):
        p = E(O, f"SmokePuff{k}", 1013, 276, 44, 44, sc.rgrad(22, [("44B8BCC4", 0.0), ("00B8BCC4", 1.0)]), opacity=0.0)
        puffs.append(p)

        def at(t: float, k: int = k) -> dict[str, float]:
            return {"x": 1013 + 30 * t + 8 * math.sin(t * 6 + k), "y": 276 - 150 * t, "scaleX": 0.7 + 1.5 * t,
                    "scaleY": 0.7 + 1.5 * t, "opacity": math.sin(math.pi * t) ** 1.3 * 0.9}
        puff_tracks.append(sc.T(p, ease=None, **wrap_keys(SMOKE_LOOP, k * SMOKE_LOOP // 3, 20, at)))
    sc.ambient("ChimneySmoke", sc.A("amb_ChimneySmoke", SMOKE_LOOP, puff_tracks, loop=True))
    smoke = d("Node", *puffs, x=0.0, y=0.0, name="ChimneySmoke")

    maple, crown = _maple(sc)
    plane2 = [maple, smoke, chimney, roof, forest_floor]

    # ------------------------------------------------------------ Plane3: the cabin
    wx0, wy0, wx1, wy1 = WALL
    log_h = 38.0
    rows = [wy0 + log_h * k for k in range(int((wy1 - wy0) // log_h) + 1)]
    log_wall = d("Node",
                 dots(sc, "LogEndRings", [(wx0 + 18, y + log_h / 2, 18, 16) for y in rows[:-1]], L("FF6E4A30", 2)),
                 dots(sc, "LogEnds", [(wx0 + 18, y + log_h / 2, 36, 34) for y in rows[:-1]], F("FFB4865C"),
                      L("FF4A2E1C", 2.4)),
                 lines(sc, "LogHi", [(wx0 + 30, y + 7, wx1, y + 7) for y in rows[:-1]], "38E8B888", 2.5),
                 lines(sc, "LogSeams", [(wx0 + 30, y, wx1, y) for y in rows[1:]], "B0281810", 3.5),
                 rect(sc, "LogBase", wx0 + 12, wy0, wx1, wy1, vfill(sc, wy0, wy1, (wy0 + wy1) / 2,
                                                                      [("FF6E4A30", 0.0), ("FF7E5638", 0.5),
                                                                       ("FF5A3A26", 1.0)])),
                 x=0.0, y=0.0, name="LogWall")
    # the lit window (left of the lantern post)
    fx0, fy0, fx1, fy1 = WINDOW
    gx0, gy0, gx1, gy1 = fx0 + 12, fy0 + 12, fx1 - 12, fy1 - 12
    win_mid = ((gx0 + gx1) / 2, (gy0 + gy1) / 2)
    window = d("Node",
               rect(sc, "WindowSill", fx0 - 10, fy1 - 4, fx1 + 10, fy1 + 10, F("FF8A6444"), r=3),
               rects(sc, "WindowMullion", [(win_mid[0] - 4, gy0, win_mid[0] + 4, gy1),
                                           (gx0, win_mid[1] - 4, gx1, win_mid[1] + 4)], F("FF4A3020")),
               polys(sc, "WindowCurtain", [[(gx0, gy0, "c"), (gx0 + 34, gy0, "c"), (gx0 + 12, gy1 - 30), (gx0, gy1, "c")],
                                           [(gx1, gy0, "c"), (gx1 - 34, gy0, "c"), (gx1 - 12, gy1 - 30), (gx1, gy1, "c")]],
                     F("D8B4604E")),
               rect(sc, "WindowLit", gx0, gy0, gx1, gy1, vfill(sc, gy0, gy1, win_mid[1], [("FFFFE6AE", 0.0),
                                                                                         ("FFF4AE5E", 1.0)])),
               d("Shape", d("Rectangle", width=fx1 - fx0, height=fy1 - fy0, name="Path"),
                 d("Rectangle", width=gx1 - gx0, height=gy1 - gy0, name="Opening"),
                 d("Fill", d("SolidColor", colorValue="FF4E3422"), fillRule="evenOdd", name="Fill"),
                 x=(fx0 + fx1) / 2, y=(fy0 + fy1) / 2, name="WindowFrame"),
               x=0.0, y=0.0, name="Window")
    window_glow = E(O, "WindowGlow", win_mid[0], win_mid[1], 340, 320,
                    sc.rgrad(170, [("4CFFC870", 0.0), ("00FFC870", 1.0)]))
    # the door
    dx0, dy0, dx1, dy1 = DOOR
    door = d("Node",
             E(O, "DoorKnob", dx1 - 14, 990, 12, 12, F("FFD8B060"), L("FF3A2A14", 1.6)),
             lines(sc, "DoorBrace", [(dx0 + 10, 1110, dx1 - 10, 900), (dx0 + 10, 900, dx1 - 10, 900),
                                     (dx0 + 10, 1110, dx1 - 10, 1110)], "FF4A2E1C", 7),
             lines(sc, "DoorSeams", [(x, dy0 + 70, x, dy1 - 4) for x in (dx0 + 30, dx0 + 60, dx0 + 90)], "80281810", 2.5),
             d("Shape", d("Rectangle", width=74.0, height=46.0, cornerRadiusTL=30.0, cornerRadiusTR=30.0,
                          name="Path"),
               vfill(sc, 760, 806, 783, [("FFFFE4A8", 0.0), ("FFF2A65A", 1.0)]), x=(dx0 + dx1) / 2, y=783.0,
               name="DoorPane"),
             rect(sc, "DoorPanel", dx0, dy0, dx1, dy1, vfill(sc, dy0, dy1, (dy0 + dy1) / 2,
                                                            [("FF744C30", 0.0), ("FF4E321E", 1.0)]), r=6),
             rect(sc, "DoorFrame", dx0 - 12, dy0 - 12, dx1 + 12, dy1, F("FF5A3C26"), r=4),
             x=0.0, y=0.0, name="Door")
    # the wreath (December), its own minting
    with sc.minting(d9):
        wcx, wcy, wr = WREATH
        blobs = [(wcx + wr * math.cos(TAU * i / 14), wcy + wr * math.sin(TAU * i / 14), 22, 18) for i in range(14)]
        berries = [(wcx + (wr + 2) * math.cos(TAU * i / 5 + 0.4), wcy + (wr + 2) * math.sin(TAU * i / 5 + 0.4), 7, 7)
                   for i in range(5)]
        wreath = d9("Node", bind(sc, d9, "festive", 18, conv(sc, d9, 1.0, lo=0.0, hi=1.0)),
                    S(O, "WreathBow", [(wcx - 16, wcy + wr + 2), (wcx, wcy + wr + 8, "c"), (wcx + 16, wcy + wr + 2),
                                       (wcx + 18, wcy + wr + 16), (wcx, wcy + wr + 10, "c"), (wcx - 18, wcy + wr + 16)],
                      F("FFC0404A"), L(INK, 1.6)),
                    dots(sc, "WreathBerries", berries, F("FFD8444C")),
                    dots(sc, "WreathPine", blobs, F("FF3E7A4C"), L("FF1E3A26", 1.6)),
                    x=0.0, y=0.0, opacity=0.0, name="Wreath")
    # the porch: roof, posts, rail, deck, steps
    porch_roof = d("Node",
                   rect(sc, "FasciaShade", 470, FASCIA[1], W + 90, FASCIA[1] + 30,
                        vfill(sc, FASCIA[1], FASCIA[1] + 30, FASCIA[1] + 15, [("70100808", 0.0), ("00100808", 1.0)])),
                   rect(sc, "Fascia", 466, FASCIA[0], W + 90, FASCIA[1], vfill(sc, FASCIA[0], FASCIA[1], sum(FASCIA) / 2,
                                                                              [("FF8A6444", 0.0), ("FF5E4230", 1.0)]),
                        r=3),
                   lines(sc, "PorchShingles", [(476 + 6 * k, y, W + 90, y) for k, y in enumerate((578, 598, 618))],
                         "60140A10", 2.5),
                   S(O, "PorchRoofSlope", [(486, 560, "c"), (W + 90, 560, "c"), (W + 90, FASCIA[0] + 2, "c"),
                                           (466, FASCIA[0] + 2, "c")],
                     vfill(sc, 560, FASCIA[0], (560 + FASCIA[0]) / 2, [("FF54443E", 0.0), ("FF3C302E", 1.0)])),
                   x=0.0, y=0.0, name="PorchRoof")
    post_rs = [(x - POST_W / 2, FASCIA[1], x + POST_W / 2, DECK[2]) for x in POSTS]
    braces = [[(x + POST_W / 2, FASCIA[1], "c"), (x + POST_W / 2 + 36, FASCIA[1], "c"), (x + POST_W / 2, FASCIA[1] + 36, "c")]
              for x in POSTS[:2]] + \
             [[(x - POST_W / 2, FASCIA[1], "c"), (x - POST_W / 2 - 36, FASCIA[1], "c"), (x - POST_W / 2, FASCIA[1] + 36, "c")]
              for x in POSTS[1:]]
    posts = d("Node",
              polys(sc, "PostBraces", braces, F("FF6A4A30")),
              lines(sc, "PostHi", [(x - POST_W / 2 + 4, FASCIA[1] + 4, x - POST_W / 2 + 4, DECK[2] - 4) for x in POSTS],
                    "40F0C890", 2.5),
              rects(sc, "PostWood", post_rs, d("Fill", lin(d, 0, FASCIA[1], 0, DECK[2], [("FF8E6444", 0.0),
                                                                                        ("FF664430", 1.0)]),
                                                name="Fill"), r=3),
              x=0.0, y=0.0, name="Posts")
    rx0, rx1 = POSTS[1] + POST_W / 2, POSTS[2] - POST_W / 2
    rail = d("Node",
             rect(sc, "RailTop", rx0, RAIL_TOP, rx1, RAIL_TOP + 12, vfill(sc, RAIL_TOP, RAIL_TOP + 12, RAIL_TOP + 6,
                                                                         [("FFA27850", 0.0), ("FF7A5434", 1.0)]), r=3),
             rect(sc, "RailLow", rx0, 1126, rx1, 1136, F("FF6E4C30")),
             rects(sc, "Balusters", [(x - 4, RAIL_TOP + 12, x + 4, 1126) for x in range(int(rx0) + 16, int(rx1) - 4, 28)],
                   F("FF7A5638")),
             x=0.0, y=0.0, name="Rail")
    deck = d("Node",
             lines(sc, "DeckBoards", [(x, DECK[0] + 2, x + 6, DECK[0] + 16) for x in range(520, W + 80, 64)],
                   "50281810", 2),
             rect(sc, "DeckTop", 490, DECK[0], W + 90, DECK[1], vfill(sc, DECK[0], DECK[1], sum(DECK[:2]) / 2,
                                                                     [("FFA07A52", 0.0), ("FF84603E", 1.0)])),
             x=0.0, y=0.0, name="Deck")
    deck_face = d("Node",
                  lines(sc, "DeckFaceBoards", [(490, y, W + 90, y) for y in (1176.0, 1196.0)], "60201008", 2.5),
                  rect(sc, "DeckFaceWood", 490, DECK[1], W + 90, DECK[2],
                       vfill(sc, DECK[1], DECK[2], (DECK[1] + DECK[2]) / 2, [("FF5E402A", 0.0), ("FF3E2A1C", 1.0)])),
                  x=0.0, y=0.0, name="DeckFace")
    steps = d("Node", *[d("Node",
                          rect(sc, f"TreadEdge{k}", x0, y0, x1, y0 + 6, F("FFB08A60"), r=2),
                          rect(sc, f"Tread{k}", x0, y0, x1, y1, vfill(sc, y0, y1, (y0 + y1) / 2,
                                                                     [("FF8E6A48", 0.0), ("FF5E4430", 1.0)]), r=3),
                          x=0.0, y=0.0, name=f"Step{k}")
                        for k, (x0, y0, x1, y1) in reversed(list(enumerate(STEPS)))],
              x=0.0, y=0.0, name="Steps")
    # the lantern (the warm key) on its bracket off the lantern post, and its light on the wall
    lantern, lantern_glow, lantern_swing, lantern_fx = _lantern(sc)
    key = gen_scenes.SCENES[SCENE_ID].key
    with sc.minting(d9):
        pool_grad = rad(d9, 0.0, 0.0, 330.0, [(key, 0.0), ("00" + key[2:], 1.0)])
        pool_grad.children[0].children.append(bind(sc, d9, "lightKey", 38))
        pool_grad.attrs["opacity"] = 0.5
        pool = d9("Shape", d9("Ellipse", width=660.0, height=660.0, name="Path"), d9("Fill", pool_grad, name="Fill"),
                  x=LANTERN_C[0], y=LANTERN_C[1] + 70, name="LanternPoolLight")
        pool_fx = d9("Node", pool, x=0.0, y=0.0, name="LanternPoolFx")
        lantern_pool = d9("Node", pool_fx, x=0.0, y=0.0, name="LanternPool")
    pinwheel, pinwheel_gust = _pinwheel(sc)
    # autumn leaves on the deck and the steps (contract v14 `autumn`)
    r_ = random.Random(77)
    with sc.minting(d11):
        porch_leaf_ps = [leaf_pts(r_.uniform(500, 1060), r_.uniform(DECK[0] + 2, DECK[1] + 2), 18, 10, r_.uniform(0, 3))
                         for _ in range(9)] + \
                        [leaf_pts(r_.uniform(x0 + 10, x1 - 10), y0 + 3, 16, 9, r_.uniform(0, 3)) for x0, y0, x1, _ in STEPS
                         for _ in range(2)]
        porch_leaves = d11("Node", bind(sc, d11, "autumn", 18),
                           polys(sc, "PorchLeafRed", porch_leaf_ps[::2], F("FFC04A2C")),
                           polys(sc, "PorchLeafGold", porch_leaf_ps[1::2], F("FFE0A040")),
                           x=0.0, y=0.0, opacity=0.0, name="PorchLeaves")
    # December: lights along the porch fascia
    swag = []
    hooks = [480.0, POSTS[0], 650.0, POSTS[1], 945.0, POSTS[2], W + 60.0]
    for a, b in zip(hooks, hooks[1:]):
        for t in (0.0, 0.25, 0.5, 0.75):
            swag.append((round(a + (b - a) * t, 1), round(FASCIA[1] + 2 + 18 * math.sin(math.pi * t), 1)))
    swag.append((hooks[-1], FASCIA[1] + 2))
    festive_lights = world_kit.festive_lights(sc, d9, [p for i, p in enumerate(swag) if i % 2 == 0],
                                              ("FFFFD27A", "FFFF7466"))
    plane3_front = [festive_lights, porch_leaves, steps, pinwheel, lantern, porch_roof, posts, rail, deck_face, deck,
                    wreath, door, window, window_glow, lantern_pool, log_wall]

    # ------------------------------------------------------------ Plane4: the yard
    yard_pts: list[tuple] = [(-80, H + 70, "c"), (-80, GROUND_Y + 4)]
    for i, x in enumerate(range(-20, W + 81, 60)):
        yard_pts.append((x, GROUND_Y + 2 + 5 * math.sin(i * 2.1)))
    yard_pts.append((W + 80, H + 70, "c"))
    yard = S(O, "Yard", yard_pts, vfill(sc, GROUND_Y, H + 70, (GROUND_Y + H + 70) / 2,
                                        [("FF34502E", 0.0), ("FF26402A", 0.4), ("FF1A2C1C", 1.0)]),
             origin=(W / 2, (GROUND_Y + H + 70) / 2))
    path_poly = [(592, GROUND_Y, "c"), (782, GROUND_Y, "c"), (842, 1420), (930, 1700), (1010, H + 70, "c"),
                 (330, H + 70, "c"), (410, 1700), (500, 1420)]
    path = S(O, "Path", path_poly, vfill(sc, GROUND_Y, H + 70, (GROUND_Y + H + 70) / 2,
                                         [("FF6E5E48", 0.0), ("FF5A4C3A", 0.5), ("FF463A2E", 1.0)]), tension=0.5,
             origin=(W / 2, (GROUND_Y + H + 70) / 2))
    stones = [(690, 1290, 70, 18), (640, 1340, 84, 22), (720, 1390, 96, 24), (600, 1460, 110, 28), (760, 1530, 120, 30),
              (640, 1620, 140, 34), (820, 1700, 150, 36), (560, 1780, 160, 40), (760, 1880, 180, 44)]
    path_stones = d("Node", dots(sc, "StoneHi", [(x - 6, y - 4, w * 0.6, h * 0.4) for x, y, w, h in stones],
                                 F("40E0D4C0")),
                    dots(sc, "Stones", stones, F("FF8A7E6A"), L("60302820", 2)), x=0.0, y=0.0, name="PathStones")
    gr = random.Random(23)
    tufts = []
    while len(tufts) < 34:
        x, y = gr.uniform(-20, W + 20), gr.uniform(GROUND_Y + 30, 1860)
        if 380 < x < 960 and y > GROUND_Y + 10 and (x - 540) ** 2 < ((y - 1000) * 0.55) ** 2 + 40000:
            continue   # off the path
        s_ = 0.7 + 0.9 * (y - GROUND_Y) / (H - GROUND_Y)
        tufts += [(x, y, x - 7 * s_, y - 16 * s_), (x, y, x + 2 * s_, y - 20 * s_), (x, y, x + 9 * s_, y - 14 * s_)]
    grass_tufts = lines(sc, "GrassTufts", tufts, "FF46663A", 2.6)
    yard_glow = E(O, "YardGlow", LANTERN_C[0] - 30, GROUND_Y + 50, 620, 200,
                  sc.rgrad(310, [("38FFC070", 0.0), ("00FFC070", 1.0)]))
    woodpile = _woodpile(sc)
    with sc.minting(sc.d5):
        wet = d("Node", bind(sc, sc.d5, "rain", 18),
                dots(sc, "Puddles", [(700, 1480, 220, 30), (520, 1700, 260, 34), (880, 1600, 160, 24),
                                     (180, 1640, 200, 28)], F("40B8C4D8")),
                E(O, "PuddleGlint", 760, 1340, 170, 26, sc.rgrad(85, [("50FFD8A0", 0.0), ("00FFD8A0", 1.0)])),
                rect(sc, "WetFilm", -80, GROUND_Y - 4, W + 80, H + 70, F(WET[0]), opacity=WET[1]),
                x=0.0, y=0.0, opacity=0.0, name="YardWet")
    with sc.minting(d11):
        pumpkin = _pumpkin(sc)
        fr_ = random.Random(31)
        spots = [(fr_.uniform(560, 620), fr_.uniform(1290, 1480)) for _ in range(5)] + \
                [(fr_.uniform(790, 880), fr_.uniform(1290, 1500)) for _ in range(6)] + \
                [(fr_.uniform(110, 320), fr_.uniform(1480, 1600)) for _ in range(5)] + \
                [(fr_.uniform(880, 1010), fr_.uniform(1320, 1520)) for _ in range(6)]
        petal_ps, centre_ps = [], []
        for i, (x, y) in enumerate(spots):
            s_ = 0.8 + 0.6 * (y - GROUND_Y) / 400
            for j in range(5):
                a = TAU * j / 5 + i
                petal_ps.append((round(x + 5 * s_ * math.cos(a), 1), round(y + 5 * s_ * math.sin(a), 1), 7 * s_, 7 * s_))
            centre_ps.append((x, y, 4.5 * s_, 4.5 * s_))
        path_flowers = d11("Node", bind(sc, d11, "spring", 18),
                           dots(sc, "FlowerCentres", centre_ps, F("FFF2C64A")),
                           dots(sc, "FlowerPetalsPink", petal_ps[::2], F("FFF4B4C8")),
                           dots(sc, "FlowerPetalsWhite", petal_ps[1::2], F("FFF8EEF0")),
                           x=0.0, y=0.0, opacity=0.0, name="PathFlowers")
        gl = random.Random(41)
        ground_ps = [maple_leaf_pts(gl.uniform(-10, W + 10), gl.uniform(GROUND_Y + 14, 1880), gl.uniform(9, 15),
                                    gl.uniform(0, TAU)) for _ in range(32)]
        ground_leaves = d11("Node", bind(sc, d11, "autumn", 18),
                            polys(sc, "GroundLeafRed", ground_ps[::3], F("FFC2462C")),
                            polys(sc, "GroundLeafOrange", ground_ps[1::3], F("FFDE7A34")),
                            polys(sc, "GroundLeafGold", ground_ps[2::3], F("FFE8B048")),
                            x=0.0, y=0.0, opacity=0.0, name="GroundLeaves")
    fireflies = _fireflies(sc)
    plane4 = [fireflies, path_flowers, ground_leaves, pumpkin, woodpile, grass_tufts, wet, path_stones, path, yard_glow,
              yard]

    # ------------------------------------------------------------ Plane5: the foreground
    fern_l, fern_r = _fern(sc, "FernL", (60.0, H + 40.0), 1), _fern(sc, "FernR", (1030.0, H + 40.0), -1)
    blades: list[tuple] = [(-80, H + 80, "c"), (-80, 1930)]
    br = random.Random(53)
    x = -70.0
    while x < W + 70:
        h_ = br.uniform(30, 70)
        blades += [(x, 1920 + br.uniform(-6, 6), "c"), (x + br.uniform(6, 14), 1920 - h_, "c")]
        x += br.uniform(16, 30)
    blades += [(W + 80, 1930), (W + 80, H + 80, "c")]
    grass_front = S(O, "GrassFront", blades, vfill(sc, 1850, H + 80, (1850 + H + 80) / 2,
                                                   [("FF2C4A2C", 0.0), ("FF1A2E1C", 1.0)]),
                    origin=(W / 2, (1850 + H + 80) / 2))
    fallen = polys(sc, "FallenLeaves", [maple_leaf_pts(x, y, r_, a) for x, y, r_, a in
                                        ((210, 1902, 15, 0.5), (300, 1930, 12, 2.0), (790, 1915, 14, 4.0),
                                         (880, 1890, 12, 1.2))], F("FF7A6A3A"), L("60302410", 1.6))
    plane5 = [fern_l, fern_r, fallen, grass_front]

    # ------------------------------------------------------------ overlays (screen space)
    with sc.minting(sc.d5):
        rain_loop = _steady_rain(sc)
    shower = _shower(sc)
    gust_leaves, gust_tracks = _gust_leaves(sc)
    leaf_drift = _drift(sc, "LeafDrift", "autumn", petals=False)
    petal_drift = _drift(sc, "PetalDrift", "spring", petals=True)
    with sc.minting(sc.d7):
        day_lift = sc.d7("Shape", bind(sc, sc.d7, "daylight", 18),
                         sc.d7("Rectangle", width=float(W + 160), height=float(H + 160), name="Path"),
                         sc.d7("Fill", sc.d7("SolidColor", colorValue=DAY_LIFT), name="Fill"),
                         x=W / 2, y=H / 2, opacity=0.0, blendModeValue=14, name="DayLift")
    overlays = [rain_loop, shower, gust_leaves, leaf_drift, petal_drift, day_lift]

    # ------------------------------------------------------------ the lantern's flicker (loops in the file)
    sc.ambient("LanternFlicker", sc.A("amb_LanternFlicker", FLICKER_FRAMES, [
        sc.T(lantern_glow, opacity=LANTERN_FLICKER),
        sc.T(pool, opacity=LANTERN_FLICKER)], loop=True))
    n_lf = EVENT_FRAMES["lanternFlicker"]
    flick = [(0, 1.0), (6, 0.4), (10, 0.92), (16, 0.15), (22, 0.05), (28, 0.8), (34, 0.3), (42, 0.95), (50, 0.55),
             (60, 1.0), (n_lf, 1.0)]
    sc.one_shot("lanternFlicker", sc.A("ev_lanternFlicker", n_lf, [
        sc.T(lantern_fx, ease=None, opacity=[(f, v, "linear") for f, v in flick]),
        sc.T(pool_fx, ease=None, opacity=[(f, round(0.35 + 0.65 * v, 3), "linear") for f, v in flick])]))

    # ------------------------------------------------------------ the gust
    n_g = EVENT_FRAMES["gust"]
    sc.one_shot("gust", sc.A("ev_gust", n_g, [
        sc.T(crown, rotation=[(0, 0.0), (26, 0.035), (62, -0.022), (98, 0.026), (134, -0.012), (166, 0.004),
                              (n_g, 0.0)]),
        sc.T(lantern_swing, rotation=[(0, 0.0), (18, 0.26), (46, -0.2), (74, 0.15), (102, -0.1), (130, 0.05),
                                      (156, -0.02), (n_g, 0.0)]),
        sc.T(pinwheel_gust, rotation=[(0, 0.0, sc.ease_in), (40, 1.4), (150, GUST_SPIN, sc.ease_out),
                                      (n_g - 1, GUST_SPIN, "hold"), (n_g, 0.0)]),
        sc.T(fern_l.children[0], rotation=[(0, 0.0), (22, 0.08), (56, -0.05), (92, 0.05), (130, -0.02), (n_g, 0.0)]),
        sc.T(fern_r.children[0], rotation=[(0, 0.0), (26, 0.07), (60, -0.05), (96, 0.04), (134, -0.02), (n_g, 0.0)]),
        *gust_tracks]))

    # ------------------------------------------------------------ props
    hits = [sc.hit("lantern", LANTERN_C[0], LANTERN_C[1] - 6, 76, 120),
            sc.hit("pinwheel", PINWHEEL_HUB[0], PINWHEEL_HUB[1], 2 * PINWHEEL_R + 16, 2 * PINWHEEL_R + 16),
            sc.hit("squirrel", SQ_WAYPOINTS[0][0] + SQ_HIT[0], SQ_WAYPOINTS[0][1] + SQ_HIT[1], SQ_HIT[2], SQ_HIT[3]),
            sc.hit("woodpile", (WOODPILE[0] + WOODPILE[2]) / 2, (WOODPILE[1] + WOODPILE[3]) / 2,
                   WOODPILE[2] - WOODPILE[0] + 10, WOODPILE[3] - WOODPILE[1] + 12)]
    for h_ in hits:
        sc.prop(str(h_.attrs["name"])[4:], h_)

    with sc.minting(sc.d8):
        squirrel = squirrel_npc(sc, hits)
    content = [*overlays, *plane5, *plane4, squirrel, *plane3_front, *plane2, *plane1, *plane0]
    front_weather(sc, RAIN_COL, splash_y=(1830.0, 1905.0))
    return sc.write(content, hits)


# ====================================================================== rain
RAIN_TILE = 480                 # a streak sheet repeats every tile: a one-tile shift loops seamlessly
RAIN_SHEETS = ((22, 70.0, 120.0, 3.2, "FF", 18), (34, 26.0, 50.0, 1.8, "70", 34))   # near, far: count, length, width, alpha, period


def _sheet(sc: Scene, name: str, seed: str, count: int, ln0: float, ln1: float, wd: float, colour: str) -> El:
    """One stroked shape of `count` slanted streaks repeated down the frame every `RAIN_TILE` px (a streak
    per path: far cheaper than a shape per streak, the look of `gen_scenes.rain_fx`)."""
    r = random.Random(zlib_seed(seed))
    segs = []
    for _ in range(count):
        x, y = r.uniform(-60, W + 60), r.uniform(0, RAIN_TILE)
        ln = r.uniform(ln0, ln1)
        for k in range(-1, H // RAIN_TILE + 1):
            segs.append((round(x, 1), round(y + k * RAIN_TILE, 1), round(x - ln * 0.22, 1), round(y + k * RAIN_TILE + ln, 1)))
    return lines(sc, name, segs, colour, wd)


def _steady_rain(sc: Scene) -> El:
    """The steady rain (contract v8 `rain`, a screen overlay at opacity `rain`): two streak sheets
    (`RainSheetNear` on an 18-frame loop, `RainSheetFar` on 34) and sixteen splashes in the yard on a
    120-frame loop (as `gen_scenes.rain_fx` loop=True draws it). Called inside `sc.minting(sc.d5)`."""
    d = sc.d
    sheets = []
    for (n, ln0, ln1, wd, alpha, period), nm in zip(RAIN_SHEETS, ("RainSheetNear", "RainSheetFar")):
        sheet = _sheet(sc, nm, "RainLoop" + nm, n, ln0, ln1, wd, alpha + RAIN_COL[2:])
        sc.ambient(nm, sc.A(f"amb_{nm}", period, [sc.T(sheet, ease=None, y=[(0, 0.0, "linear"),
                                                                            (period, float(RAIN_TILE), "linear")])],
                            loop=True))
        sheets.append(sheet)
    r = random.Random(zlib_seed("RainLoopSplash"))
    splashes, tracks = [], []
    for i in range(16):
        x, y = r.uniform(40, W - 40), r.uniform(GROUND_Y + 20, 1900.0)
        s_ = 0.6 + 0.6 * (y - GROUND_Y) / (H - GROUND_Y)
        sp = d("Shape", sc.d("Ellipse", width=30.0, height=8.0, name="Path"),
               smooth_path(d, [(-8, -2), (-12, -14)], closed=False), smooth_path(d, [(8, -2), (12, -14)], closed=False),
               sc.L("B0" + RAIN_COL[2:], 2), x=round(x, 1), y=round(y, 1), opacity=0.0, scaleX=0.3, scaleY=0.3,
               name=f"Splash{i}")
        splashes.append(sp)
        ph = r.randint(0, 40)
        op, sk = [(0, 0.0)], [(0, 0.3 * s_)]
        for c in range(1 + ph, RAIN_LOOP_FRAMES - 13, 44):
            op += [(c, 0.0, "hold"), (c + 1, 1.0), (c + 12, 0.0, "hold")]
            sk += [(c, 0.3 * s_, "hold"), (c + 1, 0.4 * s_), (c + 12, 1.3 * s_, "hold")]
        tracks.append(sc.T(sp, ease=None, opacity=uniq(op + [(RAIN_LOOP_FRAMES, 0.0)]),
                           scaleX=uniq(sk + [(RAIN_LOOP_FRAMES, 0.3 * s_)]),
                           scaleY=uniq(sk + [(RAIN_LOOP_FRAMES, 0.3 * s_)])))
        sp.attrs.update(scaleX=round(0.3 * s_, 3), scaleY=round(0.3 * s_, 3))
    sc.ambient("RainSplash", sc.A("amb_RainSplash", RAIN_LOOP_FRAMES, tracks, loop=True))
    return d("Node", bind(sc, sc.d5, "rain", 18), *splashes, *sheets, x=0.0, y=0.0, opacity=0.0, name="RainLoop")


def _shower(sc: Scene) -> El:
    """The `rain` event: a shower on top of the steady rain (7 s): two heavier streak sheets fall (saw keys
    inside the one-shot, `ShowerSheetNear` / `ShowerSheetFar`), the scene darkens a little, then it clears."""
    d = sc.d
    n = EVENT_FRAMES["rain"]
    tracks, sheets = [], []
    for (cnt, ln0, ln1, wd, alpha, period), nm in zip(((26, 80.0, 140.0, 3.4, "E0", 16), (40, 30.0, 56.0, 2.0, "80", 30)),
                                                      ("ShowerSheetNear", "ShowerSheetFar")):
        sheet = _sheet(sc, nm, "Shower" + nm, cnt, ln0, ln1, wd, alpha + RAIN_COL[2:])
        saw = []
        for c in range(0, n, period):
            saw += [(c, 0.0, "linear"), (min(c + period - 1, n), RAIN_TILE * (period - 1) / period, "linear")]
        tracks.append(sc.T(sheet, ease=None, y=uniq(saw)))
        sheets.append(sheet)
    dark = d("Shape", d("Rectangle", width=float(W + 160), height=float(H + 160), name="Path"),
             sc.vgrad(-(H + 160) / 2, (H + 160) / 2, [("FF0A1022", 0.0), ("800A1022", 1.0)]), x=W / 2, y=H / 2,
             opacity=0.0, name="ShowerDark")
    group = d("Node", *sheets, x=0.0, y=0.0, opacity=0.0, name="ShowerRain")
    sc.one_shot("rain", sc.A("ev_Shower", n, [
        sc.T(group, ease=None, opacity=[(0, 0.0), (40, 1.0, "linear"), (n - 60, 1.0, "linear"), (n, 0.0)]),
        sc.T(dark, ease=None, opacity=[(0, 0.0), (40, 0.4, "linear"), (n - 60, 0.4, "linear"), (n, 0.0)]),
        *tracks]))
    return d("Node", group, dark, x=0.0, y=0.0, name="ShowerFx")


# ====================================================================== art pieces
def _maple(sc: Scene) -> tuple[El, El]:
    """The big maple (left, Plane2): the trunk with its low branch (the squirrel's seat) and the crown on a
    pivot above the trunk (the gust sways it). The crown is green at the defaults; `MapleAutumn` (the same
    blobs, red-gold) shows at `autumn`, `MapleBlossom` (pink-white clusters) at `spring` (d11)."""
    d, S, F, L = sc.d, sc.S, sc.F, sc.L
    blobs = [(190, 520, 420, 360), (84, 606, 270, 240), (306, 626, 270, 220), (150, 382, 300, 240),
             (318, 470, 250, 230), (40, 462, 230, 220), (236, 724, 290, 160), (392, 572, 170, 190),
             (110, 720, 220, 150)]
    canopy = dots(sc, "MapleCanopy", blobs, vfill(sc, 260, 800, 0, [("FF4E7E44", 0.0), ("FF3A663A", 0.5),
                                                                     ("FF27462C", 1.0)]))
    hi = dots(sc, "MapleHighlight", [(x + w * 0.12, y - h * 0.16, w * 0.55, h * 0.4) for x, y, w, h in blobs[:6]],
              F("38A8D27A"))
    shade = dots(sc, "MapleShade", [(x - w * 0.08, y + h * 0.2, w * 0.6, h * 0.36) for x, y, w, h in blobs[4:]],
                 F("40102014"))
    with sc.minting(sc.d11):
        autumn = sc.d11("Node", bind(sc, sc.d11, "autumn", 18),
                        dots(sc, "AutumnHi", [(x + w * 0.12, y - h * 0.16, w * 0.55, h * 0.4) for x, y, w, h in blobs[:6]],
                             F("60F4C460")),
                        dots(sc, "AutumnCanopy", blobs, vfill(sc, 260, 800, 0, [("FFE0882E", 0.0), ("FFCC4A2A", 0.55),
                                                                                 ("FF8E2C22", 1.0)])),
                        x=0.0, y=0.0, opacity=0.0, name="MapleAutumn")
        br = random.Random(61)
        pink, white = [], []
        for x, y, w, h in blobs:
            for _ in range(int(w * h / 9000)):
                a, rr = br.uniform(0, TAU), br.uniform(0, 0.42)
                cx, cy = x + w * rr * math.cos(a), y + h * rr * math.sin(a)
                s_ = br.uniform(14, 24)
                (pink if br.random() < 0.6 else white).append((round(cx, 1), round(cy, 1), s_, s_ * 0.86))
        blossom = sc.d11("Node", bind(sc, sc.d11, "spring", 18),
                         dots(sc, "BlossomWhite", white, F("FFFAF0F2")),
                         dots(sc, "BlossomPink", pink, F("FFF2B6CA")),
                         x=0.0, y=0.0, opacity=0.0, name="MapleBlossom")
    crown = pivot(sc, "MapleCrown", *CROWN_PIVOT, [blossom, autumn, hi, canopy, shade])
    trunk = S(O, "MapleTrunk", [(116, 1256, "c"), (146, 1180), (154, 1010), (160, 880), (138, 780), (112, 700),
                                (138, 702), (172, 770), (196, 736), (226, 680), (244, 694), (214, 782), (206, 900),
                                (212, 1050), (226, 1190), (256, 1256, "c")],
              sc.d("Fill", lin(sc.d, -70, 0, 70, 0, [("FF5A4030", 0.0), ("FF3E2C20", 0.6), ("FF2A1E16", 1.0)]),
                   name="Fill"), L("FF1E1612", 2.4), tension=0.8)
    bx, by = BRANCH_SEAT
    branch = S(O, "MapleBranch", [(204, 1132), (238, 1114), (bx + 30, by + 2), (bx + 46, by - 6), (bx + 48, by + 2),
                                  (bx + 30, by + 12), (240, 1126), (210, 1150)],
               F("FF4A3426"), L("FF1E1612", 2.2), tension=0.8)
    twig = S(O, "MapleTwig", [(bx + 40, by - 2), (bx + 62, by - 22), (bx + 70, by - 30)], L("FF3E2C20", 4),
             closed=False)
    roots = lines(sc, "MapleRoots", [(120, 1252, 92, 1262), (250, 1252, 282, 1262)], "FF2E2018", 7)
    bark = lines(sc, "MapleBark", [(170, 900, 168, 960), (186, 1040, 184, 1110), (160, 1150, 162, 1200)], "60181008", 3)
    maple = d("Node", crown, twig, branch, bark, roots, trunk, x=0.0, y=0.0, name="Maple")
    return maple, crown


def _lantern(sc: Scene) -> tuple[El, El, El, El]:
    """The porch lantern on its iron bracket off the lantern post. Returns (the node `Lantern`, its glow (the
    ambient flicker keys it), the swing wrapper (the gust), the light's event wrapper (`lanternFlicker`))."""
    d, E, F, L, S = sc.d, sc.E, sc.F, sc.L, sc.S
    hx, hy = LANTERN_HOOK
    cx, cy = LANTERN_C
    px = POSTS[1] + POST_W / 2
    bracket = d("Node",
                S(O, "BracketScroll", [(px, hy + 34), (px + 16, hy + 14), (hx - 4, hy + 2)], L("FF2A2428", 4),
                  closed=False),
                lines(sc, "BracketArm", [(px - 2, hy, hx + 8, hy)], "FF2A2428", 6),
                rect(sc, "BracketPlate", px - 2, hy - 14, px + 6, hy + 44, F("FF2A2428"), r=2),
                x=0.0, y=0.0, name="LanternBracket")
    glow = E(O, "LanternGlow", cx, cy, 380, 380, sc.rgrad(190, [("B0FFD08A", 0.0), ("48FFB060", 0.35),
                                                               ("00FFB060", 1.0)]))
    flame = S(O, "LanternFlame", [(cx, cy - 16, "c"), (cx + 6, cy - 2), (cx + 4, cy + 8), (cx - 4, cy + 8),
                                         (cx - 6, cy - 2)], vfill(sc, cy - 16, cy + 8, cy, [("FFFFFBE0", 0.0), ("FFFFB040", 1.0)]),
              origin=(cx, cy))
    glass = rect(sc, "LanternGlass", cx - 16, cy - 28, cx + 16, cy + 28, vfill(sc, cy - 28, cy + 28, cy,
                                                                               [("FFFFE8A8", 0.0), ("FFF4A24C", 1.0)]),
                 r=4)
    light_fx = d("Node", flame, glass, glow, x=0.0, y=0.0, name="LanternFlickerFx")
    light = d("Node", light_fx, x=0.0, y=0.0, name="LanternLight")
    body = d("Node",
             E(O, "LanternRing", hx, hy + 4, 12, 12, L("FF2A2428", 3)),
             lines(sc, "LanternBail", [(hx, hy + 9, hx, cy - 44)], "FF2A2428", 2.5),
             S(O, "LanternCap", [(cx - 22, cy - 30, "c"), (cx - 14, cy - 40), (cx, cy - 46, "c"), (cx + 14, cy - 40),
                                 (cx + 22, cy - 30, "c")], F("FF3A3236"), L(INK, 2)),
             rects(sc, "LanternBars", [(cx - 21, cy - 30, cx - 15, cy + 30), (cx + 15, cy - 30, cx + 21, cy + 30),
                                       (cx - 3, cy - 30, cx + 3, cy + 30)], F("FF2E2A2E")),
             rect(sc, "LanternBase", cx - 24, cy + 28, cx + 24, cy + 38, F("FF3A3236"), r=3),
             x=0.0, y=0.0, name="LanternBody")
    swing = pivot(sc, "LanternSwing", hx, hy, [body, light])
    return d("Node", swing, bracket, x=0.0, y=0.0, name="Lantern"), glow, swing, light_fx


def _pinwheel(sc: Scene) -> tuple[El, El]:
    """The pinwheel on its stick, tied to the rail: four curled blades in four colours (a half turn reads)
    on `PinwheelSpin` (rotation = 2 pi x `pinwheel`, history-free; the contract's spin drag) inside
    `PinwheelGust` (the gust's extra spin, keyed). Minted from d9 where it binds."""
    d, E, F, L = sc.d, sc.E, sc.F, sc.L
    hx, hy = PINWHEEL_HUB
    r = PINWHEEL_R
    blades = []
    for i, col in enumerate(PINWHEEL_COLOURS):
        a = TAU * i / 4

        def rot(pts: list[tuple[float, float]], a: float = a) -> list[tuple]:
            c, s = math.cos(a), math.sin(a)
            return [(round(x * c - y * s, 2), round(x * s + y * c, 2), "c") for x, y in pts]
        outer = rot([(3, -3), (0, -r), (r * 0.74, -r * 0.7), (15, -6)])
        fold = rot([(0, -r), (r * 0.74, -r * 0.7), (12, -14)])
        blades.append(d("Node", sc.d("Shape", smooth_path(sc.d, fold), F("38000000"), x=0.0, y=0.0, name="Fold"),
                        sc.d("Shape", smooth_path(sc.d, outer), F(col), L(INK, 1.6), x=0.0, y=0.0, name="Blade"),
                        x=0.0, y=0.0, name=f"PinwheelBlade{i}"))
    with sc.minting(sc.d9):
        spin = sc.d9("Node", bind(sc, sc.d9, "pinwheel", 15, conv(sc, sc.d9, TAU)), x=0.0, y=0.0, name="PinwheelSpin")
    spin.children += [E(O, "PinwheelPin", 0, 0, 11, 11, F("FFF0E6D4"), L(INK, 1.6)), *reversed(blades)]
    gust = d("Node", spin, x=hx, y=hy, name="PinwheelGust")
    stick = d("Node",
              rects(sc, "PinwheelTie", [(hx - 7, RAIL_TOP + 2, hx + 7, RAIL_TOP + 8)], F("FFC8B48A")),
              rect(sc, "PinwheelStick", hx - 4, hy, hx + 4, RAIL_TOP + 40, F("FFB88E5E"), r=3),
              x=0.0, y=0.0, name="PinwheelStickNode")
    return d("Node", gust, stick, x=0.0, y=0.0, name="Pinwheel"), gust


def _woodpile(sc: Scene) -> El:
    """Split logs stacked in a rack with a little plank roof (left of the path, Plane4)."""
    d, F, L = sc.d, sc.F, sc.L
    x0, y0, x1, y1 = WOODPILE
    ends = []
    rr = random.Random(3)
    for row in range(4):
        y = y1 - 26 - row * 34
        for k in range(7):
            x = x0 + 34 + k * 34 + (17 if row % 2 else 0)
            if x > x1 - 26:
                continue
            ends.append((round(x + rr.uniform(-2, 2), 1), round(y + rr.uniform(-2, 2), 1), 34, 32))
    return d("Node",
             rect(sc, "WoodRoof", x0 - 14, y0 - 12, x1 + 14, y0 + 4, vfill(sc, y0 - 12, y0 + 4, y0 - 4,
                                                                         [("FF8A6A4A", 0.0), ("FF5A4230", 1.0)]), r=3),
             rects(sc, "WoodRack", [(x0, y0, x0 + 12, y1), (x1 - 12, y0, x1, y1), (x0, y1 - 10, x1, y1)],
                   F("FF4A3424")),
             dots(sc, "WoodRings", [(x, y, w * 0.45, h * 0.42) for x, y, w, h in ends], L("FF9A6A40", 1.8)),
             dots(sc, "WoodEnds", ends, F("FFD4A672"), L("FF6A4428", 2.4)),
             rect(sc, "WoodBack", x0 + 8, y0 + 8, x1 - 8, y1 - 4, F("FF3A2618")),
             sc.E(O, "WoodShadow", (x0 + x1) / 2, y1 + 6, x1 - x0 + 40, 26, F("50080C08")),
             x=0.0, y=0.0, name="Woodpile")


def _pumpkin(sc: Scene) -> El:
    """A pumpkin by the step (autumn only), minted where it is called (d11)."""
    d, E, F, L, S = sc.d, sc.E, sc.F, sc.L, sc.S
    x, y = PUMPKIN
    body = [E(O, f"PumpkinLobe{k}", x + dx, y, w, 46, sc.vgrad(-23, 23, [("FFEE9440", 0.0), ("FFC0602A", 1.0)]),
              L("FF6A2E14", 2)) for k, (dx, w) in enumerate(((-20, 36), (20, 36), (0, 44)))]
    return d("Node", bind(sc, d, "autumn", 18),
             S(O, "PumpkinLeaf", [(x + 4, y - 24), (x + 22, y - 34), (x + 30, y - 26), (x + 14, y - 22)], F("FF5E7A34")),
             S(O, "PumpkinStem", [(x - 3, y - 20), (x - 2, y - 32), (x + 5, y - 36), (x + 4, y - 20)], F("FF5A6A2E"),
               L("FF2A3014", 1.6)),
             *body, E(O, "PumpkinShadow", x, y + 22, 96, 14, F("50080C08")),
             x=0.0, y=0.0, opacity=0.0, name="Pumpkin")


def _fern(sc: Scene, name: str, base: tuple[float, float], side: int) -> El:
    """A fern in a bottom corner (Plane5): five fronds, each one serrated outline (its leaflets as teeth
    along both sides), and their ribs, on a sway pivot at the base (the gust)."""
    L = sc.L
    bx, by = base
    fronds, ribs = [], []
    for ang, ln in ((-1.2, 300), (-1.55, 360), (-1.9, 330), (-0.85, 240), (-2.3, 250)):
        a = ang if side > 0 else math.pi - ang

        def c(u: float, a: float = a, ln: float = ln) -> tuple[float, float]:
            return bx + math.cos(a) * ln * u + side * 20 * u * u, by + math.sin(a) * ln * u + 60 * u * u

        def nrm(u: float) -> tuple[float, float]:
            (x0, y0), (x1, y1) = c(max(0.0, u - 0.01)), c(min(1.0, u + 0.01))
            ll = math.hypot(x1 - x0, y1 - y0) or 1.0
            return -(y1 - y0) / ll, (x1 - x0) / ll
        n_teeth = 10
        sides = []
        for sgn in (1, -1):
            pts = []
            for j in range(n_teeth):
                u0, u1 = 0.08 + 0.9 * j / n_teeth, 0.08 + 0.9 * (j + 1) / n_teeth
                w = 34 * (1 - u0) + 8
                (cx0, cy0), (nx, ny) = c(u0), nrm(u0)
                (tx, ty) = c(min(1.0, u0 + 0.6 / n_teeth))
                pts += [(round(cx0 + sgn * nx * 4, 1), round(cy0 + sgn * ny * 4, 1), "c"),
                        (round(tx + sgn * nx * w, 1), round(ty + sgn * ny * w, 1), "c")]
            sides.append(pts)
        tip = c(1.0)
        fronds.append([(round(bx, 1), round(by, 1), "c"), *sides[0], (round(tip[0], 1), round(tip[1], 1), "c"),
                       *reversed(sides[1])])
        ribs.append([c(0.0), c(0.5), c(1.0)])
    leaves = polys(sc, "FernLeaves", fronds, vfill(sc, by - 380, by, 0, [("FF4A7E46", 0.0), ("FF24442A", 1.0)]))
    rib = polys(sc, "FernRibs", ribs, L("FF1E3622", 3), closed=False)
    sway = pivot(sc, name + "Sway", bx, by, [rib, leaves])
    return sc.d("Node", sway, x=0.0, y=0.0, name=name)


def _fireflies(sc: Scene) -> El:
    """`fireflies` (6 s): twenty glowing dots rise from the grass and wander, blinking (emissive, Plane4).
    `FireflyA*` are the first half (`FireflyB*` the tier's second half)."""
    d, E, F = sc.d, sc.E, sc.F
    n = EVENT_FRAMES["fireflies"]
    r = random.Random(97)
    nodes, tracks = [], []
    for i in range(20):
        x0 = r.choice((r.uniform(60, 330), r.uniform(760, 1020), r.uniform(330, 760)))
        y0 = r.uniform(1320, 1760)
        start, life = r.randint(0, 120), r.randint(170, 230)
        ph = r.uniform(0, TAU)
        node = d("Node", E(O, "Glow", 0, 0, 34, 34, sc.rgrad(17, [("90E8FF8A", 0.0), ("00E8FF8A", 1.0)])),
                 E(O, "Core", 0, 0, 7, 7, F("FFF8FFC8")),
                 x=round(x0, 1), y=round(y0, 1), opacity=0.0, name=f"Firefly{'AB'[i % 2]}{i // 2}")
        nodes.append(node)
        frames = sorted({0, start, min(n, start + life), n, *range(start, min(n, start + life) + 1, 30)})

        def pos(f: int, x0: float = x0, y0: float = y0, start: int = start, life: int = life,
                ph: float = ph) -> tuple[float, float, float]:
            u = min(1.0, max(0.0, (f - start) / life))
            x = x0 + 46 * math.sin(ph + u * 7) + 30 * u
            y = y0 - 260 * u + 18 * math.sin(ph * 2 + u * 11)
            blink = 0.55 + 0.45 * math.sin(ph + u * 23) ** 2
            op = min(1.0, u * 8) * min(1.0, (1 - u) * 6) * blink if start <= f <= start + life else 0.0
            return x, y, op
        tracks.append(sc.T(node, ease=None, x=[(f, round(pos(f)[0], 2), "linear") for f in frames],
                           y=[(f, round(pos(f)[1], 2), "linear") for f in frames],
                           opacity=[(f, round(pos(f)[2], 3), "linear") for f in frames]))
    group = d("Node", *nodes, x=0.0, y=0.0, opacity=0.0, name="Fireflies")
    sc.one_shot("fireflies", sc.A("ev_fireflies", n, [
        sc.T(group, opacity=[(0, 0.0), (10, 1.0), (n - 20, 1.0), (n, 0.0)]), *tracks]))
    return group


def _gust_leaves(sc: Scene) -> tuple[El, list[El]]:
    """The gust's flying leaves (screen overlay): twelve carriers blown left to right; each holds a green
    leaf (opacity 1 - spring - autumn, clamped), a petal (spring) and a red-gold maple leaf (autumn),
    history-free (d11 converters). Returns (the node, its tracks for `ev_gust`)."""
    d, F = sc.d, sc.F
    d11 = sc.d11
    f = Formulas(d11, sc.vpath)
    green_conv = d11("DataConverterFormula", *f.fn("max", [f.val(0)], [f.val(1), f.op("-"), *f.inp(), f.op("-"),
                                                                       f.bound("autumn")]))
    sc.roots.append(green_conv)
    n = EVENT_FRAMES["gust"]
    r = random.Random(131)
    nodes, tracks = [], []
    for i in range(12):
        y0 = r.uniform(420, 1640)
        s0 = 8 + 8 * i
        span = r.randint(96, 130)
        with sc.minting(d11):
            kids = [d11("Shape", bind(sc, d11, "autumn", 18), smooth_path(d11, maple_leaf_pts(0, 0, 13, 0)),
                        d11("Fill", d11("SolidColor", colorValue=("FFD0502C", "FFE4A040")[i % 2]), name="Fill"),
                        x=0.0, y=0.0, opacity=0.0, name="AutumnLeaf"),
                    d11("Shape", bind(sc, d11, "spring", 18), d11("Ellipse", width=13.0, height=10.0, name="Path"),
                        d11("Fill", d11("SolidColor", colorValue=("FFF4B8CA", "FFFAF0F2")[i % 2]), name="Fill"),
                        x=0.0, y=0.0, opacity=0.0, name="Petal"),
                    d11("Shape", bind(sc, d11, "spring", 18, green_conv), smooth_path(d11, leaf_pts(0, 0, 22, 11, 0)),
                        d11("Fill", d11("SolidColor", colorValue=("FF5E9050", "FF7AA85A")[i % 2]), name="Fill"),
                        x=0.0, y=0.0, name="GreenLeaf")]
        node = d("Node", *kids, x=-90.0, y=round(y0, 1), name=f"GustLeaf{'AB'[i % 2]}{i // 2}")
        nodes.append(node)
        frames = sorted({0, s0, min(n, s0 + span), n, *range(s0, min(n, s0 + span) + 1, 10)})

        def at(fr: int, y0: float = y0, s0: int = s0, span: int = span, i: int = i) -> tuple[float, float, float]:
            u = min(1.0, max(0.0, (fr - s0) / span))
            x = -90 + (W + 180) * (u ** 1.15)
            y = y0 - 140 * u + 46 * math.sin(u * 9 + i)
            return x, y, 4 * math.pi * u * (1 if i % 2 else -1)
        tracks.append(sc.T(node, ease=None, x=[(fr, round(at(fr)[0], 2), "linear") for fr in frames],
                           y=[(fr, round(at(fr)[1], 2), "linear") for fr in frames],
                           rotation=[(fr, round(at(fr)[2], 3), "linear") for fr in frames]))
    return d("Node", *nodes, x=0.0, y=0.0, name="GustLeaves"), tracks


def _drift(sc: Scene, name: str, season: str, petals: bool) -> El:
    """A slow seasonal drift over the scene (screen overlay), opacity `season` (d11): twelve falling leaves
    (autumn) or petals (spring) on a seamless `DRIFT_LOOP`. Groups: `<name>A` the first third, `<name>B` up
    to half, `<name>C` the rest (the tier gates hide C at high, B and C at low)."""
    d11 = sc.d11
    r = random.Random(zlib_seed(name))
    groups: list[list[El]] = [[], [], []]
    tracks = []
    with sc.minting(d11):
        for i in range(12):
            x0 = r.uniform(-40, W + 40)
            off = r.randint(0, DRIFT_LOOP - 1)
            if petals:
                shape = sc.E(O, "Petal", 0, 0, 13, 10, sc.F(("FFF4B8CA", "FFFAF0F2")[i % 2]))
            else:
                shape = d11("Shape", smooth_path(d11, maple_leaf_pts(0, 0, 12, 0)),
                            sc.F(("FFD0502C", "FFE4A040", "FFDA7A34")[i % 3]), x=0.0, y=0.0, name="Leaf")
            node = d11("Node", shape, x=0.0, y=0.0, name=f"Drift{i}")
            ph = r.uniform(0, TAU)

            def at(t: float, x0: float = x0, ph: float = ph) -> dict[str, float]:
                return {"x": x0 + 60 * math.sin(TAU * t + ph) + 90 * t, "y": -40 + (H + 80) * t,
                        "rotation": 0.9 * math.sin(TAU * 2 * t + ph)}
            tracks.append(sc.T(node, ease=None, **wrap_keys(DRIFT_LOOP, off, 40, at)))
            k0 = at(off / DRIFT_LOOP)
            node.attrs.update(x=round(k0["x"], 3), y=round(k0["y"], 3), rotation=round(k0["rotation"], 3))
            groups[0 if i < 4 else 1 if i < 6 else 2].append(node)
        sc.ambient(name, sc.A(f"amb_{name}", DRIFT_LOOP, tracks, loop=True))
        kids = [d11("Node", *g, x=0.0, y=0.0, name=f"{name}{'ABC'[k]}") for k, g in enumerate(groups)]
        return d11("Node", bind(sc, d11, season, 18), *kids, x=0.0, y=0.0, opacity=0.0, name=name)


def zlib_seed(s: str) -> int:
    import zlib  # noqa: PLC0415
    return zlib.crc32(s.encode())


# ====================================================================== the squirrel
RUST, RUST_SH, CREAM, TAIL, TAIL_HI = "FFB86A3E", "FF8A4A2C", "FFF0DCBC", "FFC27A4C", "FFE0A878"


def squirrel_path() -> tuple[list[float], list[float], list[float], list[float]]:
    """(npcX at each waypoint, x, y, scale) of the squirrel's feet along its path."""
    ts = arc_params([(x, y) for x, y, _ in SQ_WAYPOINTS])
    return ts, [x for x, _, _ in SQ_WAYPOINTS], [y for _, y, _ in SQ_WAYPOINTS], [s for _, _, s in SQ_WAYPOINTS]


def squirrel_run_speed() -> float:
    """npcX per second at which the gallop's bounds match its travel (average scale)."""
    ts, xs, ys, ss = squirrel_path()
    length = sum(math.hypot(x1 - x0, y1 - y0) for x0, y0, x1, y1 in zip(xs, ys, xs[1:], ys[1:]))
    return SQ_STRIDE * SQ_SCALE * (sum(ss) / len(ss)) * 60 / SQ_RUN / length


def squirrel_npc(sc: Scene, hits: list[El]) -> El:
    """The squirrel: a sitting drawing (rest, idle, notice, react) and a running one (move) in one path node
    `SquirrelNpc` (front of Plane3), the `Npc` layer (scene_npc.npc_layer) and the poke zone riding `npcX`.
    Called inside `sc.minting(sc.d8)`."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rig = Rig(sc)

    # ---- sitting (profile, facing left), feet at the origin
    tail = d("Node",
             S(Z, "SitTailHi", [(18, -40), (28, -60), (24, -76), (12, -84), (20, -70), (22, -54)], F(TAIL_HI)),
             S(Z, "SitTailShape", [(8, -2), (26, -10), (38, -28), (40, -50), (34, -72), (20, -88), (2, -90), (-6, -80),
                                   (6, -74), (18, -68), (22, -52), (20, -36), (12, -24), (2, -14)],
               vfill(sc, -90, 0, 0, [(TAIL, 0.0), (RUST_SH, 1.0)]), L(INK, 2), origin=Z),
             x=0.0, y=0.0, name="SqTail")
    tail_pivot = d("Node", tail, x=12.0, y=-8.0, name="SqTailPivot")
    tail.attrs.update(x=-12.0, y=8.0)
    rig.reg(tail_pivot, rotation=0.0, scaleX=1.0, scaleY=1.0)
    pupil = d("Node", E(Z, "SqGlint", -1.2, -1.4, 2.0, 2.0, F("FFFFFFFF")), E(Z, "SqPupil", 0, 0, 5.4, 6.2, F("FF1A1216")),
              x=0.0, y=0.0, name="SqPupilNode")
    rig.reg(pupil, x=0.0)
    eye = d("Node", pupil, x=-18.0, y=-63.0, name="SqEye")
    rig.reg(eye, scaleY=1.0, scaleX=1.0)
    head = d("Node",
             eye,
             E(Z, "SqNose", -31, -58, 5, 4, F("FF3A2228")),
             S(Z, "SqEarTuft", [(-6, -74), (-4, -88, "c"), (3, -80), (2, -72)], F(RUST_SH), L(INK, 1.6)),
             E(Z, "SqCheek", -20, -54, 14, 9, F(CREAM)),
             S(Z, "SqHeadShape", [(-32, -58), (-25, -67), (-14, -73), (-2, -71), (5, -62), (2, -52), (-8, -48),
                                  (-22, -50)], F(RUST), L(INK, 2)),
             x=0.0, y=0.0, name="SqHead")
    head_pivot = d("Node", head, x=-6.0, y=-48.0, name="SqHeadPivot")
    head.attrs.update(x=6.0, y=48.0)
    rig.reg(head_pivot, rotation=0.0)
    acorn = d("Node", E(Z, "AcornCap", -25, -41, 11, 6, F("FF7A5432")), E(Z, "AcornNut", -25, -36, 9, 10, F("FFC8944E"),
                                                                           L(INK, 1.2)),
              x=0.0, y=0.0, opacity=0.0, name="SqAcorn")
    rig.reg(acorn, opacity=0.0)
    paws = d("Node", acorn, E(Z, "SqPaw", -21, -33, 11, 7, F(RUST_SH), L(INK, 1.4)), x=0.0, y=0.0, name="SqPaws")
    rig.reg(paws, y=0.0)
    bob = d("Node", head_pivot, paws,
            E(Z, "SqBelly", -11, -24, 12, 28, F(CREAM)),
            E(Z, "SqHaunch", 7, -13, 24, 22, F(RUST_SH)),
            S(Z, "SqBody", [(-16, 0), (-20, -14), (-17, -32), (-8, -46), (4, -50), (16, -40), (20, -22), (18, -6),
                            (10, 0)], vfill(sc, -50, 0, 0, [(RUST, 0.0), (RUST_SH, 1.0)]), L(INK, 2), origin=Z),
            E(Z, "SqFoot", -6, -1, 24, 7, F(RUST_SH), L(INK, 1.4)),
            tail_pivot, x=0.0, y=0.0, name="SqSitBob")
    rig.reg(bob, y=0.0, scaleX=1.0, scaleY=1.0)
    sit = d("Node", d("Node", bob, x=0.0, y=0.0, scaleX=SQ_SCALE, scaleY=SQ_SCALE, name="SqSitArt"),
            E(Z, "SqSitShadow", 2, 1, 70, 8, F("40080406")), x=0.0, y=0.0, name="SqSit")
    rig.reg(sit, opacity=1.0)

    # ---- running (profile, facing left; mirrored while npcLook > 0)
    def limb(name: str, x: float, y: float, ln: float, w: float, col: str) -> El:
        n = d("Node", E(Z, "Foot", -3, ln, w + 6, 5, F(col), L(INK, 1.2)),
              S(Z, "Limb", [(-w / 2, -2), (w / 2, -2), (w / 2 - 1, ln), (-w / 2 + 1, ln)], F(col), L(INK, 1.3)),
              x=x, y=y, name=name)
        return rig.reg(n, rotation=0.0)
    fore_far, fore_near = limb("SqForeFar", -16, -14, 12, 6, RUST_SH), limb("SqForeNear", -18, -13, 12, 7, RUST)
    hind_far, hind_near = limb("SqHindFar", 14, -14, 13, 8, RUST_SH), limb("SqHindNear", 16, -13, 13, 9, RUST)
    run_tail = d("Node", S(Z, "RunTailShape", [(0, 0), (16, -8), (30, -22), (38, -40), (32, -48), (22, -42), (12, -26),
                                               (-2, -12)], vfill(sc, -48, 0, 0, [(TAIL_HI, 0.0), (TAIL, 1.0)]),
                           L(INK, 1.8), origin=Z),
                 x=24.0, y=-22.0, name="SqRunTail")
    rig.reg(run_tail, rotation=0.0)
    run_head = d("Node",
                 E(Z, "RunEye", -36, -27, 5, 5.6, F("FF1A1216")),
                 E(Z, "RunNose", -47, -22, 4, 3.4, F("FF3A2228")),
                 S(Z, "RunEar", [(-28, -32), (-27, -44, "c"), (-21, -36)], F(RUST_SH), L(INK, 1.4)),
                 S(Z, "RunHead", [(-48, -22), (-40, -31), (-28, -34), (-20, -26), (-24, -16), (-38, -15)], F(RUST),
                   L(INK, 1.8)),
                 x=0.0, y=0.0, name="SqRunHead")
    rig.reg(run_head, rotation=0.0)
    run_body = S(Z, "RunBody", [(-28, -20), (-18, -31), (4, -33), (22, -28), (28, -18), (18, -10), (-6, -10), (-22, -12)],
                 vfill(sc, -33, -10, 0, [(RUST, 0.0), (RUST_SH, 1.0)]), L(INK, 1.8), origin=Z)
    run_belly = E(Z, "RunBelly", -6, -13, 30, 7, F(CREAM))
    run_bob = d("Node", run_head, fore_near, hind_near, run_belly, run_body, run_tail, fore_far, hind_far,
                x=0.0, y=0.0, name="SqRunBob")
    rig.reg(run_bob, y=0.0, scaleX=1.0)
    f = Formulas(sc.d8, sc.vpath)
    flip = scene_npc.formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                                  *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)],
                                                                 [f.val(1000), f.op("*"), f.bound("npcLook")]))])
    run_face = d("Node", sc.bind("npcLook", 16, flip, doc=sc.d8), run_bob, E(Z, "SqRunShadow", 0, 1, 60, 6, F("38080406")),
                 x=0.0, y=0.0, scaleX=SQ_SCALE, scaleY=SQ_SCALE, name="SqRunFace")
    run = d("Node", run_face, x=0.0, y=0.0, opacity=0.0, name="SqRun")
    rig.reg(run, opacity=0.0)

    # ---- the path node, its rotation on the trunk and the poke zone
    x0, y0, _ = SQ_WAYPOINTS[0]
    npc = d("Node", run, sit, x=x0, y=y0, name="SquirrelNpc")
    rig.reg(npc, opacity=1.0)
    ts, xs, ys, ss = squirrel_path()
    gains = gen_scenes.PARALLAX_GAINS
    depth = ((gains[2] - gains[3]) * gen_scenes.PARALLAX_TRAVEL[0], (gains[2] - gains[3]) * gen_scenes.PARALLAX_TRAVEL[1])
    path_binds(sc, npc, ts, xs, ys, ss, depth=(ts[SQ_DEPTH[0]], ts[SQ_DEPTH[1]], depth), toward=True)
    npc.children.insert(0, sc.bind("npcX", 15, scene_npc.formula(sc, pw_tokens(f, list(zip(ts, SQ_ROTATIONS)))),
                                   doc=sc.d8))
    hit = next(h for h in hits if h.attrs.get("name") == "Hit_squirrel")
    hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
    path_binds(sc, hit, ts, [x + (hx - xs[0]) * s for x, s in zip(xs, ss)], [y + (hy - ys[0]) * s for y, s in zip(ys, ss)],
               ss)

    # ---- states (every state keys every registered property)
    sit_on = {sit: {"opacity": [(0, 1.0)]}, run: {"opacity": [(0, 0.0)]}}
    anims: dict[str, El | list[El]] = {}
    n = SQ_REST
    anims["rest"] = rig.anim("npc_squirrel_rest", n, {
        bob: {"scaleY": [(0, 1.0), (n // 2, 1.025), (n, 1.0)], "scaleX": [(0, 1.0), (n // 2, 0.99), (n, 1.0)]},
        tail_pivot: {"rotation": [(0, 0.0), (n // 2, 0.05), (n, 0.0)]},
        eye: {"scaleY": [(0, 1.0), (170, 1.0), (173, 0.12), (178, 1.0), (n, 1.0)]},
    })
    anims["away"] = rig.anim("npc_squirrel_away", 1, {npc: {"opacity": [(0, 0.0)]}})
    n = SQ_IDLE
    nib = [(0, 0.0)]
    head_nib = [(0, 0.0)]
    for start in (14, 150):
        for j in range(6):
            nib += [(start + 8 * j, -6.0), (start + 8 * j + 4, -3.0)]
            head_nib += [(start + 8 * j, 0.1), (start + 8 * j + 4, 0.04)]
        nib.append((start + 54, 0.0))
        head_nib.append((start + 54, 0.0))
    nib.append((n, 0.0))
    head_nib.append((n, 0.0))
    anims["idle"] = rig.anim("npc_squirrel_idle", n, {
        **sit_on,
        acorn: {"opacity": [(0, 1.0)]},
        paws: {"y": nib},
        head_pivot: {"rotation": head_nib},
        tail_pivot: {"rotation": [(0, 0.0), (90, 0.0), (94, -0.3), (100, 0.14), (106, -0.22), (114, 0.0), (210, 0.0),
                                  (214, -0.26), (220, 0.12), (228, 0.0), (n, 0.0)]},
        eye: {"scaleY": [(0, 1.0), (120, 1.0), (123, 0.12), (128, 1.0), (n, 1.0)]},
        bob: {"scaleY": [(0, 1.0), (60, 1.012), (120, 1.0), (180, 1.012), (n, 1.0)]},
    })
    m = SQ_RUN
    anims["move"] = rig.anim("npc_squirrel_move", m, {
        sit: {"opacity": [(0, 0.0)]}, run: {"opacity": [(0, 1.0)]},
        run_bob: {"y": [(0, 0.0), (6, -7.0), (12, 0.0), (18, -3.0), (m, 0.0)],
                  "scaleX": [(0, 1.08), (6, 1.0), (12, 0.9), (18, 1.0), (m, 1.08)]},
        fore_near: {"rotation": [(0, -0.75), (6, -0.1), (12, 0.75), (18, 0.2), (m, -0.75)]},
        fore_far: {"rotation": [(0, -0.6), (6, 0.0), (12, 0.85), (18, 0.25), (m, -0.6)]},
        hind_near: {"rotation": [(0, 0.85), (6, 0.2), (12, -0.7), (18, -0.1), (m, 0.85)]},
        hind_far: {"rotation": [(0, 0.7), (6, 0.1), (12, -0.8), (18, -0.15), (m, 0.7)]},
        run_tail: {"rotation": [(0, 0.12), (6, -0.1), (12, 0.14), (18, -0.08), (m, 0.12)]},
        run_head: {"rotation": [(0, 0.04), (12, -0.04), (m, 0.04)]},
    })
    n = SQ_NOTICE

    def notice(s: float) -> El:
        return rig.anim(f"npc_squirrel_notice{'LCR'[int(s) + 1]}", n, {
            **sit_on,
            bob: {"scaleY": [(0, 1.08), (60, 1.095), (n, 1.08)], "scaleX": [(0, 0.95)]},
            head_pivot: {"rotation": [(0, -0.12 if s < 0 else 0.34 * s), (60, (-0.12 if s < 0 else 0.34 * s) + 0.04),
                                      (n, -0.12 if s < 0 else 0.34 * s)]},
            pupil: {"x": [(0, 1.4 * s if s > 0 else -1.2 * abs(s))]},
            paws: {"y": [(0, -4.0)]},
            tail_pivot: {"rotation": [(0, 0.0), (30, 0.06), (60, 0.0), (90, 0.06), (n, 0.0)]},
            eye: {"scaleY": [(0, 1.12)], "scaleX": [(0, 1.1)]},
        })
    anims["notice"] = blend3(notice)
    n = SQ_REACT
    anims["react"] = rig.anim("npc_squirrel_react", n, {
        **sit_on,
        bob: {"y": [(0, 0.0), (5, 3.0), (14, -34.0), (24, -40.0), (34, 0.0), (40, 3.0), (48, 0.0), (n, 0.0)],
              "scaleY": [(0, 1.0), (5, 0.86), (14, 1.12), (26, 1.04), (34, 0.9), (42, 1.03), (50, 1.0), (n, 1.0)],
              "scaleX": [(0, 1.0), (5, 1.1), (14, 0.94), (26, 0.98), (34, 1.08), (42, 0.99), (50, 1.0), (n, 1.0)]},
        tail_pivot: {"scaleX": [(0, 1.0), (8, 1.38), (40, 1.3), (56, 1.0), (n, 1.0)],
                     "scaleY": [(0, 1.0), (8, 1.32), (40, 1.26), (56, 1.0), (n, 1.0)],
                     "rotation": [(0, 0.0), (8, -0.18), (24, 0.1), (40, -0.06), (56, 0.0), (n, 0.0)]},
        eye: {"scaleY": [(0, 1.0), (6, 1.3), (44, 1.3), (52, 1.0), (n, 1.0)],
              "scaleX": [(0, 1.0), (6, 1.3), (44, 1.3), (52, 1.0), (n, 1.0)]},
        paws: {"y": [(0, 0.0), (8, -8.0), (40, -8.0), (50, 0.0), (n, 0.0)]},
    })
    npc_layer(sc, anims)
    return npc


# ====================================================================== the diorama
PLANES: dict[str, int | None] = {
    **dict.fromkeys(("RainLoop", "ShowerFx", "GustLeaves", "LeafDrift", "PetalDrift", "DayLift"), None),
    **dict.fromkeys(("FernL", "FernR", "FallenLeaves", "GrassFront"), 5),
    **dict.fromkeys(("Fireflies", "PathFlowers", "GroundLeaves", "Pumpkin", "Woodpile", "GrassTufts", "YardWet",
                     "PathStones", "Path", "YardGlow", "Yard"), 4),
    **dict.fromkeys(("SquirrelNpc", "FestiveLights", "PorchLeaves", "Steps", "Pinwheel", "Lantern", "PorchRoof",
                     "Posts", "Rail", "DeckFace", "Deck", "Wreath", "Door", "Window", "WindowGlow", "LanternPool",
                     "LogWall"), 3),
    **dict.fromkeys(("Maple", "ChimneySmoke", "Chimney", "CabinRoof", "ForestFloor"), 2),
    **dict.fromkeys(("ForestMist", "Birch", "ForestNear", "ForestFar"), 1),
    **dict.fromkeys(("SkyOvercast", "MoonRig", "MoonDrawn", "FarRidge", "StarTwinkleA", "StarTwinkleB", "Stars", "Sky"),
                    0),
    "Hit_lantern": 3, "Hit_pinwheel": 3, "Hit_squirrel": 3, "Hit_woodpile": 4,
}
EMISSIVE = ("Stars", "StarTwinkleA", "StarTwinkleB", "MoonDrawn", "WindowLit", "WindowGlow", "DoorPane", "LanternLight",
            "LanternPool", "YardGlow", "Fireflies")
VEILS = ((0.3, 420.0, 900.0), (0.16, 860.0, 1200.0))   # a night haze over the sky and the forest wall
FOG_BANK = (1, 640.0, 1000.0, "FFB4C4B0", 0.6)

DIORAMAS[SCENE_ID] = DioramaSpec(PLANES, EMISSIVE, VEILS)
TIME_SKY[SCENE_ID] = (HORIZON, 1.0)
scene_npc.FOG_VEILS[SCENE_ID] = (0, 1)
scene_npc.FOG_BANKS[SCENE_ID] = FOG_BANK


# ====================================================================== review registry
SQ_CROP = (220, 200, -42)


def review_extras(render: Callable[..., object], out: Path, gates: list[str]) -> None:
    """review_diorama's scene extras (the M11 evidence): the events at their peaks, the world (f90, day, dusk,
    night, rain, fog, the seasons, December, parallax), the pinwheel drag's pixel proof and its wrap, the
    moon's phases, the squirrel's six states and a move, and `contact_sheet.png` (all of it, smaller)."""
    import numpy as np  # noqa: PLC0415 (review only)
    from PIL import Image, ImageDraw  # noqa: PLC0415

    def im(a: object, label: str, size: tuple[int, int] = (270, 480), box: tuple[int, ...] | None = None) -> Image.Image:
        img = Image.fromarray(a).convert("RGB")  # type: ignore[arg-type]
        if box is not None:
            img = img.crop(box)
        img = img.resize(size)
        dr = ImageDraw.Draw(img)
        dr.rectangle((0, 0, 7 * len(label) + 8, 14), fill=(0, 0, 0))
        dr.text((4, 2), label, fill=(255, 255, 0))
        return img

    def grid(cells: list[Image.Image], cols: int) -> Image.Image:
        w, h = cells[0].size
        sheet = Image.new("RGB", (cols * w, ((len(cells) + cols - 1) // cols) * h), (20, 20, 20))
        for i, c in enumerate(cells):
            sheet.paste(c, ((i % cols) * w, (i // cols) * h))
        return sheet

    rest = render("--advance=1")
    ev_cells = [im(rest, "rest")]
    for ev, fr in EVENT_PEAKS.items():
        ev_cells.append(im(render(f"--data=eventId={ev}", "--data=event=1", f"--advance={fr}"), f"{ev} +{fr}f"))
    for ev, fr, args in (("gust", 70, ("--data=spring=1",)), ("gust", 70, ("--data=autumn=1",))):
        ev_cells.append(im(render(*args, f"--data=eventId={ev}", "--data=event=1", f"--advance={fr}"),
                           f"{ev} +{fr}f {args[0][7:]}"))
    grid(ev_cells, 4).save(out / "events_strip.png")
    world = [im(rest, "rest (night)")]
    for label, args in (("f90", ("--advance=91",)), ("noon", ("--data=daylight=1", "--advance=1")),
                        ("dusk (0.4 / 1)", ("--data=daylight=0.4", "--data=dusk=1", "--advance=1")),
                        ("morning (0.75/0.2)", ("--data=daylight=0.75", "--data=dusk=0.2", "--advance=1")),
                        ("rain 1 f40", ("--data=rain=1", "--advance=41")),
                        ("fog 1", ("--data=fog=1", "--advance=1")),
                        ("spring 1", ("--data=spring=1", "--advance=121")),
                        ("autumn 1", ("--data=autumn=1", "--advance=121")),
                        ("festive 1", ("--data=festive=1", "--advance=1")),
                        ("spring 1 noon", ("--data=spring=1", "--data=daylight=1", "--advance=121")),
                        ("autumn 1 dusk", ("--data=autumn=1", "--data=daylight=0.4", "--data=dusk=1", "--advance=121")),
                        ("parallax -1 / -1", ("--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=1")),
                        ("parallax +1 / +1", ("--data=parallaxX=1", "--data=parallaxY=1", "--advance=1"))):
        world.append(im(render(*args), label))
    grid(world, 7).save(out / "world_sheet.png")

    # ---- the pinwheel drag: pixels only inside the handle's rect; 1 wraps to 0 (history-free)
    x0, y0, x1, y1 = (int(v) for v in PINWHEEL_RECT)
    box = (x0 - 30, y0 - 30, x1 + 30, y1 + 30)
    drag_cells, worst, bbox = [], 0.0, None
    for v in (0.0, 0.125, 0.25, 0.5, 0.75, 1.0):
        a = render(f"--data=pinwheel={v}", "--advance=1")
        drag_cells.append(im(a, f"pinwheel {v}", (200, 200), box))
        changed = np.abs(a.astype(int) - rest.astype(int))[..., :3].max(-1) > 0  # type: ignore[union-attr]
        inside = changed.copy()
        changed[y0:y1, x0:x1] = False
        worst = max(worst, float(changed.mean()))
        if inside.any():
            ys_, xs_ = np.nonzero(inside)
            b = (int(xs_.min()), int(ys_.min()), int(xs_.max()) + 1, int(ys_.max()) + 1)
            bbox = b if bbox is None else (min(bbox[0], b[0]), min(bbox[1], b[1]), max(bbox[2], b[2]), max(bbox[3], b[3]))
    grid(drag_cells, 6).save(out / "pinwheel_drag.png")
    gates.append(f"pinwheel drag: pixels changed at pinwheel 0.125 .. 1 outside {PINWHEEL_RECT}: {worst:.4%} "
                 f"(changed bbox {bbox}) ({'ok' if worst == 0 and bbox is not None else 'FAIL'})")
    reg = (slice(y0, y1), slice(x0, x1))
    half = int(np.abs(render("--data=pinwheel=0.5", "--advance=1").astype(int) - rest.astype(int))[reg][..., :3]
               .max())  # type: ignore[union-attr]
    wrap = int(np.abs(render("--data=pinwheel=1", "--advance=1").astype(int) - rest.astype(int))[reg][..., :3]
               .max())  # type: ignore[union-attr]
    back = render("--data=pinwheel=0.6", "--advance=1", "--data=pinwheel=0", "--advance=2")
    back_diff = int(np.abs(back.astype(int) - render("--advance=2").astype(int))[reg][..., :3].max())  # type: ignore
    gates.append(f"pinwheel a half turn reads (four colours): max diff {half}/255 ({'ok' if half > 60 else 'FAIL'}); "
                 f"pinwheel 1 wraps to 0: max diff {wrap}/255 ({'ok' if wrap <= 24 else 'FAIL'}); "
                 f"0.6 -> 0 vs never turned: max diff {back_diff}/255 ({'ok' if back_diff <= 2 else 'FAIL'})")

    # ---- the moon at eight phases
    mx, my, _ = MOON
    moon_box = (int(mx - 60), int(my - 56), int(mx + 60), int(my + 56))
    moon_cells = [im(rest, "-1 (drawn)", (150, 140), moon_box)]
    for k in range(8):
        ph = k / 8
        moon_cells.append(im(render(f"--data=moonPhase={ph}", "--advance=1"), f"{ph:.3f}", (150, 140), moon_box))
    grid(moon_cells, 9).save(out / "moon_phases.png")

    # ---- the squirrel's six states, a move and its path
    cw, ch, dy = SQ_CROP
    sx, sy = SQ_WAYPOINTS[0][:2]
    npc_box = (int(sx - cw / 2), int(sy + dy - ch / 2), int(sx + cw / 2), int(sy + dy + ch / 2))
    npc_cells = []
    for label, args in (("rest", ("--advance=151",)), ("away", ("--data=npc=away", "--advance=31")),
                        ("idle", ("--data=npc=idle", "--advance=35")),
                        ("move f0", ("--data=npc=move", "--advance=31")), ("move f6", ("--data=npc=move", "--advance=37")),
                        ("move f12", ("--data=npc=move", "--advance=43")),
                        ("notice -1", ("--data=npc=notice", "--data=npcLook=-1", "--advance=31")),
                        ("notice +1", ("--data=npc=notice", "--data=npcLook=1", "--advance=31")),
                        ("react f20", ("--data=npc=react", "--advance=51")),
                        ("move look +1", ("--data=npc=move", "--data=npcLook=1", "--advance=37"))):
        npc_cells.append(im(render(*args), label, (220, 200), npc_box))
    grid(npc_cells, 5).save(out / "squirrel_states.png")
    path_cells = []
    for tx in (0.0, 0.12, 0.25, 0.5, 0.75, 0.88, 1.0):
        a = render("--data=npc=move", f"--data=npcX={tx}", "--advance=16")
        path_cells.append(im(a, f"move npcX {tx}"))
    path_cells.append(im(render("--data=npcX=1", "--data=npc=idle", "--advance=35"), "idle npcX 1"))
    grid(path_cells, 8).save(out / "squirrel_path.png")

    w = 270 * 5
    parts = [grid(ev_cells, 5), grid(world[:10], 5), grid(npc_cells, 5).resize((w, int(400 * w / 1100))),
             grid(moon_cells, 9).resize((w, int(140 * w / 1350))), grid(drag_cells, 6).resize((w, int(200 * w / 1200)))]
    sheet = Image.new("RGB", (w, sum(p.height for p in parts)), (20, 20, 20))
    yy = 0
    for p in parts:
        sheet.paste(p.resize((w, p.height)) if p.width != w else p, (0, yy))
        yy += p.height
    sheet.save(out / "contact_sheet.png")


REVIEW: dict[str, object] = {
    "diorama": {
        "patches": [("Plane5 fern", (110, 1760, 210, 1860), 40), ("Plane4 woodpile", (60, 1310, 280, 1440), 28),
                    ("Plane3 door", (850, 1000, 950, 1050), 20), ("Plane2 maple trunk", (120, 960, 230, 1060), 12),
                    ("Plane1 birch", (440, 900, 520, 1000), 6), ("Plane0 moon", (610, 180, 670, 240), 0)],
        "wet": ((860, 1560, 1060, 1700), 0.5, 0.9),
        # streak sheets 18 / 34, splash loops 120 frames: all back at frame 0 after 6120
        "rain_loops": [("RainLoop sheets + splashes", 6120)],
        "seam_box": (0, 1300, 1080, 1920),
    },
    "extras": review_extras,
    "time": {"sky_box": (450, 0, 1080, 360), "dusk_box": (450, 400, 600, 640), "noon_gain": 12.0, "ground_lift": 6.0},
    "npc": {"crop": SQ_CROP, "seam": {"idle": SQ_IDLE, "move": FLICKER_FRAMES, "notice": FLICKER_FRAMES,
                                      "react": FLICKER_FRAMES},
            "prop": "squirrel", "waypoints": SQ_WAYPOINTS},
}


if __name__ == "__main__":
    print("wrote", forestCabin())
