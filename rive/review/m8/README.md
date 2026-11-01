# Moonshot M8 review index

One row per evidence set (M8 plan ruling 15, as M4–M7: no critic rounds, one render, one cheap
Sonnet defect-only pass). The plan and every ruling:
[2026-10-31-moonshot-m8.md](../../../docs/superpowers/plans/2026-10-31-moonshot-m8.md).

## Budgets

| File | M7 (`927a606`) | M8 | Budget |
|---|---:|---:|---:|
| `avatar.riv` | 574,335 | **564,776** | 614,400 (M8 target ≤ 590,000) |
| `journeys/journey.riv` | 20,743 | 22,364 | 163,840 |
| `scenes/livingRoom.riv` | 112,956 | 139,180 | 409,600 |
| `scenes/campfire.riv` | 244,332 | 249,842 | 409,600 |
| `scenes/beach.riv` | 273,373 | 285,130 | 409,600 |
| `scenes/deepSpace.riv` | 67,125 | 74,588 | 409,600 |
| `assets/foley/` (11 WAVs) | — | 786,788 | 921,600 (ruling 11) |

The avatar shrank although it gained 12 hand poses, three gestures, the jacket, foley events and the
tablet's weather card: the `back` hand pose was a byte-for-byte copy of `rest` in every skin and
side (−26,329 B). Step by step: [budget.md](budget.md). Posters and the UI kit are unchanged.

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **Wow #3 with the jacket, in the app** (Task 8, rulings 5–6, 18) | The running macOS app at the pinned local sunset: "Can we go to the beach?"; the camera pulls back, the door appears with the ochre jacket on its peg, the avatar reaches and takes it (cloth sound at the contact), walks out holding it (six footsteps), the cut lands on the beach door, it walks in (six footsteps), hangs the jacket back on the peg (cloth), the door closes and vanishes with the jacket | [wow3.mp4](wow/wow3.mp4) (`say` + foley mixed at their logged times), [wow3.gif](wow/wow3.gif), [beats](wow/wow3_beats.png), [gates](wow/wow3_gates.txt), [frame cost](wow/wow3_frame_cost.json) | 19/19 gates ok on the first run: beats pullBack → open → grab → exit → close → arriveOpen → enter → hang → arriveClose → vanish; one jacket at a time in all 205 shown samples; jacket in hand on both walks (98/98); 6 + 6 steps; one cloth per contact; the jacket leaves with the door; 0 network. Journey 7.7 s. Frame cost (macOS debug, not a tier): build P95 7.8 ms, raster P95 1.2 ms. Sonnet (beats + 24-frame sheets of the three GIFs): no two jackets, no old scene after the cut, no blank stretch; flagged the caption cross-fade overprinting two sentences for 1–2 frames (the app's transition since M6, kept), the jacket "vanishing" as the walk out starts (the hand crosses the threshold first and is clipped: intended), a faint arch ghost as the door vanishes (M7's 300 ms fade at 8 fps) | The reply arrives in one piece, so "Let me grab my jacket" is spoken during the walk, after the grab; at rest the held jacket is below the phone frame (ruling 23), so it reads mostly at the reach and the walks; the jacket is small at the wide shot; `say` is not the app's voice |
| **The cat's behaviour tree, in the app** (Task 8, `WOW=npc`, rulings 8–9) | Living room, no journey: the cat asleep on the cabinet; a poke (the cat's prop tap) → react, then notice; the user asks "Is your cat awake?" → notice / react; the sad reply → the cat walks down from the cabinet to the rug beside the avatar and sits | [npc.mp4](wow/npc.mp4), [npc.gif](wow/npc.gif), [beats](wow/npc_beats.png), [gates](wow/npc_gates.txt) | 9/9 gates ok: react 28 ms after the tap; notice on the name; move for 228 samples, `npcX` reaches 1.00; largest `npcX` step between 33 ms samples 0.015; states rest / react / notice / idle / notice / react / move / idle | In the medium shot the cat on the rug sits partly behind the avatar's shoulder; the tap is the director's `poke` (the same call the prop tap makes), not a synthesised pointer |
| **Tokyo on the tablet** (Task 8, ruling 14; Wow #2 re-shot) | "What's the weather in Tokyo?": the tablet comes out, and when the canned report lands its card shows the rain glyph and 18°; the tablet goes away and the avatar answers | [wow2.mp4](wow/wow2.mp4), [wow2.gif](wow/wow2.gif), [beats](wow/wow2_beats.png) (beat 4b), [gates](wow/wow2_gates.txt) | M6's gates plus "Tokyo on the tablet: rain 18 °C in 45 samples, 0 wrong". The first run showed the card for 390 ms only (the report lands as the tool ends and the 400 ms hold-over put it away): fixed by holding a weather card 1.5 s (execution ruling 32) | No city name on the screen (no font in the avatar, ruling 14) |
| **Hands** (Task 2, rulings 2–4) | 12 poses (rest, palm, edge, point, up, fist, grip, pinch, thumbsUp, one, two, three) per skin (bare, black glove, metal, stars, white glove), both sides; 8-frame strips of `thumbsUp`, `count`, `grab` | [bare](hands/poses_bare.png), [black](hands/poses_black.png), [metal](hands/poses_metal.png), [stars](hands/poses_stars.png), [white](hands/poses_white.png), [thumbsUp](hands/thumbsUp_strip.png), [count](hands/count_strip.png), [grab](hands/grab_strip.png), [gates](hands/gates.txt) | Rest frames (advance 1 and 60) and the held tablet pixel-identical to M7; grab grip 0.42 px from the hook at contact. Sonnet: glove knuckle chevrons over the curled thumb (fixed: thumb pivot in front), the `up` pose's glove seams past its shorter fingers (an M7 defect, fixed), evidence crop / labels (fixed) | Glove seams sit off-centre on the fingers (the M7 rest drawing); curls are the cartoon front view (fingers shorten), not modelled knuckles; the gestures have no hair / cloth follow-through (bytes, ruling 22) |
| **Jacket handoff** (Task 3, ruling 5) | The grab and hang with the journey door composited: the avatar's held jacket meets the peg's copy at the contact | [grab](jacket/grab_strip.png), [hang](jacket/hang_strip.png), [contact](jacket/contact.png), [gates](jacket/gates.txt) | Both copies within 1 px at the contact; the door at `jacket` 0 identical to M7 outside the peg's box; `review_journey.py` 14/14. Sonnet: the coat's edge under the door jamb (moved 18 px left) | Breathing can offset the held copy a few px against the fixed peg; the fist passes behind the jamb after the tug (the door stands in front) |
| **Tablet weather card** (Task 3, ruling 14) | Six glyphs at three temperatures each, and a digits run −40…50 | [glyphs](tablet/glyphs.png), [digits](tablet/digits.png) | Every readout decodes; `none` keeps the M4 card pixel-identical. Sonnet: the glyph sat under the left thumb (card moved right) | Readout clamps at ±99; no leading zero |
| **NPC states** (Task 4, rulings 7–8) | Per scene: rest, idle, move along the path (npcX 0 / 0.5 / 1), notice (npcLook −1 / 0 / +1), react, away; 2× crops; the path strip | [livingRoom](npc/livingRoom/), [campfire](npc/campfire/), [beach](npc/beach/), [deepSpace](npc/deepSpace/) (`sheet.png`, `crop2x.png`, `path.png`, `gates.txt`) | Rest frames f0 / f1 / f30 / f60 identical to M7 in every scene; each state moves and loops seamlessly; the hit zones follow `npcX` (pointer proofs). Sonnet: no defect left (kept: the cat mid-air in its hop down, the 200 ms state cross-fade, the crab overlapping the gull post's base at the same depth) | The cat walks 7.5 s from cabinet to rug (no foot slide); the owl has no path (its move is a shuffle); away keeps the hit zones live |
| **Fog** (Task 4, ruling 13) | fog 0 / 0.5 / 1 per scene; campfire and beach also at rain 1 + fog 1 with `SceneFront` | [livingRoom](fog/livingRoom.png), [campfire](fog/campfire.png), [beach](fog/beach.png), [deepSpace](fog/deepSpace.png) | fog 0 identical to M7; the living room's fog only through the window; deepSpace 0 px change | The front mist shows only while it rains (the app creates `SceneFront` only at rain > 0) |
| **Foley and haptics** (Tasks 3, 7, rulings 10–12) | The avatar's `foley` events (step ×6 per walk, cloth at the grab contact, click on the tablet's grip / release, paper on the newspaper) drive generated sounds; prop taps fire a selection haptic, the tablet click a light impact; crackle and rain beds follow the scene | the audio in [wow3.mp4](wow/wow3.mp4); `rive/tools/gen_foley.py` → `assets/foley/`; the macOS contract test proves a step event reaches Dart during the walk-out | `test_gen_foley.py` (38: lengths, peaks ≤ −1 dBFS, seams, budget, determinism); service tests with fake players / haptics (rate limit, setting off, pause, bed volumes, flare swell, duck, cross-fade) | Nobody has listened to the sounds (numeric checks only); haptics untested on a device; no drag haptics (no draggable prop yet: M9) |

## How to regenerate

```
uv run --with pillow --with numpy rive/tools/review_hands.py
uv run --with pillow --with numpy rive/tools/review_jacket_tablet.py
uv run --with pillow --with numpy rive/tools/review_npc.py
uv run --with numpy rive/tools/gen_foley.py
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow3   # or npc, wow2
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/wow3 rive/review/m8/wow
```

## Not verified

- The owner's mid-tier phone run (M6's, `../m6/device/README.md`) is still open; nothing in M8
  measured the NPC loops, the beds or the hands on a device or an emulator.
- Haptics and the low-latency foley players on Android; the sounds' quality by ear.
- The owl, crab and alien trees in the app (unit-tested; only the cat was captured).
- `FRIVE_GATES=all` ran at close-out: the tablet and newspaper prop gates pass (IK within 2 px,
  hold seams ≤ 1/255) after a gate-tool fix (`ik_check.marker_copy`, execution ruling 34).
