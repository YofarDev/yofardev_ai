import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../../avatar/presentation/bloc/avatar_state.dart';
import '../../chat/presentation/bloc/chat_cubit.dart';
import '../../chat/presentation/bloc/chat_state.dart';
import '../../demo/presentation/bloc/demo_cubit.dart';
import '../../demo/presentation/bloc/demo_state.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';

/// Simplified BlocListener widget - delegates to AppLifecycleService
///
/// This widget now acts as a thin wrapper that connects BlocListeners
/// to the AppLifecycleService, which handles all cross-feature coordination.
class HomeBlocListeners extends StatelessWidget {
  const HomeBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppLifecycleService appLifecycleService =
        getIt<AppLifecycleService>();

    return MultiBlocListener(
      listeners: <SingleChildWidget>[
        // Avatar animation changes → volume fade
        BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              previous.statusAnimation != current.statusAnimation ||
              previous.status != current.status,
          listener: (BuildContext context, AvatarState state) {
            if (state.statusAnimation != AvatarStatusAnimation.initial) {
              appLifecycleService.onAvatarAnimationChanged(
                state.statusAnimation,
              );
            }
          },
        ),

        // Talking state changes → waiting TTS loop
        BlocListener<TalkingCubit, TalkingState>(
          listener: (BuildContext context, TalkingState state) {
            appLifecycleService.onTalkingStateChanged(state, context);
          },
        ),

        // Streaming state changes → thinking animation
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (ChatState previous, ChatState current) =>
              previous.status != current.status,
          listener: (BuildContext context, ChatState state) {
            appLifecycleService.onStreamingStateChanged(state.status);
          },
        ),

        // Chat changed → stop talking, load avatar
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (ChatState previous, ChatState current) =>
              previous.currentChat.id != current.currentChat.id ||
              (previous.status == ChatStatus.loading &&
                  (current.status == ChatStatus.success ||
                      current.status == ChatStatus.loaded)),
          listener: (BuildContext context, ChatState state) {
            appLifecycleService.onChatChanged(state.currentChat.id);
          },
        ),

        // New chat entry → update avatar
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (ChatState previous, ChatState current) {
            // Trigger when the entry count increases
            if (current.currentChat.entries.length >
                previous.currentChat.entries.length) {
              return true;
            }

            // Also trigger when the last entry's body has changed
            if (current.currentChat.entries.isNotEmpty &&
                previous.currentChat.entries.isNotEmpty) {
              final ChatEntry currentLast = current.currentChat.entries.last;
              final ChatEntry previousLast = previous.currentChat.entries.last;

              return currentLast.id == previousLast.id &&
                  currentLast.body != previousLast.body;
            }

            return false;
          },
          listener: (BuildContext context, ChatState state) {
            final List<ChatEntry> entries = state.currentChat.entries;
            if (entries.isNotEmpty) {
              appLifecycleService.onNewChatEntry(
                entries.last,
                state.currentChat.id,
              );
            }
          },
        ),

        // Demo script changed → activate demo mode
        BlocListener<DemoCubit, DemoState>(
          listenWhen: (DemoState previous, DemoState current) =>
              previous.currentScript != current.currentScript,
          listener: (BuildContext context, DemoState state) {
            appLifecycleService.onDemoScriptChanged(
              state.currentScript,
              context,
            );
          },
        ),
      ],
      child: child,
    );
  }
}
