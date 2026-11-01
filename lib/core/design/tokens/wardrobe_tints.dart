import 'dart:ui' show Color;

import '../../models/avatar_config.dart';

/// The wardrobe's colour variants (contract v13 `topTint` / `hatTint`, M10
/// ruling 5): paint, not text, so no contrast pairing applies.
///
/// The avatar file draws each tint over the garment with blend mode
/// **color**: the tint gives the hue and saturation, the garment keeps its
/// own lightness (its authored shading survives). So these are mid-tone,
/// medium-saturation storybook hues (a tint's own lightness never shows);
/// the alpha is the amount ([amount], 0.9: a whisper of the garment's own
/// hue stays). [AvatarTint.none] is fully transparent: nothing is drawn,
/// the garment looks exactly as authored.
abstract final class WardrobeTints {
  /// How much of the tint covers the garment's own hue.
  static const double amount = 0xE6 / 0xFF;

  static const Color none = Color(0x00000000);
  static const Color red = Color(0xE6D65A4E);
  static const Color orange = Color(0xE6E58A45);
  static const Color yellow = Color(0xE6E3BE52);
  static const Color green = Color(0xE657B05A);
  static const Color teal = Color(0xE63FA39B);
  static const Color blue = Color(0xE64F7FCF);
  static const Color purple = Color(0xE68C6AC6);
  static const Color pink = Color(0xE6DD7AA6);
  static const Color grey = Color(0xE6878790);

  /// The colour written for [tint].
  static Color of(AvatarTint tint) => switch (tint) {
    AvatarTint.none => none,
    AvatarTint.red => red,
    AvatarTint.orange => orange,
    AvatarTint.yellow => yellow,
    AvatarTint.green => green,
    AvatarTint.teal => teal,
    AvatarTint.blue => blue,
    AvatarTint.purple => purple,
    AvatarTint.pink => pink,
    AvatarTint.grey => grey,
  };
}
