import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import 'interactive_surface.dart';

/// Glassmorphic icon button: a 36 dp visual inside a 48x48 hit area.
///
/// Pass `onPressed: null` to disable it. [semanticLabel] is always required
/// (screen readers); [tooltip] is the optional visible hover/long-press hint.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.semanticLabel,
    this.tooltip,
    this.iconSize = 20,
    this.active = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String semanticLabel;
  final String? tooltip;
  final double iconSize;

  /// Shows the button as toggled on (primary tinted).
  final bool active;

  static const double hitSize = 48;
  static const double visualSize = 36;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color glassSurface = context.tokens.glassSurface;
    final Color glassBorder = context.tokens.glassBorder;
    final bool enabled = onPressed != null;

    Widget button = InteractiveSurface(
      onTap: onPressed,
      builder: (BuildContext context, InteractiveStates states) {
        final bool lifted = states.hovered || states.focused;

        final double fillTop = states.pressed
            ? 0.3
            : lifted
            ? 0.2
            : 0.15;
        final double fillBottom = states.pressed
            ? 0.15
            : lifted
            ? 0.1
            : 0.05;
        final double borderAlpha = states.pressed
            ? 0.6
            : lifted
            ? 0.5
            : 0.3;

        final Color tint = active ? colors.primary : glassSurface;
        final Color iconColor = active || lifted
            ? colors.primary
            : colors.onSurface;
        final Color borderColor = active || states.focused
            ? colors.primary.withValues(alpha: states.focused ? 0.9 : 0.6)
            : glassBorder.withValues(alpha: borderAlpha);

        final Widget visual = AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          width: visualSize,
          height: visualSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tint.withValues(alpha: fillTop),
                tint.withValues(alpha: fillBottom),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: <BoxShadow>[
              if (states.hovered || states.pressed)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        );

        return Semantics(
          button: true,
          enabled: enabled,
          focusable: enabled,
          focused: states.focused,
          label: semanticLabel,
          onTap: onPressed,
          excludeSemantics: true,
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: Opacity(opacity: enabled ? 1 : 0.4, child: visual),
            ),
          ),
        );
      },
    );

    final String? hint = tooltip;
    if (hint != null) {
      // The label is already announced by the Semantics node above.
      button = Tooltip(
        message: hint,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}
