import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_glass.dart';
import 'app_palette.dart';
import 'scene_palette.dart';

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
    this.scene = _defaultScene,
    this.surfaceStyle = AppSurfaceStyle.glass,
    this.outlineWidth = 1.5,
    this.radiusScale = 1.0,
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

  /// Accent palette of the current scene.
  final ScenePalette scene;

  /// Whether raised surfaces are glass or cel (flat + outline + hard shadow).
  final AppSurfaceStyle surfaceStyle;

  /// Stroke width of surface outlines.
  final double outlineWidth;

  /// Multiplier applied to base corner radii through [radius].
  final double radiusScale;

  static const ScenePalette _defaultScene = ScenePalette(
    accent: Color(0xFF00D4FF),
    onAccent: Color(0xFF001F29),
    glow: Color(0x5900D4FF),
  );

  /// The app's only palette today (cosmic dark).
  static const AppTokens dark = AppTokens(
    background: AppPalette.background,
    glassSurface: AppPalette.glassSurface,
    glassBorder: AppPalette.glassBorder,
    success: AppPalette.success,
    warning: AppPalette.warning,
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

  /// Scales a base corner radius by [radiusScale].
  double radius(double base) => base * radiusScale;

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
    ScenePalette? scene,
    AppSurfaceStyle? surfaceStyle,
    double? outlineWidth,
    double? radiusScale,
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
      scene: scene ?? this.scene,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      radiusScale: radiusScale ?? this.radiusScale,
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
      scene: ScenePalette.lerp(scene, other.scene, t),
      surfaceStyle: t < 0.5 ? surfaceStyle : other.surfaceStyle,
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t)!,
      radiusScale: lerpDouble(radiusScale, other.radiusScale, t)!,
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
        other.glassThick == glassThick &&
        other.scene == scene &&
        other.surfaceStyle == surfaceStyle &&
        other.outlineWidth == outlineWidth &&
        other.radiusScale == radiusScale;
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
    scene,
    surfaceStyle,
    outlineWidth,
    radiusScale,
  );
}
