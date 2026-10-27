import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/route_constants.dart';
import '../../../chat/chat.dart';
import '../../../settings/settings.dart';
import '../../../talking/talking.dart';
import 'stage_menu.dart';

/// The chips on top of the Stage: History on the left, the More menu on the
/// right (new chat, language, captions, settings, demo).
///
/// [onStartDemo] plays the demo on the current chat (Home owns it).
class StageTopBar extends StatelessWidget {
  const StageTopBar({super.key, required this.onStartDemo});

  final VoidCallback onStartDemo;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: AppPill(
            label: l10n.stageHistory,
            icon: Icons.history_rounded,
            onTap: () => context.push(RouteConstants.chats),
          ),
        ),
        _MoreMenu(onStartDemo: onStartDemo),
      ],
    );
  }
}

class _MoreMenu extends StatefulWidget {
  const _MoreMenu({required this.onStartDemo});

  final VoidCallback onStartDemo;

  @override
  State<_MoreMenu> createState() => _MoreMenuState();
}

class _MoreMenuState extends State<_MoreMenu> {
  final MenuController _menu = MenuController();

  /// Closes the menu, then runs [action].
  VoidCallback _then(VoidCallback action) => () {
    _menu.close();
    action();
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String language = context.select<SettingsCubit, String>(
      (SettingsCubit cubit) => cubit.state.currentLanguage,
    );
    final bool captions = context.select<CaptionCubit, bool>(
      (CaptionCubit cubit) => cubit.state.enabled,
    );
    final String otherLanguage = language == 'fr' ? 'en' : 'fr';
    final String otherLanguageName = otherLanguage == 'fr'
        ? l10n.languageNameFrench
        : l10n.languageNameEnglish;
    return MenuAnchor(
      controller: _menu,
      style: stageMenuStyle,
      alignmentOffset: const Offset(0, AppSpace.xs),
      menuChildren: <Widget>[
        StageMenuPanel(
          children: <Widget>[
            StageMenuRow(
              icon: Icons.add_comment_outlined,
              label: l10n.newChat,
              onTap: _then(() => context.read<ChatCubit>().createNewChat()),
            ),
            StageMenuRow(
              icon: Icons.translate_rounded,
              label: otherLanguageName,
              semanticLabel: l10n.stageLanguageSwitch(otherLanguageName),
              onTap: _then(
                () => context.read<SettingsCubit>().setCurrentLanguage(
                  otherLanguage,
                ),
              ),
            ),
            StageMenuRow(
              icon: captions
                  ? Icons.subtitles_off_outlined
                  : Icons.subtitles_outlined,
              label: captions ? l10n.stageHideCaptions : l10n.stageShowCaptions,
              onTap: _then(() => context.read<CaptionCubit>().toggle()),
            ),
            StageMenuRow(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              onTap: _then(() => context.push(RouteConstants.settings)),
            ),
            StageMenuRow(
              icon: Icons.play_circle_outline_rounded,
              label: l10n.stageDemo,
              onTap: _then(widget.onStartDemo),
            ),
          ],
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              AppIconButton(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: Icons.more_horiz_rounded,
                semanticLabel: l10n.stageMenu,
                active: controller.isOpen,
              ),
    );
  }
}
