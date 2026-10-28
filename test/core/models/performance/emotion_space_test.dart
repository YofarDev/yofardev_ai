import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

List<double> _values(ActionUnits au) => <double>[
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
];

void main() {
  group('actionUnitsForEmotion', () {
    test('returns each preset exactly at its point', () {
      for (final AvatarMood m in AvatarMood.values) {
        final List<double> got = _values(
          actionUnitsForEmotion(emotionForMood(m)),
        );
        final List<double> want = _values(actionUnitsForMood(m));
        for (int i = 0; i < got.length; i++) {
          expect(got[i], closeTo(want[i], 1e-9), reason: '${m.name} AU $i');
        }
      }
    });

    test('neutral vector is the neutral face', () {
      expect(actionUnitsForEmotion(const EmotionVector()), ActionUnits.neutral);
    });

    test('halfway between happy and sad blends the two moods', () {
      // IDW is a convex blend of all 7 presets (neutral, thinking and the rest
      // pull too), so each AU stays inside the range of ALL presets (x1.25
      // for the intensity gain), and happy/sad AUs fall between the extremes.
      final EmotionVector happy = emotionForMood(AvatarMood.happy);
      final EmotionVector sad = emotionForMood(AvatarMood.sad);
      final ActionUnits mid = actionUnitsForEmotion(happy.lerp(sad, 0.5));
      final List<List<double>> presets = <List<double>>[
        for (final AvatarMood m in AvatarMood.values)
          _values(actionUnitsForMood(m)),
      ];
      final List<double> got = _values(mid);
      for (int i = 0; i < got.length; i++) {
        double hi = 0;
        for (final List<double> p in presets) {
          if (p[i] > hi) {
            hi = p[i];
          }
        }
        expect(got[i], inInclusiveRange(0.0, (hi * 1.25).clamp(0.0, 1.0)));
      }
      final ActionUnits nearHappy = actionUnitsForEmotion(happy.lerp(sad, 0.1));
      final ActionUnits nearSad = actionUnitsForEmotion(happy.lerp(sad, 0.9));
      expect(nearHappy.lipCornerPull, greaterThan(mid.lipCornerPull));
      expect(mid.lipCornerPull, greaterThan(nearSad.lipCornerPull));
      expect(nearSad.lipCornerDepress, greaterThan(mid.lipCornerDepress));
      expect(mid.lipCornerDepress, greaterThan(nearHappy.lipCornerDepress));
    });

    test('intensity 0 is neutral at any point', () {
      final EmotionVector e = emotionForMood(
        AvatarMood.angry,
      ).copyWith(intensity: 0);
      expect(actionUnitsForEmotion(e), ActionUnits.neutral);
      expect(
        actionUnitsForEmotion(
          const EmotionVector(valence: 0.3, arousal: -0.4, intensity: 0),
        ),
        ActionUnits.neutral,
      );
    });

    test('intensity scales the pose and is capped at 1.25x', () {
      final EmotionVector happy = emotionForMood(AvatarMood.happy);
      final ActionUnits full = actionUnitsForEmotion(happy);
      final ActionUnits half = actionUnitsForEmotion(
        happy.copyWith(intensity: happy.intensity / 2),
      );
      expect(half.lipCornerPull, closeTo(full.lipCornerPull / 2, 1e-9));
      final ActionUnits over = actionUnitsForEmotion(
        const EmotionVector(valence: 0.7, arousal: 0.6, intensity: 1),
      );
      expect(over.lipCornerPull, closeTo(0.7 * 1.25, 1e-9));
    });

    test('every output AU stays within [0, 1]', () {
      for (double v = -1; v <= 1; v += 0.25) {
        for (double a = -1; a <= 1; a += 0.25) {
          for (final double i in <double>[0, 0.5, 1]) {
            for (final double x in _values(
              actionUnitsForEmotion(
                EmotionVector(valence: v, arousal: a, intensity: i),
              ),
            )) {
              expect(x, inInclusiveRange(0.0, 1.0));
            }
          }
        }
      }
    });
  });
}
