# Art bible (moonshot)

Status: **signed off by the owner, 2026-10-28.** Nothing in the rig or head work (M1+) starts
until the owner signs this page and the [storyboards](../docs/superpowers/storyboards/2026-10-m1/README.md).

The numbers live in [`tools/art_bible.py`](tools/art_bible.py), which every generator imports. A test
(`tools/tests/test_art_bible.py`) keeps its tokens equal to `AppPalette`, so the art and the app
cannot drift apart. This page is the reasoning behind those numbers.

## 1. Look in one sentence

A **storybook at night**: soft, rounded shapes, warm light pools in a cool dark world, paper-white
highlights. It should feel hand-illustrated, and it is generated entirely from code.

## 2. Colour

- **App tokens are the anchor.**
  - Ink `#16121D` and surface `#211B2B` are the darkest the world gets behind UI.
  - Each scene's accent (livingRoom `#F4B860`, campfire `#FF8552`, beach `#FF9478`, deepSpace
    `#B79CFF`) is the key light's family.
- **Each scene has a colour script** (`SCENES`):
  - key, rim, ambient and fog colours;
  - a key-light direction;
  - a sky colour for each of dawn, day, dusk and night (the M4 world sync drives these);
  - a value range and a saturation cap.
- **Value budget.** Night scenes compress values: lit skin tops out around 0.9, not 1.0.
  Near-neutral highlights (saturation ≤ 0.12) may reach paper white. The scene's accent and
  nodes named `emit*` (fire, screens, stars) are exempt from the caps.
- **Lint.** `uv run rive/tools/art_bible.py lint <file.rml> --scene <id>` reports colour
  literals outside the scene's script. Today's art, which was made before the bible, is the
  baseline debt:

  | asset | hits | of which saturation |
  |---|---:|---:|
  | livingRoom | 192 (0 since the M5 diorama) | 8 |
  | campfire | 283 (0 since the M4 diorama) | 138 |
  | beach | 525 (0 since the M5 diorama) | 79 |
  | deepSpace | 190 (0 since the M5 diorama) | 15 |
  | avatar (living-room light) | 597 | n/a |

  Most hits are lit surfaces brighter than the night value range. New and rebuilt assets must
  lint clean. The four scene rebuilds in M4–M6 retire the scene debt.
- **Shadows move toward the ambient hue** of the scene's light rig. They are not a darker
  version of the same hue. The character palette (`CHARACTER`) gives neutral-light ramps; the
  shared light rig (vision pillar 5) tints them.

## 3. Shape language

From `ShapeRules`:

- **Proportions.** Storybook proportions: total height is 2.6 heads, and the eye line sits at
  52 % of head height.
- **Corners.** No hard corners on anything the eye rests on: props and furniture use a corner
  radius of 18–50 % of their shortest side.
- **Silhouette.** The silhouette must read against the background: a luminance contrast of at
  least 3:1 between character and scene, checked on posters.
- **No kissing lines.** Contours that nearly touch keep at least a 6 px gap.

## 4. Line

From `LineRules`, measured in px on a 1080 px frame:

| line | weight |
|---|---|
| silhouette | 5 |
| interior | 3 |
| detail | 1.8 |
| minimum | 1.4 (the 48 dp legibility floor) |

Open strokes taper. The ink colour is `#2A1E24`, never pure black.

## 5. Motion

From `MotionRules`, which feed the M4–M6 motion-synthesis solvers:

- 18 % anticipation and 12 % overshoot;
- a 220 ms settle;
- a 40 ms offset between body parts: the head leads, the torso follows, hair and cloth trail;
- every pose holds at least 160 ms;
- blinks every 2.6–5.2 s, moved into speech pauses;
- at most one gesture every 1.5 s.

## 6. Critic rubric

`RUBRIC` weights:

| criterion | weight |
|---|---:|
| acting and timing | 20 % |
| silhouette | 15 % |
| colour script and light | 15 % |
| appeal | 15 % |
| shape language | 10 % |
| material detail | 10 % |
| secondary motion | 10 % |
| technical cleanliness | 5 % |

Targets: the year-end bar is ≥ 9.0 per asset and ≥ 9.3 overall. The M1 2.5D head must reach
**8.5** before the rig commits to it (the M0 prototype scored 6.7).

## Sign-off

- [x] Owner approves the look, the colour scripts, the value budget and the rubric
      (or lists changes).
