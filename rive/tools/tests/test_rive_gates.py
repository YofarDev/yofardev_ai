"""Tests for rive/tools/rive_gates.py (M6 ruling 10): the gate collector and the scene arguments."""

from __future__ import annotations

from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from rive_gates import collect, parse_scenes  # noqa: E402

KNOWN = ["beach", "campfire", "deepSpace", "livingRoom"]


def test_an_all_ok_list_passes() -> None:
    assert collect(["campfire: parallax corners (ok)", "campfire: plane travel (ok)"])
    assert collect([])


def test_a_combined_line_with_one_failing_verdict_fails() -> None:
    assert not collect(["beach: rain wet (ok); back to default: max diff 3/255 (FAIL)"])
    assert not collect(["ok line", "campfire: pointer proof (FAIL); other (ok)"])


def test_the_prefix_style_fails_on_fail() -> None:
    assert not collect(["tablet: FAIL hold seam: max channel delta 4/255"])
    assert not collect(["FAIL ik: a hand error above 2.0 px"])


def test_the_ok_prefix_style_passes() -> None:
    assert collect(["newspaper: ok  ik: worst hand error within 2.0 px",
                    "ok  hold seam: max channel delta 0/255"])


def test_fail_is_a_whole_case_sensitive_word() -> None:
    assert collect(["failover (ok)", "FAILED nothing", "this did not fail", "NOFAIL"])


def test_no_scene_means_all_known_scenes() -> None:
    assert parse_scenes([], KNOWN) == KNOWN


def test_named_scenes_are_kept_in_order() -> None:
    assert parse_scenes(["campfire", "beach"], KNOWN) == ["campfire", "beach"]


def test_an_unknown_scene_is_rejected() -> None:
    with pytest.raises(SystemExit) as exc:
        parse_scenes(["campfire", "mars"], KNOWN)
    assert exc.value.code == 2
