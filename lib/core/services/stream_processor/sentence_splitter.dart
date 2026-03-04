/// Splits text into sentences, handling incomplete final sentence
class SentenceSplitter {
  static final RegExp _sentenceEnd = RegExp(
    r'[.!?]+\s+(?=[A-ZÀÂÆÇÉÈÊËÏÎÔÙÛÜŸÑ])|[:]\s+(?=[\n])',
  );

  String _incompleteBuffer = '';
  int _sentenceCount = 0;

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

    return sentences;
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
