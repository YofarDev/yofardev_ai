import 'package:flutter/material.dart';

class CurrentPromptText extends StatelessWidget {
  final String prompt;
  const CurrentPromptText({
    super.key,
    required this.prompt,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
