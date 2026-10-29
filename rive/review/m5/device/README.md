# M5 Task 10: emulator frame cost and tilt check (ruling 10)

Everything here ran on the `Medium_Phone` emulator. **An emulator is not a tier**: its numbers say
the frame loop holds 60 fps on a fast host GPU and nothing about a real mid-tier phone.

## Environment

| | |
|---|---|
| AVD | `Medium_Phone` (`sdk_gphone16k_arm64`), headless: `emulator -avd Medium_Phone -no-window -no-audio -no-boot-anim -no-snapshot` |
| Android | 17, API 37 (`system-images/android-37.2/google_apis_playstore_ps16k/arm64-v8a`, 16 KB page size) |
| ABI / screen | arm64-v8a, 1080 x 2400 |
| GPU | `hw.gpu.mode=host` (Apple Silicon host GPU through ranchu/gralloc, not a phone GPU) |
| Flutter | 3.47.4 stable, **profile mode** (`flutter drive --profile`, accepted by the emulator) |
| Renderer | the engine default on Android (Impeller) |
| App | the real `App` on Home (the Stage: scene, avatar, chips, composer), idle avatar, no chat running |

Every command named the emulator (`-d emulator-5554` / `adb -s emulator-5554`); the physical phone
on the same adb was never addressed.

## Frame cost

`integration_test/frame_cost_test.dart` boots the real service locator and `App`, switches the scene
through `AvatarCubit.onNewAvatarConfig` (no specials, so no walk-off), waits 4 s, then records every
`FrameTiming` for 10 s (plus 1 s for the last batch). Campfire is measured again with
`WorldStateService.setRain(1)`.

```
flutter drive --profile -d emulator-5554 \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart
```

Raw data: [`frame_cost_profile.json`](frame_cost_profile.json). Milliseconds; "over" = a frame whose
build or raster alone took more than 16.6 ms.

| Scene | frames | build P50 | build P95 | build P99 | raster P50 | raster P95 | raster P99 | over 16.6 ms |
|---|---|---|---|---|---|---|---|---|
| livingRoom | 647 | 9.70 | 12.95 | 15.19 | 7.65 | 9.61 | 10.29 | 0.0 % |
| campfire | 647 | 9.76 | 12.87 | 14.41 | 7.48 | 9.52 | 10.42 | 0.0 % |
| campfire, rain 1 | 641 | 9.67 | 13.06 | 14.67 | 7.16 | 9.29 | 10.31 | 0.5 % |
| beach | 649 | 9.60 | 12.63 | 14.13 | 7.69 | 9.71 | 11.00 | 0.15 % |
| deepSpace | 643 | 9.60 | 12.96 | 14.82 | 7.66 | 9.65 | 10.53 | 0.15 % |

Reading: about 59 frames a second on every scene, build P95 12.6 to 13.1 ms and raster P95 9.3 to
9.7 ms, so a frame fits 16.6 ms with room on this host; the scenes differ by less than the run to
run noise (an earlier identical run, with the system's 16 KB dialog over the app, gave build P95
10.95 to 11.55 and raster P95 10.25 to 10.3). Rain and the shared diorama pass add nothing visible.
The build time (about 10 ms P50) is high for an idle screen: the Rive `advance` of the scene and the
avatar runs inside the frame callback, so it is the number to watch on a real phone.

## Tilt signs

The test's tilt phase (`--dart-define=PHASE=tilt`) puts the app on the campfire, prints
`ParallaxSource.value` twice a second for 60 s and holds the app open while the sensor is driven
from outside:

```
flutter drive --profile -d emulator-5554 --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_cost_test.dart --dart-define=PHASE=tilt
adb -s emulator-5554 emu sensor set acceleration 0:9.78:0.81     # rest, upright portrait
adb -s emulator-5554 emu sensor set acceleration -4:9:0.81       # right edge down
adb -s emulator-5554 emu sensor set acceleration 4:9:0.81        # left edge down
adb -s emulator-5554 emu sensor set acceleration 0:9:4           # top edge away (screen faces up)
adb -s emulator-5554 emu sensor set acceleration 0:9.78:-3       # top edge toward the viewer
adb -s emulator-5554 exec-out screencap -p > shot.png            # 2.5 s after each command
```

Android's accelerometer reads the reaction to gravity, so with the right edge down it reads a
negative x. What the app wrote (`ParallaxSource.value`, 2.5 s after each command):

| Sensor command | offset | what moved on screen (screencap diff, near vs far planes) |
|---|---|---|
| right edge down (`-4:9:0.81`) | x = +0.9 to +1.0 | near planes **right** 32 px (fire, tent), mountains 7 px right, sky 0 |
| left edge down (`4:9:0.81`) | x = -1.0 | near planes left 34 px, mountains 9 px left |
| top away (`0:9:4`) | y = +0.94 | near planes down 15 to 16 px, mountains 10 px down |
| top toward (`0:9.78:-3`) | y = -1.0 | near planes up 19 px, mountains 13 px up |

(`tilt_strip_left_rest_right.png`: left edge down, rest, right edge down; `tilt_top_away.png`.)

**Verdict.** `ParallaxSource` does what its doc says (right edge down gives +x, top away gives +y),
and the planes are ordered correctly (near moves most, far least, sky none). But **ruling 10's
expectation fails on x**: tilting the right edge down moves the near planes to the **right**, not
to the left. Not changed here: a flip is not a one-liner. `parallaxX` +1 is defined by the scene
files (near planes right), the pointer path feeds the same number (pointer right also moves the near
planes right), and three tests plus the class doc encode "right edge down gives +x". Whichever way it
is settled (negate the tilt x in `ParallaxSource._onAccel`, or flip the sign in the plane bindings
so the pointer follows too), decide it once for both inputs. The y sign (top away: near planes down)
had no expectation in the ruling; it moves the scene the way a camera pitched up would.

## Not measured

- A real mid-tier phone: GPU, memory bandwidth, CPU clocks, the thermal state. Nothing here is a
  tier number; the quality-tier probe still decides on the device.
- Battery and thermal over time (10 s per scene, a cold run each).
- A speaking avatar, a running chat and the tablet or newspaper prop; the avatar was idle.
- Debug and release modes (profile only), and iOS.
- A physical sensor: the emulator's accelerometer is a clean step input, with none of a hand's
  noise; the low-pass and rest re-centring are covered by `parallax_source_test.dart`.
