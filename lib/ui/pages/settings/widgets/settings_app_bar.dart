import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../l10n/localization_manager.dart';

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
            AppColors.surface.withValues(alpha: 0.9),
            AppColors.surface.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            localized.settings,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.success.withValues(alpha: 0.2),
                  AppColors.success.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.save),
              onPressed: onSave,
              tooltip: 'Save',
            ),
          ),
        ],
      ),
    );
  }
}
