import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';

import '../../models/performance/performance.dart';
import '../../models/result.dart';
import '../../utils/logger.dart';
import '../power/power_saver_source.dart';
import '../settings_local_datasource.dart';
import 'frame_drift_watch.dart';
import 'frame_stats.dart';
import 'frame_timing_source.dart';
import 'thermal_source.dart';

/// The thermal cap on the tier (moonshot M11 ruling 12), strictest last.
enum ThermalCap {
  /// Nominal or light: no cap.
  none,

  /// Moderate: one tier below the benchmark.
  oneBelow,

  /// Severe or critical: low.
  low;

  static ThermalCap of(ThermalLevel level) => switch (level) {
    ThermalLevel.nominal || ThermalLevel.light => ThermalCap.none,
    ThermalLevel.moderate => ThermalCap.oneBelow,
    ThermalLevel.severe || ThermalLevel.critical => ThermalCap.low,
  };

  /// The tier this cap allows under [benchmark].
  QualityTier capOf(QualityTier benchmark) => switch (this) {
    ThermalCap.none => benchmark,
    ThermalCap.oneBelow => benchmark.oneBelow,
    ThermalCap.low => QualityTier.low,
  };
}

/// The quality tier in force (moonshot M11 ruling 12):
///
///     effective = min(benchmark, thermal cap, battery cap, drift cap)
///
/// never above the benchmark; a [forceTier] override (the UI lab, the
/// frame-cost harness) wins over everything. [current] is the effective tier
/// and [changes] / [tier] emit only when it changes.
///
/// - **Benchmark** (the M0 probe, [probe]): a 3 s `FrameTiming` window, P95
///   of `max(build, raster)`, the fps validity rule; ultra ≤ 3.3 ms, high ≤
///   6.6 ms, else low. Run once per [benchVersion]: started when the stage
///   first shows a scene ([notifyStageShown]), or [stageFallback] after the
///   first frame when no scene shows. A tier stored by an older bench is used
///   until the re-run lands. `high` before any benchmark.
/// - **Thermal** ([ThermalSource]): moderate caps one tier below the
///   benchmark, severe / critical cap low. A worse level applies at once; a
///   looser cap only after [thermalRelief] continuously at a level that
///   allows it (hysteresis).
/// - **Battery saver** ([PowerSaverSource]): on caps low, off lifts it.
/// - **Drift** ([FrameDriftWatch], while the stage is active
///   ([setStageActive]) and nothing is forced): three 10 s windows in a row
///   over the tier's budget × 1.25 drop one tier for the rest of the session
///   (never restored in-session, never persisted).
class QualityTierService {
  QualityTierService({
    required FrameTimingSource timingSource,
    required SettingsLocalDatasource settings,
    ThermalSource thermal = const NominalThermalSource(),
    PowerSaverSource? power,
    this.probeWindow = const Duration(seconds: 3),
    this.stageFallback = const Duration(seconds: 10),
    this.thermalRelief = const Duration(seconds: 120),
    Duration driftWindow = const Duration(seconds: 10),
  }) : _source = timingSource,
       _settings = settings,
       _thermal = thermal,
       _power = power {
    _drift = FrameDriftWatch(
      source: timingSource,
      tier: () => current,
      onDrift: _onDrift,
      window: driftWindow,
    );
  }

  static const String _tag = 'QualityTier';

  /// The benchmark's version: a stored tier from an older one re-runs once.
  static const int benchVersion = 2;

  final FrameTimingSource _source;
  final SettingsLocalDatasource _settings;
  final ThermalSource _thermal;
  final PowerSaverSource? _power;
  final Duration probeWindow;

  /// How long after the first frame the benchmark waits for a scene.
  final Duration stageFallback;

  /// How long a looser thermal cap must hold before it applies.
  final Duration thermalRelief;

  late final FrameDriftWatch _drift;

  static const int _maxProbeAttempts = 2;

  static const double _ultraThresholdMs = 3.3;
  static const double _highThresholdMs = 6.6;

  /// Minimum frames in an fps-invalid window for the over-budget rule to
  /// apply (a nearly idle window says nothing about device speed).
  static const int _minOverBudgetFrames = 20;

  QualityTier _benchmark = QualityTier.high;
  ThermalCap _thermalCap = ThermalCap.none;
  ThermalLevel _thermalLevel = ThermalLevel.nominal;
  bool _powerSaver = false;
  QualityTier? _driftCap;
  QualityTier? _forced;

  bool _needsBench = false;
  bool _benchStarted = false;
  bool _probing = false;
  bool _stageActive = false;
  bool _stageShown = false;
  bool _disposed = false;
  Timer? _fallbackTimer;
  Timer? _reliefTimer;
  ThermalCap? _reliefTarget;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  final ValueNotifier<QualityTier> _tier = ValueNotifier<QualityTier>(
    QualityTier.high,
  );

  final StreamController<QualityTier> _changes =
      StreamController<QualityTier>.broadcast();

  /// The tier in force; `high` before any benchmark.
  QualityTier get current => _tier.value;

  /// The tier in force, for widgets.
  ValueListenable<QualityTier> get tier => _tier;

  /// Emits every change of the tier in force.
  Stream<QualityTier> get changes => _changes.stream;

  /// The benchmark's tier (stored or measured; `high` before any).
  QualityTier get benchmark => _benchmark;

  /// The forced tier, if any.
  QualityTier? get forced => _forced;

  /// The thermal cap in force.
  ThermalCap get thermalCap => _thermalCap;

  /// The session's drift cap, if a drift happened.
  QualityTier? get driftCap => _driftCap;

  /// Whether the drift watch samples now.
  @visibleForTesting
  bool get driftWatching => _drift.active;

  /// Nearest-rank P95 of the given per-frame durations in ms.
  static double p95Ms(List<double> frameMs) => FrameStats.p95Ms(frameMs);

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

  /// The effective tier: [forced] if set, else the lowest of the benchmark
  /// and the caps.
  static QualityTier effective({
    required QualityTier benchmark,
    ThermalCap thermal = ThermalCap.none,
    bool powerSaver = false,
    QualityTier? driftCap,
    QualityTier? forced,
  }) {
    if (forced != null) {
      return forced;
    }
    return QualityTier.lowest(<QualityTier>[
      benchmark,
      thermal.capOf(benchmark),
      if (powerSaver) QualityTier.low,
      ?driftCap,
    ]);
  }

  /// Loads the stored tier, starts following the thermal state and battery
  /// saver, and arms the benchmark when none of the current version is
  /// stored (startup never waits for it).
  Future<void> init() async {
    _follow();
    final Result<String> stored = await _settings.getQualityTier();
    final Result<int> bench = await _settings.getQualityTierBench();
    final String? storedName = stored.getOrNull;
    QualityTier? storedTier;
    if (storedName != null && storedName.isNotEmpty) {
      try {
        storedTier = QualityTier.values.byName(storedName);
      } on ArgumentError {
        AppLogger.error(
          'QualityTier: unknown stored tier "$storedName", keeping high',
          tag: _tag,
        );
      }
    }
    if (storedTier != null) {
      _benchmark = storedTier;
      _recompute();
    }
    final int storedBench = bench.getOrNull ?? 0;
    if (storedTier != null && storedBench >= benchVersion) {
      AppLogger.debug(
        'QualityTier: loaded stored tier ${storedTier.name} (bench '
        '$storedBench)',
        tag: _tag,
      );
      return;
    }
    AppLogger.debug(
      storedTier == null
          ? 'QualityTier: no stored tier, benchmark armed'
          : 'QualityTier: tier ${storedTier.name} is from bench $storedBench, '
                're-benchmark armed',
      tag: _tag,
    );
    _needsBench = true;
    if (_stageShown) {
      // The stage beat the stored-tier read: benchmark now.
      _startBench();
      return;
    }
    unawaited(
      _source.firstFrameDrawn.then((_) {
        if (_disposed || _benchStarted) {
          return;
        }
        _fallbackTimer = Timer(stageFallback, () {
          _fallbackTimer = null;
          AppLogger.debug(
            'QualityTier: no scene shown within '
            '${stageFallback.inSeconds} s, benchmarking anyway',
            tag: _tag,
          );
          _startBench();
        });
      }),
    );
  }

  /// The stage shows a scene: the benchmark starts (once) if one is armed.
  void notifyStageShown() {
    _stageShown = true;
    _startBench();
  }

  /// Whether the stage is on screen with the app resumed: the drift watch
  /// samples only then.
  void setStageActive(bool active) {
    _stageActive = active;
    _syncDrift();
  }

  /// Forces [tier] over everything (null: back to the computed tier). Debug
  /// and test hook (the UI lab, the frame-cost harness).
  void forceTier(QualityTier? tier) {
    _forced = tier;
    AppLogger.debug('QualityTier: forced ${tier?.name ?? 'off'}', tag: _tag);
    _recompute();
  }

  void _follow() {
    if (_subscriptions.isNotEmpty) {
      return;
    }
    _subscriptions.add(_thermal.changes.listen(_onThermal));
    unawaited(
      _thermal.current.then((ThermalLevel level) {
        if (!_disposed) {
          _onThermal(level);
        }
      }),
    );
    final PowerSaverSource? power = _power;
    if (power != null) {
      _subscriptions.add(
        power.changes.listen(
          _onPowerSaver,
          onError: (Object error) => AppLogger.warning(
            'QualityTier: power saver stream error ($error)',
            tag: _tag,
          ),
        ),
      );
      unawaited(
        power.isOn
            .then((bool on) {
              if (!_disposed) {
                _onPowerSaver(on);
              }
            })
            .catchError((Object error) {
              AppLogger.warning(
                'QualityTier: power saver unavailable ($error)',
                tag: _tag,
              );
            }),
      );
    }
  }

  void _onThermal(ThermalLevel level) {
    _thermalLevel = level;
    final ThermalCap next = ThermalCap.of(level);
    if (next.index >= _thermalCap.index) {
      // Worse (or the same): at once, and any pending relief is off.
      _reliefTimer?.cancel();
      _reliefTimer = null;
      _reliefTarget = null;
      if (next != _thermalCap) {
        _thermalCap = next;
        AppLogger.debug(
          'QualityTier: thermal ${level.name} -> cap ${next.name}',
          tag: _tag,
        );
        _recompute();
      }
      return;
    }
    // Looser: only after it held for [thermalRelief]. A different looser
    // level starts the wait over (the cap it would lift to changed).
    if (_reliefTimer != null && _reliefTarget == next) {
      return;
    }
    _reliefTimer?.cancel();
    _reliefTarget = next;
    _reliefTimer = Timer(thermalRelief, () {
      _reliefTimer = null;
      _reliefTarget = null;
      if (next.index < _thermalCap.index) {
        _thermalCap = next;
        AppLogger.debug(
          'QualityTier: thermal ${_thermalLevel.name} held '
          '${thermalRelief.inSeconds} s -> cap ${next.name}',
          tag: _tag,
        );
        _recompute();
      }
    });
  }

  void _onPowerSaver(bool on) {
    if (on == _powerSaver) {
      return;
    }
    _powerSaver = on;
    AppLogger.debug(
      'QualityTier: battery saver ${on ? 'on' : 'off'}',
      tag: _tag,
    );
    _recompute();
  }

  void _onDrift() {
    final QualityTier from = current;
    final QualityTier next = from.oneBelow;
    if (next == from) {
      return;
    }
    _driftCap = next;
    AppLogger.info(
      'QualityTier: sustained frame drift at ${from.name}, '
      '${next.name} for the session',
      tag: _tag,
    );
    _recompute();
  }

  void _recompute() {
    if (_disposed) {
      return;
    }
    final QualityTier next = effective(
      benchmark: _benchmark,
      thermal: _thermalCap,
      powerSaver: _powerSaver,
      driftCap: _driftCap,
      forced: _forced,
    );
    if (next != _tier.value) {
      _tier.value = next;
      _changes.add(next);
    }
    _syncDrift();
  }

  void _syncDrift() {
    if (_disposed) {
      return;
    }
    _drift.active =
        _stageActive &&
        _forced == null &&
        !_probing &&
        current != QualityTier.low;
  }

  void _startBench() {
    if (_disposed || !_needsBench || _benchStarted) {
      return;
    }
    _benchStarted = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    unawaited(probe());
  }

  /// Runs up to [_maxProbeAttempts] collection windows and returns the tier
  /// derived from the first valid attempt (stored with [benchVersion]); when
  /// every attempt is invalid the benchmark is returned unchanged.
  Future<QualityTier> probe() async {
    _probing = true;
    _syncDrift();
    try {
      return await _probe();
    } finally {
      _probing = false;
      _syncDrift();
    }
  }

  Future<QualityTier> _probe() async {
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
            tag: _tag,
          );
          await _storeBenchmark(QualityTier.low);
          return QualityTier.low;
        }
      }
      if (!valid) {
        AppLogger.debug(
          'QualityTier: probe attempt $attempt invalid ($frames frames '
          'in ${probeWindow.inMilliseconds} ms), '
          '${attempt < _maxProbeAttempts ? 're-probing' : 'giving up'}',
          tag: _tag,
        );
        continue;
      }
      final double p95 = p95Ms(frameMs);
      final QualityTier tier = tierFor(p95);
      AppLogger.debug(
        'QualityTier: probe attempt $attempt valid: '
        'P95=${p95.toStringAsFixed(2)} ms -> ${tier.name}',
        tag: _tag,
      );
      await _storeBenchmark(tier);
      return tier;
    }
    return _benchmark;
  }

  /// Collects per-frame ms over [probeWindow]; null when no frame arrived.
  Future<List<double>?> _collectFrameMs() async {
    final Completer<List<double>> completer = Completer<List<double>>();
    final List<double> frameMs = <double>[];
    final StreamSubscription<List<FrameTiming>> subscription = _source.timings
        .listen((List<FrameTiming> batch) {
          for (final FrameTiming timing in batch) {
            frameMs.add(FrameStats.worstMs(timing));
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

  Future<void> _storeBenchmark(QualityTier tier) async {
    final Result<void> stored = await _settings.setQualityTier(tier.name);
    if (!stored.isOk) {
      AppLogger.error(
        'QualityTier: failed to persist tier ${tier.name}',
        tag: _tag,
      );
      return;
    }
    final Result<void> version = await _settings.setQualityTierBench(
      benchVersion,
    );
    if (!version.isOk) {
      AppLogger.error(
        'QualityTier: failed to persist the bench version',
        tag: _tag,
      );
    }
    _needsBench = false;
    _benchmark = tier;
    _recompute();
  }

  /// Stops the watch and the timers, closes the change stream.
  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _reliefTimer?.cancel();
    _drift.dispose();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _changes.close();
    _tier.dispose();
  }
}
