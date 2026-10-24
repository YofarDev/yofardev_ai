import '../../../../core/models/voice_effect.dart';

/// Domain contract for speech synthesis.
///
/// Implemented by the data layer (`TtsDatasource`); the domain TTS queue
/// depends on this abstraction only.
abstract class TtsSynthesizer {
  /// Synthesize [text] into an audio file and return its path.
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  });

  /// Deletes a synthesized audio file. Best-effort: failures are swallowed
  /// by implementations (scratch cleanup, never a user-facing error).
  Future<void> delete(String path);
}
