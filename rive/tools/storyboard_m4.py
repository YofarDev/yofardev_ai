"""Re-shoot the Wow #1 and Wow #2 storyboards against the M4 assets (rive/review/m4/wow/).

Same look as `storyboard.py` (scene poster + a headless capture of the real avatar, dashed
block-outs for what is not built yet), reusing its `frame` / `caption` helpers, but every beat
is a full CLI argument list, so it can write the v7 light rig, the listening lean, the breath,
the face AUs and the tablet prop (with mid-run steps).

    uv run --with pillow rive/tools/storyboard_m4.py [rive/review/m4/wow]

Writes wow1_campfire_rain.png, wow2_tokyo_weather.png, flicker.gif (campfire close-up, 1 s),
parallax_sweep.gif (campfire, parallaxX -1 -> 1) and gates.txt (objective self-check).
Rive runs are sequential (one CLI at a time). The tablet out -> hold -> away GIF is the one
`motion_review.py --tablet` already wrote (../tablet/out_hold_away.gif); it is not re-rendered.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw

HERE: Path = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import storyboard as sb  # noqa: E402
from art_bible import SCENES  # noqa: E402

ROOT: Path = sb.ROOT
AVATAR: Path = ROOT / "rive/avatar"
CAMPFIRE: Path = ROOT / "rive/scenes/campfire"
BG: tuple[int, int, int] = sb.AVATAR_BG
STEP: list[str] = ["--pointer=move@400,420"]  # lets the next --data step mid-run (costs one frame)

# Mirrors lib/core/design/tokens/scene_lights.dart (the campfire rig, written verbatim by the app).
CAMPFIRE_RIG: dict[str, str] = {
    "lightKey": "FFFF9A4D", "lightKeyIntensity": "1.0", "lightKeyX": "-0.49", "lightKeyY": "-0.872",
    "lightRim": "FF6F8FD8", "lightRimIntensity": "0.35", "lightAmbient": "FF141C2C",
    "lightAmbientAmount": "0.35", "lightFlicker": "1.0",
}
# lib/core/models/performance/mood_presets.dart, happy
HAPPY: dict[str, str] = {"mood": "happy", "auCheekRaise": "0.6", "auLidTighten": "0.1",
                         "auLipCornerPull": "0.7", "auBrowOuterUp": "0.3"}


def rig(scene: str) -> dict[str, str]:
    """The AvatarVM light numbers the app writes for `scene` (art_bible.SCENES = SceneLights.of)."""
    s = SCENES[scene]
    kx, ky = s.key_xy
    return {"lightKey": s.key, "lightKeyIntensity": str(s.key_intensity), "lightKeyX": str(kx),
            "lightKeyY": str(ky), "lightRim": s.rim, "lightRimIntensity": str(s.rim_intensity),
            "lightAmbient": s.ambient, "lightAmbientAmount": str(s.ambient_amount),
            "lightFlicker": str(s.flicker)}


def data(d: dict[str, str]) -> list[str]:
    return [f"--data={k}={v}" for k, v in d.items()]


@dataclass(frozen=True)
class Shot:
    beat: sb.Beat
    args: tuple[str, ...]  # CLI args after `rive <project> --screenshot=<png>`


def wow1() -> list[Shot]:
    r: dict[str, str] = {**CAMPFIRE_RIG, "autoBlink": "false"}
    def shot(label: str, text: str, extra: dict[str, str], advance: int, zoom: float,
             blockouts: tuple[str, ...] = (), shot_name: str = "MEDIUM") -> Shot:
        return Shot(sb.Beat(shot_name, text, "campfire", zoom=zoom, blockouts=blockouts),
                    (*data({**r, **extra}), f"--advance={advance}"))
    return [
        shot("establish", "Night, rain where the user lives; fire flickers, steam off the wet logs.",
             {"phase": "idle"}, 40, 1.0, ("rain + steam (world sync M7-M9)",), "WIDE"),
        shot("listen", "User types. Avatar leans in, eyes down on the composer caret (lean 1, eyeLeadPitch -0.6).",
             {"lean": "1", "eyeLeadPitch": "-0.6", "phase": "waiting"}, 40, 1.3),
        shot("inhale", "Inhale 350 ms before the first word: shoulders rise, lips part (breath 1).",
             {"breath": "1", "auJawDrop": "0.12", "phase": "idle"}, 40, 1.3),
        shot("pp", "Lips close on the p of 'person' (auLipPress 0.88, jaw 0).",
             {"auLipPress": "0.88", "auJawDrop": "0", "phase": "speaking"}, 40, 1.8, shot_name="CLOSE"),
        shot("question", "The question's pitch rises: inner and outer brows lift (hand-written AUs, as the prosody writes them).",
             {"auBrowInnerUp": "0.7", "auBrowOuterUp": "0.5", "auJawDrop": "0.3", "phase": "speaking"},
             40, 1.8, shot_name="CLOSE"),
        shot("firelight", "Firelight on the cheek and glasses: warm key from lower left, blue rim on the far edge.",
             {**HAPPY, "phase": "speaking"}, 61, 1.9, shot_name="CLOSE"),
        shot("settle", "Full stop: the face settles, the blink moves into the pause.",
             {**HAPPY, "phase": "idle"}, 90, 1.3),
    ]


def wow2() -> list[Shot]:
    r: dict[str, str] = {**rig("livingRoom"), "autoBlink": "false"}
    reading: dict[str, str] = {"yaw": "0.6", "pitch": "-0.5", "eyeLeadYaw": "0.35", "eyeLeadPitch": "-0.3"}
    back: dict[str, str] = {"prop": "none", "yaw": "0", "pitch": "0", "eyeLeadYaw": "0", "eyeLeadPitch": "0"}
    out: int = 29  # prop_tablet_out is 28 frames; the hold loop starts after it
    def plain(text: str, d: dict[str, str], adv: int, zoom: float, blockouts: tuple[str, ...] = (),
              name: str = "MEDIUM") -> Shot:
        return Shot(sb.Beat(name, text, "livingRoom", zoom=zoom, blockouts=blockouts),
                    (*data({**r, **d}), f"--advance={adv}"))
    def then_back(text: str, adv: int, adv2: int, d2: dict[str, str], zoom: float, name: str = "MEDIUM") -> Shot:
        # tablet out + hold, then (a step) prop none, head and gaze back to the user
        return Shot(sb.Beat(name, text, "livingRoom", zoom=zoom),
                    (*data({**r, **reading, "prop": "tablet"}), f"--advance={adv}", *STEP, *data(d2),
                     f"--advance={adv2}"))
    return [
        plain("'What's the weather in Tokyo?' The avatar listens.", {"phase": "waiting", "lean": "1"}, 40, 1.3),
        plain("The tool call starts: the head turns to a 3/4 view (yaw 0.6, pitch -0.5), the gaze leads.",
              {**reading, "phase": "generating", "mood": "thinking"}, 40, 1.1),
        plain("The tablet comes out (prop = tablet, frame 14 of 28); its screen starts to light the face.",
              {**reading, "prop": "tablet"}, 14, 1.0, ("Tokyo result on screen (tool data)",)),
        plain("Hold (frame 40 of the loop): reading, a cool screen glow under the chin and in the lenses.",
              {**reading, "prop": "tablet"}, out + 40, 1.0),
        then_back("Glance back at the user; the tablet goes away (prop none, yaw 0, away frame 10).",
                  out + 40, 10, back, 1.0),
        then_back("Tablet away, answering (jaw open, speaking).", out + 40, 40,
                  {**back, "phase": "speaking", "auJawDrop": "0.35"}, 1.3),
    ]


def capture(project: Path, args: tuple[str, ...] | list[str], png: Path) -> None:
    subprocess.run(["rive", ".", f"--screenshot={png}", *args], cwd=project, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def avatar_image(png: Path) -> Image.Image:
    image: Image.Image = Image.open(png).convert("RGBA")
    px = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = px[x, y]
            if (r, g, b) == BG:
                px[x, y] = (0, 0, 0, 0)
    return image


def sheet(name: str, shots: list[Shot], out: Path, tmp: Path, notes: list[str],
          background: Callable[[int], Image.Image] | None = None) -> None:
    """One storyboard sheet; `background(i)` gives beat i's scene image (default: the poster)."""
    cols: int = min(len(shots), 4)
    rows: int = (len(shots) + cols - 1) // cols
    cw, ch, cap = sb.CELL_W, sb.CELL_H, sb.CAPTION_H
    page: Image.Image = Image.new("RGBA", (cols * cw, rows * (ch + cap)), (10, 8, 14, 255))
    for i, s in enumerate(shots):
        png: Path = tmp / f"{name}_{i}.png"
        capture(AVATAR, s.args, png)
        av: Image.Image = avatar_image(png)
        # objective checks on the raw capture: something drawn, nothing cut at the sides or top,
        # avatar centred on the scene (the same placement the composite uses for every beat)
        alpha: Image.Image = av.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            notes.append(f"FAIL {name} beat {i + 1}: empty capture")
        else:
            l, t, r, b = bbox
            if l <= 0 or r >= av.width or t <= 0:
                notes.append(f"FAIL {name} beat {i + 1}: avatar touches the left/right/top frame edge {bbox}")
            cx: float = (l + r) / 2 / av.width
            if abs(cx - 0.5) > 0.12:
                notes.append(f"FAIL {name} beat {i + 1}: avatar off-centre ({cx:.2f})")
            # wide / medium shots: the sheet's crop must not cut the avatar (bubble, shoulders)
            if s.beat.zoom <= 1.3:
                sc: float = cw * 0.95 / av.width
                off: float = (cw - cw * 0.95) / 2
                top: float = ch - av.height * sc + 20 + t * sc
                x0: float = (cw - cw / s.beat.zoom) / 2
                y0: float = int((ch - ch / s.beat.zoom) * 0.45)
                if off + l * sc < x0 or off + r * sc > cw - x0 or top < y0:
                    notes.append(f"FAIL {name} beat {i + 1}: the {s.beat.zoom}x crop cuts the avatar")
            notes.append(f"ok   {name} beat {i + 1}: bbox {bbox}, centre {cx:.2f}")
        cell: Image.Image = sb.frame(s.beat, av, background(i) if background else None)
        x, y = (i % cols) * cw, (i // cols) * (ch + cap)
        page.alpha_composite(cell, (x, y))
        page.alpha_composite(sb.caption(s.beat, i + 1), (x, y + ch))
    path: Path = out / f"{name}.png"
    page.convert("RGB").save(path, optimize=True)
    print(path)


def save_gif(frames: list[Image.Image], path: Path, fps: int) -> None:
    pal: list[Image.Image] = [f.convert("RGB").quantize(256, dither=Image.Dither.NONE) for f in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=round(1000 / fps), loop=0)
    print(path)


def face_crop(av: Image.Image, box: tuple[int, int, int, int], scale: float = 2.5) -> Image.Image:
    """The campfire poster with the avatar placed as in `sb.frame`, at `scale` x the sheet's cell
    size, cropped to `box` (avatar capture pixels): a sharp close-up of the face."""
    cw, ch = int(sb.CELL_W * scale), int(sb.CELL_H * scale)
    canvas: Image.Image = Image.open(ROOT / "assets/rive/posters/campfire.webp").convert("RGBA").resize((cw, ch))
    aw: int = int(cw * 0.95)
    sc: float = aw / av.width
    small: Image.Image = av.resize((aw, int(av.height * sc)))
    ox, oy = (cw - aw) // 2, ch - small.height + int(20 * scale)
    canvas.alpha_composite(small, (ox, oy))
    l, t, r, b = box
    return canvas.crop((int(ox + l * sc), int(oy + t * sc), int(ox + r * sc), int(oy + b * sc))).convert("RGB")


def flicker_gif(out: Path, tmp: Path, notes: list[str]) -> None:
    """Campfire close-up (eyes to chin), 30 consecutive frames (1 s at 30 fps), full flicker."""
    r: dict[str, str] = {**CAMPFIRE_RIG, **HAPPY, "autoBlink": "false", "phase": "idle"}
    frames: list[Image.Image] = []
    for k in range(30):
        png: Path = tmp / f"fl_{k}.png"
        capture(AVATAR, (*data(r), f"--advance={61 + k}"), png)
        frames.append(face_crop(avatar_image(png), (170, 250, 630, 620)))
    # the flicker must be visible: some frame must differ from frame 0 on a real number of pixels
    base: Image.Image = frames[0].convert("L")
    worst: int = max(sum(1 for p in ImageChops.difference(base, f.convert("L")).get_flattened_data() if p > 6) for f in frames)
    notes.append(f"{'ok  ' if worst > 500 else 'FAIL'} flicker.gif: 30 frames, up to {worst} px differ from frame 0 by > 6/255")
    save_gif(frames, out / "flicker.gif", 30)


def parallax_gif(out: Path, tmp: Path, notes: list[str], project: Path = CAMPFIRE,
                 name: str = "parallax_sweep.gif") -> None:
    """A scene alone (default the campfire), parallaxX -1 -> 1 over 12 frames (8 fps: a sweep to
    read, not real time)."""
    frames: list[Image.Image] = []
    for k in range(12):
        v: float = -1 + 2 * k / 11
        png: Path = tmp / f"px_{k}.png"
        capture(project, (f"--data=parallaxX={v:.3f}", "--fit=contain", "--advance=1"), png)
        im: Image.Image = Image.open(png).convert("RGB").resize((360, 640))
        ImageDraw.Draw(im).text((10, 10), f"parallaxX {v:+.2f}", fill=(255, 210, 90))
        frames.append(im)
    first, last = frames[0].convert("L"), frames[-1].convert("L")
    moved: int = sum(1 for p in ImageChops.difference(first, last).get_flattened_data() if p > 16)
    notes.append(f"{'ok  ' if moved > 2000 else 'FAIL'} {name}: 12 frames, {moved} px differ between -1 and +1")
    save_gif(frames, out / name, 8)


def main(out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    notes: list[str] = []
    with tempfile.TemporaryDirectory() as t:
        tmp: Path = Path(t)
        sheet("wow1_campfire_rain", wow1(), out, tmp, notes)
        sheet("wow2_tokyo_weather", wow2(), out, tmp, notes)
        flicker_gif(out, tmp, notes)
        parallax_gif(out, tmp, notes)
    # the rig written for the campfire must be the one in lib/.../scene_lights.dart (a Python test
    # keeps art_bible equal to the Dart rig; this guards the hand-copied constants above)
    for k, v in rig("campfire").items():
        same: bool = (v == CAMPFIRE_RIG[k]) if k in ("lightKey", "lightRim", "lightAmbient") else float(v) == float(CAMPFIRE_RIG[k])
        if not same:
            notes.append(f"FAIL campfire rig {k}: art_bible {v} != storyboard {CAMPFIRE_RIG[k]}")
    (out / "gates.txt").write_text("\n".join(notes) + "\n")
    print("\n".join(notes))
    return 1 if any(n.startswith("FAIL") for n in notes) else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "rive/review/m4/wow"))
