# M5 Task 4: the living room as a diorama (rulings 3–6)

Rendered by
`uv run --with pillow --with numpy rive/tools/review_diorama.py livingRoom <M4 poster.webp>`
(real CLI renders of `rive/scenes/livingRoom`, 1080×1920, `--fit=contain`; pointer proofs are headless
`--pointer=click` runs that count the `event prop_tapped` log lines). The "before" poster is the M4
`assets/rive/posters/livingRoom.webp` (27,144 B), copied aside before regenerating.

| File | What |
|---|---|
| `poster_before_after.png` | M4 poster beside the M5 one |
| `parallax_sheet.png` | `parallaxX` −1/0/1 (columns) × `parallaxY` −1/0/1 (rows) |
| `parallax_edges.png` | the same nine at half size: outer 32 px of the left/right edges, bottom 32 px |
| `hit_zones.png` | parallaxX −1 / +1 with each hit zone where it now sits (green) and at rest (red) |
| `rain_strip.png` | `rain` 0 / 0.5 / 1 (rows) × frames 0, 40, 80 |
| `rain_glass.png` | the window at full size, `rain` 0 / 1 × frames 0, 10, 60 |
| `events_strip.png` | rest, `lightsOff`, `tvOn`, `catWalksBy` (mid-walk, on the ledge), `lightsOn` after `lightsOff` |
| `lamp_key.png` | the wall pool left of the shade at the default `lightKey` and at `FF60A0FF` |
| `gates.txt` | every objective gate, `ok` / `FAIL` per line (all ok) |

What changed (`gen_scenes.py`: `LIVING_ROOM_PLANES`, `living_room_light`, `DIORAMAS["livingRoom"]`):

- **Planes** (gains 0 / 0.15 / 0.3 / 0.5 / 0.7 of 40 × 24 px):
  - 0, the view: sky, moon, 12 new stars, skyline, city lights.
  - 1, the back wall: wall, wainscot, rail, panels, cornice, window frame, mullions, the rain on the glass.
  - 2: curtains and rod, the ledge under the window with the walking cat, shelves, picture, the lamp's
    wall pool (`LampGlow`) and `WallWarmth`.
  - 3: the TV unit with the sleeping cat, the floor with its planks, grain and light pools.
  - 4: rug, plant, floor lamp and its cone.
  - 5: empty, since the room has no foreground.

  The screen overlay is `Night` (lightsOff). Elements moved one plane from ruling 4 (execution ruling 53):
  - curtains 1 → 2;
  - ledge and cat walk on 2, because on Plane4 the cat would float 13 px off its ledge;
  - floor 4 → 3, because it must paint behind the TV unit standing on it.

  The content is regrouped back to front with the draw order kept inside each plane.
- **The view sits behind the wall.** Plane0 paints behind Plane1, so:
  - The wall and the frame gain an `Opening` rectangle with an even-odd fill.
  - The view runs 20 px past the glass.
  - Three wall lines that used to hide behind the old sky are cut:
    - the cornice stops under the frame;
    - the middle wall panel starts under the ledge.
- **Bleed:**
  - The wall and the wainscot run 50 px under the floor.
  - The floor, baseboard, planks and floor joints run 40–60 px past the frame.
  - The ledge runs 30 px past each side.
- **Lint clean.** 192 hits → 0. Every non-emissive colour goes through `fit_colour` and no colour
  needed re-picking: the largest shift is the cat's orange (saturation 0.71 → 0.62).
  - Emissive roots: `Shade`, `LampGlow`, `TvOn`, `TvBlob`, `Lit`, `Moon`, `Star`.
  - The scene's `lightFog` default changes from transparent to the warm dust `33E0BC8C`, in `art_bible.SCENES` and
    `AppPalette.livingRoomFog`. Veils: 0.3 in front of Plane0 (clear at y 200, full by 480) and 0.12
    in front of Plane1 (300 → 1100).
- **The lamp pool takes `lightKey`.** A bound colour sets the alpha too, so the M4 falloff (0.44 / 0.125 / 0)
  becomes two key-coloured radial fills that fade to clear: gradient opacity 0.25 at r 350, and 0.2 at r 175. The M4 middle gradient stop
  is deleted. A blue key shifts the pool by +32.9/255 (blue − red), and it returns exactly to the
  default (history-free).
- **Rain on the glass** (`RainGlass`, Plane1, opacity bound to `rain`, ids from 970000). The layer is
  clipped to the four panes by `PaneClip`, a paintless shape with 4 rectangles. It holds:
  - fine streaks: a 235 px tile on a 20-frame loop;
  - drips with trails: a 470 px tile on a 240-frame loop. Each sheet moves one tile per loop, so
    the wrap is the animation's own.
  - a misted tint (`FF7A8898` at 0.25).
- **Hit zones ride their planes:** `Hit_lamp` and `Hit_plant` on Plane4, `Hit_tv` and `Hit_cat` on Plane3.
- **Events intact:** `lightsOff`, `lightsOn`, `tvOn` and `catWalksBy` keep their ids and keys.
  `TvFloorSpill` is now a circle squashed by `scaleY` 0.29 (the M4 520 × 150 ellipse cut its own
  radial gradient into a hard-edged band).
- `lib/core/models/avatar_scene.dart`: `isDiorama` is true for livingRoom too, so the sensors run in the app.

Numbers:
- livingRoom.riv: 93,886 → 112,599 B (budget 409,600).
- Poster: 27,144 → 26,524 B.
- Travel at parallaxX ±1, all as designed: plant pot ±28, TV cabinet ±20, picture ±12, mullion ±6, moon 0.
- Wet glass median luminance: 93.9 → 105.4 (1.12, gate 1.05–1.6).
- Glass rain seam (frame 0 vs 240, at rain 1, net of what changes at rain 0): 0.0018 % of the glass.

Known limits:

- The haze in front of Plane0 lifts the dark skyline toward mauve. That is ruling 4's warm dust at
  0.3; the owner may want it thinner.
- `Hit_plant` hangs 10 px off the left edge (M4 geometry). At parallaxX −1 its leading edge is
  off the artboard, so the positive click is at x 4, just inside the frame. That point is inside both
  the moved and the rest zone; the displacement is proven by the strip the zone left (x 276), which
  fires nothing.
- Cross-plane light reads at the extremes:
  - The lamp's wall pool (Plane2) slides 16 px against the lamp (Plane4).
  - The moonbeam (Plane3) slides 14 px against the window.

  Both are soft gradients.
- Before M5 the walking cat painted in front of everything. On Plane2 it now passes behind the floor
  lamp (Plane4), which is physically right.
- Pre-existing, not changed: in `lightsOff` the shade's opacity is 0.75, so the ledge and the curtain
  show faintly through it.

Self-check (ruling 11): one Sonnet pass over every sheet, gates.txt and the RML, objective defects
only. It found no defect. It checked:
- the 9 corners: opaque, no gap at the window opening or the floor/wall junction;
- the cornice and panel lines stop at the opening;
- the streaks stay inside the panes;
- the zones cover their props;
- the cat's feet stay on the ledge;
- the pool has no hard step.

Fixed earlier, while building the gates:
- The streak sheets lacked the copy that hangs into the glass from above at the end of a loop
  (0.10 % seam). Copies now start at k = −2, and invisible ones are dropped.
- The wet tint was as dark as the view, so rain did not change the pane (ratio 1.03).
- `TvFloorSpill` had a hard edge.
