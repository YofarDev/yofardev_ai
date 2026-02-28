import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/avatar/bloc/avatar_cubit.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
import '../../../features/chat/bloc/chats_cubit.dart';
import '../../../core/models/avatar_config.dart';
import '../../../models/chat.dart';
import '../../../ui/pages/chat/image_full_screen.dart';
import '../../../ui/widgets/ai_text_input.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/message_list.dart';

/// Chat details screen - simplified coordinator
/// Reduced from 326 → 131 lines (60% reduction)
class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({super.key});

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _showEverything = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AvatarCubit, AvatarState>(
      listenWhen: (AvatarState previous, AvatarState current) =>
          previous.avatarConfig != current.avatarConfig,
      listener: (BuildContext context, AvatarState state) {
        context.read<AvatarCubit>().onNewAvatarConfig(
          context.read<ChatsCubit>().state.openedChat.id,
          state.avatarConfig,
        );
      },
      child: BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState avatarState) {
          return BlocBuilder<ChatsCubit, ChatsState>(
            builder: (BuildContext context, ChatsState state) {
              final Chat chat = state.openedChat;
              return Scaffold(
                body: Stack(
                  children: <Widget>[
                    _BackgroundImage(avatar: chat.avatar),
                    _ChatContent(
                      chat: chat,
                      isTyping: state.status == ChatsStatus.typing,
                      showEverything: _showEverything,
                    ),
                    ChatAppBar(
                      onBackPressed: () => Navigator.of(context).pop(),
                      onVisibilityToggle: () {
                        setState(() {
                          _showEverything = !_showEverything;
                        });
                      },
                      showEverything: _showEverything,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final Avatar avatar;

  const _BackgroundImage({required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.3,
        child: Image.asset(avatar.background.getPath(), fit: BoxFit.cover),
      ),
    );
  }
}

class _ChatContent extends StatelessWidget {
  final Chat chat;
  final bool isTyping;
  final bool showEverything;

  const _ChatContent({
    required this.chat,
    required this.isTyping,
    required this.showEverything,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: MessageList(
              entries: chat.entries.reversed.toList(),
              persona: chat.persona,
              isTyping: isTyping,
              showEverything: showEverything,
              onImageTap: (String path) {
                Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (BuildContext context) =>
                        ImageFullScreen(imagePath: path),
                  ),
                );
              },
            ),
          ),
          const AiTextInput(onlyText: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
