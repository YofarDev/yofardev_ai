// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter/material.dart';

class FunctionCallingWidget extends StatelessWidget {
  final String functionCallingText;
  final bool showEverything;
  const FunctionCallingWidget({
    super.key,
    required this.functionCallingText,
    this.showEverything = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final StringBuffer bf = StringBuffer();
    final List<dynamic> map = jsonDecode(functionCallingText) as List<dynamic>;
    for (int i = 0; i < map.length; i++) {
      if (i > 0) bf.write('\n');
      bf.write('➡️ ${map[i]["name"]}(');
      final Map<String, dynamic> mapParameters =
          map[i]["parameters"] as Map<String, dynamic>;
      final List<String> keys = mapParameters.keys.toList();
      for (final String key in keys) {
        bf.write('"$key": "${mapParameters[key]}"');
      }
      bf.write(')');
    }

    // Check if we have results to show
    final bool hasResults = map.any(
      (dynamic item) =>
          (item as Map<String, dynamic>).containsKey('result') &&
          item['result'] != null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    bf.toString(),
                    style: TextStyle(
                      color: colorScheme.surface,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showEverything && hasResults)
            ...buildResultSections(map, colorScheme),
        ],
      ),
    );
  }

  List<Widget> buildResultSections(List<dynamic> map, ColorScheme colorScheme) {
    final List<Widget> widgets = <Widget>[];

    for (final dynamic item in map) {
      final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
      final dynamic result = itemMap['result'];

      if (result == null) continue;

      final String functionName = itemMap['name'] as String;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 8,
              ),
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
              collapsedBackgroundColor: colorScheme.onSurface.withValues(
                alpha: 0.1,
              ),
              title: Text(
                'Result: ${_capitalize(functionName)}',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              iconColor: colorScheme.onSurface,
              collapsedIconColor: colorScheme.onSurface,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatResult(result),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  String _formatResult(dynamic result) {
    if (result is Map || result is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(result);
      } catch (_) {
        return result.toString();
      }
    }
    return result.toString();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
