import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_queue_service.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';

class TrackingMockChatRepository implements ChatRepository {
  Chat? currentChat;
  Chat? updatedChat;
  String? updatedChatId;
  int updateCallCount = 0;

  @override
  Future<Result<Chat>> createNewChat({String? language}) async {
    return Result<Chat>.ok(Chat(id: 'test-id'));
  }

  @override
  Future<Result<Chat>> getCurrentChat() async {
    if (currentChat != null) {
      return Result<Chat>.ok(currentChat!);
    }
    return Result<Chat>.ok(Chat(id: 'test-id'));
  }

  @override
  Future<Result<Chat?>> getChat(String id) async {
    return Result<Chat?>.ok(currentChat);
  }

  @override
  Future<Result<void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    updatedChatId = id;
    this.updatedChat = updatedChat;
    updateCallCount++;
    if (currentChat != null && currentChat!.id == id) {
      currentChat = updatedChat;
    }
    return Result<void>.ok(null);
  }

  @override
  Future<Result<void>> deleteChat(String id) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<List<Chat>>> getChatsList() async {
    return Result<List<Chat>>.ok(<Chat>[]);
  }

  @override
  Future<Result<void>> setCurrentChatId(String chatId) async {
    return Result<void>.ok(null);
  }

  @override
  @override
  Future<Result<(List<ChatEntry> functionEntries, String augmentedUserMessage)>>
  prepareToolTurn({
    required Chat chat,
    required String userMessage,
  }) async {
    return Result<(List<ChatEntry>, String)>.ok((<ChatEntry>[], userMessage));
  }

  @override
  Future<Result<void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return Result<void>.ok(null);
  }
}

class MockLlmService extends Mock implements LlmService {}

/// Factory to create a real ChatStreamingService with mocked dependencies for testing
ChatStreamingService createMockChatStreamingService({
  required ChatRepository chatRepository,
  required LlmServiceInterface llmService,
  required StreamProcessorService streamProcessor,
  required PromptDatasource promptDatasource,
  required InterruptionService interruptionService,
  required ChatEntryService chatEntryService,
  TtsQueueService? ttsQueueManager,
}) {
  return ChatStreamingService(
    chatRepository: chatRepository,
    llmService: llmService,
    streamProcessor: streamProcessor,
    promptDatasource: promptDatasource,
    interruptionService: interruptionService,
    chatEntryService: chatEntryService,
    ttsQueueManager: ttsQueueManager,
  );
}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class MockInterruptionService implements InterruptionService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get interruptionStream => _controller.stream;

  @override
  Future<void> interrupt() async => _controller.add(null);

  @override
  void reset() {}

  @override
  bool get isInterrupted => false;

  @override
  void dispose() => _controller.close();
}

class MockPromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'Test system prompt';
}

class MockStreamProcessorService implements StreamProcessorService {
  @override
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    // Empty implementation for testing
  }
}

class MockChatEntryService implements ChatEntryService {
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
  group('Title Generation Integration Tests', () {
    late TrackingMockChatRepository mockChatRepository;
    late MockLlmService mockLlmService;
    late ChatCubit cubit;

    setUp(() {
      mockChatRepository = TrackingMockChatRepository();
      mockLlmService = MockLlmService();
      final ChatTitleService chatTitleService = ChatTitleService(
        chatRepository: mockChatRepository,
        llmService: mockLlmService,
      );
      final MockAvatarAnimationService mockAvatarAnimationService =
          MockAvatarAnimationService();
      final MockSettingsRepository mockSettingsRepository =
          MockSettingsRepository();

      // Set up mock to return language
      when(
        () => mockSettingsRepository.getLanguage(),
      ).thenAnswer((_) async => Result<String?>.ok('en'));
      // Set up mock to return sound effects enabled
      when(
        () => mockSettingsRepository.getSoundEffects(),
      ).thenAnswer((_) async => Result<bool>.ok(true));

      // Create mock services
      final ChatStreamingService mockChatStreamingService =
          createMockChatStreamingService(
            chatRepository: mockChatRepository,
            llmService: mockLlmService,
            streamProcessor: MockStreamProcessorService(),
            promptDatasource: MockPromptDatasource(),
            interruptionService: MockInterruptionService(),
            chatEntryService: MockChatEntryService(),
          );

      cubit = ChatCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        avatarAnimationService: mockAvatarAnimationService,
        chatTitleService: chatTitleService,
        chatStreamingService: mockChatStreamingService,
        appLifecycleService: MockAppLifecycleService(),
      );
      // Initialize the cubit
      cubit.init();
    });

    tearDown(() {
      cubit.close();
    });

    test('should not generate title if already generated', () async {
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

      await cubit.generateTitle(testChat.id, testChat);

      expect(mockChatRepository.updateCallCount, 0);
      verifyNever(() => mockLlmService.init());
    });

    test('should not generate title for empty chat', () async {
      const Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[],
        title: '',
        titleGenerated: false,
      );

      await cubit.generateTitle(testChat.id, testChat);

      expect(mockChatRepository.updateCallCount, 0);
      verifyNever(() => mockLlmService.init());
    });

    test('should update chat after successful title generation', () async {
      final Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'user-entry',
            entryType: EntryType.user,
            body: 'How do I learn Flutter?',
            timestamp: DateTime.now(),
          ),
        ],
      );

      when(() => mockLlmService.init()).thenAnswer((_) async {});
      when(
        () => mockLlmService.generateTitle(
          any(),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => '"Learn Flutter"');

      await cubit.generateTitle(testChat.id, testChat);

      expect(mockChatRepository.updateCallCount, 1);
      expect(mockChatRepository.updatedChatId, testChat.id);
      expect(mockChatRepository.updatedChat?.title, 'Learn Flutter');
      expect(mockChatRepository.updatedChat?.titleGenerated, true);
      expect(cubit.state.lastGeneratedTitle?.chatId, testChat.id);
      expect(cubit.state.lastGeneratedTitle?.title, 'Learn Flutter');
      expect(cubit.state.generatingTitleChatIds, isEmpty);
    });

    test('should prevent duplicate title generation for same chat', () async {
      final Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'user-entry',
            entryType: EntryType.user,
            body: 'Test message',
            timestamp: DateTime.now(),
          ),
        ],
      );

      int generateTitleCallCount = 0;
      when(() => mockLlmService.init()).thenAnswer((_) async {});
      when(
        () => mockLlmService.generateTitle(
          any(),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async {
        generateTitleCallCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'Generated Title';
      });

      final Future<void> call1 = cubit.generateTitle(testChat.id, testChat);
      final Future<void> call2 = cubit.generateTitle(testChat.id, testChat);

      await Future.wait(<Future<void>>[call1, call2]);

      expect(generateTitleCallCount, 1);
      expect(mockChatRepository.updateCallCount, 1);
    });

    test('should handle chat with only function entries', () async {
      final Chat testChat = Chat(
        id: 'test-chat-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'system-entry',
            entryType: EntryType.functionCalling,
            body: 'Function call',
            timestamp: DateTime.now(),
          ),
        ],
      );

      await cubit.generateTitle(testChat.id, testChat);

      expect(mockChatRepository.updateCallCount, 0);
      verifyNever(
        () => mockLlmService.generateTitle(
          any(),
          language: any(named: 'language'),
        ),
      );
    });

    test('should initialize with empty generating set', () {
      expect(cubit.state.generatingTitleChatIds, isEmpty);
    });
  });
}

class MockAppLifecycleService extends Mock implements AppLifecycleService {
@override
  Stream<AvatarChangeRequested> get avatarChangeRequestedEvents =>
      const Stream<AvatarChangeRequested>.empty();

  @override
  void emitAvatarChangeRequested(AvatarChangeRequested request) {}
  @override
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      const Stream<NewChatEntryPayload>.empty();

  @override
  Stream<String> get chatChangedEvents => const Stream<String>.empty();

  @override
  Stream<ChatStatus> get streamingStateChangedEvents =>
      const Stream<ChatStatus>.empty();

  @override
  Stream<AvatarStatusAnimation> get avatarAnimationChangedEvents =>
      const Stream<AvatarStatusAnimation>.empty();

  @override
  Stream<TalkingPhase> get talkingStateChangedEvents =>
      const Stream<TalkingPhase>.empty();

  @override
  Stream<DemoScript> get demoScriptChangedEvents =>
      const Stream<DemoScript>.empty();

  @override
  void dispose() {}

  @override
  void emitAvatarAnimationChanged(AvatarStatusAnimation statusAnimation) {}

  @override
  void emitChatChanged(String chatId) {}

  @override
  void emitDemoScriptChanged(DemoScript script) {}

  @override
  void emitNewChatEntry(
    ChatEntry entry,
    String chatId,
    AvatarConfig currentAvatarConfig,
  ) {}

  @override
  void emitStreamingStateChanged(ChatStatus status) {}

  @override
  void emitTalkingStateChanged(TalkingPhase phase) {}
}
