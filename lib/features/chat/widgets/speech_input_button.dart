import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/logic/talking/talking_cubit.dart';

/// Speech input button for voice-to-text
/// Extracted from ai_text_input.dart (358 → 60 lines)
class SpeechInputButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const SpeechInputButton({
    super.key,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkingCubit, TalkingState>(
      listener: (context, state) {
        // Handle talking state changes if needed
      },
      child: IconTheme(
        data: IconThemeData(color: Theme.of(context).colorScheme.primary),
        child: IconButton(
          icon: Icon(enabled ? Icons.mic : Icons.mic_off),
          onPressed: enabled ? onPressed : null,
          tooltip: 'Voice input',
        ),
      ),
    );
  }
}
