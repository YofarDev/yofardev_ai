"""Moonshot M9 (contract v12, ruling 1): the `mountainHut` scene, a snowy mountain hut seen from inside.

    uv run rive/tools/gen_scenes.py mountainHut       # -> rive/scenes/mountainHut/mountainHut.rml

A cosy log hut at night (storybook night, warm stove key from low right, the cold window as the rim):

- Plane0, the view through the window: the night sky (`daylight` / `dusk` through `gen_scenes.sky_time`),
  stars, the moon (`moonPhase`: the drawn moon at -1, `world_kit.moon_rig` at 0..1), snowy peaks, a
  pine ridge and a snow field; the `fog` veil and bank over the peaks (`scene_npc.scene_fog`); the
  `aurora` event's ribbons.
- Plane1, the window: the frame, its cross mullion, frost in the pane corners, and the snow falling just
  outside the glass, clipped to the panes: scene `rain` draws SNOW (never rain, contract v12), two
  seamless sheets whose opacity rises with `rain` (the far sheet joins past 0.4: denser, not only
  brighter); the `snowfall` event is a heavy flurry over it.
- Plane2, the back wall: horizontal logs with an opening for the window, its casing and sill, the stove's
  warm glow (flickering) and the window's cold spill.
- Plane3, the hut: the ceiling beam, the door at the left with the bell on its bracket (prop `bell`,
  event `bell`, the `rope` pull drag), the cast-iron stove with its glowing door (prop `stove`, event
  `flare`), its pipe and a kettle; `festive` dresses the beam with a pine garland and a string of
  lights and hangs a stocking by the pipe.
- Plane4, the floor: planks, the braided rug, the stove's light pool, the dog (NPC `dog`).
- Plane5, the foreground: a log basket (left) and a pair of snow-dusted boots (right).

The dog (`npc`, contract v11 states, rulings 3 and 11): a fluffy storybook sheepdog. rest = asleep curled
on the rug (a breathing loop, Zzz); idle = sits, wags; move = trots (the cat walker's leg rig from
scene_npc.py, re-proportioned: same joint lengths, scaled `DOG_WALK_SCALE`, a fluffier body); notice =
ears up, head toward the avatar (`npcLook`); react = a happy hop. `npcX` 0 = the rug by the stove,
1 = in front of the avatar, just right of centre (`DOG_WAYPOINTS`). Poke prop `dog` follows `npcX`.

The `rope` drag (pull, contract v12): `rope` 0..1 stretches the rope down by up to `ROPE_PULL` px and
tilts the bell a little, history-free; the app fires `bell` past 0.6.

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
from rml import Doc, El, ellipse, lin, rad, smooth_path  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import Rig, arc_params, blend3, npc_layer, path_binds  # noqa: E402
import world_kit  # noqa: E402

SCENE_ID = "mountainHut"
# M12 ruling 18: this module's own M12 additions (the NPC's `NpcDraw` layer) mint from a new range after
# its own (the shared M12 range is gen_scenes.M12_ID_START = 890000), so no earlier id moves.
M12_ID_START = 880000
O = (0.0, 0.0)
Z = (0.0, 0.0)
INK = "FF2E2228"

# ---------------------------------------------------------------- layout (artboard px)
FLOOR_Y = 1200.0
GLASS = (350.0, 230.0, 730.0, 630.0)        # the window's glass
OPEN = (324.0, 204.0, 756.0, 656.0)         # the opening in the log wall (Plane2)
CASING = (300.0, 180.0, 780.0, 680.0)       # the casing ring's outer edge (Plane2)
FRAME = (300.0, 180.0, 780.0, 680.0)        # the frame's outer edge (Plane1, mostly under the wall)
VIEW = (260.0, 140.0, 820.0, 720.0)         # the view (Plane0) runs past the opening by more than its travel
MULL = (540.0, 430.0, 14.0)                 # mullion centre x, centre y, width
PANES = ((GLASS[0], GLASS[1], MULL[0] - MULL[2] / 2, MULL[1] - MULL[2] / 2),
         (MULL[0] + MULL[2] / 2, GLASS[1], GLASS[2], MULL[1] - MULL[2] / 2),
         (GLASS[0], MULL[1] + MULL[2] / 2, MULL[0] - MULL[2] / 2, GLASS[3]),
         (MULL[0] + MULL[2] / 2, MULL[1] + MULL[2] / 2, GLASS[2], GLASS[3]))
HORIZON = 560.0                             # the peaks' base in the view (sky_time)
MOON = (652.0, 306.0, 24.0)                 # the moon in the view: centre, radius
SKY_TOP, SKY_LOW = "FF141C34", "FF33406A"   # night sky gradient (times["night"] at the top)

STOVE_X = 890.0                             # the stove's centre line
STOVE_BODY = (790.0, 905.0, 990.0, 1150.0)
STOVE_DOOR = (846.0, 966.0, 934.0, 1064.0)  # the door's glass (the fire behind the grille)
PIPE = (872.0, 908.0)
BEAM = (92.0, 158.0)

BELL_PIVOT = (162.0, 468.0)                 # the bell hangs from the bracket arm here
PULLEY = (212.0, 470.0)                     # the rope's top
ROPE_LEN = 380.0                            # pulley -> the top of the toggle at rope 0
ROPE_PULL = 70.0                            # px the rope stretches at rope 1
ROPE_TILT = 0.09                            # rad the bell tilts at rope 1
ROPE_SWAY = 0.2                             # the rope's sway about the pulley, x the bell's swing (bell event)
TOGGLE_H = 40.0

# ---------------------------------------------------------------- the dog (npc)
DOG_REST = (873.0, 1400.0)                  # npcX 0: asleep on the rug by the stove (paw line), clear of the avatar
# (paw line x, y, scale) along its path: the rug by the stove (0) -> in front of the avatar (1)
DOG_WAYPOINTS = [(873.0, 1400.0, 1.0), (810.0, 1364.0, 0.96), (748.0, 1330.0, 0.93), (690.0, 1300.0, 0.9)]
DOG_WALK_SCALE = 1.85                       # the cat walker's rig, scaled up for a bigger dog
DOG_ART_SCALE = 1.2                         # the sitting drawing (the curled one is drawn at 1: x 770..980 at rest)
DOG_STRIDE = 62.0                           # the walker's local px per stride (the cat's stance sweep)
DOG_IDLE, DOG_WALK, DOG_NOTICE, DOG_REACT, DOG_REST_LOOP = 240, 30, 120, 60, 240
DOG_HIT = (873.0, 1320.0, 250.0, 200.0)     # Hit_dog at npcX 0 (cx, cy, w, h)
DOG_REACT_MS = DOG_REACT * 1000 // 60

# ---------------------------------------------------------------- loops and events (frames at 60 fps)
STOVE_FLICKER = [(0, 1.0), (13, 0.82), (27, 0.97), (41, 0.85), (60, 1.0), (74, 0.83), (92, 0.96), (106, 0.86),
                 (120, 1.0)]
FLICKER_FRAMES = 120
SNOW_NEAR = (16, 300.0, 120)    # (flakes per tile, tile px, loop frames): one tile per loop, seamless
SNOW_FAR = (24, 240.0, 240)
SNOW_SWAY = 240
SNOW_LOOP = 240                 # every snow loop is back at frame 0 after this many frames
EVENT_FRAMES = {"snowfall": 420, "flare": 130, "aurora": 480, "bell": 150}

# ---------------------------------------------------------------- v12 members this file binds
BINDS: set[str] = {"moonPhase", "festive", *world_kit.drag_numbers(SCENE_ID)}
# M11 ruling 13 (contract v14 `tier`): what the shared tier pass (world_kit.tier_gate) hides. "high": at
# high and low (the second rain / snow sheet, the second half of the splashes and of every twinkle or
# particle loop's copies, by full name); "low": at low only (decorative ambient loops that are not light).
TIER_GATES: dict[str, tuple[str, ...]] = {
    "high": ("SnowFarSheet", "Star8", "Star12", *(f"Spark{i}" for i in range(6, 12))),
    # the kettle's steam; the window's frost and its faint cool spill on the wall (decorative overlays, not the
    # stove's light: the bench needs them for low's 0.8 x ultra, rive_bench.py)
    # + (M12 ruling 3: low <= 0.7 x ultra) the upper wall's shade (a decorative overlay inside the wall's clip, as
    # WallCool) and the twinkling stars in the view
    "low": ("SteamPuff", "Frost", "WallCool", "WallShade", "Star"),
}


# ====================================================================== helpers
class _HutScene(Scene):
    """`gen_scenes.Scene` without the M4 art pass: `scene_art.refine_scene` re-dresses the four M8
    scenes only (its table has no entry for a v12 scene); this file's art is final as drawn."""

    def write(self, content: list[El], hits: list[El]) -> str:
        saved = gen_scenes.refine_scene
        gen_scenes.refine_scene = lambda sc, c: None
        try:
            return super().write(content, hits)
        finally:
            gen_scenes.refine_scene = saved


def _conv(sc: Scene, toks: list[El]) -> El:
    conv = sc.d9("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def lin_conv(sc: Scene, k: float, c: float = 0.0, lo: float | None = None, hi: float | None = None) -> El:
    """A private `c + k x input` converter (clamped to [lo, hi] when given), minted from `d9`."""
    f = Formulas(sc.d9, sc.vpath)
    toks = ([f.val(c), f.op("+")] if c else []) + [f.val(k), f.op("*"), *f.inp()]
    if lo is not None:
        toks = f.fn("max", [f.val(lo)], toks)
    if hi is not None:
        toks = f.fn("min", [f.val(hi)], toks)
    return _conv(sc, toks)


def rect_shape(sc: Scene, name: str, x0: float, y0: float, x1: float, y1: float, paint: El | None, r: float = 0.0,
               **kw: object) -> El:
    d = sc.d
    return d("Shape", d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), cornerRadiusTL=float(r),
                        cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
             paint, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), name=name, **kw)


def rect_path(sc: Scene, x0: float, y0: float, x1: float, y1: float, ox: float, oy: float, name: str = "Path",
              r: float = 0.0) -> El:
    return sc.d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2 - ox),
                y=float((y0 + y1) / 2 - oy), cornerRadiusTL=float(r) or None, cornerRadiusTR=float(r) or None,
                cornerRadiusBL=float(r) or None, cornerRadiusBR=float(r) or None, name=name)


def ring(sc: Scene, name: str, outer: tuple[float, ...], inner: tuple[float, ...], paint: El, r: float = 0.0) -> El:
    """A rectangular ring (even-odd): `outer` minus `inner`."""
    ox, oy = (outer[0] + outer[2]) / 2, (outer[1] + outer[3]) / 2
    paint.attrs["fillRule"] = "evenOdd"
    return sc.d("Shape", rect_path(sc, *outer, ox, oy, r=r), rect_path(sc, *inner, ox, oy, name="Opening"), paint,
                x=float(ox), y=float(oy), name=name)


def fluff(cx: float, cy: float, rx: float, ry: float, n: int, amp: float, a0: float = 0.0) -> list[tuple[float, float]]:
    """A soft scalloped outline: 2n points around an ellipse, every other one pushed out by `amp`."""
    pts = []
    for i in range(2 * n):
        a = a0 + math.pi * i / n
        k = 1 + (amp if i % 2 == 0 else -amp * 0.35)
        pts.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    return pts


# ====================================================================== the scene
def mountainHut() -> str:  # noqa: N802 (scene ids are contract names)
    sc = _HutScene(SCENE_ID)
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rnd = random.Random(1207)

    # ------------------------------------------------------------ Plane0: the view
    vx0, vy0, vx1, vy1 = VIEW
    sky = rect_shape(sc, "Sky", vx0, vy0, vx1, vy1, sc.vgrad(-(vy1 - vy0) / 2, (vy1 - vy0) / 2,
                                                               [(SKY_TOP, 0.0), ("FF1E284A", 0.45), (SKY_LOW, 1.0)]))
    stars = []
    while len(stars) < 16:
        x, y = rnd.uniform(GLASS[0] + 8, GLASS[2] - 8), rnd.uniform(GLASS[1] + 8, 470)
        if math.hypot(x - MOON[0], y - MOON[1]) < MOON[2] + 26 or abs(x - MULL[0]) < 14 or abs(y - MULL[1]) < 14:
            continue
        sz = rnd.choice((2.4, 3.0, 3.6, 4.2))
        stars.append(E(O, f"Star{len(stars)}", x, y, sz, sz, F("FFF2F0E4"), opacity=round(rnd.uniform(0.5, 1.0), 2)))
    tw = [sc.T(s, opacity=[(0, float(s.attrs["opacity"])), (60 + 37 * i % 120, 0.25),
                           (130 + 37 * i % 100, float(s.attrs["opacity"])), (240, float(s.attrs["opacity"]))])
          for i, s in enumerate(stars) if i % 4 == 0]
    sc.ambient("Stars", sc.A("amb_stars", 240, tw, loop=True, seam_hold=True))

    # the drawn moon (moonPhase -1) and the phase rig (0..1)
    mx, my, mr = MOON
    moon_glow = E(O, "MoonGlow", mx, my, mr * 7, mr * 7, sc.rgrad(mr * 3.5, [("40FFF2D8", 0.0), ("00FFF2D8", 1.0)]))
    moon_disc = E(O, "MoonDisc", mx, my, 2 * mr, 2 * mr, sc.rgrad(mr * 1.6, [("FFFFF8E6", 0.0), ("FFEADFC4", 1.0)],
                                                                   cx=-mr * 0.4, cy=-mr * 0.4))
    craters = [E(O, f"MoonCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A"))
               for i, (dx, dy, r_) in enumerate(((-8, 6, 9), (6, -8, 6), (9, 9, 5)))]
    moon_drawn = world_kit.hide_when_phased(sc, sc.d9, "MoonDrawn", [*craters, moon_disc, moon_glow])
    with sc.minting(sc.d9):
        lit = d("Node", *[E((mx, my), f"MoonLitCrater{i}", mx + dx, my + dy, r_, r_, F("30B8A88A"))
                          for i, (dx, dy, r_) in enumerate(((-8, 6, 9), (6, -8, 6), (9, 9, 5)))],
                E((mx, my), "MoonLitDisc", mx, my, 2 * mr, 2 * mr, F("FFF6EEDA")),
                E((mx, my), "MoonLitGlow", mx, my, mr * 7, mr * 7,
                  sc.rgrad(mr * 3.5, [("40FFF2D8", 0.0), ("00FFF2D8", 1.0)])), x=0.0, y=0.0, name="MoonLit")
    moon_rig = world_kit.moon_rig(sc, sc.d9, mx, my, mr, lit, "E61A2240")

    def ridge(name: str, pts: list[tuple[float, float]], col: str, base: float = vy1 + 10) -> El:
        return S(O, name, [(vx0 - 10, base, "c"), *pts, (vx1 + 10, base, "c")], col if isinstance(col, El) else F(col),
                 tension=0.6)

    far_pts = [(vx0 - 10, 470), (330, 430), (392, 372, "c"), (452, 446), (500, 420), (560, 352, "c"), (630, 438),
               (690, 400, "c"), (760, 450), (vx1 + 10, 430)]
    far = ridge("FarPeaks", far_pts, sc.vgrad(-180, 180, [("FF5E6A94", 0.0), ("FF39426A", 1.0)]))
    caps = [S(O, f"FarCap{i}", pts, F("FFDCE4EE")) for i, pts in enumerate((
        [(392, 372, "c"), (414, 398), (404, 404), (396, 396), (384, 408), (372, 398)],
        [(560, 352, "c"), (588, 386), (574, 392), (562, 382), (548, 396), (536, 384)],
        [(690, 400, "c"), (712, 422), (700, 428), (690, 420), (680, 430), (668, 420)]))]
    mid_pts = [(vx0 - 10, 520), (340, 498), (420, 450, "c"), (476, 506), (520, 492), (620, 444, "c"),
               (690, 500), (vx1 + 10, 486)]
    mid = ridge("MidPeaks", mid_pts, sc.vgrad(-140, 140, [("FF46507A", 0.0), ("FF2A3154", 1.0)]))
    mid_caps = [S(O, f"MidCap{i}", pts, F("FFC8D2E2")) for i, pts in enumerate((
        [(420, 450, "c"), (448, 478), (434, 482), (424, 474), (410, 486), (398, 470)],
        [(620, 444, "c"), (652, 474), (636, 480), (624, 470), (610, 482), (594, 468)]))]
    near_pts = [(vx0 - 10, 590), (360, 572), (460, 586), (560, 566), (660, 582), (vx1 + 10, 570)]
    near = ridge("NearRidge", near_pts, F("FF1C2440"))
    snow_field = ridge("SnowField", [(vx0 - 10, 616), (420, 604), (540, 612), (650, 600), (vx1 + 10, 610)],
                       sc.vgrad(-60, 60, [("FFB4C0D6", 0.0), ("FF8C98B4", 1.0)]))

    def pine(name: str, x: float, base: float, h: float, col: str) -> El:
        w = h * 0.38
        pts = [(x, base - h, "c")]
        for k in range(1, 5):
            t = k / 4
            pts += [(x + w * t * 0.6, base - h + h * t * 0.86 - h * 0.05, "c"), (x + w * t, base - h + h * t * 0.9, "c")]
        pts += [(x + w * 0.1, base, "c"), (x - w * 0.1, base, "c")]
        for k in range(4, 0, -1):
            t = k / 4
            pts += [(x - w * t, base - h + h * t * 0.9, "c"), (x - w * t * 0.6, base - h + h * t * 0.86 - h * 0.05, "c")]
        return S(O, name, pts, F(col))

    pines = [pine(f"Pine{i}", x, 600 + rnd.uniform(-6, 8), h, "FF16203A")
             for i, (x, h) in enumerate(((366, 70), (392, 96), (418, 62), (604, 74), (676, 104), (708, 66)))]
    pine_snow = [S(O, f"PineSnow{i}", [(x - 9, 604 - h * 0.62), (x, 600 - h * 0.74), (x + 9, 604 - h * 0.62),
                                        (x, 606 - h * 0.6)], F("C8DDE6F2"))
                 for i, (x, h) in enumerate(((392, 96), (676, 104)))]
    ledge = S(O, "SnowLedge", [(GLASS[0] - 10, GLASS[3] + 4, "c"), (GLASS[0] - 10, 616), (400, 606), (470, 614),
                               (540, 604), (620, 612), (700, 604), (GLASS[2] + 10, 614), (GLASS[2] + 10, GLASS[3] + 4, "c")],
              F("FFE4EAF2"))

    # aurora (event): three ribbons that ripple, in front of the sky, behind the peaks
    aurora_bands, aurora_tracks = [], []
    for b, (y_top, y_bot, x_off, ph) in enumerate(((262, 380, -10, 0.0), (300, 420, 20, 1.7), (250, 340, 40, 3.1))):
        xs = [GLASS[0] - 30 + i * (GLASS[2] - GLASS[0] + 60) / 6 for i in range(7)]
        top = [(x, y_top + 22 * math.sin(i * 1.1 + ph)) for i, x in enumerate(xs)]
        bot = [(x, y_bot + 18 * math.sin(i * 0.9 + ph + 0.6)) for i, x in enumerate(xs)]
        cx = (xs[0] + xs[-1]) / 2
        cy = (y_top + y_bot) / 2
        hgt = y_bot - y_top
        band = S((cx, cy), f"AuroraBand{b}", [*top, *reversed(bot)],
                 sc.vgrad(-hgt / 2 - 20, hgt / 2 + 20, [("00B49CFF", 0.0), ("70A08CFF", 0.35), ("B47CF0B4", 0.8),
                                                         ("00A8FFC8", 1.0)]),
                 origin=(cx, cy), tension=0.9)
        path = next(c for c in band.children if c.tag == "PointsPath")
        verts = path.children
        n = len(top)
        for j, v in enumerate(verts):
            k = j if j < n else 2 * n - 1 - j
            vy0_ = float(v.attrs["y"])
            amp = 14.0 if j >= n else 8.0
            keys = [(f, vy0_ + amp * math.sin(2 * math.pi * f / 160 + k * 0.85 + ph)) for f in range(0, 481, 40)]
            aurora_tracks.append(sc.T(v, y=keys))
        node = d("Node", band, x=float(cx + x_off), y=float(cy), name=f"AuroraRibbon{b}")
        band.attrs["x"], band.attrs["y"] = 0.0, 0.0
        aurora_bands.append(node)
        aurora_tracks.append(sc.T(node, x=[(0, cx + x_off - 24.0), (240, cx + x_off + 10.0), (480, cx + x_off + 30.0)],
                                  scaleY=[(0, 0.7), (120, 1.08), (300, 0.92), (480, 1.0)]))
    aurora = d("Node", *aurora_bands, x=0.0, y=0.0, opacity=0.0, name="Aurora")
    sc.one_shot("aurora", sc.A("ev_aurora", EVENT_FRAMES["aurora"], [
        sc.T(aurora, opacity=[(0, 0.0), (70, 1.0), (380, 1.0), (480, 0.0)]), *aurora_tracks]))

    plane0 = [aurora, moon_rig, moon_drawn, ledge, *pine_snow, *pines, snow_field, near, *mid_caps, mid, *caps, far,
              *stars, sky]

    # ------------------------------------------------------------ Plane1: the window
    frame = ring(sc, "WinFrame", FRAME, GLASS, sc.F("FF4E3828"), r=6)
    mullions = [rect_shape(sc, "MullionV", MULL[0] - MULL[2] / 2, GLASS[1], MULL[0] + MULL[2] / 2, GLASS[3], F("FF4E3828")),
                rect_shape(sc, "MullionH", GLASS[0], MULL[1] - MULL[2] / 2, GLASS[2], MULL[1] + MULL[2] / 2,
                           F("FF4E3828"))]
    mull_hi = [rect_shape(sc, "MullionHi", MULL[0] - MULL[2] / 2, GLASS[1], MULL[0] - MULL[2] / 2 + 3, GLASS[3],
                          F("40C8D4E8"))]
    # frost: a soft rime in the outer corners of the panes
    frost = []
    for i, (cxp, cyp) in enumerate(((GLASS[0], GLASS[1]), (GLASS[2], GLASS[1]), (GLASS[0], GLASS[3]),
                                    (GLASS[2], GLASS[3]))):
        rr = 70.0 if i < 2 else 90.0
        frost.append(E(O, f"Frost{i}", cxp, cyp, 2 * rr, 2 * rr,
                       sc.rgrad(rr, [("58E8F0FA", 0.0), ("20E8F0FA", 0.55), ("00E8F0FA", 1.0)])))

    # snow just outside the glass (scene `rain`), clipped to the panes
    clip = d("Shape", *[rect_path(sc, *p, 0.0, 0.0, name="Pane") for p in PANES], x=0.0, y=0.0, name="SnowClip")
    gx0, gy0, gx1, gy1 = GLASS
    r_ = random.Random(4040)

    def flake_sheet(name: str, count: int, tile: float, rmin: float, rmax: float, col: str) -> El:
        kids = []
        for i in range(count):
            x, u = r_.uniform(gx0 - 14, gx1 + 14), r_.uniform(0, tile)
            rr = r_.uniform(rmin, rmax)
            for k in range(0, math.ceil((gy1 - gy0) / tile) + 2):
                y = gy0 - tile + u + k * tile
                if y > gy1 + rr or y + tile < gy0 - rr:
                    continue
                kids.append(E(O, f"Flake{i}_{k}", x, y, 2 * rr, 2 * rr, F(col)))
        return d("Node", *kids, x=0.0, y=0.0, name=name)

    sheets = []
    for nm, (count, tile, period), (rmin, rmax), col in (("SnowNearSheet", SNOW_NEAR, (3.2, 5.6), "F0F4F8FC"),
                                                         ("SnowFarSheet", SNOW_FAR, (1.6, 2.8), "B0E8EEF6")):
        sheet = flake_sheet(nm, count, tile, rmin, rmax, col)
        sc.ambient(nm, sc.A(f"amb_{nm}", period, [sc.T(sheet, ease=None, y=[(0, 0.0, "linear"),
                                                                            (period, float(tile), "linear")])],
                            loop=True))
        sheets.append(sheet)
    near_sway = d("Node", sheets[0], x=0.0, y=0.0, opacity=0.0, name="SnowNear")
    far_sway = d("Node", sheets[1], x=0.0, y=0.0, opacity=0.0, name="SnowFar")
    sc.ambient("SnowSway", sc.A("amb_SnowSway", SNOW_SWAY, [
        sc.T(near_sway, ease=None, x=[(f, 9 * math.sin(2 * math.pi * f / SNOW_SWAY), "linear") for f in range(0, 241, 20)]),
        sc.T(far_sway, ease=None, x=[(f, -5 * math.sin(2 * math.pi * f / SNOW_SWAY + 1.0), "linear")
                                     for f in range(0, 241, 20)])], loop=True))
    near_sway.children.insert(0, sc.bind("rain", 18, lin_conv(sc, 1.6, hi=1.0), doc=sc.d9))
    far_sway.children.insert(0, sc.bind("rain", 18, lin_conv(sc, 1.7, -0.7, lo=0.0, hi=1.0), doc=sc.d9))
    snow = d("Node", d("ClippingShape", sourceId=clip.ref(), name="Clip"), near_sway, far_sway, x=0.0, y=0.0,
             name="SnowFall")

    # snowfall (event): a heavy flurry blown sideways, with a white-out haze
    fl_tile, fl_period = 260.0, 52
    fl_sheets = []
    for nm, count, (rmin, rmax), col in (("FlurryNear", 26, (4.0, 7.5), "F8F6FAFE"), ("FlurryFar", 34, (2.0, 3.6),
                                                                                       "C8EEF2F8")):
        fl_sheets.append(flake_sheet(nm, count, fl_tile, rmin, rmax, col))
    haze = d("Shape", *[rect_path(sc, *p, 0.0, 0.0, name="Pane") for p in PANES], F("FFDCE4EE"), x=0.0, y=0.0,
             opacity=0.0, name="FlurryHaze")
    n_ev = EVENT_FRAMES["snowfall"]
    flurry_tracks = []
    for s_, per in zip(fl_sheets, (fl_period, fl_period * 2)):
        saw = []
        for c in range(0, n_ev, per):
            saw += [(c, 0.0, "linear"), (min(c + per - 1, n_ev), fl_tile * (per - 1) / per, "linear")]
        flurry_tracks.append(sc.T(s_, ease=None, y=uniq(saw)))
    flurry_wind = d("Node", *fl_sheets, x=0.0, y=0.0, name="FlurryWind")
    flurry = d("Node", d("ClippingShape", sourceId=clip.ref(), name="Clip"), haze, flurry_wind, x=0.0, y=0.0,
               opacity=0.0, name="SnowFlurry")
    sc.one_shot("snowfall", sc.A("ev_snowfall", n_ev, [
        sc.T(flurry, opacity=[(0, 0.0), (40, 1.0), (n_ev - 70, 1.0), (n_ev, 0.0)]),
        sc.T(haze, opacity=[(0, 0.0), (80, 0.32), (n_ev - 90, 0.3), (n_ev, 0.0)]),
        sc.T(flurry_wind, ease=None, x=[(f, -18 + 30 * math.sin(f / 50.0), "linear") for f in range(0, n_ev + 1, 30)]),
        *flurry_tracks]))

    frost_node = d("Node", d("ClippingShape", sourceId=clip.ref(), name="Clip"), *frost, x=0.0, y=0.0, name="Frost")
    plane1 = [frost_node, *mull_hi, *mullions, flurry, snow, clip, frame]

    # ------------------------------------------------------------ Plane2: the back wall
    logs, grains, knots = [], [], []
    log_h, gap = 64.0, 6.0
    y = -24.0
    i = 0
    while y < FLOOR_Y + 40:
        y0_, y1_ = y, y + log_h - gap
        tone = ("FF8A5E3E", "FF6A4430", "FF3E281C") if i % 2 == 0 else ("FF805638", "FF62402C", "FF3A261A")
        grad = sc.vgrad(-(y1_ - y0_) / 2, (y1_ - y0_) / 2, [(tone[0], 0.0), (tone[1], 0.5), (tone[2], 1.0)])
        cut = y1_ > OPEN[1] and y0_ < OPEN[3]
        spans = [(-80.0, OPEN[0]), (OPEN[2], W + 80.0)] if cut else [(-80.0, W + 80.0)]
        for j, (a, b) in enumerate(spans):
            if j:
                grad = sc.vgrad(-(y1_ - y0_) / 2, (y1_ - y0_) / 2, [(tone[0], 0.0), (tone[1], 0.5), (tone[2], 1.0)])
            logs.append(rect_shape(sc, f"Log{len(logs)}", a, y0_, b, y1_, grad, r=(y1_ - y0_) * 0.45))
        for _ in range(2):
            gx = rnd.uniform(20, W - 60)
            if cut and OPEN[0] - 40 < gx < OPEN[2]:
                continue
            gy = rnd.uniform(y0_ + 12, y1_ - 12)
            ln = rnd.uniform(60, 160)
            grains.append(S(O, f"Grain{len(grains)}", [(gx, gy), (gx + ln * 0.5, gy + rnd.uniform(-3, 3)), (gx + ln, gy)],
                            L("40281810", 2.0), closed=False))
        if rnd.random() < 0.5:
            kx = rnd.uniform(40, W - 40)
            if not (cut and OPEN[0] - 30 < kx < OPEN[2] + 30):
                ky = (y0_ + y1_) / 2
                knots.append(E(O, f"Knot{len(knots)}", kx, ky, 18, 11, F("FF4A2E1E"), L("60281810", 2)))
        y += log_h
        i += 1
    chink = ring(sc, "Chink", (-80.0, -40.0, W + 80.0, FLOOR_Y + 60), OPEN, sc.F("FF4A3A30"))
    casing = ring(sc, "Casing", CASING, OPEN, sc.vgrad(-250, 250, [("FFA27A54", 0.0), ("FF7E5A3C", 1.0)]), r=8)
    casing_shadow = ring(sc, "CasingShadow", (OPEN[0] + 0, OPEN[1], OPEN[2], OPEN[3]),
                         (OPEN[0] + 8, OPEN[1] + 8, OPEN[2] - 8, OPEN[3]), sc.F("70120A08"))
    sill = d("Node", rect_shape(sc, "SillLip", CASING[0] - 14, OPEN[3] + 14, CASING[2] + 14, OPEN[3] + 22,
                                F("FF5E4028"), r=3),
             rect_shape(sc, "SillTop", CASING[0] - 14, OPEN[3] - 6, CASING[2] + 14, OPEN[3] + 16,
                        sc.vgrad(-11, 11, [("FFB88E64", 0.0), ("FF8E6644", 1.0)]), r=5),
             x=0.0, y=0.0, name="Sill")
    wall_glow = E(O, "WallGlow", STOVE_X, 960, 1100, 1100, sc.rgrad(550, [("58FFA860", 0.0), ("24FF9040", 0.5),
                                                                            ("00FF9040", 1.0)]))
    wall_cool = E(O, "WallCool", 540, 720, 760, 520, sc.rgrad(380, [("2C9CC0F0", 0.0), ("009CC0F0", 1.0)]))
    wall_shade = rect_shape(sc, "WallShade", -80, -40, W + 80, 520, sc.vgrad(-280, 280, [("60100808", 0.0),
                                                                                         ("00100808", 1.0)]))
    # the wall's light and shade, clipped to the wall (never over the view through the opening)
    wall_light = d("Node", d("ClippingShape", sourceId=chink.ref(), fillRule="evenOdd", name="Clip"), wall_cool,
                   wall_glow, wall_shade, x=0.0, y=0.0, name="WallLight")
    plane2 = [sill, casing, casing_shadow, wall_light, *knots, *grains, *logs, chink]

    # ------------------------------------------------------------ Plane3: beam, door, bell, stove
    beam = d("Node", rect_shape(sc, "BeamFace", -80, BEAM[0], W + 80, BEAM[1],
                                sc.vgrad(-33, 33, [("FF9A6C46", 0.0), ("FF6A4630", 0.55), ("FF3A2618", 1.0)]), r=10),
             rect_shape(sc, "BeamShadow", -80, BEAM[1], W + 80, BEAM[1] + 16, sc.vgrad(-8, 8, [("70100808", 0.0),
                                                                                               ("00100808", 1.0)])),
             *[S(O, f"BeamGrain{k}", [(x, BEAM[0] + 20 + k % 2 * 18), (x + 120, BEAM[0] + 22 + k % 2 * 18),
                                     (x + 240, BEAM[0] + 19 + k % 2 * 18)], L("40281810", 2.2), closed=False)
               for k, x in enumerate((40, 330, 620, 840))],
             x=0.0, y=0.0, name="Beam")

    # the door (left) on its frame
    door_x0, door_x1, door_top = -80.0, 96.0, 400.0
    door_planks = [S(O, f"DoorSeam{k}", [(x, door_top + 6), (x, FLOOR_Y - 4)], L("70281810", 3), closed=False)
                   for k, x in enumerate((-36, 8, 52))]
    door = d("Node",
             d("Node", S(O, "HingeTop", [(door_x0, 470), (60, 466), (72, 474), (60, 482), (door_x0, 482)], F("FF2A2428")),
               S(O, "HingeLow", [(door_x0, 1080), (60, 1076), (72, 1084), (60, 1092), (door_x0, 1092)], F("FF2A2428")),
               E(O, "Latch", 74, 820, 18, 30, F("FF2A2428")), E(O, "LatchRing", 74, 846, 20, 20, L("FF2A2428", 4)),
               x=0.0, y=0.0, name="DoorIron"),
             S(O, "DoorBrace", [(door_x0, 1040), (88, 560), (88, 600), (door_x0, 1080)], F("FF5A3C28")),
             *door_planks,
             rect_shape(sc, "DoorPanel", door_x0, door_top, door_x1, FLOOR_Y,
                        sc.vgrad(-400, 400, [("FF7A5438", 0.0), ("FF4E3424", 1.0)])),
             rect_shape(sc, "DoorPost", door_x1, door_top - 22, door_x1 + 22, FLOOR_Y,
                        sc.vgrad(-400, 400, [("FFA27A54", 0.0), ("FF6E4C32", 1.0)]), r=4),
             rect_shape(sc, "DoorLintel", door_x0 - 20, door_top - 26, door_x1 + 30, door_top, F("FF8E6644"), r=4),
             x=0.0, y=0.0, name="Door")

    # the bell on its bracket, with its pull rope (rope drag) and the bell event
    bx, by = BELL_PIVOT
    bell_body = S((bx, by), "BellBody", [(bx - 20, by + 16), (bx + 20, by + 16), (bx + 28, by + 52), (bx + 40, by + 84),
                                         (bx + 48, by + 92, "c"), (bx - 48, by + 92, "c"), (bx - 40, by + 84),
                                         (bx - 28, by + 52)],
                  sc.d("Fill", lin(sc.d, -48, 0, 48, 0, [("FFE2BC6A", 0.0), ("FFC0903E", 0.45), ("FF7A5420", 1.0)]),
                       name="Fill"), L("FF3A2410", 2.4), origin=(bx, by))
    bell_lip = S((bx, by), "BellLip", [(bx - 49, by + 88), (bx + 49, by + 88), (bx + 50, by + 96, "c"),
                                       (bx - 50, by + 96, "c")], F("FF8A6024"), L("FF3A2410", 2), origin=(bx, by))
    bell_shine = S((bx, by), "BellShine", [(bx - 14, by + 22), (bx - 20, by + 50), (bx - 30, by + 82)],
                   L("90FFF0C8", 4), closed=False, origin=(bx, by))
    crown = E((bx, by), "BellCrown", bx, by + 8, 20, 20, L("FF6A4A20", 5))
    clapper = d("Node", E(O, "ClapperBall", 0, 104, 16, 16, F("FF4A3418"), L("FF2A1A0A", 2)),
                S(O, "ClapperRod", [(0, 30), (0, 98)], L("FF4A3418", 4), closed=False),
                x=0.0, y=0.0, name="Clapper")
    tilt = d("Node", bell_shine, bell_lip, bell_body, clapper, crown, x=bx, y=by, name="BellTilt")
    swing = d("Node", tilt, x=0.0, y=0.0, name="BellSwing")
    tilt.attrs.update(x=0.0, y=0.0)
    swing.attrs.update(x=bx, y=by)
    bracket = d("Node", rect_shape(sc, "BracketPlate", 120, 438, 136, 504, F("FF2A2428"), r=4),
                S(O, "BracketArm", [(136, 464), (228, 464)], L("FF2A2428", 6), closed=False),
                S(O, "BracketScroll", [(136, 490), (150, 476), (168, 466)], L("FF2A2428", 4), closed=False),
                E(O, "Pulley", PULLEY[0], PULLEY[1], 18, 18, F("FF3A3438"), L("FF1A1418", 2)),
                x=0.0, y=0.0, name="BellBracket")
    rope_line = S(O, "RopeCore", [(0, 0), (0, ROPE_LEN)], L("FFC8A874", 6.5), closed=False, origin=O)
    rope_edge = S(O, "RopeEdge", [(0, 0), (0, ROPE_LEN)], L("FF6A4E2C", 9.5), closed=False, origin=O)
    twists = d("Shape", *[smooth_path(sc.d, [(-3.0, t), (3.0, t + 6.0)], closed=False)
                          for t in (10.0 + 13.0 * i for i in range(int((ROPE_LEN - 16) // 13) + 1))],
               L("FF8A6C44", 1.8), x=0.0, y=0.0, name="RopeTwist")
    rope = d("Node", sc.bind("rope", 17, lin_conv(sc, ROPE_PULL / ROPE_LEN, 1.0), doc=sc.d9), twists, rope_line,
             rope_edge, x=0.0, y=4.0, name="Rope")
    toggle = d("Node", sc.bind("rope", 14, lin_conv(sc, ROPE_PULL, 4 + ROPE_LEN), doc=sc.d9),
               rect_shape(sc, "ToggleWood", -9, 4, 9, 4 + TOGGLE_H, sc.vgrad(-20, 20, [("FFB88A58", 0.0),
                                                                                      ("FF7A5434", 1.0)]),
                          r=8),
               E(O, "ToggleKnot", 0, 2, 14, 10, F("FF8A6C44")),
               x=0.0, y=4.0 + ROPE_LEN, name="RopeToggle")
    tilt.children.insert(0, sc.bind("rope", 15, lin_conv(sc, ROPE_TILT), doc=sc.d9))
    rings_ = [S(O, f"BellRing{k}", [(-20, -26), (0, -34 - 4 * k), (20, -26)], L("C0FFE8B8", 3.5), closed=False,
                origin=O, opacity=0.0) for k in range(3)]
    ring_nodes = [d("Node", r_k, x=bx + sx * 62, y=by + 54 + 18 * (k == 2), rotation=sx * 1.25, name=f"BellRingSide{k}")
                  for k, (r_k, sx) in enumerate(zip(rings_, (-1, 1, 1)))]
    # the rope hangs from the pulley; it sways with the ringing bell (a lagged echo of its swing)
    rope_swing = d("Node", toggle, rope, x=PULLEY[0], y=PULLEY[1], name="RopeSwing")
    bell_rig = d("Node", rope_swing, *ring_nodes, swing, bracket, x=0.0, y=0.0, name="BellRig")
    nb = EVENT_FRAMES["bell"]
    sw = [(0, 0.0), (8, 0.3), (24, -0.24), (40, 0.18), (56, -0.12), (72, 0.08), (88, -0.045), (104, 0.02),
          (124, 0.0), (nb, 0.0)]
    cl = [(0, 0.0), (6, -0.1), (12, 0.32), (16, 0.2), (28, -0.3), (32, -0.18), (44, 0.26), (48, 0.14), (62, -0.16),
          (80, 0.08), (100, -0.03), (124, 0.0), (nb, 0.0)]
    ring_tracks = []
    for k, (rn, r_k, f0) in enumerate(zip(ring_nodes, rings_, (12, 28, 44))):
        ring_tracks.append(sc.T(r_k, ease=None, opacity=[(0, 0.0), (f0, 0.0, "hold"), (f0 + 1, 1.0), (f0 + 40, 0.0),
                                                         (nb, 0.0)],
                                scaleX=[(0, 0.6), (f0, 0.6, "hold"), (f0 + 1, 0.6), (f0 + 40, 1.8), (nb, 1.8)],
                                scaleY=[(0, 0.6), (f0, 0.6, "hold"), (f0 + 1, 0.6), (f0 + 40, 1.8), (nb, 1.8)]))
    rope_sw = uniq([(0, 0.0)] + [(min(f + 5, nb), round(ROPE_SWAY * v, 4)) for f, v in sw[1:]] + [(nb, 0.0)])
    sc.one_shot("bell", sc.A("ev_bell", nb, [sc.T(swing, rotation=sw), sc.T(clapper, rotation=cl),
                                            sc.T(rope_swing, rotation=rope_sw), *ring_tracks]))

    # the stove
    sx0, sy0, sx1, sy1 = STOVE_BODY
    dx0, dy0, dx1, dy1 = STOVE_DOOR
    fire_glow = rect_shape(sc, "FireBed", dx0 - 6, dy0 - 6, dx1 + 6, dy1 + 6,
                           sc.rgrad(70, [("FFFFE0A0", 0.0), ("FFFF9A40", 0.5), ("FFC04A20", 1.0)], cy=30))
    tongues, tongue_tracks = [], []
    for k, (tx, th, tw_, per) in enumerate(((-26, 46, 26, 30), (0, 66, 34, 40), (24, 50, 28, 60), (-8, 36, 20, 24))):
        base = dy1 - 6
        pts = [(STOVE_X + tx - tw_ / 2, base), (STOVE_X + tx - tw_ * 0.45, base - th * 0.45),
               (STOVE_X + tx - tw_ * 0.1, base - th * 0.8), (STOVE_X + tx + 2, base - th, "c"),
               (STOVE_X + tx + tw_ * 0.3, base - th * 0.6), (STOVE_X + tx + tw_ * 0.5, base - th * 0.2),
               (STOVE_X + tx + tw_ / 2, base)]
        tg = S((STOVE_X + tx, base), f"Tongue{k}", pts,
               sc.d("Fill", lin(sc.d, 0, 0, 0, -th, [("FFFFF2C0", 0.0), ("FFFFB040", 0.55), ("D0FF6A20", 1.0)]),
                    name="Fill"), origin=(STOVE_X + tx, base))
        tn = d("Node", tg, x=float(STOVE_X + tx), y=float(base), name=f"TonguePivot{k}")
        tg.attrs.update(x=0.0, y=0.0)
        tongues.append(tn)
        r2 = random.Random(70 + k)
        fs = [0, per // 3, 2 * per // 3, per]
        tongue_tracks.append(sc.A(f"amb_tongue{k}", per, [sc.T(tn, scaleY=[(f, 1.0 if f in (0, per) else
                                                                           r2.uniform(0.78, 1.2)) for f in fs],
                                                                rotation=[(f, 0.0 if f in (0, per) else
                                                                           r2.uniform(-0.12, 0.12)) for f in fs])],
                                    loop=True))
        sc.ambient(f"StoveTongue{k}", tongue_tracks[-1])
    fire = d("Node", *tongues, fire_glow, x=0.0, y=0.0, name="StoveFire")
    fire_flare = d("Node", fire, x=0.0, y=0.0, name="FireFlare")
    # the door: an arched glass behind a grille
    door_glass_clip = d("Shape", d("Rectangle", width=dx1 - dx0, height=dy1 - dy0, x=STOVE_X - STOVE_X,
                                   y=0.0, cornerRadiusTL=40.0, cornerRadiusTR=40.0, cornerRadiusBL=4.0,
                                   cornerRadiusBR=4.0, name="Path"),
                        x=STOVE_X, y=(dy0 + dy1) / 2, name="DoorGlassClip")
    fire_clip = d("Node", d("ClippingShape", sourceId=door_glass_clip.ref(), name="Clip"), fire_flare, x=0.0, y=0.0,
                  name="FireWindow")
    grille = d("Shape", *[rect_path(sc, x - 2.5, dy0 - 4, x + 2.5, dy1 + 2, 0.0, 0.0, name="Bar")
                          for x in (STOVE_X - 30, STOVE_X - 10, STOVE_X + 10, STOVE_X + 30)],
               rect_path(sc, dx0, dy0 + 40, dx1, dy0 + 45, 0.0, 0.0, name="Bar"),
               F("FF201C22"), x=0.0, y=0.0, name="Grille")
    door_frame = d("Shape", d("Rectangle", width=dx1 - dx0 + 24, height=dy1 - dy0 + 22, cornerRadiusTL=50.0,
                              cornerRadiusTR=50.0, cornerRadiusBL=6.0, cornerRadiusBR=6.0, name="Path"),
                   d("Rectangle", width=dx1 - dx0, height=dy1 - dy0, y=2.0, cornerRadiusTL=40.0, cornerRadiusTR=40.0,
                     cornerRadiusBL=4.0, cornerRadiusBR=4.0, name="Opening"),
                   d("Fill", lin(sc.d, -60, -60, 60, 60, [("FF5A5460", 0.0), ("FF2E2A32", 1.0)]), fillRule="evenOdd",
                     name="Fill"),
                   x=STOVE_X, y=(dy0 + dy1) / 2 - 2, name="DoorFrame")
    stove = d("Node",
              E(O, "DoorKnob", dx1 + 24, (dy0 + dy1) / 2, 14, 14, F("FFB89A6A"), L("FF2A2428", 2)),
              grille, door_frame, fire_clip, door_glass_clip,
              rect_shape(sc, "AshDoor", STOVE_X - 40, 1102, STOVE_X + 40, 1132, F("FF2A262C"), r=4),
              *[rect_shape(sc, f"AshSlit{k}", STOVE_X - 26 + 18 * k, 1112, STOVE_X - 18 + 18 * k, 1122,
                           F("FF8A3E1E")) for k in range(3)],
              rect_shape(sc, "StoveBand", sx0, 1086, sx1, 1096, F("FF4A4450")),
              rect_shape(sc, "StoveTop", sx0 - 16, 884, sx1 + 16, 910,
                         sc.vgrad(-13, 13, [("FF5E5866", 0.0), ("FF34303A", 1.0)]), r=6),
              rect_shape(sc, "StoveBody", sx0, sy0, sx1, sy1,
                         sc.d("Fill", lin(sc.d, -100, 0, 100, 0, [("FF2A262E", 0.0), ("FF3A3640", 0.6),
                                                                 ("FF54464A", 1.0)]), name="Fill"), r=18),
              *[S(O, f"StoveLeg{k}", [(x - 12, sy1 - 4), (x + 12, sy1 - 4), (x + 8 + 10 * s_, FLOOR_Y - 6),
                                      (x + 14 * s_, FLOOR_Y, "c"), (x - 8 * s_, FLOOR_Y - 4)], F("FF24202A"))
                for k, (x, s_) in enumerate(((sx0 + 18, -1), (sx1 - 18, 1)))],
              x=0.0, y=0.0, name="Stove")
    pipe = d("Node",
             *[rect_shape(sc, f"PipeCollar{k}", PIPE[0] - 4, yy, PIPE[1] + 4, yy + 12, F("FF4A4450"), r=3)
               for k, yy in enumerate((BEAM[1] - 2, 520, 872))],
             E(O, "Damper", PIPE[1] + 10, 700, 16, 8, F("FF6A5E58")),
             rect_shape(sc, "PipeBody", PIPE[0], BEAM[1], PIPE[1], 886,
                        sc.d("Fill", lin(sc.d, -18, 0, 18, 0, [("FF24202A", 0.0), ("FF3E3842", 0.6), ("FF5A4844", 1.0)]),
                             name="Fill")),
             x=0.0, y=0.0, name="StovePipe")
    kx, ky = 828.0, 862.0
    kettle = d("Node", E(O, "KettleKnob", kx, ky - 26, 12, 8, F("FF2A2428")),
               S(O, "KettleHandle", [(kx - 26, ky - 14), (kx, ky - 44), (kx + 26, ky - 14)], L("FF2A2428", 4),
                 closed=False),
               S(O, "KettleSpout", [(kx - 26, ky + 4), (kx - 46, ky - 10), (kx - 52, ky - 14), (kx - 44, ky - 4),
                                    (kx - 28, ky + 14)], F("FF8A5A3E"), L(INK, 2)),
               S(O, "KettleBody", [(kx - 34, ky + 22, "c"), (kx - 34, ky), (kx - 20, ky - 22), (kx + 20, ky - 22),
                                   (kx + 34, ky), (kx + 34, ky + 22, "c")],
                 sc.d("Fill", lin(sc.d, -34, 0, 34, 0, [("FFB07A50", 0.0), ("FF8A5638", 1.0)]), name="Fill"),
                 L(INK, 2)),
               x=0.0, y=0.0, name="Kettle")
    steam, steam_tracks = [], []
    for k in range(3):
        p = E(O, f"SteamPuff{k}", kx - 54, ky - 16, 26, 26, sc.rgrad(13, [("50E8ECF0", 0.0), ("00E8ECF0", 1.0)]),
              opacity=0.0)
        steam.append(p)
        off = k * 80
        fr = sorted(set(range(0, 241, 20)) | {240 - off - 1, 240 - off} - {241})
        fr = [f for f in fr if 0 <= f <= 240]

        def at(f: int, off: int = off, k: int = k) -> tuple[float, float, float, float]:
            t = ((f + off) % 240) / 240
            return (-8 * t + 6 * math.sin(t * 7 + k), -110 * t, 0.6 + 1.6 * t, math.sin(math.pi * t) ** 1.4 * 0.9)

        mode = {f: ("hold" if f == 240 - off - 1 else "linear") for f in fr}
        base_x, base_y = kx - 54, ky - 16
        steam_tracks.append(sc.T(p, ease=None, x=[(f, base_x + at(f)[0], mode[f]) for f in fr],
                                 y=[(f, base_y + at(f)[1], mode[f]) for f in fr],
                                 scaleX=[(f, at(f)[2], mode[f]) for f in fr],
                                 scaleY=[(f, at(f)[2], mode[f]) for f in fr],
                                 opacity=[(f, at(f)[3], mode[f]) for f in fr]))
    sc.ambient("KettleSteam", sc.A("amb_KettleSteam", 240, steam_tracks, loop=True))
    steam_node = d("Node", *steam, x=0.0, y=0.0, name="Steam")

    # the stove's glow (flicker) and its flare
    stove_glow = E(O, "StoveGlow", STOVE_X, (dy0 + dy1) / 2 + 10, 420, 420,
                   sc.rgrad(210, [("70FFB050", 0.0), ("28FF8A30", 0.45), ("00FF8A30", 1.0)]))
    flare_glow = E(O, "FlareGlow", STOVE_X, (dy0 + dy1) / 2, 760, 760,
                   sc.rgrad(380, [("A0FFC870", 0.0), ("40FF9A40", 0.4), ("00FF8A30", 1.0)]), opacity=0.0)
    sparks = []
    n_fl = EVENT_FRAMES["flare"]
    flare_tracks = []
    for k in range(12):
        sp = E(O, f"Spark{k}", 0, 0, 7, 7, F("FFFFD27A"), opacity=0.0)
        sparks.append(sp)
        launch, life = 8 + 3 * k, 46 + (k * 7) % 30
        dirx = (-1 if k % 2 else 1) * (0.3 + (k % 5) * 0.25)
        frames = sorted({0, launch, n_fl, *range(launch, min(n_fl, launch + life) + 1, 4)})

        def age(f: int, launch: int = launch, life: int = life) -> float:
            return max(0.0, min(1.0, (f - launch) / life))
        x0s, y0s = STOVE_X + (k % 4 - 1.5) * 14, (dy0 + dy1) / 2 + 6
        flare_tracks.append(sc.T(sp, ease=None,
                                 x=[(f, x0s + dirx * 120 * (1 - math.exp(-2.4 * age(f))), "linear") for f in frames],
                                 y=[(f, y0s - 230 * age(f) + 120 * age(f) ** 2 + 40 * age(f) * (k % 3), "linear")
                                    for f in frames],
                                 opacity=[(f, (min(1.0, age(f) * 10) * (1 - age(f)) ** 0.8)
                                           if launch <= f <= launch + life else 0.0, "linear") for f in frames]))
    flare_sparks = d("Node", *sparks, x=0.0, y=0.0, name="FlareSparks")
    flare_wash = d("Shape", d("Rectangle", width=float(W + 40), height=float(H + 40), originX=0.0, originY=0.0,
                              name="Path"),
                   sc.rgrad(1300, [("FFFFB060", 0.0), ("00FF8030", 1.0)], cx=STOVE_X - W / 2, cy=1010 - H / 2),
                   x=-20.0, y=-20.0, opacity=0.0, name="FlareWash")
    sc.one_shot("flare", sc.A("ev_flare", n_fl, [
        sc.T(fire_flare, scaleX=[(0, 1.0), (6, 0.9), (16, 1.35), (60, 1.2), (n_fl, 1.0)],
             scaleY=[(0, 1.0), (6, 0.85), (14, 1.7), (40, 1.5), (n_fl, 1.0)]),
        sc.T(flare_glow, opacity=[(0, 0.0), (14, 1.0), (40, 0.7), (n_fl, 0.0)],
             scaleX=[(0, 0.8), (14, 1.1), (n_fl, 1.0)], scaleY=[(0, 0.8), (14, 1.1), (n_fl, 1.0)]),
        sc.T(flare_wash, opacity=[(0, 0.0), (14, 0.28), (36, 0.16), (n_fl, 0.0)]),
        *flare_tracks]))
    # fire_flare pivots on the door's bottom
    fire_flare.attrs.update(x=STOVE_X, y=dy1)
    fire.attrs.update(x=-STOVE_X, y=-dy1)

    # festive (December): a pine garland and lights along the beam, a stocking by the pipe
    swag = []
    hooks = [80.0, 260.0, 440.0, 620.0, 800.0, 980.0]
    for a, b in zip(hooks, hooks[1:]):
        for t in (0.0, 0.25, 0.5, 0.75):
            swag.append((a + (b - a) * t, BEAM[1] - 4 + 46 * math.sin(math.pi * t)))
    swag.append((hooks[-1], BEAM[1] - 4))
    with sc.minting(sc.d9):
        garland = d("Node",
                    *[E(O, f"GarlandBow{k}", x, BEAM[1] - 2, 26, 16, F("FFB0404A")) for k, x in enumerate(hooks)],
                    S(O, "GarlandTips", swag, L("FF4E8A5A", 10), closed=False),
                    S(O, "GarlandBody", swag, L("FF2A5A3C", 22), closed=False),
                    x=0.0, y=0.0, name="Garland")
        stocking = d("Node",
                     S(O, "StockingCuff", [(778, 640), (830, 640), (832, 660), (776, 660)], F("FFEDE8E0"), L(INK, 2)),
                     S(O, "StockingSock", [(782, 656), (826, 656), (826, 704), (814, 734), (784, 742), (762, 736),
                                           (756, 720), (768, 710), (784, 706)], F("FFB43C44"), L(INK, 2)),
                     S(O, "StockingLoop", [(804, 640), (808, 624), (814, 640)], L("FFB43C44", 3), closed=False),
                     E(O, "StockingNail", 808, 624, 8, 8, F("FF2A2428")),
                     x=0.0, y=0.0, name="Stocking")
        festive_decor = d("Node", sc.bind("festive", 18, lin_conv(sc, 1.0, lo=0.0, hi=1.0), doc=sc.d9),
                          stocking, garland, x=0.0, y=0.0, opacity=0.0, name="FestiveDecor")
    lights_pts = [(x, y + 8) for i, (x, y) in enumerate(swag) if i % 2 == 0]
    festive_lights = world_kit.festive_lights(sc, sc.d9, lights_pts, ("FFFFD27A", "FF8AE0D0"))

    plane3 = [flare_sparks, festive_lights, festive_decor, steam_node, kettle, flare_glow, stove_glow, stove, pipe,
              bell_rig, door, beam]

    # ------------------------------------------------------------ Plane4: the floor
    floor = rect_shape(sc, "Floor", -90, FLOOR_Y - 10, W + 90, H + 60,
                       sc.vgrad(-(H + 70 - FLOOR_Y) / 2, (H + 70 - FLOOR_Y) / 2, [("FF7A5236", 0.0), ("FF3E2818", 1.0)]))
    planks = [S(O, f"Plank{k}", [(x0, FLOOR_Y), (x0 + (x0 - 540) * 1.9, H + 60)], L("50180C06", 3), closed=False)
              for k, x0 in enumerate(range(-240, 1340, 120))]
    seams = [S(O, f"PlankJoint{k}", [(x, y_), (x + 60 + (x - 540) * 0.08, y_)], L("40180C06", 2.5), closed=False)
             for k, (x, y_) in enumerate(((60, 1290), (380, 1460), (700, 1240), (180, 1640), (900, 1560), (520, 1800)))]
    floor_shade = rect_shape(sc, "FloorShade", -90, FLOOR_Y - 10, W + 90, FLOOR_Y + 40,
                             sc.vgrad(-25, 25, [("80100806", 0.0), ("00100806", 1.0)]))
    rug_c = (860.0, 1420.0)
    rug_rings = []
    for k, (w_, h_, col) in enumerate(((580, 220, "FF3C625E"), (530, 190, "FFC4AE88"), (470, 162, "FF8A4A3A"),
                                       (400, 132, "FF4C7A72"), (320, 100, "FFC4AE88"), (230, 68, "FF8A4A3A"),
                                       (130, 36, "FF4C7A72"))):
        rug_rings.append(E(O, f"RugBraid{k}", *rug_c, w_, h_, F(col), L("50180C06", 2.5)))
    rug = d("Node", *reversed(rug_rings), x=0.0, y=0.0, name="Rug")
    key = gen_scenes.SCENES[SCENE_ID].key
    with sc.minting(sc.d9):
        pool_grad = rad(sc.d, 0.0, 0.0, 380.0, [(key, 0.0), ("00" + key[2:], 1.0)])
        pool_grad.children[0].children.append(sc.bind("lightKey", 38, doc=sc.d9))
        pool_grad.attrs["opacity"] = 0.42
    pool = d("Shape", ellipse(sc.d, 760, 760), d("Fill", pool_grad, name="Fill"), x=STOVE_X - 20, y=FLOOR_Y + 110,
             scaleY=0.36, name="FloorPool")
    plane4 = [pool, rug, floor_shade, *seams, *planks, floor]

    # ------------------------------------------------------------ Plane5: the foreground
    basket = d("Node",
               *[d("Node", E(O, "LogEndRing", 0, 0, 22, 18, L("FF8A5A38", 2.2)),
                   E(O, "LogEnd", 0, 0, 52, 44, F("FFC8945E"), L("FF5A3820", 3)),
                   x=float(x), y=float(y_), name=f"BasketLog{k}")
                 for k, (x, y_) in enumerate(((40, 1700), (96, 1688), (150, 1706), (70, 1736), (128, 1742)))],
               S(O, "BasketWeave", [(-20, 1780), (230, 1780)], L("60301C0C", 4), closed=False),
               S(O, "BasketWeave2", [(-24, 1840), (236, 1840)], L("60301C0C", 4), closed=False),
               S(O, "BasketBody", [(-40, 1730, "c"), (240, 1730, "c"), (222, 1960, "c"), (-30, 1960, "c")],
                 sc.vgrad(-115, 115, [("FF9A7046", 0.0), ("FF5E4026", 1.0)]), L(INK, 3)),
               x=0.0, y=0.0, name="LogBasket")
    boots = []
    for k, (bx_, by_) in enumerate(((900.0, 1790.0), (1000.0, 1810.0))):
        boots.append(d("Node",
                       S(O, "BootSnow", [(bx_ - 50, by_ + 92), (bx_ - 30, by_ + 80), (bx_ - 4, by_ + 86), (bx_ + 4, by_ + 96)],
                         F("D8EEF2F8")),
                       S(O, "BootCuff", [(bx_ - 6, by_ - 10), (bx_ + 52, by_ - 10), (bx_ + 54, by_ + 8), (bx_ - 8, by_ + 8)],
                         F("FFD8CCB8"), L(INK, 2.5)),
                       S(O, "BootShape", [(bx_, by_), (bx_ + 46, by_), (bx_ + 50, by_ + 90), (bx_ + 46, by_ + 110, "c"),
                                          (bx_ - 52, by_ + 110, "c"), (bx_ - 56, by_ + 92), (bx_ - 30, by_ + 78),
                                          (bx_ - 4, by_ + 70)],
                         sc.vgrad(-55, 55, [("FF6A4A36", 0.0), ("FF3A281C", 1.0)]), L(INK, 3)),
                       x=0.0, y=0.0, name=f"Boot{k}"))
    plane5 = [*boots, basket]

    # ------------------------------------------------------------ flicker (the key light loops in the file)
    sc.ambient("StoveFlicker", sc.A("amb_StoveFlicker", FLICKER_FRAMES, [
        sc.T(stove_glow, opacity=STOVE_FLICKER,
             scaleX=[(0, 1.0), (60, 1.06), (120, 1.0)], scaleY=[(0, 1.0), (60, 1.06), (120, 1.0)]),
        sc.T(wall_glow, opacity=[(f, round(0.78 + 1.1 * (v - 0.8), 4)) for f, v in STOVE_FLICKER]),
        sc.T(pool, opacity=[(f, round(0.8 + 1.0 * (v - 0.8), 4)) for f, v in STOVE_FLICKER])], loop=True))

    # ------------------------------------------------------------ props
    hits = [sc.hit("dog", *DOG_HIT), sc.hit("stove", STOVE_X, 1030, 240, 330), sc.hit("bell", bx, by + 52, 110, 120),
            sc.hit("window", (GLASS[0] + GLASS[2]) / 2, (GLASS[1] + GLASS[3]) / 2, GLASS[2] - GLASS[0],
                   GLASS[3] - GLASS[1])]
    for h_ in hits:
        sc.prop(str(h_.attrs["name"])[4:], h_)

    content = [flare_wash, *plane5, *plane4, *plane3, *plane2, *plane1, *plane0]
    with sc.minting(sc.d8):
        dog_npc(sc, content, hits)
    return sc.write(content, hits)


# ====================================================================== the dog
def dog_path() -> tuple[list[float], list[float], list[float], list[float]]:
    """(npcX at each waypoint, x, y, scale) of the dog's paw line along its path."""
    ts = arc_params([(x, y) for x, y, _ in DOG_WAYPOINTS])
    return ts, [x for x, _, _ in DOG_WAYPOINTS], [y for _, y, _ in DOG_WAYPOINTS], [s for _, _, s in DOG_WAYPOINTS]


def dog_walk_speed() -> float:
    """npcX per second at which the trot's planted paws do not slide (average scale)."""
    ts, xs, ys, ss = dog_path()
    length = sum(math.hypot(x1 - x0, y1 - y0) for x0, y0, x1, y1 in zip(xs, ys, xs[1:], ys[1:]))
    px_per_s = DOG_STRIDE * DOG_WALK_SCALE * (sum(ss) / len(ss)) * 60 / DOG_WALK
    return px_per_s / length


LEG_NAMES = ("DogLegNearF", "DogLegNearB", "DogLegFarF", "DogLegFarB")


def walk_tracks(bob: El, joints: dict[str, list], frames: int) -> dict[El, dict[str, list]]:
    """scene_npc's walker IK (the cat's stance / swing, thigh 20, shin 19 local px, stride 62), one
    stride per `frames`, for the dog's leg names (a copy of `scene_npc._walk_tracks`)."""
    keys: dict[El, dict[str, list]] = {}
    samples = list(range(0, frames + 1, 2)) + ([frames] if frames % 2 else [])
    bob_keys = []
    for index, (name, ph) in enumerate(zip(LEG_NAMES, (0.0, math.pi, math.pi * 0.5, math.pi * 1.5))):
        hip_k, knee_k, paw_k = [], [], []
        for fr in samples:
            phase = 2 * math.pi * fr / frames
            p = ((phase + ph) / (2 * math.pi)) % 1.0
            if p < 0.6:
                dx, lift = 62 * (p - 0.3), 0.0
            else:
                t = (p - 0.6) / 0.4
                dx, lift = 18.6 * math.cos(math.pi * t), 12 * math.sin(math.pi * t) ** 1.5
            dy = 32 - lift + 2.2 * math.sin(phase) ** 2
            dist = min(38.95, math.hypot(dx, dy))
            bend = (1 if index % 2 else -1) * math.acos((dist ** 2 - 20 ** 2 - 19 ** 2) / (2 * 20 * 19))
            hip = math.atan2(-dx, dy) - math.atan2(19 * math.sin(bend), 20 + 19 * math.cos(bend))
            hip_k.append((fr, hip, "linear"))
            knee_k.append((fr, bend, "linear"))
            paw_k.append((fr, -hip - bend, "linear"))
            if index == 0:
                bob_keys.append((fr, -3.0 * math.sin(phase) ** 2, "linear"))
        for j, k in zip(joints[name], (hip_k, knee_k, paw_k)):
            keys[j] = {"rotation": k}
    keys[bob] = {"y": bob_keys}
    return keys


CREAM, CREAM_SH, GREY, GREY_SH, NOSE = "FFF0E8DA", "FFC8BCAC", "FF8E8A98", "FF6A6676", "FF2A2228"


def dog_npc(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The dog: three drawings (asleep, sitting, trotting) in one path node `DogNpc` (Plane4, in front of
    the rug), the `Npc` layer (scene_npc.npc_layer) and the poke zone riding `npcX`."""
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    rig = Rig(sc)

    # ---- asleep, curled on the rug, head on its paws (facing left)
    body_pts = fluff(18, -40, 78, 42, 13, 0.07)
    sleep_body = d("Node",
                   S(Z, "SleepPatch", fluff(38, -58, 38, 16, 8, 0.08), F(GREY)),
                   S(Z, "SleepTail", fluff(42, -10, 44, 13, 8, 0.1), F(CREAM), L(INK, 2)),
                   S(Z, "SleepBody", body_pts, sc.vgrad(-44, 44, [(CREAM, 0.0), (CREAM_SH, 1.0)]), L(INK, 2.4)),
                   x=0.0, y=0.0, name="SleepBody")
    rig.reg(sleep_body, scaleY=1.0)
    sleep_head = d("Node",
                   S(Z, "SleepEar", [(-36, -58), (-20, -52), (-16, -30), (-20, -10), (-32, -6), (-38, -30)], F(GREY),
                     L(INK, 2)),
                   S(Z, "SleepEye", [(-66, -36), (-58, -32), (-50, -36)], L(INK, 2.2), closed=False),
                   E(Z, "SleepNose", -96, -24, 12, 9, F(NOSE)),
                   E(Z, "SleepSnout", -84, -20, 34, 22, F(CREAM), L(INK, 2)),
                   S(Z, "SleepHead", fluff(-54, -30, 36, 30, 9, 0.08), F(CREAM), L(INK, 2.4)),
                   E(Z, "SleepPaw", -74, -4, 36, 14, F(CREAM), L(INK, 2)),
                   x=0.0, y=0.0, name="SleepHeadNode")
    rig.reg(sleep_head, y=0.0)
    zzz = []
    for k in range(3):
        zx, zy = -46 + 18 * k, -96 - 24 * k
        z = S(Z, f"DogZ{k}", [(zx - 7, zy - 7, "c"), (zx + 7, zy - 7, "c"), (zx - 7, zy + 7, "c"),
                                     (zx + 7, zy + 7, "c")], L("C0FFFFFF", 2.6), closed=False, opacity=0.0)
        zzz.append(rig.reg(z, opacity=0.0, y=float(z.attrs["y"])))
    shadow_sleep = E(Z, "SleepShadow", 0, 2, 200, 22, F("40100806"))
    asleep = d("Node", *zzz, sleep_head, sleep_body, shadow_sleep, x=0.0, y=0.0, name="DogAsleep")
    rig.reg(asleep, opacity=1.0)

    # ---- sitting (front view)
    eyes, pupils = [], []
    for k, ex in enumerate((-15.0, 15.0)):
        pupil = d("Node", E(Z, f"SitGlint{k}", 2, -2, 3.4, 3.4, F("FFFFFFFF")), E(Z, f"SitPupil{k}", 0, 0, 10, 11, F(NOSE)),
                  x=0.0, y=0.0, name=f"SitPupilNode{k}")
        eye = d("Node", pupil, x=ex, y=-4.0, name=f"SitEye{k}")
        eyes.append(rig.reg(eye, scaleY=1.0))
        pupils.append(rig.reg(pupil, x=0.0))
    tongue = rig.reg(S(Z, "SitTongue", [(-7, 26), (7, 26), (6, 38), (0, 42), (-6, 38)], F("FFE07A86"), L(INK, 1.6),
                       opacity=0.0), opacity=0.0)
    face = d("Node",
             S(Z, "SitFringe", [(-40, -18), (-30, -30), (-16, -24), (-4, -34), (8, -26), (22, -34), (34, -22),
                                (42, -12), (30, -14), (18, -10), (4, -14), (-10, -10), (-26, -12)], F(CREAM)),
             E(Z, "SitNose", 0, 10, 18, 12, F(NOSE)),
             S(Z, "SitMouth", [(-10, 20), (-4, 24), (0, 19), (4, 24), (10, 20)], L(INK, 1.8), closed=False),
             tongue, *eyes,
             E(Z, "SitMuzzle", 0, 16, 46, 30, F("FFFAF4EA")),
             x=0.0, y=0.0, name="SitFace")
    rig.reg(face, x=0.0)
    ears = []
    for k, sx in enumerate((-1, 1)):
        ear = d("Node", S(Z, f"SitEarShape{k}", [(0, 0), (sx * 12, 2), (sx * 20, 24), (sx * 16, 50), (sx * 4, 54),
                                                 (sx * -4, 30)], F(GREY), L(INK, 2.2)),
                x=sx * 34.0, y=-26.0, rotation=0.0, name=f"SitEar{k}")
        ears.append(rig.reg(ear, rotation=0.0, scaleY=1.0))
    head = d("Node", face, *ears, S(Z, "SitHeadPatch", fluff(-14, -26, 30, 18, 6, 0.1), F(GREY)),
             S(Z, "SitHeadShape", fluff(0, -6, 46, 42, 11, 0.07, a0=0.2), F(CREAM), L(INK, 2.4)),
             x=0.0, y=-132.0, name="SitHead")
    rig.reg(head, rotation=0.0, x=0.0, y=-132.0)
    tail = d("Node", S(Z, "SitTailShape", [(0, 0), (14, -16), (30, -40), (40, -60), (30, -58), (20, -44), (6, -26),
                                           (-6, -8)], F(CREAM), L(INK, 2.2)),
             x=40.0, y=-24.0, name="SitTail")
    rig.reg(tail, rotation=0.0)
    sit = d("Node", head,
            *[d("Node", E(Z, f"SitPaw{k}", 0, -4, 28, 14, F(CREAM), L(INK, 2)),
                S(Z, f"SitLeg{k}", [(-11, -64), (11, -64), (12, -6), (-12, -6)], F(CREAM), L(INK, 2)),
                x=sx * 18.0, y=0.0, name=f"SitFront{k}") for k, sx in enumerate((-1, 1))],
            S(Z, "SitBib", fluff(0, -76, 26, 34, 7, 0.08, a0=0.3), F("FFFAF4EA")),
            S(Z, "SitBody", [(-56, 0, "c"), (-62, -30), (-54, -64), (-40, -96), (-20, -112), (20, -112), (40, -96),
                             (54, -64), (62, -30), (56, 0, "c")],
              sc.vgrad(-56, 56, [(CREAM, 0.0), (CREAM_SH, 1.0)]), L(INK, 2.4)),
            *[E(Z, f"SitHaunch{k}", sx * 50, -20, 44, 40, F(CREAM_SH), L(INK, 2)) for k, sx in enumerate((-1, 1))],
            tail, x=0.0, y=0.0, name="DogSitBob")
    rig.reg(sit, y=0.0, scaleX=1.0, scaleY=1.0)
    awake = d("Node", sit, E(Z, "SitShadow", 0, 2, 150, 16, F("40100806")), x=0.0, y=0.0, opacity=0.0,
              scaleX=DOG_ART_SCALE, scaleY=DOG_ART_SCALE, name="DogSit")
    rig.reg(awake, opacity=0.0)

    # ---- trotting (profile, facing left): the cat walker's legs, re-drawn fluffier, scaled up
    joints: dict[str, list] = {}

    def leg(name: str, hx: float, col: str) -> El:
        paw = d("Node", E(Z, "Paw", -4, -1, 22, 10, F(col), L(INK, 1.6)), x=0.0, y=19.0, name=name + "Foot")
        shin = d("Node", paw, S(Z, "Shin", [(-6, -2), (6, -2), (5, 19), (-5, 19)], F(col), L(INK, 1.6)),
                 x=0.0, y=20.0, name=name + "Shin")
        n = d("Node", shin, S(Z, "Thigh", [(-9, -6), (9, -6), (7, 22), (-7, 22)], F(col), L(INK, 1.6)),
              x=hx, y=-32.0, name=name)
        joints[name] = [rig.reg(n, rotation=0.0), rig.reg(shin, rotation=0.0), rig.reg(paw, rotation=0.0)]
        return n
    legs_far = [leg("DogLegFarF", -26, CREAM_SH), leg("DogLegFarB", 44, CREAM_SH)]
    legs_near = [leg("DogLegNearF", -38, CREAM), leg("DogLegNearB", 32, CREAM)]
    wtail = d("Node", S(Z, "WalkTailShape", [(0, 0), (10, -10), (24, -22), (34, -30), (26, -32), (14, -24), (2, -14),
                                              (-4, -4)], F(CREAM), L(INK, 1.8)),
              x=56.0, y=-52.0, name="WalkTail")
    rig.reg(wtail, rotation=0.0)
    wear = d("Node", S(Z, "WalkEarShape", [(0, 0), (9, 2), (14, 18), (9, 34), (0, 36), (-5, 18)], F(GREY), L(INK, 1.6)),
             x=-58.0, y=-80.0, name="WalkEar")
    rig.reg(wear, rotation=0.0)
    whead = d("Node", wear,
              E(Z, "WalkEye", -76, -74, 7, 7.5, F(NOSE)),
              E(Z, "WalkNose", -104, -64, 9, 7, F(NOSE)),
              E(Z, "WalkSnout", -92, -62, 28, 17, F("FFFAF4EA"), L(INK, 1.6)),
              S(Z, "WalkFringe", [(-84, -82), (-74, -90), (-62, -88), (-52, -80), (-62, -78), (-74, -80)], F(CREAM)),
              S(Z, "WalkHead", fluff(-68, -72, 28, 24, 9, 0.08), F(CREAM), L(INK, 2)),
              x=0.0, y=0.0, name="WalkHeadNode")
    rig.reg(whead, rotation=0.0)
    wbody = d("Node",
              S(Z, "WalkPatch", fluff(14, -58, 32, 12, 7, 0.1), F(GREY)),
              S(Z, "WalkBody", fluff(4, -46, 62, 25, 13, 0.07), sc.vgrad(-25, 25, [(CREAM, 0.0), (CREAM_SH, 1.0)]),
                L(INK, 2)),
              x=0.0, y=0.0, name="WalkBodyShape")
    bob = d("Node", whead, *legs_near, wbody, wtail, *legs_far, x=0.0, y=0.0, name="DogWalkBob")
    rig.reg(bob, y=0.0)
    f = Formulas(sc.d8, sc.vpath)
    flip = scene_npc.formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                                  *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)],
                                                                 [f.val(1000), f.op("*"), f.bound("npcLook")]))])
    wface = d("Node", sc.bind("npcLook", 16, flip, doc=sc.d8), bob, E(Z, "WalkShadow", 4, 2, 150, 12, F("40100806")),
              x=0.0, y=0.0, scaleX=DOG_WALK_SCALE, scaleY=DOG_WALK_SCALE, name="DogWalkFace")
    walker = d("Node", wface, x=0.0, y=0.0, opacity=0.0, name="DogWalk")
    rig.reg(walker, opacity=0.0)

    # ---- the path node and the poke zone
    npc = d("Node", walker, awake, asleep, x=DOG_REST[0], y=DOG_REST[1], name="DogNpc")
    rig.reg(npc, opacity=1.0)
    ts, xs, ys, ss = dog_path()
    path_binds(sc, npc, ts, xs, ys, ss)
    hit = next(h for h in hits if h.attrs.get("name") == "Hit_dog")
    hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
    path_binds(sc, hit, ts, [x + (hx - xs[0]) * s for x, s in zip(xs, ss)], [y + (hy - ys[0]) * s for y, s in zip(ys, ss)],
               ss)
    at = next(i for i, e in enumerate(content) if e.attrs.get("name") == "FloorPool")
    content.insert(at, npc)

    # ---- states (every state keys every registered property)
    sit_on = {asleep: {"opacity": [(0, 0.0)]}, awake: {"opacity": [(0, 1.0)]}}
    anims: dict[str, El | list[El]] = {}
    n = DOG_REST_LOOP
    anims["rest"] = rig.anim("npc_dog_rest", n, {
        sleep_body: {"scaleY": [(0, 1.0), (n // 2, 1.05), (n, 1.0)]},
        sleep_head: {"y": [(0, 0.0), (n // 2, -2.0), (n, 0.0)]},
        **{z: {"opacity": [(0, 0.0), (30 + 34 * k, 0.0), (64 + 34 * k, 0.9), (170 + 20 * k, 0.0), (n, 0.0)],
               "y": [(0, float(z.attrs["y"])), (30 + 34 * k, float(z.attrs["y"])),
                     (170 + 20 * k, float(z.attrs["y"]) - 26), (n, float(z.attrs["y"]) - 26)]}
           for k, z in enumerate(zzz)},
    })
    anims["away"] = rig.anim("npc_dog_away", 1, {npc: {"opacity": [(0, 0.0)]}})
    n = DOG_IDLE
    wag = [(fr, 0.38 if (fr // 10) % 2 else -0.3) for fr in range(0, n, 10)] + [(n, -0.3)]
    anims["idle"] = rig.anim("npc_dog_idle", n, {
        **sit_on,
        tail: {"rotation": wag},
        head: {"rotation": [(0, 0.0), (100, 0.0), (116, 0.16), (160, 0.16), (176, 0.0), (n, 0.0)]},
        **{e: {"scaleY": [(0, 1.0), (60, 1.0), (63, 0.1), (67, 1.0), (190, 1.0), (193, 0.1), (197, 1.0), (n, 1.0)]}
           for e in eyes},
        tongue: {"opacity": [(0, 1.0), (n, 1.0)]},
        sit: {"scaleY": [(0, 1.0), (30, 1.015), (60, 1.0), (90, 1.015), (120, 1.0), (150, 1.015), (180, 1.0),
                         (210, 1.015), (n, 1.0)]},
        **{e: {"rotation": [(0, 0.0), (116, 0.0), (126, sx * 0.12), (160, sx * 0.12), (172, 0.0), (n, 0.0)]}
           for e, sx in zip(ears, (-1, 1))},
    })
    walk_k = walk_tracks(bob, joints, DOG_WALK)
    m = DOG_WALK
    walk_k[wtail] = {"rotation": [(0, -0.2), (m // 4, 0.25), (m // 2, -0.2), (3 * m // 4, 0.25), (m, -0.2)]}
    walk_k[wear] = {"rotation": [(0, 0.1), (m // 2, -0.25), (m, 0.1)]}
    walk_k[whead] = {"rotation": [(0, 0.0), (m // 2, 0.04), (m, 0.0)]}
    anims["move"] = rig.anim("npc_dog_move", DOG_WALK, {asleep: {"opacity": [(0, 0.0)]}, walker: {"opacity": [(0, 1.0)]},
                                                          **walk_k})
    n = DOG_NOTICE

    def notice(s: float) -> El:
        return rig.anim(f"npc_dog_notice{'LCR'[int(s) + 1]}", n, {
            **sit_on,
            head: {"rotation": [(0, 0.16 * s), (60, 0.16 * s + 0.05), (n, 0.16 * s)], "x": [(0, 8.0 * s)]},
            face: {"x": [(0, 8.0 * s)]},
            **{p: {"x": [(0, 3.0 * s)]} for p in pupils},
            **{e: {"rotation": [(0, sx * -0.7)], "scaleY": [(0, 0.85)]} for e, sx in zip(ears, (-1, 1))},
            tail: {"rotation": [(0, -0.1), (30, 0.2), (60, -0.1), (90, 0.2), (n, -0.1)]},
        })
    anims["notice"] = blend3(notice)
    n = DOG_REACT
    anims["react"] = rig.anim("npc_dog_react", n, {
        **sit_on,
        sit: {"y": [(0, 0.0), (6, 4.0), (16, -46.0), (26, -54.0), (38, 0.0), (44, 4.0), (52, 0.0), (n, 0.0)],
              "scaleY": [(0, 1.0), (6, 0.88), (16, 1.1), (26, 1.03), (38, 0.9), (46, 1.02), (54, 1.0), (n, 1.0)],
              "scaleX": [(0, 1.0), (6, 1.1), (16, 0.94), (26, 0.99), (38, 1.08), (46, 0.99), (54, 1.0), (n, 1.0)]},
        tail: {"rotation": [(fr, 0.45 if (fr // 6) % 2 else -0.35) for fr in range(0, n, 6)] + [(n, -0.35)]},
        tongue: {"opacity": [(0, 1.0)]},
        **{e: {"rotation": [(0, 0.0), (16, sx * -1.1), (30, sx * -0.9), (40, 0.0), (n, 0.0)]}
           for e, sx in zip(ears, (-1, 1))},
        **{e: {"scaleY": [(0, 1.0), (14, 0.15), (34, 0.15), (40, 1.0), (n, 1.0)]} for e in eyes},
    })
    npc_layer(sc, anims)
    # M12 ruling 7: the drawing switch on its own layer, cut in 0 ms (no ghost during the pose blend)
    with sc.minting(Doc(client=0, start=M12_ID_START)):
        scene_npc.draw_layer(sc, anims, {"away": asleep, "rest": asleep, "idle": awake, "move": walker,
                                         "notice": awake, "react": awake}, "npc_dog")


# ====================================================================== the diorama
PLANES: dict[str, int | None] = {
    "FlareWash": None,
    **dict.fromkeys(("Boot", "LogBasket"), 5),
    **dict.fromkeys(("DogNpc", "FloorPool", "Rug", "FloorShade", "PlankJoint", "Plank", "Floor"), 4),
    **dict.fromkeys(("FlareSparks", "FestiveLights", "FestiveDecor", "Steam", "Kettle", "FlareGlow", "StoveGlow", "Stove",
                     "StovePipe", "BellRig", "Door", "Beam"), 3),
    **dict.fromkeys(("Sill", "Casing", "CasingShadow", "WallLight", "Knot", "Grain", "Log", "Chink"), 2),
    **dict.fromkeys(("Frost", "MullionHi", "MullionV", "MullionH", "SnowFlurry", "SnowFall", "SnowClip", "WinFrame"), 1),
    **dict.fromkeys(("Aurora", "MoonRig", "MoonDrawn", "SnowLedge", "PineSnow", "Pine", "SnowField", "NearRidge",
                     "MidCap", "MidPeaks", "FarCap", "FarPeaks", "Star", "Sky"), 0),
    "Hit_dog": 4, "Hit_stove": 3, "Hit_bell": 3, "Hit_window": 1,
}
EMISSIVE = ("FlareWash", "FlareSparks", "FlareGlow", "StoveGlow", "StoveFire", "WallGlow", "FloorPool", "Aurora",
            "MoonDrawn", "Star")
VEILS = ((0.3, 430.0, 640.0),)          # a valley haze in front of the peaks (Plane0) at fog 0
FOG_BANK = (0, 330.0, 560.0, "FFC4CCD8", 0.75)

DIORAMAS[SCENE_ID] = DioramaSpec(PLANES, EMISSIVE, VEILS)
TIME_SKY[SCENE_ID] = (HORIZON, 0.5)
scene_npc.FOG_VEILS[SCENE_ID] = (0,)
scene_npc.FOG_BANKS[SCENE_ID] = FOG_BANK


# ====================================================================== review registry
# The rope's drag handle as built (contract v12 table row; the orchestrator copies it there): the rope
# from the pulley and its toggle at rope 0 .. 1, widened to a finger, in Plane3.
ROPE_RECT = (172.0, 470.0, 252.0, 980.0)
ROPE_PLANE = 3
BELL_BOX = (96.0, 452.0, 232.0, 604.0)   # the bell's art at any tilt the rope gives it (rope 0 .. 1)
EVENT_PEAKS = {"snowfall": 150, "flare": 16, "aurora": 200, "bell": 12}


def review_extras(render: Callable[..., object], out: Path, gates: list[str]) -> None:
    """review_diorama's scene extras: the events at their peak frames, the rope drag's pixel proof (rope
    0 / 0.5 / 1 change pixels only inside `ROPE_RECT`, plus the bell's own tilt in `BELL_BOX`), the moon
    at eight phases (the drawn moon at -1), festive, and one contact sheet of everything (`contact_sheet.png`)."""
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
    cells = [im(rest, "rest")]
    ev_cells = [im(rest, "rest")]
    for ev, f in EVENT_PEAKS.items():
        a = render(f"--data=eventId={ev}", "--data=event=1", f"--advance={f}")
        ev_cells.append(im(a, f"{ev} +{f}f"))
        cells.append(ev_cells[-1])
    grid(ev_cells, 5).save(out / "events_strip.png")
    for label, args in (("snow (rain 1) f40", ("--data=rain=1", "--advance=41")),
                        ("noon", ("--data=daylight=1", "--advance=1")),
                        ("dusk (0.4 / 1)", ("--data=daylight=0.4", "--data=dusk=1", "--advance=1")),
                        ("fog 1", ("--data=fog=1", "--advance=1")),
                        ("festive 1", ("--data=festive=1", "--advance=1")),
                        ("parallax -1 / -1", ("--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=1")),
                        ("parallax +1 / +1", ("--data=parallaxX=1", "--data=parallaxY=1", "--advance=1"))):
        cells.append(im(render(*args), label))

    # ---- the rope drag: history-free pixels only in the handle's rect (and the bell's tilt)
    x0, y0, x1, y1 = (int(v) for v in ROPE_RECT)
    bx0, by0, bx1, by1 = (int(v) for v in BELL_BOX)
    allowed = np.zeros(rest.shape[:2], bool)  # type: ignore[union-attr]
    allowed[y0:y1, x0:x1] = True
    allowed[by0:by1, bx0:bx1] = True
    rope_box = (90, 440, 290, 1000)
    drag_cells = []
    worst, bbox = 0.0, None
    for v in (0.0, 0.5, 1.0):
        a = render(f"--data=rope={v}", "--advance=1")
        drag_cells.append(im(a, f"rope {v}", (200, 560), rope_box))
        changed = np.abs(a.astype(int) - rest.astype(int))[..., :3].max(-1) > 0  # type: ignore[union-attr]
        worst = max(worst, float((changed & ~allowed).mean()))
        if changed.any():
            ys, xs = np.nonzero(changed)
            b = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
            bbox = b if bbox is None else (min(bbox[0], b[0]), min(bbox[1], b[1]), max(bbox[2], b[2]),
                                           max(bbox[3], b[3]))
    back = render("--data=rope=1", "--advance=1", "--data=rope=0", "--advance=2")
    # (inside the rope and the bell: the ambient loops elsewhere run on the CLI's extra data step)
    region = (slice(min(y0, by0), max(y1, by1)), slice(min(x0, bx0), max(x1, bx1)))
    back_diff = int(np.abs(back.astype(int) - render("--advance=2").astype(int))[region][..., :3].max())  # type: ignore
    grid(drag_cells, 3).save(out / "rope_drag.png")
    gates.append(f"rope drag: pixels changed at rope 0.5 / 1 outside {ROPE_RECT} (+ the bell's tilt {BELL_BOX}): "
                 f"{worst:.4%} (changed bbox {bbox}) ({'ok' if worst == 0 and bbox is not None else 'FAIL'})")
    gates.append(f"rope drag history-free: rope 1 -> 0 vs never pulled (rope + bell box), max diff {back_diff}/255 "
                 f"({'ok' if back_diff <= 2 else 'FAIL'})")

    # ---- the moon at eight phases
    moon_box = (int(MOON[0] - 50), int(MOON[1] - 46), int(MOON[0] + 50), int(MOON[1] + 46))
    moon_cells = [im(render("--advance=1"), "-1 (drawn)", (150, 138), moon_box)]
    for k in range(8):
        ph = k / 8
        moon_cells.append(im(render(f"--data=moonPhase={ph}", "--advance=1"), f"{ph:.3f}", (150, 138), moon_box))
    grid(moon_cells, 9).save(out / "moon_phases.png")

    # ---- NPC states
    npc_box = (640, 1080, 1060, 1460)
    npc_cells = []
    for label, args in (("dog rest", ("--advance=151",)), ("dog idle", ("--data=npc=idle", "--advance=31")),
                        ("dog move", ("--data=npc=move", "--advance=16")),
                        ("dog notice -1", ("--data=npc=notice", "--data=npcLook=-1", "--advance=31")),
                        ("dog react", ("--data=npc=react", "--advance=25")),
                        ("dog npcX 1 idle", ("--data=npc=idle", "--data=npcX=1", "--advance=31"))):
        npc_cells.append(im(render(*args), label, (270, 244), npc_box))
    sheet_cells = [*cells]
    w = 270 * 5
    top = grid(sheet_cells, 5)
    mid = grid(npc_cells, 5)
    moons = grid(moon_cells, 9).resize((w, int(138 * w / (150 * 9))))
    drags = grid(drag_cells, 3)
    drags = drags.resize((int(drags.width * 400 / drags.height), 400))
    sheet = Image.new("RGB", (w, top.height + mid.height + moons.height + drags.height), (20, 20, 20))
    yy = 0
    for part in (top, mid, moons, drags):
        sheet.paste(part, (0, yy))
        yy += part.height
    sheet.save(out / "contact_sheet.png")


REVIEW: dict[str, object] = {
    "diorama": {
        "patches": [("Plane5 log basket", (60, 1690, 200, 1760), 40), ("Plane4 rug", (600, 1450, 760, 1510), 28),
                    ("Plane3 stove door", (836, 950, 946, 1080), 20), ("Plane2 casing edge", (280, 300, 320, 400), 12),
                    ("Plane1 mullion", (520, 260, 560, 400), 6), ("Plane0 moon", (628, 282, 676, 330), 0)],
        # snow sheets 120 / 240 frames and their sway 240: all back at frame 0 after 240
        "rain_loops": [("Snow sheets + sway (rain draws snow)", SNOW_LOOP)],
        "seam_box": tuple(int(v) for v in GLASS),
    },
    "extras": review_extras,
    "time": {"sky_box": tuple(int(v) for v in GLASS), "dusk_box": (350, 380, 730, 540), "noon_gain": 12.0},
    "npc": {"crop": (360, 300, -100), "seam": {"idle": DOG_IDLE, "move": FLICKER_FRAMES, "notice": FLICKER_FRAMES,
                                               "react": FLICKER_FRAMES},
            "prop": "dog", "waypoints": DOG_WAYPOINTS, "fog_box": tuple(int(v) for v in OPEN)},
}
