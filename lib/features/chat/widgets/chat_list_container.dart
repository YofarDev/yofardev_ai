import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../presentation/bloc/chat_cubit.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/models/chat.dart';
import 'chat_list_item.dart';

/// Widget that displays a list of chats.
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
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chats.length,
        itemBuilder: (BuildContext context, int index) {
          final Chat chat = chats[index];
          final bool isSelected = chat.id == currentChat.id;

          final String previewText = _resolvePreview(context, chat);
          final String timeLabel = _relativeTime(
            context,
            chat.entries.isNotEmpty ? chat.entries.last.timestamp : null,
          );

          return ChatListItem(
            chat: chat,
            isSelected: isSelected,
            previewText: previewText,
            timeLabel: timeLabel,
            messageCount: chat.entries.length,
            onTap: () => _openChat(context, chat),
            onDismissed: () => context.read<ChatCubit>().deleteChat(chat.id),
            onDismissConfirm: () => _confirmDelete(context),
          );
        },
      ),
    );
  }

  void _openChat(BuildContext context, Chat chat) {
    context.read<ChatCubit>().setCurrentChat(chat);
    context.read<ChatCubit>().setOpenedChat(chat);
    context.push('${RouteConstants.chats}/${chat.id}');
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context).deleteChatTitle),
        content: Text(AppLocalizations.of(context).deleteChatConfirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _resolvePreview(BuildContext context, Chat chat) {
    if (chat.entries.isEmpty) {
      return AppLocalizations.of(context).empty;
    }

    // NEW: Use title if available and generated
    if (chat.titleGenerated && chat.title.isNotEmpty) {
      return chat.title;
    }

    // Fall back to existing preview logic
    for (int i = chat.entries.length - 1; i >= 0; i--) {
      final String body = chat.entries[i].body;
      if (body.trim().isEmpty) continue;
      try {
        final String visible = body.getVisiblePrompt();
        if (visible.trim().isNotEmpty) {
          // NEW: Truncate first message for temporary title
          return visible.length > 50
              ? '${visible.substring(0, 47)}...'
              : visible;
        }
      } catch (_) {
        final String raw = body.trim();
        if (raw.isNotEmpty) return raw;
      }
    }
    return AppLocalizations.of(context).empty;
  }

  String _relativeTime(BuildContext context, DateTime? date) {
    if (date == null) return '';
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return AppLocalizations.of(context).timeJustNow;
    if (diff.inMinutes < 60) {
      return AppLocalizations.of(context).timeMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return AppLocalizations.of(context).timeHoursAgo(diff.inHours);
    }
    if (diff.inDays == 1) return AppLocalizations.of(context).timeYesterday;
    if (diff.inDays < 7) {
      return AppLocalizations.of(context).timeDaysAgo(diff.inDays);
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
