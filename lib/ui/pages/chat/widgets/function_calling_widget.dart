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
      final List<String> keys = ((map[i] as Map<String, dynamic>)["parameters"]
              as Map<String, dynamic>)
          .keys
          .toList();
      for (final String key in keys) {
        String value =
            (map[i]["parameters"] as Map<String, dynamic>)[key].toString();
        if (value.length > 100) {
          value = '${value.substring(0, 100)}[...]';
        }
        (map[i]["parameters"] as Map<String, dynamic>)[key] = value;
      }
      final String parameters = jsonEncode(map[i]["parameters"]);
      bf.write(
        '➡️ ${(map[i] as Map<String, dynamic>)["name"]}($parameters)${i == map.length - 1 ? '' : '\n'}',
      );
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
