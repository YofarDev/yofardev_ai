import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/demo_cubit.dart';

/// Overlay widget that shows the demo countdown
class DemoCountdownOverlay extends StatelessWidget {
  const DemoCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DemoCubit, DemoState>(
      buildWhen: (DemoState previous, DemoState current) =>
          previous.isCountingDown != current.isCountingDown ||
          previous.countdownValue != current.countdownValue,
      builder: (BuildContext context, DemoState state) {
        if (!state.isCountingDown) {
          return const SizedBox.shrink();
        }

        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 2.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (BuildContext context, double value, Widget? child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${state.countdownValue}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
