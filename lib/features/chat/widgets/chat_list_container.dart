import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../../avatar/bloc/avatar_state.dart';
import '../bloc/chats_cubit.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../l10n/localization_manager.dart';
import '../domain/models/chat.dart';
import 'chat_list_item.dart';

/// Widget that displays a list of chats with avatar state integration.
///
/// This widget encapsulates the chat list rendering logic,
/// including avatar state monitoring and item interactions.
class ChatListContainer extends StatelessWidget {
  const ChatListContainer({
    super.key,
    required this.chats,
    required this.currentChat,
  });

  final List<Chat> chats;
  final Chat currentChat;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState avatarState) {
        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (BuildContext context, int index) {
              final Chat chat = chats[index];
              final bool isSelected = chat.id == currentChat.id;

              final String previewText = _resolvePreview(chat);
              final String timeLabel = _relativeTime(
                chat.entries.isNotEmpty ? chat.entries.last.timestamp : null,
              );

              return ChatListItem(
                chat: chat,
                isSelected: isSelected,
                previewText: previewText,
                timeLabel: timeLabel,
                messageCount: chat.entries.length,
                onTap: () => _openChat(context, chat),
                onDismissed: () =>
                    context.read<ChatsCubit>().deleteChat(chat.id),
                onDismissConfirm: () => _confirmDelete(context),
              );
            },
          ),
        );
      },
    );
  }

  void _openChat(BuildContext context, Chat chat) {
    context.read<ChatsCubit>().setCurrentChat(chat);
    context.read<ChatsCubit>().setOpenedChat(chat);
    context.push('${RouteConstants.chats}/${chat.id}');
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete chat?'),
        content: const Text('This conversation will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _resolvePreview(Chat chat) {
    if (chat.entries.isEmpty) return localized.empty;
    for (int i = chat.entries.length - 1; i >= 0; i--) {
      final String body = chat.entries[i].body;
      if (body.trim().isEmpty) continue;
      try {
        final String visible = body.getVisiblePrompt();
        if (visible.trim().isNotEmpty) return visible;
      } catch (_) {
        final String raw = body.trim();
        if (raw.isNotEmpty) return raw;
      }
    }
    return localized.empty;
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
