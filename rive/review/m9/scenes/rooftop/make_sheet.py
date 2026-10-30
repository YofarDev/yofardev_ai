"""Evidence contact sheet for the v12 scene `rooftop` (moonshot M9 Task 3b).

    uv run --with pillow rive/review/m9/scenes/rooftop/make_sheet.py

Writes next to this file:
- `sheet_world.png`: rest, rain 1, noon, dusk, fog 1, parallax -1 / +1 (full frames);
- `sheet_events.png`: fireworks, plane, shootingStar, windowsLit at their peaks (full frames);
- `sheet_moon.png`: the moon at moonPhase -1 (as drawn) and 0, 0.125 ... 0.875 (crops);
- `sheet_drag.png`: the telescope at aim -1, 0, 0.5, 1 (crops of the handle rect);
- `sheet_npc.png`: the pigeon in rest, away, idle (peck), move, notice -1 / +1, react (crops).
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
PROJ = ROOT / "rive" / "scenes" / "rooftop"
sys.path.insert(0, str(ROOT / "rive" / "tools"))
import scene_rooftop  # noqa: E402


def render(tmp: Path, *args: str) -> Image.Image:
    png = tmp / "r.png"
    subprocess.run(["rive", str(PROJ), f"--screenshot={png}", "--viewport=1080x1920", "--fit=contain", "--quiet",
                    *args], check=True)
    return Image.open(png).convert("RGB")


def cell(im: Image.Image, text: str, box: tuple[int, int, int, int] | None = None,
         size: tuple[int, int] = (270, 480)) -> Image.Image:
    if box is not None:
        im = im.crop(box)
    im = im.resize(size)
    ImageDraw.Draw(im).text((5, 4), text, fill=(255, 255, 0))
    return im


def sheet(cells: list[Image.Image], cols: int, out: Path) -> None:
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    s = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
    for i, c in enumerate(cells):
        s.paste(c, ((i % cols) * w, (i // cols) * h))
    s.save(out)


def main() -> None:
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        world = [("rest", ["--advance=31"]), ("rain 1", ["--data=rain=1", "--advance=31"]),
                 ("noon", ["--data=daylight=1", "--advance=31"]), ("dusk", ["--data=daylight=0.4", "--data=dusk=1",
                                                                             "--advance=31"]),
                 ("fog 1", ["--data=fog=1", "--advance=31"]),
                 ("parallax -1,-1", ["--data=parallaxX=-1", "--data=parallaxY=-1", "--advance=31"]),
                 ("parallax +1,+1", ["--data=parallaxX=1", "--data=parallaxY=1", "--advance=31"])]
        sheet([cell(render(tmp, *a), lab) for lab, a in world], 4, HERE / "sheet_world.png")
        events = [("fireworks", 70), ("fireworks", 150), ("plane", 300), ("shootingStar", 24), ("windowsLit", 120),
                  ("windowsLit", 280)]
        sheet([cell(render(tmp, f"--data=eventId={ev}", "--data=event=1", f"--advance={f}"), f"{ev} +{f}f")
               for ev, f in events], 3, HERE / "sheet_events.png")
        mx, my, mr = scene_rooftop.MOON
        mbox = (int(mx - 140), int(my - 140), int(mx + 140), int(my + 140))
        phases = [-1.0] + [k / 8 for k in range(8)]
        sheet([cell(render(tmp, f"--data=moonPhase={p}", "--advance=1"), f"moonPhase {p}", mbox, (220, 220))
               for p in phases], 9, HERE / "sheet_moon.png")
        x0, y0, x1, y1 = scene_rooftop.aim_rect()
        cells = []
        for a in (-1, 0, 0.5, 1):
            im = render(tmp, f"--data=aim={a}", "--advance=1")
            ImageDraw.Draw(im).rectangle((x0, y0, x1, y1), outline=(0, 255, 120), width=2)
            cells.append(cell(im, f"aim {a}", (x0 - 20, y0 - 20, x1 + 20, y1 + 20), (308, 346)))
        sheet(cells, 4, HERE / "sheet_drag.png")
        px, py, _ = scene_rooftop.PIGEON_WAYPOINTS[0]
        nbox = (int(px - 110), int(py - 120), int(px + 110), int(py + 30))
        states = [("rest", ["--advance=31"]), ("away", ["--data=npc=away", "--advance=31"]),
                  ("idle peck f36", ["--data=npc=idle", "--advance=37"]), ("idle f128", ["--data=npc=idle", "--advance=129"]),
                  ("move f0", ["--data=npc=move", "--data=npcLook=0.5", "--advance=33"]),
                  ("move f8", ["--data=npc=move", "--data=npcLook=0.5", "--advance=41"]),
                  ("notice -1", ["--data=npc=notice", "--data=npcLook=-1", "--advance=31"]),
                  ("notice +1", ["--data=npc=notice", "--data=npcLook=1", "--advance=31"]),
                  ("react f8", ["--data=npc=react", "--advance=57"]), ("react f18", ["--data=npc=react", "--advance=67"]),
                  ("react f26", ["--data=npc=react", "--advance=75"]),
                  ("move npcX 1", ["--data=npc=move", "--data=npcX=1", "--advance=31"])]
        cells = []
        for lab, a in states:
            box = nbox if "npcX 1" not in lab else (nbox[0] + 200 - 60, nbox[1], nbox[2] + 200 - 60, nbox[3])
            cells.append(cell(render(tmp, *a), lab, box, (330, 225)))
        sheet(cells, 4, HERE / "sheet_npc.png")


if __name__ == "__main__":
    main()
