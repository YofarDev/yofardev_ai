import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../res/app_colors.dart';

/// Modern glassmorphic chat message bubble with gradient accents
class ModernChatBubble extends StatelessWidget {
  const ModernChatBubble({
    required this.child,
    required this.isUser,
    super.key,
    this.showAvatar = false,
    this.avatar,
    this.onAvatarTap,
    this.timestamp,
    this.padding,
  });

  final Widget child;
  final bool isUser;
  final bool showAvatar;
  final Widget? avatar;
  final VoidCallback? onAvatarTap;
  final String? timestamp;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (!isUser && showAvatar && avatar != null) ...<Widget>[
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(child: avatar!),
            ),
          ),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    padding ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isUser ? Alignment.topRight : Alignment.topLeft,
                    end: isUser ? Alignment.bottomLeft : Alignment.bottomRight,
                    colors: isUser
                        ? <Color>[
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.85),
                          ]
                        : <Color>[
                            AppColors.glassSurface.withValues(alpha: 0.15),
                            AppColors.glassSurface.withValues(alpha: 0.08),
                          ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.glassBorder.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isUser ? AppColors.primary : AppColors.surface)
                          .withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: child,
                  ),
                ),
              ),
              if (timestamp != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    timestamp!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
