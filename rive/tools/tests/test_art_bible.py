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
