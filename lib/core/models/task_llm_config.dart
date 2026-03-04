import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_llm_config.freezed.dart';
part 'task_llm_config.g.dart';

/// Configuration mapping LLM IDs to specific task types
@freezed
sealed class TaskLlmConfig with _$TaskLlmConfig {
  const factory TaskLlmConfig({
    /// LLM config ID to use for assistant responses
    @Default(null) String? assistantLlmId,

    /// LLM config ID to use for title generation
    @Default(null) String? titleGenerationLlmId,

    /// LLM config ID to use for function calling
    @Default(null) String? functionCallingLlmId,
  }) = _TaskLlmConfig;

  factory TaskLlmConfig.fromJson(Map<String, dynamic> json) =>
      _$TaskLlmConfigFromJson(json);
}
