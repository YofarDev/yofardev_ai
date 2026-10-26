import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Background widget shown when swiping a chat item to delete
class ChatDismissibleBackground extends StatelessWidget {
  const ChatDismissibleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Delete',
            style: TextStyle(
              color: context.colors.error,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.delete_outline_rounded,
            color: context.colors.error,
            size: 22,
          ),
        ],
      ),
    );
  }
}
