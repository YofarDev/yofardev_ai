# AI Agent Documentation - Yofardev AI

> **Quick Start Guide for AI Agents and LLMs**

---

## Project Overview

- **What**: Animated AI avatar app — chat with an LLM (OpenAI-format or Gemini) that answers with TTS, lip-synced animation, and function calling (web search, weather, news…)
- **Version**: 3.0.0+6 — Dart SDK `>=3.8.0 <4.0.0`
- **Architecture**: Clean Architecture — `lib/features/<name>/{data,domain,presentation}` + shared `lib/core/`
- **App shell**: `lib/app.dart`; `lib/main.dart` is bootstrap only
- **Platforms**: all Flutter targets present, but Android is the primary one (iOS untested, web demo has reduced features)

> ⚠️ The `docs/` directory is **empty** — ignore doc references in older guides.
> Real references: `README.md` (app overview) and `scripts/README.md` (tooling).

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

These layering rules are **enforced by `test/architecture_test.dart`** (it also
bans `package:fpdart` and checks barrel-only imports), so `flutter test` fails
on violation.

### Conventions

- **Explicit types everywhere** (`always_specify_types: true`) — avoid `var`/inference in new code
- **Relative imports** within the package (`prefer_relative_imports`)
- **State idiom**: union states (freezed) for load-lifecycle screens, flat `copyWith` states for persistent interactive state
- **All user-facing strings** go through `AppLocalizations` — add keys with `./scripts/fstr.sh`, never edit `lib/core/l10n/generated/`
- **Never hand-edit** `*.g.dart` / `*.freezed.dart` — rerun `build_runner` after changing annotated models

### Gotchas

- Changing a freezed model or ARB file **requires regeneration** (`build_runner` / `gen-l10n`) or analysis and tests fail
- Golden tests store reference images under `test/**/goldens/` — only regenerate (`--update-goldens`) when a visual change is intentional
- No CI workflows in this repo — the quality gate is local (`./scripts/fverify.sh`)
- New features: use `./scripts/fgen.sh`, then wire DI (`service_locator.dart`) and route (`core/router/app_router.dart`) manually — a generated scaffold is not routed/registered until then

### Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/core/di/service_locator.dart` | All DI wiring | 228 |
| `lib/features/chat/presentation/bloc/chat_cubit.dart` | Main chat coordinator | 21.5K |
| `lib/features/chat/domain/services/chat_streaming_service.dart` | Streaming + inline tool calling | 15.6K |
| `lib/features/sound/domain/services/tts_queue_service.dart` | TTS queue | 5.5K |

### Common Operations

```dart
// Get any service
getIt<ServiceType>()

// State pattern (freezed)
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.success() = _Success;
  const factory ChatState.failure(String message) = _Failure;
}

// Error handling (Result<T>)
Future<Result<Chat>> getCurrentChat();
result.when(
  err: (failure) => emit(state.copyWith(error: failure.message)),
  ok: (chat) => emit(state.copyWith(chat: chat)),
);
```

---

## Feature Structure

```
lib/features/
├── avatar/          # Avatar customization
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

**Last Updated**: 2026-10-22
