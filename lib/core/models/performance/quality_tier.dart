/// Device performance tier chosen by the quality probe (Task 4). Gates the
/// expensive avatar features.
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
}
