"""Contract v7 on the avatar (moonshot M4 Task 4): the scene light rig, `prop` and `lean`.

Called last by gen_avatar.py, on the finished tree; every element is minted from the M4 id
range (`avatar_kit.M4_ID_START`), so no earlier id moves. Every bind is history-free: a light
number maps straight onto a paint or a transform.

- Rim (`lightRim`, `lightRimIntensity`, opposite `lightKeyX/Y`): a copy of the face outline
  (skinned to the same turn bones) and the back-hair silhouette (no torso rim, M4 ruling 22), each stroked
  `RIM_W` wide and clipped by its silhouette, so only the inner band shows (the light eats the
  inner half of the ink line). The stroke's linear gradient is clear on the key side and reaches
  the rim colour at the far side; its opacity is the rim intensity.
- Key on skin (`KeyCheek`): a radial `lightKey` pool, screen-blended, clipped by the face, centred
  at the cheek nearest the key, opacity 0.65 x `lightKeyIntensity` (0.45 read too faint at the
  campfire, Task 4 review), inside the `Firelight` node.
- Ambient (`AmbientWash`): a face-clipped multiply wash in `lightAmbient` on the side away from
  the key, opacity 0.5 x `lightAmbientAmount` (gradient opacity).
- Glasses glint: the lens glints take `lightKey` and slide `GLINT_SLIDE` px toward the key, each
  inside a `FirelightGlare` node.
- Key tint (M5 ruling 7, `KeyCheekTint`, minted from the M5 range): the same pool in `lightKey`,
  multiply-blended under `KeyCheek`, opacity `KEY_TINT x lightKeyIntensity x lightFlicker` (one
  converter): the screen pool alone barely shows on bright skin, the multiply shifts its colour,
  and only a flickering key (the campfire) tints the skin.
- Flicker: a `Firelight` state-machine layer, a 1D view-model blend on `lightFlicker` between
  `light_steady` (opacity 1) and `light_flicker` (noise 0.45-1.0, M4 0.62-1.0, from three prime
  harmonics of a 2.0 s loop, so the seam is exact).
- `lean`: the body tips toward the viewer about the shoulder line (perspective growth
  `LEAN_SCALE`, a small sink) and the head drops (`LEAN_HEAD_DROP` net at 1).
"""

from __future__ import annotations

import math
from typing import Callable, Iterator, Sequence

from art_bible import LINES, SCENES
from rig_dsl import Formulas
from rml import Doc, El

KEYS = {"x": 13, "y": 14, "scaleX": 16, "scaleY": 17, "opacity": 18, "colorValue": 37,
        "stopColor": 38, "startX": 42, "startY": 33, "endX": 34, "endY": 35, "gradOpacity": 46}
SCREEN, MULTIPLY = 14, 24  # Rive BlendMode values (rive_native 0.1.11 accepts both)

_LR = SCENES["livingRoom"]
# Contract v7 AvatarVM light numbers and colours, in contract order; defaults = livingRoom's rig.
LIGHT_DEFAULTS: dict[str, tuple[str, object]] = {
    "lightKey": ("color", _LR.key),
    "lightKeyIntensity": ("number", _LR.key_intensity),
    "lightKeyX": ("number", _LR.key_xy[0]),
    "lightKeyY": ("number", _LR.key_xy[1]),
    "lightRim": ("color", _LR.rim),
    "lightRimIntensity": ("number", _LR.rim_intensity),
    "lightAmbient": ("color", _LR.ambient),
    "lightAmbientAmount": ("number", _LR.ambient_amount),
    "lightFlicker": ("number", _LR.flicker),
}
PROP_VALUES = ("none", "tablet")

# art px per art-bible px (the face's silhouette ink is 2.6 art px = 5 bible px; face_rig.PX)
PX = 2.6 / LINES.silhouette
RIM_W = round(LINES.interior * PX, 2)  # the rim band: interior weight, 3 bible px
RIM_REACH = 150.0  # art px from a rim shape's origin to the gradient's lit end (shared converters)
RIM_STOPS = (0.0, 0.5, 1.0)  # clear .. clear (key side and middle) .. rim (far side)
KEY_CHEEK = (0.65, 0.35)  # opacity per unit key intensity, centre travel per unit key x/y (face widths)
KEY_TINT = 1.0  # KeyCheekTint opacity per unit of lightKeyIntensity x lightFlicker (M5 ruling 7)
FACE_W = 212.0  # art px (face outline x 294..506)
CHEEK = (400.0, 437.0)  # art space: the cheek line between the two cheek blooms
# the pool: a w x w circle squashed to h by the shape's scaleY, so the circular radial gradient fades to
# clear at the whole rim (M5: a w x h ellipse cut the gradient at 0.2 alpha top and bottom, a hard edge)
CHEEK_SIZE = (150.0, 120.0)
AMBIENT_GAIN = 0.5
AMBIENT_STOPS = (0.0, 0.45, 1.0)
GLINT_SLIDE = 6.0  # art px toward the key at |lightKey| = 1

FLICKER_FRAMES = 120  # 2.0 s at 60 fps
FLICKER_RANGE = (0.45, 1.0)  # M5 ruling 7 (M4: 0.62-1.0 read too steady on the cheek)
FLICKER_HARMONICS = ((3, 0.5, 0.4), (5, 0.3, 2.1), (7, 0.2, 4.4))  # (cycles per loop, weight, phase)
FLICKER_STEP = 3  # frames between keys

LEAN_PIVOT = (400.0, 610.0)  # art space: the shoulder line the body tips about
LEAN_SCALE = 0.02  # perspective growth at lean 1 (a ~3 deg tip toward a camera ~1400 px away)
LEAN_SINK = 3.0  # art px the tipped body sinks at lean 1
LEAN_HEAD = 9.5  # art px the head drops (in the tipped frame) at lean 1
HEAD_CENTRE_Y = 366.5  # art space: the face's centre
CAMERA_D, TIP_H = 1400.0, 500.0  # for the tip angle the scale stands for


def flicker(frame: float) -> float:
    """The firelight's opacity at `frame` of the loop: three prime harmonics of the 2 s loop,
    normalised into FLICKER_RANGE (the loop's ends meet exactly)."""
    t = frame / FLICKER_FRAMES
    n = sum(w * math.sin(2 * math.pi * k * t + ph) for k, w, ph in FLICKER_HARMONICS)
    lo, hi = FLICKER_RANGE
    span = max(abs(_flicker_extreme(min)), abs(_flicker_extreme(max)))
    return round(lo + (hi - lo) * (n / span + 1) / 2, 4)


def _flicker_extreme(pick: Callable[[Sequence[float]], float]) -> float:
    samples = [sum(w * math.sin(2 * math.pi * k * f / 1200 + ph) for k, w, ph in FLICKER_HARMONICS)
               for f in range(1200)]
    return pick(samples)


def lean_head_drop(lean: float) -> float:
    """Net art-space drop (+ = down) of the face centre at `lean` (the body's tip about the
    shoulder line, its sink and the head's own drop)."""
    s = 1 + LEAN_SCALE * lean
    y_tipped = LEAN_PIVOT[1] + (HEAD_CENTRE_Y - LEAN_PIVOT[1]) * s + LEAN_SINK * lean
    return y_tipped + LEAN_HEAD * lean * s - HEAD_CENTRE_Y


def lean_tip_degrees(lean: float) -> float:
    """The forward tip the perspective growth stands for (TIP_H above the pivot, CAMERA_D away)."""
    return math.degrees(math.asin(min(1.0, LEAN_SCALE * lean * CAMERA_D / TIP_H)))


def walk(e: El) -> Iterator[El]:
    yield e
    for c in e.children:
        yield from walk(c)


def parent_of(root: El, target: El) -> El:
    for e in walk(root):
        if any(c is target for c in e.children):
            return e
    raise KeyError(target.attrs.get("name"))


def top_child(root: El, target: El) -> El:
    """The child of `root` whose subtree holds `target`."""
    return next(c for c in root.children if any(e is target for e in walk(c)))


class AvatarLight:
    def __init__(self, d: Doc, vm: El, inst: El, enums: dict[str, El]) -> None:
        self.d = d
        self.vm = vm
        self.converters: list[El] = []
        self._gain: dict[float, El] = {}
        self.f = Formulas(d, self.path)
        self.props: dict[str, El] = {}
        vals: list[El] = []
        for name, (typ, default) in LIGHT_DEFAULTS.items():
            if typ == "color":
                p = d("ViewModelPropertyColor", name=name)
                vals.append(d("ViewModelInstanceColor", propertyValue=default, viewModelPropertyId=p.ref()))
            else:
                p = d("ViewModelPropertyNumber", name=name)
                vals.append(d("ViewModelInstanceNumber", propertyValue=float(default), viewModelPropertyId=p.ref()))
            self.props[name] = p
        pv = {v: d("DataEnumValue", key=v, value=v) for v in PROP_VALUES}
        enums["Prop"] = d("DataEnumCustom", *pv.values(), name="Prop")
        self.prop_values = pv
        self.props["prop"] = d("ViewModelPropertyEnumCustom", enumId=enums["Prop"].ref(), name="prop")
        vals.append(d("ViewModelInstanceEnum", propertyValue=pv["none"].ref(),
                      viewModelPropertyId=self.props["prop"].ref()))
        self.props["lean"] = d("ViewModelPropertyNumber", name="lean")
        vals.append(d("ViewModelInstanceNumber", propertyValue=0.0, viewModelPropertyId=self.props["lean"].ref()))
        at = vm.children.index(inst)
        vm.children[at:at] = list(self.props.values())
        inst.children.extend(vals)

    # ---- binds
    def path(self, pn: str) -> str:
        return f"{self.vm.ref()}-{self.props[pn].ref()}"

    def gain(self, k: float) -> El:
        """The shared `k x input` converter (one per gain)."""
        k = round(k, 3)
        if k not in self._gain:
            f = self.f
            conv = self.d("DataConverterFormula", f.val(k), f.op("*"), *f.inp())
            self.converters.append(conv)
            self._gain[k] = conv
        return self._gain[k]

    def bind(self, pn: str, key: str, k: float | None = None) -> El:
        conv = None if k is None or k == 1 else self.gain(k).ref()
        return self.d("DataBindContext", sourcePathIds=self.path(pn), propertyKey=KEYS[key], converterId=conv)

    def stop(self, pn: str, default: str, pos: float, clear: bool = False) -> El:
        if clear:
            return self.d("GradientStop", colorValue="00" + default[2:], position=float(pos))
        return self.d("GradientStop", self.bind(pn, "stopColor"), colorValue=default, position=float(pos))

    def far_gradient(self, colour: str, intensity: str, gain: float, stops: Sequence[float]) -> El:
        """A linear gradient across RIM_REACH x 2 through the shape's origin: clear toward the key,
        `colour` at the far side; its opacity is `gain x intensity`."""
        default = str(LIGHT_DEFAULTS[colour][1])
        r = RIM_REACH
        return self.d("LinearGradient",
                      self.bind("lightKeyX", "startX", r), self.bind("lightKeyY", "startY", -r),
                      self.bind("lightKeyX", "endX", -r), self.bind("lightKeyY", "endY", r),
                      self.bind(intensity, "gradOpacity", gain),
                      *[self.stop(colour, default, p, clear=i < len(stops) - 1) for i, p in enumerate(stops)],
                      startX=r * _LR.key_xy[0], startY=-r * _LR.key_xy[1], endX=-r * _LR.key_xy[0],
                      endY=r * _LR.key_xy[1])

    # ---- art
    def rim(self, name: str, path: El, clip: El, ink_w: float, x: float, y: float) -> El:
        """A rim band along `path` (already in the new shape's local space), clipped by `clip`."""
        d = self.d
        stroke = d("Stroke", self.far_gradient("lightRim", "lightRimIntensity", 1.0, RIM_STOPS),
                   thickness=round(ink_w + 2 * RIM_W, 2), cap="round", join="round", name="Rim")
        return d("Shape", d("ClippingShape", sourceId=clip.ref(), name="Clip"), path, stroke,
                 x=x, y=y, name=name)

    def clone(self, e: El) -> El:
        """A deep copy of `e` with fresh ids (references to elements outside stay as they are)."""
        c = self.d(e.tag, *[self.clone(k) for k in e.children], **dict(e.attrs))
        return c

    def key_cheek(self, face: El, head_frame: tuple[float, float]) -> El:
        d = self.d
        k_op, k_xy = KEY_CHEEK
        reach = k_xy * FACE_W
        key = str(LIGHT_DEFAULTS["lightKey"][1])
        kx, ky = _LR.key_xy
        w, h = CHEEK_SIZE
        grad = d("RadialGradient", self.stop("lightKey", key, 0.0), self.stop("lightKey", key, 1.0, clear=True),
                 startX=0.0, startY=0.0, endX=w / 2, endY=0.0)
        shape = d("Shape", self.bind("lightKeyX", "x", reach), self.bind("lightKeyY", "y", -reach),
                  self.bind("lightKeyIntensity", "opacity", k_op),
                  d("ClippingShape", sourceId=face.ref(), name="Clip"),
                  d("Ellipse", width=w, height=w, name="Path"), d("Fill", grad, name="Fill"),
                  x=round(reach * kx, 3), y=round(-reach * ky, 3), opacity=round(k_op * _LR.key_intensity, 4),
                  scaleY=round(h / w, 4), blendModeValue=SCREEN, name="KeyCheek")
        self.firelight = d("Node", shape, x=CHEEK[0] - head_frame[0], y=CHEEK[1] - head_frame[1], name="Firelight")
        return self.firelight

    def key_cheek_tint(self, m5: Doc, face: El) -> El:
        """KeyCheekTint (M5 ruling 7): the key pool again, multiply-blended and drawn under KeyCheek in
        the Firelight node (so the flicker loop drives it too), opacity KEY_TINT x lightKeyIntensity x
        lightFlicker. New elements mint from `m5`; the pool's position binds reuse KeyCheek's gains."""
        _, k_xy = KEY_CHEEK
        reach = k_xy * FACE_W
        key = str(LIGHT_DEFAULTS["lightKey"][1])
        kx, ky = _LR.key_xy
        w, h = CHEEK_SIZE
        f = Formulas(m5, self.path)
        conv = m5("DataConverterFormula", f.val(KEY_TINT), f.op("*"), *f.inp(), f.op("*"), f.bound("lightFlicker"))
        self.converters.append(conv)
        grad = m5("RadialGradient",
                  m5("GradientStop", m5("DataBindContext", sourcePathIds=self.path("lightKey"),
                                         propertyKey=KEYS["stopColor"]), colorValue=key, position=0.0),
                  m5("GradientStop", colorValue="00" + key[2:], position=1.0),
                  startX=0.0, startY=0.0, endX=w / 2, endY=0.0)
        shape = m5("Shape",
                   m5("DataBindContext", sourcePathIds=self.path("lightKeyX"), propertyKey=KEYS["x"],
                      converterId=self.gain(reach).ref()),
                   m5("DataBindContext", sourcePathIds=self.path("lightKeyY"), propertyKey=KEYS["y"],
                      converterId=self.gain(-reach).ref()),
                   m5("DataBindContext", sourcePathIds=self.path("lightKeyIntensity"), propertyKey=KEYS["opacity"],
                      converterId=conv.ref()),
                   m5("ClippingShape", sourceId=face.ref(), name="Clip"),
                   m5("Ellipse", width=w, height=w, name="Path"), m5("Fill", grad, name="Fill"),
                   x=round(reach * kx, 3), y=round(-reach * ky, 3), scaleY=round(h / w, 4),
                   opacity=round(KEY_TINT * _LR.key_intensity * _LR.flicker, 4), blendModeValue=MULTIPLY,
                   name="KeyCheekTint")
        self.firelight.children.append(shape)  # first child paints in front: the tint sits under KeyCheek
        return shape

    def ambient_wash(self, face: El) -> El:
        d = self.d
        grad = self.far_gradient("lightAmbient", "lightAmbientAmount", AMBIENT_GAIN, AMBIENT_STOPS)
        return d("Shape", d("ClippingShape", sourceId=face.ref(), name="Clip"),
                 d("Rectangle", width=260.0, height=340.0, name="Path"), d("Fill", grad, name="Fill"),
                 x=float(face.attrs.get("x", 0.0)), y=float(face.attrs.get("y", 0.0)), blendModeValue=MULTIPLY,
                 name="AmbientWash")

    def glint(self, glare: El, parent: El) -> El:
        """Re-colour a lens glint to `lightKey` (its old alpha becomes the shape's opacity) and wrap
        it in a FirelightGlare node that slides toward the key."""
        d = self.d
        solid = next(e for e in walk(glare) if e.tag == "SolidColor")
        old = str(solid.attrs["colorValue"])
        glare.attrs["opacity"] = round(int(old[:2], 16) / 255, 3)
        solid.attrs["colorValue"] = str(LIGHT_DEFAULTS["lightKey"][1])
        solid.children.insert(0, self.bind("lightKey", "colorValue"))
        kx, ky = _LR.key_xy
        wrap = d("Node", self.bind("lightKeyX", "x", GLINT_SLIDE), self.bind("lightKeyY", "y", -GLINT_SLIDE), glare,
                 x=round(GLINT_SLIDE * kx, 3), y=round(-GLINT_SLIDE * ky, 3),
                 name="Firelight" + str(glare.attrs.get("name")))
        parent.children[parent.children.index(glare)] = wrap
        return wrap

    def lean(self, body: El, body_g: El, head_roll_pivot: El, head_base: El, body_frame: tuple[float, float]) -> None:
        d = self.d
        lx, ly = LEAN_PIVOT[0] - body_frame[0], LEAN_PIVOT[1] - body_frame[1]
        inner = d("Node", body_g, x=-lx, y=-ly, name="LeanPivot")
        lean_c = self.lean_converters(ly)
        outer = d("Node",
                  d("DataBindContext", sourcePathIds=self.path("lean"), propertyKey=KEYS["scaleX"],
                    converterId=lean_c["scale"].ref()),
                  d("DataBindContext", sourcePathIds=self.path("lean"), propertyKey=KEYS["scaleY"],
                    converterId=lean_c["scale"].ref()),
                  d("DataBindContext", sourcePathIds=self.path("lean"), propertyKey=KEYS["y"],
                    converterId=lean_c["sink"].ref()),
                  inner, x=lx, y=ly, name="Lean")
        body.children[body.children.index(body_g)] = outer
        head = d("Node", self.bind("lean", "y", LEAN_HEAD), head_base, x=0.0, y=0.0, name="HeadLean")
        head_roll_pivot.children[head_roll_pivot.children.index(head_base)] = head

    def lean_converters(self, ly: float) -> dict[str, El]:
        f = self.f
        out = {}
        for key, (c0, c) in {"scale": (1.0, LEAN_SCALE), "sink": (ly, LEAN_SINK)}.items():
            conv = self.d("DataConverterFormula", f.val(c0), f.op("+"), f.val(c), f.op("*"), *f.inp())
            self.converters.append(conv)
            out[key] = conv
        return out

    # ---- flicker
    def flicker_layer(self, targets: Sequence[El]) -> tuple[list[El], El]:
        """(animations, state-machine layer): light_steady / light_flicker on every Firelight node,
        blended in 1D by lightFlicker."""
        d = self.d

        def keys(fn: Callable[[int], float], frames: Sequence[int]) -> list[El]:
            out = []
            for t in targets:
                kfs = [d("KeyFrameDouble", frame=f, value=float(fn(f)), interpolationType="linear") for f in frames]
                out.append(d("KeyedObject", d("KeyedProperty", *kfs, property="opacity"), objectId=t.ref()))
            return out

        steady = d("LinearAnimation", *keys(lambda f: 1.0, [0]), duration=1, fps=60, loopValue="loop",
                   name="light_steady")
        frames = list(range(0, FLICKER_FRAMES, FLICKER_STEP)) + [FLICKER_FRAMES]
        flick = d("LinearAnimation", *keys(flicker, frames), duration=FLICKER_FRAMES, fps=60, loopValue="loop",
                  name="light_flicker")
        blend = d("BlendState1DViewModel",
                  d("BindablePropertyNumber", d("DataBindContext", sourcePathIds=self.path("lightFlicker"),
                                                propertyKey=636)),
                  d("BlendAnimation1D", animationId=steady.ref(), value=0.0),
                  d("BlendAnimation1D", animationId=flick.ref(), value=1.0), x=160.0, y=100.0)
        layer = d("StateMachineLayer",
                  d("AnyState", x=100.0, y=-100.0),
                  d("ExitState", x=500.0, y=-100.0),
                  d("EntryState", d("StateTransition", stateToId=blend.ref()), x=-100.0, y=-100.0),
                  blend, name="Firelight")
        return [steady, flick], layer
