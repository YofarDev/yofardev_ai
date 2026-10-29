"""M3 critic round 2 (face): glasses, surprise, fringe, happy lids, brow band, 3/4 cheek and ear.

    uv run --with pytest pytest rive/tools/tests/test_critic_round2.py
"""

from __future__ import annotations

import colorsys
import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import art_bible as ab  # noqa: E402
import avatar_kit as kit  # noqa: E402
import face_rig as fr  # noqa: E402
import head_turn as ht  # noqa: E402
import rig_dsl as r  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
IRIS_TOP, IRIS_H = 388.0 - 18.0, 36.0  # the iris: a 32 x 36 ellipse at y 388 (eye art space)
EYE_SCALE = 1.06  # each Eye node's scale
PX_1080 = 1 / kit.LINE_SCALE  # 1080-frame px per art px


def _rml() -> ET.Element:
    return ET.parse(ROOT / "rive" / "avatar" / "avatar.rml").getroot()


def _shapes(root: ET.Element, name: str) -> list[ET.Element]:
    return [e for e in root.iter("Shape") if e.get("name") == name]


def _group(root: ET.Element, name: str) -> ET.Element:
    return next(e for e in root.iter("Node") if e.get("name") == name)


# ---- 1. glasses

def test_clear_lens_ring_is_interior_weight_tapered_and_round() -> None:
    ring = kit.lens_ring()
    oy, ow, oh, ort, orb, _ = ring["outer"]
    iy, iw, ih, irt, irb, _ = ring["inner"]
    top = (iy - ih / 2) - (oy - oh / 2)  # rim widths
    bottom = (oy + oh / 2) - (iy + ih / 2)
    side = (ow - iw) / 2
    assert top * PX_1080 == pytest.approx(ab.LINES.interior)  # the rim on top: 3 px at 1080
    assert bottom < top and bottom >= ab.LINES.min_visible / PX_1080  # thinner lower rim, still visible
    assert bottom < side < top
    assert min(ort, orb) >= 0.3 * min(ow, oh)  # corner radius >= 30 % of the short side
    assert min(irt, irb) > 0


def test_generated_glasses_frames() -> None:
    root = _rml()
    clear, sun = _group(root, "G_glasses"), _group(root, "G_sunglasses")
    alpha = int(kit.FRAME_INK[:2], 16) / 255
    assert 0.8 <= alpha <= 0.9 and kit.FRAME_INK[2:] == "2A1E24"
    for t in ("L", "R"):
        lens = next(e for e in clear.iter("Shape") if e.get("name") == "Lens" + t)
        rects = lens.findall("Rectangle")
        assert len(rects) == 2 and lens.find("Stroke") is None
        fills = lens.findall("Fill")
        assert len(fills) == 1 and fills[0].get("fillRule") == "evenOdd"  # the ring only: no lens tint
        assert fills[0].find("SolidColor").get("colorValue") == kit.FRAME_INK
        dark = next(e for e in sun.iter("Shape") if e.get("name") == "Lens" + t)
        stroke = dark.find("Stroke")
        assert float(stroke.get("thickness")) * PX_1080 == pytest.approx(ab.LINES.interior, abs=0.01)
        radii = [float(v.get("radius")) for v in dark.iter("StraightVertex")]
        assert min(radii) >= 0.3 * (kit.LENS_H - 6)
    for grp in (clear, sun):
        for nm in ("Glare", "Glare2"):
            glints = [e for e in grp.iter("Shape") if e.get("name") == nm]
            assert len(glints) == 1
            assert glints[0].find("Fill/SolidColor").get("colorValue")[2:] == kit.PAPER  # paper white
        st = next(e for e in grp.iter("Shape") if e.get("name") == "Bridge").find("Stroke")
        assert float(st.get("thickness")) <= kit.FRAME_W + 1e-3
    temples = [e for e in root.iter("Shape") if e.get("name") in ("TempleL", "TempleR")]  # the head turn moves them
    assert len(temples) == 4
    assert all(float(e.find("Stroke").get("thickness")) <= 1.2 * kit.FRAME_W + 1e-3 for e in temples)


def test_the_glint_is_one_diagonal_streak_inside_the_lens() -> None:
    for cx in (355.0, 445.0):
        pts = kit.lens_glint(cx)
        top, bot = pts[:2], pts[2:]
        assert all(p[1] < q[1] for p in top for q in bot)
        assert sum(p[0] for p in top) / 2 > sum(p[0] for p in bot) / 2 + 8  # leans: a diagonal
        assert all(abs(x - cx) < kit.LENS_W / 2 - 4 and abs(y - kit.LENS_CY) < kit.LENS_H / 2 - 2 for x, y in pts)


# ---- 2. surprise: AU5 shows sclera above the iris, the brows travel further and arch

def test_upper_lid_raise_clears_the_iris() -> None:
    p = fr.lid_pose({"auUpperLidRaise": 1.0}, 1)
    gap = IRIS_TOP - (p["UpperMid"][1] + fr.SEAM)  # eye-local px of white above the iris
    assert gap * EYE_SCALE * PX_1080 >= 3.0


M3_RAISE = {"Inner": 22.0, "Mid": 17.0, "Outer": 13.0}  # brow rise at IU = OU = 1 before round 2


@pytest.mark.parametrize("s", (-1, 1))
def test_brow_raise_travels_further_and_arches(s: int) -> None:
    rest = fr.brow_pose({}, s)
    up = fr.brow_pose({"auBrowInnerUp": 1.0, "auBrowOuterUp": 1.0}, s)
    for nm, old in M3_RAISE.items():
        assert rest[nm][1] - up[nm][1] >= 1.45 * old, nm
    for env in ({"auBrowInnerUp": 1.0, "auBrowOuterUp": 1.0}, {"auBrowOuterUp": 1.0}):
        p = fr.brow_pose(env, s)
        (xi, yi), (xm, ym), (xo, yo) = p["Inner"], p["Mid"], p["Outer"]
        chord = yi + (yo - yi) * (xm - xi) / (xo - xi)
        assert ym < chord - 3.0, env  # the middle stands above the line between the ends (y down)


# ---- 3. fringe: three tiers, soft points, clumps, an off-centre parting

def test_fringe_has_three_length_tiers() -> None:
    tips = {tier: [kit.FRINGE_LOCKS[i][1][1] for i in idx] for tier, idx in kit.LOCK_TIERS.items()}
    assert sorted(i for idx in kit.LOCK_TIERS.values() for i in idx) == list(range(len(kit.FRINGE_LOCKS)))
    assert max(tips["short"]) + 25 < min(tips["medium"])
    assert max(tips["medium"]) + 25 < min(tips["long"])
    # the short locks end well above the rest brows (y ~335), so a raised brow still reads
    assert max(tips["short"]) <= 315


def test_fringe_tips_are_soft_points() -> None:
    for root_, tip, w, bend in kit.FRINGE_LOCKS:
        pts, _ = kit.lock_outline(root_, tip, w, bend)
        assert len(pts) == 7
        corners = [p for p in pts if len(p) == 3]
        assert len(corners) == 1 and corners[0] is pts[3]
        radius = float(str(pts[3][2])[1:])
        shoulder_w = math.dist(pts[2], pts[4])
        assert 0 < radius <= 0.25 * shoulder_w  # a soft point, not a ball
        assert shoulder_w <= 0.4 * w  # the lock tapers toward the tip


def test_fringe_clumps_and_parting() -> None:
    locks = kit.FRINGE_LOCKS
    assert sorted(i for c in kit.LOCK_CLUMPS for i in c) == list(range(len(locks)))
    assert all(2 <= len(c) <= 4 for c in kit.LOCK_CLUMPS)
    for c in kit.LOCK_CLUMPS:  # a clump's locks hang together: neighbouring tips stay close
        xs = sorted(locks[i][1][0] for i in c)
        assert all(b - a <= 40 for a, b in zip(xs, xs[1:]))
    # the parting sits off centre, and no lock root straddles it
    assert abs(kit.PARTING_X - 400) > 10
    assert all(abs(root_[0] - kit.PARTING_X) > 12 for root_, *_ in locks)
    left = [i for i, (root_, *_) in enumerate(locks) if root_[0] < kit.PARTING_X]
    assert len(left) != len(locks) - len(left)  # asymmetric


# ---- 4. happy: the lower lid pushes up, the upper lid stays

@pytest.mark.parametrize("lt", (0.1, 0.5))
@pytest.mark.parametrize("s", (-1, 1))
def test_happy_never_drops_the_upper_lid_across_the_iris(lt: float, s: int) -> None:
    happy = {"auCheekRaise": 0.6, "auLidTighten": lt, "auLipCornerPull": 0.7, "auBrowOuterUp": 0.3}
    rest, p = fr.lid_pose({}, s), fr.lid_pose(happy, s)
    for col in fr.LID_COLS:
        assert p["Upper" + col][1] - rest["Upper" + col][1] <= 0.15 * IRIS_H, col
    assert rest["LowerMid"][1] - p["LowerMid"][1] > 6.0  # the crescent
    # cheek raise alone never lowers the middle of the upper lid
    cr = fr.lid_pose({"auCheekRaise": 1.0}, s)
    assert cr["UpperMid"][1] <= rest["UpperMid"][1]


# ---- 5. the brow band: the fringe shadow feathers out above the brows

def test_forehead_cast_fades_out_above_the_brows() -> None:
    a, y0, y1 = kit.FACE_CAST_FADE
    assert int(a, 16) <= 0x80 and y1 <= 335.0 and y0 < y1
    assert len(kit.FACE_CAST_PTS) == 15  # the head turn skins the same 15 points as M2
    cast = _shapes(_rml(), "FaceCast")[0]
    stops = cast.findall("Fill/LinearGradient/GradientStop")
    assert [s.get("colorValue")[:2] for s in stops] == [a, "00"]
    assert cast.find("Fill/SolidColor") is None


# ---- 6. 3/4: a warm far-cheek shade, the near ear seated under the side lock

def test_far_cheek_shade_is_warm_skin_shadow() -> None:
    c = ht.FAR_SHADE[0]
    rgb = [int(c[i:i + 2], 16) / 255 for i in (2, 4, 6)]
    h, _, _ = colorsys.rgb_to_hsv(*rgb)
    assert h * 360 < 30 or h * 360 > 350  # terracotta, not lavender (the old one sat at ~250 deg)


def test_near_ear_tucks_under_the_side_lock() -> None:
    a = -ht.K_YAW  # yaw -1: the right ear is the near one
    pivot = 512.0 + r.eval_poly(ht.mat(512.0, ht.EAR_Z), a)
    front = pivot + (496.0 - 512.0) * ht.EAR_NEAR_WIDEN  # the ear's front edge (mirror of EAR x 304)
    lock_right = 510.0 + (500.0 - 512.0)  # SideLockR's outer edge, shifted by its yaw -1 pose
    contour = ht.contour_pose(506.0, 396.0)[0]
    assert front < lock_right  # the front of the ear sits under the side lock
    assert front < contour  # and behind the cheek contour: no gap between face and ear
    assert pivot + (528.0 - 512.0) * ht.EAR_NEAR_WIDEN > lock_right + 10  # most of the ear still shows
