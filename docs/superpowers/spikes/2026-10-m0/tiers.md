# Tier benchmark and battery method (M0 spike, Task 7)

Question: can a short first-launch benchmark of the real Home stage set a `QualityTier`
(Low/High/Ultra), how far does the cost drift over a minute (thermal), and how will battery be
measured?

**Answer (spike level, all thresholds PROVISIONAL until the device farm exists):**

- **Validity rule for a probe:** a probe is valid only if it reached at least 90 % of the
  display refresh rate (`FrameTiming` frames ÷ 3 s ≥ 0.9 × refresh). An invalid probe sets no
  tier: it is repeated. This is the same fps gate the thresholds use. In this spike it splits
  the runs exactly: macOS a and b and emulator a and b are valid; emulator c–f are invalid
  (probe 17.7–52.0 fps, against a gate of 54).
- **A valid probe predicts the next minute:** 3 s of the real stage gives a P95 within
  −21 %…+11 % of the next 60 s (macOS 2.8–2.9 ms vs 2.3–3.1 ms; emulator 16.2 ms vs
  14.5–15.2 ms). **The run-to-run spread is large:** the same AVD gave 16.2 to 56.4 ms (3.5×)
  for the probe within one session. Sequence f is in that range, and it ran on a quiet host
  (load 3.4–4.1, no concurrent tests). A first-launch probe has to survive that spread, which
  is why invalid probes are repeated.
- **Measure with `FrameTiming`, not the timeline, and not raster alone.** The timeline
  recorder is a ring buffer that keeps the newest events: on 20 s runs the summary holds only
  ~273–314 frames (the last 4–5 s at 60–75 fps). The
  in-app `FrameTiming` probe sees every frame. Rive renders on the UI thread, so its cost
  shows up in **build**, not raster: on macOS, raster P95 is 0.5 ms and build P95 is 2.8 ms.
  The probe metric is therefore **the P95 of the per-frame `max(build, raster)`**, taken
  together with the achieved frame rate.
- **Proposed provisional thresholds** (3 s probe, P95 of `max(build, raster)`, and achieved
  fps ≥ 90 % of the display refresh rate): **Ultra ≤ 3.3 ms**, **High ≤ 6.6 ms**,
  **Low** otherwise. A probe above 13.3 ms means even the Low budget is at risk. Derivation
  and uncertainty are below.
- **Thermal drift:** none visible. On a quiet host, run 1 → run 4 is −21 %…+6 % on macOS and
  −6 % on the emulator (run 2 → run 4: +1…+2 %). Neither tier throttles: macOS is a desktop and
  the emulator is not throttled. **Real thermal drift is unmeasured until the device farm.**
- **SurfaceFlinger cross-check (emulator):** the presented-frame counts match `FrameTiming`
  to ±1 frame per 20 s run. The P95 present interval is 1.40–2.32× the larger of the `FrameTiming`
  build and raster P95s on valid runs, and 1.87–3.64× on invalid runs.
- **Rive's own production rate is observable**, through atrace of its `ImageReader` buffers:
  exactly one Rive frame per Flutter frame for each of the two `RiveWidget`s (ratio
  1.00–1.02). This is not a lagging texture.
- Battery: the procedure is written below. **Emulator battery numbers are not valid. Battery
  measurement is pending the device farm.**

## What is measured

`integration_test/spikes/tier_benchmark_test.dart` builds the Rive layers the way Home does
(only the Rive layers: Home's overlays are not drawn, see Limits). It mirrors
`lib/features/home/widgets/home_content_stack.dart`, `RiveSceneView` and `RiveAvatarView`,
which were read but not modified:

- a full-screen `Stack` holding `assets/rive/scenes/campfire.riv` (artboard `Scene`, state
  machine `Main`, `Fit.cover`, centred) under `assets/rive/avatar.riv` (`Avatar` / `Main`,
  `Fit.contain`, `Alignment.bottomCenter`)
- both files auto data-bound (`DataBind.auto()`, as `AvatarRiveBinding` does). The avatar view
  model gets the idle Home values that `RiveAvatarView` pushes on load: mood `neutral`, phase
  `idle`, mouth 0, hat `noHat`, top `pinkHoodie`, glasses `glasses`, costume `none`, presence
  `onScreen`. Names come from `rive/CONTRACT.md`.
- one mounted stage plays **1 run of 3 s (the probe), then 3 runs of 20 s**, back to back. Each
  run has its own `traceAction` key: `timeline_tierbench_<seq>_r1_probe3s`, `…_r2_20s`,
  `…_r3_20s` and `…_r4_20s`.
- independently of the timeline, each frame is counted twice:
  - a persistent frame callback counts framework frames and never schedules a frame itself.
  - `SchedulerBinding.addTimingsCallback` collects the engine's `FrameTiming`s (build, raster,
    total span). Each `FrameTiming` is assigned to a run by its vsync start, which must fall
    between the raw vsync stamps of the run's first and last framework frames. Each edge can be
    off by ±1 frame.
  - the result is the `tierbench_<seq>_frames` key. The app also records each run's edges on
    the monotonic clock (`Timeline.now`), which on Android is the clock that SurfaceFlinger and
    ftrace use.

The two counts agree: framework frames = `FrameTiming` frames + 1 in every run.

Run commands (profile mode; `<seq>` labels one full sequence):

```bash
flutter drive --profile --driver=test_driver/spike_driver.dart \
  --target=integration_test/spikes/tier_benchmark_test.dart -d macos \
  --dart-define=SPIKE_TIER=macos --dart-define=SPIKE_RENDERER=skia --dart-define=SPIKE_RUN=<seq>

# Android: start the SurfaceFlinger poller first, then drive (--no-dds is required)
uv run scripts/spikes/tier_bench.py poll build/spikes/emu/tierbench_<seq>_sf.jsonl &
flutter drive --profile --no-dds --driver=test_driver/spike_driver.dart \
  --target=integration_test/spikes/tier_benchmark_test.dart -d emulator-5554 \
  --dart-define=SPIKE_TIER=emu --dart-define=SPIKE_RENDERER=impeller --dart-define=SPIKE_RUN=<seq>

# tables below
uv run scripts/spikes/tier_bench.py summarize build/spikes --sf emu:<seq>=build/spikes/emu/tierbench_<seq>_sf.jsonl ...
```

Renderers: macOS uses Skia (Impeller is disabled in `macos/Runner/Info.plist`). The emulator
uses Impeller on OpenGLES, according to its launch log ("Using the Impeller rendering backend
(OpenGLES)"). Runtime pins: `rive` 0.14.11 and `rive_native` 0.1.11.

Stage size: on macOS the test window is 486×832 logical px at DPR 1.0 on a 75 Hz display. On
the emulator it is 1080×2400 px at DPR 2.625 on a 60 Hz display. On the emulator each
`RiveWidget` renders into its own full-screen `ImageReader` (1080×2400), so there are two
full-screen Rive textures per frame.

## Per-run P95

`seq` labels one full 1×3 s + 3×20 s sequence (one `flutter drive`). Timeline columns come from
`build/spikes/<tier>/tierbench_<seq>_<run>.timeline_summary.json`; "span" is how much of the
window the timeline frames cover. `FrameTiming` columns come from `tierbench_<seq>_frames.json`.
All values are nearest-rank P95 in ms.

### Valid probe (probe fps ≥ 0.9 × refresh)

| tier | seq | run | timeline frames (span s) | timeline P95 build/raster | FrameTiming frames | FrameTiming P95 build/raster | FrameTiming P95 max(build, raster) | framework frames | FrameTiming fps |
|---|---|---|---|---|---|---|---|---|---|
| macos | a | r1_probe3s | 226 (3.0) | 2.5/0.5 | 234 | 2.8/0.5 | **2.8** | 234 | 78.0 |
| macos | a | r2_20s | 313 (4.2) | 3.3/0.6 | 1513 | 3.1/0.5 | 3.1 | 1513 | 75.7 |
| macos | a | r3_20s | 314 (4.2) | 2.0/0.5 | 1511 | 2.6/0.5 | 2.6 | 1512 | 75.5 |
| macos | a | r4_20s | 312 (4.1) | 2.4/0.6 | 1511 | 2.9/0.5 | 2.9 | 1512 | 75.5 |
| macos | b | r1_probe3s | 226 (3.0) | 3.0/0.5 | 235 | 2.9/0.5 | **2.9** | 235 | 78.3 |
| macos | b | r2_20s | 313 (4.2) | 3.0/0.5 | 1514 | 2.6/0.5 | 2.6 | 1514 | 75.7 |
| macos | b | r3_20s | 312 (4.1) | 2.4/0.6 | 1510 | 2.4/0.6 | 2.4 | 1511 | 75.5 |
| macos | b | r4_20s | 311 (4.1) | 2.2/0.5 | 1510 | 2.3/0.5 | 2.3 | 1511 | 75.5 |
| emu | a | r1_probe3s | 177 (3.0) | 12.2/15.8 | 179 | 12.4/15.8 | **16.2** | 180 | 59.7 |
| emu | a | r2_20s | 280 (4.8) | 10.7/13.6 | 1170 | 11.5/13.9 | 14.8 | 1171 | 58.5 |
| emu | a | r3_20s | 279 (4.7) | 10.7/14.5 | 1191 | 10.9/14.4 | 14.5 | 1192 | 59.5 |
| emu | a | r4_20s | 280 (5.4) | 19.0/13.1 | 1130 | 13.8/13.6 | 15.1 | 1131 | 56.5 |
| emu | b | r1_probe3s | 171 (3.0) | 13.6/12.8 | 172 | 13.6/13.0 | **16.2** | 173 | 57.3 |
| emu | b | r2_20s | 282 (4.8) | 12.4/12.7 | 1166 | 12.3/14.0 | 15.1 | 1167 | 58.3 |
| emu | b | r3_20s | 281 (4.8) | 10.9/14.2 | 1163 | 12.3/14.0 | 15.0 | 1164 | 58.1 |
| emu | b | r4_20s | 279 (4.8) | 12.8/15.2 | 1177 | 11.8/14.7 | 15.2 | 1178 | 58.9 |

On a 3 s window, "fps" is above the refresh rate by up to 4 %. Frames are divided by the
nominal 3 s, and the window edges are ±1 frame.

### Invalid probe (fps gate failed): emulator c–f, same AVD and build, minutes later

| tier | seq | run | timeline frames (span s) | timeline P95 build/raster | FrameTiming frames | FrameTiming P95 build/raster | FrameTiming P95 max(build, raster) | framework frames | FrameTiming fps |
|---|---|---|---|---|---|---|---|---|---|
| emu | c (atrace on) | r1_probe3s | 154 (3.0) | 16.6/13.9 | 156 | 16.4/14.5 | **18.6** | 157 | 52.0 |
| emu | c (atrace on) | r2_20s | 281 (6.0) | 22.2/11.9 | 1009 | 18.3/12.6 | 18.8 | 1010 | 50.5 |
| emu | c (atrace on) | r3_20s | 278 (11.8) | 34.6/13.2 | 754 | 21.7/11.7 | 21.8 | 755 | 37.7 |
| emu | c (atrace on) | r4_20s | 275 (14.9) | 35.6/11.5 | 392 | 33.3/10.4 | 33.3 | 393 | 19.6 |
| emu | d | r1_probe3s | 62 (3.3) | 49.1/23.4 | 62 | 48.6/23.5 | **48.6** | 63 | 20.7 |
| emu | d | r2_20s | 225 (20.4) | 139.3/11.8 | 228 | 139.2/11.9 | 148.5 | 229 | 11.4 |
| emu | d | r3_20s | 277 (14.1) | 42.2/12.5 | 331 | 48.8/13.5 | 54.3 | 332 | 16.6 |
| emu | d | r4_20s | 277 (13.8) | 37.1/11.5 | 420 | 36.6/12.4 | 38.0 | 421 | 21.0 |
| emu | e | r1_probe3s | 61 (3.0) | 38.8/11.0 | 64 | 43.7/16.4 | **44.2** | 65 | 21.3 |
| emu | e | r2_20s | 276 (14.2) | 41.0/10.9 | 400 | 37.2/9.9 | 37.5 | 401 | 20.0 |
| emu | e | r3_20s | 276 (18.3) | 81.2/23.7 | 310 | 63.2/18.9 | 63.2 | 311 | 15.5 |
| emu | e | r4_20s | 279 (12.8) | 31.8/10.2 | 444 | 29.6/9.4 | 30.5 | 445 | 22.2 |
| emu | f | r1_probe3s | 51 (3.1) | 58.0/19.6 | 53 | 56.4/20.2 | **56.4** | 54 | 17.7 |
| emu | f | r2_20s | 274 (16.0) | 45.8/11.5 | 348 | 45.3/11.5 | 45.3 | 349 | 17.4 |
| emu | f | r3_20s | 274 (16.8) | 40.5/12.1 | 326 | 41.2/12.3 | 45.2 | 327 | 16.3 |
| emu | f | r4_20s | 273 (16.4) | 49.0/12.8 | 340 | 46.4/12.0 | 48.6 | 341 | 17.0 |

Sequences a and b ran first (about 19:33–19:37). Sequences c–f ran right after on the same
emulator, and everything got 3–4× slower. Every c–f probe fails the fps gate (17.7–52.0 fps,
against 0.9 × 60 = 54), so the validity rule rejects them. The rule is the same fps gate the
thresholds use, and it is what classifies them, not their cost. What happened on the host:

- During d and e, another project's `flutter test` ran on the host (3 `flutter_tester`
  processes at about 380 % CPU, load average about 12).
- c also ran with atrace on.
- f ran with no concurrent tester (host load average 3.4–4.1, logged every 10 s) and was
  still slow (17 fps).

So a quiet host does not guarantee a valid probe: f is the counter-example. The cause after
c is **not identified**. Candidates are that the emulator window was occluded or App-Napped on
the macOS host, or swap (560–660 MB used in the AVD). This is the emulator noise Tasks 3 and 5
saw (4.4 → 32 ms for one case). The invalid runs count toward the run-to-run spread
(16.2–56.4 ms), but not toward the probe-vs-soak margin. A real app would repeat such a probe
rather than set a tier from it.

## Timeline vs FrameTiming: which one the probe should use

- **The timeline summary is a subset on 20 s runs.** The timeline recorder is a ring buffer
  that keeps the newest events, so the summary holds only 273–314 frames whatever the run
  length. That is the last 4.1–5.4 s at 56–76 fps, or the last 12–20 s when the emulator ran
  at 11–22 fps. `FrameTiming` sees 1130–1514 frames in the same windows. This explains Task 5's
  "Ticker ticks ≫ timeline frames" gap (763 vs 311 on macOS): the timeline drops older frames,
  the engine does not.
- **This affects earlier tasks.** Tasks 1, 3, 4 and 5 traced `runFor` = 10 s per case, so their
  timeline P95s cover roughly the last 4–5 s of each case, not the whole run. They are still
  valid samples of steady state, but not of the full window. Remedies: run `flutter drive
  --endless-trace-buffer` (unbounded buffer instead of a ring), or count with `FrameTiming`
  as this test does.
- On the 3 s probe the two agree, because the window fits the buffer. Timeline and
  `FrameTiming` frame counts differ by ≤ 9, and the P95s by ≤ 0.3 ms on macOS and ≤ 0.2 ms on
  the valid emulator runs.
- Over 20 s they can differ materially, because the timeline's P95 covers the last few
  seconds only. In emu a r4, timeline build P95 is 19.0 ms and `FrameTiming` build P95 is
  13.8 ms.
- **Proposal: the `QualityTier` probe uses `FrameTiming`**
  (`SchedulerBinding.addTimingsCallback`):
  - it is complete;
  - it is the only source available in a release build (the timeline needs the VM service);
  - it costs nothing (the engine already batches the timings).
- **Use the P95 of `max(build, raster)` per frame, not raster.** atrace shows Rive's rendering
  running on the app's main thread, which on this Flutter version is also the UI thread: no
  `1.ui` thread exists, and `dequeueBuffer` on each Rive `ImageReader` is issued by
  `fr.yofardev-<pid>`. It runs inside the frame's build phase (RiveWidget's ticker →
  `paintTexture` → `flush`). Raster only composites the two finished textures:
  - on macOS: raster 0.5 ms, build 2.8 ms
  - on the emulator, raster and build are of the same order (13–16 ms vs 11–14 ms)

  A raster-only metric, as the brief's interface line had it, would put every device in Ultra.
  `max(build, raster)` rather than `build + raster`: build (UI thread) and raster (raster
  thread) are pipelined, so frame N rasters while frame N+1 builds. Throughput is limited by
  the slower stage, not their sum. The sum is latency, and `totalSpan` already reports it.
- **Gate on the achieved frame rate as well.** In the invalid emulator runs, the P95 presented
  interval was 1.87–3.64× max(P95 build, P95 raster) (see the cross-check below). Something
  outside build and raster was starving the frames: host contention during d and e, and an
  unidentified cause in f. `FrameTiming` cost alone would under-rate that device. `FrameTiming` count ÷ probe seconds catches it.

## Thermal drift, run 1 → run 4

FrameTiming P95 of per-frame `max(build, raster)`:

| tier | seq | r1 3 s (ms) | r2 20 s | r4 20 s | drift r1→r4 | drift r2→r4 |
|---|---|---|---|---|---|---|
| macos | a | 2.8 | 3.1 | 2.9 | +6 % | −6 % |
| macos | b | 2.9 | 2.6 | 2.3 | −21 % | −12 % |
| emu | a | 16.2 | 14.8 | 15.1 | −6 % | +2 % |
| emu | b | 16.2 | 15.1 | 15.2 | −6 % | +1 % |
| emu | c (atrace, invalid probe) | 18.6 | 18.8 | 33.3 | +79 % | +77 % |
| emu | d (invalid probe) | 48.6 | 148.5 | 38.0 | −22 % | −74 % |
| emu | e (invalid probe) | 44.2 | 37.5 | 30.5 | −31 % | −19 % |
| emu | f (invalid probe) | 56.4 | 45.3 | 48.6 | −14 % | +7 % |

- Valid runs show no upward drift over 63 s. The probe reads the same as or a little worse
  than the soak (emulator −6 %: first frames after mount), and macOS ranges 2.3–3.1 ms around a
  ~2.6 ms mean.
- None of this is thermal evidence. A desktop does not throttle in a minute, and the emulator
  is not throttled (ruling). The large swings in c–f track host or emulator state, not heat
  (d starts at 48.6 ms, peaks at 148.5 ms in run 2, and recovers to 38.0 ms).
- **Thermal drift on phones is unmeasured.** The vision's "tier drops when the phone throttles"
  needs the farm and a run of ≥ 10 min (see the battery procedure). Over 20 s runs, the timeline
  alone would hide it, because it only sees the end of each run.

## SurfaceFlinger cross-check (Android)

gfxinfo cannot be used here (Task 3, `capability-matrix.md` § gfxinfo). Flutter draws into a
`SurfaceView` and Rive into `ImageReader`s, neither of which goes through HWUI. Instead,
`scripts/spikes/tier_bench.py poll` ran on the host **during** each sequence:

1. It waited for `pidof fr.yofardev`.
2. It discovered the app's layers via `dumpsys SurfaceFlinger --list`.
3. It read `dumpsys SurfaceFlinger --latency '<layer>'` every 0.5 s (128-frame history, enough
   for 2 s at 60 Hz) and deduplicated rows by actual-present time.

Presents are assigned to a run by the app's monotonic run edges. The SurfaceFlinger timestamps
and `Timeline.now` share CLOCK_MONOTONIC: the counts line up to ±1 frame, which confirms it.
The only layer with frames is `SurfaceView[fr.yofardev/fr.yofardev.MainActivity](BLAST)`. No
`ImageReader` layer exists in SurfaceFlinger: Rive's buffers are consumed inside the app by
Flutter, not by the compositor.

| seq | run | SF frames | FrameTiming frames | SF P95 present interval (ms) | FrameTiming P95 build/raster (ms) | ratio SF P95 / max(P95 build, P95 raster) |
|---|---|---|---|---|---|---|
| a | r1_probe3s | 168 | 179 | 22.1 | 12.4/15.8 | 1.40 |
| a | r2_20s | 1171 | 1170 | 21.4 | 11.5/13.9 | 1.54 |
| a | r3_20s | 1192 | 1191 | 20.9 | 10.9/14.4 | 1.46 |
| a | r4_20s | 1131 | 1130 | 26.2 | 13.8/13.6 | 1.90 |
| b | r1_probe3s | 172 | 172 | 31.6 | 13.6/13.0 | 2.32 |
| b | r2_20s | 1167 | 1166 | 22.1 | 12.3/14.0 | 1.58 |
| b | r3_20s | 1164 | 1163 | 22.1 | 12.3/14.0 | 1.58 |
| b | r4_20s | 1178 | 1177 | 21.7 | 11.8/14.7 | 1.48 |
| c (atrace) | r1_probe3s | 136 | 156 | 33.0 | 16.4/14.5 | 2.01 |
| c (atrace) | r2_20s | 978 | 1009 | 34.1 | 18.3/12.6 | 1.87 |
| c (atrace) | r3_20s | 755 | 754 | 61.5 | 21.7/11.7 | 2.83 |
| c (atrace) | r4_20s | 393 | 392 | 109.2 | 33.3/10.4 | 3.28 |
| d | r1_probe3s | 64 | 62 | 118.4 | 48.6/23.5 | 2.44 |
| d | r2_20s | 229 | 228 | 267.7 | 139.2/11.9 | 1.92 |
| d | r3_20s | 332 | 331 | 130.3 | 48.8/13.5 | 2.67 |
| d | r4_20s | 421 | 420 | 106.7 | 36.6/12.4 | 2.92 |
| e | r1_probe3s | 66 | 64 | 128.3 | 43.7/16.4 | 2.93 |
| e | r2_20s | 401 | 400 | 109.3 | 37.2/9.9 | 2.94 |
| e | r3_20s | 311 | 310 | 141.5 | 63.2/18.9 | 2.24 |
| e | r4_20s | 445 | 444 | 107.8 | 29.6/9.4 | 3.64 |
| f | r1_probe3s | 55 | 53 | 193.6 | 56.4/20.2 | 3.43 |
| f | r2_20s | 349 | 348 | 105.2 | 45.3/11.5 | 2.32 |
| f | r3_20s | 327 | 326 | 133.4 | 41.2/12.3 | 3.24 |
| f | r4_20s | 341 | 340 | 121.0 | 46.4/12.0 | 2.61 |

The ratio divides by the larger of the two P95s in the previous column, not by the P95 of
the per-frame maximum used for the thresholds. Two r1 counts fall short: in a and c the poller had not yet found the layer when the probe
began. c r2 is also short (978 vs 1009): under atrace the poller fell behind the 128-frame
history.

- **Caveat (Task 3 review): this measures the on-screen cadence of the Flutter layer. It does
  not directly observe Rive's own surface production.** Rive could fall behind with stale
  textures without the cadence showing it.
- On valid emulator runs, presented frames match `FrameTiming` frames to ±1 per 20 s run, so
  the probe misses no presented frame. The present interval P95 is 1.40–2.32× max(P95 build,
  P95 raster), because presents snap to vsync: a 15 ms frame at 60 Hz lands on a 16.7 or 33.3 ms
  boundary, and the emulator compositor adds jitter (P95 ≈ 21–22 ms at ~58 fps).
- On invalid runs the ratio rises to 1.87–3.64×: the cadence is much slower than the
  per-frame cost. That is why the probe also gates on the frame rate.

### Rive's own production rate (atrace on the ImageReaders)

Sequence c ran with `adb -s emulator-5554 shell atrace --async_start -c -b 32768 gfx view`
before launch, and was dumped with `atrace --async_stop` afterwards. libgui traces each
`dequeueBuffer - ImageReader-1080x2400f22m7-<pid>-<n>`, one per frame that Rive renders into
that reader. The ftrace clock is CLOCK_MONOTONIC (s), the same as the app's run edges.
`uv run scripts/spikes/tier_bench.py atrace <trace> build/spikes/emu/tierbench_c_frames.json`:

| run | FrameTiming frames | reader -0 dequeues (ratio) | reader -1 dequeues (ratio) | Rive P95 interval -0 / -1 (ms) | SF P95 present interval (ms) |
|---|---|---|---|---|---|
| r1_probe3s | 156 | 157 (1.01) | 159 (1.02) | 33.0 / 32.8 | 33.0 |
| r2_20s | 1009 | 1010 (1.00) | 1010 (1.00) | 34.9 / 34.2 | 34.1 |
| r3_20s | 754 | 755 (1.00) | 755 (1.00) | 64.0 / 66.3 | 61.5 |
| r4_20s | 392 | 393 (1.00) | 393 (1.00) | 118.1 / 116.5 | 109.2 |

- Each RiveWidget (scene and avatar) renders exactly once per Flutter frame. Its interval P95
  matches the presented cadence within 9 %, and the dequeues are issued on the UI (main)
  thread.
- So on this setup **Rive cannot fall behind with stale textures independently of Flutter**:
  its encode and GL submit are synchronous inside the frame, and therefore inside
  `FrameTiming` build.
- Limit: the GPU execution of Rive's GL commands is asynchronous and not observed. It would
  only surface as back-pressure, either in `dequeueBuffer` (and so in build) or in Flutter's
  raster. atrace needs a run of its own, because tracing perturbs timing.

## Proposed thresholds (PROVISIONAL, pending the device farm)

**Probe:**

- Validity: an invalid probe (fps < 0.9 × refresh) sets no tier and is repeated (see the
  re-probe policy).
- Mount the Home stage at first launch, then wait 2 frames.
- Collect `FrameTiming` for 3 s.
- `cost` = nearest-rank P95 of per-frame `max(buildDuration, rasterDuration)`.
- `fps` = frames ÷ 3 s.
- `refresh` = `FlutterView.display.refreshRate`.

**Budgets (vision §4.8):**

- Low: P95 ≤ 16.6 ms at 60 Hz.
- High: P95 ≤ 8.3 ms at 120 Hz.

**Derivation:**

- **Margin of 20 % (× 0.8).** Valid probes give:
  - probe vs. the following 60 s: macOS soak P95 −21 %…+11 % of the probe, emulator −10 %…−6 %;
  - run-to-run spread among valid probes: macOS 2.8 vs 2.9 (+4 %), emulator 16.2 vs 16.2.

  So 20 % covers the probe-vs-soak error of a valid probe with a little room. It does **not**
  cover run-to-run spread overall: on the same AVD the probe ranged from 16.2 to 56.4 ms
  (3.5×), f included, on a quiet host. In this spike the validity rule (fps gate) caught every
  such run. That it always will is an assumption: a slow run that still reaches 90 % fps would
  pass. Repeating probes (below) is the second line of defence.
- **Content factor.** The probe runs today's v4 stage, which is the Low-tier content ("the Low
  tier never costs more than v4 does today"). High and Ultra add gated content (feather,
  skinning, WGSL, particles) whose cost is unknown. Tasks 3–5 could not separate feature costs
  on the emulator. The thresholds below assume that **High content costs ≤ 1.0× and Ultra
  content ≤ 2× the v4 stage**. High at 1.0× is **optimistic**: it assumes High's extra content
  is free, which contradicts High adding content at all. A device at the 6.6 ms High threshold
  would overrun the 8.3 ms budget as soon as High content costs more than 1.25× v4. Both factors
  are placeholders, to be replaced by farm measurements of each tier's content.

| tier | rule (3 s probe, v4 stage) | from |
|---|---|---|
| **Ultra** | cost ≤ **3.3 ms** and fps ≥ 0.9 × refresh | 8.3 ms × 0.8 ÷ 2 (Ultra content assumed ≤ 2× v4, still inside the 120 Hz budget) |
| **High** | cost ≤ **6.6 ms** and fps ≥ 0.9 × refresh | 8.3 ms × 0.8 |
| **Low** | everything else | — |
| (Low at risk) | cost > **13.3 ms** or fps < 0.9 × min(refresh, 60) | 16.6 ms × 0.8. Even v4 may miss 60 Hz: still Low, but flag it for the Director (for example, cap idle at 30 fps or freeze the scene) |

**Where today's two tiers land:**

| tier | probe cost (ms) | probe fps / refresh | tier |
|---|---|---|---|
| macOS (a, b) | 2.8, 2.9 | 78 / 75 Hz | Ultra (rule) |
| emulator, valid (a, b) | 16.2, 16.2 | 57–60 / 60 Hz | Low, at risk |
| emulator, invalid (c–f) | 18.6–56.4 | 18–52 / 60 Hz | none: re-probe (fps gate) |

The emulator is not a device tier. These rows only show that the classifier sorts it sensibly;
**never extrapolate them to a phone tier.**

**Re-probe policy (proposal).** External load only adds cost: no run was ever faster than the
valid ones. So:

- an invalid probe sets no tier: repeat it after a delay. If it is still invalid after N tries,
  fall back to Low;
- keep the best (lowest) tier evidence;
- re-probe on the next 2 launches, plus after an app update, and allow an upgrade;
- downgrade only on the thermal or battery signals described in the vision.

A single bad first launch under load must not pin a device to Low.

**What would change these numbers:**

- farm devices (low: Helio G85 class; mid: Snapdragon 7 series; flagship) with a 120 Hz
  display;
- per-tier content cost factors, measured on those devices;
- a ≥ 10 min thermal soak per device.

## Battery procedure

On a farm device (never the emulator), with the app installed as a release build and Home
showing the campfire scene:

```bash
adb shell dumpsys batterystats --reset
adb shell dumpsys battery unplug
# leave Home idle on campfire for 10 min
adb shell dumpsys batterystats --charged fr.yofardev
adb shell dumpsys battery reset
```

Notes for whoever runs it:

- Pass `-s <farm-device-serial>` on every `adb` call when more than one device is attached.
- Keep the screen on at a fixed brightness for the whole 10 min, with the same brightness on
  every device and run.
- Read the app UID's estimated power (mAh) and its CPU and GPU time from the `--charged`
  output.
- `battery unplug` only fakes the unplugged state for batterystats. USB still powers the
  device, so the numbers are relative estimates: compare them run to run and tier to tier, not
  as absolute drain.
- Run v4 (today's stage) and each tier's content back to back on the same device to get a
  delta. That delta is the "battery budget to be fixed in M0" in vision §4.8.

**Emulator battery numbers are not valid**: the emulator has a simulated battery and no real
power model. **The battery measurement is pending the device farm**, and no battery figure is
reported from this spike.

## Limits

- No device farm: there are only two tiers (macOS desktop and an unthrottled emulator). Every
  threshold is provisional.
- Emulator spread is large and not under control: within one session, the same build ran at
  16.2 ms (a, b) and at 44–56 ms (d–f), f on a quiet host.
- The Rive layers only. The real Home also draws, over the two Rive textures, the composer
  (`AiTextInput` → `GlassmorphicTextField`, whose `BackdropFilter` blur is at
  `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart:177`) and `HomeButtons`
  (`AppIconButton`, also a `BackdropFilter`). A backdrop blur over a full-screen animated
  texture is mostly raster cost, so the real Home's raster P95, and possibly
  `max(build, raster)`, is higher than measured here. A production probe should run the real
  Home screen.
- The macOS stage is a small window (486×832 logical px, DPR 1.0). A Retina or full-screen
  window has 4–10× the pixels, and Rive's cost scales with them. The emulator stage is a real
  phone size (1080×2400).
- Idle Home only. Talking (mouth writes), gestures and scene events are not exercised. Task 5
  measured view-model writes at ≤ 0.074 ms P95 per frame, which is small, but Rive's animation
  cost while talking is not measured here.
- `FrameTiming` attribution to a run is by vsync timestamp, ±1 frame at each edge.
- macOS has no compositor cross-check (no SurfaceFlinger), and GPU execution time is not
  observed on either tier.
- The invalid emulator runs (c–f) have no identified cause, and sequence c's slowdown cannot
  be separated between atrace overhead and that degradation.
- Raw artifacts (`build/spikes/<tier>/tierbench_*`, `build/tierbench_logs/`) are not committed.
  The tables above are their summaries, regenerated by `tier_bench.py summarize`.
