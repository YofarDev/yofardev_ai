"""Whole-world contact sheets for a defect pass (moonshot M12 ruling 9): every scene at ultra and at low.

    uv run --with pillow --with numpy rive/tools/review_world.py [--out=<dir>] [sceneId ...]

Writes `<out>/<sceneId>_<tier>.webp` (default out: rive/review/m12/world/), three 540x960 cells per row, each
at frame 91 (`--advance=91`):

- `rest`: the v14 defaults (no world clock: the storybook night every scene is drawn in);
- `rain 1`: rain 1, with the `SceneFront` composited over it where the scene has one (ultra only: the app never
  creates the front at low, so the low cell is the back alone);
- `night`: `night` 1 (what the world clock writes at night: (1 - daylight) x (1 - dusk)), where bound;
- `noon` / `dusk`: `daylight` 1, and `daylight` 0.4 + `dusk` 1, where the scene binds them;
- `festive`, `spring 1`, `autumn 1`: where bound.

What a scene binds is read from its built RML (a SceneVM member referenced by any bind or formula). The renders
reuse review_diorama's `Renderer` / `FrontRenderer` and review_tiers' `over` (alpha compositing); nothing here
is a gate.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
import tempfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
sys.path.insert(0, str(TOOLS))
from review_diorama import FrontRenderer, Renderer  # noqa: E402
from review_tiers import has_front, over  # noqa: E402

SCENES = ("livingRoom", "campfire", "beach", "deepSpace", "cafe", "rooftop", "mountainHut", "forestCabin",
          "trainCompartment", "library")
OUT = ROOT / "rive" / "review" / "m12" / "world"
CELL = (540, 960)
COLS = 3
FRAME = "--advance=91"
MAX_BYTES = 300 * 1024


def bound(scene: str) -> set[str]:
    """The SceneVM members the scene's RML references outside the view model's own declaration."""
    path = ROOT / "rive" / "scenes" / scene / f"{scene}.rml"
    text = path.read_text()
    root = ET.fromstring(text)
    vm = next(v for v in root.iter("ViewModel") if v.get("name") == "SceneVM")
    names = {p.get("id"): p.get("name") for p in vm if p.get("name")}
    refs = set()
    for e in root.iter():
        for k in ("sourcePathIds",):
            v = e.get(k)
            if v and v.startswith(f"{vm.get('id')}-"):
                refs.add(v.split("-")[1])
    return {names[i] for i in refs if i in names}


def cases(scene: str) -> list[tuple[str, list[str], bool]]:
    """(label, --data args, composite the front) per cell."""
    b = bound(scene)
    out = [("rest", [], False), ("rain 1", ["--data=rain=1"], has_front(scene))]
    if "night" in b:
        out.append(("night 1", ["--data=night=1"], False))
    if "daylight" in b:
        out.append(("noon (daylight 1)", ["--data=daylight=1"], False))
    if "dusk" in b:
        out.append(("dusk 1, daylight 0.4", ["--data=daylight=0.4", "--data=dusk=1"], False))
    if "festive" in b:
        out.append(("festive", ["--data=festive=1"], False))
    if "spring" in b:
        out.append(("spring 1", ["--data=spring=1"], False))
    if "autumn" in b:
        out.append(("autumn 1", ["--data=autumn=1"], False))
    return out


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 10 + 6 * len(text), 18), fill=(0, 0, 0))
    d.text((5, 3), text, fill=(255, 255, 0))
    return im


def save(im: Image.Image, path: Path) -> int:
    """WebP under MAX_BYTES: the highest quality (step 5) that fits."""
    for q in range(80, 30, -5):
        im.save(path, "WEBP", quality=q, method=6)
        if path.stat().st_size <= MAX_BYTES:
            return q
    raise SystemExit(f"{path.name}: over {MAX_BYTES} B even at quality 35")


def sheet(scene: str, tier: str, tmp: Path) -> str:
    proj = ROOT / "rive" / "scenes" / scene
    cs = cases(scene)
    front = FrontRenderer(proj, tmp / f"{scene}_{tier}") if any(f for _, _, f in cs) and tier != "low" else None

    def cell(c: tuple[str, list[str], bool]) -> Image.Image:
        lab, args, with_front = c
        r = Renderer(proj, Path(tempfile.mkdtemp(dir=tmp)))
        a = [f"--data=tier={tier}", *args, FRAME]
        arr = r(*a)
        text = f"{scene} {tier}: {lab}"
        if with_front and front is not None:
            arr = over(arr, front(*a))
            text += " + SceneFront"
        elif with_front:
            text += " (no SceneFront at low)"
        return label(Image.fromarray(arr).convert("RGB").resize(CELL, Image.LANCZOS), text)
    with ThreadPoolExecutor(4) as ex:
        cells = list(ex.map(cell, cs))
    w, h = CELL
    rows = (len(cells) + COLS - 1) // COLS
    im = Image.new("RGB", (w * COLS, h * rows), (20, 20, 20))
    for i, c in enumerate(cells):
        im.paste(c, ((i % COLS) * w, (i // COLS) * h))
    path = OUT_DIR / f"{scene}_{tier}.webp"
    q = save(im, path)
    return f"{path.name}: {', '.join(lab for lab, _, _ in cs)} ({path.stat().st_size} B, q{q})"


def main(argv: list[str]) -> int:
    global OUT_DIR
    out = next((a.split("=", 1)[1] for a in argv if a.startswith("--out=")), None)
    OUT_DIR = Path(out) if out else OUT
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    scenes = [a for a in argv if not a.startswith("--")] or list(SCENES)
    tmp = Path(tempfile.mkdtemp())
    for s in scenes:
        for t in ("ultra", "low"):
            print(sheet(s, t, tmp), flush=True)
    return 0


OUT_DIR = OUT

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
