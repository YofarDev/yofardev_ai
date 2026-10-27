# Baseline before the 4.0 UI redesign (2026-10-26)

Captured from `main` at `16f3fb4` **plus the uncommitted working tree** (36 modified files
at the time). Profile mode. Tool: [`scripts/perf`](../../../scripts/perf/README.md).

| File | What |
|---|---|
| `01-home.jpg` | macOS, Home (livingRoom scene) |
| `02-history.jpg` | macOS, chat list |
| `03-chat-detail.jpg` | macOS, chat detail |
| `04-settings.jpg` | macOS, settings |
| `android-01-home.png` | Android emulator, Home, after granting the mic permission |

## Frame timings

| Run | Frames/s | build p50 / p99 | raster p50 / p99 | Notes |
|---|---|---|---|---|
| macOS M-series, Home idle (75 Hz display) | 75 | 0.7 / 1.5 ms | 1.7 / 3.2 ms | ~14-23 % CPU, 129-176 MB |
| macOS, history list (AX scroll jumps, not a real fling) | 6 | 0.2 / 2.3 ms | 2.5 / 11.4 ms | not representative of scrolling |
| Android emulator arm64, 2 cores, 2 GB, **software GPU** (swiftshader) | 1-4 | 700 / 870 ms | 760 / 870 ms | unusable; software rasterization of the Rive vectors |
| Android emulator arm64, 2 cores, 2 GB, **host GPU** | 57 | 4.8 / 17.6 ms | 14.0 / 23.4 ms | 522 of 570 frames over 16.7 ms; app drawn with the avatar only (see below) |

**Reading:** macOS tells us nothing about low-end Android. The host-GPU emulator is the
only usable Android number and is already at the edge of a 60 fps budget on *idle Home*
(raster p50 14 ms), before any glass or sheet is added. The redesign has to **reduce**
raster cost on Home, not just hold it. A real low-end phone is still needed before the M3
gate; the emulator is a relative yardstick only.

### M3 Stage (2026-10-27, same host-GPU emulator, profile, Home idle, 12 s)

| Build | Frames/s | build p50 / p99 | raster p50 / p99 | Notes |
|---|---|---|---|---|
| Stage, UI-kit artboards always running | 54 | 10.4 / 24.4 ms | 8.6 / 17.5 ms | scene + avatar + orb + glow; 572 of 650 frames over 16.7 ms |
| Stage, artboards paused once settled (`27c98bd`) | 59.8 | 6.9 / 11.4 ms | 3.6 / 15.1 ms | same scene; 242 of 718 frames over 16.7 ms |

The Stage now draws the scene too (the M0 run drew the avatar only), and still beats the M0
numbers once static UI-kit artboards stop advancing. Not measured: thinking/speaking states
(this emulator has no LLM configuration and no Supertonic models, so no reply plays).

## Findings that are not in the redesign plan yet

1. **Android: scene not visible.** On the Android emulator the Home background is flat dark
   navy; only the avatar renders. macOS shows the livingRoom scene. No Rive error in the log.
   Unverified on a device, could be an emulator rendering limit. Check first on a real phone.
2. **Android: composer sits behind the system nav bar.** `HomeContentStack` positions it at
   `bottom: 16` with no bottom safe-area inset; with 3-button navigation it is half covered.
3. **Mic permission is requested at launch**, on the first frame, with no context
   (`AiTextInput._initSpeechToText` from `initState`). Move to first mic tap (M3/M6).
4. **Android 16 KB page size warning** on launch: `librive_native.so`, `libapp.so`,
   `libonnxruntime.so`, `libamplituda` and `libavformat` are not 16 KB aligned. Play Store
   requires 16 KB support for updates targeting Android 15+. A release blocker for 4.0,
   unrelated to UI. Needs its own ticket (plugin updates / NDK / AGP).
5. **macOS Home composer is almost invisible**: translucent glass over a busy scene, no
   placeholder text, no visible affordance. (Android shows the same: only a faint outline.)
6. **Supertonic TTS failed to initialize** on the emulator (log: `Failed to initialize
   SupertonicTTS`). Expected on emulator; not a UI issue, noted because it affects the
   speaking-state baseline.
7. The history cards read `2 messages` in a French UI (hard-coded English; plan item C6).
8. **The chat detail screen already has a date separator** ("dimanche 15 mars 2026 - 15:07").
   Plan item C2 said there were none; corrected there.

## Test and analyze status on `main` + working tree

- `flutter analyze --no-pub`: clean.
- `flutter test`: **523 passed, 71 failed**, so `fverify.sh` is red before M0 starts.
  - 31 `talking_cubit_test.dart` and 4 `new_chat_animation_test.dart`: mock streams return
    `null` (`type 'Null' is not a subtype of type 'Stream<…>'`), consistent with the
    uncommitted chat/stream changes.
  - 31 golden tests (`modern_chat_bubble*`, `chat_screen`, `shimmer_loading`): tiny pixel
    diffs (e.g. 0.01 %, 558 px). Goldens were last committed in `b0c69d8` "pre-refactor".
  - 2 `avatar_animation_service_test`, 2 `function_calling_config_screen_test`, 1
    `chats_list_screen_test`.
