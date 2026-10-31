"""Generates rive/scenes/<sceneId>/<sceneId>.rml (artboard `Scene`, see rive/CONTRACT.md).

Layout: 1080x1920 portrait. Phones crop the sides (cover), desktop landscape
crops top/bottom down to roughly y 650..1270, so anything that matters lives in
the centre band and props sit left/right of where the avatar stands.
"""

from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
import math
import os
import random
import sys
from typing import Callable, Iterator
import zlib

sys.path.insert(0, os.path.dirname(__file__))
if __name__ == "__main__":
    # run as a script: scene modules (`scene_cafe`, ...) `import gen_scenes` and must get this very module
    # (its registries: DIORAMAS, TIME_SKY ...), not a second copy
    sys.modules.setdefault("gen_scenes", sys.modules[__name__])
from rml import Doc, El, ellipse, fill, lin, rad, smooth_path, solid, stroke, track, write  # noqa: E402,F401
from scene_art import before, named, place_point, refine_scene, walk  # noqa: E402
from art_bible import EMISSIVE_PREFIX, SCENES, fit_colour  # noqa: E402
from rig_dsl import Formulas  # noqa: E402
import scene_npc  # noqa: E402
from scene_npc import scene_fog  # noqa: E402
import world_kit  # noqa: E402

W, H = 1080, 1920
SCENE_EVENTS = {
    "livingRoom": ["lightsOff", "lightsOn", "tvOn", "catWalksBy"],
    "campfire": ["flare", "rain", "shootingStar", "owlHoot"],
    "beach": ["bigWave", "seagulls", "sunset", "rain"],
    "deepSpace": ["meteor", "warp", "alienShip", "nebulaPulse"],
    # contract v12 (ruling 3): built by their own modules (world_kit.SCENE_MODULES, SCENE_BUILDERS)
    "cafe": ["espresso", "doorbell", "rain", "neonFlicker"],
    "rooftop": ["fireworks", "plane", "shootingStar", "windowsLit"],
    "mountainHut": ["snowfall", "flare", "aurora", "bell"],
    # contract v14 (M11 ruling 2): built by their own modules too
    "forestCabin": ["gust", "fireflies", "rain", "lanternFlicker"],
    "trainCompartment": ["tunnel", "whistle", "station", "rain"],
    "library": ["lightning", "bookFlutter", "clockChime", "rain"],
}


M4_ID_START = 980000  # elements added in moonshot M4 (each scene is its own document)
# The campfire diorama (M4 Task 6: planes, fog veils, parallax converters, firelight tracks) mints
# from its own range, so every element the M3/v7 campfire already had keeps its id.
DIORAMA_ID_START = 990000
# Moonshot M5 elements (rain binds, steam, the shared diorama's additions) mint from their own
# range per document (`Scene.d5`), so every M4 id stays.
M5_ID_START = 970000
# Moonshot M6: the `SceneFront` artboard (contract v9) mints from its own range per document.
M6_ID_START = 950000
# Moonshot M7: the time-of-day veils (contract v10 `daylight` / `dusk`) mint from their own range.
M7_ID_START = 940000
# Moonshot M8 (contract v11): `fog`, the NPC view-model numbers and every NPC element mint from their
# own range per document (`Scene.d8`, see scene_npc.py), so no M7 id moves.
M8_ID_START = 930000
# Moonshot M9 (contract v12): the v12 SceneVM members (world_kit.v12_members) and every v12 element mint
# from their own range per document (`Scene.d9`), so no M8 id moves. The v12 scenes mint from the same
# ranges as the others (each scene is its own document).
M9_ID_START = 920000
# The v12 members each M8 scene binds (world_kit.declared_binds; the v12 scenes declare theirs in their
# module's `BINDS`). Every scene declares all its v12 members; the unlisted ones are inert. `Scene.write`
# fails on a bind that is not listed here or a listed member nothing binds; check_contract.py rechecks
# the built file. Lane E fills these in as it binds them (ruling 19).
V12_BINDS: dict[str, frozenset[str]] = {
    "livingRoom": frozenset({"cord", "moonPhase", "festive"}),
    "campfire": frozenset({"moonPhase", "poke", "pokeX", "pokeY"}),
    "beach": frozenset({"npc2", "npc2X", "npc2Look", *world_kit.drag_numbers("beach")}),
    "deepSpace": frozenset({"spin"}),
}
# Moonshot M10 (contract v13): `night` (every scene declares it) and every M10 element (the café wipe's
# holes, the deepSpace band overlap, the beach's night, the rooftop's day lift) mint from their own range
# per document (`Scene.d10`), so no M9 id moves. The v12 scene modules mint from the same range.
M10_ID_START = 910000
# The v13 members each scene binds (world_kit.declared_v13_binds); the others declare `night` inertly.
V13_BINDS: dict[str, frozenset[str]] = {
    "beach": frozenset({"night"}),
}
# Moonshot M11 (contract v14): `tier`, `spring`, `autumn` (every scene declares them) and every M11
# element added to an existing scene (the tier gate, spring / autumn in livingRoom and campfire) mint
# from their own range per document (`Scene.d11`), so no M10 id moves. The v14 scene modules mint their
# v14 members from the same range (each scene is its own document).
M11_ID_START = 900000
# The v14 members the shared passes bind per scene (world_kit.declared_v14_binds unites this with a
# scene module's `BINDS14`); the others declare `tier`, `spring`, `autumn` inertly. Lane W fills it in
# (`tier` everywhere through the tier gate; `spring` / `autumn` in livingRoom and campfire).
V14_BINDS: dict[str, frozenset[str]] = {
    **{sid: frozenset({"tier"}) for sid in (*world_kit.BUILT_IN_SCENES, *world_kit.SCENE_MODULES)},
    # ruling 9: the seasons in two old scenes (the window sill, the clearing)
    "livingRoom": frozenset({"tier", "spring", "autumn"}),
    "campfire": frozenset({"tier", "spring", "autumn"}),
}
# M11 ruling 13 (contract v14 `tier`): the element roots (`world_kit.gate_root`: no `emit` prefix, no
# trailing digits) the shared tier pass (`world_kit.tier_gate`, run by `Scene.write`) hides per tier in the
# four M8 scenes ("high": hidden at high and low, "low": at low only); a scene module keeps its own
# `TIER_GATES`. Every fog veil also keeps one fill at low (the pass does that for any scene).
TIER_GATES: dict[str, dict[str, tuple[str, ...]]] = {
    "livingRoom": {
        # the second half of the window's rain streak columns, the city windows' blinks, the lamp's dust
        "high": (*(f"GlassStreak{i}_" for i in range(13, 26)), "GlassStreak13_-", "GlassStreak18_-",
                 "Lit10", "Lit11", "Lit13", "Lit14", "Lit16", "Lit17", *(f"LamplitDust{i}" for i in range(5, 9))),
        "low": ("LamplitDust",),
    },
    "campfire": {
        "high": ("RainSheet1", *(f"Splash{i}" for i in range(8, 16)), *(f"FrontSplash{i}" for i in range(5, 10)),
                 *(f"Star{i}" for i in range(35, 66, 5)), "Glint2", "Glint3", *(f"Spark{i}" for i in range(4, 8)),
                 "Firefly3", "Firefly4", *(f"SteamPlume{i}" for i in range(4, 7)), "WetCoalSteam2", "WetCoalSteam3"),
        "low": ("Smoke", "SteamPlume", "WetCoalSteam"),   # smoke and steam (the fire, its sparks and the flies are light)
    },
    "beach": {
        "high": ("RainSheet1", *(f"Splash{i}" for i in range(8, 16)), *(f"FrontSplash{i}" for i in range(5, 10)),
                 *(f"Glint{i}" for i in range(8, 16))),
        "low": ("Flyer",),   # the two far birds crossing the sky
    },
    "deepSpace": {
        "high": (*(f"Star{i}" for i in range(56, 105, 8)), *(f"TractorParticle{i}" for i in range(3, 6))),
        "low": ("TractorParticle",),   # the tractor beam's dust
    },
}
OUT_ROOT = os.path.join(os.path.dirname(__file__), "..", "scenes")  # tests point this at a tmp dir


def scene_vm_defaults(scene_id: str) -> list[tuple[str, str, object]]:
    """(name, type, default) of the v7/v8/v10 SceneVM numbers and colours, in contract order."""
    s = SCENES[scene_id]
    kx, ky = s.key_xy
    return [("parallaxX", "number", 0.0), ("parallaxY", "number", 0.0),
            ("lightKey", "color", s.key), ("lightKeyIntensity", "number", s.key_intensity),
            ("lightKeyX", "number", kx), ("lightKeyY", "number", ky), ("lightRim", "color", s.rim),
            ("lightRimIntensity", "number", s.rim_intensity), ("lightAmbient", "color", s.ambient),
            ("lightFog", "color", s.fog), ("lightFlicker", "number", s.flicker),
            ("rain", "number", 0.0), ("daylight", "number", 0.0), ("dusk", "number", 0.0)]


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
        self.ease_in = d("CubicEaseInterpolator", x1=0.6, y1=0.0, x2=0.9, y2=0.6)
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
        self._v7_props()
        self.d8 = Doc(client=0, start=M8_ID_START)
        self._v11_props()
        self.d9 = Doc(client=0, start=M9_ID_START)
        self._v12_props()
        self.d10 = Doc(client=0, start=M10_ID_START)
        self._v13_props()
        self.d11 = Doc(client=0, start=M11_ID_START)
        self._v14_props()
        # contract v12: the v12 members this scene binds (the others are declared and inert)
        self.binds: set[str] = set(world_kit.declared_binds(scene_id))
        # contract v13 (M10): the v13 members this scene binds (`night`: only the beach)
        self.binds13: set[str] = set(world_kit.declared_v13_binds(scene_id))
        # contract v14 (M11): the v14 members this scene binds (`tier`, `spring`, `autumn`)
        self.binds14: set[str] = set(world_kit.declared_v14_binds(scene_id))
        # M8 (contract v11): the scene's NPC rig, run on the refined content before the diorama pass
        # (`scene_npc.NPCS`), and the NPC's state enum (a root element after `EventId`).
        self.npc_rig: Callable[[Scene, list[El], list[El]], None] | None = None
        # M9 (contract v12): the scene's v12 art (drags, moon, December, gulls), run on the refined
        # content after the NPC rig and before the diorama pass; everything it adds mints from `d9`
        self.v12_art: Callable[[Scene, list[El], list[El]], None] | None = None
        # M10 (contract v13): the scene's v13 art, run on the planes after the diorama, sky-time and fog
        # passes (so it can sit in front of a plane's veils) and before the colour fit; mints from `d10`
        self.v13_art: Callable[[Scene, list[El]], None] | None = None
        # M11 (contract v14): the scene's seasonal art (`spring` / `autumn`), run on the planes after the
        # v13 art and before the colour fit; mints from `d11` (before the tier gate, which runs last)
        self.v14_art: Callable[[Scene, list[El]], None] | None = None
        # M4 dioramas: a hook run on the refined content (planes, veils), extra root elements
        # (converters), and the colour-script fit (ruling 13) for scenes rebuilt under the bible.
        self.post_refine: Callable[[list[El]], None] | None = None
        self.roots: list[El] = []
        self.fit = False
        self.d5 = Doc(client=0, start=M5_ID_START)
        self.d6 = Doc(client=0, start=M6_ID_START)
        self.d7 = Doc(client=0, start=M7_ID_START)
        # contract v9: (content, anims, layers) of the optional `SceneFront` artboard (front_weather)
        self.front: tuple[list[El], list[El], list[El]] | None = None
        self._convs: dict[tuple[float, float], El] = {}

    @contextmanager
    def minting(self, doc: Doc) -> Iterator[None]:
        """Every helper (S, E, F, T, A, ambient...) mints from `doc` inside the block, so a pass
        added late (M5) never shifts the ids the main document hands out afterwards."""
        main, self.d = self.d, doc
        try:
            yield
        finally:
            self.d = main

    def conv(self, k: float, c: float = 0.0, doc: Doc | None = None) -> El:
        """One shared `c + k x input` formula converter per (k, c), a root element (history-free
        bound transforms: parallax travel, rain opacity and scale)."""
        key = (round(k, 3), round(c, 3))
        if key not in self._convs:
            f = Formulas(doc or self.d5, self.vpath)
            head = [] if key[1] == 0 else [f.val(key[1]), f.op("+")]
            self._convs[key] = f.d("DataConverterFormula", *head, f.val(key[0]), f.op("*"), *f.inp())
            self.roots.append(self._convs[key])
        return self._convs[key]

    def bind(self, prop: str, key: int, conv: El | None = None, doc: Doc | None = None) -> El:
        """A `DataBindContext` child: SceneVM `prop` -> property `key` (13 x, 14 y, 16 scaleX,
        17 scaleY, 18 opacity), through `conv` if given."""
        return (doc or self.d5)("DataBindContext", sourcePathIds=self.vpath(prop), propertyKey=key,
                                converterId=conv.ref() if conv is not None else None)

    def _v7_props(self) -> None:
        """Contract v7 SceneVM numbers: `parallaxX`/`parallaxY` (default 0) and the scene's light rig
        as defaults (art_bible.SCENES, checked by check_contract.py). Minted from the M4 id range so
        no scene id moves; `self.vpath(name)` binds them."""
        d4 = self.d4 = Doc(client=0, start=M4_ID_START)
        self.v7: dict[str, El] = {}
        vals: list[El] = []
        for name, typ, default in scene_vm_defaults(self.id):
            if typ == "color":
                p = d4("ViewModelPropertyColor", name=name)
                vals.append(d4("ViewModelInstanceColor", propertyValue=default, viewModelPropertyId=p.ref()))
            else:
                p = d4("ViewModelPropertyNumber", name=name)
                vals.append(d4("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()))
            self.v7[name] = p
        at = self.vm.children.index(self.inst)
        self.vm.children[at:at] = list(self.v7.values())
        self.inst.children.extend(vals)

    def _v11_props(self) -> None:
        """Contract v11 SceneVM members, after `dusk` in contract order: `fog` (number), `npc` (enum
        `NpcState`, default rest), `npcX`, `npcLook` (numbers, default 0). Minted from `d8`."""
        from scene_npc import NPC_STATES  # noqa: PLC0415 (scene_npc imports this module)
        d8 = self.d8
        self.npc_vals = {v: d8("DataEnumValue", key=v, value=v) for v in NPC_STATES}
        self.npc_enum = d8("DataEnumCustom", *self.npc_vals.values(), name="NpcState")
        props, vals = [], []
        for name in ("fog", "npc", "npcX", "npcLook"):
            if name == "npc":
                p = d8("ViewModelPropertyEnumCustom", enumId=self.npc_enum.ref(), name=name)
                vals.append(d8("ViewModelInstanceEnum", propertyValue=self.npc_vals["rest"].ref(),
                               viewModelPropertyId=p.ref()))
            else:
                p = d8("ViewModelPropertyNumber", name=name)
                vals.append(d8("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=p.ref()))
            self.v7[name] = p
            props.append(p)
        at = self.vm.children.index(self.inst)
        self.vm.children[at:at] = props
        self.inst.children.extend(vals)

    def _v12_props(self) -> None:
        """Contract v12 SceneVM members after `npcLook`, in contract order (world_kit.v12_members):
        `npc2` (enum `NpcState`, default away), `npc2X`, `npc2Look`, `moonPhase` (-1), `festive` (0) and
        the scene's drag numbers (world_kit.DRAGS). Minted from `d9`, so no older id moves."""
        d9 = self.d9
        props, vals = [], []
        for name, typ, default in world_kit.v12_members(self.id):
            if typ == "enum":
                p = d9("ViewModelPropertyEnumCustom", enumId=self.npc_enum.ref(), name=name)
                vals.append(d9("ViewModelInstanceEnum", propertyValue=self.npc_vals[str(default)].ref(),
                               viewModelPropertyId=p.ref()))
            else:
                p = d9("ViewModelPropertyNumber", name=name)
                vals.append(d9("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()))
            self.v7[name] = p
            props.append(p)
        at = self.vm.children.index(self.inst)
        self.vm.children[at:at] = props
        self.inst.children.extend(vals)

    def _v13_props(self) -> None:
        """Contract v13 SceneVM members (world_kit.v13_members: `night`, default 0), after `festive` and
        before the scene's drag numbers (contract order). Minted from `d10`, so no older id moves."""
        d10 = self.d10
        drags = set(world_kit.drag_numbers(self.id))
        props, vals = [], []
        for name, _typ, default in world_kit.v13_members(self.id):
            p = d10("ViewModelPropertyNumber", name=name)
            vals.append(d10("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()))
            self.v7[name] = p
            props.append(p)
        kids = self.vm.children
        at = next((i for i, c in enumerate(kids) if c.attrs.get("name") in drags), kids.index(self.inst))
        kids[at:at] = props
        ikids = self.inst.children
        drag_ids = {self.v7[n].ref() for n in drags}
        at = next((i for i, c in enumerate(ikids) if c.attrs.get("viewModelPropertyId") in drag_ids), len(ikids))
        ikids[at:at] = vals

    def _v14_props(self) -> None:
        """Contract v14 SceneVM members (world_kit.v14_members): `tier` (enum `Tier`: low, high, ultra;
        default ultra, a root element after `NpcState`), `spring`, `autumn` (0), after `night` and before
        the scene's drag numbers (contract order). Minted from `d11`, so no older id moves."""
        d11 = self.d11
        self.tier_vals = {v: d11("DataEnumValue", key=v, value=v) for v in world_kit.TIER_VALUES}
        self.tier_enum = d11("DataEnumCustom", *self.tier_vals.values(), name="Tier")
        drags = set(world_kit.drag_numbers(self.id))
        props, vals = [], []
        for name, typ, default in world_kit.v14_members(self.id):
            if typ == "enum":
                p = d11("ViewModelPropertyEnumCustom", enumId=self.tier_enum.ref(), name=name)
                vals.append(d11("ViewModelInstanceEnum", propertyValue=self.tier_vals[str(default)].ref(),
                                viewModelPropertyId=p.ref()))
            else:
                p = d11("ViewModelPropertyNumber", name=name)
                vals.append(d11("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()))
            self.v7[name] = p
            props.append(p)
        kids = self.vm.children
        at = next((i for i, c in enumerate(kids) if c.attrs.get("name") in drags), kids.index(self.inst))
        kids[at:at] = props
        ikids = self.inst.children
        drag_ids = {self.v7[n].ref() for n in drags}
        at = next((i for i, c in enumerate(ikids) if c.attrs.get("viewModelPropertyId") in drag_ids), len(ikids))
        ikids[at:at] = vals

    def check_v12_binds(self, roots: list[El]) -> None:
        """The v12 members the file binds are exactly `self.binds`, the v13 ones exactly `self.binds13`,
        the v14 ones exactly `self.binds14` (the rest stay declared and inert)."""
        for label, members, want, where in (
                ("v12", world_kit.v12_members(self.id), self.binds, "gen_scenes.V12_BINDS or the scene module's BINDS"),
                ("v13", world_kit.v13_members(self.id), self.binds13, "gen_scenes.V13_BINDS"),
                ("v14", world_kit.v14_members(self.id), self.binds14,
                 "gen_scenes.V14_BINDS or the scene module's BINDS14")):
            names = {self.v7[n].ref(): n for n, _, _ in members}
            got = set()
            for r in roots:
                got |= world_kit.bound_names(r, self.vm.ref(), names)
            if got != want:
                raise ValueError(f"{self.id}: {label} binds {sorted(got)} != declared {sorted(want)} ({where})")

    def vpath(self, name: str) -> str:
        return f"{self.vm.ref()}-{self.v7[name].ref()}"

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
    def A(self, name: str, frames: int, tracks: list[El], loop: bool = False, seam_hold: bool = False) -> El:
        if seam_hold:
            # A one-frame rest at both ends prevents fractional advancement
            # from shifting a few antialiased edge pixels at the loop seam.
            for obj in tracks:
                for prop in obj.children:
                    first, last = prop.children[0], prop.children[-1]
                    if (len(prop.children) > 1 and first.attrs["frame"] == 0 and last.attrs["frame"] == frames
                            and math.isclose(float(first.attrs["value"]), float(last.attrs["value"]), abs_tol=1e-8)):
                        last.attrs["value"] = first.attrs["value"]
                        prop.children.insert(1, self.d(first.tag, **{**first.attrs, "frame": 1}))
                        prop.children.insert(-1, self.d(last.tag, **{**last.attrs, "frame": frames - 1}))
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

    def fit_colours(self, elements: list[El]) -> None:
        """Ruling 13: every colour passes through `art_bible.fit_colour(c, scene)`, except inside an
        emissive subtree (a node or shape named `emit*`: fire, sparks, glow, stars). Paints there are
        named `emit` too, so the line-based `art_bible.py lint` sees the exemption on their line."""
        def visit(e: El, emit: bool) -> None:
            emit = emit or str(e.attrs.get("name", "")).startswith(EMISSIVE_PREFIX)
            if e.tag in ("SolidColor", "GradientStop"):
                if emit:
                    e.attrs["name"] = EMISSIVE_PREFIX
                else:
                    e.attrs["colorValue"] = fit_colour(str(e.attrs["colorValue"]), self.id)
            for c in e.children:
                visit(c, emit)
        for e in elements:
            visit(e, False)

    def write(self, content: list[El], hits: list[El]) -> str:
        refine_scene(self, content)
        if self.post_refine is not None:
            self.post_refine(content)
        if self.npc_rig is not None:
            self.npc_rig(self, content, hits)
        if self.v12_art is not None:
            self.v12_art(self, content, hits)
        spec = DIORAMAS.get(self.id)
        if spec is not None:
            # M5 ruling 3: hit zones ride the plane of the art they cover
            content[0:0] = hits
            hits = []
            diorama(self, content, spec)
            sky_time(self, content)
            scene_fog(self, content)
        if self.v13_art is not None:
            self.v13_art(self, content)
        if self.v14_art is not None:
            self.v14_art(self, content)
        if self.fit or spec is not None:
            self.fit_colours([*hits, *content])
        if "tier" in self.binds14:
            # M11 ruling 13: the tier gate, last (minted from d11 after every other M11 element)
            front_content, front_anims = (self.front[0], self.front[1]) if self.front is not None else ([], [])
            self.tier_report = world_kit.tier_gate(self, self.d11, [content, front_content],
                                                   [*self.anims, *front_anims], world_kit.tier_gates(self.id))
        d = self.d
        sm = d("StateMachine", *self.listeners, *self.layers, name="Main")
        style = d("LayoutComponentStyle", name="Artboard Style")
        ab = d("Artboard", style, sm, self.ease, self.ease_out, self.ease_in, *self.events, *hits, *content, *self.anims,
               width=float(W), height=float(H), name="Scene", defaultStateMachineId=sm.ref(),
               viewModelId=self.vm.ref(), viewModelInstanceId=self.inst.ref(), styleId=style.ref(), clip=True)
        boards = [ab]
        if self.front is not None:
            boards.append(self._front_artboard())
        self.check_v12_binds([*boards, *self.roots])
        out = os.path.join(OUT_ROOT, self.id, self.id + ".rml")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        write(out, [*boards, self.enum, self.npc_enum, self.tier_enum, self.vm, *self.roots])
        with open(os.path.join(os.path.dirname(out), "rive.yaml"), "w") as f:
            f.write(f"name: {self.id}\nmain: Scene\noutput: {{dir: build}}\n"
                    "logs: {file: build/rive.log, problems: build/problems.log}\n")
        return os.path.normpath(out)


    def _front_artboard(self) -> El:
        """Contract v9 `SceneFront`: the weather in front of the avatar, same `SceneVM`, its own `Main`
        state machine of ambient loops, no listeners or events. Colours go through the scene's fit."""
        content, anims, layers = self.front
        self.fit_colours(content)
        d = self.d6
        sm = d("StateMachine", *layers, name="Main")
        style = d("LayoutComponentStyle", name="Artboard Style")
        return d("Artboard", style, sm, *content, *anims, x=float(W + 200), y=0.0, width=float(W), height=float(H),
                 name="SceneFront", defaultStateMachineId=sm.ref(), viewModelId=self.vm.ref(),
                 viewModelInstanceId=self.inst.ref(), styleId=style.ref(), clip=True)


def uniq(keys: list) -> list:
    """Sort keyframes by frame, first key wins on a duplicate frame."""
    seen: dict[int, tuple] = {}
    for k in keys:
        seen.setdefault(k[0], k)
    return [seen[f] for f in sorted(seen)]


def rain_fx(sc: Scene, name: str, col: str, frames: int = 480, extra: list[El] | None = None,
            darken: str = "FF0A1022", ground: tuple[float, float] = (1200.0, 1900.0), loop: bool = False,
            periods: tuple[int, int] = (18, 34)) -> tuple[El, El]:
    """Returns (content node, one-shot anim): fade in, two depth layers of falling rain (near:
    long, fast, bright; far: short, slow, faint), splashes popping on the ground, fade out.

    `loop` (M5 steady rain): returns (node `name`, the splashes' looping anim) instead: the streaks
    and splashes only, no fade and no darkening; each streak sheet gets its own `period`-frame loop
    layer, the splashes loop over `frames`; the caller binds the node's opacity."""
    d = sc.d
    r = random.Random(zlib.crc32(name.encode()))
    tile = 480                      # pattern repeats every `tile` px, so a `tile` shift loops seamlessly
    sheets, tracks = [], []
    for layer, (n, ln0, ln1, wd, alpha, period) in enumerate([(22, 70, 120, 3.2, "FF", periods[0]),
                                                              (34, 26, 50, 1.8, "70", periods[1])]):
        streaks = []
        for i in range(n):
            x, y = r.uniform(-60, W + 60), r.uniform(0, tile)
            ln = r.uniform(ln0, ln1)
            for k in range(-1, H // tile + 1):
                streaks.append(sc.S((0, 0), f"Drop{layer}_{i}_{k + 1}", [(x, y + k * tile),
                                                                         (x - ln * 0.22, y + k * tile + ln)],
                                    sc.L(alpha + col[2:], wd), closed=False))
        sheet = d("Node", *streaks, x=0.0, y=0.0, name=f"RainSheet{layer}")
        sheets.append(sheet)
        if loop:
            # its own `period`-frame loop, one tile per cycle: the wrap (tile == 0) is the
            # animation's, so no fractional frame ever sweeps the sheet back up the tile
            sc.ambient(f"{name}Sheet{layer}", sc.A(f"amb_{name}Sheet{layer}", period,
                                                   [sc.T(sheet, ease=None, y=[(0, 0.0, "linear"),
                                                                              (period, float(tile), "linear")])],
                                                   loop=True))
            continue
        saw = []
        for c in range(0, frames, period):
            saw += [(c, 0.0, "linear"), (min(c + period - 1, frames), tile * (period - 1) / period, "linear")]
        tracks.append(sc.T(sheet, ease=None, y=uniq(saw)))
    splashes = []
    for i in range(16):
        x, y = r.uniform(40, W - 40), r.uniform(*ground)
        sp = d("Node", sc.E((x, y), "Ring", x, y, 30, 8, sc.L("C0" + col[2:], 2)),
               sc.S((x, y), "Kick", [(x - 8, y - 2), (x - 12, y - 14)], sc.L("A0" + col[2:], 2), closed=False),
               sc.S((x, y), "Kick2", [(x + 8, y - 2), (x + 12, y - 14)], sc.L("A0" + col[2:], 2), closed=False),
               x=x, y=y, opacity=0.0, name=f"Splash{i}")
        splashes.append(sp)
        ph = r.randint(0, 40)
        op, sxk = [(0, 0.0)], [(0, 0.3)]
        for c in (range(1 + ph, frames - 13, 44) if loop else range(40 + ph, frames - 50, 44)):
            op += [(c, 0.0, "hold"), (c + 1, 1.0), (c + 12, 0.0, "hold")]
            sxk += [(c, 0.3, "hold"), (c + 1, 0.4), (c + 12, 1.3, "hold")]
        tracks.append(sc.T(sp, ease=None, opacity=uniq(op + [(frames, 0.0)]),
                           scaleX=uniq(sxk + [(frames, 0.3)]), scaleY=uniq(sxk + [(frames, 0.3)])))
    if loop:
        return d("Node", *splashes, *sheets, x=0.0, y=0.0, name=name), sc.A("amb_" + name, frames, tracks, loop=True)
    dark = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
             sc.vgrad(0, H, [(darken, 0.0), ("80" + darken[2:], 1.0)]), opacity=0.0, name="RainDark")
    group_ = d("Node", *splashes, *sheets, x=0.0, y=0.0, opacity=0.0, name=name)
    anim = sc.A("ev_" + name, frames, [
        sc.T(group_, ease=None, opacity=[(0, 0.0), (40, 1.0, "linear"), (frames - 60, 1.0, "linear"), (frames, 0.0)]),
        sc.T(dark, ease=None, opacity=[(0, 0.0), (40, 0.5, "linear"), (frames - 60, 0.5, "linear"), (frames, 0.0)]),
        *tracks,
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


def bird(sc: Scene, name: str, x: float, y: float, sz: float, col: str, body: bool = False,
         phase: int = 0) -> tuple[El, list[El]]:
    """Flapping gull; returns node + its flap tracks. `body` draws a white gull (wings + body)."""
    lw = 4 if not body else max(4.0, sz * 0.09)
    wcol = col if not body else "FFDDE3EA"
    wl = sc.S((x, y), "WingL", [(x, y), (x - sz * 0.5, y - sz * 0.35), (x - sz, y - sz * 0.05)], sc.L(wcol, lw),
              closed=False, origin=(x, y))
    wr = sc.S((x, y), "WingR", [(x, y), (x + sz * 0.5, y - sz * 0.35), (x + sz, y - sz * 0.05)], sc.L(wcol, lw),
              closed=False, origin=(x, y))
    kids = [wl, wr]
    if body:
        tips = [sc.S((x, y), "TipL", [(x - sz * 0.72, y - sz * 0.2), (x - sz, y - sz * 0.05)], sc.L("FF2A3040", lw),
                     closed=False), sc.S((x, y), "TipR", [(x + sz * 0.72, y - sz * 0.2), (x + sz, y - sz * 0.05)],
                                         sc.L("FF2A3040", lw), closed=False)]
        kids = [sc.E((x, y), "GBodyF", x + sz * 0.1, y + 2, sz * 0.62, sz * 0.2, sc.F("FFFFFFFF"), sc.L("FF8A94A2", 1.5)),
                sc.S((x, y), "GBeakF", [(x + sz * 0.4, y), (x + sz * 0.52, y + 2), (x + sz * 0.4, y + 5)],
                     sc.F("FFF0B030")), wl, wr]
        for t, w in zip(tips, (wl, wr)):          # dark wing tips ride the wing's flap
            t.attrs["x"] = float(t.attrs["x"]) - float(w.attrs["x"])
            t.attrs["y"] = float(t.attrs["y"]) - float(w.attrs["y"])
            w.add(t)
    n = sc.d("Node", *kids, x=float(x), y=float(y), name=name)
    P = 24 if not body else 28
    p0 = phase % P
    keys_l = uniq([(0, -0.25), ((P // 2 + p0) % P, -0.6), (p0, 0.15), (P, -0.25)]) if body else \
        [(0, 0.0), (12, -0.5), (24, 0.0)]
    flap = [sc.T(wl, rotation=keys_l), sc.T(wr, rotation=[(f, -v) for f, v in keys_l])]
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
    fire_c = (196.0, 1124.0)       # left of the avatar's head, so flares read in the app
    ground = S(O, "Ground", [(-60, 1060), (300, 1040), (700, 1050), (1140, 1070), (1140, 1960, "c"),
                             (-60, 1960, "c")],
               sc.vgrad(-400, 400, [("FF2A2338", 0.0), ("FF1C1726", 1.0)]))
    light_pool = E(O, "LightPool", fire_c[0], fire_c[1] + 50, 1000, 1000,
                   sc.rgrad(500, [("B4FF9A3C", 0.0), ("50FF7A2A", 0.45), ("00FF7A2A", 1.0)]), scaleY=0.42)
    # rim light on the nearest trees from the fire
    tree_glow = E(O, "TreeGlow", fire_c[0] - 120, fire_c[1] - 260, 700, 700,
                  sc.rgrad(350, [("48FF8A3A", 0.0), ("00FF8A3A", 1.0)]))
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
        # Convex belly, narrow neck and a concave, wind-curled tip. The right
        # edge folds back into the tongue rather than forming a straight wedge.
        pts = [(fx + dx - w / 2, fy + 10),
               (fx + dx - w * 0.55, fy - h * 0.25),
               (fx + dx - w * 0.22, fy - h * 0.52),
               (fx + dx - w * 0.32, fy - h * 0.72),
               (fx + dx + lean - w * 0.02, fy - h),
               (fx + dx + lean + w * 0.16, fy - h * 0.90),
               (fx + dx + lean + w * 0.08, fy - h * 0.78),
               (fx + dx + w * 0.04, fy - h * 0.62),
               (fx + dx + w * 0.22, fy - h * 0.73),
               (fx + dx + w * 0.38, fy - h * 0.82),
               (fx + dx + w * 0.32, fy - h * 0.60),
               (fx + dx + w * 0.50, fy - h * 0.32),
               (fx + dx + w / 2, fy + 10)]
        shp = S((fx + dx, fy + 10), name, pts, d("Fill", lin(d, 0, 0, 0, -h, cols), name="Fill"),
                origin=(fx + dx, fy + 10))
        return d("Node", shp, x=float(dx), y=0.0, name=name + "Pivot")

    OUTER = [("FFE0401E", 0.0), ("FFF2652A", 0.5), ("CCF2652A", 1.0)]
    MIDC = [("FFF79A2A", 0.0), ("FFFFB640", 1.0)]
    INNER = [("FFFFF0B0", 0.0), ("FFFFD666", 1.0)]
    tongues = [
        tongue("Core", 0, 110, 56, INNER, 4),
        tongue("MidL", -22, 160, 70, MIDC, -10), tongue("MidR", 24, 150, 64, MIDC, 12),
        tongue("Main", -8, 235, 98, OUTER, 26), tongue("OuterL", -48, 144, 66, OUTER, -35),
        tongue("OuterR", 52, 184, 70, OUTER, 30),
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
    # every tongue flickers on its own prime-ish period, so the fire never pulses as one
    periods = [37, 53, 43, 71, 47, 61]
    for i, tg in enumerate(tongues):
        P = periods[i]
        r_ = random.Random(100 + i)
        amp = 0.05 + 0.02 * (i % 3)
        n = 4 if P < 50 else 5
        fs = [0] + sorted(r_.sample(range(4, P - 3), n - 1)) + [P]
        rot = [(f, 0.0 if f in (0, P) else r_.uniform(-amp, amp)) for f in fs]
        sy = [(f, 1.0 if f in (0, P) else r_.uniform(0.86, 1.16)) for f in fs]
        sx = [(f, 1.0 if f in (0, P) else r_.uniform(0.9, 1.06)) for f in fs]
        # Heat travels up the contour: anchored roots, delayed bends through
        # the belly, and a faster curling tip. Scaling one rigid tongue alone
        # reads as a row of paper cut-outs rather than a turbulent flame.
        contour = next(c for c in tg.children[0].children if c.tag == "PointsPath")
        deform = []
        samples = sorted(set(range(0, P, 3)) | {P})
        for j, vertex in enumerate(contour.children[1:-1], 1):
            vx, vy = float(vertex.attrs["x"]), float(vertex.attrs["y"])
            height = -vy / 260
            phase = i * 0.73 - height * 2.4
            def bend(f: int, phase: float = phase) -> float:
                t = 2 * math.pi * f / P
                return math.sin(t + phase) - math.sin(phase) + 0.28 * (math.sin(2 * t + phase) - math.sin(phase))
            deform.append(sc.T(vertex, ease=None,
                x=[(f, vx + (13 + i % 3 * 4) * height * bend(f), "linear") for f in samples],
                y=[(f, vy + 12 * height * (math.cos(2 * math.pi * f / P + phase) - math.cos(phase)), "linear")
                   for f in samples]))
        sc.ambient(f"Flame{i}", sc.A(f"amb_flame{i}", P,
                   [sc.T(tg, rotation=rot, scaleY=sy, scaleX=sx), *deform], loop=True))
    fl_keys = CAMPFIRE_FLICKER
    fl_tracks = [sc.T(glow, opacity=fl_keys,
                      scaleX=[(0, 1.0), (40, 1.05), (89, 1.0)], scaleY=[(0, 1.0), (40, 1.05), (89, 1.0)])]
    firelight = sc.A("amb_firelight", 89, fl_tracks, loop=True)
    sc.ambient("FireLight", firelight)
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

    # Small pieces of hot gas shear off and dissolve above the main contour.
    # Every reset happens at zero opacity, with staggered cycles.
    fragments, fragment_tracks = [], []
    for i in range(3):
        fragment = S((0.0, 0.0), f"DetachedFlame{i}", [(-8, 0), (-13, -17), (-3, -30), (10, -50),
                                                                    (8, -28), (11, -12), (5, 0)],
                     sc.vgrad(-25, 25, [("80FFA947", 0), ("E0FFCC61", 0.6), ("60F47C33", 1)]),
                     origin=(0.0, 0.0), opacity=0.0)
        fragments.append(fragment)
        phases = [(f, ((f + i * 60) % 180) / 180) for f in range(0, 181, 3)]
        fragment_tracks.append(sc.T(fragment, ease=None,
            x=[(f, -18 + i * 20 + 26 * math.sin(t * 3.5 + i), "linear") for f, t in phases],
            y=[(f, -150 - t * 220, "linear") for f, t in phases],
            scaleX=[(f, 0.45 + 0.5 * math.sin(math.pi * t), "linear") for f, t in phases],
            scaleY=[(f, 0.5 + 0.5 * math.sin(math.pi * t), "linear") for f, t in phases],
            rotation=[(f, 0.2 + 0.5 * math.sin(t * 4 + i), "linear") for f, t in phases],
            opacity=[(f, math.sin(math.pi * t) ** 2 * 0.9, "linear") for f, t in phases]))
    sc.ambient("DetachedFlames", sc.A("amb_detached_flames", 180, fragment_tracks, loop=True))
    fire.add(*sparks, *fragments, *tongues, glow)
    # flare scales its own wrapper (the rain layer owns `fire`'s scale; two layers on one
    # property means the later layer's rest pose silently wins)
    fire.attrs.update(x=0.0, y=0.0)
    fire_flare = d("Node", fire, x=fx, y=fy + 10, name="FireFlare")
    flare_wash = d("Shape", d("Rectangle", width=float(W + 40), height=float(H + 40), originX=0.0, originY=0.0,
                              name="Path"), sc.rgrad(1300, [("FFFFB060", 0.0), ("00FF8030", 1.0)], cx=fx - W / 2,
                                                     cy=fy - H / 2),
                   x=-20.0, y=-20.0, opacity=0.0, name="FlareWash")

    # ---- events
    flare = sc.A("ev_flare", 130, [
        sc.T(fire_flare, scaleX=[(0, 1.0), (5, 0.9), (14, 1.55), (24, 1.42), (70, 1.3), (130, 1.0)],
             scaleY=[(0, 1.0), (5, 0.85), (12, 2.1), (22, 1.75), (40, 1.85), (70, 1.5), (130, 1.0)]),
        sc.T(flare_wash, opacity=[(0, 0.0), (12, 0.34), (30, 0.2), (130, 0.0)]),
        sc.T(light_pool, scaleX=[(0, 1.0), (12, 1.45), (130, 1.0)], scaleY=[(0, 0.42), (12, 0.6), (130, 0.42)]),
    ])
    # The pressure burst splits into short-lived jets and ballistic embers;
    # they detach from the scaling flame so the apex does not remain a stamp.
    flare_bits = []
    for i in range(10):
        launch = 10 + i * 2
        life = 44 + i * 3
        direction = -1 if i % 2 else 1
        bit = S(O, f"FlareEmber{i}", [(-2, 0), (-4, -9), (0, -19), (4, -7), (2, 0)],
                sc.vgrad(-10, 10, [("FFFFF1B0", 0), ("FFFFA246", 1)]), origin=O, opacity=0.0)
        flare_bits.append(bit)
        frames = sorted({0, launch, launch + 3, launch + life, 130, *range(launch, launch + life, 3)})
        def age(f: int) -> float:
            return max(0.0, min(1.0, (f - launch) / life))
        flare.add(sc.T(bit,
            x=[(f, direction * (8 + i * 2 + (55 + 6 * i) * (1 - math.exp(-2 * age(f)))), "linear") for f in frames],
            y=[(f, -130 - (390 + i * 15) * age(f) + 110 * age(f)**2, "linear") for f in frames],
            rotation=[(f, direction * (0.2 + age(f) * 0.9), "linear") for f in frames],
            scaleY=[(f, 1.2 - 0.85 * age(f), "linear") for f in frames],
            opacity=[(f, (min(1.0, age(f) * 12) * (1 - age(f))**0.7) if launch <= f <= launch + life else 0.0,
                      "linear") for f in frames]))
    fire.children[0:0] = flare_bits
    sc.one_shot("flare", flare)

    rain_node, rain_anim = rain_fx(sc, "Rain", "88B8C8F0", extra=[
        sc.T(fire, scaleX=[(0, 1.0), (60, 0.75), (400, 0.75), (480, 1.0)], scaleY=[(0, 1.0), (60, 0.6), (400, 0.6),
                                                                                     (480, 1.0)]),
        sc.T(light_pool, opacity=[(0, 1.0), (60, 0.5), (400, 0.5), (480, 1.0)])])
    sc.one_shot("rain", rain_anim)
    star_node, star_anim = streak_fx(sc, "ShootingStar", (120, 180), (760, 520), 46, 260, "FFFFF6D0", "CCFFF6D0", 7)
    sc.one_shot("shootingStar", star_anim)

    # owl on a branch of the left pine
    # the owl perches on a bough growing out of the right-hand pine, silhouetted beside the moon
    ox_, oy_ = 884.0, 704.0
    branch = S(O, "Branch", [(958, 740), (900, 752), (842, 748), (816, 738), (840, 760), (902, 766), (962, 758)],
               F("FF140F1E"))
    owl = d("Node", x=ox_, y=oy_, name="Owl")
    OW = (ox_, oy_)
    eyes_ = []
    for k, ex in enumerate((-15, 15)):
        lid = E(OW, f"OwlLid{k}", ox_ + ex, oy_ - 18, 26, 26, F("FF6A4A32"), scaleY=0.0)
        eyes_ += [lid, E(OW, f"OwlPupil{k}", ox_ + ex, oy_ - 18, 10, 12, F("FF140C08")),
                  E(OW, f"OwlEye{k}", ox_ + ex, oy_ - 18, 24, 24, F("FFF2C230"), L("FF3A2414", 2))]
    owl.add(*eyes_,
            beak := S(OW, "Beak", [(ox_ - 6, oy_ - 7), (ox_ + 6, oy_ - 7), (ox_, oy_ + 7, "c")], F("FFD8A040"),
                      origin=(ox_, oy_ - 7)),
            S(OW, "Face", [(ox_ - 34, oy_ - 18), (ox_, oy_ - 40), (ox_ + 34, oy_ - 18), (ox_, oy_ + 6)], F("FFB08860")),
            chest := S(OW, "Chest", [(ox_ - 18, oy_ + 4), (ox_ + 18, oy_ + 4), (ox_ + 14, oy_ + 42),
                                     (ox_ - 14, oy_ + 42)], F("FFC8A478"), origin=(ox_, oy_ + 42)),
            S(OW, "OwlBody", [(ox_ - 34, oy_ - 40, "c"), (ox_ - 18, oy_ - 30), (ox_ + 18, oy_ - 30), (ox_ + 34, oy_ - 40, "c"),
                              (ox_ + 40, oy_), (ox_ + 30, oy_ + 46), (ox_, oy_ + 54), (ox_ - 30, oy_ + 46), (ox_ - 40, oy_)],
              sc.vgrad(-50, 50, [("FF8A6444", 0.0), ("FF4A3220", 1.0)]), L("FF20140C", 2.5)))
    lids = [c for c in eyes_ if c.attrs["name"].startswith("OwlLid")]
    sc.ambient("OwlBlink", sc.A("amb_owl", 300, [sc.T(l_, ease=None, scaleY=[(0, 0.0), (200, 0.0), (205, 1.0),
                                                                              (212, 0.0), (300, 0.0)]) for l_ in lids],
                                loop=True))
    # a dead snag gives the owl's bough a trunk
    snag = S(O, "OwlSnag", [(906, 1100, "c"), (916, 860), (924, 700), (930, 620), (942, 626), (944, 720), (952, 900),
                            (964, 1100, "c")], F("FF0C1D22"))
    twig = S(O, "OwlTwig", [(930, 680), (962, 646), (976, 640)], L("FF0C1D22", 5), closed=False)
    hoots = [E(O, f"Hoo{k}", ox_ - 50, oy_ - 40, 40 - k * 6, 40 - k * 6, L("DDFFF2D0", 4 - k * 0.8), opacity=0.0)
             for k in range(3)]
    hoot = sc.A("ev_owlHoot", 150, [
        sc.T(owl, scaleY=[(0, 1.0), (8, 0.92), (16, 1.08), (28, 1.0), (52, 0.92), (60, 1.08), (72, 1.0), (150, 1.0)],
             rotation=[(0, 0.0), (14, -0.14), (40, -0.1), (60, -0.16), (100, -0.12), (130, 0.0), (150, 0.0)],
             y=[(0, oy_), (14, oy_ - 6), (28, oy_), (60, oy_ - 6), (72, oy_), (150, oy_)]),
        sc.T(beak, scaleY=[(0, 1.0), (10, 1.0), (14, 1.9), (26, 1.0), (56, 1.0), (60, 1.9), (72, 1.0), (150, 1.0)]),
        sc.T(chest, scaleY=[(0, 1.0), (8, 1.0), (16, 1.14), (30, 1.0), (54, 1.0), (62, 1.14), (76, 1.0), (150, 1.0)]),
        *[sc.T(h, x=[(0, ox_ - 50.0), (14 + 10 * k, ox_ - 50.0), (80 + 15 * k, ox_ - 120.0 - 30 * k)],
               y=[(0, oy_ - 40.0), (14 + 10 * k, oy_ - 40.0), (80 + 15 * k, oy_ - 130.0 - 30 * k)],
               scaleX=[(0, 0.5), (14 + 10 * k, 0.5), (80 + 15 * k, 1.8)], scaleY=[(0, 0.5), (14 + 10 * k, 0.5), (80 + 15 * k, 1.8)],
               opacity=[(0, 0.0), (14 + 10 * k, 0.0), (18 + 10 * k, 1.0), (80 + 15 * k, 0.0), (150, 0.0)])
          for k, h in enumerate(hoots)],
    ])
    sc.one_shot("owlHoot", hoot)

    # ---- props
    hit_fire = sc.hit("fire", fx, fy - 80, 300, 320)
    sc.prop("fire", hit_fire)
    hit_tent = sc.hit("tent", *place_point("campfire", "TentPlace", 840, 990), 300, 220)
    sc.prop("tent", hit_tent)
    hit_owl = sc.hit("owl", ox_, oy_, 110, 130)
    sc.prop("owl", hit_owl)
    hit_sky = sc.hit("sky", W / 2, 330, W, 660)
    sc.prop("sky", hit_sky)

    # moon_cut must paint over the moon to carve the crescent; craters on the lit part
    content = [rain_node, flare_wash, fg[0], fg[1], *stones_front, *logs, fire_flare, *smoke, *stones_back, tent, *grass, tree_glow,
               light_pool, fg[2], ground, *hoots, owl, branch, twig, snag,
               *near_trees, mid, *far_trees, far, star_node, *craters, moon, moon_glow, *stars, sky]
    sc.fit = True
    front_weather(sc, "88B8C8F0")  # M6 ruling 8: the campfire RainLoop colour
    sc.npc_rig = scene_npc.campfire_owl   # M8: the owl (contract v11)
    sc.v12_art = campfire_v12             # M9: the poke stick, the moon's phase (contract v12)
    sc.v14_art = campfire_seasons         # M11: spring flowers, autumn leaves and rust ferns (contract v14)
    return sc.write(content, [hit_fire, hit_tent, hit_owl, hit_sky])


# ====================================================================== dioramas
# The shared diorama pass (M4 ruling 14, M5 rulings 2-3): six parallax planes, back to front, and
# the gain of each. A scene becomes a diorama by registering a `DioramaSpec` in `DIORAMAS`.
PARALLAX_GAINS = (0.0, 0.15, 0.3, 0.5, 0.7, 1.0)
PARALLAX_TRAVEL = (40.0, 24.0)  # px of x / y travel at gain 1 and parallaxX / parallaxY = +-1
# Fog veils in front of Plane0..2 (ruling 14): (fog density, y where the veil starts clear, y where
# it reaches the full density). `lightFog`'s own alpha (0x33 for the campfire) would multiply a
# single fill down to 0.11 / 0.07 / 0.04, which does not read: each veil stacks FOG_FILLS bound
# fills (1 - (1 - a)^n) and takes the opacity that makes the stack reach the density at the default
# fog (`fog_opacity`). Another fog colour scales the veils with it, and alpha 0 removes them.
FOG_FILLS = 4
HIT_PREFIX = "Hit_"


def fog_opacity(density: float, fog: str, fills: int = FOG_FILLS) -> float:
    """The veil opacity at which `fills` stacked fills of `fog` reach `density` (at most 1)."""
    a = int(fog[:2], 16) / 255
    stack = 1 - (1 - a) ** fills
    return round(min(1.0, density / stack), 3) if stack > 0 else 0.0


@dataclass(frozen=True)
class DioramaSpec:
    """What makes a scene a diorama (M5 ruling 2).

    - `planes`: top-level element name without its index digits (`Star12` -> `Star`) -> plane 0..5
      (0 the sky, 5 the foreground), or `None` for a screen-space overlay (rain, a flash wash) that
      stays in front of every plane. A full name (`Asteroid0`) overrides its root. Hit zones are
      listed by full name (`Hit_fire`) in the plane of the art they cover (ruling 3). An unlisted top-level element raises `KeyError`.
    - `emissive`: name roots of light sources; they and everything below them are renamed `emit*`
      and skip the colour-script fit (M4 ruling 13).
    - `veils`: (density, y clear, y full) of the `lightFog` veil in front of Plane0, Plane1, ...;
      a fourth value (y clear again) makes the veil a band that fades out below `y full` too
      (the beach's horizon haze) instead of staying full down to the bottom.
    - `light`: the scene's own pass, run first on the refined content with the diorama's Doc
      (firelight, lamp pool, rain binds). Elements it adds need a plane entry too; new elements
      should mint from `sc.d5` (`with sc.minting(sc.d5)`), shared converters from `sc.conv`.
    """

    planes: dict[str, int | None]
    emissive: tuple[str, ...]
    veils: tuple[tuple[float, ...], ...]
    light: Callable[[Scene, list[El], Doc], None] | None = None


def _root(name: object) -> str:
    return str(name).rstrip("0123456789")


def plane_of(spec: DioramaSpec, name: str) -> int | None:
    """The plane `spec` gives a top-level element (-1 when unlisted): its full name if listed (one
    of deepSpace's asteroids), else its root; an `emit` prefix is ignored."""
    bare = name.removeprefix(EMISSIVE_PREFIX)
    return spec.planes.get(bare, spec.planes.get(_root(bare), -1))


def diorama(sc: Scene, content: list[El], spec: DioramaSpec) -> None:
    """Regroups the refined top-level `content` (front-most first, hit zones included) into
    Plane5..Plane0 behind the screen overlays, binds each plane to `parallaxX/Y`, adds the fog veils,
    runs the scene's light hook and names the light sources `emit*`. Minted from DIORAMA_ID_START
    (so the M4 campfire keeps its ids); the hook's own additions mint from the M5 range."""
    d6 = Doc(client=0, start=DIORAMA_ID_START)
    pre = len(sc.roots)
    if spec.light is not None:
        spec.light(sc, content, d6)
    late = sc.roots[pre:]   # the hook's converters go after the parallax ones in the file
    del sc.roots[pre:]

    for e in walk(content):
        if e.tag in ("Shape", "Node") and _root(e.attrs.get("name")) in spec.emissive:
            for x in walk([e]):
                if x.tag in ("Shape", "Node") and not str(x.attrs.get("name", "")).startswith(EMISSIVE_PREFIX):
                    x.attrs["name"] = EMISSIVE_PREFIX + str(x.attrs.get("name", ""))

    groups: dict[int | None, list[El]] = {}
    hits: dict[int, list[El]] = {}
    order: list[int | None] = []
    for e in content:
        name = str(e.attrs.get("name", ""))
        if name.startswith(HIT_PREFIX):
            k = spec.planes.get(name, -1)
            if k is None or k == -1:
                raise KeyError(f"{sc.id} hit zone {name!r} has no plane")
            hits.setdefault(k, []).append(e)
            continue
        k = plane_of(spec, name)
        if k == -1:
            raise KeyError(f"{sc.id} element {name!r} has no plane")
        if k not in groups:
            order.append(k)
        elif order[-1] != k:
            raise ValueError(f"{sc.id}: {name!r} (plane {k}) comes back after plane {order[-1]}: "
                             f"planes are not contiguous back to front: {order}")
        groups.setdefault(k, []).append(e)
    # content is front-most first: overlays, then Plane5 .. Plane0, each contiguous (draw order kept)
    planes_seen = [k for k in order if k is not None]
    if (None in order and order[0] is not None) or planes_seen != sorted(planes_seen, reverse=True):
        raise ValueError(f"{sc.id}: planes are not contiguous back to front: {order}")

    fog = SCENES[sc.id].fog
    planes = []
    for k in range(5, -1, -1):
        if k not in groups and k not in hits:
            continue
        gain = PARALLAX_GAINS[k]
        binds = [] if gain == 0 else [
            sc.bind("parallaxX", 13, sc.conv(gain * PARALLAX_TRAVEL[0], doc=d6), doc=d6),
            sc.bind("parallaxY", 14, sc.conv(gain * PARALLAX_TRAVEL[1], doc=d6), doc=d6)]
        veil = None
        if k < len(spec.veils):
            density, y0, y1, *band = spec.veils[k]
            if band:
                # a band: clear at y0, full at y1, clear again at band[0]
                y2 = band[0]
                fills = [d6("Fill", d6("LinearGradient",
                                       d6("GradientStop", colorValue="00" + fog[2:], position=0.0),
                                       d6("GradientStop", d6("DataBindContext", sourcePathIds=sc.vpath("lightFog"),
                                                             propertyKey=38), colorValue=fog,
                                          position=round((y1 - y0) / (y2 - y0), 4)),
                                       d6("GradientStop", colorValue="00" + fog[2:], position=1.0),
                                       startX=0.0, startY=0.0, endX=0.0, endY=float(y2 - y0)), name="Fill")
                         for _ in range(FOG_FILLS)]
                height = float(y2 - y0)
            else:
                fills = [d6("Fill", d6("LinearGradient",
                                       d6("GradientStop", colorValue="00" + fog[2:], position=0.0),
                                       d6("GradientStop", d6("DataBindContext", sourcePathIds=sc.vpath("lightFog"),
                                                             propertyKey=38), colorValue=fog, position=1.0),
                                       startX=0.0, startY=0.0, endX=0.0, endY=float(y1 - y0)), name="Fill")
                         for _ in range(FOG_FILLS)]
                height = float(H + 60 - y0)
            veil = d6("Shape", d6("Rectangle", width=float(W + 120), height=height, originX=0.0,
                                  originY=0.0, name="Path"),
                      *fills, x=-60.0, y=float(y0), opacity=fog_opacity(density, fog), name=f"FogVeil{k}")
        planes.append(d6("Node", *binds, *hits.get(k, []), veil, *groups.get(k, []), x=0.0, y=0.0, name=f"Plane{k}"))
    content[:] = [*groups.get(None, []), *planes]
    sc.roots.extend(late)


# ---------------------------------------------------------------- time of day (M7, contract v10)
# Per scene: the horizon's y in the sky plane and how much of the day veil remains there (the
# living room's night skyline sits low in the window: the veil thins over it). deepSpace has none.
TIME_SKY: dict[str, tuple[float, float]] = {"livingRoom": (640.0, 0.45), "campfire": (720.0, 1.0),
                                            "beach": (985.0, 1.0)}
# Sky-plane roots the veils go behind (the beach's sun and clouds stay out by day); elsewhere the
# veils cover the whole sky plane, stars and moon included.
TIME_BEHIND: dict[str, tuple[str, ...]] = {"beach": ("SunsetSky", "Sky")}
DAY_VEIL_MAX = 0.8     # M7 ruling 12 (as built): a day sky over the sky plane only, never a relit scene
DUSK_VEIL_MAX = 0.75


def sky_time(sc: Scene, content: list[El]) -> None:
    """Contract v10: two veils at the front of `Plane0` (the sky; behind every nearer plane and
    behind the plane's own fog veil): a day sky (`art_bible` `times["day"]`, opaque at the top,
    thinning to the scene's horizon alpha) at opacity `DAY_VEIL_MAX x daylight`, and a warm
    twilight band (`times["dusk"]`) peaking just above the horizon at `DUSK_VEIL_MAX x dusk`. Both
    are invisible at 0, so the night scene renders exactly as before. Minted from `sc.d7`."""
    if sc.id not in TIME_SKY:
        return
    horizon, low = TIME_SKY[sc.id]
    times = SCENES[sc.id].times
    plane0 = next(e for e in content if e.tag == "Node" and e.attrs.get("name") == "Plane0")
    d7 = sc.d7
    day, dusk = times["day"], times["dusk"]

    def a(colour: str, alpha: float) -> str:
        return f"{round(alpha * 255):02X}" + colour[2:]

    def veil(name: str, prop: str, k: float, stops: list[tuple[str, float]]) -> El:
        grad = d7("LinearGradient", *[d7("GradientStop", colorValue=c, position=round(pos, 4)) for c, pos in stops],
                  startX=0.0, startY=0.0, endX=0.0, endY=float(H))
        return d7("Shape", sc.bind(prop, 18, sc.conv(k, doc=d7), doc=d7),
                  d7("Rectangle", width=float(W + 120), height=float(H), originX=0.0, originY=0.0, name="Path"),
                  d7("Fill", grad, name="Fill"), x=-60.0, y=0.0, opacity=0.0, name=name)

    day_veil = veil("SkyDay", "daylight", DAY_VEIL_MAX,
                    [(a(day, 1.0), 0.0), (a(day, 1.0), (horizon * 0.55) / H), (a(day, low), horizon / H),
                     (a(day, low), 1.0)])
    dusk_veil = veil("SkyDusk", "dusk", DUSK_VEIL_MAX,
                     [(a(dusk, 0.0), max(0.0, horizon - 560) / H), (a(dusk, 1.0), (horizon - 60) / H),
                      (a(dusk, 0.0), min(H, horizon + 160) / H)])
    kids = plane0.children
    behind = TIME_BEHIND.get(sc.id)
    if behind:
        # just in front of the first of those roots: the rest of the sky's art stays in front
        at = next(i for i, c in enumerate(kids)
                  if _root(str(c.attrs.get("name", "")).removeprefix(EMISSIVE_PREFIX)) in behind)
    else:
        # after the plane's binds, hit zones and fog veil: the front of the sky's own art
        at = next((i + 1 for i, c in enumerate(kids) if str(c.attrs.get("name", "")).startswith("FogVeil")),
                  next((i for i, c in enumerate(kids) if c.tag not in ("DataBindContext",)
                        and not str(c.attrs.get("name", "")).startswith(HIT_PREFIX)), 0))
    kids[at:at] = [dusk_veil, day_veil]


def clone(d: Doc, e: El, **attrs: object) -> El:
    """A deep copy of `e` with fresh ids from `d` (attributes overridden by `attrs`)."""
    return d(e.tag, *[clone(d, c) for c in e.children], **{**e.attrs, **attrs})



# ---------------------------------------------------------------- front weather (M6, contract v9)
# outdoor rain (contract v9 / v12 / v14); livingRoom's falls outside the window. forestCabin's module
# (contract v14) builds its own front (`Scene.front`); check_contract.py holds every file to the contract
FRONT_SCENES = ("campfire", "beach", "rooftop", "forestCabin")
FRONT_GAIN = 1.25          # nearer than Plane5: the sheet travels 1.25 x PARALLAX_TRAVEL
FRONT_TILE = 480           # the sheet repeats every tile; one tile per FRONT_SHEET_FRAMES loop
FRONT_SHEET_FRAMES = 14    # faster than the back sheets (18 / 34): near rain falls past quicker
FRONT_SPLASH_FRAMES = 120
FRONT_MIST = (0.18, 1200.0)  # rain mist density at rain 1, y where it starts clear (full at the bottom)
FRONT_BLEED = 120          # px past each side, more than the sheet's 50 px travel


def front_weather(sc: Scene, col: str, splash_y: tuple[float, float] = (1820.0, 1900.0)) -> None:
    """M6 ruling 8: sets `sc.front` to the `SceneFront` artboard's content: a near rain sheet (fewer,
    longer, wider, fainter streaks than the back sheets; parallax gain 1.25) with splashes along the
    bottom edge, all at opacity `rain`, and a rain mist of `lightFog` rising from the bottom at
    `fog_opacity(0.18) x rain`. `col` is the scene's rain colour (its alpha is replaced). Everything
    mints from `sc.d6`; history-free binds only."""
    d6 = sc.d6
    main_anims, main_layers = sc.anims, sc.layers
    sc.anims, sc.layers = [], []
    r = random.Random(zlib.crc32(("front" + sc.id).encode()))
    with sc.minting(d6):
        streaks = []
        for i in range(12):
            x, y = r.uniform(-FRONT_BLEED, W + FRONT_BLEED), r.uniform(0, FRONT_TILE)
            ln = r.uniform(160, 260)
            for k in range(-1, H // FRONT_TILE + 1):
                streaks.append(sc.S((0, 0), f"FrontDrop{i}_{k + 1}",
                                    [(x, y + k * FRONT_TILE), (x - ln * 0.22, y + k * FRONT_TILE + ln)],
                                    sc.L("50" + col[2:], 5.0), closed=False))
        sheet = d6("Node", *streaks, x=0.0, y=0.0, name="FrontSheet")
        sc.ambient("FrontSheet", sc.A("amb_FrontSheet", FRONT_SHEET_FRAMES,
                                      [sc.T(sheet, ease=None, y=[(0, 0.0, "linear"),
                                                                 (FRONT_SHEET_FRAMES, float(FRONT_TILE), "linear")])],
                                      loop=True))
        splashes, tracks = [], []
        for i in range(10):
            x, y = r.uniform(40, W - 40), r.uniform(*splash_y)
            sp = d6("Node", sc.E((x, y), "Ring", x, y, 48, 12, sc.L("A0" + col[2:], 3)),
                    sc.S((x, y), "Kick", [(x - 12, y - 3), (x - 18, y - 22)], sc.L("90" + col[2:], 3), closed=False),
                    sc.S((x, y), "Kick2", [(x + 12, y - 3), (x + 18, y - 22)], sc.L("90" + col[2:], 3), closed=False),
                    x=x, y=y, opacity=0.0, name=f"FrontSplash{i}")
            splashes.append(sp)
            ph = r.randint(0, 40)
            op, sxk = [(0, 0.0)], [(0, 0.3)]
            for c in range(1 + ph, FRONT_SPLASH_FRAMES - 13, 44):
                op += [(c, 0.0, "hold"), (c + 1, 1.0), (c + 12, 0.0, "hold")]
                sxk += [(c, 0.3, "hold"), (c + 1, 0.4), (c + 12, 1.3, "hold")]
            tracks.append(sc.T(sp, ease=None, opacity=uniq(op + [(FRONT_SPLASH_FRAMES, 0.0)]),
                               scaleX=uniq(sxk + [(FRONT_SPLASH_FRAMES, 0.3)]),
                               scaleY=uniq(sxk + [(FRONT_SPLASH_FRAMES, 0.3)])))
        sc.ambient("FrontSplash", sc.A("amb_FrontSplash", FRONT_SPLASH_FRAMES, tracks, loop=True))
        near = d6("Node", sc.bind("rain", 18, doc=d6),
                  sc.bind("parallaxX", 13, sc.conv(FRONT_GAIN * PARALLAX_TRAVEL[0], doc=d6), doc=d6),
                  sc.bind("parallaxY", 14, sc.conv(FRONT_GAIN * PARALLAX_TRAVEL[1], doc=d6), doc=d6),
                  *splashes, sheet, x=0.0, y=0.0, opacity=0.0, name="FrontRain")
        density, y0 = FRONT_MIST
        fog = SCENES[sc.id].fog
        fills = [d6("Fill", d6("LinearGradient",
                               d6("GradientStop", colorValue="00" + fog[2:], position=0.0),
                               d6("GradientStop", d6("DataBindContext", sourcePathIds=sc.vpath("lightFog"),
                                                     propertyKey=38), colorValue=fog, position=1.0),
                               startX=0.0, startY=0.0, endX=0.0, endY=float(H - y0)), name="Fill")
                 for _ in range(FOG_FILLS)]
        mist = d6("Shape", sc.bind("rain", 18, sc.conv(fog_opacity(density, fog), doc=d6), doc=d6),
                  d6("Rectangle", width=float(W + 2 * FRONT_BLEED), height=float(H + 60 - y0), originX=0.0,
                     originY=0.0, name="Path"),
                  *fills, x=float(-FRONT_BLEED), y=float(y0), opacity=0.0, name="FrontMist")
    # M8 (contract v11): fog joins the front mist (a veil of its own at `FRONT_FOG_GAIN x fog`)
    fog_fills = [sc.d8("Fill", sc.d8("LinearGradient",
                                     sc.d8("GradientStop", colorValue="00" + fog[2:], position=0.0),
                                     sc.d8("GradientStop", sc.d8("DataBindContext", sourcePathIds=sc.vpath("lightFog"),
                                                                 propertyKey=38), colorValue=fog, position=1.0),
                                     startX=0.0, startY=0.0, endX=0.0, endY=float(H - y0)), name="Fill")
                 for _ in range(FOG_FILLS)]
    sc.front = ([near, scene_npc.front_fog(sc, y0, FRONT_BLEED, fog_fills), mist], sc.anims, sc.layers)
    sc.anims, sc.layers = main_anims, main_layers

# ---------------------------------------------------------------- campfire
CAMPFIRE_PLANES: dict[str, int | None] = {
    "RainLoop": None, "RainFx": None, "FlareWash": None,
    "BushL": 5, "BushR": 5,
    **dict.fromkeys(("PokeStick", "Stone", "LogA", "LogB", "LogC", "WetCoalSteam", "CoalBed", "RainSteam", "FireFlare", "Smoke",
                     "Firefly", "TentPlace", "Grass", "TreeGlow", "LightPoolFlicker", "GroundWet", "TrailStone",
                     "Path", "Ground"), 4),
    **dict.fromkeys(("Hoo", "Owl", "OwlNpc", "OwlGrip", "Branch", "OwlTwig", "OwlSnag", "Pine"), 3),
    **dict.fromkeys(("ValleyMist", "MidHills"), 2),
    **dict.fromkeys(("FarPine", "AlpineRidge", "PeakSnow", "MountainShadow", "FarHills"), 1),
    **dict.fromkeys(("ShootingStar", "MoonPhased", "MoonRig", "Crater", "Moon", "MoonGlow", "Star", "Glint", "Aurora",
                     "Sky"), 0),
    # M5 ruling 3: each hit zone rides the plane of its prop's art
    "Hit_fire": 4, "Hit_tent": 4, "Hit_owl": 3, "Hit_sky": 0,
}
FOG_VEILS = ((0.55, 700.0, 1000.0), (0.35, 700.0, 1000.0), (0.18, 880.0, 1060.0))
# Light sources (ruling 13): renamed `emit*` with every node and shape below them, exempt from the
# colour-script fit. Everything else in the campfire goes through `art_bible.fit_colour`.
CAMPFIRE_EMISSIVE = ("FireFlare", "Star", "Glint", "Moon", "MoonGlow", "ShootingStar", "CoalBed", "Firefly",
                     "LogHeat", "TentLantern")
# amb_firelight's flicker keys (frame, glow opacity), 89 frames
CAMPFIRE_FLICKER = [(0, 1.0), (9, 0.8), (17, 0.97), (31, 0.84), (44, 1.0), (58, 0.86), (70, 0.95), (89, 1.0)]
# M5 ruling 6: steady rain (`rain` 0..1)
RAIN_WET = 0.35        # ground and tent darken by up to this x rain
RAIN_DAMP = 0.15       # the fire shrinks by this x rain
RAIN_WET_COLOUR = "FF0B1318"   # a cool wet shadow, inside the campfire's colour script
RAIN_LOOP_FRAMES = 120  # 2 s splash loop; the streak sheets loop on their own periods
STEAM_FRAMES = 180      # 3 s steam rise loop
STEAM_PLUMES = ((104, 1140), (134, 1126), (164, 1146), (196, 1120), (228, 1144), (258, 1126), (290, 1138))
STEAM_PEAK = 0.8       # a plume's opacity at mid-rise (times `rain`)


def campfire_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """Firelight (M4): amb_firelight's flicker also drives the light pool (through a wrapper: the
    rain event keys the pool's own opacity) and the tree glow, a little deeper on the trees. Then the
    steady rain binds (M5 ruling 6)."""
    firelight = next(a for a in sc.anims if a.attrs["name"] == "amb_firelight")
    pool = next(e for e in content if e.attrs.get("name") == "LightPool")
    tree_glow = next(e for e in content if e.attrs.get("name") == "TreeGlow")
    pool_flicker = d6("Node", pool, x=0.0, y=0.0, name="LightPoolFlicker")
    content[content.index(pool)] = pool_flicker
    firelight.add(track(d6, pool_flicker, {"opacity": [(fr, round(0.75 + 1.25 * (v - 0.8), 4))
                                                       for fr, v in CAMPFIRE_FLICKER]}, ease=sc.ease),
                  track(d6, tree_glow, {"opacity": [(fr, round(0.7 + 1.5 * (v - 0.8), 4))
                                                    for fr, v in CAMPFIRE_FLICKER]}, ease=sc.ease))
    campfire_rain(sc, content)


def campfire_rain(sc: Scene, content: list[El]) -> None:
    """Steady rain bound to SceneVM `rain`, history-free (M5 ruling 6): a looping streak layer at
    opacity `rain` in screen space, the ground and the tent under a wet shadow at RAIN_WET x `rain`,
    steam rising off the logs at opacity `rain`, the fire scaled by 1 - RAIN_DAMP x `rain`. The
    `rain` one-shot event plays on top (a shower)."""
    d5 = sc.d5
    with sc.minting(d5):
        streaks, loop = rain_fx(sc, "RainLoop", "88B8C8F0", frames=RAIN_LOOP_FRAMES, loop=True)
        streaks.attrs["opacity"] = 0.0
        streaks.children.insert(0, sc.bind("rain", 18))
        sc.ambient("RainLoop", loop)
        content.insert(0, streaks)

        wet = sc.conv(RAIN_WET)

        def path_of(shape: El, x: float = 0.0, y: float = 0.0) -> El:
            p = next(c for c in shape.children if c.tag == "PointsPath")
            return clone(d5, p, x=x, y=y) if (x, y) != (0.0, 0.0) else clone(d5, p)

        ground = next(e for e in content if e.attrs.get("name") == "Ground")
        ground_wet = d5("Shape", sc.bind("rain", 18, wet), path_of(ground), sc.F(RAIN_WET_COLOUR),
                        x=ground.attrs["x"], y=ground.attrs["y"], opacity=0.0, name="GroundWet")
        # in front of the trail and its stones, behind the light pool, the grass and the tree glow
        before(content, "TrailStone0", ground_wet)

        tent = named(content, "Tent")
        lit, shade = named(tent.children, "TentLit"), named(tent.children, "TentShade")
        lx, ly = float(lit.attrs["x"]), float(lit.attrs["y"])
        tent_wet = d5("Shape", sc.bind("rain", 18, wet), path_of(lit),
                      path_of(shade, float(shade.attrs["x"]) - lx, float(shade.attrs["y"]) - ly),
                      sc.F(RAIN_WET_COLOUR), x=lx, y=ly, opacity=0.0, name="TentWet")
        # right behind the lantern glow: over the canvas, pole and rope (the thin fold and seam lines
        # paint in front of the lantern in M4, and moving them would change the dry tent)
        at = next(i for i, c in enumerate(tent.children) if _root(c.attrs.get("name")).endswith("TentLantern"))
        tent.children.insert(at + 1, tent_wet)

        plumes, tracks = [], []
        for i, (bx, by) in enumerate(STEAM_PLUMES):
            plume = sc.E((0.0, 0.0), f"SteamPlume{i}", bx, by, 88, 88,
                         sc.rgrad(44, [("B0DCE2DE", 0.0), ("60DCE2DE", 0.45), ("00DCE2DE", 1.0)]),
                         scaleY=0.75, opacity=0.0)
            plumes.append(plume)
            off = (i * 67) % STEAM_FRAMES
            wrap = STEAM_FRAMES - off       # frame where this plume restarts at the logs (opacity ~0)
            drift = 26 if i % 2 else -22

            def at(f: int, bx: float = bx, by: float = by, off: int = off, drift: float = drift,
                   i: int = i) -> tuple[float, float, float, float]:
                t = ((f + off) % STEAM_FRAMES) / STEAM_FRAMES
                return (bx + drift * t + 9 * math.sin(2 * math.pi * t * 1.5 + i), by - 250 * t,
                        0.4 + 1.6 * t, STEAM_PEAK * math.sin(math.pi * t) ** 1.5)

            frames = sorted(set(range(0, STEAM_FRAMES + 1, 6)) | {wrap - 1, wrap})
            keys = {f: at(f) for f in frames}
            # the frame before the restart holds, so no fractional frame sweeps the plume back down
            mode = {f: ("hold" if f == wrap - 1 else "linear") for f in frames}
            tracks.append(sc.T(plume, ease=None,
                               x=[(f, keys[f][0], mode[f]) for f in frames],
                               y=[(f, keys[f][1], mode[f]) for f in frames],
                               scaleX=[(f, keys[f][2], mode[f]) for f in frames],
                               scaleY=[(f, keys[f][2] * 0.75, mode[f]) for f in frames],
                               opacity=[(f, keys[f][3], mode[f]) for f in frames]))
        steam = d5("Node", sc.bind("rain", 18), *plumes, x=0.0, y=0.0, opacity=0.0, name="RainSteam")
        sc.ambient("RainSteam", sc.A("amb_RainSteam", STEAM_FRAMES, tracks, loop=True))
        before(content, "FireFlare", steam)

        flare = next(e for e in content if e.attrs.get("name") == "FireFlare")
        damp = sc.conv(-RAIN_DAMP, 1.0)
        flare.children = [d5("Node", sc.bind("rain", 16, damp), sc.bind("rain", 17, damp), *flare.children,
                             x=0.0, y=0.0, name="FireDamp")]


DIORAMAS: dict[str, DioramaSpec] = {
    "campfire": DioramaSpec(CAMPFIRE_PLANES, CAMPFIRE_EMISSIVE, FOG_VEILS, campfire_light),
}


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
    # M5 diorama bleed: the wall and the wainscot run 50 px under the floor (Plane3 slides 8 px more
    # than the wall), the floor 40 px past the frame (gradients keep their artboard span)
    wall = rect("Wall", -10, -10, W + 10, floor_y + 50, sc.vgrad(-625, 575, [("FF4E4460", 0.0), ("FF7A6680", 1.0)]))
    stripes = [rect(f"Stripe{i}", x, -10, x + 34, floor_y, F("10FFFFFF")) for i, x in enumerate(range(0, W, 90))]
    wainscot = rect("Wainscot", -10, 1000, W + 10, floor_y + 50,
                    sc.vgrad(-115, 65, [("FF5A4A62", 0.0), ("FF483A50", 1.0)]))
    rail = rect("Rail", -10, 992, W + 10, 1006, F("FF8A7896"))
    floor = rect("Floor", -50, floor_y, W + 50, H + 40, sc.vgrad(-385, 355, [("FF9A6844", 0.0), ("FF5E3A24", 1.0)]))
    ext = (H + 40 - floor_y) / (H - floor_y)
    planks = [S(O, f"Plank{i}", [(x0, floor_y), (x0 + (x0 - 540) * 1.6 * ext, H + 40)], L("40000000", 3), closed=False)
              for i, x0 in enumerate(range(-200, 1300, 130))]
    baseboard = rect("Baseboard", -50, floor_y - 18, W + 50, floor_y + 4, F("FFE8DCCC"))
    rug = E(O, "Rug", 540, 1520, 980, 300, sc.rgrad(490, [("FFB8484A", 0.0), ("FF8A2E36", 0.55), ("FF5A1E28", 1.0)]),
            L("FFE8C890", 6))
    rug_in = E(O, "RugInner", 540, 1520, 780, 220, L("CCE8C890", 4))

    # window with night sky + skyline, curtains
    # the window sits high: in the app the avatar's head covers the wall below ~y 760
    wx0, wy0, wx1, wy1 = 360, 230, 720, 700
    # the view (Plane0) runs 20 px past the glass: the wall's opening slides 6 / 3.6 px over it
    sky = rect("WinSky", wx0 - 20, wy0 - 20, wx1 + 20, wy1 + 20,
               sc.vgrad(-260, 260, [("FF1C2450", 0.0), ("FF6A4A80", 1.0)]))
    city = S(O, "Skyline", [(wx0 - 20, wy1 + 20, "c"), (wx0 - 20, 560, "c"), (400, 560, "c"), (400, 500, "c"), (440, 500, "c"),
                            (440, 580, "c"), (480, 580, "c"), (480, 460, "c"), (530, 460, "c"), (530, 540, "c"),
                            (580, 540, "c"), (580, 490, "c"), (630, 490, "c"), (630, 570, "c"), (680, 570, "c"),
                            (680, 520, "c"), (wx1 + 20, 520, "c"), (wx1 + 20, wy1 + 20, "c")], F("FF231C38"))
    rnd = random.Random(3)
    windows_lit = [rect(f"Lit{i}", x, y, x + 8, y + 10, F("FFFFD27A"), opacity=rnd.uniform(0.5, 1))
                   for i, (x, y) in enumerate([(rnd.uniform(400, 700), rnd.uniform(560, 680)) for _ in range(18)])]
    moon = E(O, "Moon", 640, 320, 60, 60, F("FFFFF2D0"))
    frame = rect("WinFrame", wx0 - 14, wy0 - 14, wx1 + 14, wy1 + 14, F("FFE8DCCC"), 6)
    mullion = [rect("MullV", 532, wy0, 548, wy1, F("FFE8DCCC")), rect("MullH", wx0, 458, wx1, 472, F("FFE8DCCC"))]
    # a long ledge under the window runs the width of the wall (the walking cat's stage)
    sill = rect("Sill", -30, wy1 + 8, W + 30, wy1 + 30, F("FFF2E8DA"), 4)
    ledge_sh = rect("LedgeShadow", -30, wy1 + 30, W + 30, wy1 + 44, F("40101C1E"))
    curtain = [(300, 190), (380, 190), (390, 430), (370, 780), (300, 800, "c")]
    curt_l = S(O, "CurtainL", curtain + [(280, 470)], sc.vgrad(-320, 320, [("FFA83A4A", 0.0), ("FF6E1E2E", 1.0)]),
               L(INKC, 3))
    curt_r = S(O, "CurtainR", [(W - p[0], p[1]) + tuple(p[2:]) for p in reversed(curtain + [(280, 470)])],
               sc.vgrad(-320, 320, [("FFA83A4A", 0.0), ("FF6E1E2E", 1.0)]), L(INKC, 3))
    folds = [S(O, f"Fold{i}", [(x, 210), (x + 6, 520), (x - 4, 780)], L("40000000", 3), closed=False)
             for i, x in enumerate([330, 350, W - 330, W - 350])]
    rod = rect("Rod", 270, 180, W - 270, 192, F("FF3A2A20"), 6)
    # curtains hang from the rod and sway a little (pivot at the rod)
    def sway_node(name: str, px: float, *kids: El) -> El:
        for k in kids:
            k.attrs["x"] = float(k.attrs["x"]) - px
            k.attrs["y"] = float(k.attrs["y"]) - 186.0
        return d("Node", *kids, x=px, y=186.0, name=name)
    curt_l_n = sway_node("CurtainLSway", 340.0, folds[0], folds[1], curt_l)
    curt_r_n = sway_node("CurtainRSway", W - 340.0, folds[2], folds[3], curt_r)

    # floor lamp (left)
    lx = 286.0
    lamp_glow = E(O, "LampGlow", lx, 700, 700, 700, sc.rgrad(350, [("70FFD890", 0.0), ("20FFC070", 0.5), ("00FFC070", 1.0)]))
    lamp_cone = S(O, "LampCone", [(lx - 60, 760), (lx + 60, 760), (lx + 170, floor_y + 80), (lx - 170, floor_y + 80)],
                  sc.vgrad(-260, 260, [("40FFE0A0", 0.0), ("00FFE0A0", 1.0)]))
    shade = S(O, "Shade", [(lx - 46, 640), (lx + 46, 640), (lx + 74, 760, "c"), (lx - 74, 760, "c")],
              sc.vgrad(-60, 60, [("FFFFF2D8", 0.0), ("FFF0D8A8", 1.0)]), L(INKC, 3))
    pole = rect("Pole", lx - 5, 760, lx + 5, 1230, F("FF2A2228"))
    lamp_base = E(O, "LampBase", lx, 1236, 120, 26, F("FF2A2228"))
    lamp = d("Node", shade, pole, lamp_base, x=0.0, y=0.0, name="Lamp")

    # plant (left of the avatar, on the floor)
    px_, py_ = 140.0, 1290.0
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
    cx_, cy_ = 904.0, ty0 - 4
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
    moon_pool = S(O, "MoonPool", [(380, 1240), (720, 1240), (900, 1560), (240, 1560)],
                  sc.vgrad(-160, 160, [("50B8D0FF", 0.0), ("28B8D0FF", 1.0)]), opacity=0.0)
    # a round pool squashed onto the floor (M5: the 520 x 150 ellipse cut its own radial gradient flat)
    tv_spill = E(O, "TvFloorSpill", 870, 1330, 520, 520, sc.rgrad(260, [("606AD8FF", 0.0), ("006AD8FF", 1.0)]),
                 opacity=0.0, scaleY=round(150 / 520, 4))
    lights_on = sc.A("lights_on", 1, [sc.T(night, ease=None, opacity=[(0, 0.0)]), sc.T(lamp_glow, ease=None, opacity=[(0, 1.0)]),
                                      sc.T(lamp_cone, ease=None, opacity=[(0, 1.0)]), sc.T(moonbeam, ease=None, opacity=[(0, 0.0)]),
                                      sc.T(moon_pool, ease=None, opacity=[(0, 0.0)]),
                                      sc.T(shade, ease=None, opacity=[(0, 1.0)])])
    lights_off = sc.A("lights_off", 1, [sc.T(night, ease=None, opacity=[(0, 0.62)]), sc.T(lamp_glow, ease=None, opacity=[(0, 0.0)]),
                                        sc.T(lamp_cone, ease=None, opacity=[(0, 0.0)]),
                                        sc.T(moonbeam, ease=None, opacity=[(0, 1.0)]),
                                        sc.T(moon_pool, ease=None, opacity=[(0, 1.0)]),
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
        sc.T(tv_spill, ease=None, opacity=[(0, 0.0), (8, 1.0, "linear")] + [(f, 0.65 if (f // 10) % 2 else 1.0, "linear")
                                                                           for f in range(20, 540, 10)] + [(556, 0.0)]),
        *flick])
    sc.one_shot("tvOn", tv)
    # catWalksBy: a grey tabby (same drawing language as the sleeping cat) walks the ledge
    # right to left, stops mid-way to look at the camera, flicks its tail and moves on
    ledge_y = float(wy1 + 8)
    TAB, TAB_SH, TAB_DK = "FFB9BDC6", "FF7D838F", "FF4E5460"
    wk = d("Node", x=1180.0, y=ledge_y, name="WalkingCat")
    Z = (0.0, 0.0)

    cat_joints: dict[str, tuple[El, El, El]] = {}

    def leg(name: str, hx: float, col: str) -> El:
        # Two links let the paw stay flat during stance and lift during swing.
        paw = d("Node", E(O, "Paw", -3, -1, 17, 8, F(col), L(INKC, 1.4)),
                x=0.0, y=19.0, name=name + "Foot")
        shin = d("Node", paw,
                 S(O, "Shin", [(-4, -2), (4, -2), (3, 18), (-3, 18)], F(col), L(INKC, 1.4)),
                 x=0.0, y=20.0, name=name + "Shin")
        n = d("Node", shin,
              S(O, "Thigh", [(-6, -3), (6, -3), (4, 21), (-4, 21)], F(col), L(INKC, 1.4)),
              x=hx, y=-32.0, name=name)
        cat_joints[name] = (n, shin, paw)
        return n
    legs_far = [leg("LegFarF", -22, TAB_SH), leg("LegFarB", 46, TAB_SH)]
    legs_near = [leg("LegNearF", -34, TAB), leg("LegNearB", 34, TAB)]
    tail = d("Node", x=56.0, y=-42.0, name="WTailPivot")
    tail.add(S((56.0, -42.0), "WTail", [(56, -42), (84, -50), (96, -78), (88, -100)], L(INKC, 13), closed=False),
             S((56.0, -42.0), "WTailFill", [(56, -42), (84, -50), (96, -78), (88, -100)], L(TAB_SH, 9), closed=False))
    stripes_w = [S(Z, f"WStripe{i}", [(x - 6, -60 + i), (x, -46), (x - 4, -30)], L(TAB_DK, 4), closed=False)
                 for i, x in enumerate((-8, 12, 32))]
    body_w = S(Z, "WBody", [(-50, -50), (-20, -62), (30, -60), (58, -48), (62, -30), (40, -22), (-30, -22), (-52, -32)],
               sc.vgrad(-20, 20, [(TAB, 0.0), (TAB_SH, 1.0)]), L(INKC, 2.5))
    ears = [(-88, -64), (-86, -86), (-80, -100, "c"), (-68, -88), (-56, -90), (-46, -102, "c"), (-40, -80),
            (-38, -62), (-48, -46), (-64, -42), (-80, -48)]
    head_side = d("Node", x=0.0, y=0.0, name="WHeadSide")
    head_side.add(E(Z, "WPupil", -75, -70.5, 3, 6, F("FF1A1414")),
                  S(Z, "WEye", [(-80, -70), (-74, -74), (-68, -70), (-74, -67)], F("FFE6D45A"), L(INKC, 1.6)),
                  S(Z, "WNose", [(-90, -61), (-86, -61), (-88, -58, "c")], F("FFD98A8A")),
                  S(Z, "WMuzzle", [(-90, -56), (-82, -52), (-74, -54)], L(INKC, 1.6), closed=False),
                  S(Z, "WHeadStripe", [(-66, -88), (-62, -78)], L(TAB_DK, 3), closed=False),
                  S(Z, "WHead", ears, sc.vgrad(-30, 30, [(TAB, 0.0), (TAB_SH, 1.0)]), L(INKC, 2.5)))
    head_front = d("Node", x=0.0, y=0.0, name="WHeadFront", opacity=0.0)
    fx_ = -62.0
    head_front.add(*[E(Z, f"WFPupil{k}", fx_ + dx, -70.5, 3, 7, F("FF1A1414")) for k, dx in enumerate((-11, 11))],
                   *[S(Z, f"WFEye{k}", [(fx_ + dx - 6, -70), (fx_ + dx, -75), (fx_ + dx + 6, -70), (fx_ + dx, -66)],
                       F("FFE6D45A"), L(INKC, 1.6)) for k, dx in enumerate((-11, 11))],
                   S(Z, "WFNose", [(fx_ - 3, -60), (fx_ + 3, -60), (fx_, -57, "c")], F("FFD98A8A")),
                   S(Z, "WFMouth", [(fx_ - 6, -53), (fx_, -55), (fx_ + 6, -53)], L(INKC, 1.6), closed=False),
                   S(Z, "WFHead", [(fx_ - 28, -64), (fx_ - 26, -88), (fx_ - 20, -102, "c"), (fx_ - 8, -88), (fx_ + 8, -88),
                                   (fx_ + 20, -102, "c"), (fx_ + 26, -88), (fx_ + 28, -64), (fx_ + 18, -46), (fx_, -42),
                                   (fx_ - 18, -46)], sc.vgrad(-30, 30, [(TAB, 0.0), (TAB_SH, 1.0)]), L(INKC, 2.5)))
    w_shadow = E(Z, "WShadow", 4, 2, 150, 12, F("38101818"))
    w_body = d("Node", head_front, head_side, *legs_near, *stripes_w, body_w, tail, *legs_far, x=0.0, y=0.0,
               name="WBodyBob")
    wk.add(w_body, w_shadow)
    stop0, stop1, end = 246, 330, 642

    def cat_x(frame: float) -> float:
        if stop0 <= frame <= stop1:
            return 560.0
        start, finish, x0, x1 = (0, stop0, 1180.0, 560.0) if frame < stop0 else (stop1, end, 560.0, -220.0)
        t = max(0.0, min(finish - start, frame - start))
        length, ramp = finish - start, 30.0
        # Integrate a cosine velocity ramp, cruise, then decelerate. Paw phase
        # follows distance travelled, so it cannot treadmill during the stop.
        if t < ramp:
            dist = 0.5 * (t - ramp / math.pi * math.sin(math.pi * t / ramp))
        elif t > length - ramp:
            rem = length - t
            dist = length - ramp - 0.5 * (rem - ramp / math.pi * math.sin(math.pi * rem / ramp))
        else:
            dist = t - ramp * 0.5
        return x0 + (x1 - x0) * dist / (length - ramp)

    def cat_step(frame: int) -> tuple[float, float]:
        if stop0 <= frame <= stop1:
            return 0.0, 0.0
        start, finish, dist, cycles = (0, stop0, 620.0, 10) if frame < stop0 else (stop1, end, 780.0, 12.580645)
        base = 1180.0 if start == 0 else 560.0
        phase = (base - cat_x(frame)) / dist * cycles * 2 * math.pi
        speed = abs(cat_x(frame + 1) - cat_x(frame - 1)) * 0.5
        return phase, min(1.0, speed / 2.3)

    samples = sorted(set(range(0, end + 1, 2)) | {stop0, stop1, end})
    stride = []
    for index, (lg, ph) in enumerate(zip([*legs_near, *legs_far], (0.0, math.pi, math.pi * 0.5, math.pi * 1.5))):
        upper, lower, paw = cat_joints[str(lg.attrs["name"])]
        hip_keys, knee_keys, paw_keys = [], [], []
        for f in samples:
            phase, speed = cat_step(f)
            p = ((phase + ph) / (2 * math.pi)) % 1.0
            # During 60% stance the local foot travels right at exactly the
            # body's leftward speed. During recovery it lifts in a curved arc.
            if p < 0.6:
                dx, lift = 62 * (p - 0.3), 0.0
            else:
                t = (p - 0.6) / 0.4
                dx = 18.6 * math.cos(math.pi * t)
                lift = 12 * math.sin(math.pi * t) ** 1.5
            dx *= speed
            dy = 32 - lift * speed + 2.2 * speed * math.sin(phase) ** 2
            distance = min(38.95, math.hypot(dx, dy))
            bend = (1 if index % 2 else -1) * math.acos((distance**2 - 20**2 - 19**2) / (2 * 20 * 19))
            hip = math.atan2(-dx, dy) - math.atan2(19 * math.sin(bend), 20 + 19 * math.cos(bend))
            hip_keys.append((f, hip, "linear"))
            knee_keys.append((f, bend, "linear"))
            paw_keys.append((f, -hip - bend, "linear"))
        stride.extend([sc.T(upper, ease=None, rotation=hip_keys), sc.T(lower, ease=None, rotation=knee_keys),
                       sc.T(paw, ease=None, rotation=paw_keys)])
    cat_walk = sc.A("ev_catWalksBy", end, [
        sc.T(wk, ease=None, x=[(f, cat_x(f), "linear") for f in samples]),
        sc.T(w_body, ease=None, y=[(f, -2.2 * cat_step(f)[1] * math.sin(cat_step(f)[0]) ** 2, "linear") for f in samples]),
        *stride,
        sc.T(tail, rotation=[(0, 0.0), (80, 0.12), (160, -0.08), (stop0, 0.0), (stop0 + 18, -0.4),
                             (stop0 + 32, 0.16), (stop0 + 50, -0.2), (stop1, 0.0), (440, 0.12), (end, 0.0)]),
        sc.T(head_front, opacity=[(0, 0.0), (stop0 + 2, 0.0), (stop0 + 14, 1.0),
                                  (stop1 - 20, 1.0), (stop1 - 6, 0.0), (end, 0.0)],
             x=[(0, -5.0), (stop0 + 2, -5.0), (stop0 + 16, 0.0), (stop1 - 20, 0.0), (stop1 - 6, -5.0), (end, -5.0)]),
        sc.T(head_side, opacity=[(0, 1.0), (stop0 + 2, 1.0), (stop0 + 14, 0.0),
                                 (stop1 - 20, 0.0), (stop1 - 6, 1.0), (end, 1.0)],
             x=[(0, 0.0), (stop0 + 2, 0.0), (stop0 + 14, 5.0), (stop1 - 20, 5.0), (stop1 - 6, 0.0), (end, 0.0)]),
    ])
    sc.one_shot("catWalksBy", cat_walk)

    tvp = place_point("livingRoom", "TvCorner", tx0 + 160, 970)
    catp = place_point("livingRoom", "TvCorner", cx_ - 10, cy_ - 30)
    hits = [sc.hit("lamp", lx, 900, 180, 660), sc.hit("tv", *tvp, 216, 150),
            sc.hit("cat", *catp, 140, 60), sc.hit("plant", px_, py_ - 140, 300, 380)]
    for h, pid in zip(hits, ["lamp", "tv", "cat", "plant"]):
        sc.prop(pid, h)
    # ambience: lit windows across the city wink on and off, curtains breathe, the lamp glow swells softly
    tw = []
    for i, lit in enumerate(windows_lit):
        if i % 3 == 0:
            continue
        r_ = random.Random(40 + i)
        base = float(lit.attrs["opacity"])
        P = r_.choice([300, 420, 540])
        f0 = r_.randint(20, P - 120)
        tw.append(sc.T(lit, opacity=[(0, base, "hold"), (f0, 0.08, "hold"), (f0 + r_.randint(50, 100), base, "hold"),
                                     (P, base, "hold")]))
        sc.ambient(f"City{i}", sc.A(f"amb_city{i}", P, [tw.pop()], loop=True))
    sc.ambient("Curtains", sc.A("amb_curtains", 600, [
        sc.T(curt_l_n, rotation=[(0, 0.0), (210, 0.03), (420, -0.016), (600, 0.0)]),
        sc.T(curt_r_n, rotation=[(0, 0.0), (250, -0.026), (440, 0.018), (600, 0.0)]),
        sc.T(lamp_glow, scaleX=[(0, 1.0), (300, 1.04), (600, 1.0)], scaleY=[(0, 1.0), (300, 1.04), (600, 1.0)])],
        loop=True, seam_hold=True))
    content = [night, wk, rug_in, rug, plant, cat, *zzz, tv_glare, *tv_shapes, tv_on, tv_screen, tv_frame, tv_stand,
               *knobs, cabinet, lamp, lamp_cone, moonbeam, tv_glow, lamp_glow, moon_pool, tv_spill, *planks, floor,
               baseboard,
               curt_l_n, curt_r_n, rod, sill, ledge_sh, *mullion, *windows_lit, city, moon, sky, frame, rail, wainscot,
               *stripes, wall]
    sc.npc_rig = lambda s_, c_, h_: scene_npc.living_room_cat(s_, c_, h_, PARALLAX_GAINS, PARALLAX_TRAVEL)  # M8
    sc.v12_art = living_room_v12   # M9: the lamp's pull cord, the moon's phase, the December lights (v12)
    sc.v14_art = living_room_seasons   # M11: tulips / a pumpkin on the sill (contract v14)
    return sc.write(content, hits)


# ---------------------------------------------------------------- livingRoom diorama (M5 Task 4)
# Ruling 4 (interior, short depth). Moved one plane from the ruling's table (execution ruling 53):
# the curtains and the rod (1 -> 2, they hang in front of the frame), the ledge under the window with
# the walking cat (a wall shelf: 2; on Plane4 the cat would float 13 px off it), the floor with its
# planks, grain and light pools (4 -> 3: the floor must paint behind the TV unit standing on it).
# Plane5 stays empty (the room has no foreground).
LIVING_ROOM_PLANES: dict[str, int | None] = {
    "Night": None,
    # M8: the cat NPC paints in front of the rug; on the cabinet it rides Plane3's travel (scene_npc)
    **dict.fromkeys(("CatNpc", "RugInner", "Rug", "Plant", "LampCord", "Lamp", "LamplitDust", "LampCone",
                     "PlantContact", "LampContact"), 4),
    **dict.fromkeys(("TvCorner", "MoonBeam", "TvGlow", "MoonPool", "TvFloorSpill", "Plank", "CabinetContact",
                     "WindowFloorLight", "FloorJoint", "OakGrain", "Floor", "Baseboard"), 3),
    **dict.fromkeys(("FestiveLights", "WalkingCat", "CurtainLSway", "CurtainRSway", "Rod", "Sill", "LedgeShadow", "LampGlow",
                     "WallWarmth", "ArtMountain", "ArtHill", "ArtSun", "ArtCanvas", "ArtMat", "ArtFrame",
                     "ArtShadow", "ShelfBook", "VaseRim", "CeramicVase", "VaseSprig", "VaseLeaf", "FloatingShelf",
                     "ShelfShadow"), 2),
    **dict.fromkeys(("MullV", "MullH", "RainGlass", "PaneClip", "WinFrame", "Rail", "Wainscot", "WallPanel",
                     "LowerPanel", "CorniceShadow", "CorniceInlay", "WindowCool", "Wall"), 1),
    **dict.fromkeys(("Lit", "Skyline", "MoonPhased", "MoonRig", "Moon", "Star", "WinSky"), 0),
    # ruling 3: each hit zone rides the plane of its prop's art (the sleeping cat is on the TV unit)
    "Hit_lamp": 4, "Hit_plant": 4, "Hit_tv": 3, "Hit_cat": 3,
}
# warm dust (`lightFog`) in front of the view through the window and, thinner, the back wall
LIVING_ROOM_VEILS = ((0.3, 200.0, 480.0), (0.12, 300.0, 1100.0))
LIVING_ROOM_EMISSIVE = ("Shade", "LampGlow", "TvOn", "TvBlob", "Lit", "Moon", "Star")
WINDOW_FRAME = (346.0, 216.0, 734.0, 714.0)   # WinFrame's outer edge
WINDOW_GLASS = (360.0, 230.0, 720.0, 700.0)   # the opening inside it
WINDOW_PANES = ((360.0, 230.0, 532.0, 458.0), (548.0, 230.0, 720.0, 458.0),
                (360.0, 472.0, 532.0, 700.0), (548.0, 472.0, 720.0, 700.0))
# The lamp's wall pool in `lightKey` (ruling 5): a bound colour sets the alpha too, so the M4 falloff
# (0.44 at the centre, 0.125 half-way, 0 at the edge) is two key-coloured fills fading to clear,
# (gradient opacity, share of the 350 px radius) each.
LAMP_POOL = ((0.25, 1.0), (0.2, 0.5))
# Rain on the glass (ruling 6): a fast sheet of fine streaks seen through the panes and slow drips
# running down them, each sheet moving one tile per loop (seamless at any frame time, as the
# campfire's), clipped to the four panes; a wet tint dulls the view. Opacity = `rain`.
GLASS_STREAKS = (26, 235.0, 20)   # (count, tile px, loop frames)
GLASS_DRIPS = (10, 470.0, 240)
GLASS_RAIN_FRAMES = 240            # both sheets are back at frame 0 after this many frames
GLASS_WET = ("FF7A8898", 0.25)     # wet tint and its opacity at rain 1 (misted glass, lighter than the view)
ORIGIN = (0.0, 0.0)


def _rect_path(d: Doc, x0: float, y0: float, x1: float, y1: float, ox: float = 0.0, oy: float = 0.0,
               name: str = "Path") -> El:
    """A Rectangle path covering artboard (x0, y0)-(x1, y1) in a shape placed at (ox, oy)."""
    return d("Rectangle", width=float(x1 - x0), height=float(y1 - y0), x=float((x0 + x1) / 2 - ox),
             y=float((y0 + y1) / 2 - oy), name=name)


def living_room_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """The living room's own pass (M5 Task 4): the lamp's wall pool in `lightKey`, an opening in the
    wall and the frame for the view (Plane0) behind them, stars in that view, rain on the glass bound
    to `rain`, then the content regrouped back to front by plane (draw order kept inside a plane)."""
    d5 = sc.d5
    key = SCENES["livingRoom"].key
    with sc.minting(d5):
        # ---- the wall pool takes the key light's colour
        glow = named(content, "LampGlow")
        fill0 = next(c for c in glow.children if c.tag == "Fill")
        g0 = fill0.children[0]
        r = float(g0.attrs["endX"]) - float(g0.attrs["startX"])
        g0.children = [g0.children[0], g0.children[-1]]   # the M4 mid stop goes: the falloff is two fills
        g1 = rad(d5, float(g0.attrs["startX"]), float(g0.attrs["startY"]), r * LAMP_POOL[1][1],
                 [(key, 0.0), ("00" + key[2:], 1.0)])
        for g, (op, _) in zip((g0, g1), LAMP_POOL):
            g.attrs["opacity"] = op
            centre, edge = g.children[0], g.children[-1]
            centre.attrs["colorValue"] = key
            centre.children.append(sc.bind("lightKey", 38))
            edge.attrs["colorValue"] = "00" + key[2:]
        glow.children.insert(glow.children.index(fill0) + 1, d5("Fill", g1, name="Fill"))

        # ---- the view sits behind the wall: an opening in the wall, the frame becomes a ring
        wall, frame = named(content, "Wall"), named(content, "WinFrame")
        mid = [(a + b) / 2 for a, b in zip(WINDOW_FRAME, WINDOW_GLASS)]   # under the frame's border
        for shape, hole in ((wall, mid), (frame, WINDOW_GLASS)):
            ox, oy = float(shape.attrs["x"]), float(shape.attrs["y"])
            at = next(i for i, c in enumerate(shape.children) if c.tag == "Rectangle")
            shape.children.insert(at + 1, _rect_path(d5, *hole, ox, oy, name="Opening"))
            next(c for c in shape.children if c.tag == "Fill").attrs["fillRule"] = "evenOdd"
        # the cornice ran behind the old sky: it now stops under the frame's border on both sides
        for name in ("CorniceShadow", "CorniceInlay"):
            sh = named(content, name)
            ox = float(sh.attrs["x"])
            path = next(c for c in sh.children if c.tag == "Rectangle")
            w = float(path.attrs["width"])
            x0, x1 = ox - w / 2, ox + w / 2
            path.attrs.update(width=mid[0] - x0, x=(x0 + mid[0]) / 2 - ox)
            sh.children.insert(sh.children.index(path) + 1,
                               d5("Rectangle", width=x1 - mid[2], height=path.attrs["height"],
                                  x=(mid[2] + x1) / 2 - ox, name="Path"))
        # the middle wall panel's top ran behind the old sky: it now starts under the ledge
        panel = named(content, "WallPanel1")
        path = next(c for c in panel.children if c.tag == "Rectangle")
        bottom = float(panel.attrs["y"]) + float(path.attrs["height"]) / 2
        top = WINDOW_GLASS[3] + 19.0
        panel.attrs["y"] = (top + bottom) / 2
        path.attrs["height"] = bottom - top

        # ---- stars in the view, above the skyline, clear of the moon
        rnd = random.Random(zlib.crc32(b"livingRoomStars"))
        stars = []
        while len(stars) < 12:
            x, y = rnd.uniform(WINDOW_GLASS[0] + 6, WINDOW_GLASS[2] - 6), rnd.uniform(WINDOW_GLASS[1] + 8, 440)
            if math.hypot(x - 640, y - 320) < 50 or WINDOW_PANES[0][2] - 4 < x < WINDOW_PANES[1][0] + 4 \
                    or WINDOW_PANES[0][3] - 4 < y < WINDOW_PANES[2][1] + 4:
                continue
            sz = rnd.choice((2.5, 3.0, 4.0))
            stars.append(sc.E(ORIGIN, f"Star{len(stars)}", x, y, sz, sz, sc.F("FFF4EEDC"),
                              opacity=round(rnd.uniform(0.55, 1.0), 2)))
        before(content, "WinSky", *stars)

        # ---- rain on the glass
        clip = d5("Shape", *[_rect_path(d5, *p, name="Pane") for p in WINDOW_PANES], x=0.0, y=0.0,
                  name="PaneClip")
        r_ = random.Random(zlib.crc32(b"RainGlass"))
        gx0, gy0, gx1, gy1 = WINDOW_GLASS
        sheets = []
        for label_, (n, tile, period) in (("Drips", GLASS_DRIPS), ("Streaks", GLASS_STREAKS)):
            kids = []
            for i in range(n):
                x, u = r_.uniform(gx0 + 4, gx1 - 4), r_.uniform(0, tile)
                ln = r_.uniform(26, 46) if label_ == "Streaks" else r_.uniform(18, 34)
                # every copy that is on the glass at some point of the loop (the sheet moves 0 -> tile)
                for k in range(-2, math.ceil((gy1 - gy0) / tile) + 1):
                    y = gy0 + u + k * tile
                    if y + tile + ln + 8 < gy0 or y > gy1:
                        continue
                    if label_ == "Streaks":
                        kids.append(sc.S(ORIGIN, f"GlassStreak{i}_{k + 1}", [(x, y), (x - ln * 0.18, y + ln)],
                                         sc.L("70C8D4E0", 1.6), closed=False))
                    else:
                        kids += [sc.E(ORIGIN, f"GlassDrop{i}_{k + 1}", x, y + ln, 5, 7, sc.F("B0DCE4EC")),
                                 sc.S(ORIGIN, f"GlassTrail{i}_{k + 1}", [(x, y), (x + 0.6, y + ln - 3)],
                                      sc.L("50DCE4EC", 2.0), closed=False)]
            sheet = d5("Node", *kids, x=0.0, y=0.0, name=f"Glass{label_}")
            sc.ambient(f"RainGlass{label_}", sc.A(f"amb_RainGlass{label_}", period, [
                sc.T(sheet, ease=None, y=[(0, 0.0, "linear"), (period, tile, "linear")])], loop=True))
            sheets.append(sheet)
        wet = d5("Shape", *[_rect_path(d5, *p, name="Pane") for p in WINDOW_PANES], sc.F(GLASS_WET[0]),
                 x=0.0, y=0.0, opacity=GLASS_WET[1], name="GlassWet")
        rain = d5("Node", sc.bind("rain", 18), d5("ClippingShape", sourceId=clip.ref(), name="Clip"), *sheets, wet,
                  x=0.0, y=0.0, opacity=0.0, name="RainGlass")
        # behind the mullions, in front of the frame (the streaks never leave the panes)
        before(content, "Lit0", rain, clip)

    # ---- back to front: content is front-most first, planes contiguous, draw order kept inside one
    def plane(e: El) -> int:
        name = str(e.attrs.get("name", ""))
        k = LIVING_ROOM_PLANES[name if name.startswith(HIT_PREFIX) else _root(name)]
        return 6 if k is None else k
    content.sort(key=lambda e: -plane(e))


DIORAMAS["livingRoom"] = DioramaSpec(LIVING_ROOM_PLANES, LIVING_ROOM_EMISSIVE, LIVING_ROOM_VEILS, living_room_light)


# ====================================================================== beach
# M5 ruling 4 (Task 5): planes back to front. Element roots as `DioramaSpec.planes` reads them.
BEACH_PLANES: dict[str, int | None] = {
    "RainLoop": None, "RainFx": None, "SunsetTint": None, "NightTint": None,
    "DuneGrass": 5, "DuneWet": 5, "NearDune": 5,
    # sand props, the palm and the passing flock; the shells and starfish lie on the mid-ground sand
    # (y 1470-1860, most of them not foreground), so they stay with the castle (ruling 4: 5 -> 4)
    **dict.fromkeys(("Flock", "Castle", "Flag", "Starfish", "Shell", *(f"ShellRib{i}_" for i in range(4)), "Crab", "CrabNpc",
                     "GullsNpc", "GullPlace", "PalmFrond", "TrunkRing", "PalmTrunk", "Umbrella", "TowelWeave", "TowelFringe",
                     "Towel", "UShadow", "TrailDots"), 4),
    # the surf line and the ground: the sand moves 4 -> 3, it paints behind the wet band and the foam
    **dict.fromkeys(("Wash", "Speck", "WetWash", "FoamLace", "Foam", "SandWet", "WetSand", "Sand"), 3),
    **dict.fromkeys(("BigWave", "BigWaveClip", "Wave"), 2),
    # the far sea with the horizon, the islands and the sun's glints on the water
    **dict.fromkeys(("SunsetPath", "Glint", "DistantHeadland", "DistantIslet", "SunReflection", "WaterRiffle",
                     "Sea"), 1),
    **dict.fromkeys(("Flyer", "SkyOvercast", "Cloud", "Sun", "SunsetSky", "Sky"), 0),
    # ruling 3: each hit zone rides the plane of its prop's art
    "Hit_crab": 4, "Hit_umbrella": 4, "Hit_seagull": 4,
}
# sea haze (`lightFog`) at the horizon (y 980): full there, clear high in the sky; in front of the
# sea it is a band that clears again toward the shore (the fourth value)
BEACH_VEILS = ((0.45, 560.0, 985.0), (0.25, 760.0, 985.0, 1090.0), (0.12, 860.0, 990.0, 1110.0))
BEACH_EMISSIVE = ("Sun", "Glint", "SunReflection", "SunsetPath", "SunsetSky")
# Steady rain (ruling 6): a looping streak layer at opacity `rain`, the dry sand and the near dune under
# a wet shade and the sky under an overcast, each at a share of `rain`.
BEACH_RAIN_LOOP_FRAMES = 120   # 2 s splash loop; the streak sheets loop on 18 / 34 frames
BEACH_WET = ("FF6E6656", 0.4)        # wet-sand shade and its opacity at rain 1
BEACH_OVERCAST = ("FF8E98A6", 0.45)  # overcast over the sky and the sun, opacity at rain 1


def beach_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """The beach's own pass (M5 Task 5): the sun's glow in `lightKey` (it is the glow that sets in the
    `sunset` event), then the steady rain bound to `rain` (history-free)."""
    d5 = sc.d5
    key = SCENES["beach"].key
    with sc.minting(d5):
        # ---- the sunset glow takes the key light's colour: a bound stop sets the alpha too, so the
        # M4 halo's 0x88 centre becomes the gradient's opacity
        glow = named(content, "SunGlow")
        g = next(c for c in glow.children if c.tag == "Fill").children[0]
        centre, edge = g.children[0], g.children[-1]
        g.attrs["opacity"] = round(int(str(centre.attrs["colorValue"])[:2], 16) / 255, 3)
        centre.attrs["colorValue"] = key
        centre.children.append(sc.bind("lightKey", 38))
        edge.attrs["colorValue"] = "00" + key[2:]
        # the glow now goes behind the disc (first child paints in front): over it, a key-coloured
        # glow would tint the sun itself
        sun = named(content, "Sun")
        sun.children.remove(glow)
        sun.children.append(glow)

        # ---- rain: streaks and splashes in screen space, in front of every plane
        streaks, loop = rain_fx(sc, "RainLoop", "88C8D6E4", frames=BEACH_RAIN_LOOP_FRAMES, loop=True,
                                ground=(1250.0, 1900.0))
        streaks.attrs["opacity"] = 0.0
        streaks.children.insert(0, sc.bind("rain", 18))
        sc.ambient("RainLoop", loop)
        content.insert(0, streaks)

        # ---- the sand darkens (in front of the dry sand and the wet band, behind the foam and specks)
        sand = named(content, "Sand")
        rect = next(c for c in sand.children if c.tag == "Rectangle")
        wet = d5("Shape", sc.bind("rain", 18, sc.conv(BEACH_WET[1])), clone(d5, rect), sc.F(BEACH_WET[0]),
                 x=sand.attrs["x"], y=sand.attrs["y"], opacity=0.0, name="SandWet")
        before(content, "WetSand", wet)
        # the foreground dune too (in front of the dune, behind its grass)
        dune = named(content, "NearDune")
        path = next(c for c in dune.children if c.tag == "PointsPath")
        dune_wet = d5("Shape", sc.bind("rain", 18, sc.conv(BEACH_WET[1])), clone(d5, path), sc.F(BEACH_WET[0]),
                      x=dune.attrs["x"], y=dune.attrs["y"], opacity=0.0, name="DuneWet")
        before(content, "NearDune", dune_wet)

        # ---- the sky clouds over: in front of the clouds and the sun, behind the far gulls
        sky = named(content, "Sky")
        rect = next(c for c in sky.children if c.tag == "Rectangle")
        overcast = d5("Shape", sc.bind("rain", 18, sc.conv(BEACH_OVERCAST[1])), clone(d5, rect),
                      sc.F(BEACH_OVERCAST[0]), x=sky.attrs["x"], y=sky.attrs["y"], opacity=0.0, name="SkyOvercast")
        before(content, "Cloud0", overcast)


DIORAMAS["beach"] = DioramaSpec(BEACH_PLANES, BEACH_EMISSIVE, BEACH_VEILS, beach_light)


def beach() -> str:
    sc = Scene("beach")
    d = sc.d
    S, E, F, L = sc.S, sc.E, sc.F, sc.L
    O = (0.0, 0.0)
    rnd = random.Random(11)
    INKC = "FF2A3040"
    horizon, shore = 980.0, 1180.0

    def full(name: str, paint: El, y0: float = -10, y1: float = H + 10, **kw: object) -> El:
        # M5 diorama bleed: 60 px past each side covers the nearest of these planes' travel (Plane3, 20 px)
        return d("Shape", d("Rectangle", width=float(W + 120), height=float(y1 - y0), name="Path"), paint,
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
    # the sea runs 40 px under the sand (Plane1 under Plane3, M5 bleed); the gradient keeps its M4 span
    sea = full("Sea", sc.vgrad(-125, 95, [("FF2A7AB8", 0.0), ("FF3AA8C8", 1.0)]), horizon, shore + 40)
    glints = [d("Shape", d("Rectangle", width=float(rnd.uniform(30, 70)), height=4.0, name="Path"), F("AAFFFFFF"),
                x=rnd.uniform(40, W - 40), y=rnd.uniform(horizon + 20, shore - 30), name=f"Glint{i}") for i in range(16)]
    gl_tracks = [sc.T(g, ease=None, opacity=[(0, 0.2), ((i * 17) % 100 + 10, 1.0, "linear"), ((i * 17) % 100 + 50, 0.2, "linear"),
                                             (180, 0.2)]) for i, g in enumerate(glints)]
    waves = []
    w_tracks = []
    for i, y in enumerate([shore - 70, shore - 30]):
        # the band runs 100 px past the left edge and 120 px past the right (its 30 px drift + Plane2's 12 px)
        pts = [(-100, y)] + [(x, y + (10 if (x // 60) % 2 else -6)) for x in range(20, W + 80, 60)] + \
            [(W + 120, y + 40, "c"), (-100, y + 40, "c")]
        wv = S(O, f"Wave{i}", pts, sc.vgrad(-30, 30, [("CCFFFFFF", 0.0), ("0076D0E0", 1.0)]))
        waves.append(wv)
        w_tracks.append(sc.T(wv, x=[(0, float(wv.attrs["x"])), (90, float(wv.attrs["x"]) + 30 * (1 if i else -1)),
                                    (180, float(wv.attrs["x"]))]))
    # 50 px below the frame (Plane3's 12 px of y travel); the gradient keeps its M4 span
    sand = full("Sand", sc.vgrad(-390, 350, [("FFF6DCA8", 0.0), ("FFE0B87A", 1.0)]), shore, H + 50)
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
                   L("FFC23A2A", 5), closed=False, origin=(crx + sx * 26, cry + 6))
                 for i, (sx, k) in enumerate([(-1, 0), (-1, 1), (-1, 2), (1, 0), (1, 1), (1, 2)])]
    claws = [S(CR, f"Claw{i}", [(crx + sx * 40, cry - 30), (crx + sx * 62, cry - 56), (crx + sx * 46, cry - 66, "c"),
                                (crx + sx * 52, cry - 50), (crx + sx * 30, cry - 44)], F("FFE04A36"), L("FF7A1A12", 2.5),
                 origin=(crx + sx * 30, cry - 20)) for i, sx in enumerate((-1, 1))]
    crab.add(*[E(CR, f"CPupil{i}", crx + sx * 12, cry - 40, 5, 6, F("FF20100C")) for i, sx in enumerate((-1, 1))],
             *[E(CR, f"CEye{i}", crx + sx * 12, cry - 40, 12, 12, F("FFFFFFFF"), L("FF20100C", 2)) for i, sx in enumerate((-1, 1))],
             *claws,
             E(CR, "Shell", crx, cry, 92, 60, sc.rgrad(46, [("FFF06A50", 0.0), ("FFC23A2A", 1.0)], cx=-10, cy=-10),
               L("FF7A1A12", 2.5)),
             *crab_legs)
    # Plant the feet during both pauses. Alternate tripods while side-stepping,
    # with a soft lift and a short body compression on each change of support.
    gait = []
    for i, leg_ in enumerate(crab_legs):
        keys = [(0, 0.0)]
        for f in range(3, 241, 3):
            walking = f < 60 or 120 < f < 180
            local = f if f < 60 else f - 120
            weight = math.sin(math.pi * min(local, 60) / 60) ** 0.5 if walking else 0.0
            keys.append((f, 0.22 * weight * math.sin(2 * math.pi * local / 20 + (i % 2) * math.pi), "linear"))
        gait.append(sc.T(leg_, ease=None, rotation=keys))
    sc.ambient("Crab", sc.A("amb_crab", 240, [
        sc.T(crab, x=[(0, crx), (60, crx - 40), (120, crx - 40), (180, crx), (240, crx)],
             y=[(f, cry - (1.4 * math.sin(math.pi * f / 10) ** 2 if f < 60 or 120 < f < 180 else 0), "linear")
                for f in range(0, 241, 3)]),
        *[sc.T(c, rotation=[(0, 0.0), (20, 0.25 * (1 if i else -1)), (40, 0.0), (240, 0.0)]) for i, c in enumerate(claws)],
        *gait], loop=True))

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
             *[S(GP, f"GFoot{i}", [(gx + dx, gy + 12), (gx + dx, gy + 17), (gx + dx - 5, gy + 18),
                                   (gx + dx + 4, gy + 18)], L("FFC7933F", 2), closed=False)
               for i, dx in enumerate((-7, 7))])
    gull_eye = next(c for c in gull.children if c.attrs.get("name") == "GEye")
    gull.children[0:0] = [S(GP, "GFeatherEdge", [(gx + 15, gy - 7), (gx + 35, gy - 1), (gx + 44, gy + 4)],
                            L("90E2E7E5", 1.5), closed=False),
                          S(GP, "GBreastShade", [(gx - 29, gy - 5), (gx - 20, gy + 8), (gx + 4, gy + 12)],
                            L("60A6B9BC", 2.4), closed=False)]
    sc.ambient("Gull", sc.A("amb_gull", 300, [sc.T(gull, rotation=[(0, 0.0), (200, 0.0), (215, -0.12), (230, 0.0), (300, 0.0)]),
        sc.T(gull_eye, scaleY=[(0, 1.0), (143, 1.0), (146, 0.05), (151, 1.0), (300, 1.0)])],
                            loop=True))
    for part in gull.children:
        part.attrs["y"] = float(part.attrs.get("y", 0)) - 18
    gull_reaction = d("Node", *gull.children, x=0.0, y=18.0, name="GullReaction")
    gull.children = [gull_reaction]
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
    # bigWave: a swell rises out of the sea (clipped at the shoreline, so it never fades as a
    # ghost), its foamy lip curls and collapses, then a lace-edged wash runs up the sand and
    # drains back, leaving darker wet sand that slowly dries.
    BW = (540.0, shore)
    wave_clip = d("Shape", d("Rectangle", width=float(W + 200), height=600.0, name="Path"), x=540.0, y=shore - 300,
                  name="BigWaveClip")
    body_pts = [(-700, 60, "c"), (-700, -50), (-420, -110), (-170, -190), (40, -248), (170, -246), (238, -214),
                (214, -186), (176, -196), (250, -150), (420, -112), (700, -70), (700, 60, "c")]
    wbody = S(Z := (0.0, 0.0), "BigWaveBody", body_pts,
              sc.vgrad(-250, 60, [("FF7FD6CF", 0.0), ("FF3FA7B4", 0.35), ("FF1D6E86", 1.0)]))
    face_light = S(Z, "BigWaveFace", [(-320, -120), (-80, -205), (120, -232), (60, -190), (-160, -140), (-380, -96)],
                   F("40E9FFF6"))
    # A connected, asymmetrical foam lip curls around the hollow face. Tiny
    # broken flecks erode its edge; equal separated discs look like beads.
    foam_lip = [(-478, -98), (-370, -129), (-278, -160), (-186, -193), (-101, -225),
                (-26, -248), (40, -264), (107, -267), (163, -259), (208, -242),
                (235, -221), (234, -203), (215, -190), (193, -192), (180, -205),
                (198, -214), (214, -211), (211, -223), (181, -239), (133, -249),
                (74, -249), (7, -238), (-71, -217), (-166, -183), (-270, -150),
                (-378, -120), (-477, -92)]
    scallops = [S(Z, "CrestRibbon", foam_lip,
                  sc.vgrad(-40, 40, [("FFFFFDF1", 0), ("FFE1F3E8", 0.7), ("A0ACDACE", 1)]),
                  tension=0.65),
                S(Z, "CurlHollow", [(159, -242), (188, -235), (211, -222), (201, -216),
                                    (181, -220), (170, -232)], F("FF2D8792"))]
    for i in range(22):
        x = -360 + i * 25 + rnd.uniform(-9, 9)
        y = -130 - 128 * math.sin((x + 400) / 650 * math.pi * 0.65)
        width = rnd.uniform(3, 12)
        scallops.append(E(Z, f"FoamFleck{i}", x, y + rnd.uniform(-6, 9), width, rnd.uniform(2, 5), F("C0FFFFF5")))
    spray = [E(Z, f"Spray{i}", 120 + i * 21, -273 - (i % 3) * 13,
               rnd.uniform(3, 7), rnd.uniform(5, 12), F("C8FFFFF5"), rotation=-0.4 + i * 0.13)
             for i in range(9)]
    for el in [wbody, face_light, *scallops, *spray]:
        el.children.insert(0, d("ClippingShape", sourceId=wave_clip.ref(), name="Clip"))
    crest = d("Node", *spray, *scallops, x=0.0, y=0.0, name="BigWaveCrest")
    # the crest breaks on the right, beside the avatar's head, and towers above the horizon
    big = d("Node", crest, face_light, wbody, x=760.0, y=shore + 420, scaleY=1.5, name="BigWave")
    wash_pts = [(-600, 0, "c"), (600, 0, "c"), (600, 70)] + \
               [(x, 96 + 14 * math.sin(x / 41.0) + (10 if (x // 90) % 2 else 0)) for x in range(560, -601, -80)] + \
               [(-600, 70)]
    wash = d("Node", S(Z, "WashLace", [(p[0], p[1] - 4) for p in wash_pts[3:-1]], L("D0FFFFFF", 5), closed=False),
             S(Z, "WashSheet", wash_pts, sc.vgrad(0, 100, [("E8F2FBF6", 0.0), ("B8CDEFE8", 0.7), ("60FFFFFF", 1.0)])),
             x=540.0, y=shore - 4, scaleY=0.0, name="Wash")
    wet_wash = S(O, "WetWash", [(p[0] + 540, p[1] * 1.08 + shore) + tuple(p[2:]) for p in wash_pts], F("FFB79A72"),
                 opacity=0.0)
    wave_anim = sc.A("ev_bigWave", 360, [
        sc.T(big, y=[(0, shore + 420), (16, shore + 300), (58, shore - 10, sc.ease_out), (76, shore + 8),
                     (106, shore + 440), (360, shore + 440)],
             x=[(0, 720.0), (76, 780.0), (360, 780.0)]),
        sc.T(gull_reaction, scaleY=[(0, 1.0), (48, 1.0), (61, 0.82), (78, 0.87),
                                    (94, 1.05), (113, 0.98), (133, 1.0), (360, 1.0)],
             rotation=[(0, 0.0), (49, 0.0), (62, 0.08), (86, 0.06), (110, -0.025), (133, 0.0), (360, 0.0)]),
        sc.T(wash, scaleY=[(0, 0.0), (86, 0.0), (128, 1.0, sc.ease_out), (150, 1.04), (220, 0.15), (250, 0.0),
                           (360, 0.0)],
             opacity=[(0, 1.0), (180, 1.0), (250, 0.0), (360, 0.0)]),
        sc.T(wet_wash, opacity=[(0, 0.0), (120, 0.0), (150, 0.75), (230, 0.65), (360, 0.0)]),
    ])
    # Roll the water through its contour, carrying the foam on the same
    # surface. The leading lip overtakes the body and folds down on impact.
    curl_poses = [(0, 0, 0), (32, -35, -5), (48, -18, -25), (62, 15, -5),
                  (76, 70, 45), (92, 120, 125), (110, 135, 165), (360, 0, 0)]

    def curl_point(x: float, y: float, dx: float, dy: float) -> tuple[float, float]:
        weight = math.exp(-((x - 150) / 250) ** 2) * max(0.0, min(1.0, (30 - y) / 280))
        return x + dx * weight, y + dy * weight

    for shape in (wbody, face_light, *scallops[:2]):
        path = next(c for c in shape.children if c.tag == "PointsPath")
        ox, oy = float(shape.attrs["x"]), float(shape.attrs["y"])
        poses = []
        for frame, dx, dy in curl_poses:
            pts = []
            for vertex in path.children:
                x, y = curl_point(float(vertex.attrs["x"]) + ox, float(vertex.attrs["y"]) + oy, dx, dy)
                pts.append((x - ox, y - oy, "c") if vertex.tag == "StraightVertex" else (x - ox, y - oy))
            poses.append((frame, smooth_path(d, pts, tension=0.65 if shape is scallops[0] else 1.0)))
        for i, vertex in enumerate(path.children):
            attrs = ("x", "y", "inRotation", "outRotation", "inDistance", "outDistance") if vertex.tag == "CubicDetachedVertex" else ("x", "y")
            wave_anim.add(sc.T(vertex, **{attr: [(f, float(p.children[i].attrs[attr])) for f, p in poses] for attr in attrs}))
    for fleck in scallops[2:]:
        x, y = float(fleck.attrs["x"]), float(fleck.attrs["y"])
        wave_anim.add(sc.T(fleck,
            x=[(f, curl_point(x, y, dx, dy)[0]) for f, dx, dy in curl_poses],
            y=[(f, curl_point(x, y, dx, dy)[1]) for f, dx, dy in curl_poses]))
    for i, particle in enumerate(spray):
        px_, py_ = float(particle.attrs["x"]), float(particle.attrs["y"])
        takeoff = 50 + i * 2
        wave_anim.add(sc.T(particle,
            x=[(0, px_), (takeoff, px_), (takeoff + 24, px_ + 28 + i * 3), (114, px_ + 58 + i * 3), (360, px_)],
            y=[(0, py_), (takeoff, py_), (takeoff + 13, py_ - 24 - i * 2), (114, py_ + 60), (360, py_)],
            opacity=[(0, 0.0), (takeoff - 2, 0.0), (takeoff + 2, 0.9), (105, 0.0), (360, 0.0)]))
    sc.one_shot("bigWave", wave_anim)
    flock = []
    flock_tracks = []
    for i, (x0, y0, sz) in enumerate([(-140, 520, 70), (-300, 430, 58), (-420, 600, 50), (-560, 470, 44)]):
        b, flap = bird(sc, f"Flock{i}", x0, y0, sz, "FF2A3040", body=True, phase=i * 5)
        flock.append(b)
        flock_tracks += flap
        flock_tracks.append(sc.T(b, x=[(0, float(x0)), (330, float(x0) + W + 760)],
                                 y=[(0, float(y0)), (110, float(y0) - 90), (220, float(y0) - 40),
                                    (330, float(y0) - 120)],
                                 rotation=[(0, -0.08), (110, 0.05), (220, -0.06), (330, 0.0)]))
    sc.one_shot("seagulls", sc.A("ev_seagulls", 330, flock_tracks))
    sunset_tint = d("Shape", d("Rectangle", width=float(W + 40), height=float(H + 40), name="Path"),
                    sc.vgrad(-980, 980, [("FFFFC2CF", 0.0), ("FFFFB27C", 0.48), ("FFE58A62", 0.62), ("FFB46A6A", 1.0)]),
                    x=W / 2, y=H / 2, opacity=0.0, blendModeValue=24, name="SunsetTint")
    sun_path = d("Node", *[S(O, f"SunsetPath{i}", [(700 - (14 + i * 9), horizon + 8 + i * 13), (700, horizon + 6 + i * 13),
                                                   (700 + (14 + i * 9), horizon + 8 + i * 13)],
                             L("FFFFB45A" if i % 2 else "C0FFD890", 3), closed=False) for i in range(14)],
                 x=0.0, y=0.0, opacity=0.0, name="SunsetPath")
    sunset = sc.A("ev_sunset", 720, [
        sc.T(sunset_sky, opacity=[(0, 0.0), (180, 1.0), (560, 1.0), (720, 0.0)]),
        sc.T(sunset_tint, opacity=[(0, 0.0), (200, 0.85), (540, 0.85), (720, 0.0)]),
        sc.T(sun_path, opacity=[(0, 0.0), (160, 1.0), (300, 0.7), (420, 0.0), (720, 0.0)]),
        sc.T(sun, y=[(0, 640.0), (220, 940.0), (400, 1060.0), (560, 1060.0), (720, 640.0)],
             x=[(0, 780.0), (220, 700.0), (560, 700.0), (720, 780.0)]),
    ])
    sc.one_shot("sunset", sunset)
    rain_node, rain_anim = rain_fx(sc, "Rain", "99E0F0FF", darken="FF1A2A40",
                                   extra=[sc.T(sun, ease=None, opacity=[(0, 1.0), (40, 0.2, "linear"), (420, 0.2, "linear"), (480, 1.0)])])
    sc.one_shot("rain", rain_anim)

    deco = []
    for i, (sx_, sy_, r_) in enumerate([(232, 1470, 30), (880, 1752, 26), (930, 1610, 30)]):
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = r_ if k % 2 == 0 else r_ * 0.45
            pts.append((sx_ + rr * math.cos(a), sy_ + rr * math.sin(a), "c4"))
        deco.append(S(O, f"Starfish{i}", pts, sc.rgrad(r_, [("FFFFA070", 0.0), ("FFE0604A", 1.0)]), L("FFA03A2A", 2)))
    for i, (sx_, sy_) in enumerate([(160, 1760), (980, 1490), (250, 1840), (820, 1860)]):
        fan = [(sx_ - 18, sy_), (sx_ - 14, sy_ - 16), (sx_, sy_ - 22), (sx_ + 14, sy_ - 16), (sx_ + 18, sy_), (sx_, sy_ + 8, "c")]
        deco.append(S(O, f"Shell{i}", fan, F("FFFFF0E4"), L("FFC8A88A", 2)))
        deco += [S(O, f"ShellRib{i}_{k}", [(sx_, sy_ + 6), (sx_ + (k - 1) * 10, sy_ - 16)], L("FFC8A88A", 1.5), closed=False)
                 for k in range(3)]
    # the sandcastle sits at the left edge, clear of the avatar
    castle = [S(O, "Castle", [(110, 1700, "c"), (110, 1620, "c"), (130, 1620, "c"), (130, 1600, "c"), (150, 1600, "c"),
                              (150, 1620, "c"), (190, 1620, "c"), (190, 1580, "c"), (214, 1580, "c"), (214, 1620, "c"),
                              (250, 1620, "c"), (250, 1700, "c")], sc.vgrad(-60, 60, [("FFF0D08A", 0.0), ("FFC8A060", 1.0)]),
                L("FFA07A40", 2.5)),
              S(O, "Flag", [(202, 1580), (202, 1540), (230, 1550), (202, 1560)], F("FFE04848"))]
    hits = [sc.hit("crab", crx, cry - 20, 180, 130), sc.hit("umbrella", ux, uy + 40, 400, 300),
            sc.hit("seagull", *place_point("beach", "GullPlace", gx - 10, gy - 10), 120, 100)]
    for h, pid in zip(hits, ["crab", "umbrella", "seagull"]):
        sc.prop(pid, h)
    content = [rain_node, sunset_tint, *flock, *castle, *deco, crab, gull, post, umb, towel, umb_shadow, wash, *specks,
               wet_wash, foam, wet, sand, big, wave_clip,
               *waves, sun_path, *glints, sea, *flyers, *clouds, sun, sunset_sky, sky]
    front_weather(sc, "88C8D6E4")  # M6 ruling 8: the beach RainLoop colour
    sc.npc_rig = lambda s_, c_, h_: scene_npc.beach_crab(s_, c_, h_, PARALLAX_GAINS, PARALLAX_TRAVEL)  # M8
    sc.v12_art = beach_v12   # M9: the trail in the sand, the gulls (contract v12)
    sc.v13_art = beach_night  # M10: the beach's night (contract v13 `night`)
    return sc.write(content, hits)


# ====================================================================== deepSpace
# M5 ruling 4 (Task 6): planes back to front. Space has no ground, so depth reads from size and
# overlap: the three asteroids sit on three planes by size (a full name overrides the root).
DEEP_SPACE_PLANES: dict[str, int | None] = {
    # the warp covers the whole frame (streaks scaled 4.6x, the core 2.4x, a full-frame flash)
    "Flash": None, "Warp": None, "WarpCoreN": None,
    "Asteroid0": 5,                                    # the near asteroid (r 70)
    # the front rock (r 50), the duck and the mothership whose beam lifts it (same plane: the beam
    # lands on the duck at every parallax)
    "Asteroid1": 4, "Mothership": 4, "DuckPlace": 4,
    "Asteroid2": 3, "UfoFlee": 3,                      # the small asteroid (r 36) and the saucer
    "PlanetPlace": 2, "Moonlet": 2,
    # the galaxy, the bright stars, the nebula pulse (in front of the stars, as in M4) and the meteor
    **dict.fromkeys(("Meteor", "Galaxy", "PulseRingN", "PulseSwellN", "Star"), 1),
    **dict.fromkeys(("Nebula", "DustStar", "InterstellarDust", "Void"), 0),
    # ruling 3: each hit zone rides the plane of its prop's art
    "Hit_planet": 2, "Hit_ufo": 3, "Hit_rubberDuck": 4,
}
# nebula-tinted dust (`lightFog`) in front of Plane0 and Plane1, even over the whole frame (space has
# no horizon): clear 1 px above the bleed, full from there down
DEEP_SPACE_VEILS = ((0.25, -61.0, -60.0), (0.12, -61.0, -60.0))
DEEP_SPACE_EMISSIVE = ("Star", "DustStar", "Galaxy", "Nebula", "InterstellarDust", "PulseSwellN", "PulseRingN",
                       "AtmosphericLimb", "ULight", "SLight", "Warp", "WarpCoreN", "Flash", "Meteor")
NEBULA_WASH = ("Nebula2", 0.2)   # the nebula that takes `lightKey`, and its gradient opacity


def deep_space_light(sc: Scene, content: list[El], d6: Doc) -> None:
    """deepSpace's own pass (M5 Task 6): the nebula wash in `lightKey` (deepSpace ignores `rain`),
    the moonlet back beside its planet, then the content regrouped back to front by plane (draw
    order kept inside a plane)."""
    key = SCENES["deepSpace"].key
    name, opacity = NEBULA_WASH
    with sc.minting(sc.d5):
        # a bound stop colour sets the alpha too: the M4 alpha becomes the gradient's opacity
        wash = named(content, name)
        g = next(c for c in wash.children if c.tag == "Fill").children[0]
        g.attrs["opacity"] = opacity
        centre, edge = g.children[0], g.children[-1]
        centre.attrs["colorValue"] = key
        centre.children.append(sc.bind("lightKey", 38))
        edge.attrs["colorValue"] = "00" + key[2:]
    # the moonlet stayed at its pre-M3 spot when the planet group was re-placed, hidden behind the
    # planet: it moves with the planet (same offset), above the rings' near end
    moonlet = named(content, "Moonlet")
    mx, my = place_point("deepSpace", "PlanetPlace", float(moonlet.attrs["x"]), float(moonlet.attrs["y"]))
    moonlet.attrs.update(x=mx, y=my)

    def plane(e: El) -> int:
        k = plane_of(DIORAMAS["deepSpace"], str(e.attrs.get("name", "")))
        return 6 if k is None else k
    content.sort(key=lambda e: -plane(e))


DIORAMAS["deepSpace"] = DioramaSpec(DEEP_SPACE_PLANES, DEEP_SPACE_EMISSIVE, DEEP_SPACE_VEILS, deep_space_light)


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
    ufo_flee = d("Node", ufo, x=0.0, y=0.0, name="UfoFlee")   # alienShip chases the saucer away
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
    sc.ambient("Ufo", sc.A("amb_ufo", 720, [
        sc.T(ufo, x=[(0, ux), (240, ux + 22), (510, ux - 13), (720, ux)],
             y=[(0, uy), (165, uy - 26), (395, uy + 9), (590, uy - 12), (720, uy)],
             rotation=[(0, 0.04), (215, -0.035), (480, 0.01), (640, 0.055), (720, 0.04)]),
        *[sc.T(l_, ease=None, opacity=[(0, 1.0)] +
              [(c + (i * 12) % 60 + delta, value, "linear")
               for c in (0, 240, 480) for delta, value in ((1, 0.3), (22, 1.0))] + [(720, 1.0)]) for i, l_ in enumerate(lights)],
        sc.T(beam, opacity=[(0, 0.6), (190, 0.9), (360, 0.7), (570, 1.0), (720, 0.6)])], loop=True))

    # rubber duck drifting (front right)
    dx_, dy_ = 760.0, 1260.0
    duck = d("Node", x=dx_, y=dy_, name="Duck")
    # the alien ship's beam lifts and spins this (pivot at the duck, children keep absolute coords)
    duck_lift = d("Node", d("Node", duck, x=-dx_, y=-dy_, name="DuckLiftPivot"), x=dx_, y=dy_, name="DuckLift")
    DP = (dx_, dy_)
    duck.add(E(DP, "DEye", dx_ + 30, dy_ - 56, 10, 12, F("FF101010")),
             S(DP, "DBeak", [(dx_ + 50, dy_ - 44), (dx_ + 82, dy_ - 40, "c"), (dx_ + 50, dy_ - 30)], F("FFF07A20"), L("FF8A3A10", 2)),
             E(DP, "DHead", dx_ + 26, dy_ - 46, 64, 60, F("FFFFD830"), L("FFB08010", 2.5)),
             S(DP, "DWing", [(dx_ - 30, dy_ - 6), (dx_ + 10, dy_ - 14), (dx_ + 4, dy_ + 10)], F("FFF0C020"), L("FFB08010", 2)),
             S(DP, "DBody", [(dx_ - 60, dy_ - 30, "c"), (dx_ - 30, dy_ - 12), (dx_ + 20, dy_ - 16), (dx_ + 54, dy_ - 4),
                             (dx_ + 40, dy_ + 28), (dx_ - 20, dy_ + 34), (dx_ - 56, dy_ + 10)], F("FFFFD830"), L("FFB08010", 2.5)))
    # A slow closed orbit retains momentum through top/bottom turning points;
    # the roll trails the drift. Its period differs from the saucer's hover.
    orbit = [(f, 2 * math.pi * f / 1020) for f in range(0, 1021, 30)]
    sc.ambient("Duck", sc.A("amb_duck", 1020, [sc.T(duck, ease=None,
        rotation=[(f, -0.15 + 0.1 * (math.sin(t - 0.6) - math.sin(-0.6)), "linear") for f, t in orbit],
        x=[(f, dx_ - 24 * math.sin(t) + 9 * math.sin(2 * t), "linear") for f, t in orbit],
        y=[(f, dy_ + 17 * (math.cos(t) - 1) + 5 * math.sin(2 * t), "linear") for f, t in orbit])],
        loop=True, seam_hold=True))

    # ---- events
    met, met_anim = streak_fx(sc, "Meteor", (1000, 300), (120, 1100), 70, 380, "FFFFA040", "CCFF6A20", 16)
    sc.one_shot("meteor", met_anim)
    # warp: from a point above the avatar's head, tapered coloured streaks accelerate outward,
    # a blue-white core swells, then a screen-blended flash and a fading after-glow
    WC = (540.0, 620.0)
    streaks = []
    for i in range(44):
        a = 2 * math.pi * i / 44 + rnd.uniform(-0.06, 0.06)
        r0 = rnd.uniform(70, 260)
        ln = rnd.uniform(140, 300)
        wd = rnd.uniform(3, 7)
        ca, sa = math.cos(a), math.sin(a)
        col = rnd.choice(["FFBFE6FF", "FF9FD0FF", "FFE9C8FF", "FFFFFFFF"])
        p0 = (WC[0] + ca * r0, WC[1] + sa * r0)
        p1 = (WC[0] + ca * (r0 + ln), WC[1] + sa * (r0 + ln))
        streak = S(WC, f"Warp{i}", [(p0[0] - sa * 0.6, p0[1] + ca * 0.6), (p1[0] - sa * wd, p1[1] + ca * wd),
                                    (p1[0] + ca * 6, p1[1] + sa * 6, "c"), (p1[0] + sa * wd, p1[1] - ca * wd),
                                    (p0[0] + sa * 0.6, p0[1] - ca * 0.6)], F(col), tension=0.3)
        streaks.append(streak)
    for st_ in streaks:
        st_.attrs["blendModeValue"] = 14            # screen light; native 0.1.11 rejects additive (12)
    warp = d("Node", *streaks, x=WC[0], y=WC[1], opacity=0.0, name="Warp")
    warp_core = E(WC, "WarpCore", WC[0], WC[1], 600, 600,
                  sc.rgrad(300, [("FFFFFFFF", 0.0), ("C0A8D8FF", 0.25), ("40707CFF", 0.6), ("00707CFF", 1.0)]))
    warp_core_n = d("Node", warp_core, x=WC[0], y=WC[1], opacity=0.0, scaleX=0.2, scaleY=0.2, name="WarpCoreN")
    flash = d("Shape", d("Rectangle", width=float(W), height=float(H), originX=0.0, originY=0.0, name="Path"),
              d("Fill", rad(d, WC[0], WC[1], 1400, [("FFFFFFFF", 0.0), ("FFC6DCFF", 0.4), ("FF6E86C8", 1.0)]),
                name="Fill"), opacity=0.0, blendModeValue=14, name="Flash")
    warp_anim = sc.A("ev_warp", 150, [
        sc.T(warp, scaleX=[(0, 0.3, sc.ease_in), (84, 3.6), (96, 4.6), (150, 4.6)],
             scaleY=[(0, 0.3, sc.ease_in), (84, 3.6), (96, 4.6), (150, 4.6)],
             opacity=[(0, 0.0), (12, 0.9), (84, 1.0), (98, 0.0), (150, 0.0)]),
        sc.T(warp_core_n, scaleX=[(0, 0.2), (80, 1.2, sc.ease_in), (90, 2.4), (150, 2.4)],
             scaleY=[(0, 0.2), (80, 1.2, sc.ease_in), (90, 2.4), (150, 2.4)],
             opacity=[(0, 0.0), (30, 0.5), (84, 1.0), (96, 0.55), (150, 0.0)]),
        sc.T(flash, opacity=[(0, 0.0, "hold"), (84, 0.0), (86, 0.5, "linear"), (90, 0.12), (130, 0.0), (150, 0.0)]),
    ])
    sc.one_shot("warp", warp_anim)
    ship = d("Node", x=-500.0, y=700.0, name="Mothership")
    SP = (0.0, 0.0)
    beam = S(SP, "ShipBeam", [(-46, 50), (46, 50), (150, 520), (-150, 520)],
             sc.vgrad(-235, 235, [("C0B8FFD8", 0.0), ("40B8FFD8", 0.8), ("00B8FFD8", 1.0)]), opacity=0.0,
             blendModeValue=14)
    ship.add(beam, *[E(SP, f"SLight{i}", -240 + i * 60, 30, 14, 14, F("FFFF5AA0")) for i in range(9)],
             S(SP, "HullSheen", [(-300, 4), (-160, -30), (0, -48), (160, -30), (300, 4), (160, -18), (0, -34),
                                 (-160, -18)], F("40E8F0FF")),
             E(SP, "Belly", 0, 50, 300, 30, sc.rgrad(150, [("C08CFFE0", 0.0), ("008CFFE0", 1.0)])),
             S(SP, "Hull", [(-360, 20), (-200, -40), (0, -70), (200, -40), (360, 20), (200, 60), (-200, 60)],
               sc.vgrad(-70, 60, [("FF6A7290", 0.0), ("FF262A3A", 1.0)]), L("FF0E1018", 3)),
             S(SP, "Bridge", [(-80, -50), (-40, -100), (40, -100), (80, -50)], sc.vgrad(-50, 20, [("FF9AA8C8", 0.0), ("FF4A5270", 1.0)]),
               L("FF0E1018", 2.5)))
    hover_x = 850.0
    ship_anim = sc.A("ev_alienShip", 480, [
        sc.T(ship, x=[(0, -500.0, sc.ease_out), (150, hover_x), (190, hover_x + 14), (250, hover_x - 10),
                      (300, hover_x, sc.ease_in), (480, W + 520.0)],
             y=[(0, 640.0), (150, 730.0), (200, 722.0), (250, 734.0), (300, 728.0), (480, 600.0)],
             rotation=[(0, 0.08), (150, -0.04), (180, 0.0), (300, 0.0), (340, 0.06), (480, 0.08)]),
        # the little saucer bolts off-screen when the mothership arrives, and sneaks back after
        sc.T(ufo_flee, x=[(0, 0.0), (70, 0.0, sc.ease_in), (110, 520.0), (400, 520.0, sc.ease_out), (470, 0.0),
                          (480, 0.0)]),
        sc.T(beam, opacity=[(0, 0.0), (160, 0.0), (176, 1.0), (280, 1.0), (296, 0.0), (480, 0.0)],
             scaleX=[(0, 0.4), (160, 0.4), (176, 1.0), (280, 1.0), (296, 0.6), (480, 0.6)]),
        sc.T(duck_lift, y=[(0, dy_), (176, dy_), (240, dy_ - 110.0), (262, dy_ - 96.0), (290, dy_, sc.ease_in),
                           (300, dy_ + 6.0), (312, dy_), (480, dy_)],
             rotation=[(0, 0.0), (176, 0.0), (270, 6.2832), (300, 6.2832), (480, 6.2832)]),
        *[sc.T(c, ease=None, opacity=[(f, 1.0 if ((f // 12) + i) % 3 else 0.25, "hold") for f in range(0, 481, 12)])
          for i, c in enumerate(ship.children[1:10])]])
    sc.one_shot("alienShip", ship_anim)
    # nebulaPulse: the nebula's heart brightens (screen-blended swell), shock rings of coloured light
    # roll outward through the clouds, and the nebulae breathe out with them
    NC = (380.0, 640.0)
    swell = d("Node", E(NC, "PulseSwell", NC[0], NC[1], 1100, 1100,
                         sc.rgrad(550, [("FFF6B8FF", 0.0), ("A0C060F0", 0.3), ("3050A0E0", 0.65), ("00305080", 1.0)])),
              x=NC[0], y=NC[1], opacity=0.0, scaleY=0.75, name="PulseSwellN")
    swell.children[0].attrs["blendModeValue"] = 14
    rings = []
    for k, col in enumerate(["FFF0B0FF", "FF90E8FF", "FFFFC8E0"]):
        rg = d("Node", E(NC, f"PulseRing{k}", NC[0], NC[1], 400, 400, L(col, 14 - k * 3)),
               E(NC, f"PulseRingSoft{k}", NC[0], NC[1], 400, 400, L("60" + col[2:], 40)),
               x=NC[0], y=NC[1], opacity=0.0, scaleX=0.1, scaleY=0.08, name=f"PulseRingN{k}")
        for c in rg.children:
            c.attrs["blendModeValue"] = 14
        rings.append(rg)
    pulse = sc.A("ev_nebulaPulse", 200, [
        sc.T(swell, opacity=[(0, 0.0), (18, 0.95, sc.ease_out), (60, 0.6), (200, 0.0)],
             scaleX=[(0, 0.6), (30, 1.1), (200, 1.25)], scaleY=[(0, 0.45), (30, 0.82), (200, 0.92)]),
        *[sc.T(rg, scaleX=[(0, 0.1), (10 + 22 * k, 0.1), (110 + 22 * k, 3.6 - 0.4 * k, sc.ease_out), (200, 3.6 - 0.4 * k)],
               scaleY=[(0, 0.08), (10 + 22 * k, 0.08), (110 + 22 * k, 2.7 - 0.3 * k, sc.ease_out), (200, 2.7 - 0.3 * k)],
               opacity=[(0, 0.0), (10 + 22 * k, 0.0), (16 + 22 * k, 1.0), (110 + 22 * k, 0.0), (200, 0.0)])
          for k, rg in enumerate(rings)],
        *[sc.T(n, scaleX=[(0, 1.0), (40, 1.25), (200, 1.0)],
               scaleY=[(0, float(n.attrs.get("scaleY", 1.0))), (40, float(n.attrs.get("scaleY", 1.0)) * 1.25),
                       (200, float(n.attrs.get("scaleY", 1.0)))]) for n in nebulae]])
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
    hits = [sc.hit("planet", *place_point("deepSpace", "PlanetPlace", px, py), 340, 340),
            sc.hit("ufo", ux, uy - 20, 240, 130),
            sc.hit("rubberDuck", *place_point("deepSpace", "DuckPlace", dx_, dy_ - 20), 160, 120)]
    for h, pid in zip(hits, ["planet", "ufo", "rubberDuck"]):
        sc.prop(pid, h)
    content = [flash, warp, warp_core_n, met, *rocks, ship, duck_lift, ufo_flee, planet_g, moonlet, galaxy, *rings, swell, *stars,
               *nebulae, bg]
    sc.npc_rig = scene_npc.deep_space_alien   # M8: the alien in the ufo (contract v11)
    sc.v12_art = deep_space_v12               # M9: the planet's bands spin (contract v12)
    return sc.write(content, hits)


# ====================================================================== M9: v12 art in the M8 scenes
# Lane E (contract v12, rulings 8, 10, 12, 13): the drag art of the four M8 scenes, the beach's gulls
# (scene_npc.beach_gulls), the moon's phase in livingRoom and campfire, the December lights in the
# living room. Everything mints from the scene's `d9` (M9_ID_START) with private converters (never
# `Scene.conv`'s shared cache, whose first caller would move a later pass's ids), and draws nothing at
# the v12 defaults: each scene renders exactly as in M8. The art is history-free (formula binds on
# the view-model numbers; the app owns the gestures, ruling 7).
#
# The drag handles as built (artboard px at parallax 0; the contract table copies them):
V12_DRAG_RECTS: dict[str, tuple[str, tuple[float, float, float, float], int]] = {
    "livingRoom": ("cord", (270.0, 770.0, 370.0, 940.0), 4),     # the cord and its bead, on the lamp
    "campfire": ("poke", (0.0, 1040.0, 330.0, 1340.0), 4),      # the lying stick + the tip's box (POKE_HANDLE)
    "beach": ("sand", (830.0, 1230.0, 980.0, 1700.0), 4),       # the sand right of the avatar (fix round 2: TRAIL_PATCH)
    "deepSpace": ("spin", (150.0, 440.0, 450.0, 740.0), 2),     # the planet's disc (r 150 at 300, 590)
}
KEY_X, KEY_Y, KEY_ROTATION, KEY_SCALE_X, KEY_SCALE_Y, KEY_OPACITY = 13, 14, 15, 16, 17, 18


def _v12_formula(sc: Scene, toks: list[El]) -> El:
    conv = sc.d9("DataConverterFormula", *toks)
    sc.roots.append(conv)
    return conv


def _v12_lin(sc: Scene, k: float, c: float = 0.0, lo: float | None = None, hi: float | None = None) -> El:
    """A private `c + k x input` converter (clamped to [lo, hi] when given), minted from `d9`."""
    f = Formulas(sc.d9, sc.vpath)
    toks = [*([] if c == 0 else [f.val(c), f.op("+")]), f.val(k), f.op("*"), *f.inp()]
    if lo is not None:
        toks = f.fn("max", [f.val(lo)], toks)
    if hi is not None:
        toks = f.fn("min", [f.val(hi)], toks)
    return _v12_formula(sc, toks)


def _m10_formula(sc: Scene, toks: Callable[[Formulas], list[El]]) -> El:
    """A private formula converter minted from `d10` (M10), a root element of the scene file."""
    f = Formulas(sc.d10, sc.vpath)
    conv = sc.d10("DataConverterFormula", *toks(f))
    sc.roots.append(conv)
    return conv


def _v12_bind(sc: Scene, prop: str, key: int, conv: El) -> El:
    return sc.d9("DataBindContext", sourcePathIds=sc.vpath(prop), propertyKey=key, converterId=conv.ref())


def _top(content: list[El], name: str) -> int:
    return next(i for i, e in enumerate(content) if e.attrs.get("name") == name)


def phase_moon(sc: Scene, content: list[El], cx: float, cy: float, r: float, dark: str) -> None:
    """Ruling 12: the scene's M8 moon (the top-level `Crater*` and `Moon`, contiguous) goes into
    `MoonPhased` (shown only at `moonPhase` -1, world_kit.hide_when_phased) and `MoonRig` takes over
    for a phase 0..1, its lit disc a copy of the M8 moon (craters included). `dark` is the sky behind
    the moon as rendered (glow included) at alpha 0.9; the disc and the dark side skip the colour fit
    (`emit*`), as the M8 moon does."""
    d9 = sc.d9
    kids = [e for e in content if _root(e.attrs.get("name")) in ("Crater", "Moon")]
    at = content.index(kids[0])
    assert content[at:at + len(kids)] == kids, "the M8 moon is not contiguous"
    lit_kids = []
    for k in kids:
        c = clone(d9, k, x=round(float(k.attrs["x"]) - cx, 4), y=round(float(k.attrs["y"]) - cy, 4))
        if k.attrs.get("name") == "Moon":
            c.attrs["name"] = EMISSIVE_PREFIX + "MoonLit"
        lit_kids.append(c)
    lit = d9("Node", *lit_kids, x=0.0, y=0.0, name="MoonLitArt")
    wrapper = world_kit.hide_when_phased(sc, d9, "MoonPhased", kids)
    rig = world_kit.moon_rig(sc, d9, cx, cy, r, lit, dark)
    named([rig], "MoonDark").attrs["name"] = EMISSIVE_PREFIX + "MoonDark"
    content[at:at + len(kids)] = [wrapper, rig]


# ---------------------------------------------------------------- livingRoom: the lamp's pull cord
LAMP_CORD = (320.0, 758.0)     # where the cord leaves the shade's rim (lamp x 286, rim y 760, half-width 74)
CORD_LENGTH = 72.0             # the cord at rest, to the bead's knot
CORD_PULL = 80.0               # px the bead travels at `cord` 1 (the cord stretches, thinning to 55 %)
CORD_THIN = 0.45
# Fix round 1 (orchestrator ruling): discoverability beats pixel identity. The cord hangs at its natural
# length at `cord` 0 (visible); the identity-to-M8 gates exclude exactly `V12_REST_AFFORDANCE`.
CORD_COLOURS = ("FFE6D8BC", "FFC28C5A", "FF6A4026", "FF2A2030")   # cotton, bead light, bead shade, ink
# ruling 13: string lights draped under the curtain rod, across the window's top and the curtains
FESTIVE_POINTS = [(296.0 + 44.0 * i, round(206.0 + 18.0 * (i % 2) + 16.0 * math.sin(math.pi * i / 11), 2))
                  for i in range(12)]
FESTIVE_COLOURS = ("FFFFC86A", "FFFF7466")
LIVING_ROOM_MOON = (640.0, 320.0, 30.0, "E6383C63")   # cx, cy, r, the window's sky by the moon (under the fog veil) at 0.9


def lamp_cord(sc: Scene) -> El:
    """`LampCord` (contract v12 `cord`): a cotton pull cord with a wooden bead under the lamp's shade,
    hanging at its natural length at `cord` 0 (always drawn: the affordance), stretched down by
    `CORD_PULL` px at `cord` 1 (the bead follows, the cord thins). History-free."""
    d9 = sc.d9
    cotton, light, shade, ink = CORD_COLOURS
    with sc.minting(d9):
        line = sc.S(ORIGIN, "CordLine", [(0.0, 0.0), (0.0, CORD_LENGTH)], sc.L(cotton, 2.2), closed=False,
                    origin=ORIGIN)
        line.children[0:0] = [_v12_bind(sc, "cord", KEY_SCALE_Y, _v12_lin(sc, CORD_PULL / CORD_LENGTH, 1.0)),
                              _v12_bind(sc, "cord", KEY_SCALE_X, _v12_lin(sc, -CORD_THIN, 1.0))]
        bead = sc.node("CordBead", 0.0, CORD_LENGTH,
                       _v12_bind(sc, "cord", KEY_Y, _v12_lin(sc, CORD_PULL, CORD_LENGTH)),
                       sc.E(ORIGIN, "BeadGlint", -2.5, 6.0, 3.5, 5.0, sc.F("B0FFF2DC")),
                       sc.E(ORIGIN, "Bead", 0.0, 10.0, 13.0, 17.0, sc.rgrad(11, [(light, 0.0), (shade, 1.0)], cx=-3, cy=-4),
                            sc.L(ink, 1.3)),
                       sc.E(ORIGIN, "CordKnot", 0.0, 1.0, 5.0, 4.0, sc.F(cotton)))
        return sc.node("LampCord", *LAMP_CORD, bead, line)


def living_room_v12(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The cord (in front of the lamp), the moon's phase in the window, the December lights (the front
    of the curtains' plane)."""
    content.insert(_top(content, "Lamp"), lamp_cord(sc))
    phase_moon(sc, content, *LIVING_ROOM_MOON)
    content.insert(0, world_kit.festive_lights(sc, sc.d9, FESTIVE_POINTS, FESTIVE_COLOURS))


# ---------------------------------------------------------------- campfire: the poke stick
# Fix round 1 (orchestrator ruling): the stick is visible at rest, lying on the ground left of the fire
# (outside the avatar's band x 330-750); `poke` 0 -> 1 lifts it into the fire, entering from the lower
# left (it never passes behind the avatar). Its tip: lerp(POKE_REST, POKE_TIP, poke) + poke x (pokeX,
# pokeY) x POKE_RANGE; its angle (the stick runs from the tip toward its far end, off the left edge):
# lerp(POKE_REST_ANGLE, POKE_ANGLE, poke).
POKE_TIP = (196.0, 1130.0)     # the tip at poke 1, pokeX = pokeY = 0: in the logs, under the flames
POKE_RANGE = (108.0, 80.0)     # tip travel at pokeX / pokeY = +-1 (times poke): the ember glow stays left of x 330
POKE_ANGLE = 2.3               # rad: lifted, the stick runs down-left from the tip, off the left edge
POKE_REST = (282.0, 1272.0)    # the tip lying on the ground, below the front stones
POKE_REST_ANGLE = 2.96         # rad: lying, the stick runs left and a little down, off the left edge
POKE_LENGTH = 760.0
POKE_TURN = (0.075, 0.044)     # rotation per pokeX / pokeY (x poke): the far hand moves less than the tip
POKE_SHADOW = ("58080608", 6.0, 3.0)   # the stick's shadow on the ground at rest (colour, drop px), fading x 3 poke
POKE_GLOW_REST = 0.35          # the ember's glow lying on the ground (1 in the fire)
POKE_HANDLE = (0.0, 1040.0, 330.0, 1340.0)   # the drag handle: the lying stick and the tip's box
CAMPFIRE_MOON = (800.0, 690.0, 60.0, "E6414E58")   # the sky and the moon's glow, under the fog veils, at 0.9
# Fix round 1: what draws at the v12 defaults (the affordances), the only boxes the identity-to-M8
# render gates may exclude (artboard px at parallax 0; review_diorama / review_npc / review_time and
# rive/review/m9/make_lane_e.py mask them through `rest_masked`).
V12_REST_AFFORDANCE: dict[str, tuple[tuple[int, int, int, int], ...]] = {
    "livingRoom": ((306, 752, 334, 860),),     # the cord and its bead at rest
    "campfire": ((0, 1236, 320, 1344),),       # the stick lying on the ground (and its shadow)
}


def rest_masked(scene: str, new: "np.ndarray", old: "np.ndarray") -> "np.ndarray":  # noqa: F821
    """`new` with the scene's v12 rest affordances (`V12_REST_AFFORDANCE`) copied from `old`, for the
    gates that compare a scene at the defaults with a revision drawn before them. Renders of any size
    (the boxes scale with the height over 1920)."""
    out = new.copy()
    k = new.shape[0] / H
    for x0, y0, x1, y1 in V12_REST_AFFORDANCE.get(scene, ()):
        a, b, c, e = int(x0 * k), int(y0 * k), int(math.ceil(x1 * k)), int(math.ceil(y1 * k))
        out[b:e, a:c] = old[b:e, a:c]
    return out


def poke_stick(sc: Scene) -> El:
    """`PokeStick` (contract v12 `poke`, `pokeX`, `pokeY`): a long stick lying on the ground left of the
    fire at rest (its charred, faintly glowing tip at `POKE_REST`), lifted into the fire as `poke` goes
    0 -> 1 (its tip then at `POKE_TIP` + (pokeX, pokeY) x `POKE_RANGE`), always from the lower left.
    Nodes: `PokeStick` (the aim offset, x poke) > `PokeLift` (position and angle, lerped by poke) >
    `PokeTurn` (the aim's small turn) > `PokeArt` (drawn along +x from the tip). History-free."""
    d9 = sc.d9
    ln = POKE_LENGTH
    with sc.minting(d9):
        f = Formulas(d9, sc.vpath)
        # aim: (pokeX x 120, pokeY x 80) x poke
        aim_x = _v12_formula(sc, [f.val(POKE_RANGE[0]), f.op("*"), *f.inp(), f.op("*"), f.bound("poke")])
        aim_y = _v12_formula(sc, [f.val(POKE_RANGE[1]), f.op("*"), *f.inp(), f.op("*"), f.bound("poke")])
        turn = _v12_formula(sc, [f.val(POKE_TURN[0]), f.op("*"), *f.inp(), f.op("*"), f.bound("poke"), f.op("+"),
                                 f.val(POKE_TURN[1]), f.op("*"), f.bound("pokeY"), f.op("*"), f.bound("poke")])
        wood = sc.vgrad(-11, 11, [("FF9A6A40", 0.0), ("FF6E4628", 0.55), ("FF3E2818", 1.0)])
        body = [(-1.5, 0.0), (1.0, -4.0, "c"), (ln, -11.0, "c"), (ln, 11.0, "c"), (1.0, 4.0, "c")]
        glow = sc.E(ORIGIN, "emitPokeGlow", 4.0, 0.0, 52.0, 52.0, sc.rgrad(26, [("88FFA040", 0.0), ("00FF7A20", 1.0)]),
                    opacity=POKE_GLOW_REST)
        glow.children.insert(0, _v12_bind(sc, "poke", KEY_OPACITY, _v12_lin(sc, 1 - POKE_GLOW_REST, POKE_GLOW_REST)))
        col, drop, fade = POKE_SHADOW
        shadow = sc.S(ORIGIN, "PokeShadow", [(x, y + drop) + tuple(r) for x, y, *r in body], sc.F(col), origin=ORIGIN)
        shadow.children.insert(0, _v12_bind(sc, "poke", KEY_OPACITY, _v12_lin(sc, -fade, 1.0, lo=0.0)))
        art = sc.node(
            "PokeArt", 0.0, 0.0,
            sc.E(ORIGIN, "emitPokeEmber", 5.0, 0.0, 15.0, 10.0,
                 sc.rgrad(8, [("FFFFE7A0", 0.0), ("FFFF8A30", 1.0)])),
            glow,
            sc.S(ORIGIN, "PokeChar", [(-1.5, 0.0), (1.0, -4.0, "c"), (48.0, -4.6, "c"), (48.0, 4.6, "c"), (1.0, 4.0, "c")],
                 sc.F("FF221512"), origin=ORIGIN),
            *[sc.E(ORIGIN, f"PokeKnot{i}", x, 0.0, 9.0, 5.0, sc.F("FF3A2416")) for i, x in enumerate((150.0, 330.0))],
            sc.S(ORIGIN, "PokeTwig", [(230.0, 6.0, "c"), (264.0, 27.0), (274.0, 25.0, "c"), (244.0, 4.0, "c")],
                 sc.F("FF6E4628"), sc.L("FF1A0F0A", 1.4), origin=ORIGIN),
            sc.S(ORIGIN, "PokeWood", body, wood, sc.L("FF1A0F0A", 1.6), origin=ORIGIN))
        turn_node = sc.node("PokeTurn", 0.0, 0.0, _v12_bind(sc, "pokeX", KEY_ROTATION, turn), art)
        (rx, ry), (tx, ty) = POKE_REST, POKE_TIP
        lift = sc.node("PokeLift", rx, ry,
                       _v12_bind(sc, "poke", KEY_X, _v12_lin(sc, tx - rx, rx)),
                       _v12_bind(sc, "poke", KEY_Y, _v12_lin(sc, ty - ry, ry)),
                       _v12_bind(sc, "poke", KEY_ROTATION, _v12_lin(sc, POKE_ANGLE - POKE_REST_ANGLE, POKE_REST_ANGLE)),
                       turn_node, rotation=POKE_REST_ANGLE)
        # the shadow lies on the ground under the resting stick (it stays there, fading, as the stick rises)
        ground = sc.node("PokeGround", rx, ry, shadow, rotation=POKE_REST_ANGLE)
        return sc.node("PokeStick", 0.0, 0.0,
                       _v12_bind(sc, "pokeX", KEY_X, aim_x), _v12_bind(sc, "pokeY", KEY_Y, aim_y),
                       lift, ground)


def campfire_v12(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The poke stick (the front of Plane4, in front of the stones, behind the bushes) and the moon's phase."""
    content.insert(_top(content, "BushR") + 1, poke_stick(sc))
    phase_moon(sc, content, *CAMPFIRE_MOON)


# ---------------------------------------------------------------- beach: the trail, the gulls
# Fix round 2 (orchestrator ruling, from the in-app capture): in the app the avatar's bust covers the
# sand's centre (x ~250-830 from y ~1150) and the composer its bottom (y > ~1720), so the trail moves to
# the clear sand right of the avatar, by the crab and the water's edge, inside the phone crop
# (x ~100-980), and its dots double in size: a dark damp centre with a deeper shade up-left (the sun is
# up right) on a light raised rim, readable at phone size. Consecutive dots >= 22 px apart overlap into
# a furrow.
TRAIL_PATCH = (830.0, 1230.0, 980.0, 1700.0)  # the drag handle: where the finger draws (artboard px)
TRAIL_DOT = ("D0A27A48", "B87A5530", 18.0)    # the damp centre, its shaded side, the dimple's radius
TRAIL_RIM = ("B8FFF2D4", 9.0)                 # the light rim pushed up around each dimple: a stroke on its edge
                                              # (dark inside r 13.5, light out to r 22.5; a stroke costs half a shape)


def beach_v12(sc: Scene, content: list[El], hits: list[El]) -> None:
    """The trail in the sand (`TrailDots`, the back of Plane4: on the sand, behind every prop on it)
    and the gulls (`npc2`, scene_npc.beach_gulls, in front of the crab)."""
    dots = world_kit.trail_dots(sc, sc.d9, *TRAIL_DOT)
    col, w = TRAIL_RIM
    for mark in (e for e in walk([dots]) if e.attrs.get("name") == "Mark"):
        mark.children.append(stroke(sc.d9, col, w))   # each TrailDot<i>'s dimple gets its light rim
    content.insert(_top(content, "UShadow") + 1, dots)
    scene_npc.beach_gulls(sc, content)


# ---------------------------------------------------------------- beach: the night (M10, contract v13)
# `night` (0-1, the app writes (1 - daylight) x (1 - dusk)) hides the beach's sunset: an opaque night sky
# over the whole sky plane (in front of its haze, clouds and sun), the sun's glow off, a few stars in
# front of it, and a moonlight shade over the whole frame (a screen-space multiply in front of every plane
# and the rain: the sky, stars, sea, reflections, sand, the palm and the props darken and cool together).
# Everything is a formula / opacity bind on `night`, so night 0 is M9 exactly.
NIGHT_SKY = ("FF243052", "FF34446A", "FF56648C")   # zenith, mid sky, horizon haze (before the shade)
NIGHT_SHADE = "FF6B7AA8"                            # the multiply at night 1 (x 0.42, 0.48, 0.66)
NIGHT_SUN_GAIN = 2.0                                 # the sun's disc and glow: opacity max(0, 1 - 2 night)
NIGHT_STARS = [(96, 152, 3.2), (214, 306, 2.4), (318, 96, 2.8), (402, 238, 2.0), (520, 168, 3.4), (612, 330, 2.2),
               (688, 118, 2.6), (842, 214, 3.0), (948, 92, 2.2), (1010, 300, 2.8), (150, 470, 2.0), (446, 420, 2.4),
               (900, 452, 2.0), (760, 520, 1.8), (60, 640, 1.8), (1030, 600, 2.0)]


def beach_night(sc: Scene, content: list[El]) -> None:
    d10 = sc.d10
    plane0 = next(e for e in content if e.tag == "Node" and e.attrs.get("name") == "Plane0")
    sky = next(e for e in plane0.children if e.attrs.get("name") == "Sky")
    rect = next(c for c in sky.children if c.tag == "Rectangle")
    w, h = float(rect.attrs["width"]) + 2 * FRONT_BLEED, float(rect.attrs["height"]) + FRONT_BLEED
    sx, sy = float(sky.attrs["x"]), float(sky.attrs["y"])
    horizon = TIME_SKY["beach"][0]
    zen, mid, haze = NIGHT_SKY
    top = sy - h / 2
    stops = [(zen, 0.0), (mid, (horizon - 380 - top) / h), (haze, (horizon - top) / h), (haze, 1.0)]
    night_sky = d10("Shape", d10("DataBindContext", sourcePathIds=sc.vpath("night"), propertyKey=18),
                    d10("Rectangle", width=w, height=h, name="Path"),
                    d10("Fill", d10("LinearGradient", *[d10("GradientStop", colorValue=c, position=round(p, 4))
                                                        for c, p in stops],
                                    startX=0.0, startY=-h / 2, endX=0.0, endY=h / 2), name="Fill"),
                    x=sx, y=sy, opacity=0.0, name="SkyNight")
    stars = d10("Node", d10("DataBindContext", sourcePathIds=sc.vpath("night"), propertyKey=18),
                *[d10("Shape", ellipse(d10, 2 * r, 2 * r), d10("Fill", d10("SolidColor", colorValue="FFF4F0DC"),
                                                                 name="Fill"),
                      x=float(x), y=float(y), opacity=round(0.55 + 0.45 * (r - 1.8) / 1.6, 3), name="emitNightStar")
                  for x, y, r in NIGHT_STARS],
                x=0.0, y=0.0, opacity=0.0, name="emitNightStars")
    at = next(i for i, c in enumerate(plane0.children) if c.tag != "DataBindContext"
              and not str(c.attrs.get("name", "")).startswith(HIT_PREFIX))
    plane0.children[at:at] = [stars, night_sky]
    # the sun and its glow go out by half night (they would show through the half-night sky as a dim disc)
    out = _m10_formula(sc, lambda f: f.fn("max", [f.val(0)], [f.val(1), f.op("-"), f.val(NIGHT_SUN_GAIN), f.op("*"),
                                                              *f.inp()]))
    for name in ("emitSunGlow", "emitSunDisc"):
        part = next(e for e in walk(content) if e.attrs.get("name") in (name, name.removeprefix("emit")))
        part.children.insert(0, d10("DataBindContext", sourcePathIds=sc.vpath("night"), propertyKey=18,
                                    converterId=out.ref()))
    # the moonlight shade: a screen-space multiply over the whole frame, in front of the planes and rain
    tint = d10("Shape", d10("DataBindContext", sourcePathIds=sc.vpath("night"), propertyKey=18),
               d10("Rectangle", width=float(W + 2 * FRONT_BLEED), height=float(H + 2 * FRONT_BLEED), name="Path"),
               d10("Fill", d10("SolidColor", colorValue=NIGHT_SHADE), name="Fill"),
               x=W / 2, y=H / 2, opacity=0.0, blendModeValue=24, name="NightTint")
    content.insert(0, tint)


# ---------------------------------------------------------------- deepSpace: the planet spins
SPIN_OVERLAP = 1.0     # px the copy's stroke overlaps the band's at their join (M10: the seam closes)
SPIN_HIDE_GAIN = 1e4   # the copy shows for spin > 0, the band for spin < 1 (formula slope)


def deep_space_v12(sc: Scene, content: list[El], hits: list[El]) -> None:
    """`spin` 0..1 slides each of the planet's cloud bands (`PlanetWeather*`, clipped to the disc) right
    by its own period x spin, and a copy of it, one period to the left, slides in behind it: spin 1
    draws exactly what spin 0 does. M10 (the seam): a band's period is its own stroke length (its x
    extent plus both caps) less SPIN_OVERLAP, so the copy's end overlaps the band's start by 1 px and
    the join never opens a gap. At spin 0 the copy would then show in the band's limb gap, so it is
    hidden there (opacity min(1, spin x 1e4)), and the band is hidden at spin 1 (where the copy has
    taken its place): spin 0 and spin 1 draw the M9 rest exactly. Short bands near the poles move
    slower than the equator's (a turning sphere)."""
    d9, d10 = sc.d9, sc.d10
    group = next(e for e in walk(content) if e.tag == "Node"
                 and any(_root(c.attrs.get("name")) == "PlanetWeather" for c in e.children))
    show_copy = _m10_formula(sc, lambda f: f.fn("min", [f.val(1)], [f.val(SPIN_HIDE_GAIN), f.op("*"), *f.inp()]))
    show_band = _m10_formula(sc, lambda f: f.fn("min", [f.val(1)], [f.val(SPIN_HIDE_GAIN), f.op("-"),
                                                                    f.val(SPIN_HIDE_GAIN), f.op("*"), *f.inp()]))
    out: list[El] = []
    for c in group.children:
        out.append(c)
        if c.tag != "Shape" or _root(c.attrs.get("name")) != "PlanetWeather":
            continue
        x0 = float(c.attrs["x"])
        path = next(k for k in c.children if k.tag == "PointsPath")
        xs = [float(v.attrs["x"]) for v in path.children]
        cap = float(next(k for k in c.children if k.tag == "Stroke").attrs["thickness"]) / 2
        period = round(max(xs) - min(xs) + 2 * cap - SPIN_OVERLAP, 2)
        copy = clone(d9, c, x=x0 - period, name="PlanetWeatherWrap" + str(c.attrs["name"])[len("PlanetWeather"):])
        c.children.insert(0, _v12_bind(sc, "spin", KEY_X, _v12_lin(sc, period, x0)))
        copy.children.insert(0, _v12_bind(sc, "spin", KEY_X, _v12_lin(sc, period, x0 - period)))
        c.children.insert(1, d10("DataBindContext", sourcePathIds=sc.vpath("spin"), propertyKey=KEY_OPACITY,
                                 converterId=show_band.ref()))
        copy.children.insert(1, d10("DataBindContext", sourcePathIds=sc.vpath("spin"), propertyKey=KEY_OPACITY,
                                    converterId=show_copy.ref()))
        copy.attrs["opacity"] = 0.0
        out.append(copy)
    group.children[:] = out


# ====================================================================== the scene registry (M9)
# ---------------------------------------------------------------- seasons (M11 ruling 9, contract v14)
# `spring` / `autumn` (0-1, the app writes them from the local date, ramping over a week) dress two old
# scenes: a node per season at opacity = the number (a direct bind, history-free; static 0, so at 0 / 0 the
# renderer skips it and the scene is v13 exactly). Everything mints from `d11`.
SILL_TOP = 708.0                    # livingRoom: the ledge under the window (Sill, Plane2), its top edge
TULIPS_AT = 642.0                   # the vase's centre x: the right pane's foot, clear of the curtain and
                                    # above the avatar's head (the head covers the wall below ~y 760)
TULIPS = ((-16, 76, -0.22, "FFE0485A"), (-5, 92, -0.07, "FFF27A8C"), (6, 86, 0.1, "FFF2C24A"),
          (16, 72, 0.26, "FFE0485A"), (0, 66, 0.0, "FFF4A0B4"))   # (dx at the vase mouth, height, lean, petals)
PUMPKIN = (628.0, 50.0, 34.0)       # centre x, width, height (on the sill)
SILL_LEAVES = ((578, -5, 11.0, 1.9, "FFC8602C"), (598, -3, 9.0, 0.5, "FFD89A3A"), (672, -4, 10.0, -1.2, "FFB84A2A"))                    # (x, dy above the sill top, r, turn, colour)
# campfire: the clearing's ground is Plane4 (in front of Ground and the path, behind the wet film, the
# light pool and the grass, so rain darkens and the fire lights them like the ground)
CLEARING_FLOWERS = ((64, 1296), (150, 1330), (36, 1420), (160, 1450), (90, 1530), (40, 1640), (190, 1600),
                    (900, 1262), (990, 1300), (1036, 1404), (940, 1440), (860, 1520), (1010, 1560), (920, 1660),
                    (330, 1290), (720, 1300))
FLOWER_COLOURS = ("FFF4F0E4", "FFF4D25A", "FFE89AB8", "FFB8A6E8")
AUTUMN_GROUND = ("FFC8602C", "FFD89A3A", "FFB84A2A", "FF8A4A2A", "FFE0B050")
RUST_FERN = "FF7A3A22"              # the grass tufts in autumn (an overlay in the tuft's own shape)


def _maple(cx: float, cy: float, r: float, ang: float, squash: float = 1.0) -> list[tuple]:
    """A five-lobed leaf of radius `r` at (cx, cy), turned by `ang`: rounded lobes, sharp notches, a short
    stalk; `squash` flattens it vertically (a leaf lying on the ground, seen at an angle)."""
    pts: list[tuple] = []
    for i in range(10):
        a = ang - math.pi / 2 + math.pi * i / 5
        rr = r * (1.0 if i == 0 else 0.86) if i % 2 == 0 else r * 0.42
        p = (round(cx + rr * math.cos(a), 2), round(cy + squash * rr * math.sin(a), 2))
        pts.append(p if i % 2 == 0 else (*p, "c"))
        if i == 5:   # the stalk, between the two lower lobes
            sa = ang + math.pi / 2
            pts[-1:] = [(round(cx + r * 0.36 * math.cos(sa - 0.25), 2), round(cy + squash * r * 0.36 * math.sin(sa - 0.25), 2), "c"),
                        (round(cx + r * 0.62 * math.cos(sa), 2), round(cy + squash * r * 0.62 * math.sin(sa), 2), "c"),
                        (round(cx + r * 0.36 * math.cos(sa + 0.25), 2), round(cy + squash * r * 0.36 * math.sin(sa + 0.25), 2), "c")]
    return pts


def _season_node(sc: Scene, season: str, name: str, kids: list[El]) -> El:
    return sc.d11("Node", sc.bind(season, 18, doc=sc.d11), *kids, x=0.0, y=0.0, opacity=0.0, name=name)


def _plane(content: list[El], k: int) -> El:
    return next(e for e in content if e.attrs.get("name") == f"Plane{k}")


def living_room_seasons(sc: Scene, content: list[El]) -> None:
    """A glass vase of tulips on the sill in spring (`SpringSill`), a small pumpkin and a few fallen
    leaves there in autumn (`AutumnSill`); Plane2, in front of the ledge, behind the walking cat and the
    curtains."""
    O = (0.0, 0.0)
    with sc.minting(sc.d11):
        S, E, F, L = sc.S, sc.E, sc.F, sc.L
        cx, top = TULIPS_AT, SILL_TOP
        vase = [E(O, "VaseGlint", cx - 7, top - 30, 4, 24, F("80FFFFFF")),
                S(O, "VaseWater", [(cx - 11, top - 20), (cx + 11, top - 20), (cx + 10, top - 2, "c"),
                                   (cx - 10, top - 2, "c")], F("8090B8C0")),
                S(O, "TulipVase", [(cx - 10, top - 46, "c"), (cx + 10, top - 46, "c"), (cx + 13, top - 24),
                                   (cx + 11, top - 1, "c"), (cx - 11, top - 1, "c"), (cx - 13, top - 24)],
                  F("70C8E0E8"), L("B0E8F4F8", 2))]
        stems, heads = [], []
        for i, (dx, h, lean, col) in enumerate(TULIPS):
            bx, by = cx + dx * 0.4, top - 40
            tx, ty = cx + dx + math.sin(lean) * h * 0.4, top - 40 - h
            stems.append(S(O, f"TulipStem{i}", [(bx, by), ((bx + tx) / 2 + lean * 8, (by + ty) / 2), (tx, ty)],
                           L("FF4E7A3A", 3), closed=False))
            heads.append(S(O, f"Tulip{i}", [(tx - 9, ty - 15, "c"), (tx - 3, ty - 8), (tx, ty - 16, "c"), (tx + 3, ty - 8),
                                            (tx + 9, ty - 15, "c"), (tx + 8, ty - 2), (tx, ty + 4), (tx - 8, ty - 2)],
                           F(col), L("40301A20", 1.5)))
        leaves = [S(O, "TulipLeafL", [(cx - 4, top - 40), (cx - 26, top - 84, "c"), (cx - 8, top - 58)], F("FF5E8A44")),
                  S(O, "TulipLeafR", [(cx + 4, top - 40), (cx + 24, top - 76, "c"), (cx + 8, top - 56)], F("FF6A9A4E"))]
        spring = _season_node(sc, "spring", "SpringSill", [*vase, *heads, *leaves, *stems,
                                                            E(O, "TulipShadow", cx, top + 1, 40, 6, F("40101C1E"))])
        px, pw, ph = PUMPKIN
        pumpkin = [S(O, "PumpkinStem", [(px - 2, top - ph + 2), (px - 1, top - ph - 10), (px + 6, top - ph - 13, "c"),
                                        (px + 3, top - ph - 8), (px + 3, top - ph + 2)], F("FF5A4A2A")),
                   *(S(O, f"PumpkinRib{i}", [(px + dx, top - ph + 3), (px + dx * 1.5, top - ph / 2), (px + dx, top - 2)],
                       L("60803010", 2), closed=False) for i, dx in enumerate((-10, 0, 10))),
                   E(O, "PumpkinGlint", px - 12, top - ph * 0.62, 7, 12, F("50FFE0A0")),
                   E(O, "Pumpkin", px, top - ph / 2, pw, ph, F("FFE07A2A"), L("FF8A3A14", 2)),
                   E(O, "PumpkinShadow", px + 4, top + 1, pw + 8, 7, F("40101C1E"))]
        fallen = [S(O, f"SillLeaf{i}", _maple(x, top + dy, r, a, squash=0.5), F(col)) for i, (x, dy, r, a, col) in enumerate(SILL_LEAVES)]
        autumn = _season_node(sc, "autumn", "AutumnSill", [*fallen, *pumpkin])
    kids = _plane(content, 2).children
    at = next(i for i, c in enumerate(kids) if c.attrs.get("name") == "Sill")
    kids[at:at] = [spring, autumn]


def campfire_seasons(sc: Scene, content: list[El]) -> None:
    """Spring flowers in the clearing (`SpringGround`: small five-petal clusters at its edges, clear of the
    fire and the avatar), autumn leaves on the ground (`AutumnGround`) and the grass tufts turned rust
    (`AutumnFerns`: a rust copy of each tuft in front of it); Plane4."""
    O = (0.0, 0.0)
    rnd = random.Random(1109)
    plane = _plane(content, 4)
    kids = plane.children
    with sc.minting(sc.d11):
        S, E, F = sc.S, sc.E, sc.F
        flowers = []
        for i, (x, y) in enumerate(CLEARING_FLOWERS):
            for j in range(3):
                fx, fy = x + rnd.uniform(-30, 30), y + rnd.uniform(-14, 14)
                r = rnd.uniform(8.0, 11.5) * (0.8 + 0.4 * (y - 1260) / 400)   # nearer = bigger
                col = FLOWER_COLOURS[(i + j) % len(FLOWER_COLOURS)]
                turn = rnd.uniform(0, math.pi)
                # five round petals (a smooth ten-point star), squashed: seen from above at an angle
                petals = [(round(fx + (r if k % 2 == 0 else r * 0.45) * math.cos(turn + k * math.pi / 5), 2),
                           round(fy + 0.7 * (r if k % 2 == 0 else r * 0.45) * math.sin(turn + k * math.pi / 5), 2))
                          for k in range(10)]
                flowers += [E(O, f"FlowerHeart{i}_{j}", fx, fy, r * 0.6, r * 0.42, F("FFE8A030")),
                            S(O, f"Flower{i}_{j}", petals, F(col))]
        spring = _season_node(sc, "spring", "SpringGround", flowers)
        fallen = []
        for i in range(36):
            side = i % 4
            x = (rnd.uniform(-10, 300), rnd.uniform(780, 1090), rnd.uniform(300, 780), rnd.uniform(-10, 1090))[side]
            y = (rnd.uniform(1250, 1700), rnd.uniform(1230, 1700), rnd.uniform(1700, 1900), rnd.uniform(1200, 1320))[side]
            r = rnd.uniform(12.0, 17.0) * (0.75 + 0.5 * (y - 1200) / 700)   # nearer = bigger
            fallen.append(S(O, f"GroundLeaf{i}", _maple(x, y, r, rnd.uniform(0, math.tau), squash=0.62),
                            F(AUTUMN_GROUND[i % len(AUTUMN_GROUND)])))
        ground = _season_node(sc, "autumn", "AutumnGround", fallen)
        ferns = []
        for g in (c for c in kids if str(c.attrs.get("name", "")).startswith("Grass")):
            path = next(c for c in g.children if c.tag == "PointsPath")
            verts = [sc.d11(v.tag, **v.attrs) for v in path.children]
            ferns.append(sc.d11("Shape", sc.d11("PointsPath", *verts, **path.attrs), F(RUST_FERN),
                                **{k: v for k, v in g.attrs.items() if k != "name"},
                                name="Rust" + str(g.attrs["name"])))
        rust = _season_node(sc, "autumn", "AutumnFerns", ferns)
    first_grass = next(i for i, c in enumerate(kids) if str(c.attrs.get("name", "")).startswith("Grass"))
    kids[first_grass:first_grass] = [rust]
    at = next(i for i, c in enumerate(kids) if c.attrs.get("name") == "GroundWet") + 1
    kids[at:at] = [ground, spring]


def _lazy(scene_id: str) -> Callable[[], str]:
    """Builds a module scene (v12, v14) through its own module (imported on first use: `world_kit.scene_module`
    raises `SceneNotWritten` while its lane has not written it)."""
    def build() -> str:
        return getattr(world_kit.scene_module(scene_id), scene_id)()
    build.__name__ = scene_id
    return build


SCENE_BUILDERS: dict[str, Callable[[], str]] = {
    "livingRoom": livingRoom, "campfire": campfire, "beach": beach, "deepSpace": deepSpace,
    **{sid: _lazy(sid) for sid in world_kit.SCENE_MODULES},
}


def main(argv: list[str]) -> int:
    """`gen_scenes.py [sceneId ...]`: writes the named scenes; with none, the four M8 scenes and every
    module scene (v12, v14) whose module exists. An unknown id, or a module scene asked for before its
    module exists, exits 1 with a message."""
    unknown = [a for a in argv if a not in SCENE_BUILDERS]
    if unknown:
        print(f"unknown scene {', '.join(unknown)} (known: {', '.join(SCENE_BUILDERS)})", file=sys.stderr)
        return 1
    which = argv or [*world_kit.BUILT_IN_SCENES, *world_kit.written_scene_modules()]
    for name in which:
        try:
            print("wrote", SCENE_BUILDERS[name]())
        except world_kit.SceneNotWritten as e:
            print(f"✗ {e}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
