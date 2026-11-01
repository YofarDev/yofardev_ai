# M4 Task 6: the campfire diorama (rulings 12–14)

Rendered by `uv run --with pillow --with numpy rive/tools/review_campfire.py <M3 poster.webp>`
(real CLI renders of `rive/scenes/campfire`, 1080×1920, `--fit=contain`).

| File | What |
|---|---|
| `poster_before_after.png` | M3 poster beside the M4 diorama poster (rest pose) |
| `parallax_sheet.png` | `parallaxX` −1/0/1 (columns) × `parallaxY` −1/0/1 (rows) |
| `parallax_edges.png` | the same nine renders at half size: outer 32 px of the left and right edges (columns), bottom 32 px (rows) |
| `fire_strip.png` | 10 frames across one 89-frame `amb_firelight` loop: flames, glow, light pool and tree glow |
| `events_check.png` | flare, rain, shootingStar, owlHoot mid-event, and the flare at parallax (1, 1) |
| `gates.txt` | opaque frame at all 9 parallax corners, measured plane travel, firelight seam, sizes (all ok) |

What the file does (`gen_scenes.campfire_diorama`, ids from 990000 so every M3/v7 id stays):

- **Planes.** `Plane0` sky, aurora, stars, moon, shooting star (gain 0, no bind) · `Plane1`
  mountains, far hills, far pines (0.15) · `Plane2` valley mist, mid hills (0.3) · `Plane3` near
  pines, owl, snag (0.5) · `Plane4` ground, trail, light pool, tree glow, grass, tent, fire, logs,
  stones, smoke, fireflies (0.7) · `Plane5` the two foreground bushes (1.0). Each bound
  `x = gain × 40 × parallaxX`, `y = gain × 24 × parallaxY`; 9 shared `k × input` formula converters
  (one per distinct travel; 0.5 × 24 and 0.3 × 40 share `12`). Rain and the flare wash stay in
  screen space in front.
- **Fog veils** `FogVeil0..2`, the front child of `Plane0..2`: a vertical gradient from clear to the
  bound `lightFog` (clear at y 700 / 700 / 880, full at 1000 / 1000 / 1060, the moon stays clear).
- **Firelight.** `amb_firelight` (89 frames) also keys `LightPoolFlicker` (a wrapper: the rain
  event owns the pool's own opacity) 0.75–1.0 and `TreeGlow` 0.7–1.0, in phase with the fire glow.
- **Colour.** Light sources are `emit*` (fire and everything under `emitFireFlare`, stars, glints,
  moon and moon glow, shooting star, coal bed, fireflies, log heat, tent lantern); their paints are
  named `emit` so the line-based lint sees it. Every other colour goes through
  `art_bible.fit_colour(c, "campfire")` in `Scene.fit_colours`. Lint: `ok`.

Rulings and deviations:

- **Fog density.** `lightFog`'s own alpha (0x33) multiplied a single fill down to 0.11 / 0.07 / 0.04:
  no visible change (measured ≤ 1/255). Each veil stacks 4 bound fills and takes the opacity at which
  the stack reaches ruling 14's 0.55 / 0.35 / 0.18 at the default fog (`fog_opacity`); another fog
  colour scales the veils with it, alpha 0 removes them.
- **Ramps after fitting.** The fit greyed the teal night sky (saturation cap 0.55): the sky ramp
  moves to indigo with a little more value (`FF161E30` / `FF202F40` / `FF3E4459`, `scene_art`), and
  the light pool and tree glow gain alpha (B4/50, 48) to keep the warm pool after their saturation
  drop.
- **Trail on Plane4**, not Plane5: it lies on the ground, a different gain would slide it off.
- **Hit zones stay unparallaxed** (artboard root, contract names unchanged): the largest drift is
  the owl's 20 px against a 110×130 zone.
- The flicker is not bound to `lightFlicker` (the campfire's own rig is 1.0; Dart never writes a
  steadier one for this file).

Self-check (ruling 17, objective defects only): no revealed edge at any parallax corner (alpha and
edge strips), no broken shapes in the four events, lint clean, firelight seam 0/255, budget ok
(campfire.riv 163,509 → 166,786 B, poster 19,658 → 19,042 B). Found and fixed: veil 0 first started
at y 420 and dimmed the moon by a quarter; it now starts below the moon.
