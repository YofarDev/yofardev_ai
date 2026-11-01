"""Moonshot M8 Task 3: `foley` events (contract v11), fired by timeline keys, on the generated avatar RML."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_kit as kit  # noqa: E402
import avatar_tablet as tb  # noqa: E402

RML = Path(__file__).resolve().parents[2] / "avatar" / "avatar.rml"
KINDS = ("step", "cloth", "click", "paper")


@pytest.fixture(scope="module")
def board() -> ET.Element:
    return ET.parse(RML).getroot().find("Artboard")


def _events(board: ET.Element) -> dict[str, ET.Element]:
    out = {}
    for ev in board.findall("Event"):
        if ev.get("name") == "foley":
            (prop,) = ev.findall("CustomPropertyString")
            assert prop.get("name") == "kind"
            assert prop.get("propertyValue") not in out
            out[prop.get("propertyValue")] = ev
    return out


def _keys(board: ET.Element) -> dict[tuple[str, str], list[int]]:
    """(animation, kind) -> callback frames."""
    kinds = {ev.get("id"): k for k, ev in _events(board).items()}
    out: dict[tuple[str, str], list[int]] = {}
    for a in board.findall("LinearAnimation"):
        for o in a.findall("KeyedObject"):
            if o.get("objectId") in kinds:
                (p,) = list(o)
                assert p.get("property") == "trigger"
                assert all(k.tag == "KeyFrameCallback" for k in p)
                out[(a.get("name"), kinds[o.get("objectId")])] = [int(k.get("frame")) for k in p]
    return out


def test_one_event_per_kind(board: ET.Element) -> None:
    assert set(_events(board)) == set(KINDS)


def test_footfalls_where_the_walk_crosses_each_stride() -> None:
    frames = kit.footfalls(0, 80, 850.0, 170.0)
    assert len(frames) >= 6 and frames[0] == 10 and frames[-1] == 80
    assert frames == sorted(set(frames))

    def walked(f: float) -> float:
        t = max(0.0, (f - 10) / 70)
        return 850.0 * t * t * (3 - 2 * t)

    for k, f in enumerate(frames):
        assert walked(f) >= k * 170.0 - 1e-6 and (f == 10 or walked(f - 1) < k * 170.0)


def test_steps_cloth_clicks_and_paper_on_their_frames(board: ET.Element) -> None:
    keys = _keys(board)
    steps = kit.footfalls(0, 80, 850.0, 170.0)
    out_c = next(m() for m in tb.CLIPS if m().name == "prop_tablet_out")
    away_c = next(m() for m in tb.CLIPS if m().name == "prop_tablet_away")
    assert keys == {
        ("presence_walkOut", "step"): steps,
        ("presence_walkIn", "step"): steps,
        ("gesture_grab", "cloth"): [23],
        ("prop_tablet_out", "click"): [out_c.hand[-1][1][0]],
        ("prop_tablet_away", "click"): [away_c.hand[-1][1][0]],
        ("prop_newspaper_out", "paper"): [tb.OUT_BEAT],
        ("prop_newspaper_away", "paper"): [tb.stagger(["handR", "handL"])["handL"]],
    }
    durations = {a.get("name"): int(a.get("duration")) for a in board.findall("LinearAnimation")}
    for (anim, _), frames in keys.items():
        assert all(0 <= f <= durations[anim] for f in frames)
    # the walk's steps come one stride apart in time too: never closer than 90 ms (Review Focus 4)
    assert min(b - a for a, b in zip(steps, steps[1:])) * 1000 / 60 >= 90
    assert math.isclose(23 * 1000 / 60, 383.3, abs_tol=0.1)
