# Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate the 2026-11-02 architecture-audit findings — swallowed failures, zombie wiring, dual avatar persistence, dead code, the broken `/chats/:id` route, and presentation debt in the chat/settings screens — in six independently shippable phases.

**Architecture:** Each phase is a self-contained change set that must leave the app compiling and `./scripts/fverify.sh` green. Correctness fixes come first, then the avatar single-writer refactor, then deletions, then the route/state fix, then presentation polish, then targeted test backfill. Line numbers cite the audit commit `ff90a9d`; **earlier phases shift them — always locate code by symbol name, never by line alone.**

**Tech Stack:** Flutter ≥3.8 / Dart ≥3.8, flutter_bloc 9 (Cubit), freezed 3 + json_serializable, get_it 9, go_router 17, `Result<T>` (project-owned; fpdart banned).

**Spec:** `docs/superpowers/specs/2026-11-02-audit-remediation-findings.md` — the audit findings (C1–C4, W1–W5) and the hard constraints. The plan argues from it; on conflict, the spec wins.

## Global Constraints

Copied from the spec (binding for every phase):

- `Result<T>` from `lib/core/models/result.dart` — never `Either`, never fpdart. Unknown exceptions via `mapExceptionToFailure(e, stackTrace: st, tag: '<Class>')`. UI error text only via `localizeFailure`; never display `failure.message` / `e.toString()`.
- All DI in `lib/core/di/service_locator.dart`. `getIt` resolved only in `service_locator.dart`, `lib/app.dart`, `lib/core/router/app_router.dart`. Cubits never hold cubits.
- Explicit types everywhere (`always_specify_types: true` — no `var` in new code); relative imports; user-facing strings via `AppLocalizations` (`./scripts/fstr.sh "key" "FR" "EN"`); no raw colors outside `lib/core/design/`.
- Feature `domain/` never imports its feature's `data/` or `presentation/`; cross-feature imports via barrels only.
- Freezed model field changes ⇒ `dart run build_runner build --delete-conflicting-outputs`. ARB changes ⇒ `flutter gen-l10n`. Never hand-edit `*.g.dart` / `*.freezed.dart`.
- **Golden tests must not be regenerated** (`--update-goldens` forbidden — no visual change is intended).
- Per phase: `dart fix --apply && dart format .` then `./scripts/fverify.sh` must pass (format check + `flutter analyze` + full `flutter test`, including `test/architecture_test.dart`).
- Do not commit — the orchestrator commits after each phase passes its gate and review.

## Scope

**In:** findings C1–C4, W1–W5 (see spec).
**Out (deferred):** everything listed under "Explicitly deferred" in the spec. If a phase tempts you into one of those, stop and note it in your report instead.

---

## Phase 1 — Correctness fixes: swallowed results, emit guards, read ordering

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (`updateAvatarOpenedChat`, `updateBackgroundOpenedChat`, `generateTitle`, streaming callbacks, `updateChatStreaming`)
- Modify: `lib/core/di/service_locator.dart` (sound-effects startup read, ~line 675)
- Modify: `lib/features/settings/presentation/bloc/settings_cubit.dart` (post-await emits)
- Modify: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (catch-path emit ~line 358)
- Modify: `lib/features/avatar/presentation/bloc/avatar_cubit.dart` (`loadAvatar`)
- Test: the existing ChatCubit test file(s) — locate with `rg -l "ChatCubit\(" test | head`; add cases there.

**Interfaces (produced, later phases rely on them):**
- `AvatarCubit.loadAvatar` becomes ordering-safe (epoch-guarded) — Phase 2 edits `_updateAvatar` in the same file.
- `ChatCubit.updateAvatarOpenedChat` returns after awaiting persistence and reports failure through `state.status`/`state.error` — Phase 2 changes what it awaits, not the contract.

- [ ] **Step 1.1: Fail visibly when an avatar save fails (spec C3).**
  In `updateAvatarOpenedChat` and `updateBackgroundOpenedChat` (locate by symbol):
  1. Keep building `updatedChat`/`updatedChatsList` as now.
  2. Replace the pattern *emit success, then `await _chatRepository.updateAvatar(...)` and ignore the result* with:

  ```dart
  final Result<void> saveResult =
      await _chatRepository.updateAvatar(chat.id, updatedChat.avatar);
  if (isClosed) {
    return;
  }
  saveResult.when(
    err: (Failure failure) {
      AppLogger.error(
        'Failed to save avatar change for chat ${chat.id}',
        error: failure,
        tag: 'ChatCubit',
      );
      emit(state.copyWith(status: ChatStatus.error, error: failure));
    },
    ok: (_) {
      emit(state.copyWith(
        openedChat: updatedChat,
        currentChat: updatedChat,
        chatsList: updatedChatsList,
        status: ChatStatus.success,
      ));
    },
  );
  ```

  Match the exact field set each method already updates (`updateAvatarOpenedChat` also has its own emit shape — keep its fields, change only the ordering + result handling). Mirror the existing err-emit idiom at `chat_cubit.dart` `_failReply` / `getCurrentChat` err branches. Check what `AppLogger.error`'s actual signature is first and use it (grep an existing call).
- [ ] **Step 1.2: Log the swallowed startup failure (spec C4).** In `service_locator.dart`, the `getSoundEffects()` read (~line 675): replace `err: (Failure failure) {},` with a branch that calls `AppLogger.warning(...)` with a stable message including the failure. Match the file's existing `AppLogger` import/usage.
- [ ] **Step 1.3: Guard post-await emits (spec W1).** Add `if (isClosed) return;` before every `emit` that follows an `await` in: `chat_cubit.dart` — `generateTitle` (all three emits, including the `finally` one: guard the emit inside `finally`, not the return), the stream-complete callback (~`:625`), and `updateChatStreaming` (~`:436-443`); `settings_cubit.dart` — `refreshLlmConfigs` and every other load/refresh method that emits after an await (~`:98`, `:209`, `:225`, `:258`) plus the `TtsEngineStatus` subscription callback (~`:37`); `chat_tts_cubit.dart` — the catch-path emit (~`:358`). Do NOT restructure the methods; add the guard only. If an emit is already guarded (e.g. via `interrupted()`), leave it.
- [ ] **Step 1.4: Make `loadAvatar` latest-request-wins (spec W1).** In `avatar_cubit.dart`, add a field `int _loadEpoch = 0;` next to `_journeyEpoch`. At the top of `loadAvatar`: `final int epoch = ++_loadEpoch;`. After the `getChat` await (where the existing `if (isClosed) return;` sits), extend it to `if (isClosed || epoch != _loadEpoch) { return; }`. Nothing else changes.
- [ ] **Step 1.5: Test the new failure path.** In the existing ChatCubit test file, add a case: stub the chat repository's `updateAvatar` to return `Result.err(const StorageFailure('disk full'))` (use the fakes/mocks the file already uses; see how its existing tests construct a cubit), call `updateAvatarOpenedChat(...)` on a cubit with an opened chat, await it, and expect `state.status == ChatStatus.error` and `state.error` is a `StorageFailure`. Also assert the success path still reaches `ChatStatus.success` when the stub returns `Result.ok(nil)`-equivalent (check `Result`'s ok constructor for `void`).
- [ ] **Step 1.6: Verify.** `flutter analyze` clean; `flutter test` for the touched test dirs (`test/features/chat test/features/settings test/features/avatar` — plus `test/core/di` if Step 1.2 touched its smoke test). Do NOT run the full suite or `fverify.sh` (the orchestrator gates with it). Do not regenerate goldens.

**Acceptance criteria:** No `await _chatRepository.updateAvatar` result is discarded anywhere in `chat_cubit.dart`; no `err: (Failure failure) {}` remains in `service_locator.dart`; every post-await emit listed above is guarded; `loadAvatar` drops stale results; the new test case passes and fails if the ordering fix is reverted.

---

## Phase 2 — Single avatar writer: `AvatarConfig` merge + one persistence path

**Files:**
- Modify: `lib/core/models/avatar_config.dart` (add the merge rule)
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (use the merge rule; drop the local merge copy)
- Modify: `lib/features/avatar/presentation/bloc/avatar_cubit.dart` (external config no longer persists; internal mutations persist through the chat repository)
- Modify: `lib/features/avatar/domain/repositories/avatar_repository.dart`, `lib/features/avatar/data/repositories/avatar_repository_impl.dart`, `lib/features/avatar/data/datasources/avatar_local_datasource.dart` (drop `updateAvatar` if it becomes unused)
- Modify: `lib/features/demo/data/repositories/demo_repository_impl.dart` (persist via `ChatRepository`)
- Modify: `lib/core/di/service_locator.dart` (wiring changes)
- Test: a new `test/core/models/avatar_config_merge_test.dart` (or extend an existing avatar_config test if one exists).

**Interfaces (produced):**
- `AvatarConfig.applyTo(Avatar base) → Avatar` on the `AvatarConfig` model in `lib/core/models/avatar_config.dart` — THE merge rule (Phase 3+ and all future code use it).
- `ChatRepository.updateAvatar` is the only avatar persistence path in the app.

**Decision rules (follow in order; record which fired in your report):**

- [ ] **Step 2.0: Establish storage facts.** Read `lib/features/chat/data/datasources/chat_local_datasource.dart` and `lib/features/avatar/data/datasources/avatar_local_datasource.dart` end to end. Write one paragraph in your report: where does each read/write chat+avatar data (same store/keys or different)? This decides Step 2.3's blast radius. If the two datasources share the same underlying store (likely — both speak `Chat`), the migration below is behavior-preserving. If they differ, still unify on the **chat** store (the Chat is the source of truth) and say so loudly in your report.
- [ ] **Step 2.1: Add the merge rule.** In `avatar_config.dart`, add a method on `AvatarConfig`:

  ```dart
  /// Returns [base] with every field of this config that is set (non-null)
  /// overriding the base value. The single merge rule for avatar changes.
  Avatar applyTo(Avatar base) => base.copyWith(
        background: background ?? base.background,
        hat: hat ?? base.hat,
        // …continue for EVERY AvatarConfig field, exactly once each.
      );
  ```

  Enumerate `AvatarConfig`'s fields from the model itself and cover all of them — check how the existing hand-rolled merges in `chat_cubit.dart` (`updateAvatarOpenedChat`) and `avatar_cubit.dart` (`_updateAvatar`) do it; `applyTo` must reproduce that union of fields. If `Avatar` has no `copyWith`, construct it explicitly with every field. This is a plain method (no new fields) — no `build_runner` needed; if you find you must add fields, run `build_runner` and say so in the report.
- [ ] **Step 2.2: Both cubits use the rule.** In `chat_cubit.dart` `updateAvatarOpenedChat`: replace the hand-rolled field-by-field merge with `final Chat updatedChat = chat.copyWith(avatar: avatarConfig.applyTo(chat.avatar));` (keep any surrounding logic the method has, e.g. its background-override branch — re-read the method and preserve its exact semantics). In `avatar_cubit.dart` `_updateAvatar`: same replacement using `state.avatar` as the base. Delete the duplicated field lists.
- [ ] **Step 2.3: One persistence path.**
  1. `AvatarCubit._updateAvatar` — replace `unawaited(_avatarRepository.updateAvatar(chatId, avatar))` (or the awaited form) with the same call on a `ChatRepository` (inject `ChatRepository` from `core/repositories/chat_repository.dart` via `AvatarCubit`'s constructor; register the dependency in `service_locator.dart`'s `AvatarCubit` factory). Importing `core/repositories/` from a feature is the sanctioned pattern.
  2. External config changes must persist **exactly once** — in ChatCubit. In `avatar_cubit.dart`, the public entry called from the `avatarChangeRequestedEvents` subscription (`updateAvatarConfig`, ~line 187/986) currently funnels into `_updateAvatar`, which persists. Split it: external config → update state + animate only (a private `_applyExternalConfig` that does everything `_updateAvatar` does *except* the repository write); self-originated mutations (journey landings, prop, gestures — the internal `_updateAvatar` call sites) keep persisting. Add a doc comment on both stating the contract: "external avatar config is persisted by ChatCubit (the requester); only avatar-driven mutations persist here".
  3. `demo_repository_impl.dart` (~`:42`): switch `avatarRepository.updateAvatar(...)` to the `ChatRepository` (adjust its constructor + `service_locator.dart` wiring).
  4. Delete `updateAvatar` from `AvatarRepository` (interface), `AvatarRepositoryImpl`, and `avatar_local_datasource.dart` **iff** `rg -n "updateAvatar" lib` then shows no remaining callers of the avatar path (chat repository + demo + avatar cubit are all migrated). If any caller remains, leave it and note it.
- [ ] **Step 2.4: Test the rule.** New `test/core/models/avatar_config_merge_test.dart`: for a representative `Avatar`/`AvatarConfig` pair, assert (a) a null config field keeps the base value, (b) a non-null config field overrides it, (c) every field of `Avatar` is covered — do this by constructing a base avatar with a sentinel value per field and a config with every field set, asserting the result equals the config's values field by field. Follow the style of an existing model test (find one with `rg -l "group\(" test/core/models | head`).
- [ ] **Step 2.5: Verify.** `flutter analyze`; targeted tests: the new merge test + `test/features/avatar` + `test/features/chat` + `test/core/di`. Architecture tests must stay green (an `AvatarRepository` signature change is feature-internal — legal). Do NOT run the full suite; do not regenerate goldens.

**Acceptance criteria:** `rg -n "hat: .* \?\?" lib` finds no hand-rolled avatar merge outside `avatar_config.dart`; every avatar persistence call site goes through `ChatRepository.updateAvatar`; the events chain persists an external config change exactly once (ChatCubit), and avatar-driven mutations persist exactly once (AvatarCubit); the storage-facts paragraph is in the report; merge test passes.

---

## Phase 3 — Dead-code purge: zombie wiring, dead cubits, dead registrations, dead members

**Files (each deletion is grep-gated — see steps):**
- Modify: `lib/core/services/app_lifecycle_service.dart`; delete `lib/features/home/presentation/bloc/home_cubit.dart` (+ its state file); `lib/core/router/app_router.dart`; `lib/features/chat/presentation/bloc/chat_cubit.dart` (demo path) and `chat_state.dart` (dead fields); `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (dead members); `lib/features/talking/presentation/bloc/talking_cubit.dart` + `talking_state.dart` (dead members/legacy vocab); `lib/features/home/data/**` (conditionally, whole repository stack); `lib/core/di/service_locator.dart` + `test/core/di/service_locator_test.dart`; delete `lib/features/sound/presentation/bloc/sound_cubit.dart` (+ state) if nothing provides it.
- Regenerate: `build_runner` (ChatState field deletions).

**Interfaces (consumed/produced):** Phase 1/2 shapes are stable; this phase only removes. Phase 4/5 implementers must not find references to anything deleted here (the gate: `rg` returns zero hits).

**Rules for every step:** before deleting a symbol, run `rg -n "<symbol>" lib test integration_test tool` — if there are hits beyond the definitions/registrations named in the step, DO NOT delete that symbol; leave it, and record it in your report as "deferred: still referenced at <paths>".

- [ ] **Step 3.1: Delete the zombie events (spec C2).** In `app_lifecycle_service.dart`: delete `emitAvatarAnimationChanged`, `emitTalkingStateChanged`, `emitDemoScriptChanged`, their backing stream getters/fields, and any types used only by them (e.g. `AvatarStatusAnimation`/`DemoScript` if now unreferenced — grep first).
- [ ] **Step 3.2: Delete `HomeCubit` and its stack.** Delete `home_cubit.dart` (+ state file). In `app_router.dart` (~`:103,106`): remove its `BlocProvider` from the home route (keep `DemoCubit`'s). Then grep `HomeRepository`/`home_repository` — if `HomeCubit` was the only consumer (expect yes: `playTts`/`stopTts`/`startVolumeFade`), delete `lib/features/home/data/repositories/home_repository_impl.dart`, the `HomeRepository` interface in `lib/features/home/domain/repositories/`, any home datasource files that served only it, their DI registrations in `service_locator.dart`, and any tests that mock them. Check the home feature barrel (`lib/features/home/` has none per AGENTS.md — features import Home only via the router; verify with grep). Also delete the `flutter_analysis.md`-style leftovers if any test imports the deleted files (`rg -l "HomeCubit|HomeRepository" test`).
- [ ] **Step 3.3: Delete `SoundCubit`.** It is registered (`service_locator.dart` ~`:690`) but never provided anywhere. Delete `sound_cubit.dart` + its state + the registration + its lines in `test/core/di/service_locator_test.dart` (and any other test referencing it — grep).
- [ ] **Step 3.4: Delete dead registrations.** In `service_locator.dart`: `AudioAnalyzer` (~`:274` — `AudioAmplitudeService` builds its own), `LlmStreamingServiceInterface` (~`:218-223` — `LlmService` constructs its own), `LocaleRepository` (~`:314` — only the DI smoke test resolves it; keep the class, delete the registration). Update the DI smoke test accordingly.
- [ ] **Step 3.5: ChatCubit demo path.** Delete the `demoScriptChangedEvents` subscription block (~`chat_cubit.dart:59-69,168-187`) and, if `_demoService` then has no other use in the cubit, remove the field/constructor param + the DI factory arg + fix every test constructing `ChatCubit` (grep `rg -n "DemoService" test lib/features/chat`).
- [ ] **Step 3.6: Dead state fields.** In `chat_state.dart`: delete `chatsListStatus` (+ its `ChatsListStatus` enum if unreferenced elsewhere — grep) and `audioPathsWaitingSentences` (the live copy in `chat_tts_state.dart` stays). Freezed change ⇒ run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 3.7: Dead members.** `chat_tts_cubit.dart`: delete `shuffleWaitingSentences` and `initialize` (grep first). `talking_cubit.dart`: delete `startAmplitudeAnimation` + `_animationCompleter`, `stopTalking`; inline `setLoadingStatus`'s body at its single internal call site (~`:99`) and delete the method. `talking_state.dart`: delete `enum TalkingStatus`, the `status` getter, and `AnswerData` **only if** `rg -n "TalkingStatus|AnswerData" lib test` is clean outside `talking_state.dart` (widgets use `.phase` — but verify; if referenced, defer with a note).
- [ ] **Step 3.8: Verify.** `dart fix --apply` will run in the gate; you run `flutter analyze` (expect zero references to deleted symbols) + `flutter test test/core/di test/features/chat test/features/talking test/features/home test/features/sound 2>/dev/null || true` (some dirs may no longer exist after deletions — run the ones that do). Do not run the full suite; do not regenerate goldens. Note: if `build_runner` regenerated anything, include that in the report.

**Acceptance criteria:** `rg -n "emitAvatarAnimationChanged|emitTalkingStateChanged|emitDemoScriptChanged|HomeCubit|SoundCubit|shuffleWaitingSentences|startAmplitudeAnimation|chatsListStatus|audioPathsWaitingSentences" lib test` returns only hits in `chat_tts_state.dart`/`chat_tts_cubit.dart` (the live TTS copy) — or documented deferrals; `fverify` (run by orchestrator) green including the architecture tests; the DI smoke test updated, not deleted.

---

## Phase 4 — `/chats/:id` becomes real + the delete/fetch race

**Files:**
- Modify: `lib/core/router/app_router.dart` (`/chats/:id` route builder)
- Modify: `lib/features/chat/screens/chat_details_screen.dart` (`ChatDetailsPage`)
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (new `openChatById`, delete/fetch race fix)
- Test: existing ChatCubit test file (+ router test if one exists — `rg -l "chats/:id\|ChatDetailsPage" test`).

**Interfaces (produced):** `ChatCubit.openChatById(String chatId) → Future<void>` (loads the chat from the repository when it is not already the opened one, then emits the same state shape `setOpenedChat` produces). `ChatDetailsPage` gains an optional `final String? chatId;` constructor param.

- [ ] **Step 4.1: Route passes the id.** In the `/chats/:id` builder: `final String? chatId = state.pathParameters['id'];` and pass `ChatDetailsPage(chatId: chatId)` (keep `ConstrainedWidth` and any other wrappers exactly as they are).
- [ ] **Step 4.2: Page self-sufficiency.** In `ChatDetailsPage`'s state `initState` (or `didChangeDependencies` if context is needed — prefer storing `ChatCubit` via `context.read` in `didChangeDependencies` guarded by a once-flag): if `widget.chatId != null` and the cubit's `state.openedChat.id != widget.chatId`, call `unawaited(cubit.openChatById(widget.chatId!))`. Keep everything else identical.
- [ ] **Step 4.3: `openChatById`.** In `chat_cubit.dart`:

  ```dart
  /// Opens the chat with [chatId]: no-op when it is already the opened chat,
  /// otherwise loads it (list cache first, then the repository) and emits the
  /// same state `setOpenedChat` produces. Makes /chats/:id self-sufficient.
  Future<void> openChatById(String chatId) async {
    if (state.openedChat.id == chatId) {
      return;
    }
    final Chat? cached =
        state.chatsList.where((Chat c) => c.id == chatId).firstOrNull;
    if (cached != null) {
      setOpenedChat(cached);
      return;
    }
    final Result<Chat> result = await _chatRepository.getCurrentChat(chatId);
    if (isClosed) {
      return;
    }
    result.when(
      err: (Failure failure) => _failReply(failure),
      ok: (Chat chat) => setOpenedChat(chat),
    );
  }
  ```

  Adapt to the real repository method names (`getCurrentChat`/`getChat` — check `core/repositories/chat_repository.dart`; reuse whatever loads one chat by id, as `getCurrentChat` already does elsewhere) and to `setOpenedChat`'s real signature. `firstOrNull` needs `package:collection` or manual loop — match what the file already imports.
- [ ] **Step 4.4: Fix the delete/fetch race (spec W1).** Add `final Set<String> _pendingDeletedChatIds = <String>{};` to `ChatCubit`. In `deleteChat`: add the id to the set before the await, remove it after the repository call completes. In `fetchChatsList`'s success handler (where `chatsList` is overwritten wholesale, ~`:259`): filter `..where((Chat c) => !_pendingDeletedChatIds.contains(c.id))` before emitting.
- [ ] **Step 4.5: Keep the tap path.** `chat_list_container.dart` keeps `setOpenedChat` + `push` — unchanged (fast path; the page guard makes it idempotent).
- [ ] **Step 4.6: Tests.** In the ChatCubit tests: (a) `openChatById` with the chat already opened → no state churn (assert `state.openedChat` identical and no repository call — use the existing fake); (b) `openChatById` with the chat in `chatsList` → opened without a repository load; (c) repository error → `ChatStatus.error`. (d) Race test: start `fetchChatsList` (with a completer-controlled fake so it stays in flight), call `deleteChat(id)` completing successfully, then release the fetch — assert the deleted chat is absent from `state.chatsList`.
- [ ] **Step 4.7: Verify.** `flutter analyze`; `flutter test` for the touched test dirs. Not the full suite; no goldens.

**Acceptance criteria:** Navigating to `/chats/<id>` (cold) opens exactly that chat; the four new tests pass; the deleted-chat resurrection is covered by test (d); `setOpenedChat`'s existing callers behave identically.

---

## Phase 5 — Presentation polish in the chat/settings screens

**Files:**
- Modify: `lib/features/chat/screens/chats_list_screen.dart`, `chat_details_screen.dart`
- Modify: `lib/features/chat/widgets/ai_text_input/ai_text_input.dart`, `floating_stop_button.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Modify: `lib/core/router/app_router.dart` (home route `BlocBuilder` → `BlocSelector`)
- Test: existing widget tests for these screens (`rg -l "ChatsListScreen\|ChatDetailsPage\|AiTextInput\|SettingsScreen" test`).

**Interfaces:** none — behavior-preserving UI-layer refactor only. If any step turns out NOT to be behavior-preserving after reading the code, revert that step and record it as deferred with the reason (the reviewer will check this).

- [ ] **Step 5.1: `chats_list_screen.dart` (~`:57`).** The full-body `BlocBuilder<ChatCubit, ChatState>` reads only `status`, `chatsList`, `currentChat`. Add `buildWhen: (ChatState previous, ChatState current) => previous.status != current.status || previous.chatsList != current.chatsList || previous.currentChat != current.currentChat` (freezed `==` makes this sound). Do not change the builder body.
- [ ] **Step 5.2: `chat_details_screen.dart`.** (a) Same `buildWhen` treatment for the outer builder at ~`:51` (fields: `status`, `currentChat`, `openedChat` — read the builder body and list exactly what it uses). (b) Replace the nested builder at ~`:90` that reads only `functionCallingEnabled` with `final bool functionCallingEnabled = context.select((ChatState s) => s.actionsState.functionCallingEnabled);` above the widget it feeds (match how `stage_composer_menu.dart:71` does it). (c) Delete the `AppLogger.debug('ChatDetailsScreen: Building conversation list…')` in the builder (~`:68`).
- [ ] **Step 5.3: `ai_text_input.dart`.** (a) Flatten: hoist the two `BlocListener`s (`ChatCubit` at ~`:99`, `TalkingCubit` at ~`:110`) into one `MultiBlocListener` above the builders (keep each listener's `listenWhen`/body byte-identical). (b) Outer `BlocBuilder<ChatCubit>` (~`:114`): add `buildWhen` covering exactly what its builder derives (`currentChat` last-user-entry + function-call entries + `functionCallingEnabled` — read the body first). (c) Replace raw type checks `talkingState is SpeakingState || talkingState is GeneratingState` (and the `IdleState` check at ~`:120`) with the `TalkingState.phase` extension getters (read `talking_state.dart` for the exact getter names, e.g. `isPlaying`-style; use what exists). (d) Add `_controller.dispose();` in `dispose()` (~`:91-94`). (e) Add `if (!mounted) return;` before the `setState` calls after the awaits at ~`:86` and ~`:272`. (f) `_isSubmitting`: read the flow; if `Waiting`/`Generating` phase is *exactly* the `true` window (set on send, cleared on `Idle`), replace the flag + listener-hack with a phase read; if the semantics differ in any corner, keep the flag, fix only its listener to use phase getters, and note the deferral.
- [ ] **Step 5.4: `settings_screen.dart`.** (a) Remove the file-wide `// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously` and fix what it was hiding: add `if (!mounted) return;` (or `if (context.mounted)` where a child context is used) after every await before `context.pop()`/`context.read` (~`:69-76` and anywhere `flutter analyze` now flags — run it). `avoid_dynamic_calls`: if the file still triggers it after your changes, keep JUST that one ignore on the offending lines with a comment, and note it. (b) Replace the initState `stream.listen` state mirror (~`:44`) with a `BlocListener<SettingsCubit, SettingsState>` (with a `listenWhen` naming the fields) that writes the same local fields/controllers — semantics preserved, subscription lifecycle owned by the framework; delete the manual subscription. (c) `_isSoundEffectsEnabled = true` hardcoded default (~`:36`): initialize from the cubit state when building (e.g. seed in `initState` via `context.read<SettingsCubit>().state`, or read directly in build) — do not change what saving does.
- [ ] **Step 5.5: `floating_stop_button.dart` (~`:26-34`).** Replace the nested `BlocBuilder<ChatCubit>`>…>`BlocBuilder<TalkingCubit>` with two `context.select` reads feeding the existing `shouldShow` computation (keep the widget's visuals identical).
- [ ] **Step 5.6: `app_router.dart` home route (~`:89-98`).** Replace the page-wrapping `BlocBuilder<AvatarCubit, AvatarState>` with a `BlocSelector<AvatarCubit, AvatarState, (AvatarStatus, double, double)>` selecting the record `(status, baseOriginalWidth, scaleFactor)` (records work as selector values; check the exact field names/types by reading the builder body first — adapt the record's shape to what it actually reads). Builder body unchanged.
- [ ] **Step 5.7: Verify.** `flutter analyze`; run the widget tests covering these screens + `test/features/chat test/features/settings` + goldens-adjacent tests (goldens themselves must pass unchanged — that is the proof the refactor is behavior-preserving). No `--update-goldens`.

**Acceptance criteria:** Every touched builder is scoped (buildWhen/selector/select) to exactly the fields its subtree reads; no raw `is SpeakingState`-style checks outside the phase extension; no `use_build_context_synchronously` suppression left in `settings_screen.dart`; `_controller` disposed; mounted guards after awaits; all existing tests incl. goldens pass untouched.

---

## Phase 6 — Test backfill: repository failure mapping + avatar datasource honesty

**Files:**
- Create: `test/features/settings/data/repositories/settings_repository_failure_test.dart`
- Modify: `lib/features/avatar/data/datasources/avatar_local_datasource.dart` (+ `avatar_repository_impl.dart` mapping)
- Create/extend: avatar datasource test (find its existing test with `rg -l "AvatarLocalDatasource\|avatar_local" test`).

**Interfaces:** none new.

- [ ] **Step 6.1: Settings repo failure tests.** Study the exemplar `test/features/chat/yofardev_repository_failure_test.dart` (pattern: datasource throws → repository returns the classified `Failure`). Write the settings equivalent for a representative set of at least six methods spanning families (one string get, one string set, one bool, one json/model get incl. `getTaskLlmConfig`, one json set, `getSoundEffects`): each test stubs the datasource to throw a `TimeoutException` (expect `NetworkFailure` via the mapper) and a `FormatException` (expect `StorageFailure`), plus one success-mapping case for a model method. Match the file's mock style exactly (mockito/mocktail — whatever the repo uses).
- [ ] **Step 6.2: Avatar datasource honesty (spec W5).** In `avatar_local_datasource.getChat`: capture the stack trace (`on Object catch (e, st)`), distinguish: key/file simply absent → keep returning "not found" as today (preserve the repository's existing mapping path); corrupt content (`FormatException`/`TypeError`) → return `Result.err(mapExceptionToFailure(e, stackTrace: st, tag: 'AvatarLocalDatasource'))` (adjust the method's return type to `Result<Chat?>` if it is not already — then fix `avatar_repository_impl.getChat` to pass it through, and `avatar_cubit.loadAvatar`'s err branch: it already tolerates err ("expected for new chats") — add an `AppLogger.warning` there so real failures are no longer silent). Grep all `getChat` callers before changing the signature.
- [ ] **Step 6.3: Avatar datasource tests.** Cases: absent chat → the not-found result exactly as before; corrupt JSON → `StorageFailure` (not the not-found path); happy path unchanged. Use the existing test file's fakes (temporary dir / in-memory prefs — mirror how it currently fakes storage).
- [ ] **Step 6.4: Conditionally: home repository.** If Phase 3 deleted `HomeRepositoryImpl` (expected), write one line in your report: "home repository deleted in Phase 3 — skipped". If it still exists, convert `playTts`/`stopTts`/`startVolumeFade` to `Result`-returning per the repo convention and add one failure-mapping test.
- [ ] **Step 6.5: Verify.** `flutter analyze`; `flutter test test/features/settings test/features/avatar`. Not the full suite; no goldens.

**Acceptance criteria:** `SettingsRepositoryImpl` has failure-mapping coverage across ≥6 methods with both timeout and format failure classes; `avatar_local_datasource.getChat` captures stack traces and no longer conflates corruption with absence; the cubit logs real load failures; all new tests pass and would fail on the pre-phase code.

---

## Effort & risk

| Phase | Touches | Risk | Notes |
|-------|---------|------|-------|
| 1 — Correctness | 5 lib files + tests | Low | Mechanical guards; one behavior change (save-then-emit) |
| 2 — Avatar single writer | 7 lib files | Medium | Judgment phase — Step 2.0 facts decide the migration shape |
| 3 — Dead code | ~12 files + codegen | Low-Medium | Every deletion grep-gated; deferrals allowed with note |
| 4 — Route + race | 3 lib files + tests | Medium | New public method; race test needs a controllable fake |
| 5 — Presentation | 6 lib files | Low-Medium | Behavior-preserving; goldens are the proof |
| 6 — Tests | 2 new test files, 1 datasource | Low | Follows existing exemplar patterns |

Each phase ends with `dart fix --apply && dart format . && ./scripts/fverify.sh` green (run by the orchestrator) and an independent review before the phase commit.
