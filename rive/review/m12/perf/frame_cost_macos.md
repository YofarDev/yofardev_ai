# M12 frame cost on macOS, per scene × tier (profile; plan rulings 14, execution ruling 35)

`flutter drive --profile -d macos --driver=test_driver/integration_test.dart
--target=integration_test/frame_cost_test.dart --dart-define=TIERS=low,high,ultra --dart-define=SECONDS=8`
on the M12 code (the Mac: Skia, Impeller off, desktop GPU, the shared host's load below). Run 1 is the full
run; runs 2–4 re-ran the scenes whose passes drew under 20 fps (`--dart-define=SCENES=…`). Each row is the
latest **valid** pass (`run` column); a pass under 20 fps is `invalid` and never a pass. Times in ms;
`worst` = max(build, raster) per frame; budgets 16.7 / 11.1 / 8.3 ms. Every run's `FRAME_COST_REPORT` is in
[frame_cost_macos.jsonl](frame_cost_macos.jsonl) (one report per line).

| Scene | Tier | run | frames | worst P50 | worst P95 | worst P99 | build P95 | raster P95 | over budget | pass |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| livingRoom | low | 1 | 672 | 2.0 | 2.39 | 2.56 | 2.39 | 1.28 | 0.0% | ok |
| livingRoom | high | 1 | 679 | 2.06 | 2.49 | 2.68 | 2.49 | 1.28 | 0.0% | ok |
| livingRoom | ultra | 1 | 672 | 2.07 | 2.48 | 2.78 | 2.48 | 1.28 | 0.0% | ok |
| campfire | low | 1 | 672 | 2.03 | 2.43 | 2.64 | 2.43 | 1.31 | 0.0% | ok |
| campfire_rain1 | low | 1 | 672 | 2.08 | 2.5 | 2.74 | 2.5 | 1.28 | 0.0% | ok |
| campfire | high | 1 | 680 | 2.1 | 2.49 | 2.64 | 2.49 | 1.27 | 0.0% | ok |
| campfire_rain1 | high | 1 | 672 | 2.21 | 2.66 | 2.84 | 2.66 | 1.22 | 0.0% | ok |
| campfire | ultra | 1 | 680 | 2.19 | 2.59 | 2.85 | 2.59 | 1.25 | 0.0% | ok |
| campfire_rain1 | ultra | 1 | 672 | 2.33 | 2.8 | 3.07 | 2.8 | 1.19 | 0.0% | ok |
| beach | low | 1 | 672 | 2.02 | 2.42 | 2.58 | 2.42 | 1.29 | 0.0% | ok |
| beach_rain1 | low | 1 | 671 | 2.05 | 2.53 | 2.71 | 2.53 | 1.26 | 0.0% | ok |
| beach | high | 1 | 679 | 2.05 | 2.44 | 2.63 | 2.44 | 1.28 | 0.0% | ok |
| beach_rain1 | high | 1 | 671 | 2.33 | 2.75 | 3.04 | 2.75 | 1.22 | 0.0% | ok |
| beach | ultra | 1 | 680 | 2.11 | 2.52 | 2.73 | 2.52 | 1.26 | 0.0% | ok |
| beach_rain1 | ultra | 1 | 671 | 2.27 | 2.67 | 2.85 | 2.67 | 1.18 | 0.0% | ok |
| deepSpace | low | 1 | 672 | 2.02 | 2.43 | 2.67 | 2.43 | 1.3 | 0.0% | ok |
| deepSpace | high | 1 | 672 | 2.04 | 2.49 | 2.65 | 2.49 | 1.24 | 0.0% | ok |
| deepSpace | ultra | 1 | 679 | 2.2 | 2.62 | 2.94 | 2.62 | 1.24 | 0.0% | ok |
| cafe | low | 1 | 680 | 2.04 | 2.43 | 2.63 | 2.43 | 1.31 | 0.0% | ok |
| cafe | high | 1 | 672 | 2.07 | 2.45 | 2.73 | 2.45 | 1.29 | 0.0% | ok |
| cafe | ultra | 1 | 680 | 2.09 | 2.47 | 2.71 | 2.47 | 1.29 | 0.0% | ok |
| rooftop | low | 1 | 679 | 2.02 | 2.39 | 2.54 | 2.39 | 1.3 | 0.0% | ok |
| rooftop_rain1 | low | 1 | 672 | 2.25 | 2.66 | 2.85 | 2.66 | 1.22 | 0.0% | ok |
| rooftop | high | 1 | 672 | 2.06 | 2.51 | 2.72 | 2.51 | 1.28 | 0.0% | ok |
| rooftop_rain1 | high | 1 | 680 | 2.2 | 3.5 | 4.11 | 3.5 | 1.19 | 0.0% | ok |
| rooftop | ultra | 1 | 672 | 2.03 | 3.02 | 3.71 | 3.02 | 1.28 | 0.0% | ok |
| rooftop_rain1 | ultra | 1 | 680 | 2.28 | 2.67 | 2.88 | 2.67 | 1.17 | 0.0% | ok |
| mountainHut | low | 1 | 680 | 2.21 | 2.58 | 2.75 | 2.58 | 1.25 | 0.0% | ok |
| mountainHut | high | 1 | 679 | 2.1 | 2.54 | 2.87 | 2.54 | 1.26 | 0.0% | ok |
| mountainHut | ultra | 1 | 672 | 2.07 | 2.45 | 2.63 | 2.45 | 1.27 | 0.0% | ok |
| forestCabin | low | 3 | 672 | 1.45 | 3.41 | 3.76 | 3.41 | 0.85 | 0.0% | ok |
| forestCabin_rain1 | low | 3 | 680 | 1.47 | 3.67 | 3.99 | 3.67 | 0.77 | 0.0% | ok |
| forestCabin | high | 3 | 672 | 1.41 | 3.6 | 3.98 | 3.6 | 0.77 | 0.0% | ok |
| forestCabin_rain1 | high | 3 | 680 | 1.56 | 3.71 | 4.0 | 3.71 | 0.8 | 0.0% | ok |
| forestCabin | ultra | 3 | 672 | 1.43 | 3.65 | 3.94 | 3.65 | 0.78 | 0.0% | ok |
| forestCabin_rain1 | ultra | 3 | 672 | 1.56 | 3.74 | 4.13 | 3.74 | 0.77 | 0.0% | ok |
| trainCompartment | low | 2 | 193 | 1.56 | 2.31 | 3.76 | 0.25 | 2.13 | 0.0% | ok |
| trainCompartment | high | 2 | 473 | 1.5 | 1.89 | 2.73 | 0.45 | 1.89 | 0.0% | ok |
| trainCompartment | ultra | 2 | 518 | 0.79 | 1.62 | 1.85 | 0.46 | 1.61 | 0.0% | ok |
| library | low | 3 | 672 | 0.69 | 1.67 | 1.85 | 1.46 | 1.64 | 0.0% | ok |
| library | high | 4 | 1 | 4.33 | 4.33 | 4.33 | 0.23 | 4.33 | 0.0% | invalid |
| library | ultra | 4 | 1 | 3.82 | 3.82 | 3.82 | 0.2 | 3.82 | 0.0% | invalid |

40/42 passes valid (>= 20 fps drawn); 40/40 valid passes within budget

- run 1: load 2.40 3.02 2.79 -> 4.08 2.51 2.14
- run 2: load 4.47 2.64 2.19 -> 4.53 4.82 3.40
- run 3: load 5.44 5.01 3.49 -> 5.28 5.20 3.89
- run 4: load 4.69 5.02 3.90 -> 3.80 4.77 3.94

## Reading

- **Every valid pass is within budget** (worst P95 1.6–3.7 ms against 8.3 ms at ultra; 0 % of frames over).
  The rain-1 passes cost what the dry ones cost here (the front's second render target is cheap on a desktop
  GPU; the emulator's slow regime is in [../front/README.md](../front/README.md)).
- **Two regimes on this Mac too**: run 1's first 35 passes put ~2.4 ms in build (P50 ~2.0); later passes
  (run 1's tail, runs 2–4) ~0.1–0.5 ms build except forestCabin (3.4–3.7). M11's macOS run read 0.3–0.7 ms. The
  host changed state mid-run (load 2.4 → 5.4); compare scenes within one run, never across.
- **Covered window**: run 1 lost its window from forestCabin ultra on (6 of 42 passes at 1–8 frames), the
  re-runs fixed four.
- **library high / ultra: 1 frame in 8 s in all four runs** (also in M11's macOS table, then listed `ok`
  before the `valid` flag existed), while library low draws 628–672 frames in the same runs and the
  emulator drew library high / ultra at 427–451 frames (M11). An in-app capture of the library at forced
  ultra (`wow_capture_test.dart WOW=scene SCENE=library TIER=ultra`) drew 338 live grabs, no frozen stretch.
  So it is this harness on macOS, not the stage the user sees; the cause was not found (open item).
- macOS is not a tier: it ranks scenes and tiers against each other. The per-tier verdict is the owner's
  phone ([../device/README.md](../device/README.md)).
