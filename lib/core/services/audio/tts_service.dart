enum TtsType { waiting, response }

class TtsService {
  TtsType? _currentType;

  TtsType? get currentType => _currentType;

  bool get isPlayingWaiting => _currentType == TtsType.waiting;
  bool get isPlayingResponse => _currentType == TtsType.response;

  Future<void> speak(String text) async {
    await _stopCurrent();
    _currentType = TtsType.response;
  }

  Future<void> playWaitingSentence(String text) async {
    await _stopCurrent();
    _currentType = TtsType.waiting;
  }

  Future<void> stop() async {
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    // Stop current playback
    _currentType = null;
  }

  void dispose() {
    // Cleanup
  }
}
