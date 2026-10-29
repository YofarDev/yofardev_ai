"""M5 ruling 1: the faired 3/4 face outline (rive/tools/head_turn.py), gated on the posed contour
bones (pure Python, no render; the rendered evidence is `review_face.py yaw_sweep`).

    uv run --with pytest pytest rive/tools/tests/test_head_fairing.py
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
GRID = [(yaw, pitch, jaw) for yaw in (-1.0, -0.5, 0.5, 1.0) for pitch in (-1.0, 0.0, 1.0) for jaw in (0.0, 1.0)]


def test_the_m4_tables_break_the_gate() -> None:
    """The gate sees the defect: the M4 outline at yaw +1 has a dent (the notch under the far lens)
    and a turn past the bound (the cheekbone corner)."""
    m4 = ht.m4_contour_chain(1.0)
    assert not ht.is_convex(m4) or ht.max_turn(m4) > ht.rest_bound()
    assert max(ht._turns(m4)) > math.radians(30)  # the notch: a +54 deg dent
    assert ht.max_turn(m4) > ht.rest_bound()


def test_the_bound_is_the_rest_outlines_largest_turn_times_1_25() -> None:
    rest = [ht.bone_rest(n) for n in ht.CHAIN]
    assert ht.rest_bound() == pytest.approx(1.25 * ht.max_turn(rest))
    assert ht.is_convex(rest)
    assert math.degrees(ht.max_turn(rest)) == pytest.approx(26.0, abs=0.1)  # at the chin


@pytest.mark.parametrize("yaw,pitch,jaw", GRID)
def test_faired_outline_is_convex_and_within_the_bound(yaw: float, pitch: float, jaw: float) -> None:
    """Review Focus 3: yaw +-1, +-0.5 x pitch -1/0/1 x jaw 0/1; the bound is 1.25 x the unturned
    outline's largest turn at the same pitch and jaw drop (the jaw drop deepens the chin's turn)."""
    chain = ht.contour_chain(yaw, pitch, jaw)
    assert ht.is_convex(chain), [round(math.degrees(t), 1) for t in ht._turns(chain)]
    assert ht.max_turn(chain) <= ht.rest_bound(pitch, jaw) + 1e-9


def test_the_turned_outline_is_symmetric() -> None:
    """Yaw -1 is the mirror image of yaw +1 (one fairing, mirrored)."""
    plus, minus = ht.contour_chain(1.0), ht.contour_chain(-1.0)
    for (n, x, y), (_, mx, my) in zip(plus, reversed(minus)):
        assert x == pytest.approx(2 * CX - mx, abs=0.01), n
        assert y == pytest.approx(my), n


def test_the_rest_pose_is_untouched() -> None:
    """Every contour bone's yaw shift is 0 at yaw 0 (the art), and an already fair outline (the
    rest pose) comes back from the fairing unchanged."""
    for n in ht.CHAIN:
        assert r.eval_poly(ht.bone_yaw_poly(n), 0.0) == pytest.approx(0.0, abs=1e-3), n
    rest = [(n, *ht.bone_rest(n)) for n in ht.CHAIN]
    assert ht.contour_chain(0.0) == [(n, pytest.approx(x, abs=1e-3), y) for n, x, y in rest]
    assert ht.fair_contour(rest, ht.rest_bound(), min_turn=0.0) == rest


def test_fairing_moves_x_only_and_pins_the_chain_ends() -> None:
    raw = ht.m4_contour_chain(1.0)
    faired = ht.fair_contour(raw, ht.rest_bound())
    assert [y for _, _, y in faired] == [y for _, _, y in raw]
    assert faired[0] == raw[0] and faired[-1] == raw[-1]
    assert ht.is_convex(faired) and ht.max_turn(faired) <= ht.rest_bound()


def test_a_dent_is_pushed_out_to_the_hull() -> None:
    """A point inside the hull (a notch) leaves the curve convex after the fairing."""
    chain = [(n, *ht.bone_rest(n)) for n in ht.CHAIN]
    i = ht.CHAIN.index("FJR")
    chain[i] = (chain[i][0], chain[i][1] - 25.0, chain[i][2])
    assert not ht.is_convex(chain)
    faired = ht.fair_contour(chain, ht.rest_bound())
    assert ht.is_convex(faired)
    assert faired[i][1] > chain[i][1] + 15.0


def test_the_caps_hold() -> None:
    """Ruling 1b: SECTION_BACK_N <= 2.6 and FAR_FLAT <= 0.2 (the fairing has little to do)."""
    assert max(v for _, v in ht.SECTION_BACK_N) <= ht.SECTION_BACK_CAP == 2.6
    assert max(v for _, v in ht.FAR_FLAT) <= ht.FAR_FLAT_CAP == 0.2


@pytest.mark.parametrize("sign", [1.0, -1.0])
def test_far_nose_tip_snaps_to_the_faired_far_contour(sign: float) -> None:
    """Ruling 1c: at yaw +-1 the far end of the nose (right end 410 at y 440 turning right, the
    nostril hook 392 at y 452 turning left) breaks the faired far contour by 0-4 px."""
    left, right = ht.nose_tip_travel()
    base = ht.NOSE_Z * math.sin(K)
    if sign > 0:
        past = 410.0 + base + right - ht.contour_x_at(440.0, K, 1.0)
    else:
        past = ht.contour_x_at(452.0, -K, -1.0) - (392.0 - base - left)
    assert 0.0 <= past <= 4.0


@pytest.mark.parametrize("a", [K, -K])
def test_mouth_foreshortens(a: float) -> None:
    """Ruling 1d: the mouth's width at yaw +-1 is 0.8-0.95 of rest (it was a flat 0.88)."""
    assert 0.8 <= ht.mouth_width(a) <= 0.95
    assert ht.mouth_width(0.0) == pytest.approx(1.0)


@pytest.mark.parametrize("yaw,jaw", [(1.0, 0.0), (1.0, 1.0), (-1.0, 1.0), (0.5, 1.0)])
def test_the_open_mouth_stays_inside_the_faired_outline(yaw: float, jaw: float) -> None:
    """Review Focus 3: the widest mouth (corners 28 px out at y 478, the lower lip 18 px out at y
    490, dropped by the jaw) stays >= 6 px inside the faired outline."""
    a = yaw * K
    centre = 400.0 + r.eval_poly(ht.mat(400, ht.MOUTH_Z), a)
    sx = ht.mouth_width(a)
    for y, half in ((478.0, 28.0 * sx), (490.0 + 10.0 * jaw, 18.0 * sx)):
        pts = ht.contour_chain(yaw, 0.0, jaw)
        right = sorted((yy, x) for n, x, yy in pts if n[-1] == "R")
        left = sorted((yy, x) for n, x, yy in pts if n[-1] == "L")

        def at(side: list[tuple[float, float]]) -> float:
            for (y0, x0), (y1, x1) in zip(side, side[1:]):
                if y0 <= y <= y1:
                    return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
            raise ValueError(y)
        assert centre + half <= at(right) - 6, (y, yaw, jaw)
        assert centre - half >= at(left) + 6, (y, yaw, jaw)
