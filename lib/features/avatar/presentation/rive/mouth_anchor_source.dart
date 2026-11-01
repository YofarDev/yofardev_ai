import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/models/performance/performance.dart';

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
///
/// The reading cadence follows the quality [tier] (M11 ruling 13): the avatar
/// view asks [takeReading] after each advance; ultra reads every advance,
/// high every 2nd, low only once after each [requestReading] (the stage
/// calls it at every sentence start) and once after [clear] (a fresh file).
class MouthAnchorSource {
  /// The smallest move (artboard px, either axis) worth publishing.
  static const double epsilon = 0.05;

  final ValueNotifier<Offset?> _anchor = ValueNotifier<Offset?>(null);
  Offset? _pending;
  bool _scheduled = false;
  bool _disposed = false;
  QualityTier _tier = QualityTier.ultra;
  int _advances = 0;
  bool _armed = true;

  /// The tier the reading cadence follows.
  QualityTier get tier => _tier;

  set tier(QualityTier value) {
    if (value == _tier) {
      return;
    }
    _tier = value;
    // The next advance reads, whatever the new cadence.
    _armed = true;
    _advances = 0;
  }

  /// Whether this advance should read the anchor (and consumes a pending
  /// request).
  bool takeReading() {
    if (_disposed) {
      return false;
    }
    final int? stride = _tier.mouthAnchorStride;
    if (_armed) {
      _armed = false;
      _advances = 1;
      return true;
    }
    if (stride == null) {
      return false;
    }
    final bool read = _advances % stride == 0;
    _advances++;
    return read;
  }

  /// A new sentence: the next advance reads the anchor (low tier).
  void requestReading() => _armed = true;

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

  /// No anchor any more (the avatar view went away or reloads); the next
  /// advance reads again.
  void clear() {
    _armed = true;
    report(null);
  }

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
