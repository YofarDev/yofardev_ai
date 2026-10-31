import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../chat/chat.dart';
import 'tool_kind.dart';

/// What the avatar is doing while a reply runs a tool ([ChatState.activeTool]):
/// a glass pill with the tool's animated glyph and a short line, fading in
/// above the caption and out when the tool is done.
class StageToolChip extends StatelessWidget {
  const StageToolChip({super.key});

  static const double iconSize = 18;

  @override
  Widget build(BuildContext context) {
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.fast
        : AppMotion.base;
    return BlocSelector<ChatCubit, ChatState, String?>(
      selector: (ChatState state) => state.activeTool,
      builder: (BuildContext context, String? tool) {
        return AnimatedSwitcher(
          duration: duration,
          switchInCurve: AppMotion.standard,
          switchOutCurve: AppMotion.standard,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
          child: tool == null
              ? const SizedBox(
                  key: ValueKey<String>('no-tool'),
                  width: double.infinity,
                )
              : _Chip(key: ValueKey<String>(tool), tool: tool),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.tool});

  final String tool;

  @override
  Widget build(BuildContext context) {
    final ToolIconKind kind = toolKindFor(tool);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          liveRegion: true,
          child: AppPill(
            label: toolLabel(AppLocalizations.of(context), kind),
            // large text (M11 ruling 19): the line wraps, never cut
            maxLines: 2,
            leading: ToolIcon(
              kind: kind,
              running: true,
              size: StageToolChip.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
