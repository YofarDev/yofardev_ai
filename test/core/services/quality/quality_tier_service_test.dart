import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/core/services/quality/frame_timing_source.dart';
import 'package:yofardev_ai/core/services/quality/quality_tier_service.dart';
import 'package:yofardev_ai/core/services/quality/thermal_source.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

FrameTiming _frame(num milliseconds) {
  final int micros = (milliseconds * 1000).round();
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: micros,
    rasterStart: micros,
    rasterFinish: micros,
    rasterFinishWallTime: 0,
  );
}

class _FakeTimingSource implements FrameTimingSource {
  double _refreshRate = 60;

  final StreamController<List<FrameTiming>> _controller =
      StreamController<List<FrameTiming>>.broadcast();

  int listenCount = 0;

  /// Completed by [drawFirstFrame]; the production source completes it once
  /// the app has rasterized its first frame.
  final Completer<void> _firstFrame = Completer<void>();

  void drawFirstFrame() => _firstFrame.complete();

  @override
  Future<void> get firstFrameDrawn => _firstFrame.future;

  @override
  double get refreshRate => _refreshRate;

  set refreshRate(double value) {
    _refreshRate = value;
  }

  @override
  Stream<List<FrameTiming>> get timings {
    listenCount++;
    return _controller.stream;
  }

  void emit(List<FrameTiming> batch) {
    _controller.add(batch);
  }
}

class _FakeThermal implements ThermalSource {
  ThermalLevel level = ThermalLevel.nominal;
  bool fails = false;
  final StreamController<ThermalLevel> _controller =
      StreamController<ThermalLevel>.broadcast();

  void set(ThermalLevel value) {
    level = value;
    _controller.add(value);
  }

  @override
  Future<ThermalLevel> get current async {
    if (fails) {
      throw StateError('no thermal');
    }
    return level;
  }

  @override
  Stream<ThermalLevel> get changes => _controller.stream;
}

class _FakePower implements PowerSaverSource {
  bool on = false;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  void set(bool value) {
    on = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOn async => on;

  @override
  Stream<bool> get changes => _controller.stream;
}

/// Drives [QualityTierService.probe] inside a fake clock.
class _Harness {
  _Harness(
    this.async, {
    Map<String, Object>? prefs,
    bool firstFrameDrawn = true,
  }) : source = _FakeTimingSource(),
       settings = SettingsLocalDatasource() {
    if (firstFrameDrawn) {
      source.drawFirstFrame();
    }
    SharedPreferences.setMockInitialValues(prefs ?? <String, Object>{});
    service = QualityTierService(
      timingSource: source,
      settings: settings,
      thermal: thermal,
      power: power,
    );
    service.changes.listen(changes.add);
  }

  final FakeAsync async;
  final _FakeTimingSource source;
  final SettingsLocalDatasource settings;
  final _FakeThermal thermal = _FakeThermal();
  final _FakePower power = _FakePower();
  late final QualityTierService service;
  final List<QualityTier> changes = <QualityTier>[];

  /// Runs [QualityTierService.init] and lets the prefs and the sources
  /// answer.
  void init() {
    unawaited(service.init());
    settle();
  }

  void settle() {
    async.elapse(const Duration(milliseconds: 1));
    async.flushMicrotasks();
  }

  /// Emits [fps] frames of [frameMs] per second for [duration], in 100 ms
  /// batches.
  void feed(Duration duration, {double fps = 60, num frameMs = 3}) {
    final int steps = duration.inMilliseconds ~/ 100;
    final int perBatch = (fps / 10).round();
    for (int i = 0; i < steps; i++) {
      source.emit(List<FrameTiming>.generate(perBatch, (_) => _frame(frameMs)));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
    }
  }

  String? storedString(String key) {
    String? value;
    unawaited(
      SharedPreferences.getInstance().then(
        (SharedPreferences p) => value = p.getString(key),
      ),
    );
    settle();
    return value;
  }

  int? storedInt(String key) {
    int? value;
    unawaited(
      SharedPreferences.getInstance().then(
        (SharedPreferences p) => value = p.getInt(key),
      ),
    );
    settle();
    return value;
  }

  /// Runs [QualityTierService.probe] to completion by elapsing the fake clock
  /// and emitting [framesPerWindow[w]] frames of [frameMs] across each
  /// collected window [w]. One [probe] call may span two windows (one
  /// re-probe attempt).
  QualityTier? runProbe({
    List<int> framesPerWindow = const <int>[28],
    int frameMs = 3,
  }) {
    QualityTier? result;
    unawaited(
      service.probe().then((QualityTier tier) {
        result = tier;
      }),
    );
    for (final int frames in framesPerWindow) {
      // One 3 s window in seven 400 ms steps: all batches land before the
      // window timer fires at 3000 ms.
      for (int i = 0; i < 7; i++) {
        async.elapse(const Duration(milliseconds: 400));
        source.emit(List<FrameTiming>.generate(frames, (_) => _frame(frameMs)));
        // Broadcast-stream events are delivered as microtasks: run them
        // before advancing the clock again.
        async.flushMicrotasks();
      }
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
    }
    // Prefs replies land on zero-duration timers: elapse past them.
    async.elapse(const Duration(milliseconds: 1));
    async.flushMicrotasks();
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QualityTierService.p95Ms', () {
    test('nearest-rank P95 of a known list', () {
      expect(
        QualityTierService.p95Ms(<double>[
          10,
          40,
          20,
          30,
          12,
          33,
          21,
          11,
          9,
          50,
        ]),
        50,
      );
      expect(QualityTierService.p95Ms(<double>[3, 1, 2]), 3);
      expect(QualityTierService.p95Ms(const <double>[]), 0);
    });
  });

  group('QualityTierService.tierFor', () {
    test('threshold edges', () {
      expect(QualityTierService.tierFor(3.3), QualityTier.ultra);
      expect(QualityTierService.tierFor(3.31), QualityTier.high);
      expect(QualityTierService.tierFor(6.6), QualityTier.high);
      expect(QualityTierService.tierFor(6.61), QualityTier.low);
    });
  });

  group('QualityTierService.isValidProbe', () {
    test('fps gate at 0.9 x refresh', () {
      // 162 frames in 3 s = 54 fps = 0.9 x 60.
      expect(
        QualityTierService.isValidProbe(
          frames: 162,
          window: const Duration(seconds: 3),
          refreshRate: 60,
        ),
        isTrue,
      );
      expect(
        QualityTierService.isValidProbe(
          frames: 161,
          window: const Duration(seconds: 3),
          refreshRate: 60,
        ),
        isFalse,
      );
      expect(
        QualityTierService.isValidProbe(
          frames: 162,
          window: Duration.zero,
          refreshRate: 60,
        ),
        isFalse,
      );
    });
  });

  group('QualityTierService.isOverBudget', () {
    test('needs enough frames and a P95 above the refresh budget', () {
      // 60 Hz budget = 16.67 ms.
      expect(
        QualityTierService.isOverBudget(frames: 35, p95Ms: 17, refreshRate: 60),
        isTrue,
      );
      expect(
        QualityTierService.isOverBudget(frames: 35, p95Ms: 16, refreshRate: 60),
        isFalse,
      );
      expect(
        QualityTierService.isOverBudget(frames: 5, p95Ms: 40, refreshRate: 60),
        isFalse,
      );
      expect(
        QualityTierService.isOverBudget(frames: 35, p95Ms: 40, refreshRate: 0),
        isFalse,
      );
    });
  });

  group('QualityTierService.probe', () {
    test('a device too slow to hold its refresh rate is rated low', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // 5 x 7 = 35 frames in 3 s (about 12 fps, an invalid probe) of
        // 40 ms each: well over the 16.7 ms budget at 60 Hz.
        final QualityTier? result = h.runProbe(
          framesPerWindow: const <int>[5],
          frameMs: 40,
        );

        expect(result, QualityTier.low);
        expect(h.service.current, QualityTier.low);
        expect(h.changes, <QualityTier>[QualityTier.low]);
        // The first window already decides: no re-probe.
        expect(h.source.listenCount, 1);

        String? stored;
        unawaited(
          SharedPreferences.getInstance().then(
            (SharedPreferences p) => stored = p.getString('quality_tier'),
          ),
        );
        h.async.elapse(const Duration(milliseconds: 1));
        h.async.flushMicrotasks();
        expect(stored, 'low');
      });
    });

    test('a valid probe persists the tier and emits on changes', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // 7 x 28 = 196 >= 162 frames; 3 ms P95 -> ultra.
        final QualityTier? result = h.runProbe();

        expect(h.changes, <QualityTier>[QualityTier.ultra]);
        expect(h.service.current, QualityTier.ultra);
        expect(result, QualityTier.ultra);

        // Persisted in prefs.
        String? stored;
        unawaited(
          SharedPreferences.getInstance().then(
            (SharedPreferences p) => stored = p.getString('quality_tier'),
          ),
        );
        h.async.elapse(const Duration(milliseconds: 1));
        h.async.flushMicrotasks();
        expect(stored, 'ultra');
      });
    });

    test('an fps gate failure triggers a re-probe', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // Window 1 starved (14 frames), window 2 valid: the service must
        // re-probe internally (two subscriptions) and take window 2's tier.
        final QualityTier? result = h.runProbe(
          framesPerWindow: const <int>[2, 28],
        );

        expect(h.source.listenCount, 2);
        expect(result, QualityTier.ultra);
        expect(h.changes, <QualityTier>[QualityTier.ultra]);
      });
    });

    test('a starved first attempt emits nothing yet', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // Only 14 frames in the window -> invalid, no change yet. The
        // internal re-probe window is left running.
        unawaited(h.service.probe());
        for (int i = 0; i < 7; i++) {
          h.async.elapse(const Duration(milliseconds: 400));
          h.source.emit(List<FrameTiming>.generate(2, (_) => _frame(3)));
          h.async.flushMicrotasks();
        }
        h.async.elapse(const Duration(milliseconds: 200));
        h.async.flushMicrotasks();

        expect(h.changes, isEmpty);
        expect(h.service.current, QualityTier.high);
      });
    });

    test('two invalid probes keep the stored tier', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        final QualityTier? result = h.runProbe(
          framesPerWindow: const <int>[2, 2],
        );

        expect(h.source.listenCount, 2);
        expect(result, QualityTier.high);
        expect(h.changes, isEmpty);
        expect(h.service.current, QualityTier.high);
      });
    });
  });

  group('QualityTierService.init', () {
    test('a stored tier of the current bench loads and never probes', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(
          async,
          prefs: <String, Object>{
            'quality_tier': 'low',
            'quality_tier_bench': QualityTierService.benchVersion,
          },
        );
        h.init();
        h.service.notifyStageShown();
        h.async.elapse(const Duration(seconds: 30));

        expect(h.service.current, QualityTier.low);
        expect(h.service.benchmark, QualityTier.low);
        expect(h.source.listenCount, 0);
        expect(h.changes, <QualityTier>[QualityTier.low]);
      });
    });

    test('a tier from an older bench is kept and re-benchmarked once', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(
          async,
          prefs: <String, Object>{'quality_tier': 'low'},
        );
        h.init();
        expect(h.service.current, QualityTier.low);
        expect(h.source.listenCount, 0);

        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
        h.feed(const Duration(milliseconds: 3200), frameMs: 3);
        h.settle();

        expect(h.service.current, QualityTier.ultra);
        expect(h.storedString('quality_tier'), 'ultra');
        expect(h.storedInt('quality_tier_bench'), 2);

        // A second stage show does not run it again.
        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
      });
    });

    test('without a stored tier it waits for the stage, not the first '
        'frame', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.init();
        h.async.elapse(const Duration(seconds: 5));
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.high);
        expect(h.source.listenCount, 0);

        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
        h.feed(const Duration(milliseconds: 3200), frameMs: 3);
        h.settle();
        expect(h.service.current, QualityTier.ultra);
      });
    });

    test('a stage shown before init finished still benchmarks', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.service.notifyStageShown();
        h.init();
        expect(h.source.listenCount, 1);
      });
    });

    test('no scene within the fallback: benchmark after the first frame + '
        'the fallback', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async, firstFrameDrawn: false);
        h.init();
        h.async.elapse(const Duration(seconds: 30));
        expect(h.source.listenCount, 0);

        h.source.drawFirstFrame();
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 9));
        expect(h.source.listenCount, 0);
        h.async.elapse(const Duration(seconds: 1));
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);

        // The stage showing later starts nothing more.
        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
      });
    });
  });

  group('QualityTierService.effective', () {
    test('the lowest of the benchmark and the caps, never above the '
        'benchmark', () {
      for (final QualityTier bench in QualityTier.values) {
        expect(QualityTierService.effective(benchmark: bench), bench);
        expect(
          QualityTierService.effective(
            benchmark: bench,
            thermal: ThermalCap.oneBelow,
          ),
          bench.oneBelow,
        );
        expect(
          QualityTierService.effective(
            benchmark: bench,
            thermal: ThermalCap.low,
          ),
          QualityTier.low,
        );
        expect(
          QualityTierService.effective(benchmark: bench, powerSaver: true),
          QualityTier.low,
        );
        expect(
          QualityTierService.effective(
            benchmark: bench,
            driftCap: QualityTier.ultra,
          ),
          bench,
        );
      }
      expect(
        QualityTierService.effective(
          benchmark: QualityTier.ultra,
          driftCap: QualityTier.high,
          thermal: ThermalCap.oneBelow,
        ),
        QualityTier.high,
      );
    });

    test('a forced tier wins over everything', () {
      expect(
        QualityTierService.effective(
          benchmark: QualityTier.low,
          powerSaver: true,
          thermal: ThermalCap.low,
          driftCap: QualityTier.low,
          forced: QualityTier.ultra,
        ),
        QualityTier.ultra,
      );
    });

    test('thermal levels map to caps', () {
      expect(ThermalCap.of(ThermalLevel.nominal), ThermalCap.none);
      expect(ThermalCap.of(ThermalLevel.light), ThermalCap.none);
      expect(ThermalCap.of(ThermalLevel.moderate), ThermalCap.oneBelow);
      expect(ThermalCap.of(ThermalLevel.severe), ThermalCap.low);
      expect(ThermalCap.of(ThermalLevel.critical), ThermalCap.low);
    });
  });

  group('QualityTierService caps', () {
    _Harness ultra(FakeAsync async) {
      final _Harness h = _Harness(
        async,
        prefs: <String, Object>{
          'quality_tier': 'ultra',
          'quality_tier_bench': QualityTierService.benchVersion,
        },
      );
      h.init();
      h.changes.clear();
      return h;
    }

    test('moderate caps one below at once; relief only after 120 s at '
        'nominal / light', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.high);

        h.thermal.set(ThermalLevel.light);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 119));
        expect(h.service.current, QualityTier.high);
        h.async.elapse(const Duration(seconds: 1));
        expect(h.service.current, QualityTier.ultra);
        expect(h.changes, <QualityTier>[QualityTier.high, QualityTier.ultra]);
      });
    });

    test('a blip back to moderate restarts the relief wait', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        h.thermal.set(ThermalLevel.nominal);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 100));
        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        h.thermal.set(ThermalLevel.nominal);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 100));
        expect(h.service.current, QualityTier.high);
        h.async.elapse(const Duration(seconds: 20));
        expect(h.service.current, QualityTier.ultra);
      });
    });

    test('severe and critical cap low; easing to moderate waits, then one '
        'below', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.thermal.set(ThermalLevel.severe);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.low);
        h.thermal.set(ThermalLevel.critical);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.low);

        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 60));
        expect(h.service.current, QualityTier.low);
        h.async.elapse(const Duration(seconds: 60));
        expect(h.service.current, QualityTier.high);
        expect(h.service.thermalCap, ThermalCap.oneBelow);
      });
    });

    test('the thermal state at init applies', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(
          async,
          prefs: <String, Object>{
            'quality_tier': 'ultra',
            'quality_tier_bench': QualityTierService.benchVersion,
          },
        );
        h.thermal.level = ThermalLevel.severe;
        h.init();
        expect(h.service.current, QualityTier.low);
      });
    });

    test('battery saver caps low and lifts when off', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.power.set(true);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.low);
        h.power.set(false);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.ultra);
        expect(h.changes, <QualityTier>[QualityTier.low, QualityTier.ultra]);
      });
    });

    test('forceTier overrides the caps; null goes back', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.power.set(true);
        h.async.flushMicrotasks();
        h.service.forceTier(QualityTier.ultra);
        expect(h.service.current, QualityTier.ultra);
        expect(h.service.tier.value, QualityTier.ultra);
        h.service.forceTier(QualityTier.ultra);
        h.service.forceTier(null);
        h.async.flushMicrotasks();
        expect(h.service.current, QualityTier.low);
        expect(h.changes, <QualityTier>[
          QualityTier.low,
          QualityTier.ultra,
          QualityTier.low,
        ]);
      });
    });
  });

  group('QualityTierService drift', () {
    _Harness ultra(FakeAsync async) {
      final _Harness h = _Harness(
        async,
        prefs: <String, Object>{
          'quality_tier': 'ultra',
          'quality_tier_bench': QualityTierService.benchVersion,
        },
      );
      h.init();
      h.changes.clear();
      return h;
    }

    test('three 10 s windows over budget x 1.25 drop one tier, for good', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.service.setStageActive(true);
        // ultra: 8.3 x 1.25 = 10.4 ms; 12 ms frames are over.
        h.feed(const Duration(seconds: 20), frameMs: 12);
        expect(h.service.current, QualityTier.ultra);
        h.feed(const Duration(seconds: 10), frameMs: 12);
        expect(h.service.current, QualityTier.high);
        expect(h.service.driftCap, QualityTier.high);

        // high: 11.1 x 1.25 = 13.9 ms; 12 ms frames are fine there.
        h.feed(const Duration(seconds: 60), frameMs: 12);
        expect(h.service.current, QualityTier.high);
        // Good frames never bring ultra back in the session.
        h.feed(const Duration(seconds: 60), frameMs: 2);
        expect(h.service.current, QualityTier.high);
        expect(h.changes, <QualityTier>[QualityTier.high]);
      });
    });

    test('a window within budget breaks the streak', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.service.setStageActive(true);
        h.feed(const Duration(seconds: 20), frameMs: 12);
        h.feed(const Duration(seconds: 10), frameMs: 4);
        h.feed(const Duration(seconds: 20), frameMs: 12);
        expect(h.service.current, QualityTier.ultra);
      });
    });

    test('nothing is sampled while the stage is inactive or a tier is '
        'forced', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.feed(const Duration(seconds: 40), frameMs: 20);
        expect(h.service.current, QualityTier.ultra);
        expect(h.service.driftWatching, isFalse);

        h.service.forceTier(QualityTier.ultra);
        h.service.setStageActive(true);
        expect(h.service.driftWatching, isFalse);
        h.feed(const Duration(seconds: 40), frameMs: 20);
        h.service.forceTier(null);
        expect(h.service.current, QualityTier.ultra);
        expect(h.service.driftWatching, isTrue);
      });
    });

    test('the watch rests at low (nothing below it)', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = ultra(async);
        h.service.setStageActive(true);
        h.power.set(true);
        h.async.flushMicrotasks();
        expect(h.service.driftWatching, isFalse);
        h.power.set(false);
        h.async.flushMicrotasks();
        expect(h.service.driftWatching, isTrue);
      });
    });
  });

  group('QualityTierService review fixes', () {
    const Map<String, Object> ultraPrefs = <String, Object>{
      'quality_tier': 'ultra',
      'quality_tier_bench': QualityTierService.benchVersion,
    };

    test('no benchmark while battery saver caps the tier; it runs once the '
        'cap lifts', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.power.on = true;
        h.init();
        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 0);
        h.power.set(false);
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
      });
    });

    test('no benchmark while forced or under a thermal cap', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.init();
        h.service.forceTier(QualityTier.low);
        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 0);
        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        h.service.forceTier(null);
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 0, reason: 'thermal cap');
        h.thermal.set(ThermalLevel.nominal);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 120));
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
      });
    });

    test('a cap arriving mid-probe discards the result and re-runs later', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.init();
        h.service.notifyStageShown();
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 1);
        h.feed(const Duration(milliseconds: 1000), frameMs: 3);
        h.power.set(true);
        h.async.flushMicrotasks();
        h.feed(const Duration(milliseconds: 2200), frameMs: 3);
        h.settle();
        expect(h.storedString('quality_tier'), isNull);
        expect(h.service.benchmark, QualityTier.high);
        h.power.set(false);
        h.async.flushMicrotasks();
        expect(h.source.listenCount, 2);
        h.feed(const Duration(milliseconds: 3200), frameMs: 3);
        h.settle();
        expect(h.storedString('quality_tier'), 'ultra');
      });
    });

    test('the drift watch rests under a thermal cap: no session drop', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async, prefs: ultraPrefs);
        h.init();
        h.service.setStageActive(true);
        h.thermal.set(ThermalLevel.moderate);
        h.async.flushMicrotasks();
        expect(h.service.driftWatching, isFalse);
        h.feed(const Duration(seconds: 40), frameMs: 20);
        h.thermal.set(ThermalLevel.nominal);
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 120));
        expect(h.service.current, QualityTier.ultra);
        expect(h.service.driftCap, isNull);
        expect(h.service.driftWatching, isTrue);
      });
    });

    test('a tier change resets the drift streak', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async, prefs: ultraPrefs);
        h.service.setStageActive(true);
        // Two bad windows at high (the default before init).
        h.feed(const Duration(seconds: 20), frameMs: 16);
        h.init(); // the stored ultra lands: a tier change
        h.feed(const Duration(seconds: 10), frameMs: 16);
        expect(h.service.driftCap, isNull);
        expect(h.service.current, QualityTier.ultra);
      });
    });

    test('dispose mid-probe ends the probe and leaves no timer', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        bool done = false;
        unawaited(h.service.probe().then((_) => done = true));
        h.async.elapse(const Duration(milliseconds: 500));
        h.service.dispose();
        h.async.flushMicrotasks();
        expect(done, isTrue);
        expect(h.async.nonPeriodicTimerCount, 0);
      });
    });

    test('a failing thermal read is logged, not thrown', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async, prefs: ultraPrefs);
        h.thermal.fails = true;
        h.init();
        expect(h.service.current, QualityTier.ultra);
      });
    });
  });
}
