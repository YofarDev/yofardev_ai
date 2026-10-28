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

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = ROOT / "rive" / "head"
OUT = PROJ / "review"
TMP = PROJ / "build" / "review"
sys.path.insert(0, str(HERE))

import art_bible  # noqa: E402
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


def turn_frames() -> list[Path]:
    n = len(gen_head.r.perform_turn(gen_head.TURN_TARGETS, gen_head.TURN_SECONDS)["yaw"])
    jobs = list(range(n))
    with ThreadPoolExecutor(WORKERS) as ex:
        return list(ex.map(lambda i: cli(TMP / "turn" / f"f{i:03}.png", "--artboard=PerformedTurn",
                                         f"--advance={i + 1}"), jobs))


def turn(paths: list[Path]) -> None:
    frames = [Image.open(p).convert("RGB") for p in paths]
    small = [f.resize((250, 300), Image.Resampling.LANCZOS) for f in frames[::2]]
    pal = [f.quantize(colors=80, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in small]
    pal[0].save(OUT / "turn.gif", save_all=True, append_images=pal[1:], duration=33, loop=0, optimize=True)
    picks = [round(i * (len(frames) - 1) / 23) for i in range(24)]
    cw, ch = 200, 240
    sheet = Image.new("RGB", (cw * 6, ch * 4), (20, 18, 26))
    for k, i in enumerate(picks):
        im = frames[i].resize((cw, ch), Image.Resampling.LANCZOS)
        sheet.paste(label(im, f"f{i}"), ((k % 6) * cw, (k // 6) * ch))
    sheet.save(OUT / "turn_sheet.png", optimize=True)


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
    lines = [
        "2.5D head v2 - rive/head (generated by rive/tools/gen_head.py)",
        f"rive: {subprocess.run(['rive', '--version'], capture_output=True, text=True).stdout.strip()}",
        "",
        "== Size",
        f"head.riv: {(PROJ / 'build' / 'head.riv').stat().st_size} B (gate <= 81920 B)",
        "",
        "== Performed turn (PerformedTurn artboard, every frame, one CLI run per frame)",
        f"frames: {len(frames)} at 60 fps ({gen_head.TURN_SECONDS} s loop), yawTarget steps {gen_head.TURN_TARGETS}",
        f"pops, whole clip (motion_metrics.pops, k=4 x median, floor 0.01): {len(pops(diffs))} {pops(diffs)}",
        "  note: the loop is mostly holds, so the whole-clip median is ~0 and every frame of a turn",
        "  or blink clears 4 x median; the two lines below are the meaningful checks.",
        f"pops, moving frames only (diff > 0.001, n={len(moving_idx)}): {len(moving_pops)} at frames {moving_pops}",
        f"pops, 9-frame window (diff > 4 x local median and > 0.01): {len(local_pops)} {local_pops}",
        f"local spikes (a diff > 2 x both neighbours and > 0.004): {len(spikes)} {spikes}",
        f"frame diff min / median / max: {min(diffs):.5f} / {statistics.median(diffs):.5f} / {max(diffs):.5f}",
        f"jerk (moving-pixel centroid vs frame 0): {jerk(pts):,.0f} px/s^3",
        f"loop seam (last vs first / median diff): {loop_seam(frames):.3f}",
        f"channel ranges: " + ", ".join(f"{k} {min(v):+.2f}..{max(v):+.2f}" for k, v in ch.items()),
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
    lines += ["", "== Art-bible lint (livingRoom)", lint or "?"]
    (OUT / "metrics.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def main(argv: list[str]) -> None:
    parts = set(argv) or {"grid", "zoom", "turn", "metrics"}
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(PROJ), "--once"], cwd=PROJ, check=True, capture_output=True)
    if "grid" in parts:
        grid()
    if "zoom" in parts:
        zoom()
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
