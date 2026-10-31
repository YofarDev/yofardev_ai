import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/chat.dart';
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

  void send({
    BodyLanguageProfile body = BodyLanguageProfile.normal,
    double lean = 0,
    int nodSerial = 0,
    PresenceReaction? reaction,
    int reactionSerial = 0,
  }) {
    intents.add(
      PerformanceIntent(
        body: body,
        lean: lean,
        nodSerial: nodSerial,
        reaction: reaction,
        reactionSerial: reactionSerial,
      ),
    );
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

  final BodyLanguageProfile doomer = BodyLanguageProfile.of(ChatPersona.doomer);
  final BodyLanguageProfile coach = BodyLanguageProfile.of(ChatPersona.coach);

  group('posture', () {
    test('normal leaves the face at rest', () {
      rig.send();
      final FaceFrame f = rig.run(1).last;
      expect(f.nodPitch, 0);
      expect(f.roll, 0);
      expect(f.lean, 0);
      expect(rig.performer.isSettled, isTrue);
    });

    test('the doomer eases into its slump over 600 ms, no snap', () {
      rig.send(body: doomer);
      final List<FaceFrame> frames = rig.run(0.9);
      // eased: the first frame barely moved, halfway near the middle
      expect(frames.first.nodPitch.abs(), lessThan(0.01));
      final FaceFrame mid = frames[18]; // ~0.3 s
      expect(
        mid.nodPitch,
        closeTo(doomer.posture.pitch / 2, doomer.posture.pitch.abs() * 0.2),
      );
      expect(frames.last.nodPitch, closeTo(doomer.posture.pitch, 1e-9));
      expect(frames.last.roll, closeTo(doomer.posture.roll, 1e-9));
      // no frame-to-frame jump bigger than an eased 600 ms ramp allows
      for (int i = 1; i < frames.length; i++) {
        expect(
          (frames[i].nodPitch - frames[i - 1].nodPitch).abs(),
          lessThan(doomer.posture.pitch.abs() * 0.05),
        );
      }
      // a lean back clamps at the contract's 0 (lean is 0..1)
      expect(frames.every((FaceFrame f) => f.lean == 0), isTrue);
    });

    test('the doomer lean back eats into the listening lean', () {
      rig.send(body: doomer, lean: 0.6);
      final FaceFrame f = rig.run(2).last;
      expect(f.lean, closeTo(0.6 + doomer.posture.lean, 0.01));
    });

    test('the coach leans in on top of the listening lean', () {
      rig.send(body: coach, lean: 0.6);
      final FaceFrame f = rig.run(2).last;
      expect(f.lean, closeTo(0.6 + coach.posture.lean, 0.01));
      expect(f.nodPitch, closeTo(coach.posture.pitch, 1e-6));
    });

    test('settles once the posture is reached', () {
      rig.send(body: doomer);
      rig.run(0.3);
      expect(rig.performer.isSettled, isFalse);
      rig.run(0.7);
      expect(rig.performer.isSettled, isTrue);
    });

    test('a change mid-ease eases on from where it is', () {
      rig.send(body: doomer);
      final double at = rig.run(0.3).last.nodPitch;
      rig.send(body: coach);
      final List<FaceFrame> frames = rig.run(0.8);
      expect((frames.first.nodPitch - at).abs(), lessThan(0.02));
      expect(frames.last.nodPitch, closeTo(coach.posture.pitch, 1e-9));
    });

    test('reduce motion applies the posture at once, no easing', () {
      rig.performer.reduceMotion = true;
      rig.send(body: doomer, lean: 0.6);
      final FaceFrame f = rig.performer.step(_frame);
      expect(f.nodPitch, closeTo(doomer.posture.pitch, 1e-9));
      expect(f.roll, closeTo(doomer.posture.roll, 1e-9));
      // reduce motion keeps the listening lean off, the posture lean is a
      // lean back: clamped at 0
      expect(f.lean, 0);
      rig.send(body: coach);
      final FaceFrame g = rig.performer.step(_frame);
      expect(g.nodPitch, closeTo(coach.posture.pitch, 1e-9));
      expect(g.lean, closeTo(coach.posture.lean, 1e-9));
    });
  });

  group('motionScale', () {
    double deepestBackchannel(BodyLanguageProfile body) {
      final _Rig r = _Rig(seed: 3);
      r.send(body: body);
      r.run(1);
      final double base = r.performer.frame.nodPitch;
      r.send(body: body, nodSerial: 1);
      final double deepest = r
          .run(1)
          .map((FaceFrame f) => f.nodPitch - base)
          .reduce((double a, double b) => a < b ? a : b);
      r.dispose();
      return deepest;
    }

    test('scales the backchannel nod depth', () {
      final double one = deepestBackchannel(BodyLanguageProfile.normal);
      final double big = deepestBackchannel(
        const BodyLanguageProfile(motionScale: 1.4),
      );
      final double small = deepestBackchannel(
        const BodyLanguageProfile(motionScale: 0.6),
      );
      expect(one, lessThan(0));
      expect(big / one, closeTo(1.4, 0.02));
      expect(small / one, closeTo(0.6, 0.02));
    });

    double highestQuestionBrow(BodyLanguageProfile body) {
      final _Rig r = _Rig(seed: 3);
      r.send(body: body);
      r.run(0.5);
      r.send(
        body: body,
        reaction: PresenceReaction.question,
        reactionSerial: 1,
      );
      final double top = r
          .run(1)
          .map((FaceFrame f) => f.au.browInnerUp)
          .reduce((double a, double b) => a > b ? a : b);
      r.dispose();
      return top;
    }

    test('scales a typed-punctuation reaction (AU accent intensity)', () {
      final double one = highestQuestionBrow(BodyLanguageProfile.normal);
      final double big = highestQuestionBrow(
        const BodyLanguageProfile(motionScale: 1.4),
      );
      expect(one, greaterThan(0.3));
      expect(big / one, closeTo(1.4, 0.03));
    });
  });
}
