import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/news_tool.dart';

void main() {
  test('a missing key is an error and never fetches', () async {
    final List<String> keys = <String>[];
    final NewsTool tool = NewsTool(
      fetch: (String apiKey) async {
        keys.add(apiKey);
        return '[]';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{},
    );

    expect(out, 'Error: New York Times API key not configured');
    expect(keys, isEmpty);
  });

  test('an empty key is an error too', () async {
    final NewsTool tool = NewsTool(fetch: (String apiKey) async => '[]');
    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{'apiKey': ''},
    );
    expect(out, 'Error: New York Times API key not configured');
  });

  test('forwards the configured key and returns the service string', () async {
    final List<String> keys = <String>[];
    final NewsTool tool = NewsTool(
      fetch: (String apiKey) async {
        keys.add(apiKey);
        return 'headlines';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{'apiKey': 'nyt-key'},
    );

    expect(out, 'headlines');
    expect(keys, <String>['nyt-key']);
  });

  test(
    'a throwing service becomes an error string, never an exception',
    () async {
      final NewsTool tool = NewsTool(
        fetch: (String apiKey) async => throw StateError('boom'),
      );

      final String out = await tool.execute(
        <String, dynamic>{},
        <String, dynamic>{'apiKey': 'nyt-key'},
      );

      expect(out, startsWith('Error getting news:'));
    },
  );
}
