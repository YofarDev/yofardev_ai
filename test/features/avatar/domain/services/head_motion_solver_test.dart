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
      expect(poses.last.hairLagYaw.abs(), lessThan(0.02));
      // The eyes keep looking 0.2 past the head toward the target.
      expect(poses.last.eyeLeadYaw, closeTo(0.2, 0.02));
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
      // Relaxes to a look 0.2 past the head as it arrives.
      expect(poses.last.eyeLeadYaw, closeTo(0.2, 0.02));
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
        // Drift is 0.1 yaw / 0.09 pitch; the pitch also takes 0.06 nods.
        expect((p.yaw - 0.6).abs(), lessThanOrEqualTo(0.1 + 0.005));
        expect((p.pitch - 0.1).abs(), lessThanOrEqualTo(0.09 + 0.06 + 0.005));
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

  group('HeadMotionSolver tuning round', () {
    /// Longest span in which every channel stays within [eps] of its value at
    /// the span's start.
    double longestStill(List<HeadPose> poses, {double eps = 0.002}) {
      int best = 0;
      for (int i = 0; i < poses.length; i++) {
        int j = i;
        while (j + 1 < poses.length) {
          final HeadPose a = poses[i];
          final HeadPose b = poses[j + 1];
          final bool still =
              (a.yaw - b.yaw).abs() < eps &&
              (a.pitch - b.pitch).abs() < eps &&
              (a.hairLagYaw - b.hairLagYaw).abs() < eps &&
              (a.hairLagPitch - b.hairLagPitch).abs() < eps &&
              (a.eyeLeadYaw - b.eyeLeadYaw).abs() < eps &&
              (a.eyeLeadPitch - b.eyeLeadPitch).abs() < eps;
          if (!still) {
            break;
          }
          j++;
        }
        best = math.max(best, j - i);
      }
      return best / 60;
    }

    test('reading saccades run only while reading', () {
      final HeadMotionSolver reading = _noDrift()
        ..setTarget(0.6, -0.25, reading: true);
      final HeadMotionSolver glancing = _noDrift()..setTarget(0.6, -0.25);
      final List<HeadPose> r = _run(reading, 5).sublist(120);
      final List<HeadPose> g = _run(glancing, 5).sublist(120);

      final double span =
          r.map((HeadPose p) => p.eyeLeadYaw).reduce(math.max) -
          r.map((HeadPose p) => p.eyeLeadYaw).reduce(math.min);
      expect(span, greaterThan(0.2), reason: 'steps plus a return sweep');
      for (final HeadPose p in r) {
        expect(p.eyeLeadYaw, inInclusiveRange(0.0, 0.9));
      }
      final double pitchSpan =
          r.map((HeadPose p) => p.eyeLeadPitch).reduce(math.max) -
          r.map((HeadPose p) => p.eyeLeadPitch).reduce(math.min);
      expect(pitchSpan, greaterThan(0.005), reason: 'vertical jitter');

      for (final HeadPose p in g) {
        expect(p.eyeLeadYaw, closeTo(0.2, 0.02), reason: 'held, not reading');
      }
    });

    test('saccades stop and the eyes settle when reading ends', () {
      final HeadMotionSolver solver = _noDrift()
        ..setTarget(0.6, -0.25, reading: true);
      _run(solver, 3);
      solver.setTarget(0.6, -0.25);
      final List<HeadPose> after = _run(solver, 2);
      expect(solver.target.reading, isFalse);
      expect(after.last.eyeLeadYaw, closeTo(0.2, 0.02));
    });

    test('the eyes carry a look down at the caret', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0, -0.55);
      final List<HeadPose> poses = _run(solver, 2);
      // Looking down is capped at -0.72 so the iris drops more than the lid.
      expect(poses.last.eyeLeadPitch, closeTo(-0.72, 0.01));
      expect(poses.last.pitch, closeTo(-0.55, 0.01));
      final int eyes = poses.indexWhere((HeadPose p) => p.eyeLeadPitch < -0.2);
      final int head = poses.indexWhere((HeadPose p) => p.pitch < -0.05);
      expect(eyes, greaterThanOrEqualTo(0));
      expect(eyes, lessThan(head), reason: 'the eyes lead the chin');
    });

    test('the eyes look up when thinking', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.4, 0.2);
      expect(_run(solver, 2).last.eyeLeadPitch, closeTo(0.32, 0.02));
    });

    test('the eye lead peaks at 0.5-0.7 and starts 80 ms before the head', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<HeadPose> poses = _run(solver, 2);
      final double peak = poses
          .map((HeadPose p) => p.eyeLeadYaw)
          .reduce(math.max);
      expect(peak, inInclusiveRange(0.5, 0.7));
      final int eyes = poses.indexWhere((HeadPose p) => p.eyeLeadYaw > 0.05);
      final int head = poses.indexWhere((HeadPose p) => p.yaw.abs() > 0.01);
      expect((head - eyes) / 60, greaterThanOrEqualTo(0.08));
    });

    test('hair lag peaks at 0.35-0.5, swings past and settles', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<double> lag = _run(
        solver,
        3,
      ).map((HeadPose p) => p.hairLagYaw).toList();
      final double trail = -lag.reduce(math.min);
      expect(trail, inInclusiveRange(0.35, 0.5));
      expect(lag.reduce(math.max), greaterThan(0.1));
      // About two damped cycles: it crosses zero at least twice, then rests.
      int crossings = 0;
      for (int i = 1; i < lag.length; i++) {
        if (lag[i - 1].sign != lag[i].sign && lag[i] != 0) {
          crossings++;
        }
      }
      expect(crossings, greaterThanOrEqualTo(2));
      expect(lag.last.abs(), lessThan(0.01));
    });

    test('hair pitch lag scales the same way', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0, -0.35);
      final double peak = _run(
        solver,
        2,
      ).map((HeadPose p) => p.hairLagPitch.abs()).reduce(math.max);
      expect(peak, greaterThan(0.08));
    });

    test('returning to the user winds up by at most 8 percent', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, -0.25);
      _run(solver, 3);
      solver.setTarget(0, 0);
      final List<HeadPose> poses = _run(solver, 2);
      final double high = poses.map((HeadPose p) => p.yaw).reduce(math.max);
      expect(high - 0.6, lessThanOrEqualTo(0.08 * 0.6));
      expect(poses.last.yaw.abs(), lessThan(0.01));
    });

    test('returning to the user dips the chin instead', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      _run(solver, 3);
      solver.setTarget(0, 0);
      final double low = _run(
        solver,
        1,
      ).map((HeadPose p) => p.pitch).reduce(math.min);
      expect(low, inInclusiveRange(-0.06, -0.015));
    });

    test('keeps moving: no still stretch over 1 s with motion on', () {
      final HeadMotionSolver idle = HeadMotionSolver()..setTarget(0.6, -0.25);
      expect(longestStill(_run(idle, 25)), lessThan(1.0));
      final HeadMotionSolver centre = HeadMotionSolver();
      expect(longestStill(_run(centre, 25)), lessThan(1.0));
    });

    test('micro-nods dip the chin now and then while idle', () {
      final HeadMotionSolver solver = HeadMotionSolver();
      final List<HeadPose> poses = _run(solver, 30);
      // Drift alone stays within 0.025; a nod goes clearly below.
      expect(
        poses.map((HeadPose p) => p.pitch).reduce(math.min),
        lessThan(-0.03),
      );
    });

    test('reduce motion has no saccades, drift or hair lag', () {
      final HeadMotionSolver solver = HeadMotionSolver()
        ..reduceMotion = true
        ..setTarget(0.6, -0.25, reading: true);
      final List<HeadPose> poses = _run(solver, 12);
      for (final HeadPose p in poses) {
        expect(p.eyeLeadYaw, 0);
        expect(p.hairLagYaw, 0);
        expect(p.hairLagPitch, 0);
      }
      // Fully still once there: no drift, nods or saccades.
      final HeadPose rest = poses[300];
      for (final HeadPose p in poses.sublist(300)) {
        expect(p, rest);
      }
      // The held look down is a pose, not a flourish.
      expect(rest.eyeLeadPitch, closeTo(-0.35, 0.01));
    });
  });

  group('HeadMotionSolver reading lines, idle and hair', () {
    /// Movement events of [values]: runs of frames whose per-frame change
    /// exceeds [threshold] (gaps up to 2 frames merge). Each event is
    /// (start frame, frame count, net change).
    List<({int start, int frames, double change})> events(
      List<double> values, {
      double threshold = 0.004,
    }) {
      final List<({int start, int frames, double change})> out =
          <({int start, int frames, double change})>[];
      int? start;
      int last = 0;
      double sum = 0;
      for (int i = 1; i < values.length; i++) {
        final double d = values[i] - values[i - 1];
        if (d.abs() > threshold) {
          if (start == null) {
            start = i;
            sum = 0;
          }
          sum += d;
          last = i;
        } else if (start != null && i - last > 2) {
          out.add((start: start, frames: last - start + 1, change: sum));
          start = null;
        }
      }
      if (start != null) {
        out.add((start: start, frames: last - start + 1, change: sum));
      }
      return out;
    }

    List<HeadPose> reading({double seconds = 14, bool drift = false}) {
      final HeadMotionSolver solver = drift ? HeadMotionSolver() : _noDrift();
      solver.setTarget(0.84, -0.5, reading: true);
      return _run(solver, seconds);
    }

    test('reading has line structure: fixation steps and a return sweep', () {
      final List<HeadPose> poses = reading().sublist(240);
      final List<double> yaw = poses.map((HeadPose p) => p.eyeLeadYaw).toList();
      // The first and last events may be cut by the window.
      final List<({int start, int frames, double change})> moves = events(
        yaw,
      ).sublist(1);
      moves.removeLast();

      final List<({int start, int frames, double change})> sweeps = moves
          .where(
            (({int start, int frames, double change}) e) => e.change < -0.3,
          )
          .toList();
      final List<({int start, int frames, double change})> steps = moves
          .where((({int start, int frames, double change}) e) => e.change > 0)
          .toList();
      expect(sweeps.length, greaterThanOrEqualTo(8), reason: 'loops all run');
      for (final ({int start, int frames, double change}) sweep in sweeps) {
        expect(sweep.frames / 60, lessThanOrEqualTo(0.07), reason: 'fast');
      }
      for (final ({int start, int frames, double change}) step in steps) {
        expect(step.change, greaterThanOrEqualTo(0.25));
      }

      // Between two sweeps: 2-3 forward steps covering at least 0.35.
      for (int i = 1; i < sweeps.length; i++) {
        final Iterable<({int start, int frames, double change})> line = steps
            .where(
              (({int start, int frames, double change}) e) =>
                  e.start > sweeps[i - 1].start && e.start < sweeps[i].start,
            );
        expect(line.length, inInclusiveRange(2, 3));
        final double travel = line.fold(
          0,
          (double a, ({int start, int frames, double change}) e) =>
              a + e.change,
        );
        expect(travel, inInclusiveRange(0.65, 0.9));
        // 3-4 fixations of 200-280 ms: the whole line takes under 1.2 s.
        expect(
          (sweeps[i].start - sweeps[i - 1].start) / 60,
          inInclusiveRange(0.6, 1.25),
        );
      }
    });

    test('reading never freezes the gaze for more than 300 ms', () {
      final List<HeadPose> poses = reading().sublist(90);
      int still = 0;
      int longest = 0;
      for (int i = 1; i < poses.length; i++) {
        final bool moving =
            (poses[i].eyeLeadYaw - poses[i - 1].eyeLeadYaw).abs() > 0.0005 ||
            (poses[i].eyeLeadPitch - poses[i - 1].eyeLeadPitch).abs() > 0.0005;
        still = moving ? 0 : still + 1;
        longest = math.max(longest, still);
      }
      expect(longest / 60, lessThanOrEqualTo(0.3));
    });

    test('each new line drops the eyes, never below -0.75, then wraps', () {
      final List<HeadPose> poses = reading().sublist(240);
      final List<double> pitch = poses
          .map((HeadPose p) => p.eyeLeadPitch)
          .toList();
      expect(pitch.reduce(math.min), greaterThanOrEqualTo(-0.75 - 1e-9));
      expect(
        pitch.reduce(math.max) - pitch.reduce(math.min),
        greaterThan(0.06),
      );
      // Wrapped: after dropping, the eyes come back up to the first line.
      expect(
        events(
          pitch,
          threshold: 0.0015,
        ).any((({int start, int frames, double change}) e) => e.change > 0.03),
        isTrue,
      );
    });

    test('reading is deterministic', () {
      expect(reading(seconds: 6), reading(seconds: 6));
    });

    test('the eye lead stays on the target side while away', () {
      for (final double yaw in <double>[0.84, -0.84, 0.3]) {
        for (final bool drift in <bool>[false, true]) {
          final HeadMotionSolver solver = drift
              ? HeadMotionSolver()
              : _noDrift();
          solver.setTarget(yaw, -0.5, reading: true);
          for (final HeadPose p in _run(solver, 8)) {
            expect(p.eyeLeadYaw * yaw.sign, greaterThanOrEqualTo(-1e-9));
          }
        }
      }
    });

    test('the eyes settle 0.15-0.25 past the head toward the target', () {
      for (final double yaw in <double>[0.84, -0.84]) {
        final HeadMotionSolver solver = _noDrift()..setTarget(yaw, -0.5);
        expect(
          _run(solver, 3).last.eyeLeadYaw * yaw.sign,
          inInclusiveRange(0.15, 0.25),
        );
      }
    });

    test('the eyes lock on the user when the head returns', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.84, -0.5);
      _run(solver, 3);
      solver.setTarget(0, 0);
      final List<HeadPose> poses = _run(solver, 4).sublist(120);
      for (final HeadPose p in poses) {
        expect(p.eyeLeadYaw.abs(), lessThanOrEqualTo(0.17));
      }
    });

    test('a tool glance reaches yaw 0.8-0.95 and the caret pitch 0.5-0.65', () {
      final HeadMotionSolver glance = _noDrift()..setTarget(0.84, -0.5);
      final double yaw = _run(
        glance,
        3,
      ).map((HeadPose p) => p.yaw).reduce(math.max);
      expect(yaw, inInclusiveRange(0.8, 0.96));
      final HeadMotionSolver caret = _noDrift()..setTarget(0, -0.55);
      final double pitch = _run(
        caret,
        3,
      ).map((HeadPose p) => p.pitch).reduce(math.min);
      expect(pitch, inInclusiveRange(-0.65, -0.5));
    });

    test('something moves within 0.2 s of the start', () {
      final List<HeadPose> poses = _run(HeadMotionSolver(), 0.25);
      final double moved = poses
          .map(
            (HeadPose p) => <double>[
              p.yaw,
              p.pitch,
              p.eyeLeadYaw,
              p.eyeLeadPitch,
            ].map((double v) => v.abs()).reduce(math.max),
          )
          .reduce(math.max);
      expect(moved, greaterThan(0.01));
      expect(
        poses.sublist(0, 12).any((HeadPose p) => p.eyeLeadYaw.abs() > 0.01),
        isTrue,
        reason: 'the first micro-saccade lands inside 0.2 s',
      );
    });

    test('drift is visible and nods land every 4-6 s', () {
      final List<HeadPose> poses = _run(HeadMotionSolver(), 30);
      final List<HeadPose> idle = poses.sublist(60);
      final double yawSpan =
          idle.map((HeadPose p) => p.yaw).reduce(math.max) -
          idle.map((HeadPose p) => p.yaw).reduce(math.min);
      expect(yawSpan, greaterThan(0.08));
      expect(
        idle.map((HeadPose p) => p.yaw.abs()).reduce(math.max),
        lessThanOrEqualTo(0.1),
      );
      expect(
        idle.map((HeadPose p) => p.pitch.abs()).reduce(math.max),
        lessThanOrEqualTo(0.09 + 0.06 + 0.01),
      );
    });

    test('micro-saccades happen only while the gaze is on the user', () {
      final HeadMotionSolver user = _noDrift();
      final List<double> micro = _run(
        user,
        12,
      ).map((HeadPose p) => p.eyeLeadYaw).toList();
      expect(micro.reduce(math.max), greaterThan(0.03));
      expect(micro.reduce(math.min), lessThan(-0.03));
      expect(
        micro.map((double v) => v.abs()).reduce(math.max),
        lessThanOrEqualTo(0.17),
      );
      expect(
        events(micro, threshold: 0.01).length,
        inInclusiveRange(4, 9),
        reason: 'one every 1.5-3 s',
      );

      final HeadMotionSolver away = _noDrift()..setTarget(0.84, -0.5);
      final List<double> held = _run(
        away,
        12,
      ).map((HeadPose p) => p.eyeLeadYaw).toList().sublist(180);
      expect(held.reduce(math.max) - held.reduce(math.min), lessThan(0.005));

      // They resume once the head is back on the user.
      away.setTarget(0, 0);
      _run(away, 2);
      final List<double> back = _run(
        away,
        10,
      ).map((HeadPose p) => p.eyeLeadYaw).toList();
      expect(back.reduce(math.max) - back.reduce(math.min), greaterThan(0.05));
    });

    test('hair swings past once, rebounds under 0.03, and settles', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<double> lag = _run(
        solver,
        4,
      ).map((HeadPose p) => p.hairLagYaw).toList();
      final int trail = lag.indexOf(lag.reduce(math.min));
      int visible = 0;
      for (int i = trail + 1; i < lag.length - 1; i++) {
        final bool extremum = (lag[i] - lag[i - 1]) * (lag[i + 1] - lag[i]) < 0;
        if (extremum && lag[i].abs() > 0.03) {
          visible++;
        }
      }
      expect(visible, inInclusiveRange(1, 2));
      expect(lag.last.abs(), lessThan(0.005));
    });

    test('hair lag stays within 0.6 even through violent retargets', () {
      final HeadMotionSolver solver = _noDrift();
      double worst = 0;
      for (int i = 0; i < 600; i++) {
        if (i % 12 == 0) {
          final double sign = (i ~/ 12).isEven ? 1 : -1;
          solver.setTarget(sign, sign * 0.8);
        }
        final HeadPose p = solver.step(_frame);
        worst = math.max(
          worst,
          math.max(p.hairLagYaw.abs(), p.hairLagPitch.abs()),
        );
      }
      expect(worst, lessThanOrEqualTo(0.6));
      expect(worst, greaterThan(0.3));
    });

    test('nods do not make the fringe bob', () {
      final List<HeadPose> poses = _run(HeadMotionSolver(), 40);
      expect(
        poses.map((HeadPose p) => p.hairLagPitch.abs()).reduce(math.max),
        lessThan(0.05),
      );
    });

    test('reduce motion: no saccades, drift or nods anywhere', () {
      final HeadMotionSolver user = HeadMotionSolver()..reduceMotion = true;
      expect(_run(user, 15).every((HeadPose p) => p == HeadPose.zero), isTrue);
      final HeadMotionSolver reading = HeadMotionSolver()
        ..reduceMotion = true
        ..setTarget(0.84, -0.5, reading: true);
      final List<HeadPose> poses = _run(reading, 15);
      final HeadPose rest = poses[240];
      for (final HeadPose p in poses.sublist(240)) {
        expect(p, rest);
        expect(p.eyeLeadYaw, 0);
      }
    });
  });

  group('HeadMotionSolver final round', () {
    double yawOf(HeadPose p) => p.yaw;

    test('the head starts 150-200 ms after the eyes', () {
      for (final double yaw in <double>[0.6, 0.84, -0.6]) {
        final HeadMotionSolver solver = _noDrift()..setTarget(yaw, 0);
        final List<HeadPose> poses = _run(solver, 2);
        final int eyes = poses.indexWhere(
          (HeadPose p) => p.eyeLeadYaw.abs() > 0.05,
        );
        final int head = poses.indexWhere((HeadPose p) => p.yaw.abs() > 0.01);
        expect((head - eyes) / 60, inInclusiveRange(0.15, 0.2));
      }
    });

    test('the wind-up is one continuous ease: ~100 ms, no second bump', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.6, 0);
      final List<double> yaw = _run(solver, 3).map(yawOf).toList();
      final List<double> v = <double>[
        0,
        for (int i = 1; i < yaw.length; i++) (yaw[i] - yaw[i - 1]) * 60,
      ];
      final int start = yaw.indexWhere((double y) => y.abs() > 0.01);
      final int peak = yaw.indexOf(yaw.reduce(math.max));
      int counter = start;
      while (v[counter] <= 0) {
        counter++;
      }
      expect((counter - start) / 60, inInclusiveRange(0.07, 0.15));
      expect(-yaw.reduce(math.min) / 0.6, inInclusiveRange(0.08, 0.18));

      // From the head start to the peak: one sign change, one velocity peak.
      int signChanges = 0;
      int maxima = 0;
      for (int i = start + 1; i < peak; i++) {
        if (v[i].sign != v[i - 1].sign && v[i - 1] != 0) {
          signChanges++;
        }
        if (v[i] > 0 && v[i] > v[i - 1] && v[i] >= v[i + 1]) {
          maxima++;
        }
      }
      expect(signChanges, lessThanOrEqualTo(1));
      expect(maxima, 1);
    });

    test(
      'the caret look reaches pitch -0.8, the head close behind the eyes',
      () {
        final HeadMotionSolver solver = _noDrift()..setTarget(0, -0.8);
        final List<HeadPose> poses = _run(solver, 2);
        expect(poses.last.pitch, closeTo(-0.8, 0.02));
        expect(poses.last.eyeLeadPitch, closeTo(-0.7, 0.03));
        final int eyes = poses.indexWhere(
          (HeadPose p) => p.eyeLeadPitch < -0.05,
        );
        final int head = poses.indexWhere((HeadPose p) => p.pitch.abs() > 0.01);
        expect((head - eyes) / 60, inInclusiveRange(0.0, 0.12));
      },
    );

    test('reading steps are at least 0.25 and the sweep takes 70 ms', () {
      final HeadMotionSolver solver = _noDrift()
        ..setTarget(0.84, -0.5, reading: true);
      final List<double> yaw = _run(
        solver,
        14,
      ).sublist(240).map((HeadPose p) => p.eyeLeadYaw).toList();
      final double biggest = <double>[
        for (int i = 1; i < yaw.length; i++) (yaw[i] - yaw[i - 1]).abs(),
      ].reduce(math.max);
      expect(biggest, greaterThan(0.2), reason: 'a sweep frame is a big jump');
      expect(yaw.reduce(math.max) - yaw.reduce(math.min), greaterThan(0.7));
    });

    test('the head follows each reading line by a hair', () {
      final HeadMotionSolver solver = _noDrift()
        ..setTarget(0.84, -0.5, reading: true);
      final List<double> yaw = _run(
        solver,
        14,
      ).sublist(240).map(yawOf).toList();
      final double span = yaw.reduce(math.max) - yaw.reduce(math.min);
      expect(span, inInclusiveRange(0.01, 0.06));
    });

    test('idle is visible from the start: yaw moves over the first second', () {
      final List<HeadPose> poses = _run(HeadMotionSolver(), 1);
      final double span =
          poses.map(yawOf).reduce(math.max) - poses.map(yawOf).reduce(math.min);
      expect(span, greaterThanOrEqualTo(0.02));
    });

    test('idle resumes right after the return to the user', () {
      final HeadMotionSolver solver = HeadMotionSolver()..setTarget(0.84, -0.5);
      _run(solver, 4);
      solver.setTarget(0, 0);
      final List<HeadPose> after = _run(solver, 6);
      // From 1.5 s after the return the head is idling, never frozen for 1 s.
      final List<HeadPose> idle = after.sublist(90);
      int best = 0;
      for (int i = 0; i < idle.length; i++) {
        int j = i;
        while (j + 1 < idle.length &&
            (idle[j + 1].yaw - idle[i].yaw).abs() < 0.002 &&
            (idle[j + 1].pitch - idle[i].pitch).abs() < 0.002 &&
            (idle[j + 1].eyeLeadYaw - idle[i].eyeLeadYaw).abs() < 0.002) {
          j++;
        }
        best = math.max(best, j - i);
      }
      expect(best / 60, lessThan(1.0));
      expect(
        idle.map(yawOf).reduce(math.max) - idle.map(yawOf).reduce(math.min),
        greaterThan(0.02),
      );
    });

    test('micro-saccades are at least 0.12 and arrive every 1.5-3 s', () {
      final HeadMotionSolver solver = _noDrift();
      final List<double> eye = _run(
        solver,
        30,
      ).map((HeadPose p) => p.eyeLeadYaw).toList();
      expect(
        eye.map((double v) => v.abs()).reduce(math.max),
        greaterThanOrEqualTo(0.12),
      );
      // Settled values after each dart sit at +-0.12..0.16.
      final List<int> darts = <int>[
        for (int i = 1; i < eye.length; i++)
          if ((eye[i] - eye[i - 1]).abs() > 0.05) i,
      ];
      final List<double> starts = <double>[];
      for (final int d in darts) {
        if (starts.isEmpty || d / 60 - starts.last > 0.3) {
          starts.add(d / 60);
        }
      }
      expect(starts.length, greaterThanOrEqualTo(8));
      // The first lands at 0.15 s; the rest are 1.5-3 s apart.
      expect(starts.first, lessThan(0.3));
      for (int i = 2; i < starts.length; i++) {
        expect(starts[i] - starts[i - 1], inInclusiveRange(1.45, 3.1));
      }
    });

    test('the far-side eye lead is capped while the head is past 0.5', () {
      for (final double flip in <double>[-0.84, 0.9]) {
        final HeadMotionSolver solver = _noDrift()..setTarget(0.84, -0.5);
        _run(solver, 3);
        solver.setTarget(flip, -0.5);
        for (final HeadPose p in _run(solver, 3)) {
          if (p.yaw.abs() > 0.5) {
            expect(-p.yaw.sign * p.eyeLeadYaw, lessThanOrEqualTo(0.35 + 1e-9));
          }
        }
      }
    });

    test('the far-side cap does not hold back the return to the user', () {
      final HeadMotionSolver solver = _noDrift()..setTarget(0.84, -0.5);
      _run(solver, 3);
      solver.setTarget(0, 0);
      final double lowest = _run(
        solver,
        1,
      ).map((HeadPose p) => p.eyeLeadYaw).reduce(math.min);
      expect(lowest, lessThan(-0.4), reason: 'the eyes lock on the user');
    });
  });
}
