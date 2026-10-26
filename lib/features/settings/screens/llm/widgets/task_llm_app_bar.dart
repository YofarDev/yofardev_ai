import 'package:flutter/material.dart';

import '../../../../../core/design/design.dart';
import '../../../../../core/l10n/generated/app_localizations.dart';

class TaskLlmAppBar extends StatelessWidget {
  final Animation<double> fadeAnimation;

  const TaskLlmAppBar({super.key, required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: fadeAnimation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - fadeAnimation.value)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: context.tokens.glassSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.tokens.glassBorder.withValues(
                          alpha: 0.5,
                        ),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: context.colors.onSurface,
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.taskLlmConfig,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
