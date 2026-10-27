import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Caption text straight on the stage, kept legible by a soft halo in the
/// look's ink; two lines max, broken evenly (see [BalancedText]).
class StageLine extends StatelessWidget {
  const StageLine({
    super.key,
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
    return BalancedText(
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

/// Two lines max, broken evenly: when the text needs two lines it takes the
/// narrowest width that still fits in two, so the second line is never a
/// lone word. Longer text ends with an ellipsis.
class BalancedText extends StatelessWidget {
  const BalancedText(
    this.text, {
    super.key,
    required this.align,
    required this.style,
  });

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
