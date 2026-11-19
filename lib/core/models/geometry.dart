import 'dart:math' as math;

/// Minimal immutable 2-D vector for domain code that must stay free of
/// `dart:ui` (the architecture checker bans it in `features/*/domain/`).
///
/// Presentation converts at the boundary: a Flutter `Offset` becomes a
/// [Vec2] with `Vec2(offset.dx, offset.dy)`, and back with
/// `Offset(vector.x, vector.y)`.
class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator *(double scale) => Vec2(x * scale, y * scale);

  Vec2 operator /(double scale) => Vec2(x / scale, y / scale);

  Vec2 translate(double dx, double dy) => Vec2(x + dx, y + dy);

  /// Euclidean length, like `Offset.distance`.
  double get distance => math.sqrt(x * x + y * y);

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

/// Minimal axis-aligned box (the `dart:ui` `Rect` subset domain code needs),
/// in whatever coordinate space the caller works in.
class Box2 {
  const Box2.fromLTRB(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;

  Vec2 get topLeft => Vec2(left, top);

  Vec2 get topRight => Vec2(right, top);

  Vec2 get bottomLeft => Vec2(left, bottom);

  Vec2 get bottomRight => Vec2(right, bottom);

  Vec2 get centerLeft => Vec2(left, (top + bottom) / 2);

  Vec2 get centerRight => Vec2(right, (top + bottom) / 2);

  Vec2 get center => Vec2((left + right) / 2, (top + bottom) / 2);

  Vec2 get topCenter => Vec2((left + right) / 2, top);

  /// Grown outward by [delta] on every side, like `Rect.inflate`.
  Box2 inflate(double delta) =>
      Box2.fromLTRB(left - delta, top - delta, right + delta, bottom + delta);

  /// Shrunk by [delta] on every side, like `Rect.deflate`.
  Box2 deflate(double delta) => inflate(-delta);

  double get shortestSide => math.min(width, height);

  bool contains(Vec2 point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  @override
  bool operator ==(Object other) =>
      other is Box2 &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'Box2.fromLTRB($left, $top, $right, $bottom)';
}

/// Minimal width/height pair (the `dart:ui` `Size` subset domain code needs).
class Size2 {
  const Size2(this.width, this.height);

  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is Size2 && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'Size2($width, $height)';
}
