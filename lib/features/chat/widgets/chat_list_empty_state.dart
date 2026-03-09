import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/l10n/generated/app_localizations.dart';

/// Empty state widget for the chats list
class ChatListEmptyState extends StatelessWidget {
  const ChatListEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.glassSurface.withValues(alpha: 0.1),
                AppColors.glassSurface.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: AppColors.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).empty,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to start a new conversation',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
