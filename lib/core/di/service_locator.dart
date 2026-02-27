import 'package:get_it/get_it.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/settings/bloc/settings_cubit.dart';
import 'package:yofardev_ai/logic/chat/chats_cubit.dart';
import 'package:yofardev_ai/logic/talking/talking_cubit.dart';
import 'package:yofardev_ai/services/chat_history_service.dart';
import 'package:yofardev_ai/services/settings_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
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
