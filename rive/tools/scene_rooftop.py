"""Contract v12 scene `rooftop` (moonshot M9 Task 3b, lane S2): a flat city rooftop at night.

    uv run rive/tools/gen_scenes.py rooftop     # writes rive/scenes/rooftop/rooftop.rml

A brick parapet runs across the lower third; beyond it a layered skyline (the nearest building on
the left, a mid row with a water tower, a far row with a suspension bridge), a big moon upper-left,
stars and the city's warm glow on the horizon (`lightRim`). On the roof: a TV antenna on the left
(its red aircraft light blinks), the telescope on its tripod at the right (the `aim` drag swivels
its tube), the pigeon on the parapet (the NPC), a vent and a potted plant in the near corners.

Planes (`ROOFTOP_PLANES`): sky + moon 0, far skyline + bridge + fireworks 1, mid skyline 2, the near
building 3, roof + parapet + antenna + telescope + pigeon 4, foreground 5. Steady rain: streaks in
screen space, splashes on the parapet's cap and the roof, a wet sheen on the roof, an overcast sky,
and a `SceneFront` (near sheet + mist, `gen_scenes.front_weather`). `daylight` / `dusk` veil the sky
(`gen_scenes.sky_time`) and dim the city's lit windows; `fog` thickens the veils and raises a fog
bank in front of the mid skyline (`scene_npc.scene_fog`). `moonPhase` (world_kit.moon_rig) and the
drag number `aim` are the v12 binds (`BINDS`).

This module registers its scene in the shared registries on import: `gen_scenes.DIORAMAS`,
`gen_scenes.TIME_SKY` and `scene_npc.FOG_VEILS` / `FOG_BANKS` (dict entries for `rooftop` only),
and builds through `Scene.write` with `scene_art.refine_scene` swapped for this scene's own pass
(scene_art's refine knows the four M8 scenes only).
"""

from __future__ import annotations

from contextlib import contextmanager
import math
import os
import random
import sys
from typing import Iterator
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import gen_scenes  # noqa: E402
from gen_scenes import H, W, DioramaSpec, Scene, front_weather, rain_fx, streak_fx, uniq  # noqa: E402
from art_bible import SCENES, fit_colour  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
from rml import Doc, El, ellipse, lin  # noqa: E402
from scene_art import before, named  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds  # noqa: E402
import world_kit  # noqa: E402

SID = "rooftop"
O = (0.0, 0.0)

# ---------------------------------------------------------------- layout (artboard px)
CAP_TOP = 986.0            # the parapet's coping: the pigeon walks on it
CAP_BOTTOM = 1012.0
WALL_BOTTOM = 1162.0
ROOF_Y = 1150.0            # where the roof meets the parapet
MOON = (300.0, 300.0, 92.0)   # centre and radius of the moon
NEAR_TOP = 560.0           # the near building's roof (left, Plane3)
ANTENNA_X = 112.0
RAIN_COL = "88B8C8E0"      # the steady rain's streak colour (alpha replaced in the front layer)

# ---------------------------------------------------------------- the telescope (drag `aim`)
TELESCOPE_PIVOT = (868.0, 1168.0)   # the tripod head: the tube swivels about it
TUBE_REST = 0.698          # rad: the M9-M11 elevation at aim 0; the swing's centre (aim -1 / +1 = REST -/+ SWING)
AIM_SWING = 0.611          # rad per unit of `aim` (35 deg; a formula literal keeps 3 digits)
# M12 ruling 8 (lane Q): the elevation shown at aim 0 (52 deg): at 40 deg the dew shield's rim reached x 735,
# inside the avatar's band (x 330..750); now it ends at x ~758. The extremes stay REST -/+ SWING (aim -1 / +1),
# so the drag's rect (`aim_rect`, the contract's (710, 1011, 978, 1317)) is unchanged: aim < 0 swings
# (TUBE_SHOWN - REST + SWING) rad per unit, aim > 0 (REST + SWING - TUBE_SHOWN)
TUBE_SHOWN = 0.9
TUBE = (-150.0, 96.0, 21.0)  # local x of the objective end and of the eyepiece end, the dew shield's radius

# ---------------------------------------------------------------- the pigeon (NPC)
# feet on the cap, npcX 0 -> 1 (M12 ruling 8, lane Q: 16 px right of M9-M11's 800 -> 1000, so the resting pigeon's
# beak clears the avatar's band (x 330..750; its peck reaches ~746); the path keeps its 200 px, so the walk rate
# the director uses (`pigeon_walk_speed`, 0.354 npcX/s) holds)
PIGEON_WAYPOINTS = [(816.0, CAP_TOP, 1.0), (1016.0, CAP_TOP, 1.0)]
PIGEON_SCALE = 1.35        # the rig is drawn ~70 px long; on screen it is this much bigger
PIGEON_HIT = (0.0, -36.0, 130.0, 104.0)   # the poke zone: (dx, dy) from the feet, width, height
PIGEON_IDLE, PIGEON_WALK, PIGEON_NOTICE, PIGEON_REACT = 240, 32, 120, 48
PIGEON_STRIDE = 28.0       # rig px the body travels per walk cycle (two steps, head stabilised)

# ---------------------------------------------------------------- events and loops
FIREWORKS_FRAMES = 240
PLANE_FRAMES = 600
SHOOTING_STAR_FRAMES = 46
WINDOWS_LIT_FRAMES = 420
STARS_LOOP = 240
BEACON_LOOP = 150          # the antenna's red light: one slow blink per 2.5 s
CITY_BLINK_LOOP = 600      # a few windows switch on / off over 10 s
RAIN_LOOP_FRAMES = 120     # splash loops; the streak sheets loop on 18 / 34 frames (seam: 6120)
WET = ("FF0A0C16", 0.32)   # the roof's wet film and its opacity at rain 1
OVERCAST = ("FF3C4258", 0.38)   # the sky clouds over at rain 1
DAY_DIM = 0.75             # the lit windows fade by this x daylight
DAY_LIFT = ("FF4A4B5E", "FF3A3B4E")   # M10: the screen colour over the parapet (top) and the roof (bottom) at noon

ROOFTOP_PLANES: dict[str, int | None] = {
    "RainLoop": None,
    **dict.fromkeys(("Vent", "PotPlant"), 5),
    **dict.fromkeys(("Telescope", "PigeonNpc", "Antenna", "ParapetRain", "ParapetCapLight", "ParapetCap",
                     "ParapetBricks", "ParapetWall", "RoofWet", "ParapetShadow", "RoofSeam", "GravelLight",
                     "GravelDark", "RoofFloor", "RoofDay"), 4),
    **dict.fromkeys(("NearWarmth", "NearWindowsLit", "NearLights", "NearPanes", "NearFrames", "NearDish",
                     "NearCornice", "NearFacade"), 3),
    **dict.fromkeys(("MidBlink", "MidLightsWarm", "MidLightsDim", "MidLightsCool", "WaterTower", "MidRoof",
                     "MidBldg"), 2),
    **dict.fromkeys(("Fireworks", "BridgeLights", "Bridge", "FarLights", "FarCity", "FarHills"), 1),
    **dict.fromkeys(("Airliner", "ShootingStar", "SkyOvercast", "MoonRig", "MoonDrawn", "MoonGlow", "Glint", "Star",
                     "CityGlow", "Sky"), 0),
    # each hit zone rides the plane of its prop's art (M5 ruling 3)
    "Hit_telescope": 4, "Hit_antenna": 4, "Hit_pigeon": 4, "Hit_moon": 0,
}
ROOFTOP_EMISSIVE = ("Star", "Glint", "MoonDrawn", "MoonGlow", "CityGlow", "ShootingStar", "Airliner", "Fireworks",
                    "BridgeLights", "FarLights", "MidLightsWarm", "MidLightsDim", "MidLightsCool", "MidBlink",
                    "NearLights", "NearWindowsLit", "NearWarmth", "AntennaLight", "LensGlint")
# the night haze (`lightFog`) over the sky and the far rows; the near building and the roof stay crisp
ROOFTOP_VEILS = ((0.3, 480.0, 1000.0), (0.2, 760.0, 1000.0), (0.12, 800.0, 1030.0))

# contract v12: the v12 members this file binds (world_kit.declared_binds; Scene.write and
# check_contract.py hold the file to it)
BINDS: set[str] = {"moonPhase", *world_kit.drag_numbers(SID)}
# M11 ruling 13 (contract v14 `tier`): what the shared tier pass (world_kit.tier_gate) hides. "high": at
# high and low (the second rain / snow sheet, the second half of the splashes and of every twinkle or
# particle loop's copies, by full name); "low": at low only (decorative ambient loops that are not light).
TIER_GATES: dict[str, tuple[str, ...]] = {
    "high": ("RainSheet1", *(f"Splash{i}" for i in range(8, 16)), *(f"CapSplash{i}" for i in range(7, 14)),
             *(f"FrontSplash{i}" for i in range(5, 10)), *(f"Star{i}" for i in range(35, 61, 5)), "Glint2", "Glint3",
             *(f"MidBlink{i}" for i in range(3, 6))),
    "low": (),   # nothing decorative that is not light (the beacon, the windows, the stars are); the veils thin
}


# ====================================================================== drawing helpers
def _rect(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, paint: El, r: float = 0.0,
          **kw: object) -> El:
    d = sc.d
    return d("Shape", d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), cornerRadiusTL=float(r),
                        cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
             paint, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), name=name, **kw)


def _vfill(sc: Scene, y0: float, y1: float, cy: float, stops: list[tuple[str, float]]) -> El:
    """A vertical gradient spanning artboard y0..y1 in a shape centred at artboard y `cy`."""
    return sc.vgrad(y0 - cy, y1 - cy, stops)


def _rects(sc: Scene, name: str, rects: list[tuple[float, float, float, float]], paint: El, r: float = 0.0,
           **kw: object) -> El:
    """One shape, one paint, many rectangles (windows, lights): cheaper than a shape each."""
    d = sc.d
    paths = [d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2),
               y=float((y0 + y1) / 2), cornerRadiusTL=float(r) if r else None, cornerRadiusTR=float(r) if r else None,
               cornerRadiusBL=float(r) if r else None, cornerRadiusBR=float(r) if r else None, name="Path")
             for x0, y0, x1, y1 in rects]
    return d("Shape", *paths, paint, x=0.0, y=0.0, name=name, **kw)


def _dots(sc: Scene, name: str, pts: list[tuple[float, float, float]], paint: El, **kw: object) -> El:
    """One shape of many ellipses (x, y, diameter)."""
    d = sc.d
    paths = [d("Ellipse", width=float(s), height=float(s * 0.8), x=float(x), y=float(y), name="Path")
             for x, y, s in pts]
    return d("Shape", *paths, paint, x=0.0, y=0.0, name=name, **kw)


def _lines(sc: Scene, name: str, segs: list[tuple[float, float, float, float]], colour: str, w: float,
           **kw: object) -> El:
    """One stroked shape of many straight segments (artboard px)."""
    d = sc.d
    paths = [d("PointsPath", d("StraightVertex", x=float(x0), y=float(y0)), d("StraightVertex", x=float(x1), y=float(y1)),
               isClosed=False, name="Path") for x0, y0, x1, y1 in segs]
    return d("Shape", *paths, sc.L(colour, w), x=0.0, y=0.0, name=name, **kw)


def _hfill(sc: Scene, x0: float, x1: float, cx: float, stops: list[tuple[str, float]]) -> El:
    return sc.d("Fill", lin(sc.d, x0 - cx, 0, x1 - cx, 0, stops), name="Fill")


def _mix(a: str, b: str, t: float) -> str:
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4, 6)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4, 6)]
    return "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ca, cb))


SKY_STOPS = [("FF0C1230", 0.0), ("FF151C42", 0.45), ("FF2A2A58", 0.78), ("FF4A3A66", 1.0)]   # y 0 .. 1000


def sky_at(y: float) -> str:
    """The sky gradient's colour at artboard y (before the colour-script fit)."""
    t = min(1.0, max(0.0, y / 1000.0))
    for (c0, p0), (c1, p1) in zip(SKY_STOPS, SKY_STOPS[1:]):
        if t <= p1:
            return _mix(c0, c1, (t - p0) / (p1 - p0))
    return SKY_STOPS[-1][0]


def _moon_parts(sc: Scene, parent: tuple[float, float], cx: float, cy: float, r: float, tag: str) -> list[El]:
    """The full moon (front-most first): soft maria and a few craters over a cream disc."""
    E, F = sc.E, sc.F
    marks = [(-0.32, -0.18, 0.42, "2A9C9686"), (0.18, -0.34, 0.3, "229C9686"), (0.26, 0.22, 0.46, "2A9C9686"),
             (-0.2, 0.36, 0.26, "209C9686")]
    craters = [(-0.5, 0.12, 0.13), (0.42, -0.06, 0.1), (0.04, 0.58, 0.09), (-0.06, -0.62, 0.08)]
    out = []
    for i, (dx, dy, s) in enumerate(craters):
        out.append(E(parent, f"{tag}Crater{i}", cx + dx * r, cy + dy * r, s * 2 * r, s * 2 * r,
                     F("2E8A8476"), sc.L("40FFFFFF", 1.4)))
    for i, (dx, dy, s, col) in enumerate(marks):
        out.append(E(parent, f"{tag}Mare{i}", cx + dx * r, cy + dy * r, s * 2 * r, s * 1.6 * r, F(col)))
    out.append(E(parent, f"{tag}Disc", cx, cy, 2 * r, 2 * r,
                 sc.rgrad(r * 1.15, [("FFFAF6EC", 0.0), ("FFE6E0D2", 1.0)], cx=-r * 0.25, cy=-r * 0.25)))
    return out


# ====================================================================== the scene
def rooftop() -> str:
    sc = Scene(SID)
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    rnd = random.Random(29)

    # ------------------------------------------------------------ Plane0: sky, stars, moon
    sky = _rect(sc, "Sky", -60, -60, W + 60, H + 60, _vfill(sc, 0, 1000, (H) / 2, SKY_STOPS))
    city_glow = _rect(sc, "CityGlow", -60, 600, W + 60, 1080,
                      _vfill(sc, 600, 1080, 840, [("00FFB27A", 0.0), ("FFFFB27A", 0.72), ("FFFFB27A", 1.0)]))
    next(c for c in city_glow.children if c.tag == "Fill").children[0].attrs["opacity"] = 0.55
    mx, my, mr = MOON
    stars: list[El] = []
    twinkle: list[El] = []
    while len(stars) < 64:
        x, y = rnd.uniform(0, W), rnd.uniform(30, 780)
        if math.hypot(x - mx, y - my) < mr + 70 or (x < 330 and y > NEAR_TOP - 20):
            continue
        r = rnd.choice([2.0, 2.4, 2.8, 3.4, 4.2])
        i = len(stars)
        st = E(O, f"Star{i}", x, y, r, r, F("FFFFF6E0" if i % 3 else "FFD8E4FF"), opacity=round(rnd.uniform(0.4, 1.0), 3))
        stars.append(st)
        if i % 5 == 0:
            ph = rnd.randint(0, 200)
            base = float(st.attrs["opacity"])
            twinkle.append(sc.T(st, opacity=uniq([(0, base), (STARS_LOOP, base), ((ph + 40) % STARS_LOOP, 0.15),
                                                  ((ph + 80) % STARS_LOOP, base)])))
    glints = []
    for i, (x, y) in enumerate([(640, 150), (930, 300), (520, 640), (80, 120)]):
        g = d("Node", S((x, y), "H", [(x - 12, y), (x + 12, y)], L("CCFFF6E0", 1.8), closed=False),
              S((x, y), "V", [(x, y - 12), (x, y + 12)], L("CCFFF6E0", 1.8), closed=False),
              x=float(x), y=float(y), name=f"Glint{i}")
        glints.append(g)
        twinkle.append(sc.T(g, scaleX=[(0, 1.0), (50 + 40 * i, 0.4), (100 + 40 * i, 1.0), (STARS_LOOP, 1.0)],
                            scaleY=[(0, 1.0), (50 + 40 * i, 0.4), (100 + 40 * i, 1.0), (STARS_LOOP, 1.0)]))
    sc.ambient("Stars", sc.A("amb_stars", STARS_LOOP, twinkle, loop=True))
    # its stops take `lightKey` in the light hook (the gradient's opacity carries the alpha)
    moon_glow = E(O, "MoonGlow", mx, my, 540, 540, sc.rgrad(270, [("FFDCE4FF", 0.0), ("00DCE4FF", 1.0)]))
    next(c for c in moon_glow.children if c.tag == "Fill").children[0].attrs["opacity"] = 0.24
    # contract v12 `moonPhase`: the drawn full moon at -1, the phase rig at 0..1 (ruling 12)
    moon_drawn = world_kit.hide_when_phased(sc, sc.d9, "MoonDrawn", _moon_parts(sc, O, mx, my, mr, "Moon"))
    with sc.minting(sc.d9):
        lit = sc.d9("Node", *_moon_parts(sc, (mx, my), mx, my, mr, "Phase"), x=0.0, y=0.0, name="MoonLit")
    dark = "E6" + fit_colour(sky_at(my), SID)[2:]
    moon_rig = world_kit.moon_rig(sc, sc.d9, mx, my, mr, lit, dark)

    # ------------------------------------------------------------ events in the sky
    star_node, star_anim = streak_fx(sc, "ShootingStar", (1010.0, 130.0), (600.0, 400.0), SHOOTING_STAR_FRAMES,
                                     240, "FFFFF6D0", "CCFFF6D0", 7)
    sc.one_shot("shootingStar", star_anim)
    airliner, plane_anim = _airliner(sc)
    sc.one_shot("plane", plane_anim)

    # ------------------------------------------------------------ Plane1: far hills, far city, bridge
    hill_pts: list[tuple] = [(-60, 1060, "c"), (-60, 905)]
    hr = random.Random(5)
    x = -60.0
    while x < W + 60:
        x += 110
        hill_pts.append((x, 905 + hr.uniform(-20, 14)))
    hill_pts.append((W + 60, 1060, "c"))
    far_hills = S(O, "FarHills", hill_pts, F("FF232A4C"))
    far_pts: list[tuple] = [(-60, 1060, "c")]
    lights_far = []
    x = -60.0
    fr = random.Random(17)
    while x < W + 60:
        w = fr.uniform(38, 86)
        top = fr.uniform(852, 944)
        far_pts += [(x, top, "c"), (x + w, top, "c")]
        for _ in range(int(w // 22)):
            if fr.random() < 0.55:
                lx, ly = fr.uniform(x + 6, x + w - 8), fr.uniform(top + 8, 990)
                lights_far.append((lx, ly, lx + 3, ly + 4))
        x += w
    far_pts.append((W + 60, 1060, "c"))
    far_cy = (min(p[1] for p in far_pts) + 1060) / 2   # the shape's origin: the middle of its bounding box
    far_city = S(O, "FarCity", far_pts, _vfill(sc, 850, 1060, far_cy, [("FF2C3358", 0.0), ("FF242A4A", 1.0)]))
    far_lights = _rects(sc, "FarLights", lights_far, F("90FFD28A"))
    bridge, bridge_lights = _bridge(sc)
    fireworks, fw_anim = _fireworks(sc)
    sc.one_shot("fireworks", fw_anim)

    # ------------------------------------------------------------ Plane2: the mid row, water tower
    mid_bldgs = [(-60, 70, 700), (60, 180, 780), (300, 386, 770), (378, 470, 824), (462, 548, 744), (540, 612, 860),
                 (604, 706, 902), (698, 796, 930), (788, 884, 900), (876, 952, 940), (944, W + 60, 726)]
    mids, warm, dim, cool, blink_cands = [], [], [], [], []
    mr_ = random.Random(23)
    for i, (x0, x1, top) in enumerate(mid_bldgs):
        shade = _mix("FF1E2446", "FF191E3A", (i % 3) / 2)
        cy = (top + 1040) / 2
        mids.append(_rect(sc, f"MidBldg{i}", x0, top, x1, 1040, _vfill(sc, top, 1040, cy, [(shade, 0.0), ("FF151A30", 1.0)])))
        for col_x in range(int(x0) + 10, int(x1) - 14, 18):
            for row_y in range(int(top) + 14, 1000, 24):
                p = mr_.random()
                rect = (col_x, row_y, col_x + 8, row_y + 11)
                if p < 0.16:
                    warm.append(rect)
                elif p < 0.3:
                    dim.append(rect)
                elif p < 0.33:
                    cool.append(rect)
                elif 300 <= col_x <= 640 and 770 <= row_y <= 900:
                    blink_cands.append(rect)
    roof_bits = _lines(sc, "MidRoof", [(330, 770, 330, 728), (330, 728, 346, 728), (420, 824, 420, 796),
                                       (500, 744, 500, 700), (494, 712, 506, 712), (30, 700, 30, 664)], "FF1A1F3A", 3)
    mid_warm = _rects(sc, "MidLightsWarm", warm, F("D0FFC874"))
    mid_dim = _rects(sc, "MidLightsDim", dim, F("66FFC874"))
    mid_cool = _rects(sc, "MidLightsCool", cool, F("60A8CCFF"))
    blink, blink_tracks = [], []
    picks = random.Random(41).sample(blink_cands, 6)
    for i, (x0, y0, x1, y1) in enumerate(sorted(picks)):
        # half start lit and switch off for a while, half start dark and switch on (seamless)
        a0, a1 = (0.85, 0.0) if i % 2 == 0 else (0.0, 0.85)
        b = _rect(sc, f"MidBlink{i}", x0, y0, x1, y1, F("FFFFC874"), opacity=a0)
        blink.append(b)
        t1 = 40 + i * 70
        t2 = t1 + 160
        blink_tracks.append(sc.T(b, ease=None, opacity=[(0, a0, "linear"), (t1, a0, "linear"), (t1 + 40, a1, "linear"),
                                                         (t2, a1, "linear"), (t2 + 40, a0, "linear"),
                                                         (CITY_BLINK_LOOP, a0)]))
    sc.ambient("CityBlink", sc.A("amb_cityBlink", CITY_BLINK_LOOP, blink_tracks, loop=True))
    water_tower = _water_tower(sc)

    # ------------------------------------------------------------ Plane3: the near building (left)
    near = _near_building(sc)

    # ------------------------------------------------------------ Plane4: roof, parapet, antenna, telescope
    roof = _roof(sc)
    antenna = _antenna(sc)
    telescope = _telescope(sc)

    # ------------------------------------------------------------ Plane5: the near corners
    vent, pot = _vent(sc), _pot_plant(sc)

    # ------------------------------------------------------------ props
    hit_telescope = sc.hit("telescope", 842, 1162, 250, 290)
    sc.prop("telescope", hit_telescope)
    hit_antenna = sc.hit("antenna", ANTENNA_X, 730, 200, 560)
    sc.prop("antenna", hit_antenna)
    px0, py0, _ = PIGEON_WAYPOINTS[0]
    hit_pigeon = sc.hit("pigeon", px0 + PIGEON_HIT[0], py0 + PIGEON_HIT[1], PIGEON_HIT[2], PIGEON_HIT[3])
    sc.prop("pigeon", hit_pigeon)
    hit_moon = sc.hit("moon", mx, my, 2 * mr + 50, 2 * mr + 50)
    sc.prop("moon", hit_moon)

    content = [vent, pot,
               telescope, antenna, *roof,
               *near,
               *blink, mid_warm, mid_dim, mid_cool, water_tower, roof_bits, *mids,
               fireworks, bridge_lights, bridge, far_lights, far_city, far_hills,
               airliner, star_node, moon_rig, moon_drawn, moon_glow, *glints, *stars, city_glow, sky]
    front_weather(sc, RAIN_COL)
    sc.npc_rig = rooftop_pigeon
    sc.v13_art = rooftop_day_lift   # M10 (ruling 15): daylight lifts the roof and the parapet
    with _own_refine():
        return sc.write(content, [hit_telescope, hit_antenna, hit_pigeon, hit_moon])


@contextmanager
def _own_refine() -> Iterator[None]:
    """`Scene.write` runs `scene_art.refine_scene`, which knows the four M8 scenes only: this scene's
    art is drawn at its final stroke weights, so its refine pass leaves the content as it is."""
    orig = gen_scenes.refine_scene
    gen_scenes.refine_scene = lambda sc, content: None
    try:
        yield
    finally:
        gen_scenes.refine_scene = orig


# ====================================================================== art pieces
def _airliner(sc: Scene) -> tuple[El, El]:
    """`plane`: an airliner's lights cross the sky right to left, high above the city (10 s):
    red and green wing lights, a white strobe and a red beacon blinking out of step."""
    d, E, F = sc.d, sc.E, sc.F
    x0, y0, x1, y1 = W + 80.0, 250.0, -80.0, 150.0
    body = sc.S(O, "Body", [(-16, 0), (-8, -2.5), (14, -2), (18, 0), (14, 2), (-8, 2.5)], F("C00A0E20"))
    wing = sc.S(O, "Wing", [(-2, -1), (4, -9), (8, -9), (6, 0), (8, 9), (4, 9), (-2, 1)], F("A00A0E20"))

    def light(name: str, x: float, y: float, col: str, r: float) -> El:
        return d("Node", E(O, "Bulb", 0, 0, r, r, F(col)),
                 E(O, "Halo", 0, 0, r * 6, r * 6, sc.rgrad(r * 3, [("70" + col[2:], 0.0), ("00" + col[2:], 1.0)])),
                 x=float(x), y=float(y), name=name)
    red, green = light("NavRed", 5, -9, "FFFF5048", 4.0), light("NavGreen", 5, 9, "FF6CFFA0", 4.0)
    strobe = light("Strobe", -14, 0, "FFFFFFFF", 5.0)
    beacon = light("Beacon", 2, -3, "FFFF3A30", 3.2)
    strobe.attrs["opacity"] = 0.0
    beacon.attrs["opacity"] = 0.0
    n = d("Node", strobe, beacon, red, green, wing, body, x=x0, y=y0, rotation=-0.08, scaleX=1.6, scaleY=1.6,
          opacity=0.0, name="Airliner")
    st_keys, bc_keys = [(0, 0.0)], [(0, 0.0)]
    for c in range(30, PLANE_FRAMES - 20, 64):
        st_keys += [(c, 0.0, "hold"), (c + 1, 1.0, "hold"), (c + 4, 0.0, "hold"), (c + 9, 1.0, "hold"), (c + 12, 0.0, "hold")]
        bc_keys += [(c + 30, 0.0, "hold"), (c + 31, 1.0, "linear"), (c + 44, 0.0, "hold")]
    anim = sc.A("ev_plane", PLANE_FRAMES, [
        sc.T(n, ease=None, x=[(0, x0, "linear"), (PLANE_FRAMES, x1)], y=[(0, y0, "linear"), (PLANE_FRAMES, y1)],
             opacity=[(0, 0.0, "linear"), (24, 1.0, "linear"), (PLANE_FRAMES - 24, 1.0, "linear"), (PLANE_FRAMES, 0.0)]),
        sc.T(strobe, ease=None, opacity=uniq(st_keys + [(PLANE_FRAMES, 0.0)])),
        sc.T(beacon, ease=None, opacity=uniq(bc_keys + [(PLANE_FRAMES, 0.0)])),
    ])
    return n, anim


def _bridge(sc: Scene) -> tuple[El, El]:
    """The far suspension bridge (right), its cable lights and the red lights atop its towers."""
    towers = (640.0, 880.0)
    deck_y, top_y = 912.0, 792.0
    x_l, x_r = 470.0, W + 60.0

    def cable_y(x: float) -> float:
        if x <= towers[0]:
            t = (towers[0] - x) / (towers[0] - x_l)
            return top_y + (884 - top_y) * (1 - (1 - t) ** 2)
        if x >= towers[1]:
            t = (x - towers[1]) / (x_r - towers[1])
            return top_y + (880 - top_y) * (1 - (1 - t) ** 2)
        mid = (towers[0] + towers[1]) / 2
        t = (x - mid) / (mid - towers[0])
        return 886 - (886 - top_y) * t * t

    pts = [(x, cable_y(x)) for x in range(int(x_l), int(x_r) + 1, 20)]
    segs = [(x0, y0, x1, y1) for (x0, y0), (x1, y1) in zip(pts, pts[1:])]
    col = "FF2E3662"
    hangers = [(x, cable_y(x), x, deck_y) for x in range(int(x_l) + 20, int(x_r), 26)
               if all(abs(x - t) > 10 for t in towers)]
    legs = []
    for t in towers:
        legs += [(t - 13, top_y - 4, t - 5, deck_y + 30), (t + 5, deck_y + 30, t + 13, top_y - 4)]
    tower_shapes = _rects(sc, "BridgeTowers", legs, sc.F(col))
    braces = _lines(sc, "BridgeBraces", [(t - 9, y, t + 9, y) for t in towers for y in (812.0, 850.0, 884.0)], col, 3)
    cable = _lines(sc, "BridgeCable", segs, col, 3.2)
    hanger = _lines(sc, "BridgeHangers", hangers, "B02E3662", 1.2)
    deck = _rects(sc, "BridgeDeck", [(x_l, deck_y, x_r, deck_y + 9)], sc.F("FF2A3058"))
    bridge = sc.d("Node", braces, tower_shapes, cable, hanger, deck, x=0.0, y=0.0, name="Bridge")
    dots = [(x, cable_y(x) + 1, 3.2) for x in range(int(x_l) + 30, int(x_r), 46)] + \
        [(x, deck_y + 4, 2.6) for x in range(int(x_l) + 12, int(x_r), 30)]
    lights = sc.d("Node", _dots(sc, "Warm", dots, sc.F("C8FFDCA0")),
                  _dots(sc, "Top", [(t, top_y - 8, 5.0) for t in towers], sc.F("FFFF5A48")),
                  x=0.0, y=0.0, name="BridgeLights")
    return bridge, lights


def _fireworks(sc: Scene) -> tuple[El, El]:
    """`fireworks`: three shells rise over the skyline and burst (rings of sparks and streaks that
    grow, droop and fade), in the scene's palette."""
    d, E, F = sc.d, sc.E, sc.F
    shells = [(520.0, 440.0, 0, "FF7CB8FF", "FFDCEBFF", 130.0), (860.0, 590.0, 42, "FFFFB27A", "FFFFE08A", 110.0),
              (700.0, 250.0, 88, "FFFF8FB8", "FFB79CFF", 100.0)]
    nodes, tracks = [], []
    for k, (bx, by, t0, c1, c2, R) in enumerate(shells):
        tb = t0 + 28                       # the burst
        trail = d("Node", E(O, "Spark", 0, 0, 7, 7, F("FFFFF2D0")),
                  sc.S(O, "Tail", [(0, 2), (0, 34)], sc.L("90FFE6B0", 3), closed=False),
                  x=bx, y=880.0, opacity=0.0, name=f"Rise{k}")
        dots = [E(O, f"Dot{i}", R * math.cos(2 * math.pi * i / 14), R * math.sin(2 * math.pi * i / 14), 10, 10, F(c1))
                for i in range(14)]
        streaks = []
        for i in range(10):
            a = 2 * math.pi * (i + 0.5) / 10
            r0, r1 = 0.42 * R, 0.68 * R
            streaks.append(sc.S(O, f"Streak{i}", [(r0 * math.cos(a), r0 * math.sin(a)), (r1 * math.cos(a), r1 * math.sin(a))],
                                sc.L(c2, 3.2), closed=False))
        flash = E(O, "Flash", 0, 0, 2.4 * R, 2.4 * R, sc.rgrad(1.2 * R, [("60" + c1[2:], 0.0), ("00" + c1[2:], 1.0)]),
                  opacity=0.0)
        inner = d("Node", *streaks, x=0.0, y=0.0, name="Inner")
        burst = d("Node", *dots, inner, x=bx, y=by, scaleX=0.05, scaleY=0.05, opacity=0.0, name=f"Burst{k}")
        flash_n = d("Node", flash, x=bx, y=by, name=f"FlashAt{k}")
        nodes += [trail, burst, flash_n]
        tracks += [
            sc.T(trail, ease=None, y=uniq([(t0, 880.0, sc.ease_out), (0, 880.0, "hold"), (tb, by, "hold")]),
                 opacity=uniq([(t0, 0.0, "hold"), (0, 0.0, "hold"), (t0 + 1, 1.0, "linear"), (tb - 2, 1.0, "linear"),
                               (tb, 0.0, "hold")])),
            sc.T(burst, ease=None,
                 scaleX=[(0, 0.05, "hold"), (tb, 0.05, "hold"), (tb + 1, 0.12, sc.ease_out), (tb + 34, 1.0, "linear"), (tb + 100, 1.12)],
                 scaleY=[(0, 0.05, "hold"), (tb, 0.05, "hold"), (tb + 1, 0.12, sc.ease_out), (tb + 34, 1.0, "linear"), (tb + 100, 1.12)],
                 y=[(0, by, "hold"), (tb + 20, by, "linear"), (tb + 100, by + 26)],
                 opacity=[(0, 0.0, "hold"), (tb, 0.0, "hold"), (tb + 1, 1.0, "linear"), (tb + 40, 1.0, "linear"), (tb + 100, 0.0)]),
            sc.T(inner, ease=None, scaleX=[(0, 1.0, "hold"), (tb + 20, 1.0, "linear"), (tb + 80, 0.82)],
                 scaleY=[(0, 1.0, "hold"), (tb + 20, 1.0, "linear"), (tb + 80, 0.82)]),
            sc.T(flash, ease=None, opacity=[(0, 0.0, "hold"), (tb, 0.0, "hold"), (tb + 2, 1.0, "linear"), (tb + 36, 0.0)]),
        ]
    n = d("Node", *nodes, x=0.0, y=0.0, name="Fireworks")
    return n, sc.A("ev_fireworks", FIREWORKS_FRAMES, tracks)


def _water_tower(sc: Scene) -> El:
    """A wooden water tank on stilts atop the tall mid building at the right (Plane2)."""
    S, F = sc.S, sc.F
    tx = 1012.0
    col, rim = "FF1C2140", "FF343C66"
    tank = _rect(sc, "Tank", tx - 45, 620, tx + 45, 706, sc.d("Fill", lin(sc.d, -45, 0, 45, 0,
                                                                          [(rim, 0.0), (col, 0.35), ("FF161A32", 1.0)]),
                                                           name="Fill"), 6)
    roof = S(O, "TankRoof", [(tx - 51, 624, "c"), (tx, 588), (tx + 51, 624, "c")], F("FF181C36"))
    bands = _lines(sc, "TankBands", [(tx - 43, 644, tx + 43, 644), (tx - 43, 686, tx + 43, 686)], "FF12162A", 3)
    legs = _lines(sc, "TankLegs", [(tx - 35, 706, tx - 39, 728), (tx + 35, 706, tx + 39, 728), (tx, 706, tx, 728),
                                   (tx - 37, 718, tx + 37, 718)], "FF161A30", 4)
    return sc.d("Node", roof, bands, tank, legs, x=0.0, y=0.0, name="WaterTower")


def _near_building(sc: Scene) -> list[El]:
    """The nearest building (left, Plane3): brick facade, cornice, a dish on the roof, a 3 x 6 grid of
    windows (four lit at rest; the `windowsLit` event lights the rest one after another)."""
    d, S, E, F = sc.d, sc.S, sc.E, sc.F
    x0, x1 = -60.0, 318.0
    facade = _rect(sc, "NearFacade", x0, NEAR_TOP, x1, 1060,
                   _vfill(sc, NEAR_TOP, 1060, (NEAR_TOP + 1060) / 2, [("FF2C2438", 0.0), ("FF231C2E", 1.0)]))
    cornice = d("Node", _rect(sc, "Ledge", x0, NEAR_TOP - 12, x1 + 10, NEAR_TOP + 6, F("FF3A3046"), 2),
                _lines(sc, "Edge", [(x0, NEAR_TOP - 11, x1 + 9, NEAR_TOP - 11)], "70C4D4FF", 2),
                x=0.0, y=0.0, name="NearCornice")
    dish = d("Node", S(O, "DishBowl", [(212, 520), (246, 506), (262, 530), (232, 540)], F("FF3E3852")),
             _lines(sc, "DishArm", [(236, 528, 250, 512), (236, 532, 236, NEAR_TOP - 12)], "FF3E3852", 3),
             x=0.0, y=0.0, name="NearDish")
    cols, rows = (28.0, 118.0, 208.0), (600.0, 668.0, 736.0, 804.0, 872.0, 940.0)
    wins = [(c, r, c + 56, r + 46) for r in rows for c in cols]
    frames = _rects(sc, "NearFrames", [(a - 4, b - 4, c + 4, e + 4) for a, b, c, e in wins], F("FF3C3250"), 3)
    panes = _rects(sc, "NearPanes", wins, F("FF12131F"))
    lit_at_rest = {1, 5, 9, 16}
    lit = _rects(sc, "NearLights", [w for i, w in enumerate(wins) if i in lit_at_rest], F("FFF8C47C"))
    # the event: the dark windows light one after another, bottom row first, then go off together
    order = [i for i in (15, 16, 17, 14, 13, 12, 9, 10, 11, 8, 7, 6, 3, 4, 5, 2, 1, 0) if i not in lit_at_rest]
    overlays, tracks = [], []
    for k, i in enumerate(order):
        a, b, c, e = wins[i]
        o = _rect(sc, f"WinLit{i}", a, b, c, e, _vfill(sc, b, e, (b + e) / 2, [("FFFFD488", 0.0), ("FFF0A860", 1.0)]),
                  opacity=0.0)
        overlays.append(o)
        on = 12 + 14 * k
        off = 330 + 3 * k
        tracks.append(sc.T(o, ease=None, opacity=[(0, 0.0), (on, 0.0, "hold"), (on + 1, 0.4, "linear"), (on + 3, 0.15, "linear"),
                                                  (on + 6, 1.0, "linear"), (off, 1.0, "linear"), (off + 40, 0.0)]))
    lit_node = d("Node", *overlays, x=0.0, y=0.0, name="NearWindowsLit")
    warmth = E(O, "NearWarmth", 130, 780, 560, 620, sc.rgrad(280, [("38FFB060", 0.0), ("00FFB060", 1.0)]), opacity=0.0)
    tracks.append(sc.T(warmth, ease=None, opacity=[(0, 0.0), (12, 0.0, "linear"), (12 + 14 * len(order), 1.0, "linear"),
                                                   (330, 1.0, "linear"), (WINDOWS_LIT_FRAMES - 10, 0.0)]))
    sc.one_shot("windowsLit", sc.A("ev_windowsLit", WINDOWS_LIT_FRAMES, tracks))
    return [warmth, lit_node, lit, panes, frames, dish, cornice, facade]


def _roof(sc: Scene) -> list[El]:
    """The parapet (coping, brick wall) and the tar roof in front of it, front-most first."""
    cap = _rect(sc, "ParapetCap", -60, CAP_TOP, W + 60, CAP_BOTTOM,
                _vfill(sc, CAP_TOP, CAP_BOTTOM, (CAP_TOP + CAP_BOTTOM) / 2, [("FF6E6A86", 0.0), ("FF4C4864", 1.0)]), 3)
    cap_light = _lines(sc, "ParapetCapLight", [(-60, CAP_TOP + 1.5, W + 60, CAP_TOP + 1.5)], "80C4D4FF", 2.2)
    wall = _rect(sc, "ParapetWall", -60, CAP_BOTTOM - 4, W + 60, WALL_BOTTOM,
                 _vfill(sc, CAP_BOTTOM, WALL_BOTTOM, (CAP_BOTTOM - 4 + WALL_BOTTOM) / 2,
                        [("FF4A3042", 0.0), ("FF2E2032", 1.0)]))
    segs = []
    ys = [CAP_BOTTOM + 19 * k for k in range(1, 8) if CAP_BOTTOM + 19 * k < WALL_BOTTOM]
    for y in ys:
        segs.append((-60, y, W + 60, y))
    for j, y in enumerate([CAP_BOTTOM, *ys]):
        y1 = min(y + 19, WALL_BOTTOM)
        for x in range(-60 + (j % 2) * 28, W + 60, 56):
            segs.append((x, y + 1, x, y1 - 1))
    bricks = _lines(sc, "ParapetBricks", segs, "3A0E0810", 2)
    shadow = _rect(sc, "ParapetShadow", -60, ROOF_Y, W + 60, ROOF_Y + 90,
                   _vfill(sc, ROOF_Y, ROOF_Y + 90, ROOF_Y + 45, [("A0080810", 0.0), ("00080810", 1.0)]))
    floor = _rect(sc, "RoofFloor", -60, ROOF_Y, W + 60, H + 70,
                  _vfill(sc, ROOF_Y, H + 70, (ROOF_Y + H + 70) / 2, [("FF2E2E44", 0.0), ("FF22223A", 0.4), ("FF17172A", 1.0)]))
    vp = (540.0, 620.0)
    seam = [(vp[0] + (xb - vp[0]) * (ROOF_Y + 10 - vp[1]) / (H + 70 - vp[1]), ROOF_Y + 10, xb, H + 70)
            for xb in range(-900, 2000, 300)]
    seam += [(-60, y, W + 60, y) for y in (1236.0, 1352.0, 1520.0, 1760.0)]
    seams = _lines(sc, "RoofSeam", seam, "38090A14", 2.5)
    gr = random.Random(13)
    light, darkp = [], []
    for i in range(90):
        y = gr.uniform(ROOF_Y + 20, H + 40)
        s = 2.0 + 4.0 * (y - ROOF_Y) / (H - ROOF_Y)
        (light if i % 2 else darkp).append((gr.uniform(-40, W + 40), y, s))
    gl = _dots(sc, "GravelLight", light, sc.F("30B8B4CC"))
    gd = _dots(sc, "GravelDark", darkp, sc.F("40080810"))
    return [cap_light, cap, bricks, wall, shadow, seams, gl, gd, floor]


def _antenna(sc: Scene) -> El:
    """A TV antenna clamped to the parapet (left): a mast, two fishbone booms, guy wires, and the red
    aircraft light at the top blinking slowly (an ambient loop)."""
    d, E, F = sc.d, sc.E, sc.F
    x = ANTENNA_X
    metal = "FF7C8298"
    mast = _lines(sc, "Mast", [(x, CAP_TOP, x, 452)], metal, 6)
    booms = _lines(sc, "Booms", [(36, 522, 196, 522), (58, 604, 170, 604), (76, 664, 148, 664)], metal, 4)
    rods = _lines(sc, "Rods", [(rx, 508, rx, 536) for rx in range(48, 190, 22)] +
                  [(rx, 594, rx, 614) for rx in range(66, 166, 24)], "FF6A7088", 3)
    box = _rect(sc, "Balun", x - 9, 656, x + 9, 676, F("FF4A5064"), 3)
    wires = _lines(sc, "GuyWires", [(x, 720, 26, CAP_TOP - 2), (x, 720, 204, CAP_TOP - 2)], "A0606678", 1.6)
    clamp = _rect(sc, "Clamp", x - 15, CAP_TOP - 34, x + 15, CAP_TOP + 4, F("FF4C5266"), 4)
    lit = _lines(sc, "MastLight", [(x - 2, CAP_TOP - 40, x - 2, 470)], "50C4D4FF", 1.6)
    bulb = E(O, "Bulb", 0, 0, 13, 13, F("FFFF4A3A"))
    halo = E(O, "Halo", 0, 0, 120, 120, sc.rgrad(60, [("A0FF3A2A", 0.0), ("30FF3A2A", 0.35), ("00FF3A2A", 1.0)]))
    light = d("Node", bulb, halo, x=x, y=446.0, name="AntennaLight")
    cap = E(O, "LampCap", x, 440, 12, 6, F("FF4A5064"))
    n = BEACON_LOOP
    sc.ambient("Beacon", sc.A("amb_beacon", n, [
        sc.T(bulb, ease=None, opacity=[(0, 1.0), (22, 1.0, "linear"), (40, 0.18, "linear"), (n - 18, 0.18, "linear"),
                                       (n - 6, 1.0, "linear"), (n, 1.0)]),
        sc.T(halo, ease=None, opacity=[(0, 1.0), (20, 1.0, "linear"), (44, 0.0, "linear"), (n - 16, 0.0, "linear"),
                                       (n - 4, 1.0, "linear"), (n, 1.0)]),
    ], loop=True))
    return d("Node", cap, light, lit, rods, booms, box, mast, wires, clamp, x=0.0, y=0.0, name="Antenna")


def _telescope(sc: Scene) -> El:
    """The telescope on its tripod (right, Plane4). The tube swivels about the tripod head by
    `aim` x AIM_SWING (contract v12 drag `aim`, history-free: one formula bind on its rotation)."""
    d, E, F = sc.d, sc.E, sc.F
    px, py = TELESCOPE_PIVOT
    obj, eye, rr = TUBE
    tube = _rect(sc, "TubeBody", -108, -16, 58, 16,
                 sc.vgrad(-16, 16, [("FFF2ECE0", 0.0), ("FFDAD2C4", 0.45), ("FFA49C92", 1.0)]), 3)
    dew = _rect(sc, "DewShield", obj, -rr, -104, rr, sc.vgrad(-rr, rr, [("FF3E4C74", 0.0), ("FF283456", 0.5),
                                                                       ("FF1A2240", 1.0)]), 4)
    rings = _rects(sc, "Rings", [(-108, -18, -101, 18), (-12, -18, -4, 18), (40, -18, 46, 18)],
                   sc.vgrad(-18, 18, [("FFE8C27A", 0.0), ("FF9A7240", 1.0)]), 2)
    lens = E(O, "Lens", obj + 2, 0, 9, 2 * rr - 4, F("FF141A30"))
    glint = d("Node", E(O, "Spot", obj + 2, -8, 5, 9, F("C0E8F0FF")), x=0.0, y=0.0, name="LensGlint")
    focuser = _rect(sc, "Focuser", 58, -9, 80, 9, sc.vgrad(-9, 9, [("FF54546A", 0.0), ("FF2E2E3E", 1.0)]), 2)
    eyepiece = _rect(sc, "Eyepiece", 80, -7, eye, 7, F("FF20202C"), 2)
    knob = E(O, "Knob", 66, 13, 10, 8, F("FFC8A060"))
    finder = _rect(sc, "Finder", -66, -27, -22, -19, sc.vgrad(-4, 4, [("FFE6DED2", 0.0), ("FF9C948A", 1.0)]), 3)
    finder_feet = _rects(sc, "FinderFeet", [(-58, -20, -54, -15), (-34, -20, -30, -15)], F("FF5A5A6A"))
    rest = d("Node", glint, lens, knob, finder, finder_feet, rings, dew, eyepiece, focuser, tube,
             x=0.0, y=0.0, rotation=TUBE_SHOWN, name="TubeRest")
    f = Formulas(sc.d9, sc.vpath)
    conv = sc.d9("DataConverterFormula", f.val(AIM_SWING), f.op("*"), *f.inp())
    sc.roots.append(conv)
    # M12: the converter's tokens rewritten in place (its id stays), minted from the module's M12 range:
    # (TUBE_SHOWN - lo) x clamp(aim, -1, 0) + (hi - TUBE_SHOWN) x clamp(aim, 0, 1)
    g = Formulas(scene_npc.own_m12(sc), sc.vpath)
    lo, hi = TUBE_REST - AIM_SWING, TUBE_REST + AIM_SWING
    neg = g.fn("max", [g.val(-1)], g.fn("min", [g.val(0)], g.inp()))
    pos = g.fn("min", [g.val(1)], g.fn("max", [g.val(0)], g.inp()))
    conv.children[:] = [g.val(round(TUBE_SHOWN - lo, 3)), g.op("*"), *neg, g.op("+"), g.val(round(hi - TUBE_SHOWN, 3)),
                        g.op("*"), *pos]
    aim = d("Node", sc.d9("DataBindContext", sourcePathIds=sc.vpath("aim"), propertyKey=15, converterId=conv.ref()),
            rest, x=px, y=py, name="TubeAim")
    head = d("Node", _rect(sc, "Cradle", -16, -6, 16, 14, sc.vgrad(-10, 10, [("FF6A6A7C", 0.0), ("FF34344A", 1.0)]), 4),
             E(O, "HeadBolt", 0, 0, 12, 12, F("FFC8A060")), x=px, y=py, name="TripodHead")
    wood = [("FFA06E48", 0.0), ("FF6A4430", 1.0)]

    def leg(name: str, x1: float, y1: float, w: float, cols: list[tuple[str, float]]) -> El:
        ang = math.atan2(y1 - (py + 10), x1 - px)
        ln = math.hypot(x1 - px, y1 - (py + 10))
        body = d("Shape", d("Rectangle", width=float(ln), height=float(w), cornerRadiusTL=float(w / 2),
                            cornerRadiusTR=float(w / 2), cornerRadiusBL=float(w / 2), cornerRadiusBR=float(w / 2),
                            name="Path"), sc.vgrad(-w / 2, w / 2, cols), name="Wood")
        tip = d("Shape", ellipse(d, w * 1.5, w * 1.1), F("FF1E1A22"), x=float(ln / 2), name="Tip")
        return d("Node", tip, body, x=float((px + x1) / 2), y=float((py + 10 + y1) / 2), rotation=float(ang), name=name)
    legs_front = [leg("LegL", 796, 1300, 10, wood), leg("LegR", 948, 1298, 10, wood)]
    leg_back = leg("LegBack", 884, 1284, 9, [("FF6A4832", 0.0), ("FF3E2A20", 1.0)])
    spreader = _lines(sc, "Spreader", [(828, 1250, 914, 1249), (871, 1250, 878, 1238)], "FF4A3426", 3)
    shadow = E(O, "TelescopeShadow", 872, 1300, 200, 22, F("48080A12"))
    return d("Node", aim, head, *legs_front, spreader, leg_back, shadow, x=0.0, y=0.0, name="Telescope")


def _vent(sc: Scene) -> El:
    """A galvanised roof vent with a mushroom cap (bottom-left corner, Plane5)."""
    S, F = sc.S, sc.F
    metal = [("FF5A6072", 0.0), ("FF9AA0B2", 0.3), ("FF6A7082", 0.7), ("FF3E4456", 1.0)]
    pipe = _rect(sc, "Pipe", 40, 1712, 150, H + 80, _hfill(sc, 40, 150, 95, metal))
    rings = _rects(sc, "PipeRings", [(36, 1776, 154, 1786), (36, 1872, 154, 1882)], _hfill(sc, 36, 154, 0, metal))
    cap = S(O, "VentCap", [(-6, 1714, "c"), (24, 1676), (95, 1660), (166, 1676), (196, 1714, "c")],
            sc.vgrad(-28, 28, [("FFA8AEC0", 0.0), ("FF5C6274", 1.0)]))
    lip = _rect(sc, "VentLip", -8, 1710, 198, 1722, F("FF3A4052"), 4)
    sheen = _lines(sc, "VentSheen", [(70, 1730, 70, H + 60)], "60D8E0F0", 4)
    return sc.d("Node", sheen, cap, lip, rings, pipe, x=0.0, y=0.0, name="Vent")


def _pot_plant(sc: Scene) -> El:
    """A terracotta pot with a leafy plant (bottom-right corner, Plane5)."""
    d, S, F = sc.d, sc.S, sc.F
    pot = S(O, "Pot", [(902, 1790, "c"), (1050, 1790, "c"), (1030, H + 70, "c"), (922, H + 70, "c")],
            sc.vgrad(-80, 80, [("FF9A5C46", 0.0), ("FF5E3428", 1.0)]))
    rim = _rect(sc, "PotRim", 892, 1776, 1060, 1800, F("FFA8684E"), 5)
    leaves = []
    for k, (ang, ln) in enumerate([(-2.3, 150), (-1.95, 190), (-1.6, 210), (-1.25, 180), (-0.9, 140), (-2.7, 120)]):
        bx, by = 976.0, 1782.0
        tx, ty = bx + math.cos(ang) * ln, by + math.sin(ang) * ln
        mx, my = bx + math.cos(ang) * ln * 0.55, by + math.sin(ang) * ln * 0.55
        nx, ny = -math.sin(ang) * 30, math.cos(ang) * 30
        leaves.append(S(O, f"Leaf{k}", [(bx, by), (mx + nx, my + ny), (tx, ty, "c"), (mx - nx, my - ny)],
                        sc.vgrad(-80, 80, [("FF4E7A5E", 0.0), ("FF243E30", 1.0)])))
        leaves.append(S(O, f"Vein{k}", [(bx, by), (mx, my), (tx, ty)], sc.L("FF1E3226", 1.6), closed=False))
    return d("Node", rim, pot, *leaves[::-1], x=0.0, y=0.0, name="PotPlant")


# ====================================================================== the light hook
def rooftop_day_lift(sc: Scene, content: list[El]) -> None:
    """M10 (plan ruling 15, the owner's note "dark roof at noon"): a `screen` overlay of DAY_LIFT over
    the parapet and the roof floor (Plane4, in front of the cap's light line, the wall, the floor, its
    seams, gravel and wet film; behind the rain on the cap, the telescope, the pigeon and the antenna),
    at opacity `daylight`: by day the tar roof and the bricks lift toward a lit grey and keep their
    texture (screen keeps the differences). Invisible at daylight 0, so the night is M9 exactly.
    Mints from `d10`."""
    d10 = sc.d10
    plane4 = next(e for e in content if e.tag == "Node" and e.attrs.get("name") == "Plane4")
    y0, y1 = CAP_TOP - 4, H + 70
    top, bottom = DAY_LIFT
    lift = d10("Shape", d10("DataBindContext", sourcePathIds=sc.vpath("daylight"), propertyKey=18),
               d10("Rectangle", width=float(W + 120), height=float(y1 - y0), name="Path"),
               d10("Fill", d10("LinearGradient", d10("GradientStop", colorValue=top, position=0.0),
                               d10("GradientStop", colorValue=bottom, position=1.0),
                               startX=0.0, startY=-(y1 - y0) / 2, endX=0.0, endY=(y1 - y0) / 2), name="Fill"),
               x=W / 2, y=(y0 + y1) / 2, opacity=0.0, blendModeValue=14, name="RoofDay")
    at = next(i for i, c in enumerate(plane4.children) if c.attrs.get("name") == "ParapetCapLight")
    plane4.children.insert(at, lift)


def rooftop_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """The rooftop's own pass: the city glow takes `lightRim` and the moon's halo `lightKey` (bound
    stops; the gradient opacity carries their alpha), the day dims the lit windows, then the steady
    rain binds (history-free): streaks in screen space, splashes on the cap, a wet roof, an overcast."""
    script = SCENES[SID]
    d5 = sc.d5
    with sc.minting(d5):
        for name, prop, col in (("CityGlow", "lightRim", script.rim), ("MoonGlow", "lightKey", script.key)):
            g = next(c for c in named(content, name).children if c.tag == "Fill").children[0]
            for stop in g.children:
                if str(stop.attrs["colorValue"])[:2] == "00":
                    stop.attrs["colorValue"] = "00" + col[2:]
                    continue
                stop.attrs["colorValue"] = col
                stop.children.append(sc.bind(prop, 38))
        dim = sc.conv(-DAY_DIM, 1.0)
        for name in ("MidLightsWarm", "MidLightsDim", "MidLightsCool", "NearLights", "FarLights"):
            named(content, name).children.insert(0, sc.bind("daylight", 18, dim))

        streaks, loop = rain_fx(sc, "RainLoop", RAIN_COL, frames=RAIN_LOOP_FRAMES, loop=True, ground=(1200.0, 1880.0))
        streaks.attrs["opacity"] = 0.0
        streaks.children.insert(0, sc.bind("rain", 18))
        sc.ambient("RainLoop", loop)
        content.insert(0, streaks)

        r = random.Random(zlib.crc32(b"rooftopParapetRain"))
        splashes, tracks = [], []
        for i in range(14):
            x = r.uniform(30, W - 30)
            y = CAP_TOP + r.uniform(1, 5)
            sp = d5("Node", sc.E((x, y), "Ring", x, y, 22, 6, sc.L("B0B8C8E0", 1.6)),
                    sc.S((x, y), "Kick", [(x - 5, y - 1), (x - 8, y - 10)], sc.L("90B8C8E0", 1.6), closed=False),
                    sc.S((x, y), "Kick2", [(x + 5, y - 1), (x + 8, y - 10)], sc.L("90B8C8E0", 1.6), closed=False),
                    x=x, y=y, opacity=0.0, name=f"CapSplash{i}")
            splashes.append(sp)
            ph = r.randint(0, 40)
            op, sk = [(0, 0.0)], [(0, 0.3)]
            for c in range(1 + ph, RAIN_LOOP_FRAMES - 13, 40):
                op += [(c, 0.0, "hold"), (c + 1, 1.0), (c + 12, 0.0, "hold")]
                sk += [(c, 0.3, "hold"), (c + 1, 0.4), (c + 12, 1.3, "hold")]
            tracks.append(sc.T(sp, ease=None, opacity=uniq(op + [(RAIN_LOOP_FRAMES, 0.0)]),
                               scaleX=uniq(sk + [(RAIN_LOOP_FRAMES, 0.3)]), scaleY=uniq(sk + [(RAIN_LOOP_FRAMES, 0.3)])))
        sc.ambient("ParapetRain", sc.A("amb_ParapetRain", RAIN_LOOP_FRAMES, tracks, loop=True))
        cap_rain = d5("Node", sc.bind("rain", 18), *splashes, x=0.0, y=0.0, opacity=0.0, name="ParapetRain")
        before(content, "ParapetCapLight", cap_rain)

        mx, my, _ = MOON
        film = _rect(sc, "Film", -60, ROOF_Y, W + 60, H + 70, sc.F(WET[0]), opacity=WET[1])
        glow = _rect(sc, "GlowSheen", -60, ROOF_Y, W + 60, ROOF_Y + 300,
                     _vfill(sc, ROOF_Y, ROOF_Y + 300, ROOF_Y + 150, [("30E09A78", 0.0), ("00E09A78", 1.0)]))
        # the moon's reflection: a soft vertical streak on the wet roof below it (a disc stretched 4x)
        moon_ref = sc.E(O, "MoonSheen", mx + 30, 1360, 80, 80,
                        sc.rgrad(40, [("48C8D4F0", 0.0), ("00C8D4F0", 1.0)]), scaleY=4.0)
        puddles = _dots(sc, "Puddles", [(240, 1290, 160), (660, 1400, 220), (900, 1560, 180), (420, 1700, 260)],
                        sc.F("34B8C4DC"))
        for p in puddles.children[:-1]:
            p.attrs["height"] = round(float(p.attrs["width"]) * 0.18, 2)
        wet = d5("Node", sc.bind("rain", 18), moon_ref, glow, puddles, film, x=0.0, y=0.0, opacity=0.0, name="RoofWet")
        before(content, "ParapetShadow", wet)

        sky = named(content, "Sky")
        rect = next(c for c in sky.children if c.tag == "Rectangle")
        overcast = d5("Shape", sc.bind("rain", 18, sc.conv(OVERCAST[1])), gen_scenes.clone(d5, rect),
                      sc.F(OVERCAST[0]), x=sky.attrs["x"], y=sky.attrs["y"], opacity=0.0, name="SkyOvercast")
        before(content, "MoonRig", overcast)


# ====================================================================== the pigeon (NPC)
def rooftop_pigeon(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The pigeon on the parapet's cap (contract v12 NPC, ruling 11): drawn facing left (toward the
    avatar) while `npcLook` <= 0 and mirrored (facing right) while it is > 0; `npcX` walks it along
    the cap from its spot right of the avatar (0) to the right (1), its poke zone along. rest: fluffed
    and still; idle: pecks and bobs; move: walks (the head holds still, then thrusts); notice: head
    cocked; react: a flap hop."""
    with sc.minting(sc.d8):
        d, S, E, F = sc.d, sc.S, sc.E, sc.F
        L = sc.L
        Z = O
        rig = Rig(sc)
        body_c, shade, wing_c, bar, ink = "FF8E96AC", "FF6A7290", "FFA6AEC2", "FF3C4256", "FF2A2E3C"
        # ---- head: pivot at the neck, beak to the left
        eye = d("Node", E(Z, "Glint", -1.2, -1.2, 1.6, 1.6, F("F0FFFFFF")), E(Z, "Pupil", 0, 0, 3.2, 3.2, F("FF140E10")),
                E(Z, "Iris", 0, 0, 6.4, 6.4, F("FFE8903E")), x=-4.0, y=-3.0, name="PEye")
        rig.reg(eye, scaleY=1.0)
        head = d("Node", eye,
                 E(Z, "Cere", -11.5, -2.5, 5, 3.4, F("FFE6E2DA")),
                 S(Z, "Beak", [(-10, -2.6), (-19, -0.4), (-10, 1.6)], F("FF3A3844")),
                 E(Z, "HeadShape", -2, -1, 20, 19, sc.vgrad(-10, 10, [("FF9CA4BA", 0.0), (body_c, 1.0)]), L(ink, 1.2)),
                 x=-10.0, y=-14.0, name="PHead")
        rig.reg(head, rotation=0.0, x=-10.0, y=-14.0)
        fore = d("Node", head,
                 S(Z, "Neck", [(-14, 0), (-11, -12), (-2, -14), (6, -4), (2, 6), (-10, 6)],
                   sc.vgrad(-10, 6, [("FF5E8676", 0.0), ("FF7C6A96", 1.0)])),
                 x=-12.0, y=-34.0, name="PFore")
        rig.reg(fore, rotation=0.0, x=-12.0)
        # ---- wings: the near one folded over the body, the far one shows while flapping
        wing_pts = [(0, 0), (16, -3), (32, 5), (40, 14), (22, 15), (6, 12), (-4, 6)]
        wing = d("Node", _lines(sc, "Bars", [(10, 4, 22, 8), (14, 9, 28, 12)], bar, 2.4),
                 S(Z, "WingShape", wing_pts, sc.vgrad(-4, 14, [(wing_c, 0.0), (shade, 1.0)]), L(ink, 1.2), origin=Z),
                 x=-8.0, y=-36.0, name="PWing")
        rig.reg(wing, rotation=0.0)
        wing_far = d("Node", S(Z, "FarWingShape", wing_pts, F("FF5E6680"), origin=Z),
                     x=-6.0, y=-38.0, opacity=0.0, name="PWingFar")
        rig.reg(wing_far, rotation=0.0, opacity=0.0)
        tail = d("Node", S(Z, "TailBand", [(20, -2.5), (29, -1.2), (30, 3.6), (20, 3.4)], F(bar)),
                 S(Z, "TailShape", [(-2, -4), (29, -1.5), (30, 4), (-2, 6)], F(shade), L(ink, 1.0)),
                 x=16.0, y=-24.0, name="PTail")
        rig.reg(tail, rotation=0.0, scaleY=1.0)

        def leg(name: str, hx: float, col: str) -> El:
            n = d("Node", _lines(sc, "Toes", [(-6, 10, 2, 10), (-1, 10, 4, 9)], col, 1.8),
                  _lines(sc, "Shank", [(0, 0, -1, 10)], col, 2.6), x=hx, y=-10.0, name=name)
            rig.reg(n, rotation=0.0, y=-10.0)
            return n
        leg_near, leg_far = leg("PLegNear", -4.0, "FFCC6672"), leg("PLegFar", 5.0, "FFA4505C")
        body = S(Z, "PBody", [(-26, -28), (-22, -14), (-8, -8), (10, -10), (24, -18), (28, -24), (18, -32), (2, -38),
                              (-14, -40)], sc.vgrad(-16, 16, [(body_c, 0.0), (shade, 1.0)]), L(ink, 1.3))
        chest = S(Z, "PChest", [(-25, -27), (-21, -15), (-12, -12), (-14, -26)], F("FF9EA6BC"))
        bob = d("Node", fore, wing, chest, leg_near, body, tail, wing_far, leg_far, x=0.0, y=0.0, name="PBob")
        rig.reg(bob, y=0.0, rotation=0.0, scaleX=1.0, scaleY=1.0)
        shadow = E(Z, "PShadow", 2, 1, 54, 8, F("50080A12"))
        rig.reg(shadow, scaleX=1.0)
        face = d("Node", bob, shadow, x=0.0, y=0.0, name="PigeonFace")
        f = Formulas(sc.d8, sc.vpath)
        flip = scene_npc.formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                                      *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(1000), f.op("*"),
                                                                                        f.bound("npcLook")]))])
        face.children.insert(0, sc.bind("npcLook", 16, flip, doc=sc.d8))
        x0, y0, _ = PIGEON_WAYPOINTS[0]
        size = d("Node", face, x=0.0, y=0.0, scaleX=PIGEON_SCALE, scaleY=PIGEON_SCALE, name="PigeonSize")
        npc = d("Node", size, x=x0, y=y0, name="PigeonNpc")
        rig.reg(npc, opacity=1.0)
        ts = arc_params([(x, y) for x, y, _ in PIGEON_WAYPOINTS])
        path_binds(sc, npc, ts, [p[0] for p in PIGEON_WAYPOINTS], [p[1] for p in PIGEON_WAYPOINTS])
        hit = next(h for h in hits if h.attrs.get("name") == "Hit_pigeon")
        path_binds(sc, hit, ts, [p[0] + PIGEON_HIT[0] for p in PIGEON_WAYPOINTS],
                   [p[1] + PIGEON_HIT[1] for p in PIGEON_WAYPOINTS])
        content.insert(next(i for i, e in enumerate(content) if e.attrs.get("name") == "Antenna"), npc)

        # ---- states (every one keys every registered property: Rig.anim)
        anims: dict[str, El | list[El]] = {}
        anims["rest"] = rig.anim("npc_pigeon_rest", 1, {
            bob: {"scaleX": [(0, 1.08)], "scaleY": [(0, 0.93)]}, head: {"y": [(0, -9.0)], "x": [(0, -8.0)]},
            eye: {"scaleY": [(0, 0.45)]}, tail: {"rotation": [(0, 0.08)]}})
        anims["away"] = rig.anim("npc_pigeon_away", 1, {npc: {"opacity": [(0, 0.0)]}})
        n = PIGEON_IDLE
        peck = [(0, 0.0), (28, 0.0), (36, -1.15), (40, -0.8), (44, -1.15), (54, 0.0), (160, 0.0), (168, -1.1),
                (174, -0.85), (178, -1.1), (188, 0.0), (n, 0.0)]
        tilt = [(f, -0.36 if v < -0.5 else 0.0) for f, v in peck]   # the body tips forward to peck
        anims["idle"] = rig.anim("npc_pigeon_idle", n, {
            fore: {"rotation": peck, "x": [(0, -12.0), (90, -12.0), (96, -16.0), (104, -10.0), (110, -14.0), (118, -12.0),
                                           (n, -12.0)]},
            bob: {"rotation": tilt,
                  "scaleY": [(0, 1.0), (60, 1.02), (120, 1.0), (180, 1.02), (n, 1.0)],
                  "y": [(0, 0.0), (36, 1.5), (54, 0.0), (n, 0.0)]},
            head: {"rotation": [(0, 0.0), (120, 0.0), (128, -0.22), (146, -0.22), (152, 0.12), (158, 0.0), (n, 0.0)]},
            eye: {"scaleY": [(0, 1.0), (100, 1.0, "hold"), (101, 0.12), (105, 1.0), (n, 1.0)]},
            tail: {"rotation": [(0, 0.0), (206, 0.0), (210, -0.25), (216, 0.08), (222, 0.0), (n, 0.0)]},
            # the legs stay planted while the body tips
            leg_near: {"rotation": [(f, -v) for f, v in tilt]},
            leg_far: {"rotation": [(f, -v) for f, v in tilt]},
        })
        # walk: two steps per cycle; the head keeps still while the body passes under it, then thrusts
        n = PIGEON_WALK
        step = n // 2
        hold = step * 3 // 4
        head_x = []
        for s0 in (0, step):
            head_x += [(s0, -16.0, "linear"), (s0 + hold, -16.0 + PIGEON_STRIDE / 2 * hold / step, sc.ease_out)]
        head_x.append((n, -16.0))
        anims["move"] = rig.anim("npc_pigeon_move", n, {
            fore: {"x": head_x},
            bob: {"y": [(0, 0.0), (step // 2, -1.6), (step, 0.0), (step + step // 2, -1.6), (n, 0.0)],
                  "rotation": [(0, -0.04), (step, 0.0), (n, -0.04)]},
            leg_near: {"rotation": [(0, 0.38), (step, -0.38), (n, 0.38)],
                       "y": [(0, -10.0), (step, -10.0), (step + step // 2, -13.0), (n, -10.0)]},
            leg_far: {"rotation": [(0, -0.38), (step, 0.38), (n, -0.38)],
                      "y": [(0, -10.0), (step // 2, -13.0), (step, -10.0), (n, -10.0)]},
            tail: {"rotation": [(0, 0.05), (step, -0.05), (n, 0.05)]},
        })
        n = PIGEON_NOTICE

        def notice(s: float) -> El:
            a = abs(s)
            return rig.anim(f"npc_pigeon_notice{'LCR'[int(s) + 1]}", n, {
                fore: {"rotation": [(0, 0.12)]},
                head: {"rotation": [(0, -0.38 * a), (22, -0.24 * a - 0.06), (48, -0.4 * a), (72, -0.26 * a - 0.06),
                                    (96, -0.4 * a), (n, -0.38 * a)],
                       "y": [(0, -17.0), (30, -15.5), (60, -17.0), (90, -15.5), (n, -17.0)]},
                eye: {"scaleY": [(0, 1.12)]},
                bob: {"scaleY": [(0, 1.04), (30, 1.02), (60, 1.04), (90, 1.02), (n, 1.04)],
                      "scaleX": [(0, 0.97)]},
                tail: {"rotation": [(0, -0.05), (40, 0.04), (80, -0.05), (n, -0.05)]},
            })
        anims["notice"] = blend3(notice)
        n = PIGEON_REACT
        flap = [(0, 0.0), (6, 0.0), (12, -1.9), (18, -0.5), (24, -1.9), (30, -0.5), (36, -1.6), (42, 0.0), (n, 0.0)]
        anims["react"] = rig.anim("npc_pigeon_react", n, {
            bob: {"y": [(0, 0.0), (6, 2.0), (18, -22.0), (26, -26.0), (36, 0.0), (41, 2.0), (n, 0.0)],
                  "scaleY": [(0, 1.0), (6, 0.88), (14, 1.08), (34, 1.0), (38, 0.92), (44, 1.0), (n, 1.0)],
                  "scaleX": [(0, 1.0), (6, 1.08), (14, 0.95), (34, 1.0), (38, 1.06), (44, 1.0), (n, 1.0)],
                  "rotation": [(0, 0.0), (10, 0.12), (30, 0.06), (40, 0.0), (n, 0.0)]},
            wing: {"rotation": flap},
            wing_far: {"rotation": [(fr, v * 0.85) for fr, v in flap],
                       "opacity": [(0, 0.0), (8, 0.0, "hold"), (9, 1.0), (40, 1.0, "hold"), (41, 0.0), (n, 0.0)]},
            tail: {"rotation": [(0, 0.0), (12, -0.3), (30, -0.2), (42, 0.0), (n, 0.0)], "scaleY": [(0, 1.0), (12, 1.5), (40, 1.0)]},
            fore: {"rotation": [(0, 0.0), (10, 0.22), (34, 0.1), (42, 0.0), (n, 0.0)]},
            shadow: {"scaleX": [(0, 1.0), (18, 0.6), (26, 0.55), (36, 1.0), (n, 1.0)]},
            leg_near: {"rotation": [(0, 0.0), (14, 0.5), (32, 0.2), (36, 0.0), (n, 0.0)]},
            leg_far: {"rotation": [(0, 0.0), (14, 0.6), (32, 0.25), (36, 0.0), (n, 0.0)]},
        })
        npc_layer(sc, anims)


# the telescope art's extremes in the tube's frame (x along the tube, objective at -x) and the
# tripod's in artboard px (legs, tips, contact shadow)
TUBE_POINTS = ((-150.0, -21.0), (-150.0, 21.0), (-104.0, -21.0), (-104.0, 21.0), (-108.0, -18.0), (-108.0, 18.0),
               (46.0, -18.0), (46.0, 18.0), (58.0, -16.0), (58.0, 16.0), (-66.0, -27.0), (-22.0, -27.0),
               (96.0, -7.0), (96.0, 7.0), (61.0, 17.0), (71.0, 17.0))
TRIPOD_BOX = (772.0, 1150.0, 972.0, 1311.0)


def aim_rect(pad: float = 6.0) -> tuple[float, float, float, float]:
    """The telescope's art box over every `aim` in -1..1 (artboard px at parallax 0): the drag
    handle's rect (contract v12 table, rooftop `aim`)."""
    px, py = TELESCOPE_PIVOT
    xs, ys = [TRIPOD_BOX[0], TRIPOD_BOX[2]], [TRIPOD_BOX[1], TRIPOD_BOX[3]]
    for i in range(201):
        th = TUBE_REST + AIM_SWING * (i / 100 - 1)
        c, s = math.cos(th), math.sin(th)
        for x, y in TUBE_POINTS:
            xs.append(px + x * c - y * s)
            ys.append(py + x * s + y * c)
    return (math.floor(min(xs) - pad), math.floor(min(ys) - pad), math.ceil(max(xs) + pad), math.ceil(max(ys) + pad))


def pigeon_walk_speed() -> float:
    """npcX per second at which the pigeon's walk cycle matches its travel (the head stays still)."""
    (x0, y0, _), (x1, y1, _) = PIGEON_WAYPOINTS[0], PIGEON_WAYPOINTS[-1]
    return PIGEON_STRIDE * PIGEON_SCALE * 60 / PIGEON_WALK / math.hypot(x1 - x0, y1 - y0)


# ====================================================================== registries (contract v12)
gen_scenes.DIORAMAS[SID] = DioramaSpec(ROOFTOP_PLANES, ROOFTOP_EMISSIVE, ROOFTOP_VEILS, rooftop_light)
gen_scenes.TIME_SKY[SID] = (960.0, 1.0)
scene_npc.FOG_VEILS[SID] = (0, 1, 2)
scene_npc.FOG_BANKS[SID] = (2, 560.0, 980.0, "FF6E7898", 0.6)


# ====================================================================== review configuration
def _extras(render: object, out: object, gates: list[str]) -> None:
    """The four events at their peaks, the city glow following `lightRim`, and the `aim` drag's
    pixel proof (aim -1 / +1 change pixels only inside the telescope's rect)."""
    import numpy as np  # noqa: PLC0415 (review-only)
    from PIL import Image  # noqa: PLC0415
    from review_diorama import grid, label  # noqa: PLC0415

    cells = [label(Image.fromarray(render("--advance=1")).convert("RGB").resize((360, 640)), "rest")]
    for ev, f in (("fireworks", 70), ("plane", 300), ("shootingStar", 24), ("windowsLit", 280)):
        a = render(f"--data=eventId={ev}", "--data=event=1", f"--advance={f}")
        cells.append(label(Image.fromarray(a).convert("RGB").resize((360, 640)), f"{ev} +{f}f"))
    grid(cells, 5).save(out / "events_strip.png")
    box = (slice(820, 880), slice(560, 640))   # the horizon glow between the bridge and the mid row
    rest = render("--advance=1").astype(int)[box][..., :3]
    blue = render("--data=lightRim=FF60A0FF", "--advance=1").astype(int)[box][..., :3]
    back = render("--data=lightRim=FF60A0FF", "--advance=1", f"--data=lightRim={SCENES[SID].rim}", "--advance=2"
                  ).astype(int)[box][..., :3]
    shift = float((blue[..., 2] - blue[..., 0]).mean() - (rest[..., 2] - rest[..., 0]).mean())
    drift = int(np.abs(back - rest).max())
    gates.append(f"city glow follows lightRim (blue - red, mean, blue rim vs default): {shift:+.1f}/255 "
                 f"({'ok' if shift >= 8 else 'FAIL'}); back to default: max diff {drift}/255 "
                 f"({'ok' if drift <= 2 else 'FAIL'})")
    rect = aim_rect()
    x0, y0, x1, y1 = rect
    base = render("--advance=1").astype(int)
    for v in (-1, 0.5, 1):
        a = render(f"--data=aim={v}", "--advance=1").astype(int)
        changed = np.abs(a - base)[..., :3].max(-1) > 0
        inside = changed[y0:y1, x0:x1].mean()
        changed[y0:y1, x0:x1] = False
        gates.append(f"aim {v:+}: changes {inside:.2%} of the handle rect {rect}, {changed.mean():.4%} outside it "
                     f"({'ok' if inside > 0.02 and not changed.any() else 'FAIL'})")


REVIEW: dict = {
    "diorama": {
        "patches": [("Plane5 pot", (900, 1770, 1040, 1830), 40), ("Plane4 tripod", (780, 1200, 960, 1300), 28),
                    ("Plane3 near windows", (120, 600, 300, 720), 20), ("Plane2 water tank", (980, 632, 1044, 700), 12),
                    ("Plane1 bridge tower", (610, 790, 670, 856), 6), ("Plane0 moon", (240, 240, 360, 360), 0)],
        "wet": ((560, 1700, 860, 1850), 0.55, 0.9),
        # streak sheets 18 / 34, splash loops 120 frames: all back at frame 0 after 6120
        "rain_loops": [("RainLoop sheets + splashes + ParapetRain", 6120)],
        "seam_box": (300, 1200, 1080, 1920),
    },
    "extras": _extras,
    "time": {"sky_box": (0, 0, 1080, 560), "dusk_box": (330, 560, 750, 840), "noon_gain": 12.0,
             "ground_lift": 12.0},   # M10 ruling 15: the day lifts the roof (`rooftop_day_lift`)
    "npc": {"crop": (220, 170, -30), "seam": {"idle": PIGEON_IDLE, "move": PIGEON_WALK, "notice": PIGEON_NOTICE,
                                              "react": PIGEON_REACT},
            "prop": "pigeon", "waypoints": PIGEON_WAYPOINTS},
}


if __name__ == "__main__":
    print("wrote", rooftop())
