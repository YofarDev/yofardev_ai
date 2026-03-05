import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../features/avatar/bloc/avatar_cubit.dart';
import '../../features/avatar/data/datasources/avatar_local_datasource.dart';
import '../../features/avatar/data/repositories/avatar_repository_impl.dart';
import '../../features/avatar/domain/repositories/avatar_repository.dart';
import '../../features/chat/bloc/chat_list_cubit.dart';
import '../../features/chat/bloc/chat_message_cubit.dart';
import '../../features/chat/bloc/chat_title_cubit.dart';
import '../../features/chat/bloc/chat_tts_cubit.dart';
import '../../features/chat/bloc/chats_cubit.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/yofardev_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/demo/bloc/demo_cubit.dart';
import '../../features/demo/data/repositories/demo_repository_impl.dart';
import '../../features/demo/domain/repositories/demo_repository.dart';
import '../../features/home/bloc/home_cubit.dart';
import '../../features/settings/bloc/settings_cubit.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/sound/bloc/sound_cubit.dart';
import '../../features/sound/data/datasources/tts_datasource.dart';
import '../../features/sound/data/repositories/sound_repository_impl.dart';
import '../../features/sound/domain/repositories/sound_repository.dart';
import '../../features/sound/domain/tts_queue_manager.dart';
import '../../features/talking/data/repositories/talking_repository_impl.dart';
import '../../features/talking/domain/repositories/talking_repository.dart';
import '../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../l10n/localization_manager.dart';
import '../services/audio/audio_amplitude_service.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/tts_service.dart';
import '../services/demo_controller.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_interface.dart';
import '../services/prompt_datasource.dart';
import '../services/settings_local_datasource.dart';
import '../services/stream_processor/stream_processor_service.dart';
import '../utils/logger.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services - LLM (conditional registration)
  if (kDebugMode) {
    // In debug mode, use FakeLlmService by default for easier testing
    // This can be changed via settings
    getIt.registerLazySingleton<LlmServiceInterface>(() => FakeLlmService());
    AppLogger.info(
      'Registered FakeLlmService (debug mode)',
      tag: 'ServiceLocator',
    );
  } else {
    // In release mode, always use real LlmService
    getIt.registerLazySingleton<LlmServiceInterface>(() => LlmService());
    AppLogger.info(
      'Registered LlmService (release mode)',
      tag: 'ServiceLocator',
    );
  }

  // Register both service instances for demo mode switching
  getIt.registerLazySingleton<LlmService>(() => LlmService());
  getIt.registerLazySingleton<FakeLlmService>(() => FakeLlmService());

  // Demo services
  getIt.registerLazySingleton<DemoController>(() => DemoController());
  getIt.registerLazySingleton<DemoService>(() {
    final DemoService service = DemoService();
    service.setRepository(getIt<DemoRepository>());
    return service;
  });

  // Data sources
  getIt.registerLazySingleton<ChatLocalDatasource>(() => ChatLocalDatasource());
  getIt.registerLazySingleton<AvatarLocalDatasource>(
    () => AvatarLocalDatasource(),
  );
  getIt.registerLazySingleton<SettingsLocalDatasource>(
    () => SettingsLocalDatasource(),
  );
  getIt.registerLazySingleton<TtsDatasource>(() => TtsDatasource());
  getIt.registerLazySingleton<TtsQueueManager>(
    () => TtsQueueManager(ttsDatasource: getIt<TtsDatasource>()),
  );

  // Repositories (register implementations as interfaces)
  getIt.registerLazySingleton<ChatRepository>(() => YofardevRepositoryImpl());
  getIt.registerLazySingleton<AvatarRepository>(() => AvatarRepositoryImpl());
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(),
  );
  getIt.registerLazySingleton<SoundRepository>(() => SoundRepositoryImpl());
  getIt.registerLazySingleton<TalkingRepository>(
    () => TalkingRepositoryImpl(getIt<TtsService>()),
  );
  getIt.registerLazySingleton<DemoRepository>(
    () => DemoRepositoryImpl(
      chatRepository: getIt<ChatRepository>(),
      avatarRepository: getIt<AvatarRepository>(),
    ),
  );

  // Other services
  getIt.registerLazySingleton<AudioAnalyzer>(() => AudioAnalyzer());
  // Audio service - single source of truth for TTS
  getIt.registerLazySingleton<TtsService>(() => TtsService());
  getIt.registerLazySingleton<AudioPlayerService>(() => AudioPlayerService());
  getIt.registerLazySingleton<AudioAmplitudeService>(
    () => AudioAmplitudeService(),
  );
  getIt.registerLazySingleton<LocalizationManager>(() => LocalizationManager());

  // Stream processor service
  getIt.registerLazySingleton<StreamProcessorService>(
    () => StreamProcessorService(),
  );

  // Prompt datasource
  getIt.registerLazySingleton<PromptDatasource>(() => PromptDatasource());

  // BLoCs / Cubits
  getIt.registerFactory<AvatarCubit>(
    () => AvatarCubit(getIt<AvatarRepository>()),
  );
  getIt.registerFactory<TalkingCubit>(
    () => TalkingCubit(getIt<TalkingRepository>()),
  );
  getIt.registerLazySingleton<ChatTitleCubit>(
    () => ChatTitleCubit(
      chatRepository: getIt<ChatRepository>(),
      llmService: getIt<LlmService>(),
    ),
  );
  // Chat cubits - split by responsibility
  getIt.registerFactory<ChatTtsCubit>(
    () => ChatTtsCubit(
      ttsQueueManager: getIt<TtsQueueManager>(),
      audioAmplitudeService: getIt<AudioAmplitudeService>(),
      audioPlayerService: getIt<AudioPlayerService>(),
      talkingCubit: getIt<TalkingCubit>(),
    ),
  );
  getIt.registerFactory<ChatsCubit>(
    () => ChatsCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      localizationManager: getIt<LocalizationManager>(),
    ),
  );
  getIt.registerFactory<ChatListCubit>(
    () => ChatListCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      localizationManager: getIt<LocalizationManager>(),
    ),
  );
  getIt.registerFactory<ChatMessageCubit>(
    () => ChatMessageCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmService>(),
      streamProcessor: getIt<StreamProcessorService>(),
      promptDatasource: getIt<PromptDatasource>(),
      ttsQueueManager: getIt<TtsQueueManager>(),
      chatTitleCubit: getIt<ChatTitleCubit>(),
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
  getIt.registerFactory<HomeCubit>(() => HomeCubit());
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
