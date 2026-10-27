import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../tokens/app_palette.dart';
import 'ui_look.dart';

/// The looks of the app.
abstract final class UiLooks {
  /// A lamp-lit picture book seen from a dark theatre. The shipping look (`AppTheme`). Its values live in [AppPalette].
  static const UiLook storybook = UiLook(
    id: 'storybook',
    name: 'Storybook night',
    ink: AppPalette.ink,
    surface: AppPalette.surface,
    onSurface: AppPalette.onSurface,
    outline: AppPalette.outline,
    outlineWidth: 1,
    radiusScale: 1.15,
    fonts: LookFonts(display: 'Fraunces', text: 'Manrope'),
    accents: <AvatarScene, Color>{
      AvatarScene.livingRoom: AppPalette.livingRoomAccent,
      AvatarScene.campfire: AppPalette.campfireAccent,
      AvatarScene.beach: AppPalette.beachAccent,
      AvatarScene.deepSpace: AppPalette.deepSpaceAccent,
    },
    error: AppPalette.error,
    onError: AppPalette.onError,
    tertiary: AppPalette.tertiary,
    onTertiary: AppPalette.onTertiary,
    success: AppPalette.success,
    warning: AppPalette.warning,
  );
}
