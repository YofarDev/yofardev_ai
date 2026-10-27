import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../looks/look_fonts.dart';
import '../looks/look_theme.dart';
import '../looks/ui_look_presets.dart';

/// The app's theme: Storybook night (plum ink, warm paper text, Fraunces and
/// Manrope), its accent lit by the current scene. Use [forScene] in the app
/// and [dark] (the living room) in widget and golden test harnesses.
abstract final class AppTheme {
  static final Map<AvatarScene, ThemeData> _byScene =
      <AvatarScene, ThemeData>{};

  /// The theme of [scene], built once and cached so a scene switch hands
  /// `MaterialApp` an already-built, identical [ThemeData].
  static ThemeData forScene(AvatarScene scene) {
    return _byScene.putIfAbsent(
      scene,
      () => buildLookTheme(
        UiLooks.storybook,
        scene,
        textThemeBuilder: googleFontsTextThemeBuilder,
      ),
    );
  }

  /// The living-room theme.
  static ThemeData get dark => forScene(AvatarScene.livingRoom);
}
