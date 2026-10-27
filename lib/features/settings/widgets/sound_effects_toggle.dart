import 'package:flutter/material.dart';
import '../../../core/design/design.dart';
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
            context.tokens.glassSurface.withValues(alpha: 0.12),
            context.tokens.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.tokens.glassBorder.withValues(alpha: 0.4),
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
                      context.tokens.warning.withValues(alpha: 0.2),
                      context.tokens.warning.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.volume_up_outlined,
                  color: context.tokens.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).enableSoundEffects,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.colors.primary,
            activeTrackColor: context.colors.primary.withValues(alpha: 0.5),
            inactiveThumbColor: context.colors.onSurface.withValues(alpha: 0.5),
            inactiveTrackColor: context.colors.onSurface.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}
