import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/logger.dart';
import '../../demo/demo.dart';

/// Shows a localized snackbar when the demo mode becomes active.
///
/// A [BlocListener], so it can sit in a `MultiBlocListener`.
class DemoActivatedListener extends BlocListener<DemoCubit, DemoState> {
  const DemoActivatedListener({super.key, super.child})
    : super(listener: _onDemoState);

  static void _onDemoState(BuildContext context, DemoState state) {
    if (!state.isActive) {
      return;
    }
    AppLogger.info('Demo activated - showing snackbar', tag: 'HomeScreen');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).demoModeActivated),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
