import 'package:flutter/material.dart';

import '../design/tokens/app_palette.dart';

/// Forwarder to [AppPalette]; removed once callers migrate to the theme.
class AppColors {
  static const Color primary = AppPalette.primary;
  static const Color onPrimary = AppPalette.onPrimary;
  static const Color primaryContainer = AppPalette.primaryContainer;

  static const Color secondary = AppPalette.secondary;
  static const Color onSecondary = AppPalette.onSecondary;
  static const Color secondaryContainer = AppPalette.secondaryContainer;

  static const Color background = AppPalette.background;
  static const Color surface = AppPalette.surface;
  static const Color onSurface = AppPalette.onSurface;

  static const Color glassSurface = AppPalette.glassSurface;
  static const Color glassBorder = AppPalette.glassBorder;

  static const Color accent = AppPalette.accent;
  static const Color success = AppPalette.success;
  static const Color warning = AppPalette.warning;
  static const Color error = AppPalette.error;
  static const Color onError = AppPalette.onError;
}
