import 'package:flutter/material.dart';

import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// The Cel look on the living-room scene, set in the bundled Storybook fonts
/// (Fraunces / Manrope) so look tests never fetch fonts.
ThemeData celTestTheme() {
  return buildLookTheme(
    UiLooks.cel,
    AvatarScene.livingRoom,
    textThemeBuilder: (LookFonts _, ColorScheme scheme) =>
        googleFontsTextThemeBuilder(UiLooks.storybook.fonts, scheme),
  );
}
