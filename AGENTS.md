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
> optimizations, 2026-10-27 Rive moonshot M0 spikes, 2026-10-29 moonshot M3, M4 and M5, 2026-10-30 M6 and M7, 2026-10-31 M8, M9 and M10, 2026-11-01 M11 and M12) and `specs/` (rive-v4
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
   A feature's barrel is its whole public API (it may re-export its
   presentation layer — that is how Home consumes features). Feature
   dependencies must stay **acyclic**; a contract two features both need goes
   into `core/repositories/`. `core/` never imports `features/` (except the
   composition roots `core/di/` and `core/router/`). The app shell lives in
   `lib/app.dart`; `lib/main.dart` is bootstrap only.
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

Note: `lib/core/repositories/` holds the shared repository contracts —
`settings_repository.dart` (consumed by `core/services/agent`),
`chat_repository.dart` (also consumed by demo) and
`global_memory_repository.dart` (also consumed by settings); keeping them in
core is what keeps feature dependencies acyclic, and core may not import
features. `AvatarRepository` (avatar) and `LocaleRepository` (settings) live in
their owning features' `domain/repositories/` — import via feature barrels.

These layering rules are **enforced by `test/architecture_test.dart`**: an
analyzer-based gate (`test/support/architecture_checker.dart`, the FlutterForge
checker with this project's documented adaptations — whole-feature barrels, the
app logger allowed in domain) plus scan rules for the fpdart ban, barrel-only
imports and the design-layer rules, so `flutter test` fails on violation.

### Conventions

- **Explicit types everywhere** (`always_specify_types: true`) — avoid `var`/inference in new code
- **Relative imports** within the package (`prefer_relative_imports`)
- **State idiom**: union states (freezed) for load-lifecycle screens, flat `copyWith` states for persistent interactive state
- **All user-facing strings** go through `AppLocalizations` — add keys with `./scripts/fstr.sh`, never edit `lib/core/l10n/generated/`
- **Never hand-edit** `*.g.dart` / `*.freezed.dart` — rerun `build_runner` after changing annotated models
- **Design layer** lives in `lib/core/design/` (import `design.dart`): read colors via `context.colors` / `context.tokens`, text via `context.text`; the accent of the current scene via `context.tokens.scene` (`accent`, `onAccent`, `glow`)
- **App theme** is Storybook night (ink `#16121D`, surface `#211B2B`, Fraunces display + Manrope body): `AppTheme.forScene(scene)` (cached per scene) and `AppTheme.dark` (= living room), built by `buildLookTheme(UiLooks.storybook, …)` in `lib/core/design/theme/app_theme.dart`; look colours live only in `AppPalette` (`AppTokens` keeps only literal black/white shadow and highlight). `lib/app.dart` feeds `AvatarState.scene` (via a `BlocSelector` around the `MaterialApp` only) into `MaterialApp.theme`, so the accent cross-fades (`AppMotion.slow`) — never rebuild the router or cubits on a scene change
- **Scene accent**: livingRoom `#F4B860`, campfire `#FF8552`, beach `#FF9478`, deepSpace `#B79CFF`, cafe `#E8956B`, rooftop `#7CB8FF`, mountainHut `#86D4C4`; `ScenePalette.fromAccent` is the single derivation rule (onAccent, glow); check pairs with `contrastRatio` (`tokens/contrast.dart`). Roles: error `#FF6B6B`, tertiary `#B79CFF`, success `#7BD88F`, warning `#F4B860`
- **UI kit** lives in `lib/core/design/components/` with its own barrel `components.dart` (not re-exported by `design.dart`): `AppIconButton` (48 dp hit area), `GlassPanel` (optional `shape:`), `AppPill`, `AppScaffold`, `SpeechBubbleBorder`. Glass is the only surface style. The legacy `lib/core/widgets/app_icon_button.dart` must not be used in new code (M3 replaces it)
- **UI kit Rive widgets** (`lib/core/design/rive/ui_kit.dart`): `ComposerOrb`, `StatusGlow`, `ToolIcon`, `RiveToggle`, `MarkSting`, all drawn from the shared `assets/rive/ui/ui_kit.riv` and each with a Flutter fallback (shown while loading, and when the file or artboard is missing). Properties go through `RiveVmBinding` (`rive_vm_binding.dart`: typed, skips unchanged values; colours are VM writes, so a scene change never recreates a controller). Widget tests that mount them call `serveFakeRiveAssets()` (`test/helpers/rive_test_assets.dart`) and `UiKitFile.resetForTest()` in `setUp`; the real file is covered by `integration_test/ui_kit_rive_test.dart` (`-d macos`)
- **Home = the Stage** (`lib/features/home/widgets/stage/`, assembled by `widgets/home_content_stack.dart`): top chips (History, More menu), live caption (`CaptionCubit`, talking barrel: the playing TTS sentence; `enabled` is persisted), running-tool chip (`ChatState.activeTool`), `StatusGlow`, and `StageComposer` (orb = mic/send/stop). Keep the Rive scene/avatar layer free of MediaQuery and theme reads
- **Speech input**: `SpeechInputService` (`lib/core/services/speech/`) asks for the microphone on the first mic tap, never at launch; a denied or unavailable mic shows a toast, and where STT is unsupported (`isSupported` false) the idle orb focuses the text field instead. Home gets it by constructor from `app_router.dart`

### Gotchas

- Changing a freezed model or ARB file **requires regeneration** (`build_runner` / `gen-l10n`) or analysis and tests fail
- Golden tests store reference images under `test/**/goldens/` — only regenerate (`--update-goldens`) when a visual change is intentional
- Widget tests that need app styling use `AppTheme.dark`; goldens go through `GoldenTestHelper.init()` + `makeTestableWidget` + `matchGolden`
- Fonts are bundled in `assets/fonts/google_fonts/` (Fraunces 400/500/600, Manrope 400/500) and runtime fetching is off — a new font weight needs a new TTF there
- Debug-only UI lab (`/ui-lab`; Settings → "UI lab" in debug builds) previews scenes, Home layouts and composer states. VM service extensions `ext.yofardev.uiLab.open` (in `app_router.dart`), `ext.yofardev.uiLab.configure` (JSON-string params: `scene`, `layout`, `composer`, `tab`, `accentHueOverride`, `glassAlphaScale`, `radiusScaleOverride`, `panelCollapsed`, `face`, `parallax`, `prop`, `rain`, `shot`, `topTint`, `hatTint`, `tier` (low|high|ultra|auto: `QualityTierService.forceTier`), `spring`, `autumn` (0..1, null = the calendar), `wind` (0..1, null = unknown)) and `ext.yofardev.uiLab.state`. `rain` (0..1) goes to `WorldStateService.setRain` (`core/services/world/`, app-lifetime lazy singleton; since M7 also fed by the weather tool and `WorldWeatherSync`) and the scene view writes it to `SceneVM.rain` on every scene load and change; `shot` (`wide|medium|closeUp|propInsert`) cuts the lab's stage camera. macOS stops rendering covered Flutter windows — keep the window unoccluded when capturing
- v4 avatar: the character and the 10 scenes (4 until M9, 7 until M11) are Rive files in `assets/rive/`
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
  Kokoro's sherpa-onnx API exposes no phoneme timings, so the same analysis runs on its WAVs); `ChatTtsCubit` announces each sentence 350 ms early (`SpeechPrerollEvent`,
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
- Wardrobe 2.0, persona body language, speech bubbles (contract v13, moonshot M10): the wardrobe is
  deduped after the avatar is built (`rive/tools/wardrobe_dedupe.py`): one sleeve set per sleeve kind
  and one shared hand (`Skin_shared`), each outfit's paint / opacity / seam thickness keyed in its
  `top_*` or `costume_*` clip (the hand's paint in every costume clip, `costume_none` included); the
  pass refuses to merge copies that differ in anything else. Identity to M9 is the gate
  (`uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py`, 277 cases). Colour
  variants: `topTint` / `hatTint` colours bound to a second color-blend (27) `Tint` fill on the listed
  garment shapes (`TOP_TINTED`, `SLEEVE_TINTED`, `HAT_TINTED` in `gen_avatar.py`; never ink, prints,
  skin, costumes); Dart `AvatarTint` + `WardrobeTints` (`core/design/tokens/`, the palette of record),
  stored under the map keys `topTint` / `hatTint` (missing = none), written transparent under a
  costume (`AvatarTintWriter`). `gestureId` `signature` plays the worn costume's move (transitions
  check gestureId and costume); `AvatarCubit` requests it once after a walk-off puts a new costume on;
  it is not an LLM cue. New avatar ids from `avatar_kit.M10_ID_START = 1200000` (tints 1210000,
  signatures 1220000, their arm keys 1235000); scene ids from `gen_scenes.M10_ID_START = 910000`.
  Personas: `BodyLanguageProfile.of(ChatPersona)` (`core/models/performance/body_language.dart`;
  `normal` is the identity) reaches `AvatarCueService` through `AppLifecycleService.personaEvents`
  (the current chat's persona) and arms the director (gesture rate, auto-gesture swaps, idle prop,
  glance period; applied at the next sentence), `FacePerformer` (posture eased 600 ms, motion scale)
  and the `IdleLadder` pace; trace: `flutter test tool/body_language_trace_test.dart`. Captions: the
  avatar file's `MouthAnchor` node (on the upper-lip bone) is read after each advance
  (`MouthAnchorReader` → `MouthAnchorSource`), mapped by `StageFraming.artboardToStage` through the
  avatar fit and `StageCameraView`; `StageCaptionBubble` sits beside the face or over the head with a
  brows-to-chin keep-out, follows at 8 Hz, and hands over to the classic `StageCaption` for screen
  readers, text scale ≥ 1.5, journeys, prop inserts, no anchor or no fit; reduce motion places it once
  per sentence. `SceneVM.night` = (1 − daylight) × (1 − dusk) (0 without a world clock); only the beach
  binds it. Wow harness: `WOW=wardrobe|persona|caption` (contact sheet + one short MP4, no GIF).
  Evidence index: `rive/review/m10/README.md`
- Scenes 8–10, quality tiers, seasons, accessibility (contract v14, moonshot M11): `forestCabin`
  (`scene_forest_cabin.py`; squirrel, `pinwheel` spin, `SceneFront`), `trainCompartment`
  (`scene_train.py`; the landscape scrolls on seamless tiles in the window, ladybug, `chain` pull →
  `whistle`), `library` (`scene_library.py`; storm window, mouse, `ladder` aim); each module exports
  `BINDS`, `BINDS14` (its v14 binds), `REVIEW` and `TIER_GATES`. Journeys over 90 pairs (path among
  campfire / beach / forestCabin). Legacy `library` → library, `forest` → forestCabin. **Tiers:**
  `QualityTierService` gives the effective tier = min(benchmark, thermal cap, battery-saver cap, drift
  cap); the benchmark (M0 probe, bench version 2) waits for the stage's first scene and for no cap or
  force; `ThermalSource` is the `yofardev/thermal` channel (Android `PowerManager`, Apple
  `ProcessInfo.thermalState`; moderate → one tier below, severe / critical → low, lifts after 120 s);
  `FrameDriftWatch` drops one tier for the session after three 10 s windows over budget × 1.25 (paused
  under a thermal cap, reset on a tier change). Budgets `QualityTier.frameBudgetMs` 16.7 / 11.1 /
  8.3 ms. `SceneVM.tier` (default ultra = the v13 look) is written by `SceneTierWriter`; the shared
  pass `world_kit.tier_gate` hides each scene's `TIER_GATES` names (high: dense FX halves; low: also
  ambient loops, fog veils to one fill). Low in the app: no `SceneFront`, no parallax, no camera creep,
  tints transparent, the bubble placed once per sentence; the anchor is read every frame (ultra),
  every 2nd (high), once per sentence (low). CLI bench: `uv run rive/tools/rive_bench.py` (gate in
  `rive_gates.py`: low ≤ 0.8 × ultra render p95, best run, load-aware). Frame cost per scene × tier:
  `integration_test/frame_cost_test.dart` (`TIERS`, `SECONDS`, `PHASE=battery`), steps in
  `rive/review/m11/device/README.md`. **Seasons:** `SkyCalendar.season` (meteorological, 7-day ramps,
  south swaps) → `WorldStateService.spring` / `autumn` → `SceneSeasonWriter`; forestCabin, campfire,
  livingRoom, trainCompartment bind them. Wind: `WeatherReport.windIntensity` (`wind.speed` / 12) →
  `WorldStateService.wind` → the wind bed (`assets/foley/bed_wind.wav`; scene base × (0.5 + 0.5 ×
  wind); `gust` swells it). **Accessibility:** `StageSemantics` (one node: scene + phase; a custom
  action per prop and drag handle via `tapProp` / `PropDragController.performAccessibilityAction`;
  the Rive layers are excluded), `ReduceMotionSource` (`core/services/motion/`, followed live), reduced
  journeys = a 200 ms dip-cut (`JourneyState.reduced`), `GlassPanel` opaque under high contrast,
  haptics only through `FoleyService` (`test/haptics_path_test.dart`). Evidence index:
  `rive/review/m11/README.md`
- Polish and the last gates (moonshot M12, contract v14 unchanged): **a key's ease must live in the key's
  own artboard** (Rive resolves `interpolatorId` per artboard; the `SceneFront` splashes were silently
  dropped M6–M11 because their keys used the `Scene` artboard's ease): `Scene._own_eases` copies them
  (`Scene.d12`, shared M12 ids from `gen_scenes.M12_ID_START = 890000`; module M12 ids from 880000 via
  `scene_npc.own_m12`), and a pytest checks every artboard; `integration_test/front_splash_test.dart`
  (macOS) checks the splashes in in-app grabs. **NPC drawing copies switch on their own 0 ms layer**
  (`scene_npc.draw_layer` → `NpcDraw` / `Npc2Draw`) while poses blend 200 ms on `Npc`: never key a copy's
  opacity in a pose animation (it ghosts through the blend). The bench gate (`rive_bench.py`) re-measures
  a failing scene once after the load wait and writes to `--out` (default `rive/review/m12/perf/`). The
  frame-cost harness takes `SCENES=` (narrow) and `REPS=` (alternate dry / rain passes; compare medians
  within one run). The front layer (a second Rive render target) stays at high and ultra; its emulator
  cost is intermittent, the owner's phone run decides (`rive/review/m12/device/README.md` § 1b). The final
  wows: `wow_capture_test.dart --dart-define=TIER=ultra|low` (wow1 pinned to 22:00), assembled without a
  GIF; `rive/tools/wow_compare.py` writes the then-vs-now sheets. Moonshot report:
  `rive/review/m12/README.md`
- Storybook threshold (contract v15, 2026-11-06): the `door` journey family is now the pop-up
  **book** (`JourneyFamily.book`; 66 of the 90 pairs, the planner's other rulings unchanged) —
  `journey.riv` gains `book`, `unfold` (the riffle + the pop-up vignette; the other thresholds
  ignore it) and one `dest<Scene>` per scene (exactly one nonzero: the vignette and the closed
  cover's foil medallion show that scene — the destination on the exit side, the origin from the
  cut on) plus `vignetteKey` / `vignetteAmbient` (the card glows in the OTHER scene's rig; the
  book's own rim keeps `lightKey` / `lightAmbient`). The staging is app-side in
  `JourneyChoreography` (`JourneyTiming` holds the windows): open = crack (a slow barely-open
  sliver) → cover swing around the spine (edge-on glint, lands 1010 ms) → riffle (from 850 ms,
  overlapping the swing's tail) → panels and hero card erect (fully landed at unfold 0.89, so the
  grab/exit rows snapping `unfold` to 1 change nothing); close = a 200 ms fold flutter → cover
  fall with a rebound; the arrival swing runs hold → 450 ms without the crack. Foley rides the
  book's beats through `AvatarCubit`'s optional `FoleyService` (paper 850 ms into open, click
  580 ms into close, paper 470 ms into arriveOpen; reduced journeys stay quiet). The jacket hangs
  on the **ribbon** now — it replaces the door's peg at the same hook point (628, 560), the
  grab/hang beats unchanged. Book ids mint from `gen_journeys.V15_ID_START = 6000` (the v10 door
  ids stay unused). The rive CLI stays pinned 1.8.x via the `~/.rive/bin/rive` shim (1.9+
  watermarks local builds until a `rive push` bind; pre-1.9 binaries self-block on a newer
  manifest). The wow harness gates assert family `book`. Evidence (strips, beats, gates, wow3 +
  the four-family tour): `rive/review/book-threshold/`
- Thresholds polish (contract v15 names, v16 notes, 2026-11-07): path, portal and rocket redrawn in
  `gen_journeys.py` from `V16_ID_START = 30000` (the book's page face and cover details too, via
  `book_polish`, so the book's v15 ids stay). The portal tears open (`portal` bump), its vortex irises
  with `open`, comets are `TrimPath` offsets on the loop (the seam test allows whole laps). The path is
  a scalloped thicket (`scalloped`, `fern`) with a lantern and a lit tunnel. `vignetteKey` /
  `vignetteAmbient` are now written for EVERY family (`JourneyLayer`: the scene not on screen), lighting
  the portal core, the path's far end and the rocket's porthole. Rocket staging is app-side: it lands
  with `lift` in the open beat before boarding (hatch from 750 ms), lifts off with `_LiftOffCurve`
  (`JourneyTiming.liftOff` 1000 ms, the first `ignition` 350 ms crawling through the file's 0–0.02
  rumble/smoke band), and takes off empty in `vanish` (`JourneyTiming.vanishOf`). Evidence:
  `rive/review/thresholds-v16/`
- The avatar goes in (contract v17 notes, 2026-11-07): `JourneyLayer` draws the path, portal and
  rocket UNDER the avatar (the book over it only mid-passage — while the avatar folds into its
  gutter, `JourneyLayer.thresholdOverAvatar`; otherwise under, so the standing avatar's phase
  bubble overlays the open book) and paints the avatar through
  `AvatarPassageBox` (clip, transform, opacity, colour filter; layers only while they act). The
  passage is pure Dart: `JourneyPassage.of(family, u, x)` with `u` on the beat's clock
  (`exitWindow` / `enterWindow`, ~1 s of the 1.6 s walk) and `x` from `PresenceWalk` (a mirror of
  `gen_avatar.walk_tracks`): portal pull + anticlockwise spin + glow in the far scene's key, path
  recession + silhouette, rocket shrink + hop onto the hatch sill + clip to the opening, book fold.
  Its points mirror `gen_journeys.py` (`test_journeys.py::test_the_passage_mirrors_the_journey_geometry`).
  **Never stop painting the avatar** (no early return at opacity 0, no singular transform): the Rive
  avatar advances only while painted, and a paused avatar never sends `presence_done`. Evidence:
  `rive/review/avatar-inside/`
- TTS (Kokoro, 2026-11-01): the default voice is Kokoro-82M v1.0 int8 through `sherpa_onnx`
  **pinned 1.13.3** (all eight `sherpa_onnx_*` platform packages pinned in `dependency_overrides`):
  2.x dropped espeak-ng, and 1.13.3 is the last release whose bundled ONNX Runtime (1.24.3 on
  Android) exists on Maven, so `android/app/build.gradle` forces
  `com.microsoft.onnxruntime:onnxruntime-android:1.24.3` for `flutter_onnxruntime` (Supertonic) and
  picks one `libonnxruntime.so` — both sides must load the same version-tagged ORT, or the APK
  fails to package / link. Never bump either side alone. The model (~132 MB) is downloaded once from
  GitHub releases (k2-fsa/sherpa-onnx `tts-models`) into `<appSupport>/tts/<modelId>/`
  (`KokoroModelStore`) and loaded by `KokoroTtsService` (`TtsEngineStatusService`, sound barrel);
  status shows in Settings (`TtsVoiceStatusTile`) and on Home (`StageVoiceNotice`). French =
  a male-leaning blend, 30 % `ff_siwis` + 70 % `im_nicola` (median pitch ~125 Hz vs 204 Hz for
  `ff_siwis` alone), written by `KokoroVoiceBlender` into the unused `voices.bin` slot 50
  (`zm_yunxi`; `KokoroModelSpec.voiceBlendSlot`, sid = the slot) after each install and before the
  engine loads (idempotent via a `.voice-blend` marker holding the recipe, so existing installs
  get it without a re-download; change the recipe and it is re-applied), with espeak voice **`fr`**
  (`fr-fr` is not a voice file, and sherpa aborts the process on an unknown voice), English =
  `am_michael` (sid 16, male, ~117 Hz median; was `af_heart` until 2026-11-07) with the US lexicon. Output is
  peak-normalized (`normalizePeak`, Kokoro speaks at ~half scale). `FallbackTtsSynthesizer`
  speaks Supertonic (`TtsDatasource`) while Kokoro is not ready, for other languages, or when a
  sentence fails — **Android only**: on macOS/iOS flutter_onnxruntime's ORT 1.28 wrapper binds to
  sherpa's ORT 1.24 dylib and segfaults in `Ort::Env`, so there those sentences stay text-only. Real-engine check: `flutter test integration_test/kokoro_tts_test.dart -d macos`
  (not in `fverify.sh`). The pure-Dart sherpa example must never load the pub-cache dylib directly
  on macOS (an aborted run left the file un-rsync-able by Xcode; `rm -rf` the package and
  `flutter pub get` fixes it)
- Costume voice effects live in `core/services/audio/voice_fx/` (`VoiceFx`: pure Dart,
  duration-preserving, Batman and RoboCop only, picked by `AvatarCostume.voiceEffect`; tuning
  constants at the top of `voice_fx.dart`); `VoiceEffectsService` writes `<name>_fx.wav` next to
  the dry WAV, and the speech analysis reads the dry WAV via `TtsQueueService.peekAnalysisPath`
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

**Last Updated**: 2026-11-02 (analyzer-based architecture gate from
FlutterForge, shared repository contracts in `core/repositories/`)
