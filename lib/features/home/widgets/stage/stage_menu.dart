import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/components/interactive_surface.dart';
import '../../../../core/design/design.dart';

/// The Stage menus' [MenuAnchor] style: transparent, so the
/// [StageMenuPanel] is the menu's whole look.
const MenuStyle stageMenuStyle = MenuStyle(
  backgroundColor: WidgetStatePropertyAll<Color>(Colors.transparent),
  surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
  shadowColor: WidgetStatePropertyAll<Color>(Colors.transparent),
  elevation: WidgetStatePropertyAll<double>(0),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
);

/// The thick glass sheet of a Stage menu: [children] stacked, [width] wide.
class StageMenuPanel extends StatelessWidget {
  const StageMenuPanel({
    super.key,
    required this.width,
    required this.children,
  });

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      level: AppGlassLevel.thick,
      blur: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// One tappable menu line: an icon and a label, 48 dp tall. Screen readers
/// hear [semanticLabel] when the visible label alone doesn't say what the
/// row does.
class StageMenuRow extends StatelessWidget {
  const StageMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color onSurface = context.colors.onSurface;
    return InteractiveSurface(
      onTap: onTap,
      builder: (BuildContext context, InteractiveStates states) {
        final bool lifted = states.hovered || states.focused || states.pressed;
        return Semantics(
          button: true,
          focusable: true,
          focused: states.focused,
          label: semanticLabel ?? label,
          onTap: onTap,
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            color: tokens.glassSurface.withValues(alpha: lifted ? 0.35 : 0),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: lifted ? tokens.scene.accent : onSurface,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(color: onSurface),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
