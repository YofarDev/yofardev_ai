# M6 Task 7: emulator frame cost with the front layer, and the owner's device run (ruling 11)

## The owner's mid-tier run (the band's exit gate)

The M4–M6 exit gate asks for Wow #1 and #2 "in the app on a mid-tier device, within budget". No
mid-tier phone is reachable from the agents (the phone on adb is off-limits), so this run is the
owner's. Plug in the phone, then:

```
flutter devices                                   # note the phone's id
flutter drive --profile -d <that id> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart
```

About 2 minutes. It boots the real app on Home, shows each scene for 10 s with the avatar, then
campfire and beach again at rain 1 (their front weather layer drawn over the avatar, contract v9),
and prints one `FRAME_COST <scene> {...}` line per pass (also returned as the driver's response
data). Keep the phone on the desk, screen on, not charging if possible, other apps closed.

**Pass thresholds**, every line (`livingRoom`, `campfire`, `campfire_rain1`, `beach`, `beach_rain1`,
`deepSpace`):

| Number | Pass |
|---|---|
| `over_16_6_share` (frames whose build or raster alone exceeds 16.6 ms) | ≤ 0.01 (1 %) |
| `build_p95` | ≤ 14 ms |
| `raster_p95` | ≤ 14 ms |

Reading a fail: a high `build_*` is the UI thread (the Rive scene and avatar `advance` run in the
frame callback, plus the face performer); a high `raster_*` is the GPU (feather, gradients, the
front layer's 72 streaks). A fail only at `*_rain1` is the front layer or the rain art; a fail on a
dry scene is the scene or the avatar. Battery and thermal are not measured by this test.

## The emulator run (agent, 2026-10-30)

Same AVD and command as M5 (`Medium_Phone`, API 37, host GPU, `flutter drive --profile -d
emulator-5554`; the phone was never addressed). Raw numbers:
[`frame_cost_profile.json`](frame_cost_profile.json). Milliseconds.

| Run | Scene | frames | build P50 | build P95 | raster P95 | over 16.6 ms |
|---|---|---|---|---|---|---|
| 1 | livingRoom | 523 | 10.46 | 21.23 | 10.45 | 12.6 % |
| 1 | campfire | 551 | 10.45 | 17.26 | 10.26 | 6.9 % |
| 1 | campfire, rain 1 (front on) | 641 | 10.02 | 13.64 | 9.62 | 1.2 % |
| 1 | beach | 632 | 9.77 | 13.71 | 9.86 | 0.9 % |
| 1 | beach, rain 1 (front on) | 638 | 9.72 | 13.09 | 9.74 | 0.6 % |
| 1 | deepSpace | 626 | 9.72 | 13.57 | 9.98 | 2.1 % |
| 2 | livingRoom | 549 | 10.29 | 18.72 | 10.45 | 8.0 % |
| 2 | campfire | 627 | 9.40 | 12.20 | 9.92 | 1.1 % |
| 2 | campfire, rain 1 (front on) | 597 | 9.44 | 14.23 | 10.28 | 3.0 % |
| 2 | beach | 430 | 12.74 | 26.11 | 11.69 | 28.8 % |
| 2 | beach, rain 1 (front on) | 384 | 12.96 | 30.93 | 12.21 | 30.5 % |
| 2 | deepSpace | 489 | 11.25 | 21.40 | 10.63 | 17.6 % |

**Reading: the host was busy, so these numbers say little.** Both runs ran on a loaded Mac (load
average 12–16: other sessions' `flutter_tester` processes, a game, WindowServer), unlike M5's quiet
run (build P95 12.6–13.1, ≤ 0.5 % over everywhere). The same scene moved from 0.9 % to 28.8 % over
between two back-to-back runs, and livingRoom and deepSpace, whose files M6 did not touch, came out
worse than in M5. What holds across both runs:
- raster P95 stays at 9.6–12.2 ms everywhere: the GPU side has room;
- the front layer has no visible cost: within each run, a scene at rain 1 is within the run's own
  noise of the same scene dry (run 1: campfire 6.9 % dry vs 1.2 % wet, beach 0.9 % vs 0.6 %; run 2:
  campfire 1.1 % vs 3.0 %, beach 28.8 % vs 30.5 %);
- the build thread is what the host's load hits (the Rive `advance` runs in the frame callback).

The M6 changes that run every frame are the second Rive artboard while it rains and nothing else
(dry, the front controller does not exist). A quiet-host emulator rerun is a two-minute job for the
owner (`emulator -avd Medium_Phone -no-window -no-audio -no-boot-anim -no-snapshot`, then the
command above with `-d emulator-5554`); the device run above is the one that decides the gate.

The macOS desktop numbers recorded during the wow captures (debug build, not a tier) are in
[`../wow/wow1_frame_cost.json`](../wow/wow1_frame_cost.json) and
[`../wow/wow2_frame_cost.json`](../wow/wow2_frame_cost.json): build P95 5.4–6.5 ms, raster P95
1.1–1.2 ms, 0.6 % of frames over 16.6 ms while a full reply plays (speech, tool, tablet, rain).
