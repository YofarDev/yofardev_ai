"""Moonshot M8 Task 4 (contract v11): one NPC per scene and the weather `fog`.

Each scene's NPC is a state-machine layer `Npc` driven by the `npc` enum (away, rest, idle, move,
notice, react; AnyState transitions blend in `NPC_BLEND_MS`), `notice` a 1D blend aimed by `npcLook`,
and history-free formula binds of `npcX` for its path (the art's node and its prop hit zone move
together). `rest` is the v10 look: the M7 art keeps every id and attribute; new nodes wrap it at
identity (pivot pairs, so keyed absolute values and every coordinate stay as they were) and new art
sits hidden at opacity 0. Every state keys every NPC property (`Rig.anim`), so a blend between any two
states is defined. Everything here mints from the scene's `d8` (`gen_scenes.M8_ID_START`).

- livingRoom **cat**: path 0 = its v10 spot on the TV cabinet, 1 = the rug under the lamp. It walks
  left along the cabinet, hops down in front of it and crosses the floor to the rug, growing with the
  floor's perspective. It is drawn in Plane4 (in front of the rug) and takes back the plane-gain
  difference on the cabinet and the floor (Plane3), easing to Plane4's travel as it steps onto the rug.
  `move` faces left (toward the rug) while `npcLook` <= 0 and right while it is > 0.
- campfire **owl**: no path. Head swivel (idle), restless shuffle (move), head turn + wide eyes
  (notice), wing flaps with an open beak (react).
- beach **crab**: path 0 = its v10 spot, 1 = the wet sand at the right, by the water.
- deepSpace **alien**: in the ufo; its path is the ufo's drift, 0 = the v10 spot, 1 = left of the
  avatar, under the planet. The ufo carries the `ufo` hit zone along.
"""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from rig_dsl import Formulas
from rml import Doc, El, ellipse, fill, stroke
from scene_art import named, walk

if TYPE_CHECKING:
    from gen_scenes import Scene

NPC_STATES = ("away", "rest", "idle", "move", "notice", "react")
NPC_BLEND_MS = 200
FOG_GAIN = 0.45          # ruling 7: a veil thickens by up to this opacity at fog 1
FRONT_FOG_GAIN = 0.4     # the SceneFront fog veil's opacity at fog 1 (only drawn while rain > 0)
FOG_VEILS = {"livingRoom": (0,), "campfire": (0, 1, 2), "beach": (0, 1, 2)}   # deepSpace: none
REFINE_STROKE = 0.72     # scene_art.refine_scene thins every stroke; the NPC art is added after it
Z = (0.0, 0.0)
INK = "FF2A2030"

# The art's root nodes and their opacity (rest, away) (contract: away = not drawn).
NPC_ROOTS: dict[str, dict[str, tuple[float, float]]] = {
    "livingRoom": {"CatNpc": (1.0, 0.0)},
    "campfire": {"OwlNpc": (1.0, 0.0)},
    "beach": {"CrabNpc": (1.0, 0.0)},
    "deepSpace": {"Alien": (1.0, 0.0), "AlienNpc": (0.0, 0.0)},
}

# ---------------------------------------------------------------- loops (frames at 60 fps)
CAT_IDLE, CAT_WALK, CAT_NOTICE, CAT_REACT = 360, 30, 120, 60
OWL_IDLE, OWL_MOVE, OWL_NOTICE, OWL_REACT = 360, 120, 120, 60
CRAB_IDLE, CRAB_MOVE, CRAB_NOTICE, CRAB_REACT = 120, 40, 120, 40
ALIEN_IDLE, ALIEN_MOVE, ALIEN_NOTICE, ALIEN_REACT = 240, 120, 120, 60
REACT_MS = {"cat": CAT_REACT * 1000 // 60, "owl": OWL_REACT * 1000 // 60, "crab": CRAB_REACT * 1000 // 60,
            "alien": ALIEN_REACT * 1000 // 60}


# ====================================================================== shared rig
class Rig:
    """The NPC's keyed properties and their rest values: every state animation keys all of them."""

    def __init__(self, sc: Scene) -> None:
        self.sc = sc
        self.base: dict[tuple[str, str], tuple[El, float]] = {}

    def reg(self, el: El, **vals: float) -> El:
        for p, v in vals.items():
            self.base[(el.ref(), p)] = (el, float(v))
        return el

    def anim(self, name: str, frames: int, keys: dict[El, dict[str, list]] | None = None,
             existing: El | None = None) -> El:
        """A looping state animation keying every registered property: `keys` gives the moving ones
        ({element: {prop: [(frame, value[, mode])]}}, cubic ease by default), the rest hold their
        rest value. With `existing`, the missing properties are appended to that animation."""
        keys = keys or {}
        for el, props in keys.items():
            for p in props:
                assert (el.ref(), p) in self.base, (el.attrs.get("name"), p)
        by_el: dict[str, tuple[El, dict[str, list]]] = {}
        done = set()
        if existing is not None:
            done = {(ko.attrs["objectId"], kp.attrs["property"]) for ko in existing.children for kp in ko.children}
        for (eid, p), (el, v) in self.base.items():
            if (eid, p) in done:
                continue
            ks = keys.get(el, {}).get(p, [(0, v)])
            by_el.setdefault(eid, (el, {}))[1][p] = ks
        tracks = [self.sc.T(el, **props) for el, props in by_el.values()]
        if existing is not None:
            existing.children.extend(tracks)
            return existing
        return self.sc.A(name, frames, tracks, loop=True, seam_hold=frames > 4)


def L(sc: Scene, c: str, w: float) -> El:
    return sc.L(c, w * REFINE_STROKE)


def pw_tokens(f: Formulas, pts: list[tuple[float, float]]) -> list[El]:
    """`v0 + sum(slope_i * min(len_i, max(0, input - t_i)))`: the piecewise-linear function through
    `pts` [(t, value)], exactly v0 at input 0 (history-free; clamps below t0 and above the last t)."""
    toks = [f.val(pts[0][1])]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if abs(v1 - v0) < 1e-9:
            continue
        toks += [f.op("+"), f.val((v1 - v0) / (t1 - t0)), f.op("*"),
                 *f.fn("min", [f.val(t1 - t0)], f.fn("max", [f.val(0)], [*f.inp(), f.op("-"), f.val(t0)]))]
    return toks


def formula(sc: Scene, toks: list[El], doc: Doc | None = None) -> El:
    conv = (doc or sc.d8)("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def arc_params(pts: list[tuple[float, float]]) -> list[float]:
    """npcX at each waypoint: proportional to the distance walked, so a steady npcX rate is a
    steady screen speed."""
    acc = [0.0]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        acc.append(acc[-1] + math.hypot(x1 - x0, y1 - y0))
    return [round(a / acc[-1], 4) for a in acc]


def path_binds(sc: Scene, node: El, ts: list[float], xs: list[float], ys: list[float],
               scales: list[float] | None = None, depth: tuple[float, float, tuple[float, float]] | None = None,
               toward: bool = False, prop: str = "npcX", doc: Doc | None = None) -> None:
    """Binds `node` x / y (and scaleX / scaleY) to piecewise-linear functions of `npcX` (`prop`; v12:
    `npc2X` with `doc` = the scene's d9). `depth`
    (t_from, t_to, (cx, cy)): adds `c * parallax * (1 - D(npcX))`, D ramping 0 -> 1 between the two
    t, so art drawn in a nearer plane rides a farther plane's travel until it steps onto its own;
    with `toward`, `c * parallax * D` instead (it walks off its own plane onto a farther one)."""
    doc = doc or sc.d8
    f = Formulas(doc, sc.vpath)
    for key, vals, axis in ((13, xs, 0), (14, ys, 1)):
        toks = pw_tokens(f, list(zip(ts, vals)))
        if depth is not None:
            t_a, t_b, cs = depth
            c, par = cs[axis], ("parallaxX", "parallaxY")[axis]
            a = 1.0 / (t_b - t_a)
            ramp = f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(a), f.op("*"), *f.inp(), f.op("+"),
                                                                   f.val(-t_a * a)]))
            if toward:
                toks += [f.op("+"), f.val(c), f.op("*"), f.bound(par), f.op("*"), *ramp]
            else:
                toks += [f.op("+"), f.val(c), f.op("*"), f.bound(par), f.op("-"), f.val(c), f.op("*"), f.bound(par),
                         f.op("*"), *ramp]
        node.children.insert(0, sc.bind(prop, key, formula(sc, toks, doc), doc=doc))
    if scales is not None:
        conv = formula(sc, pw_tokens(f, list(zip(ts, scales))), doc)
        for key in (17, 16):
            node.children.insert(0, sc.bind(prop, key, conv, doc=doc))


def pivot_wrap(sc: Scene, name: str, x: float, y: float, kids: list[El], **kw: object) -> tuple[El, El]:
    """`name` at (x, y) -> `name`Pivot at (-x, -y) -> kids: a transform handle at (x, y) that leaves
    the kids' own coordinates (and their keyed absolute values) untouched."""
    inner = sc.d("Node", *kids, x=float(-x), y=float(-y), name=name + "Pivot")
    outer = sc.d("Node", inner, x=float(x), y=float(y), name=name, **kw)
    return outer, inner


def npc_layer(sc: Scene, anims: dict[str, El | list[El]], slot: str = "npc", look: str = "npcLook",
              name: str = "Npc", entry: str = "rest", blend_ms: int = NPC_BLEND_MS) -> None:
    """The `Npc` layer: AnyState -> each state but rest when `npc` equals it, every state -> rest when it
    is rest (blend `blend_ms`, NPC_BLEND_MS); `notice` (three animations) is a 1D blend on `npcLook` at
    -1 / 0 / +1. Entry = rest. v12: the second slot passes `slot` npc2, `look` npc2Look, `name` Npc2 and
    `entry` away (its default: the layer starts where the view model does, so nothing is drawn at f0).
    M12: `draw_layer` passes `blend_ms` 0 for the drawing switch."""
    d = sc.d
    states: dict[str, El] = {}
    for i, k in enumerate(NPC_STATES):
        a = anims[k]
        pos = {"x": float(160 * i), "y": float(220 + 120 * (i % 2))}
        if isinstance(a, list):
            states[k] = d("BlendState1DViewModel",
                          d("BindablePropertyNumber", d("DataBindContext", sourcePathIds=sc.vpath(look),
                                                        propertyKey=636)),
                          *[d("BlendAnimation1D", animationId=x.ref(), value=v) for x, v in zip(a, (-1.0, 0.0, 1.0))],
                          **pos)
        else:
            states[k] = d("AnimationState", animationId=a.ref(), **pos)
    def is_(k: str) -> El:
        return d("TransitionViewModelCondition",
                 d("TransitionPropertyViewModelComparator",
                   d("BindablePropertyEnum", d("DataBindContext", sourcePathIds=sc.vpath(slot), propertyKey=637))),
                 d("TransitionValueEnumComparator", value=sc.npc_vals[k].ref()))
    # rest is reached from each state, never from AnyState: an AnyState transition into the state the
    # layer is in restarts it once on the first frame, which left the crab's rest loop (its v10
    # ambient) one frame behind the v10 file
    any_t = [d("StateTransition", is_(k), stateToId=s.ref(), duration=blend_ms)
             for k, s in states.items() if k != entry]
    for k, s in states.items():
        if k != entry:
            s.add(d("BlendStateTransition" if s.tag == "BlendState1DViewModel" else "StateTransition", is_(entry),
                    stateToId=states[entry].ref(), duration=blend_ms))
    sc.layers.append(sc._layer(name, states[entry], list(states.values()), any_t))


def draw_layer(sc: Scene, anims: dict[str, El | list[El]], shown: dict[str, El], prefix: str,
               name: str = "NpcDraw") -> El:
    """M12 ruling 7: the NPC's drawing switch on its own state-machine layer (the ghost blends: during the
    `Npc` layer's NPC_BLEND_MS state blend, two drawing copies, e.g. asleep and awake, cross-faded).

    `shown[state]` is the drawing copy each of NPC_STATES draws (its opacity was keyed by every pose
    animation through `Rig`). Those opacity keys leave the pose animations in `anims` (the `Npc` layer
    keeps blending the poses), and the layer `name` holds one 1-frame animation `<prefix>_draw_<state>`
    per state keying every copy (1 for the shown one, 0 for the others), switched on the same `npc`
    conditions in 0 ms: a state change cuts from one drawing to the other on the frame the pose blend
    starts. Removing keys frees ids but moves none; the new elements mint from the scene's current
    document (call it inside `sc.minting(<the module's own range>)`). Returns the layer."""
    drawings = list(dict.fromkeys(shown.values()))
    ids = {e.ref() for e in drawings}
    for a in (x for v in anims.values() for x in (v if isinstance(v, list) else [v])):
        kept = []
        for ko in a.children:
            if ko.tag == "KeyedObject" and ko.attrs.get("objectId") in ids:
                ko.children[:] = [kp for kp in ko.children if kp.attrs.get("property") != "opacity"]
                if not ko.children:
                    continue
            kept.append(ko)
        a.children[:] = kept
    draws: dict[str, El | list[El]] = {
        k: sc.A(f"{prefix}_draw_{k}", 1, [sc.T(e, opacity=[(0, 1.0 if e is shown[k] else 0.0)]) for e in drawings])
        for k in NPC_STATES}
    npc_layer(sc, draws, name=name, blend_ms=0)
    return sc.layers[-1]


def blend3(fn: object) -> list:
    """[fn(-1), fn(0), fn(+1)]: the notice poses for npcLook -1 / 0 / +1."""
    return [fn(s) for s in (-1.0, 0.0, 1.0)]  # type: ignore[operator]


def loop_keys(frames: int, pts: list[tuple[float, float]]) -> list[tuple[int, float]]:
    """Keys over `frames` with the first value repeated at the end (a seamless loop)."""
    out = [(int(f * frames), v) if isinstance(f, float) else (f, v) for f, v in pts]
    if out[-1][0] != frames:
        out.append((frames, out[0][1]))
    return out


# ====================================================================== fog (ruling 13)
def linear(sc: Scene, k: float, c: float = 0.0) -> El:
    """A private `c + k x input` converter minted from `d8`: never `Scene.conv`'s shared cache, whose
    first caller mints it (an M8 caller first would shift the ids a later M5 pass hands out)."""
    f = Formulas(sc.d8, sc.vpath)
    head = [] if c == 0 else [f.val(c), f.op("+")]
    return formula(sc, [*head, f.val(k), f.op("*"), *f.inp()])


# The fog bank (execution ruling proposal): the M5 veils sit near opacity 1 already (campfire's Plane0
# veil is 0.93) and are tinted by `lightFog` (a dark navy at the campfire), so +0.45 alone barely
# reads. Each foggy scene also gets one bank of mist in front of a far plane (the near planes stay
# crisp): (plane, y where it starts clear, y where it is full, colour, opacity at fog 1). livingRoom's
# fills the view through the window (Plane0, behind the wall's opening).
FOG_BANKS: dict[str, tuple[int, float, float, str, float]] = {
    "livingRoom": (0, 200.0, 420.0, "FF9AA0B4", 0.7),
    "campfire": (2, 520.0, 960.0, "FF8494AA", 0.6),
    "beach": (2, 520.0, 980.0, "FFDDE3E8", 0.65),
}


def scene_fog(sc: Scene, content: list[El]) -> None:
    """Contract v11 `fog`: the scene's fog veils (`FOG_VEILS`) thicken by `FOG_GAIN x fog` over their
    M5 opacity, and its fog bank (`FOG_BANKS`) rises to its opacity x fog in front of its plane
    (history-free; at fog 0 the veils keep their opacity and the bank is clear)."""
    for k in FOG_VEILS.get(sc.id, ()):
        veil = next(e for e in walk(content) if e.attrs.get("name") == f"FogVeil{k}")
        base = float(veil.attrs["opacity"])
        veil.children.insert(0, sc.bind("fog", 18, linear(sc, FOG_GAIN, base), doc=sc.d8))
    if sc.id not in FOG_BANKS:
        return
    k, y0, y1, col, gain = FOG_BANKS[sc.id]
    d8 = sc.d8
    plane = next(e for e in content if e.attrs.get("name") == f"Plane{k}")
    h = 1920.0 + 60.0 - y0
    bank = d8("Shape", sc.bind("fog", 18, linear(sc, gain), doc=d8),
              d8("Rectangle", width=1080.0 + 120.0, height=h, originX=0.0, originY=0.0, name="Path"),
              d8("Fill", d8("LinearGradient", d8("GradientStop", colorValue="00" + col[2:], position=0.0),
                            d8("GradientStop", colorValue=col, position=round((y1 - y0) / h, 4)),
                            d8("GradientStop", colorValue=col, position=1.0),
                            startX=0.0, startY=0.0, endX=0.0, endY=h), name="Fill"),
              x=-60.0, y=y0, opacity=0.0, name="FogBank")
    # the front of the plane's art: after its binds and hit zones (in front of its own veil)
    at = next(i for i, c in enumerate(plane.children) if c.tag != "DataBindContext"
              and not str(c.attrs.get("name", "")).startswith("Hit_"))
    plane.children.insert(at, bank)


def front_fog(sc: Scene, y0: float, bleed: float, fog_fills: list[El]) -> El:
    """The SceneFront fog veil: the rain mist's shape and `lightFog` fills at opacity
    `FRONT_FOG_GAIN x fog` (the app creates SceneFront only while rain > 0)."""
    d8 = sc.d8
    return d8("Shape", sc.bind("fog", 18, linear(sc, FRONT_FOG_GAIN), doc=d8),
              d8("Rectangle", width=float(1080 + 2 * bleed), height=float(1920 + 60 - y0), originX=0.0,
                 originY=0.0, name="Path"),
              *fog_fills, x=float(-bleed), y=float(y0), opacity=0.0, name="FrontFog")


# ====================================================================== livingRoom: the cat
TV_PIVOT = (865.0, 1230.0)       # scene_art.PLACES TvCorner: the cabinet group's pivot and target
TV_SCALE = 0.72
CAT_AT = (904.0, 1076.0)         # the sleeping cat's node, inside the cabinet group
# Where the cat's paws are on screen and its scale (the floor's perspective), cabinet -> rug.
CAT_WAYPOINTS = [
    (TV_PIVOT[0] + TV_SCALE * (CAT_AT[0] - TV_PIVOT[0]), TV_PIVOT[1] + TV_SCALE * (CAT_AT[1] - TV_PIVOT[1]), TV_SCALE),
    (772.0, 1119.12, 0.72),      # the cabinet's left end
    (750.0, 1100.0, 0.73),       # the hop: up ...
    (726.0, 1146.0, 0.75),       # ... and down
    (708.0, 1262.0, 0.78),       # lands on the floor in front of the TV unit
    (560.0, 1336.0, 0.83),       # the floor, just short of the rug
    (440.0, 1398.0, 0.88),       # on the rug
    (330.0, 1452.0, 0.95),       # 1: the rug in the lamp's pool, by the lamp
]
CAT_DEPTH_STEPS = (5, 6)         # the waypoints between which it steps onto the rug (Plane3 -> Plane4)
CAT_STRIDE = 62.0                # local px per walk cycle (the WalkingCat's stance sweep)


def cat_path() -> tuple[list[float], list[tuple[float, float]], list[float]]:
    """(npcX at each waypoint, the CatNpc node position there, the scale there)."""
    ts = arc_params([(x, y) for x, y, _ in CAT_WAYPOINTS])
    off = (CAT_AT[0] - TV_PIVOT[0], CAT_AT[1] - TV_PIVOT[1])
    nodes = [(x - s * off[0], y - s * off[1]) for x, y, s in CAT_WAYPOINTS]
    nodes[0] = TV_PIVOT          # exact at npcX 0
    return ts, nodes, [s for _, _, s in CAT_WAYPOINTS]


def cat_walk_speed() -> float:
    """npcX per second at which the walk cycle's planted paws do not slide (average scale)."""
    ts, _, scales = cat_path()
    length = sum(math.hypot(x1 - x0, y1 - y0) for (x0, y0, _), (x1, y1, _) in zip(CAT_WAYPOINTS, CAT_WAYPOINTS[1:]))
    px_per_s = CAT_STRIDE * (sum(scales) / len(scales)) * 60 / CAT_WALK
    return px_per_s / length


def _cat_walker(sc: Scene, rig: Rig) -> tuple[El, El, dict[str, list]]:
    """The orange tabby in profile (the WalkingCat's drawing and leg rig), facing left. Returns
    (node, the bob node, {joint: [hip, knee, paw]}) with every joint registered in `rig`."""
    S, E, F, d = sc.S, sc.E, sc.F, sc.d
    body_c, shade, dark = "FFF0A060", "FFC07038", "FFB0602E"
    joints: dict[str, list] = {}

    def leg(name: str, hx: float, col: str) -> El:
        paw = d("Node", E(Z, "Paw", -3, -1, 17, 8, F(col), L(sc, INK, 1.4)), x=0.0, y=19.0, name=name + "Foot")
        shin = d("Node", paw, S(Z, "Shin", [(-4, -2), (4, -2), (3, 18), (-3, 18)], F(col), L(sc, INK, 1.4)),
                 x=0.0, y=20.0, name=name + "Shin")
        n = d("Node", shin, S(Z, "Thigh", [(-6, -3), (6, -3), (4, 21), (-4, 21)], F(col), L(sc, INK, 1.4)),
              x=hx, y=-32.0, name=name)
        joints[name] = [rig.reg(n, rotation=0.0), rig.reg(shin, rotation=0.0), rig.reg(paw, rotation=0.0)]
        return n
    legs_far = [leg("CWLegFarF", -22, shade), leg("CWLegFarB", 46, shade)]
    legs_near = [leg("CWLegNearF", -34, body_c), leg("CWLegNearB", 34, body_c)]
    tail = d("Node", S((56.0, -42.0), "CWTailFill", [(56, -42), (84, -50), (96, -78), (88, -100)], L(sc, shade, 9),
                       closed=False),
             S((56.0, -42.0), "CWTail", [(56, -42), (84, -50), (96, -78), (88, -100)], L(sc, INK, 13),
               closed=False), x=56.0, y=-42.0, name="CWTailPivot")
    rig.reg(tail, rotation=0.0)
    stripes = [S(Z, f"CWStripe{i}", [(x - 6, -60 + i), (x, -46), (x - 4, -30)], L(sc, dark, 4), closed=False)
               for i, x in enumerate((-8, 12, 32))]
    body = S(Z, "CWBody", [(-50, -50), (-20, -62), (30, -60), (58, -48), (62, -30), (40, -22), (-30, -22), (-52, -32)],
             sc.vgrad(-20, 20, [(body_c, 0.0), (shade, 1.0)]), L(sc, INK, 2.5))
    ears = [(-88, -64), (-86, -86), (-80, -100, "c"), (-68, -88), (-56, -90), (-46, -102, "c"), (-40, -80),
            (-38, -62), (-48, -46), (-64, -42), (-80, -48)]
    head = d("Node", E(Z, "CWPupil", -75, -70.5, 3, 6, F("FF1A1414")),
             S(Z, "CWEye", [(-80, -70), (-74, -74), (-68, -70), (-74, -67)], F("FFE6D45A"), L(sc, INK, 1.6)),
             S(Z, "CWNose", [(-90, -61), (-86, -61), (-88, -58, "c")], F("FFD98A8A")),
             S(Z, "CWMuzzle", [(-90, -56), (-82, -52), (-74, -54)], L(sc, INK, 1.6), closed=False),
             S(Z, "CWHeadStripe", [(-66, -88), (-62, -78)], L(sc, dark, 3), closed=False),
             S(Z, "CWHead", ears, sc.vgrad(-30, 30, [(body_c, 0.0), (shade, 1.0)]), L(sc, INK, 2.5)),
             x=0.0, y=0.0, name="CWHeadSide")
    bob = d("Node", head, *legs_near, *stripes, body, tail, *legs_far, x=0.0, y=0.0, name="CWBodyBob")
    rig.reg(bob, y=0.0)
    face = d("Node", bob, E(Z, "CWShadow", 4, 2, 150, 12, F("38101818")), x=0.0, y=0.0, name="CatWalkFace")
    # facing: left (toward the rug) while npcLook <= 0, right (mirrored) while it is > 0
    f = Formulas(sc.d8, sc.vpath)
    flip = formula(sc, [f.val(1), f.op("-"), f.val(2), f.op("*"),
                        *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(1000), f.op("*"), f.bound("npcLook")]))])
    face.children.insert(0, sc.bind("npcLook", 16, flip, doc=sc.d8))
    node = d("Node", face, x=CAT_AT[0], y=CAT_AT[1], opacity=0.0, name="CatWalk")
    return node, bob, joints


def _walk_tracks(bob: El, joints: dict[str, list], frames: int) -> dict[El, dict[str, list]]:
    """The WalkingCat's stance / swing IK at a steady cruise, one stride per `frames` (seamless)."""
    keys: dict[El, dict[str, list]] = {}
    samples = list(range(0, frames + 1, 2)) + ([frames] if frames % 2 else [])
    bob_keys = []
    for index, (name, ph) in enumerate(zip(("CWLegNearF", "CWLegNearB", "CWLegFarF", "CWLegFarB"),
                                           (0.0, math.pi, math.pi * 0.5, math.pi * 1.5))):
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
                bob_keys.append((fr, -2.2 * math.sin(phase) ** 2, "linear"))
        for j, k in zip(joints[name], (hip_k, knee_k, paw_k)):
            keys[j] = {"rotation": k}
    keys[bob] = {"y": bob_keys}
    return keys


def living_room_cat(sc: Scene, content: list[El], hits: list[El], gains: tuple[float, ...],
                    travel: tuple[float, float]) -> None:
    S, E, F = sc.S, sc.E, sc.F
    with sc.minting(sc.d8):
        d = sc.d
        rig = Rig(sc)
        # ---- the v10 sleeping cat and its Zzz leave the cabinet group (still first there: in front)
        pivot = named(content, "TvCornerPivot")
        asleep_kids = [c for c in pivot.children if c.attrs.get("name") in ("Cat", "Z0", "Z1", "Z2")]
        assert [c.attrs["name"] for c in pivot.children[:4]] == ["Cat", "Z0", "Z1", "Z2"]
        del pivot.children[:4]
        asleep = d("Node", *asleep_kids, x=0.0, y=0.0, name="CatAsleep")
        rig.reg(asleep, opacity=1.0)

        # ---- awake, sitting (front view)
        body_c, shade = "FFF0A060", "FFC07038"
        eye_nodes, lids, pupils = [], [], []
        for k, ex in enumerate((-10.0, 10.0)):
            pupil = E(Z, f"SitPupil{k}", 0, 0, 3.4, 9, F("FF1A1414"))
            eye = d("Node", pupil,
                    S(Z, f"SitEye{k}", [(-6, 0), (0, -5), (6, 0), (0, 5)], F("FFE6D45A"), L(sc, INK, 1.6)),
                    x=ex, y=-3.0, name=f"SitEyeOpen{k}")
            lid = S((ex, -3.0), f"SitEyeShut{k}", [(ex - 6, -3), (ex, 1), (ex + 6, -3)], L(sc, INK, 2.0),
                    closed=False, opacity=0.0)
            eye_nodes.append(rig.reg(eye, scaleX=1.0, scaleY=1.0, opacity=1.0))
            lids.append(rig.reg(lid, opacity=0.0))
            pupils.append(rig.reg(pupil, x=0.0, scaleX=1.0))
        tongue = rig.reg(E(Z, "SitTongue", -3, 11, 5, 6, F("FFE07A86"), opacity=0.0), opacity=0.0)
        face = d("Node", tongue, *lids, *eye_nodes,
                 S(Z, "SitNose", [(-3, 4), (3, 4), (0, 7, "c")], F("FFD98A8A")),
                 S(Z, "SitMouth", [(-6, 9), (-3, 11.5), (0, 8.5), (3, 11.5), (6, 9)], L(sc, INK, 1.4), closed=False),
                 *[S(Z, f"SitWhisker{k}", [(sx * 9, 6 + dy), (sx * 24, 3 + dy * 2)], L(sc, "C0FFF2DC", 1.2),
                     closed=False) for k, (sx, dy) in enumerate(((-1, 0), (-1, 3), (1, 0), (1, 3)))],
                 x=0.0, y=0.0, name="SitFace")
        rig.reg(face, x=0.0)
        ears = []
        for k, sx in enumerate((-1, 1)):
            ear = d("Node", S(Z, f"SitEarInner{k}", [(-4, 0), (0, -11, "c"), (4, 0)], F("FFE89A8A")),
                    S(Z, f"SitEarShape{k}", [(-9, 3), (0, -17, "c"), (9, 3)], F(body_c), L(sc, INK, 2.2)),
                    x=sx * 15.0, y=-15.0, rotation=sx * 0.22, name=f"SitEar{k}")
            ears.append(rig.reg(ear, rotation=sx * 0.22, scaleY=1.0))
        head = d("Node", face,
                 *[S(Z, f"SitHeadStripe{k}", [(dx, -21), (dx * 0.8, -13)], L(sc, shade, 3), closed=False)
                   for k, dx in enumerate((-6, 0, 6))],
                 S(Z, "SitHeadShape", [(-27, 1), (-24, -13), (-13, -21), (0, -23), (13, -21), (24, -13), (27, 1),
                                       (19, 12), (0, 16), (-19, 12)],
                   sc.vgrad(-20, 20, [(body_c, 0.0), ("FFE09050", 1.0)]), L(sc, INK, 2.5)),
                 *ears, x=0.0, y=-70.0, name="SitHead")
        rig.reg(head, rotation=0.0, x=0.0, y=-70.0)
        paw_up = d("Node", S(Z, "SitPawUpLeg", [(-6, 0), (6, 0), (5, -30), (-5, -30)], F(body_c), L(sc, INK, 2)),
                   E(Z, "SitPawUpPad", 0, -32, 14, 10, F("FFF6C890"), L(sc, INK, 1.8)),
                   x=-12.0, y=-30.0, rotation=0.35, opacity=0.0, name="SitPawUp")
        rig.reg(paw_up, opacity=0.0, rotation=0.35)
        leg_l = rig.reg(d("Node", S(Z, "SitLegL", [(-6, -30), (5, -30), (5, -3), (-6, -3)], F(body_c),
                                    L(sc, INK, 2)),
                          E(Z, "SitPawL", 0, -3, 15, 9, F("FFF6C890"), L(sc, INK, 1.8)),
                          x=-10.0, y=0.0, name="SitFrontL"), opacity=1.0)
        leg_r = d("Node", S(Z, "SitLegR", [(-5, -30), (6, -30), (6, -3), (-5, -3)], F(body_c), L(sc, INK, 2)),
                  E(Z, "SitPawR", 0, -3, 15, 9, F("FFF6C890"), L(sc, INK, 1.8)), x=10.0, y=0.0, name="SitFrontR")
        tail_ink = L(sc, INK, 13)
        tail_fill = L(sc, shade, 9)
        # first child paints in front: the fill stroke over its wider ink outline
        tail = d("Node", S(Z, "SitTailFill", [(0, 0), (22, -2), (32, -24), (26, -46)], tail_fill, closed=False,
                           origin=Z),
                 S(Z, "SitTailInk", [(0, 0), (22, -2), (32, -24), (26, -46)], tail_ink, closed=False, origin=Z),
                 x=22.0, y=-6.0, name="SitTail")
        rig.reg(tail, rotation=0.0, scaleX=1.0, scaleY=1.0)
        rig.reg(tail_ink, thickness=float(tail_ink.attrs["thickness"]))
        rig.reg(tail_fill, thickness=float(tail_fill.attrs["thickness"]))
        sit = d("Node", head, paw_up, leg_l, leg_r,
                E(Z, "SitBib", 0, -40, 26, 32, F("FFF8DDB0")),
                *[S(Z, f"SitStripe{k}", [(sx * 22, -52 + dy), (sx * 27, -42 + dy)], L(sc, shade, 4), closed=False)
                  for k, (sx, dy) in enumerate(((-1, 0), (-1, 12), (1, 0), (1, 12)))],
                S(Z, "SitBody", [(-25, 0, "c"), (-33, -22), (-28, -50), (-16, -64), (0, -68), (16, -64), (28, -50),
                                 (33, -22), (25, 0, "c")],
                  sc.vgrad(-34, 34, [(body_c, 0.0), (shade, 1.0)]), L(sc, INK, 2.5)),
                tail, x=0.0, y=0.0, name="CatSitBob")
        rig.reg(sit, y=0.0, scaleX=1.0, scaleY=1.0)
        awake = d("Node", sit, E(Z, "SitShadow", 4, 1, 92, 10, F("38101818")), x=CAT_AT[0], y=CAT_AT[1],
                  opacity=0.0, name="CatAwake")
        rig.reg(awake, opacity=0.0)

        # ---- walking (profile)
        walker, bob, joints = _cat_walker(sc, rig)
        rig.reg(walker, opacity=0.0)

        # ---- the path: Plane4 (in front of the rug), on Plane3's travel until it steps onto the rug
        npc, _ = pivot_wrap(sc, "CatNpc", *TV_PIVOT, [walker, awake, asleep], scaleX=TV_SCALE, scaleY=TV_SCALE)
        rig.reg(npc, opacity=1.0)
        ts, nodes, scales = cat_path()
        g = gains[3] - gains[4]
        path_binds(sc, npc, ts, [n[0] for n in nodes], [n[1] for n in nodes], scales,
                   depth=(ts[CAT_DEPTH_STEPS[0]], ts[CAT_DEPTH_STEPS[1]], (g * travel[0], g * travel[1])))
        hit = next(h for h in hits if h.attrs.get("name") == "Hit_cat")
        hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
        q0 = CAT_WAYPOINTS[0]
        path_binds(sc, hit, ts, [x + (hx - q0[0]) * s / TV_SCALE for x, _, s in CAT_WAYPOINTS],
                   [y + (hy - q0[1]) * s / TV_SCALE for _, y, s in CAT_WAYPOINTS], [s / TV_SCALE for s in scales])
        at = next(i for i, e in enumerate(content) if e.attrs.get("name") == "RugInner")
        content.insert(at, npc)

        # ---- states
        awake_on = {asleep: {"opacity": [(0, 0.0)]}, awake: {"opacity": [(0, 1.0)]}}
        anims: dict[str, El | list[El]] = {}
        anims["rest"] = rig.anim("npc_cat_rest", 1)
        anims["away"] = rig.anim("npc_cat_away", 1, {npc: {"opacity": [(0, 0.0)]}})
        n = CAT_IDLE
        lick = [(0, -70.0), (110, -70.0), (128, -66.0)] + \
            [(f, v) for c in range(140, 250, 22) for f, v in ((c, -63.0), (c + 11, -67.0))] + [(262, -70.0), (n, -70.0)]
        anims["idle"] = rig.anim("npc_cat_idle", n, {
            **awake_on,
            head: {"rotation": [(0, 0.0), (110, 0.0), (128, 0.24), (250, 0.24), (268, 0.0), (n, 0.0)], "y": lick},
            paw_up: {"opacity": [(0, 0.0), (112, 0.0, "hold"), (113, 1.0), (258, 1.0, "hold"), (259, 0.0), (n, 0.0)],
                     "rotation": [(0, 0.35), (113, 0.35), (130, 0.1), (250, 0.1), (258, 0.35), (n, 0.35)]},
            leg_l: {"opacity": [(0, 1.0), (112, 1.0, "hold"), (113, 0.0), (258, 0.0, "hold"), (259, 1.0), (n, 1.0)]},
            **{e: {"opacity": [(0, 1.0), (126, 1.0, "hold"), (127, 0.0), (252, 0.0, "hold"), (253, 1.0), (n, 1.0)]}
               for e in eye_nodes},
            **{e: {"opacity": [(0, 0.0), (126, 0.0, "hold"), (127, 1.0), (252, 1.0, "hold"), (253, 0.0), (n, 0.0)]}
               for e in lids},
            tongue: {"opacity": [(0, 0.0)] + [(f, v, "hold") for c in range(140, 250, 22)
                                              for f, v in ((c + 3, 0.0), (c + 4, 1.0), (c + 9, 0.0))] + [(n, 0.0)]},
            tail: {"rotation": [(0, 0.0), (30, 0.0), (42, 0.38), (54, -0.12), (66, 0.0), (290, 0.0), (300, 0.3),
                                (312, -0.1), (324, 0.0), (n, 0.0)]},
            ears[1]: {"rotation": [(0, 0.22), (80, 0.22), (84, 0.5), (92, 0.22), (n, 0.22)]},
            sit: {"scaleY": [(0, 1.0), (60, 1.012), (120, 1.0), (300, 1.0), (330, 1.012), (n, 1.0)]},
        })
        walk_k = _walk_tracks(bob, joints, CAT_WALK)
        tail_w = next(e for e in walk([walker]) if e.attrs.get("name") == "CWTailPivot")
        walk_k[tail_w] = {"rotation": [(0, 0.0), (CAT_WALK // 2, 0.12), (CAT_WALK, 0.0)]}
        anims["move"] = rig.anim("npc_cat_move", CAT_WALK, {
            asleep: {"opacity": [(0, 0.0)]}, walker: {"opacity": [(0, 1.0)]}, **walk_k})
        n = CAT_NOTICE

        def notice(s: float) -> El:
            return rig.anim(f"npc_cat_notice{'LCR'[int(s) + 1]}", n, {
                **awake_on,
                head: {"rotation": [(0, 0.1 * s), (60, 0.1 * s + 0.04), (n, 0.1 * s)],
                       "x": [(0, 4.0 * s)]},
                face: {"x": [(0, 5.0 * s)]},
                **{p: {"x": [(0, 1.8 * s)], "scaleX": [(0, 1.7)]} for p in pupils},
                **{e: {"scaleX": [(0, 1.18)], "scaleY": [(0, 1.18)]} for e in eye_nodes},
                **{e: {"scaleY": [(0, 1.22)], "rotation": [(0, sx * 0.08)]} for e, sx in zip(ears, (-1, 1))},
                tail: {"rotation": [(0, 0.0), (40, 0.16), (80, -0.06), (n, 0.0)]},
            })
        anims["notice"] = blend3(notice)
        n = CAT_REACT
        anims["react"] = rig.anim("npc_cat_react", n, {
            **awake_on,
            sit: {"y": [(0, 0.0), (6, 3.0), (14, -30.0), (24, -40.0), (36, 0.0), (42, 3.0), (50, 0.0), (n, 0.0)],
                  "scaleY": [(0, 1.0), (6, 0.88), (14, 1.1), (24, 1.02), (36, 0.9), (44, 1.02), (52, 1.0), (n, 1.0)],
                  "scaleX": [(0, 1.0), (6, 1.1), (14, 0.94), (24, 0.99), (36, 1.08), (44, 0.99), (52, 1.0), (n, 1.0)]},
            tail: {"rotation": [(0, -0.2), (14, -0.45), (36, -0.3), (n, -0.2)],
                   "scaleX": [(0, 1.0), (8, 1.15), (n, 1.0)], "scaleY": [(0, 1.0), (8, 1.15), (n, 1.0)]},
            tail_ink: {"thickness": [(0, 9.4), (8, 17.0), (48, 17.0), (n, 9.4)]},
            tail_fill: {"thickness": [(0, 6.5), (8, 14.0), (48, 14.0), (n, 6.5)]},
            **{e: {"scaleY": [(0, 0.8)], "rotation": [(0, sx * 0.5)]} for e, sx in zip(ears, (-1, 1))},
            **{e: {"scaleX": [(0, 1.25)], "scaleY": [(0, 1.25)]} for e in eye_nodes},
            **{p: {"scaleX": [(0, 2.2)]} for p in pupils},
        })
        npc_layer(sc, anims)


# ====================================================================== campfire: the owl
OWL_AT = (884.0, 704.0)
OWL_FEET = (884.0, 756.0)
OWL_HEAD_PARTS = ("OwlTuft1", "OwlTuft-1", "HootLid1", "HootLid0", "HootLowerBeak", "HootMouth", "OwlFaceRim-1",
                  "OwlFaceRim1", "OwlLid0", "OwlPupil0", "OwlEye0", "OwlLid1", "OwlPupil1", "OwlEye1", "Beak", "Face")


def campfire_owl(sc: Scene, content: list[El], hits: list[El]) -> None:
    E, F = sc.E, sc.F
    with sc.minting(sc.d8):
        d = sc.d
        rig = Rig(sc)
        owl = named(content, "Owl")
        kids = {str(c.attrs.get("name")): c for c in owl.children}
        assert len(kids) == len(owl.children)
        # head: everything of the face, in its own order; each eye under a node at its centre
        eyes = []
        for k, ex in enumerate((-15.0, 15.0)):
            n, _ = pivot_wrap(sc, f"OwlEyeN{k}", ex, -18.0, [kids[f"OwlLid{k}"], kids[f"OwlPupil{k}"], kids[f"OwlEye{k}"]])
            eyes.append(rig.reg(n, scaleX=1.0, scaleY=1.0))
        hoot = rig.reg(E(Z, "NpcHootMouth", 0, 4, 8, 11, F("FF302218"), opacity=0.0, scaleY=0.2),
                       opacity=0.0, scaleY=0.2)
        head_kids = [kids[n] for n in OWL_HEAD_PARTS[:6]] + [hoot] + [kids[n] for n in OWL_HEAD_PARTS[6:8]] + eyes + \
            [kids["Beak"], kids["Face"]]
        head = rig.reg(d("Node", *head_kids, x=0.0, y=0.0, name="OwlHead"), rotation=0.0, x=0.0, scaleX=1.0)
        wings = []
        for side in (-1, 1):
            w, _ = pivot_wrap(sc, f"OwlWingN{side}", side * 26.0, -4.0,
                              [kids[f"OwlWing{side}"], *[kids[f"WingCovert{side}_{i}"] for i in range(3)]])
            wings.append(rig.reg(w, rotation=0.0))
        owl.children = [*wings, *[kids[f"ChestFeather{i}"] for i in range(5)], head, kids["Chest"], kids["OwlBody"]]
        placed = {id(e) for e in walk(owl.children)}
        assert all(id(e) in placed for e in kids.values())
        # its talons on the bough (right behind it in the content) go with it
        at = content.index(owl)
        grips = content[at + 1:at + 4]
        assert [g.attrs.get("name") for g in grips] == ["OwlGrip0", "OwlGrip1", "OwlGrip2"]
        npc, _ = pivot_wrap(sc, "OwlNpc", *OWL_FEET, [owl, *grips])
        rig.reg(npc, opacity=1.0, x=OWL_FEET[0], y=OWL_FEET[1], rotation=0.0, scaleX=1.0, scaleY=1.0)
        content[at:at + 4] = [npc]

        anims: dict[str, El | list[El]] = {"rest": rig.anim("npc_owl_rest", 1),
                                           "away": rig.anim("npc_owl_away", 1, {npc: {"opacity": [(0, 0.0)]}})}
        n = OWL_IDLE
        turn = [(0, 0.0), (40, 0.0), (64, -0.13), (150, -0.13), (172, 0.0), (200, 0.0), (224, 0.14), (300, 0.14),
                (322, 0.0), (n, 0.0)]
        anims["idle"] = rig.anim("npc_owl_idle", n, {
            head: {"rotation": turn, "x": [(f, v * 22) for f, v in turn],
                   "scaleX": [(f, 1 - abs(v) * 0.5) for f, v in turn]},
            npc: {"scaleY": [(0, 1.0), (90, 1.015), (180, 1.0), (270, 1.015), (n, 1.0)]},
        })
        n = OWL_MOVE
        anims["move"] = rig.anim("npc_owl_move", n, {
            npc: {"rotation": [(0, 0.0), (20, -0.07), (50, 0.06), (80, -0.05), (105, 0.03), (n, 0.0)],
                  "x": [(0, OWL_FEET[0]), (30, OWL_FEET[0] - 5), (75, OWL_FEET[0] + 5), (n, OWL_FEET[0])],
                  "y": [(0, OWL_FEET[1]), (12, OWL_FEET[1] - 4), (24, OWL_FEET[1]), (57, OWL_FEET[1] - 4),
                        (69, OWL_FEET[1]), (n, OWL_FEET[1])]},
            wings[0]: {"rotation": [(0, 0.0), (20, 0.3), (50, 0.05), (n, 0.0)]},
            wings[1]: {"rotation": [(0, 0.0), (60, -0.05), (85, -0.3), (110, -0.05), (n, 0.0)]},
            head: {"rotation": [(0, 0.0), (20, 0.06), (50, -0.06), (80, 0.05), (n, 0.0)]},
        })
        n = OWL_NOTICE

        def notice(s: float) -> El:
            r = 0.14 * s
            return rig.anim(f"npc_owl_notice{'LCR'[int(s) + 1]}", n, {
                head: {"rotation": [(0, r), (60, r + 0.04), (n, r)], "x": [(0, 2.0 * s)],
                       "scaleX": [(0, 1 - abs(s) * 0.08)]},
                **{e: {"scaleX": [(0, 1.22)], "scaleY": [(0, 1.22)]} for e in eyes},
                npc: {"scaleY": [(0, 1.03)]},
            })
        anims["notice"] = blend3(notice)
        n = OWL_REACT
        flap = [(0, 0.1), (6, 1.15), (12, 0.2), (18, 1.2), (24, 0.25), (30, 1.1), (38, 0.15), (n, 0.1)]
        anims["react"] = rig.anim("npc_owl_react", n, {
            wings[0]: {"rotation": flap}, wings[1]: {"rotation": [(f, -v) for f, v in flap]},
            npc: {"y": [(0, OWL_FEET[1]), (6, OWL_FEET[1] - 10), (12, OWL_FEET[1] - 4), (18, OWL_FEET[1] - 12),
                        (26, OWL_FEET[1] - 4), (34, OWL_FEET[1]), (n, OWL_FEET[1])],
                  "scaleY": [(0, 1.0), (40, 1.06), (50, 0.97), (n, 1.0)]},
            hoot: {"opacity": [(0, 0.0), (38, 0.0, "hold"), (39, 1.0), (54, 1.0, "hold"), (55, 0.0), (n, 0.0)],
                   "scaleY": [(0, 0.2), (39, 0.2), (44, 1.0), (52, 0.8), (n, 0.2)]},
            head: {"rotation": [(0, 0.0), (40, -0.12), (52, -0.08), (n, 0.0)]},
            **{e: {"scaleX": [(0, 1.15)], "scaleY": [(0, 1.15)]} for e in eyes},
        })
        npc_layer(sc, anims)


# ====================================================================== beach: the crab
CRAB_AT = (860.0, 1400.0)
CRAB_FEET = (860.0, 1430.0)
# its feet on screen and its scale, its v10 spot -> the wet sand at the right, by the water
CRAB_WAYPOINTS = [(860.0, 1430.0, 1.0), (900.0, 1358.0, 0.92), (940.0, 1298.0, 0.85), (980.0, 1268.0, 0.81),
                  (1016.0, 1258.0, 0.78)]
CRAB_DEPTH_STEPS = (0, 2)        # Plane4 (dry sand) -> Plane3 (the wet sand's travel)


def crab_path() -> tuple[list[float], list[tuple[float, float]], list[float]]:
    ts = arc_params([(x, y) for x, y, _ in CRAB_WAYPOINTS])
    return ts, [(x, y) for x, y, _ in CRAB_WAYPOINTS], [s for _, _, s in CRAB_WAYPOINTS]


def beach_crab(sc: Scene, content: list[El], hits: list[El], gains: tuple[float, ...],
               travel: tuple[float, float]) -> None:
    with sc.minting(sc.d8):
        rig = Rig(sc)
        crab = named(content, "Crab")
        parts = {str(c.attrs.get("name")): c for c in crab.children}
        amb = next(a for a in sc.anims if a.attrs.get("name") == "amb_crab")
        cx, cy = CRAB_AT
        rig.reg(crab, x=cx, y=cy)
        claws = [rig.reg(parts[f"Claw{i}"], rotation=0.0, scaleY=1.0) for i in range(2)]
        legs = [rig.reg(parts[f"CLeg{i}"], rotation=0.0) for i in range(6)]
        pupils = [rig.reg(parts[f"CPupil{i}"], x=float(parts[f"CPupil{i}"].attrs["x"])) for i in range(2)]
        at = content.index(crab)
        npc, _ = pivot_wrap(sc, "CrabNpc", *CRAB_FEET, [crab])
        rig.reg(npc, opacity=1.0)
        content[at] = npc
        ts, feet, scales = crab_path()
        # it walks back toward the wet sand (Plane3): its travel eases from Plane4's to Plane3's
        g = gains[3] - gains[4]
        path_binds(sc, npc, ts, [p[0] for p in feet], [p[1] for p in feet], scales,
                   depth=(ts[CRAB_DEPTH_STEPS[0]], ts[CRAB_DEPTH_STEPS[1]], (g * travel[0], g * travel[1])),
                   toward=True)
        hit = next(h for h in hits if h.attrs.get("name") == "Hit_crab")
        hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
        path_binds(sc, hit, ts, [x + (hx - CRAB_FEET[0]) * s for x, _, s in CRAB_WAYPOINTS],
                   [y + (hy - CRAB_FEET[1]) * s for _, y, s in CRAB_WAYPOINTS], scales)

        def gait(frames: int, amp: float = 0.22, period: int = 20) -> dict[El, dict[str, list]]:
            return {lg: {"rotation": [(f, amp * math.sin(2 * math.pi * f / period + (i % 2) * math.pi), "linear")
                                      for f in range(0, frames + 1, 2)]} for i, lg in enumerate(legs)}
        anims: dict[str, El | list[El]] = {"rest": rig.anim("amb_crab", 240, existing=amb),
                                           "away": rig.anim("npc_crab_away", 1, {npc: {"opacity": [(0, 0.0)]}})}
        n = CRAB_IDLE
        anims["idle"] = rig.anim("npc_crab_idle", n, {
            **gait(n),
            crab: {"x": [(0, cx), (30, cx - 12), (60, cx), (90, cx + 12), (n, cx)],
                   "y": [(f, cy - 1.6 * math.sin(math.pi * f / 10) ** 2, "linear") for f in range(0, n + 1, 2)]},
            claws[0]: {"rotation": [(0, 0.0), (15, 0.3), (30, 0.0), (75, 0.3), (90, 0.0), (n, 0.0)]},
            claws[1]: {"rotation": [(0, 0.0), (45, -0.3), (60, 0.0), (105, -0.3), (n, 0.0)]},
        })
        n = CRAB_MOVE
        anims["move"] = rig.anim("npc_crab_move", n, {
            **gait(n, 0.3),
            crab: {"y": [(f, cy - 2.0 * math.sin(math.pi * f / 10) ** 2, "linear") for f in range(0, n + 1, 2)]},
            claws[0]: {"rotation": [(0, 0.08), (20, -0.04), (n, 0.08)]},
            claws[1]: {"rotation": [(0, -0.08), (20, 0.04), (n, -0.08)]},
        })
        n = CRAB_NOTICE

        def notice(s: float) -> El:
            return rig.anim(f"npc_crab_notice{'LCR'[int(s) + 1]}", n, {
                crab: {"y": [(0, cy - 4.0)]},
                claws[0]: {"rotation": [(0, 0.36), (60, 0.3), (n, 0.36)]},
                claws[1]: {"rotation": [(0, -0.36), (60, -0.3), (n, -0.36)]},
                **{p: {"x": [(0, float(p.attrs["x"]) + 3.0 * s)]} for p in pupils},
            })
        anims["notice"] = blend3(notice)
        n = CRAB_REACT
        snap0 = [(0, -0.45)] + [(f, v) for c in range(0, n, 10) for f, v in ((c + 4, -0.2), (c + 8, -0.48))] + [(n, -0.45)]
        anims["react"] = rig.anim("npc_crab_react", n, {
            crab: {"y": [(0, cy), (6, cy - 9), (12, cy), (n, cy)]},
            claws[0]: {"rotation": snap0, "scaleY": [(0, 1.0)] + [(f, v) for c in range(0, n, 10)
                                                                  for f, v in ((c + 4, 0.82), (c + 8, 1.0))] + [(n, 1.0)]},
            claws[1]: {"rotation": [(f, -v) for f, v in snap0],
                       "scaleY": [(0, 1.0)] + [(f, v) for c in range(5, n - 5, 10)
                                               for f, v in ((c + 4, 0.82), (c + 8, 1.0))] + [(n, 1.0)]},
            **{lg: {"rotation": [(0, 0.15 * (1 if i < 3 else -1))]} for i, lg in enumerate(legs)},
        })
        npc_layer(sc, anims)


# ====================================================================== beach: the gulls (M9, v12 npc2)
# Ruling 10: the beach's second NPC slot, two storybook gulls on the sand right of (and in front of) the
# crab. `npc2X` 0 = landed (GULLS_AT), 1 = off the frame's right edge (a climb up and right, history-free:
# GULL_PATH, constant speed along it). They face left (toward the avatar) while `npc2Look` <= 0 and right
# while it is > 0, in every state: the app sets it > 0 to fly off (`move` 0 -> 1) and < 0 to land
# (`move` 1 -> 0). `notice` blends on |npc2Look|: heads up and toward where they face. Default `away`:
# the layer `Npc2` starts there (nothing drawn). Mints from the scene's d9.
GULLS_AT = (896.0, 1528.0)
GULL_FEET = ((-42.0, -12.0, 1.0), (36.0, 12.0, 1.08))    # each gull's feet from the anchor, its scale
# a climb away from the crab: right first, then up and out past the frame's right edge (+ Plane4's travel)
GULL_PATH = [(896.0, 1528.0, 1.0), (960.0, 1494.0, 0.98), (1024.0, 1430.0, 0.95), (1086.0, 1350.0, 0.92),
             (1160.0, 1272.0, 0.88), (1260.0, 1196.0, 0.84)]
GULL_REST, GULL_IDLE, GULL_MOVE, GULL_NOTICE, GULL_REACT = 240, 180, 24, 120, 36
GULL_COLOURS = {"white": "FFFFFFFF", "ink": "FF2A3040", "wing": ("FFB8C0CC", "FF7A8494"),
                "far": ("FF8A94A2", "FF5A6474"), "tip": "FF2A3040", "tail": "FFDDE3EA", "beak": "FFF0B030",
                "jaw": "FFD08A28", "leg": "FFC7933F", "eye": "FF101010", "shadow": "30805020"}


def gull_path() -> tuple[list[float], list[tuple[float, float]], list[float]]:
    ts = arc_params([(x, y) for x, y, _ in GULL_PATH])
    return ts, [(x, y) for x, y, _ in GULL_PATH], [s for _, _, s in GULL_PATH]


def _gull(sc: Scene, rig: Rig, i: int) -> tuple[El, dict[str, El]]:
    """One gull, feet at its origin, facing left. Returns its node and the rigged parts."""
    c = GULL_COLOURS
    S, E, F = sc.S, sc.E, sc.F

    def wing(name: str, cols: tuple[str, str], x: float, y: float) -> El:
        # a flight wing pointing up and back from the shoulder; its scaleY flaps it (down = negative)
        return sc.node(name, x, y,
                       S(Z, "WingTip", [(9.0, -40.0), (16.0, -50.0, "c"), (15.0, -37.0)], F(c["tip"]), origin=Z),
                       S(Z, "WingBlade", [(-7.0, 3.0), (-4.0, -14.0), (4.0, -34.0), (16.0, -50.0, "c"), (15.0, -32.0),
                                          (10.0, -12.0), (7.0, 4.0)],
                         sc.vgrad(-27, 27, [(cols[0], 0.0), (cols[1], 1.0)]), L(sc, c["ink"], 2), origin=Z),
                       opacity=0.0)

    eye = E(Z, "GullEye", -9.0, -12.0, 4.5, 4.5, F(c["eye"]))
    jaw = sc.node("GullJaw", -15.0, -7.0, S(Z, "Jaw", [(0.0, 0.0), (-12.0, 1.0, "c"), (0.0, 3.0)], F(c["jaw"]), origin=Z))
    head = sc.node(f"Gull{i}Head", -14.0, -36.0, eye,
                   S(Z, "GullBeak", [(-15.0, -12.0), (-31.0, -9.0, "c"), (-15.0, -6.0)], F(c["beak"]), origin=Z),
                   jaw, E(Z, "GullHeadShape", -5.0, -10.0, 24.0, 21.0, F(c["white"]), L(sc, c["ink"], 2)))
    near = wing(f"Gull{i}WingNear", c["wing"], 4.0, -36.0)
    far = wing(f"Gull{i}WingFar", c["far"], 8.0, -37.0)
    folded = sc.node(f"Gull{i}Wing", 0.0, 0.0,
                     S(Z, "FoldTip", [(30.0, -29.0), (42.0, -24.0, "c"), (31.0, -23.0)], F(c["tip"]), origin=Z),
                     S(Z, "Fold", [(-12.0, -33.0), (10.0, -38.0), (32.0, -31.0), (42.0, -24.0, "c"), (18.0, -21.0),
                                   (-6.0, -24.0)], sc.vgrad(-9, 9, [(c["wing"][0], 0.0), (c["wing"][1], 1.0)]),
                       L(sc, c["ink"], 2), origin=Z))
    legs = sc.node(f"Gull{i}Legs", 0.0, -13.0,
                   *[S(Z, f"GullLeg{k}", [(x, 0.0), (x - 0.5, 13.0), (x - 7.0, 13.5)], L(sc, c["leg"], 2.8), closed=False,
                       origin=Z) for k, x in enumerate((-4.0, 4.0))])
    body = sc.node(f"Gull{i}Body", 0.0, 0.0, head, near, folded,
                   E(Z, "GullBodyShape", 2.0, -26.0, 50.0, 28.0, F(c["white"]), L(sc, c["ink"], 2)),
                   S(Z, "GullTail", [(20.0, -30.0), (38.0, -27.0, "c"), (36.0, -21.0, "c"), (20.0, -21.0)],
                     F(c["tail"]), L(sc, c["ink"], 1.6), origin=Z),
                   far, legs)
    shadow = E(Z, f"Gull{i}Shadow", 2.0, 1.0, 46.0, 8.0, F(c["shadow"]))
    f = Formulas(sc.d9, sc.vpath)
    face = formula(sc, [f.val(1), f.op("+"), f.val(-2), f.op("*"),
                        *f.fn("min", [f.val(1)], f.fn("max", [f.val(0)], [f.val(40), f.op("*"), *f.inp()]))], sc.d9)
    facing = sc.node(f"Gull{i}Facing", 0.0, 0.0, sc.bind("npc2Look", 16, face, doc=sc.d9), body, shadow)
    ox, oy, s = GULL_FEET[i]
    node = sc.node(f"Gull{i}", ox, oy, facing, scaleX=s, scaleY=s)
    parts = {"body": rig.reg(body, x=0.0, y=0.0, rotation=0.0, scaleY=1.0),
             "head": rig.reg(head, rotation=0.0, y=-36.0), "eye": rig.reg(eye, scaleY=1.0),
             "jaw": rig.reg(jaw, rotation=0.0), "folded": rig.reg(folded, opacity=1.0),
             "near": rig.reg(near, opacity=0.0, scaleY=1.0), "far": rig.reg(far, opacity=0.0, scaleY=1.0),
             "legs": rig.reg(legs, scaleY=1.0), "shadow": rig.reg(shadow, opacity=1.0, scaleX=1.0)}
    return node, parts


def beach_gulls(sc: Scene, content: list[El]) -> None:
    """The gulls (`GullsNpc`, Plane4 in front of the crab) and their `Npc2` layer (see GULLS_AT)."""
    with sc.minting(sc.d9):
        rig = Rig(sc)
        gulls = [_gull(sc, rig, i) for i in range(2)]
        group = sc.node("GullsNpc", *GULLS_AT, gulls[1][0], gulls[0][0], opacity=0.0)
        rig.reg(group, opacity=1.0)
        ts, pts, scales = gull_path()
        path_binds(sc, group, ts, [p[0] for p in pts], [p[1] for p in pts], scales, prop="npc2X", doc=sc.d9)
        content.insert(next(i for i, e in enumerate(content) if e.attrs.get("name") == "CrabNpc"), group)
        g = [p for _, p in gulls]

        def blink(at: int, n: int) -> list:
            return [(0, 1.0), (at, 1.0), (at + 3, 0.1), (at + 7, 1.0), (n, 1.0)]

        def wave(n: int, period: int, lo: float, hi: float, ph: float) -> list:
            mid, amp = (hi + lo) / 2, (hi - lo) / 2
            return [(fr, round(mid + amp * math.cos(2 * math.pi * (fr / period + ph)), 4), "linear")
                    for fr in range(0, n + 1, 2)]

        def flight(n: int, period: int, i: int) -> dict[El, dict[str, list]]:
            p = g[i]
            ph = 0.25 * i
            return {p["folded"]: {"opacity": [(0, 0.0)]}, p["near"]: {"opacity": [(0, 1.0)],
                                                                       "scaleY": wave(n, period, -0.8, 1.0, ph)},
                    p["far"]: {"opacity": [(0, 1.0)], "scaleY": wave(n, period, -0.7, 0.9, ph - 0.08)}}

        anims: dict[str, El | list[El]] = {
            "away": rig.anim("npc_gulls_away", 1, {group: {"opacity": [(0, 0.0)]}}),
            "rest": rig.anim("npc_gulls_rest", GULL_REST, {
                **{p["body"]: {"scaleY": [(0, 1.0), (120 + 30 * i, 1.025), (GULL_REST, 1.0)]} for i, p in enumerate(g)},
                **{p["eye"]: {"scaleY": blink(70 + 90 * i, GULL_REST)} for i, p in enumerate(g)}}),
        }
        n = GULL_IDLE
        peck = [(0, 0.0), (24, 0.0), (34, -0.32), (52, -0.32), (62, 0.0), (104, 0.0), (114, -0.32), (128, -0.32),
                (138, 0.0), (n, 0.0)]
        peck_head = [(0, 0.0), (24, 0.0), (34, -0.85), (38, -0.7), (42, -0.9), (46, -0.72), (52, -0.85), (62, 0.0),
                     (104, 0.0), (114, -0.85), (119, -0.7), (124, -0.9), (128, -0.85), (138, 0.0), (n, 0.0)]
        hop = [(0, 0.0)] + [(fr, round(-2.5 * abs(math.sin(math.pi * (fr - a) / 10)), 3), "linear")
                            for a in (40, 120) for fr in range(a, a + 31, 5)] + [(n, 0.0)]
        anims["idle"] = rig.anim("npc_gulls_idle", n, {
            g[0]["body"]: {"rotation": peck}, g[0]["head"]: {"rotation": peck_head},
            g[0]["eye"]: {"scaleY": blink(160, n)},
            g[1]["body"]: {"x": [(0, 0.0), (40, 0.0), (70, -10.0), (120, -10.0), (150, 0.0), (n, 0.0)], "y": hop},
            g[1]["head"]: {"rotation": [(0, 0.0), (20, 0.12), (80, 0.12), (92, -0.1), (160, -0.1), (n, 0.0)]},
            g[1]["eye"]: {"scaleY": blink(30, n)},
        })
        n = GULL_MOVE
        anims["move"] = rig.anim("npc_gulls_move", n, {
            **{k: v for i in range(2) for k, v in flight(n, n, i).items()},
            **{p["legs"]: {"scaleY": [(0, 0.3)]} for p in g},
            **{p["shadow"]: {"opacity": [(0, 0.0)]} for p in g},
            **{p["head"]: {"rotation": [(0, 0.08)]} for p in g},
            **{p["body"]: {"rotation": [(0, 0.12)], "y": wave(n, n, -4.0, 4.0, 0.25 * i + 0.5)} for i, p in enumerate(g)},
        })
        n = GULL_NOTICE

        def notice(s: float) -> El:
            a = abs(s)
            return rig.anim(f"npc_gulls_notice{'LCR'[int(s) + 1]}", n, {
                **{p["head"]: {"rotation": [(0, 0.16 + 0.1 * a - 0.03 * i), (60, 0.2 + 0.1 * a - 0.03 * i),
                                            (n, 0.16 + 0.1 * a - 0.03 * i)], "y": [(0, -38.0)]}
                   for i, p in enumerate(g)},
                **{p["body"]: {"scaleY": [(0, 1.05)]} for p in g},
                **{p["eye"]: {"scaleY": [(0, 1.15)]} for p in g},
            })
        anims["notice"] = blend3(notice)
        n = GULL_REACT
        anims["react"] = rig.anim("npc_gulls_react", n, {
            **{k: v for i in range(2) for k, v in flight(n, 12, i).items()},
            **{p["body"]: {"y": [(0, 0.0), (5, -16.0), (14, -22.0 - 3 * i), (24, -14.0), (32, -3.0), (n, 0.0)],
                           "rotation": [(0, 0.15)]} for i, p in enumerate(g)},
            **{p["head"]: {"rotation": [(0, 0.3)]} for p in g},
            **{p["jaw"]: {"rotation": [(0, -0.55)]} for p in g},
            **{p["legs"]: {"scaleY": [(0, 0.6)]} for p in g},
            **{p["shadow"]: {"opacity": [(0, 0.55)], "scaleX": [(0, 0.8)]} for p in g},
        })
        npc_layer(sc, anims, slot="npc2", look="npc2Look", name="Npc2", entry="away")


# ====================================================================== deepSpace: the alien
UFO_AT = (860.0, 900.0)


def ufo_waypoints() -> list[tuple[float, float]]:
    """The ufo's drift: a quadratic arc over the avatar's head, its v10 spot -> left, under the planet."""
    p0, c, p1 = UFO_AT, (560.0, 560.0), (270.0, 1060.0)
    out = []
    for i in range(7):
        t = i / 6
        out.append(((1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * c[0] + t * t * p1[0],
                    (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * c[1] + t * t * p1[1]))
    out[0] = UFO_AT
    return out


def deep_space_alien(sc: Scene, content: list[El], hits: list[El]) -> None:
    S, E, F = sc.S, sc.E, sc.F
    with sc.minting(sc.d8):
        d = sc.d
        rig = Rig(sc)
        ufo = named(content, "Ufo")
        old = named(ufo.children, "Alien")
        rig.reg(old, opacity=1.0)
        green, deep, line = "FF8EE884", "FF4FB45E", "FF24502E"
        eyes = d("Node", *[n for k, ex in enumerate((-7.0, 7.0)) for n in (
            E(Z, f"AlienGlint{k}", ex - 1.6, -3.2, 3.2, 3.2, F("D8FFFFFF")),
            E(Z, f"AlienEye{k}", ex, 0, 10, 13, F("FF101820"), rotation=0.25 * (1 if k else -1)))],
            x=0.0, y=0.0, name="AlienEyes")
        rig.reg(eyes, x=0.0, scaleX=1.0, scaleY=1.0)
        ants = []
        for k, sx in enumerate((-1, 1)):
            a = d("Node", E(Z, f"AlienBulb{k}", sx * 5, -12, 5.5, 5.5, F("FFF4E06A")),
                  S(Z, f"AlienStalk{k}", [(0, 0), (sx * 2, -6), (sx * 5, -11)], L(sc, deep, 2.6), closed=False, origin=Z),
                  x=sx * 6.0, y=-13.0, name=f"AlienAntenna{k}")
            ants.append(rig.reg(a, rotation=0.0))
        head = d("Node", eyes,
                 S(Z, "AlienHeadShape", [(-15, 3), (-17, -6), (-10, -14), (0, -16), (10, -14), (17, -6), (15, 3),
                                         (7, 9), (-7, 9)],
                   sc.vgrad(-14, 10, [(green, 0.0), (deep, 1.0)]), L(sc, line, 2.0)),
                 *ants, x=0.0, y=-22.0, name="AlienHead")
        arm = d("Node", E(Z, "AlienHand", 9, -22, 8, 8, F(green), L(sc, line, 1.6)),
                S(Z, "AlienArmShape", [(0, 0), (7, -9), (9, -19)], L(sc, deep, 4.5), closed=False, origin=Z),
                x=10.0, y=-10.0, opacity=0.0, name="AlienArm")
        rig.reg(arm, opacity=0.0, rotation=0.0)
        bob = d("Node", arm, head, E(Z, "AlienTorso", 0, -6, 18, 15, sc.vgrad(-8, 8, [(green, 0.0), (deep, 1.0)]),
                                     L(sc, line, 1.8)),
                x=0.0, y=0.0, name="AlienBob")
        rig.reg(bob, y=0.0, rotation=0.0, scaleX=1.0, scaleY=1.0)
        npc = d("Node", bob, x=0.0, y=-14.0, opacity=0.0, name="AlienNpc")
        rig.reg(npc, opacity=0.0)
        ufo.children.insert(ufo.children.index(old), npc)
        # the ufo's drift (its own bob keeps running inside)
        flee = named(content, "UfoFlee")
        path, _ = pivot_wrap(sc, "UfoPath", *UFO_AT, [ufo])
        flee.children[flee.children.index(ufo)] = path
        rig.reg(path, rotation=0.0)
        pts = ufo_waypoints()
        ts = arc_params(pts)
        path_binds(sc, path, ts, [p[0] for p in pts], [p[1] for p in pts])
        hit = next(h for h in hits if h.attrs.get("name") == "Hit_ufo")
        hx, hy = float(hit.attrs["x"]), float(hit.attrs["y"])
        path_binds(sc, hit, ts, [x + hx - UFO_AT[0] for x, _ in pts], [y + hy - UFO_AT[1] for _, y in pts])

        on = {old: {"opacity": [(0, 0.0)]}, npc: {"opacity": [(0, 1.0)]}}
        anims: dict[str, El | list[El]] = {"rest": rig.anim("npc_alien_rest", 1),
                                           "away": rig.anim("npc_alien_away", 1, {old: {"opacity": [(0, 0.0)]}})}
        n = ALIEN_IDLE
        anims["idle"] = rig.anim("npc_alien_idle", n, {
            **on,
            bob: {"y": [(0, 9.0), (30, 0.0), (200, 0.0), (232, 9.0), (n, 9.0)],
                  "rotation": [(0, 0.0), (50, -0.08), (90, -0.08), (110, 0.08), (160, 0.08), (180, 0.0), (n, 0.0)]},
            eyes: {"x": [(0, 0.0), (40, -3.5), (90, -3.5), (110, 3.5), (160, 3.5), (180, 0.0), (n, 0.0)]},
            ants[0]: {"rotation": [(0, 0.0), (40, -0.3), (70, 0.15), (100, -0.1), (130, 0.0), (n, 0.0)]},
            ants[1]: {"rotation": [(0, 0.0), (50, 0.3), (80, -0.15), (110, 0.1), (140, 0.0), (n, 0.0)]},
        })
        n = ALIEN_MOVE
        anims["move"] = rig.anim("npc_alien_move", n, {
            **on,
            path: {"rotation": [(0, 0.0), (30, -0.05), (90, 0.05), (n, 0.0)]},
            bob: {"rotation": [(0, 0.0), (30, 0.08), (90, -0.08), (n, 0.0)]},
            ants[0]: {"rotation": [(0, 0.2), (60, 0.35), (n, 0.2)]},
            ants[1]: {"rotation": [(0, 0.35), (60, 0.2), (n, 0.35)]},
        })
        n = ALIEN_NOTICE

        def notice(s: float) -> El:
            return rig.anim(f"npc_alien_notice{'LCR'[int(s) + 1]}", n, {
                **on,
                bob: {"y": [(0, -2.0)], "rotation": [(0, 0.1 * s), (60, 0.1 * s + 0.03), (n, 0.1 * s)]},
                eyes: {"x": [(0, 3.5 * s)], "scaleX": [(0, 1.18)], "scaleY": [(0, 1.18)]},
                ants[0]: {"rotation": [(0, -0.15), (60, -0.25), (n, -0.15)]},
                ants[1]: {"rotation": [(0, 0.15), (60, 0.25), (n, 0.15)]},
            })
        anims["notice"] = blend3(notice)
        n = ALIEN_REACT
        anims["react"] = rig.anim("npc_alien_react", n, {
            **on,
            arm: {"opacity": [(0, 1.0)], "rotation": [(0, -0.35), (15, 0.45), (30, -0.35), (45, 0.45), (n, -0.35)]},
            bob: {"y": [(0, 0.0), (8, -4.0), (16, 0.0), (38, -4.0), (46, 0.0), (n, 0.0)],
                  "rotation": [(0, -0.06)]},
            eyes: {"scaleY": [(0, 1.0), (24, 1.0, "hold"), (25, 0.25), (29, 1.0), (n, 1.0)]},
        })
        npc_layer(sc, anims)


def _npc_paths() -> dict[str, tuple[str, str, tuple[float, float], tuple[float, float]]]:
    """sceneId -> (path node, its hit zone, the node's position at npcX 1, the art's anchor in the
    node's scaled frame: screen point = node + scale x anchor). The owl has no path."""
    _, cat_nodes, _ = cat_path()
    ufo = ufo_waypoints()
    return {"livingRoom": ("CatNpc", "Hit_cat", cat_nodes[-1], (CAT_AT[0] - TV_PIVOT[0], CAT_AT[1] - TV_PIVOT[1])),
            "beach": ("CrabNpc", "Hit_crab", CRAB_WAYPOINTS[-1][:2], (0.0, 0.0)),
            "deepSpace": ("UfoPath", "Hit_ufo", ufo[-1], (0.0, 0.0))}


NPC_PATHS = _npc_paths()
