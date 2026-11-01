import 'package:flutter/material.dart';

import '../../models/performance/light_rig.dart';
import 'app_palette.dart';
import 'contrast.dart';

/// The colors one scene casts on the UI: the interactive highlight, the color
/// of content drawn on top of it, its glow, and the tints of the scene's
/// static light (glass and caption text).
@immutable
class ScenePalette {
  const ScenePalette({
    required this.accent,
    required this.onAccent,
    required this.glow,
    required this.glassTint,
    required this.captionInk,
  });

  /// The palette of [accent] on a page of color [ink]: the single rule for
  /// the content color and the glow.
  ///
  /// `onAccent` is the first of [ink], black, white that clears 4.5:1 on the
  /// accent (ink preferred as it harmonises with the look); `glow` is the
  /// accent at 35 % alpha. [light] is the scene's static rig (never its
  /// flicker): `glassTint` is its key color at alpha `round(28 x keyIntensity)`
  /// and `captionInk` is [onSurface] leaned onto the key by
  /// `0.12 x keyIntensity` (rounded to 8-bit, so it equals a const hex). It
  /// defaults to the neutral (white) rig.
  factory ScenePalette.fromAccent(
    Color accent, {
    required Color ink,
    Color onSurface = AppPalette.onSurface,
    LightRig light = LightRig.neutral,
  }) {
    final Color onAccent;
    if (contrastRatio(ink, accent) >= _minOnAccentContrast) {
      onAccent = ink;
    } else if (contrastRatio(Colors.black, accent) >= _minOnAccentContrast) {
      onAccent = Colors.black;
    } else {
      onAccent = Colors.white;
    }
    final Color key = Color(light.keyColor);
    return ScenePalette(
      accent: accent,
      onAccent: onAccent,
      glow: accent.withAlpha(_glowAlpha),
      glassTint: key.withAlpha((_glassTintAlpha * light.keyIntensity).round()),
      captionInk: Color(
        Color.lerp(
          onSurface,
          key,
          _captionLean * light.keyIntensity,
        )!.toARGB32(),
      ),
    );
  }

  static const double _minOnAccentContrast = 4.5;

  /// 35 % of 255, rounded: an integer alpha so a glow can also be written as
  /// a const hex (`AppPalette.livingRoomGlow`) and compare equal.
  static const int _glowAlpha = 0x59;

  /// Alpha (of 255) of the key-colored glass tint at full key intensity.
  static const int _glassTintAlpha = 28;

  /// Share of the key color mixed into the caption ink at full intensity.
  static const double _captionLean = 0.12;

  /// Interactive highlight color (active controls, focus, key actions).
  final Color accent;

  /// Foreground color for content drawn on [accent].
  final Color onAccent;

  /// Soft halo color around accent elements.
  final Color glow;

  /// The scene's key color, faint: laid over glass so panels pick up the light.
  final Color glassTint;

  /// Caption text color: `onSurface` warmed by the key light, still at least
  /// 4.5:1 on the surface.
  final Color captionInk;

  static ScenePalette lerp(ScenePalette a, ScenePalette b, double t) {
    return ScenePalette(
      accent: Color.lerp(a.accent, b.accent, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
      glassTint: Color.lerp(a.glassTint, b.glassTint, t)!,
      captionInk: Color.lerp(a.captionInk, b.captionInk, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScenePalette &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.glow == glow &&
        other.glassTint == glassTint &&
        other.captionInk == captionInk;
  }

  @override
  int get hashCode =>
      Object.hash(accent, onAccent, glow, glassTint, captionInk);
}
