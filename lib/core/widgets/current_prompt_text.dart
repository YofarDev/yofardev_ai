import 'package:flutter/material.dart';

import '../res/app_colors.dart';

class CurrentPromptText extends StatelessWidget {
  final String prompt;
  const CurrentPromptText({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
