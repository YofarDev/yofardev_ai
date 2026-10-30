# AI Agent Documentation - Yofardev AI

> **Quick Start Guide for AI Agents and LLMs**

---

## Project Overview

- **What**: Animated AI avatar app — chat with an LLM (OpenAI-format or Gemini) that answers with TTS, lip-synced animation, and function calling (web search, weather, news…)
- **Version**: 3.0.0+6 — Dart SDK `>=3.8.0 <4.0.0`
- **Architecture**: Clean Architecture — `lib/features/<name>/{data,domain,presentation}` + shared `lib/core/`
- **App shell**: `lib/app.dart`; `lib/main.dart` is bootstrap only
- **Platforms**: all Flutter targets present, but Android is the primary one (iOS untested, web demo has reduced features)

> `docs/superpowers/` holds implementation plans and specs: `plans/` (2026-10-22
> architecture audit + alignment plan, v4 Rive plans A & B, 2026-10-24 pipeline
> optimizations, 2026-10-27 Rive moonshot M0 spikes, 2026-10-29 moonshot M3, M4 and M5, 2026-10-30 M6 and M7, 2026-10-31 M8 and M9) and `specs/` (rive-v4
> design, 2026-10-27 Rive moonshot vision). Other references: `README.md`
> (app overview), `scripts/README.md` (tooling), `rive/README.md` +
> `rive/CONTRACT.md` (avatar assets).

---

## Commands

```bash
flutter pub get                                            # install dependencies
dart run build_runner build --delete-conflicting-outputs   # regen freezed/json code (after model changes)
flutter gen-l10n                                           # regen localizations (after .arb edits)
flutter test                                               # all tests (includes architecture_test.dart)
flutter test test/features/chat                            # focused: one directory
flutter test --update-goldens test/features/avatar         # regenerate golden images (intentionally only)

# Before finishing ANY change (quality gate):
dart fix --apply
dart format .
./scripts/fverify.sh    # format check (non-mutating) + flutter analyze + flutter test
```

`./scripts/fverify.sh` does not fix or generate anything — resolve deps/codegen yourself first.

---

## Helper Scripts (`scripts/`, details in `scripts/README.md`)

| Script | Purpose |
|--------|---------|
| `./scripts/fverify.sh` | Quality gate — run before finishing any change |
| `./scripts/fgen.sh "name" [--with-service] [--with-dto]` | Scaffold a new Clean Architecture feature + codegen; refuses to overwrite existing features |
| `./scripts/fstr.sh "key" "FR" "EN"` | Add an l10n key to both ARB files, then regenerate |
| `./scripts/fl10n.sh` | Find hardcoded user-facing strings missing `AppLocalizations` |
| `./scripts/fimp.sh [--apply]` | Preview (default) or apply broken-import repairs |
| `./scripts/fanal.sh` / `fdead.sh` / `fcheck.sh` | Advisory audits: analysis report / unreferenced files / dependency inventory — findings need manual review |

Scripts `fgen`, `fstr`, `fl10n`, `fimp` require [uv](https://docs.astral.sh/uv/) on PATH.

---

## Quick Reference

### Technology Stack

- **State**: flutter_bloc ^9.1.1 (Cubit default)
- **Models**: freezed ^3.2.5 (union types) + json_serializable
- **Errors**: `Result<T>` from `lib/core/models/result.dart` (`Result.ok` / `Result.err(Failure)`); fpdart is banned
- **DI**: get_it ^9.2.1
- **Routing**: go_router ^17.1.0
- **L10n**: ARB files in `lib/core/l10n/` (en/fr), generated code in `lib/core/l10n/generated/`

### Critical Rules

1. **All DI in `lib/core/di/service_locator.dart`** - Never wire elsewhere
2. **No cubit-to-cubit dependencies** - Use domain services
3. **No cross-feature imports** - Features may only import another feature's
   public API barrel (`lib/features/<name>/<name>.dart`) or `core/services/`.
   `core/` never imports `features/` (except the composition roots
   `core/di/` and `core/router/`). The app shell lives in `lib/app.dart`;
   `lib/main.dart` is bootstrap only.
4. **`getIt` resolved ONLY in** `lib/core/di/service_locator.dart`,
   `lib/app.dart`, and `lib/core/router/app_router.dart` — everything else
   receives dependencies via constructor injection (enforced by
   `test/architecture_test.dart`)
5. **DI registrations (`getIt.register*`) appear only in `service_locator.dart`**
   (enforced)
6. **Feature `domain/` must not import that feature's `data/` or
   `presentation/`** (enforced)
7. **No raw colors or fonts outside `lib/core/design/`** — no
   `AppColors`/`AppPalette`/`Colors.*` (except `Colors.transparent`), and
   `google_fonts` only in `lib/core/design/` and `lib/main.dart` (enforced)

Note: `lib/core/repositories/settings_repository.dart` deliberately stays in
core (consumed by `core/services/agent`; core may not import features).
`AvatarRepository`/`GlobalMemoryRepository`/`LocaleRepository` live in their
owning features' `domain/repositories/` — import via feature barrels.

These layering rules are **enforced by `test/architecture_test.dart`** (it also
bans `package:fpdart` and checks barrel-only imports), so `flutter test` fails
on violation.

### Conventions

- **Explicit types everywhere** (`always_specify_types: true`) — avoid `var`/inference in new code
- **Relative imports** within the package (`prefer_relative_imports`)
- **State idiom**: union states (freezed) for load-lifecycle screens, flat `copyWith` states for persistent interactive state
- **All user-facing strings** go through `AppLocalizations` — add keys with `./scripts/fstr.sh`, never edit `lib/core/l10n/generated/`
- **Never hand-edit** `*.g.dart` / `*.freezed.dart` — rerun `build_runner` after changing annotated models
- **Design layer** lives in `lib/core/design/` (import `design.dart`): read colors via `context.colors` / `context.tokens`, text via `context.text`; the accent of the current scene via `context.tokens.scene` (`accent`, `onAccent`, `glow`)
- **App theme** is Storybook night (ink `#16121D`, surface `#211B2B`, Fraunces display + Manrope body): `AppTheme.forScene(scene)` (cached per scene) and `AppTheme.dark` (= living room), built by `buildLookTheme(UiLooks.storybook, …)` in `lib/core/design/theme/app_theme.dart`; look colours live only in `AppPalette` (`AppTokens` keeps only literal black/white shadow and highlight). `lib/app.dart` feeds `AvatarState.scene` (via a `BlocSelector` around the `MaterialApp` only) into `MaterialApp.theme`, so the accent cross-fades (`AppMotion.slow`) — never rebuild the router or cubits on a scene change
- **Scene accent**: livingRoom `#F4B860`, campfire `#FF8552`, beach `#FF9478`, deepSpace `#B79CFF`; `ScenePalette.fromAccent` is the single derivation rule (onAccent, glow); check pairs with `contrastRatio` (`tokens/contrast.dart`). Roles: error `#FF6B6B`, tertiary `#B79CFF`, success `#7BD88F`, warning `#F4B860`
- **UI kit** lives in `lib/core/design/components/` with its own barrel `components.dart` (not re-exported by `design.dart`): `AppIconButton` (48 dp hit area), `GlassPanel` (optional `shape:`), `AppPill`, `AppScaffold`, `SpeechBubbleBorder`. Glass is the only surface style. The legacy `lib/core/widgets/app_icon_button.dart` must not be used in new code (M3 replaces it)
- **UI kit Rive widgets** (`lib/core/design/rive/ui_kit.dart`): `ComposerOrb`, `StatusGlow`, `ToolIcon`, `RiveToggle`, `MarkSting`, all drawn from the shared `assets/rive/ui/ui_kit.riv` and each with a Flutter fallback (shown while loading, and when the file or artboard is missing). Properties go through `RiveVmBinding` (`rive_vm_binding.dart`: typed, skips unchanged values; colours are VM writes, so a scene change never recreates a controller). Widget tests that mount them call `serveFakeRiveAssets()` (`test/helpers/rive_test_assets.dart`) and `UiKitFile.resetForTest()` in `setUp`; the real file is covered by `integration_test/ui_kit_rive_test.dart` (`-d macos`)
- **Home = the Stage** (`lib/features/home/widgets/stage/`, assembled by `widgets/home_content_stack.dart`): top chips (History, More menu), live caption (`CaptionCubit`, talking barrel: the playing TTS sentence; `enabled` is persisted), running-tool chip (`ChatState.activeTool`), `StatusGlow`, and `StageComposer` (orb = mic/send/stop). Keep the Rive scene/avatar layer free of MediaQuery and theme reads
- **Speech input**: `SpeechInputService` (`lib/core/services/speech/`) asks for the microphone on the first mic tap, never at launch; a denied or unavailable mic shows a toast, and where STT is unsupported (`isSupported` false) the idle orb focuses the text field instead. Home gets it by constructor from `app_router.dart`

### Gotchas

- Changing a freezed model or ARB file **requires regeneration** (`build_runner` / `gen-l10n`) or analysis and tests fail
- Golden tests store reference images under `test/**/goldens/` — only regenerate (`--update-goldens`) when a visual change is intentional
- Widget tests that need app styling use `AppTheme.dark`; goldens go through `GoldenTestHelper.init()` + `makeTestableWidget` + `matchGolden`
- Fonts are bundled in `assets/fonts/google_fonts/` (Fraunces 400/500/600, Manrope 400/500) and runtime fetching is off — a new font weight needs a new TTF there
- Debug-only UI lab (`/ui-lab`; Settings → "UI lab" in debug builds) previews scenes, Home layouts and composer states. VM service extensions `ext.yofardev.uiLab.open` (in `app_router.dart`), `ext.yofardev.uiLab.configure` (JSON-string params: `scene`, `layout`, `composer`, `tab`, `accentHueOverride`, `glassAlphaScale`, `radiusScaleOverride`, `panelCollapsed`, `face`, `parallax`, `prop`, `rain`, `shot`) and `ext.yofardev.uiLab.state`. `rain` (0..1) goes to `WorldStateService.setRain` (`core/services/world/`, app-lifetime lazy singleton; since M7 also fed by the weather tool and `WorldWeatherSync`) and the scene view writes it to `SceneVM.rain` on every scene load and change; `shot` (`wide|medium|closeUp|propInsert`) cuts the lab's stage camera. macOS stops rendering covered Flutter windows — keep the window unoccluded when capturing
- v4 avatar: the character and the 7 scenes (4 until M9) are Rive files in `assets/rive/`
  (`avatar.riv` + `scenes/<sceneId>.riv`), rebuilt from RML sources via
  `./scripts/frive.sh`. `rive/CONTRACT.md` is the single source of truth for
  every artboard/state-machine/view-model/event name; the Dart mirror lives
  in `lib/features/avatar/presentation/rive/avatar_rive_contract.dart`.
  Rive types must stay in `lib/features/avatar/presentation/` and
  `lib/core/design/rive/` (UI-kit Rive widgets; enforced by
  `test/architecture_test.dart`). The UI kit is `assets/rive/ui/ui_kit.riv`
  and each scene has a poster `assets/rive/posters/<sceneId>.webp` (both
  rebuilt by `frive.sh`). macOS: Impeller is disabled in
  `macos/Runner/Info.plist` (Rive crashes the Impeller Metal backend)
- No CI workflows in this repo — the quality gate is local (`./scripts/fverify.sh`)
- Face and speech (contract v6, moonshot M2–M3): `FacePerformer` (avatar domain, app-lifetime
  singleton) turns the director's emotion and the `SpeechTimeline` into one `FaceFrame` per frame
  (symmetric AUs plus per-side `left`/`right` `ActionUnitSides` offsets, written as the 14
  `au…L`/`au…R` contract numbers); `RiveAvatarView` steps it, then hands it to
  `HeadMotionSolver.followFace` (its nods and roll drive the hair follow-through `hairLag*`,
  `gazeLock`/`saccadeSerial` steer the eyes) before stepping the solver, and writes it through
  `AvatarFaceWriter`. Moods are AU presets (`core/models/performance/mood_presets.dart`); the `mood`
  enum only drives accents (blush, sweat, anger mark). Visemes come from `SpeechAnalyzer` on the TTS
  WAV, aligned to the sentence text (`TextPhonemizer`, rule-based en/fr G2P in
  `core/services/audio/g2p/`; `maxAlignCost` falls back to the audio classifier on a mismatch;
  Kokoro is deferred); `ChatTtsCubit` announces each sentence 350 ms early (`SpeechPrerollEvent`,
  with its onset viseme) for the breath, and waits that out before playing; the performer also runs
  an idle life (`idle`, off in most tests), and `TtsPlaybackService.interrupt()` (not `stop()`)
  marks a user interruption. In the Rive file the blink is a lid sweep on lid bones (`BlinkDrive`),
  the jaw drops the chin through the 3/4 outline bones, and the arms are a bone chain with skinned
  sleeves and an IK constraint (`rive/tools/arm_rig.py`; gestures key `HandTarget*`). Critic
  evidence: `tool/face_speech_trace_test.dart` (run with `flutter test`, env-var args) +
  `uv run rive/tools/review_face.py` (history gates accept ≤ 1/255 renderer noise, clamp gates are
  exact); the UI lab's `ext.yofardev.uiLab.configure` also takes a `face` JSON (every AU 0..1, side
  offsets −1..1, `lipTuck`/`tongueUp`/`breath`, `roll`, `blink`) to pose the face by hand
- Light, presence and props (contract v7, moonshot M4): one light rig per scene lives in
  `rive/tools/art_bible.py` `SCENES`, mirrored by `SceneLights.of(scene)`
  (`lib/core/design/tokens/scene_lights.dart`, colours in `AppPalette`; a Python test keeps them
  equal) and exported as `SceneVM` defaults (`check_contract.py` compares). `AvatarLightWriter`
  writes the `light*` numbers and colours to the avatar once per scene change; the firelight
  flicker loops inside the files (`lightFlicker` blend), never from Dart. The UI reads the static
  rig through `context.tokens.scene.glassTint` / `captionInk`. Presence: the composer reports to
  `ComposerActivityService` (`core/services/presence/`); `PerformanceDirector` turns it into intent
  fields (caret gaze, `lean`, backchannel `nodSerial`, `?`/`!` reactions) and owns the `prop`
  (`AvatarProp.tablet` for lookup tools and idle stages ≥ 2, `newspaper` for
  `getMostPopularNewsOfTheDay` since M5; gestures dropped while a prop is out);
  `IdleLadder` (30 s / 2 min / 10 min) freezes under battery saver (`PowerSaverSource`,
  `battery_plus`) or reduce motion. Parallax: `ParallaxSource` (`core/services/motion/`,
  accelerometer via `sensors_plus` on phones, pointer elsewhere) feeds `parallaxX/Y` to diorama
  every scene (all four are dioramas since M5; the tilt sign follows a window: right edge
  down moves the near planes right). Budget: `rml.write()` decimates linear key runs within
  `rml.TOLERANCES` for every generator; a new baked animation is thinned automatically, so check
  renders, not key counts. Evidence index: `rive/review/m4/README.md`
- Dioramas, rain, the 3/4 face (contract v8/v8b, moonshot M5): every scene registers a
  `DioramaSpec` (plane table by element root name, emissive roots, fog veils, a light hook) in
  `gen_scenes.DIORAMAS`; `Scene.write` moves the `Hit_*` zones into their planes, runs `diorama()`
  and fits every non-emissive colour (`fit_colour`), so each scene lints clean (`check_contract.py`
  runs the lint for every diorama). Evidence per scene: `uv run --with pillow --with numpy
  rive/tools/review_diorama.py <sceneId> [before.webp]`. `SceneVM.rain` (0–1) comes from
  `WorldStateService` (`core/services/world/`) through `SceneRainWriter`; campfire (streaks, wet
  ground and tent, steam off the logs, damped flare), beach and the living-room window bind it,
  deepSpace ignores it. The yaw ±1 face outline is faired in `head_turn.py` (`fair_contour`:
  convex, largest turn ≤ 1.25 × the rest outline's; `SECTION_BACK_N` ≤ 2.6, `FAR_FLAT` ≤ 0.2;
  gate `rive/tools/tests/test_head_fairing.py`). The campfire key tints the cheek
  (`KeyCheekTint`, multiply, × `lightFlicker`). New avatar ids mint from
  `avatar_kit.M5_ID_START = 1000000` (970000+ is the M3 arm skeleton); new scene ids from
  970000. Props share one put-away (~420 ms): the director holds gestures until it ends.
  Emulator frame cost: `integration_test/frame_cost_test.dart` (`flutter drive --profile -d
  <emulator>`; never the physical phone). Evidence index: `rive/review/m5/README.md`
- Weather in front, wow captures, gates (contract v9, moonshot M6): a scene file may carry a second
  artboard `SceneFront` (campfire and beach: near rain sheet, splashes, `lightFog` rain mist, all at
  opacity `rain`, ids from `gen_scenes.M6_ID_START = 950000`). `RiveSceneView` takes the avatar as
  `middle` and draws `SceneFront` above it, under `IgnorePointer`, only while rain > 0 (created
  from the already-loaded file; `SceneFrontFollower` holds the Rive-free logic); the UI lab keeps
  its avatar across scene layers with a `GlobalKey`. `./scripts/frive.sh` now ends with the
  objective gates (`rive/tools/rive_gates.py`: parallax, pointer proofs, rain, front layer per built
  scene, ~2 min each; `FRIVE_GATES=all` adds the ~23 min tablet/newspaper prop gates, run them after
  any avatar prop or gesture change; `FRIVE_GATES=0` skips). The wows are captured from the running
  macOS app by `integration_test/wow_capture_test.dart` (`--dart-define=WOW=wow1|wow2`, not in
  `fverify.sh`): in-memory prefs, no network, the debug `FakeLlmService` (tool rounds via
  `FakeLlmResponse.toolCalls`; no title call while a script plays), a canned weather tool and macOS
  `say` through `setupServiceLocator(ttsSynthesizer:, tools:)` (null in production); assembled by
  `uv run --with pillow --with numpy rive/tools/wow_capture.py <WOW_DIR> rive/review/m6/wow` (GIF,
  MP4 with sound, beats, gates). Never add a real LLM call to the harness. Evidence index:
  `rive/review/m6/README.md`
- Camera, journeys, world clock (contract v10, moonshot M7): `CameraDirector` (avatar domain, rules
  only: reduce motion → medium locked; journey / scene event → wide; prop → `propInsert`; speaking →
  cuts only at sentence starts (`CaptionEvent`) plus a slow push-in; composing / thinking → medium;
  idle → wide) is fed by `CameraFeed` (playback with a 1.5 s reply gap, intents, scene events) and by
  Home's stage widget (talking phase, reduce motion, journey). `StageCamera` (Rive-free) frames the
  shot as one `ClipRect`+`Transform` over the composited stage only (scene, avatar, journey, front;
  never the chrome); `StageFraming` holds the shot rects in the bust-framed `Avatar` artboard and the
  pan clamp; the Rive views read `StageRenderScale.of` into `RenderResolution.layout` (one texture
  size per shot, never per frame). A background change (`leaveAndComeBack` + background) is a
  journey run by `AvatarCubit` (`JourneyPhase`: pull back, open, exit, close, cut, arriveOpen, enter,
  arriveClose, vanish; timings in `JourneyTiming`; family per pair in `JourneyPlanner`: to deepSpace
  rocket, from deepSpace portal, livingRoom ↔ outdoors door, campfire ↔ beach path). `JourneyLayer`
  is the scene view's `middle`: it clips the avatar right of the threshold (artboard x 640) and draws
  the lazy `assets/rive/journeys/journey.riv` (`gen_journeys.py`, ≤ 160 KB) from
  `JourneyChoreography`. `RiveSceneView` decodes `AvatarState.preloadScene` during the walk-off and
  calls `onSceneShown` once the new file is drawn (the cut waits for it, ≤ 3 s). The world clock:
  `WorldStateService` computes `daylight` / `dusk` once a minute from `SunClock` (sun times from the
  last own-location weather report, else a 45° N month table), paused with the app; `pinClock` for
  the lab and the harness; the scene writes them to `SceneVM` (sky-plane veils in livingRoom,
  campfire, beach) and the avatar's rig leans 35 % toward day light (`SceneLights.at`). Weather: the
  tool reports own-location results only (`onOwnLocationReport`); `WorldWeatherSync` refreshes every
  30 min only with a key, an already granted location permission and battery saver off — it never
  asks. Wow #3 and the four-family tour are captured like M6 (`--dart-define=WOW=wow3|tour`).
  `frive.sh` builds the journey file and runs `review_time.py` and `review_journey.py` gates too.
  Evidence index: `rive/review/m7/README.md`
- Hands, jacket, NPCs, foley, fog (contract v11, moonshot M8): hand poses are articulation, not
  geometry (a pose copied per hand skin × side costs ~21 KB): every hand copy's `rest` group has
  five digit pivots that copy their side's driver (`rive/tools/hand_rig.py`, `HAND_POSE_DRIVERS`;
  a `HandRest` layer keys the drivers at identity, gestures key only the digits that move); the
  `back` pose is minted and dropped (= `rest`). New avatar ids mint from `avatar_kit.M8_ID_START =
  1100000` (arm-rig ids inside it from 1150000), scene ids from `gen_scenes.M8_ID_START = 930000`,
  journey ids from `gen_journeys.M8_ID_START = 5000`. Gestures `thumbsUp`, `count` (auto-acting
  on list sentences), `grab` (contact frame 23 ≈ 380 ms at the hook point (628, 560)). The jacket
  (`jacket_art.py`) is drawn by both `avatar.riv` (`AvatarVM.jacket`, held by the viewer's-right
  fist) and `journey.riv` (`JourneyVM.jacket` on the door's peg): door journeys add the `grab` and
  `hang` beats and `AvatarCubit` flips both in one state at the contact. The avatar emits `foley`
  (`kind`: step, cloth, click, paper) from timeline `KeyFrameCallback` keys; `FoleyService` and
  `AmbientBedService` (`core/services/audio/`, generated WAVs from `rive/tools/gen_foley.py` in
  `assets/foley/`) follow the sound-effects setting (`SoundEffectsSetting`). Each scene has one NPC
  (`rive/tools/scene_npc.py`: cat, owl, crab, alien; `SceneVM.npc` / `npcX` / `npcLook`) run by
  `NpcDirector` (avatar domain, pure trees; low tier holds `rest`) through `NpcFeed` and
  `SceneNpcWriter`; `SceneVM.fog` comes from the own-location weather report
  (`WeatherReport.fogIntensity` → `WorldStateService.fog`). Any city's weather lookup reaches the
  tablet card (`TabletWeatherSource` → `tabletWeather` / `tabletTemp`), never the world. The wow
  harness logs foley through `setupServiceLocator(foleyPlayer:)` and adds `WOW=npc`. Evidence
  index: `rive/review/m8/README.md`
- Seven scenes, drags, the sky's calendar (contract v12, moonshot M9): scenes 5–7 `cafe`, `rooftop`,
  `mountainHut` each live in their own generator module (`rive/tools/scene_cafe.py`,
  `scene_rooftop.py`, `scene_mountain_hut.py`, registered lazily in `gen_scenes.SCENE_BUILDERS`; each
  exports `BINDS` (the v12 members it binds) and `REVIEW` (its per-scene review config) — the review
  tools and `check_contract.py` read those, so a new scene never edits the shared tools). The shared
  world kit is `rive/tools/world_kit.py` (`DRAGS` parsed from the contract's drag table, `moon_rig`,
  `festive_lights`, `trail_dots`); existing scenes mint M9 ids from `gen_scenes.M9_ID_START = 920000`
  and declare what they bind in `gen_scenes.V12_BINDS`; `scene_art.refine_scene` knows only the four
  M8 scenes (the new modules skip it). Scenes stay bundled. Journeys: `JourneyPlanner` covers all 42
  pairs (to deepSpace rocket, from deepSpace portal, campfire ↔ beach path, every other pair door;
  no new threshold type). Drags are Flutter gestures, not Rive listeners: `SceneDragSurface` (a
  3 px-accept handle recognizer on the scene layer) → `PropDragController` (Fit.cover + plane
  parallax → artboard px, tap-after-drag filter, ends on a scene swap) → pure `PropDragPhysics`
  (pull, poke (absolute, tip box from `gen_scenes.POKE_TIP` / `POKE_RANGE`), trail, spin, aim) →
  `SceneDragWriter`; `SceneDrags` (domain) mirrors the contract table (a test parses CONTRACT.md).
  Haptics and the `bell` foley go through `FoleyService.haptic` behind the sound-effects setting (an
  impact passes the 60 ms gate after a selection click). The avatar's `RiveWidget` hit-tests
  `transparent` inside `AvatarZoneHitGate`: the avatar claims a pointer only on `HitHead` / `HitBody`
  (contract v12), the scene behind gets the rest (the eye follow's artboard-wide hit area used to
  swallow every pointer over the avatar's frame). On macOS an unfocused window pauses Rive's pointer
  handling (the integration tests pin the app to resumed). `SkyCalendar` (`core/services/world/`, pure) gives the moon phase
  (mean synodic month; `1 − p` south of the equator once an own-location report gave a latitude) and
  the festive window (1 Dec – 6 Jan); `WorldStateService.moonPhase` / `festive` → `SceneSkyWriter`.
  `SceneVM.moonPhase` −1 = the moon as drawn before v12. In December a chat in the default outfit is
  *shown* in `santaHat` + `christmasSweater` (`seasonal_wardrobe.dart` `shownWardrobe`, never saved;
  the architecture test bans the substring "Outfit" under lib/). The beach gulls are the second NPC
  slot (`npc2*`, `GullFlock`). The scene picker is the More menu's "Scenes" row
  (`ScenePickerSheet`, the same `AvatarChangeRequested` as `change_avatar`). Wow harness:
  `WOW=scene --dart-define=SCENE=<id>`, `WOW=pairs` (all 42 journeys), `WOW=tour7` (December, full
  moon). Evidence index: `rive/review/m9/README.md`
- Fresh worktree: `rive_native` host tests fail with "Failed to lookup symbol 'init'" until
  `mkdir -p build/rive_native && ln -sfn ~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/native build/rive_native/native`
  (gitignored)
- New features: use `./scripts/fgen.sh`, then wire DI (`service_locator.dart`) and route (`core/router/app_router.dart`) manually — a generated scaffold is not routed/registered until then

### Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/core/di/service_locator.dart` | All DI wiring | 447 |
| `lib/features/chat/presentation/bloc/chat_cubit.dart` | Main chat coordinator | 21.5K |
| `lib/features/chat/domain/services/chat_streaming_service.dart` | Streaming + inline tool calling | 15.6K |
| `lib/features/sound/domain/services/tts_queue_service.dart` | TTS queue | 5.5K |

### Common Operations

```dart
// Resolve a service (composition roots ONLY: service_locator.dart, app.dart,
// app_router.dart — elsewhere use constructor injection)
getIt<ServiceType>()

// State pattern (freezed)
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.success() = _Success;
  const factory ChatState.failure(String message) = _Failure;
}

// Error handling (Result<T>): classify unknown exceptions in
// repositories/datasources via mapExceptionToFailure(e, stackTrace: st,
// tag: '<ClassName>') from lib/core/errors/exception_mapper.dart; show UI text
// via localizeFailure(AppLocalizations.of(context), failure) from
// lib/core/l10n/failure_localization.dart — never display failure.message or
// e.toString().
Future<Result<Chat>> getCurrentChat();
result.when(
  err: (failure) => emit(state.copyWith(
    error: localizeFailure(AppLocalizations.of(context), failure),
  )),
  ok: (chat) => emit(state.copyWith(chat: chat)),
);
```

---

## Feature Structure

```
lib/features/
├── avatar/          # Rive avatar + scenes (see rive/CONTRACT.md)
├── chat/            # ❗ CORE: Chat, streaming, TTS
├── demo/            # Demo mode
├── home/            # Home screen (no barrel — never imported cross-feature)
├── settings/        # App configuration
├── sound/           # Sound effects
└── talking/         # Lip-sync animation
```

Each feature except `home` exposes a public API barrel at
`lib/features/<name>/<name>.dart` — cross-feature imports go through it only.

---

**Last Updated**: 2026-10-31 (M9)
