import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../tokens/app_palette.dart';
import '../tokens/scene_palette.dart';

/// Google Fonts family names (as accepted by `GoogleFonts.getFont`) of a look.
@immutable
class LookFonts {
  const LookFonts({required this.display, required this.text});

  /// Used for display/headline/title styles.
  final String display;

  /// Used for body/label styles.
  final String text;
}

/// A visual identity for the app: surface and text colors, shape, fonts, one accent per scene and the scene-independent roles (error,
/// tertiary, success, warning). Pure data; turn it into a theme with
/// `buildLookTheme`.
@immutable
class UiLook {
  const UiLook({
    required this.id,
    required this.name,
    required this.ink,
    required this.surface,
    required this.onSurface,
    required this.outline,
    required this.outlineWidth,
    required this.radiusScale,
    required this.fonts,
    required this.accents,
    this.error = AppPalette.error,
    this.onError = AppPalette.onError,
    this.tertiary = AppPalette.tertiary,
    this.onTertiary = AppPalette.onTertiary,
    this.success = AppPalette.success,
    this.warning = AppPalette.warning,
  });

  final String id;
  final String name;

  /// Page background.
  final Color ink;

  /// Raised surface fill.
  final Color surface;

  /// Fill of glass/card surfaces (the same as [surface]).
  Color get glassSurface => surface;

  /// Body text on [surface] and [ink].
  final Color onSurface;

  /// Surface outline / border color.
  final Color outline;

  final double outlineWidth;
  final double radiusScale;
  final LookFonts fonts;

  /// Interactive accent per scene. Must cover every [AvatarScene]: a const
  /// constructor cannot assert it, so [palette] fails with a clear [StateError]
  /// for a missing scene.
  final Map<AvatarScene, Color> accents;

  /// Error role and the text drawn on it.
  final Color error;
  final Color onError;

  /// Scene-independent secondary accent and the text drawn on it.
  final Color tertiary;
  final Color onTertiary;

  /// Status colors (icons and badges, at least 3:1 on surfaces).
  final Color success;
  final Color warning;

  /// The accent palette of [scene] (see [ScenePalette.fromAccent]).
  ScenePalette palette(AvatarScene scene) {
    final Color? accent = accents[scene];
    if (accent == null) {
      throw StateError('UiLook "$id" has no accent for ${scene.name}');
    }
    return ScenePalette.fromAccent(accent, ink: ink);
  }
}
