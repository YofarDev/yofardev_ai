import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'llm_config.freezed.dart';
part 'llm_config.g.dart';

/// Configuration for LLM API connections
///
/// Contains all necessary information to connect to an LLM provider
/// including endpoint, authentication, and generation parameters.
@freezed
sealed class LlmConfig with _$LlmConfig {
  const factory LlmConfig({
    /// Unique identifier for this configuration
    required String id,

    /// User-friendly label (e.g., "My OpenAI", "Local Ollama")
    required String label,

    /// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
    required String baseUrl,

    /// API key for authentication
    required String apiKey,

    /// Model name to use (e.g., "gpt-4o", "llama3")
    required String model,

    /// Temperature for text generation (0.0 - 2.0)
    /// Lower = more focused, Higher = more creative
    @Default(0.7) double temperature,
  }) = _LlmConfig;

  factory LlmConfig.fromJson(Map<String, dynamic> json) =>
      _$LlmConfigFromJson(json);

  /// Create a new LlmConfig with a generated UUID
  factory LlmConfig.create({
    required String label,
    required String baseUrl,
    required String apiKey,
    required String model,
    double temperature = 0.7,
  }) {
    return LlmConfig(
      id: const Uuid().v4(),
      label: label,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
    );
  }
}
