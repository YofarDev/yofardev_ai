import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';

/// API key field button widget.
///
/// Displays a styled button that navigates to the LLM selection page
/// for configuring API keys and LLM providers.
class ApiKeyField extends StatelessWidget {
  const ApiKeyField({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text('API Picker'),
        onPressed: () {
          context.push(RouteConstants.llmSelection);
        },
      ),
    );
  }
}
