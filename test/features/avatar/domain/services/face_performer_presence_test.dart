import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/face_performer.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

const Duration _frame = Duration(microseconds: 16667);

class _Rig {
  _Rig({int seed = 7}) {
    performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => null,
      seed: seed,
      idle: false,
    );
  }

  final StreamController<PerformanceIntent> intents =
      StreamController<PerformanceIntent>.broadcast(sync: true);
  final StreamController<PlaybackEvent> playback =
      StreamController<PlaybackEvent>.broadcast(sync: true);
  late final FacePerformer performer;
  PerformanceIntent intent = const PerformanceIntent();

  void send({
    double lean = 0,
    int nodSerial = 0,
    PresenceReaction? reaction,
    int reactionSerial = 0,
    AvatarMood mood = AvatarMood.neutral,
  }) {
    intent = PerformanceIntent(
      emotion: emotionForMood(mood),
      face: actionUnitsForMood(mood),
      lean: lean,
      nodSerial: nodSerial,
      reaction: reaction,
      reactionSerial: reactionSerial,
    );
    intents.add(intent);
  }

  List<FaceFrame> run(double seconds) {
    final int n = (seconds / (_frame.inMicroseconds / 1e6)).round();
    return <FaceFrame>[for (int i = 0; i < n; i++) performer.step(_frame)];
  }

  Future<void> dispose() async {
    await performer.dispose();
    await intents.close();
    await playback.close();
  }
}

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  group('lean', () {
    test('a fresh frame leans 0', () {
      expect(FaceFrame.rest.lean, 0);
      expect(rig.performer.step(_frame).lean, 0);
    });

    test('reaches 0.6 +- 0.02 within 0.8 s and stays', () {
      rig.send(lean: 0.6);
      final List<FaceFrame> frames = rig.run(0.8);
      expect(frames.last.lean, closeTo(0.6, 0.02));
      expect(frames.every((FaceFrame f) => f.lean <= 0.6 + 1e-9), isTrue);
      // an eased start, not a jump
      expect(frames.first.lean, lessThan(0.05));
      for (int i = 1; i < frames.length; i++) {
        expect(frames[i].lean, greaterThanOrEqualTo(frames[i - 1].lean));
      }
    });

    test('relaxes back to 0 when the target drops', () {
      rig.send(lean: 0.6);
      rig.run(1);
      rig.send(lean: 0);
      expect(rig.run(1).last.lean, closeTo(0, 0.02));
    });

    test('is part of ==, hashCode and toJson', () {
      const FaceFrame a = FaceFrame(lean: 0.4);
      const FaceFrame b = FaceFrame(lean: 0.4);
      const FaceFrame c = FaceFrame(lean: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toJson()['lean'], 0.4);
    });

    test('reduce motion keeps the written lean at 0', () {
      rig.performer.reduceMotion = true;
      rig.send(lean: 0.6);
      expect(rig.run(1).last.lean, 0);
    });

    test('settles: isSettled waits for the lean, then holds', () {
      rig.send(lean: 0.6);
      rig.run(0.1);
      expect(rig.performer.isSettled, isFalse);
      int steps = 0;
      while (!rig.performer.isSettled && steps < 600) {
        rig.run(1 / 60);
        steps++;
      }
      expect(rig.performer.isSettled, isTrue);
      expect(rig.performer.frame.lean, closeTo(0.6, 0.002));
      // the ticker can stop: nothing changes once settled
      final FaceFrame still = rig.performer.frame;
      expect(identical(rig.performer.step(_frame), still), isTrue);
    });
  });

  group('reactions', () {
    final ActionUnits neutral = actionUnitsForMood(AvatarMood.neutral);

    test('exclaim lifts the outer brows >= 0.4 within 0.3 s and returns', () {
      rig.send(reaction: PresenceReaction.exclaim, reactionSerial: 1);
      final List<FaceFrame> frames = rig.run(1.6);
      final int at03 = (0.3 / (_frame.inMicroseconds / 1e6)).round();
      final double peak = frames
          .take(at03)
          .map((FaceFrame f) => f.au.browOuterUp)
          .reduce((double a, double b) => a > b ? a : b);
      expect(peak, greaterThanOrEqualTo(0.4));
      final double lid = frames
          .take(at03 + 10)
          .map((FaceFrame f) => f.au.upperLidRaise)
          .reduce((double a, double b) => a > b ? a : b);
      expect(lid, greaterThanOrEqualTo(0.3));

      // back to the preset within 1.5 s
      final int at15 = (1.5 / (_frame.inMicroseconds / 1e6)).round();
      final FaceFrame back = frames[at15 - 1];
      expect(back.au.browOuterUp, closeTo(neutral.browOuterUp, 0.02));
      expect(back.au.upperLidRaise, closeTo(neutral.upperLidRaise, 0.02));
    });

    test('question lifts both brows and tilts the head, then returns', () {
      rig.send(reaction: PresenceReaction.question, reactionSerial: 1);
      final List<FaceFrame> frames = rig.run(1.6);
      final int at03 = (0.3 / (_frame.inMicroseconds / 1e6)).round();
      double maxOf(double Function(FaceFrame) f, int n) =>
          frames.take(n).map(f).reduce((double a, double b) => a > b ? a : b);
      expect(
        maxOf((FaceFrame f) => f.au.browOuterUp, at03),
        greaterThanOrEqualTo(0.4),
      );
      expect(
        maxOf((FaceFrame f) => f.au.browInnerUp, at03),
        greaterThanOrEqualTo(0.4),
      );
      expect(maxOf((FaceFrame f) => f.roll, 60), greaterThan(0.2));
      final int at15 = (1.5 / (_frame.inMicroseconds / 1e6)).round();
      expect(frames[at15 - 1].au.browOuterUp, closeTo(0, 0.02));
      expect(frames[at15 - 1].au.browInnerUp, closeTo(0, 0.02));
      expect(frames[at15 - 1].roll, closeTo(0, 0.02));
    });

    test('a reaction is eased: no jump in a frame', () {
      rig.send(reaction: PresenceReaction.exclaim, reactionSerial: 1);
      final List<FaceFrame> frames = rig.run(1);
      for (int i = 1; i < frames.length; i++) {
        expect(
          (frames[i].au.browOuterUp - frames[i - 1].au.browOuterUp).abs(),
          lessThan(0.12),
        );
      }
    });

    test('the same serial does not react twice', () {
      rig.send(reaction: PresenceReaction.exclaim, reactionSerial: 1);
      rig.run(2);
      rig.send(reaction: PresenceReaction.exclaim, reactionSerial: 1);
      final List<FaceFrame> frames = rig.run(0.5);
      expect(frames.every((FaceFrame f) => f.au.browOuterUp < 0.02), isTrue);
    });

    test('is deterministic for a seed and settles afterwards', () {
      List<double> trace(int seed) {
        final _Rig r = _Rig(seed: seed);
        r.send(reaction: PresenceReaction.question, reactionSerial: 1);
        final List<double> out = r
            .run(1.2)
            .map((FaceFrame f) => f.au.browOuterUp)
            .toList();
        r.dispose();
        return out;
      }

      expect(trace(7), trace(7));

      rig.send(reaction: PresenceReaction.question, reactionSerial: 1);
      rig.run(0.2);
      expect(rig.performer.isSettled, isFalse);
      int steps = 0;
      while (!rig.performer.isSettled && steps < 600) {
        rig.run(1 / 60);
        steps++;
      }
      expect(rig.performer.isSettled, isTrue);
    });
  });

  group('backchannel nod', () {
    test('a nod serial dips the head once, shallower than a stress nod', () {
      rig.send(nodSerial: 1);
      final List<FaceFrame> frames = rig.run(1.2);
      final double deepest = frames
          .map((FaceFrame f) => f.nodPitch)
          .reduce((double a, double b) => a < b ? a : b);
      expect(deepest, lessThan(-0.03));
      expect(deepest, greaterThan(-0.5 * FacePerformer.nodDepthFor(1) * 1.25));
      expect(frames.last.nodPitch.abs(), lessThan(0.005));

      // one dip: the pitch goes down and comes back without a second dive
      int dives = 0;
      bool down = false;
      for (final FaceFrame f in frames) {
        if (!down && f.nodPitch < -0.02) {
          down = true;
          dives++;
        } else if (down && f.nodPitch > -0.005) {
          down = false;
        }
      }
      expect(dives, 1);
    });

    test('reduce motion drops the nod', () {
      rig.performer.reduceMotion = true;
      rig.send(nodSerial: 1);
      expect(rig.run(1).every((FaceFrame f) => f.nodPitch == 0), isTrue);
    });

    test('settles after the nod', () {
      rig.send(nodSerial: 1);
      rig.run(0.1);
      expect(rig.performer.isSettled, isFalse);
      int steps = 0;
      while (!rig.performer.isSettled && steps < 600) {
        rig.run(1 / 60);
        steps++;
      }
      expect(rig.performer.isSettled, isTrue);
    });
  });
}
