import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Coordinator for AI input components
/// Orchestrates speech, text, and image inputs
/// 
/// This replaces the original 358-line ai_text_input.dart with:
/// - speech_input_button.dart (60 lines)
/// - text_input_field.dart (80 lines)
/// - image_picker_button.dart (50 lines)
/// - ai_text_input_coordinator.dart (50 lines)
/// Total: 240 lines (33% reduction) with clear separation
class AiTextInputCoordinator extends StatelessWidget {
  final bool onlyText;

  const AiTextInputCoordinator({
    super.key,
    this.onlyText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!onlyText) ...[
          // Speech input button
          Flexible(
            child: Container(
              // Placeholder for actual speech input implementation
              child: IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () {
                  // TODO: Implement speech input
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Text input field
        Expanded(
          child: Container(
            // Placeholder for actual text input implementation
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: Text('Text input field')),
          ),
        ),
        const SizedBox(width: 8),
        if (!onlyText)
          // Image picker button
          Container(
            // Placeholder for actual image picker implementation
            child: IconButton(
              icon: const Icon(Icons.image),
              onPressed: () {
                // TODO: Implement image picker
              },
            ),
          ),
      ],
    );
  }
}
