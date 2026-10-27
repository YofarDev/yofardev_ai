import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';

/// The app's dark [ColorScheme], built with [ColorScheme.dark] so Material's
/// derived roles (switches, dropdowns, expansion tiles...) resolve correctly.
ColorScheme buildDarkColorScheme() {
  return ColorScheme.dark(
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    primaryContainer: AppPalette.primaryContainer,
    secondary: AppPalette.secondary,
    onSecondary: AppPalette.onSecondary,
    secondaryContainer: AppPalette.secondaryContainer,
    tertiary: AppPalette.accent,
    error: AppPalette.error,
    onError: AppPalette.onError,
    surface: AppPalette.surface,
    onSurface: AppPalette.onSurface,
    onSurfaceVariant: AppPalette.onSurface.withValues(alpha: 0.7),
    surfaceContainerLowest: AppPalette.background,
    surfaceContainerLow: AppPalette.glassSurface,
    surfaceContainer: AppPalette.glassSurface,
    surfaceContainerHigh: AppPalette.glassSurface,
    surfaceContainerHighest: AppPalette.glassSurface,
    outline: AppPalette.glassBorder,
    outlineVariant: AppPalette.glassBorder,
  );
}
