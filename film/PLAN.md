# Yofardev AI — portfolio film

16:9, 1920×1080, 60 fps, 122.5 s. Every frame of the app is the real macOS
app (debug build, ultra tier) recorded at 60 fps by a screen capture of its
window; the voice is the app's own on-device Kokoro (`am_michael`); the
score is original (composed in `music/compose.py`, rendered with fluidsynth +
MuseScore_General, mastered with pedalboard) and cut to the picture: 96 BPM,
one bar = 2.5 s = 150 frames.

## Concept

"Most AI assistants live in a text box. This one has a home." The film is one
evening with the avatar, in the app's own storybook-night look (ink
`#16121D`, Fraunces + Manrope, scene accents): it listens, it talks, it does
things, it dresses up, it takes you places, its world is alive, it is built
properly, it says goodnight.

## Beats (as cut: 49 bars, 122.5 s)

| Bars | Section | Footage |
|---|---|---|
| 1–4 | Cold open: "Most AI assistants live in a text box." The box types, swells into the phone: "This one has a *home*." | `film_hello` idle (cat poked) |
| 5–6 | Title hit: Yofardev AI, light streak | `film_hello`, blurred |
| 7–11 | It listens (gaze on the caret, lean) · it talks (wave, voice, lip-sync callouts) | `film_hello` turn 1 |
| 12–20 | Real tools, acted out: Tokyo weather (tablet), the news (paper); typing at 1.8× | `film_hello` turns 2–3 |
| 21–26 | It dresses up: four dimmed empty rooms light up one by one as each costume walks in, speaks (Batman and RoboCop through their voice effects) and does its signature move | `film_wardrobe` |
| 27–32 | Ask for the beach, go there: the pop-up book | `wow3` |
| 33–40 | The world: ten scenes, residents, four thresholds, drags, weather/clock | `scene` ×10, `tour`, `wow1`, `wow3`, `film_goodnight` |
| 41–43 | Under the hood: numbers, stack, the real source scrolling behind | — |
| 44–49 | Goodnight on the beach, end card on the last chord | `film_goodnight` |

## Swapping the music

`music/score.wav` is the only music input (`tools/mixfilm.py` reads it). A
replacement follows `music/sections.json`: 96 BPM, 2.5 s bars, soft intro
0–10 s, hit at 10 s, light groove 15–65 s, build 65–80 s, climax 80–100 s,
breakdown 100–107.5 s, resolve with the last chord at ~115 s. See README.md.
