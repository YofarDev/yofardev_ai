import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/failure_localization.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/failure.dart';
import '../../domain/models/{{FEATURE_SNAKE}}.dart';
import '../bloc/{{FEATURE_SNAKE}}_cubit.dart';
import '../bloc/{{FEATURE_SNAKE}}_state.dart';

/// Single-widget screen — it renders one load lifecycle and has no distinct
/// sub-responsibility, so there is no separate View widget to forward to.
class {{FEATURE_PASCAL}}Screen extends StatelessWidget {
  const {{FEATURE_PASCAL}}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.{{L10N_TITLE_KEY}})),
      body: BlocBuilder<{{FEATURE_PASCAL}}Cubit, {{FEATURE_PASCAL}}State>(
        builder: (BuildContext context, {{FEATURE_PASCAL}}State state) {
          return state.when(
            initial: () => const Center(child: CircularProgressIndicator()),
            loading: () => const Center(child: CircularProgressIndicator()),
            loaded: ({{FEATURE_PASCAL}} data) =>
                Center(child: Text(l10n.{{L10N_DATA_KEY}}(data.name))),
            // Localized at build time from the failure category; diagnostics
            // carried by the failure are never displayed.
            error: (Failure failure) => Center(
              child: Text(localizeFailure(AppLocalizations.of(context), failure)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<{{FEATURE_PASCAL}}Cubit>().loadData(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
