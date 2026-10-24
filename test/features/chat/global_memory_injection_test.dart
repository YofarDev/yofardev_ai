import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    Intl.defaultLocale = 'en';
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
      // Memory and the transient context message both sit before the
      // current user message; everything between them is system-role.
      expect(
        lastUserIndex,
        greaterThan(memoryIndex),
        reason: 'memory must precede the current user message',
      );
      expect(
        capturedMessages
            .sublist(memoryIndex, lastUserIndex)
            .every((LlmMessage m) => m.role == LlmMessageRole.system),
        isTrue,
        reason:
            'only transient system context may sit between memory and '
            'the current user message',
      );

      // History before the memory message is untouched
      expect(capturedMessages.first.role, LlmMessageRole.user);
      expect(capturedMessages.first.body, contains('previous message'));
    },
  );

  Chat slimPayloadChat() => Chat(
    id: 'chat-id',
    entries: <ChatEntry>[
      ChatEntry(
        id: 'u1',
        entryType: EntryType.user,
        body:
            "Date : vendredi 23 octobre 2026 - 14:30\nAvatar Config :\n{\n\"background\": \"beach\",\n}\nUser : \n'''hello'''",
        timestamp: DateTime(2026),
        attachedImage: '/tmp/old.png',
      ),
      ChatEntry(
        id: 'a1',
        entryType: EntryType.yofardev,
        body: '{"text": "hi there", "mood": "happy"}',
        timestamp: DateTime(2026),
      ),
      ChatEntry(
        id: 'u2',
        entryType: EntryType.user,
        body:
            "Date : vendredi 23 octobre 2026 - 14:31\nAvatar Config :\n{\n}\nUser : \n'''second question'''",
        timestamp: DateTime(2026),
        attachedImage: '/tmp/new.png',
      ),
      ChatEntry(
        id: 'a2',
        entryType: EntryType.yofardev,
        body: '',
        timestamp: DateTime(2026),
      ),
    ],
  );

  Future<void> runSlim(ChatStreamingService service) {
    return service.streamResponse(
      prompt: 'second question',
      onlyText: true,
      avatar: const Avatar(),
      currentChat: slimPayloadChat(),
      language: 'en',
      functionCallingEnabled: false,
      onChatUpdated: (_) {},
      onStreamComplete: (_) {},
      onError: (_) {},
    );
  }

  test(
    'request payloads are slimmed: wrapper stripped, JSON extracted, single image',
    () async {
      final ChatStreamingService service = buildService(
        FakeGlobalMemoryService(null),
      );
      await runSlim(service);

      final List<LlmMessage> sent = capturedMessages;
      final List<LlmMessage> conversation = sent
          .where((LlmMessage m) => m.role != LlmMessageRole.system)
          .toList();
      // User wrappers stripped:
      expect(
        conversation.any((LlmMessage m) => m.body.contains("'''")),
        isFalse,
      );
      expect(
        conversation.any((LlmMessage m) => m.body.contains('Avatar Config')),
        isFalse,
      );
      // Visible prompts only:
      expect(sent.any((LlmMessage m) => m.body == 'hello'), isTrue);
      expect(sent.any((LlmMessage m) => m.body == 'second question'), isTrue);
      // Assistant JSON extracted to clean text:
      expect(sent.any((LlmMessage m) => m.body == 'hi there'), isTrue);
      expect(sent.any((LlmMessage m) => m.body.contains('"mood"')), isFalse);
      // Only the LATEST entry keeps its image:
      expect(sent.where((LlmMessage m) => m.attachedFile != null).length, 1);
      expect(
        sent.firstWhere((LlmMessage m) => m.attachedFile != null).attachedFile,
        '/tmp/new.png',
      );
    },
  );

  test(
    'current avatar config and date ride a transient system message',
    () async {
      final ChatStreamingService service = buildService(
        FakeGlobalMemoryService(null),
      );
      await runSlim(service);

      final LlmMessage contextMessage = capturedMessages.firstWhere(
        (LlmMessage m) =>
            m.role == LlmMessageRole.system && m.body.contains('Avatar Config'),
      );
      // Avatar() defaults to livingRoom, not beach
      expect(contextMessage.body, contains('livingRoom'));
      expect(contextMessage.body, contains('Date :'));
    },
  );

  test('injects no memory content when memory is empty', () async {
    final ChatStreamingService service = buildService(
      FakeGlobalMemoryService(null),
    );

    await runStream(service);

    // The transient avatar/date context still rides a system message, but
    // no global-memory content may appear.
    expect(
      capturedMessages.any(
        (LlmMessage m) => m.body.contains('Global memory about the user'),
      ),
      isFalse,
    );
    expect(
      capturedMessages.any(
        (LlmMessage m) =>
            m.role == LlmMessageRole.system && m.body.contains('Avatar Config'),
      ),
      isTrue,
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
