import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/models/demo_script.dart';
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

  /// A non-singleton instance with an injected delegate, for tests.
  @visibleForTesting
  FakeLlmService.forTest(LlmServiceInterface delegate)
    : _realService = delegate;

  // Real service for config management and for calls made while inactive
  final LlmServiceInterface _realService;

  final List<FakeLlmResponse> _responseQueue = <FakeLlmResponse>[];
  bool _isActive = false;
  int _currentIndex = 0;
  String? _title;

  @override
  bool get isActive => _isActive;

  /// Get the number of remaining responses
  int get remainingResponses => _responseQueue.length - _currentIndex;

  /// Check if there are more responses available
  bool get hasMore => _currentIndex < _responseQueue.length;

  /// Activate fake LLM mode with a list of responses
  ///
  /// [title] is what [generateTitle] returns while active (null when none),
  /// so a scripted run never makes a real title call.
  void activate(List<FakeLlmResponse> responses, {String? title}) {
    _responseQueue.clear();
    _responseQueue.addAll(responses);
    _currentIndex = 0;
    _title = title;
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
    _title = null;
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
  }) async {
    if (_isActive) {
      // Scripted run: never leave the process for a title.
      return _title;
    }
    return _realService.generateTitle(
      firstUserMessage,
      config: config,
      language: language,
    );
  }

  @override
  Future<String?> extractMemory({
    required String conversationExcerpt,
    required List<String> currentMemory,
    LlmConfig? config,
  }) async {
    if (_isActive) {
      // Demo mode: keep the current memory untouched instead of consuming a
      // scripted response.
      AppLogger.debug(
        'FakeLlmService: demo active, skipping memory extraction',
        tag: 'FakeLlmService',
      );
      return jsonEncode(<String, dynamic>{'memory': currentMemory});
    }
    return _realService.extractMemory(
      conversationExcerpt: conversationExcerpt,
      currentMemory: currentMemory,
      config: config,
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
        'FakeLlmService: not active, delegating to real LLM service',
        tag: 'FakeLlmService',
      );
      // Delegate to real service when not in demo mode
      return _realService.promptModel(
        messages: messages,
        systemPrompt: systemPrompt,
        config: config,
        returnJson: returnJson,
        debugLogs: debugLogs,
      );
    }

    final FakeLlmResponse response = getNextResponse()!;
    if (debugLogs) {
      AppLogger.debug(
        'FakeLlmService: Returning fake response',
        tag: 'FakeLlmService',
      );
    }
    // Tool calls are stream-only: here a tool response is just its jsonBody.
    return response.jsonBody;
  }

  @override
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
    List<Map<String, dynamic>>? tools,
  }) async* {
    if (!_isActive || !hasMore) {
      AppLogger.debug(
        'FakeLlmService: not active, delegating to real LLM service',
        tag: 'FakeLlmService',
      );
      // Delegate to real service when not in demo mode
      yield* _realService.promptModelStream(
        messages: messages,
        systemPrompt: systemPrompt,
        config: config,
        returnJson: returnJson,
        debugLogs: debugLogs,
        tools: tools,
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

    if (response.toolCalls.isNotEmpty) {
      // A tool round: the calls only, no text. The streaming service runs the
      // tools and prompts again, which consumes the next (answer) response.
      for (int i = 0; i < response.toolCalls.length; i++) {
        final FakeToolCall call = response.toolCalls[i];
        yield LlmStreamChunk.toolCallDelta(
          index: i,
          id: 'call_$i',
          name: call.name,
          argumentsDelta: jsonEncode(call.arguments),
        );
      }
      yield const LlmStreamChunk.complete();
      return;
    }

    yield LlmStreamChunk.text(content: response.jsonBody, isComplete: true);
    yield const LlmStreamChunk.complete();
  }
}
