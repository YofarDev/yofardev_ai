# Showcase video (November 2026)

A 35-second vertical showcase of Yofardev AI, cut from real captures of the
macOS app. Everything on screen is the app's own rendering (Rive avatar,
scenes, stage camera, speech bubbles, composer); the voice is the app's
actual on-device Kokoro engine, speaking the scripted lines through the
production TTS pipeline (same engine, normalisation, lip-sync analysis and
playback path as a real conversation).

| File | What |
| --- | --- |
| `showcase-vertical.mp4` | 1080×1920, 30 fps, H.264 + AAC, fast-start (~35 s) |
| `showcase-captions.srt` | the dialogue, timed to the final cut |
| `showcase-poster.png` | representative frame (the weather answer) |
| `render_showcase.py` | the reproducible render script |

## The cut

| Time | Shot | Source run |
| --- | --- | --- |
| 0.0–3.4 | Hook: wave + greeting, overlay "An AI with a little more life." | `show_hook` |
| 3.4–6.7 | Weather request: tool chip, head turn, tablet out — dissolve — | `show_weather` |
| 6.7–10.4 | the answer with Tokyo on the tablet, overlay "Real tools. Real character." | `show_weather` |
| 10.4–15.0 | "Can we go to the beach?" → door journey out (grab, exit, close) | `show_journey` |
| 15.0–20.4 | arrival on the sunset beach (walk in, hang, "Here we are…") | `show_journey` |
| 20.4–22.6 | rainy campfire at night, the owl — overlay "A world that moves with you." | `show_campfire` |
| 22.6–24.3 | train compartment, the landscape scrolling | `show_train` |
| 24.3–25.7 | deep space, the star drag | `show_space` |
| 25.7–31.1 | the finish at dusk: "Me too. Soon the moon will take the sun's place." | `show_finish` |
| 31.1–35.0 | end card (ink, Fraunces/Manrope, repo + Ko-fi) | rendered |

## How it was captured

Scripted runs of the real app on macOS (debug build), one `flutter test` per
beat — the same harness as the M6–M12 wows, with two showcase additions
(`VOICE=kokoro`, `SHOW_OUT`/`WIN_POS`/`WIN_SIZE`/`PXR`, see
`integration_test/wow_capture_test.dart`):

```bash
# park the window on a free screen corner first (a covered window stops
# rendering on macOS); the capture writes into showcase/work/out/mac/wow/
flutter test integration_test/wow_capture_test.dart -d macos \
  --dart-define=WOW=show_hook --dart-define=TIER=ultra \
  --dart-define=VOICE=kokoro --dart-define=PXR=1.96721 \
  "--dart-define=WIN_POS={1940,40}" "--dart-define=WIN_SIZE={549,1008}" \
  "--dart-define=KOKORO_SRC=$HOME/Library/Application Support/fr.yofardev.yofardevAi/tts" \
  "--dart-define=SHOW_OUT=$PWD/showcase/work/out/mac"
# …then show_weather, show_journey, show_campfire, show_train, show_space,
#    show_finish (or just ./showcase/work/capture_mac.sh)
```

- **No network**: the harness refuses every socket and counts attempts
  (`network_attempts` is 0 in every run). The reply, the weather report and
  the title are scripted (`FakeLlmService` + a canned weather tool); chats,
  configs and keys live in in-memory preferences and never touch real data.
- **Voice**: `VOICE=kokoro` swaps the capture stand-in (`say`) for the app's
  real speech pipeline — `KokoroTtsDatasource` (sherpa-onnx, the installed
  `kokoro-int8-multi-lang-v1_0` model, English `af_heart`). Lip sync, the
  breath preroll and the speech bubbles come from the same WAVs, so the
  mouth matches the audio by construction. Each sentence's WAV is kept in
  the run's `audio/` for the mux.
- **Resolution**: the window content is 549×976 logical (aspect 9:16);
  `PXR=1.96721` grabs the render view at exactly **1080×1920** per frame.
  The Rive textures are sized by the app's `RenderResolution.layout`
  (layout × device pixel ratio × the stage camera's scale), so wide shots
  render from ~549 px-wide textures and close-ups from ~1098 px ones —
  the honest ceiling of this 1080p (non-retina) capture display.
  Capture runs at ~30 fps effective (VFR, timestamps recorded per frame).

## How it is assembled

```bash
uv run --with pillow --with numpy showcase/render_showcase.py
```

The script reads each run's `timeline.json` + raw frames + sentence WAVs,
hangs every shot on the run's own events (send, captions, journey phases,
the drag), resamples nearest-earlier onto the 30 fps grid (no interpolation
is invented), and writes the MP4, the SRT and the poster. Audio is mixed in
numpy: the Kokoro sentence WAVs at their captured offsets, the app's foley
assets at their logged times, and the ambient beds at the app's own levels
(`AmbientBedService`: crackle 0.072, outdoors rain 0.10, beach wind 0.048),
ducked to half while the avatar speaks. No music. The end card is drawn
with the app's bundled fonts and palette.

## Limitations

- Wide/medium shots are upscaled from ~549/656 px-wide Rive textures
  (close-ups are native ~1098 px). The Android emulator renders 1080 px-wide
  textures but only reached ~14 fps in debug and mis-frames the stage at
  phone metrics, and an iPhone simulator with native 1206 px textures draws
  the avatar blank — both were tried and rejected for this cut; the macOS
  window path is the honest best.

## Rendering follow-ups (separate bugs, not showcase issues)

Two platform findings from the capture work reproduce outside this cut and
deserve their own investigation. Both show the *composited stage* drawn wrong
on mobile form factors while every Dart-side camera number is correct (the
`StageCameraView.frame` read back mid-run is exactly `StageFraming.of`'s
value, and the avatar/scene/camera boxes are all the full-stage box).

1. **Android: the stage is over-zoomed and top-left-shifted at phone
   metrics.** Reproduce with a custom AVD (1080×1920 @ 320 dpi, arm64,
   `system-images;android-34;google_apis`) booted headless
   (`emulator -avd <name> -no-window -gpu host`), then
   `flutter test integration_test/wow_capture_test.dart -d emulator-5554
   --dart-define=WOW=show_hook --dart-define=VOICE=kokoro --dart-define=PXR=2`.
   At the idle wide shot (camera identity) the scene and avatar render
   ~1.35–1.45× too large, anchored toward the top-left — as if a texture
   allocated for an earlier/smaller box were drawn scaled into the current
   one. macOS at the same code path composes correctly, including a
   pixel-ratio-2 grab of a dpr-1 window (verified); the failure only appears
   on real device-pixel ratios. First suspects: the rive texture
   reallocation on view resize (the emulator's Flutter view resizes once
   when the system bars settle) or the external-texture compositing of
   rive_native content on Android.

2. **iOS simulator: the avatar renders blank.** Reproduce on any booted
   iPhone simulator:
   `flutter test integration_test/wow_capture_test.dart -d <sim>
   --dart-define=WOW=show_hook --dart-define=VOICE=kokoro`. The scene files,
   chrome and speech pipeline all work; the avatar's Rive file is live (the
   `vmGesture` / `vmLean` read-backs through `AvatarFileReadBack` animate),
   but it draws no pixels, and launching the built app outside the harness
   white-screens. Scenes share the same `RiveWidget` path and render, which
   points at the avatar artboard's draw (skinned meshes / IK) on the
   simulator slice of rive_native, not at the framework wiring.

Fixing either would allow re-shooting this cut at native 1080 px-wide Rive
textures with the same showcase commands (`showcase/work/capture_emu.sh` is
a starting point for the emulator path).
- The captures are ~30 fps effective (VFR); the encode is CFR 30 with
  nearest-earlier frame selection, so no motion interpolation is added.
- The weather shot dissolves past the synthesis latency between the request
  and the spoken answer (the pipeline's real ~5 s round trip is shortened in
  the edit; nothing is fabricated — both halves are real app frames).
- The `show_finish` and `show_journey` runs log a teardown exception
  (a leftover `audioplayers` callback after the widget tree is disposed);
  the captured data is complete — the runs print `WOW_DIR` before it.

## Regenerating

Captures land in `showcase/work/out/mac/wow/<run>/` (raw frames are large,
~8 MB each; the git-ignored `work/` tree held ~26 GB for this cut). Keep
`timeline.json` + `audio/` and delete `frames/` to save space; re-run the
capture commands above to regenerate any beat, then re-run the render
script. The showcase scripts live in
`integration_test/wow_capture_test.dart` (`WOW=show_*`).
