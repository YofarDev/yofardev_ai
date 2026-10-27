import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../chat/chat.dart';
import 'stage_menu.dart';

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
    return MenuAnchor(
      controller: _menu,
      style: stageMenuStyle,
      alignmentOffset: const Offset(0, AppSpace.sm),
      menuChildren: <Widget>[
        StageMenuPanel(
          width: StageComposerMenu.width,
          children: <Widget>[
            if (onAttach != null)
              StageMenuRow(
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
