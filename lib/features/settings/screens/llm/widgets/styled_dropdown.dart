import 'package:flutter/material.dart';
import '../../../../../core/models/llm_config.dart';
import '../../../../../core/res/app_colors.dart';
import '../../../../../core/l10n/generated/app_localizations.dart';

/// Custom styled dropdown for LLM configuration selection
class StyledDropdown extends StatelessWidget {
  const StyledDropdown({
    super.key,
    required this.currentValue,
    required this.availableConfigs,
    required this.onChanged,
  });

  final String? currentValue;
  final List<LlmConfig> availableConfigs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.autorenew_rounded,
                    size: 18,
                    color: AppColors.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.useDefaultLlm,
                    style: TextStyle(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ...availableConfigs.map((LlmConfig config) {
              final bool isSelected = config.id == currentValue;
              return DropdownMenuItem<String>(
                value: config.id,
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.secondary.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  padding: isSelected
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : null,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          config.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurface.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          onChanged: onChanged,
          selectedItemBuilder: (BuildContext context) {
            return <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.autorenew_rounded,
                      size: 18,
                      color: AppColors.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.useDefaultLlm,
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ...availableConfigs.map((LlmConfig config) {
                return DropdownMenuItem<String>(
                  value: config.id,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          config.label,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      ),
    );
  }
}
