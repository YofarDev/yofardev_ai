# Rive moonshot M0: feasibility spikes. Implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Load the `rive` skill before any Rive work, and read `~/.claude/skills/flutter-architecture/SKILL.md` before any Flutter work.

**Goal:** Run the six M0 spikes and come out with a measured go/no-go for every technology the
moonshot depends on.

**Architecture:**
- Throwaway Rive CLI projects live under `rive/spikes/`.
- A reusable Flutter `integration_test` harness runs on devices. Each run captures a timeline
  summary and a screenshot, then a Python aggregator probes the pixels and writes a capability
  matrix.
- A pixel-based motion-metrics module (`rive/tools/motion_metrics.py`) scores rendered frame
  sequences and drives a small parameter search.
- The findings land in `docs/superpowers/spikes/2026-10-m0/`.

**Tech Stack:**
- Rive CLI 1.8.0 (RML, Luau, AnimaScript, WGSL)
- `rive` 0.14.11 / `rive_native` 0.1.11
- Flutter `integration_test` + `flutter_driver` timeline summaries
- Python through `uv` (Pillow, pytest, onnx, kokoro)

**Spec:** [`docs/superpowers/specs/2026-10-27-rive-moonshot-vision.md`](../specs/2026-10-27-rive-moonshot-vision.md):
§3 (baseline), §6 (M0 row), §7 (risks).

## Global Constraints

- **Art is CLI-only.** No Rive editor work and no bought art. Vector only, with no embedded
  raster (`rive/CONTRACT.md` budgets).
- **Branch.** All work happens on `spike/rive-moonshot-m0`. Only these files merge back to
  `main`; everything else stays on the spike branch:
  - `docs/superpowers/spikes/2026-10-m0/**`
  - `rive/tools/motion_metrics.py`
  - `rive/tools/tests/test_motion_metrics.py`
- **Hands off.** Do not touch `lib/`, `rive/CONTRACT.md`, `assets/rive/*.riv` or
  `assets/rive/scenes/*.riv`.
- **Runtime pins.** Measure with the pinned `rive` 0.14.11 / `rive_native` 0.1.11. A retry on a
  newer runtime goes in a separate, labelled row and never replaces the pinned result.
- **Python.** Always `uv run`, never `python`. Annotate every function with types.
- **Spike assets.** They live in `assets/rive/spikes/`. That path is added to `pubspec.yaml`
  `assets:` on the spike branch only.
- **Budgets to measure against** (vision §4.8):
  - Low tier: P95 frame ≤ 16.6 ms at 60 Hz
  - High tier: P95 frame ≤ 8.3 ms at 120 Hz
  - the avatar today is 482 KB of its 600 KB budget
- **Devices.** Run on the throttled Android emulator and on macOS now. Physical low/mid/flagship
  columns stay `not run` until the device farm exists. Never extrapolate emulator numbers to a
  device tier.

## Review Focus

1. **A script that never runs.** A script builds green, renders, but never executes on the
   device. It must still read as **fail**: the probe pixel turns green only from the script
   itself (Task 3).
2. **Rive cost the timeline cannot see.** `rive_native` may draw outside Flutter's raster
   thread, so the Flutter timeline under-reports it. On Android, every perf number is
   cross-checked against `adb shell dumpsys gfxinfo <pkg> framestats` (Tasks 1 and 7).
3. **Kokoro duration units.** The duration units are guessed wrong, which skews every viseme.
   This is caught by an explicit "sum of durations equals the audio length" check (Task 6).
4. **Renderer differences.** macOS runs without Impeller and Android with it, so a feature can
   work on one and fail on the other. Every matrix row records its renderer (Task 1).
5. **Size and cost reported without a baseline.** Each is reported only as a delta against the
   current `avatar.riv` and the wave gesture (Tasks 4 and 5).

---

### Task 1: Device harness and capability-matrix aggregator

**Files:**
- Create: `integration_test/spikes/spike_cases.dart`
- Create: `integration_test/spikes/rive_capability_test.dart`
- Create: `test_driver/spike_driver.dart`
- Create: `rive/spikes/tools/matrix.py`
- Create: `rive/spikes/tools/tests/test_matrix.py`
- Create: `rive/spikes/tools/tests/fixtures/` (one timeline summary JSON + two 400×400 PNGs:
  green and red at 200,200)
- Modify: `pubspec.yaml` (`assets:` adds `- assets/rive/spikes/`; spike branch only)

**Interfaces:**
- Produces, in Dart:

  ```dart
  class SpikeCase {
    const SpikeCase({
      required this.id,
      required this.asset,
      this.artboard = 'Proof',
      this.stateMachine = 'Main',
      this.runFor = const Duration(seconds: 10),
    });
    // fields: id, asset, artboard, stateMachine, runFor
  }

  const List<SpikeCase> spikeCases = <SpikeCase>[];
  ```

  Tasks 3–5 and 7 append to `spikeCases`.
- Produces, on disk: `build/spikes/<tier>/<caseId>.timeline_summary.json` and
  `build/spikes/<tier>/<caseId>.png`. `<tier>` comes from `--dart-define=SPIKE_TIER=<label>`.
- Produces, in Python: `matrix.py` with:
  - `probe(png: Path, x: int, y: int) -> str`, returning ARGB hex such as `FF00FF00`
  - `p95_ms(summary: dict, key: str) -> float`, where `key` is `frame_build_times` or
    `frame_rasterizer_times` (microsecond lists)
  - `build_matrix(root: Path) -> str`, returning markdown with one row per case and one column
    per tier. Each cell is `✅ 6.1/9.8 ms`, `❌`, or `not run`.
  - a CLI: `uv run rive/spikes/tools/matrix.py build/spikes > docs/superpowers/spikes/2026-10-m0/capability-matrix.md`

- [ ] **Step 1: Create the branch.**
  Run `git switch -c spike/rive-moonshot-m0`.

- [ ] **Step 2: Write the failing tests** in `test_matrix.py`:

  ```python
  def test_probe_reads_green(): assert probe(FIX / "green.png", 200, 200) == "FF00FF00"
  def test_probe_reads_red(): assert probe(FIX / "red.png", 200, 200) == "FFFF0000"
  def test_p95_from_microseconds(): assert p95_ms({"frame_rasterizer_times": list(range(1000, 101000, 1000))}, "frame_rasterizer_times") == pytest.approx(95.0, abs=1.0)
  def test_matrix_marks_red_probe_as_fail(tmp_path): ...  # copy red.png as build/spikes/emu/luau.png -> row "luau", cell starts with "❌"
  def test_matrix_marks_missing_tier_not_run(tmp_path): ...  # two tiers, case only in one -> other cell "not run"
  ```

- [ ] **Step 3: Run the tests and confirm they fail.**
  Run `uv run --with pytest --with pillow pytest rive/spikes/tools/tests -q`.
  Expected: FAIL, because `matrix` cannot be imported.

- [ ] **Step 4: Implement `matrix.py`.**
  A probe counts as passing when its green channel is ≥ 0xC0 and its red channel is ≤ 0x40, so
  feather and anti-aliasing tolerance is allowed. Each row must state the renderer, read from a
  `renderer` field that the driver writes into the summary JSON (`impeller` or `skia`).

- [ ] **Step 5: Run the tests and confirm they pass.** Same command. Expected: PASS.

- [ ] **Step 6: Implement the harness.**
  - In the test, for each case:
    1. Pump a `RiveWidget` full-screen at 400×400 logical with `Fit.contain`.
    2. Run `binding.traceAction(() => tester.pump…, reportKey: 'timeline_<id>')` for `runFor`.
    3. Call `binding.takeScreenshot('<id>')`. On Android, call
       `binding.convertFlutterSurfaceToImage()` first.
  - The driver uses `integrationDriver(responseDataCallback:, onScreenshot:)` to write both
    files into `build/spikes/<tier>/`.
  - Add one smoke case: `SpikeCase(id: 'baseline_avatar', asset: 'assets/rive/avatar.riv', artboard: 'Avatar')`.

- [ ] **Step 7: Run the smoke case on macOS.**
  Run:
  ```bash
  flutter drive --profile --driver=test_driver/spike_driver.dart --target=integration_test/spikes/rive_capability_test.dart -d macos --dart-define=SPIKE_TIER=macos
  ```
  Expected: `build/spikes/macos/baseline_avatar.timeline_summary.json` and `.png` exist.

- [ ] **Step 8: Commit.**
  Message: `spike: device harness and capability matrix aggregator`

### Task 2: Motion metrics and the frame-sequence renderer

**Files:**
- Create: `rive/tools/motion_metrics.py`
- Create: `rive/tools/tests/test_motion_metrics.py`

**Interfaces:**
- Produces:
  - `frame_diffs(frames: list[Image.Image]) -> list[float]`: the mean absolute luminance
    difference between consecutive frames, from 0 to 1.
  - `pops(diffs: list[float], k: float = 4.0, floor: float = 0.01) -> list[int]`: the indices
    where the diff is greater than `k × median(diffs)` and also greater than `floor`.
  - `loop_seam(frames: list[Image.Image]) -> float`: `diff(last, first) / median(diffs)`.
  - `motion_centroids(frames: list[Image.Image], rest: Image.Image) -> list[tuple[float, float]]`:
    the centroid of the pixels that differ from `rest` by more than 8/255.
  - `jerk(points: list[tuple[float, float]], fps: float = 60.0) -> float`: the RMS magnitude of
    the third finite difference, in px/s³.
  - `render_sequence(project: Path, out_dir: Path, frames: int, data: dict[str, str] | None = None) -> list[Path]`:
    one `rive <project> --screenshot=<abs>/f{i:03}.png --advance={i+1}` per frame, run with
    `cwd=project`, adding `--data=k=v` for each entry.
  - `score(frames: list[Image.Image], rest: Image.Image) -> dict[str, float]`, with the keys
    `pops` (the pop count, as a float), `jerk` and `seam`.

- [ ] **Step 1: Write the failing tests.**
  They use synthetic 64×64 frames made with Pillow.

  ```python
  def test_linear_motion_has_no_pops(): assert pops(frame_diffs(square_moving_linearly(30))) == []
  def test_teleport_is_a_pop(): assert pops(frame_diffs(square_teleports_at(15, n=30))) == [14]
  def test_identical_loop_has_zero_seam(): assert loop_seam(loop_frames()) == pytest.approx(0.0, abs=1e-6)
  def test_linear_path_has_near_zero_jerk(): assert jerk([(float(i), 0.0) for i in range(30)]) < 1e-6
  def test_eased_path_has_less_jerk_than_snapping(): assert jerk(eased) < jerk(snapped)
  def test_render_sequence_builds_args(monkeypatch): ...  # capture subprocess args: f000.png with --advance=1, --data=stiffness=120 present
  ```

- [ ] **Step 2: Run the tests and confirm they fail.**
  Run `uv run --with pytest --with pillow pytest rive/tools/tests/test_motion_metrics.py -q`.
  Expected: FAIL on import.

- [ ] **Step 3: Implement `motion_metrics.py`** with the signatures above. Use Pillow plus the
  standard library; no numpy.

- [ ] **Step 4: Run the tests and confirm they pass.**

- [ ] **Step 5: Run `score` on the current wave gesture** to get the baseline numbers used by
  Task 5. Write them to `docs/superpowers/spikes/2026-10-m0/baseline-wave.json`. Reuse how
  `rive/tools/motion_review.py` captures gestures (it sets `gestureId=wave` and fires `gesture`).

- [ ] **Step 6: Commit.**
  Message: `feat(rive-tools): pixel motion metrics and sequence renderer`

### Task 3: Capability cases, proven in the CLI and then on devices

**Files:**
- Create one project per feature under `rive/spikes/cap/<id>/` (each with `rive.yaml` and
  `scene.rml`, plus a script or shader where needed):

  | id | What it exercises |
  |---|---|
  | `luau` | a `ScriptedLayout` Luau script draws the probe |
  | `animascript` | `scripting: wasm`; an AnimaScript `Layout` draws the probe |
  | `wgsl` | an AnimaScript GPU pass with a `.wgsl` shader fills the probe |
  | `skin` | a `PointsPath` with a `Skin` and 2 bones; a keyed bone rotation drags a vertex over the probe |
  | `blend2d` | a 2D blend state driven by VM numbers `x`, `y`; at `x=1, y=1` the probe region shows the green pose |
  | `feather` | a feathered green ellipse (`fillRule="clockwise"`, clockwise winding) centred on the probe |
  | `nested` | a `NestedArtboard` holding a child artboard that is green at the probe |
  | `audio` | AnimaScript `Audio.start` on a generated tone; the script draws the probe green only once start succeeds |

- Create: `assets/rive/spikes/cap_<id>.riv` (built copies)
- Modify: `integration_test/spikes/spike_cases.dart` (one `SpikeCase` per id, plus
  `<id>_stress` with artboard `Stress`)
- Create: `docs/superpowers/spikes/2026-10-m0/capability-matrix.md`

**Interfaces:**
- Consumes: `SpikeCase` and `spikeCases` from Task 1, and the `matrix.py` CLI.
- Produces: the go/no-go per feature that Tasks 4, 5 and 8 read (the "script language" is
  whichever of `animascript` or `luau` is green on Android).

**Rules every project follows:**
- Artboard `Proof` is 400×400 with a background of `FFFF0000` (red). A feature that works paints
  `FF00FF00` (green) at 200,200.
- For scripted cases, the green comes **only** from script drawing, never from static RML.
- Artboard `Stress` holds 20 instances of the same feature, for frame cost.
- Every project has a `Main` state machine.

- [ ] **Step 1: Build and prove each case in the CLI.**
  Run `rive rive/spikes/cap/<id> --screenshot=build/p.png --advance=30 --probe=200,200`.
  Expected: `probe 200,200 FF00FF00`.
  For scripted cases, also confirm the run log shows a `context.log` or `print` marker. A green
  `--verify` alone is not proof that the script ran.

- [ ] **Step 2: Negative control.**
  Break each scripted case deliberately (for example, remove the generator's return-type
  annotation) and confirm the probe reads `FFFF0000`. Then restore the case.

- [ ] **Step 3: Copy the built `.riv` files** to `assets/rive/spikes/cap_<id>.riv` and add the
  `SpikeCase` entries.

- [ ] **Step 4: Run the harness on each target.**
  - macOS: `SPIKE_TIER=macos`.
  - Throttled emulator: `SPIKE_TIER=emu-throttled`.
  - Android only: right after the run, capture
    `adb shell dumpsys gfxinfo fr.yofardev framestats` into
    `build/spikes/<tier>/gfxinfo.txt`.

- [ ] **Step 5: Generate the matrix.**
  Run:
  ```bash
  uv run rive/spikes/tools/matrix.py build/spikes > docs/superpowers/spikes/2026-10-m0/capability-matrix.md
  ```
  Below the table, add a gfxinfo P95 per Android run, and note any case where the gfxinfo number
  and the timeline number differ by more than 2×.

- [ ] **Step 6: Commit.**
  Message: `spike: rive_native capability matrix (macos, throttled emulator)`

### Task 4: Skinned 2.5D head prototype

**Files:**
- Create: `rive/spikes/head25d/gen_head25d.py`, which writes `rive/spikes/head25d/head.rml`
  using `rive/tools/rml.py` and the `avatar_kit.py` palette and shapes
- Create: `assets/rive/spikes/head25d.riv`
- Modify: `integration_test/spikes/spike_cases.dart` (adds `head25d`)
- Create: `docs/superpowers/spikes/2026-10-m0/head25d.md`

**Interfaces:**
- Consumes: a green `skin` and `blend2d` in Task 3. If either is red on Android, stop this task
  and record no-go.
- Produces:
  - Artboard `Head` with state machine `Main`.
  - VM `HeadVM` with `yaw` and `pitch` numbers, each from −1 to 1. ±1 maps to ±30° yaw and
    ±15° pitch.
  - The skeleton: a head bone, a neck bone, and face-plane bones that features are weighted to.
  - Vertex weights come from distance-to-bone falloff, with at most 4 bones per vertex.

- [ ] **Step 1: Generate and build.**
  Run `uv run rive/spikes/head25d/gen_head25d.py && rive rive/spikes/head25d --verify --format=json`.
  Expected: exit 0, and `rive inspect` shows no `weight-without-bone`.

- [ ] **Step 2: Render the 3×3 grid** (yaw ∈ {−1, 0, 1} × pitch ∈ {−1, 0, 1}) with
  `--data=yaw=… --data=pitch=…`, then build a contact sheet with `rive/tools/sheet.py`.
  Pass criteria for a visual check:
  - no feature leaves the face outline
  - the far eye is narrower than the near eye at |yaw| = 1
  - the hair occludes the ear on the far side

- [ ] **Step 3: Sweep motion.** Sweep yaw from −1 to 1 over 60 frames and run `score` from
  Task 2. Expected: `score(...)["pops"] == 0`.

- [ ] **Step 4: Measure.** Record the `.riv` size, and the harness P95 on macOS and the
  throttled emulator, in `head25d.md`. Extrapolate the size to a full avatar (head + torso +
  hands) and compare it with the current 482 KB.

- [ ] **Step 5: Get an independent critic score** from a fresh reviewer on the contact sheet and
  the sweep GIF. Use the CRITIC_ITERATIONS rubric: 10 means exceptional professional work, and
  no rounding up. Go requires ≥ 8.5.

- [ ] **Step 6: Commit.**
  Message: `spike: skinned 2.5D head prototype`

### Task 5: Procedural motion budget and parameter search

**Files:**
- Create: `rive/spikes/procmotion/` (RML + a script in the language Task 3 picked): a two-bone
  arm whose wave comes from a spring toward target angles, with VM numbers `stiffness`,
  `damping` and `amplitude`
- Create: `rive/spikes/procmotion/search.py`
- Create: `docs/superpowers/spikes/2026-10-m0/procmotion.md`

**Interfaces:**
- Consumes: `render_sequence` and `score` (Task 2), the script language (Task 3), and
  `baseline-wave.json` (Task 2).
- Produces: `search.py` with
  `search(grid: dict[str, list[float]], frames: int = 90) -> list[tuple[dict[str, float], dict[str, float]]]`,
  which returns results sorted by `(pops, jerk)` ascending.

- [ ] **Step 1: Build and prove the script runs.**
  Run `rive rive/spikes/procmotion --screenshot=build/a.png --advance=1` and again with
  `--advance=30`. Expected: `--compare` is greater than 0%, which shows the arm moved.

- [ ] **Step 2: Run the grid.**
  `stiffness` ∈ {60, 120, 240}, `damping` ∈ {8, 14, 20}, `amplitude` ∈ {0.6, 1.0}.
  Write the ranked table into `procmotion.md`.

- [ ] **Step 3: Compare the best configuration with `baseline-wave.json`.**
  - The `pops` count must be ≤ the baseline's.
  - Report jerk as a ratio.
  - Report bytes: this project's `.riv` against the bytes of the wave keys. Measure those as the
    size difference of `avatar.riv` built with and without the wave `LinearAnimation` elements.
    The tracks are named in `gen_avatar.py`; do this in a temporary copy only.

- [ ] **Step 4: Add `procmotion_stress`** (20 arms) to `spikeCases` and run the harness on
  macOS and the throttled emulator.

- [ ] **Step 5: Commit.**
  Message: `spike: procedural spring motion vs baked keys`

### Task 6: Phoneme timing and lip-sync drift

**Files:**
- Create: `scripts/spikes/kokoro_timing.py`
- Create: `scripts/spikes/inspect_onnx_outputs.py`
- Create: `integration_test/spikes/lipsync_drift_test.dart`
- Create: `docs/superpowers/spikes/2026-10-m0/phoneme-timing.md`

**Interfaces:**
- Produces:
  - `kokoro_timing.py "<text>" --lang en|fr --out <dir>` writes `<dir>/audio.wav` and
    `<dir>/timeline.json`. The JSON is a list of `{"phoneme": str, "start_s": float, "end_s": float}`.
  - `inspect_onnx_outputs.py <model.onnx>` prints each graph output's name and shape.

- [ ] **Step 1: Offline timings with the `kokoro` Python package.**
  - Voices: `af_heart` for en (lang `a`) and `ff_siwis` for fr (lang `f`). These match the
    Kokoro design.
  - Read `pred_dur` from each pipeline result and convert it to seconds.
  - Assert in the script that `abs(sum(durations_s) - len(audio)/24000) <= 0.025`. This
    determines the frame unit (vision Review Focus 3); if the assert fails, the unit is wrong.
  - Run it on 3 English and 3 French sentences.

- [ ] **Step 2: Check the timeline by eye.**
  Overlay `timeline.json` onto a waveform PNG and include it in `phoneme-timing.md`.
  Bilabials (p/b/m) must sit on visible amplitude dips.

- [ ] **Step 3: Find the on-device route.**
  Download `kokoro-int8-multi-lang-v1_0` (the sherpa release named in the Kokoro design) and run
  `inspect_onnx_outputs.py` on its `model.onnx`. Record which route works:
  - **A:** sherpa's model already exposes durations.
  - **B:** a custom ONNX export with a durations output, run through onnxruntime directly.
  - **C:** forced alignment fallback.

  Also record the estimated work for each.

- [ ] **Step 4: Measure drift.**
  `lipsync_drift_test.dart` plays a fixed 20 s WAV (generated in Step 1) with `audioplayers`. It
  runs the same stepping as `TtsPlaybackService.startAmplitudeAnimation`, where the interval is
  `duration / frames` clamped to 5–100 ms. At each tick it records
  `tickIndex × interval − (await player.getCurrentPosition())` and reports max and mean drift
  through `binding.reportData`.
  Run it on macOS and on the throttled emulator. Expected output: the numbers, recorded in
  `phoneme-timing.md`. This is a measurement, not a threshold.

- [ ] **Step 5: Commit.**
  Message: `spike: kokoro phoneme timing route and lip-sync drift`

### Task 7: Tier benchmark and battery method

**Files:**
- Create: `integration_test/spikes/tier_benchmark_test.dart`
- Create: `docs/superpowers/spikes/2026-10-m0/tiers.md`

**Interfaces:**
- Consumes: the harness from Task 1 (driver, `SPIKE_TIER`).
- Produces: proposed thresholds for `QualityTier` Low/High/Ultra (P95 raster ms on a 3 s probe)
  and a written battery procedure.

- [ ] **Step 1: Build the benchmark.**
  The real stage (`assets/rive/scenes/campfire.riv` with `Fit.cover` under
  `assets/rive/avatar.riv`) plays as 1 run of 3 s followed by 3 runs of 20 s, back to back. Each
  run has its own `traceAction` report key.

- [ ] **Step 2: Run it on macOS and the throttled emulator.**
  Record the P95 of each run and the drift from run 1 to run 4 (thermal). Cross-check against
  gfxinfo on Android.

- [ ] **Step 3: Write the battery procedure into `tiers.md`.**
  ```bash
  adb shell dumpsys batterystats --reset
  adb shell dumpsys battery unplug
  # leave Home idle on campfire for 10 min
  adb shell dumpsys batterystats --charged fr.yofardev
  adb shell dumpsys battery reset
  ```
  State that emulator battery numbers are not valid, and mark this as pending the device farm.

- [ ] **Step 4: Propose tier thresholds.**
  Derive them from the 3 s probe against the vision budgets, marked provisional until the farm
  exists.

- [ ] **Step 5: Commit.**
  Message: `spike: tier benchmark and battery method`

### Task 8: Findings and go/no-go

**Files:**
- Create: `docs/superpowers/spikes/2026-10-m0/README.md`
- Modify: `docs/superpowers/specs/2026-10-27-rive-moonshot-vision.md` (status line, and a §7 risk
  update per finding)

**Interfaces:**
- Consumes: every document produced in Tasks 2–7.

- [ ] **Step 1: Write `README.md`.**
  It has one table with the columns spike, result, go/no-go, evidence link and consequence for
  M1–M3. It covers these technologies:
  - AnimaScript
  - Luau
  - WGSL
  - skinning
  - 2D blend
  - feather
  - nested artboards
  - audio processors
  - the 2.5D head
  - procedural motion
  - Kokoro timing route
  - lip-sync drift
  - tier thresholds

  Under the table, list what was not measured: the physical device tiers and battery.

- [ ] **Step 2: Update the vision doc.**
  Change the status line to "M0 spikes done YYYY-MM-DD, see spikes/2026-10-m0", and amend each
  §7 risk with its finding.

- [ ] **Step 3: Pass the quality gate on the merge-back set.**
  - `uv run --with pytest --with pillow pytest rive/tools/tests -q`: PASS
  - `dart format --output=none --set-exit-if-changed integration_test test_driver`: exit 0
  - `flutter analyze`: no issues

- [ ] **Step 4: Commit.**
  Message: `docs: M0 spike findings and go/no-go`

- [ ] **Step 5: Merge back the allowed set only.**
  On `main`, run:
  ```bash
  git checkout spike/rive-moonshot-m0 -- docs/superpowers/spikes/2026-10-m0 rive/tools/motion_metrics.py rive/tools/tests/test_motion_metrics.py docs/superpowers/specs/2026-10-27-rive-moonshot-vision.md
  ```
  Then commit `docs: land M0 spike findings and motion metrics`. Only do this once the user
  approves.

## Out of scope for this plan

The other M0 items in vision §6 are not covered here; they get their own plan:

- the art bible as code
- the storyboards for the 3 wow moments
- buying the device farm
