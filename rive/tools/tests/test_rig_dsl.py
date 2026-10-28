"""Tests for rive/tools/rig_dsl.py (pure Python: no Rive CLI needed)."""

from __future__ import annotations

import math
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from rml import Doc, render  # noqa: E402
import rig_dsl as r  # noqa: E402

K: float = math.radians(30)


def test_material_dx_is_the_rotated_point() -> None:
    x3, z3 = 40.0, 90.0
    for a in (-K, -0.2, 0.0, 0.3, K):
        expected = x3 * math.cos(a) + z3 * math.sin(a) - x3
        assert r.eval_poly(r.material_dx(x3, z3), a) == pytest.approx(expected, abs=0.01)


def test_pitch_dy_moves_front_points_up_when_looking_up() -> None:
    assert r.eval_poly(r.pitch_dy(0.0, 100.0), math.radians(15)) < -20


def test_silhouette_of_a_circle_is_rotation_invariant_without_offset() -> None:
    for a in (-K, 0.1, K):
        assert r.eval_poly(r.silhouette_dx(1.0, 80.0, 80.0, 0.0), a) == pytest.approx(0.0, abs=0.01)


def test_fit3_hits_the_three_authored_poses() -> None:
    p = r.fit3(-12.0, 0.0, 31.0, K)
    assert r.eval_poly(p, -K) == pytest.approx(-12.0, abs=0.01)
    assert r.eval_poly(p, 0.0) == pytest.approx(0.0, abs=0.01)
    assert r.eval_poly(p, K) == pytest.approx(31.0, abs=0.01)


def test_fit3_of_a_material_point_recovers_it() -> None:
    x3, z3 = 60.0, 45.0
    poses = [r.eval_poly(r.material_dx(x3, z3), a) for a in (-K, 0.0, K)]
    p = r.fit3(*poses, K)
    for a in (-0.4, 0.1, 0.33):
        assert r.eval_poly(p, a) == pytest.approx(r.eval_poly(r.material_dx(x3, z3), a), abs=0.02)


def test_bound_tokens_add_linearly() -> None:
    p = r.poly_add(r.material_dx(10.0, 50.0), [(14.0, (r.tok("gaze"),))])
    base = r.eval_poly(p, 0.2)
    assert r.eval_poly(p, 0.2, {"gaze": 0.5}) == pytest.approx(base + 7.0, abs=0.01)


def test_tokpos_acts_on_one_side_only() -> None:
    p = [(0.0, ()), (-6.0, (r.tokpos("pitch"),))]
    assert r.eval_poly(p, 0.0, {"pitch": 1.0}) == pytest.approx(-6.0)
    assert r.eval_poly(p, 0.0, {"pitch": -1.0}) == pytest.approx(0.0)
    toks = r.Formulas(Doc(), str).poly(p)
    assert [t.tag for t in toks].count("FormulaTokenFunction") == 1


def test_poly_shift_merges_constants() -> None:
    p = r.poly_shift(r.material_dx(10.0, 0.0), 5.0)
    assert sum(1 for _, fs in p if not fs) == 1
    assert r.eval_poly(p, 0.0) == pytest.approx(5.0)


def _tokens(els: list) -> list[str]:
    return [e.tag for e in els]


def test_formula_tokens_balance_parentheses() -> None:
    d = Doc()
    f = r.Formulas(d, lambda p: f"0:1-{p}")
    toks = f.poly([(1.0, ()), (2.0, (r.COS,)), (3.0, (("sil", 4.0, 9.0),)), (5.0, (r.tok("blink"),))])
    tags = _tokens(toks)
    assert tags.count("FormulaTokenFunction") == tags.count("FormulaTokenParenthesisClose")
    assert "FormulaTokenParenthesisOpen" not in tags
    bound = [t for t in toks if t.tag == "FormulaTokenValue" and t.children]
    assert len(bound) == 1 and bound[0].children[0].attrs["propertyKey"] == 777


def test_angle_formula_clamps() -> None:
    d = Doc()
    tags = _tokens(r.Formulas(d, str).angle(0.5))
    assert tags[:3] == ["FormulaTokenValue", "FormulaTokenOperation", "FormulaTokenFunction"]


def test_rig_dedupes_identical_polys_and_shares_the_angle() -> None:
    d = Doc()
    rig = r.Rig(d, lambda p: f"0:1-{p}", origin=(0.0, 0.0), x_axis=r.Axis("yaw", K), y_axis=r.Axis("pitch", 0.26))
    rig.bone(r.BoneSpec("A", 10.0, -20.0, r.material_dx(10.0, 5.0), r.pitch_dy(-20.0, 5.0)))
    rig.bone(r.BoneSpec("B", 10.0, -20.0, r.material_dx(10.0, 5.0), r.pitch_dy(-20.0, 5.0)))
    angles = [c for c in rig.converters if c.attrs.get("name", "").endswith("Angle")]
    groups = [c for c in rig.converters if c.tag == "DataConverterGroup"]
    assert len(angles) == 2 and len(groups) == 2
    assert len(rig.binds) == 4


def test_rig_predicts_bone_positions() -> None:
    d = Doc()
    rig = r.Rig(d, str, origin=(400.0, 470.0), x_axis=r.Axis("yaw", K), y_axis=r.Axis("pitch", 0.26))
    rig.bone(r.BoneSpec("N", 400.0, 400.0, r.material_dx(0.0, 100.0), r.pitch_dy(0.0, 100.0)))
    x, y = rig.position("N", K, 0.0)
    assert x == pytest.approx(450.0, abs=0.01) and y == pytest.approx(400.0)


def test_grid_weights_are_a_partition_of_unity() -> None:
    g = r.Grid([0.0, 10.0, 20.0], [0.0, 10.0], lambda c, rr: f"G{c}{rr}")
    for x, y in ((3.0, 4.0), (-5.0, 2.0), (19.0, 30.0), (10.0, 10.0)):
        ws = g(x, y)
        assert sum(ws.values()) == pytest.approx(1.0)
        assert len(ws) <= 4


def test_chain_weights_interpolate_between_anchors() -> None:
    c = r.Chain([(0.0, "A"), (10.0, "B")], lambda x, y: x)
    assert c(2.5, 0.0) == pytest.approx({"A": 0.75, "B": 0.25})


def test_quantize_keeps_four_and_sums_to_255() -> None:
    q = r.quantize({"a": 0.4, "b": 0.3, "c": 0.15, "d": 0.1, "e": 0.05})
    assert len(q) == 4 and sum(v for _, v in q) == 255


def test_pack_round_trips() -> None:
    q = [("x", 200), ("y", 55)]
    values, indices = r.pack(q, {"x": 2, "y": 0})
    assert values & 0xFF == 200 and (values >> 8) & 0xFF == 55
    assert indices & 0xFF == 3 and (indices >> 8) & 0xFF == 1


def test_clockwise_orients_by_shoelace() -> None:
    tri = [(0.0, 0.0), (0.0, 10.0), (10.0, 0.0)]
    assert r.shoelace(tri) < 0
    assert r.shoelace(r.clockwise(tri)) > 0


def test_taper_is_closed_and_thin_at_the_ends() -> None:
    pts = [(0.0, 0.0), (10.0, 0.0), (20.0, 0.0)]
    out = r.taper(pts, 4.0, ends=0.1)
    assert len(out) == 6
    assert abs(out[0][1] - out[-1][1]) == pytest.approx(0.4, abs=1e-6)
    assert abs(out[1][1] - out[-2][1]) == pytest.approx(4.0, abs=1e-6)


def test_skinner_emits_weighted_vertices_and_one_tendon_per_bone() -> None:
    d = Doc()
    rig = r.Rig(d, str, origin=(0.0, 0.0), x_axis=r.Axis("yaw", K), y_axis=r.Axis("pitch", 0.26))
    rig.bone(r.BoneSpec("A", 0.0, 0.0, r.material_dx(0.0, 1.0)))
    rig.bone(r.BoneSpec("B", 10.0, 0.0, r.material_dx(10.0, 1.0)))
    sk = r.Skinner(rig)
    path = sk.path([(0.0, 0.0), (10.0, 0.0), (5.0, 8.0, "c")], r.Chain([(0.0, "A"), (10.0, "B")], lambda x, y: x))
    text = render(path)
    assert text.count("<CubicWeight") == 2 and text.count("<Weight") == 1
    assert text.count("<Tendon") == 2 and sk.vertices == 3


def test_critically_damped_spring_settles_without_overshoot() -> None:
    w = r.omega_for_settle(0.3)
    x, v, peak = 0.0, 0.0, 0.0
    for i in range(60):
        x, v = r.critically_damped(x, v, 1.0, w, 1 / 60)
        peak = max(peak, x)
        if i == 17:  # 0.3 s
            assert x == pytest.approx(0.95, abs=0.02)
    assert peak <= 1.0 + 1e-9 and x == pytest.approx(1.0, abs=1e-3)


def test_critically_damped_step_is_exact_under_substeps() -> None:
    w = r.omega_for_settle(0.3)
    a = r.critically_damped(0.0, 0.0, 1.0, w, 0.1)
    b = r.critically_damped(*r.critically_damped(0.0, 0.0, 1.0, w, 0.05), 1.0, w, 0.05)
    assert a[0] == pytest.approx(b[0]) and a[1] == pytest.approx(b[1])


def test_second_order_follower_overshoots_then_settles() -> None:
    f = r.SecondOrder(2.0, 0.4)
    f.reset(0.0)
    ys = [f.step(1.0, 1 / 60) for _ in range(240)]
    assert max(ys) > 1.05
    assert ys[-1] == pytest.approx(1.0, abs=0.01)


def test_simplify_stays_within_tolerance() -> None:
    vals = [math.sin(i / 10) for i in range(120)]
    keys = r.simplify(vals, 0.02)
    assert len(keys) < 50
    assert max(abs(r.interp_keys(keys, i) - v) for i, v in enumerate(vals)) <= 0.02 + 1e-9


def _turn_shape(d: float) -> tuple[float, float, int]:
    y = r.perform_turn([(0.0, 0.0), (0.5, d)], 3.0)["yaw"]
    i10 = next(i for i, v in enumerate(y) if v > 0.1 * d)
    i90 = next(i for i, v in enumerate(y) if v > 0.9 * d)
    return -min(y) / d, max(y) / d - 1, i90 - i10


def test_turn_follows_the_motion_rules() -> None:
    """MOTION: ~18 % anticipation, ~12 % overshoot; big turns take 18-22 frames (speed cap)."""
    for d in (1.25, 1.75):
        antic, over, frames = _turn_shape(d)
        assert 0.15 <= antic <= 0.19 and 0.11 <= over <= 0.13 and 18 <= frames <= 22, (d, antic, over, frames)


def test_perform_turn_channels() -> None:
    targets = [(0.0, 0.0), (1.0, 0.85), (2.6, 0.3), (4.2, -0.86), (6.0, 0.0)]
    ch = r.perform_turn(targets, 8.0)
    n = len(ch["yaw"])
    assert set(ch) == set(r.CHANNELS) and all(len(v) == n for v in ch.values())
    # gaze leads the head and saturates softly
    assert ch["yaw"][int(1.06 * 60)] < 0.01 < ch["gaze"][int(1.06 * 60)]
    assert max(abs(g) for g in ch["gaze"]) < 0.9
    # blinks: full closures on big steps 2.6-5.2 s apart, across the loop seam too (1.0, 4.2;
    # not the 6.0 step, 1.8 s after)
    starts = [i / 60 for i in range(1, n) if ch["blink"][i] > 0 and ch["blink"][i - 1] == 0]
    assert len(starts) == 2 and 2.6 <= starts[1] - starts[0] <= 5.2 and 2.6 <= 8.0 - starts[1] + starts[0] <= 5.2
    assert all(max(ch["blink"][round(t * 60):round(t * 60) + 20]) == 1.0 for t in starts)
    # idle layer: no frozen holds (every frame moves something)
    for i in range(n - 1):
        assert any(abs(ch[k][i + 1] - ch[k][i]) > 1e-6 for k in ch), i
    # a look raises the brows and shifts the mouth, then both relax
    assert max(ch["brow"][60:110]) > 0.5 and ch["brow"][130] == 0.0 and max(ch["mouth"]) > 0.3
    # roll toward the turn, dip mid-turn, smooth; the loop closes
    assert max(ch["roll"]) > 0.5 and min(ch["pitch"]) < -0.1
    def accel(v: list[float]) -> float:
        return max(abs(v[i + 1] - 2 * v[i] + v[i - 1]) for i in range(1, len(v) - 1))
    for k in ("yaw", "roll", "pitch"):  # per-frame acceleration bound: no pops
        assert accel(ch[k]) < 0.03, k
    for k, v in ch.items():
        assert abs(v[-1] - v[0]) < 0.01, k
    # hair: the fringe trails, the side locks trail it by ~40 ms, the tuft trails most and rebounds
    lag = ch["hairLag"]
    assert min(lag[60:120]) < -0.1
    peak = min(range(60, 120), key=lambda i: lag[i])
    side_peak = min(range(60, 120), key=lambda i: ch["sideLag"][i])
    assert 1 <= side_peak - peak <= 4
    tuft = ch["tuftLag"]
    assert min(tuft[60:140]) < min(lag[60:140])
    sign_changes = sum(1 for a, b in zip(tuft[64:140], tuft[65:141]) if a * b < 0)
    assert sign_changes >= 2
