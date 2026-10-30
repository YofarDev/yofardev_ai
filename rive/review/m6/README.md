# Moonshot M6 review index

One row per evidence set (M6 plan ruling 14, as M5 ruling 11: no critic rounds, one render, one
cheap self-check for objective defects). The plan and every ruling:
[2026-10-30-moonshot-m6.md](../../../docs/superpowers/plans/2026-10-30-moonshot-m6.md).

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **Wow #1 in the app** (Task 6, rulings 1–7) | The running macOS app on the campfire at rain 1: the user types "Can you tell me a story by the fire?" into the real composer, the avatar leans in, inhales, says three sentences dense in p/b/m with the app's own visemes (macOS `say` audio, the app's analysis), lifts its brows on the closing question, settles. Rain falls in front of the avatar (`SceneFront`) | [wow1.mp4](wow/wow1.mp4) (21 s, 15 fps, with sound), [wow1.gif](wow/wow1.gif) (8 fps, from the typing on), [beats](wow/wow1_beats.png), [gates](wow/wow1_gates.txt), [frame cost](wow/wow1_frame_cost.json) | All 11 gates ok: campfire at rain 1 in all 578 samples; lean 0.60 while typing; breath 1.0 in the 400 ms before the first audio; 11 lip closures for 9 p/b/m words; brows 1.84 in the question's last 600 ms; the front's rain mist darkens the avatar's hoodie to 0.952× of the dry frame (gate ≤ 0.97); 0 network attempts; 288 frames, none blank. Sonnet: no defect in the frames or the GIF (no frozen pair) | Close-ups are crops of the same frame (no camera); the caption cross-fade overprints two sentences for one frame (the app's own transition); beat 3's crop cuts the thinking bubble; `say` (Samantha) is not the app's Supertonic voice; world sync is stood in for by the harness (`setRain(1)`) |
| **Wow #2 in the app** (Task 6, rulings 1–7) | The running app in the living room: "What's the weather in Tokyo?" → the scripted LLM calls `getCurrentWeather`, a canned tool answers after 2.5 s; the head turns, the tablet comes out (tool chip "Checking the weather…", thinking bubble), the avatar glances back, puts the tablet away and answers with a nod | [wow2.mp4](wow/wow2.mp4), [wow2.gif](wow/wow2.gif), [beats](wow/wow2_beats.png), [gates](wow/wow2_gates.txt), [frame cost](wow/wow2_frame_cost.json) | All 9 gates ok: the tool ran 2,494 ms; tablet out in 100 % of its samples; head yaw 0.60 while it ran, 0.00 while answering; tablet away 1 s into the answer; 0 network attempts; 320 frames. Sonnet: no defect | The tablet screen shows placeholder glyphs, not the Tokyo data; beat 4's face crop leaves the tablet below the frame; the first sentence lip-synced from amplitudes in this run (its analysis was late under the frame grabber's load; the timing run analysed it, execution ruling 24) |
| **Rain in front of the avatar** (Tasks 1–3, rulings 8–9, contract v9) | `SceneFront` in campfire and beach: a near rain sheet (parallax gain 1.25), splashes at the bottom edge and a `lightFog` rain mist, all at opacity `rain`; composited over the scene at rain 0 / 0.5 / 1 and alone on grey | [campfire strip](front/campfire/front_strip.png), [beach strip](front/beach/front_strip.png), gates ([campfire](front/campfire/gates.txt), [beach](front/beach/gates.txt)) | Every gate ok in both scenes: dry front alpha 0; streak cover 1.52–1.56 %; bottom mist 0.19–0.22; travel ±50 px; loop seam 0 %; the `Scene` rest frames at rain 0 pixel-identical to M5 (`5911460`); all M5 diorama gates still ok. campfire 243,975 B, beach 273,016 B. Sonnet: no seam, no hard edge, aligned both sides | Streaks cross the face in close-ups (that is what near rain does; ruling worth overturning if it reads as a curtain); no front for livingRoom (indoors) or deepSpace; dry scenes have no fog in front (M5's veils stop at Plane2) |
| **Gates in `frive.sh`** (Task 4, ruling 10, execution ruling 28) | No visuals: `rive/tools/rive_gates.py` runs `review_diorama.py --gates-only` per built scene and, with `FRIVE_GATES=all`, `motion_review.py --gates-only` | `scripts/README.md`, `rive/tools/tests/test_rive_gates.py` | 110 gate lines ok on the committed files; a wrong parallax travel makes 6 pointer proofs fail and the script exit 1 | The prop gates (~23 min) are opt-in; the head fairing and the lint stay in pytest / `check_contract.py` |
| **Device budget** (Task 7, ruling 11) | Two emulator profile runs with M6 (campfire and beach at rain 1 now draw the front layer), and the owner's mid-tier command with pass thresholds | [device/README.md](device/README.md), [numbers](device/frame_cost_profile.json) | Raster P95 9.6–12.2 ms everywhere; rain 1 within each run's noise of the dry scene. Build P95 13.1–30.9 ms and 0.6–30.5 % of frames over 16.6 ms, swinging between back-to-back runs on a loaded host (execution ruling 30) | No conclusion on the budget from these runs; a quiet-host rerun and the mid-tier phone run are the owner's |
| **Mouth** (Task 8, ruling 13) | The M3 open list's two objective items, measured on M5 | [mouth/README.md](mouth/README.md) | Mouth line 0.6× the silhouette (gate ≤ 0.6×); tuck vs press at the f/v jaw 38.5/255 apart, teeth only in tuck: both pass, so no change (execution rulings 27, 29) | At a shut jaw tuck and press stay 8.1/255 apart (by design); the rest of the M3 list (oh/ou rings, th/dd/kk alike, sad visemes) is taste, not gated |

## How to regenerate

The captures (macOS, one at a time, the window unoccluded; about 1.5 min each):

```
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow1
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow2
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow1 --dart-define=CAPTURE=false
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow2 --dart-define=CAPTURE=false
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/wow1 rive/review/m6/wow
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/wow2 rive/review/m6/wow
```

The front layer: `uv run --with pillow --with numpy rive/tools/review_diorama.py <campfire|beach>
--out=rive/review/m6/front/<sceneId> --same-as=5911460` (then keep `front_strip.png` and
`gates.txt`). The gates alone: `./scripts/frive.sh` (or `FRIVE_GATES=all`).

## Not verified

- No mid-tier phone: the band's exit gate needs the owner's run (`device/README.md`).
- The app's own voice (Supertonic) cannot run on this Mac (its ONNX models are not in the repo);
  the captures speak with macOS `say`, and everything after the WAV is the app's.
- The captures' close-ups are crops; the app has no camera director yet (M7–M9).
- The macOS frame times in `wow/*_frame_cost.json` are a debug desktop build: informative, not a
  budget.
