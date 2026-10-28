import 'dart:async';

/// Source of the real playback position, implemented by
/// `AudioPlayerService` (the active player's `getCurrentPosition()`, null
/// when no player is active).
abstract interface class PlaybackPositionSource {
  Future<Duration?> currentPosition();
}

/// Closed-loop playback clock: a free-running stopwatch estimate that is
/// periodically re-anchored to the player's real position.
///
/// - The estimate is `anchor + stopwatch.elapsed`, re-anchored on every
///   [resync], so a stalled UI isolate catches up from the clock instead of
///   losing ticks.
/// - A resync that returns null, or zero while the estimate is still under
///   the cold-start grace (400 ms), keeps the estimate.
/// - A backward correction of 120 ms or less is absorbed: the estimate holds
///   still until the real position catches up, so the mouth never moves
///   backwards. A larger backward correction is a seek and re-anchors.
/// - A forward correction is applied immediately.
class PlaybackClock {
  PlaybackClock({
    required PlaybackPositionSource source,
    Stopwatch Function()? stopwatchFactory,
    this.resyncEvery = const Duration(milliseconds: 100),
  }) : _source = source,
       _stopwatchFactory = stopwatchFactory ?? Stopwatch.new {
    _stopwatch = _stopwatchFactory();
  }

  final PlaybackPositionSource _source;
  final Stopwatch Function() _stopwatchFactory;
  final Duration resyncEvery;

  static const Duration _coldStartGrace = Duration(milliseconds: 400);
  static const Duration _absorbThreshold = Duration(milliseconds: 120);

  late Stopwatch _stopwatch;
  Duration _anchor = Duration.zero;
  Duration _holdFloor = Duration.zero;
  bool _running = false;
  bool _resyncInFlight = false;
  Timer? _resyncTimer;

  /// Starts (or restarts) the clock from zero and arms the periodic resync.
  void start() {
    _resyncTimer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _anchor = Duration.zero;
    _holdFloor = Duration.zero;
    _running = true;
    _resyncTimer = Timer.periodic(resyncEvery, (Timer _) {
      unawaited(resync());
    });
    unawaited(resync());
  }

  /// Synchronous estimate of the playback position (never moves backwards).
  Duration get position {
    if (!_running) {
      return Duration.zero;
    }
    final Duration estimate = _anchor + _stopwatch.elapsed;
    return estimate > _holdFloor ? estimate : _holdFloor;
  }

  /// Re-anchors the estimate to the player's real position, applying the
  /// absorption and cold-start rules documented on the class.
  Future<void> resync() async {
    if (!_running || _resyncInFlight) {
      return;
    }
    _resyncInFlight = true;
    try {
      final Duration? real = await _source.currentPosition();
      if (!_running || real == null) {
        return;
      }
      final Duration estimate = position;
      if (real == Duration.zero && estimate < _coldStartGrace) {
        return;
      }
      final Duration diff = real - estimate;
      if (diff <= Duration.zero && -diff <= _absorbThreshold) {
        // Small backward correction: re-anchor at the real position but hold
        // the estimate where it is until reality catches up.
        _reanchor(real);
        _holdFloor = estimate;
        return;
      }
      _reanchor(real);
    } finally {
      _resyncInFlight = false;
    }
  }

  void stop() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _stopwatch.stop();
    _running = false;
  }

  void _reanchor(Duration position) {
    _anchor = position;
    _holdFloor = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
  }
}
