"""Evidence for a diorama scene (moonshot M5 Task 3, generalised from M4's review_campfire.py):
real CLI renders of `rive/scenes/<sceneId>`, 1080x1920, `--fit=contain`.

    uv run --with pillow --with numpy rive/tools/review_diorama.py <sceneId> [<before poster.webp>]
        [--out=<dir>] [--same-as=<git rev>]

Writes to rive/review/m5/<sceneId>/ (or --out):
- `poster_before_after.png` (when a before poster is given): the old poster beside the current one;
- `parallax_sheet.png`: parallaxX -1/0/1 (columns) x parallaxY -1/0/1 (rows), the full frame;
- `parallax_edges.png`: the same nine renders at half size, only the outer 32 px of the left and
  right edges (columns) and the bottom 32 px (rows), where a plane's bleed would run out;
- `hit_zones.png`: the render at parallaxX -1 / +1 with every hit zone drawn where it now sits;
- `rain_strip.png` (scenes that bind `rain`): rain 0 / 0.5 / 1 (rows) x 3 frames (columns);
- scene extras (campfire: `fire_strip.png`, 10 frames of the firelight loop);
- `gates.txt`: one `ok` / `FAIL` line per objective gate: opaque frame at every parallax corner,
  plane travel, pointer proofs (`prop_tapped` fires inside each hit zone at its displaced position,
  and not at the rest-only edge it left), rain darkening and loop seams, sizes; with `--same-as`,
  the rest frame at rain 0 is pixel-identical to that revision's scene.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import subprocess
import sys
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_scenes import PARALLAX_GAINS, PARALLAX_TRAVEL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCENE_MAX = 409_600
POSTER_MAX = 40_960


@dataclass
class Cfg:
    # (label, artboard patch, expected x travel at |parallaxX| = 1): opaque art of one plane only
    patches: list[tuple[str, tuple[int, int, int, int], int]] = field(default_factory=list)
    # (artboard patch, lowest and highest allowed median-luminance ratio rain 1 / rain 0)
    wet: tuple[tuple[int, int, int, int], float, float] | None = None
    # looping rain layers: (name, frames after which every one of them is back at frame 0)
    rain_loops: list[tuple[str, int]] = field(default_factory=list)
    # artboard patch for the loop seam check, clear of art that loops on its own periods
    seam_box: tuple[int, int, int, int] = (0, 0, 1080, 1920)


CFG: dict[str, Cfg] = {
    "campfire": Cfg(
        patches=[("Plane5 BushL", (100, 1620, 260, 1720), 40), ("Plane4 tent", (700, 920, 860, 1080), 28),
                 ("Plane3 near pine", (1000, 600, 1060, 760), 20), ("Plane1 snow peak", (330, 600, 460, 700), 6)],
        wet=((600, 1480, 900, 1600), 0.6, 0.85),   # open ground right of the trail
        # streak sheets 18 / 34, splashes 120, steam 180 frames: all back at frame 0 after 6120
        rain_loops=[("RainLoop sheets + splashes + RainSteam", 6120)],
        seam_box=(560, 1250, 1080, 1920),  # ground, bushes and rain: clear of the fire and the aurora
    ),
    "livingRoom": Cfg(
        patches=[("Plane4 plant pot", (76, 1260, 204, 1325), 28), ("Plane3 TV cabinet", (780, 1170, 950, 1220), 20),
                 ("Plane2 picture", (830, 430, 970, 620), 12), ("Plane1 mullion", (510, 300, 570, 440), 6),
                 ("Plane0 moon", (615, 295, 665, 345), 0)],
        wet=((380, 250, 520, 440), 1.05, 1.6),   # the top-left pane: wet glass and streaks over the night view
        # glass streaks 20, drips 240 frames: both back at frame 0 after 240
        rain_loops=[("RainGlass streaks + drips", 240)],
        seam_box=(360, 230, 720, 700),  # the glass
    ),
}


class Renderer:
    def __init__(self, proj: Path, tmp: Path) -> None:
        self.proj, self.tmp, self.n = proj, tmp, 0

    def __call__(self, *args: str, proj: Path | None = None) -> np.ndarray:
        self.n += 1
        png = self.tmp / f"r{self.n}.png"
        r = subprocess.run(["rive", str(proj or self.proj), f"--screenshot={png}", "--viewport=1080x1920",
                            "--fit=contain", "--quiet", *args], capture_output=True, text=True)
        if r.returncode:
            raise SystemExit(f"rive failed: {r.stderr}")
        return np.asarray(Image.open(png).convert("RGBA"))


def taps(proj: Path, *args: str) -> int:
    """How many `prop_tapped` events a headless run logs."""
    r = subprocess.run(["rive", str(proj), "--data-dump=/dev/null", *args], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"rive failed: {r.stderr}")
    return r.stderr.count("event prop_tapped")


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((6, 4), text, fill=(255, 255, 0))
    return im


def grid(cells: list[Image.Image], cols: int) -> Image.Image:
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % cols) * w, (i // cols) * h))
    return sheet


@dataclass
class Hit:
    prop: str
    plane: int
    cx: float
    cy: float
    w: float
    h: float

    def rect(self, px: float, py: float) -> tuple[float, float, float, float]:
        g = PARALLAX_GAINS[self.plane]
        x, y = self.cx + g * PARALLAX_TRAVEL[0] * px, self.cy + g * PARALLAX_TRAVEL[1] * py
        return x - self.w / 2, y - self.h / 2, x + self.w / 2, y + self.h / 2


def hits_of(rml: str) -> list[Hit]:
    ab = ET.fromstring(rml).find("Artboard")
    out = []
    for plane in ab:
        if not plane.get("name", "").startswith("Plane"):
            continue
        for c in plane:
            if c.get("name", "").startswith("Hit_"):
                rect = c.find("Rectangle")
                out.append(Hit(c.get("name")[4:], int(plane.get("name")[5:]), float(c.get("x")), float(c.get("y")),
                               float(rect.get("width")), float(rect.get("height"))))
    return out


def inside(r: tuple[float, float, float, float], x: float, y: float) -> bool:
    return r[0] < x < r[2] and r[1] < y < r[3]


def pointer_gates(proj: Path, hits: list[Hit]) -> list[str]:
    """At parallaxX -1 / +1: a click just inside the displaced zone's leading edge (outside where
    the zone rests) fires `prop_tapped`; a click on the rest-only strip it left fires nothing.
    Points that fall into another zone are moved along the zone's height."""
    gates = []
    for h in hits:
        for px in (-1, 1):
            dx = PARALLAX_GAINS[h.plane] * PARALLAX_TRAVEL[0] * px
            moved, rest = h.rect(px, 0), h.rect(0, 0)
            ys = [h.cy + f * h.h for f in (0.0, 0.3, -0.3, 0.42, -0.42)]
            if dx == 0:
                pos = [(h.cx, y) for y in ys]
                neg = []
            else:
                lead = moved[2] - 4 if px > 0 else moved[0] + 4
                # a zone that hangs off the artboard (livingRoom's plant): click just inside the edge
                lead = min(max(lead, 4.0), 1076.0)
                left_strip = (rest[0] + moved[0]) / 2 if px > 0 else (rest[2] + moved[2]) / 2
                pos = [(lead, y) for y in ys]
                neg = [(left_strip, y) for y in ys]

            def alone(pts: list[tuple[float, float]], want: set[str]) -> tuple[float, float] | None:
                for x, y in pts:
                    if {o.prop for o in hits if inside(o.rect(px, 0), x, y)} == want:
                        return x, y
                return None
            p = alone(pos, {h.prop})
            if p is None:
                gates.append(f"pointer {h.prop} parallaxX {px:+d}: no point inside it alone: FAIL")
                continue
            n = taps(proj, f"--data=parallaxX={px}", f"--pointer=click@{p[0]:.0f},{p[1]:.0f}", "--advance=3")
            ok = n == 1
            line = f"pointer {h.prop} (Plane{h.plane}) parallaxX {px:+d}: click@{p[0]:.0f},{p[1]:.0f} fires {n}"
            q = alone(neg, set()) if neg else None
            if q is not None:
                m = taps(proj, f"--data=parallaxX={px}", f"--pointer=click@{q[0]:.0f},{q[1]:.0f}", "--advance=3")
                ok &= m == 0
                line += f", rest-only click@{q[0]:.0f},{q[1]:.0f} fires {m}"
            gates.append(f"{line}: {'ok' if ok else 'FAIL'}")
    return gates


def lum(a: np.ndarray) -> np.ndarray:
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def campfire_extras(render: Renderer, out: Path, gates: list[str]) -> None:
    """The M4 firelight strip and seam (89-frame `amb_firelight`)."""
    crop = (0, 760, 760, 1400)
    frames = [1 + round(i * 89 / 10) for i in range(10)]
    cells = [label(Image.fromarray(render(f"--advance={f}")).convert("RGB").crop(crop).resize((380, 320)), f"f{f - 1}")
             for f in frames]
    grid(cells, 5).save(out / "fire_strip.png")
    a0 = render("--advance=1").astype(int)
    a1 = render("--advance=90").astype(int)
    box = (slice(1230, 1380), slice(300, 440))  # light pool right of the stones, clear of fireflies
    diff = np.abs(a0[box][..., :3] - a1[box][..., :3]).max()
    gates.append(f"firelight seam (pool region, frame 0 vs 89): max channel diff {diff}/255 "
                 f"({'ok' if diff <= 2 else 'FAIL'})")


def living_room_extras(render: Renderer, out: Path, gates: list[str]) -> None:
    """The four events still play (one frame each, mid-event) and the lamp's wall pool follows
    `lightKey` (a blue key turns the pool blue, history-free: back to the default, back to M5 rest)."""
    cells = [label(Image.fromarray(render("--advance=1")).convert("RGB").resize((360, 640)), "rest")]
    for ev, f in (("lightsOff", 60), ("tvOn", 200), ("catWalksBy", 290), ("lightsOn", 60)):
        pre = ["--data=eventId=lightsOff", "--data=event=1", "--advance=60"] if ev == "lightsOn" else []
        a = render(*pre, f"--data=eventId={ev}", "--data=event=1", f"--advance={f}")
        cells.append(label(Image.fromarray(a).convert("RGB").resize((360, 640)), f"{ev} +{f}f"))
    grid(cells, 5).save(out / "events_strip.png")
    glass = (330, 200, 750, 730)   # the window at full size: rain 0 / 1 (rows) x frames 0, 10, 60
    grid([label(Image.fromarray(render(f"--data=rain={r}", f"--advance={f}")).convert("RGB").crop(glass),
                f"rain {r} f{f - 1}") for r in (0, 1) for f in (1, 11, 61)], 3).save(out / "rain_glass.png")
    box = (slice(650, 760), slice(140, 205))   # wall left of the shade, inside the pool
    rest = render("--advance=1").astype(int)[box][..., :3]
    blue = render("--data=lightKey=FF60A0FF", "--advance=1").astype(int)[box][..., :3]
    back = render("--data=lightKey=FF60A0FF", "--advance=1", "--data=lightKey=FFFFD49A", "--advance=2"
                  ).astype(int)[box][..., :3]
    shift = float((blue[..., 2] - blue[..., 0]).mean() - (rest[..., 2] - rest[..., 0]).mean())
    drift = int(np.abs(back - rest).max())
    Image.fromarray(np.concatenate([rest, blue], 1).astype(np.uint8)).resize((400, 320)).save(out / "lamp_key.png")
    gates.append(f"lamp pool follows lightKey (blue - red, mean, blue key vs default): {shift:+.1f}/255 "
                 f"({'ok' if shift >= 8 else 'FAIL'}); back to default: max diff {drift}/255 "
                 f"({'ok' if drift <= 2 else 'FAIL'})")


EXTRAS = {"campfire": campfire_extras, "livingRoom": living_room_extras}


def run(scene: str, before: Path | None, out: Path, same_as: str | None = None) -> list[str]:
    proj = ROOT / "rive" / "scenes" / scene
    cfg = CFG.get(scene, Cfg())
    rml = (proj / f"{scene}.rml").read_text()
    out.mkdir(parents=True, exist_ok=True)
    gates: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        render = Renderer(proj, t)
        # ---- parallax corners and edges
        full, sides, bottoms = [], [], []
        shots: dict[tuple[int, int], np.ndarray] = {}
        opaque = True
        for py in (-1, 0, 1):
            for px in (-1, 0, 1):
                a = render(f"--data=parallaxX={px}", f"--data=parallaxY={py}", "--advance=1")
                ok = bool((a[..., 3] == 255).all())
                opaque &= ok
                shots[(px, py)] = a
                im = Image.fromarray(a).convert("RGB")
                full.append(label(im.resize((270, 480)), f"x{px:+d} y{py:+d}"))
                half = im.resize((540, 960))
                side = Image.new("RGB", (68, 960), (90, 0, 90))
                side.paste(half.crop((0, 0, 32, 960)), (0, 0))
                side.paste(half.crop((508, 0, 540, 960)), (36, 0))
                sides.append(side)
                bottoms.append(half.crop((0, 928, 540, 960)))
                if not ok:
                    gates.append(f"parallax ({px:+d}, {py:+d}): transparent pixels: FAIL")
        gates.append(f"parallax corners (9 renders, every pixel opaque): {'ok' if opaque else 'FAIL'}")
        grid(full, 3).save(out / "parallax_sheet.png")
        edges = Image.new("RGB", (9 * 72, 960 + 9 * 36), (20, 20, 20))
        for i, (side, bottom) in enumerate(zip(sides, bottoms)):
            edges.paste(side, (i * 72, 0))
            edges.paste(bottom, (0, 960 + i * 36))
        edges.save(out / "parallax_edges.png")
        for name, (x0, y0, x1, y1), want in cfg.patches:
            ref = shots[(0, 0)][y0:y1, x0:x1, :3].astype(int)
            got = []
            for px in (-1, 1):
                img = shots[(px, 0)][..., :3].astype(int)
                errs = {dx: np.abs(img[y0:y1, x0 + dx:x1 + dx] - ref).mean() for dx in range(-48, 49)
                        if 0 <= x0 + dx and x1 + dx <= 1080}
                got.append(min(errs, key=errs.get))
            ok = got == [-want, want]
            gates.append(f"{name} travel at parallaxX -1/+1: {got[0]:+d}/{got[1]:+d} px (want -/+{want}): "
                         f"{'ok' if ok else 'FAIL'}")

        # ---- hit zones ride their planes
        hits = hits_of(rml)
        gates.append(f"hit zones inside planes: {', '.join(f'{h.prop}=Plane{h.plane}' for h in hits) or 'none'}: "
                     f"{'ok' if hits else 'FAIL'}")
        cells = []
        for px in (-1, 1):
            im = Image.fromarray(shots[(px, 0)]).convert("RGB")
            dr = ImageDraw.Draw(im)
            for h in hits:
                dr.rectangle(h.rect(px, 0), outline=(0, 255, 120), width=4)
                dr.rectangle(h.rect(0, 0), outline=(255, 60, 60), width=2)
                dr.text((h.rect(px, 0)[0] + 8, h.rect(px, 0)[1] + 8), h.prop, fill=(0, 255, 120))
            cells.append(label(im.resize((540, 960)), f"parallaxX {px:+d}: green = hit zone now, red = at rest"))
        grid(cells, 2).save(out / "hit_zones.png")
        gates += pointer_gates(proj, hits)

        # ---- rain
        if 'name="rain"' in rml and cfg.rain_loops:
            frames = (1, 41, 81)
            rows = {}
            cells = []
            for rain in (0, 0.5, 1):
                for f in frames:
                    a = render(f"--data=rain={rain}", f"--advance={f}")
                    rows[(rain, f)] = a
                    cells.append(label(Image.fromarray(a).convert("RGB").resize((360, 640)), f"rain {rain} f{f - 1}"))
            grid(cells, 3).save(out / "rain_strip.png")
            if cfg.wet is not None:
                (x0, y0, x1, y1), lo, hi = cfg.wet
                m0 = float(np.median(lum(rows[(0, 1)][y0:y1, x0:x1, :3].astype(float))))
                m1 = float(np.median(lum(rows[(1, 1)][y0:y1, x0:x1, :3].astype(float))))
                ratio = m1 / m0 if m0 else 0.0
                gates.append(f"wet ground (median luminance rain 1 / rain 0): {m1:.1f}/{m0:.1f} = {ratio:.2f} "
                             f"(want {lo}..{hi}): {'ok' if lo <= ratio <= hi else 'FAIL'}")
            # loop seams: frame 0 vs frame N of each rain loop at rain 1, net of what changes anyway at rain 0
            x0, y0, x1, y1 = cfg.seam_box
            for name, n in cfg.rain_loops:
                d1 = np.abs(render("--data=rain=1", "--advance=1").astype(int)
                            - render("--data=rain=1", f"--advance={n + 1}").astype(int))[y0:y1, x0:x1, :3].max(-1) > 2
                d0 = np.abs(render("--advance=1").astype(int)
                            - render(f"--advance={n + 1}").astype(int))[y0:y1, x0:x1, :3].max(-1) > 2
                extra = float((d1 & ~d0).mean())
                gates.append(f"{name} seam (frame 0 vs {n}, rain 1, box {cfg.seam_box}, pixels changed beyond "
                             f"rain 0): {extra:.4%} ({'ok' if extra <= 0.001 else 'FAIL'})")

        # ---- same as a previous revision at rest
        if same_as:
            base = t / "base" / scene
            base.mkdir(parents=True)
            text = subprocess.run(["git", "show", f"{same_as}:rive/scenes/{scene}/{scene}.rml"], cwd=ROOT,
                                  capture_output=True, text=True, check=True).stdout
            (base / f"{scene}.rml").write_text(text)
            (base / "rive.yaml").write_text((proj / "rive.yaml").read_text())
            worst = 0.0
            for f in (1, 61):
                a = render(f"--advance={f}").astype(int)
                b = render(f"--advance={f}", proj=base).astype(int)
                worst = max(worst, float((np.abs(a - b).max(-1) > 0).mean()))
            gates.append(f"rain 0 rest frames (f0, f60) identical to {same_as}: {worst:.4%} pixels differ "
                         f"({'ok' if worst == 0 else 'FAIL'})")

        if scene in EXTRAS:
            EXTRAS[scene](render, out, gates)

    riv = ROOT / "assets" / "rive" / "scenes" / f"{scene}.riv"
    poster = ROOT / "assets" / "rive" / "posters" / f"{scene}.webp"
    gates.append(f"{scene}.riv {riv.stat().st_size} B (budget {SCENE_MAX:,}): "
                 f"{'ok' if riv.stat().st_size <= SCENE_MAX else 'FAIL'}")
    gates.append(f"{scene}.webp {poster.stat().st_size} B (budget {POSTER_MAX:,}): "
                 f"{'ok' if poster.stat().st_size <= POSTER_MAX else 'FAIL'}")
    if before is not None:
        b = Image.open(before).convert("RGB")
        a = Image.open(poster).convert("RGB")
        pair = Image.new("RGB", (b.width + a.width + 8, max(b.height, a.height)), (20, 20, 20))
        pair.paste(label(b, "before"), (0, 0))
        pair.paste(label(a, "after"), (b.width + 8, 0))
        pair.save(out / "poster_before_after.png")
    (out / "gates.txt").write_text("\n".join(gates) + "\n")
    return gates


def main(argv: list[str]) -> int:
    opts = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in argv if a.startswith("--")}
    pos = [a for a in argv if not a.startswith("--")]
    if not pos:
        print(__doc__)
        return 2
    scene = pos[0]
    before = Path(pos[1]) if len(pos) > 1 else None
    out = Path(opts["--out"]) if "--out" in opts else ROOT / "rive" / "review" / "m5" / scene
    gates = run(scene, before, out, opts.get("--same-as"))
    print("\n".join(gates))
    return 1 if any(g.endswith("FAIL") for g in gates) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
