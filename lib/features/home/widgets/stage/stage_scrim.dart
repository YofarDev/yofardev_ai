import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Ink fading over the stage behind the chrome, so text and controls stay
/// legible on bright scenes. Ignores pointers.
class StageScrim extends StatelessWidget {
  const StageScrim.top({super.key}) : top = true, strength = 1;

  const StageScrim.bottom({super.key, this.strength = 1}) : top = false;

  final bool top;

  /// 0..1 multiplier of the scrim's opacity.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    return IgnorePointer(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: top ? 0.16 : 0.42,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.bottomCenter : Alignment.topCenter,
                end: top ? Alignment.topCenter : Alignment.bottomCenter,
                colors: <Color>[
                  ink.withValues(alpha: 0),
                  ink.withValues(alpha: (top ? 0.25 : 0.5) * strength),
                  ink.withValues(alpha: (top ? 0.5 : 0.82) * strength),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
