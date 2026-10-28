"""Render the M1 wow-moment storyboards as labelled thumbnail sheets.

Each beat composites the scene poster with a headless avatar capture (mood / gesture /
phase via --data). Beats whose assets do not exist yet are drawn as labelled block-outs
(dashed boxes) on top of the nearest existing frame, so the sheet shows what is new.

    uv run --with pillow rive/tools/storyboard.py docs/superpowers/storyboards/2026-10-m1
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT: Path = Path(__file__).resolve().parents[2]
CELL_W: int = 270
CELL_H: int = 480
CAPTION_H: int = 92
AVATAR_BG: tuple[int, int, int] = (29, 29, 29)  # rive.yaml background of rive/avatar


@dataclass(frozen=True)
class Beat:
    shot: str
    text: str
    scene: str
    data: tuple[str, ...] = ()
    advance: int = 40
    zoom: float = 1.0  # 1 = wide/medium framing, >1 = push-in
    blockouts: tuple[str, ...] = field(default_factory=tuple)


BOARDS: dict[str, list[Beat]] = {
    "wow1_campfire_rain": [
        Beat("WIDE", "Night, rain where the user lives. Fire flickers, steam off wet logs.", "campfire",
             ("phase=idle",), blockouts=("rain + steam layer",)),
        Beat("MEDIUM", "User asks. Avatar listens, leaning in; eyes on the caret.", "campfire",
             ("phase=waiting",), zoom=1.3, blockouts=("lean (rig)",)),
        Beat("MEDIUM", "Inhale before speaking: shoulders rise, lips part.", "campfire",
             ("phase=generating", "mood=thinking"), zoom=1.3, blockouts=("breath",)),
        Beat("CLOSE", "Speaks: lips close on every p/b/m (closed loop).", "campfire",
             ("phase=speaking", "mouth=0"), zoom=1.8, blockouts=("visemes",)),
        Beat("CLOSE", "Pitch rises at the question: brows lift.", "campfire",
             ("phase=speaking", "mood=surprised", "mouth=2"), zoom=1.8, blockouts=("AU browInnerUp",)),
        Beat("CLOSE", "Firelight flickers on cheek and glasses (shared light rig).", "campfire",
             ("phase=speaking", "mood=happy", "mouth=1"), zoom=1.8, blockouts=("light rig on avatar",)),
        Beat("MEDIUM", "Full stop: settles, blink moved into the pause.", "campfire",
             ("phase=idle", "mood=happy"), zoom=1.3),
    ],
    "wow2_tokyo_weather": [
        Beat("MEDIUM", "'What's the weather in Tokyo?'", "livingRoom", ("phase=waiting",), zoom=1.3),
        Beat("MEDIUM", "Tool call starts: head turns to a real 3/4 view.", "livingRoom",
             ("phase=generating", "mood=thinking"), zoom=1.3, blockouts=("2.5D head yaw 0.6",)),
        Beat("INSERT", "Pulls out a small tablet; its screen lights the face.", "livingRoom",
             ("gestureId=think", "gesture=true"), advance=30, zoom=1.6, blockouts=("tablet prop", "screen light")),
        Beat("CLOSE", "Reads; eyes scan the screen while the call runs.", "livingRoom",
             ("phase=generating",), zoom=1.8, blockouts=("gaze saccades",)),
        Beat("MEDIUM", "Glances back at the user, tablet lowers.", "livingRoom",
             ("phase=speaking", "mouth=2"), zoom=1.3, blockouts=("gaze: user",)),
        Beat("MEDIUM", "Answers; a nod on the stressed syllable.", "livingRoom",
             ("gestureId=nod", "gesture=true", "phase=speaking", "mouth=3"), advance=25, zoom=1.3),
    ],
    "wow3_scene_journey": [
        Beat("MEDIUM", "User: 'take me to the beach'.", "livingRoom", ("phase=waiting",), zoom=1.3),
        Beat("WIDE", "Camera pulls back to reveal the whole room.", "livingRoom", ("mood=happy",),
             zoom=0.85, blockouts=("camera pull-back",)),
        Beat("WIDE", "Avatar grabs a jacket from the hook.", "livingRoom", ("mood=happy",),
             zoom=0.85, blockouts=("jacket prop", "reach IK")),
        Beat("WIDE", "Walks out the door; next scene preloads.", "livingRoom", ("presence=leaveAndComeBack",),
             advance=60, zoom=0.85, blockouts=("door transition",)),
        Beat("WIDE", "Match cut: beach at the user's local sunset.", "beach", (), zoom=0.85,
             blockouts=("sunset time-of-day",)),
        Beat("MEDIUM", "Walks in; 6-plane parallax follows the gyroscope.", "beach", ("mood=happy",),
             zoom=1.1, blockouts=("parallax planes",)),
    ],
}


def avatar_capture(beat: Beat, tmp: Path, index: int) -> Image.Image:
    png: Path = tmp / f"a{index}.png"
    args: list[str] = ["rive", str(ROOT / "rive/avatar"), f"--screenshot={png}", f"--advance={beat.advance}"]
    args += [f"--data={d}" for d in beat.data]
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    image: Image.Image = Image.open(png).convert("RGBA")
    # Key out the flat preview background (antialiased edges keep a faint fringe; fine at thumb size).
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = pixels[x, y]
            if (r, g, b) == AVATAR_BG:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def frame(beat: Beat, avatar: Image.Image) -> Image.Image:
    poster: Image.Image = Image.open(ROOT / f"assets/rive/posters/{beat.scene}.webp").convert("RGBA")
    canvas: Image.Image = poster.resize((CELL_W, CELL_H))
    aw: int = int(CELL_W * 0.95)
    small: Image.Image = avatar.resize((aw, int(avatar.height * aw / avatar.width)))
    canvas.alpha_composite(small, ((CELL_W - aw) // 2, CELL_H - small.height + 20))
    if beat.zoom != 1.0:
        w, h = int(CELL_W / beat.zoom), int(CELL_H / beat.zoom)
        x0, y0 = (CELL_W - w) // 2, int((CELL_H - h) * 0.45)
        canvas = canvas.crop((x0, y0, x0 + w, y0 + h)).resize((CELL_W, CELL_H))
    draw: ImageDraw.ImageDraw = ImageDraw.Draw(canvas)
    for i, label in enumerate(beat.blockouts):
        y: int = 14 + i * 34
        box: tuple[int, int, int, int] = (12, y, CELL_W - 12, y + 26)
        for x in range(box[0], box[2], 10):
            draw.line((x, box[1], min(x + 5, box[2]), box[1]), fill=(255, 210, 90, 255), width=2)
            draw.line((x, box[3], min(x + 5, box[2]), box[3]), fill=(255, 210, 90, 255), width=2)
        draw.text((box[0] + 6, y + 7), f"BLOCK-OUT: {label}", fill=(255, 210, 90, 255))
    return canvas


def caption(beat: Beat, number: int) -> Image.Image:
    strip: Image.Image = Image.new("RGBA", (CELL_W, CAPTION_H), (22, 18, 29, 255))
    draw: ImageDraw.ImageDraw = ImageDraw.Draw(strip)
    draw.text((8, 6), f"{number}. {beat.shot}", fill=(244, 184, 96, 255))
    words: list[str] = beat.text.split()
    line: str = ""
    y: int = 26
    for word in words:
        if len(line) + len(word) > 40:
            draw.text((8, y), line, fill=(243, 235, 221, 255))
            y += 15
            line = ""
        line = f"{line} {word}".strip()
    draw.text((8, y), line, fill=(243, 235, 221, 255))
    return strip


def render(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp: Path = Path(tmp_name)
        for name, beats in BOARDS.items():
            cols: int = min(len(beats), 4)
            rows: int = (len(beats) + cols - 1) // cols
            sheet: Image.Image = Image.new("RGBA", (cols * CELL_W, rows * (CELL_H + CAPTION_H)), (10, 8, 14, 255))
            for i, beat in enumerate(beats):
                cell: Image.Image = frame(beat, avatar_capture(beat, tmp, i))
                x, y = (i % cols) * CELL_W, (i // cols) * (CELL_H + CAPTION_H)
                sheet.alpha_composite(cell, (x, y))
                sheet.alpha_composite(caption(beat, i + 1), (x, y + CELL_H))
            sheet.convert("RGB").save(out_dir / f"{name}.png", optimize=True)
            print(out_dir / f"{name}.png")


if __name__ == "__main__":
    render(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/superpowers/storyboards/2026-10-m1")
