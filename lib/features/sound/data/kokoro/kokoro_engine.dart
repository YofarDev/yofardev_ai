import 'kokoro_model_paths.dart';

/// Kokoro inference, one sentence at a time.
abstract class KokoroEngine {
  bool get isLoaded;

  /// Loads the model (seconds; runs off the UI isolate).
  Future<void> load(KokoroModelPaths paths);

  /// Synthesizes [text] with speaker [sid] into a 16-bit PCM mono WAV at
  /// [outputPath]. [lang] routes the whole sentence through espeak-ng in
  /// that language; null keeps the English lexicons.
  ///
  /// One synthesis at a time: the TTS queue is sequential.
  Future<void> synthesizeToWav({
    required String text,
    required int sid,
    required String outputPath,
    String? lang,
    double speed = 1.0,
  });
}
