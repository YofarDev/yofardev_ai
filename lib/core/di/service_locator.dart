import 'dart:async';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/data/datasources/avatar_local_datasource.dart';
import '../../features/avatar/data/repositories/avatar_repository_impl.dart';
import '../../features/avatar/domain/repositories/avatar_repository.dart';
import '../../features/avatar/domain/services/performance_director.dart';
import '../../features/chat/domain/repositories/global_memory_repository.dart';
import '../../features/chat/presentation/bloc/chat_tts_cubit.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/domain/services/chat_entry_service.dart';
import '../../features/chat/domain/services/chat_title_service.dart';
import '../../features/chat/domain/services/global_memory_service.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/global_memory_datasource.dart';
import '../../features/chat/data/repositories/global_memory_repository_impl.dart';
import '../../features/chat/data/repositories/yofardev_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/demo/presentation/bloc/demo_cubit.dart';
import '../../features/demo/domain/services/demo_service.dart';
import '../../features/demo/data/repositories/demo_repository_impl.dart';
import '../../features/demo/domain/repositories/demo_repository.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../repositories/settings_repository.dart';
import '../../features/sound/presentation/bloc/sound_cubit.dart';
import '../../features/sound/data/datasources/tts_datasource.dart';
import '../../features/sound/data/repositories/sound_repository_impl.dart';
import '../../features/sound/domain/services/tts_queue_service.dart';
import '../../features/sound/domain/repositories/sound_repository.dart';
import '../../features/talking/data/repositories/talking_repository_impl.dart';
import '../../features/talking/domain/repositories/talking_repository.dart';
import '../../features/talking/domain/services/playback_clock.dart';
import '../../features/talking/domain/services/tts_playback_service.dart';
import '../../features/talking/presentation/bloc/caption_cubit.dart';
import '../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../services/app_lifecycle_service.dart';
import '../utils/platform_utils.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/settings/domain/repositories/locale_repository.dart';
import '../../features/settings/data/repositories/locale_repository_impl.dart';
import '../services/audio/audio_amplitude_service.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/interruption_service.dart';
import '../services/audio/voice_effects_service.dart';
import '../services/agent/tool_registry.dart';
import '../../features/avatar/domain/services/avatar_animation_service.dart';
import '../../features/avatar/domain/services/avatar_cue_service.dart';
import '../../features/avatar/domain/services/prop_reaction_service.dart';
import '../../features/demo/domain/services/demo_controller.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/llm/llm_config_manager.dart';
import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_interface.dart';
import '../services/llm/llm_streaming_service.dart';
import '../services/llm/llm_streaming_service_interface.dart';
import '../services/prompt_datasource.dart';
import '../services/quality/frame_timing_source.dart';
import '../services/quality/quality_tier_service.dart';
import '../services/settings_local_datasource.dart';
import '../services/speech/speech_input_service.dart';
import '../services/speech/speech_to_text_input_service.dart';
import '../services/stream_processor/stream_processor_service.dart';
import '../../features/chat/domain/services/chat_streaming_service.dart';
import '../utils/logger.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // ── Data sources (register early — no dependencies) ──
  getIt.registerLazySingleton<SettingsLocalDatasource>(
    () => SettingsLocalDatasource(),
  );
  getIt.registerLazySingleton<AvatarLocalDatasource>(
    () => AvatarLocalDatasource(),
  );
  getIt.registerLazySingleton<TtsDatasource>(() => TtsDatasource());
  getIt.registerLazySingleton<InterruptionService>(() => InterruptionService());
  // Lazy: no mic permission or recognizer setup until the first start().
  getIt.registerLazySingleton<SpeechInputService>(
    () => SpeechToTextInputService(),
    dispose: (SpeechInputService service) => service.dispose(),
  );

  // ── Core services (depend on datasources) ──
  getIt.registerLazySingleton<LlmConfigManager>(
    () =>
        LlmConfigManager(settingsDatasource: getIt<SettingsLocalDatasource>()),
  );
  getIt.registerLazySingleton<PromptDatasource>(
    () =>
        PromptDatasource(settingsDatasource: getIt<SettingsLocalDatasource>()),
  );
  getIt.registerLazySingleton<ChatLocalDatasource>(
    () => ChatLocalDatasource(
      settingsDatasource: getIt<SettingsLocalDatasource>(),
      promptDatasource: getIt<PromptDatasource>(),
    ),
  );
  getIt.registerLazySingleton<GlobalMemoryLocalDatasource>(
    () => GlobalMemoryLocalDatasource(),
  );

  // LLM services
  getIt.registerLazySingleton<LlmService>(() {
    final LlmService service = LlmService();
    service.setConfigManager(getIt<LlmConfigManager>());
    return service;
  });
  getIt.registerLazySingleton<FakeLlmService>(() => FakeLlmService());

  if (kDebugMode) {
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => getIt<FakeLlmService>(),
    );
    AppLogger.info(
      'Registered FakeLlmService (debug mode)',
      tag: 'ServiceLocator',
    );
  } else {
    getIt.registerLazySingleton<LlmServiceInterface>(() => getIt<LlmService>());
    AppLogger.info(
      'Registered LlmService (release mode)',
      tag: 'ServiceLocator',
    );
  }

  getIt.registerLazySingleton<LlmStreamingServiceInterface>(
    () => LlmStreamingService(
      client: http.Client(),
      configManager: getIt<LlmConfigManager>(),
    ),
  );

  // Agent & tool registry
  getIt.registerLazySingleton<ToolRegistry>(
    () => ToolRegistry(appLifecycleService: getIt<AppLifecycleService>()),
  );

  // ── Repositories (depend on datasources + services) ──
  getIt.registerLazySingleton<AvatarRepository>(
    () => AvatarRepositoryImpl(datasource: getIt<AvatarLocalDatasource>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => YofardevRepositoryImpl(chatDatasource: getIt<ChatLocalDatasource>()),
  );
  getIt.registerLazySingleton<GlobalMemoryRepository>(
    () => GlobalMemoryRepositoryImpl(
      datasource: getIt<GlobalMemoryLocalDatasource>(),
    ),
  );
  getIt.registerLazySingleton<SoundRepository>(() => SoundRepositoryImpl());
  getIt.registerLazySingleton<TalkingRepository>(() => TalkingRepositoryImpl());
  getIt.registerLazySingleton<DemoRepository>(
    () => DemoRepositoryImpl(
      chatRepository: getIt<ChatRepository>(),
      avatarRepository: getIt<AvatarRepository>(),
    ),
  );
  getIt.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl());

  // ── Audio services ──
  getIt.registerLazySingleton<AudioAnalyzer>(() => AudioAnalyzer());
  getIt.registerLazySingleton<AudioPlayerService>(() => AudioPlayerService());
  getIt.registerLazySingleton<AudioAmplitudeService>(
    () => AudioAmplitudeService(),
  );
  getIt.registerLazySingleton<VoiceEffectsService>(() => VoiceEffectsService());
  getIt.registerLazySingleton<TtsQueueService>(
    () => TtsQueueService(
      ttsSynthesizer: getIt<TtsDatasource>(),
      interruptionService: getIt<InterruptionService>(),
      voiceEffectsService: getIt<VoiceEffectsService>(),
    ),
  );

  // ── Other services ──
  getIt.registerLazySingleton<LocaleRepository>(
    () => LocaleRepositoryImpl(prefs: prefs),
  );
  getIt.registerLazySingleton<StreamProcessorService>(
    () => StreamProcessorService(),
  );
  getIt.registerLazySingleton<FrameTimingSource>(
    () => SchedulerFrameTimingSource(),
  );
  getIt.registerLazySingleton<QualityTierService>(
    () => QualityTierService(
      timingSource: getIt<FrameTimingSource>(),
      settings: getIt<SettingsLocalDatasource>(),
    ),
  );
  getIt.registerLazySingleton<PlaybackClock>(
    () => PlaybackClock(
      source: _AudioPlayerPositionSource(getIt<AudioPlayerService>()),
    ),
  );
  getIt.registerLazySingleton<TtsPlaybackService>(
    () => TtsPlaybackService(
      getIt<TalkingRepository>(),
      clock: getIt<PlaybackClock>(),
    ),
  );
  getIt.registerLazySingleton<AvatarAnimationService>(
    () => AvatarAnimationService(),
  );
  getIt.registerLazySingleton<PropReactionService>(() => PropReactionService());
  getIt.registerLazySingleton<ChatEntryService>(
    () => ChatEntryService(getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<ChatTitleService>(
    () => ChatTitleService(
      chatRepository: getIt<ChatRepository>(),
      llmService: getIt<LlmServiceInterface>(),
    ),
  );
  getIt.registerLazySingleton<GlobalMemoryService>(
    () => GlobalMemoryService(
      memoryRepository: getIt<GlobalMemoryRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmServiceInterface>(),
    ),
  );

  // ── Demo services (depend on repositories) ──
  getIt.registerLazySingleton<DemoController>(() => DemoController());
  getIt.registerLazySingleton<DemoService>(
    () => DemoService(
      repository: getIt<DemoRepository>(),
      demoController: getIt<DemoController>(),
      fakeLlmService: getIt<FakeLlmService>(),
    ),
  );

  // ── App lifecycle service (no cubit dependencies - cubits subscribe to service streams) ──
  getIt.registerLazySingleton<AppLifecycleService>(() => AppLifecycleService());

  // ── Cubits ──
  getIt.registerFactory<AvatarCubit>(
    () => AvatarCubit(
      getIt<AvatarRepository>(),
      getIt<AvatarAnimationService>(),
      getIt<AudioPlayerService>(),
      getIt<AppLifecycleService>(),
      getIt<PropReactionService>(),
      getIt<SoundRepository>(),
    ),
  );
  getIt.registerFactory<TalkingCubit>(
    () => TalkingCubit(
      getIt<TalkingRepository>(),
      getIt<InterruptionService>(),
      getIt<TtsPlaybackService>(),
      getIt<AppLifecycleService>(),
      getIt<TtsQueueService>(),
    ),
  );
  getIt.registerFactory<CaptionCubit>(
    () => CaptionCubit(
      playbackService: getIt<TtsPlaybackService>(),
      interruptionService: getIt<InterruptionService>(),
      settingsRepository: getIt<SettingsRepository>(),
    ),
  );
  getIt.registerFactory<ChatTtsCubit>(
    () => ChatTtsCubit(
      ttsQueueManager: getIt<TtsQueueService>(),
      audioAmplitudeService: getIt<AudioAmplitudeService>(),
      audioPlayerService: getIt<AudioPlayerService>(),
      interruptionService: getIt<InterruptionService>(),
      ttsPlaybackService: getIt<TtsPlaybackService>(),
    ),
  );
  getIt.registerLazySingleton<ChatStreamingService>(
    () => ChatStreamingService(
      chatRepository: getIt<ChatRepository>(),
      llmService: getIt<LlmServiceInterface>(),
      streamProcessor: getIt<StreamProcessorService>(),
      promptDatasource: getIt<PromptDatasource>(),
      interruptionService: getIt<InterruptionService>(),
      chatEntryService: getIt<ChatEntryService>(),
      ttsQueueManager: getIt<TtsQueueService>(),
      toolRegistry: getIt<ToolRegistry>(),
      settingsRepository: getIt<SettingsRepository>(),
      globalMemoryService: getIt<GlobalMemoryService>(),
    ),
  );
  getIt.registerFactory<ChatCubit>(
    () => ChatCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      avatarAnimationService: getIt<AvatarAnimationService>(),
      chatTitleService: getIt<ChatTitleService>(),
      chatStreamingService: getIt<ChatStreamingService>(),
      appLifecycleService: getIt<AppLifecycleService>(),
      globalMemoryService: getIt<GlobalMemoryService>(),
      demoService: getIt<DemoService>(),
    ),
  );

  // Eagerly created: it must be subscribed to TTS playback events and the
  // streaming cue channel from startup, or cues fired before the first
  // subscription would be lost.
  getIt.registerLazySingleton<PerformanceDirector>(
    () => PerformanceDirector(now: DateTime.now),
  );
  getIt.registerLazySingleton<AvatarCueService>(
    () => AvatarCueService(
      playbackService: getIt<TtsPlaybackService>(),
      animationService: getIt<AvatarAnimationService>(),
      streamingCues: getIt<ChatStreamingService>().streamingCues,
      director: getIt<PerformanceDirector>(),
    ),
  );
  getIt<AvatarCueService>();

  getIt.registerFactory<DemoCubit>(
    () => DemoCubit(
      demoController: getIt<DemoController>(),
      demoService: getIt<DemoService>(),
    ),
  );
  getIt.registerFactory<SoundCubit>(
    () => SoundCubit(soundRepository: getIt<SoundRepository>()),
  );
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmServiceInterface>(),
      globalMemoryRepository: getIt<GlobalMemoryRepository>(),
    ),
  );
  getIt.registerFactory<HomeCubit>(
    () => HomeCubit(getIt<HomeRepository>(), getIt<AppLifecycleService>()),
  );
}

/// Post-registration bootstrap: data migrations and optional warmup.
/// Lives here (not in main.dart) so main.dart never imports feature internals.
Future<void> bootstrapApp() async {
  // Run chat data migration (previously called from main.dart).
  await getIt<ChatLocalDatasource>().init();

  // Quality-tier probe: load the stored tier and probe in the background
  // when none is stored. Startup never waits for it.
  unawaited(getIt<QualityTierService>().init());

  // Optional TTS warmup: startup must never be blocked by it.
  if (PlatformUtils.checkPlatform() != 'Web' &&
      PlatformUtils.checkPlatform() != 'MacOS') {
    unawaited(
      TtsDatasource.initSupertonic().catchError((Object error, StackTrace st) {
        // Startup should never be blocked by optional TTS warmup.
      }),
    );
  }
}

/// Adapts the core [AudioPlayerService] to the talking feature's
/// [PlaybackPositionSource] (core may not import features, so the feature
/// interface is implemented here, in the composition root).
class _AudioPlayerPositionSource implements PlaybackPositionSource {
  _AudioPlayerPositionSource(this._audioPlayerService);

  final AudioPlayerService _audioPlayerService;

  @override
  Future<Duration?> currentPosition() => _audioPlayerService.currentPosition();
}
