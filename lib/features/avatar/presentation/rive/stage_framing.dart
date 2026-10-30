import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/models/performance/shot.dart';

/// Where a [Shot] puts the stage (moonshot M7 ruling 2), as pure geometry.
///
/// A shot is a rect of the `Avatar` artboard (800 x 1000, the bust: head top
/// near y 140, the hoodie cut by the bottom edge). The avatar view draws the
/// artboard with `Fit.contain` and `Alignment.bottomCenter` inside the whole
/// stage box, so the rect maps to the stage on any aspect; the scene (`cover`)
/// and the journey and weather layers share the same box, so one transform of
/// the stage frames them all.
///
/// The framing is the transform of the stage's child, in stage pixels with
/// the origin at the stage's top-left:
///
/// ```text
/// p' = zoom * p + translate
/// ```
///
/// that is the matrix `[zoom 0 0 tx; 0 zoom 0 ty; 0 0 1 0; 0 0 0 1]` (scale
/// first, then move by `translate`), the one [Transform] applies.
abstract final class StageFraming {
  /// The size of the `Avatar` artboard.
  static const Size artboard = Size(800, 1000);

  /// The focus sits at this fraction of the viewport's height (headroom).
  static const double focusHeight = 0.45;

  /// [shot]'s rect in artboard space; `wide` is the whole artboard.
  static Rect rectOf(Shot shot) {
    switch (shot) {
      case Shot.wide:
        return Offset.zero & artboard;
      case Shot.medium:
        return const Rect.fromLTRB(130, 100, 670, 900);
      case Shot.closeUp:
        return const Rect.fromLTRB(210, 120, 590, 620);
      case Shot.propInsert:
        return const Rect.fromLTRB(250, 380, 750, 1000);
    }
  }

  /// The most [shot] may zoom (1 for `wide`).
  static double capOf(Shot shot) {
    switch (shot) {
      case Shot.wide:
        return 1;
      case Shot.medium:
        return 1.35;
      case Shot.closeUp:
        return 2;
      case Shot.propInsert:
        return 1.8;
    }
  }

  /// The framing of [shot] on a [stage] box.
  ///
  /// `zoom` = min(cap, stage height / rect height, stage width / rect width),
  /// never below 1, times `1 + creep` (the push-in since the last cut). The
  /// rect's centre goes to the viewport's centre column and to
  /// [focusHeight] of its height; `translate` is then clamped so the zoomed
  /// stage always covers the viewport (no edge shows). `wide` is the identity
  /// whatever the creep.
  static ({double zoom, Offset translate}) of(
    Shot shot,
    Size stage, {
    double creep = 0,
  }) {
    if (shot == Shot.wide || stage.isEmpty) {
      return (zoom: 1, translate: Offset.zero);
    }
    // The artboard on the stage: contain, bottom-centre.
    final double scale = math.min(
      stage.width / artboard.width,
      stage.height / artboard.height,
    );
    final double left = (stage.width - artboard.width * scale) / 2;
    final double top = stage.height - artboard.height * scale;
    final Rect rect = rectOf(shot);
    final double rectWidth = rect.width * scale;
    final double rectHeight = rect.height * scale;
    final Offset centre = Offset(
      left + rect.center.dx * scale,
      top + rect.center.dy * scale,
    );

    final double fit = math.min(
      capOf(shot),
      math.min(stage.height / rectHeight, stage.width / rectWidth),
    );
    final double zoom = math.max(1, fit) * (1 + creep);

    final double x = (stage.width / 2 - zoom * centre.dx).clamp(
      stage.width * (1 - zoom),
      0.0,
    );
    final double y = (stage.height * focusHeight - zoom * centre.dy).clamp(
      stage.height * (1 - zoom),
      0.0,
    );
    return (zoom: zoom, translate: Offset(x, y));
  }
}

/// The scale of the Rive textures while the camera frames a shot of [zoom]:
/// the texture grows with the zoom up to 3 physical pixels per layout pixel
/// (`max(1, 3 / devicePixelRatio)`), never below 1. At a device pixel ratio
/// of 3 or more the texture stays at screen size.
double cameraRenderScale(double zoom, double devicePixelRatio) {
  final double cap = devicePixelRatio > 0
      ? math.max(1, 3 / devicePixelRatio)
      : 1;
  return math.max(1, math.min(zoom, cap));
}
