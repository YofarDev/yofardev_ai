import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('ActionUnits', () {
    test('neutral is all zero', () {
      const ActionUnits au = ActionUnits.neutral;
      for (final double v in <double>[
        au.browInnerUp,
        au.browOuterUp,
        au.browLower,
        au.lidTighten,
        au.upperLidRaise,
        au.cheekRaise,
        au.noseWrinkle,
        au.lipCornerPull,
        au.lipCornerDepress,
        au.lipStretch,
        au.lipPucker,
        au.lipPress,
        au.jawDrop,
        au.dimpler,
      ]) {
        expect(v, 0);
      }
    });

    test('addition clamps at 1', () {
      const ActionUnits a = ActionUnits(
        cheekRaise: 0.7,
        jawDrop: 0.5,
        browInnerUp: 0.2,
      );
      const ActionUnits b = ActionUnits(
        cheekRaise: 0.6,
        jawDrop: 0.4,
        lipPress: 0.3,
      );
      final ActionUnits sum = a + b;
      expect(sum.cheekRaise, 1);
      expect(sum.jawDrop, 0.9);
      expect(sum.browInnerUp, 0.2);
      expect(sum.lipPress, 0.3);
    });

    test('scale multiplies and clamps to [0, 1]', () {
      const ActionUnits au = ActionUnits(cheekRaise: 0.8, jawDrop: 0.4);
      expect(au.scale(0.5).cheekRaise, 0.4);
      expect(au.scale(2).cheekRaise, 1);
      expect(au.scale(0).jawDrop, 0);
    });

    test('value equality holds', () {
      const ActionUnits a = ActionUnits(cheekRaise: 0.5);
      const ActionUnits b = ActionUnits(cheekRaise: 0.5);
      expect(a, b);
    });
  });
}
