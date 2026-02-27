import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/demo/services/demo_controller.dart';
import 'package:yofardev_ai/features/demo/services/demo_service.dart';
import 'package:yofardev_ai/features/settings/bloc/settings_cubit.dart';
import 'package:yofardev_ai/logic/chat/chats_cubit.dart';
import 'package:yofardev_ai/logic/talking/talking_cubit.dart';
import 'package:yofardev_ai/services/chat_history_service.dart';
import 'package:yofardev_ai/services/settings_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services - LLM (conditional registration)
  if (kDebugMode) {
    // In debug mode, use FakeLlmService by default for easier testing
    // This can be changed via settings
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => FakeLlmService(),
    );
    debugPrint('Registered FakeLlmService (debug mode)');
  } else {
    // In release mode, always use real LlmService
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => LlmService(),
    );
    debugPrint('Registered LlmService (release mode)');
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

  // TODO: Register SoundService as lazy singleton when implementation is available
  // getIt.registerLazySingleton<SoundService>(() => SoundService());

  // BLoCs / Cubits
  getIt.registerFactory<AvatarCubit>(() => AvatarCubit());
  getIt.registerFactory<TalkingCubit>(() => TalkingCubit());
  getIt.registerFactory<ChatsCubit>(() => ChatsCubit());
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(settingsService: getIt<SettingsService>()),
  );

  // TODO: Register SoundCubit as factory once SoundService is implemented
  // getIt.registerFactory<SoundCubit>(() => SoundCubit(
  //   soundService: getIt<SoundService>(),
  // ));
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
    debugPrint('Switched to FakeLlmService');
  } else {
    getIt.unregister<LlmServiceInterface>();
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => getIt<LlmService>(),
    );
    debugPrint('Switched to LlmService');
  }
}
