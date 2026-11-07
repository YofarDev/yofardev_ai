"""Mixes the score stems into score.wav (48 kHz stereo, ~-16 LUFS).

    uv run --with pedalboard --with soundfile --with numpy --with pyloudnorm python mix.py
"""

from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import (Chorus, Compressor, Gain, HighpassFilter, HighShelfFilter,
                        Limiter, LowShelfFilter, Pedalboard, PeakFilter, Reverb)

HERE = Path(__file__).parent
import json
EDIT_S = sum(x["bars"] for x in json.loads((HERE / "sections.json").read_text())) * 2.5
SR = 48000

# stem: (gain dB, pan -1..1 as width tweak, chain)
CHAINS = {
    "keys": (5.0, Pedalboard([HighpassFilter(60), PeakFilter(300, -2.5, 1.0),
                               HighShelfFilter(6000, -2.0),
                               Reverb(room_size=0.78, damping=0.55, wet_level=0.22,
                                      dry_level=0.85, width=1.0)])),
    "bells": (6.0, Pedalboard([HighpassFilter(400), HighShelfFilter(9000, -3.0),
                                Reverb(room_size=0.9, damping=0.35, wet_level=0.38,
                                       dry_level=0.7, width=1.0)])),
    "strings": (-2.5, Pedalboard([HighpassFilter(55), LowShelfFilter(160, -4.0), PeakFilter(2500, 1.5, 0.8),
                                  Chorus(rate_hz=0.3, depth=0.12, mix=0.18),
                                  Reverb(room_size=0.88, damping=0.5, wet_level=0.3,
                                         dry_level=0.8, width=1.0)])),
    "pizz": (4.0, Pedalboard([HighpassFilter(90),
                               Reverb(room_size=0.7, damping=0.5, wet_level=0.25,
                                      dry_level=0.85)])),
    "winds": (-6.0, Pedalboard([HighpassFilter(150), PeakFilter(3000, -1.5, 1.0),
                                Reverb(room_size=0.85, damping=0.45, wet_level=0.32,
                                       dry_level=0.75, width=1.0)])),
    "air": (-3.0, Pedalboard([HighpassFilter(120), LowShelfFilter(250, -3.0),
                              Chorus(rate_hz=0.2, depth=0.25, mix=0.35),
                              Reverb(room_size=0.95, damping=0.3, wet_level=0.5,
                                     dry_level=0.55, width=1.0)])),
    "perc": (-1.0, Pedalboard([HighpassFilter(30), PeakFilter(4000, -2.0, 1.0),
                               Compressor(threshold_db=-14, ratio=2.5, attack_ms=8,
                                          release_ms=120),
                               Reverb(room_size=0.75, damping=0.6, wet_level=0.2,
                                      dry_level=0.9, width=0.9)])),
}


def load(name):
    a, sr = sf.read(HERE / "stems" / f"{name}.wav", dtype="float32")
    assert sr == SR
    return a.T.copy()


def main():
    stems = {}
    length = 0
    for name, (gain, chain) in CHAINS.items():
        x = load(name)
        y = chain(x, SR) * (10 ** (gain / 20))
        stems[name] = y
        length = max(length, y.shape[1])
    mix = np.zeros((2, length), dtype=np.float32)
    for y in stems.values():
        mix[:, : y.shape[1]] += y
    master = Pedalboard([
        HighpassFilter(28),
        PeakFilter(220, -1.5, 0.9),
        HighShelfFilter(10000, 1.0),
        Compressor(threshold_db=-20, ratio=1.8, attack_ms=25, release_ms=250),
        Gain(0),
    ])
    mix = master(mix, SR)
    meter = pyln.Meter(SR)
    lufs = meter.integrated_loudness(mix.T)
    mix *= 10 ** ((-16.0 - lufs) / 20)
    # JUCE's limiter makes up its threshold: -2 dB in, ceiling 0 dBFS out,
    # then down 1.5 dB (true peak headroom)
    mix = Pedalboard([Limiter(threshold_db=-2.0, release_ms=120)])(mix, SR)
    lufs = meter.integrated_loudness(mix.T)
    mix *= 10 ** ((-16.0 - lufs) / 20)
    peak = np.abs(mix).max()
    if peak > 10 ** (-1.0 / 20):
        mix *= 10 ** (-1.0 / 20) / peak
    # the edit's length + 1 s, fading over its last 4 s
    n = min(mix.shape[1], int((EDIT_S + 1.0) * SR))
    mix = mix[:, :n]
    fade = np.ones(n, dtype=np.float32)
    f0 = n - int(4.0 * SR)
    fade[f0:] = np.linspace(1, 0, n - f0) ** 2
    mix *= fade
    sf.write(HERE / "score.wav", mix.T, SR, subtype="PCM_24")
    print("score.wav", f"{meter.integrated_loudness(mix.T):.1f} LUFS",
          f"peak {20 * np.log10(np.abs(mix).max()):.1f} dBFS")
    for name, y in stems.items():
        r = np.sqrt(np.mean(y ** 2)) + 1e-9
        print(f"  {name:8s} rms {20 * np.log10(r):6.1f} dB")


if __name__ == "__main__":
    main()
