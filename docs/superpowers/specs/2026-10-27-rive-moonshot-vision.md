# Rive moonshot: "Pocket Pixar" (vision)

> Status: **vision approved 2026-10-27**. **M0 spikes done 2026-10-27, see
> [spikes/2026-10-m0](../spikes/2026-10-m0/README.md)** (go/no-go per technology).
> Scope: the Rive avatar and its environments, 12 months, team size not a constraint.
> Builds on the [v4 Rive design](2026-10-22-rive-v4-design.md) and
> [`rive/CONTRACT.md`](../../../rive/CONTRACT.md).
> First step: [M0 feasibility spikes](../plans/2026-10-27-rive-moonshot-m0-spikes.md).

## 1. North star

> A character that **performs** every reply like an actor, inside a **living diorama** lit by its
> own world, that reacts to you in real time at 60/120 fps on a mid-range Android phone. All of
> it is generated from code.

The whole year is judged against three "wow" moments. Each is storyboarded in M0 and re-shot
every quarter on the device farm:

1. **Campfire at night, raining where the user lives.**
   - Firelight flickers on the avatar's cheek and glasses.
   - The avatar inhales before speaking.
   - Its lips close on every p/b/m.
   - Its eyebrows lift as the pitch rises at the end of a question.
   - Steam hisses off the wet logs.
2. **"What's the weather in Tokyo?"**
   - The avatar turns its head into a real 3/4 view.
   - It pulls out a small tablet, and the screen lights its face.
   - It glances back at you and answers.
   - The tool call becomes acting.
3. **Changing scene is a journey.**
   - The camera pulls back, and the avatar grabs a jacket and walks out the door.
   - A match cut lands on the beach at the user's local sunset.
   - Gyroscope parallax runs across 6 depth planes.

## 2. Decisions

**From the user (2026-10-27):**

1. **Art stays CLI-only.** Everything is generated with Python → RML/scripts → Rive CLI. No
   editor work and no bought art: the v4 rule holds. The extra resources go into the generators
   (§4.8).
2. **Depth is 2.5D.** The character stays a 2D illustration. Its head turns through skinned
   vector deformation. The world gets multi-plane parallax. Shaders and scripted 3D are allowed
   only as accents in the environments. A 3D character is out.

**What changes from v4:**

| v4 | Moonshot | Guardrail |
|---|---|---|
| Flat budgets; no feather, no mesh | **Device quality tiers** (Low/High/Ultra), set by an on-device benchmark. Skinning, feather, shaders and particle counts are gated per tier. | The Low tier never costs more than v4 does today. |
| 7 discrete moods, mouth 0–4 | **A continuous face**: a valence × arousal blend, FACS-lite action units and 15 visemes. | The `mood` enum stays as a set of presets, so the reply JSON keeps working. |
| 4 scenes, swapped on a blank frame | **10 scenes** built from a shared world kit, with authored transitions between them. | Scenes are lazy-loaded and downloaded one at a time. |
| A keyframe for every pose | **Procedural motion** in scripts (springs, noise, solvers) on top of fewer keyed poses. | Files stay small. The avatar budget is reset for each tier. |

> **M0 finding:** `rive_native` 0.1.11 accepts only signed script bytecode and has no wasm
> engine. Signed Luau runs on device (retry 2026-10-28, cost not yet measured); AnimaScript
> does not. Procedural motion was proven as a **Dart-driven**
> spring writing view-model numbers instead. It costs 304 B per arm against 1,026 B for the same
> motion as keys, at the same frame cost as keys. Its motion quality is inconclusive
> ([procmotion.md](../spikes/2026-10-m0/procmotion.md)).

## 3. Where we start (verified 2026-10-27)

**The rig is a puppet.**
- `rive/tools/gen_avatar.py` generates a character animated purely by keyed transforms.
- The RML has no bones, skins, IK, blend states, scripts or feather.
- Every expression is a discrete keyed pose: 7 moods, mouth 0–4 and 8 gestures.
- `avatar.riv` is 482 KB of its 600 KB budget.
- The independent critic's best score is 8.82/10 ([`rive/CRITIC_ITERATIONS.md`](../../../rive/CRITIC_ITERATIONS.md)).

> **M0 finding:** the RML does have one blend state: `Mouth`, a `BlendState1DViewModel` with 5
> animations and no reset layer. M0 found that such blends settle at biased intermediate values
> ([head25d.md](../spikes/2026-10-m0/head25d.md) § Blend intermediates). The app's integer `mouth` values sit on
> blend points, but fractional values should be checked.

**Lip-sync uses amplitude only and runs open-loop.**
- `AudioAmplitudeService` takes RMS 40 times per second.
- A `Timer.periodic` in `tts_playback_service.dart` steps through the samples and never re-syncs
  to the player's position.
- Five thresholds turn the level into five mouth states.
- Supertonic gives no phoneme timings, and the raw PCM is thrown away.
- Kokoro is designed but not built yet ([design](2026-10-26-kokoro-tts-design.md)). It would run
  through `sherpa_onnx` 1.13.8 with espeak-ng.

> **M0 finding** ([phoneme-timing.md](../spikes/2026-10-m0/phoneme-timing.md) §4):
> - On Android, `audio_analyzer` ignores `samplesPerSecond`, so the mouth updates every 85 ms,
>   not every 25 ms. This is a current-app bug.
> - The open-loop timer leads the audio by about 250 ms on macOS, because of start latency.
> - The timer permanently loses whole ticks on every UI-isolate stall longer than one interval.
> - sherpa 1.13.8 discards the duration output that Kokoro's ONNX model already has.

**The stage is two Rive widgets stacked** (`home_content_stack.dart`).
- There is no parallax, no shader and no particle effect.
- A scene swap shows an empty box until the new file loads.
- `gesture_done` is never handled.
- There is no reduce-motion support, no tier detection and no battery handling.

**The runtime and the CLI.**
- The app runs `rive` 0.14.11 / `rive_native` 0.1.11.
- Rive CLI 1.8.0 offers several things v4 never used:
  - bones, with `Skin`/`Weight` on vector `PointsPath`s
  - IK and blend states
  - Luau and AnimaScript (wasm), with jobs, workers and audio processors
  - WGSL shaders and scripted 3D
  - nested artboards
- Whether `rive_native` runs all of this well on Android is unknown. M0 spike 1 decides.

> **M0 finding** ([capability-matrix.md](../spikes/2026-10-m0/capability-matrix.md)):
> - Bones and skinning, feather, nested artboards and 1D view-model blends work on macOS (Skia)
>   and on the emulator (Impeller). CLI 1.8.0 has no 2D blend state type. Blend verdict: GO
>   (endpoints proven on device; intermediates and reset layer CLI-only).
>
> Scripted cases:
>
> - With unsigned builds, every scripted case is red on device.
> - In the signed retry (2026-10-28), **Luau is green** on both tiers. Its cost is not yet
>   measured.
> - WGSL via Luau still fails: on 0.1.11, a VM loaded from a file gets no GPU render context.
> - AnimaScript, WGSL-via-AnimaScript and audio processors are a **no-go** on 0.1.11, which has
>   no wasm engine.

## 4. Pillars

### 4.1 Character 2.0: a real rig, generated

**The art bible is written as code.** Shape language, line-weight rules, the colour script for
each scene and a palette tied to the Storybook-night tokens all become generator parameters
and critic rubrics.

**Skeletal rig.**
- The generator emits bones, vector paths skinned with `Weight`/`CubicWeight`, and IK for the
  arms and the look-at.
- Hands have five fingers and about 12 generated poses.

**2.5D head.**
- Skinned deformation turns the head ±30° left and right (yaw) and ±15° up and down (pitch).
  A 2D blend state drives it.
- The features shift in perspective, the hair layers hide each other, and the far eye
  foreshortens.

> **M0 finding** ([head25d.md](../spikes/2026-10-m0/head25d.md), [critic](../spikes/2026-10-m0/head25d-critic.md)):
> - CLI 1.8.0 has no 2D blend state, and 1D blends settle biased without a reset layer. The
>   prototype drove the bones with formula converters instead. It is exact, history-free and
>   49.9 KB, and it fits the budget for the head only.
> - The independent critic scored it **6.7/10** against the 8.5 bar. The crown and silhouette
>   are static, the outline has no 3/4 structure, and the sweep is linear with no secondary
>   motion.
> - The cost of animating yaw/pitch is unmeasured.

**FACS-lite face.** About 14 action units are exposed as view-model numbers:
- brows: inner up, outer up, lower
- lids: tighten, upper-lid raise
- cheek raise
- nose wrinkle
- lip corners: pull, depress
- lips: stretch, pucker, press
- jaw drop
- dimpler

Moods become additive presets over these action units.

**Emotion space.** A valence × arousal blend plus an intensity, moved by springs, so emotions
*transition* instead of snapping.

**Physics.** Spring chains in AnimaScript (Luau as fallback) move the hair strands, hoodie
strings and cape, driven by how fast the head and torso move. The glint on the glasses follows
the scene light.

> **M0 finding:** AnimaScript does not run on `rive_native` 0.1.11. The Luau fallback runs when
> the build is signed (retry 2026-10-28), but its device cost is unmeasured. The proven route
> today is Dart springs writing view-model numbers ([procmotion.md](../spikes/2026-10-m0/procmotion.md)).

**Wardrobe 2.0.**
- Outfits are generated skins on one shared skeleton.
- Colour variants come from data-bound paints.
- Each costume's signature animation is rebuilt on the rig.

### 4.2 Speech that looks real

**A speech timeline.** Kokoro's espeak-ng phonemes plus its predicted durations make a
`SpeechTimeline`. The durations come out through a `sherpa_onnx` fork or by running the ONNX
model directly.

> **M0 finding** ([phoneme-timing.md](../spikes/2026-10-m0/phoneme-timing.md)):
> - Durations are 25 ms frames whose sum equals the audio length exactly.
> - The recommended route is direct ONNX: the shipped int8 model already outputs durations.
>   That route needs onnxruntime plus our own G2P, about 5–8 days.
> - Shift the timeline by about −50 ms.
> - Keep sherpa's `silence_scale` at 1.0, or replay its edit on the timeline.

**Fallbacks.** The PCM is now kept.
- First fallback: an on-device forced aligner, or an audio-to-viseme classifier.
- Last fallback: today's amplitude path.

**Visemes.** There are 15, blended with their neighbours:
- the mouth starts moving toward the next sound early
- the lips are guaranteed to close on p/b/m
- the teeth show on f/v

**Closed loop.** The player's position stream drives the timeline, not a timer.

**Prosody acting.**
- nods on stressed syllables
- brow raises on pitch peaks
- a head tilt at the end of a question
- blinks moved into pauses
- a visible breath in before each sentence, and a settle at the full stop

**Rive side.**
- The mouth is a 2D blend (jaw open × lip width/roundness) with a teeth/tongue layer.
  *M0 finding:* build it as two 1D blend layers over a reset layer (blend verdict: GO;
  endpoints proven on device, intermediates and reset layer CLI-only). Without the reset layer,
  `t` lands biased ([head25d.md](../spikes/2026-10-m0/head25d.md) § Blend intermediates).
- Dart sends `(visemeA, visemeB, t)` at 30 Hz or less, and Rive interpolates at render rate.

### 4.3 Presence: it is *with* you

**Gaze.**
- The avatar looks away while it thinks and meets your eyes at sentence ends.
- It makes procedural saccades and micro-saccades.
- It follows the composer caret, an attached image, or a prop it mentions.

**Listening.**
- The STT input level and your typing rhythm drive an attentive lean and small nods.
- The brows react to a typed `?` or `!`.

**Idle ladder.** It respects battery saver.
- 30 s: looks around.
- 2 min: plays with a prop.
- 10 min: reads or doodles.
- At night: dozes, and a tap startles it awake.

**Tool calls become acting.**
- web search → tablet
- weather → glance out the window
- news → newspaper
- deepSpace → telescope

The wait for the tool turns into a performance.

**Auto-acting.**
- Deterministic text rules fill the gaps between LLM cues: a question tilts the head, a list
  counts on the fingers, emphasis gets a beat gesture.
- The cue grammar gains `look:`, `beat:`, `prop:` and `intensity:`.
- `gesture_done` is handled, and gestures queue.

### 4.4 Living dioramas (10 scenes)

**Depth.**
- Each scene has 5–7 parallax planes, driven by the gyroscope (`sensors_plus`) and the pointer.
- Each plane has its own depth fog.
- On High and above, the far planes are feathered to fake depth of field.

**World sync.**
- Time of day is continuous and comes from the local clock.
- Weather comes from the existing weather tool.
- Seasons change the scenes; the santa hat and sweater already exist.
- Night skies show the real moon phase.

**Procedural effects.**
- AnimaScript jobs and workers render embers, rain splashes, snow build-up, fireflies, dust
  motes, glowing surf and twinkling stars.
  *M0 finding:* AnimaScript does not run on the pinned runtime
  ([capability-matrix.md](../spikes/2026-10-m0/capability-matrix.md)).
- The level of detail depends on the tier.

**WGSL accents, High and Ultra only.**
*M0 finding:* WGSL has no proven device path yet. Via AnimaScript it is a no-go on 0.1.11, and
via Luau the signed script runs but gets no GPU render context on 0.1.11 ([capability-matrix.md](../spikes/2026-10-m0/capability-matrix.md)).
- heat haze over the fire
- water caustics
- god rays through the window
- nebula noise
- a paper-grain print grade as the storybook signature

**Ecosystem.** The cat, owl, crabs, gulls and alien each run a small behaviour tree. For
example, the cat sleeps on warm spots, reacts to keywords and notices the avatar's mood.

**Interactivity.**
- Every prop has 3 or more reaction variants.
- Props can be dragged: pull the lamp cord, poke the fire, draw in the sand, spin the planet.
- There are easter eggs, plus collectible "memories".

**World kit.**
- The sky, weather, light rig, parallax and NPC base are shared by every scene.
- Scenes 5–10, for example: rainy café, rooftop at night, forest cabin, train compartment,
  library, snowy mountain hut.

### 4.5 One light, everywhere

Each scene exports a light rig as view-model data:
- key light: direction, colour and intensity
- rim light
- ambient light
- fog
- flicker seed and parameters

The avatar's gradients, rim strokes, warm cheek layer and glasses glint all bind to that rig.
Flicker is rebuilt inside the avatar from the shared seed, so Dart does not send anything per
frame.

The Flutter UI reads the same rig for its glass tint, its accent (`context.tokens.scene`) and
the warmth of the captions. This extends `ScenePalette.fromAccent` from a fixed accent to live
light.

### 4.6 Cinematography

**A virtual camera.**
- Shots: wide, medium, close-up and prop insert.
- It pushes in while the avatar speaks and pulls back on scene events.
- On High, it racks focus using feather.

**A rules-based camera director.**
- It picks the shot from the phase, the mood intensity and the cue type.
- It cuts only at sentence boundaries.
- With reduce-motion on, it locks to a medium shot.

**Scene journeys** (door, path, portal, rocket) replace the blank-frame swap. The next scene
preloads while the avatar walks out.

**Diegetic UI.** The caption bubble anchors to the mouth position that Rive exports. The
thinking bubble lives in the world.

### 4.7 Sound and haptics bound to animation

- Rive events trigger foley: footsteps, cloth, prop clicks.
- Ambient beds are mixed from scene state: the crackle follows the flame's intensity, the rain
  follows the weather.
- Haptics fire on prop taps and drags, from the same events.

### 4.8 Art-as-code studio

The big investment is making generated art beat hand-made art.

**Rig DSL.** A typed Python layer on top of `rive/tools/rml.py` and `avatar_kit.py`.
- It covers skeletons, automatic skin weights, poses, blend spaces, and the action-unit and
  viseme shapes.
- Ids are deterministic, and every output can be rebuilt from a seed.

**Motion synthesis.** The 12 animation principles become solvers:
- anticipation
- overshoot and settle
- follow-through
- arcs
- offsets between body parts

A gesture is written as intent plus timing, and its keys are generated.

**Material library.** Wood, brass, cloth, water, fire, skin and hair recipes. It extends
`scene_art.py` and `wardrobe_art.py`.

**Critic loop in CI.** It extends `review.py`, `motion_review.py` and `wardrobe_review.py`.
- Combinatorial contact sheets: mood × gesture × wardrobe × light × tier.
- Motion metrics: jerk, arc smoothness, overlap, loop seams, pops.
- An independent vision-model critic score for each asset.
- A parameter search that pushes the generators toward the rubric.
- Target: 9.3/10 overall, and no asset below 9.0.

**Performance gates.**
- A device farm: low (Helio G85 class), mid (Snapdragon 7 series), flagship, and desktop.
- Each asset build gets an `integration_test` profile run.
- Low: 95% of frames under 16.6 ms at 60 Hz.
- High: 95% of frames under 8.3 ms at 120 Hz.
- A battery budget, to be fixed in M0.
  *M0 finding:* not fixed. The procedure is written, and the measurement waits for the device
  farm ([tiers.md](../spikes/2026-10-m0/tiers.md) § Battery procedure).

**Quality tiers.**
- A benchmark on first launch sets `QualityTier`, which is passed to Rive as a view-model enum.
- The tier drops automatically when the phone throttles from heat.
  *M0 finding:* thermal drift on phones is unmeasured (no farm). The probe method is chosen: a
  3 s `FrameTiming` probe, the P95 of `max(build, raster)`, and an fps gate. Its thresholds are
  provisional: Ultra ≤ 3.3 ms, High ≤ 6.6 ms ([tiers.md](../spikes/2026-10-m0/tiers.md)).
- The tiers hook into reduce-motion and battery saver.

## 5. Flutter architecture sketch

All of this follows the `AGENTS.md` rules.

**Shared primitives** in `lib/core/models/`:
- `EmotionVector`
- `ActionUnits`
- `Viseme`
- `GazeTarget`
- `Shot`
- `LightRig`
- `QualityTier`
- an extended `AvatarCue`

**`sound` / `talking`.**
- `SpeechTimeline` is built next to synthesis, and the PCM is kept.
- `TtsPlaybackService` emits timeline events aligned to the playback position, on the same path
  as `CuesReachedEvent`.

**avatar domain.**
- `PerformanceDirector` turns mood, cues, the speech timeline, presence signals, the idle ladder
  and tool-call state into `PerformanceIntent` *targets*.
- `CameraDirector` picks the shots.
- Rive does the smoothing.
- No cubit depends on another cubit.

**`core/services/world`.** `WorldStateService` provides the time of day, weather, season, tilt,
tier and thermal state. It is constructor-injected and registered only in
`service_locator.dart`.

**A possible `stage` feature.** At M3, decide whether camera and composition move into their
own `stage` feature, if the avatar feature then has more than one reason to change.

**Rive types** stay in `features/avatar/presentation/` and `core/design/rive/`. This is
enforced by `test/architecture_test.dart`.

**Contract v5.** Nested view models: `face`, `speech`, `gaze`, `light`, `camera`, `world` and
`quality`.
- One schema generates `rive/CONTRACT.md`, the Dart mirror and `check_contract.py`.
- A change to the contract still gets its own `contract:` commit.

## 6. Roadmap

| When | Milestone | Exit gate |
|---|---|---|
| **M0** (weeks 1–4) | Feasibility spikes ([plan](../plans/2026-10-27-rive-moonshot-m0-spikes.md)), the art bible as code, storyboards for the 3 wow moments, the device farm and a baseline | A go/no-go for each technology; tier budgets fixed; the user signs off the art direction |
| M1–M3 | Rig DSL and Character 2.0 (skeleton, 2.5D head, FACS-lite, hands); visemes and prosody, landing with Kokoro; quality tiers; `PerformanceDirector` v1; contract v5 | Wow #1, without the firelight; critic ≥ 9.0 on face and speech |
| M4–M6 | The 4 scenes rebuilt as dioramas; shared light for the avatar and the UI; presence; tool-call acting; motion solvers | Wow #1 and #2 in the app on a mid-tier device, within budget |
| M7–M9 | Camera director, scene journeys, world sync, ecosystem NPCs, foley and haptics, scenes 5–7 | Wow #3; journeys between all scenes |
| M10–M12 | Scenes 8–10, wardrobe 2.0, body-language profiles per persona, performance and battery hardening, accessibility, polish | Every tier passes its performance gate; every asset ≥ 9.0, overall ≥ 9.3; a user study beats v4 on "feels alive" |

> **M0 finding** (exit gate, spikes part only; [README](../spikes/2026-10-m0/README.md)):
> - The go/no-go per technology is done: 9 GO, 6 NO-GO, 2 BLOCKED or INCONCLUSIVE (after the 2026-10-28 signed retry).
> - The tier budgets are **not** fixed. The thresholds are provisional until the device farm
>   exists.
> - The art bible, the storyboards and the art-direction sign-off are outside the spike plan.

**Team** (all CLI-only):
- 1 art director: owns the rubric and the bible, and reviews renders
- 3 technical artists / generator engineers
- 1 motion-systems engineer
- 1 shader/FX engineer
- 3 Flutter engineers
- 1 speech/ML engineer
- 1 sound designer
- 1 performance/QA engineer
- 1 producer

## 7. Risks

1. **Runtime gap.** AnimaScript, WGSL or audio may be missing or slow in `rive_native` on
   Android. Spike 1 decides. The fallbacks are Luau or Dart, and shaders only ever run on High
   and Ultra.
   **M0:** confirmed for the pinned runtime. AnimaScript, WGSL via AnimaScript and audio
   processors are a no-go on `rive_native` 0.1.11 (no wasm engine). Signed Luau runs (retry
   2026-10-28); WGSL via Luau has no GPU render context on 0.1.11. The Dart fallback works ([capability-matrix.md](../spikes/2026-10-m0/capability-matrix.md),
   [procmotion.md](../spikes/2026-10-m0/procmotion.md)).
2. **Generated art plateaus.** Countered by:
   - the Rig DSL, solvers and material library
   - critic-driven parameter search
   - the art director's veto
   - quarterly wow re-shoots that show the gap early

   **M0:** the first data point is the 2.5D head. It scored 6.7/10 against an 8.5 bar, while
   the shipped art scores 8.51–8.82. The blockers are in the generator (static crown, no 3/4
   outline, unperformed motion), not in the runtime
   ([head25d-critic.md](../spikes/2026-10-m0/head25d-critic.md)).
3. **Low-end performance and file size.** The avatar is already at 482 of 600 KB. Countered by:
   - tiers from day one
   - procedural motion instead of baked keys
   - a performance gate on every asset
   - downloading scenes one at a time

   **M0** ([README](../spikes/2026-10-m0/README.md), [tiers.md](../spikes/2026-10-m0/tiers.md)):
   - Size: a skinned head fits (avatar ≈ 551 KiB), but head plus torso plus hands is
     ≈ 773 KiB, over budget, so it needs cheaper weights.
   - Procedural drive is 0.30× the bytes of the same motion as keys.
   - Performance: low-end cost is **unmeasured**, because there is no device farm and emulator
     numbers are not a tier.
   - Earlier frame-cost numbers cover only the timeline's tail.
4. **Over-acting looks uncanny.** The director keeps cooldowns (today: 1 gesture per chunk,
   1.5 s apart). A user study and the art director's veto back this up.
   **M0:** not tested by the spikes. One related finding: a raw spring toward step targets has
   no ease-in, so procedural motion needs shaped targets
   ([procmotion.md](../spikes/2026-10-m0/procmotion.md)).
5. **Contract drift.** One schema generates the contract, the Dart mirror and the checker.
   **M0:** not tested by the spikes, so there is no finding.

## 8. Verification

**Per asset:**
- `./scripts/frive.sh`
- critic contact sheets and motion metrics, logged in `rive/CRITIC_ITERATIONS.md`
- a device-farm run for each tier

**Per app change:**
- `dart fix --apply`, `dart format .` and `./scripts/fverify.sh`
- `integration_test/rive_contract_test.dart` and `avatar_rive_binding_test.dart`

**Per quarter:**
- the wow moments re-shot
- a performance and battery report for each tier
- a user study against the v4 baseline
