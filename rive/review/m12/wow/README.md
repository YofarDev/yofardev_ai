# Moonshot M12: the final re-shoot of the three wows

These are the last shots of the three wows in the running macOS app, as M6 and M7 shot them (plan
rulings 10–12). The tier is forced to ultra. wow1 is pinned to 22:00. One extra wow1 at low is gates
only. There is no GIF. The harness has 0 network attempts, uses `FakeLlmService` with scripted
replies, a canned weather tool, macOS `say` and in-memory prefs. Each `*_then_now.webp` puts the
earlier beats sheet (wow1 and wow3 from M7, wow2 from M6) above the M12 one.

| Run | What it shows | Files | Gates | Known limits |
|---|---|---|---|---|
| **wow1** (ultra, campfire at night, rain 1) | "Can you tell me a story by the fire?": a wide shot, the listening lean, the inhale, three sentences dense in p/b/m (the third a question, with the `think` gesture to the chin), brows up on the question, the settle. The moon and owl are out, and the rain is drawn in front of the avatar | [wow1.mp4](wow1.mp4) (12.0 s, 12 fps, 486 px, with sound, 1.12 MB), [beats](wow1_beats.png), [then / now](wow1_then_now.webp), [gates](wow1_gates.txt), [frame cost](wow1_frame_cost.json) | All 12 ok. No frozen stretch (0 ms). 0 network. One camera cut, at a sentence start. Lean 0.60. Breath 1.00. 11 lip closures for 9 p/b/m words. Brows 1.83. Rain mist darkens the hoodie to **0.948** of dry (≤ 0.97, the same as M7's 0.948, so the M12 splashes do not change it). Frame cost (macOS debug): build P95 6.6 ms | `say` is not the app's voice. World sync is stood in for by the harness (`setRain(1)`, `pinClock`). Streaks cross the face (near rain, M6). The thinking bubble is cut at the medium shot's right edge (beat 3). Beat 5 is picked at the brows' peak, which is the `think` hand's release (it reaches the chin 15.4–16.2 s) |
| **wow1_low** (low, gates only) | The same moment at the low tier | [gates](wow1_low_gates.txt) | All 12 ok (the 12th, added after the review: the wet and dry grabs differ outside the avatar, 0.063 ≥ 0.02). Lean 0.60. Breath 1.00. 11 closures. Brows 1.84. **No front**: hoodie wet / dry 1.000 (want > 0.97). The first low run froze (below), so this is the re-run | No media, by ruling 12 |
| **wow2** (ultra, living room) | "What's the weather in Tokyo?": the tool runs, the head turns, the tablet comes out showing Tokyo (rain, 18 °C), the avatar glances back, puts the tablet away and answers with a nod | [wow2.mp4](wow2.mp4) (12.0 s, 0.63 MB), [beats](wow2_beats.png), [then / now](wow2_then_now.webp), [gates](wow2_gates.txt), [frame cost](wow2_frame_cost.json) | All 13 ok. No frozen stretch. 0 network. Tool 2,481 ms. Tablet out in 100 % of tool samples. Tokyo on the tablet in 46 samples, 0 wrong. Yaw 0.60 while the tool runs, 0.00 while answering. Tablet away 1 s into the answer. Build P95 5.9 ms | `say` voice. The prop-insert shot crops the crown of the head (beats 3–5). The thinking bubble covers the More chip during the tool. The fading thinking bubble still shows beside the first caption (beat 5, transient) |
| **wow3** (ultra, living room → beach at the local sunset) | "Can we go to the beach? I want to see the sunset.": the door journey with the jacket. Pull back, open, grab, exit, close, cut, arrive, enter, hang, close, vanish. It lands on the beach at dusk 1.0 | [wow3.mp4](wow3.mp4) (12.0 s, 0.63 MB), [beats](wow3_beats.png), [then / now](wow3_then_now.webp), [gates](wow3_gates.txt), [frame cost](wow3_frame_cost.json) | All 21 ok. No frozen stretch. 0 network. 1 journey, family door, beats in order. Camera wide 100 %. Avatar off screen only while clipped. The scene switches behind the closed door (the first beach sample is the cut). Dusk 1.00. One jacket at a time, in the hand on both walks. 6 + 6 footsteps. A cloth sound at each contact. The journey starts 0.04 s after the send and lasts 7.7 s. Build P95 7.4 ms | `say` voice. Speech plays during the walk, so "Let me grab my jacket." is heard after the grab (M7: the reply arrives in one piece). The living room stays storybook-night at the sunset pin, and only the beach sky follows the clock (M7) |

## Execution notes

- The first `WOW=wow1 TIER=low` run froze from 15.2 s to the end. 60 captures were byte-identical,
  because macOS stopped rendering the window. The face samples froze with it, so the question's
  brows read 0.30, which is the resting outer brow. That still passed the M6 gate (≥ 0.3).
  `wow_capture.py` now gates M12 final runs on frozen stretches: identical consecutive captures must
  stay under 500 ms. That run fails it at 1,848 ms. The re-run passes, and so do all three ultra runs
  (0 ms each).
- The timing runs (`CAPTURE=false`) ran at load average 3–4, a little higher than the capture runs
  (1.9–2.4). These are macOS debug numbers, not a tier.

## How to regenerate

```
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow1 --dart-define=TIER=ultra
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow2 --dart-define=TIER=ultra
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow3 --dart-define=TIER=ultra
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow1 --dart-define=TIER=low
# optional, for <wow>_frame_cost.json: the same three ultra runs with --dart-define=CAPTURE=false
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/<wow1|wow2|wow3|wow1_low> rive/review/m12/wow
uv run --with pillow rive/tools/wow_compare.py rive/review/m12/wow
```

Run them one at a time, with the window unoccluded. A run that fails the frozen-stretch gate is
re-run.
