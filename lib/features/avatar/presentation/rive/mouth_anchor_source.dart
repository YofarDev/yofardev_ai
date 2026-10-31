import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Where the avatar's mouth is (contract v13 `MouthAnchor`, moonshot M10
/// ruling 12), in avatar-artboard px (the `Avatar` artboard's top-left at
/// 0, 0), for the speech bubble drawn beside it. Rive-free.
///
/// The avatar view reports the anchor's world translation once per frame,
/// right after its state machine advances ([report]); [anchor] is null when
/// there is no anchor: a file without `MouthAnchor` (an older avatar), the
/// web, a non-finite reading, or no avatar on screen.
///
/// Rive advances while it paints, so a reading taken then is published once
/// the frame is over (a listener may rebuild, which a paint must never do);
/// several readings in one frame publish the last one. Moves below [epsilon]
/// are dropped: per-frame float noise is no movement.
class MouthAnchorSource {
  /// The smallest move (artboard px, either axis) worth publishing.
  static const double epsilon = 0.05;

  final ValueNotifier<Offset?> _anchor = ValueNotifier<Offset?>(null);
  Offset? _pending;
  bool _scheduled = false;
  bool _disposed = false;

  /// The mouth in artboard px; null: no anchor.
  ValueListenable<Offset?> get anchor => _anchor;

  /// One reading of the anchor ([point] null: the file has none).
  void report(Offset? point) {
    if (_disposed) {
      return;
    }
    _pending = point != null && point.isFinite ? point : null;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_scheduled) {
        _scheduled = true;
        SchedulerBinding.instance.addPostFrameCallback(_flush);
      }
      return;
    }
    _publish();
  }

  /// No anchor any more (the avatar view went away or reloads).
  void clear() => report(null);

  void dispose() {
    _disposed = true;
    _anchor.dispose();
  }

  void _flush(Duration _) {
    _scheduled = false;
    if (!_disposed) {
      _publish();
    }
  }

  void _publish() {
    final Offset? next = _pending;
    final Offset? current = _anchor.value;
    if (next != null &&
        current != null &&
        (next.dx - current.dx).abs() < epsilon &&
        (next.dy - current.dy).abs() < epsilon) {
      return;
    }
    _anchor.value = next;
  }
}
