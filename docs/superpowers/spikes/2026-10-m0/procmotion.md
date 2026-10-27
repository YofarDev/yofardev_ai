# Procedural motion: spring-driven arm vs baked wave keys (M0 spike, Task 5)

Question: can procedurally driven motion (springs) replace baked keyframes, with better motion
quality and fewer bytes, at acceptable device cost?

**Answer (spike level): go on bytes and device cost; motion quality INCONCLUSIVE.** The
go/no-go below rests on bytes and device cost only, which are sound. A Dart spring posing a two-bone arm through view-model numbers runs on the pinned
runtime on both tiers and costs 304 B of `.riv` per arm, against 1,026 B for the *same*
motion baked into keys, 4,841 B for the avatar wave's arm tracks and 18,090 B for the whole wave
gesture. Its frame cost matches the same motion played from keys (within ±15 % on both tiers; the
Dart step + 40 VM writes for 20 arms is ≤ 0.07 ms P95 per frame).

Motion quality is **inconclusive**. The plan's pops criterion (≤ the baseline's 2) is met **by
construction**: the mandated `(pops, jerk)` sort rewards under-delivery and picks the laziest
spring (stiffness 60, damping 20, amplitude 0.6), which has 0 pops and a low jerk but delivers
under half the commanded wave swing and never reaches the raised pose. Among the four configs
that actually wave (overshoot ≤ 10°, ≥ 50 % of the commanded swing), length-normalised jerk
ranges from **0.38× to 2.36×** the baked wave's: three of the four are jerkier than the keys.
Centroid jerk is also unstable between near-identical motions (amplitude alone moves it up to
6.2×), so no single-config jerk ratio here, the winner's included, supports a quality claim.
What is clear: a raw spring toward step targets starts every move at full acceleration (no
ease-in); replacing animator keys would need shaped targets, not only a spring.

## Route: Dart-driven spring (ruling R9), not a Rive script

Task 3 found that no script language runs on the device runtime (`rive_native` 0.1.11 only
accepts signed script bytecode, no wasm engine; `capability-matrix.md`). So the vision's
documented fallback is tested instead: the spring is integrated **outside Rive** and the
`.riv` only maps numbers to bone rotations.

- `rive/spikes/procmotion/gen_procmotion.py` → `procmotion.rml` → `assets/rive/spikes/procmotion.riv`
  (65,546 B with all three artboards; built by `uv run rive/spikes/procmotion/gen_procmotion.py --build`).
  - Artboard `Arm` (400×400, SM `Main`, VM `ArmVM`): a skinned two-bone arm (RootBone
    upper arm 90 px + Bone forearm 85 px, sleeve and hand skinned, elbow vertices 50/50) on
    a static torso and head. VM numbers `shoulder`, `elbow` (degrees) bind to the bone
    `rotation` (key 15) through formula converters (`π/2 − deg/57.2958`, `−deg/57.2958`),
    the Task 4 history-free VM→bone pattern; no animations, no blend states.
    `stiffness`, `damping`, `amplitude` are VM numbers too but only document the config:
    without scripts nothing in the `.riv` can integrate a spring.
  - Artboard `Stress` (2000×1600, VM `StressVM`): 20 full-size copies of the arm in a 5×4
    grid of 400 px cells, arm *i* posed by `s<i>` / `e<i>` (40 numbers, one VM instance).
    Copies are translated, never scaled, so skin/tendon transforms stay plain world positions;
    the harness fits the artboard into its 400×400 stage.
  - Artboard `StressKeyed` (device control): the same 20 arms, unbound, plus a looping 90-frame
    `Wave` LinearAnimation keying both bone rotations of every arm every 2 frames (linear, like
    the avatar's wave), sampled from the same spring (search winner, arm *i* phase 4·*i*,
    second pass of the pattern = steady state): the same motion, baked.
- The spring, identical in two places:
  - Python, CLI search: `rive/spikes/procmotion/spring.py` (`Spring`, `target`, `wave_angles`;
    re-exported by `search.py`).
  - Dart, device: `integration_test/spikes/spring_wave.dart` (`Spring`, `waveTarget`,
    `waveAngles`, `SpringArms`).
  - Per joint, degrees, fixed dt = 1/60, semi-implicit Euler, one step per frame:
    `v += (k·(target − x) − c·v)·dt; x += v·dt`.
  - Target pattern (90 frames, loops): frame 0 raise (shoulder 100°, elbow 70°); from frame 12
    the elbow target swings ±30°·amplitude every 10 frames (3 Hz, the rate of the avatar's
    `wave_sway` keys); frame 62 lower (0°, 0°).
  - Parity: `rive/spikes/procmotion/tests/test_search.py` and `test/spikes/spring_wave_test.dart`
    assert the same hard-coded outputs (frames 0, 10, 45, 89 of `wave_angles(90, 120, 14, 1)`,
    to 1e-9); the Dart test also checks `SpringArms` against `waveAngles` per arm.

### Step 1: the VM drive moves the arm, and the pose is history-free

`uv run rive/spikes/procmotion/search.py prove` (CLI 1.8.0, `--compare`):

| capture | vs | differing pixels |
|---|---|---|
| shoulder=100, elbow=70, `--advance=1` | rest (no data), `--advance=1` | **7.82 %** (12,510 / 160,000) |
| shoulder=100, elbow=40, a1 | shoulder=100, elbow=70, a1 | **3.80 %** (6,075) |
| shoulder=100, elbow=70, `--advance=40` | same data, `--advance=1` | **0.00 %** (0) |
| rest, a40 | rest, a1 | **0.00 %** (0) |

So both numbers drive the bones, and a frame depends only on the data, not on how long the
state machine ran: a single `--advance=1` capture per frame is a faithful render of that
frame. Visual check: `procmotion/sheet.png` (see below).

### Rendering for the search

Frame *i* of a clip = one CLI capture of `Arm` with that frame's spring angles:
`rive rive/spikes/procmotion --screenshot=<png> --data=shoulder=… --data=elbow=…
--data=stiffness=… --data=damping=… --data=amplitude=… --advance=1` (cwd = project), i.e. the
argument conventions of `rive/tools/motion_metrics.py` `render_sequence`. It is a small helper
(`render_pose`), not `render_sequence(project, dir, 1, data)`, because the static guard needs
each run's stderr, which `render_sequence` discards. 8 CLI runs in parallel; the 18-config grid
(1,638 captures) takes ~2.5 min. Scored with Task 2's `score`, rest = the all-zero pose.

**Static-clip guard.** `search()` ranks a config last and flags it `rejected` if its largest
frame-to-frame diff is below `STATIC_MAX_DIFF = 0.003554` or any CLI run printed an error
(`has_cli_error`: `ERROR`/`error`/`N errors` with N > 0). 0.003554 is the measured mean luma
diff of a **1° shoulder step** from rest on this artboard (`search.py calibrate`): a clip that
never changes faster than 1°/frame (60°/s) anywhere is not a wave (the raise is 100° in
~0.3 s), so it is a broken, static render that would otherwise win with pops = jerk = 0.
Covered by tests (a static fake clip and an erroring fake clip both rank last). In the real
grid every config moved and no CLI run reported an error.

## Step 2: the grid (18 configs, 90 frames each)

`uv run rive/spikes/procmotion/search.py grid` → `procmotion/grid.json`. Sorted by
`(rejected, pops, jerk)` as `search()` returns it. Diff spread = min / median / max of the
per-frame mean luma diff (×10⁻³). Swing = delivered elbow peak-to-peak during the wave
(frames 22–61; commanded: 36° at amplitude 0.6, 60° at 1.0). Overshoot = shoulder peak minus
its 100° target (negative: never reached).

| # | stiffness | damping | amp | pops | jerk (px/s³) | diff min / med / max (×10⁻³) | moved | swing ° | overshoot ° |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 60 | 20 | 0.6 | 0 | 165,253 | 0.49 / 6.39 / 16.09 | yes | 16.2 | −3.1 |
| 2 | 60 | 20 | 1.0 | 0 | 168,321 | 0.67 / 6.43 / 16.09 | yes | 18.2 | −3.1 |
| 3 | 60 | 14 | 0.6 | 0 | 178,347 | 0.07 / 6.20 / 19.94 | yes | 8.8 | −0.0 |
| 4 | 60 | 14 | 1.0 | 0 | 183,642 | 0.05 / 6.29 / 19.94 | yes | 13.1 | −0.0 |
| 5 | 240 | 8 | 1.0 | 0 | 3,016,950 | 1.32 / 11.71 / 35.16 | yes | 117.1 | +42.1 |
| 6 | 240 | 8 | 0.6 | 0 | 4,113,427 | 1.02 / 9.78 / 35.16 | yes | 70.6 | +42.1 |
| 7 | 240 | 14 | 1.0 | 5 | 3,532,221 | 0.13 / 8.04 / 33.47 | yes | 74.3 | +17.9 |
| 8 | 120 | 8 | 1.0 | 8 | 2,887,670 | 0.16 / 7.37 / 30.78 | yes | 70.4 | +27.8 |
| 9 | 240 | 20 | 1.0 | 12 | 652,401 | 0.48 / 6.61 / 31.95 | yes | 53.4 | +4.3 |
| 10 | 120 | 8 | 0.6 | 13 | 3,334,059 | 0.14 / 6.92 / 30.67 | yes | 49.0 | +27.8 |
| 11 | 240 | 14 | 0.6 | 14 | 3,376,891 | 0.06 / 5.84 / 33.47 | yes | 44.9 | +17.9 |
| 12 | 60 | 8 | 1.0 | 18 | 3,880,512 | 0.03 / 5.20 / 24.84 | yes | 35.9 | +13.7 |
| 13 | 240 | 20 | 0.6 | 18 | 4,067,110 | 0.47 / 4.17 / 31.95 | yes | 32.3 | +4.3 |
| 14 | 120 | 14 | 1.0 | 21 | 2,585,666 | 0.30 / 4.62 / 28.52 | yes | 40.9 | +5.4 |
| 15 | 120 | 20 | 0.6 | 23 | 295,415 | 0.20 / 3.58 / 26.02 | yes | 14.3 | −0.0 |
| 16 | 120 | 20 | 1.0 | 23 | 297,299 | 0.35 / 3.64 / 26.02 | yes | 26.3 | −0.0 |
| 17 | 60 | 8 | 0.6 | 25 | 1,854,966 | 0.04 / 4.36 / 24.84 | yes | 25.6 | +13.7 |
| 18 | 120 | 14 | 0.6 | 26 | 1,998,047 | 0.17 / 3.21 / 28.52 | yes | 26.0 | +5.4 |

Read with care:

- **"pops" here are fast frames, not discontinuities.** Task 2's detector flags a diff above
  4× the clip's median (and above 0.01). This clip mixes a fast raise/lower (diffs up to
  0.03) with a slow, small wave (median 0.003–0.006), so every frame of the raise and the
  lower counts. Example, 240/20/1.0 (12 pops at frames 0–5 and 63–68): diffs ×10⁻³ run
  `30.0 31.7 32.0 31.3 30.0 28.1 24.9 20.2 …` and `… 3.7 15.5 25.7 28.9 30.4 30.7 30.2 …`
  — smooth ramps, no isolated spike. The configs with 0 pops are either uniformly slow
  (stiffness 60) or uniformly fast (damping 8), not smoother.
- What the onset `3.7 → 15.5` *is*: a spring toward a **step** target starts at full
  acceleration (k·Δ), i.e. no ease-in. Keys would ease in; a spring needs a shaped target
  (eased or pre-filtered) to match that.
- **The (pops, jerk) sort favours under-delivery.** Jerk scales with how far and how fast the
  arm moves, so the stiffness-60 rows win while delivering 9–18° of a 36–60° swing and never
  reaching the 100° raise (overshoot −3.1° at damping 20). Damping 8 rows wave hard but
  overshoot by 42° and swing the arm through the head and behind the body (`sheet.png` row 3).
- **amplitude** scales only the elbow swing, yet it can move jerk a lot: 240/20 0.65 M (1.0)
  vs 4.07 M (0.6) = 6.2×, 60/8 2.1×, 240/8 1.36×, 120/14 1.29×; only 60/20, 60/14 and 120/20
  barely change. Centroid jerk is unstable across near-identical motions (see Limits).

## Step 3: best configuration vs the baked wave (`baseline-wave.json`)

**Verdict: pops criterion met by construction (the sort picks the laziest spring); motion
quality INCONCLUSIVE.** Rows: the plan's sort winner, then every config that actually waves
(overshoot ≤ 10° and ≥ 50 % of the commanded swing; four qualify).

| | pops | jerk px/s³ | arm length (shoulder→wrist) | jerk / arm length | ratio vs baseline |
|---|---|---|---|---|---|
| baked wave (avatar, 132 frames, 800×1000) | 2 | 3,444,343 | 350 px (L1 180 + L2 170, `avatar_kit.py`) | 9,841 s⁻³ | 1 |
| **sort winner 60/20/0.6** (90 frames, 400×400) | **0 ≤ 2 ✅** | 165,253 | 175 px (90 + 85) | 944 s⁻³ | **0.096×** (raw 0.048×) |
| waves: 240/20/1.0 (53.4/60°, +4.3°) | 12 (fast frames, see above) | 652,401 | 175 px | 3,728 s⁻³ | 0.38× (raw 0.19×) |
| waves: 120/14/0.6 (26.0/36°, +5.4°) | 26 | 1,998,047 | 175 px | 11,417 s⁻³ | 1.16× (raw 0.58×) |
| waves: 120/14/1.0 (40.9/60°, +5.4°) | 21 | 2,585,666 | 175 px | 14,775 s⁻³ | 1.50× (raw 0.75×) |
| waves: 240/20/0.6 (32.3/36°, +4.3°) | 18 | 4,067,110 | 175 px | 23,241 s⁻³ | 2.36× (raw 1.18×) |

Waving configs: **0.38–2.36×** the baked wave's normalised jerk (3 of 4 above 1). The two
240/20 rows differ only in amplitude yet are 6.2× apart, so these ratios rank nothing reliably.

- Jerk (centroid of the pixels that differ from rest) is in px/s³, linear in on-screen scale,
  so it is divided by the arm's on-screen length; both renders are 1× CLI captures.
- **Not like-for-like:** the baseline's moving-pixel centroid includes the whole avatar's idle
  drift (breath, hair and cloth follow-through, head and body gesture keys) and the other arm;
  the spike has only the waving arm. The baseline is 132 frames (120-frame gesture + 12 settle),
  the spike 90. The baseline's pops are 2 real snaps (frames 20–21, the keyed raise); the
  spike's are fast frames. Seam is not comparable (baseline seam is idle drift, not a loop).

**Bytes** (`uv run rive/spikes/procmotion/measure_bytes.py <tmp>`: builds `rive/avatar/avatar.rml`
in a temporary copy; the as-is build is byte-identical to `assets/rive/avatar.riv`, 493,462 B;
`uv run rive/spikes/procmotion/gen_procmotion.py --sizes <tmp>`):

| what | bytes |
|---|---|
| whole `gesture_wave` keys (34 keyed objects, 1,682 keyframes; element kept, keys removed) | 18,090 |
| whole `gesture_wave` element (+ its AnimationState's reference dropped) | 18,111 |
| waving-arm tracks only (`ArmR` + descendants: ArmR, Elbow, Hand, HandWave, UpperArt, ForeArt; 6 keyed objects) | 4,841 |
| **procedural drive** in the `.riv` (2 binds + 2 formula converters + VM of 5 numbers) = `Arm` driven 1,367 − same art static 1,063 | **304** |
| **the same spring motion baked into keys** (`StressKeyed` `Wave`, 2 tracks × 46 keys per arm): 20,518 B / 20 arms | **1,026 per arm** |
| `procmotion.riv` (Arm + Stress + StressKeyed) | 65,546 |
| `spring_wave.dart` source (spring + targets + `SpringArms`), **not in the `.riv`** | 3,526 |

Drive vs keys: **304 / 1,026 = 0.30×** against the same motion keyed every 2 frames (exactly
like-for-like), **304 / 4,841 = 0.063×** against the avatar wave's arm tracks (which also key
foreshortening and the hand), **0.017×** against the whole wave gesture. The spring's code
and its target pattern live in Dart (compiled into the app, size not measured), and one spring drives every gesture, so its cost is not per gesture.
The baked wave also carries hand-pose swaps, head/body acting and cloth follow-through that the
spike does not reproduce.

## Step 4: device cost

> † **Timeline caveat** (added in Task 8; source: [tiers.md](tiers.md) § Timeline vs FrameTiming).
> The timeline P95s in this section come from 10 s runs. The VM timeline is a ring buffer, so
> each P95 covers only about the last 4–5 s of frames. Same-run ratios share this bias. These
> numbers were not re-measured: the M1 follow-up is a re-run with `--endless-trace-buffer` or
> with `FrameTiming`. Task 7's atrace (emulator sequence c) also refines the claim that "the
> timeline under-reports Rive": Rive encodes and submits on the UI thread inside build, so
> `build` includes Rive's CPU work. Only its GPU execution is unobserved.

Harness: `integration_test/spikes/rive_capability_test.dart`, profile mode, 10 s per case,
400×400 stage, one run per tier with **all 24 cases** (`All tests passed` on both); stale
`build/spikes/<tier>/procmotion*` cleared first. P95 = nearest rank over the Flutter timeline
frame lists (`rive/spikes/tools/matrix.py` `p95_ms`).

Cases (`integration_test/spikes/spike_cases.dart`), all on `procmotion.riv`, cost only:

- `procmotion_stress` — `Stress` (20 arms), auto-bound; the new `SpikeCase.driver` hook
  (`SpringArms.stress`) runs a `Ticker`: every frame it steps 40 springs (search winner
  60/20/0.6, arm *i* phase 4·*i*, fixed dt 1/60) and writes the 40 VM numbers (`s<i>`, `e<i>`,
  resolved once). Measures Dart step + VM writes + Rive re-pose + draw. Step + write time is
  timed on the UI thread (`build/spikes/<tier>/drive_procmotion_stress.json`).
- `procmotion_static_stress` — same artboard, no driver (arms at rest), per the ruling.
- `procmotion_keyed_stress` — added because the static control turned out unusable on macOS
  (below): `StressKeyed`, the same 20 arms and the same motion baked into keys. Driven / keyed
  isolates "procedural drive" from "animating 20 skinned arms".

| tier (renderer) | case | frames | P95 build ms | P95 raster ms |
|---|---|---|---|---|
| macos (skia) | baseline_avatar | 312 | 1.65 | 0.58 |
| macos (skia) | procmotion_static_stress | **0** | – | – |
| macos (skia) | procmotion_keyed_stress | 311 | 1.01 | 0.66 |
| macos (skia) | **procmotion_stress** | 311 | 1.15 | 0.76 |
| emu (impeller, OpenGLES per logcat) | baseline_avatar | 291 | 6.66 | 2.81 |
| emu (impeller) | procmotion_static_stress | 291 | 0.90 | 20.00 |
| emu (impeller) | procmotion_keyed_stress | 285 | 6.60 | 18.96 |
| emu (impeller) | **procmotion_stress** | 285 | 5.66 | 19.44 |

Dart spring step + 40 VM writes per frame (UI thread): macOS P50 32 µs / P95 61 µs / max
208 µs over 763 ticks; emu P50 35 µs / P95 74 µs / max 4.6 ms over 600 ticks.

Same-run ratios, `procmotion_stress` vs:

| tier | keyed (same motion as keys) | static (rest) | baseline_avatar |
|---|---|---|---|
| macos build | **1.13×** (+0.14 ms) | n/a (0 frames) | 0.70× (−0.49 ms) |
| macos raster | **1.15×** (+0.10 ms) | n/a | 1.32× (+0.18 ms) |
| emu build | **0.86×** (−0.93 ms) | 6.3× (+4.76 ms) | 0.85× (−1.00 ms) |
| emu raster | **1.03×** (+0.48 ms) | 0.97× (−0.56 ms) | 6.9× (+16.6 ms) |

Read with care:

- **Procedural vs keyed is a wash** at this scale: within ±15 % on both tiers, i.e. inside the
  run-to-run noise these tiers show (Task 3/4). The Dart side itself is ≤ 0.07 ms P95 per frame
  for 20 arms. The emulator's build-time jump vs static (+4.8 ms) appears for the keyed case
  too, so it is Rive advancing/re-posing 40 moving bones and 40 skinned paths, not the drive.
- **The static control behaves differently per tier.** On macOS an unchanging artboard stops
  repainting: the traced window had **no frame at all** (the harness driver used to crash on
  that; `test_driver/spike_driver.dart` now records `frame_count: 0` and P95 "?"). A rig at rest
  costs nothing there. On the emulator it kept repainting (291 frames).
- Emulator raster is ~19–20 ms P95 for all three 20-arm cases (static included) and 2.8 ms
  for the avatar in the same run: 20 full-size arms on a 2000×1600 artboard fitted into the
  stage cost real raster time there, driven or not. Over the 16.6 ms low-tier budget, but the
  emulator is not a device tier and its raster numbers swing several-fold between runs (Task 3:
  the same case 4.4 → 32 ms). Not extrapolated.
- `rive_native` draws Rive into its own surfaces, so the Flutter timeline under-reports Rive's
  GPU work on both tiers; gfxinfo framestats cannot cross-check it (Task 3).
- The Ticker fired 763 times in the 10 s macOS window while the timeline summary counted 311
  frames (emu: 600 ticks, 285 frames); the spring steps once per tick at a fixed 1/60 s, so on
  macOS the wave ran ~1.3× fast. The cost numbers are per frame and unaffected. The 763-tick vs
  311-frame gap is explained largely by the timeline ring buffer (the † caveat in the README and
  [tiers.md](tiers.md): the summary holds only the newest ~273–314 frames), not only by the wave
  running fast.
- Device screenshots (`build/spikes/<tier>/procmotion_*.png`) were viewed: driven and keyed show
  20 arms at different phases of the wave on both tiers, static shows them at rest — the VM
  drive works on the pinned runtime with both renderers.
- The emulator was not attached when the run started; the existing `Medium_Phone` AVD was
  booted with default options, nothing reconfigured.

## Limits

- **No scripts on device** (Task 3): the spring is Dart, so every procedural rig needs app-side
  code and per-frame VM writes; the `.riv` alone cannot animate itself. The `stiffness`,
  `damping`, `amplitude` VM numbers are documentation only.
- **Motion quality is not a win yet.** The metrics' best is a sluggish arm; the arm that waves
  has no ease-in (step targets). Shaped targets (eased keys fed into the spring, or a
  critically damped pre-filter) are the next experiment; a pose-to-pose wave with a spring
  for follow-through is the likelier product shape.
- The pop metric (Task 2) is median-relative and flags fast-but-smooth frames on clips that mix
  fast and slow motion; it cannot tell a snap from a quick move here. Jerk favours small motion.
- **Centroid jerk is unstable across near-identical motions**: changing only amplitude moves it
  1.3–6.2× (240/20: 0.65 M vs 4.07 M). The jerk of the moving-pixel centroid depends on which
  pixels cross the 8/255 threshold frame to frame, not only on the motion's smoothness. This
  weakens every single-config jerk ratio in this doc, including the sort winner's 0.096×.
- One arm, two joints, no hand-pose swaps, no secondary motion; the avatar's arm also
  foreshortens (UpperArt/ForeArt `scaleY`), which the spike does not.
- The spring runs at a fixed dt of 1/60 per rendered frame on device (like the CLI); at 120 Hz
  it would play twice as fast. A product version would step by elapsed time (sub-stepped).
- Emulator numbers are not a device tier; physical tiers not run.
