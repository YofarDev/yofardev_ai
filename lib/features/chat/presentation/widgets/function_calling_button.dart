import 'package:material_ui/material_ui.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/l10n/generated/app_localizations.dart';

class FunctionCallingButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const FunctionCallingButton({
    required this.isEnabled,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppIconButton(
      icon: isEnabled ? Icons.code : Icons.code_off,
      semanticLabel: l10n.functionCallingToggle,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEnabled ? 'Function calling OFF' : 'Function calling ON',
            ),
            duration: const Duration(milliseconds: 500),
          ),
        );
        onToggle();
      },
    );
  }
}
