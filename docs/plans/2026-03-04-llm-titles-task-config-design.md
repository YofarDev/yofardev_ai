# LLM-Generated Chat Titles & Task-Specific LLM Configuration Design

**Date:** 2026-03-04
**Status:** Approved
**Author:** Claude (Architecture Design)

## Overview

This design document outlines the implementation of two features:
1. **LLM-generated chat titles** - Auto-generate contextual titles for new chats based on the user's first message
2. **Task-specific LLM configuration** - Allow users to configure different LLMs for different tasks (assistant, title generation, function calling)

---

## 1. Architecture Overview

### New Models/Enums

```dart
// lib/core/models/llm_task_type.dart
enum LlmTaskType {
  assistant,
  titleGeneration,
  functionCalling,
}

// lib/core/models/task_llm_config.dart (freezed)
@freezed
class TaskLlmConfig with _$TaskLlmConfig {
  const factory TaskLlmConfig({
    @Default(null) String? assistantLlmId,
    @Default(null) String? titleGenerationLlmId,
    @Default(null) String? functionCallingLlmId,
  }) = _TaskLlmConfig;
}
```

### Modified Chat Model

Add `title` and `titleGenerated` fields to track generated titles:

```dart
@freezed
sealed class Chat with _$Chat {
  const factory Chat({
    // ... existing fields ...
    @Default('') String title,
    @Default(false) bool titleGenerated,
  }) = _Chat;
}
```

---

## 2. Title Generation Flow

### Non-Blocking Generation

1. User sends first message → chat created with temporary title (first 50 chars of message)
2. Title generation triggered immediately after first user message (fire-and-forget)
3. LLM generates title in background using dedicated/configured LLM
4. On success: Chat updated with generated title
5. On failure: Temporary title remains (silent failure)

### Temporary Title Logic

```dart
String _getTemporaryTitle(Chat chat) {
  if (chat.titleGenerated && chat.title.isNotEmpty) {
    return chat.title;
  }

  final ChatEntry? firstUserEntry = chat.entries
      .where((e) => e.entryType == EntryType.user)
      .firstOrNull;

  if (firstUserEntry == null) return localized.newChat;

  final String message = firstUserEntry.body.getVisiblePrompt();
  return message.length > 50
      ? '${message.substring(0, 47)}...'
      : message;
}
```

### LLM Prompt

```
Generate a concise title (max 5 words) for this chat: [firstUserMessage]
```

System prompt: "You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text."

---

## 3. State Management

### Modified ChatsCubit

**New Methods:**
- `generateTitleForChat(String chatId)` - Fire-and-forget title generation
- `_triggerTitleGenerationIfNeeded(Chat chat)` - Checks if title generation needed
- `_getFirstUserMessage(Chat chat)` - Extracts first user message
- `_sanitizeTitle(String title)` - Cleans and validates generated title

**State Changes:**
```dart
@freezed
sealed class ChatsState with _$ChatsState {
  const factory ChatsState({
    // ... existing fields ...
    @Default(<String>{}) Set<String> generatingTitleChatIds,
  }) = _ChatsState;
}
```

### Modified SettingsCubit

**New Methods:**
- `loadTaskLlmConfig()` - Loads task-to-LLM mapping from storage
- `setTaskLlmConfig(TaskLlmConfig)` - Persists task configuration

**State Changes:**
```dart
@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    // ... existing fields ...
    @Default(null) TaskLlmConfig? taskLlmConfig,
    @Default(<LlmConfig>[]) List<LlmConfig> availableLlmConfigs,
  }) = _SettingsState;
}
```

---

## 4. LLM Service Changes

### New Methods

```dart
class LlmService implements LlmServiceInterface {
  LlmConfig? getConfigForTask(LlmTaskType task);
  Future<String?> generateTitle(String firstUserMessage, {LlmConfig? config});
}
```

### Task Config Resolution

1. Look up task-specific LLM ID from settings
2. Find matching LlmConfig from available configs
3. If not found or not configured, fallback to current/default LLM
4. If no default available, return null (operation fails gracefully)

---

## 5. Data Layer

### SettingsLocalDataSource

```dart
static const String _keyTaskLlmConfig = 'task_llm_config';

Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig();
Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config);
```

### ChatRepository Migration

Add migration logic to add `title` and `titleGenerated` fields to existing chats:

```dart
Future<void> _migrateChatDataIfNeeded() async {
  final bool hasMigrated = prefs.getBool(_chatMigrationKey) ?? false;
  if (!hasMigrated) {
    // Add title fields to all existing chats
    for (final Chat chat in chats) {
      final Chat migratedChat = chat.copyWith(
        title: '',
        titleGenerated: false,
      );
      await _updateChatInStorage(migratedChat);
    }
    await prefs.setBool(_chatMigrationKey, true);
  }
}
```

---

## 6. UI Components

### ChatListContainer

Update `_resolvePreview()` to use generated title when available:

```dart
String _resolvePreview(Chat chat) {
  // Use title if generated
  if (chat.titleGenerated && chat.title.isNotEmpty) {
    return chat.title;
  }

  // Fall back to temporary title (first message preview)
  // ... existing logic ...
}
```

### TaskLlmConfigPage

New settings screen with dropdowns for each task type:

- **Assistant** - Main chat responses
- **Title Generation** - Chat title generation
- **Function Calling** - Tool/function detection

Each dropdown includes:
- "Use default LLM" option (null value)
- List of all configured LLMs

---

## 7. Error Handling & Edge Cases

### Title Generation Failures

- **Empty/null title returned** → Keep temporary title
- **Title too long (>100 chars)** → Sanitize and truncate
- **Quotes in title** → Strip leading/trailing quotes
- **Network timeout** → Silent failure, temporary title remains
- **Chat deleted during generation** → Repository handles gracefully

### Duplicate Generation Prevention

Track chats currently generating titles with `generatingTitleChatIds` set to prevent duplicate requests.

### LLM Config Fallback Chain

1. Task-specific config
2. Default/selected LLM config
3. Fail gracefully with null

---

## 8. Dependency Injection

```dart
// lib/core/di/injection.dart
void configureDependencies() {
  getIt.registerLazySingleton<LlmServiceInterface>(() => LlmService());

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      localDatasource: getIt<SettingsLocalDatasource>(),
    ),
  );

  getIt.registerFactory(() => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    localizationManager: getIt<LocalizationManager>(),
    ttsQueueManager: getIt<TtsQueueManager?>(),
  ));
}
```

---

## 9. Localization Strings

Add to localization files:

```json
{
  "newChat": "New chat",
  "nouvelleConversation": "Nouvelle conversation",
  "taskLlmConfig": "Task LLM Configuration",
  "assistantTask": "Assistant",
  "titleTask": "Title Generation",
  "functionCallingTask": "Function Calling",
  "useDefaultLlm": "Use default LLM",
  "taskLlmNote": "Note: If no LLM is selected for a task, the default assistant LLM will be used."
}
```

---

## 10. File Structure

```
lib/
├── core/
│   ├── models/
│   │   ├── llm_task_type.dart           (NEW)
│   │   ├── task_llm_config.dart         (NEW)
│   │   └── ...
│   └── services/
│       └── llm/
│           └── llm_service.dart         (MODIFIED)
├── features/
│   ├── chat/
│   │   ├── bloc/
│   │   │   ├── chats_cubit.dart         (MODIFIED)
│   │   │   └── chats_state.dart         (MODIFIED)
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── chat_repository_impl.dart  (MODIFIED)
│   │   ├── domain/
│   │   │   └── models/
│   │   │       └── chat.dart            (MODIFIED)
│   │   └── widgets/
│   │       └── chat_list_container.dart  (MODIFIED)
│   └── settings/
│       ├── bloc/
│       │   ├── settings_cubit.dart      (MODIFIED)
│       │   └── settings_state.dart      (MODIFIED)
│       ├── data/
│       │   ├── datasources/
│       │   │   └── settings_local_datasource.dart  (MODIFIED)
│       │   └── repositories/
│       │       └── settings_repository_impl.dart  (MODIFIED)
│       ├── domain/
│       │   └── repositories/
│       │       └── settings_repository.dart       (MODIFIED)
│       └── screens/
│           └── llm/
│               └── task_llm_config_page.dart  (NEW)
```

---

## 11. Testing Considerations

### Unit Tests

- **ChatsCubit**: Title generation trigger, duplicate prevention
- **SettingsCubit**: Task config load/save
- **LlmService**: `getConfigForTask()`, `generateTitle()`
- **Title sanitization**: Edge cases, truncation, quote removal

### Integration Tests

- End-to-end title generation flow
- Task config persistence
- Migration script execution

### Mock Considerations

- Mock `LlmService.generateTitle()` for unit tests
- Mock `SettingsRepository.getTaskLlmConfig()`

---

## 12. Future Enhancements

- User-initiated title regeneration
- Bulk title regeneration for existing chats
- Custom title editing by user
- Additional task types (summary, translation, etc.)
- Title generation history/undo
