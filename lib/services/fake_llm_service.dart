import '../models/demo_script.dart';

/// Fake LLM service that returns pre-scripted responses.
/// Activated in demo mode, allowing natural user typing while responses are injected.
class FakeLlmService {
  static final FakeLlmService _instance = FakeLlmService._internal();
  factory FakeLlmService() => _instance;
  FakeLlmService._internal();

  final List<FakeLlmResponse> _responseQueue = <FakeLlmResponse>[];
  bool _isActive = false;
  int _currentIndex = 0;

  bool get isActive => _isActive;
  int get remainingResponses => _responseQueue.length - _currentIndex;
  bool get hasMore => _currentIndex < _responseQueue.length;

  /// Activate fake LLM mode with a list of responses
  void activate(List<FakeLlmResponse> responses) {
    _responseQueue.clear();
    _responseQueue.addAll(responses);
    _currentIndex = 0;
    _isActive = true;
  }

  /// Deactivate fake LLM mode
  void deactivate() {
    _isActive = false;
    _responseQueue.clear();
    _currentIndex = 0;
  }

  /// Get the next fake response (returns null if no more responses or not active)
  FakeLlmResponse? getNextResponse() {
    if (!_isActive || !hasMore) return null;

    final FakeLlmResponse response = _responseQueue[_currentIndex];
    _currentIndex++;
    return response;
  }

  /// Check if there's a next response available
  bool hasNextResponse() {
    return _isActive && hasMore;
  }

  /// Peek at the next response without consuming it
  FakeLlmResponse? peekNextResponse() {
    if (!_isActive || !hasMore) return null;
    return _responseQueue[_currentIndex];
  }

  /// Reset to the beginning of the script
  void reset() {
    _currentIndex = 0;
  }
}
