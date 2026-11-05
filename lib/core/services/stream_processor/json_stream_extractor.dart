import 'dart:convert';

/// Incrementally extracts a root reply text field, never nested metadata.
///
/// Each character is scanned once. Keys, escapes and structure can cross any
/// chunk boundary. One instance handles one reply; call [clear] before reuse.
class JsonStreamExtractor {
  static const List<String> _textKeys = <String>[
    'text',
    'content',
    'message',
    'response',
  ];

  final StringBuffer _rawBuffer = StringBuffer();
  final StringBuffer _key = StringBuffer();
  int _depth = 0;
  int _rootStart = -1;
  bool _done = false;
  bool _inString = false;
  bool _readingKey = false;
  bool _expectKey = false;
  bool _expectColon = false;
  bool _expectValue = false;
  bool _capturing = false;
  bool _captureDone = false;
  bool _escaped = false;
  String? _unicode;
  String? _lastFullJson;

  /// Returns only newly decoded speech. Null means no new speech, including
  /// chunks containing just JSON punctuation or avatar settings.
  String? extractText(String chunk, {bool expectJson = true}) {
    final int offset = _rawBuffer.length;
    _rawBuffer.write(chunk);
    if (!expectJson) {
      return chunk;
    }
    final StringBuffer output = StringBuffer();
    for (int i = 0; i < chunk.length; i++) {
      final String char = chunk[i];
      if (_done) {
        break;
      }
      if (_inString) {
        if (_unicode != null) {
          _unicode = '${_unicode!}$char';
          if (_unicode!.length == 4) {
            final int? code = int.tryParse(_unicode!, radix: 16);
            if (code != null) {
              _writeStringChar(String.fromCharCode(code), output);
            }
            _unicode = null;
          }
        } else if (_escaped) {
          _escaped = false;
          if (char == 'u') {
            _unicode = '';
          } else {
            _writeStringChar(_decodeSimpleEscape(char), output);
          }
        } else if (char == r'\') {
          _escaped = true;
        } else if (char == '"') {
          _inString = false;
          if (_readingKey) {
            _readingKey = false;
            _expectColon = true;
          }
          if (_capturing) {
            _capturing = false;
            _captureDone = true;
          }
        } else {
          _writeStringChar(char, output);
        }
        continue;
      }

      if (_rootStart < 0) {
        // Allow surrounding Markdown fences, but never speak the wrapper.
        if (char == '{') {
          _rootStart = offset + i;
          _depth = 1;
          _expectKey = true;
        }
        continue;
      }
      if (char.trim().isEmpty) {
        continue;
      }
      if (char == '"') {
        _inString = true;
        _readingKey = _depth == 1 && _expectKey;
        if (_readingKey) {
          _key.clear();
          _expectKey = false;
        } else {
          _capturing =
              _depth == 1 &&
              _expectValue &&
              !_captureDone &&
              _textKeys.contains(_key.toString());
          _expectValue = false;
        }
      } else if (char == ':' && _depth == 1 && _expectColon) {
        _expectColon = false;
        _expectValue = true;
      } else if (char == '{' || char == '[') {
        _expectValue = false;
        _depth++;
      } else if (char == '}' || char == ']') {
        _depth--;
        if (_depth == 0) {
          _done = true;
          final String json = _rawBuffer.toString().substring(
            _rootStart,
            offset + i + 1,
          );
          try {
            if (jsonDecode(json) is Map<String, dynamic>) {
              _lastFullJson = json;
            }
          } on FormatException {
            // An incomplete or malformed reply must never fall back to raw
            // JSON as speech. Already streamed text cannot be retracted.
          }
        }
      } else if (char == ',' && _depth == 1) {
        _expectKey = true;
        _expectColon = false;
        _expectValue = false;
      } else {
        // A non-string value cannot become a speech field when a later
        // metadata string arrives.
        _expectValue = false;
      }
    }
    return output.isEmpty ? null : output.toString();
  }

  void _writeStringChar(String char, StringBuffer output) {
    if (_readingKey) {
      _key.write(char);
    } else if (_capturing) {
      output.write(char);
    }
  }

  String _decodeSimpleEscape(String escaped) => switch (escaped) {
    'n' => '\n',
    'r' => '\r',
    't' => '\t',
    'b' => '\b',
    'f' => '\f',
    '"' => '"',
    r'\' => r'\',
    '/' => '/',
    _ => escaped,
  };

  String? getLastFullJson() => _lastFullJson;
  String getRawContent() => _rawBuffer.toString();
  String getBufferedContent() => getRawContent();

  void clearJson() {
    _lastFullJson = null;
  }

  void clear() {
    _rawBuffer.clear();
    _key.clear();
    _depth = 0;
    _rootStart = -1;
    _done = false;
    _inString = false;
    _readingKey = false;
    _expectKey = false;
    _expectColon = false;
    _expectValue = false;
    _capturing = false;
    _captureDone = false;
    _escaped = false;
    _unicode = null;
    _lastFullJson = null;
  }

  bool get hasBufferedContent => _rawBuffer.isNotEmpty;
}
