"""Moonshot M9 (contract v12): the shared world kit and the scene registry.

Everything a scene module (`scene_cafe.py`, `scene_rooftop.py`, `scene_mountain_hut.py`) or the
existing scenes (`gen_scenes.py`) share for the v12 `SceneVM` members:

- `SCENE_MODULES`: the v12 scenes and the module that builds each (`<module>.<sceneId>()` returns the
  written RML path, like `gen_scenes.livingRoom`). `scene_module(sid)` imports it, raising
  `SceneNotWritten` with a clear message while its lane has not written it yet.
- `DRAGS`: the contract's "Drag handles (v12)" table, parsed from `rive/CONTRACT.md` at import (the
  contract is the single source: a scene lane corrects a rect there, never here).
- `v12_members(sid)`: the v12 `SceneVM` members of a scene, in contract order, with their defaults.
- `v13_members(sid)`, `vm_tail(sid)`, `declared_v13_binds(sid)` (M10, contract v13): `night`, declared
  by every scene after `festive` (before the drag numbers), bound where `gen_scenes.V13_BINDS` says.
- `declared_binds(sid)`: which v12 members the scene's file binds (built-ins: `gen_scenes.V12_BINDS`;
  v12 scenes: the module-level `BINDS` set). `Scene.write` and `check_contract.py` hold the file to it.
- `review(sid)`: the scene module's module-level `REVIEW` dict (empty when there is none), read by the
  review tools for any scene they do not configure themselves. Keys (all optional):

  - `"diorama"`: kwargs of `review_diorama.Cfg`: `patches` [(label, (x0, y0, x1, y1), travel px)],
    `wet` ((x0, y0, x1, y1), lo, hi), `rain_loops` [(name, frames)], `seam_box` (x0, y0, x1, y1).
  - `"extras"`: `fn(render, out: Path, gates: list[str]) -> None`, the scene's own evidence and gates
    in `review_diorama.py` (`render(*rive_args) -> np.ndarray` RGBA 1080x1920).
  - `"time"`: `{"sky_box": (x0, y0, x1, y1), "dusk_box": (x0, y0, x1, y1), "noon_gain": 12.0}` (M10: optional
    `"ground_lift"`, the least the day may brighten the bottom quarter, else it must not change) for
    `review_time.py`; without it the scene must ignore the clock (noon changes no pixel).
  - `"npc"`: for `review_npc.py`: `crop` (w, h, dy above the anchor), `seam` {state: loop frames},
    `prop` (the NPC's propId), `waypoints` [(x, y, scale)] along its path at npcX 0 .. 1 (screen
    anchor of the NPC and its scale; scale 1 at npcX 0 for a flat path), or `at` (x, y) for an NPC
    without a path, and optional `fog_box` (x0, y0, x1, y1): the only region fog may change.

The helpers below draw the v12 world art, history-free (formula converters on the view-model
numbers, never a state), invisible at the contract defaults so a scene renders exactly as before:

- `moon_rig` (ruling 12): the phase of the moon for `moonPhase` 0..1; nothing at -1, where the
  scene keeps its M8 moon (wrap that in `hide_when_phased`).
- `festive_lights` (ruling 13): a string of bulbs, a slow two-colour twinkle, opacity x `festive`.
- `trail_dots` (ruling 8, `trail` drags): 16 dots at `trailX<i>` / `trailY<i>`, dot i shown while
  i < `trailN`, all x (1 - `trailFade`).

Every helper mints from the `doc` it is given (a scene's `d9`, `gen_scenes.M9_ID_START`) and keeps
its converters private (never `Scene.conv`'s shared cache, whose first caller mints a converter an
older pass would then reuse, moving that pass's later ids).
"""

from __future__ import annotations

from dataclasses import dataclass
import importlib
import math
from pathlib import Path
import re
from types import ModuleType
from typing import TYPE_CHECKING, Callable

from rig_dsl import FNS, OPS, Formulas
from rml import Doc, El, ellipse, smooth_path, stroke

if TYPE_CHECKING:
    from gen_scenes import Scene

CONTRACT = Path(__file__).resolve().parents[1] / "CONTRACT.md"

# ====================================================================== the scene registry
# v12 scenes (ruling 1) -> the module whose function `<sceneId>()` builds it (ruling 19: one module
# per scene lane). The four M8 scenes are built in gen_scenes.py.
SCENE_MODULES: dict[str, str] = {"cafe": "scene_cafe", "rooftop": "scene_rooftop",
                                 "mountainHut": "scene_mountain_hut"}
BUILT_IN_SCENES: tuple[str, ...] = ("livingRoom", "campfire", "beach", "deepSpace")


class SceneNotWritten(RuntimeError):
    """A v12 scene whose module its lane has not written yet."""


def scene_module(scene_id: str) -> ModuleType:
    """The module building v12 scene `scene_id` (imported once). Raises `SceneNotWritten` when the
    module file does not exist yet, `KeyError` for an id that is not a v12 scene."""
    name = SCENE_MODULES[scene_id]
    try:
        return importlib.import_module(name)
    except ModuleNotFoundError as e:
        if e.name != name:
            raise
        raise SceneNotWritten(f"scene {scene_id!r} is in contract v12, but rive/tools/{name}.py does not exist yet "
                              f"(its scene lane writes it)") from None


def written_scene_modules() -> dict[str, ModuleType]:
    """The v12 scene modules that exist, imported (their import registers their `DioramaSpec` etc.)."""
    out = {}
    for sid in SCENE_MODULES:
        try:
            out[sid] = scene_module(sid)
        except SceneNotWritten:
            continue
    return out


def review(scene_id: str) -> dict:
    """The scene module's `REVIEW` dict (see the module docstring for its keys); {} for a built-in
    scene, an unknown id or a module not written yet."""
    if scene_id not in SCENE_MODULES:
        return {}
    try:
        return dict(getattr(scene_module(scene_id), "REVIEW", {}))
    except SceneNotWritten:
        return {}


# ====================================================================== drag handles (ruling 8)
TRAIL_DOTS = 16
TRAIL_NUMBERS: tuple[tuple[str, float], ...] = (
    ("trailN", 0.0), *((f"trailX{i}", 0.0) for i in range(TRAIL_DOTS)),
    *((f"trailY{i}", 0.0) for i in range(TRAIL_DOTS)), ("trailFade", 1.0))
DRAG_KINDS = ("pull", "poke", "trail", "spin", "aim")


@dataclass(frozen=True)
class DragHandle:
    """One row of the contract's drag table: `rect` (x0, y0, x1, y1) in `Scene` artboard px at
    parallax 0, `plane` 0..5 (the handle rides that plane's parallax), `numbers` the `SceneVM` numbers
    it writes with their defaults, in contract order."""

    id: str
    kind: str
    rect: tuple[float, float, float, float]
    plane: int
    numbers: tuple[tuple[str, float], ...]


def _num(s: str) -> float:
    return float(s.replace("−", "-"))


def parse_drags(text: str) -> dict[str, tuple[DragHandle, ...]]:
    """The "Drag handles (v12)" table of the contract text. A `trail` row's numbers are always the
    canonical `TRAIL_NUMBERS` (the cafe row says "as beach"); other rows list each number in
    backticks with its default in the first "(n)" after it (0 when none)."""
    at = text.index("### Drag handles (v12)")
    rows: list[list[str]] = []
    for line in text[at:].splitlines()[1:]:
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not set("".join(cells)) <= set("-: "):
                rows.append(cells)
        elif rows:
            break
    out: dict[str, list[DragHandle]] = {}
    for sid, drag, kind, rect, plane, numbers, *_ in rows[1:]:
        if kind not in DRAG_KINDS:
            raise ValueError(f"drag {sid}/{drag}: unknown kind {kind!r}")
        x0, y0, x1, y1 = (_num(v) for v in rect.strip("()").split(","))
        if kind == "trail":
            nums = TRAIL_NUMBERS
        else:
            parts = re.split(r"`(\w+)`", numbers)   # [prose, name, prose, name, prose ...]
            nums = tuple((name, _num(m.group(1)) if (m := re.search(r"\(([−\d.-]+)\)", after)) else 0.0)
                         for name, after in zip(parts[1::2], parts[2::2]))
        out.setdefault(sid, []).append(DragHandle(drag, kind, (x0, y0, x1, y1), int(plane), nums))
    return {sid: tuple(hs) for sid, hs in out.items()}


DRAGS: dict[str, tuple[DragHandle, ...]] = parse_drags(CONTRACT.read_text(encoding="utf-8"))


def drag_numbers(scene_id: str) -> tuple[str, ...]:
    """Every number the scene's drag handles write, in contract order."""
    return tuple(n for h in DRAGS.get(scene_id, ()) for n, _ in h.numbers)


# ====================================================================== v12 SceneVM members
NPC2_NAMES = ("npc2", "npc2X", "npc2Look")
MOON_PHASE_OFF = -1.0     # contract v12: -1 draws the moon as before v12


def v12_members(scene_id: str) -> list[tuple[str, str, object]]:
    """(name, type, default) of the v12 SceneVM members, in contract order after `npcLook`: the second
    NPC slot (`npc2` enum, default away, every scene declares it, only the beach binds it), `moonPhase`
    (-1), `festive` (0), then the scene's own drag numbers."""
    return [("npc2", "enum", "away"), ("npc2X", "number", 0.0), ("npc2Look", "number", 0.0),
            ("moonPhase", "number", MOON_PHASE_OFF), ("festive", "number", 0.0),
            *((n, "number", v) for h in DRAGS.get(scene_id, ()) for n, v in h.numbers)]


def v13_members(scene_id: str) -> list[tuple[str, str, object]]:
    """(name, type, default) of the v13 SceneVM members: `night` (0). Every scene declares them after
    `festive` and before its drag numbers (contract order); `declared_v13_binds` says who binds them."""
    return [("night", "number", 0.0)]


def vm_tail(scene_id: str) -> list[tuple[str, str, object]]:
    """Every SceneVM member after `npcLook`, in contract order: the v12 members without the drag
    numbers, the v13 members, then the scene's drag numbers (the contract lists them last)."""
    drags = set(drag_numbers(scene_id))
    v12 = v12_members(scene_id)
    return [m for m in v12 if m[0] not in drags] + v13_members(scene_id) + [m for m in v12 if m[0] in drags]


def declared_v13_binds(scene_id: str) -> frozenset[str]:
    """The v13 members the scene's file binds (`gen_scenes.V13_BINDS`; M10: only the beach's `night`)."""
    import gen_scenes  # noqa: PLC0415 (gen_scenes imports this module)
    return frozenset(gen_scenes.V13_BINDS.get(scene_id, ()))


def declared_binds(scene_id: str) -> frozenset[str]:
    """The v12 members the scene's file binds (the rest are declared and inert): `gen_scenes.V12_BINDS`
    for the M8 scenes, the scene module's `BINDS` for the v12 ones (empty while not written)."""
    if scene_id in SCENE_MODULES:
        try:
            return frozenset(getattr(scene_module(scene_id), "BINDS", ()))
        except SceneNotWritten:
            return frozenset()
    import gen_scenes  # noqa: PLC0415 (gen_scenes imports this module)
    return frozenset(gen_scenes.V12_BINDS.get(scene_id, ()))


def bound_names(root: object, vm_id: str, names: dict[str, str]) -> set[str]:
    """The view-model members (`names`: property id -> name) any `DataBindContext` under `root` reads,
    for an `El` tree or an `xml.etree` element (a bind inside a converter's token counts)."""
    out: set[str] = set()

    def visit(e: object) -> None:
        if isinstance(e, El):
            tag, attrs, kids = e.tag, e.attrs, e.children
        else:
            tag, attrs, kids = e.tag, e.attrib, list(e)  # type: ignore[attr-defined]
        if tag == "DataBindContext":
            path = str(attrs.get("sourcePathIds", ""))
            if path.startswith(vm_id + "-"):
                pid = path[len(vm_id) + 1:]
                if pid in names:
                    out.add(names[pid])
        if tag in ("ViewModel",):
            return
        for k in kids:
            visit(k)

    visit(root)
    return out


# ====================================================================== formulas
def _formula(sc: Scene, doc: Doc, toks: list[El]) -> El:
    """A private converter (a root element of the scene file)."""
    conv = doc("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def _clamp(f: Formulas, lo: float, hi: float, inner: list[El]) -> list[El]:
    return f.fn("min", [f.val(hi)], f.fn("max", [f.val(lo)], inner))


def _bind(sc: Scene, doc: Doc, prop: str, key: int, conv: El | None) -> El:
    return doc("DataBindContext", sourcePathIds=sc.vpath(prop), propertyKey=key,
               converterId=conv.ref() if conv is not None else None)


KEY_X, KEY_Y, KEY_SCALE_X, KEY_OPACITY = 13, 14, 16, 18
_FN_NAMES = {v: k for k, v in FNS.items()}
_OP_NAMES = {v: k for k, v in OPS.items()}


def eval_formula(conv: object, x: float, bound: Callable[[str], float] | None = None) -> float:
    """Evaluates a `DataConverterFormula` (an `El` or `xml.etree` element) at input `x`, the way the
    runtime does: `* /` before `+ -`, functions min / max / sqrt / cos / sin. A token read from the
    view model resolves through `bound(sourcePathIds)`. For tests and evidence."""
    def parts(e: object) -> tuple[str, dict, list]:
        if isinstance(e, El):
            return e.tag, e.attrs, e.children
        return e.tag, e.attrib, list(e)  # type: ignore[attr-defined]

    toks = parts(conv)[2]
    pos = 0

    def expr() -> float:
        nonlocal pos
        v = term()
        while pos < len(toks) and parts(toks[pos])[0] == "FormulaTokenOperation" \
                and _OP_NAMES[int(parts(toks[pos])[1]["operationType"])] in "+-":
            op = _OP_NAMES[int(parts(toks[pos])[1]["operationType"])]
            pos += 1
            r = term()
            v = v + r if op == "+" else v - r
        return v

    def term() -> float:
        nonlocal pos
        v = atom()
        while pos < len(toks) and parts(toks[pos])[0] == "FormulaTokenOperation" \
                and _OP_NAMES[int(parts(toks[pos])[1]["operationType"])] in "*/":
            op = _OP_NAMES[int(parts(toks[pos])[1]["operationType"])]
            pos += 1
            r = atom()
            v = v * r if op == "*" else v / r
        return v

    def atom() -> float:
        nonlocal pos
        tag, attrs, kids = parts(toks[pos])
        pos += 1
        if tag == "FormulaTokenInput":
            return x
        if tag == "FormulaTokenValue":
            if kids:
                if bound is None:
                    raise ValueError("a bound token needs `bound`")
                return bound(str(parts(kids[0])[1]["sourcePathIds"]))
            return float(attrs["operationValue"])
        if tag == "FormulaTokenFunction":
            fn = _FN_NAMES[int(attrs["functionType"])]
            args = [expr()]
            while parts(toks[pos])[0] == "FormulaTokenArgumentSeparator":
                pos += 1
                args.append(expr())
            assert parts(toks[pos])[0] == "FormulaTokenParenthesisClose"
            pos += 1
            return {"min": min, "max": max, "sqrt": lambda a: math.sqrt(a), "cos": math.cos,
                    "sin": math.sin}[fn](*args)
        raise ValueError(f"unexpected formula token {tag}")

    v = expr()
    assert pos == len(toks), "trailing formula tokens"
    return v


# ====================================================================== the moon (ruling 12)
MOON_MIRROR_GAIN = 1e5     # the dark side flips sides within |moonPhase - 0.5| < 1e-5 (~25 s of moon age), where it is 0 wide
_KAPPA = 0.5523            # cubic handle length of a quarter circle, x the radius
# the dark side is drawn this many px wider than the lit disc (M9 fix round 1): with coincident
# anti-aliased edges (lit under 0.9-alpha dark) the limb pixels showed ~3x the interior's share of the
# lit disc, a bright hairline (+19/255 at 1x). A wider bleed overshoots into a dark line (1.25 px:
# -9/255, the dark over bare sky); 0.6 px keeps the limb profile between interior and sky (+-1/255)
MOON_DARK_BLEED = 0.6


def _half_disc(doc: Doc, r: float, side: float, name: str) -> El:
    """A closed half disc of radius `r` left (side -1) or right (+1) of the vertical diameter."""
    k = _KAPPA * r
    s = side
    left = s < 0
    return doc("PointsPath",
               doc("CubicDetachedVertex", x=0.0, y=float(-r), inRotation=0.0, inDistance=0.0,
                   outRotation=math.pi if left else 0.0, outDistance=k),
               doc("CubicDetachedVertex", x=float(s * r), y=0.0, inRotation=-math.pi / 2, inDistance=k,
                   outRotation=math.pi / 2, outDistance=k),
               doc("CubicDetachedVertex", x=0.0, y=float(r), inRotation=math.pi if left else 0.0, inDistance=k,
                   outRotation=0.0, outDistance=0.0),
               isClosed=True, isClockwise=not left, name=name)


def moon_rig(sc: Scene, doc: Doc, cx: float, cy: float, r: float, lit: El, dark: str) -> El:
    """The phase of the moon (contract v12 `moonPhase`), a node `MoonRig` centred at (cx, cy) in its
    parent's frame:

    - `lit`: the caller's lit disc of radius `r`, drawn centred on the rig's origin (0, 0), at the back
      (e.g. `sc.E((cx, cy), "MoonLit", cx, cy, 2 * r, 2 * r, sc.F(colour))`, or a node with craters);
    - `MoonDark`, one shape in `dark` (the night sky's colour at 0.9 alpha: a new moon still shows as a
      faint disc) over it, `evenOdd`, holding two paths: the dark half on the unlit side and the
      terminator, a half ellipse of half-width r x cos(2 pi p) on the lit side of the diameter
      (both MOON_DARK_BLEED px wider than r, so the dark covers the lit disc's anti-aliased limb). At a
      crescent (cos > 0) the terminator adds to the dark half (a dark terminator); at a gibbous
      (cos < 0) it is mirrored into the dark half and even-odd cuts it out (a lit terminator), so the
      lit art shows through unchanged and the dark never overlaps itself (one layer of alpha).
      The shape is mirrored (scaleX -1) for p > 0.5: waxing is lit on the right (northern view).

    History-free: three formula converters on `moonPhase` (the terminator's scaleX, the mirror, the
    rig's opacity). At `moonPhase` -1 the rig's opacity is 0 and it draws nothing; at >= 0 it is 1 and
    the scene's M8 moon must be hidden (`hide_when_phased`). The flip at p = 0.5 happens where the
    dark region is ~0 wide, and p 0.99 -> 0.01 is continuous (a dark disc on both sides)."""
    f = Formulas(doc, sc.vpath)
    term = _formula(sc, doc, f.fn("cos", [f.val(2 * math.pi), f.op("*"), *f.inp()]))
    mirror = _formula(sc, doc, _clamp(f, -1, 1, [f.val(MOON_MIRROR_GAIN / 2), f.op("-"), f.val(MOON_MIRROR_GAIN),
                                                 f.op("*"), *f.inp()]))
    show = _formula(sc, doc, _clamp(f, 0, 1, [f.val(2), f.op("*"), *f.inp(), f.op("+"), f.val(2)]))
    rd = r + MOON_DARK_BLEED
    half = _half_disc(doc, rd, -1.0, "DarkHalf")
    terminator = _half_disc(doc, rd, 1.0, "Terminator")
    terminator.children.insert(0, _bind(sc, doc, "moonPhase", KEY_SCALE_X, term))
    terminator.attrs["scaleX"] = 1.0   # cos(2 pi x -1): the static value is the default's
    dark_shape = doc("Shape", _bind(sc, doc, "moonPhase", KEY_SCALE_X, mirror), half, terminator,
                     doc("Fill", doc("SolidColor", colorValue=dark), fillRule="evenOdd", name="Fill"),
                     x=0.0, y=0.0, name="MoonDark")
    return doc("Node", _bind(sc, doc, "moonPhase", KEY_OPACITY, show), dark_shape, lit,
               x=float(cx), y=float(cy), opacity=0.0, name="MoonRig")


def hide_when_phased(sc: Scene, doc: Doc, name: str, kids: list[El]) -> El:
    """A node `name` at identity wrapping the scene's M8 moon `kids`: opacity 1 at `moonPhase` -1 (the
    v11 look, pixel-identical) and 0 once a phase (>= 0) is written, when `moon_rig` takes over."""
    f = Formulas(doc, sc.vpath)
    conv = _formula(sc, doc, _clamp(f, 0, 1, [f.val(-1), f.op("-"), f.val(2), f.op("*"), *f.inp()]))
    return doc("Node", _bind(sc, doc, "moonPhase", KEY_OPACITY, conv), *kids, x=0.0, y=0.0, name=name)


# ====================================================================== December (ruling 13)
FESTIVE_TWINKLE_FRAMES = 240        # 4 s: each colour breathes once, the other in counter-phase
FESTIVE_LOW = 0.4                   # a bulb's dimmest opacity in the twinkle
FESTIVE_BULB_R = 9.0
FESTIVE_GLOW_R = 24.0
FESTIVE_WIRE = ("FF2A3328", 2.4)    # the string's colour and thickness


def festive_lights(sc: Scene, doc: Doc, points: list[tuple[float, float]], colours: tuple[str, str]) -> El:
    """A string of lights along `points` (artboard px in the parent's frame), a node `FestiveLights`:
    the wire (a smooth stroke through the points) and one bulb with a soft glow per point, alternating
    `colours[0]` / `colours[1]`. The two colours twinkle slowly in counter-phase (an ambient loop of
    `FESTIVE_TWINKLE_FRAMES`, a layer `FestiveTwinkle`); the node's opacity is `festive` (0 at the
    default: nothing drawn). The bulbs are `emit*` (light sources skip the colour-script fit); list
    `FestiveLights` in the scene's plane table."""
    f = Formulas(doc, sc.vpath)
    conv = _formula(sc, doc, _clamp(f, 0, 1, f.inp()))
    groups: list[list[El]] = [[], []]
    for i, (x, y) in enumerate(points):
        col = colours[i % 2]
        glow = doc("Shape", ellipse(doc, 2 * FESTIVE_GLOW_R, 2 * FESTIVE_GLOW_R),
                   doc("Fill", doc("RadialGradient",
                                   doc("GradientStop", colorValue="66" + col[2:], position=0.0),
                                   doc("GradientStop", colorValue="00" + col[2:], position=1.0),
                                   startX=0.0, startY=0.0, endX=FESTIVE_GLOW_R, endY=0.0), name="Fill"),
                   x=float(x), y=float(y), name=f"emitGlow{i}")
        bulb = doc("Shape", ellipse(doc, 2 * FESTIVE_BULB_R, 2 * FESTIVE_BULB_R * 1.25),
                   doc("Fill", doc("SolidColor", colorValue=col), name="Fill"),
                   x=float(x), y=float(y + FESTIVE_BULB_R * 0.6), name=f"emitBulb{i}")
        groups[i % 2] += [bulb, glow]
    nodes = [doc("Node", *g, x=0.0, y=0.0, name=f"emitBulbs{'AB'[k]}") for k, g in enumerate(groups)]
    wire = doc("Shape", smooth_path(doc, [(float(x), float(y)) for x, y in points], closed=False),
               stroke(doc, FESTIVE_WIRE[0], FESTIVE_WIRE[1]), x=0.0, y=0.0, name="FestiveWire")
    with sc.minting(doc):
        n = FESTIVE_TWINKLE_FRAMES
        lo = FESTIVE_LOW
        anim = sc.A("amb_festive", n, [sc.T(nodes[0], opacity=[(0, 1.0), (n // 2, lo), (n, 1.0)]),
                                       sc.T(nodes[1], opacity=[(0, lo), (n // 2, 1.0), (n, lo)])],
                    loop=True, seam_hold=True)
        sc.ambient("FestiveTwinkle", anim)
    return doc("Node", _bind(sc, doc, "festive", KEY_OPACITY, conv), *nodes, wire, x=0.0, y=0.0, opacity=0.0,
               name="FestiveLights")


# ====================================================================== trails (ruling 8)
def trail_dots(sc: Scene, doc: Doc, colour: str, highlight: str, r: float) -> El:
    """The 16 marks of a `trail` drag, a node `TrailDots` that must sit at its plane's origin (no
    parent offset: `trailX<i>` / `trailY<i>` are artboard px at parallax 0). Dot i (`TrailDot<i>`, a
    disc of radius `r` in `colour` with a small `highlight` up-left) sits at (`trailX<i>`, `trailY<i>`)
    and shows while i < `trailN` (opacity min(1, max(0, trailN - i))); the node's opacity is
    1 - `trailFade`. At the defaults (`trailN` 0, `trailFade` 1) nothing is drawn."""
    f = Formulas(doc, sc.vpath)
    fade = _formula(sc, doc, _clamp(f, 0, 1, [f.val(1), f.op("-"), *f.inp()]))
    dots = []
    for i in range(TRAIL_DOTS):
        shown = _formula(sc, doc, _clamp(f, 0, 1, [*f.inp(), f.op("-"), f.val(i)]))
        hi = doc("Shape", ellipse(doc, r * 0.7, r * 0.45), doc("Fill", doc("SolidColor", colorValue=highlight),
                                                                name="Fill"),
                 x=float(-r * 0.3), y=float(-r * 0.35), name="Highlight")
        disc = doc("Shape", ellipse(doc, 2 * r, 2 * r), doc("Fill", doc("SolidColor", colorValue=colour), name="Fill"),
                   x=0.0, y=0.0, name="Mark")
        dots.append(doc("Node", _bind(sc, doc, f"trailX{i}", KEY_X, None), _bind(sc, doc, f"trailY{i}", KEY_Y, None),
                        _bind(sc, doc, "trailN", KEY_OPACITY, shown), hi, disc,
                        x=0.0, y=0.0, opacity=0.0, name=f"TrailDot{i}"))
    return doc("Node", _bind(sc, doc, "trailFade", KEY_OPACITY, fade), *dots, x=0.0, y=0.0, opacity=0.0,
               name="TrailDots")
