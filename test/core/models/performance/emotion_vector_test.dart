import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('EmotionVector', () {
    test('defaults are neutral (0, 0, 1)', () {
      const EmotionVector v = EmotionVector();
      expect(v.valence, 0);
      expect(v.arousal, 0);
      expect(v.intensity, 1);
    });

    test('clamped keeps values inside their ranges', () {
      final EmotionVector v = EmotionVector.clamped(
        valence: 0.5,
        arousal: -0.5,
        intensity: 0.5,
      );
      expect(v.valence, 0.5);
      expect(v.arousal, -0.5);
      expect(v.intensity, 0.5);
    });

    test('clamped clamps valence and arousal to [-1, 1]', () {
      final EmotionVector v = EmotionVector.clamped(valence: 3, arousal: -3);
      expect(v.valence, 1);
      expect(v.arousal, -1);
    });

    test('clamped clamps intensity to [0, 1]', () {
      expect(EmotionVector.clamped(intensity: 5).intensity, 1);
      expect(EmotionVector.clamped(intensity: -2).intensity, 0);
    });

    test('lerp at 0 returns the receiver', () {
      const EmotionVector a = EmotionVector(valence: -1, arousal: 0.5);
      const EmotionVector b = EmotionVector(
        valence: 1,
        arousal: -0.5,
        intensity: 0,
      );
      final EmotionVector r = a.lerp(b, 0);
      expect(r, a);
    });

    test('lerp at 0.5 returns the midpoint', () {
      const EmotionVector a = EmotionVector(
        valence: -1,
        arousal: 0,
        intensity: 1,
      );
      const EmotionVector b = EmotionVector(
        valence: 1,
        arousal: 1,
        intensity: 0,
      );
      final EmotionVector r = a.lerp(b, 0.5);
      expect(r.valence, 0);
      expect(r.arousal, 0.5);
      expect(r.intensity, 0.5);
    });

    test('lerp at 1 returns the target', () {
      const EmotionVector a = EmotionVector(valence: -1);
      const EmotionVector b = EmotionVector(
        valence: 1,
        arousal: 0.5,
        intensity: 0,
      );
      final EmotionVector r = a.lerp(b, 1);
      expect(r, b);
    });
  });
}
