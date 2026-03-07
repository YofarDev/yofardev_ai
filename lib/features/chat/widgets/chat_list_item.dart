import 'package:flutter/material.dart';

import '../domain/models/chat.dart';
import 'chat_card.dart';
import 'chat_dismissible_background.dart';

/// A single chat item in the chats list
class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.previewText,
    required this.timeLabel,
    required this.messageCount,
    required this.onTap,
    required this.onDismissed,
    required this.onDismissConfirm,
  });

  final Chat chat;
  final bool isSelected;
  final String previewText;
  final String timeLabel;
  final int messageCount;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Future<bool> Function() onDismissConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey<String>(chat.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDismissConfirm(),
        onDismissed: (_) => onDismissed(),
        background: const ChatDismissibleBackground(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: ChatCard(
              chat: chat,
              isSelected: isSelected,
              previewText: previewText,
              timeLabel: timeLabel,
              messageCount: messageCount,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
