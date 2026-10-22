# Yofardev AI — Architecture Audit (2026-10-22)

This is the spec the alignment plan implements. Audit method: `flutter test test/architecture_test.dart` (all 4 enforced rules pass), `./scripts/fanal.sh` (report at `flutter_analysis.md`), plus manual file reads.

Local override of the `flutter-architecture` skill: this project uses its own sealed `Result<T>` (`lib/core/models/result.dart`, `Result.ok` / `Result.err(Failure)`) instead of fpdart's `Either`. fpdart is banned by the architecture test. Everything else follows the skill.

## Findings to fix (all covered by the plan)

### Critical

1. **Domain → presentation import**: `lib/features/avatar/domain/models/avatar_animation.dart:4` imports `../../presentation/bloc/avatar_state.dart` — used only by a `[AvatarCubit]` doc-comment reference.
2. **Domain → data dependency**: `lib/features/sound/domain/services/tts_queue_service.dart` holds `TtsDatasource` (from `data/datasources/`) as a constructor field; only method used is `textToFrenchMaleVoice({required String text, required String language, required VoiceEffect voiceEffect})`.
3. **main.dart reaches into feature data internals**: imports `features/chat/data/datasources/chat_local_datasource.dart` (calls `.init()` migration) and `features/sound/data/datasources/tts_datasource.dart` (static `initSupertonic()`); also reads `SharedPreferences` for language directly while `LocaleRepository` exists. `App.initialLanguage` is passed but never read (dead).
4. **`getIt` resolved outside the composition-root allowlist** (`app.dart`, `app_router.dart`, `service_locator.dart` only):
   - `lib/features/chat/presentation/bloc/chat_cubit.dart:166` — `getIt<DemoService>()` in `_handleDemoScriptChangedEvent`
   - `lib/features/home/screens/home_screen.dart:72` — `getIt<DemoService>()` in `_startDemoMode()`
   - `lib/features/settings/screens/llm/llm_selection_page.dart:18` — field `getIt<LlmServiceInterface>()`
   - `lib/features/settings/screens/llm/llm_config_page.dart:20` — field `getIt<LlmServiceInterface>()`
   - `lib/features/chat/widgets/floating_stop_button.dart:69` — `getIt<InterruptionService>()` fallback (the `context.read` above it always throws — never provided via context)
   - `lib/core/services/agent/avatar_tool.dart:13` — getter `getIt<AppLifecycleService>()`
5. **Error handling**: no exception-mapper boundary (`lib/core/errors/` absent); every repo/datasource does catch-all `Failure(e.toString(), e)`; cubits emit `e.toString()` into UI states (`sound_cubit.dart:31`, `talking_cubit.dart:132,143`, `chat_tts_cubit.dart:200,245`); `chat_details_screen.dart:217` shows `failedToDownload(e.toString())` to the user; no `localizeFailure`. Failure variants that exist: `StorageFailure`, `NetworkFailure`, `TtsFailure`, `ConfigFailure`, `UnknownFailure` (`lib/core/models/failure.dart`).

### Warnings

6. **Repository interfaces in `core/repositories/`**: `avatar_repository.dart`, `settings_repository.dart`, `global_memory_repository.dart`, `locale_repository.dart` + `locale_repository_impl.dart` (interface and impl together in core). Decisions:
   - `AvatarRepository` → `features/avatar/domain/repositories/` (consumers: avatar feature, demo feature via barrel, DI, tests).
   - `GlobalMemoryRepository` → `features/chat/domain/repositories/` (impl already there; consumers: chat feature, settings cubit via barrel, DI, tests).
   - `LocaleRepository` + impl → settings feature (language is a setting).
   - `SettingsRepository` **stays in core** — consumed by `core/services/agent/tool_registry.dart`, and core may not import features.
   - `SettingsLocalDatasource` and `PromptDatasource` **stay in `core/services/`** — shared storage infrastructure consumed across boundaries (`llm_config_manager`, `llm_service`, chat datasources); `PromptDatasource` is consumed by `ChatStreamingService` (domain), so moving it into chat `data/` would create a new domain→data leak.
7. **`DemoController` in `core/services/`** → belongs to `features/demo/domain/services/` (pure `ChangeNotifier` singleton; consumers: demo feature files + DI only).
8. **`ChatCubit.close()` and `DemoCubit.close()`** don't await subscription/listener teardown.
9. **Dead code**: `switchLlmService()` (`service_locator.dart:286-298`, zero callers, unregister/re-register trap); `ChatState.chatsListError` (declared, never emitted, never read); `ChatCubit.setError` (zero callers).
10. **`ChatState.errorMessage` / `SettingsState.errorMessage`** are untyped strings; `ai_text_input.dart:105` renders `state.errorMessage` directly.

### Deliberate non-changes (documented)

- App-scoped providers (Settings, Talking, Chat, ChatTts, Avatar cubits in `app.dart`) are intentional: persistent chat + global avatar.
- `LlmServiceInterface` registers `FakeLlmService` in debug builds — intentional demo support.
- `ChatState` stays a single flat state (one coherent conversation state machine); only its error fields get typed. No micro-split.
- `core/services/agent/` (LLM tools) stays in core as LLM integration infrastructure.
- `fanal` direct-color and `_buildX` helper findings are style, not architecture.

### Test gaps

- No DI smoke test (`test/core/di/service_locator_test.dart` referenced by docs but absent).
- `demo` and `home` features have no cubit tests.
- Architecture checker is line-based and doesn't enforce: intra-feature layer direction, getIt allowlist, registrations-only-in-locator.
