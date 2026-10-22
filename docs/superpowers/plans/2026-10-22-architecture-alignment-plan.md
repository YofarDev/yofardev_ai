# Architecture Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the codebase with the `flutter-architecture` skill: fix dependency direction, DI composition-root discipline, typed localized error handling, and backfill the enforcing tests.

**Architecture:** Incremental refactor in 5 phases (registration/lifecycle → boundaries → error handling → state polish → tests/checker). Every task leaves the app compiling and `./scripts/fverify.sh` green. No behavior changes except where the spec names them (dead-code removal, localized error text).

**Tech Stack:** Flutter (Dart SDK >=3.8.0), flutter_bloc 9 (Cubit), freezed 3, get_it 9, go_router 17, mocktail, `Result<T>` (project-local, replaces fpdart — banned).

**Spec:** `docs/superpowers/plans/2026-10-22-architecture-audit.md` (findings + deliberate non-changes; read before executing)

## Global Constraints

- **Not a git repository.** Each task ends with the quality gate instead of a commit: `dart fix --apply && dart format . && ./scripts/fverify.sh`. If the user initializes git mid-plan, also commit after each task.
- Errors: `Result<T>` from `lib/core/models/result.dart` (`Result.ok` / `Result.err(Failure)`). **Never** fpdart/dartz, never `try/catch` returning `null`.
- Failure variants: `StorageFailure`, `NetworkFailure`, `TtsFailure`, `ConfigFailure`, `UnknownFailure` — all `const X(message, [cause])` from `lib/core/models/failure.dart`.
- Explicit types everywhere (`always_specify_types: true`); relative imports in `lib/` (`prefer_relative_imports`); tests use `package:yofardev_ai/...` imports.
- After editing any `@freezed` file: `dart run build_runner build --delete-conflicting-outputs` before `fverify`.
- New ARB keys only via `./scripts/fstr.sh "key" "FR" "EN"` (lowerCamelCase key).
- `core/` never imports `features/` (composition roots `core/di/`, `core/router/`, `app.dart` excepted); cross-feature imports go through `lib/features/<name>/<name>.dart` barrels only.
- Allowed `getIt` resolution sites after this plan: `lib/core/di/service_locator.dart`, `lib/app.dart`, `lib/core/router/app_router.dart` only.
- DI lifetimes: cubits `registerFactory`, shared state services `registerLazySingleton` — preserve each registration's existing kind.

---

## Phase 1 — Registration & Lifecycle Integrity

### Task 1: Inject `DemoService` into `ChatCubit`; await teardown; delete dead `switchLlmService`

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (imports, constructor ~lines 24-47, `_handleDemoScriptChangedEvent` ~line 166, `close()` ~lines 186-190)
- Modify: `lib/core/di/service_locator.dart` (ChatCubit registration lines 256-266; delete lines 283-298)

**Interfaces:**
- Consumes: `DemoService` (`lib/features/demo/domain/services/demo_service.dart`, already exported by `lib/features/demo/demo.dart`; `Future<void> activateDemo({required String chatId, required DemoScript script})`).
- Produces: `ChatCubit({..., required DemoService demoService})` — Task 2 and the DI registration rely on this.

- [ ] **Step 1: Update `ChatCubit` constructor and field**

In `chat_cubit.dart`, the file already imports `'../../../demo/demo.dart'` — add `demoService` to the constructor:

```dart
  ChatCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AvatarAnimationService avatarAnimationService,
    required ChatTitleService chatTitleService,
    required ChatStreamingService chatStreamingService,
    required AppLifecycleService appLifecycleService,
    required GlobalMemoryService globalMemoryService,
    required DemoService demoService,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       _chatTitleService = chatTitleService,
       _chatStreamingService = chatStreamingService,
       _appLifecycleService = appLifecycleService,
       _globalMemoryService = globalMemoryService,
       _demoService = demoService,
       super(ChatState.initial()) {
```

Add the field next to the other private fields:

```dart
  final DemoService _demoService;
```

- [ ] **Step 2: Use the field and drop the getIt import**

In `_handleDemoScriptChangedEvent` replace `final DemoService demoService = getIt<DemoService>();` and the two `demoService.` references below it with `_demoService.`. Delete the import `'../../../../core/di/service_locator.dart';` (line 166 was the only `getIt` use — verified).

- [ ] **Step 3: Await teardown in `close()`**

```dart
  @override
  Future<void> close() async {
    await _newChatEntrySubscription?.cancel();
    await _demoScriptSubscription?.cancel();
    await _avatarChangeRequestedSubscription?.cancel();
    return super.close();
  }
```

- [ ] **Step 4: Update DI and delete dead code**

In `service_locator.dart`, add to the `ChatCubit` factory (Task 6 will touch this file again — keep changes local):

```dart
  getIt.registerFactory<ChatCubit>(
    () => ChatCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      avatarAnimationService: getIt<AvatarAnimationService>(),
      chatTitleService: getIt<ChatTitleService>(),
      chatStreamingService: getIt<ChatStreamingService>(),
      appLifecycleService: getIt<AppLifecycleService>(),
      globalMemoryService: getIt<GlobalMemoryService>(),
      demoService: getIt<DemoService>(),
    ),
  );
```

Delete the whole `switchLlmService` function (lines ~283-298, including its doc comment) — zero callers (verified by `rg -n "switchLlmService" lib test`).

- [ ] **Step 5: Fix constructor call sites in tests, then gate**

Run `rg -n "ChatCubit(" test -g '*.dart'` and add `demoService: <value>` to every construction. `test/features/chat/chats_cubit_test.dart` already imports the demo barrel; use a `MockDemoService extends Mock implements DemoService {}` (create it beside the file's existing mocks; no stubs needed unless a test triggers `_handleDemoScriptChangedEvent` — stub `activateDemo` with `when(() => mock.activateDemo(chatId: any(named: 'chatId'), script: any(named: 'script'))).thenAnswer((_) async {});` in those tests only).

Run: `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS (all tests + analyze).

### Task 2: `DemoCubit.startDemoMode` replaces screen-level `getIt<DemoService>`

**Files:**
- Modify: `lib/features/demo/presentation/bloc/demo_cubit.dart` (whole file, 49 lines)
- Modify: `lib/features/home/screens/home_screen.dart` (`_startDemoMode` ~lines 71-78)
- Modify: `lib/core/di/service_locator.dart` (DemoCubit registration line 267)
- Test: `test/features/demo/demo_cubit_test.dart` (new — full test in Task 19; here only what this task changes)

**Interfaces:**
- Consumes: `DemoService.activateDemo({required String chatId, required DemoScript script})` from Task 1's barrel; `DemoCubit.startDemo(DemoScript script)` (existing).
- Produces: `DemoCubit({required DemoController demoController, required DemoService demoService})` and `Future<void> startDemoMode({required String chatId, required DemoScript script})`.

- [ ] **Step 1: Extend `DemoCubit`**

```dart
class DemoCubit extends Cubit<DemoState> {
  DemoCubit({
    required DemoController demoController,
    required DemoService demoService,
  }) : _demoController = demoController,
       _demoService = demoService {
    _demoController.addListener(_onControllerChanged);
  }

  final DemoController _demoController;
  final DemoService _demoService;
```

Add the coordination method (service call lives in the cubit; widget stays a pure consumer):

```dart
  /// Activate demo mode on the service, then reflect it in state.
  Future<void> startDemoMode({
    required String chatId,
    required DemoScript script,
  }) async {
    await _demoService.activateDemo(chatId: chatId, script: script);
    startDemo(script);
  }
```

Change `close()` to await the listener removal is unnecessary (`removeListener` is sync) — keep it, only fix formatting:

```dart
  @override
  Future<void> close() {
    _demoController.removeListener(_onControllerChanged);
    return super.close();
  }
```

- [ ] **Step 2: Rewire `home_screen.dart`**

Replace `_startDemoMode`'s body:

```dart
  Future<void> _startDemoMode() async {
    final String chatId = context.read<ChatCubit>().state.currentChat.id;
    await context
        .read<DemoCubit>()
        .startDemoMode(chatId: chatId, script: DemoScripts.beachDemo);
  }
```

Remove `lib/features/home/screens/home_screen.dart`'s `getIt`/service_locator import if nothing else in the file uses it (check `rg -n "getIt" lib/features/home/screens/home_screen.dart` → must be 0 after this).

- [ ] **Step 3: Update DI**

```dart
  getIt.registerFactory<DemoCubit>(
    () => DemoCubit(
      demoController: getIt<DemoController>(),
      demoService: getIt<DemoService>(),
    ),
  );
```

- [ ] **Step 4: Gate**

Run `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 3: `FloatingStopButton` gets `InterruptionService` via `RepositoryProvider`

**Files:**
- Modify: `lib/app.dart` (providers list lines 23-44)
- Modify: `lib/features/chat/widgets/floating_stop_button.dart` (whole file, 78 lines)
- Modify: `test/features/chat/widgets/floating_stop_button_test.dart` (wrap test trees)

**Interfaces:**
- Consumes: `InterruptionService` (`lib/core/services/audio/interruption_service.dart`, `void interrupt()`, registered lazySingleton).
- Produces: `FloatingStopButton` depends on `InterruptionService` from context — no constructor change (`const` preserved at both creation sites: `chat_details_screen.dart:105`, `home_content_stack.dart:59`).

- [ ] **Step 1: Provide the service in the app shell**

In `app.dart`, add to the `providers` list (flutter_bloc's `RepositoryProvider` is a `SingleChildWidget`, so it slots into the existing `MultiBlocProvider`):

```dart
        RepositoryProvider<InterruptionService>(
          create: (BuildContext context) => getIt<InterruptionService>(),
        ),
```

Add import `import 'core/services/audio/interruption_service.dart';`.

- [ ] **Step 2: Simplify the widget**

Delete `_resolveInterruptionService` and the `service_locator` + `logger` imports. Replace the onPressed:

```dart
                  onPressed: () => context.read<InterruptionService>().interrupt(),
```

Add import `import '../../../../core/services/audio/interruption_service.dart';`.

- [ ] **Step 3: Update the widget test**

In `floating_stop_button_test.dart`, every tree that pumps `FloatingStopButton` must wrap it in `RepositoryProvider<InterruptionService>(create: (_) => <existing mock or real instance>, child: ...)`. The test file already imports `InterruptionService` — reuse its existing mock/instance; add `import 'package:flutter_bloc/flutter_bloc.dart';` if missing.

- [ ] **Step 4: Gate**

Run `rg -n "getIt" lib/features/chat/widgets/floating_stop_button.dart` → 0 matches, then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 4: LLM settings pages go through `SettingsCubit`

**Files:**
- Modify: `lib/features/settings/presentation/bloc/settings_state.dart` (add one field, then build_runner)
- Modify: `lib/features/settings/presentation/bloc/settings_cubit.dart` (new methods; ~5 lines in `loadSettings`)
- Modify: `lib/features/settings/screens/llm/llm_selection_page.dart` (remove field + `_loadConfigs`, use state)
- Modify: `lib/features/settings/screens/llm/llm_config_page.dart` (same treatment)

**Interfaces:**
- Consumes: `LlmServiceInterface` (`lib/core/services/llm/llm_service_interface.dart`): `Future<void> init()`, `List<LlmConfig> getAllConfigs()`, `LlmConfig? getCurrentConfig()`, `Future<void> deleteConfig(String id)`, `Future<void> setCurrentConfig(String id)`, `Future<void> saveConfig(LlmConfig config)`. `SettingsState` already has `availableLlmConfigs`.
- Produces: `SettingsState.selectedLlmConfigId` (`String?`); `SettingsCubit.refreshLlmConfigs()`, `deleteLlmConfig(String id)`, `setCurrentLlmConfig(String id)`, `saveLlmConfig(LlmConfig config)`.

- [ ] **Step 1: Add the state field**

In `settings_state.dart`, inside the factory params next to `availableLlmConfigs`:

```dart
    @Default(null) String? selectedLlmConfigId,
```

Then `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Add cubit methods**

In `settings_cubit.dart` (the class already has `_llmService`):

```dart
  /// Initialize the LLM config manager and refresh config-derived state.
  Future<void> refreshLlmConfigs() async {
    await _llmService.init();
    final List<LlmConfig> configs = _llmService.getAllConfigs();
    final String? selectedId = _llmService.getCurrentConfig()?.id;
    emit(
      state.copyWith(
        availableLlmConfigs: configs,
        selectedLlmConfigId: selectedId,
      ),
    );
  }

  Future<void> deleteLlmConfig(String id) async {
    await _llmService.deleteConfig(id);
    await refreshLlmConfigs();
  }

  Future<void> setCurrentLlmConfig(String id) async {
    await _llmService.setCurrentConfig(id);
    await refreshLlmConfigs();
  }

  Future<void> saveLlmConfig(LlmConfig config) async {
    await _llmService.saveConfig(config);
    await refreshLlmConfigs();
  }
```

In `loadSettings()`, replace the existing "Load available LLM configs" try/catch block with `await refreshLlmConfigs();` wrapped in the same try/catch shape (keep the existing `AppLogger.error` + `hasError: true` emit on failure).

- [ ] **Step 3: Rewrite `llm_selection_page.dart` as a pure consumer**

- Delete `final LlmServiceInterface _llmService = getIt<LlmServiceInterface>();` and the service_locator import.
- Replace `_loadConfigs()` in `initState` with `context.read<SettingsCubit>().refreshLlmConfigs();`.
- Delete local `_configs` / `_selectedId` state; wherever they were read, read `context.watch<SettingsCubit>().state.availableLlmConfigs` and `.selectedLlmConfigId` instead.
- Replace `await _llmService.deleteConfig(config.id);` with `await context.read<SettingsCubit>().deleteLlmConfig(config.id);`
- Replace `await _llmService.setCurrentConfig(id);` with `await context.read<SettingsCubit>().setCurrentLlmConfig(id);`

- [ ] **Step 4: Same treatment for `llm_config_page.dart`**

- Delete the `_llmService` field + service_locator import.
- `initState`: `context.read<SettingsCubit>().refreshLlmConfigs();`
- Replace `final List<LlmConfig> allConfigs = _llmService.getAllConfigs();` with `final List<LlmConfig> allConfigs = context.read<SettingsCubit>().state.availableLlmConfigs;`
- Replace `await _llmService.saveConfig(newConfig);` with `await context.read<SettingsCubit>().saveLlmConfig(newConfig);`

- [ ] **Step 5: Gate**

Run `rg -n "getIt" lib/features/settings/screens/llm/` → 0 matches, then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 5: Constructor-inject `AppLifecycleService` into `AvatarTool`

**Files:**
- Modify: `lib/core/services/agent/avatar_tool.dart` (lines 11-13)
- Modify: `lib/core/services/agent/tool_registry.dart` (lines 25 and 60 construct `AvatarTool()`; constructor area ~line 17 and ~54)
- Modify: `lib/core/di/service_locator.dart` (ToolRegistry registration line 129)

**Interfaces:**
- Consumes: `AppLifecycleService.emitAvatarChangeRequested(AvatarChangeRequested ...)` (existing call unchanged).
- Produces: `AvatarTool(this.appLifecycleService)`; `ToolRegistry({required AppLifecycleService appLifecycleService})`.

- [ ] **Step 1: Change `AvatarTool`**

```dart
class AvatarTool extends AgentTool {
  AvatarTool(this._appLifecycleService);

  final AppLifecycleService _appLifecycleService;
```

Replace the getter `AppLifecycleService get _appLifecycleService => getIt<AppLifecycleService>();` and delete the `'../../di/service_locator.dart';` import. All `_appLifecycleService` uses in `execute` stay as-is.

- [ ] **Step 2: Thread through `ToolRegistry`**

Add a constructor field (merge with the existing constructor at ~line 54 if one already takes parameters — do not create a second constructor):

```dart
  ToolRegistry({required AppLifecycleService appLifecycleService})
      : _appLifecycleService = appLifecycleService;

  final AppLifecycleService _appLifecycleService;
```

Replace both `AvatarTool()` sites with `AvatarTool(_appLifecycleService)`. If the site at line 25 is inside a `static`/top-level list, make that method take `AppLifecycleService` as a parameter instead and pass it down from the instance.

- [ ] **Step 3: Update DI**

```dart
  getIt.registerLazySingleton<ToolRegistry>(
    () => ToolRegistry(appLifecycleService: getIt<AppLifecycleService>()),
  );
```

- [ ] **Step 4: Gate**

Run `rg -n "getIt" lib/core/services/agent/avatar_tool.dart` → 0, then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS. (Agent tool tests in `test/core/services/agent/` construct services directly; fix any `AvatarTool()`/`ToolRegistry()` calls the analyzer reports.)

### Task 6: `bootstrapApp()` — stop `main.dart` importing feature data

**Files:**
- Modify: `lib/core/di/service_locator.dart` (new function after `setupServiceLocator`)
- Modify: `lib/main.dart` (whole file, 57 lines)
- Modify: `lib/app.dart` (remove dead `initialLanguage`, lines 17-19)

**Interfaces:**
- Consumes: `getIt<ChatLocalDatasource>().init()` (data migration), `TtsDatasource.initSupertonic()` (static warmup), `PlatformUtils` (`lib/core/utils/platform_utils.dart`).
- Produces: `Future<void> bootstrapApp()` exported from `service_locator.dart`; `App` becomes `const App()`.

- [ ] **Step 1: Add `bootstrapApp` to `service_locator.dart`** (composition root — allowed to import features)

```dart
/// Post-registration bootstrap: data migrations and optional warmup.
/// Lives here (not in main.dart) so main.dart never imports feature internals.
Future<void> bootstrapApp() async {
  // Run chat data migration (previously called from main.dart).
  await getIt<ChatLocalDatasource>().init();

  // Optional TTS warmup: startup must never be blocked by it.
  if (PlatformUtils.checkPlatform() != 'Web' &&
      PlatformUtils.checkPlatform() != 'MacOS') {
    unawaited(
      TtsDatasource.initSupertonic().catchError((Object error, StackTrace st) {
        // Startup should never be blocked by optional TTS warmup.
      }),
    );
  }
}
```

Add `import 'dart:async';` and the two feature datasource imports to service_locator.dart (move them from main.dart).

- [ ] **Step 2: Slim `main.dart`**

Delete: the `chat_local_datasource` and `tts_datasource` imports, the `getIt<ChatLocalDatasource>().init()` line, the `TtsDatasource.initSupertonic` block, and the SharedPreferences language block (lines 37-41 + 48-55's TTS block + the `initialLanguage` variable). Delete the now-unused `shared_preferences` import. Final shape:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  await bootstrapApp();
  if (PlatformUtils.isDesktop()) {
    // ... existing window_manager block unchanged ...
  }
  if (PlatformUtils.isMobile()) {
    await Alarm.init();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
  runApp(const App());
}
```

- [ ] **Step 3: Remove the dead `App.initialLanguage`** (`rg -n "initialLanguage" lib test` shows no reader — verified). Delete the field/param in `app.dart`; no test constructs `App(...)` (verified). Locale until `loadSettings()` lands comes from `SettingsState.currentLanguage` default (`'fr'`) — same as today, since the field was never read.

- [ ] **Step 4: Gate**

Run `rg -n "features/" lib/main.dart` → 0 matches, then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

---

## Phase 2 — Layer & Module Boundaries

### Task 7: Remove the domain→presentation import in `avatar_animation.dart`

**Files:**
- Modify: `lib/features/avatar/domain/models/avatar_animation.dart` (line 4)

**Interfaces:** none changed — `AvatarAnimation` public API is untouched.

- [ ] **Step 1: Delete the import and reword the doc link**

Remove `import '../../presentation/bloc/avatar_state.dart';`. Reword the doc comment so it no longer needs a link into presentation:

```dart
/// Events that trigger avatar animations.
///
/// These events are emitted by [AvatarAnimationService] and consumed by the
/// avatar cubit to coordinate avatar animations across features.
```

- [ ] **Step 2: Gate** — `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 8: `TtsSynthesizer` interface breaks the domain→data dependency in sound

**Files:**
- Create: `lib/features/sound/domain/services/tts_synthesizer.dart`
- Modify: `lib/features/sound/data/datasources/tts_datasource.dart` (class declaration)
- Modify: `lib/features/sound/domain/services/tts_queue_service.dart` (import line 5, field, constructor param, call site line 158)
- Modify: `lib/core/di/service_locator.dart` (TtsQueueService registration lines 165-172)
- Test: `test/features/sound/tts_synthesizer_contract_test.dart` (new)

**Interfaces:**
- Produces: `abstract class TtsSynthesizer { Future<String> synthesize({required String text, required String language, required VoiceEffect voiceEffect}); }` — later tasks may rely on it staying in `sound/domain/services/`.

- [ ] **Step 1: Write the contract test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_datasource.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_synthesizer.dart';

void main() {
  test('TtsDatasource satisfies the domain TtsSynthesizer contract', () {
    final TtsSynthesizer synthesizer = TtsDatasource();
    expect(synthesizer, isA<TtsSynthesizer>());
  });

  test('synthesize signature matches the queue call shape', () async {
    // Compile-time contract: the interface exposes exactly what the queue uses.
    final TtsSynthesizer synthesizer = TtsDatasource();
    expect(
      synthesizer.synthesize
          is Future<String> Function({
            required String text,
            required String language,
            required VoiceEffect voiceEffect,
          }),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (`tts_synthesizer.dart` does not exist). Run: `flutter test test/features/sound/tts_synthesizer_contract_test.dart` — Expected: compile error.

- [ ] **Step 3: Create the interface**

```dart
import '../../../../core/models/voice_effect.dart';

/// Domain contract for speech synthesis.
///
/// Implemented by the data layer (`TtsDatasource`); the domain TTS queue
/// depends on this abstraction only.
abstract class TtsSynthesizer {
  /// Synthesize [text] into an audio file and return its path.
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  });
}
```

In `tts_datasource.dart`, declare `class TtsDatasource implements TtsSynthesizer` (import the interface) and add a delegating override — keep the existing method for other callers:

```dart
  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) =>
      textToFrenchMaleVoice(
        text: text,
        language: language,
        voiceEffect: voiceEffect,
      );
```

- [ ] **Step 4: Point the queue at the interface**

In `tts_queue_service.dart`: replace the data import with `import 'tts_synthesizer.dart';`, change the field to `final TtsSynthesizer _ttsSynthesizer;`, the constructor param to `required TtsSynthesizer ttsSynthesizer`, and the call site to `await _ttsSynthesizer.synthesize(text: ..., language: ..., voiceEffect: ...)` (keep the surrounding arguments exactly as at line 158 today). Update the DI registration to `TtsQueueService(ttsSynthesizer: getIt<TtsDatasource>(), ...)` keeping its other params.

- [ ] **Step 5: Gate** — `flutter test test/features/sound/` then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS. Then `rg -n "data/" lib/features/sound/domain/` → 0 matches.

### Task 9: Move `AvatarRepository` interface into the avatar feature

**Files:**
- Move: `lib/core/repositories/avatar_repository.dart` → `lib/features/avatar/domain/repositories/avatar_repository.dart`
- Modify: `lib/features/avatar/avatar.dart` (barrel export)
- Modify imports (from verified importer list): `lib/features/avatar/data/repositories/avatar_repository_impl.dart`, `lib/features/avatar/presentation/bloc/avatar_cubit.dart`, `lib/features/demo/data/repositories/demo_repository_impl.dart`, `lib/core/di/service_locator.dart`
- Modify test imports: `test/features/avatar/avatar_cubit_test.dart`, `test/features/avatar/widgets/background_golden_test.dart`, `test/features/avatar/widgets/clothes_change_golden_test.dart`, `test/features/avatar/widgets/animated_background_avatar_test.dart`, `test/features/chat/chats_cubit_test.dart`, `test/features/chat/widgets/floating_stop_button_test.dart`, `test/integration/features/chat/new_chat_animation_test.dart`

**Interfaces:**
- Produces: `AvatarRepository` type at its new path, re-exported by `lib/features/avatar/avatar.dart` via `export 'domain/repositories/avatar_repository.dart';`. Cross-feature consumers (demo, tests) must import it through the barrel — never the deep path.

- [ ] **Step 1: Move the file** (`git mv` equivalent: create at new path, delete old). The file's own imports (`../models/...` → now `../../../../core/models/...`) must be fixed for the new depth.

- [ ] **Step 2: Export from the barrel** — add to `lib/features/avatar/avatar.dart`:

```dart
export 'domain/repositories/avatar_repository.dart';
```

- [ ] **Step 3: Rewrite importers**

- avatar feature files: relative import `../../domain/repositories/avatar_repository.dart` (adjust depth per file).
- `demo_repository_impl.dart`: `import '../../avatar/avatar.dart';` (barrel only — the architecture test enforces this).
- `service_locator.dart`: update to the new deep path (composition root may import feature internals).
- Tests: change `package:yofardev_ai/core/repositories/avatar_repository.dart` → `package:yofardev_ai/features/avatar/avatar.dart` (barrel), except avatar-feature-internal tests which may use the deep path.

- [ ] **Step 4: Gate** — `rg -rn "core/repositories/avatar_repository" lib test` → 0, then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 10: Move `GlobalMemoryRepository` interface into the chat feature

**Files:**
- Move: `lib/core/repositories/global_memory_repository.dart` → `lib/features/chat/domain/repositories/global_memory_repository.dart`
- Modify: `lib/features/chat/chat.dart` (barrel export)
- Modify imports: `lib/features/chat/data/repositories/global_memory_repository_impl.dart`, `lib/features/chat/domain/services/global_memory_service.dart`, `lib/features/settings/presentation/bloc/settings_cubit.dart` (→ via chat barrel), `lib/core/di/service_locator.dart`
- Modify test imports: `test/features/chat/global_memory_service_test.dart`

**Interfaces:**
- Produces: `GlobalMemoryRepository` at its new path, exported by `lib/features/chat/chat.dart` via `export 'domain/repositories/global_memory_repository.dart';`. `SettingsRepository` **stays** in `core/repositories/` (consumed by `core/services/agent/tool_registry.dart`) — add a one-line comment at its top: `// Stays in core: consumed by core/services/agent (ToolRegistry); core may not import features.`

- [ ] **Step 1: Move file + fix its internal imports** for the new depth.
- [ ] **Step 2: Barrel export** (line above).
- [ ] **Step 3: Rewrite importers** — chat-internal files use relative paths; `settings_cubit.dart` uses `import '../../chat/chat.dart';`; `service_locator.dart` uses the new deep path; the test uses `package:yofardev_ai/features/chat/chat.dart`.
- [ ] **Step 4: Gate** — `rg -rn "core/repositories/global_memory_repository" lib test` → 0, then the gate — Expected: PASS.

### Task 11: Relocate `LocaleRepository` (+impl) and `DemoController`

**Files:**
- Move: `lib/core/repositories/locale_repository.dart` → `lib/features/settings/domain/repositories/locale_repository.dart` (creates the settings `domain/` layer)
- Move: `lib/core/repositories/locale_repository_impl.dart` → `lib/features/settings/data/repositories/locale_repository_impl.dart`
- Move: `lib/core/services/demo_controller.dart` → `lib/features/demo/domain/services/demo_controller.dart`
- Modify: `lib/features/settings/settings.dart` (export the locale contract), `lib/core/di/service_locator.dart`
- Modify test imports: `test/core/repositories/locale_repository_test.dart` → `test/features/settings/data/repositories/locale_repository_test.dart` (move file, update package import)

**Interfaces:**
- Produces: `LocaleRepository` (`Future<Result<String>> getLanguage()`, `Future<Result<void>> setLanguage(String languageCode)`) and `LocaleRepositoryImpl` in the settings feature, exported via the settings barrel; `DemoController` at `features/demo/domain/services/demo_controller.dart` (pure path move; it is a `ChangeNotifier` singleton with a factory constructor — no code changes inside).

- [ ] **Step 1: Move the three files**, fixing relative import depths (`../models/result.dart` → `../../../../core/models/result.dart` etc.).
- [ ] **Step 2: Export + rewire DI** — settings barrel: `export 'domain/repositories/locale_repository.dart';`. In `service_locator.dart`, update the `LocaleRepository` registration to the new impl path and `DemoController`/`DemoCubit`/`DemoService` registrations to the new demo path. Importers of `demo_controller` inside the demo feature switch to relative imports (`demo_cubit.dart`, `demo_state.dart`, `demo_service.dart`).
- [ ] **Step 3: Move the locale test** and update its imports to the new package path.
- [ ] **Step 4: Gate** — `ls lib/core/repositories` should list only `settings_repository.dart`; `ls lib/core/services | rg demo_controller` → empty. Then the gate — Expected: PASS.

### Task 12: Architecture test — enforce intra-feature layer direction (with fixtures)

**Files:**
- Modify: `test/architecture_test.dart` (add one test + extract a shared helper)
- Create: `test/fixtures/architecture/domain_leak_fixture.dart` (deliberate violation, excluded from analysis — it is under `test/`, and `analysis_options.yaml` excludes only build/platform dirs, so ALSO add a `// ignore_for_file: unused_import` and keep it importing a real data file)

**Interfaces:**
- Produces: helper `List<String> relativeImportTargets(File f)` used by the existing barrel test and the new layer test and the negative fixture test.

- [ ] **Step 1: Extract the helper** from the existing barrel test in `architecture_test.dart` (identical resolution logic, currently inline):

```dart
/// Resolves every relative import in [f] to a repo-relative path.
List<String> relativeImportTargets(File f) => f
    .readAsLinesSync()
    .map((String l) => l.trim())
    .where((String l) => l.startsWith('import \''))
    .map((String l) => RegExp(r"import '([^']+)'").firstMatch(l)?.group(1))
    .whereType<String>()
    .where((String t) => t.startsWith('.'))
    .map((String t) => File.fromUri(Uri.file(f.path).resolve(t)).path)
    .toList();
```

Refactor the barrel test to use it (same expectations, same reasons).

- [ ] **Step 2: Add the layer-direction rule**

```dart
  test('feature domain imports neither data nor presentation', () {
    for (final File f in files) {
      final List<String> parts = f.path.split('/');
      if (parts.length < 4 || parts[1] != 'features' || parts[2] != 'domain') {
        continue;
      }
      for (final String target in relativeImportTargets(f)) {
        expect(
          RegExp(r'/features/[^/]+/(data|presentation)/').hasMatch(target),
          isFalse,
          reason: '${f.path}: domain imports layer internals: $target',
        );
      }
    }
  });
```

- [ ] **Step 3: Negative fixture** — `test/fixtures/architecture/domain_leak_fixture.dart` (imported only via `File` I/O by the test below, never by a Dart import, so the test runner does not compile it; the relative import into `lib/` is analyzable by `flutter analyze`):

```dart
// Deliberate architecture violation used by test/architecture_test.dart.
// NOT real app code — never import it from lib/.
// ignore_for_file: unused_import
import '../../../lib/features/sound/data/datasources/tts_datasource.dart';

class DomainLeakFixture {
  final TtsDatasource datasource = TtsDatasource();
}
```

And the fixture test in `architecture_test.dart` (reuses the helper, asserts the rule WOULD fire):

```dart
  test('layer rule detects a deliberate domain->data violation (fixture)', () {
    final File fixture =
        File('test/fixtures/architecture/domain_leak_fixture.dart');
    expect(fixture.existsSync(), isTrue);
    final List<String> targets = relativeImportTargets(fixture);
    expect(
      targets.any(
        (String t) =>
            RegExp(r'/features/[^/]+/(data|presentation)/').hasMatch(t),
      ),
      isTrue,
      reason: 'fixture must violate the rule the previous test enforces',
    );
  });
```

(If `flutter analyze` objects to the fixture for any other reason, add `test/fixtures/` to the `analyzer.exclude` list in `analysis_options.yaml` — the scanner reads it as text, so exclusion costs nothing.)

- [ ] **Step 4: Run architecture tests first (must catch the fixture), then the gate**

Run: `flutter test test/architecture_test.dart` — Expected: 6 passing (4 existing + layer rule + fixture). Then the full gate — Expected: PASS.

---

## Phase 3 — Error Handling

### Task 13: `mapExceptionToFailure` boundary

**Files:**
- Create: `lib/core/errors/exception_mapper.dart`
- Test: `test/core/errors/exception_mapper_test.dart`

**Interfaces:**
- Produces: `Failure mapExceptionToFailure(Object error, {StackTrace? stackTrace, String tag = 'Repository'})` — used by Tasks 14, 16.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/errors/exception_mapper.dart';
import 'package:yofardev_ai/core/models/failure.dart';

void main() {
  test('TimeoutException maps to NetworkFailure', () {
    expect(
      mapExceptionToFailure(TimeoutException('t', const Duration(seconds: 1))),
      isA<NetworkFailure>(),
    );
  });

  test('SocketException maps to NetworkFailure', () {
    expect(
      mapExceptionToFailure(const SocketException('down')),
      isA<NetworkFailure>(),
    );
  });

  test('FileSystemException and FormatException map to StorageFailure', () {
    expect(
      mapExceptionToFailure(const FileSystemException('disk')),
      isA<StorageFailure>(),
    );
    expect(
      mapExceptionToFailure(const FormatException('bad')),
      isA<StorageFailure>(),
    );
  });

  test('anything else maps to UnknownFailure and keeps the cause', () {
    final Object error = StateError('boom');
    final Failure failure = mapExceptionToFailure(error, tag: 'Test');
    expect(failure, isA<UnknownFailure>());
    expect(failure.cause, same(error));
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`flutter test test/core/errors/exception_mapper_test.dart` → compile error).

- [ ] **Step 3: Implement** — `lib/core/errors/exception_mapper.dart`:

```dart
import 'dart:async';
import 'dart:io';

import '../models/failure.dart';
import '../utils/logger.dart';

/// Classifies an exception this boundary does not specifically know into a
/// typed [Failure], and logs it exactly once at the repository boundary.
///
/// Repositories classify their OWN known exception taxonomy first (specific
/// `on` clauses); everything else falls through to this mapper.
Failure mapExceptionToFailure(
  Object error, {
  StackTrace? stackTrace,
  String tag = 'Repository',
}) {
  AppLogger.error(
    '$tag: unclassified exception',
    tag: tag,
    error: error,
  );
  if (stackTrace != null) {
    AppLogger.debug('$stackTrace', tag: tag);
  }
  if (error is TimeoutException) {
    return NetworkFailure(error.toString(), error);
  }
  if (error is SocketException || error is HttpException) {
    return NetworkFailure(error.toString(), error);
  }
  if (error is FileSystemException || error is FormatException) {
    return StorageFailure(error.toString(), error);
  }
  return UnknownFailure(error.toString(), error);
}
```

(Check `AppLogger.error`'s actual parameter list at `lib/core/utils/logger.dart:109` while implementing; it is called elsewhere as `AppLogger.error(msg, tag: ..., error: ...)` — match that shape. `AppLogger.debug(msg, tag:)` is used widely.)

- [ ] **Step 4: Tests pass** — `flutter test test/core/errors/exception_mapper_test.dart` → PASS.

### Task 14: Apply the mapper at every repository/datasource catch-all

**Files (verified catch-site counts):**
- `lib/features/chat/data/repositories/yofardev_repository_impl.dart` (8 catches)
- `lib/features/chat/data/repositories/global_memory_repository_impl.dart` (4)
- `lib/features/chat/data/datasources/chat_local_datasource.dart` (1)
- `lib/features/settings/data/repositories/settings_repository_impl.dart` (10)
- `lib/core/services/settings_local_datasource.dart` (6)
- `lib/features/avatar/data/repositories/avatar_repository_impl.dart` (1)
- `lib/features/avatar/data/datasources/avatar_local_datasource.dart` (2)
- `lib/features/demo/data/repositories/demo_repository_impl.dart` (2)
- `lib/features/sound/data/repositories/sound_repository_impl.dart` (3)
- `lib/features/home/data/repositories/home_repository_impl.dart` (4)
- `lib/features/talking/data/repositories/talking_repository_impl.dart` (any `catch` found by rg — count not listed above)
- Test: extend `test/features/chat/global_memory_repository_impl_test.dart` style mapping tests — add `test/features/chat/yofardev_repository_failure_test.dart` (new)

**Interfaces:**
- Consumes: `mapExceptionToFailure` from Task 13.

- [ ] **Step 1: Transformation pattern** — apply to every bare `catch (e)` that currently builds a Failure from `e.toString()`:

Before (representative, `global_memory_repository_impl.dart:18`):

```dart
    } catch (e) {
      return Result<GlobalMemory>.err(StorageFailure(e.toString(), e));
    }
```

After:

```dart
    } catch (e, st) {
      return Result<GlobalMemory>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'GlobalMemoryRepository'),
      );
    }
```

Rules: (1) capture the stack trace (`catch (e, st)`); (2) `tag` = the class name; (3) if the surrounding `try` has `on`-clauses that already classify a known type into a specific variant (`StorageFailure`/`NetworkFailure`/`TtsFailure`/`ConfigFailure`), KEEP them — the mapper replaces only the final bare catch; (4) a site whose variant choice encodes real knowledge (e.g. TTS synthesis → `TtsFailure`) keeps its explicit variant but still logs — convert it to `TtsFailure(e.toString(), e)` unchanged ONLY if it already logs; otherwise route through the mapper and accept the mapper's variant. When in doubt: mapper.

- [ ] **Step 2: Inventory check** — `rg -n "catch \(e\)" lib/features/*/data lib/core/services -g '*.dart'` and process every file in the list above. Files under `core/services/llm/`, `core/services/agent/`, `core/services/audio/`, `core/services/stream_processor/` are NOT repositories — leave them (they throw/return raw results upstream; out of scope per spec).

- [ ] **Step 3: Failure-mapping exemplar test** — `test/features/chat/yofardev_repository_failure_test.dart`. Two substitution slots are resolved by one lookup each before writing the file; everything else is fixed:

  - Lookup A — the repo's no-arg read method: run `rg -n "Future<Result<" lib/features/chat/data/repositories/yofardev_repository_impl.dart` and pick a method with zero parameters (call it `theMethod` returning `Result<TheType>`).
  - Lookup B — the mocked datasource's same method: run `rg -n "Future<" lib/features/chat/data/datasources/chat_local_datasource.dart`, find the method `theMethod` calls, and stub THAT (`theDatasourceMethod`).

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/chat/data/datasources/chat_local_datasource.dart';

class MockChatLocalDatasource extends Mock implements ChatLocalDatasource {}

void main() {
  late MockChatLocalDatasource datasource;
  late YofardevRepositoryImpl repo;

  setUp(() {
    datasource = MockChatLocalDatasource();
    repo = YofardevRepositoryImpl(chatDatasource: datasource);
  });

  test('a timeout maps to NetworkFailure via the boundary mapper', () async {
    when(() => datasource.theDatasourceMethod()).thenThrow(
      TimeoutException('timeout', const Duration(seconds: 5)),
    );

    final Result<TheType> result = await repo.theMethod();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test('a malformed payload maps to a typed Failure instead of escaping', () async {
    when(() => datasource.theDatasourceMethod())
        .thenThrow(const FormatException('not-json'));

    final Result<TheType> result = await repo.theMethod();

    expect(result.getOrNull, isNull);
    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<Failure>(),
    );
  });
}
```

Substitute `theMethod`/`TheType`/`theDatasourceMethod` everywhere they appear (constructor param name of `YofardevRepositoryImpl` is `chatDatasource` — verified in `service_locator.dart:139`).

- [ ] **Step 4: Gate** — `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS (existing repo tests keep passing because variants for known cases are preserved).

### Task 15: `localizeFailure` + ARB keys

**Files:**
- Create: `lib/core/l10n/failure_localization.dart`
- Modify: `lib/core/l10n/app_localizations_en.arb` + `app_localizations_fr.arb` (via fstr.sh only)

**Interfaces:**
- Produces: `String localizeFailure(AppLocalizations l10n, Failure failure)` — exhaustive over all 5 variants; used by Tasks 16 and 17.

- [ ] **Step 1: Add the ARB keys** (fstr.sh regenerates afterwards):

```bash
./scripts/fstr.sh failureStorage "Échec de l'enregistrement ou de la lecture des données" "Failed to save or load data"
./scripts/fstr.sh failureNetwork "Erreur réseau" "Network error"
./scripts/fstr.sh failureTts "Erreur de synthèse vocale" "Text-to-speech error"
./scripts/fstr.sh failureConfig "Erreur de configuration" "Configuration error"
./scripts/fstr.sh failureUnknown "Une erreur inattendue est survenue" "An unexpected error occurred"
```

(fstr signature is `"key" "FR" "EN"` — confirm with `head -20 scripts/fstr.sh` before running; swap argument order if the script's help says otherwise.)

- [ ] **Step 2: Implement** — `lib/core/l10n/failure_localization.dart`:

```dart
import '../models/failure.dart';
import 'generated/app_localizations.dart';

/// Localized, user-facing text for a [Failure]. Exhaustive by construction —
/// adding a Failure variant is a compile error here.
/// Diagnostic [Failure.message] is for logs only; never display it.
String localizeFailure(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      StorageFailure() => l10n.failureStorage,
      NetworkFailure() => l10n.failureNetwork,
      TtsFailure() => l10n.failureTts,
      ConfigFailure() => l10n.failureConfig,
      UnknownFailure() => l10n.failureUnknown,
    };
```

- [ ] **Step 3: Gate** — `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS (new getters compile after gen-l10n; fstr runs it).

### Task 16: Typed failures in sound / talking / chat TTS cubits + chat details

**Files:**
- Modify: `lib/features/sound/presentation/bloc/sound_state.dart` + `sound_cubit.dart` (then build_runner)
- Modify: `lib/features/talking/presentation/bloc/talking_state.dart` + `talking_cubit.dart` lines 128-145 (then build_runner)
- Modify: `lib/features/chat/presentation/bloc/chat_tts_state.dart` line 13 + `chat_tts_cubit.dart` lines ~200, ~245 (then build_runner)
- Modify: `lib/features/chat/screens/chat_details_screen.dart` line ~217
- Modify: sound/talking/chat TTS tests that assert on message strings (`rg -n "SoundError|TalkingState.error|errorMessage" test/features/sound test/features/talking test/features/chat/bloc`)

**Interfaces:**
- Consumes: `mapExceptionToFailure` (Task 13), `localizeFailure` (Task 15).
- Produces: `SoundError(Failure failure)`; `TalkingState.error(Failure failure, [MouthState mouthState])`; `ChatTtsState.error` (`Failure?`, replacing `String errorMessage`).

- [ ] **Step 1: Sound** — state: `const factory SoundState.error(Failure failure) = SoundError;` (import failure.dart). Cubit:

```dart
      result.when(
        err: (Failure failure) {
          emit(SoundError(failure));
          emit(const SoundInitial());
        },
        ok: (_) {
          emit(const SoundInitial());
        },
      );
    } catch (e, st) {
      emit(SoundError(mapExceptionToFailure(e, stackTrace: st, tag: 'SoundCubit')));
    }
```

Run build_runner. Update sound tests: assertions like `equals(SoundError('msg'))` become `isA<SoundError>()` plus, where the message mattered, `failure.cause`/variant checks.

- [ ] **Step 2: Talking** — state (positional, preserves `mouthState`):

```dart
  /// Error occurred
  const factory TalkingState.error(
    Failure failure, [
    @Default(MouthState.closed) MouthState mouthState,
  ]) = ErrorState;
```

Cubit, both sites (`playWaitingSentence`, `generateSpeech`):

```dart
    } catch (e, st) {
      emit(
        TalkingState.error(
          mapExceptionToFailure(e, stackTrace: st, tag: 'TalkingCubit'),
        ),
      );
    }
```

Run build_runner. `rg -n "TalkingState.error|ErrorState" lib test` and update every construction/assertion from `String` to `Failure` (no widget renders the message in lib — verified; only tests).

- [ ] **Step 3: ChatTts** — state line 13: replace `@Default('') String errorMessage,` with `Failure? error,`; cubit sites ~200/~245: `errorMessage: 'Failed to play audio: ${e.toString()}'` → `error: TtsFailure(e.toString(), e)` (these two catch sites are TTS-specific, so the explicit variant is the known-taxonomy classification) and `'Failed to initialize: ...'` → same shape with `tag`-style cause. Run build_runner. No lib widget reads the field (verified); update test assertions.

- [ ] **Step 4: chat_details_screen.dart ~217** — replace:

```dart
AppLocalizations.of(context).failedToDownload(e.toString()),
```

with:

```dart
AppLocalizations.of(context).failedToDownload(
  localizeFailure(
    AppLocalizations.of(context),
    mapExceptionToFailure(e, stackTrace: st, tag: 'ChatDetailsScreen'),
  ),
),
```

(capture `st` in the surrounding `catch (e, st)`; add both imports.)

- [ ] **Step 5: Gate** — `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

---

## Phase 4 — State Polish

### Task 17: Typed error fields in `ChatState` and `SettingsState`; remove dead error members

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_state.dart` (fields `errorMessage`→`Failure? error`, delete `chatsListError`; build_runner)
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (emit sites 211, 247, 273, 319, 659; delete `setError` ~line 422-425)
- Modify: `lib/features/chat/widgets/ai_text_input/ai_text_input.dart` (line ~105)
- Modify: `lib/features/settings/presentation/bloc/settings_state.dart` (`errorMessage`→`Failure? error`; build_runner)
- Modify: `lib/features/settings/presentation/bloc/settings_cubit.dart` (`rg -n "errorMessage" settings_cubit.dart` — apply the same transform per site)
- Modify: `lib/features/chat/presentation/bloc/chat_streaming_service.dart` **only if** `rg -n "errorMessage" lib/features/chat/domain` reports call sites pushing strings into the cubit (check: it coordinates via callbacks; if it receives an error String, wrap at the cubit boundary — see Step 3)

**Interfaces:**
- Consumes: `localizeFailure` (Task 15), `Failure` variants.
- Produces: `ChatState.error` (`Failure?`, default `null`), `SettingsState.error` (`Failure?`). `ChatState.chatsListError` and `ChatCubit.setError` are deleted (both verified dead).

- [ ] **Step 1: `ChatState`** — replace `@Default('') String errorMessage,` with `Failure? error,` (import `'../../../../core/models/failure.dart';`); delete `String? chatsListError,` and its `chatsListError: null` in `initial()`. Add the cohesion decision as a doc comment on the class (closes the audit's "evaluate split" item):

```dart
/// Single flat state on purpose: the conversation, its list, streaming and
/// titles are one coherent state machine (see flutter-architecture
/// "File Cohesion"). Do NOT split into micro-cubits.
```

Run build_runner.

- [ ] **Step 2: `ChatCubit` emit sites** —
  - Lines 211/247/273/319 (`errorMessage: failure.message` where `failure` is already a typed `Failure`): → `error: failure,`
  - Line 659 (stream `onError: (String error)`): → `error: UnknownFailure(error, error),`
  - Delete `setError` (zero callers — verified).
  Then `rg -n "errorMessage" lib/features/chat/presentation lib/features/chat/domain` must return nothing; if `chat_streaming_service.dart` pushes strings into a cubit callback, wrap them at the callback boundary with `UnknownFailure(...)` — the service itself stays String-based (its errors are stream-transport diagnostics).

- [ ] **Step 3: `ai_text_input.dart` ~105** — inside the `listenWhen`-guarded listener (`state.status == ChatStatus.error` implies error is set, but stay null-safe):

```dart
        if (state.status == ChatStatus.error && state.error != null) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizeFailure(l10n, state.error!)),
              backgroundColor: colorScheme.error,
            ),
          );
        }
```

Add imports for `AppLocalizations` (generated path, copy from another chat widget) and `failure_localization.dart`.

- [ ] **Step 4: `SettingsState`/`SettingsCubit`** — state: `@Default('') String errorMessage,` → `Failure? error,` (keep `hasError`); build_runner. In the cubit, every `errorMessage: '<literal>'` becomes `error: ConfigFailure('<literal>')` (config/settings domain knowledge — deliberate variant), keeping the adjacent `hasError: true`. Run `rg -n "errorMessage" lib/features/settings` → 0.

- [ ] **Step 5: Update test assertions** — `rg -n "errorMessage|chatsListError|setError" test` and update: string equality on messages → `isA<ConfigFailure>()` / `isA<UnknownFailure>()` or `.error?.cause` checks; delete `setError` tests if any exist.

- [ ] **Step 6: Gate** — `dart run build_runner build --delete-conflicting-outputs && dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

---

## Phase 5 — Tests & Checker

### Task 18: DI smoke test

**Files:**
- Create: `test/core/di/service_locator_test.dart`

**Interfaces:**
- Consumes: `setupServiceLocator()` + every registration added/changed in Phases 1-2.

- [ ] **Step 1: Write the test** (scope deliberately excludes plugin-backed audio services — `AudioPlayerService`, `AudioAmplitudeService`, `VoiceEffectsService`, `TtsDatasource` instance methods — which touch platform channels at construction; `InterruptionService` is a pure stream service and is included):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';

void main() {
  test('service locator resolves the pure-Dart dependency graph', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await setupServiceLocator();

    // Datasources / repositories
    expect(getIt<ChatRepository>(), isNotNull);
    expect(getIt<SettingsRepository>(), isNotNull);
    expect(getIt<AvatarRepository>(), isNotNull);
    expect(getIt<GlobalMemoryRepository>(), isNotNull);
    expect(getIt<LocaleRepository>(), isNotNull);
    expect(getIt<HomeRepository>(), isNotNull);
    expect(getIt<SoundRepository>(), isNotNull);
    expect(getIt<TalkingRepository>(), isNotNull);
    expect(getIt<DemoRepository>(), isNotNull);

    // Cross-feature domain services
    expect(getIt<ToolRegistry>(), isNotNull);
    expect(getIt<LlmServiceInterface>(), isNotNull);
    expect(getIt<ChatStreamingService>(), isNotNull);
    expect(getIt<GlobalMemoryService>(), isNotNull);
    expect(getIt<AvatarAnimationService>(), isNotNull);
    expect(getIt<TtsQueueService>(), isNotNull);
    expect(getIt<AppLifecycleService>(), isNotNull);
    expect(getIt<InterruptionService>(), isNotNull);
    expect(getIt<DemoService>(), isNotNull);

    // Every cubit (registerFactory) constructs
    expect(getIt<ChatCubit>(), isNotNull);
    expect(getIt<ChatTtsCubit>(), isNotNull);
    expect(getIt<SettingsCubit>(), isNotNull);
    expect(getIt<AvatarCubit>(), isNotNull);
    expect(getIt<DemoCubit>(), isNotNull);
    expect(getIt<HomeCubit>(), isNotNull);
    expect(getIt<SoundCubit>(), isNotNull);
    expect(getIt<TalkingCubit>(), isNotNull);
  });
}
```

Import types via their canonical locations after Phase 2 (repositories via feature barrels where they moved: avatar/chat/settings barrels; others deep paths) — mirror the import set of `test/features/chat/chats_cubit_test.dart`. If a cubit construction touches a platform channel in the test env, the failure names the culprit — then exclude that cubit with a comment naming the plugin, do not mock inside the locator.

- [ ] **Step 2: Gate** — `./scripts/fverify.sh` — Expected: PASS.

### Task 19: Demo and Home cubit tests

**Files:**
- Create: `test/features/demo/demo_cubit_test.dart`
- Create: `test/features/home/home_cubit_test.dart`

**Interfaces:**
- Consumes: `DemoCubit({demoController, demoService})` (Task 2), `HomeCubit(getIt<HomeRepository>(), getIt<AppLifecycleService>())` shape (positional — match `service_locator.dart:278-280`).

- [ ] **Step 1: DemoCubit test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/features/demo/demo.dart';

class MockDemoService extends Mock implements DemoService {}

void main() {
  late DemoController controller;
  late MockDemoService demoService;
  late DemoCubit cubit;

  setUp(() {
    controller = DemoController();
    demoService = MockDemoService();
    cubit = DemoCubit(demoController: controller, demoService: demoService);
  });

  tearDown(() async => cubit.close());

  test('startDemoMode activates the service and reflects the script', () async {
    const DemoScript script = DemoScripts.beachDemo;
    when(() => demoService.activateDemo(
          chatId: any(named: 'chatId'),
          script: any(named: 'script'),
        )).thenAnswer((_) async {});

    await cubit.startDemoMode(chatId: 'chat-1', script: script);

    verify(() => demoService.activateDemo(chatId: 'chat-1', script: script))
        .called(1);
    expect(cubit.state.currentScript, script);
    expect(cubit.state.remainingResponses, script.responses.length);
  });

  test('controller notifications mirror controller state into cubit state', () {
    // Read lib/features/demo/domain/services/demo_controller.dart (post-Task 11
    // path) and call its public method that transitions DemoStatus away from
    // idle (the countdown starter). Then assert:
    //   expect(cubit.state.status, controller.status);
    //   expect(cubit.state.countdownValue, controller.countdownValue);
    // If the transition is Timer-based, first await
    //   Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, DemoStatus.idle);
  });

  test('resetDemo returns to the initial state', () {
    cubit.resetDemo();
    expect(cubit.state, const DemoState());
  });
}
```

Before finalizing, read `lib/features/demo/domain/services/demo_controller.dart` (after Task 11's move) and align `startCountdown()` with the real mutator names; `DemoScripts.beachDemo` constness must match `core/models/demo_script.dart` (drop `const` if it is not a const constructor).

- [ ] **Step 2: HomeCubit test** — first read `lib/features/home/presentation/bloc/home_cubit.dart` and list every `HomeRepository` method its `initialize()` calls; stub each of them in `setUp` with a passing `Result.ok(...)` (use the exact return type each method declares — they are all `Result<T>`), then write:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/home/domain/repositories/home_repository.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_cubit.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_state.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late MockHomeRepository repository;
  late AppLifecycleService lifecycle;
  late HomeCubit cubit;

  setUp(() {
    repository = MockHomeRepository();
    lifecycle = AppLifecycleService();
    cubit = HomeCubit(repository, lifecycle);
    // One when(...) per repository call made by initialize(), e.g.:
    // when(() => repository.someRead())
    //     .thenAnswer((_) async => Result.ok(someValue));
  });

  tearDown(() async => cubit.close());

  test('initialize flips isInitialized', () async {
    await cubit.initialize();
    expect(cubit.state.isInitialized, isTrue);
  });

  test('a repository failure does not crash initialization', () async {
    // Re-stub ONE repository call with a failure result:
    // when(() => repository.<theCall>).thenAnswer(
    //   (_) async => Result.err(UnknownFailure('disk', null)),
    // );
    await cubit.initialize();
    expect(cubit.state, isA<HomeState>());
  });
}
```

Adjust the constructor call to `HomeCubit`'s actual parameter style (positional vs named — `service_locator.dart:278-280` shows the current call shape). The failure-path assertion is deliberately weak (`isA<HomeState>()` + no throw) because the correct `isInitialized` value on failure is a property of the cubit's real policy — check the cubit's error branch and strengthen the assertion to whatever it actually does (and if it swallows silently, that is a finding: make the branch emit and assert it).

- [ ] **Step 3: Gate** — `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

### Task 20: Checker — getIt allowlist + registrations rule (+ fixtures)

**Files:**
- Modify: `test/architecture_test.dart` (two new tests + two fixtures)
- Create: `test/fixtures/architecture/getit_violation_fixture.dart`
- Create: `test/fixtures/architecture/registration_violation_fixture.dart`

**Interfaces:**
- Consumes: the file-scan `files` list and `relativeImportTargets` helper from Task 12.
- Produces: rules that make Tasks 1-6 regressions fail CI.

- [ ] **Step 1: The allowlist rule** (this is the rule Tasks 1-6 satisfied):

```dart
  test('getIt is resolved only in composition roots', () {
    const List<String> allowlist = <String>[
      'lib/core/di/service_locator.dart',
      'lib/app.dart',
      'lib/core/router/app_router.dart',
    ];
    for (final File f in files) {
      if (allowlist.contains(f.path)) continue;
      for (final String line in f.readAsLinesSync()) {
        expect(
          RegExp(r'\bgetIt[<(]').hasMatch(line),
          isFalse,
          reason: '${f.path}: resolves from getIt outside composition roots: $line',
        );
      }
    }
  });
```

- [ ] **Step 2: The registrations rule**

```dart
  test('registrations appear only in service_locator.dart', () {
    for (final File f in files) {
      if (f.path == 'lib/core/di/service_locator.dart') continue;
      for (final String line in f.readAsLinesSync()) {
        expect(
          RegExp(r'getIt\.register(LazySingleton|Singleton|Factory)').hasMatch(line),
          isFalse,
          reason: '${f.path}: DI registration outside service_locator: $line',
        );
      }
    }
  });
```

- [ ] **Step 3: Negative fixtures** — `getit_violation_fixture.dart`:

```dart
// Deliberate violation for test/architecture_test.dart. Never import from lib/.
// ignore_for_file: unused_element
void violation() => getIt<DemoService>();
```

(The fixture deliberately contains the bare identifier `getIt` with no import — it is never compiled; `flutter analyze` coverage of `test/fixtures/` is excluded per the Task 12 note if it complains.) Fixtures live under `test/`, so the `lib`-scoped rules never scan them; the negative tests apply each rule's RegExp to the fixture CONTENT directly (same approach as Task 12's fixture test). `registration_violation_fixture.dart` — must literally contain a `getIt.register...` call so the registrations rule's pattern matches:

```dart
// Deliberate violation for test/architecture_test.dart. Never import from lib/.
// ignore_for_file: unused_element
void register() => getIt.registerFactory<int>(() => 42);
```

Fixture tests in `architecture_test.dart`:

```dart
  test('getIt rule detects a deliberate violation (fixture)', () {
    final String content = File(
      'test/fixtures/architecture/getit_violation_fixture.dart',
    ).readAsStringSync();
    expect(RegExp(r'\bgetIt[<(]').hasMatch(content), isTrue);
  });

  test('registrations rule detects a deliberate violation (fixture)', () {
    final String content = File(
      'test/fixtures/architecture/registration_violation_fixture.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'getIt\.register(LazySingleton|Singleton|Factory)')
          .hasMatch(content),
      isTrue,
    );
  });
```

These prove the regexes would fire on such files if they lived in `lib/`.

- [ ] **Step 4: Final full gate** — `flutter test test/architecture_test.dart` (10 tests) then `dart fix --apply && dart format . && ./scripts/fverify.sh` — Expected: PASS.

---

## Final Verification

- [ ] `rg -n "getIt[<(]" lib -g '*.dart' | rg -v "service_locator|app.dart|app_router"` → 0 matches
- [ ] `rg -n "e\.toString\(\)" lib/features/*/presentation lib/features/*/screens -g '*.dart'` → 0 matches (diagnostic strings no longer built in presentation)
- [ ] `ls lib/core/repositories/` → only `settings_repository.dart`
- [ ] `flutter test test/architecture_test.dart` → 10 passing
- [ ] `./scripts/fverify.sh` → green
- [ ] Update `AGENTS.md` "Critical Rules": note the getIt allowlist, the layer-direction rule, `mapExceptionToFailure`/`localizeFailure`, and `SettingsRepository`'s documented core exception.
