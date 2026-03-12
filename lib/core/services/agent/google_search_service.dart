// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../utils/logger.dart';

class GoogleSearchService {
  static http.Client _client = http.Client();

  /// Set a test HTTP client (for use in tests).
  static void setTestClient(http.Client client) => _client = client;

  /// Reset to default HTTP client.
  static void resetTestClient() => _client = http.Client();

  static Future<List<Map<String, dynamic>>> searchGoogle(
    String query,
    String apiKey,
    String engineId,
  ) async {
    try {
      if (apiKey.isEmpty || engineId.isEmpty) {
        throw Exception('API Key or Engine ID is not provided');
      }
      const String baseUrl = 'https://www.googleapis.com/customsearch/v1';
      final Uri uri = Uri.parse('$baseUrl?q=$query&key=$apiKey&cx=$engineId');
      final http.Response response = await _client.get(uri);
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
        for (final dynamic result in json['items'] as List<dynamic>) {
          results.add(<String, dynamic>{
            'snippet': result['snippet'] as String? ?? '',
            'title': result['title'] as String? ?? '',
            'url': result['link'] as String? ?? '',
          });
        }
        return results;
      } else {
        throw Exception(
          'Failed to load search results: ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.debug('Error searching google : $e', tag: 'GoogleSearch');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<String> getHtmlReduced(String html) async {
    final Document document = html_parser.parse(html);
    // Remove <script> and <style> tags
    document
        .querySelectorAll('script, style')
        // ignore: always_specify_types
        .forEach((element) => element.remove());
    if (document.body == null) return html;
    // Remove comments
    document.body!.innerHtml = document.body!.innerHtml.replaceAll(
      RegExp(r"<!--(.|\n)*?-->"),
      "",
    );
    // Extract text content, trim, and collapse whitespace
    final String textSummary = document.body!.text.trim().replaceAll(
      RegExp(r"\s+"),
      " ",
    );
    return textSummary;
  }
}
