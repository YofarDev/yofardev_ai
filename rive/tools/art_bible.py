"""The moonshot art bible, as generator parameters.

Every generator (avatar, scenes, UI kit, future rig DSL) reads its look from here, and the
critic loop scores against RUBRIC. Prose and rationale live in rive/ART_BIBLE.md; this module
is the source of truth for the numbers. Colours are ARGB hex strings (Rive RML format).

    uv run rive/tools/art_bible.py            # print a summary
    uv run rive/tools/art_bible.py lint X.rml --scene campfire   # colour-script lint
"""

from __future__ import annotations

from dataclasses import dataclass
import colorsys
import math
import re
import sys

# --- 1. App tokens (mirror of lib/core/design/tokens/app_palette.dart; tests keep them equal)

TOKENS: dict[str, str] = {
    "ink": "FF16121D",
    "surface": "FF211B2B",
    "onSurface": "FFF3EBDD",
    "outline": "FF3A3046",
    "livingRoomAccent": "FFF4B860",
    "campfireAccent": "FFFF8552",
    "beachAccent": "FFFF9478",
    "deepSpaceAccent": "FFB79CFF",
}

# --- 2. Character palette (ramps: light -> shadow -> deep shadow). Shadows shift toward the
# scene's ambient hue at render time (see LightRig); these are the neutral-light values.

CHARACTER: dict[str, tuple[str, ...]] = {
    "skin": ("FFF6D3BC", "FFE3AE95", "FFD0937C"),
    "hair": ("FF795448", "FF3B2A26", "FF2A1D1A"),
    "cheek": ("66F08A7A",),
    "eyeWhite": ("FFFBF6EE", "FFE4DCD2"),
    "iris": ("FF4A3A5E", "FF2C2238"),
    "lineInk": ("FF2A1E24",),
}

# --- 3. Shape language: soft geometry, storybook proportions, no hard corners on anything
# the user looks at for long.


@dataclass(frozen=True)
class ShapeRules:
    head_to_body: float = 2.6  # total height / head height (chibi-leaning storybook)
    eye_line: float = 0.52  # eye line as a fraction of head height from the crown
    min_corner_ratio: float = 0.18  # corner radius / shortest side, for props and furniture
    max_corner_ratio: float = 0.5
    silhouette_min_contrast: float = 3.0  # character vs background luminance contrast
    tangent_min_px: float = 6.0  # min gap between near-touching contours (no "kissing" lines)


SHAPES: ShapeRules = ShapeRules()

# --- 4. Line weight, in artboard px for a 1080 px-tall frame. Interior lines are thinner than
# silhouettes; nothing under the 48 dp legibility floor.


@dataclass(frozen=True)
class LineRules:
    silhouette: float = 5.0
    interior: float = 3.0
    detail: float = 1.8
    min_visible: float = 1.4  # thinner disappears at 48 dp on a 1080p phone
    taper: bool = True  # strokes taper at open ends (TrimPath + width keys in the rig DSL)


LINES: LineRules = LineRules()

# --- 5. Colour script per scene: the light rig defaults (vision pillar 5) and the value
# budget. `value` is the allowed HSV value range for any fill in the scene, `sat_cap` the max
# saturation for anything that is not the accent or an emissive (fire, screen, star).


@dataclass(frozen=True)
class SceneScript:
    accent: str
    key: str  # key light colour
    key_dir: float  # radians, 0 = from the right, pi/2 = from above
    key_intensity: float
    rim: str
    ambient: str
    fog: str
    value: tuple[float, float]
    sat_cap: float
    times: dict[str, str]  # sky top colour per time of day (dawn, day, dusk, night)
    flicker: float = 0.0  # firelight flicker of the key light (0 steady, 1 full campfire)
    rim_intensity: float = 0.35  # rim light strength (the silhouette's back edge)
    ambient_amount: float = 0.35  # how far the shadow side leans to the ambient hue

    @property
    def key_xy(self) -> tuple[float, float]:
        """Direction toward the key light in viewer space (+x right, +y up), 3 digits: the
        contract's `lightKeyX`/`lightKeyY` (M4 ruling 4) and the Dart `LightRig.keyX/keyY`."""
        return round(math.cos(self.key_dir), 3), round(math.sin(self.key_dir), 3)


SCENES: dict[str, SceneScript] = {
    "livingRoom": SceneScript(
        accent=TOKENS["livingRoomAccent"], key="FFFFD49A", key_dir=2.4, key_intensity=0.85,
        rim="FF9FB8E6", ambient="FF2C3346", fog="33E0BC8C", value=(0.07, 0.92), sat_cap=0.62,
        times={"dawn": "FF7A86B8", "day": "FF9CC4E4", "dusk": "FF5A4A78", "night": "FF1A1F38"},
        flicker=0.15,
    ),
    "campfire": SceneScript(
        accent=TOKENS["campfireAccent"], key="FFFF9A4D", key_dir=4.2, key_intensity=1.0,
        rim="FF6F8FD8", ambient="FF141C2C", fog="3320304A", value=(0.03, 0.95), sat_cap=0.55,
        times={"dawn": "FF4A5A88", "day": "FF7FA9CF", "dusk": "FF3A2E5C", "night": "FF0A1424"},
        flicker=1.0,
    ),
    "beach": SceneScript(
        accent=TOKENS["beachAccent"], key="FFFFC48A", key_dir=0.35, key_intensity=0.9,
        rim="FFFFE2C4", ambient="FF3E4F6A", fog="22FFD9C0", value=(0.10, 0.97), sat_cap=0.58,
        times={"dawn": "FFF0A98A", "day": "FF8CCBE0", "dusk": "FFE07A6A", "night": "FF16203A"},
        flicker=0.0,
    ),
    "deepSpace": SceneScript(
        accent=TOKENS["deepSpaceAccent"], key="FFCDB8FF", key_dir=0.9, key_intensity=0.7,
        rim="FF7FE0FF", ambient="FF120E26", fog="331E1A44", value=(0.02, 0.95), sat_cap=0.70,
        times={"dawn": "FF120E26", "day": "FF120E26", "dusk": "FF120E26", "night": "FF070614"},
        flicker=0.0,
    ),
}

# --- 6. Motion principles as numbers (consumed by the motion-synthesis solvers, M4-M6).


@dataclass(frozen=True)
class MotionRules:
    anticipation: float = 0.18  # share of an action spent winding up
    overshoot: float = 0.12  # peak overshoot as a share of the travel
    settle_ms: int = 220
    part_offset_ms: int = 40  # head leads, torso follows, hair/cloth trail by n * offset
    hold_min_ms: int = 160  # a pose must read before the next one
    blink_ms: tuple[int, int] = (2600, 5200)  # random blink interval
    max_gesture_rate_hz: float = 1 / 1.5  # matches the 1.5 s gesture cooldown


MOTION: MotionRules = MotionRules()

# --- 7. Critic rubric (independent critic, renders + playback). Weights sum to 1.

RUBRIC: dict[str, float] = {
    "silhouette_readability": 0.15,
    "shape_language": 0.10,
    "colour_script_and_light": 0.15,
    "material_detail": 0.10,
    "acting_and_timing": 0.20,
    "secondary_motion": 0.10,
    "appeal": 0.15,
    "technical_cleanliness": 0.05,  # pops, seams, clipping, aliasing
}
TARGET_OVERALL: float = 9.3
TARGET_PER_ASSET: float = 9.0
HEAD_25D_GATE: float = 8.5  # M1 head prototype bar (M0 critic: 6.7)

# --- Colour-script lint -------------------------------------------------------------------

# Only colour-carrying attributes: a skinned file's packed `Weight values="16711935"` would
# otherwise read as a colour. `colorValue` is every colour in RML (SolidColor, GradientStop);
# `value` counts on KeyFrameColor lines only.
_HEX = re.compile(r'colorValue="([0-9A-Fa-f]{8}|[0-9A-Fa-f]{6})"')
_KEY_HEX = re.compile(r'<KeyFrameColor\b[^>]*?\bvalue="([0-9A-Fa-f]{8}|[0-9A-Fa-f]{6})"')
HIGHLIGHT_SAT_MAX = 0.12  # below this saturation a fill counts as a neutral highlight
EMISSIVE_PREFIX = "emit"  # nodes whose name starts with this are exempt (fire, screens, stars)


def hsv(argb: str) -> tuple[float, float, float]:
    rgb = argb[-6:]
    r, g, b = (int(rgb[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r, g, b)


def lint_colours(rml: str, scene: str) -> list[str]:
    """Return one message per colour literal outside the scene's value range or saturation cap.

    Fully transparent colours and the scene accent are always allowed. Lines containing an
    `emit*` name are skipped (emissives may exceed the caps by design).
    """
    script = SCENES[scene]
    problems: list[str] = []
    for lineno, line in enumerate(rml.splitlines(), 1):
        if f'name="{EMISSIVE_PREFIX}' in line:
            continue
        for m in [*_HEX.finditer(line), *_KEY_HEX.finditer(line)]:
            c = m.group(1).upper()
            if len(c) == 6:
                c = "FF" + c
            if c[:2] == "00" or c == script.accent:
                continue
            _, s, v = hsv(c)
            lo, hi = script.value
            # Near-neutral highlights (paper white, star glints, foam) may reach value 1.0.
            if v < lo or (v > hi and s > HIGHLIGHT_SAT_MAX):
                problems.append(f"{lineno}: {c} value {v:.2f} outside {lo:.2f}..{hi:.2f}")
            if s > script.sat_cap:
                problems.append(f"{lineno}: {c} saturation {s:.2f} > cap {script.sat_cap:.2f}")
    return problems


def fit_colour(argb: str, scene: str) -> str:
    """The nearest colour that passes `lint_colours` for `scene` (M4 ruling 13).

    Hue and alpha are kept; HSV value is clamped into the scene's range and saturation under
    its cap. The accent, fully transparent colours and near-neutral highlights (saturation at
    most HIGHLIGHT_SAT_MAX, which may exceed the value range) come back unchanged.
    """
    script = SCENES[scene]
    c = argb.upper()
    if len(c) == 6:
        c = "FF" + c
    if c[:2] == "00" or c == script.accent:
        return c
    h, s, v = hsv(c)
    lo, hi = script.value
    if s <= HIGHLIGHT_SAT_MAX and v >= lo:
        return c
    # Aim a hair inside the bounds so 8-bit rounding cannot push the result back out.
    s2 = min(s, script.sat_cap - 0.004)
    v2 = min(max(v, lo + 0.004), hi - 0.004)
    if (s2, v2) == (s, v):
        return c
    def ok(argb8: str) -> bool:
        _, so, vo = hsv(argb8)
        return so <= script.sat_cap and lo <= vo and (vo <= hi or so <= HIGHLIGHT_SAT_MAX)

    def hue_err(argb8: str) -> float:
        d = abs(hsv(argb8)[0] - h)
        return min(d, 1 - d)

    # 8-bit rounding of a dark colour can turn the hue by a few degrees: search the 27
    # neighbours of the rounded target for the passing one with the closest hue.
    for _ in range(8):
        base = [round(x * 255) for x in colorsys.hsv_to_rgb(h, s2, v2)]
        cands = [
            c[:2] + "".join(f"{min(255, max(0, base[i] + o[i])):02X}" for i in range(3))
            for o in ((dr, dg, db) for dr in (-1, 0, 1) for dg in (-1, 0, 1) for db in (-1, 0, 1))
        ]
        good = [x for x in cands if ok(x)]
        if good:
            return min(good, key=lambda x: (round(hue_err(x), 4), x != cands[13]))
        s2 -= 0.004
        v2 = min(max(v2, lo + 0.008), hi - 0.008)
    return cands[13]


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "lint":
        scene = argv[argv.index("--scene") + 1] if "--scene" in argv else "livingRoom"
        with open(argv[1], encoding="utf-8") as f:
            problems = lint_colours(f.read(), scene)
        print("\n".join(problems) or "ok")
        return 1 if problems else 0
    print(f"tokens {len(TOKENS)}, scenes {', '.join(SCENES)}, rubric {sum(RUBRIC.values()):.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
