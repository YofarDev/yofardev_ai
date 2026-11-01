# Moonshot M11 review index

One row per evidence set (M11 plan ruling 24, as M4–M10: no critic rounds, one render, one cheap Sonnet
defect-only pass over the new scenes' sheets: 0 blocker, 0 should-fix, 4 notes, 2 fixed). The plan, every
ruling (1–31) and the execution rulings (32–42):
[2026-11-01-moonshot-m11.md](../../../docs/superpowers/plans/2026-11-01-moonshot-m11.md).

**M11's own exit (ruling 30):** the three scenes are in (each ≤ 400 KB, posters ≤ 40 KB); `WOW=pairs`
drove all 90 ordered journeys in the app, every gate ok, 0 network; the tier service, the tier-gated art,
the CLI bench gate and the per-tier frame harness are in, with numbers recorded on macOS and the emulator
(load recorded); seasons and the wind bed are in; the accessibility evidence is below. The quarter's exit
gate (every tier passes its perf gate) is M12's, and its verdict is the owner's mid-tier phone run
([device/README.md](device/README.md)).

## Budgets

| File | M10 (`bf8aec8`) | M11 | Budget |
|---|---:|---:|---:|
| `avatar.riv` | 488,418 | 488,418 (untouched) | 614,400 |
| `journeys/journey.riv` | 22,364 | 22,364 (untouched; 90 pairs, no new threshold) | 163,840 |
| `scenes/livingRoom.riv` | 143,428 | 149,993 (v14 members, tier gate, spring / autumn sill) | 409,600 |
| `scenes/campfire.riv` | 252,508 | 293,827 (tier gate, spring flowers / autumn leaves and ferns) | 409,600 |
| `scenes/beach.riv` | 306,555 | 308,010 | 409,600 |
| `scenes/deepSpace.riv` | 79,711 | 80,546 | 409,600 |
| `scenes/cafe.riv` | 138,681 | 140,642 | 409,600 |
| `scenes/rooftop.riv` | 154,863 | 156,325 | 409,600 |
| `scenes/mountainHut.riv` | 116,629 | 117,331 | 409,600 |
| `scenes/forestCabin.riv` | — | **180,396** (new) | 409,600 |
| `scenes/trainCompartment.riv` | — | **97,509** (new) | 409,600 |
| `scenes/library.riv` | — | **161,287** (new) | 409,600 |
| posters (10) | ≤ 31,228 each | old 7 unchanged; forestCabin 31,762, trainCompartment 26,348, library 39,168 | 40,960 each |
| `assets/foley/` (13 WAVs) | 830,932 | 917,376 (+ `bed_wind.wav` 86,444) | 921,600 |

Ten scenes total 1,685,866 B, bundled (ruling 4). New committed evidence: 5.8 MB (ruling 25: ≤ 15 MB),
no GIF.

## Per-tier numbers

Budgets (ruling 14): low 16.7 ms, high 11.1 ms, ultra 8.3 ms — pass = P95 of max(build, raster) within
the budget and ≤ 5 % of frames over it. **A Mac or an emulator is not a tier**; these runs say where the
work goes, not whether a phone passes.

**CLI bench** ([perf/bench.md](perf/bench.md), host-independent shape, render p95 ms at rest, best of 5):

| Scene | ultra | high (×) | low (×) |
|---|---:|---:|---:|
| beach | 0.577 | 1.004 | 0.621 |
| cafe | 0.781 | 1.009 | 0.657 |
| campfire | 0.870 | 1.004 | 0.632 |
| deepSpace | 0.858 | 1.000 | 0.552 |
| forestCabin | 0.847 | 0.995 | 0.681 |
| library | 0.619 | 0.984 | 0.760 |
| livingRoom | 1.247 | 1.020 | 0.628 |
| mountainHut | 0.799 | 0.963 | 0.722 |
| rooftop | 0.939 | 1.002 | 0.567 |
| trainCompartment | 0.909 | 0.994 | 0.676 |

Gate: low ≤ 0.8 × ultra, high ≤ ultra (with the paired-noise rule of execution ruling 37). **The close-out
`FRIVE_GATES=all` run (load 5–10) passed 297 of 298 gate lines; the one FAIL was library's bench, low
0.824 × ultra; re-run alone at load 5.0 it passed at 0.780.** library (and mountainHut) sit closest to the
line: the gate is load-sensitive there; an M12 item is a little more low-tier margin in those two.
At rest high draws nearly the same file as ultra: what high drops is dense rain / snow / twinkle halves,
which only cost when raining. Host load 2.1–3.6 (1-min).

**Emulator** ([perf/frame_cost_emulator.md](perf/frame_cost_emulator.md); `Medium_Phone` API 37, host GPU,
60 Hz, `flutter drive --profile -d emulator-5554`, 8 s per pass; host load 20.3 → 6.3 over the run, the Mac
had just restarted): 42/42 passes valid. **Low passes on 12 of 14** (beach 19.8 % and library 21.7 % over,
both during load spikes; worst P95 13.6–16.4 ms elsewhere). **High and ultra fail everywhere:** the
emulator's frame P50 is ~10.3 ms whatever the tier, so the 11.1 / 8.3 ms budgets are out of its reach.
What the run does show: **rain 1 at high / ultra (the `SceneFront` drawn over the avatar) roughly doubles
the build P95** (22–58 ms against 13–17 dry), and low (no front layer) stays at 14–16 ms — the front layer
is the first thing for M12 to look at.

**macOS** ([perf/frame_cost_macos.md](perf/frame_cost_macos.md); profile, desktop GPU): 28 of 42 passes
valid (macOS stops drawing an occluded window: 14 passes drew 1–4 frames; the harness now rejects them,
82638d6); all 28 valid passes within budget (worst P95 ≤ 6.3 ms). Benchmark tier on this Mac: high.

## Evidence

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **forestCabin** (Task 2) | Porch at the forest's edge; squirrel; `pinwheel` spin; seasons; festive; rain + `SceneFront` | [scenes/forestCabin/](scenes/forestCabin/) | 45 gate lines ok; pinwheel wraps, history-free; squirrel 16.1 KB; Sonnet 0 defects | — |
| **trainCompartment** (Task 3) | Sleeper compartment, landscape scrolling on 4 seamless tiles; ladybug; `chain` pull → `whistle`; seasons in the window | [scenes/trainCompartment/](scenes/trainCompartment/), [defect fixes](scenes/trainCompartment/defect_fixes.png) | 43 gate lines ok; every loop back at frame 1800; ladybug 9.8 KB; Sonnet notes fixed (sign emblem, wing) | — |
| **library** (Task 4) | Storm window, shelves, mouse, `ladder` aim, festive garland, `lightning` | [scenes/library/](scenes/library/) | 40 gate lines ok; ladder history-free; mouse 10.9 KB | Sonnet notes kept: the asleep / awake 200 ms blend ghost; the ladder's stile off the right edge at +1 |
| **Tier gates** (Task 7) | Each scene at ultra / high / low, rest and rain 1 | [tiers/](tiers/), [bench](perf/bench.md) | ultra / spring 0 / autumn 0 identical to M10 (0 px, front artboards too) | `SceneFront` splashes never show in CLI renders (also at M10) |
| **Seasons and wind** (Tasks 7–8) | Spring / autumn in forestCabin, campfire, livingRoom, trainCompartment; the wind bed | [seasons/](seasons/), [wind](seasons/wind.txt) | 0 px at 0 / 0; wind loop join RMS 0.136 vs 0.149 in-loop | Nobody has heard the wind bed |
| **Journeys over ten scenes** (Task 10) | `WOW=pairs`: all 90 ordered pairs in the app | [reel](wow/pairs.mp4) (12 s), [sheet](wow/pairs_sheet.webp), [gates](wow/pairs_gates.txt) | All ok: 90/90 families (66 door, 9 rocket, 9 portal, 6 path), beats in order, destination drawn, one jacket at a time, 0 network | — |
| **New scenes in the app** (Task 10) | `WOW=scene` × 3: NPC poke + drag + a spoken reply | [forestCabin](wow/scene_forestCabin_gates.txt), [train](wow/scene_trainCompartment_gates.txt), [library](wow/scene_library_gates.txt) + reels and sheets | All ok: reacts in 23–26 ms; pinwheel inertia settles; chain fires `whistle` and springs back; ladder holds; drag haptics logged | Haptics unfelt |
| **Accessibility** (Task 9, rulings 17–23) | Stage semantics + custom actions, live reduce motion, large text, screen-reader order, contrast, haptics path, high contrast | [a11y/README.md](a11y/README.md), semantics dumps | Widget / semantics tests per ruling; Sonnet review 0 high, 1 medium + 1 low fixed | Not checked with a real screen reader on a device |
| **Contract on the real runtime** | `integration_test/rive_contract_test.dart -d macos` | — | 59/59: every scene's `tier` / `spring` / `autumn`, the three drags | — |
| **Device steps** | Frame cost per tier and the battery phase for the owner's phone | [device/README.md](device/README.md) | — | Not run on a phone |

## How to regenerate

```
./scripts/frive.sh                                   # FRIVE_GATES=all adds the prop gates
uv run rive/tools/rive_bench.py                      # the CLI bench per scene x tier
uv run --with pillow --with numpy rive/tools/review_tiers.py
flutter test integration_test/rive_contract_test.dart -d macos
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=pairs   # or WOW=scene --dart-define=SCENE=<id>
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/<run> rive/review/m11/wow
flutter drive --profile -d <emulator> --driver=test_driver/integration_test.dart --target=integration_test/frame_cost_test.dart
uv run rive/tools/frame_cost_table.py <drive log>
flutter test tool/a11y_semantics_dump_test.dart
```

## Not verified

- **The owner's mid-tier phone run** ([device/README.md](device/README.md)) is still the verdict for every
  tier; no tier ran on a phone. The battery phase (`PHASE=battery`) is written, not run.
- The thermal channel on a real device (Android `PowerManager`, Apple `ProcessInfo`); iOS does not build
  (pre-existing: `AppDelegate.swift` references a missing `VoiceEffectsHandler`).
- The wind bed, the new drags' haptics and every M8–M10 sound are unheard / unfelt on hardware; the screen
  reader paths are tested in widget tests only.
