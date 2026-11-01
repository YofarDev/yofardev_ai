"""Moonshot M8 Task 4 (contract v11): one NPC per scene driven by `npc` / `npcX` / `npcLook`, and the
weather `fog`, on freshly generated RML (rulings 7, 8, 13)."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_scenes  # noqa: E402
import scene_npc  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
M7 = "927a606"   # the last M7 commit: every scene's ids and rest look come from here
SCENES = ("livingRoom", "campfire", "beach", "deepSpace")
STATES = ["away", "rest", "idle", "move", "notice", "react"]
SCENE_MAX = 409_600
NPC_MAX = 30 * 1024


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {sid: ET.fromstring(Path(getattr(gen_scenes, sid)()).read_text()) for sid in SCENES}
    finally:
        gen_scenes.OUT_ROOT = root


def _git(*args: str) -> str | None:
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def _old(sid: str) -> ET.Element:
    text = _git("show", f"{M7}:rive/scenes/{sid}/{sid}.rml")
    if text is None:
        pytest.skip(f"git show {M7} unavailable")
    return ET.fromstring(text)


def _n(i: str) -> int:
    return int(i.split(":")[1])


def _vm(doc: ET.Element) -> ET.Element:
    return next(v for v in doc.iter("ViewModel") if v.get("name") == "SceneVM")


def _props(doc: ET.Element) -> dict[str, str]:
    """property id -> name."""
    return {p.get("id"): p.get("name") for p in _vm(doc) if p.tag.startswith("ViewModelProperty")}


def _binds(doc: ET.Element, el: ET.Element) -> dict[str, tuple[str, str | None]]:
    """propertyKey -> (source property name, converter id) of the binds directly under `el`."""
    props = _props(doc)
    return {b.get("propertyKey"): (props[b.get("sourcePathIds").split("-")[1]], b.get("converterId"))
            for b in el if b.tag == "DataBindContext"}


def _named(doc: ET.Element, name: str, tag: str | None = None) -> ET.Element:
    return next(e for e in doc.iter() if e.get("name") == name and (tag is None or e.tag == tag))


def _eval(doc: ET.Element, conv_id: str | None, x: float, env: dict[str, float] | None = None) -> float:
    """Evaluates a `DataConverterFormula` (or no converter: the input itself) at input `x`, bound
    tokens read from `env` by property name (0 when absent)."""
    if conv_id is None:
        return x
    props = _props(doc)
    conv = next(c for c in doc.iter("DataConverterFormula") if c.get("id") == conv_id)
    expr = []
    for t in conv:
        if t.tag == "FormulaTokenValue":
            b = t.find("DataBindContext")
            v = (env or {}).get(props[b.get("sourcePathIds").split("-")[1]], 0.0) if b is not None \
                else float(t.get("operationValue"))
            expr.append(f"({v!r})")
        elif t.tag == "FormulaTokenOperation":
            expr.append("+-*/"[int(t.get("operationType"))])
        elif t.tag == "FormulaTokenInput":
            expr.append(f"({x!r})")
        elif t.tag == "FormulaTokenFunction":
            expr.append({"0": "min(", "1": "max("}[t.get("functionType")])
        elif t.tag == "FormulaTokenArgumentSeparator":
            expr.append(",")
        elif t.tag == "FormulaTokenParenthesisClose":
            expr.append(")")
        else:
            raise AssertionError(t.tag)
    return float(eval("".join(expr)))  # noqa: S307 (our own generated tokens)


def _layer(doc: ET.Element) -> ET.Element:
    scene = doc.find("Artboard")
    (layer,) = [lay for lay in scene.iter("StateMachineLayer") if lay.get("name") == "Npc"]
    return layer


def _anims(doc: ET.Element) -> dict[str, ET.Element]:
    return {a.get("id"): a for a in doc.find("Artboard").iter("LinearAnimation")}


def _state_anims(doc: ET.Element) -> dict[str, list[ET.Element]]:
    """npc state -> its animation(s) (three for the notice blend), from the AnyState transitions."""
    props = _props(doc)
    vals = {v.get("id"): v.get("key") for e in doc.iter("DataEnumCustom") for v in e}
    layer, anims = _layer(doc), _anims(doc)
    states = {s.get("id"): s for s in layer if s.tag in ("AnimationState", "BlendState1DViewModel")}
    out: dict[str, list[ET.Element]] = {}
    targets = {}
    for t in [*layer.find("AnyState"), *[t for s in states.values() for t in s
                                         if t.tag in ("StateTransition", "BlendStateTransition")]]:
        conds = list(t.iter("TransitionViewModelCondition"))
        assert len(conds) == 1
        b = conds[0].find(".//BindablePropertyEnum/DataBindContext")
        assert props[b.get("sourcePathIds").split("-")[1]] == "npc"
        key = vals[conds[0].find("TransitionValueEnumComparator").get("value")]
        assert targets.setdefault(key, t.get("stateToId")) == t.get("stateToId"), key
    for key, sid in targets.items():
        s = states[sid]
        if s.tag == "AnimationState":
            out[key] = [anims[s.get("animationId")]]
        else:
            out[key] = [anims[b.get("animationId")] for b in s if b.tag == "BlendAnimation1D"]
    return out


def _keyed(anim: ET.Element, el_id: str, prop: str) -> list[float]:
    for ko in anim:
        if ko.get("objectId") == el_id:
            for kp in ko:
                if kp.get("property") == prop:
                    return [float(k.get("value")) for k in kp]
    return []


# ---------------------------------------------------------------- ids


def test_m8_range_is_free_at_m7() -> None:
    assert gen_scenes.M8_ID_START == 930000 < gen_scenes.M7_ID_START
    for sid in SCENES:
        ids = [_n(e.get("id")) for e in _old(sid).iter() if e.get("id")]
        assert not [i for i in ids if gen_scenes.M8_ID_START <= i < gen_scenes.M7_ID_START], sid


# M12 ruling 6: the `SceneFront`'s own eases (`Scene.d12`)
M12_EASE = gen_scenes.M12_ID_START


@pytest.mark.parametrize("sid", SCENES)
def test_existing_ids_never_move(rml: dict[str, ET.Element], sid: str) -> None:
    old = {e.get("id"): e for e in _old(sid).iter() if e.get("id")}
    new = {e.get("id"): e for e in rml[sid].iter() if e.get("id")}
    assert not set(old) - set(new), sorted(set(old) - set(new))[:10]
    for i, e in old.items():
        attrib = dict(new[i].attrib)
        if M12_EASE <= _n(attrib.get("interpolatorId", "0:0")) < gen_scenes.M11_ID_START:
            # M12 ruling 6: a `SceneFront` key points at the front's own copy of the ease it used
            attrib["interpolatorId"] = e.get("interpolatorId")
        assert (new[i].tag, attrib) == (e.tag, e.attrib), (i, e.tag, e.get("name"))
    added = set(new) - set(old)
    # M8 additions, and M9's (contract v12), M10's (v13), M11's (v14) and M12's from their own ranges below it
    # (M12 lane Q: the NPC drawing switches from scene_npc.M12_ID_START, below the shared M12 range)
    lo = min(M12_EASE, scene_npc.M12_ID_START)
    assert all(lo <= _n(i) < gen_scenes.M7_ID_START for i in added), \
        sorted(i for i in added if not lo <= _n(i) < gen_scenes.M7_ID_START)[:10]


# ---------------------------------------------------------------- view model


@pytest.mark.parametrize("sid", SCENES)
def test_scene_vm_gains_fog_and_the_npc(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    vm = _vm(doc)
    names = [p.get("name") for p in vm if p.tag.startswith("ViewModelProperty")]
    v12 = [n for n, _, _ in gen_scenes.world_kit.vm_tail(sid)]   # contract v12 (M9), v13 (M10), v14 (M11) follow
    assert names[names.index("dusk") + 1:] == ["fog", "npc", "npcX", "npcLook", *v12]
    by_name = {p.get("name"): p for p in vm if p.tag.startswith("ViewModelProperty")}
    for n in ("fog", "npcX", "npcLook"):
        assert by_name[n].tag == "ViewModelPropertyNumber"
    assert by_name["npc"].tag == "ViewModelPropertyEnumCustom"
    enum = next(e for e in doc.iter("DataEnumCustom") if e.get("id") == by_name["npc"].get("enumId"))
    assert [v.get("key") for v in enum] == STATES == list(scene_npc.NPC_STATES)
    inst = vm.find("ViewModelInstance")
    got = {v.get("viewModelPropertyId"): v.get("propertyValue") for v in inst}
    for n in ("fog", "npcX", "npcLook"):
        assert float(got[by_name[n].get("id")]) == 0.0
    rest = next(v for v in enum if v.get("key") == "rest")
    assert got[by_name["npc"].get("id")] == rest.get("id")


# ---------------------------------------------------------------- the NPC layer


@pytest.mark.parametrize("sid", SCENES)
def test_npc_layer_has_every_state_and_blends_fast(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    layer = _layer(doc)
    states = _state_anims(doc)
    assert set(states) == set(STATES)
    (entry,) = layer.find("EntryState")
    rest_state = next(s for s in layer if s.get("id") == entry.get("stateToId"))
    others = [s for s in layer if s.tag in ("AnimationState", "BlendState1DViewModel") and s is not rest_state]
    # every other state is reached from AnyState and returns to rest on its own (never AnyState -> rest)
    assert sorted(t.get("stateToId") for t in layer.find("AnyState")) == sorted(s.get("id") for s in others)
    for s in others:
        back = [t for t in s if t.tag in ("StateTransition", "BlendStateTransition")]
        assert [t.get("stateToId") for t in back] == [rest_state.get("id")]
    for t in [*layer.find("AnyState"), *[t for s in others for t in s if "Transition" in t.tag]]:
        assert int(t.get("duration", "0")) <= scene_npc.NPC_BLEND_MS
    assert _anims(doc)[rest_state.get("animationId")] is states["rest"][0]
    # every state loops (react is one short loop, the app holds it as long as it wants)
    for k, anims in states.items():
        for a in anims:
            assert a.get("loopValue") == "loop", (k, a.get("name"))
    # notice is aimed by npcLook: a 1D blend at -1 / 0 / +1
    props = _props(doc)
    blend = next(s for s in layer if s.tag == "BlendState1DViewModel")
    b = blend.find("BindablePropertyNumber/DataBindContext")
    assert props[b.get("sourcePathIds").split("-")[1]] == "npcLook"
    assert sorted(float(x.get("value")) for x in blend if x.tag == "BlendAnimation1D") == [-1.0, 0.0, 1.0]
    # the notice poses share one length (they blend frame by frame)
    assert len({a.get("duration") for a in states["notice"]}) == 1


@pytest.mark.parametrize("sid", SCENES)
def test_every_state_keys_the_same_properties(rml: dict[str, ET.Element], sid: str) -> None:
    """Blends between states are only defined when every state keys every NPC property."""
    doc = rml[sid]
    sets = {}
    for k, anims in _state_anims(doc).items():
        for a in anims:
            sets[(k, a.get("name"))] = {(ko.get("objectId"), kp.get("property")) for ko in a for kp in ko}
    union = set().union(*sets.values())
    for k, s in sets.items():
        assert s == union, (k, sorted(union - s)[:5])


@pytest.mark.parametrize("sid", SCENES)
def test_away_hides_the_npc_and_rest_is_the_v10_look(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    states = _state_anims(doc)
    for name, (rest_op, away_op) in scene_npc.NPC_ROOTS[sid].items():
        el = _named(doc, name)
        assert _keyed(states["away"][0], el.get("id"), "opacity") == [away_op], name
        assert set(_keyed(states["rest"][0], el.get("id"), "opacity")) == {rest_op}, name
        assert float(el.get("opacity", "1")) == rest_op, name


# ---------------------------------------------------------------- M12: the drawing switches (ruling 7)
# (scene, layer, animation prefix, {state: the drawing copies it shows}); the fish's notice is checked apart
DRAW_SWITCHES = [
    ("livingRoom", "NpcDraw", "npc_cat", {"away": ("CatAsleep",), "rest": ("CatAsleep",), "idle": ("CatAwake",),
                                          "move": ("CatWalk",), "notice": ("CatAwake",), "react": ("CatAwake",)}),
    ("deepSpace", "NpcDraw", "npc_alien", {"away": ("Alien",), "rest": ("Alien",), "idle": ("AlienNpc",),
                                           "move": ("AlienNpc",), "notice": ("AlienNpc",), "react": ("AlienNpc",)}),
    ("beach", "Npc2Draw", "npc_gulls", {
        **dict.fromkeys(("away", "rest", "idle", "notice"), ("Gull0Wing", "Gull1Wing")),
        **dict.fromkeys(("move", "react"), ("Gull0WingNear", "Gull0WingFar", "Gull1WingNear", "Gull1WingFar"))}),
    ("forestCabin", "NpcDraw", "npc_squirrel", {"away": ("SqSit",), "rest": ("SqSit",), "idle": ("SqSit",),
                                                "move": ("SqRun",), "notice": ("SqSit",), "react": ("SqSit",)}),
    ("cafe", "NpcDraw", "npc_fish", {k: ("FishProfile",) for k in STATES if k != "notice"}),
]


@pytest.fixture(scope="module")
def draw_docs(rml: dict[str, ET.Element], tmp_path_factory: pytest.TempPathFactory) -> dict[str, ET.Element]:
    out = tmp_path_factory.mktemp("draw")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return {**rml, **{sid: ET.fromstring(Path(gen_scenes.SCENE_BUILDERS[sid]()).read_text())
                          for sid in ("cafe", "forestCabin")}}
    finally:
        gen_scenes.OUT_ROOT = root


def _opacity_keys(anim: ET.Element) -> dict[str, float]:
    return {ko.get("objectId"): float(kf.get("value")) for ko in anim if ko.tag == "KeyedObject"
            for kp in ko if kp.get("property") == "opacity" for kf in kp}


def _layer_anims(doc: ET.Element, layer: ET.Element) -> list[ET.Element]:
    anims = _anims(doc)
    return [anims[s.get("animationId")] for s in layer.iter() if s.tag in ("AnimationState", "BlendAnimation1D")]


@pytest.mark.parametrize("sid,layer,prefix,shown", DRAW_SWITCHES, ids=[d[0] for d in DRAW_SWITCHES])
def test_drawing_switch_cuts_on_its_own_layer(draw_docs: dict[str, ET.Element], sid: str, layer: str, prefix: str,
                                              shown: dict[str, tuple[str, ...]]) -> None:
    """M12 ruling 7 (lane Q): every NPC whose states swap drawing copies keys their opacity only on its own
    0 ms layer (one 1-frame hold per state), so the 200 ms pose blend never cross-fades two copies."""
    doc = draw_docs[sid]
    ab = doc.find("Artboard")
    names = {n for v in shown.values() for n in v} | ({"FishFront"} if sid == "cafe" else set())
    ids = {n: _named(doc, n).get("id") for n in names}
    layers = {lay.get("name"): lay for lay in ab.iter("StateMachineLayer")}
    pose = _layer_anims(doc, layers[layer.replace("Draw", "")])
    assert not any(set(_opacity_keys(a)) & set(ids.values()) for a in pose)
    draw = layers[layer]
    by_name = {a.get("name"): a for a in _layer_anims(doc, draw)}
    for k, on in shown.items():
        a = by_name[f"{prefix}_draw_{k}"]
        assert int(a.get("duration")) == 1
        assert _opacity_keys(a) == {i: float(n in on) for n, i in ids.items()}, k
    ts = [t for t in draw.iter() if t.tag in ("StateTransition", "BlendStateTransition") and t.get("stateToId")]
    assert len(ts) == 2 * (len(STATES) - 1) + 1
    assert all(int(t.get("duration", "0")) == 0 for t in ts)
    owners = {a.get("name") for a in _anims(doc).values() if set(_opacity_keys(a)) & set(ids.values())}
    assert owners == set(by_name)


def test_fish_notice_shows_the_front_only_near_look_zero(draw_docs: dict[str, ET.Element]) -> None:
    """The fish's notice draws its profile at |npcLook| >= 0.5 (the director's notice look is +-0.7: M11 drew a
    70/30 mix of both copies there) and its front view nearer 0, cut 1e-4 apart on the look."""
    doc = draw_docs["cafe"]
    draw = next(lay for lay in doc.find("Artboard").iter("StateMachineLayer") if lay.get("name") == "NpcDraw")
    prof, front = _named(doc, "FishProfile").get("id"), _named(doc, "FishFront").get("id")
    anims = _anims(doc)
    (blend,) = [s for s in draw if s.tag == "BlendState1DViewModel"]
    steps = [(float(b.get("value")), _opacity_keys(anims[b.get("animationId")])) for b in blend
             if b.tag == "BlendAnimation1D"]
    assert [v for v, _ in steps] == [-1.0, -0.5, -0.4999, 0.4999, 0.5, 1.0]
    for v, keys in steps:
        assert keys == ({prof: 1.0, front: 0.0} if abs(v) >= 0.5 else {prof: 0.0, front: 1.0}), v


def test_alien_away_fades_through_its_wrapper(draw_docs: dict[str, ET.Element]) -> None:
    doc = draw_docs["deepSpace"]
    shown = _named(doc, "AlienShown")
    assert [c.get("name") for c in shown if c.get("name")] == ["AlienNpc", "Alien"]
    states = _state_anims(doc)
    for k, anims in states.items():
        for a in anims:
            assert _keyed(a, shown.get("id"), "opacity") == [0.0 if k == "away" else 1.0], k


# ---------------------------------------------------------------- npcX paths and hit zones


@pytest.mark.parametrize("sid", SCENES)
def test_paths_are_history_free_binds_of_npc_x(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    path = scene_npc.NPC_PATHS.get(sid)
    used = {b.get("sourcePathIds") for b in doc.iter("DataBindContext")}
    npc_x = f"{_vm(doc).get('id')}-{next(i for i, n in _props(doc).items() if n == 'npcX')}"
    if path is None:
        # the owl's path is unused: nothing binds npcX
        assert npc_x not in used and not any(
            t.find("DataBindContext") is not None and t.find("DataBindContext").get("sourcePathIds") == npc_x
            for t in doc.iter("FormulaTokenValue"))
        return
    node, hit, end, anchor = path
    for name, at1 in ((node, end), (hit, None)):
        el = _named(doc, name)
        binds = _binds(doc, el)
        assert binds["13"][0] == binds["14"][0] == "npcX", name
        x0, y0 = float(el.get("x")), float(el.get("y"))
        # npcX 0 is the v10 spot exactly
        assert _eval(doc, binds["13"][1], 0.0) == pytest.approx(x0, abs=1e-6)
        assert _eval(doc, binds["14"][1], 0.0) == pytest.approx(y0, abs=1e-6)
        if at1 is not None:
            assert _eval(doc, binds["13"][1], 1.0) == pytest.approx(at1[0], abs=1.0)
            assert _eval(doc, binds["14"][1], 1.0) == pytest.approx(at1[1], abs=1.0)
    # the hit zone follows the art: it keeps its offset from the art's anchor (scaled with the art)
    el, h = _named(doc, node), _named(doc, hit)
    bn, bh = _binds(doc, el), _binds(doc, h)

    def art(t: float) -> tuple[float, float, float]:
        s = _eval(doc, bn["16"][1], t) if "16" in bn else 1.0
        return (_eval(doc, bn["13"][1], t) + s * anchor[0], _eval(doc, bn["14"][1], t) + s * anchor[1], s)
    ax0, ay0, s0 = art(0.0)
    off = (float(h.get("x")) - ax0, float(h.get("y")) - ay0)
    for t in (0.1, 0.25, 0.4, 0.5, 0.75, 0.9, 1.0):
        ax, ay, s = art(t)
        assert _eval(doc, bh["13"][1], t) == pytest.approx(ax + off[0] * s / s0, abs=3.0), (t, "x")
        assert _eval(doc, bh["14"][1], t) == pytest.approx(ay + off[1] * s / s0, abs=3.0), (t, "y")


def test_cat_depth_compensation_holds_the_cabinet_plane(rml: dict[str, ET.Element]) -> None:
    """The cat lives in Plane4 (in front of the rug) but rides the cabinet's Plane3 at npcX 0: its
    x / y take back the plane gain difference times (1 - depth)."""
    doc = rml["livingRoom"]
    el = _named(doc, "CatNpc")
    b = _binds(doc, el)
    g = (gen_scenes.PARALLAX_GAINS[3] - gen_scenes.PARALLAX_GAINS[4])
    for key, prop, travel in (("13", "parallaxX", gen_scenes.PARALLAX_TRAVEL[0]),
                              ("14", "parallaxY", gen_scenes.PARALLAX_TRAVEL[1])):
        at0 = _eval(doc, b[key][1], 0.0, {prop: 1.0}) - _eval(doc, b[key][1], 0.0)
        at1 = _eval(doc, b[key][1], 1.0, {prop: 1.0}) - _eval(doc, b[key][1], 1.0)
        assert at0 == pytest.approx(g * travel, abs=0.01)
        assert at1 == pytest.approx(0.0, abs=0.01)


def test_catwalksby_stays_a_separate_one_shot(rml: dict[str, ET.Element]) -> None:
    doc = rml["livingRoom"]
    wk = _named(doc, "WalkingCat", "Node")
    assert wk.get("x") == "1180"
    assert any(a.get("name") == "ev_catWalksBy" for a in doc.iter("LinearAnimation"))
    assert not [k for a in _state_anims(doc).values() for x in a for k in x if k.get("objectId") == wk.get("id")]


# ---------------------------------------------------------------- fog


@pytest.mark.parametrize("sid", SCENES)
def test_fog_thickens_the_veils_history_free(rml: dict[str, ET.Element], sid: str) -> None:
    doc = rml[sid]
    scene = doc.find("Artboard")
    bound = []
    for e in scene.iter("Shape"):
        b = _binds(doc, e)
        if "18" in b and b["18"][0] == "fog":
            bound.append(e.get("name"))
            base = float(e.get("opacity"))
            assert _eval(doc, b["18"][1], 0.0) == pytest.approx(base, abs=1e-9)
            gain = scene_npc.FOG_BANKS[sid][4] if e.get("name") == "FogBank" else scene_npc.FOG_GAIN
            assert _eval(doc, b["18"][1], 1.0) == pytest.approx(base + gain, abs=1e-6)
    banks = ["FogBank"] if sid in scene_npc.FOG_BANKS else []
    assert sorted(bound) == sorted([f"FogVeil{k}" for k in scene_npc.FOG_VEILS.get(sid, ())] + banks)
    if banks:
        plane = next(p for p in scene if p.get("name") == f"Plane{scene_npc.FOG_BANKS[sid][0]}")
        assert any(c.get("name") == "FogBank" for c in plane)
    fronts = [a for a in doc.findall("Artboard") if a.get("name") == "SceneFront"]
    if sid in ("campfire", "beach"):
        (front,) = fronts
        fog = _named(front, "FrontFog", "Shape")
        b = _binds(doc, fog)
        assert b["18"][0] == "fog" and float(fog.get("opacity")) == 0.0
        assert _eval(doc, b["18"][1], 1.0) == pytest.approx(scene_npc.FRONT_FOG_GAIN, abs=1e-6)
    if sid == "deepSpace":
        props = _props(doc)
        fog_path = f"{_vm(doc).get('id')}-{next(i for i, n in props.items() if n == 'fog')}"
        assert fog_path not in {b.get("sourcePathIds") for b in doc.iter("DataBindContext")}


# ---------------------------------------------------------------- budgets


@pytest.mark.parametrize("sid", SCENES)
def test_built_scene_budgets(sid: str) -> None:
    riv = ROOT / "assets" / "rive" / "scenes" / f"{sid}.riv"
    size = riv.stat().st_size
    assert size <= SCENE_MAX
    old = _git("cat-file", "-s", f"{M7}:assets/rive/scenes/{sid}.riv")
    if old is None:
        pytest.skip("no git history")
    if size == int(old) and not os.environ.get("NPC_BUDGET_STRICT"):
        pytest.skip("scene not rebuilt yet")
    # the NPC (<= 30 KB) plus the fog binds (a few hundred bytes)
    # M9 / M10 grew the beach past the NPC's line on purpose: the gulls and the trail (contract v12), then
    # the night (contract v13, M10: ~1.6 KB)
    # M11 (contract v14): the tier gate in every scene (~0.3-1.9 KB), the seasons in livingRoom (tulips, a
    # pumpkin: ~6.5 KB) and campfire (flowers, leaves, rust tufts: ~41 KB)
    m11 = {"livingRoom": 8192, "campfire": 44 * 1024}.get(sid, 2048)
    assert size - int(old) <= NPC_MAX + 1024 + (2048 if sid == "beach" else 0) + m11, (sid, size, int(old))
