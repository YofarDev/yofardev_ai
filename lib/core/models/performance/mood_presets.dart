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
  // a smiling eye: the cheek lifts the lower lid and the upper lid comes
  // down a little
  AvatarMood.happy => const ActionUnits(
    cheekRaise: 0.6,
    lidTighten: 0.35,
    lipCornerPull: 0.7,
    browOuterUp: 0.3,
  ),
  // heavy lids (the inner brow raise drops them), never a wide-eyed look
  AvatarMood.sad => const ActionUnits(
    browInnerUp: 0.85,
    browLower: 0.2,
    lidTighten: 0.15,
    lipCornerDepress: 0.6,
  ),
  AvatarMood.angry => const ActionUnits(
    browLower: 0.9,
    lidTighten: 0.4,
    noseWrinkle: 0.3,
    lipCornerDepress: 0.2,
    lipPress: 0.5,
  ),
  // a dropped jaw with rounded lips: an "oh", not a grin
  AvatarMood.surprised => const ActionUnits(
    browInnerUp: 0.9,
    browOuterUp: 0.9,
    upperLidRaise: 1.0,
    jawDrop: 0.5,
    lipPucker: 0.45,
  ),
  // closed, pressed and pulled to one side by the mood's mouth skew: a
  // pondering purse, never an open dark mouth
  AvatarMood.thinking => const ActionUnits(
    browInnerUp: 0.4,
    browLower: 0.15,
    lipPress: 0.6,
    lipCornerPull: 0.15,
    dimpler: 0.4,
  ),
  AvatarMood.embarrassed => const ActionUnits(
    browLower: 0.3,
    cheekRaise: 0.5,
    lipPress: 0.4,
    lipCornerDepress: 0.3,
    dimpler: 0.3,
  ),
};
