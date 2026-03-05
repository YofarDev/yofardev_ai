import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_state.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_manager.dart';
import 'package:yofardev_ai/l10n/localization_manager.dart';

class MockHttpClient extends Mock implements Client {}

class MockChatRepository implements ChatRepository {
  List<ChatEntry> _askResponse = <ChatEntry>[
    ChatEntry(
      id: 'response-id',
      entryType: EntryType.yofardev,
      body: 'Test response',
      timestamp: DateTime.now(),
    ),
  ];

  Exception? _askError;
  Chat? _updatedChat;

  Chat? get updatedChat => _updatedChat;

  set askResponse(List<ChatEntry> response) => _askResponse = response;
  set askError(Exception? error) => _askError = error;

  @override
  Future<Either<Exception, List<ChatEntry>>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    if (_askError != null) {
      return Left<Exception, List<ChatEntry>>(_askError!);
    }
    return Right<Exception, List<ChatEntry>>(_askResponse);
  }

  @override
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    _updatedChat = updatedChat;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, Chat>> createNewChat() async {
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat>> getCurrentChat() async {
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat?>> getChat(String id) async {
    return const Right<Exception, Chat?>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, void>> deleteChat(String id) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, List<Chat>>> getChatsList() async {
    return const Right<Exception, List<Chat>>(<Chat>[]);
  }

  @override
  Future<Either<Exception, void>> setCurrentChatId(String chatId) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return const Right<Exception, void>(null);
  }
}

class MockSettingsRepository implements SettingsRepository {
  String _language = 'fr';

  @override
  Future<Either<Exception, String?>> getLanguage() async {
    return Right<Exception, String?>(_language);
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    _language = language;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    return const Right<Exception, bool>(true);
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool soundEffects) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    return const Right<Exception, String>('System prompt');
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    return const Right<Exception, ChatPersona>(ChatPersona.normal);
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    return const Right<Exception, TaskLlmConfig>(TaskLlmConfig());
  }

  @override
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return const Right<Exception, void>(null);
  }
}

class MockPromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'Test system prompt';
}

class MockTtsQueueManager implements TtsQueueManager {
  final List<TtsQueueItem> _enqueuedItems = <TtsQueueItem>[];

  List<TtsQueueItem> get enqueuedItems =>
      List<TtsQueueItem>.unmodifiable(_enqueuedItems);

  @override
  Stream<String> get audioStream => const Stream<String>.empty();

  @override
  bool get isProcessing => false;

  @override
  List<TtsQueueItem> get queue =>
      List<TtsQueueItem>.unmodifiable(_enqueuedItems);

  @override
  bool get hasItems => _enqueuedItems.isNotEmpty;

  @override
  bool get isPlaying => false;

  @override
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
  }) async {
    _enqueuedItems.add(
      TtsQueueItem(
        id: 'test-id',
        text: text,
        language: language,
        voiceEffect: voiceEffect,
        priority: priority,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void clear() {
    _enqueuedItems.clear();
  }

  @override
  void dispose() {}

  @override
  void setPaused(bool paused) {}
}

void main() {
  // Initialize Flutter test bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessageCubit', () {
    late ChatMessageCubit cubit;
    late MockChatRepository mockChatRepo;
    late MockSettingsRepository mockSettingsRepo;
    late LlmService llmService;
    late MockHttpClient mockHttpClient;
    late MockPromptDatasource mockPromptDatasource;
    late MockTtsQueueManager mockTtsManager;

    setUpAll(() {
      registerFallbackValue(
        Request('POST', Uri.parse('https://api.example.com')),
      );
    });

    setUp(() async {
      await LocalizationManager().initialize('en');
      await initializeDateFormatting('en_US', null);

      mockChatRepo = MockChatRepository();
      mockSettingsRepo = MockSettingsRepository();
      mockHttpClient = MockHttpClient();
      mockPromptDatasource = MockPromptDatasource();
      mockTtsManager = MockTtsQueueManager();

      LlmService.setTestClient(mockHttpClient);
      llmService = LlmService();

      cubit = ChatMessageCubit(
        chatRepository: mockChatRepo,
        settingsRepository: mockSettingsRepo,
        llmService: llmService,
        streamProcessor: StreamProcessorService(),
        promptDatasource: mockPromptDatasource,
        ttsQueueManager: mockTtsManager,
      );
    });

    tearDown(() {
      cubit.close();
      LlmService.resetTestClient();
    });

    test('initial state should have default values', () {
      expect(cubit.state.status, ChatMessageStatus.initial);
      expect(cubit.state.streamingContent, '');
      expect(cubit.state.streamingSentenceCount, 0);
      expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      expect(cubit.state.initializing, isTrue);
      expect(cubit.state.errorMessage, '');
    });

    group('prepareWaitingSentences', () {
      test('should set initializing to false', () async {
        await cubit.prepareWaitingSentences('fr');

        expect(cubit.state.initializing, isFalse);
      });
    });

    group('shuffleWaitingSentences', () {
      test('should shuffle audio paths waiting sentences', () {
        final List<Map<String, dynamic>> originalList = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'a'},
          <String, dynamic>{'sentence': 'B', 'audioPath': 'b'},
          <String, dynamic>{'sentence': 'C', 'audioPath': 'c'},
        ];

        cubit.emit(
          cubit.state.copyWith(audioPathsWaitingSentences: originalList),
        );

        cubit.shuffleWaitingSentences();

        // Same elements, just shuffled
        expect(cubit.state.audioPathsWaitingSentences.length, 3);

        // Check all audioPaths are still present
        final List<String> audioPaths = cubit.state.audioPathsWaitingSentences
            .map<String>(
              (Map<String, dynamic> item) => item['audioPath'] as String,
            )
            .toList();
        expect(audioPaths, containsAll(<String>['a', 'b', 'c']));
      });
    });

    group('removeWaitingSentence', () {
      test('should remove sentence by audioPath', () {
        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'path1'},
          <String, dynamic>{'sentence': 'B', 'audioPath': 'path2'},
          <String, dynamic>{'sentence': 'C', 'audioPath': 'path3'},
        ];

        cubit.emit(cubit.state.copyWith(audioPathsWaitingSentences: list));

        cubit.removeWaitingSentence('path2');

        expect(cubit.state.audioPathsWaitingSentences.length, 2);
        expect(
          cubit.state.audioPathsWaitingSentences.any(
            (Map<String, dynamic> item) => item['audioPath'] == 'path2',
          ),
          isFalse,
        );
      });

      test('should do nothing when audioPath not found', () {
        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'path1'},
        ];

        cubit.emit(cubit.state.copyWith(audioPathsWaitingSentences: list));
        final int beforeLength = cubit.state.audioPathsWaitingSentences.length;

        cubit.removeWaitingSentence('nonexistent');

        expect(cubit.state.audioPathsWaitingSentences.length, beforeLength);
      });
    });

    group('askYofardev', () {
      const Avatar testAvatar = Avatar(background: AvatarBackgrounds.lake);

      const Chat testChat = Chat(id: 'test-chat', language: 'en');

      test('should emit typing then success on successful response', () async {
        await cubit.askYofardev(
          'Hello',
          onlyText: true,
          avatar: testAvatar,
          currentChat: testChat,
        );

        expect(cubit.state.status, ChatMessageStatus.success);
        expect(mockChatRepo.updatedChat, isNotNull);
        expect(mockChatRepo.updatedChat!.entries.length, greaterThan(0));
      });

      test('should clear audioPathsWaitingSentences on ask', () async {
        cubit.emit(
          cubit.state.copyWith(
            audioPathsWaitingSentences: <Map<String, dynamic>>[
              <String, dynamic>{'sentence': 'Test', 'audioPath': 'path'},
            ],
          ),
        );

        await cubit.askYofardev(
          'Hello',
          onlyText: true,
          avatar: testAvatar,
          currentChat: testChat,
        );

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });

      test('should emit error state on repository error', () async {
        mockChatRepo.askError = Exception('API Error');

        await cubit.askYofardev(
          'Hello',
          onlyText: true,
          avatar: testAvatar,
          currentChat: testChat,
        );

        expect(cubit.state.status, ChatMessageStatus.error);
        expect(cubit.state.errorMessage, contains('API Error'));
      });

      test('should emit error state on exception', () async {
        mockChatRepo.askError = Exception('Network error');

        await cubit.askYofardev(
          'Hello',
          onlyText: true,
          avatar: testAvatar,
          currentChat: testChat,
        );

        expect(cubit.state.status, ChatMessageStatus.error);
        expect(cubit.state.errorMessage, isNotEmpty);
      });

      test('should update chat with new entries', () async {
        final Chat initialChat = testChat.copyWith(
          entries: <ChatEntry>[
            ChatEntry(
              id: 'existing',
              entryType: EntryType.user,
              body: 'Previous message',
              timestamp: DateTime.now(),
            ),
          ],
        );

        await cubit.askYofardev(
          'New message',
          onlyText: true,
          avatar: testAvatar,
          currentChat: initialChat,
        );

        expect(mockChatRepo.updatedChat, isNotNull);
        expect(
          mockChatRepo.updatedChat!.entries.length,
          greaterThan(initialChat.entries.length),
        );
      });
    });

    group('askYofardevStream', () {
      const Avatar testAvatar = Avatar(background: AvatarBackgrounds.lake);

      const Chat testChat = Chat(id: 'test-chat', language: 'en');

      test('should clear audioPathsWaitingSentences on stream start', () async {
        cubit.emit(
          cubit.state.copyWith(
            audioPathsWaitingSentences: <Map<String, dynamic>>[
              <String, dynamic>{'sentence': 'Old', 'audioPath': 'old'},
            ],
          ),
        );

        await cubit.askYofardevStream(
          'Test',
          onlyText: false,
          avatar: testAvatar,
          currentChat: testChat,
          language: 'en',
        );

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });
    });

    group('ChatMessageState', () {
      test('should create with default values', () {
        const ChatMessageState state = ChatMessageState();

        expect(state.status, ChatMessageStatus.initial);
        expect(state.errorMessage, '');
        expect(state.streamingContent, '');
        expect(state.streamingSentenceCount, 0);
        expect(state.audioPathsWaitingSentences, isEmpty);
        expect(state.initializing, isTrue);
      });

      test('should copy with new values', () {
        const ChatMessageState state = ChatMessageState();

        final ChatMessageState newState = state.copyWith(
          status: ChatMessageStatus.streaming,
          errorMessage: 'Error',
          streamingContent: 'Content',
          streamingSentenceCount: 5,
          initializing: false,
        );

        expect(newState.status, ChatMessageStatus.streaming);
        expect(newState.errorMessage, 'Error');
        expect(newState.streamingContent, 'Content');
        expect(newState.streamingSentenceCount, 5);
        expect(newState.initializing, isFalse);
      });

      test('should copy with list values', () {
        const ChatMessageState state = ChatMessageState();

        final List<Map<String, dynamic>> newList = <Map<String, dynamic>>[
          <String, dynamic>{'audioPath': 'test'},
        ];

        final ChatMessageState newState = state.copyWith(
          audioPathsWaitingSentences: newList,
        );

        expect(newState.audioPathsWaitingSentences, newList);
        expect(newState.status, state.status); // unchanged
      });
    });

    group('ChatMessageStatus enum', () {
      test('should have all required values', () {
        expect(ChatMessageStatus.values.length, 6);
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.initial));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.loading));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.typing));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.streaming));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.success));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.error));
      });
    });
  });
}
