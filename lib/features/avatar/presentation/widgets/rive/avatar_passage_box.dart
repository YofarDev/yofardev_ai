import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../rive/avatar_rive_contract.dart';
import '../../rive/journey_passage.dart';

/// An [AvatarPassage] with its tint's colour resolved (ARGB; the light rig's
/// colour for the passage's [PassageTint]).
class PaintedPassage {
  const PaintedPassage(this.passage, [this.tintColor]);

  final AvatarPassage passage;
  final int? tintColor;

  static const PaintedPassage none = PaintedPassage(AvatarPassage.none);

  /// Nothing to paint differently (a tint with no colour is no tint).
  bool get isNone =>
      !passage.transforms &&
      !passage.clips &&
      passage.opacity >= 1 &&
      (!passage.tints || tintColor == null);

  @override
  bool operator ==(Object other) =>
      other is PaintedPassage &&
      other.passage == passage &&
      other.tintColor == tintColor;

  @override
  int get hashCode => Object.hash(passage, tintColor);
}

/// Paints [child] (the avatar, laid out like the journey: contain,
/// bottom-centre in the 800 × 1000 artboard) through the current
/// [PaintedPassage]: clipped to the threshold's opening, moved, faded and
/// tinted, each layer pushed only while it does something, so outside a
/// journey the avatar paints as it is and the child is never remounted. The
/// child is painted every frame, even fully faded (the Rive avatar advances
/// only while painted). While the passage does anything the avatar takes no
/// pointer.
class AvatarPassageBox extends SingleChildRenderObjectWidget {
  const AvatarPassageBox({super.key, required this.passage, super.child});

  final ValueListenable<PaintedPassage> passage;

  @override
  RenderAvatarPassage createRenderObject(BuildContext context) =>
      RenderAvatarPassage(passage);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAvatarPassage renderObject,
  ) {
    renderObject.passage = passage;
  }
}

class RenderAvatarPassage extends RenderProxyBox {
  RenderAvatarPassage(this._passage);

  ValueListenable<PaintedPassage> _passage;
  bool _wasNone = true;

  final LayerHandle<ClipPathLayer> _clipLayer = LayerHandle<ClipPathLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ColorFilterLayer> _filterLayer =
      LayerHandle<ColorFilterLayer>();

  set passage(ValueListenable<PaintedPassage> value) {
    if (identical(value, _passage)) {
      return;
    }
    if (attached) {
      _passage.removeListener(_changed);
      value.addListener(_changed);
    }
    _passage = value;
    _changed();
  }

  void _changed() {
    final bool none = _passage.value.isNone;
    if (none != _wasNone) {
      _wasNone = none;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _passage.addListener(_changed);
    _wasNone = _passage.value.isNone;
  }

  @override
  void detach() {
    _passage.removeListener(_changed);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    _opacityLayer.layer = null;
    _filterLayer.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && !_passage.value.isNone;

  /// The artboard's scale and top-left in this box (contain, bottom-centre).
  static (double, Offset) fit(Size size) {
    final double k = math.min(
      size.width / AvatarRiveContract.journeyArtboardWidth,
      size.height / AvatarRiveContract.journeyArtboardHeight,
    );
    return (
      k,
      Offset(
        (size.width - AvatarRiveContract.journeyArtboardWidth * k) / 2,
        size.height - AvatarRiveContract.journeyArtboardHeight * k,
      ),
    );
  }

  /// The passage's transform in this box's coordinates.
  static Matrix4 matrixOf(AvatarPassage p, Size size) {
    final (double k, Offset origin) = fit(size);
    final Offset pivot = origin + p.pivot * k;
    final Offset to = pivot + p.offset * k;
    return Matrix4.translationValues(to.dx, to.dy, 0)
      ..rotateZ(p.rotation)
      ..scaleByDouble(p.scaleX, p.scaleY, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
  }

  /// The passage's clip in this box's coordinates: everything left of the
  /// plane, plus the window.
  static Path clipOf(AvatarPassage p, Size size) {
    final (double k, Offset origin) = fit(size);
    final double plane = origin.dx + p.planeX! * k;
    final Path path = Path()
      ..addRect(
        Rect.fromLTRB(-size.width, -size.height, plane, size.height * 2),
      );
    final Rect? window = p.window;
    if (window != null) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            origin.dx + window.left * k,
            origin.dy + window.top * k,
            origin.dx + window.right * k,
            origin.dy + window.bottom * k,
          ),
          Radius.circular(p.windowRadius * k),
        ),
      );
    }
    return path;
  }

  /// Lerps every colour [amount] of the way to [argb], alpha kept.
  static ColorFilter tintOf(int argb, double amount) {
    final double t = amount.clamp(0.0, 1.0);
    final double keep = 1 - t;
    final double r = ((argb >> 16) & 0xFF).toDouble();
    final double g = ((argb >> 8) & 0xFF).toDouble();
    final double b = (argb & 0xFF).toDouble();
    return ColorFilter.matrix(<double>[
      keep, 0, 0, 0, t * r, //
      0, keep, 0, 0, t * g, //
      0, 0, keep, 0, t * b, //
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_passage.value.isNone) {
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final AvatarPassage p = _passage.value.passage;
    if (p.transforms) {
      transform.multiply(matrixOf(p, size));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? box = child;
    final PaintedPassage painted = _passage.value;
    final AvatarPassage p = painted.passage;
    if (box == null) {
      return;
    }
    if (painted.isNone) {
      _clear();
      context.paintChild(box, offset);
      return;
    }
    // Never skip the child, even fully faded: the Rive avatar advances only
    // while it is painted, and a paused avatar never finishes its walk (its
    // `presence_done` never comes). A zero-alpha layer still paints it.
    final int? tintColor = painted.tintColor;

    void tinted(PaintingContext c, Offset o) {
      if (p.tints && tintColor != null) {
        _filterLayer.layer = c.pushColorFilter(
          o,
          tintOf(tintColor, p.tintAmount),
          (PaintingContext c2, Offset o2) => c2.paintChild(box, o2),
          oldLayer: _filterLayer.layer,
        );
      } else {
        _filterLayer.layer = null;
        c.paintChild(box, o);
      }
    }

    void faded(PaintingContext c, Offset o) {
      if (p.opacity < 1) {
        _opacityLayer.layer = c.pushOpacity(
          o,
          (p.opacity * 255).round(),
          tinted,
          oldLayer: _opacityLayer.layer,
        );
      } else {
        _opacityLayer.layer = null;
        tinted(c, o);
      }
    }

    void moved(PaintingContext c, Offset o) {
      if (p.transforms) {
        _transformLayer.layer = c.pushTransform(
          needsCompositing,
          o,
          matrixOf(p, size),
          faded,
          oldLayer: _transformLayer.layer,
        );
      } else {
        _transformLayer.layer = null;
        faded(c, o);
      }
    }

    if (p.clips) {
      _clipLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        clipOf(p, size),
        moved,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      moved(context, offset);
    }
  }

  void _clear() {
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    _opacityLayer.layer = null;
    _filterLayer.layer = null;
  }
}
