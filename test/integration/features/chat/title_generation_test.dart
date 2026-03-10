import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_title_cubit.dart';

class TrackingMockChatRepository implements ChatRepository {
  Chat? currentChat;
  Chat? updatedChat;
  String? updatedChatId;
  int updateCallCount = 0;

  @override
  Future<Either<Exception, Chat>> createNewChat({String? language}) async {
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat>> getCurrentChat() async {
    if (currentChat != null) {
      return Right<Exception, Chat>(currentChat!);
    }
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat?>> getChat(String id) async {
    return Right<Exception, Chat?>(currentChat);
  }

  @override
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    updatedChatId = id;
    this.updatedChat = updatedChat;
    updateCallCount++;
    if (currentChat != null && currentChat!.id == id) {
      currentChat = updatedChat;
    }
    return const Right<Exception, void>(null);
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
  Future<Either<Exception, List<ChatEntry>>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    return Right<Exception, List<ChatEntry>>(<ChatEntry>[
      ChatEntry(
        id: 'test',
        entryType: EntryType.yofardev,
        body: 'response',
        timestamp: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return const Right<Exception, void>(null);
  }
}

class MockLlmService extends Mock implements LlmService {}

void main() {
  group('Title Generation Integration Tests', () {
    late TrackingMockChatRepository mockChatRepository;
    late MockLlmService mockLlmService;
    late ChatTitleCubit cubit;

    setUp(() {
      mockChatRepository = TrackingMockChatRepository();
      mockLlmService = MockLlmService();
      cubit = ChatTitleCubit(
        chatRepository: mockChatRepository,
        llmService: mockLlmService,
      );
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
      expect(cubit.state.generatingChatIds, isEmpty);
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
      expect(cubit.state.generatingChatIds, isEmpty);
    });
  });
}
