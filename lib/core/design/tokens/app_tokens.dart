import 'package:flutter/material.dart';

import 'app_glass.dart';

/// Design tokens that [ColorScheme] and [TextTheme] cannot express, exposed as
/// a [ThemeExtension]. Read them with `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.glassSurface,
    required this.glassBorder,
    required this.success,
    required this.warning,
    required this.shadow,
    required this.highlight,
    required this.glassThin,
    required this.glassRegular,
    required this.glassThick,
  });

  final Color background;
  final Color glassSurface;
  final Color glassBorder;
  final Color success;
  final Color warning;
  final Color shadow;
  final Color highlight;
  final AppGlassStyle glassThin;
  final AppGlassStyle glassRegular;
  final AppGlassStyle glassThick;

  /// The app's only palette today (cosmic dark).
  static const AppTokens dark = AppTokens(
    background: Color(0xFF0A0E1A),
    glassSurface: Color(0xFF1A1F35),
    glassBorder: Color(0xFF2A3148),
    success: Color(0xFF00D68F),
    warning: Color(0xFFFFB020),
    shadow: Color(0xFF000000),
    highlight: Color(0xFFFFFFFF),
    glassThin: AppGlassStyle(blurSigma: 6, fillAlpha: 0.06, borderAlpha: 0.3),
    glassRegular: AppGlassStyle(
      blurSigma: 10,
      fillAlpha: 0.12,
      borderAlpha: 0.3,
    ),
    glassThick: AppGlassStyle(
      blurSigma: 20,
      fillAlpha: 0.22,
      borderAlpha: 0.55,
    ),
  );

  AppGlassStyle glass(AppGlassLevel level) {
    return switch (level) {
      AppGlassLevel.thin => glassThin,
      AppGlassLevel.regular => glassRegular,
      AppGlassLevel.thick => glassThick,
    };
  }

  @override
  AppTokens copyWith({
    Color? background,
    Color? glassSurface,
    Color? glassBorder,
    Color? success,
    Color? warning,
    Color? shadow,
    Color? highlight,
    AppGlassStyle? glassThin,
    AppGlassStyle? glassRegular,
    AppGlassStyle? glassThick,
  }) {
    return AppTokens(
      background: background ?? this.background,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
      glassThin: glassThin ?? this.glassThin,
      glassRegular: glassRegular ?? this.glassRegular,
      glassThick: glassThick ?? this.glassThick,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      glassThin: AppGlassStyle.lerp(glassThin, other.glassThin, t),
      glassRegular: AppGlassStyle.lerp(glassRegular, other.glassRegular, t),
      glassThick: AppGlassStyle.lerp(glassThick, other.glassThick, t),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppTokens &&
        other.background == background &&
        other.glassSurface == glassSurface &&
        other.glassBorder == glassBorder &&
        other.success == success &&
        other.warning == warning &&
        other.shadow == shadow &&
        other.highlight == highlight &&
        other.glassThin == glassThin &&
        other.glassRegular == glassRegular &&
        other.glassThick == glassThick;
  }

  @override
  int get hashCode => Object.hash(
    background,
    glassSurface,
    glassBorder,
    success,
    warning,
    shadow,
    highlight,
    glassThin,
    glassRegular,
    glassThick,
  );
}
