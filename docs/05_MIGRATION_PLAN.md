# Architecture Migration Plan — yofardev_ai

> **For the implementing agent:** this plan is self-contained. Execute the phases in order,
> one task at a time. After every task run `flutter analyze`; after every phase run
> `flutter analyze` AND `flutter test`. Never leave the repo in a non-compiling state.
> Do not reformat or "clean up" code you were not asked to touch.

---

## 0. Context and standards being applied

Project: `yofardev_ai` — Flutter 3.8, flutter_bloc (Cubit-only), freezed, get_it, go_router.
The codebase is already ~80% compliant with the target architecture (feature-first clean
layers, centralized DI, stream-based domain service for coordination). This migration fixes
the remaining divergences. The rules below are the standard; every task traces back to one.

### Non-negotiable rules (from `flutter-architecture` skill)

1. **Dependencies flow inward only:** `presentation → domain ← data`. Features never import
   another feature's internals — only its **public API** (a barrel file) or `core/`.
2. **`core/` must not import `features/`** (exception: composition roots `core/di/` and
   `core/router/`, which assemble the app).
3. **Errors:** repositories/services return `Result<T>` from `core/models/result.dart`
   (`Result.ok` / `Result.err(Failure)`). **fpdart `Either` is forbidden.** No raw
   `Exception` may travel to the UI layer. Map unknown exceptions via `Failure.fromException`.
4. **Cubits never depend on other cubits**, and **services never hold cubit references**
   (not even via `getIt<Cubit>()` inside a service). Services expose streams/state; cubits
   subscribe.
5. **All DI in `lib/core/di/service_locator.dart`.** Cubits are `registerFactory` unless
   documented otherwise.
6. **`main.dart` is bootstrap + `runApp()` only**; `app.dart` owns `MaterialApp.router` and
   app-scoped providers.
7. Never swallow an exception silently — log it (`AppLogger`) or surface a failure state.

### Verified current-state evidence (as of 2026-09-18)

| Issue | Evidence |
|---|---|
| fpdart `Either<Exception, T>` everywhere | 21 files, 173 usages; no `Result`/`Failure` type exists |
| Core service resolves a Cubit | `lib/core/services/agent/avatar_tool.dart:12` |
| `core/models` + `core/services` import feature presentation states | `lib/core/models/app_lifecycle_event.dart:4-6`, `lib/core/services/app_lifecycle_service.dart:8-10` |
| Cross-feature imports (relative paths) | 39 occurrences (full list in Phase 3) |
| No `app.dart`; wiring in `main.dart` | `lib/main.dart` (123 lines) |
| `ChatCubit` duplicates settings owned by `SettingsCubit` | `chat_cubit.dart:371-405` vs `settings_cubit.dart:330-345` |
| No architecture boundary tests | `test/architecture_test.dart` missing |

---

## Phase 1 — Dependency-direction fixes in `core/` (~7 files, low risk)

**Goal:** `core/` no longer imports `features/` (outside the sanctioned composition roots),
and no core service touches a Cubit.

### Task 1.1 — Remove dead cross-feature import in ChatCubit

- File: `lib/features/chat/presentation/bloc/chat_cubit.dart:19`
- The import `'../../../demo/data/repositories/demo_repository_impl.dart'` is dead — the
  file uses no symbol from it (demo activation goes through `getIt<DemoService>()` at
  line 128). Delete the import line. `flutter analyze` must show no unused/missing symbols.

### Task 1.2 — AvatarTool: route avatar changes through AppLifecycleService

Today `AvatarTool` (a core service) calls `getIt<ChatCubit>()` and invokes
`updateBackgroundOpenedChat` / `updateAvatarOpenedChat` and reads `openedChat.id`
(`avatar_tool.dart:208-223`). This is the "service holding a cubit ref" anti-pattern.

**Steps:**

1. In `lib/core/models/app_lifecycle_event.dart`, add a payload class:

   ```dart
   /// Request to change the avatar of the currently open chat.
   /// Emitted by AvatarTool; handled by ChatCubit, which owns the chat id.
   class AvatarChangeRequested {
     const AvatarChangeRequested({
       required this.newConfig,
       required this.configWithAnimation,
       required this.backgroundOnly,
     });

     /// Config to persist (raw values only, no animation specials).
     final AvatarConfig newConfig;

     /// Config including animation specials (leaveAndComeBack / outOfScreen).
     final AvatarConfig configWithAnimation;

     /// True when only the background changed (selects the cheaper update path).
     final bool backgroundOnly;
   }
   ```

2. In `lib/core/services/app_lifecycle_service.dart`, add a stream following the existing
   pattern (controller + getter + emitter):

   ```dart
   final StreamController<AvatarChangeRequested> _avatarChangeRequestedController =
       StreamController<AvatarChangeRequested>.broadcast();

   Stream<AvatarChangeRequested> get avatarChangeRequestedEvents =>
       _avatarChangeRequestedController.stream;

   void emitAvatarChangeRequested(AvatarChangeRequested request) =>
       _avatarChangeRequestedController.add(request);
   ```

   Close the controller in `dispose()`.

3. In `lib/features/chat/presentation/bloc/chat_cubit.dart`, subscribe in the constructor
   (same pattern as `_newChatEntrySubscription`) and add a handler. ChatCubit already has
   `_avatarAnimationService` injected — reuse it:

   ```dart
   Future<void> _handleAvatarChangeRequested(AvatarChangeRequested request) async {
     if (request.backgroundOnly) {
       await updateBackgroundOpenedChat(request.newConfig.background!);
     } else {
       await updateAvatarOpenedChat(request.newConfig);
     }
     _avatarAnimationService.emitUpdateConfig(
       state.openedChat.id,
       request.configWithAnimation,
     );
   }
   ```

   Cancel the subscription in `close()` alongside the existing ones.

4. In `lib/core/services/agent/avatar_tool.dart`:
   - Delete the `chat_cubit.dart` import and the `ChatCubit get _chatCubit` getter.
   - Keep the existing computation of `backgroundChanged` / `clothesChanged` /
     `configWithAnimation` / the `backgroundOnly` condition exactly as is.
   - Replace the `if/else` block that awaits `_chatCubit.update…` (lines ~196-223, through
     the `_avatarAnimationService.emitUpdateConfig` call) with a single emit:

     ```dart
     _appLifecycleService.emitAvatarChangeRequested(
       AvatarChangeRequested(
         newConfig: newConfig,
         configWithAnimation: configWithAnimation,
         backgroundOnly:
             backgroundStr != null &&
             hatStr == null &&
             topStr == null &&
             glassesStr == null &&
             costumeStr == null &&
             specialsStr == null,
       ),
     );
     ```

   - If `AvatarAnimationService` is then unused in the file, drop that import/getter too.
     Resolve `AppLifecycleService` the same way the file already resolves services
     (`getIt<AppLifecycleService>()` getter) or via constructor injection if the tool is
     constructed in `service_locator.dart`.

**Behavioral note (accepted):** persistence becomes asynchronous through the stream; the
tool's returned success string no longer waits for it. This is fine — the string is a
report to the LLM, not a persistence guarantee.

**Acceptance:** `rg -n "ChatCubit" lib/core/` returns nothing (excluding comments).
`flutter analyze` + `flutter test` green.

### Task 1.3 — Move lifecycle payload types out of presentation states

`AppLifecycleService` and `AppLifecycleEvent` (core) currently import
`ChatStatus` (from `features/chat/presentation/bloc/chat_state.dart:15`),
`AvatarStatusAnimation` (from `features/avatar/presentation/bloc/avatar_state.dart:9`),
and `TalkingState` (whole freezed union, `features/talking/presentation/bloc/talking_state.dart`).

**Steps:**

1. **ChatStatus → core.** Create `lib/core/models/chat_status.dart` containing the enum
   (copy values verbatim). In `chat_state.dart`: delete the local enum, add
   `import '../../../../core/models/chat_status.dart';` AND
   `export '../../../../core/models/chat_status.dart';` (the export keeps every existing
   importer of `chat_state.dart` compiling — do not touch the importing widgets).

2. **AvatarStatusAnimation → core.** Same recipe:
   `lib/core/models/avatar_status_animation.dart` + import/export from `avatar_state.dart`.

3. **TalkingState → core enum for the stream.** The lifecycle stream needs only *which
   phase* talking is in, not the full state. Create `lib/core/models/talking_phase.dart`:

   ```dart
   /// Cross-feature talking phase. Mirrors the variants of TalkingState.
   enum TalkingPhase { idle, waiting, generating, speaking, error }
   ```

   - In `app_lifecycle_service.dart`: change `talkingStateChangedEvents` to
     `Stream<TalkingPhase>` and `emitTalkingStateChanged(TalkingState state)` to
     `emitTalkingStateChanged(TalkingPhase phase)`.
   - In `app_lifecycle_event.dart`: `TalkingStateChangedEvent` carries `TalkingPhase`.
   - In `lib/features/home/presentation/bloc/home_cubit.dart:56-67`: change the handler to
     a plain switch on `TalkingPhase` (idle→stopWaitingTtsLoop, waiting→startWaitingTtsLoop,
     speaking→stopWaitingTtsLoop, error→stopWaitingTtsLoop, generating→no-op). Update the
     `StreamSubscription<TalkingState>` field at line 40 to `TalkingPhase`.
   - Add a convenience extension in `talking_state.dart` for future emitters:

     ```dart
     extension TalkingPhaseX on TalkingState {
       TalkingPhase get phase => map(
             idle: (_) => TalkingPhase.idle,
             waiting: (_) => TalkingPhase.waiting,
             generating: (_) => TalkingPhase.generating,
             speaking: (_) => TalkingPhase.speaking,
             error: (_) => TalkingPhase.error,
           );
     }
     ```

   - Delete the three feature-state imports from `app_lifecycle_event.dart` and
     `app_lifecycle_service.dart` (lines 4-6 / 8-10); import the new core model files
     instead.
   - Side benefit: `lib/features/talking/presentation/bloc/talking_cubit.dart` imports
     `chat_state.dart` only for `ChatStatus` — after step 1, point it at
     `core/models/chat_status.dart`.

**Acceptance:** `rg -n "features/" lib/core/models lib/core/services` returns nothing.
App compiles and all existing tests pass. If a widget breaks because it imported a state
file expecting the enum, the `export` lines in step 1-2 should have covered it — verify.

---

## Phase 2 — Error handling: `Result<T>` + `Failure` (21 files, medium risk)

**Goal:** eliminate fpdart; typed failures; no silent catches. Migration is per-module —
`Result` and `Either` may coexist between steps, so every step compiles.

### Task 2.1 — Create the types

`lib/core/models/result.dart` (plain sealed classes — no freezed, no codegen):

```dart
/// First-party result type. Repositories and services return this instead of
/// throwing or leaking exceptions. Never use fpdart/dartz.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  T? get getOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  R when<R>({
    required R Function(Failure failure) err,
    required R Function(T value) ok,
  }) => switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
```

`lib/core/models/failure.dart`:

```dart
/// Typed failure. UI shows [message]; [cause] carries the original error for logs.
abstract class Failure {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  static Failure fromException(Object error, {StackTrace? stackTrace}) {
    // Log the details; callers may also route specific exceptions to
    // narrower variants before falling back here.
    return UnknownFailure(error.toString(), error);
  }

  @override
  String toString() => '$runtimeType($message)';
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.cause]);
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.cause]);
}

final class TtsFailure extends Failure {
  const TtsFailure(super.message, [super.cause]);
}

final class ConfigFailure extends Failure {
  const ConfigFailure(super.message, [super.cause]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.cause]);
}
```

### Task 2.2 — Mechanical translation rules

Apply while migrating each module:

| fpdart | Result |
|---|---|
| `Future<Either<Exception, T>> f()` | `Future<Result<T>> f()` |
| `Right<Exception, T>(value)` | `Result<T>.ok(value)` (adjust the type arg to what inference needs) |
| `Left<Exception, T>(Exception(...))` | `Result<T>.err(StorageFailure('...'))` — pick the narrowest variant that fits |
| `result.fold((err) => A, (value) => B)` | `result.when(err: (failure) => A, ok: (value) => B)` — **note the argument order is swapped; use named args** |
| `result.getOrElse((e) => fallback)` | `result.getOrNull ?? fallback` |
| `result.isLeft()` / `isRight()` | `!result.isOk` / `result.isOk` |

Where an implementation catches a *known* exception type (e.g. `SharedPreferences`
errors, HTTP errors, TTS platform errors), map it to the specific `Failure` variant;
everything else goes through `Failure.fromException(e, stackTrace: st)`. Where a cubit
logged the raw `Exception` before, log `failure` now — do not show `failure.message`
in new UI places unless the old code already showed the exception.

### Task 2.3 — Migrate module by module, in this order

Each bullet = interface + impl + all callers. Run `flutter analyze` after each bullet.

1. **sound** (3 files): `features/sound/domain/repositories/sound_repository.dart`,
   `features/sound/data/repositories/sound_repository_impl.dart`,
   `features/sound/presentation/bloc/sound_cubit.dart`
2. **locale** (2): `core/repositories/locale_repository.dart`,
   `core/repositories/locale_repository_impl.dart`
3. **avatar** (4): `core/repositories/avatar_repository.dart`,
   `features/avatar/data/repositories/avatar_repository_impl.dart`,
   `features/avatar/data/datasources/avatar_local_datasource.dart`,
   `features/avatar/presentation/bloc/avatar_cubit.dart`
4. **settings** (4): `core/services/settings_local_datasource.dart`,
   `core/repositories/settings_repository.dart`,
   `features/settings/data/repositories/settings_repository_impl.dart`,
   `features/settings/presentation/bloc/settings_cubit.dart`
5. **demo** (2): `features/demo/domain/repositories/demo_repository.dart`,
   `features/demo/data/repositories/demo_repository_impl.dart`
6. **chat** (4): `features/chat/domain/repositories/chat_repository.dart`,
   `features/chat/data/repositories/yofardev_repository_impl.dart`,
   `features/chat/presentation/bloc/chat_cubit.dart`,
   `core/services/chat/chat_streaming_service.dart`
7. **remaining core services** (2): `core/services/agent/tool_registry.dart`,
   `core/services/llm/llm_config_manager.dart`

### Task 2.4 — Log the silent catches

Add an `AppLogger.debug/warn` (with a tag) to every empty catch. Verified sites:

- `lib/features/sound/data/datasources/tts_datasource.dart:131`
- `lib/features/chat/widgets/function_calling_widget.dart:145`
- `lib/features/chat/widgets/floating_stop_button.dart:64`
- `lib/features/chat/widgets/chat_message_item.dart:45`
- `lib/features/chat/widgets/chat_list_container.dart:107`
- `lib/features/chat/presentation/bloc/chat_cubit.dart:680`
- `lib/core/services/llm/llm_config_manager.dart:54`
- `lib/core/services/audio/audio_player_service.dart:132`
- `lib/core/models/demo_script.dart:120`
- `lib/core/models/sound_effects.dart:38`

### Task 2.5 — Remove the dependency (do LAST in this phase)

`rg -n "fpdart" lib` must return nothing. Then remove `fpdart` from `pubspec.yaml`,
run `flutter pub get`, `flutter analyze`, `flutter test`.

**Rollback:** each bullet is independent; revert the touched files if a step goes wrong.

---

## Phase 3 — Cross-feature boundary cleanup (~39 imports, medium risk)

**Goal:** features interact only through `core/` or another feature's **public API barrel**.
A barrel is a single file at the feature root, e.g. `lib/features/talking/talking.dart`,
containing only `export` statements. Cross-feature imports must target barrels, never
`presentation/`, `data/`, or `domain/` paths of another feature.

### Verified violation list (relative-path imports)

- `demo/domain/repositories/demo_repository.dart` → chat domain (`ChatRepository`)
- `home/screens/home_screen.dart` → avatar, chat, chat_tts, demo (presentation), demo **data impl**, talking
- `home/presentation/bloc/home_cubit.dart` → avatar_state, talking_state *(fixed already by Task 1.3 — verify imports now point at core models)*
- `home/widgets/home_content_stack.dart` → avatar widgets (4), chat widgets (2), avatar/chat/talking states
- `home/widgets/home_buttons.dart` → avatar, chat, talking cubits/states
- `talking/presentation/bloc/talking_cubit.dart` → chat_state *(fixed by Task 1.3 — verify)*
- `chat/screens/chats_list_screen.dart` → talking cubit
- `chat/presentation/bloc/chat_cubit.dart` → demo data impl *(fixed by Task 1.1 — verify)*
- `chat/presentation/bloc/chat_tts_cubit.dart` → talking domain service (`TtsPlaybackService`)
- `chat/widgets/floating_stop_button.dart`, `chat/widgets/ai_text_input/ai_text_input.dart` → talking cubit/state
- `avatar/widgets/talking_mouth.dart`, `avatar_widgets.dart`, `animated_avatar.dart` → talking state/cubit

### Task 3.1 — Create public API barrels

```dart
// lib/features/talking/talking.dart — public API of the talking feature.
export 'presentation/bloc/talking_cubit.dart';
export 'presentation/bloc/talking_state.dart';
```

```dart
// lib/features/chat/chat.dart
export 'presentation/bloc/chat_cubit.dart';
export 'presentation/bloc/chat_state.dart';
export 'presentation/bloc/chat_tts_cubit.dart';
```

```dart
// lib/features/avatar/avatar.dart
export 'presentation/bloc/avatar_cubit.dart';
export 'presentation/bloc/avatar_state.dart';
```

```dart
// lib/features/demo/demo.dart
export 'presentation/bloc/demo_cubit.dart';
export 'presentation/bloc/demo_state.dart';
export 'domain/repositories/demo_repository.dart';
```

Rules for barrels: only types other features legitimately need. Never export datasources
or repository impls.

### Task 3.2 — Repoint cross-feature imports to barrels

For each file in the violation list, replace the deep import with the barrel
(e.g. `import '../../talking/talking.dart';`). This is purely mechanical — the symbols
are identical. Do it file by file with `flutter analyze` between files.

### Task 3.3 — Fix the two structural outliers

1. **`home/screens/home_screen.dart` imports `demo/data/repositories/demo_repository_impl.dart`.**
   Inspect what it uses. If the import is dead → delete. If it needs demo data → depend on
   the `DemoRepository` interface (on the barrel) resolved from `getIt`, never the impl.
2. **`chat/presentation/bloc/chat_tts_cubit.dart` imports
   `talking/domain/services/tts_playback_service.dart`.** TTS playback is shared audio
   infrastructure, not talking-feature business logic (its sibling `TtsQueueService`
   already lives in `core/services/audio/`). Move `TtsPlaybackService` to
   `lib/core/services/audio/tts_playback_service.dart`, update the registration in
   `service_locator.dart` and all imports. Remove it from the talking barrel if added.

**Acceptance:** the scan below prints `CLEAN` (script resolves relative imports):

```bash
python3 - <<'EOF'
import os, re
violations = []
for dirpath, _, files in os.walk('lib/features'):
    for fn in files:
        if not fn.endswith('.dart') or fn.endswith(('.freezed.dart', '.g.dart')):
            continue
        path = os.path.join(dirpath, fn)
        src = path.split(os.sep)[2]
        for line in open(path):
            m = re.match(r"import '([^']+)';", line.strip())
            if not m or not m.group(1).startswith('.'):
                continue
            target = os.path.normpath(os.path.join(dirpath, m.group(1)))
            parts = target.split(os.sep)
            if len(parts) > 2 and parts[1] == 'features' and parts[2] != src and not target.endswith('/talking.dart') and not target.endswith('/chat.dart') and not target.endswith('/avatar.dart') and not target.endswith('/demo.dart'):
                violations.append(f"{path} -> {target}")
print('\n'.join(violations) if violations else 'CLEAN')
EOF
```

(This gets replaced by the permanent `test/architecture_test.dart` in Phase 6.)

---

## Phase 4 — App shell and DI consistency (~3 files, low risk)

### Task 4.1 — Extract `app.dart`

1. Create `lib/app.dart`. Move `MyApp` there verbatim (the `MultiBlocProvider` + locale
   `BlocBuilder` + `MaterialApp.router`). It reads `getIt` only — no manual construction.
2. Reduce `lib/main.dart` to bootstrap: `WidgetsFlutterBinding`, `setupServiceLocator()`,
   `getIt<ChatLocalDatasource>().init()`, window setup, language prefetch, `Alarm.init`,
   TTS warmup, then `runApp(App(initialLanguage: initialLanguage))`. No provider or
   `MaterialApp` code remains in `main.dart`.
3. `main.dart` must not import any `features/.../bloc` files anymore.

### Task 4.2 — Align the TalkingCubit lifetime

`lib/core/di/service_locator.dart:216` registers `TalkingCubit` as
`registerLazySingleton` while every other cubit is `registerFactory`. Change it to
`registerFactory` for consistency (it is provided app-scoped in `app.dart`, so behavior
is identical — one instance per app session either way). If a test fails because it
relied on singleton identity, fix the test to construct the cubit directly.

**Acceptance:** `flutter analyze` + `flutter test` green; app boots.

---

## Phase 5 — Cubit sizing: move app settings out of ChatCubit (~8 files, medium risk)

**Goal:** `ChatCubit` keeps chat concerns (CRUD, streaming, titles, function-calling
toggle — that one is chat behavior and stays). App-level settings (language, sound
effects) move to `SettingsCubit`, which **already owns** `soundEffectsEnabled` state and
`setSoundEffects` (`settings_state.dart:27`, `settings_cubit.dart:336`) — today the two
cubits duplicate them.

### Task 5.1 — Move language handling to SettingsCubit

1. `settings_state.dart`: add `@Default('en') String currentLanguage` (check what default
   `main.dart` prefetch uses and match it).
2. `settings_cubit.dart`: add an `init`/load that reads the saved language
   (`SettingsRepository.getLanguage()` — add `getLanguage()` to the interface + impl +
   datasource if missing; `setLanguage` already exists since `ChatCubit` calls it). Add
   `setCurrentLanguage(String)` — move the body from `chat_cubit.dart:371-387`, emitting
   `state.copyWith(currentLanguage: ...)`. Call the load in the provider's `create` in
   `app.dart`: `getIt<SettingsCubit>()..loadSettings()`.
3. `chat_state.dart`: remove `currentLanguage` and `soundEffectsEnabled` fields.
   `chat_cubit.dart`: remove `setCurrentLanguage`, `setSoundEffects` (lines 371-405) and
   their loads in `_loadSettings` (line 156).
4. `app.dart`: the locale `BlocBuilder` wraps — change `ChatCubit`/`ChatState` to
   `SettingsCubit`/`SettingsState`, keep the `buildWhen` on language. The seed
   `initialLanguage` still bootstraps the first frame; SettingsCubit's load then keeps it
   authoritative.
5. Repoint consumers:
   - `lib/features/home/widgets/home_buttons.dart:36-41` (read/write language)
   - `lib/features/home/screens/home_screen.dart:94` (language)
   - `lib/features/chat/widgets/chat_conversation_list.dart:104` (language)
   - Anywhere `soundEffectsEnabled` was read from `ChatCubit` — trace with
     `rg -n "soundEffectsEnabled" lib` and repoint to `SettingsCubit.state`; the
     `soundEffectsEnabled` **parameters** on `home_cubit.dart:94` and
     `talking_cubit.dart:228` stay — widgets pass the value from `SettingsCubit` state.
     Widgets may read several cubits; the forbidden thing is cubit-to-cubit constructor
     dependencies. Do not introduce one.
6. `functionCallingEnabled` / `toggleFunctionCalling` (`chat_cubit.dart:407`) **stay in
   ChatCubit** — they configure chat LLM calls, are not duplicated anywhere, and are not
   persisted today. Do not expand scope here.

### Task 5.2 — Fix tests

Existing chat cubit tests may construct `ChatState(currentLanguage: …)` or assert on the
removed fields. Update them to the new owners. Run the full suite.

**Acceptance:** `rg -n "currentLanguage" lib/features/chat` returns nothing;
`flutter analyze` + `flutter test` green; language toggle on the home screen still works
(manual smoke if a desktop runner is available).

---

## Phase 6 — Lock it in: boundary tests, docs, final verify

### Task 6.1 — Create `test/architecture_test.dart`

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  List<String> importsOf(File f) => f
      .readAsLinesSync()
      .where((l) => l.trimLeft().startsWith('import'))
      .map((l) => l.trim())
      .toList();

  test('core does not import features (composition roots excluded)', () {
    const allowed = ['lib/core/di/', 'lib/core/router/'];
    for (final f in files) {
      if (!f.path.startsWith('lib/core/')) continue;
      if (allowed.any(f.path.startsWith)) continue;
      for (final line in importsOf(f)) {
        expect(line.contains('features/'), isFalse,
            reason: '${f.path}: $line');
      }
    }
  });

  test('no fpdart anywhere', () {
    for (final f in files) {
      for (final line in importsOf(f)) {
        expect(line.contains('package:fpdart'), isFalse,
            reason: '${f.path}: $line');
      }
    }
  });

  test('features import other features only via their public barrel', () {
    const barrels = ['talking.dart', 'chat.dart', 'avatar.dart', 'demo.dart'];
    for (final f in files) {
      final parts = f.path.split('/');
      if (parts.length < 3 || parts[1] != 'features') continue;
      final ownFeature = parts[2];
      for (final line in f.readAsLinesSync()) {
        final m = RegExp(r"import '([^']+)'").firstMatch(line);
        if (m == null) continue;
        final target = m.group(1)!;
        if (!target.startsWith('.')) continue;
        final resolved = File.fromUri(
                Uri.file(f.path).resolve(target))
            .path;
        final t = resolved.split('/');
        if (t.length > 3 && t[1] == 'features' && t[2] != ownFeature) {
          expect(barrels.contains(t.last), isTrue,
              reason: '${f.path} imports feature internals: $resolved');
        }
      }
    }
  });

  test('no service resolves a cubit from getIt', () {
    for (final f in files) {
      if (!f.path.startsWith('lib/core/services/')) continue;
      for (final line in f.readAsLinesSync()) {
        expect(RegExp(r'getIt<\w*(Cubit|Bloc)>').hasMatch(line), isFalse,
            reason: '${f.path}: $line');
      }
    }
  });
}
```

Adjust helper imports as analyzer suggests; the assertions are the contract. If a test
fails, fix the code, not the test — unless a new legitimate composition pattern appears
(in that case document the exception in this file and in AGENTS.md).

### Task 6.2 — Update the docs

- `AGENTS.md`: replace the "Errors: fpdart 1.2.0 (Either<Failure, T>)" line with
  `Result<T>` (`core/models/result.dart`), and mention barrels + `app.dart`.
- `docs/04_CONVENTIONS.md`: same correction, plus the barrel rule.
- Delete the stale `flutter_analysis.md` at repo root (fanal scratch output).

### Task 6.3 — Final verification

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs  # only if any freezed file was touched
```

If the `fverify` command exists in this environment, run it instead of the two first
commands. All green = migration complete.

---

## Effort and risk summary

| Phase | Files | Risk | Notes for the implementer |
|---|---|---|---|
| 1 — core dependency direction | ~7 | Low | Pure wiring; no behavior change (one accepted async nuance in 1.2) |
| 2 — Result<T>/Failure | ~22 | Medium | Strictly per-module; analyzer after each bullet |
| 3 — Cross-feature barrels | ~20 | Medium | Mechanical repoints + 2 structural moves |
| 4 — app.dart + DI | ~3 | Low | |
| 5 — Settings move | ~8 | Medium | Update failing tests; smoke the language toggle |
| 6 — Tests + docs | ~3 | Low | The architecture tests are the regression net from now on |

**If you get stuck** on any task (unexpected coupling, failing test you can't explain),
stop that task, leave the repo compiling (revert the task's edits if needed), and record
the blocker in the final report instead of improvising a redesign.
