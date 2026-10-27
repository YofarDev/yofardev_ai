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

  /// Fires when the recognizer ends the current session on its own
  /// (silence timeout, final result, a permanent error), never for a
  /// [stop]/[cancel]. The words heard are then still returned by [stop].
  Stream<void> get sessionEnded;

  /// Starts a listening session in [localeId] (e.g. `fr_FR`). Overlapping
  /// calls share one pending start (the mic opens at most once); a start
  /// issued after a [stop]/[cancel] superseded the pending one waits for it
  /// to settle, then starts afresh.
  Future<SpeechStartResult> start({required String localeId});

  /// Ends the session and returns the final words ('' if none). Still
  /// returns the words when the recognizer already stopped on its own.
  /// Called while a start is pending, it aborts that start
  /// ([SpeechStartResult.cancelled]) before the mic opens.
  Future<String> stop();

  /// Ends the session and drops the words; aborts a pending start too.
  Future<void> cancel();

  /// Cancels any session and closes the streams. Owned by the DI container.
  Future<void> dispose();
}

enum SpeechStartResult {
  started,
  permissionDenied,
  unavailable,

  /// [SpeechInputService.stop]/[SpeechInputService.cancel] came in while
  /// the start was still pending (permission dialog, initialize): nothing
  /// is listening and there is nothing to report to the user.
  cancelled,
}
