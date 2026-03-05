import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/function_calling_button.dart';

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
    return Positioned(
      right: 8,
      top: 8,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            AppIconButton(
              icon: showEverything ? Icons.visibility : Icons.visibility_off,
              onPressed: onToggleVisibility,
            ),
            const SizedBox(height: 8),
            AppIconButton(icon: Icons.download, onPressed: onDownload),
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
