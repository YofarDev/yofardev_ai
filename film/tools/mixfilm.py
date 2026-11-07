"""The film's soundtrack: score + the app's own voice and foley (placed by the
edit's regions) + ambient beds + designed hits, ducked and mastered to
-14 LUFS. Writes film/work/soundtrack.wav.

    (cd film/video && npx -y tsx scripts/edl.ts > ../work/edl.json)
    uv run --with numpy --with soundfile --with scipy --with pedalboard \
        --with pyloudnorm python -I film/tools/mixfilm.py
"""

import json
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import (Compressor, HighpassFilter, HighShelfFilter, Limiter,
                        LowpassFilter, Pedalboard, PeakFilter, Reverb)
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
WORK = ROOT / "work"
CLIPS = WORK / "clips"
SR = 48000
FPS = 60
rng = np.random.default_rng(3)


def load(path):
    a, sr = sf.read(path, dtype="float32", always_2d=True)
    if sr != SR:
        from scipy.signal import resample_poly
        g = np.gcd(sr, SR)
        a = resample_poly(a, SR // g, sr // g, axis=0).astype(np.float32)
    if a.shape[1] == 1:
        a = np.repeat(a, 2, axis=1)
    return a


def at(frame):
    return int(round(frame / FPS * SR))


def place(track, clip, i, gain=1.0):
    if i < 0:
        clip, i = clip[-i:], 0
    n = min(len(clip), len(track) - i)
    if n > 0:
        track[i:i + n] += clip[:n] * gain


def ramp(n, fade):
    g = np.ones(n, dtype=np.float32)
    f = min(fade, n // 2)
    if f > 0:
        g[:f] = np.linspace(0, 1, f)
        g[-f:] = np.linspace(1, 0, f)
    return g[:, None]


# ---------------------------------------------------------------- designed sfx
def bandnoise(n, lo, hi):
    sos = butter(4, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, rng.standard_normal(n)).astype(np.float32)


def whoosh(dur=0.9):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    env = np.sin(np.pi * t) ** 2.2
    # a cutoff sweep: blend a low and a high band across the swell
    lo = bandnoise(n, 200, 900)
    hi = bandnoise(n, 1500, 6000)
    x = (lo * (1 - t) + hi * t * 0.6) * env
    pan = t
    out = np.stack([x * (1 - 0.5 * pan), x * (0.5 + 0.5 * pan)], axis=1)
    return out / (np.abs(out).max() + 1e-9) * 0.5


def boom(dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 52 * np.exp(-t * 0.35) + 30
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 1.6)
    click = bandnoise(n, 60, 2500) * np.exp(-t * 40) * 0.6
    x = (body + click).astype(np.float32)
    out = np.stack([x, x], axis=1)
    return out / np.abs(out).max() * 0.8


def riser(dur=2.5):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    env = t ** 2.4
    noise = bandnoise(n, 800, 9000) * env * 0.5
    f = 180 + 900 * t ** 2
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * env * 0.25
    x = (noise + tone).astype(np.float32)
    out = np.stack([x, np.roll(x, 240)], axis=1)
    return out / np.abs(out).max() * 0.55


def shimmer(dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n, dtype=np.float32)
    for k, f in enumerate([1174.66, 1479.98, 1760.0, 2349.32, 2959.96, 3520.0]):
        d = k * 0.045
        tt = np.clip(t - d, 0, None)
        x += (np.sin(2 * np.pi * f * tt) * np.exp(-tt * 1.6) * (t >= d) * (0.9 ** k)).astype(np.float32)
    out = np.stack([x, x], axis=1)
    out = Pedalboard([Reverb(room_size=0.9, wet_level=0.5, dry_level=0.6)])(out.T, SR).T
    return out / np.abs(out).max() * 0.35


def tick():
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    x = bandnoise(n, 1800, 7000) * np.exp(-t * 300)
    out = np.stack([x, x], axis=1)
    return out / np.abs(out).max() * 0.18


SFX = {"whoosh": whoosh(), "boom": boom(), "riser": riser(), "shimmer": shimmer()}


def main():
    edl = json.loads((WORK / "edl.json").read_text())
    total_frames = sum(s["dur"] for s in edl["sections"])
    n = at(total_frames) + SR
    score = load(ROOT / "music" / "score.wav")
    music = np.zeros((n, 2), dtype=np.float32)
    place(music, score, 0)
    # the film's dynamics: a hushed open, the climax on top, a quiet hood
    SECTION_DB = {"cold": -5, "title": 0, "listen": -1.5, "tools": -1.5, "wardrobe": -1,
                  "journey": 0, "world": 1.5, "hood": -3.5, "finale": -1.5}
    env = np.zeros(n, dtype=np.float32)
    for sct in edl["sections"]:
        a0, a1 = at(sct["from"]), at(sct["from"] + sct["dur"])
        env[a0:a1] = SECTION_DB.get(sct["id"], 0)
    env[at(total_frames):] = env[at(total_frames) - 1]
    k = int(0.6 * SR)  # 0.6 s glides between sections
    env = np.convolve(env, np.ones(k) / k, mode="same")
    music *= (10 ** (env / 20))[:, None]
    voice = np.zeros_like(music)
    foley = np.zeros_like(music)
    beds = np.zeros_like(music)
    sfx = np.zeros_like(music)

    events = json.loads((ROOT / "video" / "src" / "data" / "events.json").read_text())
    cache = {}
    for r in edl["regions"]:
        tag = r["tag"]
        if tag not in cache:
            v = CLIPS / f"{tag}_voice.wav"
            f = CLIPS / f"{tag}_foley.wav"
            cache[tag] = (load(v) if v.exists() else None, load(f) if f.exists() else None)
        v, f = cache[tag]
        i0 = int(r["atMs"] / 1000 * SR)
        length = at(r["frames"])
        g = ramp(length, int(0.02 * SR))
        dst = at(r["at"])
        for src, track, gain in ((v, voice, r["voice"]), (f, foley, r["foley"])):
            if src is None or gain == 0:
                continue
            seg = src[max(0, i0):max(0, i0) + length]
            place(track, seg * g[: len(seg)], dst, gain)
        if r.get("bed"):
            bed = load(REPO / "assets" / "foley" / f"{r['bed']}.wav")
            reps = int(np.ceil(length / len(bed))) + 1
            loop = np.tile(bed, (reps, 1))[:length]
            place(beds, loop * ramp(length, int(0.4 * SR)), dst, r["bedLevel"])
        # typing ticks: the user's keys between each typing and send
        evs = events.get(tag, {}).get("events", [])
        typings = [e["ms"] for e in evs if e["type"] == "typing"]
        sends = [e["ms"] for e in evs if e["type"] == "send"]
        for ty in typings:
            se = next((s for s in sends if s > ty), None)
            if se is None:
                continue
            a, b = ty + 380, se - 420
            k = 0
            rate = r.get("rate", 1)
            for ms in np.arange(a, b, 82):
                if r["atMs"] <= ms < r["atMs"] + r["frames"] / FPS * 1000 * rate:
                    j = dst + int((ms - r["atMs"]) / rate / 1000 * SR)
                    place(sfx, tick(), j, 0.5 + 0.3 * rng.random())
                    k += 1

    for h in edl["hits"]:
        clip = SFX[h["kind"]]
        start = at(h["at"])
        if h["kind"] == "riser":
            start -= len(clip)  # ends on the downbeat
            start += at(150)
        place(sfx, clip, start, h["gain"])

    # voice chain: clean + presence + a touch of room
    voice = Pedalboard([HighpassFilter(90), PeakFilter(3200, 2.0, 1.0), HighShelfFilter(9000, 1.0),
                        Compressor(threshold_db=-20, ratio=2.5, attack_ms=5, release_ms=120),
                        Reverb(room_size=0.25, wet_level=0.07, dry_level=0.95)])(voice.T, SR).T
    foley = Pedalboard([HighpassFilter(60), Reverb(room_size=0.3, wet_level=0.12, dry_level=0.9)])(foley.T, SR).T
    beds = Pedalboard([LowpassFilter(9000)])(beds.T, SR).T

    # duck the music under the voice (and a little under the beds)
    env = np.abs(voice).max(axis=1)
    win = int(0.02 * SR)
    env = np.sqrt(np.convolve(env ** 2, np.ones(win) / win, mode="same"))
    target = 1 - 0.58 * np.clip(env / 0.06, 0, 1)
    g = np.empty_like(target)
    att, rel = np.exp(-1 / (0.06 * SR)), np.exp(-1 / (0.45 * SR))
    y = 1.0
    for i in range(len(target)):
        x = target[i]
        c = att if x < y else rel
        y = c * y + (1 - c) * x
        g[i] = y
    music *= g[:, None]

    meter = pyln.Meter(SR)
    vl = meter.integrated_loudness(voice) if np.abs(voice).max() > 0 else -70
    print(f"voice {vl:.1f} LUFS (in-voice-regions)")

    mix = music * 1.0 + voice * 1.15 + foley * 0.9 + beds * 1.0 + sfx * 0.8
    mix = Pedalboard([Compressor(threshold_db=-18, ratio=1.6, attack_ms=20, release_ms=200)])(mix.T, SR).T
    lufs = meter.integrated_loudness(mix)
    mix *= 10 ** ((-14.0 - lufs) / 20)
    mix = Pedalboard([Limiter(threshold_db=-1.5, release_ms=100)])(mix.T, SR).T
    lufs = meter.integrated_loudness(mix)
    mix *= 10 ** ((-14.0 - lufs) / 20)
    peak = np.abs(mix).max()
    if peak > 10 ** (-1.0 / 20):
        mix *= 10 ** (-1.0 / 20) / peak
    mix = mix[: at(total_frames)]
    sf.write(WORK / "soundtrack.wav", mix, SR, subtype="PCM_24")
    print("soundtrack.wav", f"{meter.integrated_loudness(mix):.1f} LUFS",
          f"peak {20 * np.log10(np.abs(mix).max()):.1f} dBFS", f"{len(mix) / SR:.1f}s")


if __name__ == "__main__":
    main()
