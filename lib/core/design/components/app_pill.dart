import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_tokens.dart';
import 'cel_style.dart';
import 'interactive_surface.dart';

/// A compact rounded label (filter chip / tag), optionally with an icon.
///
/// The pill itself is 36 dp tall; the tappable area is at least 48 dp tall.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  static const double height = 36;
  static const double hitHeight = 48;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme colors = context.colors;
    final Color accent = tokens.scene.accent;
    final Color glassSurface = tokens.glassSurface;
    final Color glassBorder = tokens.glassBorder;
    final bool enabled = onTap != null;

    return InteractiveSurface(
      onTap: onTap,
      builder: (BuildContext context, InteractiveStates states) {
        final bool lifted = states.hovered || states.focused;

        final Color fill;
        final Color border;
        final Color foreground;
        if (tokens.isCel) {
          final Color base = selected ? accent : glassSurface;
          fill = tokens.celFill(base, states);
          border = tokens.celBorder(states, filled: selected);
          foreground = selected ? tokens.scene.onAccent : colors.onSurface;
        } else {
          fill = selected
              ? accent.withValues(alpha: states.pressed ? 0.3 : 0.2)
              : glassSurface.withValues(
                  alpha: states.pressed
                      ? 0.5
                      : lifted
                      ? 0.35
                      : 0.2,
                );
          border = selected
              ? accent.withValues(alpha: lifted || states.pressed ? 0.9 : 0.7)
              : states.focused
              ? accent.withValues(alpha: 0.9)
              : glassBorder.withValues(
                  alpha: states.pressed
                      ? 0.8
                      : lifted
                      ? 0.6
                      : 0.4,
                );
          foreground = selected ? accent : colors.onSurface;
        }

        final Widget text = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelLarge?.copyWith(color: foreground),
        );

        final Widget content = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Flexible needs a bounded main axis (an unbounded Row would
            // throw).
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: AppSpace.xs),
                ],
                if (constraints.hasBoundedWidth)
                  Flexible(child: text)
                else
                  text,
              ],
            );
          },
        );

        final Widget pill = AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.radius(AppRadius.pill)),
            border: Border.all(color: border, width: tokens.outlineWidth),
            boxShadow: tokens.isCel
                ? tokens.celShadow(pressed: states.pressed)
                : null,
          ),
          child: content,
        );

        return Semantics(
          button: enabled,
          selected: selected,
          enabled: enabled,
          focusable: enabled,
          focused: states.focused,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: hitHeight),
            child: Center(widthFactor: 1, heightFactor: 1, child: pill),
          ),
        );
      },
    );
  }
}
