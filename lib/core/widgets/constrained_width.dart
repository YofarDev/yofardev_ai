import 'package:flutter/material.dart';

import '../res/app_constants.dart';
import '../res/app_colors.dart';

class ConstrainedWidth extends StatelessWidget {
  final Widget child;
  const ConstrainedWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppConstants.maxWidth),
          child: child,
        ),
      ),
    );
  }
}
