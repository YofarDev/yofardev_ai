import 'dart:convert';
import '../../../../core/utils/logger.dart';

/// Extracts JSON from streaming chunks
class JsonStreamExtractor {
  static const List<String> _textKeys = <String>[
    'text',
    'content',
    'message',
    'response',
  ];

  final StringBuffer _buffer = StringBuffer();
  final StringBuffer _rawBuffer = StringBuffer();
  String? _lastFullJson;
  String _lastExtractedText = '';

  /// Process a chunk and attempt to extract JSON content
  ///
  /// Returns the text content if valid JSON is found, null otherwise
  String? extractText(String chunk, {bool expectJson = true}) {
    _rawBuffer.write(chunk);

    if (!expectJson) {
      return chunk;
    }

    _buffer.write(chunk);
    final String content = _buffer.toString();

    final String? completeJsonText = _tryExtractFromCompleteJson(content);
    if (completeJsonText != null) {
      return _emitDelta(completeJsonText);
    }

    final String? partialText = _extractPartialText(_rawBuffer.toString());
    if (partialText != null) {
      return _emitDelta(partialText);
    }

    return null;
  }

  String? _tryExtractFromCompleteJson(String content) {
    try {
      final int start = content.indexOf('{');
      final int end = content.lastIndexOf('}');

      if (start == -1 || end == -1 || end <= start) {
        return null;
      }

      final String jsonStr = content.substring(start, end + 1);
      final Map<String, dynamic> decodedJson =
          json.decode(jsonStr) as Map<String, dynamic>;

      _lastFullJson = jsonStr;

      // Keep any content after the parsed JSON for the next turn.
      _buffer.clear();
      _buffer.write(content.substring(end + 1));

      for (final String key in _textKeys) {
        final dynamic value = decodedJson[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    } on FormatException {
      AppLogger.debug(
        'Incomplete JSON, continuing to buffer',
        tag: 'JsonStreamExtractor',
      );
      return null;
    } catch (e) {
      AppLogger.warning(
        'Error extracting JSON from chunk: $e',
        tag: 'JsonStreamExtractor',
      );
      return null;
    }
  }

  String? _extractPartialText(String content) {
    for (final String key in _textKeys) {
      final String? value = _extractPartialStringField(content, key);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _extractPartialStringField(String content, String fieldName) {
    final int keyIndex = content.lastIndexOf('"$fieldName"');
    if (keyIndex == -1) {
      return null;
    }

    final int colonIndex = content.indexOf(':', keyIndex + fieldName.length);
    if (colonIndex == -1) {
      return null;
    }

    int cursor = colonIndex + 1;
    while (cursor < content.length &&
        (content[cursor] == ' ' ||
            content[cursor] == '\n' ||
            content[cursor] == '\r' ||
            content[cursor] == '\t')) {
      cursor++;
    }

    if (cursor >= content.length || content[cursor] != '"') {
      return null;
    }

    cursor++; // Skip opening quote.
    final StringBuffer parsedValue = StringBuffer();

    while (cursor < content.length) {
      final String char = content[cursor];

      if (char == '\\') {
        if (cursor + 1 >= content.length) {
          break;
        }

        final String escaped = content[cursor + 1];
        if (escaped == 'u') {
          if (cursor + 5 >= content.length) {
            break;
          }
          final String hex = content.substring(cursor + 2, cursor + 6);
          final int? codePoint = int.tryParse(hex, radix: 16);
          if (codePoint != null) {
            parsedValue.write(String.fromCharCode(codePoint));
          }
          cursor += 6;
          continue;
        }

        parsedValue.write(_decodeSimpleEscape(escaped));
        cursor += 2;
        continue;
      }

      if (char == '"') {
        return parsedValue.toString();
      }

      parsedValue.write(char);
      cursor++;
    }

    // Field is present but JSON is still incomplete: return the parsed prefix.
    return parsedValue.toString();
  }

  String _decodeSimpleEscape(String escaped) {
    return switch (escaped) {
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      'b' => '\b',
      'f' => '\f',
      '"' => '"',
      '\\' => '\\',
      '/' => '/',
      _ => escaped,
    };
  }

  String? _emitDelta(String candidateText) {
    if (candidateText.isEmpty) {
      return null;
    }

    if (candidateText == _lastExtractedText) {
      return null;
    }

    if (candidateText.startsWith(_lastExtractedText)) {
      final String delta = candidateText.substring(_lastExtractedText.length);
      _lastExtractedText = candidateText;
      return delta.isEmpty ? null : delta;
    }

    // Fallback when extraction context shifts: emit full candidate once.
    _lastExtractedText = candidateText;
    return candidateText;
  }

  /// Get the last complete full JSON that was extracted
  String? getLastFullJson() {
    return _lastFullJson;
  }

  /// Get the full raw content received so far
  String getRawContent() {
    return _rawBuffer.toString();
  }

  /// Clear the stored JSON
  void clearJson() {
    _lastFullJson = null;
  }

  /// Get any remaining buffered content (for cleanup)
  String getBufferedContent() {
    return _buffer.toString();
  }

  /// Clear the buffer
  void clear() {
    _buffer.clear();
    _rawBuffer.clear();
    _lastExtractedText = '';
  }

  /// Check if buffer contains content that might be partial JSON
  bool get hasBufferedContent => _buffer.isNotEmpty;
}
