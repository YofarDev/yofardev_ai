# Audit Findings — Remediation Spec

**Date:** 2026-11-02 · **Audited at commit:** `ff90a9d` (branch `main`, clean tree)
**Method:** `flutter test test/architecture_test.dart` (16/16 green), `./scripts/fanal.sh`,
four deep-analysis sweeps (state management, error handling, presentation, DI). Every
critical finding below was re-verified by direct file reads, not grep alone.

This document is the spec the remediation plan
(`docs/superpowers/plans/2026-11-02-audit-remediation.md`) argues from. Line numbers were
accurate at audit time; the plan's phases may shift them — locate items by symbol name.

---

## Critical findings (all remediated)

### C1. Two cubits persist the same avatar data through two repositories

- `lib/features/chat/presentation/bloc/chat_cubit.dart:329-370` —
  `updateAvatarOpenedChat` merges `AvatarConfig` into `Chat.avatar` field-by-field
  (`hat: avatarConfig.hat ?? chat.avatar.hat`, ~8 fields) and saves via
  `_chatRepository.updateAvatar` (`lib/core/repositories/chat_repository.dart:19` →
  `lib/features/chat/data/datasources/chat_local_datasource.dart:134`).
- `lib/features/avatar/presentation/bloc/avatar_cubit.dart:851-878` — `_updateAvatar`
  merges the same way (`hat: avatarConfig.hat ?? state.avatar.hat`) and saves via
  `_avatarRepository.updateAvatar`
  (`lib/features/avatar/domain/repositories/avatar_repository.dart:7` →
  `lib/features/avatar/data/datasources/avatar_local_datasource.dart:38`).
- One `AvatarTool` change travels `avatarChangeRequestedEvents` → ChatCubit persists
  (`chat_cubit.dart:101-117`) → animation event → AvatarCubit `_updateAvatar` persists
  again. Two writers, two storage paths, one field; the merge rule is hand-duplicated.
  `lib/features/demo/data/repositories/demo_repository_impl.dart:42` persists through the
  avatar repository as well.
- The "which avatar fields changed?" rule is triplicated:
  `lib/core/services/app_lifecycle_service.dart:122-138`,
  `chat_cubit.dart:145-151`, `avatar_cubit.dart:490-496`.

### C2. Coordination events subscribed to but never emitted (zombie wiring)

- `lib/core/services/app_lifecycle_service.dart:208` `emitAvatarAnimationChanged`,
  `:215` `emitTalkingStateChanged`, `:229` `emitDemoScriptChanged` — zero call sites in
  `lib/` (verified by grep, definitions only).
- Consequences: `lib/features/home/presentation/bloc/home_cubit.dart:18-34` subscribes two
  of them (its `isFading`/`isPlayingWaitingLoop` are permanently false and read by no
  widget); `home_cubit.dart:95` `playTts` has zero callers;
  `chat_cubit.dart:168-187` demo activation never runs.

### C3. Avatar saves emit success before persisting, then discard the failure

- `chat_cubit.dart:367` and `:397` — `await _chatRepository.updateAvatar(...)` result
  ignored; `status: ChatStatus.success` emitted *before* the write. A failed write
  vanishes silently while the UI shows the change.
- Elsewhere ChatCubit does this correctly: `chat_cubit.dart:223-225`
  `err: (failure) => emit(state.copyWith(status: ChatStatus.error, error: failure))`.

### C4. The one empty failure handler, fire-and-forget

- `lib/core/di/service_locator.dart:675-681` —
  `unawaited(getIt<SettingsRepository>().getSoundEffects().then(...))` with
  `err: (Failure failure) {},`. No log, setting silently stays unset.

## Warnings remediated by the plan

### W1. Async lifecycle / ordering gaps (state management)

- Unguarded emits after `await`: `chat_cubit.dart:436-443` (`updateChatStreaming`),
  `:520-522` (`generateTitle`, incl. a `finally` emit), `:625` (stream-complete callback);
  `settings_cubit.dart:37` (subscription callback), `:98`, `:209`, `:225`, `:258`;
  `chat_tts_cubit.dart:358` (catch path). AvatarCubit's `_emitIfOpen`
  (`avatar_cubit.dart:226-228`) is the house pattern to copy.
- `avatar_cubit.dart:258-289` `loadAvatar` has no request id: two rapid chat switches race;
  if the older `getChat` resolves last it overwrites the newer chat's avatar/scene. The
  journey epoch (`avatar_cubit.dart:729`) does not cover this read.
- `chat_cubit.dart:316-325` `deleteChat` can be resurrected by an in-flight
  `fetchChatsList` (`:259` overwrites `chatsList` wholesale).

### W2. ChatCubit holds screen-shaped state app-lifetime; `/chats/:id` param decorative

- `lib/app.dart:40-42` resolves ChatCubit once at the app root (by design — Home's stage
  reads it; keep app scope).
- But `lib/core/router/app_router.dart:127-136` builds `ChatDetailsPage()` with no id;
  the chat arrives via `context.read<ChatCubit>().setOpenedChat(chat)` immediately before
  `push` (`lib/features/chat/widgets/chat_list_container.dart:57-59`). Navigating
  directly to `/chats/<id>` shows the wrong chat. `registerFactoryParam` is never used.

### W3. Dead code (state + DI)

- Dead state fields: `chat_state.dart:29` `chatsListStatus` (never written);
  `chat_state.dart:34` `audioPathsWaitingSentences` (the live copy is
  `chat_tts_state.dart:11`; the ChatState copy is never touched by `chat_cubit.dart`).
- Dead members: `chat_tts_cubit.dart:404` `shuffleWaitingSentences` (zero callers),
  `:413` `initialize` (zero callers; body admits it is unimplemented);
  `talking_cubit.dart:237` `startAmplitudeAnimation` (zero callers; its
  `_animationCompleter` is never completed), `:296` `stopTalking` (zero callers),
  `setLoadingStatus` `@Deprecated` yet called internally at `talking_cubit.dart:99`;
  legacy vocab `talking_state.dart:9` `enum TalkingStatus`, `:67` `status` getter,
  `:83` `AnswerData`.
- Dead registrations (never resolved in production; consumers build their own):
  `service_locator.dart:274` `AudioAnalyzer`, `:218-223`
  `LlmStreamingServiceInterface`, `:314` `LocaleRepository`, `:690` `SoundCubit`
  (SoundCubit is also never provided by any route).
- `HomeCubit` (`lib/features/home/presentation/bloc/home_cubit.dart`, provided at
  `app_router.dart:103,106`) is entirely driven by the dead events of C2.
  `HomeRepositoryImpl` (`lib/features/home/data/repositories/home_repository_impl.dart`)
  exists to serve it (`playTts`/`stopTts`/`startVolumeFade`).

### W4. Presentation debt in the older chat/settings screens

(The Home/Stage side is exemplary — port its discipline; do not touch it.)

- Unscoped full-body `BlocBuilder<ChatCubit>` (ChatCubit emits per streaming chunk):
  `chats_list_screen.dart:57`, `chat_details_screen.dart:51`, nested builder reading one
  bool at `:90-101`, `ai_text_input.dart:114`.
- `settings_screen.dart:1` file-wide
  `// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously`;
  `:69-76` `context.pop()` after four awaits with no mounted check; `:44` raw
  `stream.listen` in initState copying cubit state into local fields, subscription never
  cancelled; `:36` `_isSoundEffectsEnabled = true` hardcoded default.
- `ai_text_input.dart:42` `_isSubmitting` mirrors cubit-owned streaming state,
  reconciled by a listener hack at `:120-124`; `_controller` never disposed
  (`:91-94`); `:86`/`:272` `setState` after awaits without mounted check.
- `chat_details_screen.dart:68` `AppLogger.debug` inside the builder (per-chunk log spam).
- `floating_stop_button.dart:26-34` nested builders, raw `is SpeakingState` checks
  duplicating the `TalkingState.phase` extension
  (`talking_state.dart:43`); same raw checks at `ai_text_input.dart:120,188-189`.
- `app_router.dart:89-98` `BlocBuilder<AvatarCubit>` wraps the whole home route page
  while consuming only `status`, `baseOriginalWidth`, `scaleFactor`.

### W5. Error-handling consistency (subset remediated)

- `avatar_local_datasource.dart:27-34` `getChat` catches everything (`catch (e)` — no
  stack trace) and `return null`, making corrupt JSON indistinguishable from "not found";
  `avatar_repository_impl.dart:19-21` hard-maps null to `StorageFailure('Chat not found')`.
- Repository failure-mapping tests exist only for chat + locale + Kokoro.
  `SettingsRepositoryImpl` (largest surface) has none.

## Explicitly deferred (documented, NOT in this remediation)

Hand-rolled `LlmService` singleton with static test hooks (`llm_service.dart:21-48`);
debug builds resolving `FakeLlmService` (`service_locator.dart:202-205`); eager
materialization of six lazy singletons; dispose callbacks nothing fires; Kokoro engine /
HTTP client lifetime; `AvatarCubit` screen-scaling and direct sound playback; SettingsCubit
global-memory CRUD split; `yofardev_repository_impl` error taxonomy;
`getCurrentChat`'s boolean race patch; widget-test backfill beyond the repos named above.

## Hard constraints (from AGENTS.md — binding)

- `Result<T>` from `lib/core/models/result.dart`; fpdart banned.
- Unknown exceptions via `mapExceptionToFailure(e, stackTrace: st, tag: ...)`; UI text
  only via `localizeFailure`; never display `failure.message` / `e.toString()`.
- All DI in `lib/core/di/service_locator.dart`; `getIt` resolved only in the three
  composition roots; cubits never depend on cubits (domain services / event streams).
- Cross-feature imports via feature barrels only; acyclic features; `core/` never imports
  features (except `core/di`, `core/router`).
- Explicit types (`always_specify_types`); relative imports; user-facing strings through
  `AppLocalizations` (`./scripts/fstr.sh`); no raw colors/fonts outside `lib/core/design/`.
- Rive types only in `lib/features/avatar/presentation/` and `lib/core/design/rive/`.
- Freezed model / ARB changes require regeneration (`build_runner` / `flutter gen-l10n`).
- Quality gate: `dart fix --apply`, `dart format .`, `./scripts/fverify.sh` — golden
  tests must NOT be regenerated (`--update-goldens` is forbidden here; no visual change
  is intended by this remediation).
