import 'dart:convert';

import '../../../../core/utils/logger.dart';

/// Incrementally extracts the text field of a streamed JSON object.
///
/// Each chunk is scanned once (only the new characters plus a small carry
/// window), structure state (depth / string / escape) is advanced
/// character-by-character, and a single `json.decode` is attempted per
/// top-level object close — instead of re-copying the buffer and re-parsing
/// the whole text field on every chunk (which was quadratic in reply length).
class JsonStreamExtractor {
  static const List<String> _textKeys = <String>[
    'text',
    'content',
    'message',
    'response',
  ];

  /// Raw stream content, appended once per chunk (read once at stream end).
  final StringBuffer _rawBuffer = StringBuffer();

  /// Window not yet consumed: a chunk tail that may grow into a key, an
  /// escape, or the field opening. Bounded by the longest key + quotes.
  String _carry = '';

  /// Structure state, advanced once per character.
  int _depth = 0;
  bool _inString = false;
  bool _escaped = false;
  bool _sawOpenBrace = false;

  /// Text-field capture state (set when the opening quote of the value is
  /// found; capture ends at its unescaped closing quote).
  bool _capturing = false;
  bool _captureDone = false;
  final StringBuffer _captured = StringBuffer();

  String? _lastFullJson;
  String _lastExtractedText = '';

  /// Process a chunk and return the newly extracted text delta, if any.
  String? extractText(String chunk, {bool expectJson = true}) {
    _rawBuffer.write(chunk);
    if (!expectJson) {
      // Non-JSON streams pass the chunk through untouched: do NOT route
      // through _emitDelta, whose dedupe state stays reserved for the JSON
      // path.
      return chunk;
    }

    final String window = '$_carry$chunk';
    if (_capturing) {
      _unflushedWindowStart = 0;
    }
    _carry = '';
    String? delta;

    int i = 0;
    while (i < window.length) {
      if (!_capturing && !_captureDone) {
        // Looking for the value opening of the first text key.
        final int valueQuote = _findValueQuote(window, i);
        if (valueQuote < 0) {
          break; // carry handled below
        }
        _capturing = true;
        _unflushedWindowStart = valueQuote + 1;
        // Braces before the value were never fed to _advanceStructure (the
        // key-matching phase skips them), so seed the depth by scanning the
        // prefix once — this is the only non-incremental scan per stream.
        _seedDepth(window, valueQuote);
        i = valueQuote + 1;
        continue;
      }

      final String char = window[i];
      if (_capturing) {
        if (_escaped) {
          if (char == 'u') {
            // Hex digits not fully arrived: stop scanning and hold the
            // whole escape (from its backslash) for the next chunk.
            if (i + 5 > window.length) {
              // Rewind the unflushed tail into the carry: the whole region
              // (including the partial escape, from its backslash) is
              // re-parsed once the hex digits arrive.
              _rewindUnflushed(window);
              _escaped = false;
              return delta;
            }
            final String hex = window.substring(i + 1, i + 5);
            final int? codePoint = int.tryParse(hex, radix: 16);
            if (codePoint != null) {
              _captured.write(String.fromCharCode(codePoint));
            }
            _escaped = false;
            i += 5;
            continue;
          }
          _captured.write(_decodeSimpleEscape(char));
          _escaped = false;
          i++;
          continue;
        }
        if (char == r'\') {
          if (i + 1 >= window.length) {
            // Lone trailing backslash: hold the unflushed region (including
            // this backslash) for the next chunk.
            _rewindUnflushed(window);
            return delta;
          }
          _escaped = true;
          i++;
          continue;
        }
        if (char == '"') {
          _capturing = false;
          _captureDone = true;
          delta = _mergeDelta(delta, _emitDelta(_captured.toString()));
          _flushedLength = _captured.length;
          i++;
          continue;
        }
        _captured.write(char);
        i++;
        continue;
      }

      // _captureDone: track structure only, to spot the top-level close.
      delta = _mergeDelta(delta, _advanceStructure(char));
      i++;
    }

    // Stream the captured prefix as it arrives: _emitDelta's prefix dedupe
    // makes this emit only the newly captured tail. (The escape-pending early
    // returns above skip this on purpose: a trailing partial escape is held.)
    if (_capturing) {
      delta = _mergeDelta(delta, _emitDelta(_captured.toString()));
      _flushedLength = _captured.length;
    }

    // Hold back a tail that may still grow into a key or the field opening.
    // While capturing, everything scanned is already consumed (escapes are
    // carried explicitly above) — carrying from the last quote here would
    // re-inject value text.
    if (!_capturing && !_captureDone) {
      _carry = _carryTail(window);
    }

    return delta;
  }

  /// Rewinds every captured-but-unemitted character (plus the pending escape)
  /// into [_carry] so the next chunk re-parses them from a complete escape.
  void _rewindUnflushed(String window) {
    if (_captured.length > _flushedLength) {
      final String kept = _captured.toString().substring(0, _flushedLength);
      _captured
        ..clear()
        ..write(kept);
    }
    _carry = window.substring(_unflushedWindowStart);
  }

  /// Length of [_captured] already emitted as a delta; the tail is rewound
  /// into [_carry] when a split escape forces a re-parse.
  int _flushedLength = 0;

  /// Index in the current window of the first captured character that has
  /// not been emitted yet (start of the rewinding region).
  int _unflushedWindowStart = 0;

  /// Counts braces/strings in [window] before [endIndex] and seeds
  /// [_depth]/_inString so the post-capture structure tracking is exact.
  void _seedDepth(String window, int endIndex) {
    _depth = 0;
    _inString = false;
    _escaped = false;
    _sawOpenBrace = false;
    for (int i = 0; i < endIndex; i++) {
      _advanceStructure(window[i]);
    }
  }

  /// Finds the opening quote of the value for the first of [_textKeys]
  /// appearing at or after [from] in [window]. Returns -1 when none is
  /// complete yet (the caller then keeps a tail in [_carry]).
  int _findValueQuote(String window, int from) {
    int best = -1;
    for (final String key in _textKeys) {
      final int keyIndex = window.indexOf('"$key"', from);
      if (keyIndex < 0) {
        continue;
      }
      final int colonIndex = window.indexOf(':', keyIndex + key.length + 2);
      if (colonIndex < 0) {
        continue;
      }
      int cursor = colonIndex + 1;
      while (cursor < window.length &&
          (window[cursor] == ' ' ||
              window[cursor] == '\n' ||
              window[cursor] == '\r' ||
              window[cursor] == '\t')) {
        cursor++;
      }
      if (cursor >= window.length) {
        continue; // opening quote not arrived yet
      }
      if (window[cursor] != '"') {
        continue; // not a string field
      }
      if (best < 0 || keyIndex < best) {
        best = cursor;
      }
    }
    return best;
  }

  /// Carries the smallest tail that could still grow into a key + value
  /// opening: from the last quote, else nothing. Only used while not
  /// capturing — inside the value, escapes are carried explicitly.
  String _carryTail(String window) {
    final int lastQuote = window.lastIndexOf('"');
    if (lastQuote >= 0) {
      return window.substring(lastQuote);
    }
    return '';
  }

  String? _advanceStructure(String char) {
    if (_inString) {
      if (_escaped) {
        _escaped = false;
      } else if (char == r'\') {
        _escaped = true;
      } else if (char == '"') {
        _inString = false;
      }
      return null;
    }
    switch (char) {
      case '"':
        _inString = true;
      case '{':
        _depth++;
        _sawOpenBrace = true;
      case '}':
        _depth--;
        if (_sawOpenBrace && _depth <= 0) {
          final String? closeDelta = _onTopLevelClose();
          _depth = 0;
          _sawOpenBrace = false;
          return closeDelta;
        }
    }
    return null;
  }

  /// One json.decode attempt per completed top-level object (was: per chunk).
  String? _onTopLevelClose() {
    final String raw = _rawBuffer.toString();
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    final String jsonStr = raw.substring(start, end + 1);
    try {
      final Map<String, dynamic> decoded =
          json.decode(jsonStr) as Map<String, dynamic>;
      _lastFullJson = jsonStr;
      for (final String key in _textKeys) {
        final dynamic value = decoded[key];
        if (value is String && value.isNotEmpty) {
          // Complete JSON wins; if it differs from the streamed prefix, the
          // _emitDelta fallback re-emits the full value once.
          return _emitDelta(value);
        }
      }
    } on FormatException {
      AppLogger.debug(
        'Top-level close without valid JSON; continuing to buffer',
        tag: 'JsonStreamExtractor',
      );
    } catch (e) {
      AppLogger.warning(
        'Error extracting JSON at top-level close: $e',
        tag: 'JsonStreamExtractor',
      );
    }
    return null;
  }

  String _decodeSimpleEscape(String escaped) {
    return switch (escaped) {
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
  }

  String? _mergeDelta(String? accumulated, String? latest) {
    if (latest == null) {
      return accumulated;
    }
    return accumulated == null ? latest : '$accumulated$latest';
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

  /// Get the last complete full JSON that was extracted.
  String? getLastFullJson() => _lastFullJson;

  /// Get the full raw content received so far.
  String getRawContent() => _rawBuffer.toString();

  /// Clear the stored JSON.
  void clearJson() {
    _lastFullJson = null;
  }

  /// Get any remaining buffered content (for cleanup).
  String getBufferedContent() => _rawBuffer.toString();

  /// Clear the buffer.
  void clear() {
    _rawBuffer.clear();
    _carry = '';
    _depth = 0;
    _inString = false;
    _escaped = false;
    _sawOpenBrace = false;
    _capturing = false;
    _captureDone = false;
    _captured.clear();
    _flushedLength = 0;
    _unflushedWindowStart = 0;
    _lastExtractedText = '';
  }

  /// Whether buffer contains content that might be partial JSON.
  bool get hasBufferedContent => _rawBuffer.isNotEmpty;
}
