"""Generates rive/scenes/<sceneId>/<sceneId>.rml (artboard `Scene`, see rive/CONTRACT.md).

Layout: 1080x1920 portrait. Phones crop the sides (cover), desktop landscape
crops top/bottom down to roughly y 650..1270, so anything that matters lives in
the centre band and props sit left/right of where the avatar stands.
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from rml import Doc, El, ellipse, fill, lin, rad, smooth_path, solid, stroke, track, write  # noqa: E402

W, H = 1080, 1920
SCENE_EVENTS = {
    "livingRoom": ["lightsOff", "lightsOn", "tvOn", "catWalksBy"],
    "campfire": ["flare", "rain", "shootingStar", "owlHoot"],
    "beach": ["bigWave", "seagulls", "sunset", "rain"],
    "deepSpace": ["meteor", "warp", "alienShip", "nebulaPulse"],
}


class Scene:
    def __init__(self, scene_id: str) -> None:
        self.id = scene_id
        self.d = Doc(client=0, start=10)
        d = self.d
        self.anims: list[El] = []
        self.layers: list[El] = []
        self.listeners: list[El] = []
        self.events: list[El] = []
        self.ease = d("CubicEaseInterpolator", x1=0.42, y1=0.0, x2=0.58, y2=1.0)
        self.ease_out = d("CubicEaseInterpolator", x1=0.15, y1=0.0, x2=0.25, y2=1.0)
        vals = {v: d("DataEnumValue", key=v, value=v) for v in SCENE_EVENTS[scene_id]}
        self.enum_vals = vals
        self.enum = d("DataEnumCustom", *vals.values(), name="EventId")
        self.p_event_id = d("ViewModelPropertyEnumCustom", enumId=self.enum.ref(), name="eventId")
        self.p_event = d("ViewModelPropertyTrigger", name="event")
        inst = d("ViewModelInstance",
                 d("ViewModelInstanceEnum", propertyValue=next(iter(vals.values())).ref(),
                   viewModelPropertyId=self.p_event_id.ref()),
                 d("ViewModelInstanceTrigger", viewModelPropertyId=self.p_event.ref()),
                 exports=True, name="Default")
        self.inst = inst
        self.vm = d("ViewModel", self.p_event_id, self.p_event, inst, name="SceneVM", defaultInstanceId=inst.ref())

    # ---------------------------------------------------------------- drawing
    def S(self, parent: tuple[float, float], name: str, pts: list, *paints: El | None,
          closed: bool = True, tension: float = 1.0, origin: tuple[float, float] | None = None,
          **kw: object) -> El:
        d = self.d
        if origin is None:
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            origin = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
        loc = [((p[0] - origin[0], p[1] - origin[1]) + tuple(p[2:])) for p in pts]
        return d("Shape", smooth_path(d, loc, closed=closed, tension=tension),
                 *[p for p in paints if p is not None],
                 x=float(origin[0] - parent[0]), y=float(origin[1] - parent[1]), name=name, **kw)

    def E(self, parent: tuple[float, float], name: str, cx: float, cy: float, w: float, h: float,
          *paints: El | None, **kw: object) -> El:
        return self.d("Shape", ellipse(self.d, w, h), *[p for p in paints if p is not None],
                      x=float(cx - parent[0]), y=float(cy - parent[1]), name=name, **kw)

    def F(self, c: str) -> El:
        return fill(self.d, c)

    def L(self, c: str, w: float) -> El:
        return stroke(self.d, c, w)

    def vgrad(self, y0: float, y1: float, stops: list[tuple[str, float]]) -> El:
        return self.d("Fill", lin(self.d, 0, y0, 0, y1, stops), name="Fill")

    def rgrad(self, r: float, stops: list[tuple[str, float]], cx: float = 0, cy: float = 0) -> El:
        return self.d("Fill", rad(self.d, cx, cy, r, stops), name="Fill")

    def node(self, name: str, x: float, y: float, *kids: El | None, **kw: object) -> El:
        return self.d("Node", *kids, x=float(x), y=float(y), name=name, **kw)

    # ---------------------------------------------------------------- animation
    def A(self, name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
        a = self.d("LinearAnimation", *tracks, duration=frames, fps=60,
                   loopValue="loop" if loop else None, name=name)
        self.anims.append(a)
        return a

    def T(self, target: El, ease: El | None = None, **props: list) -> El:
        return track(self.d, target, props, ease=self.ease if ease is None else ease)

    def ambient(self, name: str, anim: El) -> None:
        d = self.d
        s = d("AnimationState", animationId=anim.ref(), x=160.0, y=100.0)
        self.layers.append(self._layer(name, s, [s]))

    def _layer(self, name: str, entry: El, states: list[El], any_t: list[El] | None = None) -> El:
        d = self.d
        return d("StateMachineLayer", d("AnyState", *(any_t or []), x=100.0, y=-100.0),
                 d("ExitState", x=500.0, y=-100.0),
                 d("EntryState", d("StateTransition", stateToId=entry.ref()), x=-100.0, y=-100.0),
                 *states, name=name)

    def scene_events(self, anims: dict[str, El], rest: El) -> None:
        """One layer: idle rest pose; `event` trigger + eventId plays that one-shot then returns."""
        d = self.d
        idle = d("AnimationState", animationId=rest.ref(), x=0.0, y=100.0)
        states = [idle]
        for i, (ev, a) in enumerate(anims.items()):
            st = d("AnimationState",
                   d("StateTransition", stateToId=idle.ref(), enableExitTime=True, exitTimeIsPercetange=True,
                     exitTime=100, duration=200),
                   animationId=a.ref(), x=float(200 + 160 * i), y=float(260))
            vm_path = f"{self.vm.ref()}-"
            idle.add(d("StateTransition",
                       d("TransitionViewModelCondition",
                         d("TransitionPropertyViewModelComparator",
                           d("BindablePropertyTrigger", d("DataBindContext", sourcePathIds=vm_path + self.p_event.ref(),
                                                          propertyKey=686))),
                         d("TransitionValueTriggerComparator")),
                       d("TransitionViewModelCondition",
                         d("TransitionPropertyViewModelComparator",
                           d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=vm_path + self.p_event_id.ref(),
                                                       propertyKey=637))),
                         d("TransitionValueEnumComparator", value=self.enum_vals[ev].ref())),
                       stateToId=st.ref(), duration=100))
            states.append(st)
        self.layers.append(self._layer("SceneEvents", idle, states))

    def prop(self, prop_id: str, hit: El) -> None:
        d = self.d
        ev = d("Event", d("CustomPropertyString", propertyValue=prop_id, name="propId"), name="prop_tapped")
        self.events.append(ev)
        self.listeners.append(d("StateMachineListenerSingle", d("ListenerFireEvent", eventId=ev.ref()),
                                targetId=hit.ref(), listenerTypeValue="click", name="Tap_" + prop_id))

    def hit(self, name: str, cx: float, cy: float, w: float, h: float) -> El:
        d = self.d
        return d("Shape", d("Rectangle", width=float(w), height=float(h), name="Path"), self.F("00000000"),
                 x=float(cx), y=float(cy), name="Hit_" + name)

    def write(self, content: list[El], hits: list[El]) -> str:
        d = self.d
        sm = d("StateMachine", *self.listeners, *self.layers, name="Main")
        style = d("LayoutComponentStyle", name="Artboard Style")
        ab = d("Artboard", style, sm, self.ease, self.ease_out, *self.events, *hits, *content, *self.anims,
               width=float(W), height=float(H), name="Scene", defaultStateMachineId=sm.ref(),
               viewModelId=self.vm.ref(), viewModelInstanceId=self.inst.ref(), styleId=style.ref(), clip=True)
        out = os.path.join(os.path.dirname(__file__), "..", "scenes", self.id, self.id + ".rml")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        write(out, [ab, self.enum, self.vm])
        with open(os.path.join(os.path.dirname(out), "rive.yaml"), "w") as f:
            f.write(f"name: {self.id}\nmain: Scene\noutput: {{dir: build}}\n"
                    "logs: {file: build/rive.log, problems: build/problems.log}\n")
        return os.path.normpath(out)


def uniq(keys: list) -> list:
    """Sort keyframes by frame, first key wins on a duplicate frame."""
    seen: dict[int, tuple] = {}
    for k in keys:
        seen.setdefault(k[0], k)
    return [seen[f] for f in sorted(seen)]


# ====================================================================== campfire
def campfire() -> str:
    sc = Scene("campfire")
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    O = (0.0, 0.0)
    rnd = random.Random(7)
    content: list[El] = []   # front-most first

    # ---- sky + celestial
    sky = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
            sc.vgrad(0, 1300, [("FF0B1026", 0.0), ("FF1A1B45", 0.45), ("FF3D2A5C", 0.8), ("FF6B3A5A", 1.0)]),
            name="Sky")
    stars: list[El] = []
    twinkle_tracks: list[El] = []
    for i in range(70):
        x, y = rnd.uniform(0, W), rnd.uniform(40, 1050)
        r = rnd.choice([2.2, 2.6, 3.0, 3.6, 4.6])
        st = E(O, f"Star{i}", x, y, r, r, F("FFFFF6E0" if i % 3 else "FFD8E4FF"), opacity=rnd.uniform(0.45, 1.0))
        stars.append(st)
        if i % 5 == 0:   # only a few twinkle (cheap)
            ph = rnd.randint(0, 200)
            base = float(st.attrs["opacity"])
            keys = uniq([(0, base), (240, base), ((ph + 40) % 240, 0.15), ((ph + 80) % 240, base)])
            twinkle_tracks.append(sc.T(st, opacity=keys))
    # sparkle crosses on the brightest stars
    for i, (x, y) in enumerate([(180, 300), (820, 220), (640, 520), (930, 760)]):
        cr = d("Node", S((x, y), "H", [(x - 14, y), (x + 14, y)], L("CCFFF6E0", 2), closed=False),
               S((x, y), "V", [(x, y - 14), (x, y + 14)], L("CCFFF6E0", 2), closed=False),
               x=float(x), y=float(y), name=f"Glint{i}")
        stars.append(cr)
        twinkle_tracks.append(sc.T(cr, scaleX=[(0, 1.0), (60 + i * 30, 0.4), (120 + i * 30, 1.0), (240, 1.0)],
                                   scaleY=[(0, 1.0), (60 + i * 30, 0.4), (120 + i * 30, 1.0), (240, 1.0)]))
    sc.ambient("Stars", sc.A("amb_stars", 240, twinkle_tracks, loop=True))

    moon_c = (800, 690)
    moon_glow = E(O, "MoonGlow", *moon_c, 420, 420,
                  sc.rgrad(210, [("40FFE9C4", 0.0), ("18FFE9C4", 0.5), ("00FFE9C4", 1.0)]))
    moon_cut = E(O, "MoonShadow", moon_c[0] + 26, moon_c[1] - 14, 112, 112, F("FF1F1D48"))
    moon = E(O, "Moon", *moon_c, 120, 120, sc.rgrad(80, [("FFFFF6DE", 0.0), ("FFF2DDB0", 1.0)], cx=-20, cy=-20))
    craters = [E(O, f"Crater{i}", moon_c[0] + dx, moon_c[1] + dy, r, r, F("33C8A878"))
               for i, (dx, dy, r) in enumerate([(-30, 10, 18), (-12, 34, 12), (-36, -22, 10)])]

    # ---- landscape silhouettes (back to front)
    def ridge(name: str, y: float, amp: float, seed: int, col: str, step: int = 90) -> El:
        r = random.Random(seed)
        pts = [(-60, 1960, "c"), (-60, y)]
        x = -60
        while x < W + 60:
            x += step
            pts.append((x, y + r.uniform(-amp, amp)))
        pts.append((W + 60, 1960, "c"))
        return S(O, name, pts, F(col))

    far = ridge("FarHills", 910, 50, 3, "FF2A2550", 120)

    def pine(name: str, x: float, base: float, h: float, col: str) -> El:
        w = h * 0.42
        pts = [(x, base - h, "c")]
        tiers = 5
        for k in range(1, tiers + 1):
            t = k / tiers
            yy = base - h + h * t * 0.92
            ww = w * t
            pts.append((x + ww * 0.55, yy - h * 0.06, "c"))
            pts.append((x + ww, yy, "c"))
        pts.append((x + w * 0.12, base, "c"))
        pts.append((x - w * 0.12, base, "c"))
        for k in range(tiers, 0, -1):
            t = k / tiers
            yy = base - h + h * t * 0.92
            ww = w * t
            pts.append((x - ww, yy, "c"))
            pts.append((x - ww * 0.55, yy - h * 0.06, "c"))
        return S(O, name, pts, F(col))

    far_trees = [pine(f"FarPine{i}", x, 960 + rnd.uniform(-10, 20), rnd.uniform(160, 240), "FF1E1A3C")
                 for i, x in enumerate(range(-20, W + 60, 70))]
    mid = ridge("MidHills", 1010, 25, 11, "FF1A1630", 80)
    near_trees = [pine(f"Pine{i}", x, 1080 + rnd.uniform(0, 30), h, "FF120F22")
                  for i, (x, h) in enumerate([(-40, 520), (70, 430), (150, 360), (950, 480), (1050, 560),
                                              (870, 340)])]

    # ---- ground + fire light
    fire_c = (290.0, 1140.0)
    ground = S(O, "Ground", [(-60, 1060), (300, 1040), (700, 1050), (1140, 1070), (1140, 1960, "c"),
                             (-60, 1960, "c")],
               sc.vgrad(-400, 400, [("FF2A2338", 0.0), ("FF1C1726", 1.0)]))
    light_pool = E(O, "LightPool", fire_c[0], fire_c[1] + 50, 1000, 1000,
                   sc.rgrad(500, [("88FF9A3C", 0.0), ("33FF7A2A", 0.45), ("00FF7A2A", 1.0)]), scaleY=0.42)
    # rim light on the nearest trees from the fire
    tree_glow = E(O, "TreeGlow", fire_c[0] - 120, fire_c[1] - 260, 700, 700,
                  sc.rgrad(350, [("30FF8A3A", 0.0), ("00FF8A3A", 1.0)]))
    grass = []
    for i in range(26):
        gx = rnd.uniform(-20, W + 20)
        gy = rnd.uniform(1080, 1700)
        hgt = rnd.uniform(18, 36)
        grass.append(S(O, f"Grass{i}", [(gx - 8, gy, "c"), (gx - 4, gy - hgt, "c"), (gx, gy - 4, "c"),
                                         (gx + 5, gy - hgt * 0.8, "c"), (gx + 8, gy, "c")], F("FF241C30")))

    # ---- tent (right of the avatar), lit on its fire-facing side
    tx, ty = 840.0, 1100.0
    tent_dark = S(O, "TentShade", [(tx, ty - 250, "c"), (tx + 200, ty, "c"), (tx + 20, ty + 12, "c")],
                  sc.vgrad(-130, 130, [("FF3A4A5A", 0.0), ("FF243040", 1.0)]), L("FF121820", 3))
    tent_lit = S(O, "TentLit", [(tx, ty - 250, "c"), (tx + 20, ty + 12, "c"), (tx - 190, ty + 4, "c")],
                 sc.vgrad(-130, 130, [("FF6E7E6A", 0.0), ("FF8A6A4A", 1.0)]), L("FF121820", 3))
    door = S(O, "TentDoor", [(tx - 4, ty - 170, "c"), (tx + 30, ty + 10, "c"), (tx - 60, ty + 8, "c")],
             sc.vgrad(-90, 90, [("FF1A1418", 0.0), ("FF2A1E1A", 1.0)]))
    flap = S(O, "TentFlap", [(tx - 4, ty - 170, "c"), (tx - 30, ty - 40), (tx - 90, ty + 6, "c"), (tx - 60, ty + 8, "c")],
             sc.vgrad(-90, 90, [("FF7E8A70", 0.0), ("FF9A7650", 1.0)]), L("FF121820", 2.5))
    rope = S(O, "TentRope", [(tx - 120, ty - 90), (tx - 230, ty + 20)], L("AA8A7A60", 2), closed=False)
    pole = S(O, "TentPole", [(tx, ty - 250), (tx, ty - 290)], L("FF5A4030", 5), closed=False)
    tent = d("Node", pole, flap, door, tent_lit, tent_dark, rope, x=0.0, y=0.0, name="Tent")
    # foreground silhouettes frame the bottom corners
    fg = [S(O, "BushL", [(-80, 1960, "c"), (-80, 1700), (20, 1640), (120, 1690), (200, 1660), (280, 1760),
                         (300, 1960, "c")], F("FF0E0B16")),
          S(O, "BushR", [(800, 1960, "c"), (820, 1780), (900, 1700), (990, 1720), (1060, 1640), (1160, 1700),
                         (1160, 1960, "c")], F("FF0E0B16")),
          S(O, "Path", [(380, 1960, "c"), (470, 1500), (520, 1180), (560, 1180), (640, 1500), (760, 1960, "c")],
            sc.vgrad(-400, 400, [("FF2E2638", 0.0), ("FF241E2E", 1.0)]))]

    # ---- logs + stones
    fx, fy = fire_c

    def log(name: str, x0: float, y0: float, x1: float, y1: float, w: float) -> El:
        ang = math.atan2(y1 - y0, x1 - x0)
        ln = math.hypot(x1 - x0, y1 - y0)
        body_ = d("Shape", d("Rectangle", width=float(ln), height=float(w), cornerRadiusTL=float(w / 2),
                             cornerRadiusTR=float(w / 2), cornerRadiusBL=float(w / 2), cornerRadiusBR=float(w / 2),
                             name="Path"),
                  sc.vgrad(-w / 2, w / 2, [("FF7A4A2E", 0.0), ("FF4A2A1C", 0.6), ("FF2A1812", 1.0)]),
                  L("FF1A0F0A", 3), name="Bark")
        end = d("Shape", ellipse(d, w * 0.55, w), F("FFC08A5A"), L("FF5A3420", 2.5), x=float(ln / 2 - 2),
                name="End")
        ring = d("Shape", ellipse(d, w * 0.25, w * 0.45), L("FF8A5A38", 2), x=float(ln / 2 - 2), name="Ring")
        return d("Node", ring, end, body_, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), rotation=float(ang),
                 name=name)

    logs = [log("LogA", fx - 110, fy + 40, fx + 90, fy - 10, 40), log("LogB", fx + 110, fy + 40, fx - 90, fy - 10, 40),
            log("LogC", fx - 70, fy + 62, fx + 80, fy + 58, 34)]
    stones = []
    for i in range(9):
        a = math.pi * (0.05 + 0.9 * i / 8)
        sx_, sy_ = fx + math.cos(a) * 150, fy + 70 + math.sin(a) * 28 - 10
        stones.append(E(O, f"Stone{i}", sx_, sy_, rnd.uniform(46, 60), rnd.uniform(28, 36),
                        sc.vgrad(-18, 18, [("FF8A8098", 0.0), ("FF4A4258", 1.0)]), L("FF1E1A28", 2.5)))
    stones_back = [s for i, s in enumerate(stones) if i in (0, 8)]
    stones_front = [s for i, s in enumerate(stones) if i not in (0, 8)]

    # ---- flames: each tongue bends/stretches out of phase; Fire node scales for flare
    fire = d("Node", x=fx, y=fy + 10, name="Fire")
    FP = (fx, fy + 10)

    def tongue(name: str, dx: float, h: float, w: float, cols: list[tuple[str, float]], lean: float) -> El:
        pts = [(fx + dx - w / 2, fy + 10), (fx + dx - w * 0.55, fy - h * 0.25), (fx + dx - w * 0.2 + lean * 0.5,
                                                                                 fy - h * 0.62),
               (fx + dx + lean, fy - h, "c"), (fx + dx + w * 0.28 + lean * 0.4, fy - h * 0.55),
               (fx + dx + w * 0.55, fy - h * 0.2), (fx + dx + w / 2, fy + 10)]
        shp = S((fx + dx, fy + 10), name, pts, d("Fill", lin(d, 0, 0, 0, -h, cols), name="Fill"),
                origin=(fx + dx, fy + 10))
        return d("Node", shp, x=float(dx), y=0.0, name=name + "Pivot")

    OUTER = [("FFE0401E", 0.0), ("FFF2652A", 0.5), ("CCF2652A", 1.0)]
    MIDC = [("FFF79A2A", 0.0), ("FFFFB640", 1.0)]
    INNER = [("FFFFF0B0", 0.0), ("FFFFD666", 1.0)]
    tongues = [
        tongue("Core", 0, 110, 56, INNER, 4),
        tongue("MidL", -22, 160, 70, MIDC, -10), tongue("MidR", 24, 150, 64, MIDC, 12),
        tongue("Main", 0, 250, 120, OUTER, 8), tongue("OuterL", -48, 170, 80, OUTER, -22),
        tongue("OuterR", 52, 190, 78, OUTER, 26),
    ]
    glow = E(FP, "Glow", fx, fy - 60, 520, 520, sc.rgrad(260, [("70FFB040", 0.0), ("30FF7A2A", 0.4), ("00FF6A20", 1.0)]))
    sparks = []
    spark_tracks = []
    for i in range(8):
        sx0 = rnd.uniform(-40, 40)
        sp = E(FP, f"Spark{i}", fx + sx0, fy - 60, 6, 6, F("FFFFD27A"), opacity=0.0)
        sparks.append(sp)
        start = i * 15
        dur = 90
        drift = rnd.uniform(-60, 60)
        rise = []
        for f in range(0, 121, 10):
            t = ((f - start) % 120) / dur
            rise.append((f, t))
        spark_tracks.append(sc.T(sp, ease=None,
                                 y=[(f, -70 - 300 * min(t, 1.0), "linear") for f, t in rise],
                                 x=[(f, sx0 + drift * math.sin(min(t, 1.0) * 2.4), "linear") for f, t in rise],
                                 opacity=[(f, 0.0 if t > 1 else (1.0 - t) * 1.0, "linear") for f, t in rise]))
    # flame loop: tongues sway, stretch, and the glow breathes
    fl_tracks = []
    for i, tg in enumerate(tongues):
        ph = i * 7
        amp = 0.06 + 0.02 * (i % 3)
        keys_r = [(0, 0.0), ((10 + ph) % 40, amp), ((25 + ph) % 40, -amp), (40, 0.0)]
        keys_s = [(0, 1.0), ((8 + ph) % 40, 1.12), ((20 + ph) % 40, 0.9), ((32 + ph) % 40, 1.06), (40, 1.0)]
        fl_tracks.append(sc.T(tg, rotation=uniq(keys_r), scaleY=uniq(keys_s),
                              scaleX=[(0, 1.0), (20, 0.94), (40, 1.0)]))
    fl_tracks.append(sc.T(glow, opacity=[(0, 1.0), (9, 0.82), (17, 1.0), (27, 0.88), (40, 1.0)],
                          scaleX=[(0, 1.0), (20, 1.05), (40, 1.0)], scaleY=[(0, 1.0), (20, 1.05), (40, 1.0)]))
    fl_tracks.append(sc.T(light_pool, opacity=[(0, 1.0), (13, 0.86), (26, 1.0), (33, 0.9), (40, 1.0)]))
    sc.ambient("Flames", sc.A("amb_flames", 40, fl_tracks, loop=True))
    sc.ambient("Sparks", sc.A("amb_sparks", 120, spark_tracks, loop=True))

    # smoke wisps drifting up
    smoke = []
    sm_tracks = []
    for i in range(3):
        sm = E(FP, f"Smoke{i}", fx, fy - 260, 70, 70, sc.rgrad(35, [("33B8A8C8", 0.0), ("00B8A8C8", 1.0)]),
               opacity=0.0)
        smoke.append(sm)
        off = i * 80
        sm_tracks.append(sc.T(sm, ease=None,
                              y=[(f, -270 - 260 * (((f + off) % 240) / 240), "linear") for f in range(0, 241, 40)],
                              x=[(f, 30 * math.sin(((f + off) % 240) / 240 * 3.0), "linear") for f in range(0, 241, 40)],
                              opacity=[(f, math.sin(math.pi * (((f + off) % 240) / 240)), "linear") for f in range(0, 241, 40)],
                              scaleX=[(f, 1 + 1.4 * (((f + off) % 240) / 240), "linear") for f in range(0, 241, 40)],
                              scaleY=[(f, 1 + 1.4 * (((f + off) % 240) / 240), "linear") for f in range(0, 241, 40)]))
    sc.ambient("Smoke", sc.A("amb_smoke", 240, sm_tracks, loop=True))

    fire.add(*sparks, *[tg for tg in tongues], glow)
    fire_flare = d("Node", fire, x=0.0, y=0.0, name="FireFlare")

    # ---- events
    rest = sc.A("ev_rest", 1, [sc.T(fire, ease=None, scaleX=[(0, 1.0)], scaleY=[(0, 1.0)]),
                               sc.T(sky, ease=None, opacity=[(0, 1.0)])])
    flare = sc.A("ev_flare", 110, [
        sc.T(fire, scaleX=[(0, 1.0), (10, 1.5), (60, 1.35), (110, 1.0)],
             scaleY=[(0, 1.0), (8, 1.9), (60, 1.6), (110, 1.0)]),
        sc.T(light_pool, scaleX=[(0, 1.0), (10, 1.35), (110, 1.0)], scaleY=[(0, 1.0), (10, 1.35), (110, 1.0)]),
        sc.T(tree_glow, opacity=[(0, 1.0), (10, 2.0), (110, 1.0)]),
    ])
    sc.scene_events({"flare": flare}, rest)

    # ---- props
    hit_fire = sc.hit("fire", fx, fy - 80, 300, 320)
    sc.prop("fire", hit_fire)

    # moon_cut must paint over the moon to carve the crescent; craters on the lit part
    content = [fg[0], fg[1], *stones_front, *logs, fire_flare, *smoke, *stones_back, tent, *grass, tree_glow,
               light_pool, fg[2], ground,
               *near_trees, mid, *far_trees, far, *craters, moon, moon_glow, *stars, sky]
    return sc.write(content, [hit_fire])


if __name__ == "__main__":
    which = sys.argv[1:] or ["campfire"]
    for name in which:
        print("wrote", globals()[name]())
