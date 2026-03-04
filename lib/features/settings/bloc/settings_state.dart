import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/task_llm_config.dart';
import '../../../core/models/llm_config.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    // NEW FIELDS:
    @Default(null) TaskLlmConfig? taskLlmConfig,
    @Default(<LlmConfig>[]) List<LlmConfig> availableLlmConfigs,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState();
}
