import 'package:get_it/get_it.dart';
import '../services/audio/tts_service.dart';

final GetIt getIt = GetIt.instance;

/// Configure all dependencies for the app
/// Call this in main() before runApp()
Future<void> configureDependencies() async {
  // Audio - SINGLE SOURCE OF TRUTH
  getIt.registerLazySingleton<TtsService>(() => TtsService());
}

/// Reset all dependencies (for testing)
Future<void> resetInjection() async {
  await getIt.reset();
}
