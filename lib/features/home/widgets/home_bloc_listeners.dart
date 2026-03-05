import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../avatar/bloc/avatar_cubit.dart';
import '../../avatar/bloc/avatar_state.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../../chat/bloc/chats_state.dart';
import '../../talking/bloc/talking_cubit.dart';
import '../../talking/bloc/talking_state.dart';
import '../bloc/home_cubit.dart';

/// Combines all BlocListeners for HomeScreen
/// Flat structure instead of 5-level nesting
class HomeBlocListeners extends StatelessWidget {
  const HomeBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AvatarCubit, AvatarState>(
      listenWhen: (AvatarState previous, AvatarState current) =>
          previous.statusAnimation != current.statusAnimation ||
          previous.status != current.status,
      listener: (BuildContext context, AvatarState state) async {
        if (state.statusAnimation == AvatarStatusAnimation.initial) return;
        context.read<HomeCubit>().startVolumeFade(
          state.statusAnimation != AvatarStatusAnimation.leaving,
        );
      },
      child: BlocListener<TalkingCubit, TalkingState>(
        listener: (BuildContext context, TalkingState talkingState) {
          // Handle talking state changes with new freezed union type
          talkingState.when(
            idle: () {
              context.read<HomeCubit>().stopWaitingTtsLoop();
            },
            waiting: () {
              // Waiting sentences - no thinking animation
              // TtsService handles playback, HomeCubit manages volume
              if (context.mounted) {
                context.read<HomeCubit>().startWaitingTtsLoop();
              }
            },
            generating: () {
              // TTS generation - thinking animation shows
              // No action needed here, UI updates via state.shouldShowTalking
            },
            speaking: () {
              // TTS is playing
              context.read<HomeCubit>().stopWaitingTtsLoop();
            },
            error: (String message) {
              context.read<HomeCubit>().stopWaitingTtsLoop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $message')));
            },
          );
        },
        child: BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (ChatsState previous, ChatsState current) =>
              previous.currentLanguage != current.currentLanguage,
          listener: (BuildContext context, ChatsState state) {
            // Prepare waiting TTS sentences for new language
            // TODO: Move this logic to a service or cubit
          },
          child: BlocListener<ChatsCubit, ChatsState>(
            listenWhen: (ChatsState previous, ChatsState current) =>
                previous.currentChat.id != current.currentChat.id ||
                (previous.status == ChatsStatus.loading &&
                    (current.status == ChatsStatus.success ||
                        current.status == ChatsStatus.loaded)),
            listener: (BuildContext context, ChatsState state) {
              context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}
