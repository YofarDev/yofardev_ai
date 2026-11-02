import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/talking_phase.dart';
import '../../../core/services/audio/interruption_service.dart';
import '../../talking/talking.dart';
import '../presentation/bloc/chat_cubit.dart';
import '../presentation/bloc/chat_state.dart';

/// Floating stop button that appears when assistant is streaming
///
/// Should be placed in a Stack at the bottom-right of the screen.
/// Tapping interrupts the assistant's TTS and animation.
class FloatingStopButton extends StatelessWidget {
  const FloatingStopButton({
    super.key,
    this.bottomPadding = 100,
    this.onlyText = false,
  });

  final double bottomPadding;
  final bool onlyText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ChatStatus chatStatus = context.select<ChatCubit, ChatStatus>(
      (ChatCubit cubit) => cubit.state.status,
    );
    final TalkingPhase talkingPhase = context
        .select<TalkingCubit, TalkingPhase>(
          (TalkingCubit cubit) => cubit.state.phase,
        );
    final bool shouldShow =
        (!onlyText && chatStatus == ChatStatus.streaming) ||
        talkingPhase == TalkingPhase.speaking ||
        talkingPhase == TalkingPhase.generating ||
        talkingPhase == TalkingPhase.waiting;

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
          onPressed: () => context.read<InterruptionService>().interrupt(),
          child: const Icon(Icons.stop),
        ),
      ),
    );
  }
}
