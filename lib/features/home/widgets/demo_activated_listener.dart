import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/logger.dart';
import '../../demo/demo.dart';

/// Shows a localized snackbar when the demo mode becomes active.
class DemoActivatedListener extends StatelessWidget {
  const DemoActivatedListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DemoCubit, DemoState>(
      listener: (BuildContext context, DemoState state) {
        if (state.isActive) {
          AppLogger.info(
            'Demo activated - showing snackbar',
            tag: 'HomeScreen',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).demoModeActivated),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: child,
    );
  }
}
