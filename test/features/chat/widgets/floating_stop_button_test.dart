import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_queue_service.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/chat/widgets/floating_stop_button.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';

class MockAvatarRepository extends Mock implements AvatarRepository {}

class MockDemoService extends Mock implements DemoService {}

class MockChatRepository implements ChatRepository {
  @override
  Future<Result<void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<Chat>> createNewChat({String? language}) async {
    return Result<Chat>.ok(Chat(id: 'test-id'));
  }

  @override
  Future<Result<Chat>> getCurrentChat() async {
    return Result<Chat>.ok(Chat(id: 'test-id'));
  }

  @override
  Future<Result<Chat?>> getChat(String id) async {
    return Result<Chat?>.ok(Chat(id: 'test-id'));
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
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar) async {
    return Result<void>.ok(null);
  }
}

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<Result<String?>> getLanguage() async {
    return Result<String?>.ok('en');
  }

  @override
  Future<Result<void>> setLanguage(String language) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getSoundEffects() async {
    return Result<bool>.ok(true);
  }

  @override
  Future<Result<void>> setSoundEffects(bool soundEffects) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String?>> getUsername() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setUsername(String username) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String>> getSystemPrompt() async {
    return Result<String>.ok('System prompt');
  }

  @override
  Future<Result<void>> setSystemPrompt(String prompt) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<ChatPersona>> getPersona() async {
    return Result<ChatPersona>.ok(ChatPersona.normal);
  }

  @override
  Future<Result<void>> setPersona(ChatPersona persona) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<TaskLlmConfig>> getTaskLlmConfig() async {
    return Result<TaskLlmConfig>.ok(TaskLlmConfig());
  }

  @override
  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return Result<void>.ok(null);
  }

  // Function Calling Configuration - Google Search
  @override
  Future<Result<String?>> getGoogleSearchKey() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setGoogleSearchKey(String key) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String?>> getGoogleSearchEngineId() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setGoogleSearchEngineId(String id) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getGoogleSearchEnabled() async {
    return Result<bool>.ok(false);
  }

  @override
  Future<Result<void>> setGoogleSearchEnabled(bool enabled) async {
    return Result<void>.ok(null);
  }

  // Function Calling Configuration - OpenWeather
  @override
  Future<Result<String?>> getOpenWeatherKey() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setOpenWeatherKey(String key) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getOpenWeatherEnabled() async {
    return Result<bool>.ok(false);
  }

  @override
  Future<Result<void>> setOpenWeatherEnabled(bool enabled) async {
    return Result<void>.ok(null);
  }

  // Function Calling Configuration - New York Times
  @override
  Future<Result<String?>> getNewYorkTimesKey() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setNewYorkTimesKey(String key) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getNewYorkTimesEnabled() async {
    return Result<bool>.ok(false);
  }

  @override
  Future<Result<void>> setNewYorkTimesEnabled(bool enabled) async {
    return Result<void>.ok(null);
  }

  // Global Memory Configuration
  @override
  Future<Result<bool>> getMemoryEnabled() async {
    return Result<bool>.ok(true);
  }

  @override
  Future<Result<void>> setMemoryEnabled(bool enabled) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getCaptionsEnabled() async => Result<bool>.ok(true);

  @override
  Future<Result<void>> setCaptionsEnabled(bool enabled) async =>
      Result<void>.ok(null);
}

class MockPromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'Test system prompt';
}

class MockGlobalMemoryService implements GlobalMemoryService {
  @override
  Future<LlmMessage?> buildMemoryMessage() async => null;

  @override
  Future<void> updateMemory(Chat chat) async {}
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

class MockStreamProcessorService extends Mock
    implements StreamProcessorService {}

class MockTalkingRepository extends Mock implements TalkingRepository {}

class MockTtsPlaybackService implements TtsPlaybackService {
  @override
  void announceSpeech(Duration lead) {}

  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  @override
  Stream<PlaybackEvent> get events => _controller.stream;

  @override
  Duration get tick => const Duration(milliseconds: 16);

  @override
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    List<AvatarCue> cues = const <AvatarCue>[],
    String? caption,
    SpeechTimeline? timeline,
  }) {}

  @override
  Duration? get speechPosition => null;

  @override
  void fireCues(List<AvatarCue> cues) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> interrupt() async {}

  @override
  void cancelAnimation() {}

  @override
  void dispose() {}
}

class MockTtsQueueService implements TtsQueueService {
  @override
  bool get isProcessing => false;

  @override
  bool get hasPendingSpeech => false;

  @override
  Stream<void> get drained => const Stream<void>.empty();

  @override
  List<TtsQueueItem> get queue => <TtsQueueItem>[];

  bool get hasItems => false;

  bool get isPlaying => false;

  @override
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
    List<AvatarCue> cues = const <AvatarCue>[],
  }) async {}

  @override
  Future<void> deleteAudio(String audioPath) async {}

  @override
  void clear() {}

  @override
  void dispose() {}

  @override
  void setPaused(bool paused) {}

  @override
  Stream<String> get audioStream => const Stream<String>.empty();

  @override
  Stream<List<AvatarCue>> get cueOnlyStream =>
      const Stream<List<AvatarCue>>.empty();

  @override
  List<AvatarCue> consumeCues(String audioPath) => const <AvatarCue>[];

  @override
  String? consumeText(String audioPath) => null;

  @override
  String? peekText(String audioPath) => null;

  @override
  String? peekLanguage(String audioPath) => null;
}

class MockAvatarAnimationService implements AvatarAnimationService {
  final StreamController<AvatarAnimation> _controller =
      StreamController<AvatarAnimation>.broadcast();

  @override
  Stream<AvatarAnimation> get animations => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {}

  @override
  void emitUpdateConfig(String chatId, AvatarConfig config) {}

  @override
  void trigger(AvatarAnimation animation) {}
}

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
  group('FloatingStopButton', () {
    late InterruptionService interruptionService;
    late ChatCubit chatsCubit;
    late TalkingCubit talkingCubit;
    late MockTalkingRepository talkingRepository;
    late MockTtsPlaybackService playbackService;

    setUp(() {
      interruptionService = InterruptionService();
      talkingRepository = MockTalkingRepository();
      playbackService = MockTtsPlaybackService();
      when(() => talkingRepository.stop()).thenAnswer((_) async {});
      when(
        () => talkingRepository.generateSpeech(any()),
      ).thenAnswer((_) async {});
      when(
        () => talkingRepository.playWaitingSentence(any()),
      ).thenAnswer((_) async {});
      talkingCubit = TalkingCubit(
        talkingRepository,
        interruptionService,
        playbackService,
        MockAppLifecycleService(),
        MockTtsQueueService(),
      );

      chatsCubit = ChatCubit(
        chatRepository: MockChatRepository(),
        settingsRepository: MockSettingsRepository(),
        avatarAnimationService: MockAvatarAnimationService(),
        chatTitleService: ChatTitleService(
          chatRepository: MockChatRepository(),
          llmService: MockLlmService(),
        ),
        chatStreamingService: createMockChatStreamingService(
          chatRepository: MockChatRepository(),
          llmService: MockLlmService(),
          streamProcessor: MockStreamProcessorService(),
          promptDatasource: MockPromptDatasource(),
          interruptionService: interruptionService,
          chatEntryService: MockChatEntryService(),
        ),
        appLifecycleService: MockAppLifecycleService(),
        globalMemoryService: MockGlobalMemoryService(),
        demoService: MockDemoService(),
      );
    });

    tearDown(() {
      chatsCubit.close();
      talkingCubit.close();
      interruptionService.dispose();
    });

    testWidgets('should not show when not streaming', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ChatCubit>.value(value: chatsCubit),
              BlocProvider<TalkingCubit>.value(value: talkingCubit),
            ],
            child: Scaffold(
              body: RepositoryProvider<InterruptionService>.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show when streaming', (WidgetTester tester) async {
      // Arrange
      chatsCubit.emit(chatsCubit.state.copyWith(status: ChatStatus.streaming));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ChatCubit>.value(value: chatsCubit),
              BlocProvider<TalkingCubit>.value(value: talkingCubit),
            ],
            child: Scaffold(
              body: RepositoryProvider<InterruptionService>.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('should show while speaking', (WidgetTester tester) async {
      talkingCubit.setSpeakingState();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ChatCubit>.value(value: chatsCubit),
              BlocProvider<TalkingCubit>.value(value: talkingCubit),
            ],
            child: Scaffold(
              body: RepositoryProvider<InterruptionService>.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('should call interrupt when tapped', (
      WidgetTester tester,
    ) async {
      // Arrange
      chatsCubit.emit(chatsCubit.state.copyWith(status: ChatStatus.streaming));
      final List<bool> interrupted = <bool>[false];

      interruptionService.interruptionStream.listen((_) {
        interrupted[0] = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ChatCubit>.value(value: chatsCubit),
              BlocProvider<TalkingCubit>.value(value: talkingCubit),
            ],
            child: Scaffold(
              body: RepositoryProvider<InterruptionService>.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Assert
      expect(interrupted[0], true);
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
