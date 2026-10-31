"""Moonshot M10 Task 3 (plan ruling 15): evidence and gates for the four M9 scene notes.

    uv run --with pillow --with numpy rive/tools/review_m10_notes.py [cafe] [spin] [beach] [rooftop] [identity]

Writes before / after strips (M9 = the scene RML at `--base`, default `58aeff2`, built in a temp dir)
and `gates.txt` into `rive/review/m10/notes/`. Each note's gates:

- `cafe`: the wipe cuts the mist (clear glass): inside the stroke's core the view's contrast rises
  (luminance std / rest's >= 1.15), every changed pixel lies inside the handle rect, `trailFade` 1
  draws nothing, trailN 0 is M9.
- `spin`: deepSpace's bands, painted opaque yellow in a temp copy of the RML (a test-only paint, so a
  gap is measurable): at 16 spin values no band loses >= 4 px of contiguous coverage it has at spin 0
  (columns under the planet's ring excluded: it draws over the bands); spin 1 draws spin 0 exactly.
- `beach`: night 0 = M9 at daylight / dusk 0, 1 and dusk 1; night 1 darkens the sky, sea and sand and
  turns the sun's glow off; strips at night 0 / 0.5 / 1 x daylight / dusk.
- `rooftop`: daylight lifts the roof floor (mean luminance at noon >= M9's + 12/255); daylight 0 = M9.
- `identity`: every scene at the v13 defaults (rest, frame 90, noon, dusk, rain, fog, parallax) = M9,
  except the intended changes (rooftop at daylight > 0).
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "rive" / "review" / "m10" / "notes"
SCENES = ("livingRoom", "campfire", "beach", "deepSpace", "cafe", "rooftop", "mountainHut")
TMP = Path(tempfile.mkdtemp(prefix="m10notes"))
_n = [0]


def proj_of(scene: str) -> Path:
    return ROOT / "rive" / "scenes" / scene


def base_proj(scene: str, rev: str) -> Path:
    """The scene's RML at `rev` (M9), as a temp project."""
    p = TMP / f"base_{rev}" / scene
    if not p.exists():
        p.mkdir(parents=True)
        text = subprocess.run(["git", "show", f"{rev}:rive/scenes/{scene}/{scene}.rml"], cwd=ROOT,
                              capture_output=True, text=True, check=True).stdout
        (p / f"{scene}.rml").write_text(text)
        shutil.copy(proj_of(scene) / "rive.yaml", p)
    return p


def render(proj: Path, *args: str) -> np.ndarray:
    _n[0] += 1
    png = TMP / f"r{_n[0]}.png"
    r = subprocess.run(["rive", str(proj), f"--screenshot={png}", "--viewport=1080x1920", "--fit=contain", "--quiet",
                        *args], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"rive failed: {r.stderr}")
    return np.asarray(Image.open(png).convert("RGB")).astype(np.int16)


def differ(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.abs(a.astype(int) - b.astype(int)).max(-1) > 0


def lum(a: np.ndarray) -> np.ndarray:
    return a[..., :3].astype(float) @ np.array([0.299, 0.587, 0.114])


def cell(a: np.ndarray, box: tuple[int, int, int, int], text: str, scale: float = 1.0) -> Image.Image:
    im = Image.fromarray(a.astype(np.uint8)).crop(box)
    if scale != 1.0:
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    ImageDraw.Draw(im).rectangle((0, 0, 7 * len(text) + 10, 16), fill=(15, 15, 20))
    ImageDraw.Draw(im).text((5, 3), text, fill=(255, 230, 90))
    return im


def sheet(rows: list[list[Image.Image]], path: Path) -> None:
    w = max(sum(c.width for c in r) + 4 * (len(r) - 1) for r in rows)
    h = sum(max(c.height for c in r) for r in rows) + 4 * (len(rows) - 1)
    out = Image.new("RGB", (w, h), (12, 12, 16))
    y = 0
    for r in rows:
        x = 0
        for c in r:
            out.paste(c, (x, y))
            x += c.width + 4
        y += max(c.height for c in r) + 4
    out.save(path, optimize=True)


def runs(mask: np.ndarray) -> int:
    run = best = 0
    for v in mask:
        run = run + 1 if v else 0
        best = max(best, run)
    return best


# ====================================================================== café wipe
def cafe(rev: str, gates: list[str]) -> None:
    import scene_cafe  # noqa: PLC0415
    now, m9 = proj_of("cafe"), base_proj("cafe", rev)
    x0, y0, x1, y1 = (int(v) for v in scene_cafe.GLASS)
    rest = render(now, "--advance=1")
    wiped = render(now, *scene_cafe.trail_args(), "--advance=1")
    ch = differ(wiped, rest)
    out_ = ch.copy()
    out_[y0:y1, x0:x1] = False
    gates.append(f"{'ok' if not out_.any() and ch[y0:y1, x0:x1].mean() > 0.02 else 'FAIL'} cafe wipe: 16 spots change "
                 f"{ch[y0:y1, x0:x1].mean():.2%} of the handle rect, {int(out_.sum())} px outside")
    gone = int(differ(render(now, *scene_cafe.trail_args(fade=1.0), "--advance=1"), rest).sum())
    gates.append(f"{'ok' if gone == 0 else 'FAIL'} cafe wipe: trailFade 1 draws nothing ({gone} px differ from rest)")
    same = int(differ(render(m9, "--advance=1"), rest).sum())
    gates.append(f"{'ok' if same == 0 else 'FAIL'} cafe wipe: trailN 0 is M9 ({same} px differ)")
    # clear glass: in the stroke's core (r 10 around each dot) the view's contrast rises (the mist
    # flattens it by (1 - its alpha)); the M9 darken tint flattened it further
    yy, xx = np.mgrid[0:1920, 0:1080]
    core = np.zeros((1920, 1080), bool)
    for x, y in scene_cafe.TRAIL_PROOF:
        core |= (xx - x) ** 2 + (yy - y) ** 2 <= 100
    std_rest = float(lum(rest)[core].std())
    for label, a in (("M10", wiped), ("M9", render(m9, *scene_cafe.trail_args(), "--advance=1"))):
        ratio = float(lum(a)[core].std()) / std_rest
        want = ratio >= 1.15 if label == "M10" else True
        gates.append(f"{'ok' if want else 'FAIL'} cafe wipe {label}: contrast in the stroke's core x{ratio:.2f} of rest "
                     f"({'clear glass, >= 1.15' if label == 'M10' else 'reference'})")
    box = (x0 - 30, y0 - 30, x1 + 30, y1 + 30)
    cases = [("trailN 8", scene_cafe.trail_args(8)), ("trailN 16", scene_cafe.trail_args()),
             ("trailFade 0.5", scene_cafe.trail_args(fade=0.5)), ("trailFade 0.9", scene_cafe.trail_args(fade=0.9)),
             ("rain 1", [*scene_cafe.trail_args(), "--data=rain=1"]),
             ("noon", [*scene_cafe.trail_args(), "--data=daylight=1"])]
    rows = []
    for label, proj in (("M9", m9), ("M10", now)):
        rows.append([cell(render(proj, *args, "--advance=31"), box, f"{label} {t}", 0.6) for t, args in cases])
    sheet(rows, OUT / "cafe_wipe.png")


# ====================================================================== deepSpace spin seam
def painted(proj: Path) -> Path:
    """A temp copy of deepSpace whose cloud bands (and their wrap copies) are opaque yellow."""
    dst = TMP / f"painted_{proj.parent.name}_{_n[0]}" / "deepSpace"
    dst.mkdir(parents=True)
    shutil.copy(proj / "rive.yaml", dst)
    text = (proj / "deepSpace.rml").read_text()
    text = re.sub(r'<Shape [^>]*name="PlanetWeather[^"]*".*?</Shape>',
                  lambda m: re.sub(r'colorValue="[0-9A-F]{8}"', 'colorValue="FFFFFF00"', m.group(0)), text, flags=re.S)
    (dst / "deepSpace.rml").write_text(text)
    return dst


BAND_ROWS = [(460 + 17 * i, 478 + 17 * i) for i in range(14)]   # screen rows of each cloud band (its wave)


def band_cover(a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Per band: columns where its yellow shows, and columns the planet's ring covers in its rows."""
    y = (a[..., 0] > 180) & (a[..., 1] > 180) & (a[..., 2] < 90)
    ring = (a[..., 0] > 150) & (a[..., 1] > 140) & (a[..., 2] > 110)
    return (np.stack([y[r0:r1].any(0) for r0, r1 in BAND_ROWS]),
            np.stack([ring[r0:r1].any(0) for r0, r1 in BAND_ROWS]))


def spin_gaps(proj: Path) -> list[int]:
    """The widest run of columns a band covers at spin 0 but not at spin k/16, per k."""
    p = painted(proj)
    c0, r0 = band_cover(render(p, "--data=spin=0", "--advance=1"))
    out = []
    for k in range(16):
        c, r = band_cover(render(p, f"--data=spin={k / 16}", "--advance=1"))
        out.append(max(runs(c0[i] & ~c[i] & ~r0[i] & ~r[i]) for i in range(len(BAND_ROWS))))
    return out


def spin(rev: str, gates: list[str]) -> None:
    now, m9 = proj_of("deepSpace"), base_proj("deepSpace", rev)
    for label, proj in (("M9", m9), ("M10", now)):
        g = spin_gaps(proj)
        ok = max(g) < 4 if label == "M10" else True
        gates.append(f"{'ok' if ok else 'FAIL'} deepSpace spin {label}: widest band gap per spin k/16 {g} px"
                     f"{' (< 4)' if label == 'M10' else ' (reference)'}")
    a0, a1 = render(now, "--data=spin=0", "--advance=1"), render(now, "--data=spin=1", "--advance=1")
    n = int(differ(a0, a1).sum())
    gates.append(f"{'ok' if n == 0 else 'FAIL'} deepSpace spin: spin 1 draws spin 0 ({n} px differ)")
    n = int(differ(a0, render(m9, "--data=spin=0", "--advance=1")).sum())
    gates.append(f"{'ok' if n == 0 else 'FAIL'} deepSpace spin: spin 0 is M9 ({n} px differ)")
    box = (140, 430, 460, 750)
    rows = []
    for label, proj in (("M9", m9), ("M10", now)):
        rows.append([cell(render(proj, f"--data=spin={s}", "--advance=1"), box, f"{label} spin {s}", 0.75)
                     for s in (0.0, 0.0625, 0.25, 0.5, 0.75, 0.9375, 1.0)])
    sheet(rows, OUT / "deepSpace_spin.png")
    zoom = (160, 455, 330, 600)
    sheet([[cell(render(proj, "--data=spin=0.25", "--advance=1"), zoom, f"{label} spin 0.25", 2.0)
            for label, proj in (("M9", m9), ("M10", now))]], OUT / "deepSpace_spin_zoom.png")


# ====================================================================== beach night
def beach(rev: str, gates: list[str]) -> None:
    now, m9 = proj_of("beach"), base_proj("beach", rev)
    rest = render(now, "--advance=1")
    night = render(now, "--data=night=1", "--advance=1")
    regions = {"sky": (slice(80, 800), slice(0, 1080)), "sea": (slice(1000, 1150), slice(300, 1080)),
               "sand": (slice(1350, 1800), slice(300, 1080)), "sun glow": (slice(520, 760), slice(660, 900))}
    for name, (ys, xs) in regions.items():
        r = float(lum(night[ys, xs]).mean()) / float(lum(rest[ys, xs]).mean())
        lim = 0.35 if name in ("sky", "sun glow") else 0.6
        gates.append(f"{'ok' if r <= lim else 'FAIL'} beach night 1: {name} luminance x{r:.2f} of night 0 (<= {lim})")
    sky = lum(night[80:800])
    from_bg = sky - np.median(sky)
    stars = int((from_bg > 40).sum())
    gates.append(f"{'ok' if stars >= 60 else 'FAIL'} beach night 1: {stars} star px stand out of the sky (>= 60)")
    for args in (["--advance=1"], ["--data=daylight=1", "--advance=1"], ["--data=dusk=1", "--advance=1"]):
        n = int(differ(render(m9, *args), render(now, "--data=night=0", *args)).sum())
        gates.append(f"{'ok' if n == 0 else 'FAIL'} beach night 0 = M9 at {' '.join(args[:-1]) or 'rest'} ({n} px differ)")
    # the app writes night = (1 - daylight) x (1 - dusk): the clock's day
    clock = [("midnight", 0.0, 0.0), ("pre-dawn", 0.15, 0.3), ("sunrise", 0.4, 1.0), ("morning", 0.8, 0.2),
             ("noon", 1.0, 0.0), ("sunset", 0.4, 1.0), ("dusk", 0.15, 0.4)]
    rows = [[cell(render(m9, f"--data=daylight={d}", f"--data=dusk={k}", "--advance=31"), (0, 0, 1080, 1920),
                  f"M9 {name}", 0.25) for name, d, k in clock],
            [cell(render(now, f"--data=daylight={d}", f"--data=dusk={k}",
                         f"--data=night={round((1 - d) * (1 - k), 3)}", "--advance=31"), (0, 0, 1080, 1920),
                  f"M10 {name} n{round((1 - d) * (1 - k), 2)}", 0.25) for name, d, k in clock]]
    sheet(rows, OUT / "beach_night_clock.png")
    rows = [[cell(render(now, f"--data=night={v}", *extra, "--advance=31"), (0, 0, 1080, 1920), f"night {v}{label}", 0.25)
             for v in (0.0, 0.25, 0.5, 0.75, 1.0)]
            for label, extra in (("", []), (" rain", ["--data=rain=1"]), (" fog", ["--data=fog=1"]))]
    sheet(rows, OUT / "beach_night.png")


# ====================================================================== rooftop day lift
def rooftop(rev: str, gates: list[str]) -> None:
    now, m9 = proj_of("rooftop"), base_proj("rooftop", rev)
    ys, xs = slice(1180, 1900), slice(0, 1080)
    for d in (0.5, 1.0):
        a = float(lum(render(m9, f"--data=daylight={d}", "--advance=1")[ys, xs]).mean())
        b = float(lum(render(now, f"--data=daylight={d}", "--advance=1")[ys, xs]).mean())
        want = 12 * d
        gates.append(f"{'ok' if b - a >= want else 'FAIL'} rooftop daylight {d}: roof floor mean luminance "
                     f"{a:.1f} -> {b:.1f} (+{b - a:.1f}, >= {want:.0f})")
    sky = (slice(0, 900), slice(0, 1080))
    n = int(differ(render(m9, "--data=daylight=1", "--advance=1")[sky], render(now, "--data=daylight=1", "--advance=1")[sky]).sum())
    gates.append(f"{'ok' if n == 0 else 'FAIL'} rooftop daylight 1: the sky and the skyline above the parapet unchanged "
                 f"({n} px differ above y 900)")
    cases = [("night", []), ("daylight 0.5", ["--data=daylight=0.5"]), ("noon", ["--data=daylight=1"]),
             ("sunset", ["--data=daylight=0.4", "--data=dusk=1"]), ("noon rain", ["--data=daylight=1", "--data=rain=1"])]
    rows = [[cell(render(proj, *args, "--advance=31"), (0, 0, 1080, 1920), f"{label} {t}", 0.25) for t, args in cases]
            for label, proj in (("M9", m9), ("M10", now))]
    sheet(rows, OUT / "rooftop_day.png")


# ====================================================================== identity
IDENTITY_CASES = [("rest", ["--advance=1"]), ("f90", ["--advance=90"]),
                  ("noon", ["--data=daylight=1", "--advance=1"]), ("dusk", ["--data=dusk=1", "--advance=1"]),
                  ("rain", ["--data=rain=1", "--advance=31"]), ("fog", ["--data=fog=1", "--advance=1"]),
                  ("parallax", ["--data=parallaxX=1", "--data=parallaxY=-1", "--advance=1"])]
INTENDED = {("rooftop", "noon")}   # ruling 15: daylight lifts the rooftop floor


def identity(rev: str, gates: list[str]) -> None:
    for s in SCENES:
        bad = []
        for name, args in IDENTITY_CASES:
            if (s, name) in INTENDED:
                continue
            n = int(differ(render(base_proj(s, rev), *args), render(proj_of(s), *args)).sum())
            if n:   # the worktree is shared: a concurrent rebuild of the project can race one capture
                n = int(differ(render(base_proj(s, rev), *args), render(proj_of(s), *args)).sum())
            if n:
                bad.append(f"{name} {n} px")
        cases = [n for n, _ in IDENTITY_CASES if (s, n) not in INTENDED]
        gates.append(f"{'ok' if not bad else 'FAIL'} identity {s}: v13 defaults = M9 at {', '.join(cases)}"
                     + (f" -- differ: {'; '.join(bad)}" if bad else ""))


def main(argv: list[str]) -> int:
    opts = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in argv if a.startswith("--") and "=" in a}
    rev = opts.get("--base", "58aeff2")
    which = [a for a in argv if not a.startswith("--")] or ["cafe", "spin", "beach", "rooftop", "identity"]
    OUT.mkdir(parents=True, exist_ok=True)
    fns = {"cafe": cafe, "spin": spin, "beach": beach, "rooftop": rooftop, "identity": identity}
    gates: list[str] = []
    for w in which:
        fns[w](rev, gates)
    for g in gates:
        print(g)
    name = "gates.txt" if len(which) == 5 else f"gates_{'_'.join(which)}.txt"   # the full run writes gates.txt
    (OUT / name).write_text("\n".join(gates) + "\n")
    return 1 if any(g.startswith("FAIL") for g in gates) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
