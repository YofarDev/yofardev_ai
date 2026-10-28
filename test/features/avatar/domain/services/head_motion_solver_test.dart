import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/domain/models/head_pose.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_motion_solver.dart';

const Duration _frame = Duration(microseconds: 16667);

/// Steps [solver] for [seconds] at 60 fps and returns every frame's pose.
List<HeadPose> _run(HeadMotionSolver solver, double seconds) {
  final int frames = (seconds * 60).round();
  return <HeadPose>[for (int i = 0; i < frames; i++) solver.step(_frame)];
}

/// A solver with idle drift switched off, to look at a single turn.
HeadMotionSolver _noDrift() => HeadMotionSolver(
  params: const HeadMotionParams(driftYaw: 0, driftPitch: 0),
);

void main() {
  group('HeadMotionSolver turn', () {
    test('converges on the target within the settle window', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, -0.25);
      final List<HeadPose> poses = _run(solver, 1.5);
      // lead + wind-up + travel + 220 ms settle, then at rest.
      for (final HeadPose p in poses.sublist(90)) {
        expect(p.yaw, closeTo(0.6, 0.02));
        expect(p.pitch, closeTo(-0.25, 0.02));
      }
      expect(poses.last.yaw, closeTo(0.6, 0.005));
      expect(poses.last.hairLagYaw.abs(), lessThan(0.01));
      expect(poses.last.eyeLeadYaw.abs(), lessThan(0.01));
    });

    test('overshoots a 0 to 0.6 turn by about 12 percent', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final double peak = _run(
        solver,
        2,
      ).map((HeadPose p) => p.yaw).reduce(math.max);
      final double overshoot = peak / 0.6 - 1;
      expect(overshoot, inInclusiveRange(0.09, 0.15));
    });

    test('winds up against a big turn, by at most 18 percent of travel', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final double low = _run(
        solver,
        2,
      ).map((HeadPose p) => p.yaw).reduce(math.min);
      expect(low, lessThan(-0.02));
      expect(-low, lessThanOrEqualTo(0.18 * 0.6));
    });

    test('does not wind up on a small turn', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.2, 0);
      final double low = _run(
        solver,
        2,
      ).map((HeadPose p) => p.yaw).reduce(math.min);
      expect(low, greaterThanOrEqualTo(-1e-6));
    });

    test('the eyes lead: lead peaks before the head covers 10 percent', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<HeadPose> poses = _run(solver, 2);
      final int firstEye = poses.indexWhere(
        (HeadPose p) => p.eyeLeadYaw > 0.05,
      );
      final int firstHead = poses.indexWhere(
        (HeadPose p) => p.yaw.abs() > 0.01,
      );
      int peakAt = 0;
      for (int i = 0; i < poses.length; i++) {
        if (poses[i].eyeLeadYaw > poses[peakAt].eyeLeadYaw) {
          peakAt = i;
        }
      }
      final int tenPercent = poses.indexWhere((HeadPose p) => p.yaw > 0.06);
      expect(firstEye, greaterThanOrEqualTo(0));
      expect(firstEye, lessThan(firstHead));
      expect(peakAt, lessThan(tenPercent));
      expect(poses[peakAt].eyeLeadYaw, greaterThan(0.3));
      // Relaxes to rest as the head arrives.
      expect(poses.last.eyeLeadYaw.abs(), lessThan(0.01));
    });

    test('the eyes lead toward the new direction on a negative turn', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(-0.6, 0);
      final List<HeadPose> poses = _run(solver, 0.3);
      expect(
        poses.map((HeadPose p) => p.eyeLeadYaw).reduce(math.min),
        lessThan(-0.3),
      );
    });

    test('hair trails the head, swings past, then settles', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<HeadPose> poses = _run(solver, 3);
      final List<double> lag = poses.map((HeadPose p) => p.hairLagYaw).toList();
      final int trailAt = lag.indexWhere((double v) => v < -0.08);
      expect(trailAt, greaterThanOrEqualTo(0));
      // Follow-through: after trailing it swings the other way.
      expect(lag.sublist(trailAt).reduce(math.max), greaterThan(0.01));
      expect(lag.last.abs(), lessThan(0.005));
      expect(
        lag.map((double v) => v.abs()).reduce(math.max),
        lessThanOrEqualTo(1),
      );
    });

    test('pitch turns independently of yaw', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0, -0.35);
      final List<HeadPose> poses = _run(solver, 2);
      expect(poses.last.pitch, closeTo(-0.35, 0.005));
      expect(
        poses.map((HeadPose p) => p.yaw.abs()).reduce(math.max),
        lessThan(1e-9),
      );
      expect(
        poses.map((HeadPose p) => p.hairLagPitch.abs()).reduce(math.max),
        greaterThan(0.01),
      );
    });
  });

  group('HeadMotionSolver idle and timing', () {
    test('drifts lightly once the target has been steady for 1.5 s', () {
      final HeadMotionSolver solver = HeadMotionSolver()..setTarget(0.6, 0.1);
      final List<HeadPose> poses = _run(solver, 10);
      final List<HeadPose> idle = poses.sublist(4 * 60);
      final double yawSpan =
          idle.map((HeadPose p) => p.yaw).reduce(math.max) -
          idle.map((HeadPose p) => p.yaw).reduce(math.min);
      expect(yawSpan, greaterThan(0.005), reason: 'no dead holds');
      for (final HeadPose p in idle) {
        expect((p.yaw - 0.6).abs(), lessThanOrEqualTo(0.04 + 0.005));
        expect((p.pitch - 0.1).abs(), lessThanOrEqualTo(0.03 + 0.005));
      }
    });

    test('holds a quick retarget for hold_min, but not a return to user', () {
      final HeadMotionSolver solver = HeadMotionSolver()..setTarget(0.6, 0);
      solver.step(const Duration(milliseconds: 50));
      solver.setTarget(-0.6, 0);
      expect(solver.target.yaw, 0.6, reason: 'held within 160 ms');
      solver.step(const Duration(milliseconds: 120));
      expect(solver.target.yaw, -0.6, reason: 'applied after 160 ms');

      solver.setTarget(0.5, 0);
      solver.step(const Duration(milliseconds: 20));
      solver.setTarget(0, 0);
      expect(
        solver.target,
        HeadTarget.zero,
        reason: 'user return is immediate',
      );
    });

    test(
      'a held retarget is dropped when the target returns to the current',
      () {
        final HeadMotionSolver solver = HeadMotionSolver()..setTarget(0.6, 0);
        solver.step(const Duration(milliseconds: 50));
        solver.setTarget(-0.6, 0);
        solver.setTarget(0.6, 0);
        solver.step(const Duration(milliseconds: 300));
        expect(solver.target.yaw, 0.6);
      },
    );

    test('is deterministic for the same inputs', () {
      List<HeadPose> scenario() {
        final HeadMotionSolver solver = HeadMotionSolver();
        final List<HeadPose> out = <HeadPose>[];
        for (int i = 0; i < 600; i++) {
          if (i == 30) solver.setTarget(0.6, -0.25);
          if (i == 250) solver.setTarget(0, 0);
          if (i == 400) solver.setTarget(0, -0.35);
          out.add(solver.step(_frame));
        }
        return out;
      }

      expect(scenario(), scenario());
    });

    test('a different seed drifts differently', () {
      List<HeadPose> run(int seed) {
        final HeadMotionSolver solver = HeadMotionSolver(
          params: HeadMotionParams(seed: seed),
        );
        return _run(solver, 6);
      }

      expect(run(1), isNot(run(2)));
    });

    test('splits a large dt into 50 ms substeps', () {
      final HeadMotionSolver big = HeadMotionSolver()..setTarget(0.6, 0.2);
      final HeadMotionSolver small = HeadMotionSolver()..setTarget(0.6, 0.2);
      final HeadPose a = big.step(const Duration(milliseconds: 200));
      HeadPose b = HeadPose.zero;
      for (int i = 0; i < 4; i++) {
        b = small.step(const Duration(milliseconds: 50));
      }
      expect(a, b);
    });

    test('survives a huge dt (app resumed) and stays within -1..1', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(1, -1);
      final HeadPose p = solver.step(const Duration(minutes: 30));
      for (final double v in p.toJson().values) {
        expect(v.isFinite, isTrue);
        expect(v, inInclusiveRange(-1, 1));
      }
      expect(p.yaw, closeTo(1, 0.01));
      expect(p.pitch, closeTo(-1, 0.01));
    });

    test('zero and negative dt change nothing', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      solver.step(const Duration(milliseconds: 100));
      final HeadPose before = solver.pose;
      expect(solver.step(Duration.zero), before);
      expect(solver.step(const Duration(milliseconds: -50)), before);
    });

    test('clamps out-of-range targets and every output to -1..1', () {
      final HeadMotionSolver solver = HeadMotionSolver()..setTarget(5, -5);
      expect(solver.target, const HeadTarget(1, -1));
      for (final HeadPose p in _run(solver, 3)) {
        for (final double v in p.toJson().values) {
          expect(v, inInclusiveRange(-1, 1));
        }
      }
    });

    test('isSettled turns false on a retarget and true after the turn', () {
      final HeadMotionSolver solver = _noDrift();
      expect(solver.isSettled, isTrue);
      solver.setTarget(0.6, 0);
      expect(solver.isSettled, isFalse);
      _run(solver, 4);
      expect(solver.isSettled, isTrue);
    });
  });

  group('HeadMotionSolver reduceMotion', () {
    test('is critically damped: no wind-up, overshoot, hair lag or drift', () {
      final HeadMotionSolver solver = HeadMotionSolver()
        ..reduceMotion = true
        ..setTarget(0.6, -0.25);
      final List<HeadPose> poses = _run(solver, 4);
      for (final HeadPose p in poses) {
        expect(p.yaw, inInclusiveRange(-1e-6, 0.6 + 1e-6));
        expect(p.pitch, inInclusiveRange(-0.25 - 1e-6, 1e-6));
        expect(p.hairLagYaw, 0);
        expect(p.hairLagPitch, 0);
        expect(p.eyeLeadYaw, 0);
      }
      expect(poses.last.yaw, closeTo(0.6, 0.001));
      expect(poses.last.pitch, closeTo(-0.25, 0.001));
    });

    test('settles for good and no longer needs drift ticks', () {
      final HeadMotionSolver solver = HeadMotionSolver()
        ..reduceMotion = true
        ..setTarget(0.6, 0);
      expect(solver.driftEnabled, isFalse);
      expect(solver.isSettled, isFalse);
      _run(solver, 5);
      expect(solver.isSettled, isTrue);
      final HeadPose rest = solver.pose;
      expect(_run(solver, 5).every((HeadPose p) => p == rest), isTrue);
    });

    test('reaches the target immediately-held retargets too', () {
      final HeadMotionSolver solver = HeadMotionSolver()
        ..reduceMotion = true
        ..setTarget(0.6, 0);
      solver.step(const Duration(milliseconds: 20));
      solver.setTarget(-0.6, 0);
      _run(solver, 5);
      expect(solver.pose.yaw, closeTo(-0.6, 0.001));
    });

    test('switching on mid-turn does not pop the head', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      _run(solver, 0.6);
      final double before = solver.pose.yaw;
      solver.reduceMotion = true;
      expect(solver.pose.yaw, closeTo(before, 1e-9));
      expect(solver.pose.hairLagYaw, 0);
      solver.step(_frame);
      expect((solver.pose.yaw - before).abs(), lessThan(0.05));
    });
  });
}
