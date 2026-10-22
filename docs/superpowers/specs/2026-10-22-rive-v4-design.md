# Yofardev AI v4: Rive migration (design)

> Status: approved 2026-10-22.
> Shared Rive interface: [`rive/CONTRACT.md`](../../../rive/CONTRACT.md).
> Plans: [Plan A, Rive assets](../plans/2026-10-22-v4-plan-a-rive-assets.md) ·
> [Plan B, app integration](../plans/2026-10-22-v4-plan-b-app.md).

## 1. Context / why

Today the avatar is built from about 40 hand-placed PNG layers in `assets/avatar/`: the base
body, 5 mouth sprites, eye frames, outfits, and 4 costumes. Behind it sit 27 JPEG backgrounds,
and 2 Lottie indicators live in `assets/lotties/`.

The LLM changes the avatar's look in two ways:

- fields in every reply's JSON (`background`, `hat`, `top`, `glasses`, `costume`,
  `soundEffect`), defined in `assets/txt/system_prompt_*.txt`, read back by
  `ChatEntry.getAvatarConfig()` and applied by `AppLifecycleService`;
- the `change_avatar` tool (`lib/core/services/agent/avatar_tool.dart`). Its option lists are
  wrong: it offers `mountain`, `pirate`, `crown` and other values that don't exist.

The avatar has no emotions.

**v4 goal: the avatar acts.** The LLM picks a mood and fires gestures in time with speech,
inside living Rive scenes the user can touch. Rive replaces the stacked PNGs with one rigged
character driven by a state machine, so new acting means a new state, not new widget code.

## 2. Decisions

**From the user:**

1. **Acting:** one base mood per reply, plus occasional inline gesture cues that fire when TTS
   reaches them.
2. **Art:** generated with the Rive CLI only (RML + scripts). A simpler vector style is fine.
   If the spike looks cheap, the fix is more CLI iteration: no Rive-editor work, no bought art.
3. **Parity, rebuilt in Rive:** outfits, hats, glasses, the 4 costumes (each keeps its signature
   animation), and leave/come-back.
4. **Photo backgrounds are dropped.** A few animated Rive scenes replace them.
5. **Scenes are interactive.** The LLM triggers scene events. Taps on props or on the avatar
   trigger **local reactions only**: no LLM call, nothing written to chat history.
6. **Platforms that must work:** Android (primary) and desktop. The web demo and iOS are not
   required and may break.
7. **Test rig:** an Android emulator with throttled CPU, plus desktop. No physical low-end phone.
8. **Two agents:** an expensive agent builds only the Rive assets (Plan A). A cheaper agent does
   everything else (Plan B).

**Anti-goals (user):** art that looks cheap; jank or battery drain on low-end Android.

**Designer's calls:**

- v4 ships all at once. The Rive flag is for development only, and the data migration runs one
  way.
- The reply JSON stays the main channel and gains `mood`. `change_avatar` stays, with its options
  generated from the Dart enums.
- Old background names in saved chats and replies map to the nearest scene **when read**. Stored
  data is never rewritten.
- v4.0 has 4 scenes: `livingRoom` (default), `campfire`, `beach`, `deepSpace`.
- Anti-spam: at most 1 gesture per sentence chunk, with a 1.5 s cooldown.
- The mood stays in place until the next reply sets a new one.
- No 3D and no user-built avatars.

## 3. Architecture fit (flutter-architecture + AGENTS.md)

Project rules override the skill: errors use `Result<T>` (`lib/core/models/result.dart`), and
fpdart is banned.

- **Shared primitives go in `lib/core/models/`**, like `AvatarConfig` and `TalkingPhase` today.
  These are `AvatarMood`, `AvatarGesture`, `AvatarScene`, `SceneEvent`, and the `AvatarCue`
  sealed type (gesture | sceneEvent). The chat, sound, talking and avatar features all use them,
  and none of those features may import another's internals.
- **Rive types live only in `lib/features/avatar/presentation/`.** Domain code and cubits never
  see Rive classes.
- **Event flow.** Dependencies point inward, and no cubit depends on another cubit:
  1. The chat domain's `CueParser` strips cues from the stream.
  2. `TtsQueueItem` (sound) carries a `List<AvatarCue>`.
  3. `TtsPlaybackService` (talking) emits `CuesReachedEvent` when that item starts playing.
  4. `AvatarCueService` (new, avatar domain) subscribes, applies the anti-spam guard, and calls
     `AvatarAnimationService.trigger(...)`.
  5. `AvatarCubit` updates its state, and the Rive view fires the trigger.

  The avatar feature already imports the talking barrel, and talking and sound don't import
  avatar, so this adds no dependency cycle.
- **One-shot triggers live in state as events with a sequence number**
  (`gestureEvent: (AvatarGesture, int seq)`). The view fires them from a `BlocListener` with
  `listenWhen` on `seq`, so repeating the same gesture still fires.
- **Rive tap events.** The scene or avatar emits a Rive event. The view calls
  `avatarCubit.onPropTapped(sceneId, propId)`. `PropReactionService`, a mapping table in the
  avatar domain, returns a mood, gesture or sound.
- New services are registered only in `service_locator.dart`, the DI smoke test is updated, and
  `test/architecture_test.dart` stays green.

## 4. Order and sync points

```
contract committed ──► A0 spike ──┐
                  └──► B1 lab ────┴─► USER GATE (looks cheap? janky?)
after gate:  A1…A7  ∥  B2…B7
             A1 + A6 ──► B8 (Rive views)
             A7 done ──► B9 cut-over ──► B10
```

- The two plans run in parallel, in separate worktrees, and never touch the same files.
  `rive/CONTRACT.md` is the only thing they share.
- Plan A logs each finished milestone in `rive/CHANGELOG.md`. Plan B starts the steps that need
  real assets (B8, B9) only once that log says the parts it needs are in.

## 5. Verification (whole project)

- **Unit tests:** cue parser (chunk splits, unknown cues, stripping), mood validation, tool
  schema matching the enums, the old background mapping, the anti-spam guard,
  `PropReactionService`.
- **Cubit and wiring:** bloc_test for the `AvatarCubit` transitions, an updated DI smoke test,
  and a green `architecture_test.dart`.
- **Contract check:** `integration_test/rive_contract_test.dart`, run on macOS, keeps the
  `.riv` files in line with the contract.
- **Manual pass** on the throttled emulator and on desktop:
  - a scripted conversation that hits every mood, gesture and scene event
  - a tap on every prop
  - the perf overlay
  - an old saved chat
