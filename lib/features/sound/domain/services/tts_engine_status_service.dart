import '../tts_engine_status.dart';

/// The on-device Kokoro voice's install state, and the way to install it.
///
/// Implemented by the data layer (`KokoroTtsService`).
abstract class TtsEngineStatusService {
  /// Latest status. Read this first: [status] replays nothing.
  TtsEngineStatus get current;

  /// Broadcast stream of status changes.
  Stream<TtsEngineStatus> get status;

  /// Ensures the model is installed and the engine loaded. Idempotent and
  /// single-flight: concurrent calls share one run, a no-op once ready.
  /// Never throws: a failure is reported as [TtsEngineStatus.failed].
  Future<void> install();
}
