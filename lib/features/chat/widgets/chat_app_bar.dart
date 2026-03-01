import 'package:flutter/material.dart';

import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/function_calling_button.dart';

/// Chat app bar with back and action buttons
/// Extracted from chat_details_page.dart (326 → 60 lines)
class ChatAppBar extends StatelessWidget {
  final VoidCallback onBackPressed;
  final VoidCallback onVisibilityToggle;
  final bool showEverything;

  const ChatAppBar({
    super.key,
    required this.onBackPressed,
    required this.onVisibilityToggle,
    required this.showEverything,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 8,
          top: 8,
          child: SafeArea(
            child: AppIconButton(
              icon: Icons.arrow_back_ios_new_outlined,
              onPressed: onBackPressed,
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                AppIconButton(
                  icon: showEverything
                      ? Icons.visibility
                      : Icons.visibility_off,
                  onPressed: onVisibilityToggle,
                ),
                const SizedBox(height: 8),
                const FunctionCallingButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
