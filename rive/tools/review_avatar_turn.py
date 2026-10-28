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
import json
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


# a performed turn on the real avatar: rig_dsl.perform_turn's yaw / pitch plus its follow-through
# (hairLag -> hairLagYaw, gaze -> eyeLeadYaw), one CLI run per frame (the rig is history-free;
# the state machine advances with the frame, so idle blinks and the nod fired at frame 0 play)
# the big turn starts at 2.75 s so the avatar's own idle blink (frames 168-181) lands in it
TURN_TARGETS = [(0.0, 0.0), (0.5, 0.8), (2.75, -0.75), (4.0, 0.0)]
TURN_SECONDS = 5.0
STEP = 2  # every 2nd 60 fps frame -> a 30 fps GIF


LOWER_FACE = (290, 420, 510, 574)  # mouth, chin and jaw (artboard px)
MOUTH_STATES: list[tuple[str, dict[str, str]]] = [
    *[(f"mouth {m}", {"mouth": str(m)}) for m in range(5)],
    *[(mood, {"mood": mood}) for mood in ("happy", "sad", "angry", "surprised", "thinking", "embarrassed")]]


def mouth_matrix() -> None:
    """Every mouth (0-4 and each mood mouth) at yaw {-1, 0, 1} x pitch {-1, -0.5, 0, 1}."""
    poses = [(y, p) for y in (-1.0, 0.0, 1.0) for p in (-1.0, -0.5, 0.0, 1.0)]
    jobs = [(f"{tag} y{y:+.0f} p{p:+.1f}", {**data, "yaw": f"{y:g}", "pitch": f"{p:g}"}, 40)
            for tag, data in MOUTH_STATES for y, p in poses]
    sheet(render_cells(jobs, LOWER_FACE, (150, 105), "mouth"), len(poses), "mouth_matrix.png")


def glasses() -> None:
    """Both glasses sets across the turn: lenses, glints and the near temple, eye band zoom."""
    jobs = [(f"{g} yaw {y:+.1f}", {"glasses": g, "yaw": f"{y:g}"}, 1)
            for g in ("glasses", "sunglasses") for y in (-1.0, -0.5, 0.0, 0.5, 1.0)]
    sheet(render_cells(jobs, (210, 300, 590, 480), (380, 180), "glasses"), 5, "glasses.png")


def lag() -> None:
    """Follow-through and eye-lead channels at yaw 0.5: eyeLeadYaw +-1, eyeLeadPitch +-1 (and a
    blink at -1), hairLagYaw +-0.5 / +-1, hairLagPitch +-0.5. Second row: the eyes zoomed."""
    jobs = [("yaw 0.5", {"yaw": "0.5"}, 1)]
    jobs += [(f"{k} {v:+g}", {"yaw": "0.5", k: f"{v:g}"}, 1)
             for k, vals in (("eyeLeadYaw", (-1.0, 1.0)), ("eyeLeadPitch", (-1.0, 1.0)),
                             ("hairLagYaw", (-0.5, 0.5, -1.0, 1.0)), ("hairLagPitch", (-0.5, 0.5)))
             for v in vals]
    jobs.append(("eyeLeadPitch -1 + blink", {"yaw": "0.5", "eyeLeadPitch": "-1"}, 172))
    heads = render_cells(jobs, HEAD_BOX, (240, 288), "lag")
    eyes = render_cells([j for j in jobs if j[0].startswith(("yaw", "eyeLead"))], (280, 330, 520, 460), (240, 130),
                        "lag_eyes")
    eyes_row = Image.new("RGB", (240 * 6, 288), (20, 18, 26))
    for k, c in enumerate(eyes):
        eyes_row.paste(c, ((k % 6) * 240, (k // 6) * 140))
    cells = heads + [eyes_row.crop((k * 240, 0, (k + 1) * 240, 288)) for k in range(6)]
    sheet(cells, 6, "lag.png")


FINAL_POSES: list[tuple[str, dict[str, str], int]] = [
    ("eyeLeadPitch -1", {"eyeLeadPitch": "-1"}, 1),
    ("eyeLeadPitch -1 blink", {"eyeLeadPitch": "-1"}, 172),
    ("yaw .8 hairLagYaw -.46", {"yaw": "0.8", "hairLagYaw": "-0.46"}, 1),
    ("yaw -.8 hairLagYaw +.46", {"yaw": "-0.8", "hairLagYaw": "0.46"}, 1),
    ("yaw .7 eyeLeadYaw -.52", {"yaw": "0.7", "eyeLeadYaw": "-0.52"}, 1),
    ("yaw -.7 eyeLeadYaw +.52", {"yaw": "-0.7", "eyeLeadYaw": "0.52"}, 1),
    ("yaw .5 hairLagYaw -.4", {"yaw": "0.5", "hairLagYaw": "-0.4"}, 1),
    ("yaw .5 hairLagYaw +.4", {"yaw": "0.5", "hairLagYaw": "0.4"}, 1),
    ("yaw 1 hairLagYaw -1", {"yaw": "1", "hairLagYaw": "-1"}, 1),
    ("yaw -1 hairLagYaw +1", {"yaw": "-1", "hairLagYaw": "1"}, 1),
]


def final() -> None:
    """The final-round critic poses: whole head, then the eyes zoomed."""
    heads = render_cells(FINAL_POSES, HEAD_BOX, (240, 288), "final")
    eyes = render_cells(FINAL_POSES, (260, 320, 540, 460), (240, 120), "final_eyes")
    out = Image.new("RGB", (240 * 5, 288 * 2 + 120 * 2), (20, 18, 26))
    for k, c in enumerate(heads):
        out.paste(c, ((k % 5) * 240, (k // 5) * 288))
    for k, c in enumerate(eyes):
        out.paste(c, ((k % 5) * 240, 576 + (k // 5) * 120))
    out.save(OUT / "final.png", optimize=True)


def lead_travel() -> list[str]:
    """Measured iris / pupil travel (centroid of the dark pupil pixels in the right eye)."""
    def centroid(data: dict[str, str]) -> tuple[float, float]:
        tag = "_".join(f"{k}{v}" for k, v in data.items()) or "rest"
        im = Image.open(cli(TMP / "lead" / f"{tag}.png", data, 1)).convert("RGB")
        pts = [(x, y) for x in range(425, 500) for y in (range(360, 430))
               if sum(im.getpixel((x, y))) < 120 and im.getpixel((x, y))[0] - im.getpixel((x, y))[2] > 10]  # pupil/ring, not frame
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    x0, y0 = centroid({})
    out = []
    for k, v in (("eyeLeadYaw", "1"), ("eyeLeadYaw", "-1"), ("eyeLeadPitch", "1"), ("eyeLeadPitch", "-1")):
        x, y = centroid({k: v})
        out.append(f"{k} {v}: pupil moves dx {x - x0:+.1f}, dy {y - y0:+.1f} artboard px")
    return out


def turn() -> list[Path]:
    ch = r.perform_turn(TURN_TARGETS, TURN_SECONDS)
    frames = list(range(0, len(ch["yaw"]), STEP))

    def one(f: int) -> Path:
        data = {"yaw": f"{ch['yaw'][f]:.4f}", "pitch": f"{ch['pitch'][f]:.4f}", "gestureId": "nod", "gesture": "1",
                "hairLagYaw": f"{max(-1.0, min(1.0, ch['hairLag'][f])):.4f}",
                "eyeLeadYaw": f"{max(-1.0, min(1.0, ch['gaze'][f])):.4f}"}
        return cli(TMP / "turn" / f"f{f:03}.png", data, f + 1)
    with ThreadPoolExecutor(WORKERS) as ex:
        paths = list(ex.map(one, frames))
    small = [Image.open(p).convert("RGB").crop(HEAD_BOX).resize((220, 264), Image.Resampling.LANCZOS) for p in paths]
    strip = Image.new("RGB", (220 * 8, 264))
    for k in range(8):
        strip.paste(small[k * len(small) // 8], (k * 220, 0))
    palette = strip.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    pal = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in small]
    pal[0].save(OUT / "turn.gif", save_all=True, append_images=pal[1:], duration=33, loop=0, optimize=True)
    picks = [round(i * (len(small) - 1) / 11) for i in range(12)]
    sheet([label(small[i].copy(), f"f{frames[i]}") for i in picks], 6, "turn_sheet.png")
    return paths


# the integrated turn: the app's own HeadMotionSolver drives the avatar, frame by frame, from the
# trace `dart run tool/head_motion_trace.dart > rive/avatar/review/head_rig/app_trace.json`
# (user 0.8 s -> tool glance away(0.6) 2.4 s -> user 1.4 s -> caret 1.4 s, 60 fps)
APP_KEYS = ("yaw", "pitch", "hairLagYaw", "hairLagPitch", "eyeLeadYaw", "eyeLeadPitch")


def app_turn() -> None:
    trace = json.loads((OUT / "app_trace.json").read_text())
    frames = list(range(0, len(trace), STEP))

    def one(f: int) -> Path:
        data = {k: f"{trace[f][k]:.4f}" for k in APP_KEYS}
        return cli(TMP / "app" / f"f{f:03}.png", data, f + 1)
    with ThreadPoolExecutor(WORKERS) as ex:
        paths = list(ex.map(one, frames))
    small = [Image.open(p).convert("RGB").crop(HEAD_BOX).resize((220, 264), Image.Resampling.LANCZOS) for p in paths]
    strip = Image.new("RGB", (220 * 8, 264))
    for k in range(8):
        strip.paste(small[k * len(small) // 8], (k * 220, 0))
    palette = strip.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    pal = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in small]
    pal[0].save(OUT / "app_turn.gif", save_all=True, append_images=pal[1:], duration=33, loop=0, optimize=True)
    picks = [round(i * (len(small) - 1) / 11) for i in range(12)]
    sheet([label(small[i].copy(), f"f{frames[i]}") for i in picks], 6, "app_turn_sheet.png")


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
              "", "== Art-bible lint (livingRoom), avatar.rml", f"{len(lint)} hits (baseline 597)",
              "", "== Eye lead travel at yaw 0 (eye white ~61 px wide, ~38 px tall on the artboard)", *lead_travel()]
    (OUT / "metrics.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def main(argv: list[str]) -> None:
    order = ("grid", "moods", "corners", "zoom", "glasses", "mouth_matrix", "lag", "final", "identity", "turn", "app_turn",
             "metrics")
    parts = set(argv) or set(order)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rive", str(PROJ), "--once"], cwd=PROJ, check=True, capture_output=True)
    for name in order:
        if name in parts:
            globals()[name]()
    for f in sorted(OUT.iterdir()):
        if f.is_file():
            print(f"{f.relative_to(ROOT)}: {f.stat().st_size} B")


if __name__ == "__main__":
    main(sys.argv[1:])
