import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Caption text straight on the stage, kept legible by a soft halo in the
/// look's ink; capped at [maxLines] lines (null: unlimited), broken evenly
/// when capped (see [BalancedText]).
class StageLine extends StatelessWidget {
  const StageLine({
    super.key,
    required this.text,
    required this.style,
    required this.align,
    this.color,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle? style;
  final TextAlign align;

  /// The text colour; null is the theme's `onSurface`.
  final Color? color;

  /// The line cap; null shows the whole text.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    return BalancedText(
      text,
      align: align,
      maxLines: maxLines,
      style: style?.copyWith(
        color: color ?? context.colors.onSurface,
        shadows: <Shadow>[
          Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 18),
          Shadow(color: ink.withValues(alpha: 0.7), blurRadius: 4),
        ],
      ),
    );
  }
}

/// At most [maxLines] lines (null: unlimited), broken evenly: when the text
/// needs exactly that many lines it takes the narrowest width that still
/// fits, so the last line is never a lone word; an uncapped text that fits
/// the two-line display look keeps that balancing. Longer capped text ends
/// with an ellipsis.
class BalancedText extends StatelessWidget {
  const BalancedText(
    this.text, {
    super.key,
    required this.align,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextAlign align;
  final TextStyle? style;

  /// The line cap; null shows the whole text.
  final int? maxLines;

  /// The display look's line count: an uncapped text that fits it keeps the
  /// even-break balancing instead of growing to full width.
  static const int _balanceLines = 2;

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
      final int target = maxLines ?? _balanceLines;
      if (_lines(painter, maxWidth) != target) {
        return maxWidth;
      }
      double low = maxWidth / 2;
      double high = maxWidth;
      while (high - low > 1) {
        final double mid = (low + high) / 2;
        if (_lines(painter, mid) <= target) {
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
          maxLines: maxLines,
          overflow: maxLines == null
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          textAlign: align,
          style: style,
        );
        if (!constraints.hasBoundedWidth) {
          return child;
        }
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
