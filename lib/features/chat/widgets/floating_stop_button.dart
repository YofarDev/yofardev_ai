import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio/interruption_service.dart';
import '../bloc/chat_message_cubit.dart';
import '../bloc/chat_message_state.dart';

/// Floating stop button that appears when assistant is streaming
///
/// Should be placed in a Stack at the bottom-right of the screen.
/// Tapping interrupts the assistant's TTS and animation.
class FloatingStopButton extends StatelessWidget {
  const FloatingStopButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<ChatMessageCubit, ChatMessageState>(
      builder: (BuildContext context, ChatMessageState state) {
        // Only show when streaming
        final bool shouldShow = state.status == ChatMessageStatus.streaming;

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 100),
            child: FloatingActionButton(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              onPressed: () => context.read<InterruptionService>().interrupt(),
              child: const Icon(Icons.stop),
            ),
          ),
        );
      },
    );
  }
}
