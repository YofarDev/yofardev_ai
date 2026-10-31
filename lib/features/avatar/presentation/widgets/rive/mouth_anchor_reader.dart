import 'dart:ui' show Offset;

import 'package:rive/rive.dart';

/// Reads the avatar file's `MouthAnchor` (contract v13: a named `Node` at the
/// centre of the lips, inside the head's turn pivot) the way
/// `AvatarTapZones` reads `HitHead`: `artboard.component(name)` and its
/// `worldTransform`.
///
/// [read] gives the anchor's world translation in artboard px (the
/// artboard's bounds' top-left at 0, 0); null when the file has no
/// `MouthAnchor` (an older avatar).
class MouthAnchorReader {
  MouthAnchorReader(Artboard artboard)
    : _anchor = artboard.component(node),
      _bounds = artboard.bounds;

  /// The contract v13 name of the mouth's node.
  static const String node = 'MouthAnchor';

  final Component? _anchor;
  final AABB _bounds;

  /// Whether the file has the anchor.
  bool get found => _anchor != null;

  /// The anchor now, or null without one.
  Offset? read() {
    final Component? anchor = _anchor;
    if (anchor == null) {
      return null;
    }
    return translationOf(anchor.worldTransform, _bounds);
  }

  void dispose() => _anchor?.dispose();

  /// The translation of a world transform [world] (`[a b c d tx ty]`) in
  /// artboard px, relative to the artboard [bounds]' top-left.
  static Offset translationOf(Mat2D world, AABB bounds) =>
      Offset(world[4] - bounds.left, world[5] - bounds.top);
}
