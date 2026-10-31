"""Tests for rive/tools/avatar_light.py and the v7 view-model defaults (moonshot M4 Task 4)."""

from __future__ import annotations

from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_light as al
from art_bible import SCENES
import check_contract
import gen_scenes


def test_avatar_light_defaults_are_the_living_room_rig() -> None:
    s = SCENES["livingRoom"]
    want = {"lightKey": s.key, "lightKeyIntensity": s.key_intensity, "lightKeyX": -0.737, "lightKeyY": 0.675,
            "lightRim": s.rim, "lightRimIntensity": 0.35, "lightAmbient": s.ambient,
            "lightAmbientAmount": 0.35, "lightFlicker": 0.15}
    assert {k: v for k, (_, v) in al.LIGHT_DEFAULTS.items()} == want


def test_flicker_loops_seamlessly_inside_its_range() -> None:
    vals = [al.flicker(f) for f in range(al.FLICKER_FRAMES + 1)]
    assert vals[0] == vals[-1]
    lo, hi = al.FLICKER_RANGE
    assert min(vals) >= lo - 1e-3 and max(vals) <= hi + 1e-3
    assert max(vals) - min(vals) > 0.3  # it does flicker
    # the step across the seam is no bigger than any other step (no pop)
    steps = [abs(b - a) for a, b in zip(vals, vals[1:])]
    seam = abs(al.flicker(1) - al.flicker(al.FLICKER_FRAMES - 1 + 1))
    assert seam <= max(steps)
    assert all(k in (2, 3, 5, 7, 11, 13) for k, _, _ in al.FLICKER_HARMONICS)


def test_lean_tips_at_most_four_degrees_and_drops_the_head_up_to_ten_px() -> None:
    assert al.lean_head_drop(0) == 0
    assert 6.0 <= al.lean_head_drop(1) <= 10.0
    assert 0 < al.lean_tip_degrees(1) <= 4.0
    assert al.lean_head_drop(0.5) < al.lean_head_drop(1)


def test_rim_band_is_the_interior_weight() -> None:
    assert math.isclose(al.RIM_W, 1.56)


def test_contract_scene_vm_matches_the_scene_generator() -> None:
    c = check_contract.parse_contract()
    # v11's `fog` / `npc*` mint from the M8 range (gen_scenes.Scene._v11_props), after these; v12's
    # `npc2*`, `moonPhase`, `festive` from the M9 range (Scene._v12_props, world_kit.v12_members) after them
    v11 = ["fog", "npc", "npcX", "npcLook"]
    v12 = ["npc2", "npc2X", "npc2Look", "moonPhase", "festive"]
    v13 = ["night"]   # M10: from the M10 range (Scene._v13_props, world_kit.v13_members)
    assert [n for n in c["scene_vm_props"]][-10:] == v11 + v12 + v13
    names = [n for n in c["scene_vm_props"] if n not in ("eventId", "event", *v11, *v12, *v13)]
    for sid in SCENES:
        gen = gen_scenes.scene_vm_defaults(sid)
        assert [n for n, _, _ in gen] == names
        assert {n: t for n, t, _ in gen} == {n: c["scene_vm_props"][n] for n in names}
        want = {**check_contract.scene_light_defaults(sid), "rain": 0.0, "daylight": 0.0, "dusk": 0.0}
        assert {n: v for n, _, v in gen} == want


def _avatar_rml() -> "ET.Element":
    import xml.etree.ElementTree as ET
    return ET.parse(Path(__file__).resolve().parents[2] / "avatar" / "avatar.rml").getroot()


def test_flicker_reaches_down_to_045() -> None:
    """M5 ruling 7: the loop's range is 0.45-1.0 at lightFlicker 1 (M4: 0.62-1.0)."""
    vals = [al.flicker(f) for f in range(al.FLICKER_FRAMES)]
    assert al.FLICKER_RANGE == (0.45, 1.0)
    assert min(vals) <= 0.46 and max(vals) >= 0.99


def test_key_cheek_tint_multiplies_the_key_under_the_screen_pool() -> None:
    """M5 ruling 7: KeyCheekTint is the key pool again, multiply-blended, face-clipped, drawn under
    KeyCheek inside the Firelight node (the flicker loop drives it), opacity KEY_TINT x
    lightKeyIntensity x lightFlicker through one converter; minted from the M5 range."""
    root = _avatar_rml()
    by_id = {e.get("id"): e for e in root.iter() if e.get("id")}
    fire = next(e for e in root.iter("Node") if e.get("name") == "Firelight")
    names = [c.get("name") for c in fire]
    assert names.index("KeyCheek") < names.index("KeyCheekTint")  # first child paints in front
    tint = next(c for c in fire if c.get("name") == "KeyCheekTint")
    assert int(tint.get("id").split(":")[1]) >= 1_000_000
    assert tint.get("blendModeValue") == str(al.MULTIPLY)
    face = next(e for e in root.iter("Shape") if e.get("name") == "Face")
    assert tint.find("ClippingShape").get("sourceId") == face.get("id")
    op = next(b for b in tint.findall("DataBindContext") if b.get("propertyKey") == str(al.KEYS["opacity"]))
    conv = by_id[op.get("converterId")]
    vals = [float(t.get("operationValue")) for t in conv.findall("FormulaTokenValue")]
    assert al.KEY_TINT in vals
    bound = [b for t in conv.findall("FormulaTokenValue") for b in t.findall("DataBindContext")]
    assert len(bound) == 1  # lightFlicker, read inside the formula (history-free: no state)
    stop = tint.find("Fill/RadialGradient/GradientStop/DataBindContext")
    assert stop is not None and stop.get("propertyKey") == str(al.KEYS["stopColor"])  # lightKey colour


def test_key_pools_fade_to_clear_at_their_whole_rim() -> None:
    """The circular radial gradient must reach clear at the ellipse's rim: a w x w circle squashed
    by scaleY (a w x h ellipse cut it at 20 % alpha top and bottom)."""
    root = _avatar_rml()
    for name in ("KeyCheek", "KeyCheekTint"):
        sh = next(e for e in root.iter("Shape") if e.get("name") == name)
        el = sh.find("Ellipse")
        grad = sh.find("Fill/RadialGradient")
        assert float(el.get("width")) == float(el.get("height")) == 2 * float(grad.get("endX")), name
        assert float(sh.get("scaleY")) == al.CHEEK_SIZE[1] / al.CHEEK_SIZE[0]
