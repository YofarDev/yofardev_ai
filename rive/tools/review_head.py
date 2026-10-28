# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Evidence for the 2.5D head v2 (rive/head) -> rive/head/review/.

    uv run rive/tools/review_head.py            # everything (~2 min)
    uv run rive/tools/review_head.py grid zoom  # only some parts: grid, zoom, turn, metrics

grid.png     5x5 yaw x pitch (rows pitch +1 .. -1, columns yaw -1 .. +1)
zoom.png     close-ups: far contour, near jaw, nose, eyes, blink, under-jaw, crown
turn.gif     the PerformedTurn artboard, every 2nd frame at 30 fps
turn_sheet.png  24 evenly spaced PerformedTurn frames
metrics.txt  motion metrics of the performed turn, file size, history-free check, lint
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import statistics
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = ROOT / "rive" / "head"
OUT = PROJ / "review"
TMP = PROJ / "build" / "review"
sys.path.insert(0, str(HERE))

import gen_head  # noqa: E402
from motion_metrics import frame_diffs, jerk, loop_seam, motion_centroids, pops  # noqa: E402

WORKERS = 6


def cli(png: Path, *args: str) -> Path:
    png.parent.mkdir(parents=True, exist_ok=True)
    res = subprocess.run(["rive", str(PROJ), f"--screenshot={png}", *args], cwd=PROJ, capture_output=True, text=True)
    log = res.stdout + res.stderr
    if res.returncode != 0 or " error " in log.lower():
        raise SystemExit(f"rive failed for {args}: {log}")
    return png


def pose_args(yaw: float = 0.0, pitch: float = 0.0, advance: int = 1, **extra: float) -> list[str]:
    out = [f"--data=yaw={yaw:g}", f"--data=pitch={pitch:g}"]
    out += [f"--data={k}={v:g}" for k, v in extra.items()]
    return out + [f"--advance={advance}"]


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((6, 4), text, fill=(255, 230, 120))
    return im


def grid() -> None:
    yaws = [-1.0, -0.5, 0.0, 0.5, 1.0]
    pitches = [1.0, 0.5, 0.0, -0.5, -1.0]
    jobs = [(y, p) for p in pitches for y in yaws]
    with ThreadPoolExecutor(WORKERS) as ex:
        pngs = list(ex.map(lambda j: cli(TMP / "grid" / f"y{j[0]:+.1f}_p{j[1]:+.1f}.png", *pose_args(*j)), jobs))
    cw, ch = 240, 288
    sheet = Image.new("RGB", (cw * 5, ch * 5), (20, 18, 26))
    for k, ((y, p), png) in enumerate(zip(jobs, pngs)):
        im = Image.open(png).convert("RGB").resize((cw, ch), Image.Resampling.LANCZOS)
        sheet.paste(label(im, f"yaw {y:+.1f}  pitch {p:+.1f}"), ((k % 5) * cw, (k // 5) * ch))
    sheet.save(OUT / "grid.png", optimize=True)


ZOOMS: list[tuple[str, dict[str, float], tuple[int, int, int, int]]] = [
    ("far contour + nose, yaw +1", {"yaw": 1.0}, (230, 150, 360, 340)),
    ("near jaw angle, yaw +1", {"yaw": 1.0}, (90, 200, 250, 380)),
    ("front, yaw 0", {}, (110, 110, 290, 330)),
    ("yaw +0.5 (mouth, far eye)", {"yaw": 0.5}, (150, 150, 330, 340)),
    ("blink 0.5", {"blink": 0.5}, (120, 150, 280, 230)),
    ("blink 1", {"blink": 1.0}, (120, 150, 280, 230)),
    ("under-jaw, pitch +1", {"pitch": 1.0}, (120, 250, 280, 380)),
    ("crown, yaw -1", {"yaw": -1.0}, (60, 0, 340, 180)),
    ("crown, yaw +1", {"yaw": 1.0}, (60, 0, 340, 180)),
]


def zoom() -> None:
    cells: list[Image.Image] = []
    for k, (name, data, box) in enumerate(ZOOMS):
        png = cli(TMP / "zoom" / f"z{k}.png", *pose_args(**data))
        im = Image.open(png).convert("RGB").crop(box)
        scale = 300 / max(im.width, im.height)
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)
        cell = Image.new("RGB", (300, 300), (20, 18, 26))
        cell.paste(im, ((300 - im.width) // 2, (300 - im.height) // 2))
        cells.append(label(cell, name))
    sheet = Image.new("RGB", (900, 300 * ((len(cells) + 2) // 3)), (20, 18, 26))
    for k, c in enumerate(cells):
        sheet.paste(c, ((k % 3) * 300, (k // 3) * 300))
    sheet.save(OUT / "zoom.png", optimize=True)


def identity() -> None:
    """The shipped avatar (rive/avatar at rest) next to the head at rest, same art-space window."""
    av = TMP / "identity" / "avatar.png"
    av.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(ROOT / "rive" / "avatar"), f"--screenshot={av}", "--advance=1"], check=True,
                   capture_output=True)
    box = (int(gen_head.OX), int(gen_head.OY), int(gen_head.OX + gen_head.ART_W), int(gen_head.OY + gen_head.ART_H))
    left = Image.open(av).convert("RGB").crop(box)
    right = Image.open(cli(TMP / "identity" / "head.png", *pose_args())).convert("RGB")
    sheet = Image.new("RGB", (800, 480), (20, 18, 26))
    sheet.paste(label(left, "shipped avatar (rive/avatar, rest)"), (0, 0))
    sheet.paste(label(right, "head v2 (rive/head, yaw 0 pitch 0)"), (400, 0))
    sheet.save(OUT / "identity.png", optimize=True)


CORNER_POSES = [(-1.0, 1.0), (1.0, 1.0), (-1.0, 0.5), (1.0, 0.5)]


def corners() -> None:
    """Hair corners at |yaw| = 1, pitch >= 0.5 (round-3 spikes), both sides, 2.5x."""
    cells: list[Image.Image] = []
    for yaw, pitch in CORNER_POSES:
        im = Image.open(cli(TMP / "corners" / f"y{yaw:+.0f}p{pitch:+.1f}.png", *pose_args(yaw, pitch))).convert("RGB")
        for side, box in (("L", (30, 180, 150, 330)), ("R", (250, 180, 370, 330))):
            c = im.crop(box).resize((300, 375), Image.Resampling.LANCZOS)
            cells.append(label(c, f"yaw {yaw:+.0f} pitch {pitch:+.1f} {side}"))
    sheet = Image.new("RGB", (300 * 4, 375 * 2), (20, 18, 26))
    for k, c in enumerate(cells):
        sheet.paste(c, ((k % 4) * 300, (k // 4) * 375))
    sheet.save(OUT / "corners.png", optimize=True)


def turn_frames() -> list[Path]:
    n = len(gen_head.r.perform_turn(gen_head.TURN_TARGETS, gen_head.TURN_SECONDS)["yaw"])
    jobs = list(range(n))
    with ThreadPoolExecutor(WORKERS) as ex:
        return list(ex.map(lambda i: cli(TMP / "turn" / f"f{i:03}.png", "--artboard=PerformedTurn",
                                         f"--advance={i + 1}"), jobs))


def turn(paths: list[Path]) -> None:
    frames = [Image.open(p).convert("RGB") for p in paths]
    small = [f.resize((220, 264), Image.Resampling.LANCZOS) for f in frames[::2]]
    # one shared palette (from 8 spread frames): no palette flicker, and the GIF stays < 1.5 MB
    strip = Image.new("RGB", (220 * 8, 264))
    for k in range(8):
        strip.paste(small[k * len(small) // 8], (k * 220, 0))
    palette = strip.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    pal = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in small]
    pal[0].save(OUT / "turn.gif", save_all=True, append_images=pal[1:], duration=33, loop=0, optimize=True)
    picks = [round(i * (len(frames) - 1) / 23) for i in range(24)]
    cw, ch = 200, 240
    sheet = Image.new("RGB", (cw * 6, ch * 4), (20, 18, 26))
    for k, i in enumerate(picks):
        im = frames[i].resize((cw, ch), Image.Resampling.LANCZOS)
        sheet.paste(label(im, f"f{i}"), ((k % 6) * cw, (k // 6) * ch))
    sheet.save(OUT / "turn_sheet.png", optimize=True)


PROBE = PROJ / "build" / "hairprobe"
GHOST_PX = 0  # any translucent area fails (the round-1 cross-fade gave 110-135 px at yaw +-0.40)


def _mixed_hair_pixels(png: Path) -> int:
    """Hair over a flat green face on magenta: count pixels that mix hair with green or magenta
    (alpha 0.1-0.9) more than 2 px from mostly-green/magenta pixels. Antialiased edges and 1-2 px
    gaps are excluded; a translucent hair layer over the face (a ghost) is an area and counts."""
    im = Image.open(png).convert("RGB")
    r, g, b = im.split()
    magenta = ImageChops.darker(ImageChops.subtract(r, g), ImageChops.subtract(b, g))
    green = ImageChops.subtract(g, ImageChops.lighter(r, b))
    share = ImageChops.lighter(magenta, green)
    seed = share.point(lambda v: 255 if v > 150 else 0).filter(ImageFilter.MaxFilter(5))
    mixed = share.point(lambda v: 255 if 0.1 * 255 < v < 0.9 * 255 else 0)
    # a ghost is an area: erode away 1-2 px lines (slivers along contours) before counting
    area = ImageChops.subtract(mixed, seed).filter(ImageFilter.MinFilter(3))
    return sum(1 for v in area.tobytes() if v)


def translucency_sweep() -> list[str]:
    _build_probe()
    yaws = [round(-1 + 0.05 * k, 2) for k in range(41)]
    with ThreadPoolExecutor(WORKERS) as ex:
        counts = list(ex.map(lambda y: _mixed_hair_pixels(_probe(TMP / "sweep" / f"y{y:+.2f}.png", y)), yaws))
    bad = [(y, c) for y, c in zip(yaws, counts) if c > GHOST_PX]
    return [f"hair over a flat face, yaw -1..1 step 0.05 (41 poses), pixels with alpha 0.1-0.9 away from edges: "
            f"max {max(counts)} (fail above {GHOST_PX}) -> {'PASS' if not bad else 'FAIL ' + str(bad)}"]


def _probe(png: Path, yaw: float) -> Path:
    png.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(PROBE), f"--screenshot={png}", f"--data=yaw={yaw:g}", "--advance=1"], cwd=PROBE,
                   check=True, capture_output=True)
    return png


def _lum(c: tuple[float, float, float]) -> float:
    def ch(v: float) -> float:
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def _not_magenta(c: tuple[int, int, int]) -> bool:
    return min(c[0] - c[1], c[2] - c[1]) < 128


def _build_probe() -> None:
    subprocess.run(["uv", "run", str(HERE / "gen_head.py"), "--variant", "hair", "--out", str(PROBE)], check=True,
                   capture_output=True)


POSTER = ROOT / "assets" / "rive" / "posters" / "livingRoom.webp"
# the poster window behind the head: the wall band above the floor at the centre of the
# 540x960 poster (window, curtains, lamp glow and wall), scaled to the 400x480 head artboard
POSTER_BOX = (130, 330, 410, 666)


def silhouette_contrast() -> list[str]:
    """Hair-to-background luminance contrast against the livingRoom poster: per row of the side
    masses (art y 290-470), the better of the two edge tones (the ink outline 0-1 px inside the
    silhouette, the edge light 3-6 px inside) vs the poster just outside it (4-10 px). Rows where
    the ear (skin) is the outer edge are skipped. Reports the median row and the share of rows
    >= 3:1, per side."""
    _build_probe()
    poster = Image.open(POSTER).convert("RGB").crop(POSTER_BOX).resize((400, 480), Image.Resampling.LANCZOS)
    out = []
    for yaw in (0.0, 1.0, -1.0):
        full = Image.open(cli(TMP / "contrast" / f"f{yaw:+.0f}.png", *pose_args(yaw))).convert("RGB")
        hair = Image.open(_probe(TMP / "contrast" / f"h{yaw:+.0f}.png", yaw)).convert("RGB")
        res = []
        for side in (-1, 1):
            ratios: list[float] = []
            for y in range(290 - 172, 470 - 172, 2):
                xs = [x for x in range(hair.width) if _not_magenta(hair.getpixel((x, y)))]
                if not xs:
                    continue
                edge = min(xs) if side < 0 else max(xs)
                if full.getpixel((edge - side, y))[0] > 150:  # the ear, not hair, is the edge here
                    continue
                bgs = [poster.getpixel((min(399, max(0, edge + side * k)), y)) for k in range(4, 11)]
                lg = sum(_lum(c) for c in bgs) / len(bgs)
                best = 1.0
                for ks in ((0, 1), (3, 4, 5, 6)):  # the dark outline, then the edge light inside it
                    lb = sum(_lum(full.getpixel((edge - side * k, y))) for k in ks) / len(ks)
                    best = max(best, (max(lb, lg) + 0.05) / (min(lb, lg) + 0.05))
                ratios.append(best)
            ratios.sort()
            res.append((ratios[len(ratios) // 2], sum(1 for q in ratios if q >= 3.0) / len(ratios)))
        out.append(f"yaw {yaw:+.0f}: left median {res[0][0]:.2f}:1 ({res[0][1]:.0%} of rows >= 3:1), "
                   f"right median {res[1][0]:.2f}:1 ({res[1][1]:.0%} of rows >= 3:1)")
    return out


STATIC_PX = 20  # a frame is "static" when fewer than this many pixels change by > 8/255


def seam_stats(frames: list[Image.Image]) -> list[str]:
    """Visible per-frame change (pixels changed by > 8/255) across the loop seam, and the longest
    static stretch anywhere in the loop (wrapping)."""
    lum = [f.convert("L") for f in frames]
    changed = [sum(1 for v in ImageChops.difference(a, b).tobytes() if v > 8) for a, b in zip(lum, lum[1:])]
    n = len(changed)
    run = best = 0
    for c in changed + changed:
        run = run + 1 if c < STATIC_PX else 0
        best = max(best, run)
    tail, head = changed[n - 48:], changed[:48]
    return [f"seam: px changed (> 8/255) per frame, last 48 transitions: {tail}",
            f"seam: px changed (> 8/255) per frame, first 48 transitions: {head}",
            f"longest static stretch (< {STATIC_PX} px changed), wrapping: {best} frames = {best / 60:.2f} s"]


def brow_travel() -> list[str]:
    """Measured brow lift at brow = 1: centroid of pixels that darkened (brow arrived) minus
    centroid of pixels that lightened (brow left), in the right brow's column band."""
    ims = [Image.open(cli(TMP / "brow" / f"{n}.png", *pose_args(**e))).convert("L")
           for n, e in (("rest", {}), ("brow1", {"brow": 1.0}))]
    x0, x1 = int(445 - 30 - gen_head.OX), int(445 + 36 - gen_head.OX)
    y0, y1 = int(300 - gen_head.OY), int(352 - gen_head.OY)
    came: list[int] = []
    left: list[int] = []
    for x in range(x0, x1):
        for y in range(y0, y1):
            dv = ims[1].getpixel((x, y)) - ims[0].getpixel((x, y))
            if dv < -40:
                came.append(y)
            elif dv > 40:
                left.append(y)
    lift = sum(left) / max(1, len(left)) - sum(came) / max(1, len(came))
    return [f"brow lift at brow=1 (right brow, appeared-vs-vanished centroid): {lift:.1f} artboard px (rig: 14 inner, "
            f"12 outer); the avatar artboard is 800 px wide, so on a 390 dp phone showing it full width that is "
            f"{lift * 390 / 800:.1f} dp ({lift * 390 / 800 * 3:.0f} device px at 3x)"]


def metrics(paths: list[Path]) -> None:
    frames = [Image.open(p).convert("RGB") for p in paths]
    rest = frames[0]
    diffs = frame_diffs(frames)
    moving_idx = [i for i, x in enumerate(diffs) if x > 0.001]
    moving_pops = [moving_idx[j] for j in pops([diffs[i] for i in moving_idx])]
    local_pops = [i for i in range(len(diffs))
                  if diffs[i] > 0.01 and diffs[i] > 4 * statistics.median(diffs[max(0, i - 4):i + 5])]
    spikes = [i for i in range(1, len(diffs) - 1)
              if diffs[i] > 0.004 and diffs[i] > 2 * diffs[i - 1] and diffs[i] > 2 * diffs[i + 1]]
    pts = motion_centroids(frames, rest)
    ch = gen_head.r.perform_turn(gen_head.TURN_TARGETS, gen_head.TURN_SECONDS)
    bl = ch["blink"]
    blinks = [round(i / 60, 2) for i in range(1, len(bl)) if bl[i] > 0 and bl[i - 1] == 0]
    blink_gaps = [round(b - a, 2) for a, b in zip(blinks, blinks[1:])] + \
        [round(gen_head.TURN_SECONDS - blinks[-1] + blinks[0], 2)]
    lines = [
        "2.5D head v2 - rive/head (generated by rive/tools/gen_head.py)",
        f"rive: {subprocess.run(['rive', '--version'], capture_output=True, text=True).stdout.strip()}",
        "",
        "== Size",
        f"head.riv: {(PROJ / 'build' / 'head.riv').stat().st_size} B (gate <= 92160 B = 90 KB)",
        "",
        "== Performed turn (PerformedTurn artboard, every frame, one CLI run per frame)",
        f"frames: {len(frames)} at 60 fps ({gen_head.TURN_SECONDS} s loop), yawTarget steps {gen_head.TURN_TARGETS}",
        f"pops, whole clip (motion_metrics.pops, k=4 x median, floor 0.01): {len(pops(diffs))} {pops(diffs)}",
        "  (a whole-clip median is dominated by holds; the windowed checks below are the robust ones)",
        f"pops, moving frames only (diff > 0.001, n={len(moving_idx)}): {len(moving_pops)} at frames {moving_pops}",
        f"pops, 9-frame window (diff > 4 x local median and > 0.01): {len(local_pops)} {local_pops}",
        f"local spikes (a diff > 2 x both neighbours and > 0.004): {len(spikes)} {spikes}",
        f"frame diff min / median / max: {min(diffs):.5f} / {statistics.median(diffs):.5f} / {max(diffs):.5f}",
        f"jerk (moving-pixel centroid vs frame 0): {jerk(pts):,.0f} px/s^3",
        f"loop seam (last vs first / median diff): {loop_seam(frames):.3f}",
        f"frozen frames (diff exactly 0, seam included): {sum(1 for x in diffs if x == 0)}",
        f"look spacing (s): {[round(b[0] - a[0], 2) for a, b in zip(gen_head.TURN_TARGETS[1:], gen_head.TURN_TARGETS[2:])]}"
        f" + {round(gen_head.TURN_SECONDS - gen_head.TURN_TARGETS[-1][0] + gen_head.TURN_TARGETS[1][0], 2)} across the seam",
        f"blink starts (s): {blinks}; intervals incl. the seam: {blink_gaps}",
        "channel ranges: " + ", ".join(f"{k} {min(v):+.2f}..{max(v):+.2f}" for k, v in ch.items()),
        "",
        "== History-free (static Head: --advance=1 vs --advance=40, rive --compare)",
    ]
    for k, pose in enumerate(({"yaw": 0.37, "pitch": -0.42}, {"yaw": -0.9, "pitch": 0.8}, {"yaw": 1.0, "pitch": 0.0,
                                                                                            "blink": 0.6})):
        a = cli(TMP / "hist" / f"a{k}.png", *pose_args(**pose))
        b = TMP / "hist" / f"b{k}.png"
        res = subprocess.run(["rive", str(PROJ), f"--screenshot={b}", f"--compare={a}",
                              *pose_args(**pose, advance=40)[:-1], "--advance=40"],
                             cwd=PROJ, capture_output=True, text=True)
        out = (res.stdout + res.stderr).splitlines()
        cmp = next((ln.split(": ", 1)[-1].strip() for ln in out if ln.startswith("compare ")), "?")
        lines.append(f"{pose}: {cmp}")
    lint = subprocess.run(["uv", "run", str(HERE / "art_bible.py"), "lint", str(PROJ / "head.rml"),
                           "--scene", "livingRoom"], capture_output=True, text=True).stdout.strip()
    lines += ["", "== Idle across the loop seam", *seam_stats(frames)]
    lines += ["", "== Brow travel", *brow_travel()]
    lines += ["", "== Art-bible lint (livingRoom)", lint or "?"]
    lines += ["", "== Hair translucency (regression for the side-lock cross-fade ghost)", *translucency_sweep()]
    lines += ["", f"== Silhouette contrast vs the livingRoom poster (window {POSTER_BOX}; bible >= 3:1)",
              *silhouette_contrast()]
    (OUT / "metrics.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def main(argv: list[str]) -> None:
    parts = set(argv) or {"grid", "zoom", "identity", "corners", "turn", "metrics"}
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(PROJ), "--once"], cwd=PROJ, check=True, capture_output=True)
    if "grid" in parts:
        grid()
    if "zoom" in parts:
        zoom()
    if "identity" in parts:
        identity()
    if "corners" in parts:
        corners()
    if parts & {"turn", "metrics"}:
        paths = turn_frames()
        if "turn" in parts:
            turn(paths)
        if "metrics" in parts:
            metrics(paths)
    for f in sorted(OUT.iterdir()):
        print(f"{f.relative_to(ROOT)}: {f.stat().st_size} B")


if __name__ == "__main__":
    main(sys.argv[1:])
