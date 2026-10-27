import 'package:flutter/material.dart';

import '../../../../../core/design/design.dart';

class TaskLlmBackgroundLayers extends StatelessWidget {
  const TaskLlmBackgroundLayers({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    context.tokens.background,
                    context.colors.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: <Color>[
                    context.colors.primary.withValues(alpha: 0.08),
                    context.colors.secondary.withValues(alpha: 0.05),
                    context.colors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    context.colors.surface.withValues(alpha: 0.4),
                    context.colors.surface.withValues(alpha: 0.2),
                    context.colors.surface.withValues(alpha: 0.4),
                  ],
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
