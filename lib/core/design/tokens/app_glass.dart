import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';

/// Elevation of a glass surface: the higher, the more blurred and opaque.
enum AppGlassLevel { thin, regular, thick }

/// Blur and opacity parameters of one [AppGlassLevel].
@immutable
class AppGlassStyle {
  const AppGlassStyle({
    required this.blurSigma,
    required this.fillAlpha,
    required this.borderAlpha,
  });

  /// Gaussian blur sigma applied to what is behind the surface.
  final double blurSigma;

  /// Alpha (0..1) of the surface fill color.
  final double fillAlpha;

  /// Alpha (0..1) of the surface border color.
  final double borderAlpha;

  static AppGlassStyle lerp(AppGlassStyle a, AppGlassStyle b, double t) {
    return AppGlassStyle(
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      fillAlpha: lerpDouble(a.fillAlpha, b.fillAlpha, t)!,
      borderAlpha: lerpDouble(a.borderAlpha, b.borderAlpha, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppGlassStyle &&
        other.blurSigma == blurSigma &&
        other.fillAlpha == fillAlpha &&
        other.borderAlpha == borderAlpha;
  }

  @override
  int get hashCode => Object.hash(blurSigma, fillAlpha, borderAlpha);
}
