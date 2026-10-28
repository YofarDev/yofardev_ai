import '../avatar_mood.dart';
import 'action_units.dart';
import 'emotion_vector.dart';

/// Per-mood emotion presets for the avatar performance layer.
EmotionVector emotionForMood(AvatarMood mood) => switch (mood) {
  AvatarMood.neutral => const EmotionVector(),
  AvatarMood.happy => const EmotionVector(
    valence: 0.7,
    arousal: 0.6,
    intensity: 0.8,
  ),
  AvatarMood.sad => const EmotionVector(
    valence: -0.7,
    arousal: -0.3,
    intensity: 0.6,
  ),
  AvatarMood.angry => const EmotionVector(
    valence: -0.8,
    arousal: 0.8,
    intensity: 0.9,
  ),
  AvatarMood.surprised => const EmotionVector(
    valence: 0.2,
    arousal: 0.9,
    intensity: 1.0,
  ),
  AvatarMood.thinking => const EmotionVector(
    valence: 0.1,
    arousal: 0.2,
    intensity: 0.4,
  ),
  AvatarMood.embarrassed => const EmotionVector(
    valence: -0.3,
    arousal: 0.5,
    intensity: 0.7,
  ),
};

/// Per-mood facial action unit presets (plausible FACS-style poses).
ActionUnits actionUnitsForMood(AvatarMood mood) => switch (mood) {
  AvatarMood.neutral => ActionUnits.neutral,
  AvatarMood.happy => const ActionUnits(
    cheekRaise: 0.6,
    lipCornerPull: 0.7,
    browOuterUp: 0.3,
  ),
  AvatarMood.sad => const ActionUnits(
    browInnerUp: 0.7,
    browLower: 0.3,
    upperLidRaise: 0.3,
    lipCornerDepress: 0.6,
  ),
  AvatarMood.angry => const ActionUnits(
    browLower: 0.8,
    lidTighten: 0.5,
    noseWrinkle: 0.4,
    lipCornerDepress: 0.5,
    lipPress: 0.6,
  ),
  AvatarMood.surprised => const ActionUnits(
    browInnerUp: 0.9,
    browOuterUp: 0.8,
    upperLidRaise: 0.7,
    jawDrop: 0.6,
  ),
  AvatarMood.thinking => const ActionUnits(
    browInnerUp: 0.4,
    lipPress: 0.5,
    lipPucker: 0.3,
    dimpler: 0.3,
  ),
  AvatarMood.embarrassed => const ActionUnits(
    browLower: 0.3,
    cheekRaise: 0.5,
    lipPress: 0.4,
    lipCornerDepress: 0.3,
    dimpler: 0.3,
  ),
};
