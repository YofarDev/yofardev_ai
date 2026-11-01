import '../../../../core/models/voice_effect.dart';
import '../../../../core/utils/logger.dart';
import 'tts_synthesizer.dart';

/// Speaks with [primary] (Kokoro) and falls back to [fallback]
/// (Supertonic) when the primary throws: its model is still downloading,
/// it failed to install, it has no voice for the language, or one sentence
/// failed. Both write the same scratch files, so [delete] goes to either.
/// Without a fallback the primary's error reaches the queue (the sentence
/// stays text-only).
class FallbackTtsSynthesizer implements TtsSynthesizer {
  FallbackTtsSynthesizer({
    required TtsSynthesizer primary,
    required TtsSynthesizer? fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final TtsSynthesizer _primary;
  final TtsSynthesizer? _fallback;

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    try {
      return await _primary.synthesize(
        text: text,
        language: language,
        voiceEffect: voiceEffect,
      );
    } catch (e) {
      final TtsSynthesizer? fallback = _fallback;
      if (fallback == null) rethrow;
      AppLogger.warning(
        'Primary TTS unavailable ($e), using the fallback voice',
        tag: 'FallbackTtsSynthesizer',
      );
      return fallback.synthesize(
        text: text,
        language: language,
        voiceEffect: voiceEffect,
      );
    }
  }

  @override
  Future<void> delete(String path) => _primary.delete(path);
}
