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

  // Scene-independent roles.
  static const Color error = Color(0xFFFF6B6B);
  static const Color onError = ink;
  static const Color tertiary = Color(0xFFB79CFF);
  static const Color onTertiary = ink;
  static const Color success = Color(0xFF7BD88F);
  static const Color warning = Color(0xFFF4B860);
}
