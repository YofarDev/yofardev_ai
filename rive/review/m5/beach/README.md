# M5 Task 5: the beach as a diorama (rulings 3–6)

Rendered by
`uv run --with pillow --with numpy rive/tools/review_diorama.py beach <M4 poster.webp>`
(real CLI renders of `rive/scenes/beach`, 1080×1920, `--fit=contain`; pointer proofs are headless
`--pointer=click` runs that count the `event prop_tapped` log lines). The "before" poster is the M4
`assets/rive/posters/beach.webp` (32,168 B), copied aside before regenerating.

| File | What |
|---|---|
| `poster_before_after.png` | M4 poster beside the M5 one |
| `parallax_sheet.png` | `parallaxX` −1/0/1 (columns) × `parallaxY` −1/0/1 (rows) |
| `parallax_edges.png` | the same nine at half size: outer 32 px of the left/right edges, bottom 32 px |
| `hit_zones.png` | parallaxX −1 / +1 with each hit zone where it now sits (green) and at rest (red) |
| `rain_strip.png` | `rain` 0 / 0.5 / 1 (rows) × frames 0, 40, 80 |
| `events_strip.png` | rest, `bigWave` +60 f, `seagulls` +160 f, `sunset` +300 f, `rain` +200 f |
| `sun_key.png` | the sky inside the sun's glow at the default `lightKey` and at `FF60A0FF` |
| `gates.txt` | every objective gate, `ok` / `FAIL` per line (all ok) |

What changed (`gen_scenes.py`: `BEACH_PLANES`, `BEACH_VEILS`, `beach_light`, `DIORAMAS["beach"]`):

- **Planes** (gains 0 / 0.15 / 0.3 / 0.5 / 0.7 / 1.0 of 40 × 24 px):
  - 0: sky, the sunset sky band, sun, clouds, the two far gulls, the rain overcast.
  - 1: the far sea with the horizon, the headland and the islet, the sun's glints, reflections and
    riffles on the water, the sunset's reflection path.
  - 2: the shore wave band, `BigWave` and its clip shape (same plane, so the clip never slides off).
  - 3: the sand, the wet band, the foam and its lace, specks, the `bigWave` wash and wet wash.
  - 4: umbrella and towel, palm, crab, the gull on its post, castle, shells, starfish, the `seagulls`
    flock.
  - 5: the near dune and its grass.

  The screen overlays are `RainLoop` (steady rain), `RainFx` (the `rain` event) and `SunsetTint`.
  Elements moved one plane from ruling 4 (execution ruling 56):
  - the sand 4 → 3, because it paints behind the wet band and the foam;
  - shells and starfish 5 → 4: they lie on the mid-ground sand (y 1470–1860) and stay with the castle.
  M4's draw order already ran back to front, so nothing is re-sorted.
- **Bleed:**
  - Sky, sea and sand are 60 px wider each side (`full()`).
  - The sea runs 40 px under the sand, and the sand 50 px below the frame.
  - The shore wave band runs 100–120 px past each side, which covers its own 30 px drift.
  - The near dune runs 40 px below the frame.
  - Each moved gradient keeps its M4 span (same artboard y), so the rest colours do not move.
- **Horizon haze:** sea haze (`lightFog`, default `22FFD9C0`, which draws) in front of Plane0
  (0.45, clear at y 560 → full at the horizon). In front of Plane1 (0.25) and Plane2 (0.12) it is a
  *band*: full at the horizon and clear again by y 1090 / 1110. `DioramaSpec.veils` takes an
  optional fourth value for this; the 3-value veils of the campfire and livingRoom are unchanged
  (their RML is byte-identical). At the fog's alpha 0x22, four fills reach 0.435 at most, so Plane0's
  veil is 0.435, not 0.45.
- **Lint clean:** 525 hits (79 saturation) → 0.
  - Emissive roots: `Sun`, `Glint`, `SunReflection`, `SunsetPath`, `SunsetSky`.
  - No colour needed re-picking. The largest shifts are the big wave's deep teal and the crab's
    outline (saturation 0.78 / 0.85 → 0.56). The crab reads coral-red, and the sea a muted teal.
- **The sunset glow takes `lightKey`:** the sun's halo `SunGlow` is the glow that sets in the `sunset`
  event. Its centre stop binds `lightKey`; a bound colour sets the alpha too, so M4's `0x88` becomes
  the gradient's opacity (0.533). The halo now paints behind the disc (it used to paint over it):
  a key-coloured halo in front would tint the sun itself.
  - A blue key shifts the halo by +14.4/255 (blue − red).
  - It returns exactly to the default (history-free).
- **Steady rain** (ids from 970000, all binds history-free):
  - `RainLoop`: `rain_fx(loop=True)` streak sheets (18 / 34-frame loops, one tile each) and
    splashes on the sand (120 frames), at opacity `rain`, in screen space.
  - `SandWet` (in front of the dry sand and the wet band) and `DuneWet` (on the near dune):
    `FF6E6656` at 0.4 × `rain`, one shared converter.
  - `SkyOvercast`: `FF8E98A6` at 0.45 × `rain` over the sky, clouds and sun, behind the far gulls.
  - The `rain` one-shot event still plays on top.
- **Hit zones ride their planes:** `Hit_crab`, `Hit_umbrella` and `Hit_seagull` sit on Plane4. The
  seagull prop is the gull on its post, which does not fly: its zone is static, as in M4. The
  flying gulls are not props.
- **Events intact:** `bigWave`, `seagulls`, `sunset` and `rain` keep their ids and keys. `bigWave`
  was re-rendered at parallax (−1, −1) and (+1, +1): its waterline still meets the wet band.
- `lib/core/models/avatar_scene.dart`: `isDiorama` is true for the beach too, so the sensors run in
  the app.

Numbers:
- beach.riv: 199,815 → 256,807 B (budget 409,600). The RML is 1.65 MB.
- Poster: 32,168 → 31,228 B.
- Travel at parallaxX ±1, all as designed: dune grass ±40, towel ±28, foam lace ±20, wave band ±12,
  islet ±6, sun 0.
- Dry sand median luminance at rain 1 / rain 0: 158.8 / 196.5 = 0.81 (gate 0.6–0.9).
- Rain seam (frame 0 vs 6120, at rain 1, net of what changes at rain 0): 0.0019 % of the sand box.

Known limits:

- Ground objects slide against the sand at the extremes. The sand is one Plane3 surface spanning the
  whole depth, so Plane4 props (towel, crab, the palm and post bases) move 8 px against it at
  parallaxX ±1. None has a contact edge that opens.
- The crab's hit zone is static while the crab side-steps 40 px (M4 geometry). The zone is
  180 px wide, so it still covers most of the crab.
- `Hit_umbrella` reaches 20 px from the left edge, so at parallaxX −1 its leading edge is off the
  artboard. The positive click is at x 4, and the strip the zone left (x 406) fires nothing.
- Under rain, the castle, shells and starfish stay dry-coloured, and the haze keeps the horizon peach.
- Pre-existing, not changed: the shore wave band has a flat lighter lower edge under its crests.

Self-check (ruling 11): one Sonnet pass over every sheet, gates.txt, lint and budgets, plus its own
corner renders. It found no objective defect. It checked:
- the 9 corners: opaque, the sand, wet band and foam continuous, the horizon seam clean;
- no hard edge in the veils or the sun's glow;
- the palm and post bases on the sand at every corner;
- no pops in the rain strip;
- the zones cover the crab, the canopy and the gull.

It could not trigger `bigWave` in its own renders; the corner re-render above covers it.

Fixed earlier, while building the gates:
- The first haze band (clear by y 1190) washed the whole sea grey. It now clears by 1090 / 1110.
- The key-coloured halo over the disc turned the sun orange. The halo now paints behind the disc.
- The near dune stayed dry under rain, so `DuneWet` was added.
- The travel patches first overlapped Plane4 (the palm, pole and post cross the surf). They now
  avoid them.
