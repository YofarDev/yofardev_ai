import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/data/datasources/avatar_local_datasource.dart';
import '../../features/avatar/data/repositories/avatar_repository_impl.dart';
import '../repositories/avatar_repository.dart';
import '../../features/chat/presentation/bloc/chat_tts_cubit.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/domain/services/chat_entry_service.dart';
import '../../features/chat/domain/services/chat_title_service.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/yofardev_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/demo/presentation/bloc/demo_cubit.dart';
import '../../features/demo/data/repositories/demo_repository_impl.dart';
import '../../features/demo/domain/repositories/demo_repository.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../repositories/settings_repository.dart';
import '../../features/sound/presentation/bloc/sound_cubit.dart';
import '../../features/sound/data/datasources/tts_datasource.dart';
import '../../features/sound/data/repositories/sound_repository_impl.dart';
import '../services/audio/tts_queue_service.dart';
import '../../features/sound/domain/repositories/sound_repository.dart';
import '../../features/talking/data/repositories/talking_repository_impl.dart';
import '../../features/talking/domain/repositories/talking_repository.dart';
import '../../features/talking/domain/services/tts_playback_service.dart';
import '../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../services/app_lifecycle_service.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../repositories/locale_repository.dart';
import '../repositories/locale_repository_impl.dart';
import '../services/audio/audio_amplitude_service.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/interruption_service.dart';
import '../services/agent/yofardev_agent.dart';
import '../services/agent/tool_registry.dart';
import '../services/avatar_animation_service.dart';
import '../services/demo_controller.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/llm/llm_config_manager.dart';
import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_interface.dart';
import '../services/llm/llm_streaming_service.dart';
import '../services/llm/llm_streaming_service_interface.dart';
import '../services/prompt_datasource.dart';
import '../services/settings_local_datasource.dart';
import '../services/stream_processor/stream_processor_service.dart';
import '../services/chat/chat_streaming_service.dart';
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
  getIt.registerLazySingleton<ToolRegistry>(() => ToolRegistry());
  getIt.registerLazySingleton<YofardevAgent>(
    () => YofardevAgent(
      llmService: getIt<LlmService>(),
      toolRegistry: getIt<ToolRegistry>(),
    ),
  );

  // ── Repositories (depend on datasources + services) ──
  getIt.registerLazySingleton<AvatarRepository>(
    () => AvatarRepositoryImpl(datasource: getIt<AvatarLocalDatasource>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => YofardevRepositoryImpl(
      settingsRepository: getIt<SettingsRepository>(),
      agent: getIt<YofardevAgent>(),
      promptService: getIt<PromptDatasource>(),
      fakeLlmService: getIt<FakeLlmService>(),
      chatDatasource: getIt<ChatLocalDatasource>(),
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
  getIt.registerLazySingleton<TtsQueueService>(
    () => TtsQueueService(
      ttsDatasource: getIt<TtsDatasource>(),
      interruptionService: getIt<InterruptionService>(),
    ),
  );

  // ── Other services ──
  getIt.registerLazySingleton<LocaleRepository>(
    () => LocaleRepositoryImpl(prefs: prefs),
  );
  getIt.registerLazySingleton<StreamProcessorService>(
    () => StreamProcessorService(),
  );
  getIt.registerLazySingleton<TtsPlaybackService>(
    () => TtsPlaybackService(getIt<TalkingRepository>()),
  );
  getIt.registerLazySingleton<AvatarAnimationService>(
    () => AvatarAnimationService(),
  );
  getIt.registerLazySingleton<ChatEntryService>(
    () => ChatEntryService(getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<ChatTitleService>(
    () => ChatTitleService(
      chatRepository: getIt<ChatRepository>(),
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

  // ── Cubits ──
  getIt.registerFactory<AvatarCubit>(
    () => AvatarCubit(
      getIt<AvatarRepository>(),
      getIt<AvatarAnimationService>(),
      getIt<AudioPlayerService>(),
    ),
  );
  getIt.registerLazySingleton<TalkingCubit>(
    () => TalkingCubit(
      getIt<TalkingRepository>(),
      getIt<InterruptionService>(),
      getIt<TtsPlaybackService>(),
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
    ),
  );
  getIt.registerFactory<ChatCubit>(
    () => ChatCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      avatarAnimationService: getIt<AvatarAnimationService>(),
      chatTitleService: getIt<ChatTitleService>(),
      chatStreamingService: getIt<ChatStreamingService>(),
    ),
  );
  getIt.registerFactory<DemoCubit>(() => DemoCubit(getIt<DemoController>()));
  getIt.registerFactory<SoundCubit>(
    () => SoundCubit(soundRepository: getIt<SoundRepository>()),
  );
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmServiceInterface>(),
    ),
  );
  getIt.registerFactory<HomeCubit>(() => HomeCubit(getIt<HomeRepository>()));

  // ── App lifecycle service (depends on cubits) ──
  getIt.registerLazySingleton<AppLifecycleService>(
    () => AppLifecycleService(
      homeCubit: getIt<HomeCubit>(),
      avatarCubit: getIt<AvatarCubit>(),
      talkingCubit: getIt<TalkingCubit>(),
      chatCubit: getIt<ChatCubit>(),
    ),
  );
}

/// Switch between real and fake LLM service
///
/// This allows runtime switching for demo mode
void switchLlmService(bool useFakeService) {
  if (useFakeService) {
    getIt.unregister<LlmServiceInterface>();
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => getIt<FakeLlmService>(),
    );
    AppLogger.info('Switched to FakeLlmService', tag: 'ServiceLocator');
  } else {
    getIt.unregister<LlmServiceInterface>();
    getIt.registerLazySingleton<LlmServiceInterface>(() => getIt<LlmService>());
    AppLogger.info('Switched to LlmService', tag: 'ServiceLocator');
  }
}
