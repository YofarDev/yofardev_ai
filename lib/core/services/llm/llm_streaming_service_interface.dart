import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import 'llm_stream_chunk.dart';

/// Interface for LLM streaming operations
///
/// This interface separates streaming concerns from configuration management,
/// allowing for easier testing and maintenance.
abstract class LlmStreamingServiceInterface {
  /// Streams a response from the LLM
  ///
  /// Returns a stream of [LlmStreamChunk] objects containing:
  /// - Text chunks as they arrive
  /// - Completion signals
  /// - Error information
  ///
  /// Parameters:
  /// - [messages]: The conversation history
  /// - [systemPrompt]: System prompt to guide the LLM
  /// - [config]: Optional LLM configuration (uses current if null)
  /// - [returnJson]: If true, requests JSON response format
  /// - [debugLogs]: If true, enables detailed logging
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  });
}
