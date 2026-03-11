import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/audio/interruption_service.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import '../presentation/bloc/chats_cubit.dart';
import '../presentation/bloc/chats_state.dart';

/// Floating stop button that appears when assistant is streaming
///
/// Should be placed in a Stack at the bottom-right of the screen.
/// Tapping interrupts the assistant's TTS and animation.
class FloatingStopButton extends StatelessWidget {
  const FloatingStopButton({super.key, this.bottomPadding = 100});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return BlocBuilder<TalkingCubit, TalkingState>(
          builder: (BuildContext context, TalkingState talkingState) {
            final bool shouldShow =
                state.status == ChatsStatus.streaming ||
                talkingState is SpeakingState ||
                talkingState is GeneratingState ||
                talkingState is WaitingState;

            if (!shouldShow) {
              return const SizedBox.shrink();
            }

            return Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: 20, bottom: bottomPadding),
                child: FloatingActionButton(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  onPressed: () =>
                      _resolveInterruptionService(context).interrupt(),
                  child: const Icon(Icons.stop),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InterruptionService _resolveInterruptionService(BuildContext context) {
    try {
      return context.read<InterruptionService>();
    } catch (_) {
      return getIt<InterruptionService>();
    }
  }
}
