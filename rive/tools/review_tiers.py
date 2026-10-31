"""Tier and season evidence (moonshot M11 rulings 9 and 13, contract v14 `tier`, `spring`, `autumn`).

    uv run --with pillow --with numpy rive/tools/review_tiers.py [--same-as=<git ref>] [sceneId ...]

- `rive/review/m11/tiers/<sceneId>.webp`: ultra / high / low (columns) at rest, at rain 1, and (scenes with
  a `SceneFront`) the front layer over the rain-1 scene (rows), each at frame 91 (`--advance=91`);
- `rive/review/m11/tiers/gates.txt`: per scene, what the tier pass gates (from the built RML), how many
  pixels each tier changes at rest and at rain 1, and, with `--same-as`, the identity of the default
  (tier ultra, spring 0, autumn 0) against that ref's RML at frames 1 and 91 (0 px expected);
- `rive/review/m11/seasons/<sceneId>.webp` for the scenes binding `spring` / `autumn` (livingRoom, campfire,
  forestCabin, trainCompartment): both 0 / spring 1 / autumn 1, at night (the default) and by day
  (`daylight` 1).

Headless renders through the CLI (`--viewport=1080x1920 --fit=contain`).
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
sys.path.insert(0, str(TOOLS))
import world_kit  # noqa: E402

SCENES_DIR = ROOT / "rive" / "scenes"
OUT_TIERS = ROOT / "rive" / "review" / "m11" / "tiers"
OUT_SEASONS = ROOT / "rive" / "review" / "m11" / "seasons"
TIERS = ("ultra", "high", "low")
SEASON_SCENES = ("livingRoom", "campfire", "forestCabin", "trainCompartment")
CELL = (270, 480)
FRAME = "--advance=91"


def render(proj: Path, png: Path, *args: str) -> np.ndarray:
    r = subprocess.run(["rive", str(proj), f"--screenshot={png}", "--viewport=1080x1920", "--fit=contain", "--quiet",
                        *args], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"rive failed ({proj.name} {' '.join(args)}): {r.stderr[-400:]}")
    return np.asarray(Image.open(png).convert("RGBA"))


def has_front(scene: str) -> bool:
    return 'name="SceneFront"' in (SCENES_DIR / scene / f"{scene}.rml").read_text()


def label(im: Image.Image, text: str) -> Image.Image:
    draw = ImageDraw.Draw(im)
    draw.rectangle((0, 0, 8 + 6 * len(text), 16), fill=(0, 0, 0))
    draw.text((4, 2), text, fill=(255, 255, 0))
    return im


def sheet(rows: list[list[tuple[str, np.ndarray]]]) -> Image.Image:
    w, h = CELL
    out = Image.new("RGB", (w * max(len(r) for r in rows), h * len(rows)), (0, 0, 0))
    for y, row in enumerate(rows):
        for x, (text, arr) in enumerate(row):
            im = Image.fromarray(arr).convert("RGB").resize(CELL, Image.LANCZOS)
            out.paste(label(im, text), (x * w, y * h))
    return out


def over(back: np.ndarray, front: np.ndarray) -> np.ndarray:
    a = front[..., 3:4].astype(float) / 255
    rgb = front[..., :3] * a + back[..., :3] * (1 - a)
    return np.dstack([rgb, np.full(rgb.shape[:2], 255.0)]).astype(np.uint8)


def diff_px(a: np.ndarray, b: np.ndarray) -> int:
    return int((np.abs(a.astype(int) - b.astype(int)).max(-1) > 0).sum())


def gated_names(scene: str) -> dict[str, list[str]]:
    """From the built RML: the gated elements per level (wrappers report what they wrap) and the veils
    thinned at low."""
    root = ET.parse(SCENES_DIR / scene / f"{scene}.rml").getroot()
    vm = root.find("ViewModel")
    tier = next(p.get("id") for p in vm if p.get("name") == "tier")
    path = f"{vm.get('id')}-{tier}"
    formulas = {c.get("id"): c for c in root.iter("DataConverterFormula")}
    level = {}
    for g in root.iter("DataConverterGroup"):
        f = formulas.get(list(g)[-1].get("converterId"))
        if f is not None:
            vals = tuple(world_kit.eval_formula(f, float(i)) for i in range(3))
            level[g.get("id")] = {(0.0, 0.0, 1.0): "high", (0.0, 1.0, 1.0): "low"}.get(vals, "?")
    out: dict[str, list[str]] = {"high": [], "low": [], "veils": []}
    for e in root.iter():
        b = next((b for b in e.findall("DataBindContext") if b.get("sourcePathIds") == path), None)
        if b is None or e.tag not in ("Node", "Shape"):
            continue
        name = e.get("name", "")
        if name.startswith(world_kit.TIER_FOG_FILLS):
            out["veils"].append("FogVeil" + name.removeprefix(world_kit.TIER_FOG_FILLS))
        elif name.startswith(world_kit.TIER_WRAP_PREFIX):
            out[level[b.get("converterId")]].append(next(c.get("name") for c in e if c.tag in ("Node", "Shape")))
        else:
            out[level[b.get("converterId")]].append(name)
    return out


def compact(names: list[str]) -> str:
    """`Splash8, Splash9 ...` -> `Splash8-15` style runs, roots with counts."""
    groups: dict[str, list[int]] = {}
    plain: list[str] = []
    for n in names:
        m = re.fullmatch(r"(?:emit)?(.*?)(\d+)", n)
        if m:
            groups.setdefault(m.group(1), []).append(int(m.group(2)))
        else:
            plain.append(n.removeprefix("emit"))
    parts = [f"{k}{{{','.join(map(str, sorted(v)))}}}" if len(v) > 1 else f"{k}{v[0]}" for k, v in groups.items()]
    return ", ".join(sorted(set(plain)) + parts) or "-"


def tier_evidence(scene: str, tmp: Path, same_as: str | None) -> list[str]:
    proj = SCENES_DIR / scene
    jobs = [(t, cond) for cond in ("rest", "rain", *(("front",) if has_front(scene) else ())) for t in TIERS]

    front = None
    if has_front(scene):
        from review_diorama import FrontRenderer  # noqa: PLC0415 (the CLI paints its grey under a screenshot)
        (tmp / f"front_{scene}").mkdir()
        front = FrontRenderer(proj, tmp / f"front_{scene}")

    def one(job: tuple[str, str]) -> tuple[tuple[str, str], np.ndarray]:
        t, cond = job
        args = [f"--data=tier={t}", FRAME]
        if cond != "rest":
            args.insert(0, "--data=rain=1")
        if cond == "front":
            return job, front(*args)   # RGBA: the front alone
        return job, render(proj, tmp / f"{scene}_{t}_{cond}.png", *args)

    with ThreadPoolExecutor(3) as ex:
        shots = dict(ex.map(one, [j for j in jobs if j[1] != "front"]))
    shots.update(one(j) for j in jobs if j[1] == "front")   # FrontRenderer is not thread-safe
    rows = []
    for cond in ("rest", "rain", "front"):
        if (TIERS[0], cond) not in shots:
            continue
        row = []
        for t in TIERS:
            img = shots[(t, cond)]
            if cond == "front":
                img = over(shots[(t, "rain")], img)
            row.append((f"{scene} {t} {cond if cond != 'front' else 'rain 1 + SceneFront'}", img))
        rows.append(row)
    OUT_TIERS.mkdir(parents=True, exist_ok=True)
    sheet(rows).save(OUT_TIERS / f"{scene}.webp", "WEBP", quality=80, method=6)
    g = gated_names(scene)
    lines = [f"{scene}:",
             f"  high (hidden at high and low): {compact(g['high'])}",
             f"  low (hidden at low): {compact(g['low'])}",
             f"  fog veils down to one fill at low: {', '.join(sorted(g['veils'])) or '-'}"]
    for cond in ("rest", "rain", "front"):
        if (TIERS[0], cond) in shots:
            u = shots[("ultra", cond)]
            lines.append(f"  {cond}: high changes {diff_px(u, shots[('high', cond)])} px, low {diff_px(u, shots[('low', cond)])} px "
                         f"(of {u.shape[0] * u.shape[1]})")
    if same_as:
        ref = tmp / "ref" / scene
        ref.mkdir(parents=True)
        for f in (f"{scene}.rml", "rive.yaml"):
            text = subprocess.run(["git", "show", f"{same_as}:rive/scenes/{scene}/{f}"], cwd=ROOT, capture_output=True,
                                  text=True, check=True).stdout
            (ref / f).write_text(text)
        worst = []
        for adv, extra in (("--advance=1", ()), ("--advance=91", ()), ("--advance=91", ("--data=rain=1",))):
            a = render(proj, tmp / f"{scene}_id_new.png", *extra, adv)
            b = render(ref, tmp / f"{scene}_id_ref.png", *extra, adv)
            n = diff_px(a, b)
            worst.append(n)
            lines.append(f"  identity vs {same_as} (default: tier ultra, spring 0, autumn 0) {' '.join(extra)} {adv}: "
                         f"{n} px {'ok' if n == 0 else 'FAIL'}")
    return lines


def season_evidence(scene: str, tmp: Path) -> None:
    proj = SCENES_DIR / scene
    rows = []
    for tod, extra in (("night", ()), ("day", ("--data=daylight=1",))):
        row = []
        for name, args in (("spring 0 / autumn 0", ()), ("spring 1", ("--data=spring=1",)),
                           ("autumn 1", ("--data=autumn=1",))):
            png = tmp / f"{scene}_{tod}_{name.replace(' ', '_').replace('/', '')}.png"
            row.append((f"{scene} {tod} {name}", render(proj, png, *extra, *args, FRAME)))
        rows.append(row)
    OUT_SEASONS.mkdir(parents=True, exist_ok=True)
    sheet(rows).save(OUT_SEASONS / f"{scene}.webp", "WEBP", quality=80, method=6)


def main(argv: list[str]) -> int:
    same_as = next((a.split("=", 1)[1] for a in argv if a.startswith("--same-as=")), None)
    scenes = [a for a in argv if not a.startswith("--")] or sorted(p.name for p in SCENES_DIR.iterdir() if p.is_dir())
    lines = ["# Tier gates per scene (M11 ruling 13; rive/tools/review_tiers.py)", ""]
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        for s in scenes:
            got = tier_evidence(s, tmp, same_as)
            print("\n".join(got), flush=True)
            lines += got
            if s in SEASON_SCENES:
                season_evidence(s, tmp)
    if len(scenes) > 1 or not (OUT_TIERS / "gates.txt").exists():
        (OUT_TIERS / "gates.txt").write_text("\n".join(lines) + "\n")
    return 1 if any(line.endswith("FAIL") for line in lines) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
