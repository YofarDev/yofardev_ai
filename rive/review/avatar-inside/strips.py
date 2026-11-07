"""Per-journey strips of the exit and enter beats from a wow tour capture: one row per (journey, beat)."""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
step = int(sys.argv[3]) if len(sys.argv) > 3 else 3
only = sys.argv[4].split(",") if len(sys.argv) > 4 else None
t = json.load(open(os.path.join(src, "timeline.json")))
frames = t["frames"]
samples = t["samples"]
fpath = os.path.join(src, "frames")
nbytes = os.path.getsize(os.path.join(fpath, "0000.rgba"))
w = int(t["size"][0])
h = int(t["size"][1])
scale = int(round((nbytes / 4 / (w * h)) ** 0.5))
W, H = w * scale, h * scale


def sample_at(ms):
    best = min(samples, key=lambda s: abs(s["ms"] - ms))
    return best


rows = {}
for f in frames:
    s = sample_at(f["ms"])
    if s.get("journey") in ("exit", "enter", "close", "arriveOpen"):
        key = (s["family"], s["journey"] if s["journey"] in ("exit", "enter") else
               ("exit" if s["journey"] == "close" else "enter"))
        rows.setdefault(key, []).append((f, s))

TW = 270
TH = int(TW * H / W)
lines = []
for (fam, beat), items in rows.items():
    if only and f"{fam}:{beat}" not in only:
        continue
    picked = [it for it in items if it[1]["journey"] in ("exit", "enter")][::step][:16]
    tiles = []
    for f, s in picked:
        raw = np.fromfile(os.path.join(fpath, f"{f['i']:04d}.rgba"), dtype=np.uint8).reshape(H, W, 4)
        im = Image.fromarray(raw, "RGBA").convert("RGB").resize((TW, TH))
        ImageDraw.Draw(im).text((4, 4), f"{fam} {beat} {f['ms']}", fill=(255, 255, 0))
        tiles.append(im)
    if tiles:
        row = Image.new("RGB", (TW * len(tiles), TH))
        for k, im in enumerate(tiles):
            row.paste(im, (k * TW, 0))
        lines.append(row)
sheet = Image.new("RGB", (max(r.width for r in lines), TH * len(lines)))
for k, r in enumerate(lines):
    sheet.paste(r, (0, k * TH))
sheet.save(out)
print(out, sheet.size, [k for k in rows])
