import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../../avatar/presentation/bloc/avatar_state.dart';
import '../../chat/presentation/bloc/chats_cubit.dart';
import '../../chat/presentation/bloc/chats_state.dart';
import '../../chat/presentation/bloc/chat_message_cubit.dart';
import '../../chat/presentation/bloc/chat_message_state.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import '../presentation/bloc/home_cubit.dart';

/// Combines all BlocListeners for HomeScreen using MultiBlocListener
/// Flat structure for better readability and maintainability
class HomeBlocListeners extends StatelessWidget {
  const HomeBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <SingleChildWidget>[
        BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              previous.statusAnimation != current.statusAnimation ||
              previous.status != current.status,
          listener: _onAvatarStateChanged,
        ),
        BlocListener<TalkingCubit, TalkingState>(
          listener: _onTalkingStateChanged,
        ),
        BlocListener<ChatMessageCubit, ChatMessageState>(
          listenWhen: (ChatMessageState previous, ChatMessageState current) =>
              current.status == ChatMessageStatus.success ||
              current.status == ChatMessageStatus.error,
          listener: (BuildContext context, ChatMessageState state) {
            // TalkingCubit now manages its own state transitions
            // No need to manually reset loading status
          },
        ),
        BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (ChatsState previous, ChatsState current) =>
              previous.currentLanguage != current.currentLanguage,
          listener: _onLanguageChanged,
        ),
        BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (ChatsState previous, ChatsState current) =>
              previous.currentChat.id != current.currentChat.id ||
              (previous.status == ChatsStatus.loading &&
                  (current.status == ChatsStatus.success ||
                      current.status == ChatsStatus.loaded)),
          listener: _onCurrentChatChanged,
        ),
      ],
      child: child,
    );
  }

  void _onAvatarStateChanged(BuildContext context, AvatarState state) {
    if (state.statusAnimation == AvatarStatusAnimation.initial) return;
    context.read<HomeCubit>().startVolumeFade(
      state.statusAnimation != AvatarStatusAnimation.leaving,
    );
  }

  void _onTalkingStateChanged(BuildContext context, TalkingState talkingState) {
    // Handle talking state changes with new freezed union type
    talkingState.when(
      idle: (MouthState mouthState) {
        context.read<HomeCubit>().stopWaitingTtsLoop();
      },
      waiting: (MouthState mouthState) {
        // Waiting sentences - no thinking animation
        // TtsService handles playback, HomeCubit manages volume
        if (context.mounted) {
          context.read<HomeCubit>().startWaitingTtsLoop();
        }
      },
      generating: (MouthState mouthState) {
        // TTS generation - thinking animation shows
        // No action needed here, UI updates via state.shouldShowTalking
      },
      speaking: (MouthState mouthState) {
        // TTS is playing
        context.read<HomeCubit>().stopWaitingTtsLoop();
      },
      error: (String message, MouthState mouthState) {
        context.read<HomeCubit>().stopWaitingTtsLoop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $message')));
      },
    );
  }

  void _onLanguageChanged(BuildContext context, ChatsState state) {
    // Prepare waiting TTS sentences for new language
    // TODO: Move this logic to a service or cubit
  }

  void _onCurrentChatChanged(BuildContext context, ChatsState state) {
    context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
  }
}
