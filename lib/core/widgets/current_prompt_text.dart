import 'package:flutter/material.dart';

import '../design/design.dart';

class CurrentPromptText extends StatelessWidget {
  final String prompt;
  const CurrentPromptText({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            color: context.colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
