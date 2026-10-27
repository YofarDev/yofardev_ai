import 'package:flutter/material.dart';

/// A rounded speech bubble with a short tail on its bottom edge.
///
/// The tail takes [tailHeight] of the box's height: lay the content out with
/// at least that much bottom padding. Use it as the `shape` of a `GlassPanel`.
class SpeechBubbleBorder extends OutlinedBorder {
  const SpeechBubbleBorder({
    this.radius = 20,
    this.tailAt = 0.5,
    super.side = BorderSide.none,
  });

  /// Corner radius of the bubble body.
  final double radius;

  /// Horizontal position of the tail, 0..1 of the width. Clamped so the tail
  /// never starts inside a rounded corner.
  final double tailAt;

  /// Height of the tail, taken from the bottom of the box.
  static const double tailHeight = 12;
  static const double _tailHalfWidth = 9;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final Rect body = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom - tailHeight,
    );
    final double r = radius.clamp(0, body.shortestSide / 2);
    final double minX = body.left + r + _tailHalfWidth;
    final double maxX = body.right - r - _tailHalfWidth;
    final double x = (body.left + body.width * tailAt).clamp(
      minX,
      maxX < minX ? minX : maxX,
    );
    // The tail leans towards the side it sits on, like a voice coming from
    // below and slightly off-centre.
    final double lean = (tailAt - 0.5) * 2 * _tailHalfWidth;
    final Path tail = Path()
      ..moveTo(x - _tailHalfWidth, body.bottom - 1)
      ..lineTo(x + lean, rect.bottom)
      ..lineTo(x + _tailHalfWidth, body.bottom - 1)
      ..close();
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(r))),
      tail,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) {
      return;
    }
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  SpeechBubbleBorder copyWith({
    BorderSide? side,
    double? radius,
    double? tailAt,
  }) {
    return SpeechBubbleBorder(
      radius: radius ?? this.radius,
      tailAt: tailAt ?? this.tailAt,
      side: side ?? this.side,
    );
  }

  @override
  ShapeBorder scale(double t) => SpeechBubbleBorder(
    radius: radius * t,
    tailAt: tailAt,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is SpeechBubbleBorder &&
      other.radius == radius &&
      other.tailAt == tailAt &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, tailAt, side);
}
