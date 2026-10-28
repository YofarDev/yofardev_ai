import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('mood presets', () {
    test('every mood has both an emotion and an AU preset', () {
      for (final AvatarMood mood in AvatarMood.values) {
        expect(emotionForMood(mood), isA<EmotionVector>(), reason: mood.name);
        expect(actionUnitsForMood(mood), isA<ActionUnits>(), reason: mood.name);
      }
    });

    test('emotion presets differ pairwise', () {
      final List<AvatarMood> moods = AvatarMood.values;
      for (int i = 0; i < moods.length; i++) {
        for (int j = i + 1; j < moods.length; j++) {
          expect(
            emotionForMood(moods[i]),
            isNot(emotionForMood(moods[j])),
            reason: '${moods[i].name} vs ${moods[j].name}',
          );
        }
      }
    });

    test('AU presets differ pairwise', () {
      final List<AvatarMood> moods = AvatarMood.values;
      for (int i = 0; i < moods.length; i++) {
        for (int j = i + 1; j < moods.length; j++) {
          expect(
            actionUnitsForMood(moods[i]),
            isNot(actionUnitsForMood(moods[j])),
            reason: '${moods[i].name} vs ${moods[j].name}',
          );
        }
      }
    });

    test('happy = cheekRaise + lipCornerPull', () {
      final ActionUnits au = actionUnitsForMood(AvatarMood.happy);
      expect(au.cheekRaise, greaterThan(0));
      expect(au.lipCornerPull, greaterThan(0));
      expect(emotionForMood(AvatarMood.happy).valence, greaterThan(0));
    });

    test('sad = browInnerUp + lipCornerDepress', () {
      final ActionUnits au = actionUnitsForMood(AvatarMood.sad);
      expect(au.browInnerUp, greaterThan(0));
      expect(au.lipCornerDepress, greaterThan(0));
      expect(emotionForMood(AvatarMood.sad).valence, lessThan(0));
    });

    test('surprised = browInnerUp + browOuterUp + upperLidRaise + jawDrop', () {
      final ActionUnits au = actionUnitsForMood(AvatarMood.surprised);
      expect(au.browInnerUp, greaterThan(0));
      expect(au.browOuterUp, greaterThan(0));
      expect(au.upperLidRaise, greaterThan(0));
      expect(au.jawDrop, greaterThan(0));
    });

    test('neutral mood is fully neutral', () {
      expect(actionUnitsForMood(AvatarMood.neutral), ActionUnits.neutral);
    });

    test('all preset AU values are within [0, 1]', () {
      for (final AvatarMood mood in AvatarMood.values) {
        final ActionUnits au = actionUnitsForMood(mood);
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
          expect(v, inInclusiveRange(0, 1), reason: mood.name);
        }
      }
    });
  });
}
