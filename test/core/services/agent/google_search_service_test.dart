import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/agent/google_search_service.dart';

class MockHttpClient extends Mock implements Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    GoogleSearchService.setTestClient(mockClient);
  });

  tearDown(() {
    GoogleSearchService.resetTestClient();
  });

  group('GoogleSearchService.searchGoogle', () {
    const String validApiKey = 'test-api-key';
    const String validEngineId = 'test-engine-id';
    const String query = 'test query';

    test('should return empty list when API key is empty', () async {
      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(query, '', validEngineId);

      expect(result, isEmpty);
    });

    test('should return empty list when engine ID is empty', () async {
      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(query, validApiKey, '');

      expect(result, isEmpty);
    });

    test(
      'should return empty list when both API key and engine ID are empty',
      () async {
        final List<Map<String, dynamic>> result =
            await GoogleSearchService.searchGoogle(query, '', '');

        expect(result, isEmpty);
      },
    );

    test('should handle empty query string', () async {
      expect(
        () => GoogleSearchService.searchGoogle('', validApiKey, validEngineId),
        returnsNormally,
      );
    });

    test('should return parsed results on success', () async {
      final Map<String, dynamic> responseBody = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'snippet': 'A snippet',
            'title': 'A title',
            'link': 'https://example.com',
          },
          <String, dynamic>{
            'snippet': 'Another snippet',
            'title': 'Another title',
            'link': 'https://example2.com',
          },
        ],
      };

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => Response(jsonEncode(responseBody), 200));

      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(
            query,
            validApiKey,
            validEngineId,
          );

      expect(result.length, 2);
      expect(result[0]['title'], 'A title');
      expect(result[0]['snippet'], 'A snippet');
      expect(result[0]['url'], 'https://example.com');
      expect(result[1]['title'], 'Another title');
    });

    test('should return empty list on HTTP error', () async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => Response('Server Error', 500));

      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(
            query,
            validApiKey,
            validEngineId,
          );

      expect(result, isEmpty);
    });

    test('should return empty list when items field is missing', () async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => Response(jsonEncode(<String, dynamic>{}), 200));

      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(
            query,
            validApiKey,
            validEngineId,
          );

      expect(result, isEmpty);
    });

    test('should handle missing snippet/title/link gracefully', () async {
      final Map<String, dynamic> responseBody = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{}, // Missing all fields
        ],
      };

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => Response(jsonEncode(responseBody), 200));

      final List<Map<String, dynamic>> result =
          await GoogleSearchService.searchGoogle(
            query,
            validApiKey,
            validEngineId,
          );

      expect(result.length, 1);
      expect(result[0]['title'], '');
      expect(result[0]['snippet'], '');
      expect(result[0]['url'], '');
    });
  });

  group('GoogleSearchService.getHtmlReduced', () {
    test('should remove script tags from HTML', () async {
      const String html =
          '<html><body><script>alert("test")</script><p>Hello</p></body></html>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, isNot(contains('<script>')));
      expect(result, isNot(contains('alert')));
      expect(result, contains('Hello'));
    });

    test('should remove style tags from HTML', () async {
      const String html =
          '<html><body><style>body { color: red; }</style><p>Hello</p></body></html>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, isNot(contains('<style>')));
      expect(result, isNot(contains('color: red')));
      expect(result, contains('Hello'));
    });

    test('should remove HTML comments', () async {
      const String html =
          '<html><body><!-- This is a comment --><p>Hello</p></body></html>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, isNot(contains('<!--')));
      expect(result, isNot(contains('This is a comment')));
      expect(result, contains('Hello'));
    });

    test('should extract text content', () async {
      const String html =
          '<html><body><h1>Title</h1><p>Paragraph</p></body></html>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, contains('Title'));
      expect(result, contains('Paragraph'));
      expect(result, isNot(contains('<h1>')));
      expect(result, isNot(contains('<p>')));
    });

    test('should handle HTML without body tag', () async {
      const String html = '<div>No body here</div>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, equals('No body here'));
    });

    test('should collapse whitespace', () async {
      const String html = '<html><body><p>Word1    Word2</p></body></html>';

      final String result = await GoogleSearchService.getHtmlReduced(html);

      expect(result, contains('Word1 Word2'));
      expect(result, isNot(contains('Word1    Word2')));
    });
  });
}
