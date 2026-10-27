import 'package:flutter/material.dart';
import '../../../core/design/design.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class SettingsAppBar extends StatelessWidget {
  final VoidCallback onSave;

  const SettingsAppBar({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            context.colors.surface.withValues(alpha: 0.9),
            context.colors.surface.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: context.tokens.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: AppLocalizations.of(context).commonBack,
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
          Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context).settings,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  context.tokens.success.withValues(alpha: 0.2),
                  context.tokens.success.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.tokens.success.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.save),
              onPressed: onSave,
              tooltip: AppLocalizations.of(context).commonSave,
            ),
          ),
        ],
      ),
    );
  }
}
