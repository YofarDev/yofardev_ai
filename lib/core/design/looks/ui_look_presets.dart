import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
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
  static const UiLook storybook = UiLook(
    id: 'storybook',
    name: 'Storybook night',
    ink: Color(0xFF16121D),
    surface: Color(0xFF211B2B),
    onSurface: Color(0xFFF3EBDD),
    outline: Color(0xFF3A3046),
    surfaceStyle: AppSurfaceStyle.glass,
    outlineWidth: 1,
    radiusScale: 1.15,
    fonts: LookFonts(display: 'Fraunces', text: 'Manrope'),
    accents: <AvatarScene, Color>{
      AvatarScene.livingRoom: Color(0xFFF4B860),
      AvatarScene.campfire: Color(0xFFFF8552),
      AvatarScene.beach: Color(0xFFFF9478),
      AvatarScene.deepSpace: Color(0xFFB79CFF),
    },
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
