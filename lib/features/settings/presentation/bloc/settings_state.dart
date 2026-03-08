import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/task_llm_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/chat.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    // NEW FIELDS:
    @Default(null) TaskLlmConfig? taskLlmConfig,
    @Default(<LlmConfig>[]) List<LlmConfig> availableLlmConfigs,
    // Function Calling Configuration Fields:
    @Default(null) String? googleSearchKey,
    @Default(null) String? googleSearchEngineId,
    @Default(true) bool googleSearchEnabled,
    @Default(null) String? openWeatherKey,
    @Default(true) bool openWeatherEnabled,
    @Default(null) String? newYorkTimesKey,
    @Default(true) bool newYorkTimesEnabled,
    // User Settings Fields:
    @Default(null) String? username,
    @Default(null) String? systemPrompt,
    @Default(ChatPersona.assistant) ChatPersona persona,
    // Error fields:
    @Default(false) bool hasError,
    @Default(null) String? errorMessage,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState();
}
