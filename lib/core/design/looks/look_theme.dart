import 'package:flutter/material.dart';

import '../../models/avatar_scene.dart';
import '../tokens/app_tokens.dart';
import '../tokens/scene_palette.dart';
import 'ui_look.dart';

/// Builds the [TextTheme] of a look. Injected so tests never load fonts; the
/// production implementation is `googleFontsTextThemeBuilder`.
typedef LookTextThemeBuilder =
    TextTheme Function(LookFonts fonts, ColorScheme scheme);

/// Turns [look] and [scene] into a dark [ThemeData], with component themes
/// structurally mirroring `AppTheme.dark` (radii scaled by `radiusScale`).
///
/// This deliberately duplicates the component-theme body of `AppTheme.dark`
/// instead of sharing it, so `AppTheme.dark` stays untouched.
ThemeData buildLookTheme(
  UiLook look,
  AvatarScene scene, {
  required LookTextThemeBuilder textThemeBuilder,
}) {
  final ScenePalette palette = look.palette(scene);
  final AppTokens tokens = AppTokens.dark.copyWith(
    background: look.ink,
    glassSurface: look.glassSurface,
    glassBorder: look.outline,
    scene: palette,
    surfaceStyle: look.surfaceStyle,
    outlineWidth: look.outlineWidth,
    radiusScale: look.radiusScale,
  );
  final ColorScheme scheme = _buildScheme(look, palette);
  final TextTheme textTheme = textThemeBuilder(look.fonts, scheme);
  final double Function(double) r = tokens.radius;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.background,
    extensions: <ThemeExtension<dynamic>>[tokens],
    fontFamily: textTheme.bodyMedium?.fontFamily,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r(16)),
        side: BorderSide(color: tokens.glassBorder, width: tokens.outlineWidth),
      ),
      color: tokens.glassSurface.withValues(alpha: 0.6),
      shadowColor: scheme.surface.withValues(alpha: 0.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return scheme.onSurface.withValues(alpha: 0.6);
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: 0.2);
        }
        return scheme.onSurface.withValues(alpha: 0.1);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.glassSurface.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r(16)),
        borderSide: BorderSide(color: tokens.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r(16)),
        borderSide: BorderSide(color: tokens.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r(16)),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.hovered)) {
            return tokens.glassSurface;
          }
          if (states.contains(WidgetState.pressed)) {
            return tokens.glassSurface.withValues(alpha: 0.8);
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary;
          }
          return scheme.onSurface;
        }),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.2);
          }
          return null;
        }),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r(20))),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r(16))),
      iconColor: scheme.onSurface.withValues(alpha: 0.7),
      textColor: scheme.onSurface,
      tileColor: tokens.glassSurface.withValues(alpha: 0.4),
      selectedTileColor: scheme.primary.withValues(alpha: 0.15),
      selectedColor: scheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r(16))),
      backgroundColor: scheme.surface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: tokens.glassBorder.withValues(alpha: 0.3),
      thickness: 1,
      space: 1,
    ),
  );
}

ColorScheme _buildScheme(UiLook look, ScenePalette palette) {
  return ColorScheme.dark(
    primary: palette.accent,
    onPrimary: palette.onAccent,
    primaryContainer: Color.alphaBlend(
      palette.accent.withValues(alpha: 0.25),
      look.surface,
    ),
    secondary: palette.accent,
    onSecondary: palette.onAccent,
    secondaryContainer: Color.alphaBlend(
      palette.accent.withValues(alpha: 0.25),
      look.surface,
    ),
    tertiary: palette.accent,
    surface: look.surface,
    onSurface: look.onSurface,
    onSurfaceVariant: look.onSurface.withValues(alpha: 0.7),
    surfaceContainerLowest: look.ink,
    surfaceContainerLow: look.surface,
    surfaceContainer: look.surface,
    surfaceContainerHigh: look.surface,
    surfaceContainerHighest: look.surface,
    outline: look.outline,
    outlineVariant: look.outline,
  );
}
