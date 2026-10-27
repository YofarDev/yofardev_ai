import 'package:flutter/material.dart';

import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/design/theme/app_text_theme.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// The Cel look on the living-room scene, with the bundled Outfit / Plus
/// Jakarta Sans text theme so look tests never fetch fonts.
ThemeData celTestTheme() {
  return buildLookTheme(
    UiLooks.cel,
    AvatarScene.livingRoom,
    textThemeBuilder: (LookFonts _, ColorScheme scheme) =>
        buildTextTheme(scheme),
  );
}
