import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../../core/design/design.dart';

/// Where the speech bubble sits relative to the face.
enum BubbleSide {
  /// Left of the face, its tail on its right end.
  left,

  /// Right of the face, its tail on its left end.
  right,

  /// Over the head (no room beside the face: portrait phones), its tail
  /// coming down beside the mouth.
  above,
}

/// The per-sentence plan of the bubble: its side and how wide it may grow.
typedef BubblePlan = ({BubbleSide side, double maxWidth});

/// The bubble on the stage: its box (tail included) and where its tail sits
/// along its bottom edge (0..1, `SpeechBubbleBorder.tailAt`).
typedef BubblePlacement = ({Rect rect, double tailAt});

/// The speech bubble's geometry (moonshot M10 ruling 13), pure, in
/// stage-local px.
///
/// The bubble sits beside the mouth on the side with more room, never over
/// the face ([keepOut]), at most [maxWidthFactor] of the stage wide, inside
/// the safe area between the top chips and the tool chip / composer. When
/// neither side leaves [minSideWidth], it goes over the head.
abstract final class StageBubbleLayout {
  /// The face around the mouth, in avatar-artboard px: the head's width
  /// (`HitHead`, an ellipse 300 wide centred on the mouth's x) and from the
  /// brows (190 above the lips) to under the chin (70 below).
  static const EdgeInsets faceKeepOut = EdgeInsets.fromLTRB(150, 190, 150, 70);

  /// The bubble is at most this share of the stage's width.
  static const double maxWidthFactor = 0.72;

  /// Lines of text a bubble may hold; more: the classic caption.
  static const int maxLines = 4;

  /// The space between the bubble and the face.
  static const double gap = AppSpace.sm;

  /// The narrowest bubble worth putting beside the face.
  static const double minSideWidth = 160;

  /// Where the tail sits on a side bubble (towards the face).
  static const double sideTailAt = 0.86;

  /// The face's box around the mouth [anchor] (stage px), [scale] stage px
  /// per artboard px (`StageFraming.stageScale`).
  static Rect keepOut(Offset anchor, double scale) => Rect.fromLTRB(
    anchor.dx - faceKeepOut.left * scale,
    anchor.dy - faceKeepOut.top * scale,
    anchor.dx + faceKeepOut.right * scale,
    anchor.dy + faceKeepOut.bottom * scale,
  );

  /// The side and the widest bubble for a sentence spoken with the mouth at
  /// [anchor] on a [stage] whose chrome leaves [safe].
  static BubblePlan plan({
    required Size stage,
    required Rect safe,
    required Offset anchor,
    required double scale,
  }) {
    final Rect face = keepOut(anchor, scale);
    final double widest = stage.width * maxWidthFactor;
    final double roomLeft = face.left - gap - safe.left;
    final double roomRight = safe.right - face.right - gap;
    final double room = math.max(roomLeft, roomRight);
    if (room >= minSideWidth) {
      return (
        side: roomLeft >= roomRight ? BubbleSide.left : BubbleSide.right,
        maxWidth: math.min(widest, room),
      );
    }
    return (side: BubbleSide.above, maxWidth: math.min(widest, safe.width));
  }

  /// A bubble of [size] on [side] of the mouth [anchor], clear of the face
  /// [keepOut] and inside [safe]; null when it does not fit.
  ///
  /// [tailAt] is kept for an `above` bubble (the shape stays the sentence's
  /// while the bubble follows); null computes it.
  static BubblePlacement? place({
    required BubbleSide side,
    required Size size,
    required Offset anchor,
    required Rect keepOut,
    required Rect safe,
    double? tailAt,
  }) {
    if (size.width > safe.width || size.height > safe.height) {
      return null;
    }
    switch (side) {
      case BubbleSide.left:
      case BubbleSide.right:
        final double left = side == BubbleSide.left
            ? keepOut.left - gap - size.width
            : keepOut.right + gap;
        if (left < safe.left - _slack ||
            left + size.width > safe.right + _slack) {
          return null;
        }
        // The tail's tip at the mouth's height, kept inside the safe area.
        final double top = (anchor.dy - size.height).clamp(
          safe.top,
          safe.bottom - size.height,
        );
        return (
          rect: Rect.fromLTWH(left, top, size.width, size.height),
          tailAt: side == BubbleSide.left ? sideTailAt : 1 - sideTailAt,
        );
      case BubbleSide.above:
        final double bottom = keepOut.top - gap;
        final double top = bottom - size.height;
        if (top < safe.top - _slack) {
          return null;
        }
        // The tail comes down halfway between the face's edge and the
        // mouth, on the side with more room; the body leans that way.
        final bool leanLeft =
            keepOut.left - safe.left >= safe.right - keepOut.right;
        final double tailX = leanLeft
            ? (keepOut.left + anchor.dx) / 2
            : (keepOut.right + anchor.dx) / 2;
        final double at = tailAt ?? (leanLeft ? sideTailAt : 1 - sideTailAt);
        final double left = (tailX - size.width * at).clamp(
          safe.left,
          safe.right - size.width,
        );
        return (
          rect: Rect.fromLTWH(left, top, size.width, size.height),
          tailAt: tailAt ?? ((tailX - left) / size.width).clamp(0.1, 0.9),
        );
    }
  }

  /// Rounding slack for the fit checks.
  static const double _slack = 0.01;
}

/// A critically damped follow of the bubble's anchor (M10 ruling 13): about
/// [frequency] Hz, no overshoot, and target moves under [deadband] dp are
/// ignored, so per-frame noise never moves the bubble.
class BubbleFollow {
  BubbleFollow(Offset start) : _position = start, _target = start;

  /// The follow's natural frequency.
  static const double frequency = 8;

  /// Target moves smaller than this (dp) are noise.
  static const double deadband = 1;

  static const double _omega = 2 * math.pi * frequency;

  Offset _position;
  Offset _target;
  Offset _velocity = Offset.zero;

  /// Where the bubble's anchor is now.
  Offset get position => _position;

  /// Whether it rests on its target.
  bool get isSettled => _position == _target && _velocity == Offset.zero;

  /// Aims at [next]; false (ignored) when it is within [deadband] of the
  /// current target.
  bool target(Offset next) {
    if ((next.dx - _target.dx).abs() < deadband &&
        (next.dy - _target.dy).abs() < deadband) {
      return false;
    }
    _target = next;
    return true;
  }

  /// Goes to [to] at once (a new sentence, reduce motion).
  void jump(Offset to) {
    _position = to;
    _target = to;
    _velocity = Offset.zero;
  }

  /// Advances by [dt] (the exact critically damped solution: stable for any
  /// frame length).
  void step(Duration dt) {
    if (isSettled) {
      return;
    }
    final double t = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final double decay = math.exp(-_omega * t);
    final Offset e0 = _position - _target;
    final Offset c = _velocity + e0 * _omega;
    final Offset e = (e0 + c * t) * decay;
    _velocity = (_velocity - c * (_omega * t)) * decay;
    _position = _target + e;
    if (e.distance < 0.05 && _velocity.distance < 1) {
      _position = _target;
      _velocity = Offset.zero;
    }
  }
}
