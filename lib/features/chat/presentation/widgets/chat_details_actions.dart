import 'package:material_ui/material_ui.dart';

import '../../../../../core/design/components/components.dart';
import '../../../../../core/l10n/generated/app_localizations.dart';
import 'function_calling_button.dart';

class ChatDetailsActions extends StatelessWidget {
  final bool showEverything;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDownload;
  final bool isFunctionCallingEnabled;
  final VoidCallback onFunctionCallingToggle;

  const ChatDetailsActions({
    super.key,
    required this.showEverything,
    required this.onToggleVisibility,
    required this.onDownload,
    required this.isFunctionCallingEnabled,
    required this.onFunctionCallingToggle,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Positioned(
      right: 8,
      top: 8,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            AppIconButton(
              icon: showEverything ? Icons.visibility : Icons.visibility_off,
              semanticLabel: showEverything ? l10n.commonHide : l10n.commonShow,
              onPressed: onToggleVisibility,
            ),
            const SizedBox(height: 8),
            AppIconButton(
              icon: Icons.download,
              semanticLabel: l10n.chatDownloadConversation,
              onPressed: onDownload,
            ),
            const SizedBox(height: 8),
            FunctionCallingButton(
              isEnabled: isFunctionCallingEnabled,
              onToggle: onFunctionCallingToggle,
            ),
          ],
        ),
      ),
    );
  }
}
