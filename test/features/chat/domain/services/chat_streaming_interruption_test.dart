import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/agent/tool_registry.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/core/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockLlmService extends Mock implements LlmServiceInterface {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _FakePromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'system';
}

/// Each text chunk is one sentence.
class _SentencePerChunkProcessor implements StreamProcessorService {
  @override
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    int index = 0;
    await for (final LlmStreamChunk chunk in llmChunks) {
      final String? text = chunk.maybeWhen(
        text: (String content, bool _) => content,
        orElse: () => null,
      );
      if (text != null) {
        yield SentenceChunk.sentence(text: text, index: index++);
      }
    }
  }
}

class _FakeChatEntryService implements ChatEntryService {
  @override
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async => ChatEntry(
    id: 'user-$prompt',
    entryType: EntryType.user,
    body: prompt,
    timestamp: DateTime.now(),
  );
}

/// A tool that waits for [gate] (a slow search) and records each run.
class _SlowTool extends AgentTool {
  _SlowTool(this.log, this.gate);

  final List<String> log;
  final Future<void> gate;

  @override
  String get name => 'slowTool';

  @override
  String get description => 'A slow tool';

  @override
  List<Parameter> get parameters => <Parameter>[];

  @override
  Map<String, String> get requiredConfigKeys => <String, String>{};

  @override
  Future<dynamic> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    log.add('execute');
    await gate;
    return 'sunny';
  }
}

class _FakeToolRegistry extends ToolRegistry {
  _FakeToolRegistry(AgentTool tool)
    : _tool = tool,
      super(
        appLifecycleService: AppLifecycleService(),
        tools: <AgentTool>[tool],
      );

  final AgentTool _tool;

  @override
  Future<List<FunctionInfo>> getFunctionInfos(
    SettingsRepository settingsRepository,
  ) async => <FunctionInfo>[_tool.toFunctionInfo()];
}

/// Lets queued microtasks and stream deliveries run.
Future<void> _settle() async {
  for (int i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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

  late _MockChatRepository chatRepository;
  late _MockLlmService llmService;
  late InterruptionService interruption;
  late List<String> log;

  /// One controller per promptModelStream call, in call order.
  late List<StreamController<LlmStreamChunk>> requests;

  setUp(() {
    chatRepository = _MockChatRepository();
    llmService = _MockLlmService();
    interruption = InterruptionService();
    log = <String>[];
    requests = <StreamController<LlmStreamChunk>>[];

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
    ).thenAnswer((_) {
      // A provider that stalls until the test feeds it.
      final StreamController<LlmStreamChunk> request =
          StreamController<LlmStreamChunk>();
      requests.add(request);
      return request.stream;
    });
    when(
      () => chatRepository.updateChat(
        id: any(named: 'id'),
        updatedChat: any(named: 'updatedChat'),
      ),
    ).thenAnswer((_) async => Result<void>.ok(null));
  });

  tearDown(() => interruption.dispose());

  ChatStreamingService buildService({AgentTool? tool}) => ChatStreamingService(
    chatRepository: chatRepository,
    llmService: llmService,
    streamProcessor: _SentencePerChunkProcessor(),
    promptDatasource: _FakePromptDatasource(),
    interruptionService: interruption,
    chatEntryService: _FakeChatEntryService(),
    toolRegistry: tool == null ? null : _FakeToolRegistry(tool),
    settingsRepository: tool == null ? null : _MockSettingsRepository(),
  );

  /// The chat each reply ended with, by reply name.
  final Map<String, Chat> finals = <String, Chat>{};

  Future<void> run(
    ChatStreamingService service,
    String name, {
    Chat currentChat = const Chat(id: 'chat-1'),
  }) => service.streamResponse(
    prompt: name,
    onlyText: true,
    avatar: const Avatar(),
    currentChat: currentChat,
    language: 'en',
    onChatUpdated: (Chat chat) {
      final String body = chat.entries.last.body;
      final String entry = '$name:update:$body';
      if (chat.entries.last.entryType == EntryType.yofardev &&
          body.isNotEmpty &&
          !log.contains(entry)) {
        log.add(entry);
      }
    },
    onStreamComplete: (Chat chat) {
      finals[name] = chat;
      log.add('$name:complete');
    },
    onError: (String e) => log.add('$name:error'),
  );

  Future<void> waitFor(bool Function() condition) async {
    for (int i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(condition(), isTrue, reason: 'condition never met');
  }

  test('an interruption before the first chunk ends the reply at once and '
      'cancels the provider stream', () async {
    final ChatStreamingService service = buildService();
    bool done = false;
    final Future<void> reply = run(
      service,
      'A',
    ).whenComplete(() => done = true);
    await waitFor(() => requests.isNotEmpty && requests[0].hasListener);

    await interruption.interrupt();
    await _settle();

    expect(done, isTrue, reason: 'the reply must not wait for a chunk');
    expect(requests[0].hasListener, isFalse, reason: 'request cancelled');
    expect(log, <String>['A:complete']);
    await reply;
  });

  test('an interruption during setup sends no request', () async {
    final Completer<void> init = Completer<void>();
    when(() => llmService.init()).thenAnswer((_) => init.future);
    final ChatStreamingService service = buildService();
    final Future<void> reply = run(service, 'A');
    await _settle();

    // Stop while the LLM service is still initialising.
    await interruption.interrupt();
    init.complete();
    await reply.timeout(const Duration(seconds: 1));

    expect(requests, isEmpty, reason: 'no provider request was started');
    verifyNever(
      () => llmService.promptModelStream(
        messages: any(named: 'messages'),
        systemPrompt: any(named: 'systemPrompt'),
        config: any(named: 'config'),
        returnJson: any(named: 'returnJson'),
        debugLogs: any(named: 'debugLogs'),
        tools: any(named: 'tools'),
      ),
    );
    expect(log, <String>['A:complete']);
  });

  test('an interruption mid-reply drops the rest of the stream', () async {
    final ChatStreamingService service = buildService();
    final Future<void> reply = run(service, 'A');
    await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
    requests[0].add(
      const LlmStreamChunk.text(content: 'Hello.', isComplete: false),
    );
    await waitFor(() => log.isNotEmpty);

    await interruption.interrupt();
    await reply.timeout(const Duration(seconds: 1));

    expect(requests[0].hasListener, isFalse);
    expect(log, <String>['A:update:Hello.', 'A:complete']);
  });

  test(
    'an interruption while a tool runs skips the pending tool round',
    () async {
      final Completer<void> toolGate = Completer<void>();
      final _SlowTool tool = _SlowTool(log, toolGate.future);
      final ChatStreamingService service = buildService(tool: tool);
      {
        bool done = false;
        final Future<void> reply = run(
          service,
          'A',
        ).whenComplete(() => done = true);
        await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
        requests[0]
          ..add(
            const LlmStreamChunk.toolCallDelta(
              index: 0,
              id: 'call_1',
              name: 'slowTool',
              argumentsDelta: '{}',
            ),
          )
          ..add(
            const LlmStreamChunk.toolCallDelta(
              index: 1,
              id: 'call_2',
              name: 'slowTool',
              argumentsDelta: '{}',
            ),
          );
        unawaited(requests[0].close());
        await waitFor(() => log.contains('execute'));

        await interruption.interrupt();
        await _settle();

        // Ended without waiting for the running tool; the second call and the
        // answer round never start.
        expect(done, isTrue);
        expect(log, <String>['execute', 'A:complete']);
        expect(requests, hasLength(1));

        toolGate.complete();
        await _settle();
        await reply;
        expect(log, <String>['execute', 'A:complete']);
        expect(requests, hasLength(1));
      }
    },
  );

  test('a stopped reply never resumes after the next reply resets the '
      'interruption', () async {
    final ChatStreamingService service = buildService();
    final Future<void> first = run(service, 'A');
    await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
    final StreamController<LlmStreamChunk> firstRequest = requests[0];

    // Stop, then send the next prompt straight away: the new reply resets
    // the shared interruption flag.
    await interruption.interrupt();
    final Future<void> second = run(service, 'B');
    await waitFor(() => requests.length == 2 && requests[1].hasListener);
    await first.timeout(const Duration(seconds: 1));

    // The old provider stream was cancelled: a late chunk reaches no one.
    expect(firstRequest.hasListener, isFalse);
    firstRequest.add(
      const LlmStreamChunk.text(content: 'Stale.', isComplete: false),
    );
    requests[1]
      ..add(const LlmStreamChunk.text(content: 'Fresh.', isComplete: false))
      ..add(const LlmStreamChunk.complete());
    unawaited(requests[1].close());
    await second.timeout(const Duration(seconds: 1));

    expect(log, <String>['A:complete', 'B:update:Fresh.', 'B:complete']);
  });

  test('a reply still in its tool when the next one starts does not '
      'resume', () async {
    final Completer<void> toolGate = Completer<void>();
    final ChatStreamingService service = buildService(
      tool: _SlowTool(log, toolGate.future),
    );
    final Future<void> first = run(service, 'A');
    await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
    requests[0].add(
      const LlmStreamChunk.toolCallDelta(
        index: 0,
        id: 'call_1',
        name: 'slowTool',
        argumentsDelta: '{}',
      ),
    );
    unawaited(requests[0].close());
    await waitFor(() => log.contains('execute'));

    await interruption.interrupt();
    final Future<void> second = run(service, 'B');
    await waitFor(() => requests.length == 2);
    toolGate.complete();
    await first.timeout(const Duration(seconds: 1));
    await _settle();

    // A's answer round (a third request) never starts.
    expect(requests, hasLength(2));
    requests[1].add(const LlmStreamChunk.complete());
    unawaited(requests[1].close());
    await second.timeout(const Duration(seconds: 1));
    expect(log, <String>['execute', 'A:complete', 'B:complete']);
  });

  group('no empty reply is stored', () {
    /// The chat last persisted through the repository.
    Chat persisted() =>
        verify(
              () => chatRepository.updateChat(
                id: any(named: 'id'),
                updatedChat: captureAny(named: 'updatedChat'),
              ),
            ).captured.last
            as Chat;

    List<EntryType> types(Chat chat) =>
        chat.entries.map((ChatEntry e) => e.entryType).toList();

    test('Stop before the first sentence keeps only the prompt', () async {
      final ChatStreamingService service = buildService();
      final Future<void> reply = run(service, 'Hello');
      await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
      await interruption.interrupt();
      await reply.timeout(const Duration(seconds: 1));

      final Chat saved = persisted();
      expect(types(finals['Hello']!), <EntryType>[EntryType.user]);
      expect(types(saved), <EntryType>[EntryType.user]);
      expect(saved.entries.single.body, 'Hello');
      // Still a first exchange: the title gets generated as before.
      expect(
        ChatTitleService(
          chatRepository: chatRepository,
          llmService: llmService,
        ).shouldGenerateTitle(saved),
        isTrue,
      );
    });

    test('the next request carries no empty assistant message', () async {
      final ChatStreamingService service = buildService();
      final Future<void> first = run(service, 'Hello');
      await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
      await interruption.interrupt();
      await first.timeout(const Duration(seconds: 1));

      final Future<void> second = run(
        service,
        'Again',
        currentChat: finals['Hello']!,
      );
      await waitFor(() => requests.length == 2);
      final List<LlmMessage> messages =
          verify(
                () => llmService.promptModelStream(
                  messages: captureAny(named: 'messages'),
                  systemPrompt: any(named: 'systemPrompt'),
                  config: any(named: 'config'),
                  returnJson: any(named: 'returnJson'),
                  debugLogs: any(named: 'debugLogs'),
                  tools: any(named: 'tools'),
                ),
              ).captured.last
              as List<LlmMessage>;
      expect(
        messages.where(
          (LlmMessage m) =>
              m.role == LlmMessageRole.assistant && m.body.trim().isEmpty,
        ),
        isEmpty,
      );
      expect(
        messages
            .where((LlmMessage m) => m.role == LlmMessageRole.user)
            .map((LlmMessage m) => m.body),
        <String>['Hello', 'Again'],
      );
      requests[1].add(const LlmStreamChunk.complete());
      unawaited(requests[1].close());
      await second.timeout(const Duration(seconds: 1));
    });

    test('Stop after a sentence keeps the reply', () async {
      final ChatStreamingService service = buildService();
      final Future<void> reply = run(service, 'Hello');
      await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
      requests[0].add(
        const LlmStreamChunk.text(content: 'Hi there.', isComplete: false),
      );
      await waitFor(() => log.isNotEmpty);
      await interruption.interrupt();
      await reply.timeout(const Duration(seconds: 1));

      final Chat saved = persisted();
      expect(types(saved), <EntryType>[EntryType.user, EntryType.yofardev]);
      expect(saved.entries.last.body, 'Hi there.');
    });

    test('a reply that ends without a word stores only the prompt', () async {
      final ChatStreamingService service = buildService();
      final Future<void> reply = run(service, 'Hello');
      await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
      requests[0].add(const LlmStreamChunk.complete());
      unawaited(requests[0].close());
      await reply.timeout(const Duration(seconds: 1));

      expect(types(persisted()), <EntryType>[EntryType.user]);
    });

    test('Stop before the answer round keeps the prompt and the tool '
        'entries', () async {
      final ChatStreamingService service = buildService(
        tool: _SlowTool(log, Future<void>.value()),
      );
      final Future<void> reply = run(service, 'Weather?');
      await waitFor(() => requests.isNotEmpty && requests[0].hasListener);
      requests[0].add(
        const LlmStreamChunk.toolCallDelta(
          index: 0,
          id: 'call_1',
          name: 'slowTool',
          argumentsDelta: '{}',
        ),
      );
      unawaited(requests[0].close());
      // The tool ran; the answer round is waiting for its first chunk.
      await waitFor(() => requests.length == 2 && requests[1].hasListener);
      await interruption.interrupt();
      await reply.timeout(const Duration(seconds: 1));

      expect(types(persisted()), <EntryType>[
        EntryType.user,
        EntryType.functionCalling,
      ]);
    });
  });
}
