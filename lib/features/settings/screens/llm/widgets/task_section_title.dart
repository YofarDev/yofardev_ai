import 'package:flutter/material.dart';
import '../../../../../core/res/app_colors.dart';

/// Animated section title widget for task configuration sections
class TaskSectionTitle extends StatelessWidget {
  const TaskSectionTitle({
    super.key,
    required this.title,
    required this.animation,
  });

  final String title;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - animation.value)),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
