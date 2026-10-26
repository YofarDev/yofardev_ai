import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
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
    final ColorScheme colors = context.colors;
    final Color glassSurface = context.tokens.glassSurface;
    final Color glassBorder = context.tokens.glassBorder;
    final bool enabled = onTap != null;

    return InteractiveSurface(
      onTap: onTap,
      builder: (BuildContext context, InteractiveStates states) {
        final bool lifted = states.hovered || states.focused;

        final Color fill = selected
            ? colors.primary.withValues(alpha: states.pressed ? 0.3 : 0.2)
            : glassSurface.withValues(
                alpha: states.pressed
                    ? 0.5
                    : lifted
                    ? 0.35
                    : 0.2,
              );
        final Color border = selected
            ? colors.primary.withValues(
                alpha: lifted || states.pressed ? 0.9 : 0.7,
              )
            : states.focused
            ? colors.primary.withValues(alpha: 0.9)
            : glassBorder.withValues(
                alpha: states.pressed
                    ? 0.8
                    : lifted
                    ? 0.6
                    : 0.4,
              );
        final Color foreground = selected ? colors.primary : colors.onSurface;

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
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: border, width: 1.5),
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
