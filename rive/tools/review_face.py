# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Evidence for the M2 face rig and speech -> rive/avatar/review/face/.

    dart run tool/face_speech_trace.dart presets > rive/avatar/build/face/presets.json
    dart run tool/face_speech_trace.dart speech <wav> "<text>" [mood] > rive/avatar/build/face/<name>.json
    uv run rive/tools/review_face.py sheets                # au, moods, visemes, yaw (needs presets.json)
    uv run rive/tools/review_face.py blink                 # lid-sweep strip: neutral, happy, sad (M3)
    uv run rive/tools/review_face.py speech <name> [...]   # strip + GIF per trace

Every cell is a real CLI render of rive/avatar driven through AvatarVM numbers exactly as the app
writes them (FaceFrame -> au*, lipTuck, tongueUp, roll, breath, pitch += nodPitch, autoBlink,
blink). Renders run in parallel on one project (screenshots only, no builds).
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = ROOT / "rive" / "avatar"
OUT = PROJ / "review" / "face"
DATA = PROJ / "build" / "face"
TMP = PROJ / "build" / "face_cells"
WORKERS = 6
FACE_BOX = (270, 230, 530, 520)  # artboard window around the face
WIDE_BOX = (180, 150, 620, 700)  # head and shoulders (roll, breath, nods)
ZOOM = 1.6
AU_NAMES = ("browInnerUp", "browOuterUp", "browLower", "lidTighten", "upperLidRaise", "cheekRaise",
            "noseWrinkle", "lipCornerPull", "lipCornerDepress", "lipStretch", "lipPucker", "lipPress", "jawDrop",
            "dimpler")
SETTLE = 40  # frames: mood crossfades (240 ms) are done


def cli(png: Path, data: dict[str, str], advance: int, blink_at: int | None = None, scale: int = 1) -> Path:
    png.parent.mkdir(parents=True, exist_ok=True)
    args = ["rive", str(PROJ), f"--screenshot={png}", *[f"--data={k}={v}" for k, v in data.items()]]
    if scale != 1:  # supersampled: the artboard laid out at scale x its size
        args += [f"--viewport={800 * scale}x{1000 * scale}", "--fit=contain"]
    if blink_at is not None and 0 <= blink_at < advance:
        # the pointer move rests the eyes where they already look; it only lets --data step mid-run
        args += [f"--advance={advance - blink_at}", "--pointer=move@400,420", "--data=blink=1",
                 f"--advance={blink_at}"]
    else:
        args.append(f"--advance={advance}")
    res = subprocess.run(args, cwd=PROJ, capture_output=True, text=True)
    if res.returncode != 0:
        raise SystemExit(res.stdout[-2000:] + res.stderr[-2000:])
    return png


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
           box: tuple[int, int, int, int] = FACE_BOX, zoom: float = ZOOM, scale: int = 1) -> list[Image.Image]:
    def one(j: tuple[str, dict[str, str], int, int | None]) -> Image.Image:
        tag, data, adv, blink = j
        png = cli(TMP / sub / (tag.replace(" ", "_").replace("/", "_") + ".png"), data, adv, blink, scale)
        return label(cell(png, tuple(v * scale for v in box), zoom / scale), tag)  # type: ignore[arg-type]
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
    print("moods:", sheet(render(jobs, "moods"), 4, "moods.png"))
    jobs = [(v, frame_data(f), SETTLE, None) for v, f in presets["visemes"].items()]
    print("visemes:", sheet(render(jobs, "visemes"), 5, "visemes.png"))
    jobs = []
    for m in ("happy", "surprised", "sad"):
        for yaw in ("-0.84", "0", "0.84"):  # the app's widest turn (tool glance, head_target_mapper)
            d = frame_data(presets["moods"][m], m)
            d["yaw"] = yaw
            jobs.append((f"{m} yaw {yaw}", d, SETTLE, None))
    talk = frame_data(presets["visemes"]["aa"])
    for yaw in ("-0.84", "0", "0.84"):
        jobs.append((f"aa yaw {yaw}", {**talk, "yaw": yaw}, SETTLE, None))
    print("yaw:", sheet(render(jobs, "yaw"), 3, "face_yaw.png"))


# ------------------------------------------------------------------ blink (M3 lid sweep)

EYES_BOX = (296, 340, 504, 420)  # both eyes and the glasses
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
    cells[0].save(OUT / f"speech_{name}.gif", save_all=True, append_images=cells[1:], duration=33, loop=0,
                  optimize=True)
    # contact strip: every 2nd rendered frame (15 fps) during speech, face crop
    face = []
    for c, i in zip(cells, idx):
        if frames[i]["speech"] >= 0 and (i // 2) % 2 == 0:
            w, h = c.size
            face.append(c.crop((int(w * 0.2), int(h * 0.1), int(w * 0.8), int(h * 0.7))))
    print("strip:", sheet(face, 10, f"speech_{name}_strip.png"))
    print("gif:", OUT / f"speech_{name}.gif")
    print("timing:", timing(name, tr, blinks))


def timing(name: str, tr: dict, blinks: list[int]) -> Path:
    """One chart: waveform, viseme row, prosody marks, and the face curves the app writes."""
    import struct
    import wave
    frames = tr["frames"]
    fps = tr["fps"]
    lead = tr["lead"]
    total = len(frames) / fps
    W, lane = 1800, 46
    curves = [("jawDrop", lambda f: f["au"]["jawDrop"], (240, 200, 120)),
              ("lipPress", lambda f: f["au"]["lipPress"], (230, 110, 110)),
              ("lipPucker", lambda f: f["au"]["lipPucker"], (150, 190, 250)),
              ("lipStretch", lambda f: f["au"]["lipStretch"], (160, 220, 160)),
              ("lipTuck", lambda f: f["lipTuck"], (250, 160, 220)),
              ("browOuterUp", lambda f: f["au"]["browOuterUp"], (250, 230, 120)),
              ("browInnerUp", lambda f: f["au"]["browInnerUp"], (220, 200, 90)),
              ("nodPitch (x3)", lambda f: 0.5 + 1.5 * f["nodPitch"], (200, 160, 250)),
              ("roll", lambda f: f["roll"], (120, 220, 230)),
              ("breath", lambda f: f["breath"], (180, 180, 180))]
    H = 90 + 30 + lane * len(curves) + 20
    im = Image.new("RGB", (W, H), (20, 18, 26))
    dr = ImageDraw.Draw(im)
    x0, x1 = 120, W - 20

    def X(t: float) -> float:
        return x0 + (x1 - x0) * t / total

    wav = DATA / f"{name}.wav"
    if wav.exists():
        with wave.open(str(wav)) as w:
            n = w.getnframes()
            raw = w.readframes(n)
            sr = w.getframerate()
        samples = struct.unpack(f"<{n}h", raw[: 2 * n])
        step = max(1, n // (x1 - x0))
        for k in range(0, n, step):
            seg = samples[k:k + step]
            a = max(abs(v) for v in seg) / 32768
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
    for i, (nm, fn, col) in enumerate(curves):
        top = 130 + lane * i
        dr.line([(x0, top + lane - 4), (x1, top + lane - 4)], fill=(50, 50, 60))
        dr.text((6, top + 12), nm, fill=col)
        pts = [(X(k / fps), top + lane - 4 - (lane - 8) * max(0.0, min(1.0, fn(f)))) for k, f in enumerate(frames)]
        dr.line(pts, fill=col, width=2)
    for k in range(int(total) + 1):
        dr.text((X(k) - 4, H - 14), f"{k}s", fill=(150, 150, 150))
    out = OUT / f"speech_{name}_timing.png"
    im.save(out, optimize=True)
    return out


if __name__ == "__main__":
    what = sys.argv[1:] or ["sheets"]
    if what[0] == "sheets":
        sheets()
    elif what[0] == "blink":
        blink()
    elif what[0] == "speech":
        for n in what[1:]:
            speech(n)
    else:
        raise SystemExit(__doc__)
