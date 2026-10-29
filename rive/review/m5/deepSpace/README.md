# M5 Task 6: deep space as a diorama (rulings 3–6)

Rendered by
`uv run --with pillow --with numpy rive/tools/review_diorama.py deepSpace <M4 poster.webp>`
(real CLI renders of `rive/scenes/deepSpace`, 1080×1920, `--fit=contain`; pointer proofs are headless
`--pointer=click` runs that count the `event prop_tapped` log lines). The "before" poster is the M4
`assets/rive/posters/deepSpace.webp` (15,632 B), copied aside before regenerating.

| File | What |
|---|---|
| `poster_before_after.png` | M4 poster beside the M5 one |
| `parallax_sheet.png` | `parallaxX` −1/0/1 (columns) × `parallaxY` −1/0/1 (rows) |
| `parallax_edges.png` | the same nine at half size: outer 32 px of the left/right edges, bottom 32 px |
| `hit_zones.png` | parallaxX −1 / +1 with each hit zone where it now sits (green) and at rest (red) |
| `events_strip.png` | rest, `meteor` +35 f, `warp` +88 f, `alienShip` +230 f, `nebulaPulse` +60 f, and `alienShip` +230 f at parallax (−1, −1) and (+1, +1) |
| `nebula_key.png` | inside the nebula wash at the default `lightKey` and at `FFFF9A4D` |
| `gates.txt` | every objective gate, `ok` / `FAIL` per line (all ok) |

There is no `rain_strip.png`: deepSpace has no rain art and ignores `rain` (ruling 6). The gate
instead renders the rest frame at `rain` 1 and checks it against `rain` 0: 0 pixels differ.

## What changed

The code is in `gen_scenes.py`: `DEEP_SPACE_PLANES`, `DEEP_SPACE_VEILS`, `deep_space_light` and
`DIORAMAS["deepSpace"]`.

- **Planes** (gains 0 / 0.15 / 0.3 / 0.5 / 0.7 / 1.0 of 40 × 24 px):
  - 0: the void, the three nebulae, the interstellar dust lane and its pinprick stars.
  - 1: the 110 bright stars, the galaxy, the meteor, and the `nebulaPulse` swell and rings (in front
    of the stars, as in M4).
  - 2: the planet group (halo, rings, limb) and the moonlet.
  - 3: the small asteroid (r 36) and the UFO.
  - 4: the front rock (r 50), the rubber duck and the mothership.
  - 5: the near asteroid (r 70).

  The screen overlays are `Flash`, `Warp` and `WarpCoreN`. The warp's streaks scale to 4.6× and its
  core to 2.4×, so both cover the whole frame.

  Space has no ground, so size sets the depth: the three asteroids sit on three planes by size.
  `DioramaSpec.planes` now accepts a full name (`Asteroid0`), which overrides the name's root
  (execution ruling 58). The mothership shares Plane4 with the duck: its beam lifts the duck, and on
  one plane it lands on the duck at every parallax (`events_strip.png`, last two cells). The meteor
  rides Plane1 and passes behind the planet and the saucer. The content is regrouped back to front
  with a stable sort, so the draw order inside each plane is M4's.
- **Bleed:** the void is on Plane0 (gain 0) and never moves. Every nearer plane is sparse art on a
  clear background, so no plane has an edge to reveal. The Plane1 dust veil spans −60..1140 ×
  −61..1980 px.
- **Nebula dust:** `lightFog` sits in front of Plane0 (0.25) and Plane1 (0.12). It is even over the
  whole frame, because space has no horizon. The default was `00000000`, which draws nothing. It is
  now `331E1A44`, a dark violet close to the void, in both `art_bible.SCENES` and
  `AppPalette.deepSpaceFog`. A lighter violet (`33302660`) was tried first: it lifted the void to a
  flat purple and greyed out the teal nebula, so it was rejected. With the chosen fog:
  - The top of the void moves from (6, 4, 16) to (18, 14, 36), about the app's ink `#16121D`.
  - The teal mid-nebula keeps its colour: (23, 44, 68) becomes (25, 39, 67).
  - Against the nearer props, the dust-lane stars (Plane0) keep 0.66 of their M4 contrast and the
    bright stars (Plane1) keep 0.88.
- **Lint clean:** 190 hits (15 of them saturation) → 0.
  - Emissive roots:
    - stars: `Star`, `DustStar`, `Galaxy`;
    - nebulae: `Nebula`, `InterstellarDust`, the `nebulaPulse` swell and rings;
    - the planet's lit rim: `AtmosphericLimb`;
    - UFO lights: `ULight`, plus the mothership's `SLight`;
    - warp: `Warp`, `WarpCoreN`, `Flash`;
    - `Meteor`.
  - No colour needed re-picking. The largest shifts are the duck's outline and beak: saturation
    0.91 / 0.87 → 0.70. The duck still reads as yellow with an orange beak.
- **The nebula wash takes `lightKey`:** `Nebula2` is the cloud up and right of the planet, on the
  key's side (`key_dir` 0.9). Its centre stop binds `lightKey`. A bound colour sets the alpha too, so
  the gradient's opacity is 0.2. The wash now reads lavender (the key `FFCDB8FF`) rather than M4's
  mauve.
  - A warm key shifts it by +16.1/255 (red − blue).
  - It returns exactly to the default (history-free).
- **The moonlet is visible again:** M3's re-placement moved the planet group from (230, 820) to
  (300, 590) but left the moonlet at (420, 640), behind the planet. It now keeps its original offset
  from the planet: (490, 410), above the near end of the rings (execution ruling 58).
- **Hit zones ride their planes:** `Hit_planet` is on Plane2, `Hit_ufo` on Plane3 and
  `Hit_rubberDuck` on Plane4. The UFO bobs (±22 / ±26 px) and its zone is static inside the plane,
  as in M4. The 240 × 130 zone still covers the saucer at every phase.
- **Events intact:** `meteor`, `warp`, `alienShip` and `nebulaPulse` keep their ids and keys.
- **Self-check fix:** the mothership's beam ended in a hard horizontal edge, a step of 11.7/255
  (pre-existing in M4). Its 16 volume gradients now end inside the shape (`scene_art.py`). The
  largest row step is now 2.4/255.
- `lib/core/models/avatar_scene.dart`: `isDiorama` is true for every scene. It is an exhaustive
  switch, so a future scene has to choose.

## Numbers

- deepSpace.riv: 62,435 → 67,089 B (budget 409,600). The RML is 352 KB.
- Poster: 15,632 → 15,032 B.
- Travel at parallaxX ±1, all as designed: near asteroid ±40, duck ±28, saucer ±20, planet ±12,
  galaxy ±6, dust lane 0.
- Pointer proofs: 6 of 6 fire at the displaced zone, and the strip each zone left fires none.

## Known limits

- The UFO's own tractor beam (Plane3) ends about 8 px off the duck (Plane4) at the parallax
  extremes. The beam is a soft cone, so the offset does not read.
- The UFO and duck hit zones are static while their art bobs or orbits (M4 geometry). Both zones
  still cover their prop.
- The `nebulaPulse` swell (Plane1) and the nebulae it breathes with (Plane0) can be up to 6 px
  apart. Both are soft gradients.
- Pre-existing, not changed: the thick back ring band stops about 8 px short of the planet's limb at
  the upper right, with a butt cap (M4 renders it the same).

## Self-check (ruling 11)

One Sonnet pass over every sheet, gates.txt, lint and budgets, plus its own renders. It covered the 9
corners at frame 400, `alienShip` at the four corners over frames 40–530, the other events at two
corners, the loop ends (UFO 720, duck 1020, rocks 600, stars 240) and full-resolution corner crops.
It found:

- the mothership beam's hard bottom edge: fixed, see above;
- the back ring's stub at the limb: pre-existing and left as it is.

Everything else passed: alpha 255 everywhere, no edge step above 0.7/255 within 80 px of any border,
continuous loop ends, the beam centred on the duck at every corner, lint ok, budgets ok, and the
zones cover their props.
