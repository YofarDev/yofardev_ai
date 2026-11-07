import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/google_search_tool.dart';

void main() {
  test('a missing API key is an error and never searches', () async {
    final List<String> calls = <String>[];
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async {
        calls.add('$query|$apiKey|$engineId');
        return <Map<String, dynamic>>[];
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'engineId': 'e1'},
    );

    expect(out, 'Error: Google Search API key not configured');
    expect(calls, isEmpty);
  });

  test('a missing engine ID is an error too', () async {
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async =>
          <Map<String, dynamic>>[],
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'apiKey': 'k'},
    );

    expect(out, 'Error: Google Search Engine ID not configured');
  });

  test('forwards query, key and engine ID; returns rows toString()', () async {
    final List<String> calls = <String>[];
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async {
        calls.add('$query|$apiKey|$engineId');
        return <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Cats'},
        ];
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'apiKey': 'k', 'engineId': 'e1'},
    );

    expect(calls, <String>['cats|k|e1']);
    expect(out, contains('Cats'));
  });

  test(
    'a throwing service becomes an error string, never an exception',
    () async {
      final GoogleSearchTool tool = GoogleSearchTool(
        search: (String query, String apiKey, String engineId) async =>
            throw StateError('boom'),
      );

      final String out = await tool.execute(
        <String, dynamic>{'query': 'cats'},
        <String, dynamic>{'apiKey': 'k', 'engineId': 'e1'},
      );

      expect(out, startsWith('Error executing Google Search:'));
    },
  );
}
