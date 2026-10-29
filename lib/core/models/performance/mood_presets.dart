import '../avatar_mood.dart';
import 'action_unit_sides.dart';
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
  // a smiling eye: the cheek lifts the lower lid into a crescent; the upper
  // lid stays clear of the iris (lidTighten also lowers it: at 0.5 it hid
  // about a third of the iris, 0.1 keeps it near the open eye's)
  AvatarMood.happy => const ActionUnits(
    cheekRaise: 0.6,
    lidTighten: 0.1,
    lipCornerPull: 0.7,
    browOuterUp: 0.3,
  ),
  // heavy lids (the inner brow raise drops them), never a wide-eyed look
  AvatarMood.sad => const ActionUnits(
    browInnerUp: 0.75,
    browLower: 0.2,
    lidTighten: 0.05,
    lipCornerDepress: 0.9,
  ),
  AvatarMood.angry => const ActionUnits(
    browLower: 0.9,
    lidTighten: 0.7,
    noseWrinkle: 0.3,
    lipCornerDepress: 0.35,
    lipStretch: 0.3,
    lipPress: 0.6,
  ),
  // a dropped jaw with rounded lips: a tall "oh" oval, not a grin; the
  // brows and upper lids as high as they go
  AvatarMood.surprised => const ActionUnits(
    browInnerUp: 1.0,
    browOuterUp: 1.0,
    upperLidRaise: 1.0,
    jawDrop: 0.45,
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
  // sheepish: a worried brow, a pressed, dimpled half-smile
  AvatarMood.embarrassed => const ActionUnits(
    browInnerUp: 0.35,
    browLower: 0.1,
    cheekRaise: 0.4,
    lipPress: 0.5,
    lipCornerDepress: 0.15,
    dimpler: 0.5,
  ),
};

/// Per-mood side offsets (contract v6, the viewer's left and right), added to
/// [actionUnitsForMood] on each side. Only the lopsided moods have any.
({ActionUnitSides left, ActionUnitSides right}) sidesForMood(AvatarMood mood) =>
    switch (mood) {
      AvatarMood.neutral ||
      AvatarMood.happy ||
      AvatarMood.sad ||
      AvatarMood.angry ||
      AvatarMood.surprised => (
        left: ActionUnitSides.zero,
        right: ActionUnitSides.zero,
      ),
      // one brow knits, the other lifts, the mouth pulled to one side: weighing
      // it up
      AvatarMood.thinking => (
        left: const ActionUnitSides(browLower: 0.25),
        right: const ActionUnitSides(browOuterUp: 0.35, lipCornerPull: 0.2),
      ),
      // a lopsided, sheepish half-smile
      AvatarMood.embarrassed => (
        left: const ActionUnitSides(lipCornerPull: 0.25),
        right: const ActionUnitSides(lipCornerDepress: 0.15),
      ),
    };
