import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/models/llm_config.dart';
import '../../../core/models/task_llm_config.dart';
import '../../../core/services/llm/llm_service_interface.dart';
import '../../../core/utils/logger.dart';
import '../../chat/domain/models/chat.dart';
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
    // Initialize LLM service if not already done
    await _llmService.init();

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

  /// Set the system prompt
  Future<void> setSystemPrompt(String prompt) async {
    final Either<Exception, void> result = await _settingsRepository
        .setSystemPrompt(prompt);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to set system prompt',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => null, // Don't need to emit, value is stored in repository
    );
  }

  /// Set the username
  Future<void> setUsername(String username) async {
    final Either<Exception, void> result = await _settingsRepository
        .setUsername(username);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to set username',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => null, // Don't need to emit, value is stored in repository
    );
  }

  /// Set the persona
  Future<void> setPersona(ChatPersona persona) async {
    final Either<Exception, void> result = await _settingsRepository.setPersona(
      persona,
    );
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to set persona',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => null, // Don't need to emit, value is stored in repository
    );
  }
}
