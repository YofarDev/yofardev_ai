# Moonshot M12 review index, and the moonshot's final report

M12 is the last milestone of the Rive moonshot ([vision](../../../docs/superpowers/specs/2026-10-27-rive-moonshot-vision.md)).
It was run autonomously on one branch, as M4–M11 were: no critic rounds, one render per evidence set, one
cheap Sonnet defect-only pass. The owner judges at the end. The plan, rulings 1–23 and execution rulings
24 onward are in [2026-11-01-moonshot-m12.md](../../../docs/superpowers/plans/2026-11-01-moonshot-m12.md).

**M12's exit.**
- Contract v14 is unchanged; there was no new contract commit.
- The `SceneFront` splashes draw in the app and the CLI. A file bug had hidden them since M6.
- library and mountainHut's low tier now has margin.
- The NPC ghost blends are gone in seven NPCs.
- The bench of record is 20 / 20 gate lines ok.
- Frame cost is recorded per scene × tier on macOS.
- The three wows were re-shot in the app (all gates ok, 0 network).

The quarter's exit gate ("every tier passes its performance gate") is still the owner's to judge, on the
mid-tier phone ([device/README.md](device/README.md)). Neither the emulator nor macOS is a tier.

## Final gates

- `dart fix --apply` and `dart format .`: no changes.
- `./scripts/fverify.sh`: analyze clean, 2,647 tests green.
- pytest `rive/tools/tests`: 987 passed, 3 skipped.
- macOS `integration_test/rive_contract_test.dart`: 59 / 59.
- `FRIVE_GATES=all ./scripts/frive.sh`: 328 gate lines ok, 0 FAIL. Every asset rebuilt byte-identical to the committed files.
- Whole-branch Sonnet review: 0 high, 2 medium (both fixed in `62241c4`, with five lows).

## Evidence index

| Set | What | Where |
|---|---|---|
| Front layer | The splash file bug and its fix. The front's cost (two emulator regimes; render scale has no effect), with every experiment's numbers | [front/](front/README.md) |
| Low-tier margin | library and mountainHut ablation, the low lists, the bench gate retry | [bench/](bench/README.md) |
| Bench of record | CLI bench, 10 scenes × 3 tiers, load recorded | [perf/bench.md](perf/bench.md), [perf/bench.json](perf/bench.json) |
| Frame cost (macOS) | `frame_cost_test.dart`, profile, 10 scenes × 3 tiers + 4 rain scenes, 4 runs merged | [perf/frame_cost_macos.md](perf/frame_cost_macos.md), [perf/frame_cost_macos.jsonl](perf/frame_cost_macos.jsonl) |
| Polish | Ghost blends (7 NPCs), ladder, rooftop band, café wipe, birches / pole | [polish/](polish/README.md) |
| World sheets | 20 sheets (10 scenes × ultra / low) for the defect pass | [world/](world/README.md) |
| The three wows | MP4 with sound, beats, gates, then-vs-now sheets, frame cost | [wow/](wow/README.md) |
| The owner's phone | Steps for frame cost per tier, the front-layer repeat, battery, tilt | [device/README.md](device/README.md) |

Evidence added in M12: about 11 MB (cap 15 MB, no GIF).

## Budgets

| File | M11 (`2c3d11e`) | M12 | Budget |
|---|---:|---:|---:|
| `avatar.riv` | 488,418 | 488,418 (untouched) | 614,400 |
| `journeys/journey.riv` | 22,364 | 22,364 (untouched) | 163,840 |
| `scenes/livingRoom.riv` | 149,993 | 150,409 (NPC draw layer) | 409,600 |
| `scenes/campfire.riv` | 293,827 | 293,829 (front eases) | 409,600 |
| `scenes/beach.riv` | 308,010 | 308,646 (front eases, gull draw layer, night pole) | 409,600 |
| `scenes/deepSpace.riv` | 80,546 | 81,179 (NPC draw layer) | 409,600 |
| `scenes/cafe.riv` | 140,642 | 141,234 (NPC draw layer, wipe edge) | 409,600 |
| `scenes/rooftop.riv` | 156,325 | 156,420 (front eases, telescope / pigeon) | 409,600 |
| `scenes/mountainHut.riv` | 117,331 | 118,167 (low list, NPC draw layer) | 409,600 |
| `scenes/forestCabin.riv` | 180,396 | 181,136 (front eases, NPC draw layer, birches) | 409,600 |
| `scenes/trainCompartment.riv` | 97,509 | 97,509 (untouched) | 409,600 |
| `scenes/library.riv` | 161,287 | 162,485 (low list, NPC draw layer, ladder) | 409,600 |

## Per-tier performance

Three instruments are used. None of them is the phone.

### 1. CLI bench of record

Source: [perf/bench.md](perf/bench.md). Rive 1.8.0 headless, 1080×1920, 5 interleaved repeats. Host load
went from 1.66 to 3.54.

- Gate: low p95 ≤ 0.8 × ultra and high ≤ 1.02 × ultra. 20 / 20 lines ok, with no retry needed.
- Ruling 3 aimed for low ≤ 0.70 × ultra. Every scene meets it except library, at 0.721 (kept; execution ruling 26).

| Scene | low ÷ ultra (p95) | high ÷ ultra | M11 low ÷ ultra |
|---|---:|---:|---:|
| beach | 0.608 | 0.990 | — |
| cafe | 0.633 | 1.010 | — |
| campfire | 0.620 | 1.014 | — |
| deepSpace | 0.557 | 0.994 | — |
| forestCabin | 0.692 | 1.009 | — |
| library | **0.721** | 0.995 | 0.760 |
| livingRoom | 0.644 | 0.993 | — |
| mountainHut | 0.671 | 0.997 | 0.722 |
| rooftop | 0.546 | 1.002 | — |
| trainCompartment | 0.705 | 0.999 | — |

(M11 recorded library and mountainHut only as the two at risk. The other M11 ratios are in
`rive/review/m11/perf/`.)

### 2. Frame cost on macOS, profile

Source: [perf/frame_cost_macos.md](perf/frame_cost_macos.md).

- One full run plus three re-runs of the covered-window passes. Load went from 2.40 to 5.44.
- 40 / 42 passes are valid, and **all 40 are within budget**: worst P95 is 1.6–3.7 ms at every tier, with 0 % of frames over.
- Rain 1 costs what dry costs here.
- **library at high and ultra drew 1 frame in 8 s in all four runs.** This is also in M11's table.
  - Low drew 672 frames in the same runs, and the emulator drew it fine in M11.
  - An in-app capture at forced ultra had 338 live grabs.
  - So the stall is this harness on macOS. The cause is an open item.

macOS ranks the scenes and tiers against each other. Its build P95 of about 2.4–3.5 ms is 3–5 × under
even the ultra budget, on Skia, a desktop GPU, and with no thermal limit. It says nothing about a phone.

### 3. Emulator

The emulator `emulator-5554` was held for the whole close-out by another session's app,
`fr.yofardev.run_life`, in the foreground from ~13:09. That run was never disturbed (execution ruling 33),
so M12 has no full 10-scene emulator run. What exists:

- **Front scenes, M12 code (lane F, before the emulator was taken):** [front/README.md](front/README.md).
  - Quiet regime: rain 1 ÷ dry build P95 0.81–1.28.
  - Slow regime: 1.22–2.13, about +1 vsync.
  - Low with rain = dry, since the front is never created.
- **All ten scenes, M11 code:** [../m11/perf/frame_cost_emulator.md](../m11/perf/frame_cost_emulator.md).
  - 42 / 42 valid, 12 / 42 within budget.
  - On a 60 Hz emulator, the high and ultra budgets (11.1 / 8.3 ms) sit under the emulator's own worst P50 of about 10 ms. Those FAILs measure the emulator, not the tiers.
  - M12 changed nothing a phone's frame cost would see outside the four front files (eases only), library and mountainHut low (lighter), and the NPC draw layers (one 1-frame animation per state).

### The verdict that remains

[device/README.md](device/README.md) §1 covers all tiers. §1b covers the front repeat at high and ultra, and
its target is rain-1 build P95 ≤ 1.25 × dry. If the phone misses it, the fallback ready to land is
`QualityTier.allowsSceneFront` at ultra only (one line; execution ruling 26).

## What shipped against the vision

The north star: "a character that performs every reply like an actor, inside a living diorama lit by its own
world, that reacts to you in real time at 60/120 fps on a mid-range Android phone. All of it is generated
from code."

| Pillar | Shipped | Not shipped (or changed) |
|---|---|---|
| **4.1 Character 2.0** | Generated rig: bones, skinned paths, arm IK, five-finger hands driven by digit pivots, ±yaw / pitch head turn with a faired 3/4 outline, FACS-lite AUs per side (14 numbers), wardrobe on one skeleton with data-bound tints, costume signatures | Feather / mesh per tier (feather is not used) |
| **4.2 Speech** | Visemes from the TTS WAV aligned to text (rule-based en / fr G2P, audio-classifier fallback), p/b/m closures (wow1: 11 for 9 words), the inhale pre-roll, nods / brows / tilt from prosody, the settle | **Kokoro** deferred (M1–M3). The aligner is rule-based, not a forced aligner |
| **4.3 Presence** | Caret gaze, lean and backchannel nods from typing / STT, `?` / `!` reactions, the idle ladder 30 s / 2 min / 10 min, tool acting (tablet, newspaper, window glance), cue grammar, persona body language | Night doze with a startle tap. The deepSpace telescope as a *tool* prop (the telescope is a scene drag) |
| **4.4 Living dioramas** | 10 scenes. Every one a diorama with parallax planes (gyro / pointer), fog veils, time of day from the clock, weather from the own-location report (rain, fog, wind), seasons, moon phase, festive window, NPCs, drags (pull, poke, trail, spin, aim, chain), the front weather layer | Feathered depth of field. Caustics, god rays, heat haze, paper-grain grade. Easter eggs and collectible memories. Scene *download* (scenes stay bundled; M9). AnimaScript particles (M0 NO-GO: the effects are keyed in RML) |
| **4.5 One light** | One rig per scene (`art_bible.SCENES` = `SceneLights`), written to the avatar and the UI (glass tint, caption ink), firelight flicker in-file, day-light lean | — |
| **4.6 Cinematography** | `CameraDirector`: wide / medium / close-up / prop insert, cuts at sentence starts, push-in while speaking, pull-back on events, reduce motion → medium locked. Journeys over all 90 pairs | Rack focus (no feather) |
| **4.7 Sound / haptics** | Foley from Rive events (step, cloth, click, paper, bell), ambient beds following scene state (crackle, rain, wind), haptics on drags through `FoleyService`, behind the sound-effects setting, never taking audio focus | Heard by nobody yet (headless only) |
| **4.8 Art-as-code studio** | Everything generated (Python → RML → CLI), deterministic ids, the review tools (contact sheets, motion metrics, identity / tier / time / journey / rain gates), quality tiers (benchmark, thermal, battery saver, drift), the CLI bench gate, the per-tier frame harness | The **critic score target** (9.3 / ≥ 9.0), dropped in M4 by the owner's lean-review rule. The **device farm** (never built; one owner phone). Signed Luau scripts (unused) |

**The three wows.** All three run in the app with scripted replies and every gate ok ([wow/](wow/README.md)).
- Firelight on the cheek and glasses, the inhale, p/b/m closures, brows on the question, steam off wet logs, and rain in front.
- The 3/4 turn, the tablet lighting the face, the glance back, and the answer.
- The door journey with the jacket, a cut to the beach at the local sunset, and parallax (the vision's 6 planes are 5–7 per scene).

**Exit gates the moonshot did not reach.**
- "Every tier passes its performance gate" waits on the phone.
- "Every asset ≥ 9.0, overall ≥ 9.3" was dropped in M4.
- "A user study beats v4 on *feels alive*" is the owner's, and was never run.

## Open items for the owner

1. **The phone run**: [device/README.md](device/README.md) §1 (all tiers), §1b (the front at high / ultra), §2 (battery per tier).
2. **The front fallback.** If the phone's rain passes at high / ultra miss 1.25 × dry, set `allowsSceneFront` to ultra only. One candidate was not measured in the emulator's slow regime: the `Factory.flutter` front ([front/README.md](front/README.md), Open). Its patch is in the shared notes folder.
3. **library low 0.721 × ultra** (target 0.70). The rest of its low cost is the bookcases' books, which are the scene's art.
4. **Kept defects.**
   - The cat's idle sub-part swaps (paw, lids, tongue) still blend when the state changes mid-lick.
   - Occlusion at the avatar band's edge: palm, umbrella, canopy, Saturn's ring.
   - deepSpace's low haze differs from ultra.
   - A soft band where the rooftop parapet meets the wet floor.
   - The rooftop pigeon at `npcX` 1 is cropped on tall phones.
5. **Wow framing.** These are app-level shot choices, not fixed here.
   - wow1's thinking bubble is cut at the medium shot's edge.
   - wow2's prop insert crops the crown of the head, and the thinking bubble covers the More chip.
   - wow3's caption comes after the grab, and the living room keeps its night sky at sunset.
6. **wow1's brows gate** (≥ 0.3) passes on a resting outer brow. The real value is 1.83, but the threshold is too low to catch a frozen face. The new frozen-stretch gate covers that case; raising the threshold is the owner's call.
7. **Not verified at all.**
   - Sounds and haptics by ear and hand.
   - iOS: the build is broken by the pre-existing `VoiceEffectsHandler`.
   - A real LLM reply driving the wows (the harness never calls one).
8. **The macOS frame-cost harness draws library at high and ultra as 1 frame in 8 s.** This is seen in M11 and in all four M12 runs. The in-app stage is live, so this is a measurement gap, not a frozen app. The library's high and ultra rows are therefore missing on macOS.
9. `android/.kotlin/` (gradle output) is untracked in this worktree. It was never staged.
