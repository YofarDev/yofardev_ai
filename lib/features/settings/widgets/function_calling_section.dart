import 'package:flutter/material.dart';

/// A reusable section widget for function calling configuration
class FunctionCallingSection extends StatelessWidget {
  const FunctionCallingSection({
    super.key,
    required this.title,
    required this.apiName,
    required this.icon,
    required this.fields,
    this.isEnabled,
    this.onToggle,
  });

  final String title;
  final String apiName;
  final String icon;
  final List<Widget> fields;
  final bool? isEnabled;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        apiName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEnabled != null && onToggle != null)
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: isEnabled!,
                      onChanged: onToggle,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            if (fields.isNotEmpty) const SizedBox(height: 12),
            ...fields,
          ],
        ),
      ),
    );
  }
}
