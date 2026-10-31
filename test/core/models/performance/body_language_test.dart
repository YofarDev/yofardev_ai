import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('BodyLanguageProfile', () {
    test('normal is the identity profile', () {
      const BodyLanguageProfile p = BodyLanguageProfile.normal;
      expect(BodyLanguageProfile.of(ChatPersona.normal), same(p));
      expect(p.gestureRate, 1);
      expect(p.gestureBias, isEmpty);
      expect(p.posture, BodyPosture.zero);
      expect(p.motionScale, 1);
      expect(p.idle, IdleStyle.calmDefault);
      expect(p.idle.ladderScale, 1);
      expect(p.idle.glancePeriodScale, 1);
      expect(p.idle.prop, AvatarProp.tablet);
      expect(p.isIdentity, isTrue);
    });

    test('every persona has a profile inside the ruling 9 ranges', () {
      for (final ChatPersona persona in ChatPersona.values) {
        final BodyLanguageProfile p = BodyLanguageProfile.of(persona);
        expect(p.gestureRate, inInclusiveRange(0.5, 1.6), reason: '$persona');
        expect(
          p.posture.lean,
          inInclusiveRange(-0.15, 0.2),
          reason: '$persona',
        );
        expect(
          p.posture.pitch,
          inInclusiveRange(-0.25, 0.1),
          reason: '$persona',
        );
        expect(p.posture.roll, inInclusiveRange(-0.1, 0.1), reason: '$persona');
        expect(p.motionScale, inInclusiveRange(0.6, 1.4), reason: '$persona');
        expect(
          p.idle.ladderScale,
          inInclusiveRange(0.7, 1.4),
          reason: '$persona',
        );
        expect(
          p.idle.glancePeriodScale,
          inInclusiveRange(0.7, 1.4),
          reason: '$persona',
        );
        expect(
          p.idle.prop,
          isIn(<AvatarProp>[AvatarProp.tablet, AvatarProp.newspaper]),
        );
        for (final GestureSwap swap in p.gestureBias) {
          expect(swap.to, isNotEmpty, reason: '$persona');
        }
        if (persona != ChatPersona.normal) {
          expect(p.isIdentity, isFalse, reason: '$persona');
        }
      }
    });

    test('the philosopher and the conservative read the newspaper', () {
      for (final ChatPersona persona in ChatPersona.values) {
        final AvatarProp prop = BodyLanguageProfile.of(persona).idle.prop;
        final bool reader =
            persona == ChatPersona.philosopher ||
            persona == ChatPersona.conservative;
        expect(
          prop,
          reader ? AvatarProp.newspaper : AvatarProp.tablet,
          reason: '$persona',
        );
      }
    });

    test('the doomer slumps, the coach leans in with the chin up', () {
      final BodyLanguageProfile doomer = BodyLanguageProfile.of(
        ChatPersona.doomer,
      );
      final BodyLanguageProfile coach = BodyLanguageProfile.of(
        ChatPersona.coach,
      );
      expect(doomer.posture.pitch, lessThan(0));
      expect(doomer.posture.lean, lessThan(0));
      expect(doomer.gestureRate, lessThan(1));
      expect(doomer.motionScale, lessThan(1));
      expect(coach.posture.lean, greaterThan(0));
      expect(coach.posture.pitch, greaterThan(0));
      expect(coach.gestureRate, greaterThan(1));
      expect(coach.motionScale, greaterThan(1));
    });

    test('swapFor picks the first matching swap, cycled by the index', () {
      const BodyLanguageProfile p = BodyLanguageProfile(
        gestureBias: <GestureSwap>[
          GestureSwap(
            from: AvatarGesture.nod,
            to: <AvatarGesture>[AvatarGesture.thumbsUp, AvatarGesture.clap],
          ),
          GestureSwap(
            from: AvatarGesture.nod,
            to: <AvatarGesture>[AvatarGesture.wave],
          ),
        ],
      );
      expect(p.swapFor(AvatarGesture.nod, 0), AvatarGesture.thumbsUp);
      expect(p.swapFor(AvatarGesture.nod, 1), AvatarGesture.clap);
      expect(p.swapFor(AvatarGesture.nod, 2), AvatarGesture.thumbsUp);
      expect(p.swapFor(AvatarGesture.think, 0), AvatarGesture.think);
      expect(p.beatFor(0), isNull);
    });

    test('equality is by value', () {
      const BodyLanguageProfile a = BodyLanguageProfile(
        gestureRate: 1.2,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.clap]),
        ],
        posture: BodyPosture(lean: 0.1),
      );
      final BodyLanguageProfile b = BodyLanguageProfile(
        gestureRate: 1.2,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.clap]),
        ],
        posture: const BodyPosture(lean: 0.1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == BodyLanguageProfile.normal, isFalse);
    });
  });
}
