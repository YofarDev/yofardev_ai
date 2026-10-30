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
  static const Color cafeAccent = Color(0xFFE8956B);
  static const Color rooftopAccent = Color(0xFF7CB8FF);
  static const Color mountainHutAccent = Color(0xFF86D4C4);

  /// [livingRoomAccent] at the look's 35 % glow alpha (0x59).
  static const Color livingRoomGlow = Color(0x59F4B860);

  // Scene light rigs (mirror of `rive/tools/art_bible.py` SCENES; one hex
  // literal per line, a Python test parses them). Colours are ARGB.
  static const Color livingRoomKey = Color(0xFFFFD49A);
  static const Color livingRoomRim = Color(0xFF9FB8E6);
  static const Color livingRoomAmbient = Color(0xFF2C3346);
  static const Color livingRoomFog = Color(0x33E0BC8C);
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
  static const Color deepSpaceFog = Color(0x331E1A44);

  // Moonshot M9 scenes (contract v12).
  static const Color cafeKey = Color(0xFFFFC98A);
  static const Color cafeRim = Color(0xFF8FA8D0);
  static const Color cafeAmbient = Color(0xFF2A2433);
  static const Color cafeFog = Color(0x33A8B4C4);
  static const Color rooftopKey = Color(0xFFC4D4FF);
  static const Color rooftopRim = Color(0xFFFFB27A);
  static const Color rooftopAmbient = Color(0xFF161A2E);
  static const Color rooftopFog = Color(0x33303A5C);
  static const Color mountainHutKey = Color(0xFFFFA25A);
  static const Color mountainHutRim = Color(0xFF8CB4E0);
  static const Color mountainHutAmbient = Color(0xFF1E1A26);
  static const Color mountainHutFog = Color(0x33B8C8DC);

  // Moonshot M7: the neutral daylight the scene rigs lean toward by day
  // (`SceneLights.at`): a pale warm key and a cool sky fill.
  static const Color dayKey = Color(0xFFFFF2DC);
  static const Color dayAmbient = Color(0xFF6E7F9A);

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
