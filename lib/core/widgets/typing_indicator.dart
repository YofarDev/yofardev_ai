import 'package:flutter/material.dart';

import '../design/design.dart';

/// Three pulsing dots used as the typing indicator, replacing the v3 Lottie
/// asset with pure Flutter animation.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.size = 8.0});

  /// Diameter of each dot.
  final double size;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color dotColor = context.colors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _pulseDot(i, dotColor),
              ),
          ],
        );
      },
    );
  }

  Widget _pulseDot(int index, Color color) {
    // Staggered phase per dot: each peaks in turn within one cycle.
    final double phase = (_controller.value * 3 - index).clamp(0.0, 1.0);
    final double scale = 0.6 + 0.4 * (1.0 - (2.0 * phase - 1.0).abs());
    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
