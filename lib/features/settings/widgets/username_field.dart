import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/design/design.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class UsernameField extends StatelessWidget {
  final TextEditingController controller;

  const UsernameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.colors.onSurface),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).username,
              hintStyle: TextStyle(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
