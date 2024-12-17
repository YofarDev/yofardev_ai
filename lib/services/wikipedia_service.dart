import 'dart:convert';

import 'package:http/http.dart' as http;

class WikipediaService {
  static String _cleanString(String input) {
    // Step 1: Remove HTML tags using a regex
    final String cleaned = input.replaceAll(RegExp('<[^>]*>'), '');

    return cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&quot;', '"')
        .trim();
  }

  static Future<String> searchWikipedia(
    String query,
  ) async {
    final Uri url = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query&format=json&list=search&srsearch=$query&origin=*&srlimit=10',
    );
    final http.Response response = await http.get(url);
    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      final List<dynamic> results = ((data as Map<String, dynamic>)['query']
          as Map<String, dynamic>)['search'] as List<dynamic>;
      final List<Map<String, dynamic>> pages = <Map<String, dynamic>>[];
      for (final dynamic result in results) {
        final String title =
            (result as Map<String, dynamic>)['title'] as String? ?? '';
        final String snippet = _cleanString(result['snippet'] as String? ?? '');
        pages.add(<String, dynamic>{
          'title': title,
          'snippet': snippet,
        });
      }
      return pages.toString();
    } else {
      throw Exception('Failed to fetch Wikipedia pages');
    }
  }

  static Future<String> getWikipediaPage(String title) async {
    final Uri url = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query&titles=$title&prop=extracts&format=json',
    );
    final http.Response response = await http.get(url);
    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      final String extract =
          // ignore: avoid_dynamic_calls
          data['query']['pages'].values.first['extract'] as String? ?? '';
      return _cleanString(extract);
    } else {
      throw Exception('Failed to fetch Wikipedia page');
    }
  }
}
