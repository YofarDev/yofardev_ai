import 'package:flutter/material.dart';

/// Raw hex values of the shipping look, Storybook night: a lamp-lit picture
/// book seen from a dark theatre. Used only inside `lib/core/design/`; the
/// rest of the app reads colors through `Theme.of(context).colorScheme` or
/// `context.tokens`.
class AppPalette {
  const AppPalette._();

  // Plum ink and paper.
  static const Color ink = Color(0xFF16121D);
  static const Color surface = Color(0xFF211B2B);
  static const Color onSurface = Color(0xFFF3EBDD);
  static const Color outline = Color(0xFF3A3046);

  // Scene light: the accent each scene casts on the UI.
  static const Color livingRoomAccent = Color(0xFFF4B860);
  static const Color campfireAccent = Color(0xFFFF8552);
  static const Color beachAccent = Color(0xFFFF9478);
  static const Color deepSpaceAccent = Color(0xFFB79CFF);

  /// [livingRoomAccent] at the look's 35 % glow alpha (0x59).
  static const Color livingRoomGlow = Color(0x59F4B860);

  // Scene light rigs (mirror of `rive/tools/art_bible.py` SCENES; one hex
  // literal per line, a Python test parses them). Colours are ARGB.
  static const Color livingRoomKey = Color(0xFFFFD49A);
  static const Color livingRoomRim = Color(0xFF9FB8E6);
  static const Color livingRoomAmbient = Color(0xFF2C3346);
  static const Color livingRoomFog = Color(0x00000000);
  static const Color campfireKey = Color(0xFFFF9A4D);
  static const Color campfireRim = Color(0xFF6F8FD8);
  static const Color campfireAmbient = Color(0xFF141C2C);
  static const Color campfireFog = Color(0x3320304A);
  static const Color beachKey = Color(0xFFFFC48A);
  static const Color beachRim = Color(0xFFFFE2C4);
  static const Color beachAmbient = Color(0xFF3E4F6A);
  static const Color beachFog = Color(0x22FFD9C0);
  static const Color deepSpaceKey = Color(0xFFCDB8FF);
  static const Color deepSpaceRim = Color(0xFF7FE0FF);
  static const Color deepSpaceAmbient = Color(0xFF120E26);
  static const Color deepSpaceFog = Color(0x00000000);

  /// The UI tints derived from the living-room rig (see `ScenePalette`):
  /// [livingRoomKey] at alpha round(28 x 0.85) and `onSurface` leaned onto
  /// the key by 0.12 x 0.85. A test pins both against the derivation.
  static const Color livingRoomGlassTint = Color(0x18FFD49A);
  static const Color livingRoomCaptionInk = Color(0xFFF4E9D6);

  // Scene-independent roles.
  static const Color error = Color(0xFFFF6B6B);
  static const Color onError = ink;
  static const Color tertiary = Color(0xFFB79CFF);
  static const Color onTertiary = ink;
  static const Color success = Color(0xFF7BD88F);
  static const Color warning = Color(0xFFF4B860);
}
