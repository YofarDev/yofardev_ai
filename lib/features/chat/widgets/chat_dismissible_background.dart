import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';

/// Background widget shown when swiping a chat item to delete
class ChatDismissibleBackground extends StatelessWidget {
  const ChatDismissibleBackground({super.key});

  @override
  Widget build(BuildContext context) {
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
}
