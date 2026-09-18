/// Splits text into sentences, handling incomplete final sentence
class SentenceSplitter {
  static final RegExp _sentenceEnd = RegExp(r'[.!?]+(?:\s+|$)|[:]\s*(?=\n)');

  /// Buffer length beyond which an unpunctuated run is force-flushed at the
  /// last soft boundary. Bounds first-audio latency when the model produces a
  /// long clause without sentence-ending punctuation.
  final int maxBufferLength;

  /// Minimum prefix length when force-flushing at a soft boundary.
  static const int _minSoftFlushLength = 60;

  String _incompleteBuffer = '';
  int _sentenceCount = 0;

  SentenceSplitter({this.maxBufferLength = 180});

  /// Extract complete sentences from text
  ///
  /// Returns list of complete sentences found
  /// Keeps incomplete sentence in buffer for next call
  List<String> extractCompleteSentences(String text) {
    final List<String> sentences = <String>[];
    final String fullText = '$_incompleteBuffer$text';

    final StringBuffer current = StringBuffer();

    for (int i = 0; i < fullText.length; i++) {
      current.write(fullText[i]);

      // Check if we have a complete sentence ending
      final String currentText = current.toString();
      final RegExpMatch? match = _sentenceEnd.firstMatch(currentText);

      if (match != null && match.end == currentText.length) {
        final String sentence = currentText.trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
          _sentenceCount++;
        }
        current.clear();
      }
    }

    // Keep remainder in buffer
    _incompleteBuffer = current.toString();

    // A long unpunctuated run would delay first audio; flush it at the last
    // soft boundary (or entirely if none exists).
    if (_incompleteBuffer.length >= maxBufferLength) {
      sentences.addAll(_flushLongBuffer());
    }

    return sentences;
  }

  /// Flushes the oversized buffer at its last soft boundary (", " preferred,
  /// else any space) at least [_minSoftFlushLength] characters in; hard-flushes
  /// the whole buffer when no such boundary exists.
  List<String> _flushLongBuffer() {
    final String buffer = _incompleteBuffer;
    _incompleteBuffer = '';

    int cutIndex = -1;
    final int lastUsableIndex = buffer.length - 1;
    for (int i = buffer.length - 1; i >= _minSoftFlushLength; i--) {
      if (buffer[i] == ' ' && i <= lastUsableIndex) {
        // Prefer a ", " boundary (comma directly before the space).
        if (i > 0 && buffer[i - 1] == ',') {
          cutIndex = i;
          break;
        }
        cutIndex = i;
      }
    }

    final String flushedText;
    if (cutIndex != -1) {
      flushedText = buffer.substring(0, cutIndex);
      _incompleteBuffer = buffer.substring(cutIndex + 1);
    } else {
      flushedText = buffer;
    }

    final String sentence = flushedText.trim();
    if (sentence.isNotEmpty) {
      _sentenceCount++;
      return <String>[sentence];
    }
    return const <String>[];
  }

  /// Get the current incomplete buffer
  String get incompleteBuffer => _incompleteBuffer;

  /// Get total sentences extracted so far
  int get sentenceCount => _sentenceCount;

  /// Clear all state
  void clear() {
    _incompleteBuffer = '';
    _sentenceCount = 0;
  }

  /// Force flush the buffer (returns incomplete sentence as complete)
  List<String> flush() {
    final List<String> flushed = <String>[];
    if (_incompleteBuffer.trim().isNotEmpty) {
      flushed.add(_incompleteBuffer.trim());
    }
    clear();
    return flushed;
  }
}
