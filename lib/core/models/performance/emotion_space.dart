import '../avatar_mood.dart';
import 'action_units.dart';
import 'emotion_vector.dart';
import 'mood_presets.dart';

/// Face for any point of the valence/arousal plane: inverse-distance weighting
/// (power 2) of the seven mood presets placed at their emotion points, scaled
/// by `e.intensity` relative to the presets' interpolated intensity. At a
/// preset point the preset is returned exactly; intensity 0 gives neutral.
ActionUnits actionUnitsForEmotion(EmotionVector e) {
  final List<AvatarMood> moods = AvatarMood.values;
  final List<double> weights = <double>[];
  double total = 0;
  for (final AvatarMood mood in moods) {
    final EmotionVector p = emotionForMood(mood);
    final double dv = e.valence - p.valence;
    final double da = e.arousal - p.arousal;
    final double d2 = dv * dv + da * da;
    if (d2 == 0) {
      // Exactly on a preset point: that preset wins outright.
      return actionUnitsForMood(mood).scale(_gain(e.intensity, p.intensity));
    }
    final double w = 1 / d2;
    weights.add(w);
    total += w;
  }

  ActionUnits blended = ActionUnits.neutral;
  double idwIntensity = 0;
  for (int i = 0; i < moods.length; i++) {
    final double share = weights[i] / total;
    blended = blended + actionUnitsForMood(moods[i]).scale(share);
    idwIntensity += share * emotionForMood(moods[i]).intensity;
  }
  return blended.scale(_gain(e.intensity, idwIntensity));
}

double _gain(double intensity, double presetIntensity) =>
    (intensity / presetIntensity).clamp(0.0, 1.25);
