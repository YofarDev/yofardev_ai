import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/components/components.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/logger.dart';
import '../../demo/demo.dart';

/// Shows a localized toast once, when the demo mode becomes active (not on
/// every later state of an active demo).
///
/// A [BlocListener], so it can sit in a `MultiBlocListener`.
class DemoActivatedListener extends BlocListener<DemoCubit, DemoState> {
  const DemoActivatedListener({super.key, super.child})
    : super(listenWhen: _activated, listener: _onDemoActivated);

  static bool _activated(DemoState previous, DemoState current) =>
      !previous.isActive && current.isActive;

  static void _onDemoActivated(BuildContext context, DemoState state) {
    AppLogger.info('Demo activated - showing toast', tag: 'HomeScreen');
    showAppToast(context, AppLocalizations.of(context).demoModeActivated);
  }
}
