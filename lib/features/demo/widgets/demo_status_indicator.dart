import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/demo_cubit.dart';

/// Status indicator showing demo mode is active
class DemoStatusIndicator extends StatelessWidget {
  const DemoStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DemoCubit, DemoState>(
      buildWhen: (DemoState previous, DemoState current) =>
          previous.isActive != current.isActive ||
          previous.remainingResponses != current.remainingResponses,
      builder: (BuildContext context, DemoState state) {
        if (!state.isActive) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.play_circle, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'DEMO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.remainingResponses > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  '${state.remainingResponses} left',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
