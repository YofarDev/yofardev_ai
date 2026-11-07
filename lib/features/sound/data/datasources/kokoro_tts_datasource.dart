import '../../../../core/models/voice_effect.dart';
import '../../domain/services/tts_synthesizer.dart';
import '../kokoro/kokoro_engine.dart';
import '../kokoro/kokoro_model_spec.dart';
import 'tts_scratch_files.dart';

/// Kokoro is not loaded yet (model downloading, or failed to install).
class TtsEngineNotReadyException implements Exception {
  const TtsEngineNotReadyException();

  @override
  String toString() => 'TtsEngineNotReadyException';
}

/// Kokoro has no voice for this language.
class TtsLanguageUnsupportedException implements Exception {
  const TtsLanguageUnsupportedException(this.language);

  final String language;

  @override
  String toString() => 'TtsLanguageUnsupportedException($language)';
}

/// [TtsSynthesizer] on the on-device Kokoro engine: French with `ff_siwis`
/// (espeak-ng `fr`), English with `af_heart` (English lexicons).
/// [VoiceEffect] is accepted and ignored (the TTS queue post-processes the
/// WAV through `VoiceEffectsService`).
class KokoroTtsDatasource implements TtsSynthesizer {
  KokoroTtsDatasource({
    required KokoroEngine engine,
    Future<String> Function()? outputPath,
  }) : _engine = engine,
       _outputPath = outputPath ?? TtsScratchFiles.newWavPath;

  final KokoroEngine _engine;
  final Future<String> Function() _outputPath;

  /// Languages Kokoro speaks here (the chat's `language`, e.g. `fr`).
  static bool supports(String language) {
    final String code = _code(language);
    return code == 'fr' || code == 'en';
  }

  static String _code(String language) =>
      language.toLowerCase().split(RegExp('[-_]')).first;

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    if (!_engine.isLoaded) {
      throw const TtsEngineNotReadyException();
    }
    if (!supports(language)) {
      throw TtsLanguageUnsupportedException(language);
    }
    final bool french = _code(language) == 'fr';
    TtsScratchFiles.ensureSweeping();
    final String path = await _outputPath();
    await _engine.synthesizeToWav(
      text: text,
      sid: french ? KokoroModelSpec.sidFrench : KokoroModelSpec.sidEnglish,
      lang: french ? KokoroModelSpec.espeakFrench : null,
      outputPath: path,
    );
    return path;
  }

  @override
  Future<void> delete(String path) => TtsScratchFiles.delete(path);
}
