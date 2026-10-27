# M0 feasibility spikes: findings and go/no-go

Done 2026-10-27 on branch `spike/rive-moonshot-m0`. Feeds the M1–M3 decisions of the
[moonshot vision](../../specs/2026-10-27-rive-moonshot-vision.md) (§6 M0 exit gate: "a go/no-go
for each technology").

**Provenance.** Source paths (`rive/spikes/…`, `integration_test/spikes/…`, `scripts/spikes/…`, `test_driver/…`, `assets/rive/spikes/…`) refer to branch `spike/rive-moonshot-m0` at commit 8f722dc; raw run outputs under `build/spikes/` are local and not preserved — see [`data/`](data/README.md) for the copied summaries.

**Setup.** Runtime pinned at `rive` 0.14.11 / `rive_native` 0.1.11. Authoring with Rive CLI 1.8.0,
using unsigned `--once` builds (no `rive login`). Two tiers only, never extrapolated to a phone:

- `macos`: Flutter on Skia (Impeller is off in `macos/Runner/Info.plist`).
- `emu`: Android emulator-5554, API 37, Impeller on OpenGLES, **not throttled**.

Physical low/mid/flagship tiers were not run, because the device farm does not exist yet.

**Verdicts.**

- **GO**: works on both tiers and the evidence supports building on it.
- **NO-GO**: does not work, or misses its bar, as tested.
- **BLOCKED / INCONCLUSIVE**: not decided. The row says what would decide it.

**† on a number** means a Flutter timeline-summary P95 from a 10 s run (Tasks 1, 3, 4 and 5). The
VM timeline is a ring buffer, so such a P95 covers only about the **last 4–5 s** of frames.
Same-run ratios share this bias. See [Measurement caveats](#measurement-caveats).

## Go/no-go

| spike | result | go/no-go | evidence | consequence for M1–M3 |
|---|---|---|---|---|
| **Luau** scripting | Works in the CLI: run markers, plus a negative control. Red on both tiers. `rive_native` 0.1.11 registers a script only if its bytecode is **signed** (`file.cpp:711-721`, `script_asset.cpp:199-218`). macOS prints `ScriptAsset doesn't have a generator function`. | **BLOCKED** (unsigned build). This is not a capability no-go. | [capability-matrix.md](capability-matrix.md) § luau, § Why every scripted case is ❌ | Nothing in M1 may depend on device scripts. To unblock: retry with a signed build (`rive login` + `--publish`, the user's decision), or with a tools-enabled diagnostic `rive_native` build. Record it as a separate, labelled row. |
| **AnimaScript** (wasm) | Works in the CLI. Red on both tiers. Two separate blockers: signing, and **no wasm engine** in `rive_native` 0.1.11 (`Failed to import object of type 106`). | **NO-GO** on 0.1.11. Revisit only with a newer-runtime row. | [capability-matrix.md](capability-matrix.md) § animascript | The vision's "physics in AnimaScript", "AnimaScript jobs/workers" for particles and "procedural motion in scripts" cannot ship on this runtime. Plan for Dart drivers (see procedural motion) or a runtime upgrade. |
| **WGSL** via AnimaScript | Works in the CLI: the pixel is the shader's output (a blue negative control). Red on both tiers, for the AnimaScript reasons. | **NO-GO** on 0.1.11 | [capability-matrix.md](capability-matrix.md) § wgsl | WGSL accents (heat haze, caustics, god rays, paper grain) have **no proven device path**. Keep them out of the M1–M3 scope. |
| **WGSL** via Luau GPU pass | Works in the CLI (with negative controls). Red on both tiers. The unsigned Luau never runs, so the shader on device is **untested**. The GPU API symbols are present in `librive_native.so`. | **BLOCKED** (unsigned build) | [capability-matrix.md](capability-matrix.md) § wgsl_luau | Same unblock as Luau. If the signed retry runs, the WGSL device cost still has to be measured per tier before High or Ultra can use it. |
| **Audio processors** (AnimaScript `Audio.start`) | Works in the CLI: `--render-audio` gives a 440 Hz tone (FFT). Red on both tiers, for the AnimaScript reasons. | **NO-GO** on 0.1.11. Revisit with a newer-runtime row. | [capability-matrix.md](capability-matrix.md) § audio | Foley and ambient beds (§4.7) stay in Flutter audio, triggered by Rive events. |
| **Skinning** (bones + `Skin`/`Weight`) | Green on both tiers. The bent shape is drawn on device, and two negative controls pass in the CLI. Also carries the head (Task 4) and the procedural arm (Task 5). | **GO** | [capability-matrix.md](capability-matrix.md) § skin | The basis for the Character 2.0 rig. Its cost per feature could not be separated on the emulator (an all-red case costs as much as a green one†). |
| **2D blend** | CLI 1.8.0 has **no `BlendState2D`**. Two `BlendState1DViewModel` layers work. Device evidence on both tiers is the (1, 1) corner (green) plus a red rest corner. **Intermediate values settle biased**: each animation is mixed onto the *current* value, so x = 0.5 gives 0.667 instead of 0.5, and the pose lags a moving input. A reset layer under the blend makes the result exact. That fix was verified in the CLI only. | **GO** (endpoints proven on device; intermediates and reset layer CLI-only), as two 1D layers plus a reset layer | [head25d.md](head25d.md) § Blend intermediates; [capability-matrix.md](capability-matrix.md) § blend2d | Every blend in the rig DSL needs a reset layer. The vision's continuous visemes `(visemeA, visemeB, t)` would be biased without one. **Check the shipped avatar's `Mouth` blend**: it has the same structure (1D VM blend, 5 animations, no reset layer). Its integer `mouth` values sit on blend points, where the model predicts exact poses, but fractional values would be biased. For the head, formula converters were used instead (next row). |
| **Feather** | Green on both tiers. The device edge profile matches the CLI's soft ramp, which rules out a hard edge. | **GO** (function) | [capability-matrix.md](capability-matrix.md) § feather | Can be used for High-tier depth of field and rack focus. Its cost is unmeasured on a real device; on the emulator it could not be separated from the other cases. |
| **Nested artboards** | Green on both tiers, including 20 nested-in-nested instances (Stress). | **GO** | [capability-matrix.md](capability-matrix.md) § nested | Usable for the world kit, props and NPCs. |
| **2.5D head**: rig and size | Formula converters (`c0 + c1·cos a + c2·sin a`) bind 44 face bones to `yaw`/`pitch`. The rig is history-free (0 px difference between `--advance=1` and `--advance=40`). All 3×3 pass checks hold (features inside the face, far eye at 0.585×, far ear hidden). The sweep is smooth (per-frame diff 0.00696–0.00728). The file is **49,928 B**. Extrapolated: head-only rig → avatar 551 KiB, inside the 600 KiB budget. Head + torso + hands → about **773 KiB, over budget**. It renders identically on both tiers (static pose). Static-pose raster vs the avatar in the same run: macos 0.83 vs 0.61 ms†, emu 20.15 vs 18.05 ms†. | **GO** for the technique. **The cost of animated yaw/pitch is not measured.** | [head25d.md](head25d.md) | Use formula-converter bone drives (not blend states) in the rig DSL. Skin the head only: the body needs cheaper weights before it fits. Measure the per-frame cost of 88 binds and 371 re-skinned vertices while yaw/pitch animate. |
| **2.5D head**: art and motion quality | Independent critic: **6.7/10** (visual 7.1, animation 6.3) against an 8.5 bar. The shipped art scores 8.51–8.82. Blockers: (1) the crown and silhouette are static, so the face slides on a balloon; (2) the outline has no 3/4 structure (cheekbone, temple, nose breaking the far contour); (3) the sweep is linear, with no ease, lead, lag or blink. The critic expects fixing only the smaller blockers 4–6 (forehead shading reads as stripes; pitch moves features inside a fixed head; ears and mouth are rigid) to reach about 7.3–7.5. | **NO-GO** against 8.5, *as prototyped* | [head25d-critic.md](head25d-critic.md), [grid](head25d/grid.png), [sweep](head25d/sweep.gif) | The blockers sit in the generator, not the runtime. "Real 3/4 view" (wow #2) needs generator work: a skinned crown, side masses and back hair, 3/4 silhouette bones, a performed turn (spring toward `yawTarget`, gaze lead, hair lag, blink). Then re-score before committing the M1 head. |
| **Procedural motion**: bytes and device cost | No device scripts, so this used a **Dart-driven spring** writing VM numbers bound to bone rotations. The drive is **304 B per arm** against 1,026 B for the same motion as keys (0.30×), and 0.063× the wave's arm tracks (4,841 B). The Dart step plus 40 VM writes takes **≤ 0.074 ms P95** (UI-thread timer, not the timeline). The 20 driven arms cost about the same as 20 keyed arms (ratio 0.86–1.15×†). | **GO** (Dart route), relative to keyed motion only | [procmotion.md](procmotion.md) | Procedural motion lives in Dart (`PerformanceDirector` / motion drivers) and writes VM numbers. The `.riv` only maps numbers to bones. Step by elapsed time, not a fixed 1/60 (otherwise it plays 2× fast at 120 Hz). |
| **Procedural motion**: motion quality | The mandated `(pops, jerk)` sort **rewards under-delivery**: the winner swings 16° of a commanded 36° and never reaches the raise. The 4 configs that really wave score **0.38–2.36×** the baked wave's normalised jerk, and 3 of the 4 are jerkier. Centroid jerk moves up to 6.2× when only the amplitude changes. A raw spring toward step targets has no ease-in. | **INCONCLUSIVE** | [procmotion.md](procmotion.md) § Step 3, Limits; [sheet](procmotion/sheet.png) | Do not claim "springs look better than keys". Next experiment: shaped targets (eased keys or a critically damped pre-filter), with a pose-to-pose wave plus spring follow-through. It also needs a motion metric that does not favour small motion (the critic loop in §4.8). |
| **Kokoro timing route** | Durations are **25 ms frames** (600 samples at 24 kHz). Their sum equals the audio length with 0 ms residual (11/11 chunks). sherpa's `model.int8.onnx` already outputs durations as output 2, matching PyTorch to ±1 frame, but **sherpa 1.13.8 drops it**. sherpa's default `silence_scale` 0.2 rewrites pauses. Raw timeline lag: −50 ms (EN) to −65 ms (FR). Bilabial deep-dip hits rise from 11/33 EN and 3/23 FR (raw) to **23/33 EN and 15/23 FR** with a −50 ms shift. The dip metric is a weak heuristic. | **GO**: route **B** (same ONNX through onnxruntime, our own G2P). On-device inference has not been built yet. | [phoneme-timing.md](phoneme-timing.md) §1–3, [overlays](phoneme-timing/) | Plan about 5–8 dev-days for route B: onnxruntime in Flutter takes 1–2 days, and on-device G2P 3–5 days (espeak-ng is GPL-3, so it needs a licensing review). Route A (a sherpa fork) takes about 4–6 days, if G2P is out of scope. Route C (forced alignment) is a fallback only. Apply a −50 ms shift, fold stress and diacritic tokens, and pass `silenceScale = 1.0` or replay the edit on the timeline. |
| **Lip-sync drift** (today's open-loop timer) | macOS: the mouth leads the audio by about **250 ms** for the whole sentence, because of audio start latency. The emulator shows means of −4…+84 ms (extremes −178…+88 ms), with noise. **Each UI-isolate stall longer than one interval permanently loses whole ticks**: a 300 ms stall moved drift by −296 ms on macOS and −169 ms on the emulator, with no recovery. The emulator's reported position can jump backwards (−76 ms). **Current-app bug**: on Android, `audio_analyzer` ignores `samplesPerSecond`, so the mouth updates every 85 ms instead of every 25 ms. | **NO-GO** for the open-loop timer. Closed loop is required. | [phoneme-timing.md](phoneme-timing.md) §4, [data](phoneme-timing/data/) | Index visemes and amplitude by the player clock (`getCurrentPosition` / `onPositionChanged` each frame), and smooth or clamp backward jumps. This confirms the vision's "closed loop" (§4.2). Fix the Android analyzer rate independently of the moonshot. |
| **Tier probe method** | A 3 s first-launch probe on the real Rive stage uses `FrameTiming` (complete, and available in release builds), not the timeline. The metric is the **P95 of the per-frame `max(build, raster)`**, because Rive encodes on the UI thread inside build, and raster alone would put every device in Ultra. The evidence that Rive runs on the UI thread is atrace from emulator sequence c only; that sequence failed the fps gate (invalid probe), but the UI-thread conclusion is structural and still holds. It comes with an **fps-gate validity rule** (probe fps ≥ 0.9 × refresh, otherwise re-probe). The gate caught every bad run in this spike. That it always will is an assumption: a slow run that still reaches 90 % fps would pass. A valid probe predicts the next 60 s within −21 %…+11 %. | **GO** (method) | [tiers.md](tiers.md) | Build the `QualityTier` probe on `FrameTiming` with the fps gate and the re-probe policy. Run it on the **real Home**: the `BackdropFilter` composer and buttons were not in the probe. |
| **Tier thresholds** | Provisional: **Ultra ≤ 3.3 ms**, **High ≤ 6.6 ms**, Low otherwise, and "Low at risk" above 13.3 ms. The High content factor of 1.0× is **optimistic**: a 6.6 ms device overruns 8.3 ms once High content costs more than 1.25× v4. The quiet-host emulator spread was 16.2–56.4 ms (3.5×) for the same build. The "at risk" gate (0.9 × min(refresh, 60)) is inconsistent with the validity gate on 120 Hz displays. | **BLOCKED** (device farm) | [tiers.md](tiers.md) § Proposed thresholds | The vision's "tier budgets fixed" exit gate is **not met**. These are placeholders until the farm measures each tier's content cost and a ≥ 10 min thermal soak. |

**Count:** 8 GO, 5 NO-GO, 4 BLOCKED / INCONCLUSIVE.

The 2.5D head, procedural motion and tiers are each split into two rows, because their parts got
different verdicts.

## Not measured

- **Physical device tiers** (low: Helio G85 class; mid: Snapdragon 7 series; flagship). There is
  no device farm. No emulator number stands in for one.
- **Battery.** The procedure is written ([tiers.md](tiers.md) § Battery procedure), but no figure
  exists, and emulator battery numbers are not valid. The §4.8 "battery budget, to be fixed in M0"
  is still open.
- **Thermal drift on phones.** The macOS and emulator runs show none, but neither tier
  throttles.
- **Animated 2.5D head cost**: 88 formula re-evaluations and 371 re-skinned vertices per frame
  while yaw/pitch change. Only a static pose was measured.
- **Home overlay raster.** The tier probe drew only the two Rive layers, not the `BackdropFilter`
  composer and `HomeButtons`.
- **GPU execution time** of Rive's GL commands, on either tier. Only CPU encode and submit (inside
  build) and the presented cadence were observed.
- **Per-feature cost** of feather, skinning, nested artboards and blends on a device. Emulator
  noise swamps it.
- **Scripts on device**, signed: Luau, WGSL via Luau, and their cost.
- **Talking cost** on the real stage: mouth writes, gestures and scene events while speaking.
- **Acoustic output latency** (from the player position to the speaker). Measuring it needs a
  loopback recording.
- **On-device route B**: onnxruntime in Flutter, and G2P parity against sherpa's tokens.
- **Combined yaw and pitch sweep** of the head, and a head combined with the avatar's
  mood/blink/viseme animations.

## Measurement caveats

- **Timeline ring buffer.** The VM timeline keeps only the newest events, about 273–314
  frames. The 10 s runs of Tasks 1, 3, 4 and 5 therefore report P95s over roughly the **last
  4–5 s** of frames. They are marked † here, and a † caveat note now heads each affected section in capability-matrix.md, head25d.md and procmotion.md. Ratios within one run share the bias.
  These numbers were not re-measured. The **M1 follow-up** is a re-run with
  `flutter drive --endless-trace-buffer`, or with `FrameTiming`, as Task 7 did.
- **Emulator noise.** The same case on the same AVD drifted from 4.4† to 32† ms between runs
  (`baseline_avatar`, Task 3), and the Home stage probe from 16.2 to 56.4 ms within one session,
  one of those runs on a quiet host. Emulator numbers do not separate features from each other
  (an all-red script case costs as much as `feather`†). They are not a device tier.
- **Renderer per tier.** macOS runs Skia and the emulator runs Impeller/OpenGLES, so a result on
  one tier does not transfer to the other. Every matrix cell records its renderer. Physical
  devices may use Impeller on Vulkan, which was not covered.
- **Where Rive's cost shows up.** Earlier docs (Tasks 3–5) say the timeline under-reports Rive's
  own work. Task 7's atrace on the emulator refines this: Rive encodes and submits **synchronously
  on the UI thread inside build**, exactly one Rive frame per Flutter frame, so its CPU cost is in
  `build`. Only the GPU execution is unobserved. This was not traced on macOS. `gfxinfo
  framestats` cannot see Flutter or Rive here (`SurfaceView` and `ImageReader` bypass HWUI), so
  SurfaceFlinger present intervals were used instead. They show the cadence of the Flutter layer,
  not Rive's GPU work.
- **Same-run comparisons only.** Every cost here is a same-run ratio against `baseline_avatar` or
  a keyed control, never an absolute cross-run figure.
- **Stage size.** macOS is a 486×832 window at DPR 1.0 (Task 7) and the harness stage is 400×400.
  Rive's cost scales with pixels.
- **Smaller notes from the reviews**:
  - The Task 1 driver does not clear old outputs. Tasks 4 and 5 cleared them by hand. Task 3's
    greens are backed by device PNGs that were viewed, and feather's device edge profile differs
    per tier, which points to fresh renders.
  - The probe pixel checks red and green only.
  - The drift harness awaits `getCurrentPosition` before starting the timer (a small bias, low).
    The preload path was not measured.
  - The "everything" size extrapolation uses 4 rigs, not 5 (about 842 KiB, not 830 KiB). This
    does not change the verdict.

## Recommended next decisions

1. **Signed-script retry** (the user's call: `rive login` + `--publish`), or a tools-enabled
   diagnostic `rive_native` build. Rerun `luau` and `wgsl_luau` as a separate, labelled row. Also
   track newer `rive_native` releases for a wasm engine (AnimaScript and audio).
2. **Fund generator work for the 2.5D head** before M1 commits to wow #2. Address critic blockers
   1–3 (skinned crown and back hair, 3/4 silhouette bones, a performed turn), then re-score
   against 8.5 and measure the animated cost.
3. **Add a reset layer under every blend**, as a rig DSL rule. Check the shipped `Mouth` blend
   with fractional values.
4. **Re-run the frame-cost numbers with `FrameTiming`** or `--endless-trace-buffer`. Then run the
   tier probe on the real Home, overlays included.
5. **Fix the `audio_analyzer` rate on Android** (85 ms instead of 25 ms). This is a current-app
   bug, independent of the moonshot. Move lip-sync to the player clock (closed loop).
6. **Choose the Kokoro route**: B (onnxruntime plus our own G2P, 5–8 days, espeak-ng GPL-3
   review) or A (a sherpa fork, 4–6 days).
7. **Buy the device farm.** Physical tiers, thresholds, thermal soak and battery all wait on it.
8. **Procedural motion**: build the Dart motion driver, and test shaped targets before any quality
   claim.
