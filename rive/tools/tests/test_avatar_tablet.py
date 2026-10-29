"""Tests for rive/tools/avatar_tablet.py (moonshot M4 Task 5: the tablet prop)."""

from __future__ import annotations

from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import arm_rig
import avatar_tablet as tb
from avatar_kit import L1, L2, ik
from rml import Doc

CLIPS = {c.name: c for c in (make() for make in tb.CLIPS)}


def test_slab_corners_follow_the_shape_language() -> None:
    assert tb.CORNER / min(tb.W, tb.H) >= 0.18
    assert tb.SCREEN_R / min(tb.W - 2 * tb.BEZEL, tb.H - 2 * tb.BEZEL) >= 0.18


def test_two_nodes_reproduce_the_projection() -> None:
    m = tb.plane()
    phi, sx, sy, theta = tb.svd2(m)
    assert sx > 0 and sy > 0

    def rot(a: float) -> tuple[float, float, float, float]:
        return math.cos(a), -math.sin(a), math.sin(a), math.cos(a)

    def mul(p: tuple[float, ...], q: tuple[float, ...]) -> tuple[float, float, float, float]:
        return (p[0] * q[0] + p[1] * q[2], p[0] * q[1] + p[1] * q[3], p[2] * q[0] + p[3] * q[2],
                p[2] * q[1] + p[3] * q[3])

    got = mul(mul(rot(phi), (sx, 0.0, 0.0, sy)), rot(theta))
    assert all(math.isclose(g, w, abs_tol=1e-9) for g, w in zip(got, m))


def test_screen_faces_the_eyes_and_the_viewer() -> None:
    nx, ny, nz = tb.normal()
    assert nz < 0  # toward the viewer: the screen shows
    assert ny < -0.5  # mostly up, toward the face above it
    assert nx < 0  # and toward the face (the viewer's left of the tablet)
    assert tb.HOLD[0] > 400  # held toward the viewer's right, where the 3/4 gaze lands


def test_clip_lengths() -> None:
    out, hold, away = (CLIPS[f"prop_tablet_{c}"] for c in ("out", "hold", "away"))
    assert 400 <= out.frames * 1000 / 60 <= 500  # ~450 ms
    assert 350 <= away.frames * 1000 / 60 <= 450  # ~400 ms
    assert hold.frames == 120 and hold.loop


def test_clips_start_and_end_in_the_gesture_rest_pose() -> None:
    out, away = CLIPS["prop_tablet_out"], CLIPS["prop_tablet_away"]
    for side in (-1, 1):
        assert out.arms[side][0].rest and away.arms[side][away.frames].rest
        assert out.hand[side][0] == (0, "rest") and away.hand[side][-1][1] == "rest"
    assert out.opacity[0][1] == 0.0 and away.opacity[-1][1] == 0.0
    assert out.glow[0][1] == 0.0 and away.glow[-1][1] == 0.0


def test_hands_stay_on_the_slab() -> None:
    """Once a hand holds the tablet, its blade sits on its grip point every frame."""
    out, hold, away = (CLIPS[f"prop_tablet_{c}"] for c in ("out", "hold", "away"))
    lag = tb.stagger(["handL", "handR"])["handR"]

    def off(clip: tb.Clip, side: int, f: int) -> float:
        a = clip.arms[side][f]
        fd = math.radians(tb.finger_dir(clip.tablet[f], side))
        blade = (a.wrist[0] + tb.HAND_REACH * math.cos(fd), a.wrist[1] + tb.HAND_REACH * math.sin(fd))
        return math.dist(blade, tb.grip(clip.tablet[f], side))

    for f in range(3, out.frames + 1):  # the left hand holds it from the hip (turning onto it by frame 3)
        assert off(out, 1, f) < 0.5, f
    for f in range(lag + tb.OUT_BEAT, out.frames + 1):  # the right hand once it has caught the edge
        assert off(out, -1, f) < 0.5, f
    for f in range(hold.frames + 1):
        assert off(hold, -1, f) < 0.5
        assert off(hold, 1, f) < 4.5  # the thumb flick rocks the left hand by at most 4 px
    for f in range(0, 3):
        assert off(away, 1, f) < 0.5 and off(away, -1, f) < 0.5


def test_every_wrist_is_reachable_and_each_arm_bends_one_way() -> None:
    for clip in CLIPS.values():
        for side in (-1, 1):
            bends = set()
            for f, a in clip.arms[side].items():
                sx, sy = tb.SHOULDER[side]
                assert math.dist(a.wrist, (sx, sy)) <= L1 * a.fs + L2 * a.fs2 + 1e-6, (clip.name, side, f)
                r = (0.0, 0.0, 0.0) if a.rest else ik(side, a.wrist, a.finger, False, a.fs, a.fs2)
                _, bend = arm_rig.ik_target(side, r, a.fs, a.fs2)
                if bend:
                    bends.add(bend)
            assert len(bends) <= 1, (clip.name, side, bends)  # no elbow flip inside a clip


def test_hold_loop_is_seamless() -> None:
    hold = CLIPS["prop_tablet_hold"]
    assert hold.tablet[0] == hold.tablet[hold.frames]
    for side in (-1, 1):
        a, b = hold.arms[side][0], hold.arms[side][hold.frames]
        assert math.dist(a.wrist, b.wrist) < 1e-9 and math.isclose(a.finger, b.finger)
    # the list scrolls by exactly one item: the scrolled list draws like the unscrolled one
    assert hold.scroll[0][1] == 0.0 and hold.scroll[-1][1] == -tb.LIST_PERIOD


def test_pull_out_anticipates_and_overshoots() -> None:
    out = CLIPS["prop_tablet_out"]
    rots = [out.tablet[f].rot for f in range(out.frames + 1)]
    assert min(rots) < tb.HIP_ROT - 0.1  # winds up past the hip angle
    assert max(rots) > tb.HOLD_POSE.rot + 0.05  # overshoots the reading angle
    assert math.isclose(rots[-1], tb.HOLD_POSE.rot, abs_tol=1e-9)
    ys = [out.arms[1][f].wrist[1] for f in range(out.frames + 1)]
    assert min(ys) < out.arms[1][out.frames].wrist[1] - 5  # the lift overshoots, then settles


def test_prop_layer_graph() -> None:
    d = Doc(start=10)
    values = {v: d("DataEnumValue", key=v, value=v) for v in ("none", "tablet")}
    t = tb.Tablet(d, "0:1-0:2", values, d("CubicEaseInterpolator"))
    anims = {n: d("LinearAnimation", name=n) for n in ("prop_none", "prop_tablet_out", "prop_tablet_hold",
                                                       "prop_tablet_away")}
    layer = t.layer(anims)
    assert layer.attrs["name"] == "Prop"
    states = {s.attrs["animationId"]: s for s in layer.children if s.tag == "AnimationState"}
    by_anim = {n: states[a.ref()] for n, a in anims.items()}
    ref_name = {s.ref(): n for n, s in by_anim.items()}

    def edges(name: str) -> list[tuple[str, str | None, object]]:
        out = []
        for tr in by_anim[name].children:
            cond = next((c for c in tr.children if c.tag == "TransitionViewModelCondition"), None)
            val = None
            if cond is not None:
                vref = next(c for c in cond.children if c.tag == "TransitionValueEnumComparator").attrs["value"]
                val = next(k for k, v in values.items() if v.ref() == vref)
            out.append((ref_name[tr.attrs["stateToId"]], val, tr.attrs.get("exitTime")))
        return out

    assert edges("prop_none") == [("prop_tablet_out", "tablet", None)]  # no keys in none: gestures win
    assert edges("prop_tablet_out") == [("prop_tablet_away", "none", None), ("prop_tablet_hold", None, 100)]
    assert edges("prop_tablet_hold") == [("prop_tablet_away", "none", None)]
    assert edges("prop_tablet_away") == [("prop_tablet_out", "tablet", 55), ("prop_tablet_hold", "tablet", None),
                                         ("prop_none", None, 100)]
    for s in by_anim.values():  # every interruption blends (Review Focus 1: no pop)
        for tr in s.children:
            if not tr.attrs.get("exitTime") == 100 or s is by_anim["prop_tablet_away"]:
                assert 0 < int(tr.attrs["duration"]) <= 200
