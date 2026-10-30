import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/audio/voice_effects_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/sound/sound.dart';
import 'package:yofardev_ai/features/talking/data/repositories/talking_repository_impl.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

class MockRigChatRepository extends Mock implements ChatRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class MockRigLlmService extends Mock implements LlmServiceInterface {}

class _MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class _MockChatTitleService extends Mock implements ChatTitleService {}

class _MockGlobalMemoryService extends Mock implements GlobalMemoryService {}

class _MockDemoService extends Mock implements DemoService {}

class _FakePromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'system';
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

/// Records every sentence it is asked to speak; [synthesize] then waits for
/// [gate] (null: never answers) or throws when [fails].
class RecordingSynthesizer implements TtsSynthesizer {
  final List<String> texts = <String>[];
  bool fails = false;
  Completer<String>? gate;

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    texts.add(text);
    if (fails) {
      throw StateError('Supertonic models missing');
    }
    return (gate ??= Completer<String>()).future;
  }

  @override
  Future<void> delete(String path) async {}
}

/// A real [ChatCubit] (over a real [ChatStreamingService] and TTS queue) and
/// a real [TalkingCubit], sharing one [AppLifecycleService] and
/// [InterruptionService]. The LLM is fake: every request is a stream the
/// test feeds through [requests] (it stalls until then).
class RealReplyRig {
  RealReplyRig() {
    when(() => llm.init()).thenAnswer((_) async {});
    when(() => llm.getCurrentConfig()).thenReturn(
      const LlmConfig(
        id: 'test',
        label: 'test',
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'test-model',
      ),
    );
    when(
      () => llm.promptModelStream(
        messages: any(named: 'messages'),
        systemPrompt: any(named: 'systemPrompt'),
        config: any(named: 'config'),
        returnJson: any(named: 'returnJson'),
        debugLogs: any(named: 'debugLogs'),
        tools: any(named: 'tools'),
      ),
    ).thenAnswer((_) {
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
    final _MockGlobalMemoryService memory = _MockGlobalMemoryService();
    when(() => memory.updateMemory(any())).thenAnswer((_) async {});
    final _MockChatTitleService titles = _MockChatTitleService();
    when(() => titles.shouldGenerateTitle(any())).thenReturn(false);

    ttsQueue = TtsQueueService(
      ttsSynthesizer: synthesizer,
      interruptionService: interruption,
      voiceEffectsService: VoiceEffectsService(),
    );
    chat = ChatCubit(
      chatRepository: chatRepository,
      settingsRepository: _MockSettingsRepository(),
      avatarAnimationService: _MockAvatarAnimationService(),
      chatTitleService: titles,
      chatStreamingService: ChatStreamingService(
        chatRepository: chatRepository,
        llmService: llm,
        streamProcessor: StreamProcessorService(),
        promptDatasource: _FakePromptDatasource(),
        interruptionService: interruption,
        chatEntryService: _FakeChatEntryService(),
        ttsQueueManager: ttsQueue,
      ),
      appLifecycleService: lifecycle,
      globalMemoryService: memory,
      demoService: _MockDemoService(),
    );
    talking = TalkingCubit(
      TalkingRepositoryImpl(),
      interruption,
      playback,
      lifecycle,
      ttsQueue,
    );
  }

  static void registerFallbacks() {
    registerFallbackValue(const Chat());
    registerFallbackValue(<LlmMessage>[]);
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(
      const LlmConfig(
        id: 'fallback',
        label: 'fallback',
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'fallback-model',
      ),
    );
  }

  final AppLifecycleService lifecycle = AppLifecycleService();
  final InterruptionService interruption = InterruptionService();
  final RecordingSynthesizer synthesizer = RecordingSynthesizer();
  final TtsPlaybackService playback = TtsPlaybackService(
    TalkingRepositoryImpl(),
  );
  final MockRigLlmService llm = MockRigLlmService();
  final MockRigChatRepository chatRepository = MockRigChatRepository();

  /// One stalled provider stream per LLM request, in order.
  final List<StreamController<LlmStreamChunk>> requests =
      <StreamController<LlmStreamChunk>>[];

  late final TtsQueueService ttsQueue;
  late final ChatCubit chat;
  late final TalkingCubit talking;

  /// Sends one whole JSON reply on request [index] and ends it.
  void answer(int index, String message) {
    requests[index]
      ..add(
        LlmStreamChunk.text(
          content: '{"message": "$message"}',
          isComplete: true,
        ),
      )
      ..add(const LlmStreamChunk.complete());
    unawaited(requests[index].close());
  }

  Future<void> close() async {
    await chat.close();
    await talking.close();
    ttsQueue.dispose();
    playback.dispose();
    interruption.dispose();
  }
}
