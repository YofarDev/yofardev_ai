import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/components/interactive_surface.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../chat/chat.dart';

/// The Stage composer's "+" button and its glass menu: attach an image
/// ([onAttach]; the row is hidden when null) and the Tools on/off switch
/// (function calling, from [ChatCubit]).
class StageComposerMenu extends StatefulWidget {
  const StageComposerMenu({super.key, required this.onAttach});

  final VoidCallback? onAttach;

  static const double width = 248;

  @override
  State<StageComposerMenu> createState() => _StageComposerMenuState();
}

class _StageComposerMenuState extends State<StageComposerMenu> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VoidCallback? onAttach = widget.onAttach;
    const WidgetStateProperty<Color> clear = WidgetStatePropertyAll<Color>(
      Colors.transparent,
    );
    return MenuAnchor(
      controller: _menu,
      // The glass panel below is the menu's whole look.
      style: const MenuStyle(
        backgroundColor: clear,
        surfaceTintColor: clear,
        shadowColor: clear,
        elevation: WidgetStatePropertyAll<double>(0),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
      ),
      alignmentOffset: const Offset(0, AppSpace.sm),
      menuChildren: <Widget>[
        GlassPanel(
          level: AppGlassLevel.thick,
          blur: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: SizedBox(
            width: StageComposerMenu.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (onAttach != null)
                  _MenuRow(
                    icon: Icons.image_outlined,
                    label: l10n.composerAttach,
                    onTap: () {
                      _menu.close();
                      onAttach();
                    },
                  ),
                const _ToolsRow(),
              ],
            ),
          ),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              AppIconButton(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: Icons.add_rounded,
                semanticLabel: l10n.composerMore,
                active: controller.isOpen,
              ),
    );
  }
}

/// One tappable menu line: an icon and a label, 48 dp tall.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
          label: label,
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

/// "Tools" with its switch, bound to the chat's function calling.
class _ToolsRow extends StatelessWidget {
  const _ToolsRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color onSurface = context.colors.onSurface;
    final bool enabled = context.select<ChatCubit, bool>(
      (ChatCubit cubit) => cubit.state.functionCallingEnabled,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpace.lg,
        end: AppSpace.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.handyman_outlined, size: 20, color: onSurface),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                l10n.composerTools,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(color: onSurface),
              ),
            ),
          ),
          RiveToggle(
            value: enabled,
            onChanged: (_) => context.read<ChatCubit>().toggleFunctionCalling(),
            semanticLabel: l10n.composerTools,
          ),
        ],
      ),
    );
  }
}
