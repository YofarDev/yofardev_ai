import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  // TODO: Register SoundService as lazy singleton when implementation is available
  // getIt.registerLazySingleton<SoundService>(() => SoundService());

  // BLoCs
  // TODO: Register SoundCubit as factory once SoundService is implemented
  // getIt.registerFactory<SoundCubit>(() => SoundCubit(
  //   soundService: getIt<SoundService>(),
  // ));
}
