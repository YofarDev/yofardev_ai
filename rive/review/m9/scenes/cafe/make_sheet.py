"""Evidence for the M9 scene `cafe` (lane S1): one contact sheet of real CLI renders.

    uv run --with pillow --with numpy rive/review/m9/scenes/cafe/make_sheet.py

Writes next to this file:
- `contact.png`: rest, rain 1, noon, dusk, fog 1, the four events at their peaks, festive 1,
  parallax -1 / +1 (full frames, 270 x 480);
- `npc.png`: the fish in every state (crops at 2x);
- `wipe.png`: the `wipe` drag at trailN 0 / 8 / 16, trailFade 0.5, and with rain 1 (the window);
- `moon.png`: moonPhase -1 (the drawn moon) and 0, 0.125 ... 0.875 (the window's top-left pane at 2x);
- `festive.png`: festive 0 / 1 and the twinkle half a loop later (the window top and the door).
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / "rive" / "tools"))
import scene_cafe  # noqa: E402

PROJ = ROOT / "rive" / "scenes" / "cafe"
OUT = Path(__file__).resolve().parent


def render(tmp: Path, *args: str) -> Image.Image:
    render.n = getattr(render, "n", 0) + 1  # type: ignore[attr-defined]
    png = tmp / f"r{render.n}.png"  # type: ignore[attr-defined]
    r = subprocess.run(["rive", str(PROJ), f"--screenshot={png}", "--viewport=1080x1920", "--fit=contain", "--quiet",
                        *args], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(r.stderr)
    return Image.open(png).convert("RGB")


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 6 * len(text), 16), fill=(0, 0, 0))
    d.text((4, 3), text, fill=(255, 230, 80))
    return im


def grid(cells: list[Image.Image], cols: int) -> Image.Image:
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % cols) * w, (i // cols) * h))
    return sheet


def main() -> None:
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        small = (270, 480)
        shots = [("rest", ["--advance=1"]), ("rain 1", ["--data=rain=1", "--advance=31"]),
                 ("noon", ["--data=daylight=1", "--advance=1"]), ("dusk", ["--data=daylight=0.4", "--data=dusk=1",
                                                                         "--advance=1"]),
                 ("fog 1", ["--data=fog=1", "--advance=1"])]
        shots += [(f"{ev} +{f}f", [f"--data=eventId={ev}", "--data=event=1", f"--advance={f}"])
                  for ev, f in scene_cafe.EVENT_PEAKS.items()]
        shots += [("festive 1", ["--data=festive=1", "--advance=1"]),
                  ("parallax -1,-1", ["--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=1"]),
                  ("parallax +1,+1", ["--data=parallaxX=1", "--data=parallaxY=1", "--advance=1"])]
        grid([label(render(tmp, *a).resize(small), n) for n, a in shots], 6).save(OUT / "contact.png")

        fx, fy, _ = scene_cafe.FISH_WAYPOINTS[0]
        crop = (int(fx) - 110, int(fy) - 110, int(fx) + 110, int(fy) + 70)
        npc = [("rest", ["--advance=31"]), ("away", ["--data=npc=away", "--advance=31"])]
        npc += [(f"idle f{f - 1}", ["--data=npc=idle", f"--advance={f}"]) for f in (31, 151)]
        npc += [(f"move npcX {x}", ["--data=npc=move", f"--data=npcX={x}", "--advance=16"]) for x in (0, 0.5, 1)]
        npc += [(f"notice look {s:+d}", ["--data=npc=notice", f"--data=npcLook={s}", "--advance=31"])
                for s in (-1, 0, 1)]
        npc += [(f"react f{f - 1}", ["--data=npc=react", f"--advance={f}"]) for f in (7, 15, 25, 41, 55)]
        grid([label(render(tmp, *a).crop(crop).resize((440, 360)), n) for n, a in npc], 5).save(OUT / "npc.png")

        x0, y0, x1, y1 = (int(v) for v in scene_cafe.GLASS)
        win = (x0 - 40, y0 - 40, x1 + 40, y1 + 40)
        wipe = [("trailN 0 (defaults)", ["--advance=1"]),
                ("trailN 8", [*scene_cafe.trail_args(8), "--advance=1"]),
                ("trailN 16", [*scene_cafe.trail_args(), "--advance=1"]),
                ("trailN 16, trailFade 0.5", [*scene_cafe.trail_args(fade=0.5), "--advance=1"]),
                ("trailN 16, rain 1", [*scene_cafe.trail_args(), "--data=rain=1", "--advance=31"])]
        grid([label(render(tmp, *a).crop(win), n) for n, a in wipe], 5).save(OUT / "wipe.png")

        mx, my, _ = scene_cafe.MOON
        mc = (int(mx) - 60, int(my) - 50, int(mx) + 60, int(my) + 50)
        phases = [-1.0] + [k / 8 for k in range(8)]
        grid([label(render(tmp, f"--data=moonPhase={p}", "--advance=1").crop(mc).resize((240, 200)),
                    f"moonPhase {p:g}") for p in phases], 9).save(OUT / "moon.png")

        fc = (280, 200, 1060, 820)
        fest = [("festive 0", ["--advance=1"]), ("festive 1 f0", ["--data=festive=1", "--advance=1"]),
                ("festive 1 f120", ["--data=festive=1", "--advance=121"])]
        grid([label(render(tmp, *a).crop(fc), n) for n, a in fest], 3).save(OUT / "festive.png")
    print("wrote", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
