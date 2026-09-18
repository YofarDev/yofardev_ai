import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/global_memory.dart';

/// Local storage for the global memory store (facts about the user shared
/// across all chats), persisted as a single JSON blob in SharedPreferences.
class GlobalMemoryLocalDatasource {
  static const String _memoryKey = 'global_memory';

  Future<GlobalMemory> getMemory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString(_memoryKey);
    if (json == null) return GlobalMemory.empty();
    return GlobalMemory.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveMemory(GlobalMemory memory) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoryKey, jsonEncode(memory.toMap()));
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_memoryKey);
  }
}
