# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Evidence for the M2 face rig and speech -> rive/avatar/review/face/.

    FACE_TRACE=presets FACE_OUT=rive/avatar/build/face/presets.json flutter test tool/face_speech_trace_test.dart
    FACE_TRACE=speech FACE_WAV=<wav> FACE_TEXT="<text>" [FACE_MOOD=happy] [FACE_LANG=fr] \
        FACE_OUT=rive/avatar/build/face/<name>.json flutter test tool/face_speech_trace_test.dart
    uv run rive/tools/review_face.py sheets                # au, moods, visemes, yaw (needs presets.json)
    uv run rive/tools/review_face.py yaw                   # 3/4 sheet + silhouette overlay + overhang gate (M3)
    uv run rive/tools/review_face.py blink                 # lid-sweep strip: neutral, happy, sad (M3)
    uv run rive/tools/review_face.py sides                 # v6 per-side offsets alone at +1, clamp cases (M3)
    uv run rive/tools/review_face.py fvs                   # f/v-s-th-pp-oh-ou at phone size (360 px) + close-up
    uv run rive/tools/review_face.py gates                 # history-free and clamp --compare gates (exit 1 on diff)
    uv run rive/tools/review_face.py speech <name> [...]   # strip + GIF per trace

Every cell is a real CLI render of rive/avatar driven through AvatarVM numbers exactly as the app
writes them (FaceFrame -> au*, lipTuck, tongueUp, roll, breath, pitch += nodPitch, autoBlink,
blink; speech traces also carry the head solver's yaw, hairLagYaw, hairLagPitch, eyeLeadYaw and
eyeLeadPitch, stepped after the face so the hair follows the nods). Renders run in parallel on one
project (screenshots only, no builds).
"""

from __future__ import annotations

from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = ROOT / "rive" / "avatar"
OUT = PROJ / "review" / "face"
DATA = PROJ / "build" / "face"
TMP = PROJ / "build" / "face_cells"
WORKERS = 6
# The jaw drops the chin ~15 artboard px at auJawDrop 1 (Rive 5ef775a): every face crop reaches
# below the dropped chin.
FACE_BOX = (270, 230, 530, 552)  # artboard window around the face, open jaw included
WIDE_BOX = (180, 150, 620, 700)  # head and shoulders (roll, breath, nods)
ZOOM = 1.6
AU_NAMES = ("browInnerUp", "browOuterUp", "browLower", "lidTighten", "upperLidRaise", "cheekRaise",
            "noseWrinkle", "lipCornerPull", "lipCornerDepress", "lipStretch", "lipPucker", "lipPress", "jawDrop",
            "dimpler")
SETTLE = 40  # frames: mood crossfades (240 ms) are done


def cli(png: Path, data: dict[str, str], advance: int, blink_at: int | None = None, scale: float = 1,
        proj: Path = PROJ) -> Path:
    png.parent.mkdir(parents=True, exist_ok=True)
    args = ["rive", str(proj), f"--screenshot={png}", *[f"--data={k}={v}" for k, v in data.items()]]
    if scale != 1:  # the artboard laid out at scale x its size (supersampled, or phone-sized below 1)
        args += [f"--viewport={round(800 * scale)}x{round(1000 * scale)}", "--fit=contain"]
    if blink_at is not None and 0 <= blink_at < advance:
        # the pointer move rests the eyes where they already look; it only lets --data step mid-run
        args += [f"--advance={advance - blink_at}", "--pointer=move@400,420", "--data=blink=1",
                 f"--advance={blink_at}"]
    else:
        args.append(f"--advance={advance}")
    res = subprocess.run(args, cwd=proj, capture_output=True, text=True)
    if res.returncode != 0:
        raise SystemExit(res.stdout[-2000:] + res.stderr[-2000:])
    return png


def gif_durations(n: int, fps: int) -> list[int]:
    """Per-frame GIF delays (ms) for [n] frames at [fps]: GIF stores whole centiseconds, so the
    delays follow the ideal clock rounded to 10 ms (30/30/40 at 30 fps) and every second of
    frames lasts exactly 1000 ms."""
    def at(k: int) -> int:
        return int(round(k * 100 / fps)) * 10
    return [at(k + 1) - at(k) for k in range(n)]


def save_gif(frames: list[Image.Image], out: Path, fps: int) -> None:
    """[frames] as a looping GIF playing at [fps] (see [gif_durations])."""
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=gif_durations(len(frames), fps),
                   loop=0, optimize=True)


def frame_data(f: dict, mood: str | None = None) -> dict[str, str]:
    d = {f"au{k[0].upper()}{k[1:]}": f"{v:.4f}" for k, v in f["au"].items()}
    # contract v6 per-side offsets (viewer's left / right), when the trace has them
    for side, t in (("left", "L"), ("right", "R")):
        d.update({f"au{k[0].upper()}{k[1:]}{t}": f"{v:.4f}" for k, v in f.get(side, {}).items() if v})
    d.update(lipTuck=f"{f['lipTuck']:.4f}", tongueUp=f"{f['tongueUp']:.4f}", roll=f"{f['roll']:.4f}",
             breath=f"{f['breath']:.4f}", pitch=f"{f['nodPitch']:.4f}",
             autoBlink="true" if f["autoBlink"] else "false")
    head = f.get("head")
    if head:
        # the avatar view writes the solver's pose and adds the nod to the pitch
        d.update(yaw=f"{head['yaw']:.4f}", hairLagYaw=f"{head['hairLagYaw']:.4f}",
                 hairLagPitch=f"{head['hairLagPitch']:.4f}", eyeLeadYaw=f"{head['eyeLeadYaw']:.4f}",
                 eyeLeadPitch=f"{head['eyeLeadPitch']:.4f}",
                 pitch=f"{max(-1.0, min(1.0, head['pitch'] + f['nodPitch'])):.4f}")
    if mood:
        d["mood"] = mood
    return d


def label(im: Image.Image, *lines: str) -> Image.Image:
    dr = ImageDraw.Draw(im)
    for i, t in enumerate(lines):
        dr.text((6, 4 + 12 * i), t, fill=(255, 230, 120))
    return im


def cell(png: Path, box: tuple[int, int, int, int], zoom: float = ZOOM) -> Image.Image:
    im = Image.open(png).convert("RGB").crop(box)
    return im.resize((int(im.width * zoom), int(im.height * zoom)), Image.Resampling.LANCZOS)


def render(jobs: list[tuple[str, dict[str, str], int, int | None]], sub: str,
           box: tuple[int, int, int, int] = FACE_BOX, zoom: float = ZOOM, scale: float = 1,
           tag_it: bool = True) -> list[Image.Image]:
    def one(j: tuple[str, dict[str, str], int, int | None]) -> Image.Image:
        tag, data, adv, blink = j
        png = cli(TMP / sub / (tag.replace(" ", "_").replace("/", "_") + ".png"), data, adv, blink, scale)
        im = cell(png, tuple(round(v * scale) for v in box), zoom / scale)  # type: ignore[arg-type]
        return label(im, tag) if tag_it else im
    with ThreadPoolExecutor(WORKERS) as ex:
        return list(ex.map(one, jobs))


def sheet(cells: list[Image.Image], cols: int, name: str) -> Path:
    w, h = cells[0].size
    out = Image.new("RGB", (w * cols, h * ((len(cells) + cols - 1) // cols)), (20, 18, 26))
    for k, c in enumerate(cells):
        out.paste(c, ((k % cols) * w, (k // cols) * h))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / name, optimize=True)
    return OUT / name


# ------------------------------------------------------------------ static sheets

def sheets() -> None:
    presets = json.loads((DATA / "presets.json").read_text())
    jobs = [("rest", {}, SETTLE, None)]
    jobs += [(f"{n} 1.0", {f"au{n[0].upper()}{n[1:]}": "1"}, SETTLE, None) for n in AU_NAMES]
    jobs += [("lipTuck 1.0", {"lipTuck": "1"}, SETTLE, None), ("tongueUp 1.0 jaw .3",
             {"tongueUp": "1", "auJawDrop": "0.3"}, SETTLE, None)]
    print("au_solo:", sheet(render(jobs, "au"), 6, "au_solo.png"))
    jobs = [(m, frame_data(f, m), SETTLE, None) for m, f in presets["moods"].items()]
    # the angry AUs on the neutral mood: no anger mark, the face alone has to read
    jobs.append(("angry AUs, no mark", frame_data(presets["moods"]["angry"]), SETTLE, None))
    print("moods:", sheet(render(jobs, "moods"), 4, "moods.png"))
    jobs = [(v, frame_data(f), SETTLE, None) for v, f in presets["visemes"].items()]
    print("visemes:", sheet(render(jobs, "visemes"), 5, "visemes.png"))
    yaw_sheet()


# ------------------------------------------------------------------ 3/4 turn (M3)

YAWS = ("-1", "-0.5", "0", "0.5", "1")
YAW_ROWS = (("neutral", "moods"), ("happy", "moods"), ("aa", "visemes"), ("ff", "visemes"))
YAW_BOX = (226, 236, 574, 566)  # the turned face with both cheeks, the ears and the open jaw
YAW_ZOOM = 1.25
FACE_INK = (110, 235, 255)  # this pose's face silhouette
REST_INK = (255, 200, 80)  # the same row at yaw 0
CLIPPED = ("mouth", "lens", "blush")  # groups clipped by the face: their unclipped overhang is the gate
EDGE_YS = (370, 400, 430, 460, 490, 505)  # artboard rows where the silhouette edges are measured


def variant(name: str) -> Path:
    """A throwaway copy of rive/avatar for review renders only: `mask` draws the face shape on top of
    the head in flat magenta (its silhouette, hair and all), `noclip_<group>` removes the face clip
    from that group (what the clip hides is the overhang)."""
    out = TMP / "variants" / name
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy(PROJ / "rive.yaml", out / "rive.yaml")
    tree = ET.parse(PROJ / "avatar.rml")
    parent = {c: p for p in tree.iter() for c in p}
    face = next(e for e in tree.iter("Shape") if e.get("name") == "Face")
    if name == "mask":
        holder = parent[face]
        holder.remove(face)
        holder.insert(0, face)
        for paint in face:
            if paint.tag in ("Fill", "Stroke"):
                for c in list(paint):
                    paint.remove(c)
                ET.SubElement(paint, "SolidColor", colorValue="FFFF00FF", id=f"0:{3_900_000 + len(paint.tag)}")
    else:
        group = name.removeprefix("noclip_")
        roots = {"mouth": ["Mouth"], "blush": ["Blush"], "lens": ["LensL", "LensR", "Glare", "Glare2", "HingeL", "HingeR"]}[group]
        for top in [e for e in tree.iter() if e.get("name") in roots]:
            for e in top.iter():
                for c in [c for c in e if c.tag == "ClippingShape" and c.get("sourceId") == face.get("id")]:
                    e.remove(c)
    tree.write(out / "avatar.rml", encoding="unicode")
    return out


def _mask(png: Path) -> Image.Image:
    r, g, b = Image.open(png).convert("RGB").split()
    hot = ImageChops.multiply(r.point(lambda v: 255 if v > 170 else 0), b.point(lambda v: 255 if v > 170 else 0))
    return ImageChops.multiply(hot, g.point(lambda v: 255 if v < 110 else 0))


def _edge(mask: Image.Image, size: tuple[int, int]) -> Image.Image:
    big = mask.resize(size, Image.Resampling.BILINEAR).point(lambda v: 255 if v >= 128 else 0)
    return ImageChops.subtract(big, big.filter(ImageFilter.MinFilter(3)))


def _edges_at(mask: Image.Image, y: int) -> tuple[int, int] | None:
    row = [x for x in range(mask.width) if mask.getpixel((x, y))]
    return (row[0], row[-1]) if row else None


def _overhang(a: Path, b: Path) -> int:
    diff = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB")).crop(YAW_BOX)
    return sum(1 for v in diff.convert("L").get_flattened_data() if v > 40)


def yaw_sheet() -> None:
    """Yaw -1 .. 1 x neutral / happy / aa / ff as the app writes them (presets.json). face_yaw.png:
    the renders; face_yaw_outline.png: the same with the face silhouette traced (cyan: this pose,
    amber: the row at yaw 0), from a variant that draws the face shape on top in magenta;
    face_yaw.txt: the silhouette edges per row height and, per clipped group (mouth, lenses,
    blush), the pixels its face clip hides (0 = nothing hangs past the outline). Exit 1 if any
    group hangs past the outline by more than 25 px in any cell."""
    presets = json.loads((DATA / "presets.json").read_text())
    jobs = [(f"{m} yaw {y}", {**frame_data(presets[k][m], m if k == "moods" else None), "yaw": y,
                              "autoBlink": "false"}, SETTLE, None)
            for m, k in YAW_ROWS for y in YAWS]
    projs = {"": PROJ, **{v: variant(v) for v in ("mask", *(f"noclip_{g}" for g in CLIPPED))}}

    def one(j: tuple[str, dict[str, str], int, int | None], v: str) -> Path:
        tag, data, adv, _ = j
        return cli(TMP / "yaw" / (v or "plain") / (tag.replace(" ", "_") + ".png"), data, adv, proj=projs[v])
    with ThreadPoolExecutor(WORKERS) as ex:
        pngs = {v: list(ex.map(lambda j, v=v: one(j, v), jobs)) for v in projs}
    size = (round((YAW_BOX[2] - YAW_BOX[0]) * YAW_ZOOM), round((YAW_BOX[3] - YAW_BOX[1]) * YAW_ZOOM))
    plain = [label(cell(p, YAW_BOX, YAW_ZOOM), j[0]) for p, j in zip(pngs[""], jobs)]
    print("yaw:", sheet(plain, len(YAWS), "face_yaw.png"))
    masks = [_mask(p) for p in pngs["mask"]]
    traced = []
    for k, (p, j) in enumerate(zip(pngs[""], jobs)):
        im = cell(p, YAW_BOX, YAW_ZOOM)
        rest = masks[k - k % len(YAWS) + YAWS.index("0")]
        for m, ink in ((rest, REST_INK), (masks[k], FACE_INK)):
            im.paste(Image.new("RGB", size, ink), (0, 0), _edge(m.crop(YAW_BOX), size))
        traced.append(label(im, j[0], "cyan: face outline", "amber: same row at yaw 0"))
    print("yaw outline:", sheet(traced, len(YAWS), "face_yaw_outline.png"))
    lines = ["3/4 turn evidence (review_face.py yaw): face silhouette edges in artboard px (left / right) and",
             "per clipped group the pixels its face clip hides (unclipped render vs shipped; 0 = inside)", ""]
    worst = 0
    for k, j in enumerate(jobs):
        edges = [_edges_at(masks[k], y) for y in EDGE_YS]
        cols = "  ".join(f"y{y} {e[0]}/{e[1]}" if e else f"y{y} -" for y, e in zip(EDGE_YS, edges))
        over = {g: _overhang(pngs[""][k], pngs[f"noclip_{g}"][k]) for g in CLIPPED}
        worst = max(worst, *over.values())
        lines.append(f"{j[0]:<18} {cols}   " + "  ".join(f"{g} {n}" for g, n in over.items()))
    lines += ["", f"worst overhang: {worst} px (gate <= 25)"]
    (OUT / "face_yaw.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if worst > 25:
        raise SystemExit(1)


# ------------------------------------------------------------------ blink (M3 lid sweep)

EYES_BOX = (288, 326, 512, 434)  # both eyes and the (taller, M3 round 2) glasses
BLINK_FRAMES = (0, 1, 2, 3, 4, 5, 7, 9, 11, 14)  # frames after the `blink` trigger (blink_once: 16)


def blink() -> None:
    """One row per mood (neutral, happy, sad): the `blink` trigger fired with autoBlink off, then
    the frames after it. Closed on frames 3-5; the lids reopen to the mood's AU pose."""
    presets = json.loads((DATA / "presets.json").read_text())
    jobs = []
    for m in ("neutral", "happy", "sad"):
        data = {**frame_data(presets["moods"][m], m), "autoBlink": "false"}
        for k in BLINK_FRAMES:
            jobs.append((f"{m} +{k}", data, SETTLE + max(k, 1), k if k else None))
    cells = render(jobs, "blink", EYES_BOX, 2.0, scale=2)
    print("blink:", sheet(cells, len(BLINK_FRAMES), "blink.png"))


# ------------------------------------------------------------------ per-side offsets (M3, contract v6)

SIDED = ("browInnerUp", "browOuterUp", "browLower", "lidTighten", "cheekRaise", "lipCornerPull", "lipCornerDepress")


def au(n: str, side: str = "") -> str:
    return f"au{n[0].upper()}{n[1:]}{side}"


def clamp_case(n: str) -> dict[str, str]:
    """Review Focus 1: the symmetric AU full on, the left offset +1 and the right -1 -> a full left
    pose and a neutral right side (the sums clamp to 0..1)."""
    return {au(n): "1", au(n, "L"): "1", au(n, "R"): "-1"}


def sides() -> None:
    """Each of the 14 offsets alone at +1 on a neutral face, then the clamp case next to the plain
    full-left pose it must equal."""
    jobs = [("rest", {"autoBlink": "false"}, SETTLE, None)]
    for n in SIDED:
        for t in ("L", "R"):
            jobs.append((f"{n}{t} +1", {au(n, t): "1", "autoBlink": "false"}, SETTLE, None))
    jobs += [("browLower 1 L+1 R-1 (clamp)", {**clamp_case("browLower"), "autoBlink": "false"}, SETTLE, None),
             ("lipCornerPull 1 L+1 R-1", {**clamp_case("lipCornerPull"), "autoBlink": "false"}, SETTLE, None),
             ("smirk: pull .3 L+.7 R-.3",
              {au("lipCornerPull"): "0.3", au("lipCornerPull", "L"): "0.7", au("lipCornerPull", "R"): "-0.3",
               au("cheekRaise", "L"): "0.4", "autoBlink": "false"}, SETTLE, None)]
    print("sides:", sheet(render(jobs, "sides"), 6, "au_sides.png"))


# ------------------------------------------------------------------ f/v vs s at phone size (M3)

FVS = ("ff", "ss", "th", "pp", "oh", "ou")
PHONE = 360 / 800  # the artboard laid out 360 px wide, as on a phone
PHONE_BOX = (300, 300, 500, 548)  # the lower face with the dropped chin (artboard px)
MOUTH_BOX = (350, 452, 450, 536)


def fvs() -> None:
    """Visemes exactly as the app writes them (presets.json). Phone row: the artboard rendered 360
    px wide and cropped at 1:1, then the same pixels x3 (nearest) so the 1:1 row can be read here;
    close-up row: the mouth supersampled."""
    presets = json.loads((DATA / "presets.json").read_text())
    jobs = [(v, {**frame_data(presets["visemes"][v]), "autoBlink": "false"}, SETTLE, None) for v in FVS]
    phone = render(jobs, "fvs_phone", PHONE_BOX, 1.0, scale=PHONE, tag_it=False)
    big = [label(c.resize((c.width * 3, c.height * 3), Image.Resampling.NEAREST), v) for c, v in zip(phone, FVS)]
    print("phone 1:1:", sheet([label(c, v) for c, v in zip(phone, FVS)], len(FVS), "fvs_phone.png"))
    print("phone x3:", sheet(big, len(FVS), "fvs_phone_x3.png"))
    close = render(jobs, "fvs_close", MOUTH_BOX, 4.0, scale=4)
    print("close-up:", sheet(close, len(FVS), "fvs_closeup.png"))


# ------------------------------------------------------------------ gates (M3)

def capture(png: Path, steps: list[tuple[dict[str, str], int]]) -> list[str]:
    """CLI args: a first data set, then mid-run data steps (the pointer move lets --data step;
    every capture makes the same move at the same frame, so only the history differs)."""
    args = ["rive", str(PROJ), f"--screenshot={png}"]
    for i, (data, adv) in enumerate(steps):
        if i:
            args.append("--pointer=move@400,420")
        args += [f"--data={k}={v}" for k, v in data.items()]
        args.append(f"--advance={adv}")
    return args


def gates() -> None:
    """History-free: each pose reached from rest and from a different pose (all numbers rewritten)
    renders identically; clamp: au=1, L=+1, R=-1 renders identically to L=+1 alone.

    Turn poses (yaw / pitch, M3 Task 6) are reached from rest and from yaw -1 pitch +1. Any
    different yaw / pitch history leaves a few dozen antialiasing pixels 1/255 apart (16-63 px; the
    pre-Task-6 file shows 23-48 px on the same captures: a renderer artefact, not a pose difference;
    even yaw 1 from the start vs yaw 1 set at frame 20 does it), so they pass when no channel
    differs by more than 1. Since the jaw drives the outline bones (M3 critic round 1) every pose
    goes through them, so the same 1/255 tolerance applies to every history gate; clamp gates stay
    exact."""
    presets = json.loads((DATA / "presets.json").read_text())
    names = sorted({k for f in [*presets["moods"].values(), *presets["visemes"].values()]
                    for k in frame_data(f)} | {au(n, t) for n in SIDED for t in ("L", "R")})
    zero = {k: ("false" if k == "autoBlink" else "0") for k in names if k != "mood"}

    def full(d: dict[str, str]) -> dict[str, str]:
        return {**zero, **d, "autoBlink": "false"}

    poses = {"angry": frame_data(presets["moods"]["angry"]), "ff": frame_data(presets["visemes"]["ff"]),
             "ou": frame_data(presets["visemes"]["ou"]), "thinking": frame_data(presets["moods"]["thinking"]),
             "smirkL": {au("lipCornerPull", "L"): "1", au("cheekRaise", "L"): "0.5"}}
    other = full({**frame_data(presets["visemes"]["aa"]), **frame_data(presets["moods"]["happy"]),
                  au("browLower", "R"): "1", au("lipCornerDepress", "L"): "1"})
    # the 3/4 outline (M3 Task 6): contour, features and lens clips are formulas of yaw / pitch
    turn = {"yaw": "0", "pitch": "0"}
    turns = {"turnFar": {**turn, "yaw": "1", "pitch": "0.5"},
             "turnNearFF": {**frame_data(presets["visemes"]["ff"]), "yaw": "-0.5", "pitch": "-1"},
             "turnHappy": {**frame_data(presets["moods"]["happy"]), **turn, "yaw": "0.75"}}
    other_turn = {**other, "yaw": "-1", "pitch": "1"}
    out = TMP / "gates"
    out.mkdir(parents=True, exist_ok=True)
    jobs: list[tuple[str, Path, Path, list[str], list[str]]] = []
    for n, d in poses.items():
        a, b = out / f"hist_{n}_rest.png", out / f"hist_{n}_other.png"
        jobs.append((f"history {n}", a, b, capture(a, [(full({}), 20), (full(d), 40)]),
                     capture(b, [(other, 20), (full(d), 40)])))
    for n, d in turns.items():
        a, b = out / f"hist_{n}_rest.png", out / f"hist_{n}_other.png"
        jobs.append((f"turn history {n}", a, b, capture(a, [(full(turn), 20), (full(d), 40)]),
                     capture(b, [(other_turn, 20), (full(d), 40)])))
    for n in SIDED:
        a, b = out / f"clamp_{n}.png", out / f"left_{n}.png"
        jobs.append((f"clamp {n}", a, b, capture(a, [(full(clamp_case(n)), 40)]),
                     capture(b, [(full({au(n, "L"): "1"}), 40)])))

    def run(j: tuple[str, Path, Path, list[str], list[str]]) -> tuple[str, str]:
        tag, a, _b, ca, cb = j  # capture a, then capture b and let the CLI --compare it with a
        r = subprocess.run(ca, cwd=PROJ, capture_output=True, text=True)
        if r.returncode:
            raise SystemExit(r.stderr[-2000:])
        r = subprocess.run([*cb, f"--compare={a}"], cwd=PROJ, capture_output=True, text=True)
        found = re.search(r"\d+\.\d+% of pixels differ \(\d+ of \d+\)", r.stdout + r.stderr)
        if not found:
            raise SystemExit(f"{tag}: no --compare result\n{r.stdout[-1000:]}{r.stderr[-1000:]}")
        return tag, found.group(0)

    with ThreadPoolExecutor(WORKERS) as ex:
        res = list(ex.map(run, jobs))
    bad = 0
    for (tag, cmp), j in zip(res, jobs):
        same = cmp.startswith("0.00% of pixels differ (0 of")
        if "history" in tag and not same:
            delta = max(ImageChops.difference(Image.open(j[1]).convert("RGB"), Image.open(j[2]).convert("RGB"))
                        .getextrema(), key=lambda e: e[1])[1]
            same = delta <= 1
            cmp += f", max channel delta {delta}/255"
        print(f"{'ok ' if same else 'BAD'} {tag}: {cmp}")
        bad += not same
    if bad:
        raise SystemExit(f"{bad} gate(s) differ")


# ------------------------------------------------------------------ speech

def speech(name: str) -> None:
    tr = json.loads((DATA / f"{name}.json").read_text())
    frames = tr["frames"]
    spans = tr["timeline"]["visemes"]
    marks = tr["timeline"]["marks"]
    blinks: list[int] = []
    for i in range(1, len(frames)):
        if frames[i]["blinkSerial"] != frames[i - 1]["blinkSerial"]:
            blinks.append(i)

    def at(ms: float) -> str:
        for s in spans:
            if s["start"] <= ms < s["end"]:
                return s["v"]
        return "-"

    def mark_near(ms: float) -> str:
        out = [m["kind"] for m in marks if abs(m["at"] - ms) <= 50]
        return " ".join(out)

    jobs = []
    idx = list(range(0, len(frames), 2))  # 30 fps
    for i in idx:
        f = frames[i]
        last = max((b for b in blinks if b <= i), default=None)
        blink = (i - last) if last is not None and i - last < 16 else None
        sp = f["speech"]
        tag = f"{i:04d}"
        jobs.append((tag, frame_data(f, tr["mood"]), SETTLE + i, blink))
    cells = render(jobs, f"speech_{name}", WIDE_BOX, 0.9)
    for c, i in zip(cells, idx):
        sp = frames[i]["speech"]
        ms = sp * 1000
        label(c, "", f"t {frames[i]['t']:.2f}s", f"{at(ms) if sp >= 0 else 'idle'} {mark_near(ms) if sp >= 0 else ''}")
    OUT.mkdir(parents=True, exist_ok=True)
    save_gif(cells, OUT / f"speech_{name}.gif", 30)
    # contact strip: every 2nd rendered frame (15 fps) during speech, face crop, each cell labelled
    # with its time and the viseme (and any mark) under it
    face = []
    for c, i in zip(cells, idx):
        sp = frames[i]["speech"]
        if sp >= 0 and (i // 2) % 2 == 0:
            ms = sp * 1000
            face.append(strip_cell(c, f"{frames[i]['t']:.2f}s  sp {sp:.2f}", f"{at(ms)} {mark_near(ms)}".strip()))
    print("strip:", sheet(face, 10, f"speech_{name}_strip.png"))
    print("gif:", OUT / f"speech_{name}.gif")
    print("timing:", timing(name, tr, blinks))


STRIP_CROP = (0.2, 0.1, 0.8, 0.78)  # share of a WIDE_BOX cell: the face down past the dropped chin


def strip_cell(c: Image.Image, *lines: str) -> Image.Image:
    """One contact-strip cell: the face cropped out of a speech cell, then labelled (the GIF labels
    sit outside the crop)."""
    w, h = c.size
    a, b, x, y = STRIP_CROP
    return label(c.crop((int(w * a), int(h * b), int(w * x), int(h * y))), *lines)


def find_wav(name: str, tr: dict) -> Path | None:
    """The trace's audio: the path it records (`wav`, from the repo root unless absolute), else
    build/face/<name>.wav, else the speech fixture of that name."""
    found = [Path(tr["wav"]) if Path(tr["wav"]).is_absolute() else ROOT / tr["wav"]] if tr.get("wav") else []
    found += [DATA / f"{name}.wav", ROOT / "test" / "fixtures" / "speech" / f"{name}.wav"]
    return next((p for p in found if p.exists()), None)


def read_wav(path: Path) -> tuple[list[float], int]:
    """Mono samples in -1..1 and the sample rate of a RIFF WAV: PCM 8/16/24/32-bit or 32-bit float,
    any rate and channel count (channels averaged), unknown chunks skipped."""
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError(f"{path}: not a RIFF WAVE file")
    fmt: tuple[int, int, int, int] | None = None
    pcm = b""
    k = 12
    while k + 8 <= len(data):
        tag, size = data[k:k + 4], struct.unpack("<I", data[k + 4:k + 8])[0]
        body = data[k + 8:k + 8 + size]
        if tag == b"fmt ":
            code, channels, rate = struct.unpack("<HHI", body[:8])
            bits = struct.unpack("<H", body[14:16])[0]
            if code == 0xFFFE and len(body) >= 26:  # WAVE_FORMAT_EXTENSIBLE: the sub-format code
                code = struct.unpack("<H", body[24:26])[0]
            fmt = (code, channels, rate, bits)
        elif tag == b"data":
            pcm = body
        k += 8 + size + (size & 1)
    if fmt is None:
        raise ValueError(f"{path}: no fmt chunk")
    code, channels, rate, bits = fmt
    width = bits // 8
    n = len(pcm) // width
    if code == 3 and width == 4:
        vals = list(struct.unpack(f"<{n}f", pcm[:4 * n]))
    elif code == 1 and width == 1:
        vals = [(v - 128) / 128 for v in pcm[:n]]
    elif code == 1 and width == 2:
        vals = [v / 32768 for v in struct.unpack(f"<{n}h", pcm[:2 * n])]
    elif code == 1 and width == 3:
        vals = [int.from_bytes(pcm[3 * i:3 * i + 3], "little", signed=True) / 8388608 for i in range(n)]
    elif code == 1 and width == 4:
        vals = [v / 2147483648 for v in struct.unpack(f"<{n}i", pcm[:4 * n])]
    else:
        raise ValueError(f"{path}: unsupported WAV format {code}, {bits} bits")
    frames = len(vals) // channels
    mono = [sum(vals[f * channels:(f + 1) * channels]) / channels for f in range(frames)]
    return mono, rate


def head_value(f: dict, key: str) -> float:
    """A head solver number of a trace frame (0 for a frame without the solver's pose)."""
    return f.get("head", {}).get(key, 0.0)


def timing_curves() -> list[tuple[str, Callable[[dict], float], tuple[int, int, int]]]:
    """The timing chart's lanes: the face numbers the app writes, then the head solver's hair
    follow-through and eye lead (signed, drawn around the lane's middle)."""
    def signed(key: str, gain: float = 1) -> Callable[[dict], float]:
        return lambda f: 0.5 + 0.5 * gain * head_value(f, key)
    return [("jawDrop", lambda f: f["au"]["jawDrop"], (240, 200, 120)),
              ("lipPress", lambda f: f["au"]["lipPress"], (230, 110, 110)),
              ("lipPucker", lambda f: f["au"]["lipPucker"], (150, 190, 250)),
              ("lipStretch", lambda f: f["au"]["lipStretch"], (160, 220, 160)),
              ("lipTuck", lambda f: f["lipTuck"], (250, 160, 220)),
              ("browOuterUp", lambda f: f["au"]["browOuterUp"], (250, 230, 120)),
              ("browInnerUp", lambda f: f["au"]["browInnerUp"], (220, 200, 90)),
              # 0.5 + 0.8 x: a full-strength nod (-0.55) stays in the lane (x3 clipped every nod
              # past -0.33 into a flat-bottomed "square" dip)
              ("nodPitch (0.5+0.8x)", lambda f: 0.5 + 0.8 * f["nodPitch"], (200, 160, 250)),
              ("roll", lambda f: f["roll"], (120, 220, 230)),
              ("breath", lambda f: f["breath"], (180, 180, 180)),
              # the hair lags the head (and the face's nods and roll): 0.5 + x, so a lag shows
              # above or below the lane's middle
              ("hairLagPitch (0.5+x)", signed("hairLagPitch", 2), (240, 150, 90)),
              ("hairLagYaw (0.5+x)", signed("hairLagYaw", 2), (230, 120, 160)),
              ("eyeLeadYaw (0.5+0.5x)", signed("eyeLeadYaw"), (140, 230, 140)),
              ("eyeLeadPitch (0.5+0.5x)", signed("eyeLeadPitch"), (110, 200, 160))]


def timing(name: str, tr: dict, blinks: list[int]) -> Path:
    """One chart: waveform, viseme row, prosody marks, blinks (B) and gaze saccades (S) the
    performer asks for, and the face and head curves the app writes."""
    frames = tr["frames"]
    fps = tr["fps"]
    lead = tr["lead"]
    total = len(frames) / fps
    W, lane = 1800, 46
    curves = timing_curves()
    H = 90 + 30 + lane * len(curves) + 20
    im = Image.new("RGB", (W, H), (20, 18, 26))
    dr = ImageDraw.Draw(im)
    x0, x1 = 120, W - 20

    def X(t: float) -> float:
        return x0 + (x1 - x0) * t / total

    # the waveform: before, only build/face/<name>.wav was looked for, so the speech fixtures
    # (test/fixtures/speech, 16 kHz) drew an empty lane
    wav = find_wav(name, tr)
    if wav is not None:
        samples, sr = read_wav(wav)
        n = len(samples)
        step = max(1, n // (x1 - x0))
        for k in range(0, n, step):
            a = min(1.0, max(abs(v) for v in samples[k:k + step]))
            x = X(lead + k / sr)
            dr.line([(x, 45 - 40 * a), (x, 45 + 40 * a)], fill=(110, 110, 130))
    dr.text((6, 40), "audio", fill=(200, 200, 200))
    for sp in tr["timeline"]["visemes"]:
        a, b = X(lead + sp["start"] / 1000), X(lead + sp["end"] / 1000)
        col = (200, 70, 70) if sp["v"] == "pp" else (70, 90, 140) if sp["v"] != "sil" else (40, 40, 50)
        dr.rectangle([a, 92, b, 112], fill=col, outline=(20, 18, 26))
        if b - a > 14:
            dr.text((a + 2, 96), sp["v"], fill=(240, 240, 240))
    dr.text((6, 96), "viseme", fill=(200, 200, 200))
    for m in tr["timeline"]["marks"]:
        x = X(lead + m["at"] / 1000)
        col = {"pitchPeak": (250, 230, 120), "stress": (200, 160, 250), "pause": (120, 220, 230)}[m["kind"]]
        dr.line([(x, 88), (x, H - 10)], fill=col)
    for b in blinks:
        x = X(b / fps)
        dr.text((x - 3, 114), "B", fill=(255, 255, 255))
    for i in range(1, len(frames)):
        if frames[i].get("saccadeSerial", 0) != frames[i - 1].get("saccadeSerial", 0):
            dr.text((X(i / fps) - 3, 114), "S", fill=(140, 230, 140))
        if frames[i].get("gazeLock") and not frames[i - 1].get("gazeLock"):
            dr.text((X(i / fps) - 3, 114), "L", fill=(140, 230, 140))
    for i, (nm, fn, col) in enumerate(curves):
        top = 130 + lane * i
        dr.line([(x0, top + lane - 4), (x1, top + lane - 4)], fill=(50, 50, 60))
        dr.text((6, top + 12), nm, fill=col)
        pts = [(X(k / fps), top + lane - 4 - (lane - 8) * max(0.0, min(1.0, fn(f)))) for k, f in enumerate(frames)]
        dr.line(pts, fill=col, width=2)
    for k in range(int(total) + 1):
        dr.text((X(k) - 4, H - 14), f"{k}s", fill=(150, 150, 150))
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"speech_{name}_timing.png"
    im.save(out, optimize=True)
    return out


if __name__ == "__main__":
    what = sys.argv[1:] or ["sheets"]
    if what[0] == "sheets":
        sheets()
    elif what[0] == "blink":
        blink()
    elif what[0] == "sides":
        sides()
    elif what[0] == "fvs":
        fvs()
    elif what[0] == "yaw":
        yaw_sheet()
    elif what[0] == "gates":
        gates()
    elif what[0] == "speech":
        for n in what[1:]:
            speech(n)
    else:
        raise SystemExit(__doc__)
