import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_glass.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_tokens.dart';

/// A raised glass surface: a diagonal gradient fill and an outline, both
/// driven by the [level]'s tokens.
///
/// By default the panel is a rounded rectangle ([borderRadius]). Pass [shape]
/// for any other outline (a stadium, a speech bubble with a tail...): the
/// fill, the border and the blur then follow it. An [OutlinedBorder] shape
/// gets the glass border as its side; any other [ShapeBorder] keeps its own
/// border. [shape] takes precedence over [borderRadius].
///
/// The scene's key light tints the fill's hue (`scene.glassTint`, derived
/// from the static light rig, so it never flickers).
///
/// The backdrop blur is expensive, so it is applied only when [blur] is true
/// (use it for a few large surfaces, never for list items).
///
/// With the system's high-contrast setting on (`MediaQuery.highContrastOf`,
/// M11 ruling 23: the closest flag Flutter exposes to iOS "reduce
/// transparency") the panel is solid: the opaque surface colour, a full
/// opacity outline and no blur, whatever [level] and [blur] say.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.level = AppGlassLevel.regular,
    this.borderRadius,
    this.blur = false,
    this.padding,
    this.shape,
  });

  final Widget child;
  final AppGlassLevel level;
  final BorderRadius? borderRadius;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  /// Custom outline; null keeps the rounded rectangle of [borderRadius].
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    if (MediaQuery.maybeHighContrastOf(context) ?? false) {
      return _solid(context, tokens);
    }
    final AppGlassStyle style = tokens.glass(level);
    // The key light leans the fill's hue toward the scene's glass tint
    // without making the panel any more opaque.
    final Color fill = Color.alphaBlend(
      tokens.scene.glassTint,
      tokens.glassSurface.withValues(alpha: 1),
    );
    final Color border = tokens.glassBorder;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(tokens.radius(AppRadius.lg));
    final ShapeBorder? customShape = shape;
    final Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    final LinearGradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        fill.withValues(alpha: style.fillAlpha),
        fill.withValues(alpha: style.fillAlpha * 0.4),
      ],
    );
    final BorderSide side = BorderSide(
      color: border.withValues(alpha: style.borderAlpha),
      width: tokens.outlineWidth,
    );

    final Decoration decoration;
    if (customShape == null) {
      decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        border: Border.fromBorderSide(side),
      );
    } else {
      decoration = ShapeDecoration(
        gradient: gradient,
        shape: customShape is OutlinedBorder
            ? customShape.copyWith(side: side)
            : customShape,
      );
    }
    final Widget panel = DecoratedBox(decoration: decoration, child: content);

    if (!blur) {
      return panel;
    }
    final Widget blurred = BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: style.blurSigma,
        sigmaY: style.blurSigma,
      ),
      child: panel,
    );
    if (customShape == null) {
      return ClipRRect(borderRadius: radius, child: blurred);
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: customShape),
      child: blurred,
    );
  }

  /// High contrast: the surface colour, opaque, with a solid outline.
  Widget _solid(BuildContext context, AppTokens tokens) {
    final Color surface = context.colors.surface.withValues(alpha: 1);
    final BorderSide side = BorderSide(
      color: tokens.glassBorder.withValues(alpha: 1),
      width: tokens.outlineWidth,
    );
    final ShapeBorder? customShape = shape;
    final Decoration decoration = customShape == null
        ? BoxDecoration(
            color: surface,
            borderRadius:
                borderRadius ??
                BorderRadius.circular(tokens.radius(AppRadius.lg)),
            border: Border.fromBorderSide(side),
          )
        : ShapeDecoration(
            color: surface,
            shape: customShape is OutlinedBorder
                ? customShape.copyWith(side: side)
                : customShape,
          );
    return DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}
