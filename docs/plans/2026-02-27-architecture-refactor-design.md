# Architecture Refactor Design Document

**Date:** 2026-02-27
**Author:** Claude (with user collaboration)
**Status:** Approved

## Executive Summary

This document outlines a comprehensive refactoring of the Yofardev AI Flutter application from a layered architecture to a feature-based architecture. The refactoring will improve code maintainability, reduce coupling, and establish consistent architectural patterns throughout the codebase.

**Motivation:** Code maintainability
**Approach:** Feature-by-feature migration
**Timeline:** 6-8 weeks
**Risk:** Low (incremental, tested, reversible)

---

## Current State Analysis

### Existing Structure

```
lib/
├── logic/           # Business logic (BLoCs/Cubits, agents)
├── ui/              # UI layer (pages, widgets)
├── models/          # Data models
├── services/        # Business services
├── repositories/    # Data repositories
└── utils/           # Utility functions
```

### Identified Issues

| Category | Issue | Impact |
|----------|-------|--------|
| File Size | `llm_service.dart` (460 lines), `chat_details_page.dart` (402 lines), `ai_text_input.dart` (357 lines) | Difficult to navigate and maintain |
| Models | No freezed usage, manual copyWith implementations | Boilerplate, error-prone |
| Anti-patterns | Navigation in `build()`, UI controllers in BLoCs | Crashes, tight coupling |
| DI | No dependency injection, direct instantiation | Tight coupling, hard to test |
| Duplication | Both `llm_service.dart` and `fake_llm_service.dart` | Confusion, maintenance burden |

---

## Target Architecture

### New Structure

```
lib/
├── core/                   # Shared, cross-cutting concerns
│   ├── di/                # Dependency injection (get_it)
│   ├── theme/             # App theme
│   ├── l10n/              # Localizations
│   ├── utils/             # Utilities (AppLogger)
│   ├── widgets/           # Reusable widgets
│   ├── models/            # Shared models (freezed)
│   ├── repositories/      # Data repositories
│   └── services/          # Business services
│
├── features/              # Feature modules
│   ├── chat/
│   │   ├── bloc/         # chat_cubit.dart, chat_state.dart
│   │   ├── screens/      # chat_details_page.dart
│   │   └── widgets/      # message_bubble.dart, chat_input.dart
│   │
│   ├── avatar/
│   │   ├── bloc/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── settings/
│   │   ├── bloc/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── demo/
│   │   ├── bloc/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   └── sound/
│       ├── bloc/
│       ├── screens/
│       └── widgets/
│
└── main.dart
```

### Key Architectural Changes

1. **Feature-based organization** → All related files co-located
2. **Dependency injection** → `get_it` service locator
3. **Freezed models** → Immutable, auto-generated
4. **Separated state files** → `chat_state.dart`, not inline
5. **Interface-based services** → Clear abstractions for testability

---

## Migration Strategy

### Approach: Feature-by-Feature Migration

**Why this approach?**
- Immediate improvements to working features
- Each migration is self-contained and testable
- Natural checkpoints for validation
- Learn patterns on simpler features first
- Fits "incremental but breaking" constraint

### Migration Order

#### Phase 0: Foundation Setup (1 week)
- Add `freezed` and `get_it` dependencies
- Set up `lib/core/di/` with service locator
- Create empty feature folders
- Write base patterns/conventions doc
- **Checkpoint:** Dependencies configured, folder structure ready

#### Phase 1: Sound Effects (3 days)
- Simplest feature, minimal dependencies
- Convert sound models to freezed
- Register SoundService in DI
- Create `lib/features/sound/` structure
- Update references
- **Learning:** Basic migration pattern, DI setup

#### Phase 2: Avatar (1 week)
- Medium complexity, has BLoC and widgets
- Extract `avatar_state.dart`
- Convert avatar models to freezed
- Register AvatarCubit in DI
- Split large widgets (extract `talking_mouth.dart` sub-components)
- Fix navigation anti-patterns
- **Learning:** BLoC migration, widget extraction

#### Phase 3: Settings (1 week)
- Multiple screens, LLM config management
- Create `lib/features/settings/` with sub-features
- Extract `llm_config_state.dart`
- Separate config service from UI logic
- Fix oversized screens (split widgets)
- Remove direct navigation in build()
- **Learning:** Complex feature migration, multi-screen flows

#### Phase 4: Demo (1 week)
- Demo scripts, controllers, fake LLM
- Decide: Keep demo in production or make dev-only?
- Migrate demo service to DI
- Extract demo widgets
- Clean up duplicate LLM service patterns
- **Learning:** Handling optional/dev features

#### Phase 5: Chat (2 weeks)
- Core feature, 400+ line files, tight coupling
- Extract `chat_state.dart`
- Split `ai_text_input.dart` (357 lines) into:
  - `speech_input_button.dart`
  - `text_input_field.dart`
  - `image_picker_button.dart`
- Fix `chat_details_page.dart` (402 lines):
  - Extract message building logic
  - Move navigation to BlocListener
  - Split into smaller widgets
- Consolidate LLM services (remove duplication)
- **Learning:** Large-scale refactoring, complex widget decomposition

#### Phase 6: Cleanup (1 week)
- Remove old structure (`lib/logic/`, `lib/ui/`)
- Update all imports
- Run `dart fix --apply` and `flutter analyze`
- Update tests
- Final polish

---

## Technical Implementation Details

### Dependency Injection (get_it)

**Setup in `lib/core/di/service_locator.dart`:**

```dart
final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  getIt.registerLazySingleton<LlmServiceInterface>(
    () => kDebugMode ? FakeLlmService() : LlmService(),
  );
  getIt.registerLazySingleton<SoundService>(() => SoundService());

  // Repository
  getIt.registerLazySingleton<YofardevRepository>(() => YofardevRepository(
    llmService: getIt<LlmServiceInterface>(),
    soundService: getIt<SoundService>(),
  ));

  // BLoCs (factories since they can be recreated)
  getIt.registerFactory<AvatarCubit>(() => AvatarCubit(
    repository: getIt<YofardevRepository>(),
  ));
  getIt.registerFactory<ChatsCubit>(() => ChatsCubit(
    repository: getIt<YofardevRepository>(),
  ));
}
```

**Usage in widgets:**

```dart
BlocProvider(
  create: (_) => getIt<ChatsCubit>()..init(),
  child: ChatScreen(),
)
```

### Freezed Models

**Example: `ChatEntry` refactor:**

```dart
@freezed
class ChatEntry with _$ChatEntry {
  const factory ChatEntry.text({
    required String id,
    required String content,
    required String role,
  }) = ChatEntryText;

  const factory ChatEntry.image({
    required String id,
    required String imageUrl,
    required String role,
  }) = ChatEntryImage;

  const factory ChatEntry.toolCall({
    required String id,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) = ChatEntryToolCall;

  factory ChatEntry.fromJson(Map<String, dynamic> json) =>
      _$ChatEntryFromJson(json);
}
```

### Navigation Pattern Fix

**Before (anti-pattern):**

```dart
BlocBuilder<ChatsCubit, ChatsState>(
  builder: (context, state) {
    if (state is ChatDeleted) {
      Navigator.of(context).pop(); // ❌ Crashes if state rebuilds
    }
    return ...;
  },
)
```

**After (correct):**

```dart
BlocListener<ChatsCubit, ChatsState>(
  listener: (context, state) {
    if (state is ChatDeleted) {
      Navigator.of(context).pop();
    } else if (state is ChatError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  child: BlocBuilder<ChatsCubit, ChatsState>(
    builder: (context, state) {
      return ChatView(chat: state.chat);
    },
  ),
)
```

### Service Interface Pattern

```dart
// lib/core/services/llm/llm_service_interface.dart
abstract class LlmServiceInterface {
  Future<String> completeChat(List<ChatEntry> messages);
  Stream<String> streamChat(List<ChatEntry> messages);
}

// lib/core/services/llm/llm_service.dart
class LlmService implements LlmServiceInterface {
  // Real API implementation
}

// lib/core/services/llm/fake_llm_service.dart
class FakeLlmService implements LlmServiceInterface {
  // Demo/mock implementation
}
```

### Widget Extraction Pattern

**Before:** `ai_text_input.dart` (357 lines)

**After:**
```
lib/features/chat/widgets/
├── ai_text_input.dart              # Coordinator (50 lines)
├── speech_input_button.dart        # Speech handling (60 lines)
├── text_input_field.dart           # Text input (80 lines)
└── image_picker_button.dart        # Image handling (50 lines)
```

---

## Testing Strategy

### Testing Order

1. **Write tests for OLD code** (before touching it)
2. **Refactor code** (run tests continuously)
3. **Update tests for NEW structure**

### Coverage Requirements

- All BLoCs/Cubits: Unit tests
- All screens: Widget tests
- Critical widgets: Widget tests
- Full user flows: Integration tests

### Per-Feature Testing Checklist

- [ ] Sound: SoundService plays correct sounds
- [ ] Avatar: AvatarCubit state transitions work
- [ ] Settings: LLM config saves/loads correctly
- [ ] Demo: Fake LLM service returns expected responses
- [ ] Chat: Full chat flow integration test

---

## Risk Management

### Primary Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing functionality | HIGH | Tests before refactoring, incremental commits |
| Lost work during merge conflicts | MEDIUM | Feature branches, frequent merges |
| Taking longer than estimated | MEDIUM | Can stop after any phase |
| Learning curve slowing progress | LOW | Start with simple features |

### Git Strategy

```
main                    ← Always working
├── refactor/foundation
├── refactor/sound
├── refactor/avatar
├── refactor/settings
├── refactor/demo
├── refactor/chat
└── refactor/cleanup
```

### Rollback Strategy

- Each merge to main is a checkpoint
- Can revert to any previous phase
- No "big bang" integration risk

---

## Migration Checklist Template

**Before Migration:**
- [ ] Write tests for current implementation
- [ ] Document current behavior
- [ ] Identify all files to migrate
- [ ] Identify dependencies on this feature

**During Migration:**
- [ ] Convert models to freezed
- [ ] Register services in DI
- [ ] Extract state to separate files
- [ ] Fix navigation anti-patterns
- [ ] Split oversized widgets
- [ ] Update imports
- [ ] Update tests
- [ ] Run `flutter analyze` (no errors)
- [ ] Run tests (all pass)

**After Migration:**
- [ ] Manual smoke test of feature
- [ ] Cross-feature integration test
- [ ] Commit with descriptive message
- [ ] Merge to main
- [ ] Delete feature branch

---

## Success Criteria

✅ All file size violations fixed (<300 lines for widgets/screens)
✅ Dependency injection implemented with get_it
✅ All models use freezed
✅ Navigation anti-patterns eliminated
✅ Oversized widgets extracted
✅ Duplicate services consolidated
✅ Comprehensive test coverage
✅ Working app maintained throughout
✅ Can rollback at any checkpoint

---

## Next Steps

1. Review and approve this design document
2. Invoke writing-plans skill to create detailed implementation plan
3. Begin Phase 0: Foundation Setup
