import 'package:flutter/material.dart';

import 'app_icon_button.dart';

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
    return AppIconButton(
      icon: isEnabled ? Icons.code : Icons.code_off,
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
