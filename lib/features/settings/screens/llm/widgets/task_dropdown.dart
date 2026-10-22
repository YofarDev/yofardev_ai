import 'package:flutter/material.dart';
import '../../../../../core/models/llm_config.dart';
import '../../../../../core/res/app_colors.dart';
import 'styled_dropdown.dart';

/// Dropdown widget for selecting LLM configuration for a specific task
class TaskDropdown extends StatelessWidget {
  const TaskDropdown({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.currentId,
    required this.availableConfigs,
    required this.onChanged,
    required this.delay,
  });

  final String label;
  final String description;
  final IconData icon;
  final String? currentId;
  final List<LlmConfig> availableConfigs;
  final ValueChanged<String?> onChanged;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.glassSurface.withValues(alpha: 0.16),
                    AppColors.glassSurface.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.surface.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.secondary.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StyledDropdown(
                    currentValue: currentId,
                    availableConfigs: availableConfigs,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
