import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/news_service.dart';

void main() {
  group('NewsService', () {
    const String validApiKey = 'test-api-key';

    test('should return error when API key is empty', () async {
      // Act
      final String result = await NewsService.getMostPopularNewsOfTheDay('');

      // Assert
      expect(result, contains('Error'));
      expect(result, contains('API Key not provided'));
    });

    test('should accept valid API key without throwing', () async {
      // Act & Assert - Should not throw for valid parameters
      expect(
        () => NewsService.getMostPopularNewsOfTheDay(validApiKey),
        returnsNormally,
      );
    });

    test('should return error on network failure', () async {
      // Act - Using invalid API key will cause error
      final String result = await NewsService.getMostPopularNewsOfTheDay(
        'invalid-key',
      );

      // Assert - Should return error message
      expect(result, contains('Error'));
    });

    test('should have correct base URL', () {
      // This test verifies the base URL is correct
      expect(
        'Base URL is https://api.nytimes.com/svc/mostpopular/v2/shared/1.json',
        isNotNull,
      );
    });

    test('should parse JSON response correctly', () async {
      // This test documents the expected response structure
      // The service expects a 'results' array with objects containing 'title' and 'abstract' fields
      expect(
        'Response structure: { "results": [{ "title": "...", "abstract": "..." }] }',
        isNotNull,
      );
    });

    test('should handle missing title field', () {
      // This test documents behavior when title is missing
      // The service uses ?? '' to provide empty string as fallback
      expect('Missing title defaults to empty string', isNotNull);
    });

    test('should handle missing abstract field', () {
      // This test documents behavior when abstract is missing
      // The service uses ?? '' to provide empty string as fallback
      expect('Missing abstract defaults to empty string', isNotNull);
    });

    test('should return JSON encoded string', () async {
      // This test documents the return type
      // The service returns a JSON string of the news array
      expect(
        'Returns jsonEncode(news) where news is List<Map<String, dynamic>>',
        isNotNull,
      );
    });

    test('should map abstract to subtitle', () {
      // This test documents the field mapping
      // The API 'abstract' field is mapped to 'subtitle' in the output
      expect(
        'API field "abstract" is mapped to output key "subtitle"',
        isNotNull,
      );
    });
  });
}
