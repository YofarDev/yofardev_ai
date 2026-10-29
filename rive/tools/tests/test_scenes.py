"""Tests for the scene generator's campfire diorama (moonshot M4 Task 6, rulings 12-14)."""

from __future__ import annotations

from pathlib import Path
import re
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from art_bible import EMISSIVE_PREFIX, SCENES, lint_colours  # noqa: E402
import gen_scenes  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
COMMITTED = ROOT / "rive" / "scenes" / "campfire" / "campfire.rml"


@pytest.fixture(scope="module")
def rml(tmp_path_factory: pytest.TempPathFactory) -> str:
    """A fresh campfire, generated into a temporary directory."""
    out = tmp_path_factory.mktemp("scenes")
    root = gen_scenes.OUT_ROOT
    gen_scenes.OUT_ROOT = str(out)
    try:
        return Path(gen_scenes.campfire()).read_text()
    finally:
        gen_scenes.OUT_ROOT = root


def _converter_values(rml: str) -> dict[str, float]:
    """converter id -> its `k` (every diorama converter is `k * input`)."""
    out = {}
    for m in re.finditer(r'<DataConverterFormula id="([\d:]+)">\s*<FormulaTokenValue operationValue="([-\d.]+)"', rml):
        out[m.group(1)] = float(m.group(2))
    return out


def test_generator_is_deterministic_and_committed(rml: str) -> None:
    assert rml == COMMITTED.read_text()


def test_six_planes_with_the_ruling_gains(rml: str) -> None:
    assert gen_scenes.PARALLAX_GAINS == (0.0, 0.15, 0.3, 0.5, 0.7, 1.0)
    assert gen_scenes.PARALLAX_TRAVEL == (40.0, 24.0)
    k_of = _converter_values(rml)
    assert len(k_of) == len(set(k_of.values()))  # one shared converter per travel
    vm = re.search(r'<ViewModel [^>]*name="SceneVM"', rml)
    assert vm
    px = re.search(r'<ViewModelPropertyNumber name="parallaxX" id="([\d:]+)"', rml).group(1)
    py = re.search(r'<ViewModelPropertyNumber name="parallaxY" id="([\d:]+)"', rml).group(1)
    for k, gain in enumerate(gen_scenes.PARALLAX_GAINS):
        m = re.search(rf'<Node x="0" y="0" name="Plane{k}" id="[\d:]+">\n((?:\s*<DataBindContext [^>]*/>\n)*)', rml)
        assert m, f"Plane{k}"
        binds = re.findall(r'sourcePathIds="[\d:]+-([\d:]+)" propertyKey="(\d+)" converterId="([\d:]+)"', m.group(1))
        if gain == 0:
            assert binds == []
            continue
        got = {(src, key): k_of[conv] for src, key, conv in binds}
        assert got == {(px, "13"): pytest.approx(gain * 40), (py, "14"): pytest.approx(gain * 24)}


def test_planes_paint_back_to_front_behind_the_screen_overlays(rml: str) -> None:
    at = [rml.index(f'name="Plane{k}"') for k in range(5, -1, -1)]
    assert at == sorted(at)  # first declared paints in front: Plane5 first
    assert rml.index('name="RainFx"') < at[0] and rml.index('name="FlareWash"') < at[0]


def test_fog_veils_bind_light_fog_in_front_of_the_three_back_planes(rml: str) -> None:
    fog = re.search(r'<ViewModelPropertyColor name="lightFog" id="([\d:]+)"', rml).group(1)
    for k in range(3):
        plane = rml.index(f'name="Plane{k}"')
        veil = rml.index(f'name="FogVeil{k}"')
        nxt = rml.find('<Node x="0" y="0" name="Plane', plane + 1)
        assert plane < veil and (nxt == -1 or veil < nxt)
        body = rml[veil:rml.index("</Shape>", veil)]
        assert body.count(f'-{fog}" propertyKey="38"') == gen_scenes.FOG_FILLS
    assert 'name="FogVeil3"' not in rml
    densities = [v[0] for v in gen_scenes.FOG_VEILS]
    assert densities == [0.55, 0.35, 0.18]
    a = int(SCENES["campfire"].fog[:2], 16) / 255
    for dens in densities:
        op = gen_scenes.fog_opacity(dens, SCENES["campfire"].fog)
        assert 0 < op <= 1
        assert op * (1 - (1 - a) ** gen_scenes.FOG_FILLS) == pytest.approx(dens, abs=1e-3)
    assert gen_scenes.fog_opacity(0.55, "00000000") == 0.0


def test_lint_clean(rml: str) -> None:
    assert lint_colours(rml, "campfire") == []


def test_light_sources_are_named_emissive(rml: str) -> None:
    for name in ("emitStar0", "emitGlint0", "emitMoon", "emitMoonGlow", "emitShootingStar", "emitFireFlare",
                 "emitFire", "emitGlow", "emitSpark0", "emitCorePivot", "emitMain", "emitDetachedFlame0",
                 "emitFlareEmber0", "emitCoalBed", "emitFirefly0", "emitTentLantern", "emitLogHeat"):
        assert f'name="{name}"' in rml, name
    # lit surfaces are not light sources: they go through the colour-script fit
    for name in ("LightPool", "TreeGlow", "Ground", "TentLit", "Sky"):
        assert f'name="{name}"' in rml, name
    # the paints of emissives carry the prefix on their own line (the lint is line based)
    assert f'<SolidColor colorValue="FFFFF6E0" name="{EMISSIVE_PREFIX}"' in rml


def test_firelight_drives_the_light_pool_and_tree_glow(rml: str) -> None:
    ids = {n: re.search(rf'name="{n}" id="([\d:]+)"', rml).group(1) for n in ("LightPoolFlicker", "TreeGlow")}
    anim = re.search(r'<LinearAnimation duration="89" fps="60" loopValue="loop" name="amb_firelight".*?</LinearAnimation>',
                     rml, re.S).group(0)
    for n, i in ids.items():
        obj = re.search(rf'<KeyedObject objectId="{i}"[^>]*>(.*?)</KeyedObject>', anim, re.S)
        assert obj, n
        keys = [float(v) for v in re.findall(r'<KeyFrameDouble frame="\d+" value="([-\d.]+)"', obj.group(1))]
        assert keys[0] == keys[-1] == 1.0 and min(keys) < 0.9  # seamless loop, and it flickers


def test_contract_names_survive(rml: str) -> None:
    for hit in ("Hit_fire", "Hit_tent", "Hit_owl", "Hit_sky"):
        assert f'name="{hit}"' in rml
    for prop in ("fire", "tent", "owl", "sky"):
        assert f'name="Tap_{prop}"' in rml
    for ev in gen_scenes.SCENE_EVENTS["campfire"]:
        assert f'name="ev_{ev}"' in rml or f'key="{ev}"' in rml
