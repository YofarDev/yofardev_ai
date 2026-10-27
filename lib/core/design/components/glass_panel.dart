import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_glass.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_tokens.dart';

/// A raised glass surface: a diagonal gradient fill and an outline, both
/// driven by the [level]'s tokens.
///
/// The backdrop blur is expensive, so it is applied only when [blur] is true
/// (use it for a few large surfaces, never for list items).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.level = AppGlassLevel.regular,
    this.borderRadius,
    this.blur = false,
    this.padding,
  });

  final Widget child;
  final AppGlassLevel level;
  final BorderRadius? borderRadius;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AppGlassStyle style = tokens.glass(level);
    final Color fill = tokens.glassSurface;
    final Color border = tokens.glassBorder;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(tokens.radius(AppRadius.lg));
    final Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    final Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            fill.withValues(alpha: style.fillAlpha),
            fill.withValues(alpha: style.fillAlpha * 0.4),
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: border.withValues(alpha: style.borderAlpha),
          width: tokens.outlineWidth,
        ),
      ),
      child: content,
    );

    if (!blur) {
      return panel;
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: panel,
      ),
    );
  }
}
