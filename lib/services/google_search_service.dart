// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class GoogleSearchService {
  static Future<List<Map<String, dynamic>>> searchGoogle(String query) async {
    try {
      final String apiKey = dotenv.env['GOOGLE_SEARCH_KEY'] ?? '';
      final String engineId = dotenv.env['GOOGLE_SEARCH_ENGINE_ID'] ?? '';
      if (apiKey.isEmpty || engineId.isEmpty) {
        throw Exception(
          'API Key or Engine ID is not set in environment variables',
        );
      }
      const String baseUrl = 'https://www.googleapis.com/customsearch/v1';
      final Uri uri = Uri.parse('$baseUrl?q=$query&key=$apiKey&cx=$engineId');
      final http.Response response = await http.get(uri);
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
      debugPrint('Error searching google : $e');
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
    document.body!.innerHtml =
        document.body!.innerHtml.replaceAll(RegExp(r"<!--(.|\n)*?-->"), "");
    // Extract text content, trim, and collapse whitespace
    final String textSummary =
        document.body!.text.trim().replaceAll(RegExp(r"\s+"), " ");
    return textSummary;
  }
}
