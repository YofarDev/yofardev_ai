import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../../avatar/presentation/bloc/avatar_state.dart';
import '../../chat/domain/models/chat_entry.dart';
import '../../chat/presentation/bloc/chat_message_cubit.dart';
import '../../chat/presentation/bloc/chat_message_state.dart';
import '../../chat/presentation/bloc/chat_streaming_cubit.dart';
import '../../chat/presentation/bloc/chat_streaming_state.dart';
import '../../chat/presentation/bloc/chats_cubit.dart';
import '../../chat/presentation/bloc/chats_state.dart';
import '../../demo/data/repositories/demo_repository_impl.dart';
import '../../demo/presentation/bloc/demo_cubit.dart';
import '../../demo/presentation/bloc/demo_state.dart';
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
        BlocListener<ChatStreamingCubit, ChatStreamingState>(
          listenWhen:
              (ChatStreamingState previous, ChatStreamingState current) =>
                  previous.status != current.status,
          listener: _onChatStreamingStateChanged,
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
              previous.currentChat.id != current.currentChat.id ||
              (previous.status == ChatsStatus.loading &&
                  (current.status == ChatsStatus.success ||
                      current.status == ChatsStatus.loaded)),
          listener: _onCurrentChatChanged,
        ),
        BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (ChatsState previous, ChatsState current) =>
              current.currentChat.entries.length >
              previous.currentChat.entries.length,
          listener: _onNewChatEntry,
        ),
        BlocListener<DemoCubit, DemoState>(
          listenWhen: (DemoState previous, DemoState current) =>
              previous.currentScript != current.currentScript,
          listener: _onDemoScriptChanged,
        ),
      ],
      child: child,
    );
  }

  void _onAvatarStateChanged(BuildContext context, AvatarState state) async {
    if (state.statusAnimation == AvatarStatusAnimation.initial) return;
    await context.read<HomeCubit>().startVolumeFade(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).errorWithMessage(message),
            ),
          ),
        );
      },
    );
  }

  void _onChatStreamingStateChanged(
    BuildContext context,
    ChatStreamingState streamingState,
  ) {
    final TalkingCubit talkingCubit = context.read<TalkingCubit>();

    switch (streamingState.status) {
      case ChatStreamingStatus.initial:
        // Do nothing
        break;
      case ChatStreamingStatus.loading:
      case ChatStreamingStatus.typing:
      case ChatStreamingStatus.streaming:
        // Show thinking animation while waiting for LLM response
        talkingCubit.setLoadingStatus(true);
      case ChatStreamingStatus.success:
        // Streaming completed successfully
        // Don't stop here - let TTS play and handle state transition
        break;
      case ChatStreamingStatus.error:
      case ChatStreamingStatus.interrupted:
        // Error or interruption - stop thinking animation
        talkingCubit.stop();
        break;
    }
  }

  void _onCurrentChatChanged(BuildContext context, ChatsState state) {
    context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
  }

  void _onDemoScriptChanged(BuildContext context, DemoState state) {
    if (state.currentScript != null) {
      AppLogger.info(
        'Demo script changed to: ${state.currentScript!.name}',
        tag: 'HomeBlocListeners',
      );

      // Activate demo mode when a script is set
      final DemoService demoService = getIt<DemoService>();
      final ChatsState chatsState = context.read<ChatsCubit>().state;

      AppLogger.info(
        'Calling activateDemo for chat: ${chatsState.currentChat.id}',
        tag: 'HomeBlocListeners',
      );

      demoService.activateDemo(
        chatId: chatsState.currentChat.id,
        script: state.currentScript!,
      );

      AppLogger.info(
        'Demo activated, FakeLlmService isActive: ${demoService.isActive}',
        tag: 'HomeBlocListeners',
      );

      // Show snackbar to indicate demo mode is active
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).demoModeActivated(state.currentScript!.name),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onNewChatEntry(BuildContext context, ChatsState state) {
    final List<ChatEntry> entries = state.currentChat.entries;
    if (entries.isEmpty) return;

    final ChatEntry lastEntry = entries.last;

    AppLogger.debug(
      '_onNewChatEntry called: entryType=${lastEntry.entryType}, entries.length=${entries.length}',
      tag: 'HomeBlocListeners',
    );

    // Only process yofardev (AI) entries
    if (lastEntry.entryType != EntryType.yofardev) return;

    // Extract avatar config from JSON safely (handles empty/malformed JSON)
    AvatarConfig avatarConfig = lastEntry.getAvatarConfig();

    // Get current avatar state
    final AvatarState avatarState = context.read<AvatarCubit>().state;
    final Avatar currentAvatar = avatarState.avatar;

    AppLogger.debug(
      'Current avatar: bg=${currentAvatar.background}, top=${currentAvatar.top}',
      tag: 'HomeBlocListeners',
    );
    AppLogger.debug(
      'New avatar config: bg=${avatarConfig.background}, top=${avatarConfig.top}',
      tag: 'HomeBlocListeners',
    );

    // Determine what changed and set appropriate animation
    final bool backgroundChanged =
        avatarConfig.background != null &&
        avatarConfig.background != currentAvatar.background;

    final bool clothesChanged =
        (avatarConfig.top != null && avatarConfig.top != currentAvatar.top) ||
        (avatarConfig.glasses != null &&
            avatarConfig.glasses != currentAvatar.glasses) ||
        (avatarConfig.hat != null && avatarConfig.hat != currentAvatar.hat) ||
        (avatarConfig.costume != null &&
            avatarConfig.costume != currentAvatar.costume);

    AppLogger.debug(
      'backgroundChanged=$backgroundChanged, clothesChanged=$clothesChanged',
      tag: 'HomeBlocListeners',
    );

    // Set animation type based on what changed (ignoring LLM's specials value)
    // Animations are now fully controlled client-side, not by the LLM
    if (backgroundChanged) {
      // Background change requires leave and comeback animation
      avatarConfig = avatarConfig.copyWith(
        specials: AvatarSpecials.leaveAndComeBack,
      );
      AppLogger.debug(
        'Background changed, setting leaveAndComeBack animation',
        tag: 'HomeBlocListeners',
      );
    } else if (clothesChanged) {
      // Clothes change requires outOfScreen animation (go down and up)
      avatarConfig = avatarConfig.copyWith(
        specials: AvatarSpecials.outOfScreen,
      );
      AppLogger.debug(
        'Clothes changed, setting outOfScreen for animation',
        tag: 'HomeBlocListeners',
      );
    }

    // Check if there's anything to update (ignore specials from LLM)
    if (avatarConfig.background != null ||
        avatarConfig.top != null ||
        avatarConfig.glasses != null ||
        avatarConfig.hat != null ||
        avatarConfig.costume != null) {
      AppLogger.debug(
        'Updating avatar with config: '
        'bg=${avatarConfig.background}, '
        'top=${avatarConfig.top}, '
        'glasses=${avatarConfig.glasses}, '
        'hat=${avatarConfig.hat}, '
        'costume=${avatarConfig.costume}, '
        'specials=${avatarConfig.specials}',
        tag: 'HomeBlocListeners',
      );

      if (context.mounted) {
        // Update AvatarCubit for animation and display
        context.read<AvatarCubit>().onNewAvatarConfig(
          state.currentChat.id,
          avatarConfig,
        );

        // Update ChatsCubit to persist avatar to chat
        context.read<ChatsCubit>().updateAvatarOpenedChat(avatarConfig);
      }
    }
  }
}
