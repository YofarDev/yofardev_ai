"""Assembles the Yofardev AI showcase (9:16, 1080x1920, 30 fps) from the
capture runs of `integration_test/wow_capture_test.dart` (WOW=show_*).

    uv run --with pillow --with numpy showcase/render_showcase.py

Reads   showcase/work/out/<src>/wow/<run>/  (timeline.json, frames/NNNN.rgba,
audio/NN.wav; src = mac | emu) and writes into showcase/:

- showcase-vertical.mp4   H.264 + AAC, fast-start
- showcase-captions.srt   the dialogue, timed to the final cut
- showcase-poster.png     a representative frame
- work/show_frames/       the assembled PNG sequence (kept for re-edits)

Every shot maps a [t0, t1] window of a capture run onto the show timeline at
1:1 speed; frames are resampled nearest-earlier onto the 30 fps grid (the
captures are VFR; no motion is invented). Frames are scaled and centre-cropped
to 1080x1920 with one uniform factor per source. Audio is assembled in numpy:
the Kokoro sentence WAVs at their captured offsets, the app's foley assets at
their logged times, and the ambient beds mixed at the app's own levels
(AmbientBedService: crackle 0.072, outdoors rain 0.10, beach wind 0.048),
ducked to half while the avatar speaks, like the app does. The end card is
drawn with the app's bundled fonts (Fraunces / Manrope) and its palette
(ink #16121D, accent #F4B860).
"""

from __future__ import annotations

import json
import math
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent  # the repository root (assets live here)
DELIVER = ROOT
FRAMES_DIR = ROOT / "work" / "show_frames"
SOURCES = {"mac": ROOT / "work" / "out" / "mac" / "wow", "emu": ROOT / "work" / "out" / "emu" / "wow"}

FPS = 30
W, H = 1080, 1920
SR = 48000

FONT_DIR = OUT / "assets" / "fonts" / "google_fonts"
FRAUNCES_500 = FONT_DIR / "Fraunces-Medium.ttf"
FRAUNCES_600 = FONT_DIR / "Fraunces-SemiBold.ttf"
MANROPE_400 = FONT_DIR / "Manrope-Regular.ttf"
MANROPE_500 = FONT_DIR / "Manrope-Medium.ttf"

INK = (22, 18, 29)
CREAM = (243, 237, 226)
ACCENT = (244, 184, 96)
GREY = (176, 168, 189)

# AmbientBedService levels (lib/core/services/audio/ambient_bed_service.dart).
CRACKLE_LEVEL = 0.072
RAIN_LEVEL = 0.10
WIND_LEVEL = 0.048
DUCK = 0.5
FOLEY_LEVEL = 0.55

# ---------------------------------------------------------------------------
# The cut. Each shot takes a [t0, t1] window of one capture run, resolved
# from the run's own events (see resolve_window). `src` picks the platform
# whose footage the shot uses (mac = 30 fps capture with softer wide shots;
# emu = ~13 fps capture with full-resolution Rive textures).
# ---------------------------------------------------------------------------

SHOTS = [
    {"id": "hook", "run": "show_hook", "src": "mac", "pick": "speech", "anchor": "speech", "lead": 500, "tail": 0, "sentences": 2},
    {"id": "weather_a", "run": "show_weather", "src": "mac", "pick": "toolhead", "lead": 800, "len": 2900, "blend": 0.4},
    {"id": "weather_b", "run": "show_weather", "src": "mac", "pick": "answerspeech", "lead": 250, "tail": 0, "sentences": 1},
    {"id": "journey_a", "run": "show_journey", "src": "mac", "pick": "journey_out", "lead": 700},
    {"id": "journey_b", "run": "show_journey", "src": "mac", "pick": "journey_in", "tail": 0},
    {"id": "campfire", "run": "show_campfire", "src": "mac", "pick": "speech", "lead": 250, "tail": 150, "max": 2200, "take": "late"},
    {"id": "train", "run": "show_train", "src": "mac", "pick": "speech", "anchor": "speech", "lead": 600, "tail": 100, "max": 2100, "sentences": 1},
    {"id": "space", "run": "show_space", "src": "mac", "pick": "drag", "lead": 200, "tail": 450},
    {"id": "finish", "run": "show_finish", "src": "mac", "pick": "speech", "anchor": "speech", "lead": 550, "tail": 450, "max": 5400},
]

OVERLAYS = [
    {"shot": "hook", "text": "An AI with a little more life.", "font": FRAUNCES_500, "size": 60, "in": 250, "out": -250},
    {"shot": "weather_a", "text": "Real tools. Real character.", "font": FRAUNCES_500, "size": 60, "in": 400, "out": -250},
    {"shot": "campfire", "text": "A world that moves with you.", "font": FRAUNCES_500, "size": 60, "in": 350, "out": None, "hold": True},
    {"shot": "space", "text": "A world that moves with you.", "font": FRAUNCES_500, "size": 60, "in": None, "out": -350, "hold": True},
]

END_CARD_S = 4.0
END_FADE_S = 0.6
POSTER_SHOT = "weather_b"
POSTER_T = 0.68  # fraction into the shot


# ---------------------------------------------------------------- timeline io
def load_run(src: str, name: str) -> dict:
    root = SOURCES[src] / name
    tl = json.loads((root / "timeline.json").read_text())
    frames = {f["i"]: f["ms"] for f in tl["frames"]}
    audio = []
    for a in tl["audio"]:
        path = Path(a["file"])
        if not path.is_absolute():
            path = root / a["file"].split("/")[-1]
        audio.append((a["text"].strip(), path))
    events = tl["events"]
    sentences: list[dict] = []
    used: set[int] = set()
    for e in events:
        if e["type"] != "caption":
            continue
        for i, (text, path) in enumerate(audio):
            if i not in used and text == e["text"].strip():
                used.add(i)
                # the sentence's audible end is its own wav length (the stop
                # event trails into the next sentence's preroll)
                with wave.open(str(path), "rb") as w:
                    dur = w.getnframes() / w.getframerate() * 1000
                sentences.append({"text": text, "t0": e["ms"], "t1": e["ms"] + dur, "file": path})
                break
    return {
        "root": root,
        "tl": tl,
        "frames": frames,
        "size": (int(tl["size"][0]), int(tl["size"][1])),
        "sentences": sentences,
        "events": events,
    }


def ev(run: dict, kind: str, **match) -> dict | None:
    for e in run["events"]:
        if e["type"] != kind:
            continue
        if all(e.get(k) == v for k, v in match.items()):
            return e
    return None


def resolve_window(run: dict, shot: dict) -> tuple[int, int]:
    """The shot's [t0, t1] inside the run, in milliseconds."""
    pick = shot["pick"]
    sents = run["sentences"]
    last = max(run["frames"].keys())
    t_end = run["frames"][last] + 300
    if pick == "speech":
        if shot.get("anchor") == "speech":
            # hang the window on the greeting itself: the breath before the
            # first sentence, out after the last covered one
            n = shot.get("sentences", len(sents))
            t0 = sents[0]["t0"] - shot.get("lead", 500)
            t1 = sents[min(n, len(sents)) - 1]["t1"] + shot.get("tail", 300)
        elif shot.get("take") == "late" and len(sents) > 1:
            t0 = sents[-1]["t0"] - 700
            t1 = sents[-1]["t1"] + shot.get("tail", 300)
        else:
            start = ev(run, "typing") or ev(run, "send")
            t0 = (start["ms"] if start else sents[0]["t0"]) + shot.get("lead", 0)
            t1 = sents[-1]["t1"] + shot.get("tail", 400)
        if shot.get("max") and t1 - t0 > shot["max"]:
            if shot.get("take") == "late":
                t0 = t1 - shot["max"]
            else:
                t1 = t0 + shot["max"]
    elif pick == "toolhead":
        samples = run["tl"]["samples"]
        tool = [x for x in samples if x.get("tool") == "getCurrentWeather"]
        if not tool:
            raise SystemExit(f"no tool samples in {shot['run']}")
        t0 = max(0, tool[0]["ms"] - shot.get("lead", 800))
        t1 = t0 + shot.get("len", 3500)
    elif pick == "answerspeech":
        samples = run["tl"]["samples"]
        tool = [x for x in samples if x.get("tool") == "getCurrentWeather"]
        after = [x for x in sents if x["t0"] > tool[-1]["ms"]] if tool else sents
        if not after:
            raise SystemExit(f"no answer sentences in {shot['run']}")
        n = shot.get("sentences", len(after))
        t0 = after[0]["t0"] - shot.get("lead", 450)
        t1 = after[min(n, len(after)) - 1]["t1"] + shot.get("tail", 0)
    elif pick == "tool":
        samples = run["tl"]["samples"]
        tool = [x for x in samples if x.get("tool") == "getCurrentWeather"]
        if not tool:
            raise SystemExit(f"no tool samples in {shot['run']}")
        t0 = tool[0]["ms"] - shot.get("lead", 1300)
        answers = [s for s in sents if s["t0"] > tool[-1]["ms"]]
        if not answers:
            raise SystemExit(f"no answer sentences in {shot['run']}")
        last = answers[min(shot.get("sentences", len(answers)), len(answers)) - 1]
        t1 = last["t1"] + shot.get("tail", 400)
    elif pick == "journey_out":
        samples = run["tl"]["samples"]
        phases = [x for x in samples if x.get("journey")]
        if not phases:
            raise SystemExit(f"no journey samples in {shot['run']}")
        close = next((x["ms"] for x in phases if x["journey"] == "close"), None)
        send = ev(run, "send")
        t0 = (send["ms"] if send else phases[0]["ms"] - 800) - shot.get("lead", 700)
        t1 = close + 250 if close else phases[0]["ms"] + 4500
    elif pick == "journey_in":
        samples = run["tl"]["samples"]
        phases = [x for x in samples if x.get("journey")]
        arrive = next((x["ms"] for x in phases if x["journey"] == "arriveOpen"), None)
        t0 = arrive - 150 if arrive else t_end - 4000
        # hold through the arrival line, end when its audio ends
        after = [x for x in sents if x["t0"] >= t0]
        t1 = after[-1]["t1"] + shot.get("tail", 0) if after else t_end
    elif pick == "drag":
        ds = ev(run, "dragStart")
        de = ev(run, "dragEnd")
        if ds is None or de is None:
            raise SystemExit(f"no drag events in {shot['run']}")
        t0 = ds["ms"] - shot.get("lead", 200)
        t1 = de["ms"] + shot.get("tail", 2600)
    else:
        raise SystemExit(f"unknown pick {pick}")
    t0 = max(0, min(t0, t_end - 300))
    t1 = max(t0 + 400, min(t1, t_end))
    if shot.get("max") and t1 - t0 > shot["max"]:
        t1 = t0 + shot["max"]
    return int(t0), int(t1)


# ---------------------------------------------------------------- frames
_frame_cache: dict[tuple[str, str, int], Image.Image] = {}


def load_frame(run: dict, index: int) -> Image.Image:
    key = (run["root"].parent.parent.name, run["root"].name, index)
    if key not in _frame_cache:
        raw = (run["root"] / "frames" / f"{index:04d}.rgba").read_bytes()
        w, h = run["size"]
        _frame_cache[key] = Image.frombytes("RGBA", (w, h), raw).convert("RGB")
    return _frame_cache[key]


def frame_at(run: dict, ms: float) -> int:
    """The nearest captured frame index at or before [ms]."""
    best, best_ms = None, -1.0
    for i, t in run["frames"].items():
        if t <= ms and t > best_ms:
            best, best_ms = i, t
    if best is None:
        best = min(run["frames"], key=lambda i: run["frames"][i])
    return best


def to_canvas(img: Image.Image) -> Image.Image:
    """One uniform scale to cover 1080x1920, then a centre crop."""
    w, h = img.size
    scale = max(W / w, H / h)
    if abs(scale - 1.0) > 1e-3:
        img = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    x0 = (img.width - W) // 2
    y0 = (img.height - H) // 2
    return img.crop((x0, y0, x0 + W, y0 + H))


# ---------------------------------------------------------------- overlays
def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def text_layer(text: str, font: ImageFont.FreeTypeFont, fill) -> Image.Image:
    pad = 40
    layer = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    box = ImageDraw.Draw(layer).textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text(
        (pad - box[0] + 3, pad - box[1] + 3), text, font=font, fill=(0, 0, 0, 190),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    layer = Image.alpha_composite(layer, shadow)
    ImageDraw.Draw(layer).text((pad - box[0], pad - box[1]), text, font=font, fill=fill)
    return layer


def compose_overlay(frame: Image.Image, layer: Image.Image, alpha: float) -> None:
    if alpha <= 0:
        return
    faded = layer.copy()
    faded.putalpha(faded.getchannel("A").point(lambda v: int(v * alpha)))
    frame.paste(faded, ((W - faded.width) // 2, int(H * 0.185) - faded.height // 2), faded)


def overlay_alpha(rel_ms: int, ovl: dict, shot_len_ms: int) -> float:
    a = ovl["in"] if ovl["in"] is not None else 0
    out = ovl["out"]
    # a negative "out" counts backwards from the shot's end
    b = shot_len_ms + out if out is not None and out < 0 else (
        out if out is not None else shot_len_ms
    )
    fade = 350
    if rel_ms < a:
        return 0.0
    if rel_ms < a + fade:
        return (rel_ms - a) / fade
    if rel_ms > b:
        return 0.0
    if rel_ms > b - fade:
        return max(0.0, (b - rel_ms) / fade)
    return 1.0


# ---------------------------------------------------------------- end card
def end_card_frame(t: float) -> Image.Image:
    """The end card at second [t]: ink field, breathing amber glow, the
    title and lines fading in over the first 0.6 s."""
    img = Image.new("RGB", (W, H), INK)
    glow_alpha = 26 + 10 * math.sin(t / END_CARD_S * 2 * math.pi)
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy, r = W // 2, int(H * 0.72), int(W * 0.62)
    for k in range(7):
        radius = int(r * (1 - k / 7))
        gd.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=int(glow_alpha * (k + 1) / 7))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.composite(Image.new("RGB", (W, H), ACCENT), img, glow)

    text_alpha = min(1.0, t / 0.6)
    d = ImageDraw.Draw(img)

    def blend(fill):
        return tuple(int(INK[i] + (fill[i] - INK[i]) * text_alpha) for i in range(3))

    title = "Yofardev AI"
    f_title = load_font(FRAUNCES_600, 104)
    tw = d.textbbox((0, 0), title, font=f_title)[2]
    d.text(((W - tw) / 2, int(H * 0.335)), title, font=f_title, fill=blend(CREAM))

    d.rectangle(((W - 88) / 2, int(H * 0.435), (W + 88) / 2, int(H * 0.435) + 3), fill=blend(ACCENT))

    body = "Open source. Bring your own LLM."
    f_body = load_font(MANROPE_500, 44)
    bw = d.textbbox((0, 0), body, font=f_body)[2]
    d.text(((W - bw) / 2, int(H * 0.475)), body, font=f_body, fill=blend(GREY))

    f_link = load_font(MANROPE_400, 40)
    y = int(H * 0.56)
    for link in ("github.com/YofarDev/yofardev_ai", "Support the project: ko-fi.com/yofardev"):
        lw = d.textbbox((0, 0), link, font=f_link)[2]
        d.text(((W - lw) / 2, y), link, font=f_link, fill=blend(ACCENT))
        y += 84
    return img


# ---------------------------------------------------------------- audio
def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    return data.astype(np.float64) / 32768.0, sr


def resample_to(data: np.ndarray, sr: int, target: int = SR) -> np.ndarray:
    if sr == target:
        return data
    idx = (np.arange(int(len(data) * target / sr)) * sr / target).astype(int)
    return data[np.clip(idx, 0, len(data) - 1)]


def write_wav(path: Path, mono: np.ndarray, sr: int = SR) -> None:
    pcm = (np.clip(mono, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def place(track: np.ndarray, clip: np.ndarray, at_s: float, gain: float = 1.0, fade_s: float = 0.0) -> None:
    start = int(at_s * SR)
    if start >= len(track):
        return
    n = min(len(clip), len(track) - start)
    seg = clip[:n] * gain
    if fade_s > 0:
        f = min(int(fade_s * SR), n)
        seg = seg.copy()
        seg[:f] *= np.linspace(0, 1, f)
        seg[-f:] *= np.linspace(1, 0, f)
    track[start : start + n] += seg


def bed_loop(path: Path, seconds: float) -> np.ndarray:
    data, sr = read_wav(path)
    data = resample_to(data, sr)
    need = int(math.ceil(seconds * SR))
    reps = int(math.ceil(need / len(data))) + 1
    out = np.tile(data, reps)[:need]
    f = min(len(data) // 4, SR // 10)
    if need > len(data) + f:
        out[len(data) - f : len(data)] = (
            data[-f:] * np.linspace(1, 0, f) + data[:f] * np.linspace(0, 1, f)
        )
    return out


# ---------------------------------------------------------------- main
def main() -> int:
    runs: dict[tuple[str, str], dict] = {}
    for shot in SHOTS:
        key = (shot["src"], shot["run"])
        if key not in runs:
            runs[key] = load_run(shot["src"], shot["run"])

    cursor = 0.0
    plan: list[dict] = []
    for shot in SHOTS:
        run = runs[(shot["src"], shot["run"])]
        t0, t1 = resolve_window(run, shot)
        if shot.get("blend"):
            # the dissolve reads this shot's tail under the next one's head
            t1 = min(t1 + int(shot["blend"] * 1000), max(run["frames"].values()) + 300)
        length = (t1 - t0) / 1000
        plan.append({**shot, "t0": t0, "t1": t1, "len": length, "show0": cursor, "show1": cursor + length, "r": run})
        cursor += length
    end_card0 = cursor
    total = cursor + END_CARD_S
    frames_n = int(round(total * FPS))
    print(f"show: {total:.2f} s, {frames_n} frames")
    for p in plan:
        print(f"  {p['id']:<11} {p['src']}:{p['run']:<13} {p['t0']:>6}-{p['t1']:>6} ms -> {p['show0']:6.2f}-{p['show1']:6.2f} s")

    # ---- video
    if FRAMES_DIR.exists():
        for old in FRAMES_DIR.glob("*.png"):
            old.unlink()
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)
    overlays_ready = [
        {**o, "layer": text_layer(o["text"], load_font(o["font"], o["size"]), CREAM + (255,))}
        for o in OVERLAYS
    ]
    for o in overlays_ready:
        o["p"] = next(x for x in plan if x["id"] == o["shot"])

    last_frame: Image.Image | None = None
    for k in range(frames_n):
        t = k / FPS
        dest = FRAMES_DIR / f"{k:05d}.png"
        if t >= end_card0 - END_FADE_S:
            card = end_card_frame(t - end_card0)
            if t < end_card0 and last_frame is not None:
                a = (t - (end_card0 - END_FADE_S)) / END_FADE_S
                last_frame = Image.blend(last_frame.copy(), card, a)
                last_frame.save(dest)
            else:
                card.save(dest)
            continue
        covering = [p for p in plan if p["show0"] <= t < p["show1"]]
        shot = covering[0] if covering else plan[-1]
        later = covering[1] if len(covering) > 1 else None
        run = shot["r"]
        rel_ms = int((t - shot["show0"]) * 1000)
        img = to_canvas(load_frame(run, frame_at(run, shot["t0"] + rel_ms))).copy()
        if later is not None:
            blend_s = later.get("blend", 0.0)
            if blend_s > 0:
                a = (t - later["show0"]) / blend_s
                lrel = int((t - later["show0"]) * 1000)
                limg = to_canvas(load_frame(later["r"], frame_at(later["r"], later["t0"] + lrel)))
                img = Image.blend(img, limg, min(1.0, max(0.0, a)))
        for o in overlays_ready:
            if o.get("hold"):
                # one thought held across several shots: in at its own shot,
                # out at the last hold shot
                if o["p"]["id"] == shot["id"] or (
                    shot["id"] in ("campfire", "train", "space") and o["shot"] in ("campfire", "space")
                ):
                    alpha = overlay_alpha(rel_ms, o, int(shot["len"] * 1000))
                    if o["shot"] == "space" and shot["id"] != "space":
                        alpha = 1.0
                    compose_overlay(img, o["layer"], alpha)
            elif o["p"]["id"] == shot["id"]:
                compose_overlay(img, o["layer"], overlay_alpha(rel_ms, o, int(shot["len"] * 1000)))
        last_frame = img
        img.save(dest)

    # ---- poster
    p = next(x for x in plan if x["id"] == POSTER_SHOT)
    poster = to_canvas(load_frame(p["r"], frame_at(p["r"], p["t0"] + p["len"] * 1000 * POSTER_T)))
    poster.save(DELIVER / "showcase-poster.png")
    print(f"poster: {p['run']} at {POSTER_T:.0%}")

    # ---- audio. A sentence is placed once, by the shot whose run window
    # contains its caption; the clip may run past the shot's own cut (J-cut).
    track = np.zeros(int(total * SR) + SR, dtype=np.float64)
    duck = np.zeros_like(track)
    srt: list[tuple[float, float, str]] = []
    placed: set[tuple[str, int, str]] = set()
    voice_ends: dict[int, float] = {}
    for p in plan:
        run = p["r"]
        for s in run["sentences"]:
            key = (p["run"], s["t0"], s["text"])
            if key in placed or not (p["t0"] <= s["t0"] <= p["t1"]):
                continue
            placed.add(key)
            a = p["show0"] + (s["t0"] - p["t0"]) / 1000
            data = resample_to(*read_wav(s["file"]))
            peak = float(np.max(np.abs(data))) or 1.0
            data = data * (0.85 / peak)
            b = a + len(data) / SR
            clip_start = max(0.0, a)
            clip = data[int((clip_start - a) * SR):]
            place(track, clip, clip_start, 1.0, fade_s=0.02)
            duck[int(max(0.0, a) * SR):int(min(total, b) * SR)] = 1.0
            srt.append((max(0.0, a), b, s["text"]))
    srt.sort()

    env = np.clip(duck, 0, 1)
    env = np.convolve(env, np.ones(int(0.06 * SR)) / int(0.06 * SR), mode="same")
    env = 1.0 - (1.0 - env) * (1.0 - DUCK)
    track[: len(env)] *= env

    assets = OUT / "assets" / "foley"
    for p in plan:
        a0, a1 = int(p["show0"] * SR), int(p["show1"] * SR)
        ease = int(0.35 * SR)
        gain_in = np.linspace(0, 1, ease)
        gain_out = np.linspace(1, 0, ease)
        scene = p["r"]["tl"]["scene"]
        rain = p["r"]["tl"].get("rain", 0)
        span = a1 - a0

        def add_bed(name: str, gain: float) -> None:
            if gain <= 0:
                return
            bed = bed_loop(assets / f"bed_{name}.wav", span / SR) * gain
            bed[:ease] *= gain_in
            bed[-ease:] *= gain_out
            track[a0:a1] += bed[: a1 - a0]

        if scene == "campfire":
            add_bed("crackle", CRACKLE_LEVEL * (1 + 0.4 * rain))
        if rain > 0:
            add_bed("rain", RAIN_LEVEL * rain)
        if scene == "beach":
            add_bed("wind", WIND_LEVEL)

    foley_duck = 1.0 - (1.0 - env) * 0.45  # foley sits under speech too
    for p in plan:
        for e in p["r"]["events"]:
            if e["type"] != "foley":
                continue
            at = p["show0"] + (e["ms"] - p["t0"]) / 1000
            if not (p["show0"] <= at < p["show1"]):
                continue
            path = OUT / e["file"]
            if not path.exists():
                continue
            data = resample_to(*read_wav(path))
            gain = FOLEY_LEVEL * float(foley_duck[min(int(at * SR), len(foley_duck) - 1)])
            place(track, data, at, gain)

    tail_start = int(end_card0 * SR)
    tail = len(track) - tail_start
    track[tail_start:] *= np.linspace(1, 0, tail) ** 1.5
    track = track[: int(total * SR)]

    peak = float(np.max(np.abs(track)))
    if peak > 0.98:
        track *= 0.97 / peak
        print(f"audio: normalised (peak was {peak:.2f})")
    else:
        print(f"audio: peak {peak:.2f}")
    wav_path = ROOT / "work" / "show_audio.wav"
    write_wav(wav_path, track)

    # ---- encode
    mp4 = DELIVER / "showcase-vertical.mp4"
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-framerate", str(FPS), "-i", str(FRAMES_DIR / "%05d.png"),
            "-i", str(wav_path),
            "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2",
            "-movflags", "+faststart", "-shortest",
            str(mp4),
        ],
        check=True,
    )
    print(f"wrote {mp4.name}")

    # ---- srt
    def ts(t: float) -> str:
        ms = int(round(t * 1000))
        h, ms = divmod(ms, 3600000)
        m, ms = divmod(ms, 60000)
        s, ms = divmod(ms, 1000)
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

    lines = []
    for i, (a, b, text) in enumerate(srt, 1):
        text = re.sub(r"\s+", " ", re.sub(r"\[[a-z]:[^\]]*\]", "", text)).strip()
        lines.append(f"{i}\n{ts(a)} --> {ts(min(b, end_card0 + 0.5))}\n{text}\n")
    (DELIVER / "showcase-captions.srt").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote showcase-captions.srt ({len(srt)} cues)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
