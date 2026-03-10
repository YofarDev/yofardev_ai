# Flutter Architecture Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Incrementally refactor a Flutter chat application to eliminate cubit-to-cubit dependencies and consolidate 7 chat cubits into 2, following clean architecture principles.

**Architecture:** The application uses Flutter BLoC pattern with cubits. Currently has tight cubit-to-cubit coupling. Goal is to introduce domain services for coordination and consolidate redundant cubits. Each phase must be independently deployable - the app must compile and run after every task.

**Tech Stack:** Flutter, flutter_bloc, get_it (DI), freezed (immutable states), fpdart (Either for error handling)

**Context:** This is a continuation of an architecture migration. Phases 1-2 (DI integrity and breaking cubit dependencies) are complete. This plan covers Phases 3-5 (cubit consolidation, layer cleanup, presentation polish).

**Critical Rules:**
- ⚠️ **Run `flutter analyze` after EVERY change** - if it fails, the task is incomplete
- ⚠️ **Run relevant tests after every change** - tests must pass before committing
- ⚠️ **Commit after each task** - small, atomic commits only
- ⚠️ **One file changed per task when possible** - minimize blast radius
- ⚠️ **Never change behavior** - refactoring only, no functional changes
- ⚠️ **Read files before editing** - understand current state before changing

---

## Phase 3a: Merge ChatTitleCubit into ChatsCubit

**Goal:** Absorb title generation state into ChatsCubit, eliminating a separate cubit.

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart`
- Modify: `lib/features/chat/presentation/bloc/chat_title_state.dart` (will be deleted later)
- Modify: `lib/core/di/service_locator.dart`
- Modify: `lib/features/chat/presentation/bloc/chat_streaming_cubit.dart`
- Test: `test/integration/features/chat/title_generation_test.dart`

### Task 1: Add title generation state to ChatsState

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart`
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart` (freezed file)
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`

**Step 1: Read current ChatTitleState**

Read file to understand what state needs to be merged:

```bash
cat lib/features/chat/presentation/bloc/chat_title_state.dart
```

Expected: State contains `generatingChatIds` (Set<String>) and `lastGeneratedTitle` (TitleResult?)

**Step 2: Add title generation fields to ChatsState**

Edit `lib/features/chat/presentation/bloc/chats_state.dart`:

Add to ChatsState class (around line 50-60, after existing fields):

```dart
/// Set of chat IDs currently generating titles
final Set<String> generatingChatIds;

/// Result of the most recent title generation
final TitleResult? lastGeneratedTitle;
```

**Step 3: Update freezed ChatsState constructor**

Edit `lib/features/chat/presentation/bloc/chats_state.dart` freezed section:

Add to constructor parameters (after existing fields):

```dart
const ChatsState({
  required this.status,
  required this.currentLanguage,
  required this.soundEffectsEnabled,
  required this.currentChat,
  required this.openedChat,
  required this.initializing,
  this.generatingChatIds = const <String>{},
  this.lastGeneratedTitle,
}) ;
```

**Step 4: Update copyWith method**

Add to copyWith method in freezed annotation:

```dart
$ChatsStateCopyWith<Set<String>> get generatingChatIds;
$ChatsStateCopyWith<TitleResult?> get lastGeneratedTitle;
```

**Step 5: Update ChatsState.initial() factory**

Update initial factory to include new fields:

```dart
const factory ChatsState.initial() = ChatsInitialState;

class ChatsInitialState extends ChatsState {
  const ChatsInitialState()
      : generatingChatIds = const <String>{},
        lastGeneratedTitle = null;
        // ... keep existing fields
}
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 7: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_state.dart
git commit -m "refactor(phase3a): add title generation state fields to ChatsState"
```

---

### Task 2: Move title generation methods to ChatsCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`

**Step 1: Read ChatTitleCubit implementation**

```bash
cat lib/features/chat/presentation/bloc/chat_title_cubit.dart
```

Expected: Understanding of generateTitle() and shouldGenerateTitle() methods

**Step 2: Add ChatTitleService dependency to ChatsCubit**

Edit `lib/features/chat/presentation/bloc/chats_cubit.dart`:

Add to imports (around line 21):

```dart
import '../../domain/services/chat_title_service.dart';
```

Add to constructor parameters (around line 17-20):

```dart
ChatsCubit({
  required ChatRepository chatRepository,
  required SettingsRepository settingsRepository,
  required AvatarAnimationService avatarAnimationService,
  required ChatTitleService chatTitleService,
}) : _chatRepository = chatRepository,
     _settingsRepository = settingsRepository,
     _avatarAnimationService = avatarAnimationService,
     _chatTitleService = chatTitleService,
     super(ChatsState.initial());
```

Add field declaration (around line 26-28):

```dart
final ChatRepository _chatRepository;
final SettingsRepository _settingsRepository;
final AvatarAnimationService _avatarAnimationService;
final ChatTitleService _chatTitleService;
```

**Step 3: Add generateTitle method to ChatsCubit**

Add method to ChatsCubit class (after existing methods, around line 100+):

```dart
/// Generate a title for a chat based on its first user message
Future<void> generateTitle(String chatId, Chat chat) async {
  // Prevent duplicate generation attempts
  if (state.generatingChatIds.contains(chatId)) {
    AppLogger.debug(
      'Already generating title for chat $chatId, skipping',
      tag: 'ChatsCubit',
    );
    return;
  }

  // Add to generating set
  emit(
    state.copyWith(
      generatingChatIds: <String>{...state.generatingChatIds, chatId},
    ),
  );

  try {
    final String? title = await _chatTitleService.generateTitle(chatId, chat);

    if (title != null) {
      emit(
        state.copyWith(
          lastGeneratedTitle: TitleResult(
            chatId: chatId,
            title: title,
          ),
        ),
      );
    }
  } finally {
    // Remove from generating set
    final Set<String> updatedIds = state.generatingChatIds.toSet()
      ..remove(chatId);
    emit(state.copyWith(generatingChatIds: updatedIds));
  }
}
```

**Step 4: Add shouldGenerateTitle method to ChatsCubit**

```dart
/// Check if title generation should be triggered for a chat
bool shouldGenerateTitle(Chat chat) {
  return _chatTitleService.shouldGenerateTitle(chat);
}
```

**Step 5: Add TitleResult import**

Add to imports at top of file:

```dart
import 'chat_title_state.dart'; // For TitleResult class
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 7: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_cubit.dart
git commit -m "refactor(phase3a): add title generation methods to ChatsCubit"
```

---

### Task 3: Update ChatStreamingCubit to use ChatsCubit for title generation

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_streaming_cubit.dart`

**Step 1: Find title generation calls in ChatStreamingCubit**

```bash
grep -n "chatTitleService" lib/features/chat/presentation/bloc/chat_streaming_cubit.dart
```

Expected: Two locations where titles are generated (after function calls, after streaming)

**Step 2: Replace ChatTitleService with ChatsCubit for title generation**

Edit `lib/features/chat/presentation/bloc/chat_streaming_cubit.dart`:

Change constructor parameter (around line 33-43):

FROM:
```dart
ChatStreamingCubit({
  required ChatRepository chatRepository,
  required SettingsRepository settingsRepository,
  required LlmServiceInterface llmService,
  required StreamProcessorService streamProcessor,
  required PromptDatasource promptDatasource,
  required InterruptionService interruptionService,
  required ChatEntryService chatEntryService,
  required ChatTitleService chatTitleService,
  TtsQueueManager? ttsQueueManager,
})
```

TO:
```dart
ChatStreamingCubit({
  required ChatRepository chatRepository,
  required SettingsRepository settingsRepository,
  required LlmServiceInterface llmService,
  required StreamProcessorService streamProcessor,
  required PromptDatasource promptDatasource,
  required InterruptionService interruptionService,
  required ChatEntryService chatEntryService,
  required ChatsCubit chatsCubit,
  TtsQueueManager? ttsQueueManager,
})
```

Change field declaration (around line 70-77):

FROM:
```dart
final ChatTitleService _chatTitleService;
```

TO:
```dart
final ChatsCubit _chatsCubit;
```

**Step 3: Update title generation calls**

Find and replace (around line 223-226):

FROM:
```dart
if (_chatTitleService.shouldGenerateTitle(chat)) {
  _chatTitleService.generateTitle(chat.id, chat);
}
```

TO:
```dart
if (_chatsCubit.shouldGenerateTitle(chat)) {
  _chatsCubit.generateTitle(chat.id, chat);
}
```

Repeat for second location (around line 346-349).

**Step 4: Update imports**

Remove:
```dart
import '../../domain/services/chat_title_service.dart';
```

Add:
```dart
import 'chats_cubit.dart';
```

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 6: Commit**

```bash
git add lib/features/chat/presentation/bloc/chat_streaming_cubit.dart
git commit -m "refactor(phase3a): use ChatsCubit for title generation instead of service"
```

---

### Task 4: Update service_locator registration

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Find ChatsCubit registration**

```bash
grep -n "registerFactory<ChatsCubit>" lib/core/di/service_locator.dart
```

Expected: Found around line 195-201

**Step 2: Add ChatTitleService dependency to ChatsCubit registration**

Edit registration (around line 195-201):

FROM:
```dart
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    avatarAnimationService: getIt<AvatarAnimationService>(),
  ),
);
```

TO:
```dart
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    avatarAnimationService: getIt<AvatarAnimationService>(),
    chatTitleService: getIt<ChatTitleService>(),
  ),
);
```

**Step 3: Update ChatStreamingCubit registration**

Find ChatStreamingCubit registration and update (around line 239-251):

FROM:
```dart
getIt.registerFactory<ChatStreamingCubit>(
  () => ChatStreamingCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    llmService: getIt<LlmServiceInterface>(),
    streamProcessor: getIt<StreamProcessorService>(),
    promptDatasource: getIt<PromptDatasource>(),
    interruptionService: getIt<InterruptionService>(),
    chatEntryService: getIt<ChatEntryService>(),
    chatTitleService: getIt<ChatTitleService>(),
    ttsQueueManager: getIt<TtsQueueManager>(),
  ),
);
```

TO:
```dart
getIt.registerFactory<ChatStreamingCubit>(
  () => ChatStreamingCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    llmService: getIt<LlmServiceInterface>(),
    streamProcessor: getIt<StreamProcessorService>(),
    promptDatasource: getIt<PromptDatasource>(),
    interruptionService: getIt<InterruptionService>(),
    chatEntryService: getIt<ChatEntryService>(),
    chatsCubit: getIt<ChatsCubit>(),
    ttsQueueManager: getIt<TtsQueueManager>(),
  ),
);
```

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 5: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "refactor(phase3a): update DI registrations for ChatsCubit with title generation"
```

---

### Task 5: Update tests to use ChatsCubit directly

**Files:**
- Modify: `test/integration/features/chat/title_generation_test.dart`

**Step 1: Read test file**

```bash
cat test/integration/features/chat/title_generation_test.dart
```

**Step 2: Update test to use ChatsCubit instead of ChatTitleCubit**

Edit imports (around line 1-9):

FROM:
```dart
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_title_cubit.dart';
```

TO:
```dart
import 'package:yofardev_ai/features/chat/presentation/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chats_state.dart';
import 'package:mocktail/mocktail.dart';
```

Add mock after existing mocks (after line 80):

```dart
class MockAvatarAnimationService extends Mock implements AvatarAnimationService {}
```

**Step 3: Update test setup**

Edit setUp method (around line 97-103):

FROM:
```dart
setUp(() {
  mockChatRepository = TrackingMockChatRepository();
  mockLlmService = MockLlmService();
  final ChatTitleService chatTitleService = ChatTitleService(
    chatRepository: mockChatRepository,
    llmService: mockLlmService,
  );
  cubit = ChatTitleCubit(
    chatTitleService: chatTitleService,
  );
});
```

TO:
```dart
setUp(() {
  mockChatRepository = TrackingMockChatRepository();
  mockLlmService = MockLlmService();
  final ChatTitleService chatTitleService = ChatTitleService(
    chatRepository: mockChatRepository,
    llmService: mockLlmService,
  );
  final MockAvatarAnimationService mockAvatarAnimationService =
      MockAvatarAnimationService();
  cubit = ChatsCubit(
    chatRepository: mockChatRepository,
    settingsRepository: MockSettingsRepository(),
    avatarAnimationService: mockAvatarAnimationService,
    chatTitleService: chatTitleService,
  );
  // Initialize the cubit
  cubit.init();
});
```

**Step 4: Update test assertions**

The tests now check ChatsState instead of ChatTitleState. Update assertions to check:
- `state.generatingChatIds` instead of state.generatingChatIds (same)
- `state.lastGeneratedTitle` instead of state.lastGeneratedTitle (same)

Actually, the state structure is the same, so most tests should work without changes.

**Step 5: Add missing imports for test**

Add to imports (around line 10-20):

```dart
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
```

**Step 6: Run tests**

```bash
flutter test test/integration/features/chat/title_generation_test.dart
```

Expected: All tests pass

**Step 7: Commit**

```bash
git add test/integration/features/chat/title_generation_test.dart
git commit -m "refactor(phase3a): update title generation tests to use ChatsCubit"
```

---

### Task 6: Verify Phase 3a completion

**Step 1: Run full flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 2: Run all tests**

```bash
flutter test
```

Expected: All tests pass

**Step 3: Verify app still runs**

```bash
flutter run -d chrome --web-renderer html
```

Expected: App launches successfully, title generation still works

**Step 4: Create summary commit**

```bash
git add .
git commit -m "feat(phase3a): complete ChatTitleCubit merge into ChatsCubit

- Moved title generation state from ChatTitleState to ChatsState
- Moved generateTitle() and shouldGenerateTitle() methods to ChatsCubit
- Updated ChatStreamingCubit to use ChatsCubit for title generation
- Updated DI registrations
- Updated tests

ChatsCubit now handles:
- Chat list management
- Current chat state
- Title generation

ChatTitleCubit can be removed in next phase after verifying no remaining consumers."
```

---

## Phase 3b: Merge ChatListCubit into ChatsCubit

**Goal:** Absorb chat list state into ChatsCubit.

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart`
- Modify: `lib/features/chat/presentation/bloc/chat_list_cubit.dart` (to be deleted)
- Modify: `lib/core/di/service_locator.dart`
- Modify: Consumers that use ChatListCubit

### Task 1: Read ChatListCubit to understand state

**Step 1: Read ChatListCubit implementation**

```bash
cat lib/features/chat/presentation/bloc/chat_list_cubit.dart
```

**Step 2: Read ChatListState**

```bash
cat lib/features/chat/presentation/bloc/chat_list_state.dart
```

Expected: Understanding of state structure and methods

**Step 3: Find all consumers of ChatListCubit**

```bash
grep -r "ChatListCubit" lib/ --include="*.dart" | grep -v ".freezed.dart"
grep -r "ChatListState" lib/ --include="*.dart" | grep -v ".freezed.dart"
```

Expected: List of files that use ChatListCubit

---

### Task 2: Add chat list state to ChatsState

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart`

**Step 1: Add chat list fields to ChatsState**

Edit `lib/features/chat/presentation/bloc/chats_state.dart`:

Add fields after existing state fields:

```dart
/// List of all chats
final List<Chat> chatsList;

/// Status of chats list loading
final ChatsListStatus chatsListStatus;

/// Error message for chats list loading
final String? chatsListError;
```

**Step 2: Add enum for ChatsListStatus**

Add at top of file after ChatsStatus enum:

```dart
enum ChatsListStatus {
  initial,
  loading,
  success,
  error,
}
```

**Step 3: Update ChatsState constructor**

Add to factory constructor parameters:

```dart
const ChatsState({
  required this.status,
  required this.currentLanguage,
  required this.soundEffectsEnabled,
  required this.currentChat,
  required this.openedChat,
  required this.initializing,
  this.chatsList = const <Chat>[],
  this.chatsListStatus = ChatsListStatus.initial,
  this.chatsListError,
  this.generatingChatIds = const <String>{},
  this.lastGeneratedTitle,
}) ;
```

**Step 4: Update copyWith method**

Add to freezed copyWith:

```dart
$ChatsStateCopyWith<List<Chat>> get chatsList;
$ChatsStateCopyWith<ChatsListStatus> get chatsListStatus;
$ChatsStateCopyWith<String?> get chatsListError;
```

**Step 5: Update initial state**

Update ChatsInitialState:

```dart
class ChatsInitialState extends ChatsState {
  const ChatsInitialState()
      : status = ChatsStatus.initial,
        currentLanguage = 'fr',
        soundEffectsEnabled = false,
        currentChat = const Chat.empty(),
        openedChat = const Chat.empty(),
        initializing = true,
        chatsList = const <Chat>[],
        chatsListStatus = ChatsListStatus.initial,
        chatsListError = null,
        generatingChatIds = const <String>{},
        lastGeneratedTitle = null;
}
```

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 7: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_state.dart
git commit -m "refactor(phase3b): add chat list state fields to ChatsState"
```

---

### Task 3: Move chat list methods to ChatsCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`

**Step 1: Read ChatListCubit methods**

```bash
cat lib/features/chat/presentation/bloc/chat_list_cubit.dart | grep -A 20 "Future<void>"
```

Expected: Methods like fetchChatsList(), maybe filter/search methods

**Step 2: Add fetchChatsList method to ChatsCubit**

Add method to ChatsCubit class:

```dart
/// Fetch the list of all chats
Future<void> fetchChatsList() async {
  emit(state.copyWith(chatsListStatus: ChatsListStatus.loading));

  final Either<Exception, List<Chat>> result = await _chatRepository.getChatsList();

  result.fold(
    (Exception error) {
      emit(
        state.copyWith(
          chatsListStatus: ChatsListStatus.error,
          chatsListError: error.toString(),
        ),
      );
    },
    (List<Chat> chats) {
      emit(
        state.copyWith(
          chatsListStatus: ChatsListStatus.success,
          chatsList: chats,
        ),
      );
    },
  );
}
```

**Step 3: Add any other methods from ChatListCubit**

Look for other public methods in ChatListCubit and add them to ChatsCubit with same implementation.

**Step 4: Update init() to fetch chat list**

Modify existing init() method in ChatsCubit to also fetch chat list:

```dart
Future<void> init() async {
  await getCurrentChat();
  await _loadSettings();
  await fetchChatsList(); // Add this line
  emit(state.copyWith(initializing: false));
}
```

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 6: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_cubit.dart
git commit -m "refactor(phase3b): add chat list methods to ChatsCubit"
```

---

### Task 4: Update consumers to use ChatsCubit instead of ChatListCubit

**Files:**
- All files that import/use ChatListCubit

**Step 1: For each consumer file, do the following:**

1. Replace import:
   - Remove: `import 'chat_list_cubit.dart';`
   - Already have: `import 'chats_cubit.dart';`

2. Replace BlocBuilder/BlocListener:
   - Find: `BlocBuilder<ChatListCubit, ChatListState>`
   - Replace: `BlocBuilder<ChatsCubit, ChatsState>`

3. Update state access:
   - Find: `state.chats` or `state.status`
   - Replace: `state.chatsList` and `state.chatsListStatus`

**Example replacement:**

FROM:
```dart
BlocBuilder<ChatListCubit, ChatListState>(
  builder: (context, state) {
    if (state.status == ChatListStatus.loading) {
      return CircularProgressIndicator();
    }
    return ListView.builder(
      itemCount: state.chats.length,
      itemBuilder: (context, index) {
        return ChatTile(state.chats[index]);
      },
    );
  },
)
```

TO:
```dart
BlocBuilder<ChatsCubit, ChatsState>(
  builder: (context, state) {
    if (state.chatsListStatus == ChatsListStatus.loading) {
      return CircularProgressIndicator();
    }
    return ListView.builder(
      itemCount: state.chatsList.length,
      itemBuilder: (context, index) {
        return ChatTile(state.chatsList[index]);
      },
    );
  },
)
```

**Step 2: For method calls:**

FROM:
```dart
context.read<ChatListCubit>().fetchChatsList();
```

TO:
```dart
context.read<ChatsCubit>().fetchChatsList();
```

**Step 3: Run flutter analyze after each file**

```bash
flutter analyze
```

**Step 4: Commit after each file**

```bash
git add <file>
git commit -m "refactor(phase3b): update <file> to use ChatsCubit instead of ChatListCubit"
```

---

### Task 5: Remove ChatListCubit from service_locator

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Find and comment out ChatListCubit registration**

```bash
grep -n "ChatListCubit" lib/core/di/service_locator.dart
```

Comment out the registration:

```dart
// getIt.registerFactory<ChatListCubit>(
//   () => ChatListCubit(
//     chatRepository: getIt<ChatRepository>(),
//     settingsRepository: getIt<SettingsRepository>(),
//   ),
// );
```

**Step 2: Remove ChatListCubit from main.dart providers**

Edit `lib/main.dart`:

Remove or comment out:
```dart
// BlocProvider<ChatListCubit>(
//   create: (BuildContext context) => getIt<ChatListCubit>()..init(),
// ),
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 4: Commit**

```bash
git add lib/core/di/service_locator.dart lib/main.dart
git commit -m "refactor(phase3b): remove ChatListCubit from DI"
```

---

### Task 6: Delete ChatListCubit files

**Files:**
- Delete: `lib/features/chat/presentation/bloc/chat_list_cubit.dart`
- Delete: `lib/features/chat/presentation/bloc/chat_list_state.dart`
- Delete: `lib/features/chat/presentation/bloc/chat_list_state.freezed.dart`
- Delete: `test/features/chat/bloc/chat_list_cubit_test.dart` (if exists)

**Step 1: Delete files**

```bash
rm lib/features/chat/presentation/bloc/chat_list_cubit.dart
rm lib/features/chat/presentation/bloc/chat_list_state.dart
rm lib/features/chat/presentation/bloc/chat_list_state.freezed.dart
rm test/features/chat/bloc/chat_list_cubit_test.dart
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues

**Step 3: Run tests**

```bash
flutter test
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add .
git commit -m "refactor(phase3b): delete ChatListCubit files after merge into ChatsCubit"
```

---

## Phase 3c: Merge ChatAudioCubit into ChatTtsCubit

**Goal:** Combine waiting sentences audio queue management into TTS cubit.

**Pattern:** Similar to Phase 3b - read state, merge, update consumers, delete old files.

**Key considerations:**
- ChatAudioCubit manages waiting sentences audio queue
- ChatTtsCubit manages TTS playback
- These are related concerns that can be combined

**Follow same pattern as Phase 3b:**
1. Read ChatAudioCubit and ChatAudioState
2. Add state to ChatTtsState
3. Move methods to ChatTtsCubit
4. Update consumers
5. Update DI
6. Delete old files

---

## Phase 3d: Deprecate ChatMessageCubit wrapper

**Goal:** Remove thin wrapper, have consumers use child cubits directly.

**Rationale:** After extracting ChatMessageService in Phase 2b, ChatMessageCubit is now just a pass-through wrapper. Consumers should use ChatAudioCubit and ChatStreamingCubit directly.

**Files:**
- Modify: All consumers of ChatMessageCubit
- Modify: `lib/core/di/service_locator.dart`
- Modify: `lib/main.dart`
- Delete: `lib/features/chat/presentation/bloc/chat_message_cubit.dart`

### Task 1: Find all consumers

```bash
grep -r "ChatMessageCubit" lib/ --include="*.dart" | grep -v ".freezed.dart"
```

### Task 2: For each consumer:

Replace state access:
- `state.streamingContent` → `context.watch<ChatStreamingCubit>().state.streamingContent`
- `state.audioPathsWaitingSentences` → `context.watch<ChatAudioCubit>().state.audioPathsWaitingSentences`

Replace method calls:
- `cubit.prepareWaitingSentences()` → `context.read<ChatAudioCubit>().prepareWaitingSentences()`
- `cubit.askYofardev()` → `context.read<ChatStreamingCubit>().streamResponse()`

### Task 3: Remove from DI and main.dart

### Task 4: Delete files

---

## Phase 3e: Merge ChatStreamingCubit into ChatsCubit

**Goal:** Core consolidation - move streaming logic into main chat cubit.

**This is the largest merge - most careful planning required.**

**Key state to merge:**
- streamingContent
- streamingStatus
- streamingSentenceCount
- errorMessage

**Key methods to move:**
- streamResponse()
- All streaming-related methods

**Special considerations:**
- ChatStreamingCubit is 374 lines (exceeds 300 line limit)
- After merge, extract helper methods to keep file size manageable
- Consider extracting stream processing logic to domain service if needed

---

## Phase 3f: Rename to final structure

**Goal:** Rename ChatsCubit → ChatCubit for final naming.

**Files:**
- Rename: `lib/features/chat/presentation/bloc/chats_cubit.dart` → `chat_cubit.dart`
- Rename: `lib/features/chat/presentation/bloc/chats_state.dart` → `chat_state.dart`
- Global rename of class names

**Step 1: Use IDE rename or find-replace**

```bash
# Rename file
mv lib/features/chat/presentation/bloc/chats_cubit.dart lib/features/chat/presentation/bloc/chat_cubit.dart
mv lib/features/chat/presentation/bloc/chats_state.dart lib/features/chat/presentation/bloc/chat_state.dart

# Update all references
grep -rl "ChatsCubit" lib/ --include="*.dart" | xargs sed -i 's/ChatsCubit/ChatCubit/g'
grep -rl "ChatsState" lib/ --include="*.dart" | xargs sed -i 's/ChatsState/ChatState/g'
grep -rl "chats_cubit" lib/ --include="*.dart" | xargs sed -i 's/chats_cubit/chat_cubit/g'
grep -rl "chats_state" lib/ --include="*.dart" | xargs sed -i 's/chats_state/chat_state/g'
```

**Step 2: Update all imports**

```bash
grep -rl "chats_cubit" lib/ --include="*.dart" | xargs sed -i 's/chats_cubit/chat_cubit/g'
```

**Step 3: Update service_locator**

**Step 4: Update main.dart**

**Step 5: Update tests**

**Step 6: Run flutter analyze and tests**

**Step 7: Final commit**

```bash
git add .
git commit -m "refactor(phase3f): rename ChatsCubit to ChatCubit for final naming"
```

---

## Phase 4: Layer Boundary Cleanup

**Goal:** Fix presentation → data layer imports.

**Files:**
- Move: `lib/features/sound/data/tts_queue_manager.dart` → `lib/core/services/audio/tts_queue_service.dart`
- Modify: All files that import TtsQueueManager
- Modify: `lib/core/di/service_locator.dart`

### Task 1: Move TtsQueueManager to core/services

**Step 1: Read current file**

```bash
cat lib/features/sound/data/tts_queue_manager.dart
```

**Step 2: Move to core with new name**

```bash
mkdir -p lib/core/services/audio
cp lib/features/sound/data/tts_queue_manager.dart lib/core/services/audio/tts_queue_service.dart
```

**Step 3: Rename class in new file**

Edit `lib/core/services/audio/tts_queue_service.dart`:

Change class name:
```dart
class TtsQueueService {
```

**Step 4: Update imports in new file**

Fix imports to use correct relative paths.

**Step 5: Update all consumers**

```bash
grep -rl "sound/data/tts_queue_manager" lib/ --include="*.dart" | while read file; do
  sed -i 's|sound/data/tts_queue_manager|core/services/audio/tts_queue_service|g' "$file"
  sed -i 's|TtsQueueManager|TtsQueueService|g' "$file"
done
```

**Step 6: Update service_locator**

Find TtsQueueManager registration and update name:

```dart
getIt.registerLazySingleton<TtsQueueService>(
  () => TtsQueueService(
    ttsDatasource: getIt<TtsDatasource>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);
```

**Step 7: Delete old file**

```bash
rm lib/features/sound/data/tts_queue_manager.dart
```

**Step 8: Run flutter analyze**

```bash
flutter analyze
```

**Step 9: Commit**

```bash
git add .
git commit -m "refactor(phase4): move TtsQueueManager to core/services as TtsQueueService"
```

---

## Phase 5: Presentation Polish

**Goal:** Clean up presentation layer issues.

### Task 1: Replace nested BlocListeners with MultiBlocListener

**Files:**
- Modify: `lib/features/chat/screens/chat_details_screen.dart`
- Modify: `lib/features/chat/screens/chats_list_screen.dart`

**Pattern:**

FROM:
```dart
BlocListener<A, AState>(
  listener: (context, state) { ... },
  child: BlocListener<B, BState>(
    listener: (context, state) { ... },
    child: Widget(...),
  ),
)
```

TO:
```dart
MultiBlocListener(
  listeners: [
    BlocListener<A, AState>(
      listener: (context, state) { ... },
    ),
    BlocListener<B, BState>(
      listener: (context, state) { ... },
    ),
  ],
  child: Widget(...),
)
```

### Task 2: Reduce file sizes

**Files:**
- Modify: `lib/features/settings/presentation/bloc/settings_cubit.dart` (324 lines)
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (after consolidation)

**Strategy:**
- Extract unrelated functionality to separate widgets or services
- Break large methods into smaller helpers
- Consider extracting configuration logic to domain services

### Task 3: Enforce state exhaustiveness

**Pattern:** Ensure all freezed states use `.when()` instead of `if (state is X)` checks.

---

## Testing Strategy

### After Each Phase:

**Step 1: Run flutter analyze**

```bash
flutter analyze
```

Must pass with no issues.

**Step 2: Run unit tests**

```bash
flutter test test/features/
```

All tests must pass.

**Step 3: Run integration tests**

```bash
flutter test test/integration/
```

All tests must pass.

**Step 4: Smoke test the application**

```bash
flutter run -d chrome --web-renderer html
```

Verify:
- App launches
- Can create new chat
- Can send message
- TTS works
- Title generation works
- Settings work

**Step 5: If all pass, create summary commit**

```bash
git add .
git commit -m "feat(phase<N>): complete phase <N> - <brief description>

Summary of changes:
- <bullet list of key changes>

All tests passing, app verified working."
```

---

## Rollback Strategy

If any phase fails:

**Step 1: Identify breaking change**

```bash
git diff HEAD~5
```

**Step 2: Revert to last known good state**

```bash
git reset --hard HEAD~1
```

**Step 3: Run tests to verify**

```bash
flutter test
```

**Step 4: Document the issue**

Create markdown file in docs/plans/ describing what failed and why.

---

## Success Criteria

Phase 3-5 complete when:
- ✅ Only 2 chat cubits exist: ChatCubit and ChatMediaCubit
- ✅ No cubit-to-cubit dependencies
- ✅ No presentation → data layer imports
- ✅ All files under 300 lines (or have justification)
- ✅ All tests pass
- ✅ flutter analyze passes with no issues
- ✅ App functions identically to before refactoring

---

## References

**Skills to reference during implementation:**
- @superpowers:executing-plans - For task-by-task execution
- @superpowers:systematic-debugging - If tests fail
- @superpowers:verification-before-completion - Before claiming any phase complete

**Documentation:**
- Flutter Architecture & Coding Standards: `/home/yofardev/.claude/skills/flutter-architecture`
- Original Audit: Review audit output for detailed issue descriptions

**Key Commands:**
```bash
# Analyze code
flutter analyze

# Run all tests
flutter test

# Run specific test
flutter test test/path/to/test.dart

# Run app
flutter run -d chrome --web-renderer html

# Check git diff
git diff

# Commit changes
git add .
git commit -m "type: description"

# View recent commits
git log --oneline -10
```

---

**End of Plan**

Total estimated effort: 6-8 hours of focused work across 3-4 sessions.

Remember: Each phase is independently deployable. The app must compile and run after EVERY phase.
