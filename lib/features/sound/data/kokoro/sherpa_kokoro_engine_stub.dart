import 'kokoro_engine.dart';
import 'kokoro_model_paths.dart';

/// The engine where FFI is missing (web): never loads, so the fallback
/// voice speaks (picked by `kokoro_engine_factory.dart`).
KokoroEngine createPlatformKokoroEngine() => const UnavailableKokoroEngine();

class UnavailableKokoroEngine implements KokoroEngine {
  const UnavailableKokoroEngine();

  @override
  bool get isLoaded => false;

  @override
  Future<void> load(KokoroModelPaths paths) =>
      Future<void>.error(UnsupportedError('Kokoro needs dart:ffi'));

  @override
  Future<void> synthesizeToWav({
    required String text,
    required int sid,
    required String outputPath,
    String? lang,
    double speed = 1.0,
  }) => Future<void>.error(UnsupportedError('Kokoro needs dart:ffi'));
}
