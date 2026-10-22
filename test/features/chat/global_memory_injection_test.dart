import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLlmService extends Mock implements LlmServiceInterface {}

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
    // Empty implementation: no sentence chunks for these tests
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
      id: 'user-entry-id',
      entryType: EntryType.user,
      body: prompt,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
  }
}

/// Fake memory service returning a configurable message
class FakeGlobalMemoryService implements GlobalMemoryService {
  FakeGlobalMemoryService(this.message);

  final LlmMessage? message;

  @override
  Future<LlmMessage?> buildMemoryMessage() async => message;

  @override
  Future<void> updateMemory(Chat chat) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(<LlmMessage>[]);
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(const Chat());
    registerFallbackValue(
      const LlmConfig(
        id: 'fallback',
        label: 'fallback',
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'fallback-model',
      ),
    );
  });

  late MockChatRepository chatRepository;
  late MockLlmService llmService;
  late List<LlmMessage> capturedMessages;
  late List<Chat> updatedChats;

  ChatStreamingService buildService(GlobalMemoryService memoryService) {
    return ChatStreamingService(
      chatRepository: chatRepository,
      llmService: llmService,
      streamProcessor: MockStreamProcessorService(),
      promptDatasource: MockPromptDatasource(),
      interruptionService: MockInterruptionService(),
      chatEntryService: MockChatEntryService(),
      globalMemoryService: memoryService,
    );
  }

  setUp(() {
    chatRepository = MockChatRepository();
    llmService = MockLlmService();
    capturedMessages = <LlmMessage>[];
    updatedChats = <Chat>[];

    when(() => llmService.init()).thenAnswer((_) async {});
    when(() => llmService.getCurrentConfig()).thenReturn(
      const LlmConfig(
        id: 'test',
        label: 'test',
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'test-model',
      ),
    );
    when(
      () => llmService.promptModelStream(
        messages: any(named: 'messages'),
        systemPrompt: any(named: 'systemPrompt'),
        config: any(named: 'config'),
        returnJson: any(named: 'returnJson'),
        debugLogs: any(named: 'debugLogs'),
        tools: any(named: 'tools'),
      ),
    ).thenAnswer((Invocation invocation) {
      capturedMessages =
          invocation.namedArguments[#messages] as List<LlmMessage>;
      return Stream<LlmStreamChunk>.fromIterable(const <LlmStreamChunk>[
        LlmStreamChunk.complete(),
      ]);
    });
    when(
      () => chatRepository.updateChat(
        id: any(named: 'id'),
        updatedChat: any(named: 'updatedChat'),
      ),
    ).thenAnswer((Invocation invocation) async {
      updatedChats.add(invocation.namedArguments[#updatedChat] as Chat);
      return Result<void>.ok(null);
    });
  });

  Future<void> runStream(ChatStreamingService service) {
    return service.streamResponse(
      prompt: 'What do you remember about me?',
      onlyText: true,
      avatar: const Avatar(),
      currentChat: Chat(
        id: 'chat-1',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'old-user',
            entryType: EntryType.user,
            body: "User : \n'''previous message'''",
            timestamp: DateTime.now(),
          ),
        ],
      ),
      language: 'en',
      functionCallingEnabled: false,
      onChatUpdated: (_) {},
      onStreamingUpdate: (_, _) {},
      onStreamComplete: (_) {},
      onError: (_) {},
    );
  }

  test(
    'injects memory system message right before the current user message',
    () async {
      final LlmMessage memoryMessage = LlmMessage(
        role: LlmMessageRole.system,
        body: 'Global memory about the user...\n- Likes hiking',
      );
      final ChatStreamingService service = buildService(
        FakeGlobalMemoryService(memoryMessage),
      );

      await runStream(service);

      expect(capturedMessages, isNotEmpty);
      final int memoryIndex = capturedMessages.indexWhere(
        (LlmMessage m) => m.role == LlmMessageRole.system,
      );
      expect(memoryIndex, greaterThan(0), reason: 'memory must follow history');

      // Find the last user message: it must be immediately after the memory
      final int lastUserIndex = capturedMessages.lastIndexWhere(
        (LlmMessage m) => m.role == LlmMessageRole.user,
      );
      expect(
        lastUserIndex,
        memoryIndex + 1,
        reason: 'memory must sit immediately before the current user message',
      );

      // History before the memory message is untouched
      expect(capturedMessages.first.role, LlmMessageRole.user);
      expect(capturedMessages.first.body, contains('previous message'));
    },
  );

  test('does not inject anything when memory is empty', () async {
    final ChatStreamingService service = buildService(
      FakeGlobalMemoryService(null),
    );

    await runStream(service);

    expect(
      capturedMessages.where((LlmMessage m) => m.role == LlmMessageRole.system),
      isEmpty,
    );
  });

  test('never persists the memory message into chat entries', () async {
    final LlmMessage memoryMessage = LlmMessage(
      role: LlmMessageRole.system,
      body: 'Global memory about the user...',
    );
    final ChatStreamingService service = buildService(
      FakeGlobalMemoryService(memoryMessage),
    );

    await runStream(service);

    expect(updatedChats, isNotEmpty);
    for (final Chat chat in updatedChats) {
      expect(
        chat.entries.where(
          (ChatEntry e) => e.body.contains('Global memory about the user'),
        ),
        isEmpty,
        reason: 'memory must stay request-scoped',
      );
    }
  });
}
