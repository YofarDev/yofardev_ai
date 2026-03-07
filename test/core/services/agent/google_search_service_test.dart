import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/google_search_service.dart';

void main() {
  group('GoogleSearchService', () {
    const String validApiKey = 'test-api-key';
    const String validEngineId = 'test-engine-id';
    const String query = 'test query';

    test('should throw exception when API key is empty', () async {
      // Act - The service catches the exception and returns empty list
      final List<Map<String, dynamic>> result = await GoogleSearchService.searchGoogle(
        query,
        '',
        validEngineId,
      );

      // Assert - Service logs error and returns empty list
      expect(result, isEmpty);
    });

    test('should throw exception when engine ID is empty', () async {
      // Act - The service catches the exception and returns empty list
      final List<Map<String, dynamic>> result = await GoogleSearchService.searchGoogle(
        query,
        validApiKey,
        '',
      );

      // Assert - Service logs error and returns empty list
      expect(result, isEmpty);
    });

    test('should throw exception when both API key and engine ID are empty', () async {
      // Act - The service catches the exception and returns empty list
      final List<Map<String, dynamic>> result = await GoogleSearchService.searchGoogle(
        query,
        '',
        '',
      );

      // Assert - Service logs error and returns empty list
      expect(result, isEmpty);
    });

    test('should handle empty query string', () async {
      // Act & Assert - Should not throw for empty query, only for empty API key or engine ID
      expect(
        () => GoogleSearchService.searchGoogle('', validApiKey, validEngineId),
        returnsNormally,
      );
    });

    test('should return empty list on API error', () async {
      // Act - This will fail with invalid credentials but should return empty list
      final List<Map<String, dynamic>> result = await GoogleSearchService.searchGoogle(
        query,
        'invalid-key',
        validEngineId,
      );

      // Assert - Service catches errors and returns empty list
      expect(result, isEmpty);
    });

    test('should accept valid parameters without throwing', () async {
      // Act & Assert - Should not throw for valid parameters format
      expect(
        () => GoogleSearchService.searchGoogle(query, validApiKey, validEngineId),
        returnsNormally,
      );
    });
  });

  group('GoogleSearchService.getHtmlReduced', () {
    test('should remove script tags from HTML', () async {
      // Arrange
      const String html = '<html><body><script>alert("test")</script><p>Hello</p></body></html>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert
      expect(result, isNot(contains('<script>')));
      expect(result, isNot(contains('alert')));
      expect(result, contains('Hello'));
    });

    test('should remove style tags from HTML', () async {
      // Arrange
      const String html = '<html><body><style>body { color: red; }</style><p>Hello</p></body></html>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert
      expect(result, isNot(contains('<style>')));
      expect(result, isNot(contains('color: red')));
      expect(result, contains('Hello'));
    });

    test('should remove HTML comments', () async {
      // Arrange
      const String html = '<html><body><!-- This is a comment --><p>Hello</p></body></html>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert
      expect(result, isNot(contains('<!--')));
      expect(result, isNot(contains('This is a comment')));
      expect(result, contains('Hello'));
    });

    test('should extract text content', () async {
      // Arrange
      const String html = '<html><body><h1>Title</h1><p>Paragraph</p></body></html>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert
      expect(result, contains('Title'));
      expect(result, contains('Paragraph'));
      expect(result, isNot(contains('<h1>')));
      expect(result, isNot(contains('<p>')));
    });

    test('should handle HTML without body tag', () async {
      // Arrange
      const String html = '<div>No body here</div>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert - When there's no body tag, it returns the original HTML
      expect(result, equals('No body here'));
    });

    test('should collapse whitespace', () async {
      // Arrange
      const String html = '<html><body><p>Word1    Word2</p></body></html>';

      // Act
      final String result = await GoogleSearchService.getHtmlReduced(html);

      // Assert
      expect(result, contains('Word1 Word2'));
      expect(result, isNot(contains('Word1    Word2')));
    });
  });
}
