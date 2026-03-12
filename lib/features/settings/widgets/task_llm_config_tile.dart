import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';

/// Tile widget for navigating to task-specific LLM configuration
class TaskLlmConfigTile extends StatelessWidget {
  const TaskLlmConfigTile({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RouteConstants.taskLlmConfig),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: 0.12),
              AppColors.glassSurface.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.psychology_outlined,
              color: AppColors.onSurface.withValues(alpha: 0.7),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Task LLM Config',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure different LLMs for assistant, title generation, and function calling',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurface.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
