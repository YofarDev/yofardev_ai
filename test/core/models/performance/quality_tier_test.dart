import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  test('ruling 14 frame budgets', () {
    expect(QualityTier.low.frameBudgetMs, 16.7);
    expect(QualityTier.high.frameBudgetMs, 11.1);
    expect(QualityTier.ultra.frameBudgetMs, 8.3);
  });

  test('oneBelow and lowest', () {
    expect(QualityTier.ultra.oneBelow, QualityTier.high);
    expect(QualityTier.high.oneBelow, QualityTier.low);
    expect(QualityTier.low.oneBelow, QualityTier.low);
    expect(
      QualityTier.lowest(<QualityTier>[QualityTier.ultra, QualityTier.high]),
      QualityTier.high,
    );
    expect(QualityTier.lowest(<QualityTier>[]), QualityTier.ultra);
  });

  test('ruling 13 gates: low drops the front, parallax, creep and tints', () {
    for (final QualityTier tier in QualityTier.values) {
      final bool rich = tier != QualityTier.low;
      expect(tier.allowsSceneFront, rich, reason: tier.name);
      expect(tier.allowsParallax, rich, reason: tier.name);
      expect(tier.allowsCameraCreep, rich, reason: tier.name);
      expect(tier.allowsTints, rich, reason: tier.name);
      expect(tier.placesCaptionOnce, !rich, reason: tier.name);
    }
  });

  test('mouth anchor cadence: ultra every frame, high every 2nd, low per '
      'sentence', () {
    expect(QualityTier.ultra.mouthAnchorStride, 1);
    expect(QualityTier.high.mouthAnchorStride, 2);
    expect(QualityTier.low.mouthAnchorStride, isNull);
  });
}
