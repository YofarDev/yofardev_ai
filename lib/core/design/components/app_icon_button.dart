import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_tokens.dart';
import 'cel_style.dart';
import 'interactive_surface.dart';

/// Icon button (glass or cel, from the tokens): a 36 dp visual inside a 48x48 hit area.
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

  /// Shows the button as toggled on (scene accent).
  final bool active;

  static const double hitSize = 48;
  static const double visualSize = 36;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme colors = context.colors;
    final Color accent = tokens.scene.accent;
    final Color glassSurface = tokens.glassSurface;
    final Color glassBorder = tokens.glassBorder;
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

        final BorderRadius radius = BorderRadius.circular(
          tokens.radius(AppRadius.md),
        );

        final BoxDecoration decoration;
        final Color iconColor;
        if (tokens.isCel) {
          final Color base = active ? accent : glassSurface;
          final Color fill = states.pressed
              ? Color.alphaBlend(tokens.shadow.withValues(alpha: 0.15), base)
              : lifted
              ? Color.alphaBlend(tokens.highlight.withValues(alpha: 0.08), base)
              : base;
          iconColor = active
              ? tokens.scene.onAccent
              : lifted
              ? accent
              : colors.onSurface;
          decoration = BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(
              color: states.focused && !active ? accent : glassBorder,
              width: tokens.outlineWidth,
            ),
            boxShadow: tokens.celShadow(pressed: states.pressed),
          );
        } else {
          final Color tint = active ? accent : glassSurface;
          iconColor = active || lifted ? accent : colors.onSurface;
          final Color borderColor = active || states.focused
              ? accent.withValues(alpha: states.focused ? 0.9 : 0.6)
              : glassBorder.withValues(alpha: borderAlpha);
          decoration = BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tint.withValues(alpha: fillTop),
                tint.withValues(alpha: fillBottom),
              ],
            ),
            borderRadius: radius,
            border: Border.all(color: borderColor, width: tokens.outlineWidth),
            boxShadow: <BoxShadow>[
              if (states.hovered || states.pressed)
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          );
        }

        final Widget visual = AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          width: visualSize,
          height: visualSize,
          decoration: decoration,
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
