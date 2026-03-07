import 'package:flutter/material.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class SoundEffectsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SoundEffectsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.warning.withValues(alpha: 0.2),
                      AppColors.warning.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volume_up_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).enableSoundEffects ??
                    'Enable Sound Effects',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            inactiveThumbColor: AppColors.onSurface.withValues(alpha: 0.5),
            inactiveTrackColor: AppColors.onSurface.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}
