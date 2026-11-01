# M11 device runs: frame cost per tier and battery (rulings 14–16)

These are the owner's steps for the mid-tier phone. M11 does not run them on the phone: it records
the macOS and emulator numbers with their caveats, and the verdict per tier is the phone's run.
Everything comes from one harness, `integration_test/frame_cost_test.dart`, driven by
`test_driver/integration_test.dart` (90 min timeout).

## Before any run

- **Profile build**, never debug: `flutter drive --profile ...` (release-like timings with
  `FrameTiming` still reported).
- Name the device on every call: `-d <serial>` for `flutter drive`, `adb -s <serial>` for adb
  (`adb devices -l` lists the serials). Several devices may be attached.
- Charge to ≥ 80 %, close the other apps, screen on at a fixed brightness (the same for every run),
  auto-rotate off, battery saver **off** (it caps the app at low: ruling 12), do-not-disturb on.
- Let the phone cool for 10 min between runs (`adb -s <serial> shell dumpsys thermalservice`
  shows the status; 0 = none).
- Record the host load on the Mac before and after each run: `uptime` (the three load averages).
  A loaded host slows `flutter drive` and the emulator, not the phone's frames, but the number
  makes reruns comparable.
- The harness forces each tier with `QualityTierService.forceTier`, so the thermal, battery and
  drift caps never interfere during a pass (the app's own benchmark waits while a tier is forced);
  the phone's own benchmark is read 8 s after the last pass and printed as `benchmark` in
  the report (what the app would pick by itself).

## 1. Frame cost per scene × tier

```bash
uptime
flutter drive --profile -d <serial> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart \
  --dart-define=TIERS=low,high,ultra --dart-define=SECONDS=8 \
  | tee frame_cost_<device>_<date>.log
uptime
```

- Every `AvatarScene` is shown in turn (the list is read from the enum: ten scenes once lane
  D-scenes lands), and for each tier in `TIERS` the stage runs `SECONDS` (default 8) of
  `FrameTiming`. Each scene with a `SceneFront` (`AvatarRiveContract.sceneFrontScenes`: campfire,
  beach, rooftop, and forestCabin once it is in) is measured again at rain 1 for each tier
  (`<scene>_rain1`; on low the front is never drawn, so its rain-1 pass shows what that saves).
- One line per pass: `FRAME_COST <scene> <tier> {json}`; at the end `FRAME_COST_REPORT {json}`
  with everything, also written by the driver as its response data (`build/integration_response_data.json`).
- The run takes about 10 scenes × 3 tiers × 11 s + 4 rain scenes × 3 tiers × 11 s + scene switches,
  ≈ 9 min. To narrow it: `--dart-define=TIERS=high` (one tier), `--dart-define=SECONDS=4`.
- Copy the log and the JSON into `rive/review/m11/perf/` (or a later milestone's folder), with the
  device model, Android version, the `benchmark` the app picked and both `uptime` lines.

### What each pass reports

| Key | Meaning |
|---|---|
| `frames` | frames drawn in the window (a 120 Hz phone at ultra: about 960 in 8 s) |
| `build_p50/p95/p99`, `raster_p50/p95/p99` | per-thread frame times, ms (Rive's advance runs in build) |
| `worst_p50/p95/p99` | `max(build, raster)` per frame, ms: the tier metric (M0) |
| `budget_ms` | the tier's frame budget (below) |
| `over_budget_share` | share of frames whose `max(build, raster)` is over `budget_ms` |
| `pass` | ruling 14: `worst_p95 ≤ budget_ms` **and** `over_budget_share ≤ 0.05` |
| `over_16_6_share`, `m6_pass` | M6's mid-tier rule (below) |

### Pass table (ruling 14; the gates M12 must pass)

| Tier | Target | Frame budget | Gate per scene (P95 of max(build, raster); share over budget) |
|---|---|---|---|
| low | 60 Hz | 16.7 ms | P95 ≤ 16.7 ms and ≤ 5 % of frames over 16.7 ms |
| high | 90 Hz | 11.1 ms | P95 ≤ 11.1 ms and ≤ 5 % over 11.1 ms |
| ultra | 120 Hz | 8.3 ms | P95 ≤ 8.3 ms and ≤ 5 % over 8.3 ms |

**M6's mid-tier rule** still holds on the owner's phone, **at the tier its benchmark picks**
(`benchmark` in the report): ≤ 1 % of frames over 16.6 ms, build P95 ≤ 14 ms and raster P95 ≤ 14 ms
(`m6_pass`). The other tiers' rows on that phone are recorded, not judged by M6's rule.

### Reading a fail

- **`pass` false at the benchmark's tier**: the tier the app would pick on its own is too rich for
  that scene. Look at which thread: `build_p95` over the budget is Rive's advance and the Dart
  writers (the scene's animation count, the avatar, the NPC); `raster_p95` over it is drawing
  (blend modes, fog veils, the front sheet, texture size per shot). Compare the same scene one
  tier down: if the lower tier passes, the tier gates buy what they should and the fix is in the
  benchmark thresholds or the art; if it fails too, the scene's base cost is the problem.
- **Only `<scene>_rain1` fails**: the front weather (and the rain sheets) cost it. On low the front
  is never created; if low still fails at rain 1, the rain in the back artboard is the cost.
- **`over_budget_share` > 5 % but P95 within budget**: periodic spikes (a scene event loop, garbage
  collection, a texture re-upload at a camera cut). Rerun once; if it repeats, it is real.
- **A higher tier that passes while a lower one fails** on the same scene: noise or thermal. Let
  the phone cool and rerun that scene only; record both runs.
- **`frames` far below `SECONDS` × refresh**: the phone dropped to a lower refresh rate (battery
  saver, a thermal limit, the display's adaptive rate) or the app was covered: the pass says
  nothing, rerun it.
- A fail is recorded with the numbers and the caveats; M11 does not tune to these gates (M12 does).

## 2. Battery (ruling 16)

The app's own sample: the campfire at one forced tier for `MINUTES` (default 30), one
`BATTERY {json}` line per minute (`level` %, `state`, `saver`, `thermal`, `tier`).

The battery level only falls while the phone is **not charging**: run the drive over wireless
debugging (`adb pair` / `adb connect`, then pull the USB cable), or the level stays flat.

```bash
uptime
adb -s <serial> shell dumpsys batterystats --reset
flutter drive --profile -d <serial> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart \
  --dart-define=PHASE=battery --dart-define=TIER=high --dart-define=MINUTES=30 \
  | tee battery_<device>_<tier>_<date>.log
adb -s <serial> shell dumpsys batterystats --charged fr.yofardev > batterystats_<tier>.txt
uptime
```

- Run it once per tier (`TIER=low`, `high`, `ultra`), from the same start level (± 5 %), the same
  brightness, cooled in between. Same order every time, or alternate the order on reruns.
- Report per tier: level drop over the run (% / 30 min), the thermal levels seen, and from
  `--charged` the app UID's estimated power (mAh) and its CPU / GPU time (M0's procedure). The
  drop is coarse (1 % steps); batterystats is the finer number. Compare tier to tier on the same
  phone, never across phones.
- A `thermal` above `light` during the run is a finding on its own (the app would have capped its
  tier there: moderate → one tier below the benchmark, severe / critical → low).
- M11 claims no battery number; this is the procedure M12's gate uses.

## 3. Tilt (unchanged from M5)

`--dart-define=PHASE=tilt` prints `TILT t=… x=… y=…` twice a second for 60 s on the campfire; tilt
the phone by hand (or `adb -s <serial> emu sensor set acceleration x:y:z` on an emulator). On a
forced or benchmarked **low** tier the parallax is off by design (ruling 13): run it at high or
ultra.

## Caveats: an emulator or a Mac is not a tier

- **macOS** (`-d macos`): a desktop GPU, no thermal throttling worth the name, Skia (Impeller is
  off in `macos/Runner/Info.plist`), a 60 Hz or 120 Hz display depending on the screen. Its numbers
  rank the scenes and the tiers against each other; they say nothing about a phone. macOS stops
  rendering a covered window: keep the app window visible and unoccluded for the whole run.
- **The emulator** (`Medium_Phone`, which we start ourselves: `emulator -avd Medium_Phone
  -no-window -no-audio -no-boot-anim -no-snapshot`): the host's GPU through a translation layer,
  60 Hz, a simulated battery (battery numbers are invalid) and no thermal model. Its build times
  are inflated and noisy (M0 saw a 3.5× spread on one AVD in one session), so record `uptime`
  before and after and rerun a suspicious scene.
- Both are recorded with these caveats in the review index; the per-tier verdict stays the phone's.
- The thermal channel reads the OS state only (Android `PowerManager` thermal status, API 29+;
  Apple `ProcessInfo.thermalState`); nothing leaves the device (ruling 29).
