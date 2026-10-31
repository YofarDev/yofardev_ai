import 'dart:async';
import 'dart:ui' show FrameTiming, VoidCallback;

import '../../models/performance/performance.dart';
import '../../utils/logger.dart';
import 'frame_stats.dart';
import 'frame_timing_source.dart';

/// How one sampling window of the [FrameDriftWatch] came out.
enum DriftWindow {
  /// Too few frames to say anything (idle, nothing animating).
  idle,

  /// Its P95 is within the tier's budget × the over-budget factor.
  withinBudget,

  /// Its P95 is over the tier's budget × the over-budget factor.
  overBudget,
}

/// Watches for sustained frame drift on the stage (moonshot M11 ruling 12):
/// while [active] (Home shown, the app resumed), it samples the
/// [FrameTimingSource] in [window]s; each window's P95 of
/// `max(build, raster)` is compared with the current [tier]'s
/// [QualityTier.frameBudgetMs] × [overBudgetFactor]. [windowsToDrop]
/// over-budget windows in a row call [onDrift] once (the tier service drops
/// one tier for the session) and start the count over.
///
/// A window with fewer than [minFramesPerSecond] frames per second is
/// [DriftWindow.idle]: it is not judged and it breaks the streak (drift must
/// be sustained while something animates). Going inactive drops the window in
/// progress and the streak.
class FrameDriftWatch {
  FrameDriftWatch({
    required FrameTimingSource source,
    required QualityTier Function() tier,
    required VoidCallback onDrift,
    this.window = const Duration(seconds: 10),
    this.windowsToDrop = 3,
    this.overBudgetFactor = 1.25,
    this.minFramesPerSecond = 10,
  }) : _source = source,
       _tier = tier,
       _onDrift = onDrift;

  static const String _tag = 'QualityTier';

  final FrameTimingSource _source;
  final QualityTier Function() _tier;
  final VoidCallback _onDrift;

  /// One sampling window.
  final Duration window;

  /// Over-budget windows in a row that make a drift.
  final int windowsToDrop;

  /// How far over its budget a window's P95 must be (ruling 12: 1.25).
  final double overBudgetFactor;

  /// Fewer frames per second than this: an idle window.
  final double minFramesPerSecond;

  StreamSubscription<List<FrameTiming>>? _subscription;
  Timer? _timer;
  List<double> _frameMs = <double>[];
  int _streak = 0;
  bool _active = false;
  bool _disposed = false;

  /// Whether the watch samples now.
  bool get active => _active;

  /// Over-budget windows in a row so far.
  int get streak => _streak;

  set active(bool value) {
    if (_disposed || value == _active) {
      return;
    }
    _active = value;
    if (value) {
      _start();
    } else {
      _stop();
    }
  }

  /// Judges one window of [frameMs] (per-frame `max(build, raster)`) at
  /// [tier] over [window].
  static DriftWindow judge({
    required List<double> frameMs,
    required QualityTier tier,
    required Duration window,
    double overBudgetFactor = 1.25,
    double minFramesPerSecond = 10,
  }) {
    final double seconds = window.inMicroseconds / 1e6;
    if (seconds <= 0 || frameMs.length < minFramesPerSecond * seconds) {
      return DriftWindow.idle;
    }
    final double p95 = FrameStats.p95Ms(frameMs);
    return p95 > tier.frameBudgetMs * overBudgetFactor
        ? DriftWindow.overBudget
        : DriftWindow.withinBudget;
  }

  void _start() {
    _frameMs = <double>[];
    _subscription = _source.timings.listen(_onTimings);
    _timer = Timer.periodic(window, (Timer _) => _closeWindow());
  }

  void _stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _frameMs = <double>[];
    _streak = 0;
  }

  void _onTimings(List<FrameTiming> batch) {
    for (final FrameTiming timing in batch) {
      _frameMs.add(FrameStats.worstMs(timing));
    }
  }

  void _closeWindow() {
    final List<double> frames = _frameMs;
    _frameMs = <double>[];
    final QualityTier tier = _tier();
    final DriftWindow verdict = judge(
      frameMs: frames,
      tier: tier,
      window: window,
      overBudgetFactor: overBudgetFactor,
      minFramesPerSecond: minFramesPerSecond,
    );
    if (verdict != DriftWindow.overBudget) {
      _streak = 0;
      return;
    }
    _streak++;
    AppLogger.debug(
      'FrameDriftWatch: window over budget at ${tier.name} '
      '(P95 ${FrameStats.p95Ms(frames).toStringAsFixed(2)} ms, '
      '$_streak/$windowsToDrop)',
      tag: _tag,
    );
    if (_streak >= windowsToDrop) {
      _streak = 0;
      _onDrift();
    }
  }

  /// Stops sampling for good.
  void dispose() {
    _stop();
    _active = false;
    _disposed = true;
  }
}
