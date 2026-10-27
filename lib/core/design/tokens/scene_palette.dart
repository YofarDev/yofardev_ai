import 'package:flutter/material.dart';

import 'contrast.dart';

/// The accent colors of one scene: the interactive highlight, the color of
/// content drawn on top of it, and its glow.
@immutable
class ScenePalette {
  const ScenePalette({
    required this.accent,
    required this.onAccent,
    required this.glow,
  });

  /// The palette of [accent] on a page of color [ink]: the single rule for
  /// the content color and the glow.
  ///
  /// `onAccent` is the first of [ink], black, white that clears 4.5:1 on the
  /// accent (ink preferred as it harmonises with the look); `glow` is the
  /// accent at 35 % alpha.
  factory ScenePalette.fromAccent(Color accent, {required Color ink}) {
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

  static const double _minOnAccentContrast = 4.5;

  /// 35 % of 255, rounded: an integer alpha so a glow can also be written as
  /// a const hex (`AppPalette.livingRoomGlow`) and compare equal.
  static const int _glowAlpha = 0x59;

  /// Interactive highlight color (active controls, focus, key actions).
  final Color accent;

  /// Foreground color for content drawn on [accent].
  final Color onAccent;

  /// Soft halo color around accent elements.
  final Color glow;

  static ScenePalette lerp(ScenePalette a, ScenePalette b, double t) {
    return ScenePalette(
      accent: Color.lerp(a.accent, b.accent, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScenePalette &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.glow == glow;
  }

  @override
  int get hashCode => Object.hash(accent, onAccent, glow);
}
