"""Assembles a wow captured by the running macOS app (moonshot M6 Task 6, rulings 6-7).

    uv run --with pillow --with numpy rive/tools/wow_capture.py <wow dir> <out dir>

`<wow dir>` is what `integration_test/wow_capture_test.dart` printed as `WOW_DIR`
(`timeline.json`, `frames/NNNN.rgba`, `audio/NN.wav`; `wet.rgba` / `dry.rgba` for wow1). A
`<wow dir>_timing` sibling (the CAPTURE=false run) adds `frame_cost.json`. Writes to `<out dir>`:
- `<wow>.gif`: 8 fps real time, 280 px wide, 64 colours (narrower if over 4 MB), from just before the user
  types to the end;
- `<wow>.mp4`: 15 fps, the whole run, the window's size, with the sentence WAVs muxed where their captions
  appeared (ffmpeg);
- `<wow>_beats.png`: the storyboard beats, each the captured frame nearest its moment;
- `<wow>_gates.txt`: one `ok` / `FAIL` line per gate (ruling 7), exit 1 on a FAIL;
- `<wow>_frame_cost.json` when the timing run exists.
"""

from __future__ import annotations

import json
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

GIF_FPS = 8
GIF_W = 280
GIF_COLOURS = 64
MP4_FPS = 15
GIF_MAX = 4 * 1024 * 1024


# ---------------------------------------------------------------- timeline helpers (tested)
def bilabial_words(text: str) -> int:
    """Words whose first letter is p, b or m (inline cues like `[g:nod]` dropped)."""
    text = re.sub(r"\[[a-z]:[^\]]*\]", " ", text)
    return sum(1 for w in re.findall(r"[A-Za-z']+", text) if w[0].lower() in "pbm")


def closures(samples: list[dict]) -> int:
    """Separate runs of closed lips (lipPress >= 0.5, jaw <= 0.1) while speaking."""
    runs, inside = 0, False
    for s in samples:
        closed = s["speaking"] and s["press"] >= 0.5 and s["jaw"] <= 0.1
        if closed and not inside:
            runs += 1
        inside = closed
    return runs


def audio_offsets(events: list[dict], audio: list[dict], t0: int) -> list[tuple[str, int]]:
    """(wav, ms after t0) for each caption, matched in order to the synthesised sentence of the
    same text."""
    used: set[int] = set()
    out = []
    for e in events:
        if e["type"] != "caption":
            continue
        for i, a in enumerate(audio):
            if i not in used and a["text"].strip() == e["text"].strip():
                used.add(i)
                out.append((a["file"], e["ms"] - t0))
                break
    return out


def longest_closure(samples: list[dict]) -> dict:
    """The sample in the middle of the longest closed-lips run while speaking (a single grabbed frame
    lands inside a 66 ms window, so the middle of the longest run is the one most likely shown)."""
    best: list[dict] = []
    run: list[dict] = []
    for s in samples:
        if s["speaking"] and s["press"] >= 0.5 and s["jaw"] <= 0.1:
            run.append(s)
            if len(run) > len(best):
                best = list(run)
        else:
            run = []
    return best[len(best) // 2] if best else max(samples, key=lambda x: x["press"])


def _between(samples: list[dict], a: float, b: float) -> list[dict]:
    return [s for s in samples if a <= s["ms"] <= b]


def _first(events: list[dict], kind: str, after: float = -1) -> dict | None:
    return next((e for e in events if e["type"] == kind and e["ms"] > after), None)


def _line(text: str, ok: bool) -> str:
    return f"{text}: {'ok' if ok else 'FAIL'}"


def _common(tl: dict) -> list[str]:
    return [_line(f"captured frames: {len(tl['frames'])}", len(tl["frames"]) > 0),
            _line(f"network attempts during the run: {tl['network_attempts']}", tl["network_attempts"] == 0)]


def gates_wow1(tl: dict, front_visible: bool) -> list[str]:
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    g.append(_line(f"campfire at rain 1 in every sample ({len(s)})",
                   all(x["scene"] == "campfire" and x["rain"] >= 0.999 for x in s)))
    typing, send = _first(ev, "typing"), _first(ev, "send")
    lean = max((x["lean"] for x in _between(s, typing["ms"], send["ms"] + 300)), default=0.0)
    g.append(_line(f"listening lean while the user types: max {lean:.2f} (want > 0.3)", lean > 0.3))
    start = _first(ev, "start")
    breath = max((x["breath"] for x in _between(s, start["ms"] - 400, start["ms"] + 100)), default=0.0) \
        if start else 0.0
    g.append(_line(f"inhale before the first audio: breath max {breath:.2f} in the 400 ms before it (want > 0.5)",
                   breath > 0.5))
    words, runs = bilabial_words(tl["reply"]), closures(s)
    g.append(_line(f"lip closures while speaking: {runs} for {words} p/b/m words (want >= {0.7 * words:.1f})",
                   runs >= 0.7 * words))
    caps = [e for e in ev if e["type"] == "caption"]
    last = caps[-1] if caps else None
    stop = _first(ev, "stop", last["ms"]) if last else None
    brow = 0.0
    if last and stop:
        brow = max((x["browInner"] + x["browOuter"] for x in _between(s, stop["ms"] - 600, stop["ms"])), default=0.0)
    g.append(_line(f"brows up at the question's end: inner + outer max {brow:.2f} in its last 600 ms (want >= 0.3)",
                   brow >= 0.3))
    g.append(_line("front rain drawn over the avatar (wet vs dry frame, avatar box)", front_visible))
    return g


def gates_wow2(tl: dict) -> list[str]:
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    tool = [x for x in s if x["tool"] == "getCurrentWeather"]
    span = (tool[-1]["ms"] - tool[0]["ms"]) if tool else 0
    g.append(_line(f"tool getCurrentWeather running for {span} ms (want >= 2000)", span >= 2000))
    tablet = sum(1 for x in tool if x["prop"] == "tablet") / len(tool) if tool else 0.0
    g.append(_line(f"tablet out while the tool runs: {tablet:.0%} of its samples (want >= 80%)", tablet >= 0.8))
    yaw = statistics.median(abs(x["yaw"]) for x in tool) if tool else 0.0
    g.append(_line(f"head turned while the tool runs: median |yaw| {yaw:.2f} (want >= 0.3)", yaw >= 0.3))
    start = _first(ev, "start", tool[-1]["ms"]) if tool else None
    g.append(_line("the answer is spoken after the tool", start is not None))
    if start:
        stop = _first(ev, "stop", start["ms"])
        answer = _between(s, start["ms"] + 1000, stop["ms"] if stop else 1e12)
        held = sum(1 for x in answer if x["prop"] != "none")
        g.append(_line(f"tablet put away 1 s into the answer: {held} samples still holding a prop", held == 0
                       and bool(answer)))
        ay = statistics.median(abs(x["yaw"]) for x in answer) if answer else 1.0
        g.append(_line(f"facing the user while answering: median |yaw| {ay:.2f} (want <= 0.15)", ay <= 0.15))
    return g


# ---------------------------------------------------------------- frames
def load_frame(path: Path, size: tuple[int, int]) -> Image.Image:
    return Image.frombytes("RGBA", size, path.read_bytes()).convert("RGB")


def resample(frames: list[dict], fps: int) -> list[int]:
    """Frame indices, one per 1/fps tick from the first capture to the last (nearest earlier)."""
    if not frames:
        return []
    t0, t1 = frames[0]["ms"], frames[-1]["ms"]
    out, j = [], 0
    for k in range(int((t1 - t0) * fps / 1000) + 1):
        t = t0 + k * 1000 / fps
        while j + 1 < len(frames) and frames[j + 1]["ms"] <= t:
            j += 1
        out.append(frames[j]["i"])
    return out


def nearest(frames: list[dict], ms: float) -> int:
    return min(frames, key=lambda f: abs(f["ms"] - ms))["i"]


def front_visible(wow_dir: Path, size: tuple[int, int]) -> tuple[bool, float]:
    """Wet vs dry frame inside the avatar's hoodie. The avatar is opaque there, so the scene's own
    rain is behind it and only the front layer can change it; at any one instant the sparse near
    streaks may miss the box, but the rain mist darkens all of it. Passes when the wet median
    luminance is at most 0.97 of the dry one (idle motion moves edges, not the median)."""
    wet, dry = wow_dir / "wet.rgba", wow_dir / "dry.rgba"
    if not (wet.exists() and dry.exists()):
        return False, 1.0
    weights = np.array([0.2126, 0.7152, 0.0722])
    a = np.asarray(load_frame(wet, size)).astype(float) @ weights
    b = np.asarray(load_frame(dry, size)).astype(float) @ weights
    w, h = size
    box = (slice(int(h * 0.66), int(h * 0.84)), slice(int(w * 0.38), int(w * 0.62)))
    ratio = float(np.median(a[box]) / max(np.median(b[box]), 1e-6))
    return ratio <= 0.97, ratio


def beats(tl: dict) -> list[tuple[str, float, float]]:
    """(label, ms, zoom) of the storyboard beats found in the timeline."""
    s, ev = tl["samples"], tl["events"]
    first = tl["frames"][0]["ms"]
    start = _first(ev, "start")
    stop_all = [e for e in ev if e["type"] == "stop"]
    end = stop_all[-1]["ms"] if stop_all else tl["frames"][-1]["ms"]
    speaking = [x for x in s if x["speaking"]]
    if tl["wow"] == "wow1":
        typing, send = _first(ev, "typing"), _first(ev, "send")
        lean = max(_between(s, typing["ms"], send["ms"] + 300), key=lambda x: x["lean"])
        pre = max(_between(s, start["ms"] - 400, start["ms"] + 100), key=lambda x: x["breath"])
        closed = longest_closure(s)
        caps = [e for e in ev if e["type"] == "caption"]
        q_stop = _first(ev, "stop", caps[-1]["ms"])
        brow = max(_between(s, q_stop["ms"] - 600, q_stop["ms"]), key=lambda x: x["browInner"] + x["browOuter"])
        mid = speaking[len(speaking) // 2]
        return [("1 wide: rain, steam, firelight", first + 800, 1.0),
                (f"2 listening lean {lean['lean']:.2f} while typing", lean["ms"], 1.0),
                (f"3 inhale: breath {pre['breath']:.2f}", pre["ms"], 1.6),
                (f"4 lips closed (press {closed['press']:.2f})", closed["ms"], 2.2),
                (f"5 question brows ({brow['browInner'] + brow['browOuter']:.2f})", brow["ms"], 1.6),
                ("6 firelight on the cheek", mid["ms"], 2.2),
                ("7 settles after the stop", min(end + 900, tl["frames"][-1]["ms"]), 1.0)]
    tool = [x for x in s if x["tool"] == "getCurrentWeather"]
    answer = [x for x in speaking if x["ms"] > tool[-1]["ms"]] if tool else speaking
    send = _first(ev, "send")
    return [("1 the user asks", send["ms"] - 300, 1.0),
            ("2 tool starts: head turns", tool[0]["ms"] + 350, 1.0),
            ("3 tablet out, screen lights the face", tool[0]["ms"] + 1200, 1.0),
            ("4 eyes on the screen", tool[len(tool) * 3 // 4]["ms"], 1.6),
            ("5 glances back, tablet away", tool[-1]["ms"] + 1300, 1.0),
            ("6 answers (nod)", answer[len(answer) // 3]["ms"] if answer else end, 1.0)]


def crop_zoom(im: Image.Image, zoom: float) -> Image.Image:
    """The face-centred crop the storyboard's close-ups use (the avatar's head sits ~43 % down)."""
    if zoom == 1.0:
        return im
    w, h = im.size
    cw, ch = int(w / zoom), int(h / zoom)
    x0, y0 = (w - cw) // 2, max(0, min(h - ch, int(h * 0.43 - ch / 2)))
    return im.crop((x0, y0, x0 + cw, y0 + ch)).resize((w, h), Image.LANCZOS)


def beat_sheet(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> None:
    cells = []
    cw = 300
    chh = int(size[1] * cw / size[0])
    for label, ms, zoom in beats(tl):
        i = nearest(tl["frames"], ms)
        im = crop_zoom(load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size), zoom).resize((cw, chh))
        cell = Image.new("RGB", (cw, chh + 34), (22, 18, 29))
        cell.paste(im, (0, 0))
        d = ImageDraw.Draw(cell)
        d.text((6, chh + 4), label, fill=(244, 184, 96))
        d.text((6, chh + 18), f"t = {(ms - tl['frames'][0]['ms']) / 1000:.2f} s, frame {i}", fill=(200, 200, 200))
        cells.append(cell)
    sheet = Image.new("RGB", (len(cells) * (cw + 6) - 6, chh + 34), (10, 10, 10))
    for k, c in enumerate(cells):
        sheet.paste(c, (k * (cw + 6), 0))
    sheet.save(out)


def write_gif(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> int:
    typing = _first(tl["events"], "typing")
    t0 = typing["ms"] - 800 if typing else tl["frames"][0]["ms"]
    idx = resample([f for f in tl["frames"] if f["ms"] >= t0], GIF_FPS)
    width = GIF_W
    while True:
        h = int(size[1] * width / size[0])
        ims = [load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size).resize((width, h), Image.LANCZOS)
               for i in idx]
        pal = [im.quantize(colors=GIF_COLOURS, method=Image.Quantize.MEDIANCUT) for im in ims]
        pal[0].save(out, save_all=True, append_images=pal[1:], duration=round(1000 / GIF_FPS), loop=0,
                    optimize=True)
        if out.stat().st_size <= GIF_MAX or width <= 200:
            return out.stat().st_size
        width -= 40


def write_mp4(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> None:
    idx = resample(tl["frames"], MP4_FPS)
    with tempfile.TemporaryDirectory() as tmp:
        for k, i in enumerate(idx):
            load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size).save(Path(tmp) / f"{k:05d}.png")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(MP4_FPS), "-i", f"{tmp}/%05d.png"]
        clips = audio_offsets(tl["events"], tl["audio"], tl["frames"][0]["ms"])
        for f, _ in clips:
            cmd += ["-i", f]
        w, h = size[0] // 2 * 2, size[1] // 2 * 2
        vf = f"[0:v]crop={w}:{h}:0:0,format=yuv420p[v]"
        if clips:
            delays = ";".join(f"[{k + 1}:a]adelay={max(0, ms)}|{max(0, ms)}[a{k}]" for k, (_, ms) in enumerate(clips))
            mix = "".join(f"[a{k}]" for k in range(len(clips))) + \
                f"amix=inputs={len(clips)}:normalize=0,apad[a]"
            cmd += ["-filter_complex", f"{vf};{delays};{mix}", "-map", "[v]", "-map", "[a]", "-shortest",
                    "-c:a", "aac"]
        else:
            cmd += ["-filter_complex", vf, "-map", "[v]"]
        cmd += ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", str(out)]
        subprocess.run(cmd, check=True)


def frame_cost(timing_dir: Path) -> dict | None:
    p = timing_dir / "timeline.json"
    if not p.exists():
        return None
    t = json.loads(p.read_text())["frame_timings"]
    if not t:
        return None

    def pct(xs: list[float], q: float) -> float:
        xs = sorted(xs)
        return round(xs[min(len(xs) - 1, int(q * len(xs)))], 2)
    b, r = [x["build"] for x in t], [x["raster"] for x in t]
    over = sum(1 for x in t if x["build"] > 16.6 or x["raster"] > 16.6)
    return {"frames": len(t), "build_p50": pct(b, 0.5), "build_p95": pct(b, 0.95), "raster_p50": pct(r, 0.5),
            "raster_p95": pct(r, 0.95), "over_16_6_share": round(over / len(t), 4),
            "note": "macOS desktop (debug build, Skia; not a device tier)"}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    wow_dir, out = Path(argv[0]), Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    tl = json.loads((wow_dir / "timeline.json").read_text())
    wow = tl["wow"]
    size = (int(tl["size"][0]), int(tl["size"][1]))
    gates = []
    empty = []
    for f in tl["frames"]:
        a = np.asarray(load_frame(wow_dir / "frames" / f"{f['i']:04d}.rgba", size))
        if a.std() < 5:
            empty.append(f["i"])
    gates.append(_line(f"every frame non-empty ({len(empty)} blank)", not empty))
    try:
        if wow == "wow1":
            ok, share = front_visible(wow_dir, size)
            gates += [g.replace("(wet vs dry frame, avatar box)",
                                f"(rain mist: wet / dry median luminance inside the hoodie {share:.3f}, "
                                f"want <= 0.97)")
                      for g in gates_wow1(tl, ok)]
        else:
            gates += gates_wow2(tl)
    except (TypeError, ValueError, IndexError, KeyError, AttributeError) as e:
        # an event or a sample the gates need is missing: a verdict, not a crash
        gates.append(_line(f"timeline incomplete ({type(e).__name__}: {e})", False))
    size_gif = write_gif(wow_dir, tl, size, out / f"{wow}.gif")
    gates.append(_line(f"{wow}.gif {size_gif} B (budget {GIF_MAX})", size_gif <= GIF_MAX))
    if shutil.which("ffmpeg"):
        write_mp4(wow_dir, tl, size, out / f"{wow}.mp4")
    if not any(g.endswith("FAIL") for g in gates):
        beat_sheet(wow_dir, tl, size, out / f"{wow}_beats.png")
    cost = frame_cost(Path(str(wow_dir) + "_timing"))
    if cost:
        (out / f"{wow}_frame_cost.json").write_text(json.dumps(cost, indent=1) + "\n")
        gates.append(f"frame cost (macOS desktop, not a tier): build P95 {cost['build_p95']} ms, raster P95 "
                     f"{cost['raster_p95']} ms, over 16.6 ms {cost['over_16_6_share']:.1%}: info")
    (out / f"{wow}_gates.txt").write_text("\n".join(gates) + "\n")
    print("\n".join(gates))
    return 1 if any(g.endswith("FAIL") for g in gates) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
