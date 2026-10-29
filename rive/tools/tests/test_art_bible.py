"""Tests for rive/tools/art_bible.py: the bible must not drift from the app tokens."""

from __future__ import annotations

from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import art_bible
from art_bible import RUBRIC, SCENES, TOKENS, lint_colours

ROOT: Path = Path(__file__).resolve().parents[3]
PALETTE: Path = ROOT / "lib/core/design/tokens/app_palette.dart"


def dart_palette() -> dict[str, str]:
    text: str = PALETTE.read_text(encoding="utf-8")
    return {m.group(1): m.group(2).upper() for m in re.finditer(r"static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\)", text)}


def test_tokens_match_app_palette() -> None:
    dart: dict[str, str] = dart_palette()
    for name, argb in TOKENS.items():
        assert dart[name] == argb, name


def test_every_contract_scene_has_a_script_with_its_token_accent() -> None:
    contract: str = (ROOT / "rive/CONTRACT.md").read_text(encoding="utf-8")
    for scene in ("livingRoom", "campfire", "beach", "deepSpace"):
        assert scene in contract
        assert SCENES[scene].accent == TOKENS[f"{scene}Accent"]
        assert set(SCENES[scene].times) == {"dawn", "day", "dusk", "night"}


def test_rubric_weights_sum_to_one() -> None:
    assert abs(sum(RUBRIC.values()) - 1.0) < 1e-9
    assert art_bible.TARGET_PER_ASSET <= art_bible.TARGET_OVERALL


def test_lint_flags_value_and_saturation_but_not_accent_alpha_or_emissives() -> None:
    rml: str = "\n".join(
        [
            '<SolidColor colorValue="FFFFE0A0"/>',  # value 1.0 > campfire max 0.95, sat 0.37
            '<SolidColor colorValue="FF00FF00"/>',  # saturation 1.0 > cap
            f'<SolidColor colorValue="{TOKENS["campfireAccent"]}"/>',  # accent: allowed
            '<SolidColor colorValue="00FFFFFF"/>',  # transparent: allowed
            '<Shape name="emitFlame"><SolidColor colorValue="FFFFFF00"/></Shape>',  # emissive
            '<SolidColor colorValue="FF2A3040"/>',  # in range
            '<SolidColor colorValue="FFFFFFFF"/>',  # neutral highlight: allowed
        ]
    )
    problems: list[str] = lint_colours(rml, "campfire")
    assert sorted({p.split(":")[0] for p in problems}) == ["1", "2"]


def test_lint_accepts_six_digit_colours() -> None:
    assert lint_colours('<SolidColor colorValue="2A3040"/>', "livingRoom") == []


def test_lint_ignores_numbers_that_look_like_hex_but_reads_colour_keys() -> None:
    rml: str = "\n".join(
        [
            '<Weight values="16711935" indices="66051"/>',  # packed skin weights, not colours
            '<CubicWeight values="255" indices="1" inValues="12345678"/>',
            '<KeyFrameColor frame="0" value="FF00FF00"/>',  # a keyed colour is still linted
        ]
    )
    assert {p.split(":")[0] for p in lint_colours(rml, "livingRoom")} == {"3"}


def test_scene_scripts_carry_flicker_rim_and_ambient() -> None:
    assert {s: SCENES[s].flicker for s in SCENES} == {
        "livingRoom": 0.15, "campfire": 1.0, "beach": 0.0, "deepSpace": 0.0,
    }
    assert all(s.ambient_amount == 0.35 and s.rim_intensity == 0.35 for s in SCENES.values())
    assert SCENES["campfire"].key_xy == (-0.49, -0.872)


def test_fit_colour_keeps_hue_and_meets_the_scene_caps() -> None:
    out: str = art_bible.fit_colour("FF0B1026", "campfire")
    h0, _, _ = art_bible.hsv("FF0B1026")
    h1, s1, _ = art_bible.hsv(out)
    assert s1 <= 0.55
    assert abs(h1 - h0) * 360 <= 1.0
    assert out.startswith("FF")


def test_fit_colour_outputs_lint_clean() -> None:
    import random

    rng: random.Random = random.Random(7)
    for scene in SCENES:
        colours: list[str] = [
            "FF" + "".join(f"{rng.randrange(256):02X}" for _ in range(3)) for _ in range(300)
        ] + ["FF000000", "FF0000FF", "FFFF0000", "80FFE0A0", "FF010203"]
        line: str = " ".join(
            f'<SolidColor colorValue="{art_bible.fit_colour(c, scene)}"/>' for c in colours
        )
        assert lint_colours(line, scene) == [], scene


def test_fit_colour_passes_accent_transparent_and_neutral_highlights_unchanged() -> None:
    for scene, script in SCENES.items():
        assert art_bible.fit_colour(script.accent, scene) == script.accent
        assert art_bible.fit_colour("00123456", scene) == "00123456"
        assert art_bible.fit_colour("FFFFFFFF", scene) == "FFFFFFFF"


SCENE_LIGHTS: Path = ROOT / "lib/core/design/tokens/scene_lights.dart"


def dart_scene_lights() -> dict[str, dict[str, str]]:
    """Per scene, the named arguments of its `LightRig(...)` in scene_lights.dart (raw text)."""
    text: str = SCENE_LIGHTS.read_text(encoding="utf-8")
    consts: dict[str, str] = dict(re.findall(r"static const double (_\w+) = ([-\d.]+);", text))
    out: dict[str, dict[str, str]] = {}
    for scene, body in re.findall(r"AvatarScene\.(\w+) => LightRig\((.*?)\n\s*\),", text, re.S):
        args = dict(re.findall(r"(\w+):\s*([^,]+),", body))
        out[scene] = {k: consts.get(v.strip(), v.strip()) for k, v in args.items()}
    return out


def test_scene_lights_match_art_bible() -> None:
    """M4 ruling 3: one light table. AppPalette's per-scene colours and SceneLights' numbers equal
    art_bible.SCENES (key x/y = cos/sin of key_dir to 3 digits)."""
    palette: dict[str, str] = dart_palette()
    lights: dict[str, dict[str, str]] = dart_scene_lights()
    assert set(lights) == set(SCENES)
    for scene, s in SCENES.items():
        assert palette[f"{scene}Key"] == s.key, scene
        assert palette[f"{scene}Rim"] == s.rim, scene
        assert palette[f"{scene}Ambient"] == s.ambient, scene
        assert palette[f"{scene}Fog"] == s.fog, scene
        rig: dict[str, str] = lights[scene]
        for colour, suffix in (("keyColor", "Key"), ("rimColor", "Rim"), ("ambientColor", "Ambient"),
                               ("fogColor", "Fog")):
            assert rig[colour] == f"AppPalette.{scene}{suffix}.toARGB32()", (scene, colour)
        kx, ky = s.key_xy
        numbers: dict[str, float] = {"keyIntensity": s.key_intensity, "keyX": kx, "keyY": ky,
                                     "rimIntensity": s.rim_intensity, "ambientAmount": s.ambient_amount,
                                     "flicker": s.flicker}
        for name, want in numbers.items():
            assert abs(float(rig[name]) - want) < 1e-9, (scene, name, rig[name], want)
