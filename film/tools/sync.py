"""Cuts a run's window out of its 60 fps screen recording, synced to the
run's timeline (ms 0 = the harness clock start).

    uv run --with numpy --with pillow python -I film/tools/sync.py <TAG>

Reads film/work/cap/<TAG>.mov (+ .recstart) and the run's timeline.json with
its sparse in-app grabs (PXR 0.25), finds the window's content rect and the
recording time of each grab by image matching, and writes
film/work/clips/<TAG>.mp4 (content only, 60 fps, timeline ms 0 at t = 0)
plus <TAG>.json (offset, rect, fit residuals).
"""

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAP = ROOT / "work" / "cap"
CLIPS = ROOT / "work" / "clips"
CLIPS.mkdir(parents=True, exist_ok=True)


def frames_at(mov, t0, dur, fps, scale_w):
    """Grey frames (float32) of the recording from t0, at fps, width scale_w."""
    h = int(round(1080 * scale_w / 1920))
    cmd = ["ffmpeg", "-loglevel", "error", "-ss", f"{t0:.3f}", "-i", str(mov),
           "-t", f"{dur:.3f}", "-vf", f"fps={fps},scale={scale_w}:{h},format=gray",
           "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    a = np.frombuffer(raw, dtype=np.uint8).reshape(-1, h, scale_w).astype(np.float32)
    return a


def grab(run_dir, i, size):
    w, h = size
    d = (run_dir / "frames" / f"{i:04d}.rgba").read_bytes()
    im = Image.frombytes("RGBA", (w, h), d).convert("L")
    return np.asarray(im, dtype=np.float32)


def main(tag):
    mov = CAP / f"{tag}.mov"
    rec_start = int((CAP / f"{tag}.recstart").read_text().strip())
    runs = list((CAP / tag / "wow").iterdir())
    run_dir = runs[0]
    tl = json.loads((run_dir / "timeline.json").read_text())
    gw, gh = int(tl["size"][0]), int(tl["size"][1])
    frames = tl["frames"]
    approx = (tl["clockStartEpochMs"] - rec_start) / 1000.0
    # content size in recording px (the grab is PXR 0.25 of the logical size)
    cw, ch = round(gw * 4), round(gh * 4)

    # 1) the content rect: the window is parked at a known spot (centred on
    # the display, under the menu and title bars); check it against several
    # probe grabs, and search the frame only if it does not match
    def score_at(f, x, y):
        p = f[y:y + gh, x:x + gw]
        if p.shape != (gh, gw) or p.std() < 1:
            return -1.0
        return float(((p - p.mean()) / p.std() * gz).mean())

    probes = [frames[int(len(frames) * q)] for q in (0.2, 0.35, 0.5, 0.65, 0.8)]
    exp = ((1920 - cw) // 2 // 4, 60 // 4)
    best = (-1.0, exp[0], exp[1], probes[0])
    for pr in probes:
        g = grab(run_dir, pr["i"], (gw, gh))
        gz = (g - g.mean()) / (g.std() + 1e-6)
        for dt in (-0.3, 0.0, 0.3):
            f = frames_at(mov, max(0, approx + pr["ms"] / 1000 + dt), 0.02, 60, 480)[0]
            H, W = f.shape
            for y in range(max(0, exp[1] - 3), min(H - gh, exp[1] + 3) + 1):
                for x in range(max(0, exp[0] - 3), min(W - gw, exp[0] + 3) + 1):
                    sc = score_at(f, x, y)
                    if sc > best[0]:
                        best = (sc, x, y, pr)
    if best[0] < 0.75:  # not where expected: search the whole frame
        pr = probes[2]
        g = grab(run_dir, pr["i"], (gw, gh))
        gz = (g - g.mean()) / (g.std() + 1e-6)
        f = frames_at(mov, max(0, approx + pr["ms"] / 1000), 0.02, 60, 480)[0]
        H, W = f.shape
        for y in range(0, H - gh + 1):
            for x in range(0, W - gw + 1):
                sc = score_at(f, x, y)
                if sc > best[0]:
                    best = (sc, x, y, pr)
    _, x0, y0, mid = best
    t_mid = approx + mid["ms"] / 1000
    g = grab(run_dir, mid["i"], (gw, gh))
    print("coarse rect", x0 * 4, y0 * 4, "score", round(best[0], 3))

    # 2) refine at full scale: the rect's left/top within ±4 px
    def full_frame(t):
        cmd = ["ffmpeg", "-loglevel", "error", "-ss", f"{t:.3f}", "-i", str(mov),
               "-frames:v", "1", "-vf", "format=gray", "-f", "rawvideo", "-"]
        raw = subprocess.run(cmd, capture_output=True, check=True).stdout
        return np.frombuffer(raw, dtype=np.uint8).reshape(1080, 1920).astype(np.float32)

    ff = full_frame(t_mid)
    gup = np.asarray(Image.fromarray(g.astype(np.uint8)).resize((cw, ch), Image.BILINEAR),
                     dtype=np.float32)
    gupz = (gup - gup.mean()) / gup.std()
    best = (-1e9, 0, 0)
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            X, Y = x0 * 4 + dx, y0 * 4 + dy
            if X < 0 or Y < 0 or X + cw > 1920 or Y + ch > 1080:
                continue
            p = ff[Y:Y + ch, X:X + cw]
            s = float(((p - p.mean()) / (p.std() + 1e-6) * gupz).mean())
            if s > best[0]:
                best = (s, X, Y)
    _, X, Y = best
    print("rect", X, Y, cw, ch, "score", round(best[0], 3))

    # 3) time: each grab's best recording frame within ±1.2 s of the estimate
    small_w = 480
    sx, sy, sw, sh = X / 4, Y / 4, cw / 4, ch / 4
    offsets = []
    picks = frames[3:-3:max(1, len(frames) // 80)]
    for fr in picks:
        t_est = approx + fr["ms"] / 1000
        win = frames_at(mov, max(0, t_est - 1.2), 2.4, 60, small_w)
        crop = win[:, int(round(sy)):int(round(sy)) + gh, int(round(sx)):int(round(sx)) + gw]
        if crop.shape[1] != gh or crop.shape[2] != gw:
            continue
        gg = grab(run_dir, fr["i"], (gw, gh))
        err = ((crop - gg[None]) ** 2).mean(axis=(1, 2))
        k = int(np.argmin(err))
        # need a distinct minimum (motion), else skip
        if np.sort(err)[min(5, len(err) - 1)] < err[k] * 1.15:
            continue
        offsets.append(max(0, t_est - 1.2) + k / 60 - fr["ms"] / 1000)
    offsets = np.array(offsets)
    off = float(np.median(offsets))
    print(f"offset {off:.3f}s (approx {approx:.3f}), n={len(offsets)}, "
          f"spread {np.percentile(offsets, 75) - np.percentile(offsets, 25):.3f}s")

    # 4) cut: from the clock start to the last sample, content only
    # exact 9:16 (the window's content may be a few px off)
    ow = int(round(ch * 9 / 16 / 2) * 2)
    oh = ch - ch % 2
    ox = X + (cw - ow) // 2
    end_ms = tl["samples"][-1]["ms"] if tl["samples"] else frames[-1]["ms"]
    dur = end_ms / 1000 + 1.0
    out = CLIPS / f"{tag}.mp4"
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{off:.3f}", "-i", str(mov),
         "-t", f"{dur:.3f}", "-vf", f"crop={ow}:{oh}:{ox}:{Y},fps=60,format=yuv420p",
         "-c:v", "libx264", "-preset", "slow", "-crf", "12", "-g", "30",
         "-movflags", "+faststart", "-an", str(out)], check=True)
    (CLIPS / f"{tag}.json").write_text(json.dumps({
        "offset": off, "approx": approx, "rect": [int(X), int(Y), int(cw), int(ch)],
        "n": len(offsets), "offsets": offsets.round(4).tolist(), "duration": dur,
        "run": str(run_dir),
    }, indent=1))
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
