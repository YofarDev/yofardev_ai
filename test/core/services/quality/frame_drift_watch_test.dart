import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/quality/frame_drift_watch.dart';
import 'package:yofardev_ai/core/services/quality/frame_timing_source.dart';

FrameTiming _frame(num buildMs, [num? rasterMs]) {
  final int build = (buildMs * 1000).round();
  final int raster = ((rasterMs ?? 0) * 1000).round();
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: build,
    rasterStart: build,
    rasterFinish: build + raster,
    rasterFinishWallTime: 0,
  );
}

class _Source implements FrameTimingSource {
  final StreamController<List<FrameTiming>> controller =
      StreamController<List<FrameTiming>>.broadcast();

  @override
  Stream<List<FrameTiming>> get timings => controller.stream;

  @override
  double get refreshRate => 60;

  @override
  Future<void> get firstFrameDrawn async {}
}

void main() {
  group('FrameDriftWatch.judge', () {
    const Duration window = Duration(seconds: 10);

    test('over budget x 1.25 per tier (ruling 14 budgets)', () {
      // ultra 8.3 x 1.25 = 10.375; high 13.875; low 20.875.
      final Map<QualityTier, (double, double)> edges =
          <QualityTier, (double, double)>{
            QualityTier.ultra: (10.3, 10.4),
            QualityTier.high: (13.8, 13.9),
            QualityTier.low: (20.8, 20.9),
          };
      edges.forEach((QualityTier tier, (double, double) edge) {
        expect(
          FrameDriftWatch.judge(
            frameMs: List<double>.filled(600, edge.$1),
            tier: tier,
            window: window,
          ),
          DriftWindow.withinBudget,
          reason: tier.name,
        );
        expect(
          FrameDriftWatch.judge(
            frameMs: List<double>.filled(600, edge.$2),
            tier: tier,
            window: window,
          ),
          DriftWindow.overBudget,
          reason: tier.name,
        );
      });
    });

    test('the P95 decides, not the worst frame', () {
      final List<double> frames = <double>[
        ...List<double>.filled(96, 4),
        ...List<double>.filled(4, 50),
      ];
      expect(
        FrameDriftWatch.judge(
          frameMs: frames,
          tier: QualityTier.ultra,
          window: const Duration(seconds: 1),
        ),
        DriftWindow.withinBudget,
      );
    });

    test('fewer than 10 frames a second is idle', () {
      expect(
        FrameDriftWatch.judge(
          frameMs: List<double>.filled(99, 40),
          tier: QualityTier.ultra,
          window: window,
        ),
        DriftWindow.idle,
      );
      expect(
        FrameDriftWatch.judge(
          frameMs: List<double>.filled(100, 40),
          tier: QualityTier.ultra,
          window: window,
        ),
        DriftWindow.overBudget,
      );
    });
  });

  group('FrameDriftWatch', () {
    late _Source source;
    late int drifts;
    late QualityTier tier;
    late FrameDriftWatch watch;

    setUp(() {
      source = _Source();
      drifts = 0;
      tier = QualityTier.ultra;
      watch = FrameDriftWatch(
        source: source,
        tier: () => tier,
        onDrift: () => drifts++,
      );
    });

    void feed(FakeAsync async, Duration d, num buildMs, {num? rasterMs}) {
      for (int i = 0; i < d.inMilliseconds ~/ 100; i++) {
        source.controller.add(
          List<FrameTiming>.generate(6, (_) => _frame(buildMs, rasterMs)),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 100));
      }
    }

    test('three windows in a row over budget drift once, then count again', () {
      fakeAsync((FakeAsync async) {
        watch.active = true;
        feed(async, const Duration(seconds: 30), 12);
        expect(drifts, 1);
        expect(watch.streak, 0);
        feed(async, const Duration(seconds: 20), 12);
        expect(drifts, 1);
        expect(watch.streak, 2);
      });
    });

    test('max(build, raster) is judged: a slow raster counts', () {
      fakeAsync((FakeAsync async) {
        watch.active = true;
        feed(async, const Duration(seconds: 30), 2, rasterMs: 12);
        expect(drifts, 1);
      });
    });

    test('an idle window breaks the streak', () {
      fakeAsync((FakeAsync async) {
        watch.active = true;
        feed(async, const Duration(seconds: 20), 12);
        async.elapse(const Duration(seconds: 10));
        feed(async, const Duration(seconds: 20), 12);
        expect(drifts, 0);
        expect(watch.streak, 2);
      });
    });

    test('the budget follows the current tier', () {
      fakeAsync((FakeAsync async) {
        tier = QualityTier.high;
        watch.active = true;
        feed(async, const Duration(seconds: 30), 12);
        expect(drifts, 0);
      });
    });

    test('inactive: nothing is sampled and the streak is dropped', () {
      fakeAsync((FakeAsync async) {
        watch.active = true;
        feed(async, const Duration(seconds: 20), 12);
        watch.active = false;
        expect(watch.streak, 0);
        expect(source.controller.hasListener, isFalse);
        feed(async, const Duration(seconds: 30), 12);
        watch.active = true;
        feed(async, const Duration(seconds: 20), 12);
        expect(drifts, 0);
        watch.dispose();
        expect(source.controller.hasListener, isFalse);
      });
    });
  });
}
