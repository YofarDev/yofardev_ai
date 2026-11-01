"""Tests for the 3/4 face outline in rive/tools/head_turn.py (pure Python: no Rive CLI needed).

    uv run --with pytest pytest rive/tools/tests/test_head_turn.py
"""

from __future__ import annotations

import math
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import head_turn as ht  # noqa: E402
import rig_dsl as r  # noqa: E402

K = ht.K_YAW
CX = ht.CX


def pose(name: str) -> tuple[float, float, float]:
    """(rest x, right-side x at yaw -1, at yaw +1) of contour bone `name`, as shipped (M5: the faired
    outline, `ht.faired_poses`)."""
    x, _, _ = ht.CONTOUR[name]
    m, p = ht.faired_poses()[name]
    return x, m, p


def near_left(name: str) -> tuple[float, float]:
    """(rest x, x at yaw +1) of the LEFT contour bone: the near side when turning right."""
    x, m, _ = pose(name)
    return 2 * CX - x, 2 * CX - m


def contour_at(y: float, a: float, side: float) -> float:
    """Screen x of the turned (faired) contour (right side +1, left -1) at height y, linear between bones."""
    return ht.contour_x_at(y, a, side)


def test_round_sections_reproduce_the_m1_ellipse_silhouette() -> None:
    for x, y, _ in ht.CONTOUR.values():
        w, z0, dd, _, _ = ht.section(x, y)
        e = math.sqrt((w * math.cos(K)) ** 2 + (dd * math.sin(K)) ** 2)
        m, p = ht.ellipse_contour_pose(x, y)
        assert p == pytest.approx(CX + e + z0 * math.sin(K), abs=0.05)
        assert m == pytest.approx(CX + e - z0 * math.sin(K), abs=0.05)


@pytest.mark.parametrize("name", list(ht.CONTOUR))
def test_contour_bones_rest_exactly_on_the_outline(name: str) -> None:
    x, m, p = pose(name)
    assert r.eval_poly(ht.poses(m, x, p), 0.0) == pytest.approx(0.0, abs=1e-3)
    assert r.section_silhouette(*ht.section(x, ht.CONTOUR[name][1]), 0.0) == pytest.approx(x - CX, abs=0.01)


def chin_travel() -> float:
    """The chin bone's x travel at yaw +1 (faired)."""
    return ht.faired_poses()["Chin"][1] - 400.0


def test_far_cheekbone_bulges_past_the_old_outline() -> None:
    """M5: the fairing keeps most of the M3 bulge (12 px before, 10.8 now) while it rounds it."""
    x, _, p = pose("C")
    _, old_p = ht.ellipse_contour_pose(x, ht.CONTOUR["C"][1])
    assert p - x >= 9  # out past the rest outline
    assert p - old_p >= 4  # and past the M1 turned outline (M4: 8.2, M5: 4.6)


def test_far_cheek_runs_from_the_cheekbone_to_the_jaw_without_a_notch() -> None:
    """M5 ruling 1 overturns M3 round 3's flattened far cheek (the notch under the far lens): below
    the cheekbone the far contour falls steadily toward the jaw, never back out."""
    xs = [pose(n)[2] for n in ("C", "K", "J", "W", "Q", "V")]
    assert all(b < a for a, b in zip(xs, xs[1:])), xs
    assert pose("C")[2] - pose("J")[2] >= 15  # the cheekbone still stands out over the cheek


def test_near_cheek_holds_its_place() -> None:
    """Critic round 3: the near cheek must not shrink away; M5's fairing lets it ease in a little
    toward the chin's swing (it slid in ~5 px in M2, 0 in M3, <= 9 now)."""
    for name in ("K", "J"):
        rest, turned = near_left(name)
        assert turned - rest <= 15.0, name  # the left side: in would be a larger x
    assert near_left("C")[1] - near_left("C")[0] <= 9.0


def test_chin_swings_with_the_jaw() -> None:
    """Critic round 3: the chin and the lower jaw swing as one volume (the jaw midpoint moved
    ~26 artboard px at yaw 1, the chin's centre should travel ~45; faired: ~36)."""
    assert 34 <= chin_travel() <= 46
    for name in ("Q", "V"):
        x, m, p = pose(name)
        rest_l, turned_l = near_left(name)
        assert (p - x) + (turned_l - rest_l) >= 52, name  # both jaw edges at that height move right


def test_the_near_jaw_angle_moves_less_than_the_chin() -> None:
    """M3 held the near jaw angle in place (a near-90 deg corner at yaw 1, M5 ruling 1); faired, the
    chin's swing spreads up the jaw line, but the jaw angle still moves far less than the chin."""
    rest_j, turned_j = near_left("J")
    rest_v, turned_v = near_left("V")
    assert abs(turned_j - rest_j) <= 15
    assert turned_v - rest_v >= 20  # the jaw line runs on to the chin, toward the turn
    assert chin_travel() - (turned_j - rest_j) >= 20


def test_the_jaw_changes_shape_not_only_position() -> None:
    """Rigid sliding would move every contour height by the same amount."""
    for side_name in ("far", "near"):
        shifts = []
        for name in ("C", "K", "J", "W", "Q", "V"):
            if side_name == "far":
                x, _, p = pose(name)
                shifts.append(p - x)
            else:
                rest, turned = near_left(name)
                shifts.append(turned - rest)
        assert max(shifts) - min(shifts) >= 12, (side_name, shifts)
    # and differently from the M1 ellipse model, which only sheared the outline
    old = [ht.ellipse_contour_pose(*ht.CONTOUR[n][:2])[1] for n in ("C", "K", "J")]
    new = [pose(n)[2] for n in ("C", "K", "J")]
    assert max(b - a for a, b in zip(old, new)) >= 4


def test_the_turn_widens_the_face_only_a_little() -> None:
    for name in ("C", "K", "J"):
        x, m, p = pose(name)
        rest_w = 2 * (x - CX)
        turned_w = p - (2 * CX - m)
        assert abs(turned_w - rest_w) <= 16, name


def test_mouth_leads_with_the_nose_and_rides_over_the_chin() -> None:
    s = math.sin(K)
    nose, mouth, chin = ht.NOSE_Z * s, ht.MOUTH_Z * s, ht.CHIN_Z * s
    assert nose - mouth <= 15  # M2: 61 vs 35, the mouth lagged the nose by 26 px
    assert mouth >= chin
    assert mouth - chin <= 8


@pytest.mark.parametrize("a", [K, -K, K / 2, -K / 2])
def test_mouth_stays_inside_the_turned_outline(a: float) -> None:
    centre = 400.0 + r.eval_poly(ht.mat(400, ht.MOUTH_Z), a)
    sx = r.eval_poly(ht.factor(0.88, 0.88), a)
    # the widest mouth (aa): corners ~28 px out at y 478, the lower lip ~18 px out at y 490
    for y, half in ((478.0, 28.0 * sx), (490.0, 18.0 * sx)):
        assert centre + half <= contour_at(y, a, 1.0) - 6, y
        assert centre - half >= contour_at(y, a, -1.0) + 6, y


@pytest.mark.parametrize("a", [K, -K])
def test_far_lens_and_blush_fit_inside_the_far_cheek(a: float) -> None:
    far = 1.0 if a > 0 else -1.0
    _, outer = ht.lens_ends(400 + far * 45, a)
    assert far * (contour_at(396.0, a, far) - outer) >= 4  # the outer frame end, before its stroke
    bx = 400 + far * 62
    centre = bx + r.eval_poly(ht.face_point(bx, ht.BLUSH_Y, ht.face_z(bx, ht.BLUSH_Y)), a)
    edge = centre + far * 0.75 * 27 * ht.foreshorten(bx, ht.BLUSH_Y, a)  # the visible core of the gradient
    # (round 3: the far cheek is flatter and the blush rides it in; the rendered overhang gate,
    # review_face.py yaw, stays 0 px)
    assert far * (contour_at(ht.BLUSH_Y, a, far) - edge) >= 2


def test_far_lens_foreshortens_like_the_far_eye() -> None:
    inner, outer = ht.lens_ends(445.0, K)
    far = abs(outer - inner) / 86
    assert 0.55 <= far <= math.cos(K)
    inner, outer = ht.lens_ends(355.0, K)
    assert abs(outer - inner) / 86 >= 1.0  # the near lens faces the viewer


def test_blush_foreshortens_on_the_far_cheek_and_caps_the_near_one() -> None:
    assert ht.foreshorten(462.0, ht.BLUSH_Y, K) < 0.6
    assert ht.foreshorten(462.0, ht.BLUSH_Y, -K) == pytest.approx(ht.NEAR_WIDEN)
    assert ht.foreshorten(462.0, ht.BLUSH_Y, 0.0) == pytest.approx(1.0)


def test_contour_poses_are_history_free_formulas_of_yaw() -> None:
    """Each bone x is c0 + c1 cos a + c2 sin a: the same yaw always gives the same outline."""
    for name in ht.CONTOUR:
        x, m, p = pose(name)
        poly = ht.poses(m, x, p)
        assert all(set(fs) <= {r.COS, r.SIN} for _, fs in poly)
        assert r.eval_poly(poly, K) == pytest.approx(p - x, abs=0.01)
        assert r.eval_poly(poly, -K) == pytest.approx(m - x, abs=0.01)


def test_fringe_parallax_moves_the_front_tips_more_than_the_temples() -> None:
    front, temple = ht.fringe_parallax(100.0), ht.fringe_parallax(30.0)
    assert r.eval_poly(front, 0.0) == 0.0
    assert 15.0 < r.eval_poly(front, K) < 25.0  # ~0.4 x the depth's yaw travel at yaw +1
    assert r.eval_poly(temple, K) < 0.4 * r.eval_poly(front, K)
    assert r.eval_poly(front, -K) == pytest.approx(-r.eval_poly(front, K))


def test_far_cheek_shade_shows_only_on_the_cheek_turning_away() -> None:
    assert ht.far_cheek_opacity(0.0, 1.0) == 0.0 and ht.far_cheek_opacity(0.0, -1.0) == 0.0
    assert ht.far_cheek_opacity(1.0, 1.0) == pytest.approx(ht.FAR_SHADE[3])  # right cheek, turning right
    assert ht.far_cheek_opacity(1.0, -1.0) == 0.0  # the near cheek stays lit
    assert ht.far_cheek_opacity(-0.5, -1.0) == pytest.approx(ht.FAR_SHADE[3] / 2)
