"""Generated foley and ambient beds for the avatar's Rive events (moonshot M8 ruling 11).

No bought assets: every sound is synthesised from a fixed seed with numpy and written as a
22.05 kHz mono 16-bit WAV into ``assets/foley/``:

- ``step_0..3``: a low thump (a falling sine) plus gravel grains, 120 ms;
- ``cloth_0..1``: a band-passed noise swish, 350 ms;
- ``click_0``: a two-tick latch, 50 ms;
- ``paper_0..1``: crinkle bursts, 300 ms;
- ``bed_crackle``: pops and hiss over brown noise, a seamless 8 s loop;
- ``bed_rain``: pink noise and sparse drops, a seamless 8 s loop.

The beds are built circularly (noise shaped in the frequency domain over exactly the loop length,
events added modulo the length), so the last sample runs into the first as if the loop never ended.
Every peak sits below -1 dBFS; the whole set stays under 900 KB.

Run: ``uv run --with numpy rive/tools/gen_foley.py [--out DIR]``.
"""

from __future__ import annotations

import argparse
from collections.abc import Callable
from pathlib import Path
import wave

import numpy as np

RATE = 22050
SEED = 8_2026
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "foley"

# target peaks (dBFS): short sounds near full scale, beds quieter (the app mixes them low)
SHORT_PEAK_DB = -1.5
BED_PEAK_DB = -3.0
MAX_TOTAL_BYTES = 900 * 1024

# lengths in ms (ruling 11)
STEP_MS = 120
CLOTH_MS = 350
CLICK_MS = 50
PAPER_MS = 300
BED_MS = 8000


def _n(ms: float) -> int:
    return int(round(RATE * ms / 1000.0))


def _db(db: float) -> float:
    return float(10 ** (db / 20.0))


def _normalise(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = float(np.max(np.abs(x)))
    if peak <= 0:
        return x
    return x * (_db(peak_db) / peak)


def _band(x: np.ndarray, lo: float, hi: float, *, tilt: float = 0.0) -> np.ndarray:
    """Band-limits ``x`` to ``lo``..``hi`` Hz in the frequency domain (soft 1-octave skirts), with an
    optional spectral ``tilt`` (power of 1/f: 0.5 pink, 1 brown). Circular over ``len(x)``."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    f_safe = np.maximum(f, 1.0)
    gain = np.ones_like(f)
    if lo > 0:
        gain *= 1.0 / (1.0 + (lo / f_safe) ** 4)
    if hi > 0:
        gain *= 1.0 / (1.0 + (f_safe / hi) ** 4)
    if tilt:
        gain *= f_safe ** (-tilt)
    gain[0] = 0.0
    return np.fft.irfft(spec * gain, n=len(x))


def _fade(x: np.ndarray, in_ms: float, out_ms: float) -> np.ndarray:
    y = x.copy()
    a, b = _n(in_ms), _n(out_ms)
    if a:
        y[:a] *= np.linspace(0.0, 1.0, a)
    if b:
        y[-b:] *= np.linspace(1.0, 0.0, b) ** 2
    return y


def _burst(rng: np.random.Generator, length: int, decay_ms: float) -> np.ndarray:
    """A noise grain with an exponential decay."""
    t = np.arange(length) / RATE
    return rng.standard_normal(length) * np.exp(-t / (decay_ms / 1000.0))


def step(rng: np.random.Generator, variant: int) -> np.ndarray:
    """A footfall: a 60-90 Hz thump with a falling pitch, and gravel grains after the heel."""
    n = _n(STEP_MS)
    t = np.arange(n) / RATE
    f0 = 62.0 + 9.0 * variant + rng.uniform(-3, 3)
    freq = f0 * (1.0 + 0.9 * np.exp(-t / 0.012))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    thump = np.sin(phase) * np.exp(-t / 0.035) * (1 - np.exp(-t / 0.002))
    gravel = np.zeros(n)
    for _ in range(int(rng.integers(9, 15))):
        at = int(rng.uniform(0.004, 0.075) * RATE)
        size = _n(rng.uniform(2.0, 6.0))
        if at + size > n:
            continue
        gravel[at:at + size] += _burst(rng, size, rng.uniform(0.6, 1.6)) * rng.uniform(0.3, 1.0)
    gravel = _band(gravel, 1400.0 + 200 * variant, 5200.0)
    gravel *= np.exp(-t / 0.05)
    x = thump + 0.55 * gravel / max(1e-9, float(np.max(np.abs(gravel))))
    return _normalise(_fade(x, 0.5, 12), SHORT_PEAK_DB)


def cloth(rng: np.random.Generator, variant: int) -> np.ndarray:
    """A swish: band-passed noise whose band rises and falls, under a smooth rise-fall envelope."""
    n = _n(CLOTH_MS)
    t = np.arange(n) / (n - 1)
    lo, hi = (500.0, 2600.0) if variant == 0 else (700.0, 3400.0)
    x = _band(rng.standard_normal(n), lo, hi)
    # a slow second layer, lower: the coat's weight
    x += 0.6 * _band(rng.standard_normal(n), 180.0, 900.0)
    peak_at = 0.38 if variant == 0 else 0.3
    env = np.where(t < peak_at, (t / peak_at) ** 1.6, ((1 - t) / (1 - peak_at)) ** 2.2)
    # a little flutter (the fabric catching)
    env *= 1.0 + 0.25 * np.sin(2 * np.pi * (9 + 3 * variant) * t * CLOTH_MS / 1000.0)
    return _normalise(_fade(x * env, 2, 20), SHORT_PEAK_DB)


def click(rng: np.random.Generator) -> np.ndarray:
    """A latch: two short ticks 22 ms apart, the second softer and a little lower."""
    n = _n(CLICK_MS)
    x = np.zeros(n)
    for at_ms, gain, ring in ((1.0, 1.0, 3100.0), (23.0, 0.65, 2500.0)):
        at = _n(at_ms)
        size = _n(6.0)
        t = np.arange(size) / RATE
        tick = _burst(rng, size, 0.5) + 0.8 * np.sin(2 * np.pi * ring * t) * np.exp(-t / 0.0015)
        x[at:at + size] += gain * tick
    x = _band(x, 900.0, 9000.0)
    return _normalise(_fade(x, 0.2, 8), SHORT_PEAK_DB)


def paper(rng: np.random.Generator, variant: int) -> np.ndarray:
    """A crinkle: dense, uneven bursts of broadband crackles under a rise-fall density."""
    n = _n(PAPER_MS)
    x = np.zeros(n)
    count = int(rng.integers(55, 80)) + 15 * variant
    for _ in range(count):
        at = int(rng.beta(2.0, 2.6) * (n - 1))
        size = _n(rng.uniform(0.6, 3.5))
        if at + size > n:
            continue
        x[at:at + size] += _burst(rng, size, rng.uniform(0.3, 1.2)) * rng.uniform(0.15, 1.0) ** 2
    x = _band(x, 1100.0, 8500.0)
    # the sheet's body: a faint low rustle under the crackles
    t = np.arange(n) / (n - 1)
    x += 0.08 * float(np.max(np.abs(x))) * _band(rng.standard_normal(n), 300.0, 1500.0) * np.sin(np.pi * t)
    return _normalise(_fade(x, 1, 15), SHORT_PEAK_DB)


def _add_circular(buf: np.ndarray, at: int, grain: np.ndarray) -> None:
    idx = (at + np.arange(len(grain))) % len(buf)
    np.add.at(buf, idx, grain)


def bed_crackle(rng: np.random.Generator) -> np.ndarray:
    """The campfire: brown-noise rumble, a soft hiss and random pops (some big cracks)."""
    n = _n(BED_MS)
    rumble = _band(rng.standard_normal(n), 30.0, 600.0, tilt=1.0)
    rumble /= float(np.max(np.abs(rumble)))
    hiss = _band(rng.standard_normal(n), 2500.0, 9000.0)
    hiss /= float(np.max(np.abs(hiss)))
    pops = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / 7.0)
        if t >= BED_MS / 1000.0:
            break
        big = rng.random() < 0.12
        size = _n(rng.uniform(8.0, 20.0) if big else rng.uniform(1.5, 5.0))
        grain = _burst(rng, size, rng.uniform(2.0, 5.0) if big else rng.uniform(0.3, 1.0))
        _add_circular(pops, int(t * RATE), grain * (rng.uniform(0.6, 1.0) if big else rng.uniform(0.15, 0.6)))
    pops = _band(pops, 400.0, 8000.0)
    pops /= float(np.max(np.abs(pops)))
    x = 0.35 * rumble + 0.06 * hiss + 0.75 * pops
    return _normalise(x, BED_PEAK_DB)


def bed_rain(rng: np.random.Generator) -> np.ndarray:
    """Steady rain: pink noise (no rumble) and sparse, bright drops."""
    n = _n(BED_MS)
    wash = _band(rng.standard_normal(n), 250.0, 7000.0, tilt=0.5)
    wash /= float(np.max(np.abs(wash)))
    drops = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / 14.0)
        if t >= BED_MS / 1000.0:
            break
        size = _n(rng.uniform(3.0, 9.0))
        ts = np.arange(size) / RATE
        ring = rng.uniform(1800.0, 4200.0)
        grain = np.sin(2 * np.pi * ring * ts) * np.exp(-ts / rng.uniform(0.0008, 0.0025))
        _add_circular(drops, int(t * RATE), grain * rng.uniform(0.2, 1.0))
    drops /= float(np.max(np.abs(drops)))
    x = 0.8 * wash + 0.35 * drops
    return _normalise(x, BED_PEAK_DB)


def sounds() -> dict[str, np.ndarray]:
    """Every foley file, by name (no extension), from the fixed seed."""
    rng = np.random.default_rng(SEED)
    out: dict[str, np.ndarray] = {}
    for k in range(4):
        out[f"step_{k}"] = step(rng, k)
    for k in range(2):
        out[f"cloth_{k}"] = cloth(rng, k)
    out["click_0"] = click(rng)
    for k in range(2):
        out[f"paper_{k}"] = paper(rng, k)
    out["bed_crackle"] = bed_crackle(rng)
    out["bed_rain"] = bed_rain(rng)
    return out


def to_pcm16(x: np.ndarray) -> bytes:
    return (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes()


def write_wav(path: Path, x: np.ndarray) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(to_pcm16(x))


def generate(out_dir: Path = OUT_DIR, log: Callable[[str], None] | None = print) -> dict[str, Path]:
    """Writes every sound into ``out_dir``; returns name -> path. Raises if over the size budget."""
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: dict[str, Path] = {}
    for name, x in sounds().items():
        path = out_dir / f"{name}.wav"
        write_wav(path, x)
        paths[name] = path
    total = sum(p.stat().st_size for p in paths.values())
    if total > MAX_TOTAL_BYTES:
        raise SystemExit(f"foley over budget: {total} B > {MAX_TOTAL_BYTES} B")
    if log is not None:
        log(f"wrote {len(paths)} files, {total} B, into {out_dir}")
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT_DIR, help="output directory (default assets/foley)")
    args = parser.parse_args()
    generate(args.out)


if __name__ == "__main__":
    main()
