// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter/material.dart';

class FunctionCallingWidget extends StatelessWidget {
  final String functionCallingText;
  const FunctionCallingWidget({
    super.key,
    required this.functionCallingText,
  });

  @override
  Widget build(BuildContext context) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                bf.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
