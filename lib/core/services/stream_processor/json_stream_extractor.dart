import 'dart:convert';
import '../../../../core/utils/logger.dart';

/// Extracts JSON from streaming chunks
class JsonStreamExtractor {
  final StringBuffer _buffer = StringBuffer();

  /// Process a chunk and attempt to extract JSON content
  ///
  /// Returns the text content if valid JSON is found, null otherwise
  String? extractText(String chunk, {bool expectJson = true}) {
    if (!expectJson) {
      return chunk;
    }

    _buffer.write(chunk);
    final String content = _buffer.toString();

    try {
      // Try to find JSON boundaries
      final int start = content.indexOf('{');
      final int end = content.lastIndexOf('}');

      if (start != -1 && end != -1 && end > start) {
        final String jsonStr = content.substring(start, end + 1);

        try {
          final Map<String, dynamic> decodedJson =
              json.decode(jsonStr) as Map<String, dynamic>;

          // Clear buffer up to the end of this JSON
          _buffer.clear();
          _buffer.write(content.substring(end + 1));

          // Extract common field names
          final String? text =
              decodedJson['text'] as String? ??
              decodedJson['content'] as String? ??
              decodedJson['message'] as String? ??
              decodedJson['response'] as String?;

          if (text != null) {
            return text;
          }
        } on FormatException {
          // JSON not complete yet
          AppLogger.debug(
            'Incomplete JSON, continuing to buffer',
            tag: 'JsonStreamExtractor',
          );
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Error extracting JSON from chunk: $e',
        tag: 'JsonStreamExtractor',
      );
    }

    return null;
  }

  /// Get any remaining buffered content (for cleanup)
  String getBufferedContent() {
    return _buffer.toString();
  }

  /// Clear the buffer
  void clear() {
    _buffer.clear();
  }

  /// Check if buffer contains content that might be partial JSON
  bool get hasBufferedContent => _buffer.isNotEmpty;
}
