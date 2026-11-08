import 'package:flutter/foundation.dart' show ValueListenable;

import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../../models/llm_task_type.dart';
import 'llm_stream_chunk.dart';

/// Interface for LLM service implementations
///
/// Allows swapping between real LLM API and fake/demo implementations
abstract class LlmServiceInterface {
  /// Initialize the service (load configs, etc.)
  Future<void> init();

  /// Get all stored LLM configurations
  List<LlmConfig> getAllConfigs();

  /// Get the currently active LLM configuration
  LlmConfig? getCurrentConfig();

  /// Whether any configuration exists: null until [init] has loaded them,
  /// then kept current by [saveConfig] and [deleteConfig].
  ValueListenable<bool?> get configured;

  /// Save a configuration (add new or update existing)
  Future<void> saveConfig(LlmConfig config);

  /// Delete a configuration by ID
  Future<void> deleteConfig(String id);

  /// Set a configuration as the current active one
  Future<void> setCurrentConfig(String id);

  /// Send a prompt to the LLM model
  ///
  /// Returns the response content as a string, or null if failed
  Future<String?> promptModel({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  });

  /// Send a prompt to the LLM model with streaming response
  ///
  /// Returns a Stream of LlmStreamChunk for real-time processing
  /// Use this for faster UI feedback and progressive TTS generation
  ///
  /// [tools]: optional OpenAI-format tool definitions; when provided the
  /// stream may carry toolCallDelta chunks instead of text.
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
    List<Map<String, dynamic>>? tools,
  });

  /// Whether this service is active (for fake/demo service)
  bool get isActive;

  // NEW METHODS:
  /// Get the LLM configuration for a specific task type
  /// Falls back to current/default config if task-specific config not found
  Future<LlmConfig?> getConfigForTask(LlmTaskType task);

  /// Generate a title for a chat based on the first user message
  /// Returns null if generation fails or no config is available
  Future<String?> generateTitle(
    String firstUserMessage, {
    LlmConfig? config,
    String language = 'en',
  });

  /// Update the global memory items from a conversation excerpt
  ///
  /// Returns the raw JSON response containing the complete updated memory
  /// list, or null if generation fails or no config is available
  Future<String?> extractMemory({
    required String conversationExcerpt,
    required List<String> currentMemory,
    LlmConfig? config,
  });
}
