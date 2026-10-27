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
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockLlmService extends Mock implements LlmServiceInterface {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _FakeInterruptionService implements InterruptionService {
  @override
  Stream<void> get interruptionStream => const Stream<void>.empty();

  @override
  Future<void> interrupt() async {}

  @override
  void reset() {}

  @override
  bool get isInterrupted => false;

  @override
  void dispose() {}
}

class _FakePromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'system';
}

/// Drains the LLM stream (so tool-call deltas are captured) and emits no
/// sentences.
class _DrainingStreamProcessor implements StreamProcessorService {
  @override
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    await for (final LlmStreamChunk _ in llmChunks) {}
  }
}

class _FakeChatEntryService implements ChatEntryService {
  @override
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async => ChatEntry(
    id: 'user',
    entryType: EntryType.user,
    body: prompt,
    timestamp: DateTime.now(),
  );
}

/// A tool that records when it runs and returns [result].
class _FakeTool extends AgentTool {
  _FakeTool(this.log, {this.result = 'sunny', this.gate});

  final List<String> log;
  final Object result;

  /// When set, each run waits for it after logging (a slow tool).
  final Future<void>? gate;

  @override
  String get name => 'fakeTool';

  @override
  String get description => 'A fake tool';

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
    return result;
  }
}

/// Registry exposing only the fake tool.
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
  late List<String> log;

  setUp(() {
    chatRepository = _MockChatRepository();
    llmService = _MockLlmService();
    log = <String>[];

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
    int round = 0;
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
      // Round 1 calls the tool, round 2 answers.
      final List<LlmStreamChunk> chunks = round++ == 0
          ? const <LlmStreamChunk>[
              LlmStreamChunk.toolCallDelta(
                index: 0,
                id: 'call_1',
                name: 'fakeTool',
                argumentsDelta: '{}',
              ),
              LlmStreamChunk.complete(),
            ]
          : const <LlmStreamChunk>[LlmStreamChunk.complete()];
      return Stream<LlmStreamChunk>.fromIterable(chunks);
    });
    when(
      () => chatRepository.updateChat(
        id: any(named: 'id'),
        updatedChat: any(named: 'updatedChat'),
      ),
    ).thenAnswer((_) async => Result<void>.ok(null));
  });

  ChatStreamingService buildService(
    AgentTool tool, {
    InterruptionService? interruptionService,
  }) => ChatStreamingService(
    chatRepository: chatRepository,
    llmService: llmService,
    streamProcessor: _DrainingStreamProcessor(),
    promptDatasource: _FakePromptDatasource(),
    interruptionService: interruptionService ?? _FakeInterruptionService(),
    chatEntryService: _FakeChatEntryService(),
    toolRegistry: _FakeToolRegistry(tool),
    settingsRepository: _MockSettingsRepository(),
  );

  Future<void> run(
    ChatStreamingService service, {
    void Function(String error)? onError,
  }) => service.streamResponse(
    prompt: 'Weather?',
    onlyText: true,
    avatar: const Avatar(),
    currentChat: const Chat(id: 'chat-1'),
    language: 'en',
    onChatUpdated: (_) {},
    onStreamComplete: (_) => log.add('complete'),
    onError: onError ?? (String e) => log.add('error'),
    onToolActivity: (String? name) => log.add('tool:$name'),
  );

  test('reports the tool before it runs, then null once it finished', () async {
    await run(buildService(_FakeTool(log)));

    expect(log, <String>['tool:fakeTool', 'execute', 'tool:null', 'complete']);
  });

  test('clears the running tool before reporting an error', () async {
    // A result that cannot be JSON-encoded makes the tool round throw after
    // the tool started.
    await run(buildService(_FakeTool(log, result: Object())));

    expect(log, <String>['tool:fakeTool', 'execute', 'tool:null', 'error']);
  });

  test('never reports a tool when none is called', () async {
    when(
      () => llmService.promptModelStream(
        messages: any(named: 'messages'),
        systemPrompt: any(named: 'systemPrompt'),
        config: any(named: 'config'),
        returnJson: any(named: 'returnJson'),
        debugLogs: any(named: 'debugLogs'),
        tools: any(named: 'tools'),
      ),
    ).thenAnswer(
      (_) => Stream<LlmStreamChunk>.fromIterable(const <LlmStreamChunk>[
        LlmStreamChunk.complete(),
      ]),
    );

    await run(buildService(_FakeTool(log)));

    expect(log, <String>['complete']);
  });

  test('an interruption clears the running tool at once and no later tool '
      'is reported', () async {
    // Round 1 calls the tool twice.
    when(
      () => llmService.promptModelStream(
        messages: any(named: 'messages'),
        systemPrompt: any(named: 'systemPrompt'),
        config: any(named: 'config'),
        returnJson: any(named: 'returnJson'),
        debugLogs: any(named: 'debugLogs'),
        tools: any(named: 'tools'),
      ),
    ).thenAnswer(
      (_) => Stream<LlmStreamChunk>.fromIterable(const <LlmStreamChunk>[
        LlmStreamChunk.toolCallDelta(
          index: 0,
          id: 'call_1',
          name: 'fakeTool',
          argumentsDelta: '{}',
        ),
        LlmStreamChunk.toolCallDelta(
          index: 1,
          id: 'call_2',
          name: 'fakeTool',
          argumentsDelta: '{}',
        ),
        LlmStreamChunk.complete(),
      ]),
    );
    final InterruptionService interruption = InterruptionService();
    addTearDown(interruption.dispose);
    final Completer<void> toolGate = Completer<void>();
    final _FakeTool tool = _FakeTool(log, gate: toolGate.future);

    final Future<void> reply = run(
      buildService(tool, interruptionService: interruption),
    );
    while (!log.contains('execute')) {
      await Future<void>.delayed(Duration.zero);
    }

    await interruption.interrupt();
    await Future<void>.delayed(Duration.zero);
    // Cleared while the (uncancellable) tool is still running.
    expect(log, <String>['tool:fakeTool', 'execute', 'tool:null']);

    toolGate.complete();
    await reply;

    expect(log, <String>[
      'tool:fakeTool',
      'execute',
      'tool:null',
      'execute', // the second call still runs, but is not reported
      'complete',
    ]);
  });
}
