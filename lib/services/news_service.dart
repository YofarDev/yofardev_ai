import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NewsService {
  static const String _baseUrl =
      'https://api.nytimes.com/svc/mostpopular/v2/shared/1.json';

  static Future<String> getMostPopularNewsOfTheDay() async {
    try {
      final String apiKey = dotenv.env['NEWYORKTIMES_KEY'] ?? '';
      final Uri url = Uri.parse(
        "$_baseUrl?api-key=$apiKey",
      );
      final http.Response response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final List<dynamic> results = (data as Map<String, dynamic>)['results'] as List<dynamic>;
        final List<Map<String, dynamic>> news = <Map<String, dynamic>>[];
        for (final dynamic result in results) {
          final String title =
              (result as Map<String, dynamic>)['title'] as String? ?? '';
          final String subtitle = result['abstract'] as String? ?? '';
          news.add(<String, dynamic>{'title': title, 'subtitle': subtitle});
        }
        return jsonEncode(news);
      } else {
        return "Error fetching weather data: ${response.statusCode}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
