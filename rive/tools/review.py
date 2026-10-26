"""Capture the actual Rive artwork, animation sheets, and loop seam evidence.

Run with a Python environment containing Pillow:
    python rive/tools/review.py

All output, including temporary isolated-loop projects, stays in build/rive-review.
No source art or shipped assets are changed by this tool.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import copy
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/rive-review"
PROJECTS = {"avatar": ROOT / "rive/avatar", **{s: ROOT / "rive/scenes" / s
            for s in ("livingRoom", "campfire", "beach", "deepSpace")}}


def run(project: Path, image: Path, *args: str) -> str:
    image.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["rive", str(project), f"--screenshot={image}", *args],
                            capture_output=True, text=True, check=True)
    # Check only this invocation, since Rive's file logs append across builds.
    if re.search(r"[1-9]\d* (?:errors|warnings)|runtime error|generator function", result.stderr, re.I):
        raise RuntimeError(result.stderr)
    return result.stderr


def sheet(paths: list[Path], labels: list[str], out: Path, width: int = 240, columns: int = 4) -> None:
    images = []
    for path, label in zip(paths, labels):
        image = Image.open(path).convert("RGB")
        image.thumbnail((width, 430))
        cell = Image.new("RGB", (width, image.height + 30), "#16252b")
        cell.paste(image, ((width - image.width) // 2, 30))
        ImageDraw.Draw(cell).text((10, 8), label, fill="#e9dbc0", font=ImageFont.load_default(size=13))
        images.append(cell)
    height = max(im.height for im in images)
    canvas = Image.new("RGB", (width * columns, height * ((len(images) + columns - 1) // columns)), "#16252b")
    for i, im in enumerate(images):
        canvas.paste(im, ((i % columns) * width, (i // columns) * height))
    canvas.save(out)


def make_project(path: Path, source: ET.Element, main: str) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "rive.yaml").write_text(f"name: review\nmain: {main}\noutput: {{dir: build}}\n")
    ET.ElementTree(source).write(path / "scene.rml", encoding="unicode")


def loop_seams(name: str, names: set[str] | None = None) -> list[dict]:
    original = ET.parse(PROJECTS[name] / f"{name}.rml").getroot()
    results = []
    for timeline in original.findall("Artboard/LinearAnimation"):
        if timeline.get("loopValue") != "loop":
            continue
        label = timeline.get("name")
        if names is not None and label not in names:
            continue
        path = OUT / "loops" / name / label
        source = copy.deepcopy(original)
        machine = source.find("Artboard/StateMachine")
        machine[:] = []
        layer = ET.SubElement(machine, "StateMachineLayer", {"name": "IsolatedLoop", "id": "99:1"})
        ET.SubElement(layer, "AnyState", {"id": "99:2"})
        ET.SubElement(layer, "ExitState", {"id": "99:3"})
        entry = ET.SubElement(layer, "EntryState", {"id": "99:4"})
        ET.SubElement(entry, "StateTransition", {"stateToId": "99:6", "id": "99:5"})
        ET.SubElement(layer, "AnimationState", {"animationId": timeline.get("id"), "id": "99:6"})
        make_project(path, source, source.find("Artboard").get("name"))
        a, b = path / "start.png", path / "end.png"
        run(path, a, "--advance=1", "--scale=0.35")
        run(path, b, f"--advance={int(timeline.get('duration')) + 1}", "--scale=0.35")
        diff = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB"))
        rgb = diff.tobytes()
        pixels = sum(any(rgb[i:i + 3]) for i in range(0, len(rgb), 3))
        results.append({"asset": name, "animation": label, "durationFrames": int(timeline.get("duration")),
                        "differentPixels": pixels, "identical": pixels == 0})
    return results


def captures(name: str) -> None:
    project = PROJECTS[name]
    paths = []
    frames = [1, 31, 61, 91, 121, 181, 241, 361]
    for frame in frames:
        path = OUT / name / f"ambient-{frame}.png"
        run(project, path, f"--advance={frame}", "--scale=0.45")
        paths.append(path)
    sheet(paths, [f"frame {f - 1}" for f in frames], OUT / f"{name}-motion.png")
    images = [Image.open(p).convert("RGB") for p in paths]
    durations = [round((b - a) * 1000 / 60) for a, b in zip(frames, frames[1:])] + [500]
    images[0].save(OUT / f"{name}-motion.gif", save_all=True, append_images=images[1:], duration=durations, loop=0)

    if name == "avatar":
        cases = [(m, [f"--data=mood={m}"]) for m in ("neutral", "happy", "sad", "angry", "surprised", "thinking", "embarrassed")]
        cases += [(c, [f"--data=costume={c}", "--data=mood=happy", "--data=mouth=2"])
                  for c in ("batman", "robocop", "soubrette", "singularity")]
        cases += [(h, [f"--data=hat={h}"]) for h in ("beanie", "backwardsCap", "frenchBeret", "swimCap", "santaHat", "redMagaCap")]
        paths = []
        for label, data in cases:
            path = OUT / name / f"look-{label}.png"
            run(project, path, *data, "--advance=40", "--scale=0.45")
            paths.append(path)
        sheet(paths, [c[0] for c in cases], OUT / "avatar-expressions-wardrobe.png", columns=6)
        paths = []
        for frame in (1, 9, 17, 25, 41, 63, 87, 112):
            path = OUT / name / f"wave-{frame}.png"
            run(project, path, "--data=gestureId=wave", "--data=gesture=true", "--data=mood=happy",
                f"--advance={frame}", "--scale=0.45")
            paths.append(path)
        sheet(paths, [p.stem for p in paths], OUT / "avatar-wave.png")
    else:
        source = ET.parse(project / f"{name}.rml").getroot()
        events = [e.get("value") for e in source.findall("DataEnumCustom/DataEnumValue")]
        paths = []
        for event in events:
            path = OUT / name / f"event-{event}.png"
            frame = {"shootingStar": 20, "meteor": 25, "flare": 30, "owlHoot": 40, "seagulls": 60,
                     "sunset": 240, "rain": 150, "catWalksBy": 100, "tvOn": 120, "bigWave": 80,
                     "warp": 90, "alienShip": 180, "nebulaPulse": 55}.get(event, 90)
            run(project, path, f"--data=eventId={event}", "--data=event=true", f"--advance={frame}", "--scale=0.45")
            paths.append(path)
        sheet(paths, events, OUT / f"{name}-events.png")
    if name != "avatar":
        run(project, OUT / f"{name}-landscape.png", "--advance=91", "--viewport=1280x720", "--fit=cover")


def composite(name: str) -> Path:
    """Render actual nested vectors with the app's cover/contain composition.

    No screenshot background removal or simulated paint is involved.
    """
    source = ET.parse(PROJECTS[name] / f"{name}.rml").getroot()
    avatar_text = (PROJECTS["avatar"] / "avatar.rml").read_text()
    avatar = ET.fromstring(re.sub(r"\b0:", "10:", avatar_text))
    avatar_board = avatar.find("Artboard")
    avatar_board.set("x", "1250")
    scene_board = source.find("Artboard")
    nested = ET.Element("NestedArtboard", {"id": "99:10", "artboardId": avatar_board.get("id"),
                         "isStateful": "true", "x": "0", "y": "570", "scaleX": "1.35", "scaleY": "1.35", "name": "AvatarPreview"})
    ET.SubElement(nested, "NestedStateMachine", {"id": "99:11", "animationId": avatar_board.get("defaultStateMachineId")})
    scene_board.insert(0, nested)
    source.extend(list(avatar))
    project = OUT / "composites" / name
    make_project(project, source, "Scene")
    path = OUT / f"{name}-with-avatar.png"
    run(project, path, "--advance=91", "--scale=0.5")
    return path


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        loop_results = [row for rows in pool.map(loop_seams, PROJECTS) for row in rows]
        list(pool.map(captures, PROJECTS))
        scenes = list(PROJECTS)[1:]
        images = list(pool.map(composite, scenes))
    # Parallel headless processes can differ by one or two colour levels in
    # gradient/antialias pixels. Re-capture those cases sequentially once;
    # acceptance still requires an actually pixel-identical pair, not tolerance.
    for name in PROJECTS:
        failed = {r["animation"] for r in loop_results if r["asset"] == name and not r["identical"]}
        if not failed:
            continue
        retry = {r["animation"]: r for r in loop_seams(name, failed)}
        for i, result in enumerate(loop_results):
            if result["asset"] == name and result["animation"] in retry:
                loop_results[i] = {**retry[result["animation"]], "firstCaptureDifferentPixels": result["differentPixels"]}
    (OUT / "loop-seams.json").write_text(json.dumps(loop_results, indent=2) + "\n")
    sheet(images, ["Living room", "Alpine camp", "Coast", "Deep space"], OUT / "environments.png", width=300)
    failures = [r for r in loop_results if not r["identical"]]
    print(f"{len(loop_results) - len(failures)}/{len(loop_results)} loop seams pixel-identical")
    for failure in failures:
        print(f"  {failure['asset']}/{failure['animation']}: {failure['differentPixels']} pixels")
    print(f"Review captures: {OUT}")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
