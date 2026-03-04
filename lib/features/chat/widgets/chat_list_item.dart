import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';
import '../domain/models/chat.dart';

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
      child: _buildDismissibleChatTile(context),
    );
  }

  Widget _buildDismissibleChatTile(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>(chat.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDismissConfirm(),
      onDismissed: (_) => onDismissed(),
      background: _buildDismissableBackground(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: _buildChatCard(context),
        ),
      ),
    );
  }

  Widget _buildDismissableBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Delete',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
        ],
      ),
    );
  }

  Widget _buildChatCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: isSelected ? 0.2 : 0.12),
            AppColors.glassSurface.withValues(alpha: isSelected ? 0.1 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.glassBorder.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            blurRadius: isSelected ? 16 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                _buildIndicatorDot(),
                const SizedBox(width: 14),
                Expanded(child: _buildChatPreview(context)),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurface.withValues(alpha: 0.2),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorDot() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected
            ? const LinearGradient(
                colors: <Color>[AppColors.primary, AppColors.secondary],
              )
            : null,
        color: isSelected ? null : AppColors.onSurface.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildChatPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          previewText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Text(
              '$messageCount messages',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.45),
              ),
            ),
            if (timeLabel.isNotEmpty) ...<Widget>[
              Text(
                ' · ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.3),
                ),
              ),
              Text(
                timeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
