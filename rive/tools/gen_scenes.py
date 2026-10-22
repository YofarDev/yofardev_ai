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
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from rml import Doc, El, ellipse, fill, lin, rad, smooth_path, solid, stroke, track, write  # noqa: E402,F401

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

    def cond(self, ev: str) -> list[El]:
        """`event` fired AND eventId == ev."""
        d = self.d
        vm_path = f"{self.vm.ref()}-"
        return [d("TransitionViewModelCondition",
                  d("TransitionPropertyViewModelComparator",
                    d("BindablePropertyTrigger", d("DataBindContext", sourcePathIds=vm_path + self.p_event.ref(),
                                                   propertyKey=686))),
                  d("TransitionValueTriggerComparator")),
                d("TransitionViewModelCondition",
                  d("TransitionPropertyViewModelComparator",
                    d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=vm_path + self.p_event_id.ref(),
                                                propertyKey=637))),
                  d("TransitionValueEnumComparator", value=self.enum_vals[ev].ref()))]

    def rest_of(self, anim: El) -> El:
        """1-frame pose holding every property `anim` keys at its frame-0 value."""
        d = self.d
        objs = []
        for ko in anim.children:
            kps = []
            for kp in ko.children:
                k0 = kp.children[0]
                kps.append(d("KeyedProperty", d(k0.tag, frame=0, value=k0.attrs["value"], interpolationType="hold"),
                             property=kp.attrs["property"]))
            objs.append(d("KeyedObject", *kps, objectId=ko.attrs["objectId"]))
        return self.A(anim.attrs["name"] + "_rest", 1, objs)

    def one_shot(self, ev: str, anim: El) -> None:
        """Own layer per event so events can overlap: rest -> anim -> rest."""
        d = self.d
        idle = d("AnimationState", animationId=self.rest_of(anim).ref(), x=0.0, y=100.0)
        play = d("AnimationState",
                 d("StateTransition", stateToId=idle.ref(), enableExitTime=True, exitTimeIsPercetange=True,
                   exitTime=100, duration=200),
                 animationId=anim.ref(), x=200.0, y=260.0)
        idle.add(d("StateTransition", *self.cond(ev), stateToId=play.ref(), duration=100))
        self.layers.append(self._layer("Event_" + ev, idle, [idle, play]))

    def toggle(self, name: str, default: El, events: dict[str, El], ms: int = 700) -> None:
        """Sticky states: each event switches the layer to its pose and it stays there."""
        d = self.d
        base = d("AnimationState", animationId=default.ref(), x=0.0, y=100.0)
        states = [base]
        any_t = []
        for i, (ev, a) in enumerate(events.items()):
            st = base if a is default else d("AnimationState", animationId=a.ref(), x=float(200 + 160 * i), y=260.0)
            if st is not base:
                states.append(st)
            any_t.append(d("StateTransition", *self.cond(ev), stateToId=st.ref(), duration=ms))
        self.layers.append(self._layer(name, base, states, any_t))

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


def rain_fx(sc: Scene, name: str, col: str, frames: int = 480, extra: list[El] | None = None,
            darken: str = "FF0A1022") -> tuple[El, El]:
    """Returns (content node, one-shot anim): fade in, falling sheet loop, fade out."""
    d = sc.d
    r = random.Random(zlib.crc32(name.encode()))
    streaks = []
    tile = 480                      # pattern repeats every `tile` px, so a `tile` shift loops seamlessly
    for i in range(16):
        x, y = r.uniform(-60, W + 60), r.uniform(0, tile)
        ln = r.uniform(40, 80)
        for k in range(-1, H // tile + 1):
            streaks.append(sc.S((0, 0), f"Drop{i}_{k + 1}", [(x, y + k * tile), (x - ln * 0.25, y + k * tile + ln)],
                                sc.L(col, 3), closed=False))
    sheet = d("Node", *streaks, x=0.0, y=0.0, name="RainSheet")
    dark = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
             sc.F(darken), opacity=0.0, name="RainDark")
    group_ = d("Node", sheet, x=0.0, y=0.0, opacity=0.0, name=name)
    saw = []
    for c in range(0, frames, 24):
        saw += [(c, 0.0, "linear"), (min(c + 23, frames), tile * 23 / 24, "linear")]
    anim = sc.A("ev_" + name, frames, [
        sc.T(group_, ease=None, opacity=[(0, 0.0), (40, 1.0, "linear"), (frames - 60, 1.0, "linear"), (frames, 0.0)]),
        sc.T(dark, ease=None, opacity=[(0, 0.0), (40, 0.4, "linear"), (frames - 60, 0.4, "linear"), (frames, 0.0)]),
        sc.T(sheet, ease=None, y=uniq(saw)),
        *(extra or []),
    ])
    return d("Node", group_, dark, x=0.0, y=0.0, name=name + "Fx"), anim


def streak_fx(sc: Scene, name: str, p0: tuple[float, float], p1: tuple[float, float], frames: int, length: float,
              head_col: str, tail_col: str, head_r: float = 10) -> tuple[El, El]:
    d = sc.d
    ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    tail = d("Shape", d("Rectangle", width=float(length), height=float(head_r * 0.9), originX=1.0, originY=0.5,
                        name="Path"),
             d("Fill", lin(d, -length, 0, 0, 0, [("00" + tail_col[2:], 0.0), (tail_col, 1.0)]), name="Fill"),
             name="Tail")
    glow = d("Shape", ellipse(d, head_r * 5, head_r * 5),
             sc.rgrad(head_r * 2.5, [(head_col, 0.0), ("00" + head_col[2:], 1.0)]), name="Glow")
    core = d("Shape", ellipse(d, head_r * 1.6, head_r * 1.6), sc.F("FFFFFFFF"), name="Core")
    n = d("Node", core, glow, tail, x=float(p0[0]), y=float(p0[1]), rotation=float(ang), opacity=0.0, name=name)
    anim = sc.A("ev_" + name, frames, [
        sc.T(n, ease=None, x=[(0, p0[0]), (frames, p1[0])], y=[(0, p0[1]), (frames, p1[1])],
             opacity=[(0, 0.0), (6, 1.0), (frames - 10, 1.0), (frames, 0.0)]),
        sc.T(tail, scaleX=[(0, 0.2), (frames // 2, 1.0), (frames, 0.4)]),
    ])
    return n, anim


def bird(sc: Scene, name: str, x: float, y: float, sz: float, col: str) -> tuple[El, list[El]]:
    """Flapping gull 'M' silhouette; returns node + its flap tracks (loop 24f)."""
    wl = sc.S((x, y), "WingL", [(x, y), (x - sz * 0.5, y - sz * 0.35), (x - sz, y - sz * 0.05)], sc.L(col, 4),
              closed=False, origin=(x, y))
    wr = sc.S((x, y), "WingR", [(x, y), (x + sz * 0.5, y - sz * 0.35), (x + sz, y - sz * 0.05)], sc.L(col, 4),
              closed=False, origin=(x, y))
    n = sc.d("Node", wl, wr, x=float(x), y=float(y), name=name)
    flap = [sc.T(wl, rotation=[(0, 0.0), (12, -0.5), (24, 0.0)]), sc.T(wr, rotation=[(0, 0.0), (12, 0.5), (24, 0.0)])]
    return n, flap


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
    flare = sc.A("ev_flare", 110, [
        sc.T(fire, scaleX=[(0, 1.0), (10, 1.5), (60, 1.35), (110, 1.0)],
             scaleY=[(0, 1.0), (8, 1.9), (60, 1.6), (110, 1.0)]),
        sc.T(light_pool, scaleX=[(0, 1.0), (10, 1.35), (110, 1.0)], scaleY=[(0, 1.0), (10, 1.35), (110, 1.0)]),
        sc.T(tree_glow, opacity=[(0, 1.0), (10, 2.0), (110, 1.0)]),
    ])
    sc.one_shot("flare", flare)

    rain_node, rain_anim = rain_fx(sc, "Rain", "88B8C8F0", extra=[
        sc.T(fire, scaleX=[(0, 1.0), (60, 0.75), (400, 0.75), (480, 1.0)], scaleY=[(0, 1.0), (60, 0.6), (400, 0.6),
                                                                                     (480, 1.0)]),
        sc.T(light_pool, opacity=[(0, 1.0), (60, 0.5), (400, 0.5), (480, 1.0)])])
    sc.one_shot("rain", rain_anim)
    star_node, star_anim = streak_fx(sc, "ShootingStar", (120, 180), (760, 520), 46, 260, "FFFFF6D0", "CCFFF6D0", 7)
    sc.one_shot("shootingStar", star_anim)

    # owl on a branch of the left pine
    ox_, oy_ = 196.0, 826.0
    branch = S(O, "Branch", [(40, 880), (150, 868), (250, 872), (250, 884), (150, 882), (40, 896)], F("FF140F1E"))
    owl = d("Node", x=ox_, y=oy_, name="Owl")
    OW = (ox_, oy_)
    eyes_ = []
    for k, ex in enumerate((-15, 15)):
        lid = E(OW, f"OwlLid{k}", ox_ + ex, oy_ - 18, 26, 26, F("FF6A4A32"), scaleY=0.0)
        eyes_ += [lid, E(OW, f"OwlPupil{k}", ox_ + ex, oy_ - 18, 10, 12, F("FF140C08")),
                  E(OW, f"OwlEye{k}", ox_ + ex, oy_ - 18, 24, 24, F("FFF2C230"), L("FF3A2414", 2))]
    owl.add(*eyes_,
            S(OW, "Beak", [(ox_ - 5, oy_ - 6), (ox_ + 5, oy_ - 6), (ox_, oy_ + 6, "c")], F("FFD8A040")),
            S(OW, "Face", [(ox_ - 34, oy_ - 18), (ox_, oy_ - 40), (ox_ + 34, oy_ - 18), (ox_, oy_ + 6)], F("FFB08860")),
            S(OW, "Chest", [(ox_ - 18, oy_ + 4), (ox_ + 18, oy_ + 4), (ox_ + 14, oy_ + 42), (ox_ - 14, oy_ + 42)],
              F("FFC8A478")),
            S(OW, "OwlBody", [(ox_ - 34, oy_ - 40, "c"), (ox_ - 18, oy_ - 30), (ox_ + 18, oy_ - 30), (ox_ + 34, oy_ - 40, "c"),
                              (ox_ + 40, oy_), (ox_ + 30, oy_ + 46), (ox_, oy_ + 54), (ox_ - 30, oy_ + 46), (ox_ - 40, oy_)],
              sc.vgrad(-50, 50, [("FF8A6444", 0.0), ("FF4A3220", 1.0)]), L("FF20140C", 2.5)))
    lids = [c for c in eyes_ if c.attrs["name"].startswith("OwlLid")]
    sc.ambient("OwlBlink", sc.A("amb_owl", 300, [sc.T(l_, ease=None, scaleY=[(0, 0.0), (200, 0.0), (205, 1.0),
                                                                              (212, 0.0), (300, 0.0)]) for l_ in lids],
                                loop=True))
    hoots = [E(O, f"Hoo{k}", ox_ + 50, oy_ - 40, 22 - k * 4, 22 - k * 4, L("CCFFF2D0", 3), opacity=0.0)
             for k in range(3)]
    hoot = sc.A("ev_owlHoot", 120, [
        sc.T(owl, scaleY=[(0, 1.0), (10, 0.9), (20, 1.06), (30, 1.0), (50, 0.9), (60, 1.06), (70, 1.0), (120, 1.0)],
             rotation=[(0, 0.0), (20, 0.12), (70, 0.12), (100, 0.0), (120, 0.0)]),
        *[sc.T(h, x=[(0, ox_ + 50.0), (60 + 15 * k, ox_ + 90.0 + 20 * k)], y=[(0, oy_ - 40.0), (60 + 15 * k, oy_ - 120.0 - 30 * k)],
               opacity=[(0, 0.0), (10 + 15 * k, 1.0), (60 + 15 * k, 0.0), (120, 0.0)]) for k, h in enumerate(hoots)],
    ])
    sc.one_shot("owlHoot", hoot)

    # ---- props
    hit_fire = sc.hit("fire", fx, fy - 80, 300, 320)
    sc.prop("fire", hit_fire)
    hit_tent = sc.hit("tent", 840, 990, 420, 300)
    sc.prop("tent", hit_tent)
    hit_owl = sc.hit("owl", ox_, oy_, 110, 130)
    sc.prop("owl", hit_owl)
    hit_sky = sc.hit("sky", W / 2, 330, W, 660)
    sc.prop("sky", hit_sky)

    # moon_cut must paint over the moon to carve the crescent; craters on the lit part
    content = [rain_node, fg[0], fg[1], *stones_front, *logs, fire_flare, *smoke, *stones_back, tent, *grass, tree_glow,
               light_pool, fg[2], ground, *hoots, owl, branch,
               *near_trees, mid, *far_trees, far, star_node, *craters, moon, moon_glow, *stars, sky]
    return sc.write(content, [hit_fire, hit_tent, hit_owl, hit_sky])


# ====================================================================== livingRoom
def livingRoom() -> str:  # noqa: N802 (scene ids are contract names)
    sc = Scene("livingRoom")
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    O = (0.0, 0.0)
    INKC = "FF2A2030"

    def rect(name: str, x0: float, y0: float, x1: float, y1: float, paint: El, r: float = 0, **kw: object) -> El:
        return d("Shape", d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), cornerRadiusTL=float(r),
                            cornerRadiusTR=float(r), cornerRadiusBL=float(r), cornerRadiusBR=float(r), name="Path"),
                 paint, x=float((x0 + x1) / 2), y=float((y0 + y1) / 2), name=name, **kw)

    floor_y = 1180
    wall = rect("Wall", -10, -10, W + 10, floor_y, sc.vgrad(-600, 600, [("FF4E4460", 0.0), ("FF7A6680", 1.0)]))
    stripes = [rect(f"Stripe{i}", x, -10, x + 34, floor_y, F("10FFFFFF")) for i, x in enumerate(range(0, W, 90))]
    wainscot = rect("Wainscot", -10, 1000, W + 10, floor_y, sc.vgrad(-90, 90, [("FF5A4A62", 0.0), ("FF483A50", 1.0)]))
    rail = rect("Rail", -10, 992, W + 10, 1006, F("FF8A7896"))
    floor = rect("Floor", -10, floor_y, W + 10, H + 10, sc.vgrad(-370, 370, [("FF9A6844", 0.0), ("FF5E3A24", 1.0)]))
    planks = [S(O, f"Plank{i}", [(x0, floor_y), (x0 + (x0 - 540) * 1.6, H)], L("40000000", 3), closed=False)
              for i, x0 in enumerate(range(-200, 1300, 130))]
    baseboard = rect("Baseboard", -10, floor_y - 18, W + 10, floor_y + 4, F("FFE8DCCC"))
    rug = E(O, "Rug", 540, 1520, 980, 300, sc.rgrad(490, [("FFB8484A", 0.0), ("FF8A2E36", 0.55), ("FF5A1E28", 1.0)]),
            L("FFE8C890", 6))
    rug_in = E(O, "RugInner", 540, 1520, 780, 220, L("CCE8C890", 4))

    # window with night sky + skyline, curtains
    wx0, wy0, wx1, wy1 = 360, 380, 720, 900
    sky = rect("WinSky", wx0, wy0, wx1, wy1, sc.vgrad(-260, 260, [("FF1C2450", 0.0), ("FF6A4A80", 1.0)]))
    city = S(O, "Skyline", [(wx0, wy1, "c"), (wx0, 760, "c"), (400, 760, "c"), (400, 700, "c"), (440, 700, "c"),
                            (440, 780, "c"), (480, 780, "c"), (480, 660, "c"), (530, 660, "c"), (530, 740, "c"),
                            (580, 740, "c"), (580, 690, "c"), (630, 690, "c"), (630, 770, "c"), (680, 770, "c"),
                            (680, 720, "c"), (wx1, 720, "c"), (wx1, wy1, "c")], F("FF231C38"))
    rnd = random.Random(3)
    windows_lit = [rect(f"Lit{i}", x, y, x + 8, y + 10, F("FFFFD27A"), opacity=rnd.uniform(0.5, 1))
                   for i, (x, y) in enumerate([(rnd.uniform(400, 700), rnd.uniform(720, 880)) for _ in range(18)])]
    moon = E(O, "Moon", 640, 470, 60, 60, F("FFFFF2D0"))
    frame = rect("WinFrame", wx0 - 14, wy0 - 14, wx1 + 14, wy1 + 14, F("FFE8DCCC"), 6)
    mullion = [rect("MullV", 532, wy0, 548, wy1, F("FFE8DCCC")), rect("MullH", wx0, 632, wx1, 646, F("FFE8DCCC"))]
    sill = rect("Sill", wx0 - 34, wy1 + 8, wx1 + 34, wy1 + 30, F("FFF2E8DA"), 4)
    curtain = [(300, 340), (380, 340), (390, 600), (370, 960), (300, 980, "c")]
    curt_l = S(O, "CurtainL", curtain + [(280, 640)], sc.vgrad(-320, 320, [("FFA83A4A", 0.0), ("FF6E1E2E", 1.0)]),
               L(INKC, 3))
    curt_r = S(O, "CurtainR", [(W - p[0], p[1]) + tuple(p[2:]) for p in reversed(curtain + [(280, 640)])],
               sc.vgrad(-320, 320, [("FFA83A4A", 0.0), ("FF6E1E2E", 1.0)]), L(INKC, 3))
    folds = [S(O, f"Fold{i}", [(x, 360), (x + 6, 700), (x - 4, 960)], L("40000000", 3), closed=False)
             for i, x in enumerate([330, 350, W - 330, W - 350])]
    rod = rect("Rod", 270, 330, W - 270, 342, F("FF3A2A20"), 6)

    # floor lamp (left)
    lx = 170.0
    lamp_glow = E(O, "LampGlow", lx, 700, 700, 700, sc.rgrad(350, [("70FFD890", 0.0), ("20FFC070", 0.5), ("00FFC070", 1.0)]))
    lamp_cone = S(O, "LampCone", [(lx - 60, 760), (lx + 60, 760), (lx + 170, floor_y + 80), (lx - 170, floor_y + 80)],
                  sc.vgrad(-260, 260, [("40FFE0A0", 0.0), ("00FFE0A0", 1.0)]))
    shade = S(O, "Shade", [(lx - 46, 640), (lx + 46, 640), (lx + 74, 760, "c"), (lx - 74, 760, "c")],
              sc.vgrad(-60, 60, [("FFFFF2D8", 0.0), ("FFF0D8A8", 1.0)]), L(INKC, 3))
    pole = rect("Pole", lx - 5, 760, lx + 5, 1230, F("FF2A2228"))
    lamp_base = E(O, "LampBase", lx, 1236, 120, 26, F("FF2A2228"))
    lamp = d("Node", shade, pole, lamp_base, x=0.0, y=0.0, name="Lamp")

    # plant (left of the avatar, on the floor)
    px_, py_ = 330.0, 1250.0
    leaves = []
    for k, (ang, ln) in enumerate([(-2.2, 190), (-1.8, 230), (-1.4, 250), (-1.0, 220), (-0.7, 170), (-2.6, 150)]):
        tx, ty = px_ + math.cos(ang) * ln, py_ - 60 + math.sin(ang) * ln
        mx, my = px_ + math.cos(ang) * ln * 0.55, py_ - 60 + math.sin(ang) * ln * 0.55
        nx, ny = -math.sin(ang) * 40, math.cos(ang) * 40
        leaves.append(S(O, f"Leaf{k}", [(px_, py_ - 60), (mx + nx, my + ny), (tx, ty, "c"), (mx - nx, my - ny)],
                        sc.vgrad(-100, 100, [("FF5AA86A", 0.0), ("FF2E6A3E", 1.0)]), L("FF1A3A22", 2.5)))
        leaves.append(S(O, f"Vein{k}", [(px_, py_ - 60), (mx, my), (tx, ty)], L("FF1A3A22", 2), closed=False))
    pot = S(O, "Pot", [(px_ - 60, py_ - 70, "c"), (px_ + 60, py_ - 70, "c"), (px_ + 46, py_ + 40, "c"),
                       (px_ - 46, py_ + 40, "c")], sc.vgrad(-55, 55, [("FFD88A5A", 0.0), ("FF9A5232", 1.0)]),
              L(INKC, 3))
    plant = d("Node", pot, *leaves[::-1], x=0.0, y=0.0, name="Plant")

    # TV on a cabinet (right)
    tx0, ty0 = 700.0, 1080.0
    cabinet = rect("Cabinet", tx0, ty0, tx0 + 330, ty0 + 150, sc.vgrad(-75, 75, [("FF8A5A3A", 0.0), ("FF5A3622", 1.0)]),
                   6)
    knobs = [E(O, f"Knob{i}", tx0 + 90 + i * 150, ty0 + 75, 12, 12, F("FFE0C080")) for i in range(2)]
    tv_frame = rect("TvFrame", tx0 + 20, 880, tx0 + 300, 1060, F("FF15141A"), 10)
    tv_screen = rect("TvScreen", tx0 + 34, 894, tx0 + 286, 1046, sc.vgrad(-76, 76, [("FF2A2E3A", 0.0), ("FF14161E", 1.0)]),
                     4)
    tv_on = rect("TvOn", tx0 + 34, 894, tx0 + 286, 1046, sc.vgrad(-76, 76, [("FF6AD8FF", 0.0), ("FFB86AFF", 1.0)]), 4,
                 opacity=0.0)
    tv_shapes = [E(O, f"TvBlob{i}", tx0 + 100 + i * 70, 960 + (i % 2) * 30, 70, 50, F(c), opacity=0.0)
                 for i, c in enumerate(["CCFFE066", "CCFF6AA0", "CC66FFB0"])]
    tv_glow = E(O, "TvGlow", tx0 + 160, 970, 700, 500, sc.rgrad(350, [("506AD8FF", 0.0), ("006AD8FF", 1.0)]), opacity=0.0)
    tv_stand = rect("TvStand", tx0 + 140, 1060, tx0 + 180, 1080, F("FF15141A"))
    tv_glare = S(O, "TvGlare", [(tx0 + 50, 900), (tx0 + 110, 900), (tx0 + 60, 1040), (tx0 + 40, 1040)], F("18FFFFFF"))

    # sleeping cat on the cabinet (prop)
    cx_, cy_ = 960.0, ty0 - 4
    cat = d("Node", x=cx_, y=cy_, name="Cat")
    CP = (cx_, cy_)
    cat_body = S(CP, "CatBody", [(cx_ - 60, cy_), (cx_ - 54, cy_ - 34), (cx_ - 10, cy_ - 50), (cx_ + 40, cy_ - 40),
                                 (cx_ + 64, cy_ - 10), (cx_ + 60, cy_, "c")],
                 sc.vgrad(-30, 30, [("FFF0A060", 0.0), ("FFC07038", 1.0)]), L(INKC, 2.5))
    cat_head = S(CP, "CatHead", [(cx_ - 78, cy_), (cx_ - 84, cy_ - 30), (cx_ - 80, cy_ - 52, "c"), (cx_ - 66, cy_ - 38),
                                 (cx_ - 50, cy_ - 40), (cx_ - 40, cy_ - 54, "c"), (cx_ - 36, cy_ - 28), (cx_ - 44, cy_)],
                 F("FFF0A060"), L(INKC, 2.5))
    cat_eyes = [S(CP, f"CatEye{i}", [(cx_ - 72 + i * 20, cy_ - 22), (cx_ - 66 + i * 20, cy_ - 18), (cx_ - 60 + i * 20, cy_ - 22)],
                  L(INKC, 2), closed=False) for i in range(2)]
    cat_tail = S(CP, "CatTail", [(cx_ + 56, cy_ - 4), (cx_ + 90, cy_ - 2), (cx_ + 104, cy_ - 30)], L("FFC07038", 10),
                 closed=False, origin=(cx_ + 56, cy_ - 4))
    zzz = [S(O, f"Z{i}", [(cx_ - 90 - i * 18, cy_ - 70 - i * 26, "c"), (cx_ - 76 - i * 18, cy_ - 70 - i * 26, "c"),
                         (cx_ - 90 - i * 18, cy_ - 56 - i * 26, "c"), (cx_ - 76 - i * 18, cy_ - 56 - i * 26, "c")],
               L("AAFFFFFF", 2.5), closed=False, opacity=0.0) for i in range(3)]
    stripes_c = [S(CP, f"CatStripe{i}", [(cx_ - 10 + i * 18, cy_ - 46), (cx_ - 4 + i * 18, cy_ - 26)], L("FFC07038", 4),
                   closed=False) for i in range(3)]
    cat.add(*cat_eyes, cat_head, *stripes_c, cat_body, cat_tail)
    sc.ambient("CatSleep", sc.A("amb_cat", 180, [
        sc.T(cat_body, scaleY=[(0, 1.0), (90, 1.06), (180, 1.0)]),
        sc.T(cat_tail, rotation=[(0, 0.0), (60, -0.15), (120, 0.05), (180, 0.0)]),
        *[sc.T(z, ease=None, opacity=[(0, 0.0), (30 + 30 * i, 0.0), (60 + 30 * i, 0.9, "linear"), (150, 0.0), (180, 0.0)])
          for i, z in enumerate(zzz)]], loop=True))

    # ---- events
    night = rect("Night", -10, -10, W + 10, H + 10, F("FF060A1C"), opacity=0.0)
    moonbeam = S(O, "MoonBeam", [(wx0, wy0), (wx1, wy0), (wx1 + 260, H), (wx0 - 160, H)],
                 sc.vgrad(-800, 800, [("30B8C8FF", 0.0), ("00B8C8FF", 1.0)]), opacity=0.0)
    lights_on = sc.A("lights_on", 1, [sc.T(night, ease=None, opacity=[(0, 0.0)]), sc.T(lamp_glow, ease=None, opacity=[(0, 1.0)]),
                                      sc.T(lamp_cone, ease=None, opacity=[(0, 1.0)]), sc.T(moonbeam, ease=None, opacity=[(0, 0.0)]),
                                      sc.T(shade, ease=None, opacity=[(0, 1.0)])])
    lights_off = sc.A("lights_off", 1, [sc.T(night, ease=None, opacity=[(0, 0.62)]), sc.T(lamp_glow, ease=None, opacity=[(0, 0.0)]),
                                        sc.T(lamp_cone, ease=None, opacity=[(0, 0.0)]),
                                        sc.T(moonbeam, ease=None, opacity=[(0, 1.0)]),
                                        sc.T(shade, ease=None, opacity=[(0, 0.75)])])
    sc.toggle("Lights", lights_on, {"lightsOn": lights_on, "lightsOff": lights_off})
    flick = []
    for i, b in enumerate(tv_shapes):
        flick.append(sc.T(b, ease=None, opacity=[(0, 0.0), (20, 0.0)] + [(f, 0.9 if (f // 15 + i) % 3 == 0 else 0.2, "linear")
                                                                       for f in range(30, 540, 15)] + [(560, 0.0)],
                          x=[(0, float(b.attrs["x"])), (560, float(b.attrs["x"]) + (40 if i % 2 else -40))]))
    tv = sc.A("ev_tvOn", 560, [
        sc.T(tv_on, ease=None, opacity=[(0, 0.0), (8, 1.0, "linear"), (540, 1.0), (556, 0.0)]),
        sc.T(tv_glow, ease=None, opacity=[(0, 0.0), (8, 1.0, "linear")] + [(f, 0.7 if (f // 10) % 2 else 1.0, "linear")
                                                                         for f in range(20, 540, 10)] + [(556, 0.0)]),
        *flick])
    sc.one_shot("tvOn", tv)
    # a second cat trots across the floor
    wk = d("Node", x=-200.0, y=1560.0, name="WalkingCat")
    WP = (-200.0, 1560.0)
    legs = []
    for i, lx_ in enumerate((-50, -30, 30, 50)):
        leg = S(WP, f"Leg{i}", [(WP[0] + lx_, WP[1] - 20), (WP[0] + lx_, WP[1] + 34)], L("FF3A3440", 9), closed=False,
                origin=(WP[0] + lx_, WP[1] - 20))
        legs.append(leg)
    wk.add(S(WP, "WHead", [(WP[0] + 70, WP[1] - 40), (WP[0] + 76, WP[1] - 76, "c"), (WP[0] + 90, WP[1] - 58),
                           (WP[0] + 106, WP[1] - 76, "c"), (WP[0] + 112, WP[1] - 40), (WP[0] + 96, WP[1] - 20),
                           (WP[0] + 78, WP[1] - 22)], F("FF3A3440")),
           E(WP, "WEye", WP[0] + 100, WP[1] - 46, 8, 6, F("FFE0F060")),
           S(WP, "WBody", [(WP[0] - 70, WP[1] - 40), (WP[0] + 80, WP[1] - 46), (WP[0] + 74, WP[1] - 4),
                           (WP[0] - 64, WP[1] + 2)], F("FF3A3440")),
           S(WP, "WTail", [(WP[0] - 66, WP[1] - 34), (WP[0] - 110, WP[1] - 60), (WP[0] - 100, WP[1] - 110)],
             L("FF3A3440", 9), closed=False),
           *legs)
    stride = [sc.T(lg, ease=None, rotation=[(f, (0.35 if ((f // 10) + i) % 2 else -0.35), "linear")
                                            for f in range(0, 241, 10)]) for i, lg in enumerate(legs)]
    cat_walk = sc.A("ev_catWalksBy", 240, [sc.T(wk, ease=None, x=[(0, -200.0), (240, W + 220.0)],
                                                y=[(f, 1560.0 - (4 if (f // 10) % 2 else 0), "linear") for f in range(0, 241, 10)]),
                                           *stride])
    sc.one_shot("catWalksBy", cat_walk)

    hits = [sc.hit("lamp", lx, 900, 180, 660), sc.hit("tv", tx0 + 160, 970, 300, 200),
            sc.hit("cat", cx_ - 10, cy_ - 30, 190, 80), sc.hit("plant", px_, py_ - 140, 300, 380)]
    for h, pid in zip(hits, ["lamp", "tv", "cat", "plant"]):
        sc.prop(pid, h)
    content = [night, wk, rug_in, rug, plant, cat, *zzz, tv_glare, *tv_shapes, tv_on, tv_screen, tv_frame, tv_stand,
               *knobs, cabinet, lamp, lamp_cone, moonbeam, tv_glow, lamp_glow, *planks, floor, baseboard, rod, *folds,
               curt_l, curt_r, sill, *mullion, *windows_lit, city, moon, sky, frame, rail, wainscot, *stripes, wall]
    return sc.write(content, hits)


# ====================================================================== beach
def beach() -> str:
    sc = Scene("beach")
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    O = (0.0, 0.0)
    rnd = random.Random(11)
    INKC = "FF2A3040"
    horizon, shore = 980.0, 1180.0

    def full(name: str, paint: El, y0: float = -10, y1: float = H + 10, **kw: object) -> El:
        return d("Shape", d("Rectangle", width=float(W + 20), height=float(y1 - y0), name="Path"), paint,
                 x=float(W / 2), y=float((y0 + y1) / 2), name=name, **kw)

    sky = full("Sky", sc.vgrad(-500, 500, [("FF4AA0E0", 0.0), ("FF9AD0F0", 0.7), ("FFFFE4C8", 1.0)]), -10, horizon + 10)
    sunset_sky = full("SunsetSky", sc.vgrad(-500, 500, [("FF3A2A6A", 0.0), ("FFE0607A", 0.55), ("FFFFB060", 1.0)]),
                      -10, horizon + 10, opacity=0.0)
    sun = d("Node", E((0, 0), "SunGlow", 0, 0, 360, 360, sc.rgrad(180, [("88FFF2B0", 0.0), ("00FFF2B0", 1.0)])),
            E((0, 0), "SunDisc", 0, 0, 120, 120, sc.rgrad(60, [("FFFFFBE0", 0.0), ("FFFFE080", 1.0)])),
            x=780.0, y=640.0, name="Sun")
    clouds = []
    cl_tracks = []
    for i, (cx, cy, sz) in enumerate([(220, 420, 1.0), (700, 300, 0.8), (960, 520, 0.6)]):
        puffs = [E((cx, cy), f"Puff{k}", cx + dx * sz, cy + dy * sz, w * sz, w * sz * 0.8, F("F0FFFFFF"))
                 for k, (dx, dy, w) in enumerate([(-60, 10, 90), (0, -14, 120), (64, 6, 96), (10, 22, 150)])]
        c = d("Node", *puffs, x=float(cx), y=float(cy), name=f"Cloud{i}")
        clouds.append(c)
        cl_tracks.append(sc.T(c, ease=None, x=[(0, float(cx)), (1200, float(cx) + 120 * (1 if i % 2 else -1))] ,
                              ))
    for t in cl_tracks:   # drift there and back (seamless loop)
        kp = t.children[0]
        kp.children[0].attrs["interpolationType"] = "linear"
    cl_tracks = [sc.T(c, x=[(0, float(c.attrs["x"])), (600, float(c.attrs["x"]) + 60 * (1 if i % 2 else -1)),
                            (1200, float(c.attrs["x"]))]) for i, c in enumerate(clouds)]
    sea = full("Sea", sc.vgrad(-110, 110, [("FF2A7AB8", 0.0), ("FF3AA8C8", 1.0)]), horizon, shore + 10)
    glints = [d("Shape", d("Rectangle", width=float(rnd.uniform(30, 70)), height=4.0, name="Path"), F("AAFFFFFF"),
                x=rnd.uniform(40, W - 40), y=rnd.uniform(horizon + 20, shore - 30), name=f"Glint{i}") for i in range(16)]
    gl_tracks = [sc.T(g, ease=None, opacity=[(0, 0.2), ((i * 17) % 100 + 10, 1.0, "linear"), ((i * 17) % 100 + 50, 0.2, "linear"),
                                             (180, 0.2)]) for i, g in enumerate(glints)]
    waves = []
    w_tracks = []
    for i, y in enumerate([shore - 70, shore - 30]):
        pts = [(-40, y)] + [(x, y + (10 if (x // 60) % 2 else -6)) for x in range(20, W + 80, 60)] + [(W + 60, y + 40, "c"),
                                                                                                  (-40, y + 40, "c")]
        wv = S(O, f"Wave{i}", pts, sc.vgrad(-30, 30, [("CCFFFFFF", 0.0), ("0076D0E0", 1.0)]))
        waves.append(wv)
        w_tracks.append(sc.T(wv, x=[(0, float(wv.attrs["x"])), (90, float(wv.attrs["x"]) + 30 * (1 if i else -1)),
                                    (180, float(wv.attrs["x"]))]))
    sand = full("Sand", sc.vgrad(-370, 370, [("FFF6DCA8", 0.0), ("FFE0B87A", 1.0)]), shore, H + 10)
    wet = S(O, "WetSand", [(-40, shore), (W + 40, shore), (W + 40, shore + 40), (W / 2, shore + 60), (-40, shore + 40)],
            F("FFD6B07A"))
    foam = S(O, "Foam", [(-40, shore + 4)] + [(x, shore + 22 + (8 if (x // 50) % 2 else 0)) for x in range(0, W + 41, 50)] +
             [(W + 40, shore - 6, "c"), (-40, shore - 6, "c")], F("EEFFFFFF"))
    foam_tracks = [sc.T(foam, y=[(0, float(foam.attrs["y"])), (90, float(foam.attrs["y"]) + 18), (180, float(foam.attrs["y"]))],
                        opacity=[(0, 1.0), (90, 0.6), (180, 1.0)])]
    specks = [E(O, f"Speck{i}", rnd.uniform(0, W), rnd.uniform(shore + 80, H), 5, 4, F("40A07840")) for i in range(30)]
    sc.ambient("Sea", sc.A("amb_sea", 180, gl_tracks + w_tracks + foam_tracks, loop=True))
    sc.ambient("Clouds", sc.A("amb_clouds", 1200, cl_tracks, loop=True))

    # umbrella + towel (left)
    ux, uy = 220.0, 1060.0
    canopy_pts = [(ux - 190, uy + 60, "c"), (ux - 120, uy - 20), (ux, uy - 70), (ux + 120, uy - 20), (ux + 190, uy + 60, "c")]
    canopy = S(O, "Canopy", canopy_pts + [(ux, uy + 40)], F("FFF4F0E8"), L(INKC, 3))
    canopy_clip = S(O, "CanopyClip", canopy_pts + [(ux, uy + 40)])
    canopy_clip.children = [c for c in canopy_clip.children if c.tag not in ("Fill", "Stroke")]
    stripes_u = [S(O, f"UStripe{i}", [(ux, uy - 90), (ux + (i * 2 - 3) * 60 - 30, uy + 80), (ux + (i * 2 - 3) * 60 + 30, uy + 80)],
                   F("FFE04848"), ) for i in range(4)]
    for su in stripes_u:
        su.children.insert(0, d("ClippingShape", sourceId=canopy_clip.ref(), name="Clip"))
    pole_u = S(O, "UPole", [(ux, uy - 70), (ux + 10, 1330)], L("FFEDEDED", 7), closed=False)
    towel = S(O, "Towel", [(90, 1300), (330, 1290), (350, 1380), (100, 1392)], sc.vgrad(-50, 50, [("FF3AB0C8", 0.0), ("FF2A8AA8", 1.0)]),
              L(INKC, 2.5))
    umb = d("Node", *stripes_u, canopy, canopy_clip, pole_u, x=0.0, y=0.0, name="Umbrella")
    umb_shadow = E(O, "UShadow", ux + 30, 1340, 360, 60, F("30805020"))

    # crab (right front), side-steps
    crx, cry = 860.0, 1400.0
    crab = d("Node", x=crx, y=cry, name="Crab")
    CR = (crx, cry)
    crab_legs = [S(CR, f"CLeg{i}", [(crx + sx * 26, cry + 6), (crx + sx * 50, cry + 4 + k * 6), (crx + sx * 58, cry + 30 + k * 6)],
                   L("FFC23A2A", 5), closed=False) for i, (sx, k) in enumerate([(-1, 0), (-1, 1), (-1, 2), (1, 0), (1, 1), (1, 2)])]
    claws = [S(CR, f"Claw{i}", [(crx + sx * 40, cry - 30), (crx + sx * 62, cry - 56), (crx + sx * 46, cry - 66, "c"),
                                (crx + sx * 52, cry - 50), (crx + sx * 30, cry - 44)], F("FFE04A36"), L("FF7A1A12", 2.5),
                 origin=(crx + sx * 30, cry - 20)) for i, sx in enumerate((-1, 1))]
    crab.add(*[E(CR, f"CEye{i}", crx + sx * 12, cry - 40, 12, 12, F("FFFFFFFF"), L("FF20100C", 2)) for i, sx in enumerate((-1, 1))],
             *[E(CR, f"CPupil{i}", crx + sx * 12, cry - 40, 5, 6, F("FF20100C")) for i, sx in enumerate((-1, 1))],
             *claws,
             E(CR, "Shell", crx, cry, 92, 60, sc.rgrad(46, [("FFF06A50", 0.0), ("FFC23A2A", 1.0)], cx=-10, cy=-10),
               L("FF7A1A12", 2.5)),
             *crab_legs)
    sc.ambient("Crab", sc.A("amb_crab", 240, [
        sc.T(crab, x=[(0, crx), (60, crx - 40), (120, crx - 40), (180, crx), (240, crx)]),
        *[sc.T(c, rotation=[(0, 0.0), (20, 0.25 * (1 if i else -1)), (40, 0.0), (240, 0.0)]) for i, c in enumerate(claws)],
        *[sc.T(lg, ease=None, rotation=[(f, 0.15 if ((f // 8) + i) % 2 else -0.15, "linear") for f in range(0, 241, 8)])
          for i, lg in enumerate(crab_legs)]], loop=True))

    # gull on a post (prop) + flying gulls
    gx, gy = 980.0, 1060.0
    post = d("Shape", d("Rectangle", width=26.0, height=200.0, name="Path"), sc.vgrad(-100, 100, [("FF8A6A48", 0.0), ("FF5A4028", 1.0)]),
             L(INKC, 2.5), x=gx, y=gy + 110, name="Post")
    gull = d("Node", x=gx, y=gy, name="Gull")
    GP = (gx, gy)
    gull.add(E(GP, "GEye", gx - 18, gy - 34, 5, 5, F("FF101010")),
             S(GP, "GBeak", [(gx - 30, gy - 30), (gx - 50, gy - 26, "c"), (gx - 30, gy - 22)], F("FFF0B030")),
             E(GP, "GHead", gx - 16, gy - 30, 34, 30, F("FFFFFFFF"), L(INKC, 2)),
             S(GP, "GWing", [(gx - 10, gy - 14), (gx + 40, gy - 8), (gx + 52, gy + 6, "c"), (gx + 4, gy + 4)],
               sc.vgrad(-10, 10, [("FFB8C0CC", 0.0), ("FF7A8494", 1.0)]), L(INKC, 2)),
             E(GP, "GBody", gx, gy - 4, 72, 40, F("FFFFFFFF"), L(INKC, 2)),
             S(GP, "GLegs", [(gx - 6, gy + 12), (gx - 6, gy + 12 + 0.01)], L("FFF0B030", 3), closed=False))
    sc.ambient("Gull", sc.A("amb_gull", 300, [sc.T(gull, rotation=[(0, 0.0), (200, 0.0), (215, -0.12), (230, 0.0), (300, 0.0)])],
                            loop=True))
    flyers = []
    fly_tracks = []
    for i, (fx_, fy_) in enumerate([(300, 560), (420, 500)]):
        b, flap = bird(sc, f"Flyer{i}", fx_, fy_, 22, "FF3A4050")
        flyers.append(b)
        fly_tracks += flap
        fly_tracks.append(sc.T(b, x=[(0, float(fx_)), (360, float(fx_) + 160), (720, float(fx_))],
                               y=[(0, float(fy_)), (180, float(fy_) - 30), (540, float(fy_) + 20), (720, float(fy_))]))
    sc.ambient("Flyers", sc.A("amb_flyers", 720, fly_tracks, loop=True))

    # ---- events
    big = S(O, "BigWave", [(-60, shore + 10, "c"), (-60, horizon + 60), (200, horizon - 40), (420, horizon - 160),
                           (560, horizon - 210), (660, horizon - 170), (640, horizon - 120), (590, horizon - 140),
                           (640, horizon - 60), (W + 60, horizon + 40), (W + 60, shore + 10, "c")],
            sc.vgrad(-200, 200, [("FF3AA0D0", 0.0), ("FF2A6A9A", 1.0)]), L("EEFFFFFF", 6), opacity=0.0)
    big_foam = S(O, "BigFoam", [(-40, shore), (W + 40, shore), (W + 40, shore + 140), (W / 2, shore + 170), (-40, shore + 140)],
                 F("DDFFFFFF"), opacity=0.0)
    by0 = float(big.attrs["y"])
    wave_anim = sc.A("ev_bigWave", 200, [
        sc.T(big, y=[(0, by0 + 160), (60, by0), (90, by0 + 40), (120, by0 + 220), (200, by0 + 220)],
             opacity=[(0, 0.0), (20, 1.0), (110, 1.0), (130, 0.0), (200, 0.0)],
             scaleX=[(0, 1.0), (90, 1.05), (200, 1.0)]),
        sc.T(big_foam, opacity=[(0, 0.0), (100, 0.0), (120, 1.0), (170, 0.6), (200, 0.0)],
             y=[(0, float(big_foam.attrs["y"])), (120, float(big_foam.attrs["y"]) + 60), (200, float(big_foam.attrs["y"]))]),
    ])
    sc.one_shot("bigWave", wave_anim)
    flock = []
    flock_tracks = []
    for i in range(6):
        x0, y0 = -120 - i * 70, 380 + (i % 3) * 50 + i * 6
        b, flap = bird(sc, f"Flock{i}", x0, y0, 30, "FF2A3040")
        flock.append(b)
        flock_tracks += flap * 1
        flock_tracks.append(sc.T(b, ease=None, x=[(0, float(x0)), (300, float(x0) + W + 700)],
                                 y=[(0, float(y0)), (150, float(y0) - 40), (300, float(y0))]))
    sc.one_shot("seagulls", sc.A("ev_seagulls", 300, flock_tracks))
    sunset = sc.A("ev_sunset", 720, [
        sc.T(sunset_sky, opacity=[(0, 0.0), (180, 1.0), (560, 1.0), (720, 0.0)]),
        sc.T(sun, y=[(0, 640.0), (200, 930.0), (560, 930.0), (720, 640.0)], x=[(0, 780.0), (200, 700.0), (560, 700.0), (720, 780.0)]),
        sc.T(sea, opacity=[(0, 1.0), (180, 0.7), (560, 0.7), (720, 1.0)]),
    ])
    sc.one_shot("sunset", sunset)
    rain_node, rain_anim = rain_fx(sc, "Rain", "99E0F0FF", darken="FF1A2A40",
                                   extra=[sc.T(sun, ease=None, opacity=[(0, 1.0), (40, 0.2, "linear"), (420, 0.2, "linear"), (480, 1.0)])])
    sc.one_shot("rain", rain_anim)

    deco = []
    for i, (sx_, sy_, r_) in enumerate([(180, 1560, 34), (620, 1700, 26), (930, 1610, 30)]):
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = r_ if k % 2 == 0 else r_ * 0.45
            pts.append((sx_ + rr * math.cos(a), sy_ + rr * math.sin(a), "c4"))
        deco.append(S(O, f"Starfish{i}", pts, sc.rgrad(r_, [("FFFFA070", 0.0), ("FFE0604A", 1.0)]), L("FFA03A2A", 2)))
    for i, (sx_, sy_) in enumerate([(420, 1480), (760, 1520), (300, 1800), (850, 1830)]):
        fan = [(sx_ - 18, sy_), (sx_ - 14, sy_ - 16), (sx_, sy_ - 22), (sx_ + 14, sy_ - 16), (sx_ + 18, sy_), (sx_, sy_ + 8, "c")]
        deco.append(S(O, f"Shell{i}", fan, F("FFFFF0E4"), L("FFC8A88A", 2)))
        deco += [S(O, f"ShellRib{i}_{k}", [(sx_, sy_ + 6), (sx_ + (k - 1) * 10, sy_ - 16)], L("FFC8A88A", 1.5), closed=False)
                 for k in range(3)]
    castle = [S(O, "Castle", [(560, 1640, "c"), (560, 1560, "c"), (580, 1560, "c"), (580, 1540, "c"), (600, 1540, "c"),
                              (600, 1560, "c"), (640, 1560, "c"), (640, 1520, "c"), (664, 1520, "c"), (664, 1560, "c"),
                              (700, 1560, "c"), (700, 1640, "c")], sc.vgrad(-60, 60, [("FFF0D08A", 0.0), ("FFC8A060", 1.0)]),
                L("FFA07A40", 2.5)),
              S(O, "Flag", [(652, 1520), (652, 1480), (680, 1490), (652, 1500)], F("FFE04848"))]
    hits = [sc.hit("crab", crx, cry - 20, 180, 130), sc.hit("umbrella", ux, uy + 40, 400, 300),
            sc.hit("seagull", gx - 10, gy - 10, 120, 100)]
    for h, pid in zip(hits, ["crab", "umbrella", "seagull"]):
        sc.prop(pid, h)
    content = [rain_node, *flock, *castle, *deco, crab, gull, post, umb, towel, umb_shadow, *specks, big_foam, foam, wet, sand, big,
               *waves, *glints, sea, *flyers, *clouds, sun, sunset_sky, sky]
    return sc.write(content, hits)


# ====================================================================== deepSpace
def deepSpace() -> str:  # noqa: N802
    sc = Scene("deepSpace")
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    O = (0.0, 0.0)
    rnd = random.Random(23)
    bg = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
           sc.vgrad(0, H, [("FF05040E", 0.0), ("FF120A2A", 0.5), ("FF060818", 1.0)]), name="Void")
    for g in bg.children:
        if g.tag == "Fill":
            g.children[0].attrs.update(startY=0.0, endY=float(H))
    nebulae = [E(O, f"Nebula{i}", x, y, r * 2, r * 2, sc.rgrad(r, [(c, 0.0), ("00" + c[2:], 1.0)]), scaleY=sy)
               for i, (x, y, r, c, sy) in enumerate([(300, 700, 520, "66B03AD0", 0.7), (780, 1100, 600, "5530B0C8", 0.6),
                                                     (600, 500, 380, "44E04A8A", 0.8)])]
    stars = []
    tw = []
    for i in range(110):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        r = rnd.choice([2.0, 2.4, 3.0, 3.0, 4.2])
        st = E(O, f"Star{i}", x, y, r, r, F(rnd.choice(["FFFFFFFF", "FFCFE0FF", "FFFFE6C8"])), opacity=rnd.uniform(0.4, 1))
        stars.append(st)
        if i % 8 == 0:
            base = float(st.attrs["opacity"])
            ph = rnd.randint(0, 200)
            tw.append(sc.T(st, opacity=uniq([(0, base), (240, base), ((ph + 40) % 240, 0.1), ((ph + 90) % 240, base)])))
    sc.ambient("Stars", sc.A("amb_stars", 240, tw, loop=True))
    neb_breathe = sc.A("amb_nebula", 480, [sc.T(n, opacity=[(0, 1.0), (240, 0.75), (480, 1.0)]) for n in nebulae], loop=True)
    sc.ambient("Nebula", neb_breathe)

    # planet with rings (left)
    px, py = 230.0, 820.0
    ring_back = E(O, "RingBack", px, py, 520, 120, L("AAE0C8A0", 10), rotation=-0.25)
    ring_back_clip = S(O, "RingBackClip", [(px - 300, py - 200), (px + 300, py - 200), (px + 300, py), (px - 300, py)])
    ring_back_clip.children = [c for c in ring_back_clip.children if c.tag not in ("Fill", "Stroke")]
    ring_front = E(O, "RingFront", px, py, 520, 120, L("DDF0D8B0", 10), rotation=-0.25)
    ring_front_clip = S(O, "RingFrontClip", [(px - 300, py), (px + 300, py), (px + 300, py + 200), (px - 300, py + 200)])
    ring_front_clip.children = [c for c in ring_front_clip.children if c.tag not in ("Fill", "Stroke")]
    ring_back.children.insert(0, d("ClippingShape", sourceId=ring_back_clip.ref(), name="Clip"))
    ring_front.children.insert(0, d("ClippingShape", sourceId=ring_front_clip.ref(), name="Clip"))
    planet = E(O, "Planet", px, py, 300, 300, sc.rgrad(170, [("FFF0A070", 0.0), ("FFC0587A", 0.55), ("FF3A1A4A", 1.0)],
                                                        cx=-60, cy=-60))
    bands = [E(O, f"Band{i}", px, py - 60 + i * 50, 300 - abs(i - 1.2) * 60, 18, F("30FFFFFF")) for i in range(3)]
    planet_g = d("Node", ring_front, *bands, planet, ring_back, ring_front_clip, ring_back_clip, x=0.0, y=0.0, name="PlanetGroup")
    sc.ambient("Planet", sc.A("amb_planet", 600, [sc.T(planet_g, y=[(0, 0.0), (300, -10.0), (600, 0.0)])], loop=True))
    moonlet = E(O, "Moonlet", 420, 640, 50, 50, sc.rgrad(30, [("FFD8D8E8", 0.0), ("FF6A6A80", 1.0)], cx=-10, cy=-10))

    # UFO (right) bobbing with blinking lights
    ux, uy = 860.0, 900.0
    ufo = d("Node", x=ux, y=uy, name="Ufo")
    UP = (ux, uy)
    lights = [E(UP, f"ULight{i}", ux + (i - 2) * 40, uy + 12, 12, 12, F("FFFFE060")) for i in range(5)]
    beam = S(UP, "Beam", [(ux - 40, uy + 20), (ux + 40, uy + 20), (ux + 110, uy + 300), (ux - 110, uy + 300)],
             sc.vgrad(-140, 140, [("6090FFB0", 0.0), ("0090FFB0", 1.0)]))
    ufo.add(*lights,
            S(UP, "Dome", [(ux - 54, uy - 10), (ux - 40, uy - 50), (ux, uy - 66), (ux + 40, uy - 50), (ux + 54, uy - 10)],
              sc.vgrad(-30, 30, [("CCB8F0FF", 0.0), ("886AA8D0", 1.0)]), L("FF2A3450", 2.5)),
            E(UP, "Alien", ux, uy - 30, 30, 34, F("FF7AE070")),
            E(UP, "Saucer", ux, uy + 4, 220, 54, sc.rgrad(110, [("FFE0E6F0", 0.0), ("FF7A8498", 1.0)], cy=-14), L("FF2A3450", 2.5)),
            beam)
    sc.ambient("Ufo", sc.A("amb_ufo", 240, [
        sc.T(ufo, y=[(0, uy), (120, uy - 22), (240, uy)], rotation=[(0, 0.04), (120, -0.04), (240, 0.04)]),
        *[sc.T(l_, ease=None, opacity=[(0, 1.0), ((i * 12) % 60 + 1, 0.2, "hold"), ((i * 12) % 60 + 30, 1.0, "hold"), (240, 1.0)])
          for i, l_ in enumerate(lights)],
        sc.T(beam, opacity=[(0, 0.6), (120, 1.0), (240, 0.6)])], loop=True))

    # rubber duck drifting (front right)
    dx_, dy_ = 760.0, 1260.0
    duck = d("Node", x=dx_, y=dy_, name="Duck")
    DP = (dx_, dy_)
    duck.add(E(DP, "DEye", dx_ + 30, dy_ - 56, 10, 12, F("FF101010")),
             S(DP, "DBeak", [(dx_ + 50, dy_ - 44), (dx_ + 82, dy_ - 40, "c"), (dx_ + 50, dy_ - 30)], F("FFF07A20"), L("FF8A3A10", 2)),
             E(DP, "DHead", dx_ + 26, dy_ - 46, 64, 60, F("FFFFD830"), L("FFB08010", 2.5)),
             S(DP, "DWing", [(dx_ - 30, dy_ - 6), (dx_ + 10, dy_ - 14), (dx_ + 4, dy_ + 10)], F("FFF0C020"), L("FFB08010", 2)),
             S(DP, "DBody", [(dx_ - 60, dy_ - 30, "c"), (dx_ - 30, dy_ - 12), (dx_ + 20, dy_ - 16), (dx_ + 54, dy_ - 4),
                             (dx_ + 40, dy_ + 28), (dx_ - 20, dy_ + 34), (dx_ - 56, dy_ + 10)], F("FFFFD830"), L("FFB08010", 2.5)))
    sc.ambient("Duck", sc.A("amb_duck", 480, [sc.T(duck, rotation=[(0, -0.15), (240, 0.15), (480, -0.15)],
                                                   x=[(0, dx_), (240, dx_ - 50), (480, dx_)], y=[(0, dy_), (240, dy_ + 30), (480, dy_)])],
                            loop=True))

    # ---- events
    met, met_anim = streak_fx(sc, "Meteor", (1000, 300), (120, 1100), 70, 380, "FFFFA040", "CCFF6A20", 16)
    sc.one_shot("meteor", met_anim)
    warp_lines = []
    for i in range(36):
        a = 2 * math.pi * i / 36 + rnd.uniform(-0.05, 0.05)
        r0 = rnd.uniform(60, 200)
        warp_lines.append(S((W / 2, H / 2), f"Warp{i}", [(W / 2 + math.cos(a) * r0, H / 2 + math.sin(a) * r0),
                                                         (W / 2 + math.cos(a) * (r0 + 160), H / 2 + math.sin(a) * (r0 + 160))],
                            L("CCDDEEFF", 4), closed=False))
    warp = d("Node", *warp_lines, x=W / 2, y=H / 2, opacity=0.0, name="Warp")
    flash = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"), F("FFEEF4FF"),
              opacity=0.0, name="Flash")
    warp_anim = sc.A("ev_warp", 120, [
        sc.T(warp, scaleX=[(0, 0.4), (90, 4.0)], scaleY=[(0, 0.4), (90, 4.0)], opacity=[(0, 0.0), (10, 1.0), (80, 1.0), (96, 0.0), (120, 0.0)]),
        sc.T(flash, ease=None, opacity=[(0, 0.0), (84, 0.0), (90, 0.85, "linear"), (120, 0.0)]),
    ])
    sc.one_shot("warp", warp_anim)
    ship = d("Node", x=-500.0, y=700.0, name="Mothership")
    SP = (0.0, 0.0)
    ship.add(*[E(SP, f"SLight{i}", -240 + i * 60, 30, 14, 14, F("FFFF5AA0")) for i in range(9)],
             S(SP, "Hull", [(-360, 20), (-200, -40), (0, -70), (200, -40), (360, 20), (200, 60), (-200, 60)],
               sc.vgrad(-70, 60, [("FF6A7290", 0.0), ("FF262A3A", 1.0)]), L("FF0E1018", 3)),
             S(SP, "Bridge", [(-80, -50), (-40, -100), (40, -100), (80, -50)], sc.vgrad(-50, 20, [("FF9AA8C8", 0.0), ("FF4A5270", 1.0)]),
               L("FF0E1018", 2.5)))
    ship_anim = sc.A("ev_alienShip", 420, [
        sc.T(ship, ease=None, x=[(0, -500.0), (420, W + 500.0)], y=[(0, 700.0), (210, 660.0), (420, 700.0)]),
        *[sc.T(c, ease=None, opacity=[(f, 1.0 if ((f // 15) + i) % 2 else 0.3, "hold") for f in range(0, 421, 15)])
          for i, c in enumerate(ship.children[:9])]])
    sc.one_shot("alienShip", ship_anim)
    pulse = sc.A("ev_nebulaPulse", 150, [sc.T(n, scaleX=[(0, 1.0), (40, 1.25), (150, 1.0)],
                                               scaleY=[(0, float(n.attrs.get("scaleY", 1.0))), (40, float(n.attrs.get("scaleY", 1.0)) * 1.25),
                                                       (150, float(n.attrs.get("scaleY", 1.0)))]) for n in nebulae])
    sc.one_shot("nebulaPulse", pulse)

    rocks = []
    rock_tracks = []
    for i, (rx, ry, rr) in enumerate([(160, 1500, 70), (930, 1640, 50), (420, 1780, 36)]):
        pts = [(rx + rr * (0.8 + 0.2 * math.sin(k * 2.3)) * math.cos(k * math.pi / 4),
                ry + rr * (0.8 + 0.2 * math.cos(k * 1.7)) * math.sin(k * math.pi / 4)) for k in range(8)]
        rk = S(O, f"Rock{i}", pts, sc.rgrad(rr, [("FF8A7E9A", 0.0), ("FF3A3248", 1.0)], cx=-rr * 0.3, cy=-rr * 0.3),
               L("FF14101E", 2.5))
        craters = [E(O, f"RockPit{i}_{k}", rx + (k - 0.5) * rr * 0.6, ry + (0.2 - k * 0.3) * rr, rr * 0.3, rr * 0.24,
                     F("40141020")) for k in range(2)]
        g = d("Node", *craters, rk, x=0.0, y=0.0, name=f"Asteroid{i}")
        rocks.append(g)
        rock_tracks.append(sc.T(g, y=[(0, 0.0), (300, 14.0 * (1 if i % 2 else -1)), (600, 0.0)]))
    sc.ambient("Asteroids", sc.A("amb_rocks", 600, rock_tracks, loop=True))
    galaxy = E(O, "Galaxy", 820, 1420, 220, 70, sc.rgrad(110, [("AAFFF0E0", 0.0), ("40C8A0FF", 0.4), ("00C8A0FF", 1.0)]),
               rotation=-0.4)
    hits = [sc.hit("planet", px, py, 340, 340), sc.hit("ufo", ux, uy - 20, 240, 130), sc.hit("rubberDuck", dx_, dy_ - 20, 160, 120)]
    for h, pid in zip(hits, ["planet", "ufo", "rubberDuck"]):
        sc.prop(pid, h)
    content = [flash, warp, met, *rocks, ship, duck, ufo, planet_g, moonlet, galaxy, *stars, *nebulae, bg]
    return sc.write(content, hits)


if __name__ == "__main__":
    which = sys.argv[1:] or ["livingRoom", "campfire", "beach", "deepSpace"]
    for name in which:
        print("wrote", globals()[name]())
