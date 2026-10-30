import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart';

/// Where the avatar claims a pointer (M9 ruling 7).
///
/// `avatar.riv`'s eye follow listens on a hit area as big as the artboard,
/// so Rive's own hit test (`RiveHitTestBehavior.translucent`) claims every
/// pointer over the avatar's whole frame, and nothing below it (the scene's
/// prop taps, its drag handle) hears one. Measured on the real runtime
/// (`integration_test/rive_contract_test.dart`): the cord could not be
/// dragged through the avatar layer.
///
/// The gate lets the avatar's [RiveWidget] (hit-testing
/// [RiveHitTestBehavior.transparent]) hear every pointer its listeners cover
/// (the eye follow, the head and body taps), and claims a pointer (stops it
/// reaching what lies below) only where [claims] says it lands on one of the
/// avatar's own tap zones.
class AvatarZoneHitGate extends SingleChildRenderObjectWidget {
  const AvatarZoneHitGate({
    super.key,
    required this.claims,
    required super.child,
  });

  /// Whether a pointer at [Offset] (local, in a box of [Size]) lands on one
  /// of the avatar's tap zones.
  final bool Function(Offset local, Size size) claims;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAvatarZoneHitGate(claims);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAvatarZoneHitGate renderObject,
  ) {
    renderObject.claims = claims;
  }
}

/// [AvatarZoneHitGate]'s render object.
class RenderAvatarZoneHitGate extends RenderProxyBox {
  RenderAvatarZoneHitGate(this.claims);

  bool Function(Offset local, Size size) claims;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }
    // The Rive widget is transparent: it joins the result when one of its
    // listeners is hit, and never stops the pointer.
    hitTestChildren(result, position: position);
    if (!claims(position, size)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

/// The avatar's tap zones read live from its artboard (they follow the
/// head turn, the gestures and the walk): the `avatar_tapped` listeners'
/// targets `HitHead` (an ellipse) and `HitBody` (a rectangle), named in
/// `rive/tools/gen_avatar.py`.
///
/// A file without them falls back to Rive's own listener hit test (any
/// listener claims, the eye follow's included).
class AvatarTapZones {
  AvatarTapZones(
    this._artboard,
    this._stateMachine, {
    required this.fit,
    required this.alignment,
  }) : _head = _artboard.component(headZone),
       _body = _artboard.component(bodyZone);

  static const String headZone = 'HitHead';
  static const String bodyZone = 'HitBody';

  final Artboard _artboard;
  final StateMachine _stateMachine;
  final Component? _head;
  final Component? _body;

  /// How the avatar's [RiveWidget] lays the artboard out.
  final Fit fit;
  final Alignment alignment;

  /// Whether both zones were found in the file.
  bool get found => _head != null && _body != null;

  /// Whether a pointer at [local] in a box [size] big lands on a tap zone.
  bool claims(Offset local, Size size) {
    final Vec2D? point = _toArtboard(local, size);
    if (point == null) {
      return false;
    }
    final Component? head = _head;
    final Component? body = _body;
    if (head == null || body == null) {
      return _stateMachine.hitTest(point);
    }
    return _inside(head, point, ellipse: true) ||
        _inside(body, point, ellipse: false);
  }

  void dispose() {
    _head?.dispose();
    _body?.dispose();
  }

  /// [local] in artboard space, mapped as the Rive widget maps pointers.
  Vec2D? _toArtboard(Offset local, Size size) {
    final Mat2D view = Renderer.computeAlignment(
      fit,
      alignment,
      AABB.fromValues(0, 0, size.width, size.height),
      _artboard.bounds,
      1,
    );
    final Mat2D inverse = Mat2D();
    if (!Mat2D.invert(inverse, view)) {
      return null;
    }
    return inverse * Vec2D.fromOffset(local);
  }

  static bool _inside(Component zone, Vec2D point, {required bool ellipse}) {
    final Mat2D inverse = Mat2D();
    if (!Mat2D.invert(inverse, zone.worldTransform)) {
      return false;
    }
    final Vec2D p = inverse * point;
    final AABB b = zone.localBounds;
    if (b.isEmpty) {
      return false;
    }
    if (!ellipse) {
      return p.x >= b.left && p.x <= b.right && p.y >= b.top && p.y <= b.bottom;
    }
    final double rx = b.width / 2;
    final double ry = b.height / 2;
    final double dx = (p.x - b.centerX) / rx;
    final double dy = (p.y - b.centerY) / ry;
    return dx * dx + dy * dy <= 1;
  }
}
