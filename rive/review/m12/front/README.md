# M12 lane F: the front layer — perf and splashes (rulings 1, 2, 6)

`SceneFront` (contract v9: near rain sheet, splashes, rain mist, fog veil) is a second full-screen
`RiveWidget` drawn over the avatar by `RiveSceneView` on campfire, beach, rooftop and forestCabin, at
high and ultra only (low never creates it). M11's emulator run had rain 1 at high / ultra at 22–58 ms
build P95 against 13–17 dry.

## Verdict

| Item | Result |
|---|---|
| **Splashes** | **Fixed** (file bug, CLI and app alike). Every `SceneFront` key used the `Scene` artboard's `CubicEaseInterpolator` (`interpolatorId="0:10"`); the runtime resolves an interpolator inside the key's own artboard, so the splash keys (and with them each splash's opacity / scale animation) were dropped and the splashes stayed at opacity 0. Fix: `Scene._own_eases` (`gen_scenes.py`) gives the front its own copy of each ease its keys use (minted from `M12_ID_START = 890000`). |
| **Front cost** | **Two regimes on the emulator, no render-scale effect.** Quiet regime (4 of 6 runs): the front costs nothing measurable (rain-1 build P95 ÷ dry 0.81–1.28, within the pass-to-pass noise, and equal to the no-front control). Slow regime (M11, exp2, final1): +5–8 ms build **P50** on every rain pass at high / ultra (≈ one 60 Hz vsync: ~37 fps instead of 60), 1.2–2.1 × dry P95. It goes away when the front texture is not redrawn (`static`) or absent (`none`), and **does not change with the texture size** (0.5 / 0.7 / 1.0 equal): a per-frame cost of the second native render target, not fill. |
| **Fix landed for perf** | **None.** (a) render scale: no gain in either regime and it erodes the splash rims (in-app grabs at 0.5: 0 of 30 grabs with a splash rim, vs 19–25 of 30 at 1.0): rejected. (b) thinner front: the cost does not depend on what the front draws (`frontdry`, drawing nothing visible, costs the same in the quiet regime; `static` vs base in exp2): not a lever. (c) one render target: `RivePanel`'s shared texture paints its `RiveWidget`s into one texture behind everything else in the panel, so back + front in it would draw behind the avatar; moving the avatar in as well needs the shared texture to honour the stage camera's transform and the journey layer's clip (not verified, not attempted at the last milestone). (d) `Factory.flutter` front (no native render target, a second decode of the scene file): equal to base in the quiet regime; **not measured in the slow regime** (see open items). |
| **Ruling 2 target** (rain-1 build P95 ≤ 1.25 × dry, same run, high and ultra) | Met by the unchanged code in the quiet runs (after1: 7 of 8 scene × tier, campfire high 1.28 whose no-front control is 1.20; exp4 / exp5: all). Missed in the slow regime (final1: campfire high 1.56, ultra 1.22, beach high 2.13; exp2: 1.25–2.03). |
| Low never creates the front | Unchanged (`QualityTier.allowsSceneFront`); low rain-1 passes = dry in every run (final1 0.82–0.93, rooftop 1.30 under the other app's load). |

## Splashes — evidence

- `splash_cli_campfire.webp`: CLI render of `SceneFront` at rain 1, bottom band, frames 2 / 6 / 12 / 20
  / 30 / 45 / 60 / 90: left the M11 file (no splash in any frame), right the M12 file. CLI probe, frames
  of 8 with no pixel over alpha 0.5 in the band: M11 campfire / beach / rooftop 8 / 8 / 8 (forestCabin
  3, its crossing streaks), M12 1 / 2 / 5 / 1. A scratch copy of the M11 RML with the splash keys
  switched to linear, or with a local copy of the ease, drew them too: the ease reference was the cause.
- `splash_app_before_after.webp`: the same front in the app (macOS, `RiveWidget` + `RiveVmBinding`
  exactly as `RiveSceneView._syncFront` builds it, `OffsetLayer.toImage` grabs, rain 1), best grab of
  30 per scene, M11 file vs M12 file.
- Gate: `integration_test/front_splash_test.dart` (`-d macos`, ~15 s): 30 grabs per front scene at the
  artboard's resolution; counts band pixels with alpha > 128 lying in a flat run ≥ 8 px (a ring's rim;
  a streak's cross-section, or two crossing, is shorter). M11 files: 0 / 30 grabs in all four scenes;
  M12 files: campfire 25, beach 19, rooftop 19, forestCabin 24 (gate: ≥ 10). `FRONT_SPLASH` lines carry
  the numbers, `--dart-define=OUT=<dir>` writes the bands and one whole grab.
- pytest: `test_scene_front.py` checks every artboard's keys ease within their own artboard (built and
  committed RML, all ten scenes) and that the splashes keep the 0.42 / 0.58 ease. The four front scenes'
  `Scene` artboards are unchanged: the RML differs only in the front (1 ease + 126–135 `interpolatorId`s),
  posters byte-identical, `frive.sh` gates 144 lines ok (front gates: mist + splash band 0.194–0.222,
  streak cover 1.5–1.8 %, travel ±50 px, seam 0 %).

`front_look_campfire.webp`: the lower half of the front in the app at rain 1: M11 file at scale 1, M12
file at scale 1 (shipped), M12 file at scale 0.5 (rejected (a): softer streaks, faint rims).

## Front cost — measurements

All on `emulator-5554` (Medium_Phone, API 37, host GPU, 60 Hz), `flutter drive --profile`, campfire +
beach (exp) or all four front scenes, rain passes alternating with dry passes in the same run (`REPS`),
medians of the passes. Variants came from a throwaway knob in `RiveSceneView` (reverted):
`none` front never created, `static` created then its controller made inactive after 0.5 s (texture kept,
not redrawn), `frontdry` drawn every frame with its own rain 0, `s<N>` at N % of the back's render
scale, `flutter` from a second decode with `Factory.flutter`. All passes valid (≥ 20 fps) unless noted.
Full per-pass data with host load and Rive CLI activity (another lane's bench) per pass:
`measurements.json`. Columns: build P50 / P95 ms.

**M11 (before, of record):** campfire high 15.2 → 43.7, ultra 13.2 → 22.1; beach high 14.2 → 58.2, ultra
21.5 → 24.7; rooftop high 14.5 → 25.1, ultra 16.0 → 22.0; forestCabin high 14.9 → 21.9, ultra 17.6 →
23.3 (dry → rain 1 build P95, one pass each; load 20.3 → 6.3).

**exp2 — slow regime, M11 file** (load 9.05 → 6.99; 3 reps):

| scene | tier | dry | base | none | static | s50 | s70 | base ÷ dry (P95) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| campfire | high | 11.7 / 15.5 | 17.6 / 20.2 | 12.3 / 16.0 | 11.8 / 14.9 | 17.4 / 20.5 | 17.7 / 21.5 | 1.31 |
| campfire | ultra | 10.6 / 13.7 | 16.7 / 19.5 | 11.9 / 18.8 | 12.0 / 17.3 | 17.3 / 21.0 | 17.0 / 20.2 | 1.42 |
| beach | high | 10.7 / 17.8 | 15.5 / 22.4 | 11.5 / 17.3 | 11.3 / 15.5 | 17.5 / 23.9 | 18.3 / 24.8 | 1.25 |
| beach | ultra | 10.7 / 13.8 | 16.6 / 28.0 | 11.0 / 16.7 | 11.4 / 15.7 | 16.3 / 22.4 | 17.7 / 21.3 | 2.03 |

**exp5 — quiet regime, M11 file** (load 9.46 → 7.84; 3 reps):

| scene | tier | dry | base | none | s50 | flutter | base ÷ dry |
|---|---|---:|---:|---:|---:|---:|---:|
| campfire | high | 11.3 / 20.8 | 12.7 / 19.7 | 13.5 / 27.1 | 11.6 / 16.9 | 11.8 / 20.3 | 0.95 |
| campfire | ultra | 10.6 / 15.8 | 10.8 / 14.2 | 10.6 / 15.7 | 13.9 / 20.5 | 12.6 / 19.2 | 0.90 |
| beach | high | 11.0 / 14.4 | 11.3 / 17.0 | 12.0 / 17.4 | 10.6 / 13.8 | 11.6 / 17.6 | 1.18 |
| beach | ultra | 10.0 / 12.4 | 10.4 / 12.9 | 10.7 / 13.1 | 12.6 / 14.5 | 10.8 / 15.0 | 1.04 |

(exp3, ultra, 3 reps: campfire dry 9.4 / 11.4, base 9.8 / 13.6, none 10.0 / 15.4, frontdry 11.3 / 17.8,
s10 10.4 / 14.0; beach dry 10.7 / 13.5, base 10.2 / 12.9, none 10.8 / 13.7, frontdry 10.0 / 12.3, s10
10.9 / 16.2. exp4, 4 reps: base ÷ dry 0.89–1.14.)

**after1 — M12 file, quiet regime** (load 6.34 → 5.74; 2 reps):

| scene | tier | dry | base | none | flutter | base ÷ dry |
|---|---|---:|---:|---:|---:|---:|
| campfire | low | 12.6 / 22.9 | 13.5 / 23.2 | 15.1 / 32.2 | 13.5 / 24.7 | 1.01 |
| campfire | high | 12.9 / 22.0 | 16.6 / 28.1 | 15.6 / 26.4 | 17.4 / 29.1 | 1.28 |
| campfire | ultra | 12.8 / 19.5 | 14.3 / 22.7 | 14.7 / 21.6 | 13.2 / 19.5 | 1.16 |
| beach | low | 12.9 / 18.9 | 11.3 / 17.6 | 14.8 / 24.8 | 12.2 / 19.6 | 0.93 |
| beach | high | 12.5 / 19.8 | 12.8 / 22.3 | 11.3 / 19.0 | 11.5 / 17.4 | 1.12 |
| beach | ultra | 11.0 / 16.6 | 10.2 / 13.9 | 15.3 / 28.3 | 12.3 / 24.0 | 0.83 |
| rooftop | low | 10.9 / 16.0 | 11.3 / 15.5 | 10.2 / 13.0 | 11.8 / 15.6 | 0.97 |
| rooftop | high | 10.3 / 15.3 | 11.1 / 14.1 | 11.7 / 15.6 | 12.7 / 17.7 | 0.92 |
| rooftop | ultra | 14.1 / 20.5 | 12.7 / 16.6 | 12.3 / 15.4 | 12.6 / 16.5 | 0.81 |
| forestCabin | low | 11.9 / 14.6 | 12.2 / 15.5 | 12.1 / 15.7 | 12.0 / 15.0 | 1.06 |
| forestCabin | high | 12.3 / 15.6 | 11.8 / 14.9 | 12.3 / 15.5 | 12.5 / 15.9 | 0.96 |
| forestCabin | ultra | 11.9 / 15.5 | 12.5 / 15.9 | 12.0 / 15.5 | 12.0 / 15.2 | 1.03 |

**final1 — M12 file, final code, slow regime** (the harness as committed, `REPS=3`; load 4.22 → 5.87;
Rive CLI idle the whole run). Stopped during forestCabin: another `flutter run` (`fr.yofardev.run_life`)
took the emulator's foreground at ~13:09; rooftop high / ultra are disturbed by its build and launch
(dry 45 / 44 ms), forestCabin high / ultra not measured.

| scene | tier | dry | rain 1 | rain ÷ dry (P95) | frames dry / rain (per 6 s) |
|---|---|---:|---:|---:|---|
| campfire | low | 10.7 / 15.3 | 10.7 / 14.2 | 0.93 | 333–382 / 336–369 |
| campfire | high | 10.4 / 13.4 | 16.7 / 20.9 | 1.56 | 318–372 / 219–242 |
| campfire | ultra | 11.7 / 16.7 | 17.2 / 20.4 | 1.22 | 273–367 / 222–229 |
| beach | low | 13.2 / 19.4 | 11.2 / 16.4 | 0.85 | — |
| beach | high | 10.6 / 14.3 | 19.5 / 30.5 | 2.13 | 341–365 / 199–239 |
| beach | ultra | 16.2 / 29.1 | 18.2 / 24.1 | 0.83 | 225–330 / 158–219 |
| rooftop | low | 10.5 / 13.2 | 10.9 / 17.2 | 1.30 | (other app building) |

### Reading

- The front's cost is the per-frame work of a second Rive render target on the UI thread
  (`RiveNativeRenderBox.paintTexture`: clear, draw, `flush` in the frame callback): `static` (texture
  composited, not redrawn) and `none` are equal and cheap in every regime; any redrawn front (`base`,
  `s50`, `s70`, `frontdry`) pays the same.
- Its size does not matter: on this emulator the GPU is the Mac's, fill is free; in the slow regime the
  UI thread waits about one vsync (P50 ≈ 16.7 ms, ~37 fps), which looks like the producer waiting for a
  free buffer of the front's surface. What switches the regime on is outside the app: it came and went
  between runs at similar loads (it was on in final1 with the Rive CLI idle, off in exp4 / exp5 with
  another lane's bench running); within a run it held for every rain pass.
- On a phone the GPU and the compositor are different: the owner's phone run is the verdict (ruling 14).
  macOS (M11): rain = dry, build 0.3–0.7 ms.

## Open

- **The `Factory.flutter` front in the slow regime** is the one candidate that removes the second
  render target without touching the avatar's layer (a second decode of the scene file while it rains;
  memory and a decode at the first rain). In the quiet runs it equals base; it was not measured in a
  slow-regime run (final1 had no variant knob; the emulator was taken by another session afterwards).
  The throwaway knob that produced every variant is in the lane's scratchpad as
  `front_experiment_knob.patch` (plus an `EXPS` loop in the harness); rerun exp2's shape with
  `EXPS=base,none,flutter` when the regime shows (rain passes at ~37 fps).
- **The phone**: watch `<scene>_rain1` at high / ultra in `rive/review/m11/device/README.md`'s run;
  `--dart-define=REPS=3` alternates dry / rain passes, `SCENES=campfire,beach,rooftop,forestCabin`
  narrows it to the front scenes.

## How to regenerate

```
uv run --with pytest --with numpy --with pillow pytest rive/tools/tests/test_scene_front.py -q
flutter test integration_test/front_splash_test.dart -d macos [--dart-define=OUT=<dir>] [--dart-define=FRONT_SCALE=0.5]
flutter drive --profile -d emulator-5554 --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart --dart-define=TIERS=low,high,ultra \
  --dart-define=SECONDS=6 --dart-define=SCENES=campfire,beach,rooftop,forestCabin --dart-define=REPS=3
```
