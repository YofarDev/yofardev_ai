import '../avatar_mood.dart';
import 'action_unit_sides.dart';
import 'action_units.dart';
import 'emotion_vector.dart';
import 'mood_presets.dart';

/// Face for any point of the valence/arousal plane: inverse-distance weighting
/// (power 2) of the seven mood presets placed at their emotion points, scaled
/// by `e.intensity` relative to the presets' interpolated intensity. At a
/// preset point the preset is returned exactly; intensity 0 gives neutral.
ActionUnits actionUnitsForEmotion(EmotionVector e) {
  final _Idw idw = _Idw.at(e);
  final AvatarMood? exact = idw.exact;
  if (exact != null) {
    return actionUnitsForMood(exact).scale(idw.gain);
  }
  ActionUnits blended = ActionUnits.neutral;
  for (int i = 0; i < idw.shares.length; i++) {
    blended =
        blended + actionUnitsForMood(AvatarMood.values[i]).scale(idw.shares[i]);
  }
  return blended.scale(idw.gain);
}

/// Side offsets (contract v6) for any point of the valence/arousal plane,
/// blended exactly like [actionUnitsForEmotion]: the [sidesForMood] presets
/// at their emotion points, exact there, zero at intensity 0.
({ActionUnitSides left, ActionUnitSides right}) sidesForEmotion(
  EmotionVector e,
) {
  final _Idw idw = _Idw.at(e);
  final AvatarMood? exact = idw.exact;
  if (exact != null) {
    final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForMood(
      exact,
    );
    return (left: s.left.scale(idw.gain), right: s.right.scale(idw.gain));
  }
  ActionUnitSides left = ActionUnitSides.zero;
  ActionUnitSides right = ActionUnitSides.zero;
  for (int i = 0; i < idw.shares.length; i++) {
    final ({ActionUnitSides left, ActionUnitSides right}) s = sidesForMood(
      AvatarMood.values[i],
    );
    left = left + s.left.scale(idw.shares[i]);
    right = right + s.right.scale(idw.shares[i]);
  }
  return (left: left.scale(idw.gain), right: right.scale(idw.gain));
}

/// The inverse-distance weights of the mood presets at one emotion point:
/// either [exact] (the point is a preset's) or one share per
/// [AvatarMood.values] entry, plus the intensity [gain].
class _Idw {
  const _Idw({this.exact, this.shares = const <double>[], required this.gain});

  factory _Idw.at(EmotionVector e) {
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
        return _Idw(exact: mood, gain: _gain(e.intensity, p.intensity));
      }
      final double w = 1 / d2;
      weights.add(w);
      total += w;
    }
    double idwIntensity = 0;
    for (int i = 0; i < moods.length; i++) {
      weights[i] = weights[i] / total;
      idwIntensity += weights[i] * emotionForMood(moods[i]).intensity;
    }
    return _Idw(shares: weights, gain: _gain(e.intensity, idwIntensity));
  }

  final AvatarMood? exact;
  final List<double> shares;
  final double gain;
}

double _gain(double intensity, double presetIntensity) =>
    (intensity / presetIntensity).clamp(0.0, 1.25);
