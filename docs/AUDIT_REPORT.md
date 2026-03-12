# Flutter Architecture Audit — Yofardev AI

**Version**: 3.0.0+6 | **Stack**: Flutter 3.8+, flutter_bloc 9.1.1, freezed 3.2.5, fpdart 1.2.0, get_it 9.2.1
**Date**: 2026-03-12 | **7 features** | **39 test files**

---

## Summary

| Category | Status | Issues |
|----------|--------|--------|
| Project Structure | ⚠️ | 2 |
| State Management | ⚠️ | 3 |
| State Design | ✅ | 0 |
| Error Handling | ✅ | 0 |
| Presentation | ❌ | 6 |
| DI Integrity | ❌ | 7 |
| Cubit Coupling | ❌ | 5 |
| Routing | ⚠️ | 3 |
| Models | ⚠️ | 3 |
| Standards | ⚠️ | 4 |
| Testing | ⚠️ | 6 |

**Overall Grade: B-**

Well-documented architecture with strong testing fundamentals and consistent use of freezed/Either patterns, but undermined by pervasive cross-feature coupling (~40 imports across 30 files) that contradicts the project's own stated rules. The documentation accurately describes the *intended* architecture, but the code has drifted significantly.

---

## 🔴 Critical Issues

### [CUBIT COUPLING] All cubits provided at root MultiBlocProvider

**File**: `lib/main.dart` (lines 77-104)
**Problem**: All 7 cubits (`TalkingCubit`, `ChatCubit`, `ChatTtsCubit`, `AvatarCubit`, `DemoCubit`, `SettingsCubit`, `HomeCubit`) are provided at the root `MultiBlocProvider`. Every screen in the app receives all cubits, defeating feature isolation. Additionally, `BlocBuilder<ChatCubit, ChatState>` wraps the entire `MaterialApp`, causing the whole app to rebuild on any chat state change (including locale updates).
**Fix**: Scope cubit providers to feature screens. Only provide truly global cubits (e.g., `SettingsCubit`) at root. Use `BlocProvider` at the route level for feature-scoped cubits.
**Migration risk**: High — affects every screen's dependency chain.

---

### [LAYER VIOLATION] 40 cross-feature imports across 30 files

This is the most pervasive architectural violation. No feature is clean.

**avatar → chat** (4 files):
- `lib/features/avatar/data/datasources/avatar_local_datasource.dart:5`
- `lib/features/avatar/data/repositories/avatar_repository_impl.dart:3`
- `lib/features/avatar/domain/repositories/avatar_repository.dart:3`
- `lib/features/avatar/presentation/bloc/avatar_cubit.dart:11`

**avatar → talking** (2 files):
- `lib/features/avatar/widgets/talking_mouth.dart:6-7`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart:9-10`

**chat → settings** (3 files):
- `lib/features/chat/data/repositories/yofardev_repository_impl.dart:13`
- `lib/features/chat/domain/services/chat_entry_service.dart:6`
- `lib/features/chat/presentation/bloc/chat_cubit.dart:17`

**chat → talking** (4 files):
- `lib/features/chat/presentation/bloc/chat_tts_cubit.dart:11`
- `lib/features/chat/widgets/floating_stop_button.dart:6-7`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:19-20`
- `lib/features/chat/screens/chats_list_screen.dart:8`

**chat → avatar** (4 files):
- `lib/features/chat/screens/chat_details_screen.dart:10-11`
- `lib/features/chat/screens/chats_list_screen.dart:5`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:17-18`
- `lib/features/chat/widgets/chat_list_container.dart:5-6`

**chat → demo** (1 file):
- `lib/features/chat/data/repositories/yofardev_repository_impl.dart:8`

**home → avatar** (4 files):
- `lib/features/home/screens/home_screen.dart:5-6`
- `lib/features/home/widgets/home_content_stack.dart:4-9`
- `lib/features/home/widgets/home_buttons.dart:5`
- `lib/features/home/widgets/home_bloc_listeners.dart:9-10`

**home → chat** (5 files):
- `lib/features/home/screens/home_screen.dart:7-8`
- `lib/features/home/widgets/home_content_stack.dart:10-12`
- `lib/features/home/widgets/home_buttons.dart:6-7`
- `lib/features/home/widgets/home_bloc_listeners.dart:11-13`

**home → talking** (4 files):
- `lib/features/home/screens/home_screen.dart:12-13`
- `lib/features/home/widgets/home_content_stack.dart:13`
- `lib/features/home/widgets/home_buttons.dart:8`
- `lib/features/home/widgets/home_bloc_listeners.dart:17-18`

**home → demo** (2 files):
- `lib/features/home/screens/home_screen.dart:10-11`
- `lib/features/home/widgets/home_bloc_listeners.dart:14-16`

**settings → chat** (1 file):
- `lib/features/settings/screens/settings_screen.dart:10`

**demo → chat** (1 file):
- `lib/features/demo/domain/repositories/demo_repository.dart:4-5`

**demo → avatar** (1 file):
- `lib/features/demo/domain/repositories/demo_repository.dart:6`

**core → features** (7 files, technically allowed but worth noting):
- `lib/core/di/service_locator.dart`
- `lib/core/router/app_router.dart`
- `lib/core/services/agent/tool_registry.dart`
- `lib/core/services/agent/yofardev_agent.dart`
- `lib/core/services/audio/tts_queue_service.dart`
- `lib/core/services/avatar_animation_service.dart`
- `lib/core/widgets/constrained_width.dart`

**Fix**: Extract all shared models (`Chat`, `ChatEntry`, `AvatarConfig`) to `core/models/`. Extract cross-feature coordination into `core/services/`. Features must never import from each other.
**Migration risk**: High — requires moving shared models and creating new core services.

---

### [CUBIT COUPLING] `home_bloc_listeners.dart` is a god-object

**File**: `lib/features/home/widgets/home_bloc_listeners.dart` (310 lines)
**Problem**: Reads 5 cubits simultaneously — `AvatarCubit`, `TalkingCubit`, `ChatCubit`, `DemoCubit`, `HomeCubit`. Contains 100+ line listener methods with business logic that belongs in domain services. Acts as an implicit coordination hub replacing proper domain services.
**Fix**: Extract coordination logic into an `AppLifecycleService` in `core/services/`. Each listener concern should be a separate domain service method.
**Migration risk**: Medium — additive, can be done incrementally.

---

### [CUBIT COUPLING] ChatTtsCubit depends on TalkingCubit (singleton)

**File**: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart:11`
**Problem**: `ChatTtsCubit` constructor takes `TalkingCubit` as a dependency. This is a direct cubit-to-cubit dependency across features. The `TalkingCubit` must be a singleton so both `ChatTtsCubit` and the UI share it — a hidden coupling signal.
**Fix**: Extract talking state into a `TalkingService` in `core/services/` that exposes a stream. Both `ChatTtsCubit` and the UI subscribe to the service, not to each other.
**Migration risk**: Medium.

---

### [DI INTEGRITY] ChatTitleService uses concrete LlmService

**File**: `lib/core/di/service_locator.dart` (lines 222-227)
**Problem**: `ChatTitleService` is injected with `getIt<LlmService>()` (concrete) instead of `getIt<LlmServiceInterface>()`. Title generation will always use the real LLM, even in demo/fake mode, because it bypasses the abstraction.
**Fix**: Change to `getIt<LlmServiceInterface>()`.
**Migration risk**: Low — one-line change.

---

### [DI INTEGRITY] ToolRegistry is entirely static

**File**: `lib/core/services/agent/tool_registry.dart` (lines 16-174)
**Problem**: All methods are static. Tools are hardcoded, not injectable. Cannot be tested with mocks — any test touching function calling requires real tool execution.
**Fix**: Convert to an injectable class registered in `service_locator.dart`. Accept tools via constructor.
**Migration risk**: Medium — requires updating `YofardevAgent` and tool consumers.

---

### [DI INTEGRITY] PromptDatasource bypasses DI

**File**: `lib/core/services/prompt_datasource.dart` (lines 11, 13, 50, 57)
**Problem**: Instantiates `SettingsLocalDatasource()` directly on every call instead of receiving it via DI. Creates a hidden dependency that bypasses the service locator.
**Fix**: Inject `SettingsLocalDatasource` via constructor, register `PromptDatasource` in `service_locator.dart`.
**Migration risk**: Low.

---

## 🟡 Warnings

### [DI INTEGRITY] LlmConfigManager creates its own datasource

**File**: `lib/core/services/llm/llm_config_manager.dart` (line 18)
**Problem**: Creates `SettingsLocalDatasource()` directly, bypassing DI.
**Fix**: Inject via constructor.
**Migration risk**: Low.

---

### [DI INTEGRITY] DemoService uses post-construction setRepository()

**File**: `lib/core/di/service_locator.dart` (lines 95-99) + `lib/features/demo/data/repositories/demo_repository_impl.dart`
**Problem**: `DemoService` is constructed first, then its repository is set via `service.setRepository()`. This is a service locator anti-pattern — the repository should be constructor-injected.
**Fix**: Refactor `DemoService` to accept `DemoRepository` via constructor.
**Migration risk**: Low.

---

### [DI INTEGRITY] AvatarRepositoryImpl self-instantiates datasource

**File**: `lib/features/avatar/data/repositories/avatar_repository_impl.dart`
**Problem**: Uses `= AvatarLocalDatasource()` default parameter instead of receiving it via constructor injection. Makes the repository untestable with a mock datasource.
**Fix**: Remove default parameter, always inject via `service_locator.dart`.
**Migration risk**: Low.

---

### [DI INTEGRITY] ChatLocalDatasource self-instantiates dependencies

**File**: `lib/features/chat/data/datasources/chat_local_datasource.dart`
**Problem**: Internally instantiates `SettingsLocalDatasource()` and `PromptDatasource()` instead of receiving them via DI.
**Fix**: Inject via constructor.
**Migration risk**: Low.

---

### [DI INTEGRITY] switchLlmService() uses unregister + re-register

**File**: `lib/core/di/service_locator.dart` (lines 244-256)
**Problem**: Unregisters and re-registers `LlmServiceInterface`. Any singleton that was injected with the original instance still holds a stale reference. There is no notification mechanism.
**Fix**: Use a proxy/adapter pattern that delegates to the current implementation, or make `LlmServiceInterface` a factory that resolves the current backend.
**Migration risk**: Medium.

---

### [DI INTEGRITY] LlmService uses static _testClient for test injection

**File**: `lib/core/services/llm/llm_service.dart` (lines 32-49)
**Problem**: Static test injection field is fragile and not thread-safe.
**Fix**: Use constructor injection with a test-friendly factory.
**Migration risk**: Low.

---

### [DI INTEGRITY] FakeLlmService holds concrete LlmService reference

**File**: `lib/core/services/llm/fake_llm_service.dart` (line 31)
**Problem**: The fake service depends on the concrete real service, breaking the abstraction pattern.
**Fix**: Remove the dependency or make it optional behind an interface.
**Migration risk**: Low.

---

### [CUBIT COUPLING] ChatCubit is 707 lines (2.3x file size limit)

**File**: `lib/features/chat/presentation/bloc/chat_cubit.dart` (707 lines)
**Problem**: Handles chat CRUD, streaming, function calling, title generation, language settings, sound effects, and avatar updates. Violates the 300-line file size limit by 407 lines. This is the #1 maintenance risk in the codebase.
**Fix**: Split into:
- `ChatCubit` (~300 lines): chat CRUD, streaming, state
- Domain service for title generation coordination
- Domain service for function calling coordination
**Migration risk**: Medium — each extraction is independent.

---

### [CUBIT COUPLING] AudioPlayer created directly in AvatarCubit

**File**: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`
**Problem**: `_goDownAndUp()` creates an `AudioPlayer` instance directly and plays audio inline. Audio logic belongs in a service.
**Fix**: Extract to an `AudioPlaybackService` in `core/services/audio/`.
**Migration risk**: Low.

---

### [CUBIT COUPLING] Duplicated _getMouthState() logic

**Files**: `lib/features/talking/domain/services/tts_playback_service.dart`, `lib/features/talking/presentation/bloc/talking_cubit.dart`
**Problem**: Identical mouth state mapping logic exists in both files.
**Fix**: Keep one canonical implementation, have the other delegate.
**Migration risk**: Low.

---

### [PRESENTATION] BlocBuilder wrapping entire MaterialApp

**File**: `lib/main.dart` (lines 105-122)
**Problem**: `BlocBuilder<ChatCubit, ChatState>` wraps the entire `MaterialApp` to handle locale changes. Any chat state change triggers a full app rebuild.
**Fix**: Move locale to a dedicated `LocaleCubit` or use `SettingsCubit` for locale. Narrow the `BlocBuilder` scope.
**Migration risk**: Medium.

---

### [PRESENTATION] Core widget imports from feature

**File**: `lib/core/widgets/constrained_width.dart`
**Problem**: Core widget imports from `features/avatar/` — a core-to-feature dependency that reverses the intended flow.
**Fix**: The widget should receive its data via parameters, not reach into a feature cubit.
**Migration risk**: Low.

---

### [ROUTING] Type-unsafe route extras

**File**: `lib/core/router/app_router.dart` (line 77)
**Problem**: `LlmConfig` is passed via `state.extra` with `as LlmConfig?` cast — no null guard, not serializable, breaks deep linking.
**Fix**: Use path parameters or a typed route data class with serialization.
**Migration risk**: Medium.

---

### [ROUTING] Hardcoded route string in widget

**File**: `lib/features/settings/widgets/task_llm_config_tile.dart`
**Problem**: Uses hardcoded `"/settings/llm/task-llm"` instead of the `Routes` constants.
**Fix**: Import and use `Routes.taskLlmConfig` (or fix the constant to match the actual route).
**Migration risk**: Low.

---

### [ROUTING] Unused route constant

**File**: `lib/core/router/route_constants.dart`
**Problem**: `taskLlmConfig` constant is defined but the route in `app_router.dart` uses a different path (`task-llm` as subpath of `llm`).
**Fix**: Align the constant with the actual route or remove it.
**Migration risk**: Low.

---

### [STANDARDS] Constructor side effects in ChatLocalDatasource

**File**: `lib/features/chat/data/datasources/chat_local_datasource.dart`
**Problem**: Runs `_migrateChatDataIfNeeded()` in the constructor. Migrations should not happen at instantiation time.
**Fix**: Move migration to an explicit `init()` or `migrate()` method called after construction.
**Migration risk**: Low.

---

### [STANDARDS] SettingsRepositoryImpl is 269 lines of boilerplate

**File**: `lib/features/settings/data/repositories/settings_repository_impl.dart` (269 lines)
**Problem**: Nearly identical try/catch/Either wrappers for every method.
**Fix**: Create a generic `SafeDatasourceWrapper<T>` that handles the try/catch/Either pattern.
**Migration risk**: Low.

---

### [STANDARDS] SettingsLocalDatasource is 261 lines of repetition

**File**: `lib/core/services/settings_local_datasource.dart` (261 lines)
**Problem**: Repetitive getter/setter for Google Search, OpenWeather, NYT API keys.
**Fix**: Use a generic `getApiKey(String service)` / `setApiKey(String service, String value)` pattern.
**Migration risk**: Low.

---

### [STANDARDS] TtsService is an empty stub

**File**: `lib/core/services/audio/tts_service.dart` (33 lines)
**Problem**: `speak()` and `playWaitingSentence()` only set a type but do not actually play audio. Dead code or incomplete implementation.
**Fix**: Either implement or remove.
**Migration risk**: Low.

---

### [STANDARDS] Empty lib/services/ directory

**File**: `lib/services/` (contains only `.DS_Store`)
**Problem**: Empty directory that should be deleted.
**Fix**: `rm -rf lib/services/`
**Migration risk**: None.

---

### [STANDARDS] Deprecated methods kept in TalkingCubit

**File**: `lib/features/talking/presentation/bloc/talking_cubit.dart`
**Problem**: `@Deprecated` methods (`setLoadingStatus`, `stopTalking`) kept for backward compatibility.
**Fix**: Remove deprecated methods if no longer needed.
**Migration risk**: Low.

---

### [STANDARDS] Commented-out ChatListCubit in service_locator

**File**: `lib/core/di/service_locator.dart` (lines 211-216)
**Problem**: Dead code.
**Fix**: Remove.
**Migration risk**: None.

---

### [MODELS] Chat model split across core and chat feature

**Files**: `lib/core/models/chat.dart` (ChatPersona enum), `lib/features/chat/domain/models/chat.dart` (Chat class)
**Problem**: The Chat model is split — an enum lives in core while the class lives in the chat feature. Other features (avatar, demo) need to import from the chat feature to use the Chat class.
**Fix**: Move the full `Chat` model to `core/models/` since it's shared across features.
**Migration risk**: Low — mechanical move.

---

### [MODELS] AvatarConfig backward-compat field mapping

**File**: `lib/core/models/avatar_config.dart` (lines 87-92)
**Problem**: `fromMap` maps `hat` → `'top'` key and `top` → `'bottom'` key. This reversed naming is a data corruption risk.
**Fix**: Document the mapping clearly or migrate stored data to use consistent keys.
**Migration risk**: Medium — data migration needed.

---

### [MODELS] FunctionInfo uses plain classes instead of freezed

**File**: `lib/core/models/function_info.dart`
**Problem**: Inconsistent with the rest of the codebase which uses freezed extensively.
**Fix**: Convert to freezed.
**Migration risk**: Low.

---

## 🟢 Suggestions

### [STANDARDS] Stale documentation in ChatTitleService

**File**: `lib/features/chat/domain/services/chat_title_service.dart`
**Problem**: Doc comment references `ChatTitleCubit` which does not exist.
**Fix**: Update or remove the stale doc comment.

---

### [STANDARDS] Unused imports in avatar_animation.dart

**File**: `lib/features/avatar/domain/models/avatar_animation.dart`
**Problem**: Unused imports suppressed with `// ignore: unused_import`.
**Fix**: Remove the unused imports.

---

### [STANDARDS] Import path inconsistency

**File**: `lib/core/services/stream_processor/stream_processor_service.dart` (line 6)
**Problem**: Imports `../../../../core/utils/logger.dart` instead of the shorter `../../utils/logger.dart`.
**Fix**: Use the shorter relative path.

---

### [STANDARDS] withOpacity deprecated usage

**Problem**: If any `withOpacity()` calls remain, they should use `.withValues(alpha: ...)`.
**Fix**: Run `dart fix --apply` to auto-migrate.

---

## 📏 File Size Violations

| File | Lines | Limit | Overage |
|------|-------|-------|---------|
| `chat_cubit.dart` | 707 | 300 | **+407** |
| `llm_service.dart` | 408 | 400 | +8 |
| `settings_cubit.dart` | 324 | 300 | +24 |
| `home_bloc_listeners.dart` | 310 | 300 | +10 |

---

## 🗺️ Incremental Migration Plan

**Guiding principle**: Each phase is independently deployable. The app must compile and run after every phase. Commit after each phase.

---

### Phase 1 — DI Integrity _(~12 files, low risk)_

**Goal**: Single source of truth for all wiring. Fix bypasses.

- [ ] Inject `SettingsLocalDatasource` into `PromptDatasource` via constructor
- [ ] Inject `SettingsLocalDatasource` into `LlmConfigManager` via constructor
- [ ] Inject `AvatarLocalDatasource` into `AvatarRepositoryImpl` via constructor (remove `= AvatarLocalDatasource()` default)
- [ ] Inject `SettingsLocalDatasource` + `PromptDatasource` into `ChatLocalDatasource` via constructor
- [ ] Refactor `DemoService` to accept `DemoRepository` via constructor (remove `setRepository()`)
- [ ] Fix `ChatTitleService` injection: `getIt<LlmService>()` → `getIt<LlmServiceInterface>()`
- [ ] Convert `ToolRegistry` from static to injectable class, register in `service_locator.dart`
- [ ] Remove commented-out `ChatListCubit` from `service_locator.dart`
- [ ] Delete empty `lib/services/` directory
- [ ] Remove `@Deprecated` methods from `TalkingCubit`

**Safe because**: Pure mechanical changes — behavior unchanged, just wiring location. Each item is independent.

---

### Phase 2 — Model Consolidation _(~8 files, low risk)_

**Goal**: Shared models live in `core/models/`. Features stop exporting shared types.

- [ ] Move `Chat` class from `features/chat/domain/models/chat.dart` → `core/models/chat.dart`
- [ ] Move `ChatEntry` class from `features/chat/domain/models/chat_entry.dart` → `core/models/chat_entry.dart`
- [ ] Move `AvatarRepository` interface from `features/avatar/domain/repositories/` → `core/repositories/avatar_repository.dart`
- [ ] Update all imports across the codebase (mechanical)
- [ ] Convert `FunctionInfo` to freezed

**Safe because**: Mechanical move + import updates. No behavior change.

---

### Phase 3 — Cubit Decoupling _(~15 files, medium risk)_

**Goal**: No cubit holds a reference to another cubit. Cross-feature coordination goes through core services.

- [ ] **TalkingCubit dependency**: Extract `TalkingService` in `core/services/` that exposes `Stream<TalkingState>`. Remove `TalkingCubit` param from `ChatTtsCubit`. Both subscribe to the service.
- [ ] **home_bloc_listeners coordination**: Extract `AppLifecycleService` in `core/services/` with methods like `onNewChatEntry()`, `onStreamingComplete()`, `onInterruption()`. Move listener logic out of the widget.
- [ ] **AvatarCubit audio**: Extract `AudioPlaybackService` in `core/services/audio/`. Remove `AudioPlayer` from `AvatarCubit._goDownAndUp()`.
- [ ] **Deduplicate `_getMouthState()`**: Keep canonical version in `TtsPlaybackService`, have `TalkingCubit` delegate.
- [ ] **AvatarAnimationService**: Remove `AvatarCubit` reference. Use stream-based communication instead.

**Safe because**: New services are additive. Old cubits keep working until switched over. Do one dependency at a time, commit after each.

---

### Phase 4 — Feature Boundary Cleanup _(~30 files, medium risk)_

**Goal**: Zero cross-feature imports.

For each violation:

- [ ] **avatar → chat**: Already fixed in Phase 2 (Chat model moved to core)
- [ ] **avatar → talking**: Widgets `talking_mouth.dart`, `singularity_costume.dart` should receive talking state via parameters or a core service stream, not import `TalkingCubit` directly
- [ ] **chat → settings**: `chat_entry_service.dart` and `chat_cubit.dart` already receive `SettingsRepository` via constructor — remove the direct import, rely on the injected interface from `core/repositories/`
- [ ] **chat → talking**: Fixed in Phase 3 (TalkingService in core)
- [ ] **chat → avatar**: Screens/widgets should receive avatar state via parameters or core service, not import `AvatarCubit`
- [ ] **chat → demo**: Move `DemoScript` model to `core/models/`
- [ ] **home → all features**: `home_bloc_listeners.dart` refactored in Phase 3. Remaining screen/widget imports should use parameters or core services
- [ ] **settings → chat**: `settings_screen.dart` should not read `ChatCubit` — extract sound effects toggle concern
- [ ] **demo → chat/avatar**: Already fixed in Phase 2 (models moved to core, repo interfaces in core)

**Safe because**: Each violation fix is independent. Start with the features that import the fewest other features (settings, sound) and work outward.

---

### Phase 5 — Presentation Polish _(ongoing, low risk)_

**Goal**: Clean presentation layer — no unnecessary rebuilds, no oversized files.

- [ ] Narrow `BlocBuilder<ChatCubit, ChatState>` in `main.dart` — extract locale to separate concern
- [ ] Scope cubit providers to feature screens (only truly global cubits at root)
- [ ] Split `ChatCubit` (707 → ~300 + domain services for title/function calling)
- [ ] Extract `_buildX` helper methods to separate widget classes
- [ ] Fix type-unsafe `state.extra` in router — use path parameters or typed route data
- [ ] Align route constants with actual paths
- [ ] Extract `SettingsLocalDatasource` boilerplate into generic key-value pattern
- [ ] Remove constructor side effects from `ChatLocalDatasource`
- [ ] Implement or remove `TtsService` stub

**Safe because**: UI-only changes, no logic modifications.

---

## Estimated Effort

| Phase | Files Affected | Risk | LLM Agent Alone? |
|-------|---------------|------|-------------------|
| 1 — DI integrity | ~12 | Low | ✅ Yes |
| 2 — Model consolidation | ~8 | Low | ✅ Yes |
| 3 — Cubit decoupling | ~15 | Medium | ✅ Yes (one dep at a time) |
| 4 — Feature boundaries | ~30 | Medium | ⚠️ Review each fix |
| 5 — Presentation polish | ~20 | Low | ✅ Yes |

---

**Next step**: Which phase would you like to start with?
