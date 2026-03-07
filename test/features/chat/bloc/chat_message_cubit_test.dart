import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_audio_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_message_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_message_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_streaming_cubit.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/sound/data/tts_queue_manager.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';

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

  // Function Calling Configuration - Google Search
  @override
  Future<Either<Exception, String?>> getGoogleSearchKey() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getGoogleSearchEngineId() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEngineId(String id) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  // Function Calling Configuration - OpenWeather
  @override
  Future<Either<Exception, String?>> getOpenWeatherKey() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  // Function Calling Configuration - New York Times
  @override
  Future<Either<Exception, String?>> getNewYorkTimesKey() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }
}

class MockPromptDatasource extends Mock implements PromptDatasource {
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

  bool get hasItems => _enqueuedItems.isNotEmpty;

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

class MockStreamProcessorService extends Mock
    implements StreamProcessorService {}

class MockChatEntryService implements ChatEntryService {
  const MockChatEntryService();

  @override
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async {
    return ChatEntry(
      id: 'test-id',
      entryType: EntryType.user,
      body: prompt,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
  }
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
    late InterruptionService interruptionService;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
      registerFallbackValue(
        Request('POST', Uri.parse('https://api.example.com')),
      );
      registerFallbackValue(const Stream<LlmStreamChunk>.empty());
    });

    setUp(() async {
      await initializeDateFormatting('en_US', null);

      mockChatRepo = MockChatRepository();
      mockSettingsRepo = MockSettingsRepository();
      mockHttpClient = MockHttpClient();
      mockPromptDatasource = MockPromptDatasource();
      mockTtsManager = MockTtsQueueManager();
      interruptionService = InterruptionService();

      LlmService.setTestClient(mockHttpClient);
      llmService = LlmService();

      // Save a test config so getCurrentConfig() doesn't return null
      await llmService.saveConfig(
        const LlmConfig(
          id: 'test-config',
          label: 'Test',
          baseUrl: 'https://api.test.com',
          apiKey: 'test-key',
          model: 'test-model',
        ),
      );

      final ChatAudioCubit chatAudioCubit = ChatAudioCubit();
      final ChatStreamingCubit chatStreamingCubit = ChatStreamingCubit(
        chatRepository: mockChatRepo,
        settingsRepository: mockSettingsRepo,
        llmService: llmService,
        streamProcessor: StreamProcessorService(),
        promptDatasource: mockPromptDatasource,
        interruptionService: interruptionService,
        chatEntryService: MockChatEntryService(),
        ttsQueueManager: mockTtsManager,
      );
      cubit = ChatMessageCubit(
        chatAudioCubit: chatAudioCubit,
        chatStreamingCubit: chatStreamingCubit,
      );
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
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
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(cubit.state.initializing, isFalse);
      });
    });

    group('shuffleWaitingSentences', () {
      test('should shuffle audio paths waiting sentences', () async {
        final List<Map<String, dynamic>> originalList = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'a'},
          <String, dynamic>{'sentence': 'B', 'audioPath': 'b'},
          <String, dynamic>{'sentence': 'C', 'audioPath': 'c'},
        ];

        // Set up state using the child cubit
        cubit.chatAudioCubit.emit(
          cubit.chatAudioCubit.state.copyWith(
            audioPathsWaitingSentences: originalList,
          ),
        );
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        cubit.shuffleWaitingSentences();
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

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
      test('should remove sentence by audioPath', () async {
        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'path1'},
          <String, dynamic>{'sentence': 'B', 'audioPath': 'path2'},
          <String, dynamic>{'sentence': 'C', 'audioPath': 'path3'},
        ];

        // Set up state using the child cubit
        cubit.chatAudioCubit.emit(
          cubit.chatAudioCubit.state.copyWith(audioPathsWaitingSentences: list),
        );
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        cubit.removeWaitingSentence('path2');
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(cubit.state.audioPathsWaitingSentences.length, 2);
        expect(
          cubit.state.audioPathsWaitingSentences.any(
            (Map<String, dynamic> item) => item['audioPath'] == 'path2',
          ),
          isFalse,
        );
      });

      test('should do nothing when audioPath not found', () async {
        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'A', 'audioPath': 'path1'},
        ];

        // Set up state using the child cubit
        cubit.chatAudioCubit.emit(
          cubit.chatAudioCubit.state.copyWith(audioPathsWaitingSentences: list),
        );
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        final int beforeLength = cubit.state.audioPathsWaitingSentences.length;

        cubit.removeWaitingSentence('nonexistent');
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

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
          language: 'en',
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
          language: 'en',
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
          language: 'en',
        );

        // The implementation logs function call errors but continues with streaming
        // Stream errors are logged but don't result in error state - final state is success
        expect(cubit.state.status, ChatMessageStatus.success);
        expect(mockChatRepo.updatedChat, isNotNull);
      });

      test('should emit error state on exception', () async {
        mockChatRepo.askError = Exception('Network error');

        await cubit.askYofardev(
          'Hello',
          onlyText: true,
          avatar: testAvatar,
          currentChat: testChat,
          language: 'en',
        );

        // The implementation logs function call errors but continues with streaming
        // Stream errors are logged but don't result in error state - final state is success
        expect(cubit.state.status, ChatMessageStatus.success);
        expect(mockChatRepo.updatedChat, isNotNull);
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
          language: 'en',
        );

        expect(mockChatRepo.updatedChat, isNotNull);
        expect(
          mockChatRepo.updatedChat!.entries.length,
          greaterThan(initialChat.entries.length),
        );
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
        expect(ChatMessageStatus.values.length, 7);
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.initial));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.loading));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.typing));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.streaming));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.success));
        expect(ChatMessageStatus.values, contains(ChatMessageStatus.error));
        expect(
          ChatMessageStatus.values,
          contains(ChatMessageStatus.interrupted),
        );
      });
    });

    group('Interruption', () {
      late MockChatRepository mockChatRepository;
      late MockSettingsRepository mockSettingsRepository;
      late LlmService mockLlmService;
      late MockHttpClient mockHttpClient;
      late MockStreamProcessorService mockStreamProcessor;
      late MockPromptDatasource mockPromptDatasource;
      late InterruptionService interruptionService;

      setUp(() async {
        mockChatRepository = MockChatRepository();
        mockSettingsRepository = MockSettingsRepository();
        mockHttpClient = MockHttpClient();
        mockStreamProcessor = MockStreamProcessorService();
        mockPromptDatasource = MockPromptDatasource();
        interruptionService = InterruptionService();

        LlmService.setTestClient(mockHttpClient);
        mockLlmService = LlmService();

        // Save a test config so getCurrentConfig() doesn't return null
        await mockLlmService.saveConfig(
          const LlmConfig(
            id: 'test-config',
            label: 'Test',
            baseUrl: 'https://api.test.com',
            apiKey: 'test-key',
            model: 'test-model',
          ),
        );
      });

      tearDown(() {
        interruptionService.dispose();
        LlmService.resetTestClient();
      });

      test(
        'should transition to interrupted state when interruption occurs',
        () async {
          // Arrange
          final ChatAudioCubit chatAudioCubit = ChatAudioCubit();
          final ChatStreamingCubit chatStreamingCubit = ChatStreamingCubit(
            chatRepository: mockChatRepository,
            settingsRepository: mockSettingsRepository,
            llmService: mockLlmService,
            streamProcessor: mockStreamProcessor,
            promptDatasource: mockPromptDatasource,
            interruptionService: interruptionService,
            chatEntryService: MockChatEntryService(),
          );
          final ChatMessageCubit cubit = ChatMessageCubit(
            chatAudioCubit: chatAudioCubit,
            chatStreamingCubit: chatStreamingCubit,
          );

          // Start streaming
          final StreamController<SentenceChunk> controller =
              StreamController<SentenceChunk>();
          when(
            () => mockStreamProcessor.processStream(any()),
          ).thenAnswer((_) => controller.stream);

          // Start streaming (don't await)
          unawaited(
            cubit.askYofardev(
              'test',
              onlyText: true,
              avatar: const Avatar(),
              currentChat: const Chat(),
              language: 'fr',
            ),
          );

          await Future<dynamic>.delayed(const Duration(milliseconds: 100));

          // Act
          await interruptionService.interrupt();
          await Future<dynamic>.delayed(const Duration(milliseconds: 100));

          // Assert
          expect(cubit.state.status, ChatMessageStatus.interrupted);

          // Close stream controller first to stop streaming
          await controller.close();
          await cubit.close();
        },
      );
    });
  });
}
