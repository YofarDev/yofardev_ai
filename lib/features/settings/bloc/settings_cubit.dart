import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/models/task_llm_config.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/services/llm/llm_service_interface.dart';
import '../../../core/utils/logger.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import 'settings_state.dart';

/// Cubit for managing application settings
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required LlmServiceInterface llmService,
  }) : _settingsRepository = settingsRepository,
       _llmService = llmService,
       super(SettingsState.initial());

  final SettingsRepository _settingsRepository;
  final LlmServiceInterface _llmService;

  /// Load all settings
  Future<void> loadSettings() async {
    // Load task LLM config
    await loadTaskLlmConfig();

    // Load available LLM configs
    try {
      final List<LlmConfig> configs = _llmService.getAllConfigs();
      emit(state.copyWith(availableLlmConfigs: configs));
    } catch (e) {
      AppLogger.error(
        'Failed to load available LLM configs',
        tag: 'SettingsCubit',
        error: e,
      );
    }
  }

  /// Load the task-specific LLM configuration
  Future<void> loadTaskLlmConfig() async {
    final Either<Exception, TaskLlmConfig> result = await _settingsRepository
        .getTaskLlmConfig();
    result.fold((Exception error) {
      AppLogger.error(
        'Failed to load task LLM config',
        tag: 'SettingsCubit',
        error: error,
      );
      emit(state.copyWith(taskLlmConfig: const TaskLlmConfig()));
    }, (TaskLlmConfig config) => emit(state.copyWith(taskLlmConfig: config)));
  }

  /// Save the task-specific LLM configuration
  Future<void> setTaskLlmConfig(TaskLlmConfig config) async {
    final Either<Exception, void> result = await _settingsRepository
        .setTaskLlmConfig(config);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to save task LLM config',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(taskLlmConfig: config)),
    );
  }
}
