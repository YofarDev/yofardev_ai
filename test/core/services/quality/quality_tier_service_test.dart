import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/quality/frame_timing_source.dart';
import 'package:yofardev_ai/core/services/quality/quality_tier_service.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

FrameTiming _frame(int milliseconds) {
  final int micros = milliseconds * 1000;
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
    service = QualityTierService(timingSource: source, settings: settings);
    service.changes.listen(changes.add);
  }

  final FakeAsync async;
  final _FakeTimingSource source;
  final SettingsLocalDatasource settings;
  late final QualityTierService service;
  final List<QualityTier> changes = <QualityTier>[];

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
    test('with a stored tier it loads it and does not probe', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(
          async,
          prefs: <String, Object>{'quality_tier': 'low'},
        );
        unawaited(h.service.init());
        h.async.elapse(const Duration(milliseconds: 1));
        h.async.flushMicrotasks();
        h.async.elapse(const Duration(seconds: 5));

        expect(h.service.current, QualityTier.low);
        expect(h.source.listenCount, 0);
        expect(h.changes, isEmpty);
      });
    });

    test('the probe starts only after the first frame is drawn', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async, firstFrameDrawn: false);
        unawaited(h.service.init());
        h.async.elapse(const Duration(seconds: 5));
        h.async.flushMicrotasks();

        expect(h.source.listenCount, 0);

        h.source.drawFirstFrame();
        h.async.flushMicrotasks();

        expect(h.source.listenCount, 1);
      });
    });

    test('without a stored tier it defaults to high and schedules a probe', () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        unawaited(h.service.init());
        h.async.elapse(const Duration(milliseconds: 1));
        h.async.flushMicrotasks();

        // The scheduled probe has subscribed to the timings stream, but the
        // tier stays high until a valid probe lands.
        expect(h.source.listenCount, 1);
        expect(h.service.current, QualityTier.high);

        // Feed a valid probe to completion.
        for (int i = 0; i < 7; i++) {
          h.async.elapse(const Duration(milliseconds: 400));
          h.source.emit(List<FrameTiming>.generate(28, (_) => _frame(3)));
          h.async.flushMicrotasks();
        }
        h.async.elapse(const Duration(milliseconds: 200));
        h.async.elapse(const Duration(milliseconds: 1));
        h.async.flushMicrotasks();

        expect(h.service.current, QualityTier.ultra);
      });
    });
  });
}
