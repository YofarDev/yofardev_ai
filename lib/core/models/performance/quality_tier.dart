/// Device performance tier chosen by the quality probe (Task 4). Gates the
/// expensive avatar features.
///
/// Ordered from the cheapest to the richest: [index] compares tiers
/// ([lowest]). Moonshot M11 ruling 13 gates the art per tier (the getters
/// below); ruling 14 fixes each tier's [frameBudgetMs].
enum QualityTier {
  low,
  high,
  ultra;

  /// Feathered hair/fur cards.
  bool get allowsFeather => this != QualityTier.low;

  /// Full-screen shader effects.
  bool get allowsShaders => this == QualityTier.ultra;

  /// Per-scene particle budget.
  int get particleBudget => switch (this) {
    QualityTier.low => 0,
    QualityTier.high => 40,
    QualityTier.ultra => 120,
  };

  /// The frame budget of the tier's target refresh rate (M11 ruling 14):
  /// low 60 Hz, high 90 Hz, ultra 120 Hz.
  double get frameBudgetMs => switch (this) {
    QualityTier.low => 16.7,
    QualityTier.high => 11.1,
    QualityTier.ultra => 8.3,
  };

  /// The tier one step down (low stays low).
  QualityTier get oneBelow =>
      this == QualityTier.low ? QualityTier.low : QualityTier.values[index - 1];

  /// The cheapest of [tiers] ([QualityTier.ultra] when empty).
  static QualityTier lowest(Iterable<QualityTier> tiers) {
    QualityTier result = QualityTier.ultra;
    for (final QualityTier tier in tiers) {
      if (tier.index < result.index) {
        result = tier;
      }
    }
    return result;
  }

  /// Whether the scene's `SceneFront` artboard (the weather in front of the
  /// avatar) may be created (low: never).
  bool get allowsSceneFront => this != QualityTier.low;

  /// Whether the parallax is written and its sensors run (low: neither).
  bool get allowsParallax => this != QualityTier.low;

  /// Whether the camera pushes in slowly during a sentence (low: cuts only).
  bool get allowsCameraCreep => this != QualityTier.low;

  /// Whether the wardrobe's colour variants are drawn (low: the garment's
  /// own colour).
  bool get allowsTints => this != QualityTier.low;

  /// Whether the speech bubble is placed once per sentence, like reduce
  /// motion, instead of following the mouth (low).
  bool get placesCaptionOnce => this == QualityTier.low;

  /// Every how many advances the avatar's `MouthAnchor` is read: ultra every
  /// frame, high every 2nd; null on low (once per sentence).
  int? get mouthAnchorStride => switch (this) {
    QualityTier.low => null,
    QualityTier.high => 2,
    QualityTier.ultra => 1,
  };
}
