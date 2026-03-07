import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/chat.dart';

class PersonaDropdown extends StatelessWidget {
  final ChatPersona value;
  final ValueChanged<ChatPersona> onChanged;

  const PersonaDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppLocalizations.of(context).personaAssistant,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ChatPersona>(
                    value: value,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.onSurface),
                    items: ChatPersona.values
                        .map<DropdownMenuItem<ChatPersona>>((
                          ChatPersona personaValue,
                        ) {
                          return DropdownMenuItem<ChatPersona>(
                            value: personaValue,
                            child: Text(
                              personaValue.name.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (ChatPersona? newValue) {
                      if (newValue != null) onChanged(newValue);
                    },
                    iconEnabledColor: AppColors.onSurface.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
