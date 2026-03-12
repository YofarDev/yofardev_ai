import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/models/chat.dart';

/// Card widget displaying chat information
class ChatCard extends StatelessWidget {
  const ChatCard({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.previewText,
    required this.timeLabel,
    required this.messageCount,
    required this.onTap,
  });

  final Chat chat;
  final bool isSelected;
  final String previewText;
  final String timeLabel;
  final int messageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                _IndicatorDot(isSelected: isSelected),
                const SizedBox(width: 14),
                Expanded(
                  child: _ChatPreview(
                    previewText: previewText,
                    timeLabel: timeLabel,
                    messageCount: messageCount,
                    isSelected: isSelected,
                  ),
                ),
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
}

class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
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
}

class _ChatPreview extends StatelessWidget {
  const _ChatPreview({
    required this.previewText,
    required this.timeLabel,
    required this.messageCount,
    required this.isSelected,
  });

  final String previewText;
  final String timeLabel;
  final int messageCount;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
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
