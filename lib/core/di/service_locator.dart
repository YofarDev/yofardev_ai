import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../l10n/localization_manager.dart';
import '../utils/logger.dart';

import '../../features/avatar/bloc/avatar_cubit.dart';
import '../../features/chat/bloc/chats_cubit.dart';
import '../../features/demo/bloc/demo_cubit.dart';
import '../../features/demo/services/demo_controller.dart';
import '../../features/demo/services/demo_service.dart';
import '../../features/sound/bloc/sound_cubit.dart';
import '../../features/talking/bloc/talking_cubit.dart';
import '../repositories/yofardev_repository.dart';
import '../services/agent/sound_service.dart';
import '../services/chat_history_service.dart';
import '../services/sound_service_interface.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_interface.dart';

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
  getIt.registerLazySingleton<DemoService>(() => DemoService());

  // Other services
  getIt.registerLazySingleton<ChatHistoryService>(() => ChatHistoryService());
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<YofardevRepository>(() => YofardevRepository());
  getIt.registerLazySingleton<TtsService>(() => TtsService());
  getIt.registerLazySingleton<AudioAnalyzer>(() => AudioAnalyzer());
  getIt.registerLazySingleton<LocalizationManager>(() => LocalizationManager());

  // Sound services
  getIt.registerLazySingleton<SoundService>(() => SoundService());

  // BLoCs / Cubits
  getIt.registerFactory<AvatarCubit>(() => AvatarCubit());
  getIt.registerFactory<TalkingCubit>(() => TalkingCubit());
  getIt.registerFactory<ChatsCubit>(
    () => ChatsCubit(
      chatHistoryService: getIt<ChatHistoryService>(),
      settingsService: getIt<SettingsService>(),
      yofardevRepository: getIt<YofardevRepository>(),
      ttsService: getIt<TtsService>(),
      audioAnalyzer: getIt<AudioAnalyzer>(),
      localizationManager: getIt<LocalizationManager>(),
    ),
  );
  getIt.registerFactory<DemoCubit>(() => DemoCubit(getIt<DemoController>()));
  getIt.registerFactory<SoundCubit>(
    () => SoundCubit(soundService: getIt<ISoundService>()),
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
