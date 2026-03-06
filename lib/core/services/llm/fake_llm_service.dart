import 'dart:async';

import '../../../../features/demo/domain/models/demo_script.dart';
import '../../models/function_info.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../../models/llm_task_type.dart';
import '../../utils/logger.dart';
import 'llm_service_interface.dart';
import 'llm_stream_chunk.dart';
import 'llm_service.dart';

/// Fake LLM service that returns pre-scripted responses for demo mode
///
/// This service implements the same interface as the real LLM service but
/// returns queued responses instead of making API calls. This allows for
/// natural user typing while responses are injected from a demo script.
///
/// Config management operations are delegated to the real LlmService
/// to ensure configs are always accessible.
class FakeLlmService implements LlmServiceInterface {
  static final FakeLlmService _instance = FakeLlmService._internal();

  factory FakeLlmService() {
    return _instance;
  }

  FakeLlmService._internal() : _realService = LlmService();

  // Real service for config management
  final LlmService _realService;

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
    // Initialize both services
    await _realService.init();
    AppLogger.info('FakeLlmService initialized', tag: 'FakeLlmService');
  }

  @override
  List<LlmConfig> getAllConfigs() => _realService.getAllConfigs();

  @override
  LlmConfig? getCurrentConfig() => _realService.getCurrentConfig();

  @override
  Future<void> saveConfig(LlmConfig config) => _realService.saveConfig(config);

  @override
  Future<void> deleteConfig(String id) => _realService.deleteConfig(id);

  @override
  Future<void> setCurrentConfig(String id) => _realService.setCurrentConfig(id);

  @override
  Future<LlmConfig?> getConfigForTask(LlmTaskType task) =>
      _realService.getConfigForTask(task);

  @override
  Future<String?> generateTitle(
    String firstUserMessage, {
    LlmConfig? config,
    String language = 'en',
  }) => _realService.generateTitle(
    firstUserMessage,
    config: config,
    language: language,
  );

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
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  }) async* {
    if (!_isActive || !hasMore) {
      AppLogger.debug(
        'FakeLlmService: not active or no more responses for streaming',
        tag: 'FakeLlmService',
      );
      yield const LlmStreamChunk.error(
        'Fake LLM service is not active or no more responses',
      );
      return;
    }

    final FakeLlmResponse response = getNextResponse()!;

    // Simulate streaming by yielding the full response at once
    // In a real demo, you might want to split this into chunks
    if (debugLogs) {
      AppLogger.debug(
        'FakeLlmService: Streaming fake response',
        tag: 'FakeLlmService',
      );
    }

    yield LlmStreamChunk.text(content: response.jsonBody, isComplete: true);
    yield const LlmStreamChunk.complete();
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
