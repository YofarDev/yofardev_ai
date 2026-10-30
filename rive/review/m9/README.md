# Moonshot M9 review index

One row per evidence set (M9 plan ruling 17, as M4–M8: no critic rounds, one render, one cheap
Sonnet defect-only pass over every sheet: 0 blocker, 1 should-fix (fixed), 12 notes kept for the
owner). The plan and every ruling:
[2026-10-31-moonshot-m9.md](../../../docs/superpowers/plans/2026-10-31-moonshot-m9.md).

**Exit gate of the M7–M9 quarter (vision §6):** Wow #3 works in the app (20/20 gates) and journeys
run between all seven scenes: `WOW=pairs` drove every one of the 42 ordered pairs once in the macOS
app, each in its ruled family, the destination drawn after every cut (11/11 gates).

## Budgets

| File | M8 (`6639d3c`) | M9 | Budget |
|---|---:|---:|---:|
| `avatar.riv` | 564,776 | 564,776 (untouched) | 614,400 |
| `journeys/journey.riv` | 22,364 | 22,364 (no new threshold) | 163,840 |
| `scenes/livingRoom.riv` | 139,180 | 143,411 | 409,600 |
| `scenes/campfire.riv` | 249,842 | 252,491 | 409,600 |
| `scenes/beach.riv` | 285,130 | 304,870 | 409,600 |
| `scenes/deepSpace.riv` | 74,588 | 79,151 | 409,600 |
| `scenes/cafe.riv` | — | 125,039 | 409,600 |
| `scenes/rooftop.riv` | — | 154,732 | 409,600 |
| `scenes/mountainHut.riv` | — | 116,612 | 409,600 |
| posters (7) | 4 × ≤ 31,228 | cafe 30,156, rooftop 22,386, mountainHut 30,940; livingRoom 26,636 and campfire 19,442 (the new cord / stick) | 40,960 each |
| `assets/foley/` (12 WAVs) | 786,788 | 830,932 (+ `bell_0.wav` 44,144) | 921,600 |

Seven scenes total 1,176,306 B, bundled and lazily loaded (ruling 2).

## Evidence

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **Journeys between all seven scenes, in the app** (exit gate, ruling 5) | `WOW=pairs`: an Eulerian circuit of the seven scenes from the living room, 42 journeys back to back, no speech | [pairs.gif](wow/pairs.gif) (0.5 fps), [pairs.mp4](wow/pairs.mp4) (4× silent), [beats](wow/pairs_beats.png), [gates](wow/pairs_gates.txt) | 11/11: 42/42 pairs once, family per ruling 5 42/42 (28 door, 2 path, 6 portal, 6 rocket), beats in order, the destination file drawn after the cut (never before `close`), 28 door journeys with one jacket in all 7,765 samples, 937 frames none blank, mean journey 9.79 s, 0 network | Frames at 2 fps: some arrival cells show the frame before the avatar steps in (the gates read the 33 ms samples) |
| **Wow #3, re-shot** (quarterly, ruling 20) | Living room at sunset → "Can we go to the beach?" → the door, the jacket grab, the walk out, the cut, the walk in, the hang | [wow3.mp4](wow/wow3.mp4), [gif](wow/wow3.gif), [beats](wow/wow3_beats.png), [gates](wow/wow3_gates.txt) | 20/20 (M8's 19 + the blank-frame gate): 6 + 6 steps, cloth [1, 1], journey 7.67 s | As M8 |
| **Wow #1, #2, re-shot** | Campfire in the rain (breath, p/b/m closures, question brows, steam); "What's the weather in Tokyo?" (tablet, card 18 °C rain) | [wow1](wow/wow1.mp4) [gates](wow/wow1_gates.txt), [wow2](wow/wow2.mp4) [gates](wow/wow2_gates.txt) | 11/11, 12/12 | `say` is not the app's voice |
| **The December tour** (rulings 12–13, 20) | `WOW=tour7`: livingRoom → cafe → rooftop → mountainHut → campfire → beach → deepSpace → livingRoom on a pinned Christmas Eve, 22:00 | [tour7.mp4](wow/tour7.mp4), [gif](wow/tour7.gif), [beats](wow/tour7_beats.png), [gates](wow/tour7_gates.txt) | 47/47: moon phase 0.522 written and read back from all five moon scenes' files, festive 1 read back from the three indoor files, santaHat + christmasSweater in every sample, seven journeys in their families | The beach keeps its sunset art at 22:00 (by contract: at daylight / dusk 0 a scene looks as before v10) |
| **One run per scene: NPC + drag, in the app** (rulings 8–11, 20) | `WOW=scene SCENE=<id>`: poke the scene's NPC, drag its prop with a synthesised finger, one scripted line. livingRoom cat + cord (`lightsOff`), campfire owl + poke (a fast stir flares), beach gulls (land, poked, fly off) + crab + sand, deepSpace alien + spin, cafe fish + wipe (mists back after 20 s), rooftop pigeon + telescope, mountainHut dog + bell rope (`bell` + its sound) | `wow/scene_<id>.{mp4,gif}`, `_beats.png`, `_gates.txt` | 14–17 gates each, all ok; NPC reacts in 3–27 ms; every drag read back from the scene file's own view model; drag haptics logged (4–17 per run) | The orange crosshair is the test framework's finger marker. The café wipe reads as a dark streak on the mist (darken blend), owner's call |
| **Scenes 5–7** (Tasks 3a–c, rulings 1, 3, 11) | cafe, rooftop, mountainHut: contact sheets (rest, rain / snow, noon, dusk, fog, events at peak, NPC states, drag, moon phases, festive, parallax) | [cafe](scenes/cafe/), [rooftop](scenes/rooftop/), [mountainHut](scenes/mountainHut/) | Every `review_diorama` / `review_time` / `review_npc` / `check_contract --strict-binds` gate ok; Sonnet: the sleeping dog sat inside the avatar's band (moved, should-fix); notes kept (see `rive/CRITIC_ITERATIONS.md` § M9) | The new scenes skip `scene_art.refine_scene` (it knows only the four M8 scenes) |
| **Drags in the four M8 scenes** (Task 4, ruling 8) | The lamp cord (visible at rest), the campfire poke stick (lying left of the fire), the sand trail, the planet spin | [drags](drags/) | Each number changes pixels only in its handle's box; identity to M8 outside the cord / stick boxes 0.00 % | The planet spin shows a faint 4–7 px seam travelling across the disc |
| **Gulls** (ruling 10) | The beach's second NPC slot: rest, idle, flight path, notice, react | [states](gulls/states.png), [path](gulls/path.png) | `away` draws nothing, npc2X 1 is off the frame, seams ≤ 0.03 % | — |
| **Moon phase** (ruling 12) | Eight phases in livingRoom, campfire (and each new scene's sheet); the kit sheet | [moon](moon/), [world_kit](world_kit/) | −1 and 0.5 identical to the M8 moons; a bright limb hairline fixed (dark side 0.6 px wider) | The phase is the mean synodic month (≤ 1 day off) |
| **December** (ruling 13) | festive 0 / 1 in livingRoom (string lights), cafe (lights + wreath), mountainHut (garland + stocking); the avatar's December outfit in tour7 | [festive](festive/), the scene sheets, tour7 | festive 0 identical to M8 | `lightsOff` dims the festive lights with the moon |
| **Contract on the real runtime** (Task 8a) | `integration_test/rive_contract_test.dart -d macos`: 43 tests | — | the v12 members and defaults in all 7 scenes; posters; every propId found by tapping a grid over each real scene; one real drag per handle; the darken wipe renders; the avatar over the scene: head / body taps claimed, scene props and the cord reachable through the avatar | It found the M8-era bug that the avatar layer swallowed every pointer over its frame (fixed: `AvatarZoneHitGate`) |

## How to regenerate

```
./scripts/frive.sh                       # FRIVE_GATES=all adds the prop gates
uv run --with pillow --with numpy rive/tools/review_diorama.py <sceneId>
uv run --with pillow --with numpy rive/review/m9/make_lane_e.py drags|gulls|moon|festive
flutter test integration_test/rive_contract_test.dart -d macos
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=scene --dart-define=SCENE=<id>   # or pairs, tour7, wow1..3
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/<run> rive/review/m9/wow
```

## Not verified

- The owner's mid-tier phone run (M6's, `../m6/device/README.md`) is still open: nothing in M9
  measured the three new scenes, the drags, the gulls or the moon rig on a device or an emulator; no
  frame-cost JSON was captured in M9.
- Drag feel and haptics on a real touch screen (the drags were proven with synthesised pointers on
  macOS); the bell and the other generated sounds by ear.
- On macOS an unfocused window pauses Rive's pointer handling (pre-existing; the tests pin the app
  to resumed).
