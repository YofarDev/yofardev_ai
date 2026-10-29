"""Re-shoot the Wow #1 and Wow #2 storyboards against the M5 assets (rive/review/m5/wow/).

Same layout and gates as `storyboard_m4.py` (whose `sheet`, `capture`, `avatar_image`, `save_gif`
and `parallax_gif` it reuses), but the scene behind every beat is a live headless capture of the
scene's Rive file (`rive/scenes/<id>`, 1080x1920, `--fit=contain`) instead of the rest-pose poster:

- Wow #1: the campfire at `rain` 1 (contract v8: streaks, wet ground and tent, steam off the logs,
  the fire damped), each beat at its own frame inside the 3 s steam loop, so the rain moves from
  cell to cell; the avatar wears the campfire rig (M5 cheek firelight included, ruling 7); the
  firelight close-up is the loop frame where the cheek tint is strongest (measured here).
- Wow #2: the livingRoom diorama with the faired 3/4 head (yaw 0.6, pitch -0.5, ruling 1) and the
  tablet: out, hold, glance back, answering.

    uv run --with pillow --with numpy rive/tools/storyboard_m5.py [rive/review/m5/wow]

Writes wow1_campfire_rain.png, wow2_tokyo_weather.png, rain_steam.gif (campfire at rain 1, 2 s
real time, cropped to the fire and the tent), parallax_<scene>.gif for livingRoom, beach and
deepSpace (parallaxX -1 -> 1, 12 frames) and gates.txt; exit code 1 on any FAIL line. The yaw
sweep GIF is Task 2's (../head/yaw_sweep.gif), linked from the index, not re-rendered. Rive runs
are sequential (one CLI at a time).
"""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile

import numpy as np
from PIL import Image

HERE: Path = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import storyboard as sb  # noqa: E402
import storyboard_m4 as m4  # noqa: E402
from art_bible import SCENES  # noqa: E402

ROOT: Path = sb.ROOT
AVATAR: Path = m4.AVATAR
SCENE_DIR: Path = ROOT / "rive/scenes"
GIF_MAX: int = 3 * 1024 * 1024  # bytes per GIF
YAW_SWEEP: Path = ROOT / "rive/review/m5/head/yaw_sweep.gif"

# review_face.CHEEK_BOX (M5 light gate): the key-side lower cheek, avatar artboard px
CHEEK_BOX: tuple[int, int, int, int] = (338, 462, 362, 494)
# rive/review/m5/light/cheek.txt: blue shift (flicker minus steady) over the loop, -41.4 .. -30.0
CHEEK_PEAK_B: float = 41.4
# review_face.tint_silhouette: the loop's brightest frame is 45 (advance 46), one loop later
FIRE_PEAK_GUESS: int = 46 + 120
WOW1_SCENE_FRAME: int = 91  # mid steam loop (3 s = 180 frames); beat i renders 91 + 12 i


def scene_capture(scene: str, args: list[str], png: Path) -> Image.Image:
    m4.capture(SCENE_DIR / scene, (*args, "--fit=contain"), png)
    return Image.open(png).convert("RGBA")


def lum(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert("L"), dtype=np.int16)


def firelight_frame(tmp: Path, notes: list[str]) -> int:
    """The flicker frame near the loop's peak for the close-up: the happy speaking face at the
    campfire rig, five frames around the light review's brightest one; the one whose cheek blue
    drops most against the same frame at steady light (lightFlicker 0) wins."""
    base: dict[str, str] = {**m4.CAMPFIRE_RIG, **m4.HAPPY, "autoBlink": "false", "phase": "speaking"}
    best: tuple[float, int] = (0.0, FIRE_PEAK_GUESS)
    shifts: list[str] = []
    for adv in range(FIRE_PEAK_GUESS - 8, FIRE_PEAK_GUESS + 9, 4):
        means: list[float] = []
        for flick in ("1.0", "0"):
            png: Path = tmp / f"cheek_{adv}_{flick}.png"
            m4.capture(AVATAR, (*m4.data({**base, "lightFlicker": flick}), f"--advance={adv}"), png)
            box: np.ndarray = np.asarray(Image.open(png).convert("RGB").crop(CHEEK_BOX), dtype=float)
            means.append(float(box[..., 2].mean()))
        shift: float = means[1] - means[0]  # how much blue the firelit cheek lost
        shifts.append(f"{adv}: {shift:.1f}")
        if shift > best[0]:
            best = (shift, adv)
    ok: bool = best[0] >= 0.85 * CHEEK_PEAK_B
    notes.append(f"{'ok  ' if ok else 'FAIL'} firelight close-up: advance {best[1]}, cheek blue -{best[0]:.1f}/255 "
                 f"vs steady (light gate's loop peak -{CHEEK_PEAK_B}; gate >= 85 %); sampled {', '.join(shifts)}")
    return best[1]


def wow1(fire_adv: int) -> list[m4.Shot]:
    r: dict[str, str] = {**m4.CAMPFIRE_RIG, "autoBlink": "false"}

    def shot(text: str, extra: dict[str, str], advance: int, zoom: float, name: str = "MEDIUM") -> m4.Shot:
        return m4.Shot(sb.Beat(name, text, "campfire", zoom=zoom), (*m4.data({**r, **extra}), f"--advance={advance}"))
    return [
        shot("Night, rain where the user lives (rain 1, live render): streaks, wet ground and tent, steam off the logs.",
             {"phase": "idle"}, 40, 1.0, "WIDE"),
        shot("User types. Avatar leans in, eyes down on the composer caret (lean 1, eyeLeadPitch -0.6).",
             {"lean": "1", "eyeLeadPitch": "-0.6", "phase": "waiting"}, 40, 1.3),
        # FacePerformer's pre-roll at its peak: breath 1, jaw max(0.12 x breath, parted 0.10), no press
        shot("Inhale 350 ms before the first word: shoulders rise, lips part (breath 1, jaw 0.12, the pre-roll's peak).",
             {"breath": "1", "auJawDrop": "0.12", "auLipPress": "0", "phase": "idle"}, 40, 1.3),
        shot("Lips close on the p of 'person' (auLipPress 0.88, jaw 0).",
             {"auLipPress": "0.88", "auJawDrop": "0", "phase": "speaking"}, 40, 1.8, "CLOSE"),
        shot("The question's pitch rises: inner and outer brows lift (hand-written AUs, as the prosody writes them).",
             {"auBrowInnerUp": "0.7", "auBrowOuterUp": "0.5", "auJawDrop": "0.3", "phase": "speaking"}, 40, 1.8, "CLOSE"),
        shot(f"Firelight near the flicker's peak (frame {fire_adv - 1}): the key-side cheek and jaw turn orange, blue rim far side.",
             {**m4.HAPPY, "phase": "speaking"}, fire_adv, 1.9, "CLOSE"),
        shot("Full stop: the face settles, the blink moves into the pause.",
             {**m4.HAPPY, "phase": "idle"}, 90, 1.3),
    ]


def scene_frames(scene: str, data: list[str], n: int, first: int, step: int, tmp: Path,
                 notes: list[str], label: str) -> list[Image.Image]:
    """One live scene capture per beat (frames first, first + step, ...), each checked non-empty."""
    out: list[Image.Image] = []
    for i in range(n):
        adv: int = first + step * i
        im: Image.Image = scene_capture(scene, [*data, f"--advance={adv}"], tmp / f"{label}_scene_{i}.png")
        sd: float = float(lum(im).std())
        if im.size != (1080, 1920) or sd < 8:
            notes.append(f"FAIL {label} scene capture {i + 1}: size {im.size}, luminance std {sd:.1f} (empty?)")
        out.append(im)
    notes.append(f"ok   {label}: {n} live {scene} captures (frames {first - 1}..{first - 1 + step * (n - 1)}, "
                 f"{' '.join(data) or 'defaults'}), 1080x1920, none flat")
    return out


def rain_check(tmp: Path, notes: list[str]) -> None:
    """The Wow #1 scene really is the rained one: rain 1 vs rain 0 at the same frame."""
    wet: np.ndarray = lum(scene_capture("campfire", ["--data=rain=1", f"--advance={WOW1_SCENE_FRAME}"], tmp / "wet.png"))
    dry: np.ndarray = lum(scene_capture("campfire", [f"--advance={WOW1_SCENE_FRAME}"], tmp / "dry.png"))
    frac: float = float((np.abs(wet - dry) > 16).mean())
    notes.append(f"{'ok  ' if frac > 0.02 else 'FAIL'} campfire rain 1 vs 0 (frame {WOW1_SCENE_FRAME - 1}): "
                 f"{100 * frac:.1f} % of px differ by > 16/255")


def wow2() -> list[m4.Shot]:
    """M4's Wow #2 beats, unchanged: the faired head comes from the avatar file itself."""
    return m4.wow2()


def rain_steam_gif(out: Path, tmp: Path, notes: list[str]) -> None:
    """Campfire at rain 1, 2 s in real time (every 2nd frame at 30 fps), cropped to the fire,
    its steam and the tent (x 0-1080, y 760-1340), at 4/9 size (480 x 258)."""
    frames: list[Image.Image] = []
    for k in range(60):
        im: Image.Image = scene_capture("campfire", ["--data=rain=1", f"--advance={WOW1_SCENE_FRAME + 2 * k}"],
                                        tmp / f"rs_{k}.png")
        frames.append(im.crop((0, 760, 1080, 1340)).resize((480, 258), Image.Resampling.LANCZOS).convert("RGB"))
    steps: list[int] = [int((np.abs(lum(a) - lum(b)) > 16).sum()) for a, b in zip(frames, frames[1:])]
    path: Path = out / "rain_steam.gif"
    m4.save_gif(frames, path, 30)
    size: int = path.stat().st_size
    ok: bool = min(steps) > 200 and size <= GIF_MAX
    notes.append(f"{'ok  ' if ok else 'FAIL'} rain_steam.gif: 60 frames, every frame differs from the last "
                 f"({min(steps)}..{max(steps)} px > 16/255), {size:,} B")


def gif_size(path: Path, notes: list[str]) -> None:
    size: int = path.stat().st_size
    notes.append(f"{'ok  ' if size <= GIF_MAX else 'FAIL'} {path.name}: {size:,} B (<= {GIF_MAX:,})")


def main(out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    notes: list[str] = []
    with tempfile.TemporaryDirectory() as t:
        tmp: Path = Path(t)
        fire_adv: int = firelight_frame(tmp, notes)
        shots1: list[m4.Shot] = wow1(fire_adv)
        bg1: list[Image.Image] = scene_frames("campfire", ["--data=rain=1"], len(shots1), WOW1_SCENE_FRAME, 12,
                                              tmp, notes, "wow1_campfire_rain")
        rain_check(tmp, notes)
        m4.sheet("wow1_campfire_rain", shots1, out, tmp, notes, background=lambda i: bg1[i])
        shots2: list[m4.Shot] = wow2()
        bg2: list[Image.Image] = scene_frames("livingRoom", [], len(shots2), 91, 12, tmp, notes, "wow2_tokyo_weather")
        m4.sheet("wow2_tokyo_weather", shots2, out, tmp, notes, background=lambda i: bg2[i])
        rain_steam_gif(out, tmp, notes)
        for scene in ("livingRoom", "beach", "deepSpace"):
            name: str = f"parallax_{scene}.gif"
            m4.parallax_gif(out, tmp, notes, project=SCENE_DIR / scene, name=name)
            gif_size(out / name, notes)
    notes.append(f"{'ok  ' if YAW_SWEEP.exists() else 'FAIL'} yaw sweep: linked, not copied "
                 f"({YAW_SWEEP.relative_to(ROOT)}, {YAW_SWEEP.stat().st_size if YAW_SWEEP.exists() else 0:,} B)")
    # the campfire rig written to the avatar must be art_bible.SCENES (= SceneLights.of); Wow #2
    # takes its rig from SCENES directly (m4.rig)
    for k, v in m4.rig("campfire").items():
        c: str = m4.CAMPFIRE_RIG[k]
        same: bool = v == c if k in ("lightKey", "lightRim", "lightAmbient") else float(v) == float(c)
        notes.append(f"{'ok  ' if same else 'FAIL'} campfire rig {k}: art_bible {v}, written {c}")
    assert SCENES["livingRoom"]  # Wow #2's rig source
    (out / "gates.txt").write_text("\n".join(notes) + "\n")
    print("\n".join(notes))
    return 1 if any(n.startswith("FAIL") for n in notes) else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "rive/review/m5/wow"))
