import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
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

/// A candidate visual identity for the app: surface and text colors, surface
/// style, shape, fonts and one accent per scene. Pure data; turn it into a
/// theme with `buildLookTheme`.
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

  /// Interactive accent per scene.
  final Map<AvatarScene, Color> accents;

  static const double _minOnAccentContrast = 4.5;
  static const double _glowAlpha = 0.35;

  /// The accent palette of [scene]. `onAccent` is the darkest of ([ink], black)
  /// clearing 4.5:1 on the accent, else white; `glow` is the accent at 35 %.
  ScenePalette palette(AvatarScene scene) {
    final Color accent = accents[scene]!;
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
      glow: accent.withValues(alpha: _glowAlpha),
    );
  }
}
