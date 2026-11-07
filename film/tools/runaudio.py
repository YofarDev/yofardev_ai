"""Rebuilds a run's sound on its timeline (ms 0 = the harness clock start):
the Kokoro sentence WAVs at their playback `start` events, and the app's
foley at the logged times. Writes film/work/clips/<TAG>_voice.wav and
<TAG>_foley.wav (48 kHz stereo float).

    uv run --with numpy --with soundfile --with scipy python -I film/tools/runaudio.py <TAG>
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
CAP = ROOT / "work" / "cap"
CLIPS = ROOT / "work" / "clips"
SR = 48000


def load(path):
    a, sr = sf.read(path, dtype="float32", always_2d=True)
    if sr != SR:
        g = np.gcd(sr, SR)
        a = resample_poly(a, SR // g, sr // g, axis=0).astype(np.float32)
    if a.shape[1] == 1:
        a = np.repeat(a, 2, axis=1)
    return a


def place(track, clip, ms, gain=1.0):
    i = int(round(ms / 1000 * SR))
    if i < 0:
        clip, i = clip[-i:], 0
    n = min(len(clip), len(track) - i)
    if n > 0:
        track[i:i + n] += clip[:n] * gain


def main(tag):
    run_dir = next((CAP / tag / "wow").iterdir())
    tl = json.loads((run_dir / "timeline.json").read_text())
    dur = (tl["samples"][-1]["ms"] / 1000 if tl["samples"] else 60) + 4
    voice = np.zeros((int(dur * SR), 2), dtype=np.float32)
    foley = np.zeros_like(voice)
    starts = [e for e in tl["events"] if e["type"] == "start"]
    audio = tl["audio"]
    if len(starts) != len(audio):
        print(f"warning: {len(starts)} starts for {len(audio)} sentences")
    log = []
    for e, a in zip(starts, audio):
        f = Path(a["file"])
        fx = f.with_name(f.stem + "_fx.wav")
        clip = load(fx if fx.exists() else f)
        place(voice, clip, e["ms"])
        log.append((e["ms"], round(len(clip) / SR, 2), a["text"]))
    for e in tl["events"]:
        if e["type"] == "foley":
            p = REPO / e["file"]
            if p.exists():
                place(foley, load(p), e["ms"], 0.8)
    sf.write(CLIPS / f"{tag}_voice.wav", voice, SR, subtype="FLOAT")
    sf.write(CLIPS / f"{tag}_foley.wav", foley, SR, subtype="FLOAT")
    for row in log:
        print(*row)


if __name__ == "__main__":
    main(sys.argv[1])
