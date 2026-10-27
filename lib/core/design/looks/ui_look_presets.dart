import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../tokens/app_palette.dart';
import '../tokens/scene_palette.dart';
import 'ui_look.dart';

/// The three candidate looks of the v4 look gate.
abstract final class UiLooks {
  /// A: today's neon glass, kept as the baseline.
  static const UiLook neon = UiLook(
    id: 'neon',
    name: 'Neon',
    ink: Color(0xFF0A0E1A),
    surface: Color(0xFF141829),
    glassSurface: Color(0xFF1A1F35),
    onSurface: Color(0xFFF5F5F7),
    outline: Color(0xFF2A3148),
    surfaceStyle: AppSurfaceStyle.glass,
    outlineWidth: 1.5,
    radiusScale: 1.0,
    fonts: LookFonts(display: 'Outfit', text: 'Plus Jakarta Sans'),
    accents: <AvatarScene, Color>{
      AvatarScene.livingRoom: Color(0xFF00D4FF),
      AvatarScene.campfire: Color(0xFF00D4FF),
      AvatarScene.beach: Color(0xFF00D4FF),
      AvatarScene.deepSpace: Color(0xFF00D4FF),
    },
  );

  /// B: a lamp-lit picture book seen from a dark theatre.
  /// The shipping look (`AppTheme`). Its values live in [AppPalette].
  static const UiLook storybook = UiLook(
    id: 'storybook',
    name: 'Storybook night',
    ink: AppPalette.ink,
    surface: AppPalette.surface,
    onSurface: AppPalette.onSurface,
    outline: AppPalette.outline,
    surfaceStyle: AppSurfaceStyle.glass,
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

  /// C: flat fills, ink outlines and hard shadows, like the character's art.
  static const UiLook cel = UiLook(
    id: 'cel',
    name: 'Cel',
    ink: Color(0xFF1B1830),
    surface: Color(0xFF2A2545),
    onSurface: Color(0xFFFFF8EE),
    outline: Color(0xFF0E0B1A),
    surfaceStyle: AppSurfaceStyle.cel,
    outlineWidth: 2,
    radiusScale: 1.35,
    fonts: LookFonts(display: 'Bricolage Grotesque', text: 'Geist'),
    accents: <AvatarScene, Color>{
      AvatarScene.livingRoom: Color(0xFFFFC24B),
      AvatarScene.campfire: Color(0xFFFF7A3D),
      AvatarScene.beach: Color(0xFFFF6F91),
      AvatarScene.deepSpace: Color(0xFF8C7CFF),
    },
  );

  static const List<UiLook> all = <UiLook>[neon, storybook, cel];
}
