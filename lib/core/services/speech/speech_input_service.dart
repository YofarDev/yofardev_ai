/// Push-to-talk speech input for the Home stage composer.
///
/// Nothing is asked at launch: the microphone permission and the recognizer
/// are set up on the first [start].
abstract class SpeechInputService {
  /// False on web, macOS and Linux (no stable recognizer there): hide the mic.
  bool get isSupported;

  /// Input level normalised to 0–1 while listening (0 once it stops).
  Stream<double> get soundLevel;

  /// Words heard so far in the current session.
  Stream<String> get partialWords;

  /// Starts a listening session in [localeId] (e.g. `fr_FR`).
  Future<SpeechStartResult> start({required String localeId});

  /// Ends the session and returns the final words ('' if none). Still
  /// returns the words when the recognizer already stopped on its own.
  Future<String> stop();

  /// Ends the session and drops the words.
  Future<void> cancel();
}

enum SpeechStartResult { started, permissionDenied, unavailable }
