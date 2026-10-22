/// Repository interface for TTS-related operations
///
/// This abstracts the TTS service, allowing for easier testing
/// and separation of concerns.
abstract class TalkingRepository {
  /// Play a waiting sentence (does NOT show thinking animation)
  Future<void> playWaitingSentence(String sentence);

  /// Generate TTS for speech (shows thinking animation)
  Future<void> generateSpeech(String text);

  /// Stop all TTS playback
  Future<void> stop();
}
