import 'package:freezed_annotation/freezed_annotation.dart';

part 'emotion_vector.freezed.dart';

/// Valence/arousal/intensity emotion state in [-1, 1] (valence, arousal) and
/// [0, 1] (intensity).
@freezed
sealed class EmotionVector with _$EmotionVector {
  const factory EmotionVector({
    @Default(0.0) double valence,
    @Default(0.0) double arousal,
    @Default(1.0) double intensity,
  }) = _EmotionVector;

  const EmotionVector._();

  /// Clamps [valence] and [arousal] to [-1, 1] and [intensity] to [0, 1].
  factory EmotionVector.clamped({
    double? valence,
    double? arousal,
    double? intensity,
  }) {
    return EmotionVector(
      valence: (valence ?? 0.0).clamp(-1.0, 1.0),
      arousal: (arousal ?? 0.0).clamp(-1.0, 1.0),
      intensity: (intensity ?? 1.0).clamp(0.0, 1.0),
    );
  }

  /// Linear interpolation between this vector and [to] at parameter [t].
  EmotionVector lerp(EmotionVector to, double t) => EmotionVector(
    valence: valence + (to.valence - valence) * t,
    arousal: arousal + (to.arousal - arousal) * t,
    intensity: intensity + (to.intensity - intensity) * t,
  );
}
