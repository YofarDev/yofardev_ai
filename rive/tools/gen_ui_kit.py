"""Generates rive/ui_kit/ui_kit.rml: the v4 UI kit (see rive/CONTRACT.md, `assets/rive/ui/ui_kit.riv`).

Five artboards in one file, each with state machine `Main` and view model `<Artboard>VM`:
ComposerOrb, StatusGlow, ToolIcon, Toggle, Mark. No Rive events and no listeners: the app owns
taps. Every accent / glyph / track / knob / tint paint is bound to a view-model colour, so the
app re-themes the kit per scene; defaults are Storybook night.

    uv run rive/tools/gen_ui_kit.py                       # writes rive/ui_kit/
    uv run rive/tools/gen_ui_kit.py --out DIR --backdrop FF16121D   # review copy on a backdrop

State changes are pose states mixed by transitions with cubic (springy) interpolators, one layer
per element, so any state can follow any other without a pop. `reduceMotion` swaps every
transition for a <= 110 ms ease-out and gates every ambient loop off.
"""

from __future__ import annotations

import argparse
import math
import os
import sys
from typing import Iterable

sys.path.insert(0, os.path.dirname(__file__))
from rml import Doc, El, write  # noqa: E402

# client 7: ids never collide with the avatar / scene projects (client 0)
d = Doc(client=7, start=10)

ACCENT = "FFF4B860"
INK = "FF16121D"
PAPER = "FFF3EBDD"
OUTLINE = "FF3A3046"
SURFACE = "FF211B2B"
RM_MS = 110          # reduceMotion: every state change takes at most this long
TAU = math.tau

# ---------------------------------------------------------------- geometry helpers


def P(*verts: El, closed: bool = False, name: str = "Path") -> El:
    xs = [float(v.attrs["x"]) for v in verts]
    ys = [float(v.attrs["y"]) for v in verts]
    area = sum(xs[i] * ys[(i + 1) % len(xs)] - xs[(i + 1) % len(xs)] * ys[i] for i in range(len(xs)))
    return d("PointsPath", *verts, isClosed=closed, isClockwise=area > 0, name=name)


def sv(x: float, y: float, r: float = 0) -> El:
    return d("StraightVertex", x=float(x), y=float(y), radius=float(r) if r else None)


def cv(x: float, y: float, in_rot: float, in_d: float, out_rot: float, out_d: float) -> El:
    return d("CubicDetachedVertex", x=float(x), y=float(y), inRotation=float(in_rot), inDistance=float(in_d),
             outRotation=float(out_rot), outDistance=float(out_d))


def line(*pts: tuple[float, float], closed: bool = False) -> El:
    return P(*[sv(x, y) for x, y in pts], closed=closed)


def arc(cx: float, cy: float, r: float, a0: float, a1: float) -> El:
    """Open circular arc a0 -> a1 (radians, y-down), exact cubic segments."""
    n = max(1, math.ceil(abs(a1 - a0) / (math.pi / 2) - 1e-9))
    step = (a1 - a0) / n
    k = 4 / 3 * math.tan(abs(step) / 4) * r
    sgn = 1 if step > 0 else -1
    verts = []
    for i in range(n + 1):
        a = a0 + i * step
        tx, ty = -math.sin(a) * sgn, math.cos(a) * sgn
        rot = math.atan2(ty, tx)
        verts.append(cv(cx + r * math.cos(a), cy + r * math.sin(a), rot + math.pi, 0 if i == 0 else k,
                        rot, 0 if i == n else k))
    return P(*verts)


def star4(cx: float, cy: float, rx: float, ry: float | None = None, pinch: float = 0.62) -> El:
    """Four-point sparkle with concave sides (handles point at the centre)."""
    ry = rx if ry is None else ry
    tips = [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]
    verts = []
    for x, y in tips:
        to_c = math.atan2(cy - y, cx - x)
        dist = math.hypot(cx - x, cy - y) * pinch
        verts.append(cv(x, y, to_c, dist, to_c, dist))
    return P(*verts, closed=True)


def ell(w: float, h: float | None = None) -> El:
    return d("Ellipse", width=float(w), height=float(h if h is not None else w), name="Path")


def rect(w: float, h: float, r: float = 0, ox: float | None = None, oy: float | None = None) -> El:
    return d("Rectangle", width=float(w), height=float(h), cornerRadiusTL=float(r) if r else None,
             originX=ox, originY=oy, name="Path")


def node(name: str, *kids: El | None, x: float = 0, y: float = 0, **kw: object) -> El:
    return d("Node", *[k for k in kids if k is not None], x=float(x), y=float(y), name=name, **kw)


def shape(name: str, path: El | list[El], *paints: El | None, x: float = 0, y: float = 0, **kw: object) -> El:
    paths = path if isinstance(path, list) else [path]
    return d("Shape", *paths, *[p for p in paints if p is not None], x=float(x), y=float(y), name=name, **kw)


def solid(c: str) -> El:
    return d("SolidColor", colorValue=c)


def fill(c: str) -> El:
    return d("Fill", solid(c), name="Fill")


def grad_fill(kind: str, coords: tuple[float, float, float, float], stops: list[tuple[str, float]]) -> El:
    g = d(kind, *[d("GradientStop", colorValue=c, position=float(p)) for c, p in stops],
          startX=float(coords[0]), startY=float(coords[1]), endX=float(coords[2]), endY=float(coords[3]))
    return d("Fill", g, name="Fill")


# ---------------------------------------------------------------- board (artboard + VM + SM)


class Board:
    def __init__(self, name: str, w: int, h: int, x: float, y: float) -> None:
        self.name, self.w, self.h, self.x, self.y = name, w, h, x, y
        self.vm = d("ViewModel", name=f"{name}VM")
        self.props: list[El] = []
        self.inst_vals: list[El] = []
        self.roots: list[El] = []
        self.anims: list[El] = []
        self.layers: list[El] = []
        self.ease = d("CubicEaseInterpolator", x1=0.45, y1=0.0, x2=0.55, y2=1.0)
        self.out = d("CubicEaseInterpolator", x1=0.2, y1=0.0, x2=0.0, y2=1.0)       # emphasized decel
        self.inn = d("CubicEaseInterpolator", x1=0.55, y1=0.0, x2=0.9, y2=0.45)    # quick exit
        self.back = d("CubicEaseInterpolator", x1=0.3, y1=1.55, x2=0.55, y2=1.0)   # springy overshoot
        self.late_back = d("CubicEaseInterpolator", x1=0.55, y1=0.0, x2=0.4, y2=1.45)  # waits, then overshoots
        self.interps = [self.ease, self.out, self.inn, self.back, self.late_back]
        self.rm: El | None = None

    # ---- view model
    def _prop(self, el: El, inst: El, kind: str) -> El:
        el.kind = kind  # type: ignore[attr-defined]
        self.props.append(el)
        self.inst_vals.append(inst)
        return el

    def enum(self, name: str, values: list[str]) -> El:
        vals = [d("DataEnumValue", key=v, value=v) for v in values]
        en = d("DataEnumCustom", *vals, name=self.name + name[0].upper() + name[1:])
        self.roots.append(en)
        p = d("ViewModelPropertyEnumCustom", enumId=en.ref(), name=name)
        p.vals = dict(zip(values, vals))  # type: ignore[attr-defined]
        return self._prop(p, d("ViewModelInstanceEnum", propertyValue=vals[0].ref(), viewModelPropertyId=p.ref()), "enum")

    def number(self, name: str, default: float = 0) -> El:
        p = d("ViewModelPropertyNumber", name=name)
        return self._prop(p, d("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()), "number")

    def boolean(self, name: str, default: bool = False) -> El:
        p = d("ViewModelPropertyBoolean", name=name)
        return self._prop(p, d("ViewModelInstanceBoolean", propertyValue=default, viewModelPropertyId=p.ref()), "bool")

    def color(self, name: str, default: str) -> El:
        p = d("ViewModelPropertyColor", name=name)
        p.default = default  # type: ignore[attr-defined]
        return self._prop(p, d("ViewModelInstanceColor", propertyValue=default, viewModelPropertyId=p.ref()), "color")

    def trigger(self, name: str) -> El:
        p = d("ViewModelPropertyTrigger", name=name)
        return self._prop(p, d("ViewModelInstanceTrigger", viewModelPropertyId=p.ref()), "trigger")

    def path(self, p: El) -> str:
        return f"{self.vm.ref()}-{p.ref()}"

    # ---- bound paints
    def solid_b(self, p: El) -> El:
        return d("SolidColor", d("DataBindContext", sourcePathIds=self.path(p), propertyKey=37),
                 colorValue=p.default)  # type: ignore[attr-defined]

    def fill_b(self, p: El, feather: float | None = None) -> El:
        if feather:
            return d("Fill", self.solid_b(p), d("Feather", strength=float(feather), name="Feather"),
                     fillRule="clockwise", name="Fill")
        return d("Fill", self.solid_b(p), name="Fill")

    def stroke_b(self, p: El, w: float, trim: El | None = None) -> El:
        return d("Stroke", self.solid_b(p), trim, thickness=float(w), cap="round", join="round", name="Line")

    # ---- conditions
    def c_enum(self, p: El, value: str, op: str | None = None) -> El:
        return d("TransitionViewModelCondition",
                 d("TransitionPropertyViewModelComparator",
                   d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=self.path(p), propertyKey=637))),
                 d("TransitionValueEnumComparator", value=p.vals[value].ref()), opValue=op)  # type: ignore[attr-defined]

    def c_bool(self, p: El, value: bool) -> El:
        return d("TransitionViewModelCondition",
                 d("TransitionPropertyViewModelComparator",
                   d("BindablePropertyBoolean", d("DataBindContext", sourcePathIds=self.path(p), propertyKey=634))),
                 d("TransitionValueBooleanComparator", value=value))

    def c_trigger(self, p: El) -> El:
        return d("TransitionViewModelCondition",
                 d("TransitionPropertyViewModelComparator",
                   d("BindablePropertyTrigger", d("DataBindContext", sourcePathIds=self.path(p), propertyKey=686))),
                 d("TransitionValueTriggerComparator"))

    def cond(self, c: tuple[El, object], negate: bool = False) -> El:
        p, v = c
        if p.kind == "enum":  # type: ignore[attr-defined]
            return self.c_enum(p, str(v), "notEqual" if negate else None)
        return self.c_bool(p, (not v) if negate else bool(v))

    # ---- animation
    def anim(self, name: str, frames: int, tracks: list[El], loop: bool = False) -> El:
        a = d("LinearAnimation", *tracks, duration=frames, fps=60, loopValue="loop" if loop else None, name=name)
        self.anims.append(a)
        return a

    def T(self, target: El, ease: El | None = None, **props: list) -> El:
        """Keyed object. Keys: (frame, value) or (frame, value, interp El | 'hold' | 'linear')."""
        kps = []
        for prop, keys in props.items():
            kfs = []
            for k in keys:
                f, v = k[0], k[1]
                interp = k[2] if len(k) > 2 else (ease if ease is not None else self.ease)
                tag = "KeyFrameColor" if isinstance(v, str) else "KeyFrameDouble"
                if isinstance(interp, El):
                    kfs.append(d(tag, frame=f, value=v if isinstance(v, str) else float(v), interpolationType="cubic",
                                 interpolatorId=interp.ref()))
                else:
                    kfs.append(d(tag, frame=f, value=v if isinstance(v, str) else float(v), interpolationType=interp))
            kps.append(d("KeyedProperty", *kfs, property=prop))
        return d("KeyedObject", *kps, objectId=target.ref())

    def pose(self, name: str, values: dict[El, dict[str, float]]) -> El:
        tracks = [self.T(t, **{k: [(0, v, "hold")] for k, v in props.items()}) for t, props in values.items()]
        return self.anim(name, 1, tracks)

    # ---- state machine
    def transition(self, to: El, conds: Iterable[El] = (), ms: int = 0, interp: El | None = None, **kw: object) -> El:
        return d("StateTransition", *conds, stateToId=to.ref(), duration=int(ms),
                 interpolationType="cubic" if interp is not None and ms else None,
                 interpolatorId=interp.ref() if interp is not None and ms else None, **kw)

    def layer(self, name: str, states: list[El], entry: list[El]) -> El:
        lay = d("StateMachineLayer", d("AnyState", x=-120.0, y=-120.0), d("ExitState", x=600.0, y=-120.0),
                d("EntryState", *entry, x=-120.0, y=0.0), *states, name=name)
        self.layers.append(lay)
        return lay

    def pose_layer(self, name: str, prop: El, poses: dict[str, El],
                   timing: "callable[[El, El], tuple[int, El]]") -> El:
        """One state per distinct pose animation; prop's enum value picks the pose.

        timing(from_anim, to_anim) -> (ms, interpolator) for normal motion; with
        reduceMotion every change is RM_MS with the decelerating ease.
        """
        uniq: list[El] = []
        for a in poses.values():
            if a not in uniq:
                uniq.append(a)
        states = {a: d("AnimationState", animationId=a.ref(), x=float(200 * i), y=200.0) for i, a in enumerate(uniq)}
        for a_from, st in states.items():
            for value, a_to in poses.items():
                if a_to is a_from:
                    continue
                ms, ip = timing(a_from, a_to)
                if self.rm is not None:
                    st.add(self.transition(states[a_to], [self.c_enum(prop, value), self.c_bool(self.rm, False)], ms, ip))
                    st.add(self.transition(states[a_to], [self.c_enum(prop, value), self.c_bool(self.rm, True)],
                                           min(ms, RM_MS), self.out))
                else:
                    st.add(self.transition(states[a_to], [self.c_enum(prop, value)], ms, ip))
        entry = [self.transition(states[a], [self.c_enum(prop, v)]) for v, a in poses.items()]
        return self.layer(name, list(states.values()), entry)

    def bool_pose_layer(self, name: str, prop: El, off: El, on: El, ms: int, ip: El) -> El:
        s_off = d("AnimationState", animationId=off.ref(), x=0.0, y=200.0)
        s_on = d("AnimationState", animationId=on.ref(), x=200.0, y=200.0)
        s_off.add(self.transition(s_on, [self.c_bool(prop, True)], ms, ip))
        s_on.add(self.transition(s_off, [self.c_bool(prop, False)], ms, ip))
        return self.layer(name, [s_off, s_on], [self.transition(s_on, [self.c_bool(prop, True)]), self.transition(s_off)])

    def gate_layer(self, name: str, entries: list[tuple[El, list[tuple[El, object]]]],
                   rest: dict[El, dict[str, float]], in_ms: int = 240, out_ms: int = 240) -> El:
        """Rest pose <-> animations that run while ALL their conditions hold."""
        rest_a = self.pose(name + "_rest", rest)
        s_rest = d("AnimationState", animationId=rest_a.ref(), x=0.0, y=200.0)
        states = [s_rest]
        for i, (a, conds) in enumerate(entries):
            st = d("AnimationState", animationId=a.ref(), x=float(200 * (i + 1)), y=320.0)
            s_rest.add(self.transition(st, [self.cond(c) for c in conds], in_ms, self.ease))
            for c in conds:
                st.add(self.transition(s_rest, [self.cond(c, negate=True)], out_ms, self.ease))
            states.append(st)
        return self.layer(name, states, [self.transition(s_rest)])

    def artboard(self, content: list[El]) -> list[El]:
        inst = d("ViewModelInstance", *self.inst_vals, exports=True, name="Default")
        self.vm.add(*self.props, inst)
        self.vm.attrs["defaultInstanceId"] = inst.ref()
        sm = d("StateMachine", *self.layers, name="Main")
        style = d("LayoutComponentStyle", name="Artboard Style")
        ab = d("Artboard", style, sm, *self.interps, *content, *self.anims,
               x=float(self.x), y=float(self.y), width=float(self.w), height=float(self.h), name=self.name,
               defaultStateMachineId=sm.ref(), viewModelId=self.vm.ref(), viewModelInstanceId=inst.ref(),
               styleId=style.ref(), clip=True)
        return [ab, *self.roots, self.vm]


def backdrop(w: float, h: float, color: str | None) -> El | None:
    if not color:
        return None
    return shape("ReviewBackdrop", rect(w, h, ox=0.0, oy=0.0), fill(color))


# ---------------------------------------------------------------- ComposerOrb

ORB_STATES = ["idle", "typing", "listening", "thinking", "speaking", "error"]


def mic_glyph(b: Board, name: str, color: El) -> El:
    """Microphone: capsule + cradle + stem + foot, optically centred on (0, 0)."""
    return node(name,
                shape("Capsule", rect(17, 27, 8.5), b.fill_b(color), y=-11.5),
                shape("Cradle", arc(0, -6.5, 13.5, 0.0, math.pi), b.stroke_b(color, 5.5)),
                shape("Stem", line((0, 7.5), (0, 15.5)), b.stroke_b(color, 5.5)),
                shape("Foot", line((-7.5, 16), (7.5, 16)), b.stroke_b(color, 5.5)),
                y=1.5)


def composer_orb(bd: str | None) -> list[El]:
    b = Board("ComposerOrb", 96, 96, 0, 0)
    state = b.enum("state", ORB_STATES)
    level = b.number("level", 0)
    accent = b.color("accent", ACCENT)
    on_accent = b.color("onAccent", INK)
    b.rm = b.boolean("reduceMotion", False)

    # ---- art (first-declared paints in front)
    mic = mic_glyph(b, "Mic", on_accent)
    arrow = node("Arrow",
                 shape("Shaft", line((0, 15), (0, -14)), b.stroke_b(on_accent, 6.5)),
                 shape("Head", line((-12.5, -2.5), (0, -15), (12.5, -2.5)), b.stroke_b(on_accent, 6.5)))
    stop = node("Stop", shape("Square", rect(25, 25, 6.5), b.fill_b(on_accent)))
    dots = []
    for i in range(3):
        a = -math.pi / 2 + i * TAU / 3
        dot = shape(f"Dot{i}", ell(10.5), b.fill_b(on_accent), x=15 * math.cos(a), y=15 * math.sin(a))
        dots.append(dot)
    spin = node("DotsSpin", *dots)
    dots_g = node("Dots", spin)

    # listening: the disc opens into a ring; level drives the pulse
    l_mic = mic_glyph(b, "ListenMic", accent)
    ring = shape("Ring", ell(69), b.stroke_b(accent, 6))
    echo = shape("Echo", ell(72), b.stroke_b(accent, 3), opacity=0.0)
    tint = shape("Tint", ell(66), b.fill_b(accent), opacity=0.07)
    pulse = node("Pulse", echo, ring, tint)
    listen = node("Listen", l_mic, pulse)

    disc = node("Disc",
                shape("Rim", arc(0, 0, 35.5, math.pi * 1.08, math.pi * 1.92),
                      d("Stroke", solid("40FFFFFF"), thickness=1.6, cap="round", name="Line")),
                shape("Gloss", ell(56, 22), grad_fill("LinearGradient", (0, -12, 0, 12), [("24FFFFFF", 0), ("00FFFFFF", 1)]),
                      y=-22),
                shape("Shade", ell(76), grad_fill("LinearGradient", (0, -8, 0, 38), [("0016121D", 0), ("3316121D", 1)])),
                shape("Face", ell(76), b.fill_b(accent)))
    shadow = shape("Shadow", ell(70, 18), grad_fill("RadialGradient", (0, 0, 35, 0), [("4C0A070E", 0), ("000A070E", 1)]),
                   y=36, scaleY=1.0)
    breath = node("Breath", mic, arrow, stop, dots_g, listen, disc, shadow)
    shake = node("Shake", breath, x=48, y=48)

    # ---- poses (one layer per element)
    def show_hide(el: El, shown: dict[str, float], hidden: dict[str, float], when: set[str], name: str,
                  show: tuple[int, El], hide: tuple[int, El]) -> None:
        on = b.pose(name + "_on", {el: shown})
        off = b.pose(name + "_off", {el: hidden})
        poses = {s: (on if s in when else off) for s in ORB_STATES}
        b.pose_layer(name, state, poses, lambda f, t: show if t is on else hide)

    show_hide(mic, {"opacity": 1, "scaleX": 1, "scaleY": 1, "y": 1.5, "rotation": 0},
              {"opacity": 0, "scaleX": 0.35, "scaleY": 0.35, "y": 6, "rotation": 0}, {"idle", "error"}, "Mic",
              (300, b.late_back), (100, b.inn))
    show_hide(arrow, {"opacity": 1, "scaleX": 1, "scaleY": 1, "y": 0},
              {"opacity": 0, "scaleX": 0.4, "scaleY": 0.4, "y": 12}, {"typing"}, "Arrow",
              (320, b.late_back), (100, b.inn))
    show_hide(stop, {"opacity": 1, "scaleX": 1, "scaleY": 1, "rotation": 0},
              {"opacity": 0, "scaleX": 0.3, "scaleY": 0.3, "rotation": -0.8}, {"speaking"}, "Stop",
              (300, b.late_back), (100, b.inn))
    show_hide(dots_g, {"opacity": 1, "scaleX": 1, "scaleY": 1},
              {"opacity": 0, "scaleX": 0.45, "scaleY": 0.45}, {"thinking"}, "Dots",
              (300, b.late_back), (100, b.inn))
    show_hide(listen, {"opacity": 1, "scaleX": 1, "scaleY": 1},
              {"opacity": 0, "scaleX": 1.18, "scaleY": 1.18}, {"listening"}, "Listen",
              (320, b.back), (160, b.inn))
    # disc: full face, hidden while listening (opens into the ring), dimmed after an error
    face = {"opacity": 1, "scaleX": 1, "scaleY": 1}
    d_full = b.pose("Disc_full", {disc: face, shadow: {"opacity": 1}})
    d_open = b.pose("Disc_open", {disc: {"opacity": 0, "scaleX": 0.82, "scaleY": 0.82}, shadow: {"opacity": 0}})
    d_dim = b.pose("Disc_dim", {disc: {"opacity": 0.78, "scaleX": 0.95, "scaleY": 0.95}, shadow: {"opacity": 0.6}})
    b.pose_layer("Disc", state, {"idle": d_full, "typing": d_full, "listening": d_open, "thinking": d_full,
                                 "speaking": d_full, "error": d_dim},
                 lambda f, t: (260, b.back) if t is d_full else (220, b.out))

    # level -> pulse (blend 0..100 through a range mapper); still under reduceMotion
    to100 = d("DataConverterRangeMapper", minInput=0.0, maxInput=1.0, minOutput=0.0, maxOutput=100.0,
              clampLower=True, clampUpper=True, name="LevelTo100")
    smooth = d("DataConverterInterpolator", interpolationType="linear", duration=0.14,
               name="LevelSmooth")
    group = d("DataConverterGroup", d("DataConverterGroupItem", converterId=to100.ref()),
              d("DataConverterGroupItem", converterId=smooth.ref()), name="LevelPulse")
    b.roots += [to100, smooth, group]
    lv_keys = {pulse: ("scaleX", "scaleY"), echo: ("opacity", "scaleX", "scaleY"), tint: ("opacity",),
               ring: ("scaleX", "scaleY")}
    quiet = {pulse: {"scaleX": 1, "scaleY": 1}, echo: {"opacity": 0, "scaleX": 1, "scaleY": 1},
             tint: {"opacity": 0.07}, ring: {"scaleX": 1, "scaleY": 1}}
    loud = {pulse: {"scaleX": 1.05, "scaleY": 1.05}, echo: {"opacity": 0.6, "scaleX": 1.15, "scaleY": 1.15},
            tint: {"opacity": 0.22}, ring: {"scaleX": 1.0, "scaleY": 1.0}}
    assert all(set(quiet[k]) == set(v) and set(loud[k]) == set(v) for k, v in lv_keys.items())
    lv0 = b.pose("Level_0", quiet)
    lv1 = b.pose("Level_1", loud)
    still = b.pose("Level_still", quiet)
    s_still = d("AnimationState", animationId=still.ref(), x=0.0, y=200.0)
    blend = d("BlendState1DViewModel",
              d("BindablePropertyNumber", d("DataBindContext", sourcePathIds=b.path(level), propertyKey=636,
                                            converterId=group.ref())),
              d("BlendAnimation1D", animationId=lv0.ref(), value=0.0),
              d("BlendAnimation1D", animationId=lv1.ref(), value=100.0), x=200.0, y=200.0)
    s_still.add(b.transition(blend, [b.c_enum(state, "listening"), b.c_bool(b.rm, False)], 200, b.ease))
    blend.add(d("BlendStateTransition", b.c_enum(state, "listening", "notEqual"), stateToId=s_still.ref(), duration=200))
    blend.add(d("BlendStateTransition", b.c_bool(b.rm, True), stateToId=s_still.ref(), duration=RM_MS))
    b.layer("Level", [s_still, blend], [b.transition(s_still)])

    # thinking: slow breathing + orbiting dots (ambient: gated off by reduceMotion)
    breathe = b.anim("Think_breathe", 150, [
        b.T(breath, scaleX=[(0, 1), (75, 1.045), (150, 1)], scaleY=[(0, 1), (75, 1.045), (150, 1)]),
        b.T(spin, rotation=[(0, 0, "linear"), (150, TAU, "linear")]),
        *[b.T(dt, scaleX=[(0, 1), (10 + 20 * i, 1.0), (30 + 20 * i, 1.22), (50 + 20 * i, 1), (150, 1)],
              scaleY=[(0, 1), (10 + 20 * i, 1.0), (30 + 20 * i, 1.22), (50 + 20 * i, 1), (150, 1)])
          for i, dt in enumerate(dots)]], loop=True)
    b.gate_layer("Think", [(breathe, [(state, "thinking"), (b.rm, False)])],
                 {breath: {"scaleX": 1, "scaleY": 1}, spin: {"rotation": 0},
                  **{dt: {"scaleX": 1, "scaleY": 1} for dt in dots}}, in_ms=300, out_ms=200)

    # error: one horizontal shake (400 ms), then still. reduceMotion: no shake.
    shake_a = b.anim("Error_shake", 24, [b.T(shake, x=[(0, 48), (4, 41), (9, 54.5), (14, 43.5), (18, 51), (21, 47), (24, 48)])])
    b.gate_layer("Shake", [(shake_a, [(state, "error"), (b.rm, False)])], {shake: {"x": 48}}, in_ms=0, out_ms=120)

    content = [shake]
    if bd:
        content.append(backdrop(96, 96, bd))
    return b.artboard(content)


# ---------------------------------------------------------------- StatusGlow

PHASES = ["idle", "waiting", "generating", "speaking", "error"]


def status_glow(bd: str | None) -> list[El]:
    b = Board("StatusGlow", 480, 200, 200, 0)
    phase = b.enum("phase", PHASES)
    accent = b.color("accent", ACCENT)
    b.rm = b.boolean("reduceMotion", False)

    shimmer = shape("Shimmer", ell(90, 26), b.fill_b(accent, feather=18), opacity=0.0)
    shimmer_n = node("ShimmerTravel", shimmer, x=-150)
    core = shape("Core", ell(230, 40), b.fill_b(accent, feather=26), opacity=0.85)
    breath = node("Breath", core)
    lobe_l = shape("LobeL", ell(150, 56), b.fill_b(accent, feather=34), opacity=0.55)
    lobe_r = shape("LobeR", ell(150, 54), b.fill_b(accent, feather=34), opacity=0.55)
    drift_l = node("DriftL", lobe_l, x=-104)
    drift_r = node("DriftR", lobe_r, x=104)
    haze = shape("Haze", ell(350, 70), b.fill_b(accent, feather=44), opacity=0.45)
    level = node("Level", shimmer_n, breath, drift_l, drift_r, haze)
    glow = node("Glow", level, x=240, y=104)

    def lv(op: float, sx: float, sy: float) -> El:
        return b.pose(f"Phase_{op}_{sx}_{sy}", {level: {"opacity": op, "scaleX": sx, "scaleY": sy}})

    poses = {"idle": lv(0.34, 0.86, 0.8), "waiting": lv(0.5, 0.94, 0.9), "generating": lv(0.62, 1.0, 1.0),
             "speaking": lv(0.92, 1.06, 1.12), "error": lv(0.26, 0.8, 0.74)}
    b.pose_layer("Phase", phase, poses, lambda f, t: (420, b.ease))

    # ambient per phase (inner nodes only), gated by reduceMotion
    drift = b.anim("Waiting_drift", 240, [
        b.T(drift_l, x=[(0, -104), (120, -70), (240, -104)], y=[(0, 0), (60, -4), (180, 4), (240, 0)]),
        b.T(drift_r, x=[(0, 104), (120, 70), (240, 104)], y=[(0, 0), (60, 4), (180, -4), (240, 0)]),
        b.T(breath, scaleX=[(0, 1), (120, 0.9), (240, 1)], scaleY=[(0, 1), (240, 1)], opacity=[(0, 1), (240, 1)]),
    ], loop=True)
    breathe = b.anim("Generating_breathe", 192, [
        b.T(breath, scaleX=[(0, 1), (96, 1.16), (192, 1)], scaleY=[(0, 1), (96, 1.3), (192, 1)],
            opacity=[(0, 1), (96, 0.72), (192, 1)]),
        b.T(drift_l, x=[(0, -104), (96, -112), (192, -104)], y=[(0, 0), (192, 0)]),
        b.T(drift_r, x=[(0, 104), (96, 112), (192, 104)], y=[(0, 0), (192, 0)]),
    ], loop=True)
    shim = b.anim("Speaking_shimmer", 96, [
        b.T(shimmer_n, x=[(0, -150, "linear"), (96, 150, "linear")]),
        b.T(shimmer, opacity=[(0, 0), (30, 0.9), (66, 0.9), (96, 0)]),
        b.T(breath, scaleX=[(0, 1), (24, 1.06), (48, 0.98), (72, 1.05), (96, 1)],
            scaleY=[(0, 1), (24, 1.12), (48, 0.96), (72, 1.1), (96, 1)], opacity=[(0, 1), (48, 0.88), (96, 1)]),
    ], loop=True)
    pulse = b.anim("Error_pulse", 28, [
        b.T(breath, scaleX=[(0, 1), (10, 1.12, b.out), (28, 0.96)], scaleY=[(0, 1), (10, 1.2, b.out), (28, 0.94)],
            opacity=[(0, 1), (10, 1.0), (28, 0.55)]),
    ])
    rest = {drift_l: {"x": -104, "y": 0}, drift_r: {"x": 104, "y": 0}, breath: {"scaleX": 1, "scaleY": 1, "opacity": 1},
            shimmer_n: {"x": -150}, shimmer: {"opacity": 0}}
    b.gate_layer("Ambient", [(drift, [(phase, "waiting"), (b.rm, False)]),
                             (breathe, [(phase, "generating"), (b.rm, False)]),
                             (shim, [(phase, "speaking"), (b.rm, False)]),
                             (pulse, [(phase, "error"), (b.rm, False)])], rest, in_ms=360, out_ms=360)

    content = [glow]
    if bd:
        content.append(backdrop(480, 200, bd))
    return b.artboard(content)


# ---------------------------------------------------------------- ToolIcon

KINDS = ["search", "weather", "news", "memory", "generic"]


def tool_icon(bd: str | None) -> list[El]:
    b = Board("ToolIcon", 48, 48, 760, 0)
    kind = b.enum("kind", KINDS)
    running = b.boolean("running", False)
    tint = b.color("tint", PAPER)
    S = 3.4  # glyph stroke at 48 px

    # search: magnifier (lens centre is the sweep pivot)
    glint = shape("Glint", arc(0, 0, 4.6, math.pi * 1.1, math.pi * 1.45), b.stroke_b(tint, 2.0), opacity=0.7)
    lens = shape("Lens", ell(18.5), b.stroke_b(tint, S))
    handle = shape("Handle", line((6.9, 6.9), (13.2, 13.2)), b.stroke_b(tint, S + 1.2))
    sweep = node("Sweep", glint, lens, handle, x=21.5, y=21.5)
    g_search = node("Search", sweep)

    # weather: sun behind a cloud
    rays = node("Rays", *[shape(f"Ray{i}", line((8.6 * math.cos(a), 8.6 * math.sin(a)), (11.6 * math.cos(a), 11.6 * math.sin(a))),
                                b.stroke_b(tint, 2.5))
                          for i, a in enumerate(i * TAU / 8 for i in range(8))])
    sun = node("Sun", rays, shape("Disc", ell(10.5), b.stroke_b(tint, 2.8)), x=30.5, y=16.5)
    cloud = node("Cloud",
                 shape("Puff1", ell(13), b.fill_b(tint), x=-7, y=0.5),
                 shape("Puff2", ell(16.5), b.fill_b(tint), x=0, y=-3),
                 shape("Puff3", ell(11.5), b.fill_b(tint), x=7, y=1),
                 shape("Base", rect(25, 11, 5.5), b.fill_b(tint), x=0, y=3),
                 x=21.5, y=30.5)
    cloud_drift = node("CloudDrift", cloud)
    g_weather = node("Weather", cloud_drift, sun)

    # news: newspaper page
    page = shape("Page", rect(26, 30, 4.5), b.stroke_b(tint, 3.0), x=24, y=24)
    block = shape("Photo", rect(8, 7, 1.6), b.fill_b(tint), x=19.5, y=16.5)
    lines = []
    for i, (y, w) in enumerate([(14.3, 6.5), (18.7, 6.5), (25.2, 17), (30.6, 17), (36.0, 11)]):
        x0 = 26.2 if i < 2 else 15.5
        ln = shape(f"Text{i}", rect(w, 2.6, 1.3, ox=0.0), b.fill_b(tint), x=x0, y=y)
        lines.append(ln)
    g_news = node("News", *lines, block, page)

    # memory: bookmark ribbon with a star
    ribbon = shape("Ribbon", P(sv(15.5, 9.5, 3), sv(32.5, 9.5, 3), sv(32.5, 38.5, 1.2), sv(24, 31.5, 1.2),
                               sv(15.5, 38.5, 1.2), closed=True), b.stroke_b(tint, 3.0))
    m_star = shape("Star", star4(0, 0, 6.2), b.fill_b(tint), x=24, y=19.5)
    bob = node("Bob", m_star, ribbon)
    g_memory = node("Memory", bob)

    # generic: sparkles
    big = shape("Big", star4(0, 0, 11.5, 13.5), b.fill_b(tint), x=20.5, y=26)
    small = shape("Small", star4(0, 0, 5.2, 6.2), b.fill_b(tint), x=34.5, y=12.5)
    dot = shape("Dot", ell(4.4), b.fill_b(tint), x=36, y=33)
    g_generic = node("Generic", dot, small, big)

    glyphs = {"search": g_search, "weather": g_weather, "news": g_news, "memory": g_memory, "generic": g_generic}
    for g in glyphs.values():
        g.attrs.update(opacity=0.0)
    # wrap each glyph so the pose scale pivots on the icon centre
    wraps = {}
    for k, g in glyphs.items():
        g.attrs.update(x=-24.0, y=-24.0)
        wraps[k] = node("Kind_" + k, g, x=24, y=24)

    poses = {}
    for k in KINDS:
        poses[k] = b.pose("Kind_" + k, {glyphs[j]: ({"opacity": 1} if j == k else {"opacity": 0}) for j in KINDS} |
                          {wraps[j]: ({"scaleX": 1, "scaleY": 1} if j == k else {"scaleX": 0.6, "scaleY": 0.6}) for j in KINDS})
    b.pose_layer("Kind", kind, poses, lambda f, t: (240, b.back))

    # running loops, one per glyph
    run_search = b.anim("Run_search", 84, [
        b.T(sweep, x=[(0, 21.5), (21, 24.5), (42, 22.5), (63, 19.5), (84, 21.5)],
            y=[(0, 21.5), (21, 20), (42, 23.5), (63, 21), (84, 21.5)],
            rotation=[(0, 0), (21, 0.14), (42, 0), (63, -0.14), (84, 0)]),
        b.T(glint, opacity=[(0, 0.7), (42, 1), (84, 0.7)])], loop=True)
    run_weather = b.anim("Run_weather", 120, [
        b.T(rays, rotation=[(0, 0, "linear"), (120, TAU / 8, "linear")]),
        b.T(sun, scaleX=[(0, 1), (60, 1.08), (120, 1)], scaleY=[(0, 1), (60, 1.08), (120, 1)]),
        b.T(cloud_drift, x=[(0, 0), (60, -1.8), (120, 0)])], loop=True)
    run_news = b.anim("Run_news", 108, [
        *[b.T(ln, scaleX=[(0, 1), (8 * i, 1), (8 * i + 14, 0.25), (8 * i + 32, 1), (108, 1)]) for i, ln in enumerate(lines)],
        b.T(block, opacity=[(0, 1), (54, 0.55), (108, 1)])], loop=True)
    run_memory = b.anim("Run_memory", 96, [
        b.T(m_star, scaleX=[(0, 1), (24, 1.3), (48, 0.7), (72, 1.15), (96, 1)],
            scaleY=[(0, 1), (24, 1.3), (48, 0.7), (72, 1.15), (96, 1)],
            rotation=[(0, 0), (48, math.pi / 4), (96, math.pi / 2)]),
        b.T(bob, y=[(0, 0), (48, -1.6), (96, 0)])], loop=True)
    run_generic = b.anim("Run_generic", 96, [
        b.T(big, scaleX=[(0, 1), (32, 1.14), (64, 0.9), (96, 1)], scaleY=[(0, 1), (32, 1.14), (64, 0.9), (96, 1)],
            rotation=[(0, 0), (48, 0.12), (96, 0)]),
        b.T(small, scaleX=[(0, 1), (24, 0.45), (56, 1.25), (96, 1)], scaleY=[(0, 1), (24, 0.45), (56, 1.25), (96, 1)]),
        b.T(dot, opacity=[(0, 1), (40, 0.2), (80, 1), (96, 1)])], loop=True)
    # loops must start where the rest pose is, or the gate blend pops
    rest = {sweep: {"x": 21.5, "y": 21.5, "rotation": 0}, glint: {"opacity": 0.7}, rays: {"rotation": 0},
            sun: {"scaleX": 1, "scaleY": 1}, cloud_drift: {"x": 0}, **{ln: {"scaleX": 1} for ln in lines},
            block: {"opacity": 1}, m_star: {"scaleX": 1, "scaleY": 1, "rotation": 0}, bob: {"y": 0},
            big: {"scaleX": 1, "scaleY": 1, "rotation": 0}, small: {"scaleX": 1, "scaleY": 1}, dot: {"opacity": 1}}
    runs = {"search": run_search, "weather": run_weather, "news": run_news, "memory": run_memory, "generic": run_generic}
    b.gate_layer("Running", [(runs[k], [(kind, k), (running, True)]) for k in KINDS], rest, in_ms=200, out_ms=260)

    content = [*wraps.values()]
    if bd:
        content.append(backdrop(48, 48, bd))
    return b.artboard(content)


# ---------------------------------------------------------------- Toggle

def toggle(bd: str | None) -> list[El]:
    b = Board("Toggle", 104, 64, 860, 0)
    value = b.boolean("value", False)
    accent = b.color("accent", ACCENT)
    track_c = b.color("track", OUTLINE)
    knob_c = b.color("knob", PAPER)

    knob_shape = node("KnobArt",
                      shape("Sheen", ell(30, 16), grad_fill("LinearGradient", (0, -8, 0, 8), [("55FFFFFF", 0), ("00FFFFFF", 1)]),
                            y=-9),
                      shape("Body", ell(40), b.fill_b(knob_c)),
                      shape("Drop", ell(44), grad_fill("RadialGradient", (0, 0, 22, 0),
                                                       [("6608050C", 0.72), ("0008050C", 1)]), y=2.5))
    squash = node("Squash", knob_shape)
    knob = node("Knob", squash, x=32, y=32)
    inset = shape("Inset", rect(92, 52, 26), grad_fill("LinearGradient", (0, -26, 0, 4), [("4008050C", 0), ("0008050C", 1)]),
                  x=52, y=32)
    on = shape("TrackOn", rect(92, 52, 26), b.fill_b(accent), x=52, y=32, opacity=0.0)
    off = shape("TrackOff", rect(92, 52, 26), b.fill_b(track_c), x=52, y=32)

    p_off = b.pose("Value_off", {knob: {"x": 32}, on: {"opacity": 0}})
    p_on = b.pose("Value_on", {knob: {"x": 72}, on: {"opacity": 1}})
    b.bool_pose_layer("Value", value, p_off, p_on, 300, b.back)

    # squash while travelling (keyed on the inner node; starts and ends at rest)
    sq = b.anim("Squash", 18, [b.T(squash, scaleX=[(0, 1), (5, 1.2), (12, 0.94), (18, 1)],
                                   scaleY=[(0, 1), (5, 0.84), (12, 1.05), (18, 1)])])
    sq2 = b.anim("Squash_back", 18, [b.T(squash, scaleX=[(0, 1), (5, 1.2), (12, 0.94), (18, 1)],
                                         scaleY=[(0, 1), (5, 0.84), (12, 1.05), (18, 1)])])
    s_a = d("AnimationState", animationId=sq.ref(), x=0.0, y=200.0)
    s_b = d("AnimationState", animationId=sq2.ref(), x=200.0, y=200.0)
    s_a.add(b.transition(s_b, [b.c_bool(value, False)], 40, b.ease))
    s_b.add(b.transition(s_a, [b.c_bool(value, True)], 40, b.ease))
    rest = b.pose("Squash_rest", {squash: {"scaleX": 1, "scaleY": 1}})
    s_rest_on = d("AnimationState", animationId=rest.ref(), x=0.0, y=400.0)
    s_rest_off = d("AnimationState", animationId=rest.ref(), x=200.0, y=400.0)
    s_rest_on.add(b.transition(s_b, [b.c_bool(value, False)]))
    s_rest_off.add(b.transition(s_a, [b.c_bool(value, True)]))
    b.layer("Squash", [s_a, s_b, s_rest_on, s_rest_off],
            [b.transition(s_rest_on, [b.c_bool(value, True)]), b.transition(s_rest_off)])

    content = [knob, inset, on, off]
    if bd:
        content.append(backdrop(104, 64, bd))
    return b.artboard(content)


# ---------------------------------------------------------------- Mark

def mark(bd: str | None) -> list[El]:
    b = Board("Mark", 256, 256, 1000, 0)
    play = b.trigger("play")
    accent = b.color("accent", ACCENT)
    W = 9.0

    def lens_path(cx: float) -> El:
        return rect(76, 60, 24)

    trims = []

    def drawn(name: str, path: El, x: float = 0, y: float = 0) -> El:
        t = d("TrimPath", start=0.0, end=1.0, offset=0.0, modeValue=1)
        trims.append(t)
        return shape(name, path, d("Stroke", solid(PAPER), t, thickness=W, cap="round", join="round", name="Line"), x=x, y=y)

    lens_l = drawn("LensL", lens_path(0), x=-44, y=0)
    lens_r = drawn("LensR", lens_path(0), x=44, y=0)
    bridge = drawn("Bridge", arc(0, 4, 9, math.pi * 1.12, math.pi * 1.88))
    arm_l = drawn("ArmL", line((-82, -12), (-100, -15)))
    arm_r = drawn("ArmR", line((82, -12), (100, -15)))

    # tinted glass + glint, clipped to the lenses
    clip_src = node("LensClip", shape("ClipL", rect(76, 60, 24), x=-44), shape("ClipR", rect(76, 60, 24), x=44))
    glint = shape("Glint", P(sv(-14, -60), sv(6, -60), sv(-34, 60), sv(-54, 60), closed=True), fill("8CF3EBDD"))
    glint2 = shape("Glint2", P(sv(12, -60), sv(19, -60), sv(-21, 60), sv(-28, 60), closed=True), fill("66F3EBDD"))
    sweep = node("GlintSweep", glint, glint2, x=-150)
    glass = node("Glass",
                 shape("TintL", rect(76, 60, 24), b.fill_b(accent), x=-44, opacity=0.13),
                 shape("TintR", rect(76, 60, 24), b.fill_b(accent), x=44, opacity=0.13))
    for s in (glint, glint2):
        s.add(d("ClippingShape", sourceId=clip_src.ref(), name="Clip"))
    frame = node("Frame", lens_l, lens_r, bridge, arm_l, arm_r)

    spark_big = shape("SparkBig", star4(0, 0, 17, 21), b.fill_b(accent))
    spark_small = shape("SparkSmall", star4(0, 0, 7, 8.5), b.fill_b(accent))
    spark = node("Spark", spark_big, x=74, y=-50)
    spark2 = node("Spark2", spark_small, x=97, y=-26)
    halo = shape("Halo", ell(230, 130), b.fill_b(accent, feather=46), opacity=0.22)
    glasses = node("Glasses", spark, spark2, sweep, frame, glass, clip_src)
    settle = node("Settle", glasses)
    mark_n = node("Mark", settle, halo, x=128, y=134)

    # rest = finished logo; play = draw-on sting (84 frames = 1.4 s), ending exactly on rest
    tl, tr, tb, tal, tar = trims
    o = b.out
    sting = b.anim("Sting", 84, [
        b.T(tl, end=[(0, 0), (4, 0, o), (34, 1)]),
        b.T(tr, end=[(0, 0), (9, 0, o), (39, 1)]),
        b.T(tb, end=[(0, 0), (26, 0, o), (38, 1)]),
        b.T(tal, end=[(0, 0), (32, 0, o), (44, 1)]),
        b.T(tar, end=[(0, 0), (34, 0, o), (46, 1)]),
        b.T(glass, opacity=[(0, 0), (18, 0), (40, 1)]),
        b.T(settle, scaleX=[(0, 0.86), (30, 0.86, b.back), (54, 1)], scaleY=[(0, 0.86), (30, 0.86, b.back), (54, 1)],
            y=[(0, 8), (30, 8, b.back), (54, 0)]),
        b.T(sweep, x=[(0, -150), (44, -150, b.ease), (70, 150)]),
        b.T(spark, scaleX=[(0, 0), (46, 0, b.back), (62, 1)], scaleY=[(0, 0), (46, 0, b.back), (62, 1)],
            rotation=[(0, -1.2), (46, -1.2, o), (70, 0)]),
        b.T(spark2, scaleX=[(0, 0), (54, 0, b.back), (68, 1)], scaleY=[(0, 0), (54, 0, b.back), (68, 1)]),
        b.T(halo, opacity=[(0, 0), (20, 0), (52, 0.4), (84, 0.22)],
            scaleX=[(0, 0.6), (20, 0.6, o), (60, 1)], scaleY=[(0, 0.6), (20, 0.6, o), (60, 1)]),
    ])
    rest = b.pose("Mark_rest", {t: {"end": 1} for t in trims} | {
        glass: {"opacity": 1}, settle: {"scaleX": 1, "scaleY": 1, "y": 0}, sweep: {"x": -150},
        spark: {"scaleX": 1, "scaleY": 1, "rotation": 0}, spark2: {"scaleX": 1, "scaleY": 1},
        halo: {"opacity": 0.22, "scaleX": 1, "scaleY": 1}})
    s_rest = d("AnimationState", animationId=rest.ref(), x=0.0, y=200.0)
    s_play = d("AnimationState", animationId=sting.ref(), x=200.0, y=200.0)
    s_play2 = d("AnimationState", animationId=sting.ref(), x=400.0, y=200.0)
    s_rest.add(b.transition(s_play, [b.c_trigger(play)]))
    s_play.add(b.transition(s_rest, enableExitTime=True, exitTimeIsPercetange=True, exitTime=100))
    s_play.add(b.transition(s_play2, [b.c_trigger(play)]))   # replay while playing restarts cleanly
    s_play2.add(b.transition(s_rest, enableExitTime=True, exitTimeIsPercetange=True, exitTime=100))
    s_play2.add(b.transition(s_play, [b.c_trigger(play)]))
    b.layer("Sting", [s_rest, s_play, s_play2], [b.transition(s_rest)])

    content = [mark_n]
    if bd:
        content.append(backdrop(256, 256, bd))
    return b.artboard(content)


# ---------------------------------------------------------------- main

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "ui_kit"))
    ap.add_argument("--backdrop", default=None, help="ARGB fill painted behind every artboard (review only)")
    ap.add_argument("--main", default="ComposerOrb")
    a = ap.parse_args()
    roots: list[El] = []
    for build in (composer_orb, status_glow, tool_icon, toggle, mark):
        roots += build(a.backdrop)
    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, "ui_kit.rml")
    write(out, roots)
    name = os.path.basename(os.path.normpath(a.out))
    with open(os.path.join(a.out, "rive.yaml"), "w") as f:
        f.write(f"name: {name}\nmain: {a.main}\noutput: {{dir: build}}\n"
                "logs: {file: build/rive.log, problems: build/problems.log}\n")
    print("wrote", os.path.normpath(out))


if __name__ == "__main__":
    main()
