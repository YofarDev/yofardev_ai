import 'dart:async';
import 'dart:ui' show FrameTiming;

import '../../models/performance/performance.dart';
import '../../utils/logger.dart';
import 'frame_timing_source.dart';
import '../../models/result.dart';
import '../settings_local_datasource.dart';

/// Quality-tier probe (M0 method): collects per-frame
/// `max(buildDuration, rasterDuration)` from [FrameTiming] over a probe
/// window, takes the P95, and maps it to a quality tier. A probe whose fps is
/// below 0.9 x refresh is invalid and never changes the stored tier, unless it
/// has enough frames and its P95 is over the refresh budget (a device too slow
/// to hold its refresh rate): that device is rated low. At most two attempts
/// run per [probe] call.
class QualityTierService {
  QualityTierService({
    required FrameTimingSource timingSource,
    required SettingsLocalDatasource settings,
    this.probeWindow = const Duration(seconds: 3),
  }) : _source = timingSource,
       _settings = settings;

  final FrameTimingSource _source;
  final SettingsLocalDatasource _settings;
  final Duration probeWindow;

  static const int _maxProbeAttempts = 2;

  static const double _ultraThresholdMs = 3.3;
  static const double _highThresholdMs = 6.6;

  /// Minimum frames in an fps-invalid window for the over-budget rule to
  /// apply (a nearly idle window says nothing about device speed).
  static const int _minOverBudgetFrames = 20;

  QualityTier _current = QualityTier.high;

  final StreamController<QualityTier> _changes =
      StreamController<QualityTier>.broadcast();

  /// The tier currently in force; `high` before any probe.
  QualityTier get current => _current;

  /// Emits every persisted tier change.
  Stream<QualityTier> get changes => _changes.stream;

  /// Nearest-rank P95 of the given per-frame durations in ms.
  static double p95Ms(List<double> frameMs) {
    if (frameMs.isEmpty) {
      return 0;
    }
    final List<double> sorted = List<double>.of(frameMs)..sort();
    final int rank = (sorted.length * 0.95).ceil();
    return sorted[rank - 1];
  }

  /// Maps a P95 frame time to a tier: ultra ≤ 3.3 ms, high ≤ 6.6 ms, else low.
  static QualityTier tierFor(double p95MsValue) {
    if (p95MsValue <= _ultraThresholdMs) {
      return QualityTier.ultra;
    }
    if (p95MsValue <= _highThresholdMs) {
      return QualityTier.high;
    }
    return QualityTier.low;
  }

  /// A probe is valid when its observed fps is at least 0.9 x [refreshRate]
  /// over [window]; invalid probes never change the stored tier.
  static bool isValidProbe({
    required int frames,
    required Duration window,
    required double refreshRate,
  }) {
    final double seconds = window.inMicroseconds / 1000000;
    if (seconds <= 0 || refreshRate <= 0) {
      return false;
    }
    final double fps = frames / seconds;
    return fps >= 0.9 * refreshRate;
  }

  /// Whether an fps-invalid probe still proves the device is too slow: enough
  /// frames were drawn and the P95 frame time exceeds the refresh budget
  /// (`1000 / refreshRate` ms).
  static bool isOverBudget({
    required int frames,
    required double p95Ms,
    required double refreshRate,
  }) {
    if (refreshRate <= 0 || frames < _minOverBudgetFrames) {
      return false;
    }
    return p95Ms > 1000 / refreshRate;
  }

  /// Loads the stored tier; when none is stored, schedules a probe after the
  /// first frame without awaiting it (startup is never blocked).
  Future<void> init() async {
    final Result<String> stored = await _settings.getQualityTier();
    final String? storedName = stored.getOrNull;
    if (storedName != null && storedName.isNotEmpty) {
      try {
        _current = QualityTier.values.byName(storedName);
        AppLogger.debug(
          'QualityTier: loaded stored tier ${_current.name}',
          tag: 'QualityTier',
        );
        return;
      } on ArgumentError {
        AppLogger.error(
          'QualityTier: unknown stored tier "$storedName", keeping high',
          tag: 'QualityTier',
        );
      }
    }
    AppLogger.debug(
      'QualityTier: no stored tier, scheduling probe after the first frame',
      tag: 'QualityTier',
    );
    unawaited(_source.firstFrameDrawn.then((_) => probe()));
  }

  /// Runs up to [_maxProbeAttempts] collection windows and returns the tier
  /// derived from the first valid attempt; when every attempt is invalid the
  /// stored tier is returned unchanged.
  Future<QualityTier> probe() async {
    for (int attempt = 1; attempt <= _maxProbeAttempts; attempt++) {
      final List<double>? frameMs = await _collectFrameMs();
      final int frames = frameMs?.length ?? 0;
      final bool valid =
          frameMs != null &&
          isValidProbe(
            frames: frames,
            window: probeWindow,
            refreshRate: _source.refreshRate,
          );
      if (!valid && frameMs != null) {
        final double p95 = p95Ms(frameMs);
        if (isOverBudget(
          frames: frames,
          p95Ms: p95,
          refreshRate: _source.refreshRate,
        )) {
          AppLogger.debug(
            'QualityTier: probe attempt $attempt too slow to hold the '
            'refresh rate: P95=${p95.toStringAsFixed(2)} ms -> low',
            tag: 'QualityTier',
          );
          await _storeTier(QualityTier.low);
          return QualityTier.low;
        }
      }
      if (!valid) {
        AppLogger.debug(
          'QualityTier: probe attempt $attempt invalid ($frames frames '
          'in ${probeWindow.inMilliseconds} ms), '
          '${attempt < _maxProbeAttempts ? 're-probing' : 'giving up'}',
          tag: 'QualityTier',
        );
        continue;
      }
      final double p95 = p95Ms(frameMs);
      final QualityTier tier = tierFor(p95);
      AppLogger.debug(
        'QualityTier: probe attempt $attempt valid: P95=${p95.toStringAsFixed(2)} ms -> ${tier.name}',
        tag: 'QualityTier',
      );
      await _storeTier(tier);
      return tier;
    }
    return _current;
  }

  /// Collects per-frame ms over [probeWindow]; null when no frame arrived.
  Future<List<double>?> _collectFrameMs() async {
    final Completer<List<double>> completer = Completer<List<double>>();
    final List<double> frameMs = <double>[];
    final StreamSubscription<List<FrameTiming>> subscription = _source.timings
        .listen((List<FrameTiming> batch) {
          for (final FrameTiming timing in batch) {
            final Duration worst = timing.buildDuration > timing.rasterDuration
                ? timing.buildDuration
                : timing.rasterDuration;
            frameMs.add(worst.inMicroseconds / 1000);
          }
        });
    Timer(probeWindow, () {
      if (!completer.isCompleted) {
        completer.complete(List<double>.of(frameMs));
      }
    });
    final List<double> collected = await completer.future;
    // Broadcast subscriptions cancel without further work; the future only
    // completes on a later microtask/event, so do not await it here.
    unawaited(subscription.cancel());
    return collected.isEmpty ? null : collected;
  }

  Future<void> _storeTier(QualityTier tier) async {
    final Result<void> stored = await _settings.setQualityTier(tier.name);
    if (!stored.isOk) {
      AppLogger.error(
        'QualityTier: failed to persist tier ${tier.name}',
        tag: 'QualityTier',
      );
      return;
    }
    _current = tier;
    _changes.add(tier);
  }

  /// Closes the change stream.
  void dispose() {
    _changes.close();
  }
}
