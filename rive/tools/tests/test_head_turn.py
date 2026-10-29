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
    """(rest x, right-side x at yaw -1, at yaw +1) of contour bone `name`."""
    x, y, _ = ht.CONTOUR[name]
    m, p = ht.contour_pose(x, y)
    return x, m, p


def near_left(name: str) -> tuple[float, float]:
    """(rest x, x at yaw +1) of the LEFT contour bone: the near side when turning right."""
    x, m, _ = pose(name)
    return 2 * CX - x, 2 * CX - m


def contour_at(y: float, a: float, side: float) -> float:
    """Screen x of the turned contour (right side +1, left -1) at height y, linear between bones."""
    pts = []
    for x, yy, _ in ht.CONTOUR.values():
        m, p = ht.contour_pose(x, yy)
        dx = r.eval_poly(ht.poses(m, x, p), a if side > 0 else -a)
        pts.append((yy, CX + side * (x - CX + dx)))
    pts.sort()
    for (y0, x0), (y1, x1) in zip(pts, pts[1:]):
        if y0 <= y <= y1:
            return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    raise ValueError(y)


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


def test_far_cheekbone_bulges_past_the_old_outline() -> None:
    x, _, p = pose("C")
    _, old_p = ht.ellipse_contour_pose(x, ht.CONTOUR["C"][1])
    assert p - x >= 12  # out past the rest outline
    assert p - old_p >= 7  # and past the M1 turned outline


def test_far_cheek_flattens_under_the_cheekbone() -> None:
    """Critic round 3: below the cheekbone the far contour comes in past the rest outline (it bulged
    18 px out), so the line from the cheekbone to the chin is flat, not a swollen cheek."""
    for name in ("K", "J"):
        x, _, p = pose(name)
        assert -12 <= p - x <= 0, name
    assert pose("C")[2] - pose("K")[2] >= 25  # the cheekbone stands out over the flat cheek


def test_near_cheek_fills_out() -> None:
    """Critic round 3: the near cheek holds its place (it slid in ~5 px) instead of shrinking."""
    for name in ("K", "J"):
        rest, turned = near_left(name)
        assert turned - rest <= 1.0, name  # the left side: in would be a larger x


def test_nose_tip_breaks_over_the_far_cheek() -> None:
    """At yaw +-1 the nose tip (art: right end 410 at y 440, the nostril hook 392 at y 452) reaches
    past the far contour, by a few px, not far out into the hair."""
    tip = (ht.NOSE_TIP_Z) * math.sin(K)
    right = 410.0 + tip + ht.NOSE_TIP_RIGHT - contour_at(440.0, K, 1.0)
    left = contour_at(452.0, -K, -1.0) - (392.0 - tip)
    for past in (right, left):
        assert 0.0 <= past <= 8.0, (right, left)


def test_chin_swings_with_the_jaw() -> None:
    """Critic round 3: the chin and the lower jaw swing as one volume (the jaw midpoint moved
    ~26 artboard px at yaw 1, the chin's centre should travel ~45)."""
    chin = ht.CHIN_Z * math.sin(K)
    assert 38 <= chin <= 46
    for name in ("Q", "V"):
        x, m, p = pose(name)
        rest_l, turned_l = near_left(name)
        assert (p - x) + (turned_l - rest_l) >= 52, name  # both jaw edges at that height move right


def test_near_jaw_corner_stays_out_while_the_chin_swings() -> None:
    rest_j, turned_j = near_left("J")
    rest_v, turned_v = near_left("V")
    old_m, _ = ht.ellipse_contour_pose(*ht.CONTOUR["J"][:2])
    assert abs(turned_j - rest_j) <= 6  # the jaw angle holds its place ...
    assert (2 * CX - old_m) - turned_j >= 10  # ... where the M1 outline slid it in
    assert turned_v - rest_v >= 20  # while the jaw line runs on to the chin, toward the turn
    assert ht.CHIN_Z * math.sin(K) >= 35


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
    assert max(b - a for a, b in zip(old, new)) >= 7


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
