import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static String waitingSentencesKey = 'WAITING_SENTENCES';

  static Future<List<Map<String, dynamic>>?> getWaitingSentencesMap(
    String language,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? list = prefs.getString('${waitingSentencesKey}_$language');
    if (list == null) return null;
    final dynamic map = json.decode(list);
    final List<dynamic> toList = map as List<dynamic>;
    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    for (final dynamic item in toList) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      map['amplitudes'] =
          (map['amplitudes'] as List<dynamic>)
              .cast<int>();
      results.add(item);
    }
    return results;
  }

  static Future<void> setWaitingSentencesMap(
    List<Map<String, dynamic>> map,
    String language,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String toString = json.encode(map);
    prefs.setString('${waitingSentencesKey}_$language', toString);
  }

  static Future<void> clearWaitingSentencesMap(String language) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('${waitingSentencesKey}_$language');
  }
}
