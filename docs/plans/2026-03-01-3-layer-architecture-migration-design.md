# 3-Layer Architecture Migration - Design Document

**Date:** 2026-03-01
**Status:** Approved
**Author:** Claude Code
**Approach:** File Reorganization (Option A)

## Executive Summary

A **file reorganization migration** to implement 3-layer architecture (data/domain/presentation) across all features in the yofardev_ai Flutter codebase. This focuses on structural changes with minimal code modifications, establishing the foundation for future architectural improvements.

## Problem Statement

The current codebase mixes architectural layers, with models in `core/`, services scattered between `core/services/` and `features/*/services/`, and no clear separation between data and domain logic. This violates the standardized 3-layer feature architecture defined in the Flutter architecture skill.

### Current Issues

1. **Feature-specific models in core** - `chat.dart`, `chat_entry.dart`, `avatar_config.dart` should be in feature domains
2. **No repository interfaces** - Concrete classes used directly, hard to test
3. **Services not organized by layer** - Mix of data sources and business logic
4. **No clear data/domain separation** - Cubits depend directly on services

## Goals

1. **Establish 3-layer structure** - Each feature has `data/`, `domain/`, `presentation/` folders
2. **Extract repository interfaces** - Enable dependency inversion and testability
3. **Move feature-specific code** - Models and services belong to their features
4. **Minimal code changes** - Focus on file moves, not behavioral changes
5. **Maintain functionality** - Zero regressions in user-facing features

## Design

### Section 1: Target Directory Structure

All features follow this pattern:

```
features/{feature}/
├── data/
│   ├── datasources/           # Local storage, API clients
│   └── repositories/          # Repository implementations
├── domain/
│   ├── models/                # Feature entities (freezed)
│   └── repositories/          # Repository interfaces
└── presentation/
    ├── bloc/                  # Cubits and state
    ├── screens/               # UI screens
    └── widgets/               # Reusable widgets
```

**Example (chat feature):**
```
features/chat/
├── data/
│   ├── datasources/
│   │   ├── chat_local_datasource.dart
│   │   └── chat_remote_datasource.dart
│   └── repositories/
│       └── chat_repository_impl.dart
├── domain/
│   ├── models/
│   │   ├── chat.dart
│   │   └── chat_entry.dart
│   └── repositories/
│       └── chat_repository.dart
└── presentation/
    ├── bloc/
    ├── screens/
    └── widgets/
```

---

### Section 2: File Mapping

#### **Feature: chat**

**Moves:**
| From | To |
|------|-----|
| `core/models/chat.dart` | `features/chat/domain/models/chat.dart` |
| `core/models/chat_entry.dart` | `features/chat/domain/models/chat_entry.dart` |
| `core/repositories/yofardev_repository.dart` | `features/chat/data/repositories/chat_repository_impl.dart` |
| `core/services/chat_history_service.dart` | `features/chat/data/datasources/chat_local_datasource.dart` |

---

#### **Feature: avatar**

**Moves:**
| From | To |
|------|-----|
| `core/models/avatar_config.dart` | `features/avatar/domain/models/avatar_config.dart` |
| `core/services/cache_service.dart` | `features/avatar/data/datasources/avatar_cache_datasource.dart` |

---

#### **Feature: demo**

**Moves:**
| From | To |
|------|-----|
| `core/models/demo_script.dart` | `features/demo/domain/models/demo_script.dart` |
| `features/demo/services/demo_service.dart` | `features/demo/data/repositories/demo_repository_impl.dart` |
| `features/demo/services/demo_controller.dart` | `features/demo/data/datasources/demo_controller.dart` |

---

#### **Feature: home**

**Moves:**
| From | To |
|------|-----|
| `core/services/prompt_service.dart` | `features/home/data/datasources/prompt_datasource.dart` |

---

#### **Feature: settings**

**Moves:**
| From | To |
|------|-----|
| `core/services/settings_service.dart` | `features/settings/data/datasources/settings_local_datasource.dart` |

---

#### **Feature: sound**

**Moves:**
| From | To |
|------|-----|
| `core/services/tts_service.dart` | `features/sound/data/datasources/tts_datasource.dart` |
| `core/services/agent/sound_service.dart` | `features/sound/data/repositories/sound_repository_impl.dart` |
| `core/services/sound_service_interface.dart` | `features/sound/domain/repositories/sound_repository.dart` |

---

#### **Feature: talking**

**No data layer needed** - Pure UI state feature.

**Structure:**
```
features/talking/
├── domain/
│   └── entities/
│       └── talking_state.dart
└── presentation/
    └── bloc/
        ├── talking_cubit.dart
        └── talking_state.dart
```

---

#### **Shared Models (stay in core/)**

These remain in `core/models/` as they're used by multiple features:
- `answer.dart`
- `voice.dart`
- `function_info.dart`
- `llm_message.dart`
- `sound_effects.dart`
- `llm_config.dart`

---

### Section 3: Repository Interfaces

#### **Chat Repository Interface**

```dart
// features/chat/domain/repositories/chat_repository.dart
import 'package:fpdart/fpdart.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';

abstract class ChatRepository {
  Future<Either<Exception, Chat>> createNewChat();
  Future<Either<Exception, Chat?>> getChat(String id);
  Future<Either<Exception, List<Chat>>> getChatsList();
  Future<Either<Exception, void>> updateChat({required String id, required Chat updatedChat});
  Future<Either<Exception, void>> deleteChat(String id);
  Future<Either<Exception, void>> setCurrentChatId(String id);
  Future<Either<Exception, Chat>> getCurrentChat();
  Future<Either<Exception, void>> updateAvatar(String chatId, Avatar avatar);
  Future<Either<Exception, ChatEntry>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  });
}
```

#### **Other Repository Interfaces**

- `AvatarRepository` (avatar feature)
- `DemoRepository` (demo feature)
- `SettingsRepository` (settings feature)
- `SoundRepository` (sound feature)

All use `Either<Exception, T>` from `fpdart` for typed error handling.

---

### Section 4: Dependency Injection

#### **Updated Service Locator Structure**

```dart
// lib/core/di/service_locator.dart

// 1. Data Sources
getIt.registerLazySingleton<ChatLocalDatasource>(() => ChatLocalDatasourceImpl());
getIt.registerLazySingleton<ChatRemoteDatasource>(() => ChatRemoteDatasourceImpl());

// 2. Repositories (Interface → Implementation)
getIt.registerLazySingleton<ChatRepository>(
  () => ChatRepositoryImpl(
    localDatasource: getIt<ChatLocalDatasource>(),
    remoteDatasource: getIt<ChatRemoteDatasource>(),
  ),
);

// 3. Cubits (depend on interfaces)
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
  ),
);
```

#### **Cubit Constructor Changes**

**Before:**
```dart
ChatsCubit({
  required ChatHistoryService chatHistoryService,
  required SettingsService settingsService,
  required YofardevRepository yofardevRepository,
});
```

**After:**
```dart
ChatsCubit({
  required ChatRepository chatRepository,
  required SettingsRepository settingsRepository,
});
```

---

### Section 5: Import Path Updates

#### **Mapping Strategy**

| Old Path | New Path |
|----------|----------|
| `'../../core/models/chat.dart'` | `'../../domain/models/chat.dart'` |
| `'../../core/services/chat_history_service.dart'` | `'../../data/datasources/chat_local_datasource.dart'` |
| `'../../core/repositories/yofardev_repository.dart'` | `'../../data/repositories/chat_repository_impl.dart'` |
| `'../../core/services/settings_service.dart'` | `'../../../../features/settings/domain/repositories/settings_repository.dart'` |

#### **Automated Fix Script**

Create `scripts/fix_imports.dart` to batch-update imports:
- Define replacement patterns
- Recursively scan `lib/`
- Apply replacements
- Log modified files

#### **Import Style Standards**

**Within feature:**
```dart
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
```

**Cross-feature:**
```dart
import '../../../features/avatar/domain/models/avatar_config.dart';
```

**From core:**
```dart
import '../../../core/utils/logger.dart';
```

---

### Section 6: Verification & Testing

#### **Verification Steps**

1. **File structure** - Verify new directories exist
2. **Import analysis** - `flutter analyze` (0 errors expected)
3. **Code generation** - `flutter pub run build_runner build`
4. **Build test** - `flutter build apk --debug`
5. **Runtime smoke tests** - Manual feature verification

#### **Success Criteria**

✅ All features have 3-layer structure
✅ `flutter analyze` passes with 0 errors
✅ `flutter build` succeeds
✅ App launches and features work
✅ No broken imports

#### **Commit Strategy**

```bash
git commit -m "refactor: create 3-layer directory structure"
git commit -m "refactor: move feature-specific models to domain layer"
git commit -m "refactor: move services to data/datasources"
git commit -m "refactor: update import paths for new structure"
git commit -m "refactor: update service locator with repository interfaces"
git commit -m "refactor: fix imports and verify compilation"
```

---

## Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  fpdart: ^1.0.0  # For Either<Exception, T> type
```

---

## Migration Order

| Phase | Description | Time |
|-------|-------------|------|
| 1 | Create directory structure | 30 min |
| 2 | Move models to domain | 30 min |
| 3 | Move services to data layer | 1 hour |
| 4 | Create repository interfaces | 1 hour |
| 5 | Update imports (automated) | 30 min |
| 6 | Update service locator | 30 min |
| 7 | Update cubit constructors | 1 hour |
| 8 | Verification and fixes | 1 hour |
| **Total** | | **~5-6 hours** |

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking imports | High | Automated fix script + analyze verification |
| Circular dependencies | Medium | Cross-feature imports use lib-root relative paths |
| Runtime crashes | Medium | Smoke tests after each phase |
| Freezed generation errors | Low | Clean build + regenerate after migration |

---

## Deferred Work

**Not included in this migration (future phases):**

- Use case extraction (business logic layer)
- Full error handling with custom Failure types
- Comprehensive test coverage
- Repository interface extraction for all services

---

## Next Steps

1. **Create implementation plan** - Detailed step-by-step guide
2. **Create branch** - `refactor/3-layer-architecture`
3. **Execute phases 1-8** - Follow migration order
4. **Verify and deploy** - Ensure quality before merge

---

**Document Version:** 1.0
**Last Updated:** 2026-03-01
