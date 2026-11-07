# Yofardev AI — portfolio film

`out/yofardev-ai-film.mp4`: 1920×1080, 60 fps, H.264 + AAC 320k, about 2 min.

Every frame of the app in the film is the real macOS app (debug build, ultra
tier) driven by the scripted capture harness and recorded at 60 fps by a
screen capture of its window. The voice is the app's own on-device Kokoro
(`am_michael`) speaking through the production TTS pipeline, so the lips match
the audio by construction. No LLM or network is involved: replies, the weather
and the news are scripted (`FakeLlmService`, canned tools).

## Pipeline

| Step | Tool | Output |
|---|---|---|
| Capture (display 2 free, ~35 min) | `capture_all.sh` → `capture.sh` (ffmpeg avfoundation 60 fps + `integration_test/wow_capture_test.dart`, `WOW=film_*`/`wow*`/`tour`/`scene`) | `work/cap/<tag>.mov` + timeline, Kokoro WAVs |
| Sync | `tools/sync.py` (finds the window and the clock offset by matching the harness's sparse in-app grabs, ±17 ms) | `work/clips/<tag>.mp4` (574×1020, 60 fps) |
| Sound per run | `tools/runaudio.py` | `<tag>_voice.wav`, `<tag>_foley.wav` |
| Event index | `tools/events.py` | `video/src/data/events.json` |
| Edit | Remotion (`video/`): every cut hangs on run events (`src/plans.ts`), sections round to bars (`src/sections.ts`) | |
| Score | `music/compose.py` (D major, 96 BPM, one bar = 2.5 s, built from `sections.json`; fluidsynth + MuseScore_General) → `music/mix.py` | `music/score.wav` |
| Mix | `tools/mixfilm.py` (score ducked under the voice, the app's foley and beds, designed whooshes/booms/risers, typing ticks; -14 LUFS) | `work/soundtrack.wav` |
| Render + mux | `build.sh` | `out/yofardev-ai-film.mp4` |

```bash
film/capture_all.sh        # only with the second display free (and awake)
film/build.sh              # sync + index + score + mix + render + mux
film/build.sh render       # after an edit-only change
cd film/video && npx remotion studio   # preview / tweak the edit
```

## Swapping the music

`music/score.wav` is the only music input. A replacement must follow the
section map in `music/sections.json` (96 BPM, 2.5 s bars): soft intro
0–10 s, hit at 10 s (title), light groove through the conversation, a build
over the journey, the climax over the world montage, a short breakdown (under
the hood), and a resolve on the end card. Drop it in as `music/score.wav`
(48 kHz) and run `film/build.sh render` without the compose/mix steps (or just
rerun `tools/mixfilm.py` and the mux).

A Suno prompt that fits: *"whimsical cinematic storybook score, 96 BPM, D
major, celesta and music box intro, warm felt piano, pizzicato strings, flute
melody, gentle shakers, big orchestral swell with strings and horns at 1:20,
soft music box breakdown, warm resolve, instrumental, no vocals"*.

## Notes

- macOS stops rendering a covered window and the app stalls, and a sleeping
  display has no capture device: the capture keeps the display awake and
  needs the second screen free.
- `scene` runs, `tour`, `wow1`, `wow3` reuse the M9–M15 wow scripts with
  `FILM_OUTFIT=true` (the hoodie in every shot). The film scripts are
  `film_hello`, `film_wardrobe`, `film_goodnight`.
