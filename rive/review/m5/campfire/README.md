# M5 Task 3: shared diorama pass, hit zones in planes, campfire rain and steam (rulings 2, 3, 6)

Rendered by
`uv run --with pillow --with numpy rive/tools/review_diorama.py campfire <M4 poster.webp> --same-as=5b10b23`
(real CLI renders of `rive/scenes/campfire`, 1080×1920, `--fit=contain`; pointer proofs are headless
`--pointer=click` runs that count the `event prop_tapped` log lines).

| File | What |
|---|---|
| `poster_before_after.png` | M4 poster beside the M5 one (identical: rain is 0 at rest) |
| `parallax_sheet.png` | `parallaxX` −1/0/1 (columns) × `parallaxY` −1/0/1 (rows) |
| `parallax_edges.png` | the same nine at half size: outer 32 px of the left/right edges, bottom 32 px |
| `hit_zones.png` | parallaxX −1 / +1 with each hit zone where it now sits (green) and at rest (red) |
| `rain_strip.png` | `rain` 0 / 0.5 / 1 (rows) × frames 0, 40, 80 |
| `fire_strip.png` | 10 frames of the 89-frame firelight loop (unchanged from M4) |
| `gates.txt` | every objective gate, `ok` / `FAIL` per line (all ok) |

What changed (`gen_scenes.py`):

- **One diorama pass.** `diorama(sc, content, spec: DioramaSpec)`; `DioramaSpec(planes, emissive,
  veils, light=None)`; a scene in `DIORAMAS` is a diorama (`Scene.write` runs the pass and the
  colour fit). The campfire's M4 firelight binds moved into its `light` hook (`campfire_light`).
  Every M4 element keeps its id, tag and attributes (`test_diorama.py` diffs the RML against
  `5b10b23`); the only re-parented M4 elements are the four hit zones and `emitFire` (now under
  `emitFireDamp`). Rest frames at rain 0 are pixel-identical to M4 (0 of 2,073,600 px, f0 and f60).
- **Hit zones ride their planes** (`Hit_fire`, `Hit_tent` → Plane4, `Hit_owl` → Plane3, `Hit_sky` →
  Plane0). At parallaxX ±1 a click just inside each moved zone's leading edge fires `prop_tapped`,
  and a click on the strip it left fires nothing (fire, tent, owl; the sky has gain 0).
- **Rain bound to `rain`** (history-free, M5 ids from 970000): `RainLoop`, a screen overlay at
  opacity `rain` reusing `rain_fx(loop=True)` (near / far sheets on their own 18 / 34-frame loops,
  one tile per loop, so the wrap is the animation's own; splashes on a 2 s loop); `GroundWet` and
  `TentWet`, copies of the ground's and the canvas's outlines in a wet shadow (`FF0B1318`) at
  0.35 × `rain` (one shared `0.35 × input` converter); `RainSteam`, seven soft radial plumes rising
  250 px off the logs on a 3 s loop at opacity `rain` (peak 0.8 each); `emitFireDamp` scales the
  fire by `1 − 0.15 × rain` (one shared converter on scaleX and scaleY). The `rain` one-shot event
  plays on top unchanged.
- **Lint drift guard:** `check_contract.py` runs `art_bible.lint_colours` on every scene in
  `DIORAMAS` and fails on any hit. Campfire lint: `ok`.

Numbers: campfire.riv 166,802 → 227,517 B (budget 409,600; the steady streak sheets are most of
it), poster 19,042 B (unchanged). Wet ground median luminance 39.8 → 32.5 at rain 1 (0.82). Rain
loops seam (frame 0 vs 6,120, where every rain loop is back at 0; ground box, net of what changes at
rain 0): 0.017 % of pixels, small float drift over 102 s.

Known limits:

- The rain overlay and its splashes stay in screen space (ruling 6): at parallax ±1 the splashes
  slide up to 28 px against the ground under them.
- The tent's thin fold and seam lines paint in front of its lantern glow in M4, so the wet shadow
  sits behind them (moving them would change the dry tent): they stay light on the wet canvas.
- The grass is not darkened (the ruling names the ground and the tent).

Self-check (ruling 11, one Sonnet pass over every sheet, objective defects only): no defect found
(no revealed edge, zones cover their props, steam soft, streaks full height, no pops). Found and
fixed earlier while building the gates: the steam at its first opacity barely read (raised to 0.8
peak, larger plumes); the lantern reorder changed 39 dry-tent pixels (wet shadow moved behind the
lantern instead); a saw-tooth streak loop with a held reset key lagged a tile at near-integer
frame times (each sheet now loops on its own).
