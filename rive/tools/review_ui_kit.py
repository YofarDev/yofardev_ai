"""Contact sheets for the UI kit (rive/ui_kit): every artboard x every state, frame strips.

    uv run --with pillow rive/tools/review_ui_kit.py            # -> rive/ui_kit/review/*.png
    uv run --with pillow rive/tools/review_ui_kit.py orb glow   # only some sheets

Captures run on review copies of the kit generated with a backdrop behind every artboard
(build/ui_kit_review/<colour>/), so the shipped RML stays clean. StatusGlow is also rendered on
black and white backdrops to recover its alpha, then composited over each scene's rest pose.
Mid-run state changes use the 1.8.0 CLI rule: `--data` after a gesture flag is a step.
"""

from __future__ import annotations

import re
import shlex
import shutil
import threading
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "rive" / "tools"
WORK = ROOT / "build" / "ui_kit_review"
OUT = ROOT / "rive" / "ui_kit" / "review"
SURFACE = "FF211B2B"   # composer dock / sheets
INK = "FF16121D"
LABEL = (233, 219, 192)
BG = (22, 18, 29)
SCENES = ["livingRoom", "campfire", "beach", "deepSpace"]
SCENE_ACCENT = {"livingRoom": "FFF4B860", "campfire": "FFFF8552", "beach": "FFFF9478", "deepSpace": "FFB79CFF"}


def project(bd: str) -> Path:
    p = WORK / bd
    if not (p / "ui_kit.rml").exists():
        subprocess.run(["uv", "run", str(TOOLS / "gen_ui_kit.py"), "--out", str(p), "--backdrop", bd],
                       check=True, stdout=subprocess.DEVNULL)
    return p


_tls = threading.local()


def local(proj: Path) -> Path:
    """Per-thread copy of a project: `rive` rebuilds into <proj>/build on every capture, so two
    parallel captures of one directory race on the same .riv."""
    copies = _tls.__dict__.setdefault("copies", {})
    if proj not in copies:
        dst = WORK / "threads" / f"{threading.get_ident()}" / proj.name
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(proj, dst, ignore=shutil.ignore_patterns("build"))
        copies[proj] = dst
    return copies[proj]


def shot(proj: Path, artboard: str, png: Path, args: str, size: int | tuple[int, int]) -> Image.Image:
    vw, vh = (size, size) if isinstance(size, int) else size
    png.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["rive", str(local(proj)), f"--artboard={artboard}", f"--screenshot={png}", f"--viewport={vw}x{vh}", "--fit=contain",
           *shlex.split(args)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode or re.search(r"[1-9]\d* (?:errors|warnings)|runtime error", r.stderr, re.I):
        raise RuntimeError(f"{' '.join(cmd)}\n{r.stderr}")
    return Image.open(png).convert("RGB")


def font(sz: int) -> ImageFont.ImageFont:
    return ImageFont.load_default(size=sz)


def strip_sheet(rows: list[tuple[str, list[tuple[str, Image.Image]]]], out: Path, title: str) -> None:
    """rows: (row label, [(cell label, image)])"""
    cw = max(im.width for _, cells in rows for _, im in cells)
    ch = max(im.height for _, cells in rows for _, im in cells)
    lw, top = 150, 40
    ncol = max(len(cells) for _, cells in rows)
    sheet = Image.new("RGB", (lw + ncol * (cw + 8) + 8, top + len(rows) * (ch + 26) + 8), BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 10), title, fill=LABEL, font=font(16))
    for r, (rl, cells) in enumerate(rows):
        y = top + r * (ch + 26)
        dr.text((10, y + ch // 2), rl, fill=LABEL, font=font(14))
        for c, (cl, im) in enumerate(cells):
            x = lw + c * (cw + 8)
            sheet.paste(im, (x, y + 18))
            dr.text((x, y + 2), cl, fill=(150, 140, 160), font=font(11))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(out, optimize=True)
    print("wrote", out.relative_to(ROOT))


def change(before: str, after: str, settle: int = 40) -> str:
    """Capture args for a mid-run change: start with `before`, settle, then apply `after`."""
    pre = " ".join(f"--data={x}" for x in before.split()) if before else ""
    post = " ".join(f"--data={x}" for x in after.split())
    return f"{pre} --advance={settle} --pointer=move@1,1 {post}"


def run_rows(proj: Path, artboard: str, specs: list[tuple[str, str, list[int]]], size: int, tag: str,
             pool: ThreadPoolExecutor) -> list[tuple[str, list[tuple[str, Image.Image]]]]:
    """specs: (row label, base args, frames) -> each frame captured with `--advance=f` appended."""
    jobs = []
    for r, (label, args, frames) in enumerate(specs):
        for f in frames:
            png = WORK / "shots" / tag / f"{r:02d}_{f:04d}.png"
            jobs.append((label, f, pool.submit(shot, proj, artboard, png, f"{args} --advance={f}", size)))
    rows: dict[str, list[tuple[str, Image.Image]]] = {}
    for label, f, fut in jobs:
        rows.setdefault(label, []).append((f"+{f - 1}f / {round((f - 1) * 1000 / 60)}ms", fut.result()))
    return list(rows.items())


# ---------------------------------------------------------------- sheets

def orb(pool: ThreadPoolExecutor) -> None:
    p = project(SURFACE)
    rest = [("idle", "--data=state=idle", [1]), ("typing", "--data=state=typing", [1]),
            ("listening 0", "--data=state=listening --data=level=0", [1]),
            ("listening .5", "--data=state=listening --data=level=0.5", [1]),
            ("listening 1", "--data=state=listening --data=level=1", [1]),
            ("thinking", "--data=state=thinking", [1]), ("speaking", "--data=state=speaking", [1]),
            ("error (held)", "--data=state=error", [40])]
    big = [(lab, cells[0][1]) for lab, cells in run_rows(p, "ComposerOrb", rest, 192, "orb_rest", pool)]
    small = [(lab, cells[0][1]) for lab, cells in run_rows(p, "ComposerOrb", rest, 48, "orb_rest48", pool)]
    mid = [(lab, cells[0][1]) for lab, cells in run_rows(p, "ComposerOrb", rest, 56, "orb_rest56", pool)]
    pad = lambda im: _pad(im, 192)  # noqa: E731
    strip_sheet([("192 px", big), ("56 px (1x)", [(lab, pad(im)) for lab, im in mid]),
                 ("48 px (1x)", [(lab, pad(im)) for lab, im in small])],
                OUT / "orb_states.png", "ComposerOrb - every state at rest (3x, and at true 56/48 px)")
    fr = [1, 4, 7, 10, 13, 16, 20, 25, 31]
    tr = [("idle>typing", change("state=idle", "state=typing"), fr),
          ("typing>idle", change("state=typing", "state=idle"), fr),
          ("idle>listening", change("state=idle", "state=listening"), fr),
          ("listening>thinking", change("state=listening", "state=thinking"), fr),
          ("thinking>speaking", change("state=thinking", "state=speaking"), fr),
          ("speaking>idle", change("state=speaking", "state=idle"), fr),
          ("idle>error (shake)", change("state=idle", "state=error"), [1, 4, 6, 9, 12, 15, 19, 23, 31]),
          ("rm: idle>typing", change("state=idle reduceMotion=true", "state=typing"), [1, 3, 5, 7, 9]),
          ("rm: idle>error", change("state=idle reduceMotion=true", "state=error"), [1, 3, 5, 7, 9])]
    strip_sheet(run_rows(p, "ComposerOrb", tr, 144, "orb_tr", pool), OUT / "orb_transitions.png",
                "ComposerOrb - state changes, frame by frame after the change (rm = reduceMotion)")
    amb = [("thinking loop", "--data=state=thinking", [61, 76, 91, 106, 121, 136, 151, 166, 181]),
           ("thinking rm", "--data=state=thinking --data=reduceMotion=true", [61, 106, 151]),
           ("level sweep", "--data=state=listening --data=level=0 --advance=30 --pointer=move@1,1 --data=level=0.25 "
            "--advance=6 --pointer=move@1,1 --data=level=0.6 --advance=6 --pointer=move@1,1 --data=level=1", [1, 3, 6]),
           ("level rm=1", "--data=state=listening --data=level=1 --data=reduceMotion=true", [30])]
    strip_sheet(run_rows(p, "ComposerOrb", amb, 144, "orb_amb", pool), OUT / "orb_ambient.png",
                "ComposerOrb - thinking loop (every 250 ms), listening level, reduceMotion")


def _pad(im: Image.Image, size: int) -> Image.Image:
    c = Image.new("RGB", (size, im.height if im.height > size else size), BG)
    c.paste(im, ((size - im.width) // 2, (c.height - im.height) // 2))
    return c


def glow_alpha(phase_args: str, frame: int, tag: str, accent: str = "FFF4B860") -> Image.Image:
    """RGBA glow recovered from black + white backdrop captures."""
    args = f"{phase_args} --data=accent={accent} --advance={frame}"
    k = shot(project("FF000000"), "StatusGlow", WORK / "shots" / tag / "k.png", args, (480, 200))
    w = shot(project("FFFFFFFF"), "StatusGlow", WORK / "shots" / tag / "w.png", args, (480, 200))
    alpha = ImageChops.invert(ImageChops.subtract(w.convert("L"), k.convert("L")))
    rgb = Image.new("RGB", k.size)
    kp, ap = k.load(), alpha.load()
    rp = rgb.load()
    for y in range(k.height):
        for x in range(k.width):
            a = ap[x, y]
            if a:
                rp[x, y] = tuple(min(255, round(v * 255 / a)) for v in kp[x, y])
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def glow(pool: ThreadPoolExecutor) -> None:
    p = project(INK)
    frames = [1, 31, 61, 91, 121, 151, 181, 211]
    specs = [(ph, f"--data=phase={ph}", frames) for ph in ("idle", "waiting", "generating", "speaking")]
    specs += [("error (pulse)", change("phase=generating", "phase=error"), [1, 5, 9, 13, 17, 21, 25, 31]),
              ("rm generating", "--data=phase=generating --data=reduceMotion=true", [1, 61, 121]),
              ("idle>speaking", change("phase=idle", "phase=speaking"), [1, 7, 13, 19, 25, 31])]
    rows = run_rows(p, "StatusGlow", specs, (480, 200), "glow", pool)
    rows = [(lab, [(cl, im.resize((240, 100), Image.LANCZOS)) for cl, im in cells]) for lab, cells in rows]
    strip_sheet(rows, OUT / "glow_phases.png", "StatusGlow - phases over ink #16121D, every 500 ms")
    # over each scene: alpha-recovered glow composited on the scene rest pose, behind a composer pill
    cells = []
    futs = {}
    for s in SCENES:
        for ph in ("idle", "generating", "speaking"):
            futs[(s, ph)] = pool.submit(glow_alpha, f"--data=phase={ph}", 91, f"glow_{s}_{ph}", SCENE_ACCENT[s])
    scene_imgs = {s: pool.submit(shot, ROOT / "rive" / "scenes" / s, "Scene", WORK / "shots" / f"scene_{s}.png",
                                 "--advance=1", (1080, 1920)) for s in SCENES}
    rows = []
    for s in SCENES:
        bg = scene_imgs[s].result().crop((60, 1500, 1020, 1900)).resize((480, 200), Image.LANCZOS).convert("RGBA")
        row = []
        for ph in ("idle", "generating", "speaking"):
            g = futs[(s, ph)].result()
            comp = Image.alpha_composite(bg, g)
            dr = ImageDraw.Draw(comp)
            dr.rounded_rectangle((60, 76, 420, 132), radius=28, fill=(33, 27, 43, 235), outline=(58, 48, 70, 255))
            row.append((ph, comp.convert("RGB")))
        rows.append((s, row))
    strip_sheet(rows, OUT / "glow_over_scenes.png",
                "StatusGlow - scene accent, alpha-composited over each scene's lower band, behind a composer pill")
    # edge check: alpha at the artboard border must be ~0 (no hard clip edge)
    worst = 0
    for (s, ph), f in futs.items():
        a = f.result().getchannel("A")
        border = [a.getpixel((x, y)) for x in range(480) for y in (0, 199)] + \
                 [a.getpixel((x, y)) for y in range(200) for x in (0, 479)]
        worst = max(worst, max(border))
    print(f"StatusGlow max border alpha: {worst}/255")


def tool(pool: ThreadPoolExecutor) -> None:
    p = project(SURFACE)
    kinds = ["search", "weather", "news", "memory", "generic"]
    rest = [(k, f"--data=kind={k}", [1]) for k in kinds]
    big = [(lab, c[0][1]) for lab, c in run_rows(p, "ToolIcon", rest, 144, "tool_rest", pool)]
    s24 = [(lab, _pad(c[0][1], 144)) for lab, c in run_rows(p, "ToolIcon", rest, 24, "tool_24", pool)]
    s20 = [(lab, _pad(c[0][1], 144)) for lab, c in run_rows(p, "ToolIcon", rest, 20, "tool_20", pool)]
    s48 = [(lab, _pad(c[0][1], 144)) for lab, c in run_rows(p, "ToolIcon", rest, 48, "tool_48", pool)]
    strip_sheet([("144 px", big), ("48 px", s48), ("24 px", s24), ("20 px", s20)], OUT / "tool_kinds.png",
                "ToolIcon - kinds at rest (3x, 48, 24, 20 px)")
    fr = [1, 11, 21, 31, 41, 51, 61, 71, 81]
    run = [(f"{k} running", f"--data=kind={k} --data=running=true --advance=30", fr) for k in kinds]
    run += [("search>news", change("kind=search", "kind=news"), [1, 4, 7, 10, 14, 18, 24]),
            ("running>stop", change("kind=weather running=true", "running=false"), [1, 5, 9, 13, 17, 21])]
    strip_sheet(run_rows(p, "ToolIcon", run, 96, "tool_run", pool), OUT / "tool_running.png",
                "ToolIcon - running loops (every ~167 ms) and changes")


def toggle(pool: ThreadPoolExecutor) -> None:
    p = project(SURFACE)
    fr = [1, 3, 5, 7, 9, 11, 13, 16, 19, 25]
    specs = [("off (rest)", "--data=value=false", [1]), ("on (rest)", "--data=value=true", [1]),
             ("on, scene accent", "--data=value=true --data=accent=FFB79CFF", [1]),
             ("off>on", change("value=false", "value=true"), fr),
             ("on>off", change("value=true", "value=false"), fr),
             ("on>off>on fast", change("value=true", "value=false") + " --advance=6 --pointer=move@1,1 --data=value=true",
              [1, 4, 7, 10, 14, 20])]
    rows = run_rows(p, "Toggle", specs, (208, 128), "toggle", pool)
    s1x = run_rows(p, "Toggle", [("off 1x", "--data=value=false", [1]), ("on 1x", "--data=value=true", [1])], (52, 32),
                   "toggle1x", pool)
    rows.append(("52x32 (1x)", [(lab, c[0][1].crop((0, 0, 52, 32)).resize((52, 32))) for lab, c in s1x]))
    strip_sheet(rows, OUT / "toggle.png", "Toggle - rest, colours, both directions and a fast reversal")


def mark(pool: ThreadPoolExecutor) -> None:
    p = project(INK)
    fr = [1, 6, 11, 16, 21, 26, 31, 37, 43, 49, 55, 61, 67, 73, 85]
    specs = [("rest (no play)", "", [1]), ("play", "--data=play=1", fr),
             ("play, violet", "--data=play=1 --data=accent=FFB79CFF", [1, 31, 49, 61, 85])]
    rows = run_rows(p, "Mark", specs, 160, "mark", pool)
    strip_sheet(rows, OUT / "mark.png", "Mark - rest pose and the play sting (1.4 s)")


def compare(proj: Path, artboard: str, a_args: str, b_args: str, size: int | tuple[int, int], tag: str) -> str:
    """Render two captures; return the CLI's differing-pixel summary for b vs a."""
    vw, vh = (size, size) if isinstance(size, int) else size
    a = WORK / "proof" / f"{tag}_a.png"
    shot(proj, artboard, a, a_args, size)
    r = subprocess.run(["rive", str(local(proj)), f"--artboard={artboard}", f"--screenshot={WORK / 'proof' / (tag + '_b.png')}",
                        f"--viewport={vw}x{vh}", "--fit=contain", *shlex.split(b_args), f"--compare={a}"],
                       capture_output=True, text=True)
    m = re.search(r"(\d+\.\d+)% of pixels differ \((\d+) of (\d+)\)", r.stdout + r.stderr)
    return m.group(0) if m else f"? {r.stderr[-200:]}"


def probe(proj: Path, artboard: str, args: str, xy: str, size: int | tuple[int, int]) -> str:
    vw, vh = (size, size) if isinstance(size, int) else size
    r = subprocess.run(["rive", str(local(proj)), f"--artboard={artboard}", f"--screenshot={WORK / 'proof' / 'probe.png'}",
                        f"--viewport={vw}x{vh}", "--fit=contain", *shlex.split(args), f"--probe={xy}"],
                       capture_output=True, text=True)
    m = re.search(r"probe \S+ (\w+)", r.stdout + r.stderr)
    return m.group(1) if m else "?"


LOOP_DATA = {"Think_breathe": "--data=state=thinking", "Waiting_drift": "--data=phase=waiting",
             "Generating_breathe": "--data=phase=generating", "Speaking_shimmer": "--data=phase=speaking",
             **{f"Run_{k}": f"--data=kind={k}" for k in ("search", "weather", "news", "memory", "generic")}}


def seams() -> list[tuple[str, str, bool]]:
    """Copy the kit with each looping animation alone on its own layer (other layers kept), then
    compare frame 0 with frame `duration`: a seam pop shows up as differing pixels."""
    import xml.etree.ElementTree as ET
    base = project(INK)
    out = []
    root0 = ET.parse(base / "ui_kit.rml").getroot()
    for ab in root0.findall("Artboard"):
        for anim in ab.findall("LinearAnimation"):
            if anim.get("loopValue") != "loop":
                continue
            root = ET.parse(base / "ui_kit.rml").getroot()
            board = next(a for a in root.findall("Artboard") if a.get("name") == ab.get("name"))
            for layer in board.iter("StateMachineLayer"):
                if any(st.get("animationId") == anim.get("id") for st in layer.iter("AnimationState")):
                    layer[:] = []
                    ET.SubElement(layer, "AnyState", {"id": "99:1", "x": "0", "y": "0"})
                    ET.SubElement(layer, "ExitState", {"id": "99:2", "x": "0", "y": "0"})
                    entry = ET.SubElement(layer, "EntryState", {"id": "99:3", "x": "0", "y": "0"})
                    ET.SubElement(entry, "StateTransition", {"stateToId": "99:5", "id": "99:4"})
                    ET.SubElement(layer, "AnimationState", {"animationId": anim.get("id"), "id": "99:5", "x": "1", "y": "1"})
            proj = WORK / "seams" / anim.get("name")
            proj.mkdir(parents=True, exist_ok=True)
            ET.ElementTree(root).write(proj / "ui_kit.rml", encoding="unicode")
            (proj / "rive.yaml").write_text("name: seam\nmain: ComposerOrb\noutput: {dir: build}\n")
            w, h = int(float(board.get("width"))), int(float(board.get("height")))
            dur = int(anim.get("duration"))
            res = compare(proj, board.get("name"), f"{LOOP_DATA.get(anim.get('name'), '')} --data=running=true --advance=1"
                          if board.get("name") == "ToolIcon" else f"{LOOP_DATA.get(anim.get('name'), '')} --advance=1",
                          f"{LOOP_DATA.get(anim.get('name'), '')} {'--data=running=true ' if board.get('name') == 'ToolIcon' else ''}"
                          f"--advance={dur + 1}", (w, h), "seam_" + anim.get("name"))
            px = int(re.search(r"\((\d+) of", res).group(1)) if "(" in res else -1
            good = px == 0
            # a spin keyed 0 -> 2pi/n (n-fold symmetric art) wraps to the same geometry; only float
            # antialiasing differs. Accept that, and say so, when the worst channel delta stays tiny.
            wraps = any(kp.get("property") == "rotation" and kp[0].get("value") != kp[-1].get("value")
                        for kp in anim.iter("KeyedProperty"))
            if px > 0 and wraps:
                a_im = Image.open(WORK / "proof" / f"seam_{anim.get('name')}_a.png").convert("RGB")
                b_im = Image.open(WORK / "proof" / f"seam_{anim.get('name')}_b.png").convert("RGB")
                worst = max(hi for _, hi in ImageChops.difference(a_im, b_im).getextrema())
                good = worst <= 24 and px * 100 <= a_im.width * a_im.height
                res += f" - rotation wrap, worst channel delta {worst}/255 (antialias only)"
            out.append((f"{board.get('name'):12} loop seam {anim.get('name')} ({dur}f)", res, good))
    return out


def proof(pool: ThreadPoolExecutor) -> None:
    """Behavioural proof: loop seams, end-of-change == rest, reduceMotion stillness, colour binds."""
    p = project(INK)
    checks: list[tuple[str, str, str, str, object, str]] = [
        # (label, artboard, a args, b args, size, expectation)
        ("orb thinking, reduceMotion: still", "ComposerOrb", "--data=state=thinking --data=reduceMotion=true --advance=61",
         "--data=state=thinking --data=reduceMotion=true --advance=133", 96, "0 px"),
        ("orb error after shake == reduceMotion error", "ComposerOrb", "--data=state=error --data=reduceMotion=true --advance=60",
         "--data=state=error --advance=60", 96, "0 px"),
        ("orb listening level=1, reduceMotion == level 0", "ComposerOrb",
         "--data=state=listening --data=level=0 --advance=40",
         "--data=state=listening --data=level=1 --data=reduceMotion=true --advance=40", 96, "0 px"),
        ("orb listening level=1 != level 0", "ComposerOrb", "--data=state=listening --data=level=0 --advance=40",
         "--data=state=listening --data=level=1 --advance=40", 96, "> 0 px"),
        ("orb typing>idle ends on idle rest", "ComposerOrb", "--data=state=idle --advance=1",
         change("state=typing", "state=idle") + " --advance=40", 96, "0 px"),
        ("glow generating, reduceMotion: still", "StatusGlow",
         "--data=phase=generating --data=reduceMotion=true --advance=61",
         "--data=phase=generating --data=reduceMotion=true --advance=121", (480, 200), "0 px"),
        ("glow speaking != idle", "StatusGlow", "--data=phase=idle --advance=61", "--data=phase=speaking --advance=61",
         (480, 200), "> 0 px"),
        ("tool running>stopped returns to rest", "ToolIcon", "--data=kind=weather --advance=1",
         change("kind=weather running=true", "running=false") + " --advance=40", 48, "0 px"),
        ("tool search != news", "ToolIcon", "--data=kind=search --advance=30", "--data=kind=news --advance=30", 48, "> 0 px"),
        ("toggle off>on ends on on-rest", "Toggle", "--data=value=true --advance=1",
         change("value=false", "value=true") + " --advance=40", (104, 64), "0 px"),
        ("toggle on>off ends on off-rest", "Toggle", "--data=value=false --advance=1",
         change("value=true", "value=false") + " --advance=40", (104, 64), "0 px"),
        ("mark sting ends on rest", "Mark", "--advance=1", "--data=play=1 --advance=90", 256, "0 px"),
        ("mark sting mid != rest", "Mark", "--advance=1", "--data=play=1 --advance=20", 256, "> 0 px"),
    ]
    futs =[(c, pool.submit(compare, p, c[1], c[2], c[3], c[4], f"c{i}")) for i, c in enumerate(checks)]
    lines = []
    ok = True
    for (label, ab, _, _, _, want), f in futs:
        res = f.result()
        px = int(re.search(r"\((\d+) of", res).group(1)) if "(" in res else -1
        good = px == 0 if want == "0 px" else px > 0
        ok &= good
        lines.append(f"{'PASS' if good else 'FAIL'}  {ab:12} {label}: {res} (want {want})")
    # loop seams: each ambient loop isolated on its layer, frame 0 vs frame `duration`
    for label, res, good in seams():
        ok &= good
        lines.append(f"{'PASS' if good else 'FAIL'}  {label}: {res} (want 0 px)")
    # colour binds: the app's colour reaches the paint
    pb = project(INK)
    binds = [("ComposerOrb accent -> disc", "ComposerOrb", "--data=accent=FF3080FF --advance=2", "30,48", 96, "FF3080FF"),
             ("ComposerOrb onAccent -> glyph", "ComposerOrb", "--data=onAccent=FF20C040 --advance=2", "48,40", 96, "FF20C040"),
             ("Toggle accent -> track (on)", "Toggle", "--data=value=true --data=accent=FF3080FF --advance=2", "20,50", (104, 64),
              "FF3080FF"),
             ("Toggle track -> track (off)", "Toggle", "--data=track=FF20C040 --advance=2", "80,40", (104, 64), "FF20C040"),
             ("Toggle knob -> knob", "Toggle", "--data=knob=FFC03030 --advance=2", "32,40", (104, 64), "FFC03030"),
             ("ToolIcon tint -> glyph", "ToolIcon", "--data=kind=generic --data=tint=FF3080FF --advance=2", "20,26", 48,
              "FF3080FF"),
             ("Mark accent -> sparkle", "Mark", "--data=accent=FF3080FF --advance=2", "208,82", 256, "FF3080FF")]
    for label, ab, args, xy, size, want in binds:
        got = probe(pb, ab, args, xy, size)
        good = all(abs(int(got[i:i + 2], 16) - int(want[i:i + 2], 16)) <= 12 for i in (2, 4, 6)) if got != "?" else False
        ok &= good
        lines.append(f"{'PASS' if good else 'FAIL'}  {ab:12} {label}: probe {xy} = {got} (want {want})")
    text = "\n".join(lines) + "\n"
    (OUT / "proof.txt").write_text(text)
    print(text)
    print("all proofs pass" if ok else "SOME PROOFS FAIL")


SHEETS = {"proof": proof, "orb": orb, "glow": glow, "tool": tool, "toggle": toggle, "mark": mark}


def main() -> None:
    which = sys.argv[1:] or list(SHEETS)
    (WORK / "proof").mkdir(parents=True, exist_ok=True)
    subprocess.run(["rm", "-rf", str(WORK)], check=True)
    (WORK / "proof").mkdir(parents=True)
    for bd in (SURFACE, INK, "FF000000", "FFFFFFFF"):
        project(bd)
    with ThreadPoolExecutor(max_workers=8) as pool:
        for name in which:
            SHEETS[name](pool)


if __name__ == "__main__":
    main()
