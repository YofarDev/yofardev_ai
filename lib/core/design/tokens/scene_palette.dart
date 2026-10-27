import 'package:flutter/material.dart';

/// How raised surfaces are drawn.
enum AppSurfaceStyle {
  /// Translucent blurred glass (today's look).
  glass,

  /// Flat opaque fill with an ink outline and a hard offset shadow.
  cel,
}

/// The accent colors of one scene: the interactive highlight, the color of
/// content drawn on top of it, and its glow.
@immutable
class ScenePalette {
  const ScenePalette({
    required this.accent,
    required this.onAccent,
    required this.glow,
  });

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
