import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/repositories/chat_repository.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/sound/sound.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockLlmService extends Mock implements LlmServiceInterface {}

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

/// Records the text and voice effect of every sentence it is asked to say.
class _RecordingTtsQueue extends Mock implements TtsQueueService {
  final List<(String, VoiceEffect)> enqueued = <(String, VoiceEffect)>[];

  @override
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
    List<AvatarCue> cues = const <AvatarCue>[],
  }) async {
    enqueued.add((text, voiceEffect));
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
  late _RecordingTtsQueue queue;

  /// One controller per promptModelStream call, in call order.
  late List<StreamController<LlmStreamChunk>> requests;
  late List<String> errors;

  setUp(() {
    chatRepository = _MockChatRepository();
    llmService = _MockLlmService();
    interruption = InterruptionService();
    queue = _RecordingTtsQueue();
    requests = <StreamController<LlmStreamChunk>>[];
    errors = <String>[];

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

  /// Starts a spoken reply (not text-only, so every sentence is enqueued).
  Future<void> reply({
    required Avatar avatar,
    Avatar Function()? currentAvatar,
  }) =>
      ChatStreamingService(
        chatRepository: chatRepository,
        llmService: llmService,
        streamProcessor: _SentencePerChunkProcessor(),
        promptDatasource: _FakePromptDatasource(),
        interruptionService: interruption,
        chatEntryService: _FakeChatEntryService(),
        ttsQueueManager: queue,
      ).streamResponse(
        prompt: 'Hi',
        onlyText: false,
        avatar: avatar,
        currentChat: const Chat(id: 'chat-1'),
        language: 'en',
        onChatUpdated: (_) {},
        onStreamComplete: (_) {},
        onError: errors.add,
        currentAvatar: currentAvatar,
      );

  Future<void> waitFor(bool Function() condition) async {
    for (int i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(condition(), isTrue, reason: 'condition never met');
  }

  /// The reply's provider request, once the reply listens to it.
  Future<StreamController<LlmStreamChunk>> providerRequest() async {
    await waitFor(() => requests.isNotEmpty && requests.last.hasListener);
    return requests.last;
  }

  void say(StreamController<LlmStreamChunk> request, String sentence) =>
      request.add(LlmStreamChunk.text(content: sentence, isComplete: false));

  void end(StreamController<LlmStreamChunk> request) {
    request.add(const LlmStreamChunk.complete());
    unawaited(request.close());
  }

  test('a reply whose currentAvatar() wears robocop enqueues '
      'VoiceEffect.robocop', () async {
    final Future<void> done = reply(
      avatar: const Avatar(),
      currentAvatar: () => const Avatar(costume: AvatarCostume.robocop),
    );
    final StreamController<LlmStreamChunk> request = await providerRequest();
    say(request, 'I am the law.');
    say(request, 'Come quietly.');
    end(request);
    await done;

    expect(queue.enqueued, <(String, VoiceEffect)>[
      ('I am the law.', VoiceEffect.robocop),
      ('Come quietly.', VoiceEffect.robocop),
    ]);
    expect(errors, isEmpty);
  });

  test('a costume put on mid-reply voices the following sentences', () async {
    Avatar worn = const Avatar();
    final Future<void> done = reply(
      avatar: const Avatar(),
      currentAvatar: () => worn,
    );
    final StreamController<LlmStreamChunk> request = await providerRequest();
    say(request, 'Suiting up.');
    await waitFor(() => queue.enqueued.length == 1);
    // What a change_avatar tool call does between two sentences.
    worn = const Avatar(costume: AvatarCostume.batman);
    say(request, 'I am vengeance.');
    end(request);
    await done;

    expect(queue.enqueued, <(String, VoiceEffect)>[
      ('Suiting up.', VoiceEffect.none),
      ('I am vengeance.', VoiceEffect.batman),
    ]);
  });

  test('without currentAvatar the reply avatar picks the voice', () async {
    final Future<void> done = reply(
      avatar: const Avatar(costume: AvatarCostume.batman),
    );
    final StreamController<LlmStreamChunk> request = await providerRequest();
    say(request, 'I am the night.');
    end(request);
    await done;

    expect(queue.enqueued, <(String, VoiceEffect)>[
      ('I am the night.', VoiceEffect.batman),
    ]);
  });
}
