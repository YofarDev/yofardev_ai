# LLM-Generated Chat Titles & Task-Specific LLM Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement automatic LLM-generated chat titles and allow users to configure different LLMs for different tasks (assistant, title generation, function calling).

**Architecture:** Add `title` and `titleGenerated` fields to Chat model; create `LlmTaskType` enum and `TaskLlmConfig` model; implement non-blocking title generation in ChatsCubit; extend SettingsRepository with task config persistence; add settings UI for task-to-LLM mapping.

**Tech Stack:** Flutter, BLoC/Cubit, freezed, fpdart, SharedPreferences, get_it DI

---

## Task 1: Add LlmTaskType Enum

**Files:**
- Create: `lib/core/models/llm_task_type.dart`

**Step 1: Create the enum file**

```dart
/// Represents different task types that can use different LLM configurations
enum LlmTaskType {
  /// Main chat assistant responses
  assistant,

  /// Chat title generation
  titleGeneration,

  /// Function/tool calling detection
  functionCalling,
}
```

**Step 2: Commit**

```bash
git add lib/core/models/llm_task_type.dart
git commit -m "feat: add LlmTaskType enum for task-specific LLM configuration"
```

---

## Task 2: Add TaskLlmConfig Freezed Model

**Files:**
- Create: `lib/core/models/task_llm_config.dart`
- Create: `lib/core/models/task_llm_config.freezed.dart` (auto-generated)
- Create: `lib/core/models/task_llm_config.g.dart` (auto-generated)

**Step 1: Create the model**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_llm_config.freezed.dart';
part 'task_llm_config.g.dart';

/// Configuration mapping LLM IDs to specific task types
@freezed
class TaskLlmConfig with _$TaskLlmConfig {
  const factory TaskLlmConfig({
    /// LLM config ID to use for assistant responses
    @Default(null) String? assistantLlmId,

    /// LLM config ID to use for title generation
    @Default(null) String? titleGenerationLlmId,

    /// LLM config ID to use for function calling
    @Default(null) String? functionCallingLlmId,
  }) = _TaskLlmConfig;

  factory TaskLlmConfig.fromJson(Map<String, dynamic> json) =>
      _$TaskLlmConfigFromJson(json);
}
```

**Step 2: Run build_runner to generate freezed code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Files created at `lib/core/models/task_llm_config.freezed.dart` and `lib/core/models/task_llm_config.g.dart`

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/models/task_llm_config.dart lib/core/models/task_llm_config.freezed.dart lib/core/models/task_llm_config.g.dart
git commit -m "feat: add TaskLlmConfig model for task-to-LLM mapping"
```

---

## Task 3: Update Chat Model with Title Fields

**Files:**
- Modify: `lib/features/chat/domain/models/chat.dart`

**Step 1: Add title fields to Chat model**

Find the `@freezed` class `Chat` and add the new fields after `persona`:

```dart
@freezed
sealed class Chat with _$Chat {
  const Chat._();

  const factory Chat({
    @Default('') String id,
    @Default(<ChatEntry>[]) List<ChatEntry> entries,
    @AvatarJsonConverter() @Default(Avatar()) Avatar avatar,
    @Default('en') String language,
    @Default('') String systemPrompt,
    @Default(ChatPersona.normal) ChatPersona persona,
    // NEW FIELDS:
    @Default('') String title,
    @Default(false) bool titleGenerated,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => Chat.fromMap(json);
```

**Step 2: Update toMap method to include new fields**

Find the `toMap()` method and add the new fields:

```dart
Map<String, dynamic> toMap() {
  return <String, dynamic>{
    'id': id,
    'entries': entries.map((ChatEntry x) => x.toJson()).toList(),
    'avatar': avatar.toMap(),
    'language': language,
    'systemPrompt': systemPrompt,
    'persona': persona.name,
    // NEW FIELDS:
    'title': title,
    'titleGenerated': titleGenerated,
  };
}
```

**Step 3: Update fromMap factory to handle new fields**

Find the `Chat.fromMap()` factory and add the new fields with defaults for backward compatibility:

```dart
factory Chat.fromMap(Map<String, dynamic> map) {
  return Chat(
    id: map['id'] as String? ?? '',
    entries: List<ChatEntry>.from(
      (map['entries'] as List<dynamic>? ?? <String>[]).map(
        (dynamic x) => ChatEntry.fromJson(x as Map<String, dynamic>),
      ),
    ),
    avatar: Avatar.fromMap(
      map['avatar'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
    language: map['language'] as String? ?? 'en',
    systemPrompt: map['systemPrompt'] as String? ?? '',
    persona: ChatPersona.values.byName(map['persona'] as String? ?? 'normal'),
    // NEW FIELDS (with defaults for backward compatibility):
    title: map['title'] as String? ?? '',
    titleGenerated: map['titleGenerated'] as bool? ?? false,
  );
}
```

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/chat/domain/models/chat.dart
git commit -m "feat: add title and titleGenerated fields to Chat model"
```

---

## Task 4: Update ChatsState with Title Generation Tracking

**Files:**
- Modify: `lib/features/chat/bloc/chats_state.dart`

**Step 1: Add generatingTitleChatIds field to state**

Find the `ChatsState` freezed class and add the new field:

```dart
@freezed
sealed class ChatsState with _$ChatsState {
  const factory ChatsState({
    @Default(ChatsStatus.initial) ChatsStatus status,
    @Default(<Chat>[]) List<Chat> chatsList,
    @Default(null) Chat? currentChat,
    @Default(null) Chat? openedChat,
    @Default(null) String? errorMessage,
    @Default(false) bool chatCreated,
    @Default(false) bool functionCallingEnabled,
    @Default(<Map<String, dynamic>>[])
        List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(false) bool initializing,
    @Default(false) bool soundEffectsEnabled,
    @Default('fr') String currentLanguage,
    // NEW FIELD:
    @Default(<String>{}) Set<String> generatingTitleChatIds,
  }) = _ChatsState;
}
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/bloc/chats_state.dart
git commit -m "feat: add generatingTitleChatIds tracking to ChatsState"
```

---

## Task 5: Update SettingsState with Task LLM Config

**Files:**
- Modify: `lib/features/settings/bloc/settings_state.dart`

**Step 1: Add taskLlmConfig and availableLlmConfigs fields**

First, add the import at the top:

```dart
import '../../../core/models/task_llm_config.dart';
import '../../../core/models/llm_config.dart';
```

Then find the `SettingsState` freezed class and add the new fields:

```dart
@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    // ... existing fields ...
    // NEW FIELDS:
    @Default(null) TaskLlmConfig? taskLlmConfig,
    @Default(<LlmConfig>[]) List<LlmConfig> availableLlmConfigs,
  }) = _SettingsState;
}
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/settings/bloc/settings_state.dart
git commit -m "feat: add taskLlmConfig and availableLlmConfigs to SettingsState"
```

---

## Task 6: Update SettingsRepository Interface

**Files:**
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`

**Step 1: Add new methods to interface**

First, add the import:

```dart
import '../../../core/models/task_llm_config.dart';
```

Then add the new methods to the abstract class:

```dart
abstract class SettingsRepository {
  // ... existing methods ...

  // NEW METHODS:
  /// Get the task-specific LLM configuration
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig();

  /// Save the task-specific LLM configuration
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config);
}
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: Error about missing implementation in SettingsRepositoryImpl

**Step 3: Commit**

```bash
git add lib/features/settings/domain/repositories/settings_repository.dart
git commit -m "feat: add task LLM config methods to SettingsRepository interface"
```

---

## Task 7: Implement Task LLM Config in SettingsLocalDatasource

**Files:**
- Modify: `lib/features/settings/data/datasources/settings_local_datasource.dart`

**Step 1: Add import**

```dart
import '../../../../core/models/task_llm_config.dart';
```

**Step 2: Add key constant**

Add with other constants at the top of the class:

```dart
class SettingsLocalDatasource {
  static const String _keyUsername = 'username';
  static const String _keySoundEffects = 'sound_effects';
  static const String _keyLanguage = 'language';
  // NEW:
  static const String _keyTaskLlmConfig = 'task_llm_config';
```

**Step 3: Implement getTaskLlmConfig method**

```dart
Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString(_keyTaskLlmConfig);

    if (json == null) {
      return Right(TaskLlmConfig());
    }

    final Map<String, dynamic> data = jsonDecode(json);
    return Right(TaskLlmConfig.fromJson(data));
  } catch (e) {
    return Left(Exception('Failed to load task LLM config: $e'));
  }
}
```

**Step 4: Implement setTaskLlmConfig method**

```dart
Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String json = jsonEncode(config.toJson());
    await prefs.setString(_keyTaskLlmConfig, json);
    return const Right(null);
  } catch (e) {
    return Left(Exception('Failed to save task LLM config: $e'));
  }
}
```

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/settings/data/datasources/settings_local_datasource.dart
git commit -m "feat: implement task LLM config persistence in SettingsLocalDatasource"
```

---

## Task 8: Implement Task LLM Config in SettingsRepositoryImpl

**Files:**
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Step 1: Add import**

```dart
import '../../../../core/models/task_llm_config.dart';
```

**Step 2: Implement getTaskLlmConfig method**

```dart
@override
Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
  return await _localDatasource.getTaskLlmConfig();
}
```

**Step 3: Implement setTaskLlmConfig method**

```dart
@override
Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
  return await _localDatasource.setTaskLlmConfig(config);
}
```

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/settings/data/repositories/settings_repository_impl.dart
git commit -m "feat: implement task LLM config methods in SettingsRepositoryImpl"
```

---

## Task 9: Add Migration Logic to ChatRepositoryImpl

**Files:**
- Modify: `lib/features/chat/data/repositories/chat_repository_impl.dart`

**Step 1: Add migration key constant**

Add with other constants:

```dart
class ChatRepositoryImpl implements ChatRepository {
  static const String _chatsKey = 'chats';
  static const String _currentChatIdKey = 'current_chat_id';
  // NEW:
  static const String _chatMigrationKey = 'chat_title_migration_v1';
```

**Step 2: Update _chatToJson to include title fields**

Find the `_chatToJson` method (or similar serialization method) and add the new fields:

```dart
Map<String, dynamic> _chatToJson(Chat chat) {
  return <String, dynamic>{
    'id': chat.id,
    'entries': chat.entries.map((ChatEntry e) => e.toJson()).toList(),
    'avatar': chat.avatar.toMap(),
    'language': chat.language,
    'systemPrompt': chat.systemPrompt,
    'persona': chat.persona.name,
    // NEW FIELDS:
    'title': chat.title,
    'titleGenerated': chat.titleGenerated,
  };
}
```

**Step 3: Update _chatFromJson to include title fields with defaults**

Find the `_chatFromJson` method and add the new fields:

```dart
Chat _chatFromJson(Map<String, dynamic> json) {
  return Chat(
    id: json['id'] as String? ?? '',
    entries: List<ChatEntry>.from(
      (json['entries'] as List<dynamic>? ?? <dynamic>[]).map(
        (dynamic x) => ChatEntry.fromJson(x as Map<String, dynamic>),
      ),
    ),
    avatar: Avatar.fromMap(
      json['avatar'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
    language: json['language'] as String? ?? 'en',
    systemPrompt: json['systemPrompt'] as String? ?? '',
    persona: ChatPersona.values.byName(json['persona'] as String? ?? 'normal'),
    // NEW FIELDS (with defaults for backward compatibility):
    title: json['title'] as String? ?? '',
    titleGenerated: json['titleGenerated'] as bool? ?? false,
  );
}
```

**Step 4: Add migration method**

```dart
Future<void> _migrateChatDataIfNeeded() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool hasMigrated = prefs.getBool(_chatMigrationKey) ?? false;

    if (!hasMigrated) {
      AppLogger.info('Starting chat title migration', tag: 'ChatRepository');

      final Either<Exception, List<Chat>> chatsResult = await getChatsList();
      final List<Chat> chats = chatsResult.getOrElse(() => <Chat>[]);

      // Add title/titleGenerated fields to all existing chats
      for (final Chat chat in chats) {
        final Chat migratedChat = chat.copyWith(
          title: chat.title.isNotEmpty ? chat.title : '',
          titleGenerated: chat.titleGenerated,
        );
        await _updateChatInStorage(migratedChat);
      }

      await prefs.setBool(_chatMigrationKey, true);
      AppLogger.info('Chat title migration complete', tag: 'ChatRepository');
    }
  } catch (e) {
    AppLogger.error('Chat migration failed', tag: 'ChatRepository', error: e);
  }
}
```

**Step 5: Call migration in constructor or init**

Find the constructor or initialization method and add the migration call:

```dart
ChatRepositoryImpl({
  required SettingsLocalDatasource settingsDatasource,
}) : _settingsDatasource = settingsDatasource {
  _migrateChatDataIfNeeded();
}
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 7: Commit**

```bash
git add lib/features/chat/data/repositories/chat_repository_impl.dart
git commit -m "feat: add chat title migration and update serialization"
```

---

## Task 10: Update LlmServiceInterface

**Files:**
- Modify: `lib/core/services/llm/llm_service_interface.dart`

**Step 1: Add imports**

```dart
import '../../models/llm_config.dart';
import '../../models/llm_task_type.dart';
```

**Step 2: Add new abstract methods**

```dart
abstract class LlmServiceInterface {
  // ... existing methods ...

  // NEW METHODS:
  /// Get the LLM configuration for a specific task type
  /// Falls back to current/default config if task-specific config not found
  LlmConfig? getConfigForTask(LlmTaskType task);

  /// Generate a title for a chat based on the first user message
  /// Returns null if generation fails or no config is available
  Future<String?> generateTitle(String firstUserMessage, {LlmConfig? config});
}
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: Error about missing implementation in LlmService

**Step 4: Commit**

```bash
git add lib/core/services/llm/llm_service_interface.dart
git commit -m "feat: add task config and title generation methods to LlmServiceInterface"
```

---

## Task 11: Implement Task Config Methods in LlmService

**Files:**
- Modify: `lib/core/services/llm/llm_service.dart`

**Step 1: Add imports**

```dart
import '../../models/llm_task_type.dart';
import '../../models/task_llm_config.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../../../features/settings/data/datasources/settings_local_datasource.dart';
```

**Step 2: Add SettingsLocalDatasource dependency**

Find the class properties and add:

```dart
class LlmService implements LlmServiceInterface {
  // ... existing properties ...
  final SettingsLocalDatasource _settingsDatasource = SettingsLocalDatasource();
```

**Step 3: Implement _getTaskConfigFromSettings helper**

```dart
TaskLlmConfig _getTaskConfigFromSettings() {
  // Load from SettingsRepository via SharedPreferences
  try {
    final result = _settingsDatasource.getTaskLlmConfig();
    return result.getOrElse(() => TaskLlmConfig());
  } catch (e) {
    AppLogger.error('Failed to load task config', tag: 'LlmService', error: e);
    return TaskLlmConfig();
  }
}
```

**Step 4: Implement _getConfigIdForTask helper**

```dart
String? _getConfigIdForTask(LlmTaskType task, TaskLlmConfig config) {
  switch (task) {
    case LlmTaskType.assistant:
      return config.assistantLlmId;
    case LlmTaskType.titleGeneration:
      return config.titleGenerationLlmId;
    case LlmTaskType.functionCalling:
      return config.functionCallingLlmId;
  }
}
```

**Step 5: Implement getConfigForTask method**

```dart
@override
LlmConfig? getConfigForTask(LlmTaskType task) {
  try {
    final TaskLlmConfig taskConfig = _getTaskConfigFromSettings();
    final String? configId = _getConfigIdForTask(task, taskConfig);

    if (configId != null) {
      try {
        return _configs.firstWhere((c) => c.id == configId);
      } catch (e) {
        AppLogger.warning(
          'Task-specific LLM config not found: $configId',
          tag: 'LlmService',
          parameters: {'task': task.name},
        );
      }
    }

    // Fallback to current/default config
    final LlmConfig? defaultConfig = getCurrentConfig();
    if (defaultConfig == null) {
      AppLogger.error(
        'No LLM configuration available for task: ${task.name}',
        tag: 'LlmService',
      );
    }
    return defaultConfig;
  } catch (e) {
    AppLogger.error(
      'Failed to get config for task: ${task.name}',
      tag: 'LlmService',
      error: e,
    );
    return getCurrentConfig();
  }
}
```

**Step 6: Implement generateTitle method**

```dart
@override
Future<String?> generateTitle(String firstUserMessage, {LlmConfig? config}) async {
  try {
    final LlmConfig? activeConfig = config ?? getConfigForTask(LlmTaskType.titleGeneration);
    if (activeConfig == null) {
      AppLogger.error('No LLM config available for title generation', tag: 'LlmService');
      return null;
    }

    final List<LlmMessage> messages = <LlmMessage>[
      LlmMessage(
        role: LlmMessageRole.user,
        body: 'Generate a concise title (max 5 words) for this chat: $firstUserMessage',
      ),
    ];

    final String? result = await promptModel(
      messages: messages,
      systemPrompt: 'You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.',
      config: activeConfig,
      returnJson: false,
    );

    return result?.trim();
  } catch (e) {
    AppLogger.error('Title generation failed', tag: 'LlmService', error: e);
    return null;
  }
}
```

**Step 7: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 8: Commit**

```bash
git add lib/core/services/llm/llm_service.dart
git commit -m "feat: implement getConfigForTask and generateTitle in LlmService"
```

---

## Task 11: Add Task LLM Config Methods to SettingsCubit

**Files:**
- Modify: `lib/features/settings/bloc/settings_cubit.dart`

**Step 1: Add imports**

```dart
import '../../../core/models/task_llm_config.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/services/llm/llm_service_interface.dart';
```

**Step 2: Update constructor to include LlmService**

Find the constructor and add the parameter:

```dart
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required LlmServiceInterface llmService, // NEW
  })  : _settingsRepository = settingsRepository,
        _llmService = llmService, // NEW
        super(SettingsState.initial());

  final SettingsRepository _settingsRepository;
  final LlmServiceInterface _llmService; // NEW
```

**Step 3: Add loadTaskLlmConfig method**

```dart
Future<void> loadTaskLlmConfig() async {
  final result = await _settingsRepository.getTaskLlmConfig();
  result.fold(
    (error) {
      AppLogger.error('Failed to load task LLM config', tag: 'SettingsCubit', error: error);
      emit(state.copyWith(taskLlmConfig: TaskLlmConfig()));
    },
    (config) => emit(state.copyWith(taskLlmConfig: config)),
  );
}
```

**Step 4: Add setTaskLlmConfig method**

```dart
Future<void> setTaskLlmConfig(TaskLlmConfig config) async {
  final result = await _settingsRepository.setTaskLlmConfig(config);
  result.fold(
    (error) => AppLogger.error('Failed to save task LLM config', tag: 'SettingsCubit', error: error),
    (_) => emit(state.copyWith(taskLlmConfig: config)),
  );
}
```

**Step 5: Update loadSettings to call loadTaskLlmConfig**

Find the `loadSettings()` method and add the call at the end:

```dart
@override
Future<void> loadSettings() async {
  // ... existing load logic ...

  // Load task LLM config
  await loadTaskLlmConfig();

  // Load available LLM configs
  try {
    final configs = _llmService.getAllConfigs();
    emit(state.copyWith(availableLlmConfigs: configs));
  } catch (e) {
    AppLogger.error('Failed to load available LLM configs', tag: 'SettingsCubit', error: e);
  }
}
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: Error in DI (ChatsCubit needs LlmService)

**Step 7: Commit**

```bash
git add lib/features/settings/bloc/settings_cubit.dart
git commit -m "feat: add task LLM config methods to SettingsCubit"
```

---

## Task 12: Update DI Configuration

**Files:**
- Modify: `lib/core/di/injection.dart`

**Step 1: Update ChatsCubit registration to include LlmService**

Find the ChatsCubit registration and update:

```dart
// ChatsCubit - no LlmService needed for now (using static instantiation)
getIt.registerFactory(() => ChatsCubit(
  chatRepository: getIt<ChatRepository>(),
  settingsRepository: getIt<SettingsRepository>(),
  localizationManager: getIt<LocalizationManager>(),
  ttsQueueManager: getIt<TtsQueueManager?>(),
));
```

**Step 2: Update SettingsCubit registration to include LlmService**

Find the SettingsCubit registration and update:

```dart
// SettingsCubit
getIt.registerFactory(() => SettingsCubit(
  settingsRepository: getIt<SettingsRepository>(),
  llmService: getIt<LlmServiceInterface>(),
));
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/di/injection.dart
git commit -m "feat: update DI for task LLM config support"
```

---

## Task 13: Add Title Generation Helper Methods to ChatsCubit

**Files:**
- Modify: `lib/features/chat/bloc/chats_cubit.dart`

**Step 1: Add LlmService property**

Find the class properties and add:

```dart
class ChatsCubit extends EmittingCubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LocalizationManager localizationManager,
    TtsQueueManager? ttsQueueManager,
  })  : _chatRepository = chatRepository,
        _settingsRepository = settingsRepository,
        _localizationManager = localizationManager,
        _ttsQueueManager = ttsQueueManager,
        _llmService = LlmService(), // NEW
        super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final LocalizationManager _localizationManager;
  final TtsQueueManager? _ttsQueueManager;
  final LlmService _llmService; // NEW
```

**Step 2: Add _getChatById helper**

```dart
Chat? _getChatById(String chatId) {
  try {
    return state.chatsList.firstWhere((chat) => chat.id == chatId);
  } catch (_) {
    return state.currentChat.id == chatId ? state.currentChat : null;
  }
}
```

**Step 3: Add _getFirstUserMessage helper**

```dart
String? _getFirstUserMessage(Chat chat) {
  try {
    return chat.entries
        .where((e) => e.entryType == EntryType.user)
        .firstOrNull
        ?.body
        .getVisiblePrompt();
  } catch (e) {
    AppLogger.error('Failed to extract first user message', tag: 'ChatsCubit', error: e);
    return null;
  }
}
```

**Step 4: Add _sanitizeTitle helper**

```dart
String _sanitizeTitle(String title) {
  // Remove excessive whitespace
  String sanitized = title.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Remove any quotes the LLM might have added
  sanitized = sanitized.replaceAll(RegExp(r'^["\']|["\']$'), '');

  // Truncate if still too long
  if (sanitized.length > 50) {
    sanitized = '${sanitized.substring(0, 47)}...';
  }

  return sanitized;
}
```

**Step 5: Add _updateChatInState helper**

```dart
void _updateChatInState(Chat updatedChat) {
  final List<Chat> updatedChatsList = state.chatsList.map((chat) {
    return chat.id == updatedChat.id ? updatedChat : chat;
  }).toList();

  final Chat? current = state.currentChat.id == updatedChat.id
      ? updatedChat
      : state.currentChat;
  final Chat? opened = state.openedChat?.id == updatedChat.id
      ? updatedChat
      : state.openedChat;

  emit(state.copyWith(
    chatsList: updatedChatsList,
    currentChat: current,
    openedChat: opened,
  ));
}
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 7: Commit**

```bash
git add lib/features/chat/bloc/chats_cubit.dart
git commit -m "feat: add title generation helper methods to ChatsCubit"
```

---

## Task 14: Implement generateTitleForChat in ChatsCubit

**Files:**
- Modify: `lib/features/chat/bloc/chats_cubit.dart`

**Step 1: Implement generateTitleForChat method**

```dart
Future<void> generateTitleForChat(String chatId) async {
  final Chat? chat = _getChatById(chatId);
  if (chat == null || chat.titleGenerated || chat.entries.isEmpty) return;

  // Prevent duplicate generation attempts
  final bool isAlreadyGenerating = state.generatingTitleChatIds.contains(chatId);
  if (isAlreadyGenerating) return;

  // Add to generating set
  final Set<String> newGeneratingIds = {...state.generatingTitleChatIds, chatId};
  emit(state.copyWith(generatingTitleChatIds: newGeneratingIds));

  try {
    final String? firstUserMessage = _getFirstUserMessage(chat);
    if (firstUserMessage == null || firstUserMessage.isEmpty) return;

    final String? title = await _llmService.generateTitle(firstUserMessage);

    if (title != null && title.isNotEmpty && title.length <= 100) {
      final String sanitizedTitle = _sanitizeTitle(title);

      final Chat updatedChat = chat.copyWith(
        title: sanitizedTitle,
        titleGenerated: true,
      );

      await _chatRepository.updateChat(id: chatId, updatedChat: updatedChat);
      _updateChatInState(updatedChat);

      AppLogger.info(
        'Title generated for chat $chatId: $sanitizedTitle',
        tag: 'ChatsCubit',
      );
    } else {
      AppLogger.warning(
        'Generated title was invalid or too long',
        tag: 'ChatsCubit',
        parameters: {'title': title, 'length': title?.length},
      );
    }
  } catch (e) {
    AppLogger.error(
      'Failed to generate title for chat $chatId',
      tag: 'ChatsCubit',
      error: e,
    );
  } finally {
    // Remove from generating set
    final Set<String> updatedIds = state.generatingTitleChatIds.toSet()
      ..remove(chatId);
    emit(state.copyWith(generatingTitleChatIds: updatedIds));
  }
}
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/bloc/chats_cubit.dart
git commit -m "feat: implement generateTitleForChat in ChatsCubit"
```

---

## Task 15: Add Title Generation Trigger to askYofardev

**Files:**
- Modify: `lib/features/chat/bloc/chats_cubit.dart`

**Step 1: Add _triggerTitleGenerationIfNeeded helper**

```dart
void _triggerTitleGenerationIfNeeded(Chat chat) {
  final bool hasOnlyOneUserMessage = chat.entries
      .where((e) => e.entryType == EntryType.user)
      .length == 1;

  if (hasOnlyOneUserMessage && !chat.titleGenerated) {
    // Fire and forget - don't await
    generateTitleForChat(chat.id);
  }
}
```

**Step 2: Update askYofardev to trigger title generation**

Find the success case in `askYofardev` (where `result.fold` handles the Right case) and add the trigger:

```dart
Future<ChatEntry?> askYofardev(
  String prompt, {
  required bool onlyText,
  String? attachedImage,
  required Avatar avatar,
}) async {
  // ... existing code ...

  return result.fold(
    (Exception error) {
      // ... error handling ...
      return null;
    },
    (List<ChatEntry> newEntries) {
      final List<ChatEntry> entries = <ChatEntry>[
        ...chat.entries,
        ...newEntries,
      ];
      chat = chat.copyWith(entries: entries);
      emit(
        state.copyWith(
          openedChat: onlyText ? chat : state.openedChat,
          currentChat: onlyText ? state.currentChat : chat,
          status: ChatsStatus.success,
        ),
      );

      // Update chat with new entries
      _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      // NEW: Trigger title generation after first user message
      _triggerTitleGenerationIfNeeded(chat);

      // Return the last entry (which should be the actual response)
      return newEntries.isNotEmpty ? newEntries.last : null;
    },
  );
}
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/chat/bloc/chats_cubit.dart
git commit -m "feat: trigger title generation after first user message"
```

---

## Task 16: Update ChatListContainer to Use Generated Titles

**Files:**
- Modify: `lib/features/chat/widgets/chat_list_container.dart`

**Step 1: Update _resolvePreview method**

Find the `_resolvePreview` method and update it:

```dart
String _resolvePreview(Chat chat) {
  if (chat.entries.isEmpty) return localized.empty;

  // NEW: Use title if available and generated
  if (chat.titleGenerated && chat.title.isNotEmpty) {
    return chat.title;
  }

  // Fall back to existing preview logic
  for (int i = chat.entries.length - 1; i >= 0; i--) {
    final String body = chat.entries[i].body;
    if (body.trim().isEmpty) continue;
    try {
      final String visible = body.getVisiblePrompt();
      if (visible.trim().isNotEmpty) {
        // NEW: Truncate first message for temporary title
        return visible.length > 50 ? '${visible.substring(0, 47)}...' : visible;
      }
    } catch (_) {
      final String raw = body.trim();
      if (raw.isNotEmpty) return raw;
    }
  }
  return localized.empty;
}
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/widgets/chat_list_container.dart
git commit -m "feat: use generated titles in chat list"
```

---

## Task 17: Create TaskLlmConfigPage Widget

**Files:**
- Create: `lib/features/settings/screens/llm/task_llm_config_page.dart`

**Step 1: Create the settings page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/res/app_colors.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../../chat/bloc/chats_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';
import '../../widgets/glassmorphic/glass_container.dart';
import '../../widgets/settings_app_bar.dart';

/// Settings page for configuring task-specific LLM mappings
class TaskLlmConfigPage extends StatefulWidget {
  const TaskLlmConfigPage({super.key});

  @override
  State<TaskLlmConfigPage> createState() => _TaskLlmConfigPageState();
}

class _TaskLlmConfigPageState extends State<TaskLlmConfigPage> {
  @override
  void initState() {
    super.initState();
    // Load configs on page load
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final TaskLlmConfig taskConfig = state.taskLlmConfig ?? TaskLlmConfig();
        final List<LlmConfig> availableConfigs = state.availableLlmConfigs;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const SettingsAppBar(
            title: 'Task LLM Configuration',
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTaskDropdown(
                label: 'Assistant',
                description: 'LLM used for main chat responses',
                currentId: taskConfig.assistantLlmId,
                availableConfigs: availableConfigs,
                onChanged: (id) => _updateTaskConfig(
                  taskConfig.copyWith(assistantLlmId: id),
                ),
              ),

              const SizedBox(height: 16),

              _buildTaskDropdown(
                label: 'Title Generation',
                description: 'LLM used to generate chat titles',
                currentId: taskConfig.titleGenerationLlmId,
                availableConfigs: availableConfigs,
                onChanged: (id) => _updateTaskConfig(
                  taskConfig.copyWith(titleGenerationLlmId: id),
                ),
              ),

              const SizedBox(height: 16),

              _buildTaskDropdown(
                label: 'Function Calling',
                description: 'LLM used for tool/function detection',
                currentId: taskConfig.functionCallingLlmId,
                availableConfigs: availableConfigs,
                onChanged: (id) => _updateTaskConfig(
                  taskConfig.copyWith(functionCallingLlmId: id),
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Note: If no LLM is selected for a task, the default assistant LLM will be used.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskDropdown({
    required String label,
    required String description,
    required String? currentId,
    required List<LlmConfig> availableConfigs,
    required ValueChanged<String?> onChanged,
  }) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: currentId,
            decoration: InputDecoration(
              hintText: 'Use default LLM',
              filled: true,
              fillColor: AppColors.glassSurface.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            dropdownColor: AppColors.glassSurface,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Use default LLM',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ),
              ...availableConfigs.map((config) {
                return DropdownMenuItem<String>(
                  value: config.id,
                  child: Text(
                    config.name,
                    style: TextStyle(color: AppColors.onSurface),
                  ),
                );
              }),
            ],
            onChanged: onChanged,
            iconEnabledColor: AppColors.primary,
            style: TextStyle(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  void _updateTaskConfig(TaskLlmConfig config) {
    context.read<SettingsCubit>().setTaskLlmConfig(config);
  }
}
```

**Step 2: Check if GlassContainer exists or use alternative**

If `GlassContainer` doesn't exist, replace with:

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AppColors.glassSurface.withValues(alpha: 0.12),
        AppColors.glassSurface.withValues(alpha: 0.06),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.glassBorder.withValues(alpha: 0.3),
      width: 1.5,
    ),
  ),
  padding: const EdgeInsets.all(16),
  child: Column(...),
)
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/settings/screens/llm/task_llm_config_page.dart
git commit -m "feat: add TaskLlmConfigPage settings UI"
```

---

## Task 18: Add Route for TaskLlmConfigPage

**Files:**
- Modify: `lib/core/router/app_router.dart` (or equivalent router file)

**Step 1: Add import**

```dart
import '../../features/settings/screens/llm/task_llm_config_page.dart';
```

**Step 2: Add route**

Find the settings routes section and add:

```dart
GoRoute(
  path: '/settings/task-llm',
  parent: RouteConstants.settings,
  builder: (_, __) => const TaskLlmConfigPage(),
),
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: add route for TaskLlmConfigPage"
```

---

## Task 19: Add Localization Strings

**Files:**
- Modify: `lib/l10n/language_en.dart`
- Modify: `lib/l10n/language_fr.dart`

**Step 1: Add to English localization**

```dart
static const Map<String, String> en = {
  // ... existing strings ...
  'newChat': 'New chat',
  'taskLlmConfig': 'Task LLM Configuration',
  'assistantTask': 'Assistant',
  'titleTask': 'Title Generation',
  'functionCallingTask': 'Function Calling',
  'useDefaultLlm': 'Use default LLM',
  'taskLlmNote': 'Note: If no LLM is selected for a task, the default assistant LLM will be used.',
  'taskLlmDescription': 'LLM used for main chat responses',
  'titleLlmDescription': 'LLM used to generate chat titles',
  'functionCallingLlmDescription': 'LLM used for tool/function detection',
};
```

**Step 2: Add to French localization**

```dart
static const Map<String, String> fr = {
  // ... existing strings ...
  'newChat': 'Nouvelle conversation',
  'taskLlmConfig': 'Configuration LLM par tâche',
  'assistantTask': 'Assistant',
  'titleTask': 'Génération de titre',
  'functionCallingTask': 'Appel de fonctions',
  'useDefaultLlm': 'Utiliser le LLM par défaut',
  'taskLlmNote': 'Note: Si aucun LLM n\'est sélectionné pour une tâche, le LLM assistant par défaut sera utilisé.',
  'taskLlmDescription': 'LLM utilisé pour les réponses principales du chat',
  'titleLlmDescription': 'LLM utilisé pour générer les titres des conversations',
  'functionCallingLlmDescription': 'LLM utilisé pour la détection d\'outils/fonctions',
};
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/l10n/language_en.dart lib/l10n/language_fr.dart
git commit -m "feat: add localization strings for task LLM config"
```

---

## Task 20: Initialize Task LLM Config on App Start

**Files:**
- Modify: `lib/main.dart` (or app initialization file)

**Step 1: Find initialization code**

Look for where SettingsCubit is initialized or where initial settings are loaded.

**Step 2: Add task LLM config loading**

```dart
// Load task LLM config on app start
final settingsCubit = getIt<SettingsCubit>();
await settingsCubit.loadTaskLlmConfig();
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: load task LLM config on app initialization"
```

---

## Task 21: Add Integration Test for Title Generation

**Files:**
- Create: `test_integration/features/chat/title_generation_test.dart`

**Step 1: Create integration test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/features/chat/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chats_state.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/l10n/localization_manager.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';

class MockChatRepository extends Mock implements ChatRepository {}
class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockLocalizationManager extends Mock implements LocalizationManager {}
class MockLlmService extends Mock implements LlmService {}

void main() {
  late ChatRepository mockChatRepository;
  late SettingsRepository mockSettingsRepository;
  late LocalizationManager mockLocalizationManager;
  late LlmService mockLlmService;
  late ChatsCubit cubit;

  setUp(() {
    mockChatRepository = MockChatRepository();
    mockSettingsRepository = MockSettingsRepository();
    mockLocalizationManager = MockLocalizationManager();
    mockLlmService = MockLlmService();

    // Setup default mock behaviors
    when(() => mockLocalizationManager.initialize(any()))
        .thenAnswer((_) async {});
    when(() => mockSettingsRepository.getLanguage())
        .thenAnswer((_) async => Right('en'));
    when(() => mockSettingsRepository.getSoundEffects())
        .thenAnswer((_) async => Right(true));
  });

  group('Title Generation', () {
    test('should trigger title generation after first user message', () async {
      // Arrange
      final Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'user-entry',
            entryType: EntryType.user,
            body: 'What is the weather today?',
            timestamp: DateTime.now(),
          ),
        ],
        title: '',
        titleGenerated: false,
      );

      when(() => mockChatRepository.getCurrentChat())
          .thenAnswer((_) async => Right(testChat));
      when(() => mockChatRepository.updateChat(
        id: any(named: 'id'),
        updatedChat: any(named: 'updatedChat'),
      )).thenAnswer((_) async => Right(null));

      when(() => mockLlmService.generateTitle(any()))
          .thenAnswer((_) async => 'Weather Inquiry');

      // Act
      cubit = ChatsCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        localizationManager: mockLocalizationManager,
      );
      await cubit.getCurrentChat();

      // Need to trigger title generation manually for testing
      await cubit.generateTitleForChat(testChat.id);

      // Assert - wait for async title generation
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final ChatsState state = cubit.state;
      expect(state.currentChat?.titleGenerated, isTrue);
      expect(state.currentChat?.title, contains('Weather'));
    });

    test('should not generate title if already generated', () async {
      // Arrange
      final Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'user-entry',
            entryType: EntryType.user,
            body: 'What is the weather today?',
            timestamp: DateTime.now(),
          ),
        ],
        title: 'Weather Inquiry',
        titleGenerated: true,
      );

      when(() => mockChatRepository.getCurrentChat())
          .thenAnswer((_) async => Right(testChat));

      // Act
      cubit = ChatsCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        localizationManager: mockLocalizationManager,
      );
      await cubit.getCurrentChat();
      await cubit.generateTitleForChat(testChat.id);

      // Assert
      verifyNever(() => mockLlmService.generateTitle(any()));
    });
  });
}
```

**Step 2: Run test**

```bash
flutter test test_integration/features/chat/title_generation_test.dart
```

Expected: May fail initially due to setup issues, adjust as needed

**Step 3: Commit**

```bash
git add test_integration/features/chat/title_generation_test.dart
git commit -m "test: add integration test for title generation"
```

---

## Task 22: Add Unit Test for Title Sanitization

**Files:**
- Create: `test/features/chat/bloc/title_sanitization_test.dart`

**Step 1: Create unit test**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Title Sanitization', () {
    String sanitizeTitle(String title) {
      // Copy of the implementation for testing
      String sanitized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
      sanitized = sanitized.replaceAll(RegExp(r'^["\']|["\']$'), '');
      if (sanitized.length > 50) {
        sanitized = '${sanitized.substring(0, 47)}...';
      }
      return sanitized;
    }

    test('removes excessive whitespace', () {
      expect(sanitizeTitle('Hello    World'), 'Hello World');
    });

    test('removes leading and trailing quotes', () {
      expect(sanitizeTitle('"Weather Today"'), 'Weather Today');
      expect(sanitizeTitle("'Weather Today'"), 'Weather Today');
    });

    test('truncates long titles', () {
      final longTitle = 'This is a very long title that exceeds the maximum length allowed for chat titles in the application';
      final result = sanitizeTitle(longTitle);
      expect(result.length, lessThanOrEqualTo(50));
      expect(result, endsWith('...'));
    });

    test('handles empty string', () {
      expect(sanitizeTitle(''), '');
    });

    test('handles string with only whitespace', () {
      expect(sanitizeTitle('     '), '');
    });
  });
}
```

**Step 2: Run test**

```bash
flutter test test/features/chat/bloc/title_sanitization_test.dart
```

Expected: PASS

**Step 3: Commit**

```bash
git add test/features/chat/bloc/title_sanitization_test.dart
git commit -m "test: add unit tests for title sanitization"
```

---

## Task 23: Manual Testing Checklist

Create a test plan document:

**Files:**
- Create: `docs/testing/llm-titles-checklist.md`

**Step 1: Create test checklist**

```markdown
# LLM-Generated Titles & Task Config Testing Checklist

## Title Generation Tests

- [ ] Create new chat
- [ ] Send first message
- [ ] Verify temporary title shows in chat list (first 50 chars of message)
- [ ] Wait for AI response to complete
- [ ] Verify title updates to AI-generated title
- [ ] Refresh app and verify title persists

### Edge Cases
- [ ] Send empty first message - should not crash
- [ ] Send very long first message - temporary title should be truncated
- [ ] Send special characters in first message - title should be sanitized
- [ ] Delete chat while title is generating - should not crash

## Task LLM Config Tests

- [ ] Navigate to Settings > Task LLM Configuration
- [ ] Verify all three task types show dropdowns
- [ ] Verify "Use default LLM" option is available
- [ ] Verify all configured LLMs appear in dropdowns
- [ ] Select different LLM for Assistant task
- [ ] Select different LLM for Title Generation task
- [ ] Select different LLM for Function Calling task
- [ ] Create new chat and verify title uses title-specific LLM
- [ ] Send function-calling message and verify it uses function-specific LLM
- [ ] Restart app and verify task config persists

## Migration Tests

- [ ] Install app version before this feature
- [ ] Update to new version
- [ ] Verify existing chats have empty title and titleGenerated: false
- [ ] Create new chat and verify title generation works
- [ ] Verify migration only runs once

## UI Tests

- [ ] Verify generated titles display correctly in chat list
- [ ] Verify temporary titles display before generation
- [ ] Verify settings page is responsive
- [ ] Verify glassmorphic styling matches app design
- [ ] Verify all text is properly localized (EN/FR)
```

**Step 2: Commit**

```bash
git add docs/testing/llm-titles-checklist.md
git commit -m "docs: add manual testing checklist for LLM titles feature"
```

---

## Task 24: Final Build and Verify

**Step 1: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 2: Run all tests**

```bash
flutter test
```

Expected: All tests pass

**Step 3: Build for release (optional)**

```bash
flutter build apk --release
# or for iOS
flutter build ios --release
```

**Step 4: Final commit**

```bash
git add .
git commit -m "feat: complete LLM-generated titles and task-specific LLM configuration

Features:
- Auto-generate chat titles using LLM after first user message
- Configure different LLMs for assistant, title generation, and function calling
- Non-blocking title generation with temporary titles
- Task config persistence in settings
- Migration support for existing chat data
- Settings UI for task-to-LLM mapping

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Notes for Implementation

### Dependencies
- freezed (already installed)
- fpdart (already installed)
- SharedPreferences (already installed)
- get_it (already installed)
- flutter_bloc (already installed)

### Key Design Decisions
1. **Non-blocking title generation**: Fire-and-forget pattern after first user message
2. **Temporary titles**: First 50 chars of first user message
3. **Fallback chain**: Task-specific → Default → Silent failure
4. **Migration**: One-time migration to add title fields to existing chats
5. **Duplicate prevention**: Track generating chats with Set<String> in state

### Testing Strategy
- Unit tests for title sanitization
- Integration tests for title generation flow
- Manual testing checklist for UI verification
- Migration test for backward compatibility
