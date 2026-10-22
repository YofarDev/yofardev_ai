import 'package:flutter/material.dart';

import '../../../../../core/res/app_colors.dart';

class TaskLlmBackgroundLayers extends StatelessWidget {
  const TaskLlmBackgroundLayers({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[AppColors.background, AppColors.surface],
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
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.05),
                    AppColors.surface.withValues(alpha: 0.0),
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
                    AppColors.surface.withValues(alpha: 0.4),
                    AppColors.surface.withValues(alpha: 0.2),
                    AppColors.surface.withValues(alpha: 0.4),
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
