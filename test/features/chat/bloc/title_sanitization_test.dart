import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Title Sanitization', () {
    String sanitizeTitle(String title) {
      // Copy of the implementation for testing
      String sanitized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
      sanitized = sanitized.replaceAll(RegExp(r'''^["']|["']$'''), '');
      if (sanitized.length > 50) {
        sanitized = '${sanitized.substring(0, 47)}...';
      }
      return sanitized;
    }

    test('removes excessive whitespace', () {
      expect(sanitizeTitle('Hello    World'), 'Hello World');
    });

    test('removes leading and trailing quotes', () {
      expect(sanitizeTitle('"Weather Today"'), 'Weather Today');
      expect(sanitizeTitle("'Weather Today'"), 'Weather Today');
    });

    test('truncates long titles', () {
      const String longTitle =
          'This is a very long title that exceeds the maximum length allowed for chat titles in the application';
      final String result = sanitizeTitle(longTitle);
      expect(result.length, lessThanOrEqualTo(50));
      expect(result, endsWith('...'));
    });

    test('handles empty string', () {
      expect(sanitizeTitle(''), '');
    });

    test('handles string with only whitespace', () {
      expect(sanitizeTitle('     '), '');
    });
  });
}
