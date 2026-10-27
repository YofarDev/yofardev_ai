// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_scene.dart';

/// How a [LabCaption] sits on the stage.
enum LabCaptionVariant {
  /// Large, left-aligned display type above the composer (layout L1).
  storyline,

  /// Centred, film-subtitle style line above the dock (layout L2).
  subtitle,

  /// A speech bubble near the character's head (layout L3).
  bubble,
}

/// What the character just said, in the look's display font, two lines max.
/// The sample sentence depends on the scene.
class LabCaption extends StatelessWidget {
  const LabCaption({
    super.key,
    required this.scene,
    this.variant = LabCaptionVariant.storyline,
    this.tailAt = 0.5,
  });

  final AvatarScene scene;
  final LabCaptionVariant variant;

  /// Horizontal position (0..1 of the bubble width) of the bubble's tail.
  final double tailAt;

  /// One line per scene, in the character's voice.
  static String sampleFor(AvatarScene scene) => switch (scene) {
    AvatarScene.livingRoom => 'The cat thinks the lamp is a second moon.',
    AvatarScene.campfire =>
      "Marshmallow number four. I'm not counting, the owl is.",
    AvatarScene.beach => 'That crab keeps side-eyeing my sandwich.',
    AvatarScene.deepSpace => 'Out here, even my rubber duck has its own orbit.',
  };

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      LabCaptionVariant.storyline => _StageLine(
        text: sampleFor(scene),
        style: context.text.headlineSmall?.copyWith(height: 1.22),
        align: TextAlign.start,
      ),
      LabCaptionVariant.subtitle => _StageLine(
        text: sampleFor(scene),
        style: context.text.titleLarge?.copyWith(fontSize: 19, height: 1.32),
        align: TextAlign.center,
      ),
      LabCaptionVariant.bubble => _Bubble(
        text: sampleFor(scene),
        tailAt: tailAt,
      ),
    };
  }
}

/// Caption text straight on the stage, kept legible by a soft halo in the
/// look's ink.
class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.text,
    required this.style,
    required this.align,
  });

  final String text;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    return _BalancedText(
      text,
      align: align,
      style: style?.copyWith(
        color: context.colors.onSurface,
        shadows: <Shadow>[
          Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 18),
          Shadow(color: ink.withValues(alpha: 0.7), blurRadius: 4),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.tailAt});

  final String text;
  final double tailAt;

  static const double _blurSigma = 14;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool cel = tokens.surfaceStyle == AppSurfaceStyle.cel;
    final LabBubbleBorder shape = LabBubbleBorder(
      radius: tokens.radius(AppRadius.lg),
      tailAt: tailAt,
      side: BorderSide(
        color: cel
            ? tokens.glassBorder
            : tokens.glassBorder.withValues(
                alpha: tokens.glassThick.borderAlpha,
              ),
        width: tokens.outlineWidth,
      ),
    );
    final Widget bubble = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: cel
            ? tokens.glassSurface
            : tokens.glassSurface.withValues(alpha: 0.82),
        shadows: cel
            ? <BoxShadow>[
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: 0.6),
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.md + LabBubbleBorder.tailHeight,
        ),
        child: _BalancedText(
          text,
          align: TextAlign.start,
          style: context.text.titleMedium?.copyWith(
            fontSize: 17,
            height: 1.3,
            color: context.colors.onSurface,
          ),
        ),
      ),
    );
    if (cel) {
      return bubble;
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: bubble,
      ),
    );
  }
}

/// Two lines max, broken evenly: when the text needs two lines it takes the
/// narrowest width that still fits in two, so the second line is never a
/// lone word.
class _BalancedText extends StatelessWidget {
  const _BalancedText(this.text, {required this.align, required this.style});

  final String text;
  final TextAlign align;
  final TextStyle? style;

  static const int _maxLines = 2;

  int _lines(TextPainter painter, double width) {
    painter.layout(maxWidth: width);
    return painter.computeLineMetrics().length;
  }

  double _balancedWidth(BuildContext context, double maxWidth) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    try {
      if (_lines(painter, maxWidth) != _maxLines) {
        return maxWidth;
      }
      double low = maxWidth / 2;
      double high = maxWidth;
      while (high - low > 1) {
        final double mid = (low + high) / 2;
        if (_lines(painter, mid) <= _maxLines) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return high.ceilToDouble();
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget child = Text(
          text,
          maxLines: _maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: style,
        );
        if (!constraints.hasBoundedWidth) {
          return child;
        }
        return Align(
          alignment: align == TextAlign.center
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: SizedBox(
            width: _balancedWidth(context, constraints.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// A rounded speech bubble with a short tail on its bottom edge. The tail
/// takes [tailHeight] of the box's height.
class LabBubbleBorder extends ShapeBorder {
  const LabBubbleBorder({
    required this.radius,
    this.tailAt = 0.5,
    this.side = BorderSide.none,
  });

  final double radius;

  /// Horizontal position of the tail, 0..1 of the width.
  final double tailAt;
  final BorderSide side;

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
  ShapeBorder scale(double t) =>
      LabBubbleBorder(radius: radius * t, tailAt: tailAt, side: side.scale(t));
}
