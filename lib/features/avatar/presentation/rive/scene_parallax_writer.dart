import 'dart:ui' show Offset;

import 'avatar_rive_contract.dart';

/// Writes the parallax offset to `SceneVM.parallaxX` / `parallaxY`
/// (contract v7), each axis only when it moved by more than [epsilon].
class SceneParallaxWriter {
  SceneParallaxWriter(this._setNumber);

  final void Function(String name, double value) _setNumber;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  double? _x;
  double? _y;

  /// Forgets what was written (a fresh binding has none of it).
  void reset() {
    _x = null;
    _y = null;
  }

  /// Writes [offset] (each axis clamped to -1..1); [force] writes both axes.
  void write(Offset offset, {bool force = false}) {
    final double x = offset.dx.clamp(
      AvatarRiveContract.lightDirMin,
      AvatarRiveContract.lightDirMax,
    );
    final double y = offset.dy.clamp(
      AvatarRiveContract.lightDirMin,
      AvatarRiveContract.lightDirMax,
    );
    final double? lastX = _x;
    if (force || lastX == null || (x - lastX).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropParallaxX, x);
      _x = x;
    }
    final double? lastY = _y;
    if (force || lastY == null || (y - lastY).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropParallaxY, y);
      _y = y;
    }
  }
}
