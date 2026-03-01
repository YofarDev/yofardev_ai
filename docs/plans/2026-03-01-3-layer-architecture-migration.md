# 3-Layer Architecture Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure yofardev_ai Flutter codebase to implement 3-layer architecture (data/domain/presentation) across all features through file reorganization and repository interface extraction.

**Architecture:** File reorganization approach - move feature-specific models from `core/models/` to `features/*/domain/models/`, move services to `features/*/data/datasources/`, extract repository interfaces to `features/*/domain/repositories/`, update dependency injection, and fix all import paths.

**Tech Stack:** Flutter 3.8+, Dart, freezed, fpdart, get_it

---

## Prerequisites

**Before starting:**

1. Ensure you're on the correct branch:
   ```bash
   git branch --show-current
   ```
   Expected: `refactor/architecture-standardization`

2. Verify clean working directory:
   ```bash
   git status --short
   ```
   Expected: Empty or only expected modified files

3. Add fpdart dependency:
   ```bash
   flutter pub add fpdart
   ```
   Expected: Package added successfully

4. Verify baseline:
   ```bash
   flutter analyze
   ```
   Expected: No issues found

---

## Task 1: Create Directory Structure for All Features

**Goal:** Create empty `data/`, `domain/`, and `presentation/` directories for all features.

**Files:**
- Create: `lib/features/chat/data/`
- Create: `lib/features/chat/data/datasources/`
- Create: `lib/features/chat/data/repositories/`
- Create: `lib/features/chat/domain/`
- Create: `lib/features/chat/domain/models/`
- Create: `lib/features/chat/domain/repositories/`
- Create: `lib/features/chat/presentation/bloc/`
- Create: `lib/features/chat/presentation/screens/`
- Create: `lib/features/chat/presentation/widgets/`
- Create: `lib/features/avatar/data/`
- Create: `lib/features/avatar/data/datasources/`
- Create: `lib/features/avatar/data/repositories/`
- Create: `lib/features/avatar/domain/`
- Create: `lib/features/avatar/domain/models/`
- Create: `lib/features/avatar/domain/repositories/`
- Create: `lib/features/avatar/presentation/bloc/`
- Create: `lib/features/avatar/presentation/widgets/`
- Create: `lib/features/demo/data/`
- Create: `lib/features/demo/data/datasources/`
- Create: `lib/features/demo/data/repositories/`
- Create: `lib/features/demo/domain/`
- Create: `lib/features/demo/domain/models/`
- Create: `lib/features/demo/domain/repositories/`
- Create: `lib/features/demo/presentation/bloc/`
- Create: `lib/features/demo/presentation/screens/`
- Create: `lib/features/demo/presentation/widgets/`
- Create: `lib/features/home/data/`
- Create: `lib/features/home/data/datasources/`
- Create: `lib/features/home/domain/`
- Create: `lib/features/home/presentation/bloc/`
- Create: `lib/features/home/presentation/screens/`
- Create: `lib/features/home/presentation/widgets/`
- Create: `lib/features/settings/data/`
- Create: `lib/features/settings/data/datasources/`
- Create: `lib/features/settings/domain/`
- Create: `lib/features/settings/domain/repositories/`
- Create: `lib/features/settings/presentation/screens/`
- Create: `lib/features/settings/presentation/widgets/`
- Create: `lib/features/sound/data/`
- Create: `lib/features/sound/data/datasources/`
- Create: `lib/features/sound/data/repositories/`
- Create: `lib/features/sound/domain/`
- Create: `lib/features/sound/domain/repositories/`
- Create: `lib/features/sound/presentation/bloc/`
- Create: `lib/features/talking/domain/`
- Create: `lib/features/talking/presentation/bloc/`

**Step 1: Create chat feature directories**

```bash
mkdir -p lib/features/chat/data/datasources
mkdir -p lib/features/chat/data/repositories
mkdir -p lib/features/chat/domain/models
mkdir -p lib/features/chat/domain/repositories
mkdir -p lib/features/chat/presentation/bloc
mkdir -p lib/features/chat/presentation/screens
mkdir -p lib/features/chat/presentation/widgets
```

**Step 2: Create avatar feature directories**

```bash
mkdir -p lib/features/avatar/data/datasources
mkdir -p lib/features/avatar/data/repositories
mkdir -p lib/features/avatar/domain/models
mkdir -p lib/features/avatar/domain/repositories
mkdir -p lib/features/avatar/presentation/bloc
mkdir -p lib/features/avatar/presentation/widgets
```

**Step 3: Create demo feature directories**

```bash
mkdir -p lib/features/demo/data/datasources
mkdir -p lib/features/demo/data/repositories
mkdir -p lib/features/demo/domain/models
mkdir -p lib/features/demo/domain/repositories
mkdir -p lib/features/demo/presentation/bloc
mkdir -p lib/features/demo/presentation/screens
mkdir -p lib/features/demo/presentation/widgets
```

**Step 4: Create home feature directories**

```bash
mkdir -p lib/features/home/data/datasources
mkdir -p lib/features/home/domain
mkdir -p lib/features/home/presentation/bloc
mkdir -p lib/features/home/presentation/screens
mkdir -p lib/features/home/presentation/widgets
```

**Step 5: Create settings feature directories**

```bash
mkdir -p lib/features/settings/data/datasources
mkdir -p lib/features/settings/domain/repositories
mkdir -p lib/features/settings/presentation/screens
mkdir -p lib/features/settings/presentation/widgets
```

**Step 6: Create sound feature directories**

```bash
mkdir -p lib/features/sound/data/datasources
mkdir -p lib/features/sound/data/repositories
mkdir -p lib/features/sound/domain/repositories
mkdir -p lib/features/sound/presentation/bloc
```

**Step 7: Create talking feature directories**

```bash
mkdir -p lib/features/talking/domain
mkdir -p lib/features/talking/presentation/bloc
```

**Step 8: Verify structure**

```bash
find lib/features -type d | sort
```

Expected: All new directories listed

**Step 9: Commit**

```bash
git add lib/features
git commit -m "refactor: create 3-layer directory structure for all features"
```

---

## Task 2: Move Chat Feature Models to Domain Layer

**Goal:** Move `chat.dart` and `chat_entry.dart` from `core/models/` to `features/chat/domain/models/`.

**Files:**
- Move: `lib/core/models/chat.dart` → `lib/features/chat/domain/models/chat.dart`
- Move: `lib/core/models/chat_entry.dart` → `lib/features/chat/domain/models/chat_entry.dart`

**Step 1: Move chat.dart**

```bash
git mv lib/core/models/chat.dart lib/features/chat/domain/models/chat.dart
```

**Step 2: Move chat_entry.dart**

```bash
git mv lib/core/models/chat_entry.dart lib/features/chat/domain/models/chat_entry.dart
```

**Step 3: Update imports in chat.dart**

Edit: `lib/features/chat/domain/models/chat.dart`

Change:
```dart
import 'avatar_config.dart';
import 'chat_entry.dart';
import 'llm_message.dart';
```

To:
```dart
import '../../../avatar/domain/models/avatar_config.dart';
import 'chat_entry.dart';
import '../../../../core/models/llm_message.dart';
```

**Step 4: Update freezed part directive in chat.dart**

Edit: `lib/features/chat/domain/models/chat.dart`

Ensure line 7-8 are:
```dart
part 'chat.freezed.dart';
part 'chat.g.dart';
```

**Step 5: Update imports in chat_entry.dart**

Edit: `lib/features/chat/domain/models/chat_entry.dart`

Add/modify imports to reference new location:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'chat_entry.freezed.dart';
```

**Step 6: Verify files compile**

```bash
flutter analyze lib/features/chat/domain/models/
```

Expected: No errors

**Step 7: Commit**

```bash
git add lib/features/chat/domain/models/
git commit -m "refactor: move chat models to domain layer"
```

---

## Task 3: Move Avatar Feature Models to Domain Layer

**Goal:** Move `avatar_config.dart` from `core/models/` to `features/avatar/domain/models/`.

**Files:**
- Move: `lib/core/models/avatar_config.dart` → `lib/features/avatar/domain/models/avatar_config.dart`

**Step 1: Move avatar_config.dart**

```bash
git mv lib/core/models/avatar_config.dart lib/features/avatar/domain/models/avatar_config.dart
```

**Step 2: Verify files compile**

```bash
flutter analyze lib/features/avatar/domain/models/
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/avatar/domain/models/
git commit -m "refactor: move avatar_config to domain layer"
```

---

## Task 4: Move Demo Feature Models to Domain Layer

**Goal:** Move `demo_script.dart` from `core/models/` to `features/demo/domain/models/`.

**Files:**
- Move: `lib/core/models/demo_script.dart` → `lib/features/demo/domain/models/demo_script.dart`

**Step 1: Move demo_script.dart**

```bash
git mv lib/core/models/demo_script.dart lib/features/demo/domain/models/demo_script.dart
```

**Step 2: Verify files compile**

```bash
flutter analyze lib/features/demo/domain/models/
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/demo/domain/models/
git commit -m "refactor: move demo_script to domain layer"
```

---

## Task 5: Create Chat Repository Interface

**Goal:** Create `ChatRepository` interface in domain layer.

**Files:**
- Create: `lib/features/chat/domain/repositories/chat_repository.dart`

**Step 1: Create chat repository interface**

Create file: `lib/features/chat/domain/repositories/chat_repository.dart`

```dart
import 'package:fpdart/fpdart.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';

abstract class ChatRepository {
  Future<Either<Exception, Chat>> createNewChat();
  Future<Either<Exception, Chat?>> getChat(String id);
  Future<Either<Exception, List<Chat>>> getChatsList();
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  });
  Future<Either<Exception, void>> deleteChat(String id);
  Future<Either<Exception, void>> setCurrentChatId(String id);
  Future<Either<Exception, Chat>> getCurrentChat();
  Future<Either<Exception, void>> updateAvatar(String chatId, avatar);
  Future<Either<Exception, ChatEntry>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  });
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/chat/domain/repositories/chat_repository.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/domain/repositories/
git commit -m "refactor: add ChatRepository interface"
```

---

## Task 6: Create Avatar Repository Interface

**Goal:** Create `AvatarRepository` interface in domain layer.

**Files:**
- Create: `lib/features/avatar/domain/repositories/avatar_repository.dart`

**Step 1: Create avatar repository interface**

Create file: `lib/features/avatar/domain/repositories/avatar_repository.dart`

```dart
import 'package:fpdart/fpdart.dart';
import '../models/avatar_config.dart';
import '../../../../core/models/chat.dart';

abstract class AvatarRepository {
  Future<Either<Exception, Chat>> getChat(String id);
  Future<Either<Exception, void>> updateAvatar(String chatId, Avatar avatar);
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/avatar/domain/repositories/avatar_repository.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/avatar/domain/repositories/
git commit -m "refactor: add AvatarRepository interface"
```

---

## Task 7: Create Settings Repository Interface

**Goal:** Create `SettingsRepository` interface in domain layer.

**Files:**
- Create: `lib/features/settings/domain/repositories/settings_repository.dart`

**Step 1: Create settings repository interface**

Create file: `lib/features/settings/domain/repositories/settings_repository.dart`

```dart
import 'package:fpdart/fpdart.dart';

abstract class SettingsRepository {
  Future<Either<Exception, String?>> getLanguage();
  Future<Either<Exception, void>> setLanguage(String language);
  Future<Either<Exception, bool>> getSoundEffects();
  Future<Either<Exception, void>> setSoundEffects(bool enabled);
  Future<Either<Exception, String?>> getUsername();
  Future<Either<Exception, void>> setUsername(String username);
  Future<Either<Exception, String>> getSystemPrompt();
  Future<Either<Exception, void>> setSystemPrompt(String prompt);
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/settings/domain/repositories/settings_repository.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/settings/domain/repositories/
git commit -m "refactor: add SettingsRepository interface"
```

---

## Task 8: Create Sound Repository Interface

**Goal:** Create `SoundRepository` interface in domain layer.

**Files:**
- Create: `lib/features/sound/domain/repositories/sound_repository.dart`

**Step 1: Create sound repository interface**

Create file: `lib/features/sound/domain/repositories/sound_repository.dart`

```dart
import 'package:fpdart/fpdart.dart';

abstract class SoundRepository {
  Future<Either<Exception, void>> play(String soundPath);
  Future<Either<Exception, void>> stop();
  Future<Either<Exception, bool>> get isPlaying;
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/sound/domain/repositories/sound_repository.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/sound/domain/repositories/
git commit -m "refactor: add SoundRepository interface"
```

---

## Task 9: Move ChatHistoryService to Data Layer

**Goal:** Move `chat_history_service.dart` from `core/services/` to `features/chat/data/datasources/`.

**Files:**
- Move: `lib/core/services/chat_history_service.dart` → `lib/features/chat/data/datasources/chat_local_datasource.dart`

**Step 1: Move file**

```bash
git mv lib/core/services/chat_history_service.dart lib/features/chat/data/datasources/chat_local_datasource.dart
```

**Step 2: Rename class in file**

Edit: `lib/features/chat/data/datasources/chat_local_datasource.dart`

Change class name from `ChatHistoryService` to `ChatLocalDatasource`.

**Step 3: Update imports for moved models**

Edit: `lib/features/chat/data/datasources/chat_local_datasource.dart`

Change imports to:
```dart
import '../models/chat.dart';
import '../models/chat_entry.dart';
```

**Step 4: Verify file compiles**

```bash
flutter analyze lib/features/chat/data/datasources/chat_local_datasource.dart
```

Expected: Some errors (will be fixed when imports are updated globally)

**Step 5: Commit**

```bash
git add lib/features/chat/data/datasources/
git commit -m "refactor: move ChatHistoryService to data layer as ChatLocalDatasource"
```

---

## Task 10: Move SettingsService to Data Layer

**Goal:** Move `settings_service.dart` from `core/services/` to `features/settings/data/datasources/`.

**Files:**
- Move: `lib/core/services/settings_service.dart` → `lib/features/settings/data/datasources/settings_local_datasource.dart`

**Step 1: Move file**

```bash
git mv lib/core/services/settings_service.dart lib/features/settings/data/datasources/settings_local_datasource.dart
```

**Step 2: Rename class in file**

Edit: `lib/features/settings/data/datasources/settings_local_datasource.dart`

Change class name from `SettingsService` to `SettingsLocalDatasource`.

**Step 3: Verify file compiles**

```bash
flutter analyze lib/features/settings/data/datasources/settings_local_datasource.dart
```

Expected: Some errors (will be fixed when imports are updated globally)

**Step 4: Commit**

```bash
git add lib/features/settings/data/datasources/
git commit -m "refactor: move SettingsService to data layer as SettingsLocalDatasource"
```

---

## Task 11: Move CacheService to Data Layer

**Goal:** Move `cache_service.dart` from `core/services/` to `features/avatar/data/datasources/`.

**Files:**
- Move: `lib/core/services/cache_service.dart` → `lib/features/avatar/data/datasources/avatar_cache_datasource.dart`

**Step 1: Move file**

```bash
git mv lib/core/services/cache_service.dart lib/features/avatar/data/datasources/avatar_cache_datasource.dart
```

**Step 2: Rename class in file**

Edit: `lib/features/avatar/data/datasources/avatar_cache_datasource.dart`

Change class name from `CacheService` to `AvatarCacheDatasource`.

**Step 3: Verify file compiles**

```bash
flutter analyze lib/features/avatar/data/datasources/avatar_cache_datasource.dart
```

**Step 4: Commit**

```bash
git add lib/features/avatar/data/datasources/
git commit -m "refactor: move CacheService to avatar data layer"
```

---

## Task 12: Move Demo Services to Data Layer

**Goal:** Move demo services from `features/demo/services/` to `features/demo/data/`.

**Files:**
- Move: `lib/features/demo/services/demo_service.dart` → `lib/features/demo/data/repositories/demo_repository_impl.dart`
- Move: `lib/features/demo/services/demo_controller.dart` → `lib/features/demo/data/datasources/demo_controller.dart`

**Step 1: Move demo_service.dart**

```bash
git mv lib/features/demo/services/demo_service.dart lib/features/demo/data/repositories/demo_repository_impl.dart
```

**Step 2: Move demo_controller.dart**

```bash
git mv lib/features/demo/services/demo_controller.dart lib/features/demo/data/datasources/demo_controller.dart
```

**Step 3: Verify files compile**

```bash
flutter analyze lib/features/demo/data/
```

**Step 4: Commit**

```bash
git add lib/features/demo/data/
git rm -r lib/features/demo/services/
git commit -m "refactor: move demo services to data layer"
```

---

## Task 13: Move YofardevRepository to Data Layer

**Goal:** Move `yofardev_repository.dart` from `core/repositories/` to `features/chat/data/repositories/`.

**Files:**
- Move: `lib/core/repositories/yofardev_repository.dart` → `lib/features/chat/data/repositories/yofardev_repository_impl.dart`

**Step 1: Move file**

```bash
git mv lib/core/repositories/yofardev_repository.dart lib/features/chat/data/repositories/yofardev_repository_impl.dart
```

**Step 2: Update class name to implement interface**

Edit: `lib/features/chat/data/repositories/yofardev_repository_impl.dart`

Change:
```dart
class YofardevRepository {
```

To:
```dart
class YofardevRepositoryImpl implements ChatRepository {
```

**Step 3: Add Either return types**

Edit: `lib/features/chat/data/repositories/yofardev_repository_impl.dart`

Wrap return values in `Either`:

```dart
@override
Future<Either<Exception, ChatEntry>> askYofardevAi(
  Chat chat,
  String userMessage, {
  bool functionCallingEnabled = true,
}) async {
  try {
    // Check if fake LLM service has a scripted response
    if (_fakeLlmService.isActive) {
      final FakeLlmResponse? fakeResponse = _fakeLlmService.getNextResponse();
      if (fakeResponse != null) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return Right(ChatEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          entryType: EntryType.yofardev,
          body: fakeResponse.jsonBody,
          timestamp: DateTime.now(),
        ));
      }
    }

    // Fall back to real LLM
    final entry = await _agent.ask(
      chat: chat,
      userMessage: userMessage,
      systemPrompt: await _promptService.getSystemPrompt(),
      functionCallingEnabled: functionCallingEnabled,
    );
    return Right(entry);
  } catch (e) {
    return Left(Exception(e.toString()));
  }
}
```

**Step 4: Update imports**

Edit: `lib/features/chat/data/repositories/yofardev_repository_impl.dart`

```dart
import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../../demo/domain/models/demo_script.dart';
import '../../../../core/services/agent/yofardev_agent.dart';
import '../../../../core/services/prompt_service.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
```

**Step 5: Verify file compiles**

```bash
flutter analyze lib/features/chat/data/repositories/yofardev_repository_impl.dart
```

**Step 6: Commit**

```bash
git add lib/features/chat/data/repositories/
git commit -m "refactor: move YofardevRepository to data layer and implement ChatRepository"
```

---

## Task 14: Move PromptService to Data Layer

**Goal:** Move `prompt_service.dart` from `core/services/` to `features/home/data/datasources/`.

**Files:**
- Move: `lib/core/services/prompt_service.dart` → `lib/features/home/data/datasources/prompt_datasource.dart`

**Step 1: Move file**

```bash
git mv lib/core/services/prompt_service.dart lib/features/home/data/datasources/prompt_datasource.dart
```

**Step 2: Rename class**

Edit: `lib/features/home/data/datasources/prompt_datasource.dart`

Change class name from `PromptService` to `PromptDatasource`.

**Step 3: Verify file compiles**

```bash
flutter analyze lib/features/home/data/datasources/prompt_datasource.dart
```

**Step 4: Commit**

```bash
git add lib/features/home/data/datasources/
git commit -m "refactor: move PromptService to home data layer"
```

---

## Task 15: Move Sound Services to Data Layer

**Goal:** Move sound-related services from `core/services/` to `features/sound/data/`.

**Files:**
- Move: `lib/core/services/tts_service.dart` → `lib/features/sound/data/datasources/tts_datasource.dart`
- Move: `lib/core/services/agent/sound_service.dart` → `lib/features/sound/data/repositories/sound_repository_impl.dart`
- Move: `lib/core/services/sound_service_interface.dart` → `lib/features/sound/domain/repositories/sound_repository.dart`

**Step 1: Move tts_service.dart**

```bash
git mv lib/core/services/tts_service.dart lib/features/sound/data/datasources/tts_datasource.dart
```

**Step 2: Rename TtsService class**

Edit: `lib/features/sound/data/datasources/tts_datasource.dart`

Change class name from `TtsService` to `TtsDatasource`.

**Step 3: Move sound_service.dart**

```bash
git mv lib/core/services/agent/sound_service.dart lib/features/sound/data/repositories/sound_repository_impl.dart
```

**Step 4: Rename and implement interface**

Edit: `lib/features/sound/data/repositories/sound_repository_impl.dart`

Change class declaration to implement interface and add Either return types.

**Step 5: Move sound_service_interface.dart**

```bash
git mv lib/core/services/sound_service_interface.dart lib/features/sound/domain/repositories/sound_repository.dart
```

**Step 6: Update interface to use Either**

Edit: `lib/features/sound/domain/repositories/sound_repository.dart`

Update method signatures to return `Either<Exception, T>`.

**Step 7: Verify files compile**

```bash
flutter analyze lib/features/sound/data/
flutter analyze lib/features/sound/domain/
```

**Step 8: Commit**

```bash
git add lib/features/sound/
git commit -m "refactor: move sound services to data layer"
```

---

## Task 16: Update All Import Paths - Automated Script

**Goal:** Create and run script to fix all import paths.

**Files:**
- Create: `scripts/fix_imports.dart`

**Step 1: Create import fix script**

Create file: `scripts/fix_imports.dart`

```dart
import 'dart:io';

void main() async {
  final libDir = Directory('lib');

  final replacements = <String, String>{
    // Core models → Feature domain models
    "'../../../core/models/chat.dart'": "'../../domain/models/chat.dart'",
    "'../../../core/models/chat_entry.dart'": "'../../domain/models/chat_entry.dart'",
    "'../../../core/models/avatar_config.dart'": "'../../domain/models/avatar_config.dart'",
    "'../../../core/models/demo_script.dart'": "'../../domain/models/demo_script.dart'",

    // Core services → Feature data sources
    "'../../../core/services/chat_history_service.dart'": "'../../data/datasources/chat_local_datasource.dart'",
    "'../../../core/services/settings_service.dart'": "'../../../../features/settings/domain/repositories/settings_repository.dart'",
    "'../../../core/services/cache_service.dart'": "'../../data/datasources/avatar_cache_datasource.dart'",
    "'../../../core/services/prompt_service.dart'": "'../../data/datasources/prompt_datasource.dart'",
    "'../../../core/services/tts_service.dart'": "'../../../features/sound/data/datasources/tts_datasource.dart'",

    // Core repositories → Feature repositories
    "'../../../core/repositories/yofardev_repository.dart'": "'../../data/repositories/yofardev_repository_impl.dart'",

    // Cross-feature imports
    "'../../../core/models/chat.dart'": "'../../../features/chat/domain/models/chat.dart'",
    "'../../../core/models/chat_entry.dart'": "'../../../features/chat/domain/models/chat_entry.dart'",
    "'../../../core/models/avatar_config.dart'": "'../../../features/avatar/domain/models/avatar_config.dart'",
    "'../../../core/models/demo_script.dart'": "'../../../features/demo/domain/models/demo_script.dart'",

    // Demo services
    "'../services/demo_service.dart'": "'../data/repositories/demo_repository_impl.dart'",
    "'../services/demo_controller.dart'": "'../data/datasources/demo_controller.dart'",
  };

  await for (final entity in libDir.list(recursive: true)) {
    if (entity.path.endsWith('.dart')) {
      final file = File(entity.path);
      var content = await file.readAsString();
      var modified = false;

      for (final entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          modified = true;
        }
      }

      if (modified) {
        await file.writeAsString(content);
        print('✓ Updated: ${entity.path}');
      }
    }
  }

  print('\nImport fix complete!');
}
```

**Step 2: Create scripts directory**

```bash
mkdir -p scripts
```

**Step 3: Run import fix script**

```bash
dart run scripts/fix_imports.dart
```

Expected: List of updated files

**Step 4: Verify no analyze errors**

```bash
flutter analyze
```

Expected: May have some errors (will fix in next tasks)

**Step 5: Commit script**

```bash
git add scripts/fix_imports.dart
git add lib/
git commit -m "refactor: update import paths for new structure"
```

---

## Task 17: Fix Broken Imports - Chat Feature

**Goal:** Manually fix any remaining broken imports in chat feature.

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Modify: `lib/features/chat/presentation/screens/*.dart`
- Modify: `lib/features/chat/presentation/widgets/*.dart`

**Step 1: Check for errors**

```bash
flutter analyze lib/features/chat/
```

**Step 2: Fix imports in ChatsCubit**

Edit: `lib/features/chat/presentation/bloc/chats_cubit.dart`

Update imports to:
```dart
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/repositories/yofardev_repository_impl.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../avatar/domain/models/avatar_config.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
```

**Step 3: Update constructor to use interfaces**

Edit: `lib/features/chat/presentation/bloc/chats_cubit.dart`

Change constructor to:
```dart
class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
```

**Step 4: Update method calls to use Either**

Edit: `lib/features/chat/presentation/bloc/chats_cubit.dart`

Update methods to unwrap Either:

```dart
void createNewChat() async {
  emit(state.copyWith(status: ChatsStatus.updating));
  final result = await _chatRepository.createNewChat();
  result.fold(
    (error) {
      emit(state.copyWith(status: ChatsStatus.error, errorMessage: error.toString()));
    },
    (newChat) {
      emit(state.copyWith(
        status: ChatsStatus.success,
        chatsList: <Chat>[newChat, ...state.chatsList],
        currentChat: newChat,
        chatCreated: true,
      ));
      emit(state.copyWith(chatCreated: false));
    },
  );
}
```

**Step 5: Verify chat feature compiles**

```bash
flutter analyze lib/features/chat/
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/chat/
git commit -m "refactor: fix imports and update ChatsCubit to use repository interfaces"
```

---

## Task 18: Fix Broken Imports - Avatar Feature

**Goal:** Fix imports in avatar feature.

**Files:**
- Modify: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`

**Step 1: Check for errors**

```bash
flutter analyze lib/features/avatar/
```

**Step 2: Fix imports in AvatarCubit**

Edit: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`

Update imports to:
```dart
import '../../domain/models/avatar_config.dart';
import '../../domain/repositories/avatar_repository.dart';
```

**Step 3: Update constructor to use repository**

Edit: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`

Change constructor:
```dart
class AvatarCubit extends Emit<AvatarState> {
  AvatarCubit({
    required AvatarRepository avatarRepository,
  }) : _avatarRepository = avatarRepository,
       super(const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()));

  final AvatarRepository _avatarRepository;
```

**Step 4: Update method calls to use Either**

Edit: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`

Update methods to unwrap Either.

**Step 5: Verify avatar feature compiles**

```bash
flutter analyze lib/features/avatar/
```

**Step 6: Commit**

```bash
git add lib/features/avatar/
git commit -m "refactor: fix imports and update AvatarCubit to use repository interface"
```

---

## Task 19: Fix Broken Imports - Other Features

**Goal:** Fix imports in remaining features (demo, home, settings, sound, talking).

**Files:**
- Modify: `lib/features/demo/presentation/bloc/demo_cubit.dart`
- Modify: `lib/features/home/presentation/bloc/home_cubit.dart`
- Modify: `lib/features/settings/presentation/screens/*.dart`
- Modify: `lib/features/sound/presentation/bloc/sound_cubit.dart`
- Modify: `lib/features/talking/presentation/bloc/talking_cubit.dart`

**Step 1: Fix DemoCubit**

Edit: `lib/features/demo/presentation/bloc/demo_cubit.dart`

Update imports and constructor to use repository interfaces.

**Step 2: Fix HomeCubit**

Edit: `lib/features/home/presentation/bloc/home_cubit.dart`

Update imports and constructor to use datasources.

**Step 3: Fix settings screens**

Edit: `lib/features/settings/presentation/screens/*.dart`

Update imports to reference new locations.

**Step 4: Fix SoundCubit**

Edit: `lib/features/sound/presentation/bloc/sound_cubit.dart`

Update imports and constructor to use SoundRepository interface.

**Step 5: Verify all features compile**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/
git commit -m "refactor: fix imports in remaining features"
```

---

## Task 20: Update Service Locator

**Goal:** Update `service_locator.dart` to register repositories and use new constructor signatures.

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update imports**

Edit: `lib/core/di/service_locator.dart`

Add new imports:
```dart
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/yofardev_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/avatar/domain/repositories/avatar_repository.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/sound/domain/repositories/sound_repository.dart';
```

**Step 2: Register data sources**

Edit: `lib/core/di/service_locator.dart`

Add after services section:
```dart
// Data sources
getIt.registerLazySingleton<ChatLocalDatasource>(() => ChatLocalDatasource());
getIt.registerLazySingleton<SettingsLocalDatasource>(() => SettingsLocalDatasource());
```

**Step 3: Register repositories**

Edit: `lib/core/di/service_locator.dart`

Update repository registrations:
```dart
// Repositories
getIt.registerLazySingleton<ChatRepository>(
  () => YofardevRepositoryImpl(),
);
getIt.registerLazySingleton<AvatarRepository>(
  () => AvatarRepositoryImpl(),
);
getIt.registerLazySingleton<SettingsRepository>(
  () => SettingsRepositoryImpl(),
);
getIt.registerLazySingleton<SoundRepository>(
  () => SoundRepositoryImpl(),
);
```

**Step 4: Update cubit registrations**

Edit: `lib/core/di/service_locator.dart`

Update cubit factory registrations to use new constructors:
```dart
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
  ),
);
getIt.registerFactory<AvatarCubit>(
  () => AvatarCubit(
    avatarRepository: getIt<AvatarRepository>(),
  ),
);
```

**Step 5: Verify service locator compiles**

```bash
flutter analyze lib/core/di/service_locator.dart
```

**Step 6: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "refactor: update service locator with repository interfaces"
```

---

## Task 21: Regenerate Freezed Files

**Goal:** Regenerate freezed files after moving models.

**Step 1: Clean build**

```bash
flutter clean
```

**Step 2: Get dependencies**

```bash
flutter pub get
```

**Step 3: Regenerate code**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: Successfully generated files

**Step 4: Verify no errors**

```bash
flutter analyze
```

Expected: No errors

**Step 5: Commit generated files**

```bash
git add lib/
git commit -m "refactor: regenerate freezed files after model migration"
```

---

## Task 22: Verification - Build Test

**Goal:** Verify app builds successfully.

**Step 1: Try building**

```bash
flutter build apk --debug
```

OR for web:
```bash
flutter build web
```

Expected: Build succeeds

**Step 2: If build fails, fix errors**

Review error output and fix any remaining issues.

**Step 3: Commit any fixes**

```bash
git add lib/
git commit -m "refactor: fix build errors"
```

---

## Task 23: Verification - Runtime Smoke Test

**Goal:** Verify app launches and basic features work.

**Step 1: Launch app**

```bash
flutter run
```

**Step 2: Smoke test checklist**

Manual testing:
- [ ] App launches without crash
- [ ] Chat list loads
- [ ] Can create new chat
- [ ] Avatar displays correctly
- [ ] Settings page opens
- [ ] Can change language
- [ ] Navigation between screens works

**Step 4: Document any issues**

If issues found, create note for follow-up.

**Step 5: Final commit**

```bash
git add lib/
git commit -m "refactor: fix runtime issues found during smoke testing"
```

---

## Task 24: Cleanup - Remove Empty Directories

**Goal:** Remove now-empty directories.

**Step 1: Remove empty directories**

```bash
# Remove empty core directories if they exist
rmdir lib/core/models 2>/dev/null || true
rmdir lib/core/repositories 2>/dev/null || true
rmdir lib/core/services/agent 2>/dev/null || true
```

**Step 2: Verify no important files were deleted**

```bash
git status
```

**Step 3: Commit cleanup**

```bash
git add -A
git commit -m "refactor: remove empty directories after migration"
```

---

## Task 25: Final Verification

**Goal:** Final check that everything is working.

**Step 1: Run full analysis**

```bash
flutter analyze
```

Expected: No issues

**Step 2: Run tests**

```bash
flutter test
```

Expected: Existing tests pass

**Step 3: Check directory structure**

```bash
find lib/features -type d | sort
```

Expected: All features have data/domain/presentation structure

**Step 4: Final commit**

```bash
git commit --allow-empty -m "refactor: complete 3-layer architecture migration"
```

---

## Success Criteria

✅ All features have `data/`, `domain/`, `presentation/` structure
✅ Repository interfaces extracted for all features
✅ `flutter analyze` passes with 0 errors
✅ `flutter build` succeeds
✅ App launches and basic features work
✅ No broken imports

---

## Rollback Plan

If critical issues arise:

```bash
# Reset to before migration
git log --oneline -10
git reset --hard <commit-before-migration>

# OR start fresh from main
git checkout main
git checkout -b refactor/3-layer-architecture-v2
```

---

## Next Steps After Migration

Once this migration is complete, future work can include:

1. **Extract use cases** - Create use case classes in domain layer
2. **Add comprehensive tests** - Unit tests for repositories and use cases
3. **Implement custom Failure types** - Replace generic Exception with typed failures
4. **Add go_router** - Implement declarative routing
5. **Convert widget methods to classes** - Extract `_build` methods to widget classes

---

**End of Implementation Plan**
