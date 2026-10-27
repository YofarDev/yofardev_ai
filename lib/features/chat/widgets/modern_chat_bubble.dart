import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/design/design.dart';

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
    this.isStreaming = false,
  });

  final Widget child;
  final bool isUser;
  final bool showAvatar;
  final Widget? avatar;
  final VoidCallback? onAvatarTap;
  final String? timestamp;
  final EdgeInsetsGeometry? padding;
  final bool isStreaming;

  // Fix #7: Extract shared BorderRadius to avoid duplication
  BorderRadius get _bubbleRadius => BorderRadius.only(
    topLeft: const Radius.circular(20),
    topRight: const Radius.circular(20),
    bottomLeft: Radius.circular(isUser ? 16 : 4),
    bottomRight: Radius.circular(isUser ? 4 : 16),
  );

  @override
  Widget build(BuildContext context) {
    // The bubble owns its foreground: on the accent fill (user) only
    // onPrimary is legible, so callers' unstyled text and icons follow it.
    final Color foreground = isUser
        ? context.colors.onPrimary
        : context.colors.onSurface;
    final Widget content = IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: child,
      ),
    );
    return LayoutBuilder(
      // Fix #9: Use LayoutBuilder instead of MediaQuery for max-width constraint
      builder: (BuildContext context, BoxConstraints constraints) {
        return Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!isUser && showAvatar && avatar != null) ...<Widget>[
              // Fix #10: Add semanticsLabel for accessibility
              Semantics(
                label: AppLocalizations.of(context).aiAssistantAvatar,
                button: onAvatarTap != null,
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    // Fix #3: Slightly smaller avatar with tighter margin
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: context.colors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(child: avatar!),
                  ),
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
                      // Fix #9: Use LayoutBuilder constraints instead of MediaQuery
                      maxWidth: constraints.maxWidth * 0.75,
                    ),
                    padding:
                        padding ??
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: isUser ? Alignment.topRight : Alignment.topLeft,
                        end: isUser
                            ? Alignment.bottomLeft
                            : Alignment.bottomRight,
                        colors: isUser
                            ? <Color>[
                                // Fix #1: Slightly desaturated blue — less harsh than pure cyan
                                context.colors.primary,
                                context.colors.primary.withValues(alpha: 0.88),
                              ]
                            : <Color>[
                                // Fix #2: Slightly more opaque for better contrast against dark bg
                                context.tokens.glassSurface.withValues(
                                  alpha: 0.22,
                                ),
                                context.tokens.glassSurface.withValues(
                                  alpha: 0.12,
                                ),
                              ],
                      ),
                      // Fix #7: Use shared _bubbleRadius
                      borderRadius: _bubbleRadius,
                      border: Border.all(
                        color: isUser
                            ? context.colors.primary.withValues(alpha: 0.5)
                            // Fix #2: Slightly stronger border on AI bubble for definition
                            : context.tokens.glassBorder.withValues(
                                alpha: 0.55,
                              ),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              (isUser
                                      ? context.colors.primary
                                      : context.colors.surface)
                                  .withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // Fix #8: Only apply BackdropFilter for AI bubbles — wasteful on solid user bubble
                    child: isUser
                        ? ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: content,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: content,
                            ),
                          ),
                  ),
                  if (timestamp != null)
                    Padding(
                      // Fix #4: More vertical breathing room under the bubble
                      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                      child: Text(
                        timestamp!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
