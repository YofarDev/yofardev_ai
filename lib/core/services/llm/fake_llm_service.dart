import 'dart:async';

import '../../../../features/demo/domain/models/demo_script.dart';
import '../../models/function_info.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../../utils/logger.dart';
import 'llm_service_interface.dart';

/// Fake LLM service that returns pre-scripted responses for demo mode
///
/// This service implements the same interface as the real LLM service but
/// returns queued responses instead of making API calls. This allows for
/// natural user typing while responses are injected from a demo script.
class FakeLlmService implements LlmServiceInterface {
  static final FakeLlmService _instance = FakeLlmService._internal();

  factory FakeLlmService() {
    return _instance;
  }

  FakeLlmService._internal();

  final List<FakeLlmResponse> _responseQueue = <FakeLlmResponse>[];
  bool _isActive = false;
  int _currentIndex = 0;

  @override
  bool get isActive => _isActive;

  /// Get the number of remaining responses
  int get remainingResponses => _responseQueue.length - _currentIndex;

  /// Check if there are more responses available
  bool get hasMore => _currentIndex < _responseQueue.length;

  /// Activate fake LLM mode with a list of responses
  void activate(List<FakeLlmResponse> responses) {
    _responseQueue.clear();
    _responseQueue.addAll(responses);
    _currentIndex = 0;
    _isActive = true;
    AppLogger.info(
      'FakeLlmService activated with ${responses.length} responses',
      tag: 'FakeLlmService',
    );
  }

  /// Deactivate fake LLM mode
  void deactivate() {
    _isActive = false;
    _responseQueue.clear();
    _currentIndex = 0;
    AppLogger.info('FakeLlmService deactivated', tag: 'FakeLlmService');
  }

  /// Get the next fake response (returns null if no more responses or not active)
  FakeLlmResponse? getNextResponse() {
    if (!_isActive || !hasMore) return null;

    final FakeLlmResponse response = _responseQueue[_currentIndex];
    _currentIndex++;
    AppLogger.debug(
      'FakeLlmService returning response $_currentIndex/${_responseQueue.length}',
      tag: 'FakeLlmService',
    );
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
    AppLogger.info('FakeLlmService reset to beginning', tag: 'FakeLlmService');
  }

  // LlmServiceInterface implementation

  @override
  Future<void> init() async {
    // No initialization needed for fake service
    AppLogger.info('FakeLlmService initialized', tag: 'FakeLlmService');
  }

  @override
  List<LlmConfig> getAllConfigs() {
    // Return empty list - fake service doesn't use configs
    return const <LlmConfig>[];
  }

  @override
  LlmConfig? getCurrentConfig() {
    // Return null - fake service doesn't use configs
    return null;
  }

  @override
  Future<void> saveConfig(LlmConfig config) async {
    // No-op - fake service doesn't save configs
    AppLogger.warning(
      'FakeLlmService: saveConfig is a no-op',
      tag: 'FakeLlmService',
    );
  }

  @override
  Future<void> deleteConfig(String id) async {
    // No-op - fake service doesn't manage configs
    AppLogger.warning(
      'FakeLlmService: deleteConfig is a no-op',
      tag: 'FakeLlmService',
    );
  }

  @override
  Future<void> setCurrentConfig(String id) async {
    // No-op - fake service doesn't manage configs
    AppLogger.warning(
      'FakeLlmService: setCurrentConfig is a no-op',
      tag: 'FakeLlmService',
    );
  }

  @override
  Future<String?> promptModel({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  }) async {
    if (!_isActive || !hasMore) {
      AppLogger.debug(
        'FakeLlmService: not active or no more responses',
        tag: 'FakeLlmService',
      );
      return null;
    }

    final FakeLlmResponse response = getNextResponse()!;
    if (debugLogs) {
      AppLogger.debug(
        'FakeLlmService: Returning fake response',
        tag: 'FakeLlmService',
      );
    }
    return response.jsonBody;
  }

  @override
  Future<(String, List<FunctionInfo>)> checkFunctionsCalling({
    required LlmConfig api,
    required List<FunctionInfo> functions,
    required List<LlmMessage> messages,
    required String lastUserMessage,
  }) async {
    if (!_isActive || !hasMore) {
      AppLogger.debug(
        'FakeLlmService: not active or no more responses for function calling',
        tag: 'FakeLlmService',
      );
      return ('', <FunctionInfo>[]);
    }

    // For demo purposes, we'll just return the next response
    // In a real demo script, you might want to simulate function calls
    final FakeLlmResponse response = getNextResponse()!;
    return (response.jsonBody, <FunctionInfo>[]);
  }
}
