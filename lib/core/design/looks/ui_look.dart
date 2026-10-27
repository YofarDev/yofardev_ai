import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../tokens/app_palette.dart';
import '../tokens/scene_palette.dart';
import 'contrast.dart';

/// Google Fonts family names (as accepted by `GoogleFonts.getFont`) of a look.
@immutable
class LookFonts {
  const LookFonts({required this.display, required this.text});

  /// Used for display/headline/title styles.
  final String display;

  /// Used for body/label styles.
  final String text;
}

/// A visual identity for the app: surface and text colors, surface style,
/// shape, fonts, one accent per scene and the scene-independent roles (error,
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
    required this.surfaceStyle,
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
    Color? glassSurface,
  }) : _glassSurface = glassSurface;

  final String id;
  final String name;

  /// Page background.
  final Color ink;

  /// Raised surface fill.
  final Color surface;

  final Color? _glassSurface;

  /// Fill of glass/card surfaces. Defaults to [surface]; Neon overrides it to
  /// reproduce today's palette, where the two differ.
  Color get glassSurface => _glassSurface ?? surface;

  /// Body text on [surface] and [ink].
  final Color onSurface;

  /// Surface outline / border color.
  final Color outline;

  final AppSurfaceStyle surfaceStyle;
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

  static const double _minOnAccentContrast = 4.5;

  /// 35 % of 255, rounded: an integer alpha so a glow can also be written as
  /// a const hex (`AppPalette.livingRoomGlow`) and compare equal.
  static const int _glowAlpha = 0x59;

  /// The accent palette of [scene]. `onAccent` is the first of [ink], black,
  /// white that clears 4.5:1 on the accent (ink preferred as it harmonises with
  /// the look); `glow` is the accent at 35 % alpha.
  ScenePalette palette(AvatarScene scene) {
    final Color? found = accents[scene];
    if (found == null) {
      throw StateError('UiLook "$id" has no accent for ${scene.name}');
    }
    final Color accent = found;
    final Color onAccent;
    if (contrastRatio(ink, accent) >= _minOnAccentContrast) {
      onAccent = ink;
    } else if (contrastRatio(Colors.black, accent) >= _minOnAccentContrast) {
      onAccent = Colors.black;
    } else {
      onAccent = Colors.white;
    }
    return ScenePalette(
      accent: accent,
      onAccent: onAccent,
      glow: accent.withAlpha(_glowAlpha),
    );
  }
}
