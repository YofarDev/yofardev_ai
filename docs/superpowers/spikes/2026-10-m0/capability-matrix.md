# M0 capability matrix: Rive 1.8.0 features on the pinned Flutter runtime

Runtime under test: `rive` 0.14.11 / `rive_native` 0.1.11 (pinned), `Factory.rive`.
Authoring: rive CLI 1.8.0, unsigned `--once` builds (no `rive login` on this machine).
Harness: `integration_test/spikes/rive_capability_test.dart` (Task 1), profile mode,
10 s per case, 400x400 stage, PNG via `RepaintBoundary.toImage`.

Tiers: `macos` (Flutter on Skia, Impeller off in `macos/Runner/Info.plist`) and `emu`
(Android emulator-5554, API 37, Impeller/OpenGLES; **not throttled**, controller ruling R3).
Physical low/mid/flagship tiers: not run (no device farm yet).

Generated with `uv run rive/spikes/tools/matrix.py build/spikes`. Cells: `✅`/`❌` = probe
pixel (200,200) green or not; `·` = cost-only case (Stress artboard, 20 nested `Proof`
instances); numbers = Flutter timeline P95 build/raster ms (Rive's own GPU work on
`Factory.rive` is outside these numbers, see "Frame cost cross-check").

## Matrix

> † **Timeline caveat** (added in Task 8; source: [tiers.md](tiers.md) § Timeline vs FrameTiming).
> The timeline P95s in this section come from 10 s runs. The VM timeline is a ring buffer, so
> each P95 covers only about the last 4–5 s of frames. Same-run ratios share this bias. These
> numbers were not re-measured: the M1 follow-up is a re-run with `--endless-trace-buffer` or
> with `FrameTiming`. Task 7's atrace (emulator sequence c) also refines the claim that "the
> timeline under-reports Rive": Rive encodes and submits on the UI thread inside build, so
> `build` includes Rive's CPU work. Only its GPU execution is unobserved.

| case | emu | macos |
|---|---|---|
| animascript | ❌ 8.0/123.7 ms (impeller) probe=FFFF0000 | ❌ 0.6/1.8 ms (skia) probe=FFFF0000 |
| animascript_stress | · 6.0/119.0 ms (impeller) | · 0.9/2.0 ms (skia) |
| audio | ❌ 6.6/135.6 ms (impeller) probe=FFFF0000 | ❌ 0.7/2.2 ms (skia) probe=FFFF0000 |
| audio_stress | · 7.9/109.7 ms (impeller) | · 0.9/2.0 ms (skia) |
| baseline_avatar | · 32.1/23.6 ms (impeller) | · 2.3/0.8 ms (skia) |
| blend2d | ✅ 19.6/85.7 ms (impeller) | ✅ 1.5/1.8 ms (skia) |
| blend2d_stress | · 16.7/122.5 ms (impeller) | · 1.5/2.2 ms (skia) |
| feather | ✅ 7.5/139.8 ms (impeller) | ✅ 0.2/1.0 ms (skia) |
| feather_stress | · 8.1/137.9 ms (impeller) | · 0.2/1.0 ms (skia) |
| luau | ❌ 4.8/118.3 ms (impeller) probe=FFFF0000 | ❌ 0.7/1.9 ms (skia) probe=FFFF0000 |
| luau_stress | · 9.3/138.7 ms (impeller) | · 1.0/2.5 ms (skia) |
| nested | ✅ 5.3/115.9 ms (impeller) | ✅ 0.3/1.1 ms (skia) |
| nested_stress | · 5.9/119.9 ms (impeller) | · 0.3/1.1 ms (skia) |
| skin | ✅ 3.9/118.7 ms (impeller) | ✅ 0.2/1.0 ms (skia) |
| skin_stress | · 7.6/136.7 ms (impeller) | · 0.3/1.1 ms (skia) |
| wgsl | ❌ 7.8/139.0 ms (impeller) probe=FFFF0000 | ❌ 0.7/1.9 ms (skia) probe=FFFF0000 |
| wgsl_luau | ❌ 4.2/89.5 ms (impeller) probe=FFFF0000 | ❌ 0.7/2.9 ms (skia) probe=FFFF0000 |
| wgsl_luau_stress | · 7.4/159.6 ms (impeller) | · 0.9/2.2 ms (skia) |
| wgsl_stress | · 8.0/119.0 ms (impeller) | · 1.1/2.1 ms (skia) |

Renderer: `macos` = Flutter Skia (Impeller off), Rive via `Factory.rive`; `emu` = Impeller/OpenGLES
(`Using the Impeller rendering backend (OpenGLES)` in logcat), Rive via `Factory.rive`.
Device PNGs were viewed: the four green rows draw the same picture as the CLI on both tiers
(feathered disc, nested square, bent arm, blended square; Stress = 20 copies); the five
scripted rows are plain red, Stress included.

## Verdict per feature

| feature | CLI 1.8.0 | macos | emu | blocker |
|---|---|---|---|---|
| feather | ✅ | ✅ | ✅ | none (soft edge measured on both tiers) |
| nested | ✅ | ✅ | ✅ | none |
| skin | ✅ | ✅ | ✅ | none |
| blend2d | ✅ (as two 1D view-model blend layers) | ✅ | ✅ | none; no `BlendState2D` type in CLI 1.8.0 |
| luau | ✅ | ❌ | ❌ | **unsigned scripts are never registered by the release runtime** |
| wgsl_luau (extra) | ✅ | ❌ | ❌ | same signing blocker (the shader never gets a chance to run) |
| animascript | ✅ | ❌ | ❌ | signing **and** no wasm VM in `rive_native` 0.1.11 (`Failed to import object of type 106`) |
| wgsl (AnimaScript pass) | ✅ | ❌ | ❌ | as animascript |
| audio (AnimaScript `Audio.start`) | ✅ (+ `--render-audio`: 440 Hz) | ❌ | ❌ | as animascript |


## Why every scripted case is ❌ on device (source evidence)

`rive_native` 0.1.11 ships the C++ runtime source in the pub cache
(`~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/runtime/`):

- `src/file.cpp:711-721`: when a file is loaded, each `ScriptAsset` is added to the VM only
  `if (scriptAsset->verified())`; the unconditional `vm->addModule` sits behind
  `#ifdef WITH_RIVE_TOOLS` ("allows unverified scripts for testing").
- `src/assets/script_asset.cpp:199-218`: unsigned bytecode sets `m_verified = false`; signed
  bytecode is checked with `hydro_sign_verify(..., "RiveCode", g_scriptVerificationPublicKey)`.
- `src/lua/rive_lua_libs.cpp:832-838`: `tryRegisterModule` refuses unverified modules unless
  `WITH_RIVE_TOOLS`.
- Observed on macOS (native stderr is visible there): `luau` printed
  `ScriptAsset doesn't have a generator function probe` once, `luau_stress` 20 times (one per
  nested instance), `wgsl_luau` likewise. That is the same line the CLI prints in the Luau
  negative control (generator annotation removed), i.e. "script never ran". Android drops
  native stderr, so there is no log line there, only the red probe.
- `rive docs publishing`: `--once` builds are unsigned and play "in the CLI's own window and in
  any runtime built with tools enabled"; only `--publish` signs.

AnimaScript adds a second, independent blocker: the runtime source and `librive_native.so`
contain no wasm engine (no WAMR or wasm symbols; `runtime/scripting/` holds Luau only). Loading
`cap_animascript`/`cap_wgsl`/`cap_audio` prints `Failed to import object of type 106` on macOS:
106 is `FileAssetContents`, whose import fails with `MissingObject` when the asset it belongs
to (the wasm module, an asset type 0.1.11 does not know) was dropped
(`src/assets/file_asset_contents.cpp:8-14`, `src/file.cpp:383-387`). So a signed AnimaScript
build would most likely still not run on 0.1.11; a newer `rive_native` would need a
separate, labelled retry row.

None of the scripted cases crashed the app; every case produced a timeline and a PNG.

## Per-feature notes

Every CLI command below was run from the project dir as
`rive rive/spikes/cap/<id> --screenshot=build/p.png --advance=30 --probe=200,200`.
Negative controls were run on throw-away copies (scratch dir), never on the committed files.
Device numbers: the matrix row; renderer per tier as above.

### feather (`cap_feather.riv`)
- CLI: `probe 200,200 FF00FF00`. Edge profile along y=200: x=260 `FF00FF00`, 290 `FF15EA00`,
  320 `FF897600`, 350 `FFF10E00` (a soft ramp, not a hard edge).
- Negative: `fillRule="clockwise"` removed (default nonZero) → `FFFF0000` (the feathered paint
  is what draws).
- Device: ✅ on both. Edge profile in the device PNGs matches the CLI: macos 290 `FF15EA00`,
  320 `FF897700`; emu 290 `FF17E700`, 320 `FF8E7000`. So the feather really renders soft
  (a runtime without feather support would draw a hard ellipse that still passes the centre
  probe; this profile rules that out).

### nested (`cap_nested.riv`)
- CLI: `probe 200,200 FF00FF00`. `Proof` holds only a red background and a `NestedArtboard` of
  the 120x120 green component `Child` at (140,140).
- Device: ✅ on both. `Stress` = 20 `NestedArtboard`s of `Proof` (so 20 nested-in-nested).

### skin (`cap_skin.riv`)
- CLI: `probe 200,200 FF00FF00`. Rest pose (`--advance=1`): `FFFF0000`.
- Negative A (rotation key pi/2 → 0): `FFFF0000`. Negative B (`Skin` and all `Weight`s
  removed, rotation still keyed): `FFFF0000`. The green comes from skin deformation only.
- Device: ✅ on both; device PNG also shows the bent L shape (upper arm (150,100) green,
  un-bent forearm position (300,100) red).

### blend2d (`cap_blend2d.riv`)
- CLI 1.8.0 has no 2D blend state type: `rive schema --search Blend` lists
  `BlendState1DInput`, `BlendState1DViewModel`, `BlendStateDirect`, `BlendAnimation1D`,
  `BlendAnimationDirect` only. First attempt: one `BlendStateDirect` whose two weights are
  bound to x and y through a `DataConverterOperationValue` (multiply 100) or a
  `DataConverterRangeMapper` (0..1 → 0..100): the probe stayed green for every x/y including
  0/0, so a converter on a `BlendAnimationDirect` bind is ignored and the weight sits at full
  (without a converter the same bind works on a 0..100 scale). Shipped design: two layers, each
  a `BlendState1DViewModel` on one axis (points 0 and 1), the usual 2D-blend idiom.
- CLI (`--data=x=.. --data=y=..`): 1/1 `FF00FF00`; 0/0 `FFFF0000`; 1/0 `FFFF0000`;
  0/1 `FFFF0000`; no `--data` (default instance x=1, y=1) `FF00FF00`. At 0.5/0.5 the probe is
  also green: layered 1D blends compound across layers, so the square sits near (153,163), not
  (125,125); the decisive controls are the three corners above. (Superseded explanation:
  [head25d.md](head25d.md) § Blend intermediates shows each animation is mixed onto the
  *current* value, not just "compounding across layers".)
- The axis points 0 and 1 blend correctly (contrary to the `rive docs easing` warning that a
  0–1 axis "collapses every pose onto the first one").
- Device: the harness gained `SpikeCase.autoBind` (`controller.dataBind(DataBind.auto())`),
  because `RiveWidgetController` binds no view model by itself; without it the default instance
  (x=1, y=1) never reaches the state machine. ✅ on both, rest corner (50,50) red.

### luau (`cap_luau.riv`)
- CLI: `probe 200,200 FF00FF00`, run markers `CAP_LUAU init` and `CAP_LUAU draw 400x400`
  (console `probe:11`, `probe:26`). Stress: 20 × `CAP_LUAU init`.
- Negative: generator return annotation `: Layout<Probe>` removed → `--verify` green,
  `ScriptAsset doesn't have a generator function probe` ×2, probe `FFFF0000`.
- Device: ❌ on both (unsigned; see above).

### wgsl_luau (`cap_wgsl_luau.riv`, extra row)
Added to tell "WGSL fails" apart from "AnimaScript fails": the same `green.wgsl` run from a
Luau GPU pass (`context:gpuCanvas`, `GPUPipeline.new`, `beginRenderPass`, `draw(3)`,
`drawImage`).
- CLI: `probe 200,200 FF00FF00`, markers `CAP_WGSL_LUAU init / pipeline / pass 400x400`.
- Negative A (fragment returns blue): `FF0000FF`. Negative B (annotation removed): `FFFF0000`.
- Device: ❌ on both (unsigned Luau never runs, so WGSL on device is still untested).

### animascript (`cap_animascript.riv`, `scripting: wasm`)
- CLI: `probe 200,200 FF00FF00`, markers `console :0 CAP_AS init`, `CAP_AS draw 400.0x400.0`
  (script tier: interp). Stress: 20 × `CAP_AS init`.
- Negative: `export` removed from the class → `--verify` green, no marker, `FFFF0000`.
- Device: ❌ on both (signing + no wasm VM; `Failed to import object of type 106` on macOS).

### wgsl (`cap_wgsl.riv`, AnimaScript GPU pass)
- CLI: `probe 200,200 FF00FF00`, markers `CAP_WGSL init / pipeline / pass 400x400`.
- Negative A (fragment returns blue): `FF0000FF` (the pixel is the shader's output).
  Negative B (`pass.draw(3)` removed, canvas only cleared to transparent): `FFFF0000`.
- Device: ❌ on both (as animascript).

### audio (`cap_audio.riv`, AnimaScript `Audio.start`)
- The script draws the centre square only when the `Audio.start` handle is `running` with no
  `failed`, and a 20x20 marker at (10..30) only once the processor has rendered blocks
  (a meter `Snapshot` it publishes from the audio thread).
- CLI `--screenshot`: markers `CAP_AUDIO init rate=48000.0`, `start called`, `running`;
  probe `FF00FF00`; block marker (20,20) `FFFF0000` (headless capture has no audio device, the
  processor runs but renders no blocks).
- CLI `rive rive/spikes/cap/audio --render-audio=build/tone.wav --advance=30`: adds
  `CAP_AUDIO blocks=1.0`; the WAV is 48 kHz float stereo, 0.5 s, peak 0.05, RMS 0.0354,
  dominant 440.0 Hz (FFT), i.e. the generated tone.
- Negative A (`Audio.start` call removed): `FFFF0000`. Negative B (processor `init` throws):
  `processor Tone failed: cap negative control`, `CAP_AUDIO failed: ...`, `FFFF0000`.
- Device: ❌ on both (as animascript; block marker red too).

## Files

- Projects: `rive/spikes/cap/<id>/` (`rive.yaml`, `scene.rml`, generated `stress.rml`, plus
  `probe.luau` / `probe.as` / `green.wgsl`). `uv run rive/spikes/cap/build.py --build`
  regenerates every `stress.rml`, builds with `rive --once` (fails on any error or warning)
  and copies `build/cap_<id>.riv` to `assets/rive/spikes/`.
- One `.riv` per feature holding both artboards: `Proof` (probe, a component) and `Stress`
  (20 `NestedArtboard` instances of `Proof`, scale 0.2, 5x4 grid, each with its
  `NestedStateMachine`). Sizes: feather 1.3 KB, nested 1.4 KB, skin 1.5 KB, blend2d 1.6 KB,
  luau 2.8 KB, wgsl_luau 8.8 KB, animascript 68.8 KB, wgsl 86.0 KB, audio 107.5 KB (the wasm
  module dominates the AnimaScript files).

## Frame cost cross-check (Android, `emu`)

> † **Timeline caveat** (added in Task 8; source: [tiers.md](tiers.md) § Timeline vs FrameTiming).
> The timeline P95s in this section come from 10 s runs. The VM timeline is a ring buffer, so
> each P95 covers only about the last 4–5 s of frames. Same-run ratios share this bias. These
> numbers were not re-measured: the M1 follow-up is a re-run with `--endless-trace-buffer` or
> with `FrameTiming`. Task 7's atrace (emulator sequence c) also refines the claim that "the
> timeline under-reports Rive": Rive encodes and submits on the UI thread inside build, so
> `build` includes Rive's CPU work. Only its GPU execution is unobserved.

### gfxinfo: no P95 possible, and why

- Command, right after the run: `adb -s emulator-5554 shell dumpsys gfxinfo fr.yofardev framestats > build/spikes/emu/gfxinfo.txt`
  (package confirmed: `applicationId = "fr.yofardev"`, `pidof fr.yofardev` during the run).
  Result: `No process found for: fr.yofardev`: the test app exits as soon as `flutter drive`
  ends, so a dump "right after" the run is always empty.
- So a second emu run polled `dumpsys gfxinfo fr.yofardev framestats` every 3 s while the app
  ran (68 snapshots). Every snapshot reads `Total frames rendered: 1` (one at start: 0) and
  its `---PROFILEDATA---` block has no `Flags == 0` row. Column math the P95 would have used:
  per row `FrameCompleted − IntendedVsync` (ns), `Flags == 0` rows only, nearest-rank P95.
  With zero rows the gfxinfo P95 is **undefined, not 0**.
- Reason: Flutter on Android draws into a `SurfaceView` (`83e7ced SurfaceView[fr.yofardev/...](BLAST)`),
  not through HWUI, and `Factory.rive` renders Rive into its own `ImageReader` surfaces
  (`ImageReader-1050x1050...` in logcat). gfxinfo only counts HWUI frames of the Activity
  window, which drew once. **gfxinfo framestats cannot cross-check Flutter or Rive frame cost
  on this setup**; the plan's cross-check (review focus 2) needs another source.
- gfxinfo is per process for the whole run, not per case, and the harness cannot
  `dumpsys gfxinfo <pkg> reset` between cases from inside the test.

### Substitute: SurfaceFlinger present timestamps of the Flutter surface

During the same polled run, `dumpsys SurfaceFlinger --latency '<Flutter SurfaceView layer>'`
was read every 1.5 s (rows: desired present, actual present, frame ready, ns; refresh period
16.67 ms). Rows were deduplicated by actual-present time and attributed to the case the host
log showed when the frame was first seen (so up to 1.5 s of a neighbour case can leak in at
each boundary; the poller started late and missed `baseline_avatar`, `feather*`, `nested`;
`audio_stress` also caught teardown frames). Interval = gap between consecutive presents of
one case (gaps > 1 s dropped); P95 nearest rank. This is the actual on-screen cadence, so it
includes everything the timeline cannot see, Rive's own GPU work included.

Compared with the Flutter timeline of that same run (`build/spikes_emu_polled/emu/`):

| case | timeline frames | timeline P95 build/raster (ms) | SF frames | SF P95 present interval (ms) | ratio SF/raster | >2x |
|---|---|---|---|---|---|---|
| nested_stress | 256 | 8.9/123.5 | 268 | 136.1 | 1.10 | no |
| skin | 238 | 5.9/151.8 | 211 | 161.4 | 1.06 | no |
| skin_stress | 248 | 8.4/84.1 | 276 | 157.4 | 1.87 | no |
| blend2d | 240 | 11.8/90.0 | 252 | 137.4 | 1.53 | no |
| blend2d_stress | 267 | 17.9/93.3 | 274 | 115.8 | 1.24 | no |
| luau | 248 | 5.9/140.7 | 236 | 153.2 | 1.09 | no |
| luau_stress | 236 | 6.5/135.3 | 259 | 170.6 | 1.26 | no |
| wgsl_luau | 250 | 8.1/124.5 | 258 | 176.7 | 1.42 | no |
| wgsl_luau_stress | 252 | 12.6/108.9 | 255 | 136.3 | 1.25 | no |
| animascript | 267 | 5.6/124.2 | 270 | 137.6 | 1.11 | no |
| animascript_stress | 260 | 10.9/96.4 | 265 | 133.3 | 1.38 | no |
| wgsl | 268 | 8.8/120.3 | 246 | 144.9 | 1.20 | no |
| wgsl_stress | 267 | 12.0/106.3 | 298 | 138.2 | 1.30 | no |
| audio | 272 | 7.1/113.3 | 253 | 128.7 | 1.14 | no |
| audio_stress | 270 | 8.4/84.4 | 796 | 117.7 | 1.39 | no |


- No case differs by more than 2× (ratio SF P95 / max(build, raster) P95 is 1.06–1.87).
- Timeline frame counts match the presented frame counts within ~12 % per case (`audio_stress`
  excepted: its SF count includes the teardown frames), so the timeline is not missing frames
  that Rive presents on its own.
- The two quantities are not the same thing (present interval vs raster time); they agree
  here because the emulator is raster-bound (~25 fps) for every case.
- Polling `dumpsys` does not explain the slow emulator: the clean run (the matrix above, no
  polling) shows the same range (raster P95 86–160 ms). Note that `baseline_avatar` on `emu`
  is 32.1/23.6 ms now against 4.4/2.3 ms in Task 1's run on the same AVD: emulator numbers
  drift a lot run to run (host load). They are not a device tier and must never be
  extrapolated to one; they do not separate features from each other either (an all-red
  `luau` case costs the same as `feather`).

## Script language for Tasks 4–5

**Script language for Tasks 4–5: none is green on Android (or macOS) with the pinned runtime
and unsigned builds.** Luau is the only candidate: the runtime ships a Luau VM and its GPU API
(`lua_gpu_load_shader_by_name` is in `librive_native.so`), but it registers a script only when
its bytecode carries a valid Rive signature, which only `rive <dir> --publish` (needs
`rive login`) produces. AnimaScript is out for this runtime: no wasm engine in 0.1.11 (see
below). Tasks 4–5 should either rerun `luau`/`wgsl_luau` from a signed build (a separate,
labelled row; needs the user's `rive login`) or stay script-free (bones, skin, blend states and
nested artboards all work).
