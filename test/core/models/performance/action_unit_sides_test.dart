import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

List<double> _values(ActionUnitSides s) => <double>[
  s.browInnerUp,
  s.browOuterUp,
  s.browLower,
  s.lidTighten,
  s.cheekRaise,
  s.lipCornerPull,
  s.lipCornerDepress,
];

void main() {
  group('ActionUnitSides', () {
    test('zero is all zero and is the default', () {
      expect(_values(ActionUnitSides.zero), everyElement(0));
      expect(const ActionUnitSides(), ActionUnitSides.zero);
    });

    test('addition clamps to [-1, 1]', () {
      const ActionUnitSides a = ActionUnitSides(
        browInnerUp: 0.7,
        lipCornerPull: -0.8,
      );
      const ActionUnitSides b = ActionUnitSides(
        browInnerUp: 0.6,
        lipCornerPull: -0.5,
        cheekRaise: 0.2,
      );
      final ActionUnitSides sum = a + b;
      expect(sum.browInnerUp, 1);
      expect(sum.lipCornerPull, -1);
      expect(sum.cheekRaise, closeTo(0.2, 1e-12));
    });

    test('scale multiplies and clamps to [-1, 1]', () {
      const ActionUnitSides a = ActionUnitSides(
        browLower: 0.4,
        lidTighten: -0.6,
      );
      final ActionUnitSides half = a.scale(0.5);
      expect(half.browLower, closeTo(0.2, 1e-12));
      expect(half.lidTighten, closeTo(-0.3, 1e-12));
      final ActionUnitSides big = a.scale(3);
      expect(big.browLower, 1);
      expect(big.lidTighten, -1);
    });

    test('lerp at 0, 0.5 and 1', () {
      const ActionUnitSides a = ActionUnitSides(browOuterUp: 0.4);
      const ActionUnitSides b = ActionUnitSides(
        browOuterUp: -0.2,
        lipCornerDepress: 1,
      );
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      final ActionUnitSides mid = a.lerp(b, 0.5);
      expect(mid.browOuterUp, closeTo(0.1, 1e-12));
      expect(mid.lipCornerDepress, closeTo(0.5, 1e-12));
      expect(a.lerp(b, 3).lipCornerDepress, 1);
    });
  });

  group('sidesForMood', () {
    test('symmetric moods have no side offsets', () {
      for (final AvatarMood m in <AvatarMood>[
        AvatarMood.neutral,
        AvatarMood.happy,
        AvatarMood.sad,
        AvatarMood.angry,
        AvatarMood.surprised,
      ]) {
        final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForMood(
          m,
        );
        expect(s.left, ActionUnitSides.zero, reason: m.name);
        expect(s.right, ActionUnitSides.zero, reason: m.name);
      }
    });

    test('thinking lowers the left brow and raises the right one', () {
      final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForMood(
        AvatarMood.thinking,
      );
      expect(s.left, const ActionUnitSides(browLower: 0.25));
      expect(
        s.right,
        const ActionUnitSides(browOuterUp: 0.35, lipCornerPull: 0.2),
      );
    });

    test('embarrassed gives a lopsided half-smile', () {
      final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForMood(
        AvatarMood.embarrassed,
      );
      expect(s.left, const ActionUnitSides(lipCornerPull: 0.25));
      expect(s.right, const ActionUnitSides(lipCornerDepress: 0.15));
    });
  });

  group('sidesForEmotion', () {
    test('returns each preset exactly at its point', () {
      for (final AvatarMood m in AvatarMood.values) {
        final ({ActionUnitSides left, ActionUnitSides right}) got =
            sidesForEmotion(emotionForMood(m));
        final ({ActionUnitSides left, ActionUnitSides right}) want =
            sidesForMood(m);
        final List<double> gl = _values(got.left);
        final List<double> gr = _values(got.right);
        final List<double> wl = _values(want.left);
        final List<double> wr = _values(want.right);
        for (int i = 0; i < gl.length; i++) {
          expect(gl[i], closeTo(wl[i], 1e-9), reason: '${m.name} left $i');
          expect(gr[i], closeTo(wr[i], 1e-9), reason: '${m.name} right $i');
        }
      }
    });

    test('blends between presets like the action units', () {
      final EmotionVector thinking = emotionForMood(AvatarMood.thinking);
      final EmotionVector happy = emotionForMood(AvatarMood.happy);
      final ({ActionUnitSides left, ActionUnitSides right}) near =
          sidesForEmotion(thinking.lerp(happy, 0.1));
      final ({ActionUnitSides left, ActionUnitSides right}) far =
          sidesForEmotion(thinking.lerp(happy, 0.9));
      expect(near.right.browOuterUp, greaterThan(far.right.browOuterUp));
      expect(near.right.browOuterUp, lessThanOrEqualTo(0.35 * 1.25));
      expect(far.right.browOuterUp, greaterThan(0));
    });

    test('intensity 0 gives no offsets', () {
      final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForEmotion(
        emotionForMood(AvatarMood.thinking).copyWith(intensity: 0),
      );
      expect(s.left, ActionUnitSides.zero);
      expect(s.right, ActionUnitSides.zero);
    });

    test('every offset stays within [-1, 1]', () {
      for (double v = -1; v <= 1; v += 0.25) {
        for (double a = -1; a <= 1; a += 0.25) {
          final ({ActionUnitSides left, ActionUnitSides right}) s =
              sidesForEmotion(EmotionVector(valence: v, arousal: a));
          for (final double x in <double>[
            ..._values(s.left),
            ..._values(s.right),
          ]) {
            expect(x, inInclusiveRange(-1.0, 1.0));
          }
        }
      }
    });
  });
}
