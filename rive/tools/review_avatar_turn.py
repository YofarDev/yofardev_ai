# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Evidence for the avatar's head yaw / pitch rig -> rive/avatar/review/head_rig/.

    uv run rive/tools/review_avatar_turn.py            # everything (~3 min)
    uv run rive/tools/review_avatar_turn.py grid turn  # some parts: grid moods corners zoom identity turn metrics

The "before" renders in review/head_rig/before/ were captured from the avatar before the rig was
added (rest, happy, thinking, mouth=3, nod mid-frame); metrics compares the same captures now.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = ROOT / "rive" / "avatar"
OUT = PROJ / "review" / "head_rig"
BEFORE = OUT / "before"
TMP = PROJ / "build" / "head_rig"
sys.path.insert(0, str(HERE))

import rig_dsl as r  # noqa: E402

WORKERS = 6
HEAD_BOX = (200, 150, 600, 630)  # avatar artboard window around the head and shoulders
# the before captures: (name, extra --data, advance)
CAPTURES: list[tuple[str, dict[str, str], int]] = [
    ("rest", {}, 1), ("happy", {"mood": "happy"}, 40), ("thinking", {"mood": "thinking"}, 40),
    ("mouth3", {"mouth": "3"}, 12), ("nod", {"gestureId": "nod", "gesture": "1"}, 30)]


def cli(png: Path, data: dict[str, str], advance: int = 1, *extra: str) -> Path:
    png.parent.mkdir(parents=True, exist_ok=True)
    args = ["rive", str(PROJ), f"--screenshot={png}", *[f"--data={k}={v}" for k, v in data.items()], *extra,
            f"--advance={advance}"]
    res = subprocess.run(args, cwd=PROJ, capture_output=True, text=True)
    if res.returncode != 0:
        raise SystemExit(res.stdout + res.stderr)
    return png


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((6, 4), text, fill=(255, 230, 120))
    return im


def sheet(cells: list[Image.Image], cols: int, name: str) -> None:
    w, h = cells[0].size
    out = Image.new("RGB", (w * cols, h * ((len(cells) + cols - 1) // cols)), (20, 18, 26))
    for k, c in enumerate(cells):
        out.paste(c, ((k % cols) * w, (k // cols) * h))
    out.save(OUT / name, optimize=True)


def render_cells(jobs: list[tuple[str, dict[str, str], int]], box: tuple[int, int, int, int],
                 size: tuple[int, int], sub: str) -> list[Image.Image]:
    def one(j: tuple[str, dict[str, str], int]) -> Image.Image:
        tag, data, adv = j
        png = cli(TMP / sub / (tag.replace(" ", "_").replace("/", "_") + ".png"), data, adv)
        im = Image.open(png).convert("RGB").crop(box).resize(size, Image.Resampling.LANCZOS)
        return label(im, tag)
    with ThreadPoolExecutor(WORKERS) as ex:
        return list(ex.map(one, jobs))


def grid() -> None:
    jobs = [(f"yaw {y:+.1f} pitch {p:+.0f}", {"yaw": f"{y:g}", "pitch": f"{p:g}"}, 1)
            for p in (1.0, 0.0, -1.0) for y in (-1.0, -0.5, 0.0, 0.5, 1.0)]
    sheet(render_cells(jobs, HEAD_BOX, (240, 288), "grid"), 5, "grid.png")


def moods() -> None:
    jobs = [(f"{m} yaw {y:+.1f}", {"mood": m, "yaw": f"{y:g}"}, 40)
            for m in ("happy", "thinking", "surprised") for y in (-0.6, 0.6)]
    sheet(render_cells(jobs, HEAD_BOX, (240, 288), "moods"), 6, "moods.png")


def corners() -> None:
    jobs = []
    for y in (-1.0, 1.0):
        for p in (-1.0, -0.5, 0.5, 1.0):
            jobs.append((f"yaw {y:+.0f} pitch {p:+.1f}", {"yaw": f"{y:g}", "pitch": f"{p:g}"}, 1))
    cells: list[Image.Image] = []
    for side_box in ((210, 260, 390, 520), (410, 260, 590, 520)):
        cells += render_cells(jobs, side_box, (180, 340), "corners")
    sheet(cells, 8, "corners.png")


def zoom() -> None:
    jobs = [(f"yaw {y:+.0f} pitch {p:+.0f}", {"yaw": f"{y:g}", "pitch": f"{p:g}"}, 1)
            for y in (-1.0, 1.0) for p in (0.0, 1.0, -1.0)]
    sheet(render_cells(jobs, (250, 280, 550, 590), (420, 434), "zoom"), 3, "zoom.png")


def identity() -> None:
    after = cli(TMP / "identity" / "rest.png", {}, 1)
    left = Image.open(BEFORE / "rest.png").convert("RGB").crop(HEAD_BOX)
    right = Image.open(after).convert("RGB").crop(HEAD_BOX)
    out = Image.new("RGB", (800, 480), (20, 18, 26))
    out.paste(label(left, "before the rig (shipped avatar, rest)"), (0, 0))
    out.paste(label(right, "after the rig (yaw 0 pitch 0, rest)"), (400, 0))
    out.save(OUT / "identity.png", optimize=True)


# a performed turn on the real avatar: the yaw / pitch channels of rig_dsl.perform_turn, one CLI
# run per frame (the rig is history-free; the state machine advances with the frame, so idle
# blinks and the nod fired at frame 0 play while the head turns)
# the big turn starts at 2.75 s so the avatar's own idle blink (frames 168-181) lands in it
TURN_TARGETS = [(0.0, 0.0), (0.5, 0.8), (2.75, -0.75), (4.0, 0.0)]
TURN_SECONDS = 5.0
STEP = 2  # every 2nd 60 fps frame -> a 30 fps GIF


def turn() -> list[Path]:
    ch = r.perform_turn(TURN_TARGETS, TURN_SECONDS)
    frames = list(range(0, len(ch["yaw"]), STEP))

    def one(f: int) -> Path:
        data = {"yaw": f"{ch['yaw'][f]:.4f}", "pitch": f"{ch['pitch'][f]:.4f}", "gestureId": "nod", "gesture": "1"}
        return cli(TMP / "turn" / f"f{f:03}.png", data, f + 1)
    with ThreadPoolExecutor(WORKERS) as ex:
        paths = list(ex.map(one, frames))
    small = [Image.open(p).convert("RGB").crop(HEAD_BOX).resize((220, 264), Image.Resampling.LANCZOS) for p in paths]
    strip = Image.new("RGB", (220 * 8, 264))
    for k in range(8):
        strip.paste(small[k * len(small) // 8], (k * 220, 0))
    palette = strip.quantize(colors=56, method=Image.Quantize.MEDIANCUT)
    pal = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in small]
    pal[0].save(OUT / "turn.gif", save_all=True, append_images=pal[1:], duration=33, loop=0, optimize=True)
    picks = [round(i * (len(small) - 1) / 11) for i in range(12)]
    sheet([label(small[i].copy(), f"f{frames[i]}") for i in picks], 6, "turn_sheet.png")
    return paths


def metrics() -> None:
    lines = ["Avatar head yaw / pitch rig (rive/tools/head_turn.py, called by gen_avatar.py)",
             f"rive: {subprocess.run(['rive', '--version'], capture_output=True, text=True).stdout.strip()}", "",
             "== Rest pose unchanged (yaw = pitch = 0, rive --compare against the pre-rig captures)"]
    for name, data, adv in CAPTURES:
        png = TMP / "compare" / f"{name}.png"
        png.parent.mkdir(parents=True, exist_ok=True)
        res = subprocess.run(["rive", str(PROJ), f"--screenshot={png}", f"--compare={BEFORE / (name + '.png')}",
                              *[f"--data={k}={v}" for k, v in data.items()], f"--advance={adv}"],
                             cwd=PROJ, capture_output=True, text=True)
        cmp = next((ln.split(": ", 1)[-1] for ln in (res.stdout + res.stderr).splitlines()
                    if ln.startswith("compare ")), "?")
        lines.append(f"{name} {data or ''} advance {adv}: {cmp}")
    hist = []
    for k, (y, p) in enumerate(((0.37, -0.42), (-0.9, 0.8))):
        a = cli(TMP / "hist" / f"a{k}.png", {"yaw": f"{y}", "pitch": f"{p}"}, 1)
        res = subprocess.run(["rive", str(PROJ), f"--screenshot={TMP / 'hist' / f'b{k}.png'}", f"--compare={a}",
                              f"--data=yaw={y}", f"--data=pitch={p}", "--advance=1"], cwd=PROJ, capture_output=True,
                             text=True)
        hist.append(next((ln.split(": ", 1)[-1] for ln in (res.stdout + res.stderr).splitlines()
                          if ln.startswith("compare ")), "?"))
    riv = ROOT / "assets" / "rive" / "avatar.riv"
    lint = subprocess.run(["uv", "run", str(HERE / "art_bible.py"), "lint", str(PROJ / "avatar.rml"), "--scene",
                           "livingRoom"], capture_output=True, text=True).stdout.strip().splitlines()
    lines += ["", "== Deterministic: the same turned pose rendered twice (the rig is bind-only, no state)", *[f"pose {k}: {h}"
                                                                                     for k, h in enumerate(hist)],
              "", "== Size", f"assets/rive/avatar.riv: {riv.stat().st_size} B (budget 614400 B = 600 KB)",
              "", "== Art-bible lint (livingRoom), avatar.rml", f"{len(lint)} hits (baseline 597)"]
    (OUT / "metrics.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def main(argv: list[str]) -> None:
    parts = set(argv) or {"grid", "moods", "corners", "zoom", "identity", "turn", "metrics"}
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(PROJ), "--once"], cwd=PROJ, check=True, capture_output=True)
    for name in ("grid", "moods", "corners", "zoom", "identity", "turn", "metrics"):
        if name in parts:
            globals()[name]()
    for f in sorted(OUT.iterdir()):
        if f.is_file():
            print(f"{f.relative_to(ROOT)}: {f.stat().st_size} B")


if __name__ == "__main__":
    main(sys.argv[1:])
