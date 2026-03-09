import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/llm_config.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../domain/repositories/settings_repository.dart';
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

    // Load user settings
    await loadUsername();
    await loadSystemPrompt();
    await loadPersona();

    // Load task LLM config
    await loadTaskLlmConfig();

    // Load function calling configurations
    await loadFunctionCallingConfigs();

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
      emit(
        state.copyWith(
          hasError: true,
          errorMessage: 'Failed to load available LLM configs',
        ),
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
      (_) => emit(state.copyWith(systemPrompt: prompt)),
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
      (_) => emit(state.copyWith(username: username)),
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
      (_) => emit(state.copyWith(persona: persona)),
    );
  }

  /// Load the username
  Future<void> loadUsername() async {
    final Either<Exception, String?> result = await _settingsRepository
        .getUsername();
    result.fold((Exception error) {
      AppLogger.error(
        'Failed to load username',
        tag: 'SettingsCubit',
        error: error,
      );
      emit(state.copyWith(username: null));
    }, (String? username) => emit(state.copyWith(username: username)));
  }

  /// Load the system prompt
  Future<void> loadSystemPrompt() async {
    final Either<Exception, String> result = await _settingsRepository
        .getSystemPrompt();
    result.fold((Exception error) {
      AppLogger.error(
        'Failed to load system prompt',
        tag: 'SettingsCubit',
        error: error,
      );
      emit(state.copyWith(systemPrompt: null));
    }, (String prompt) => emit(state.copyWith(systemPrompt: prompt)));
  }

  /// Load the persona
  Future<void> loadPersona() async {
    final Either<Exception, ChatPersona> result = await _settingsRepository
        .getPersona();
    result.fold((Exception error) {
      AppLogger.error(
        'Failed to load persona',
        tag: 'SettingsCubit',
        error: error,
      );
      emit(state.copyWith(persona: ChatPersona.assistant));
    }, (ChatPersona persona) => emit(state.copyWith(persona: persona)));
  }

  /// Load Google Search configuration
  Future<void> loadGoogleSearchConfig() async {
    final Either<Exception, String?> keyResult = await _settingsRepository
        .getGoogleSearchKey();
    final Either<Exception, String?> idResult = await _settingsRepository
        .getGoogleSearchEngineId();
    final Either<Exception, bool> enabledResult = await _settingsRepository
        .getGoogleSearchEnabled();

    final String? key = keyResult.getOrElse((Exception _) => null);
    final String? id = idResult.getOrElse((Exception _) => null);
    final bool enabled = enabledResult.getOrElse((Exception _) => true);

    emit(
      state.copyWith(
        googleSearchKey: key,
        googleSearchEngineId: id,
        googleSearchEnabled: enabled,
      ),
    );
  }

  /// Update Google Search API key
  Future<void> updateGoogleSearchKey(String key) async {
    final Either<Exception, void> result = await _settingsRepository
        .setGoogleSearchKey(key);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to save Google Search key: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(googleSearchKey: key)),
    );
  }

  /// Update Google Search Engine ID
  Future<void> updateGoogleSearchEngineId(String id) async {
    final Either<Exception, void> result = await _settingsRepository
        .setGoogleSearchEngineId(id);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to save Google Search Engine ID: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(googleSearchEngineId: id)),
    );
  }

  /// Toggle Google Search enabled state
  Future<void> toggleGoogleSearch(bool enabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setGoogleSearchEnabled(enabled);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to toggle Google Search: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(googleSearchEnabled: enabled)),
    );
  }

  /// Load OpenWeather configuration
  Future<void> loadOpenWeatherConfig() async {
    final Either<Exception, String?> keyResult = await _settingsRepository
        .getOpenWeatherKey();
    final Either<Exception, bool> enabledResult = await _settingsRepository
        .getOpenWeatherEnabled();

    final String? key = keyResult.getOrElse((Exception _) => null);
    final bool enabled = enabledResult.getOrElse((Exception _) => true);

    emit(state.copyWith(openWeatherKey: key, openWeatherEnabled: enabled));
  }

  /// Update OpenWeather API key
  Future<void> updateOpenWeatherKey(String key) async {
    final Either<Exception, void> result = await _settingsRepository
        .setOpenWeatherKey(key);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to save OpenWeather key: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(openWeatherKey: key)),
    );
  }

  /// Toggle OpenWeather enabled state
  Future<void> toggleOpenWeather(bool enabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setOpenWeatherEnabled(enabled);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to toggle OpenWeather: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(openWeatherEnabled: enabled)),
    );
  }

  /// Load New York Times configuration
  Future<void> loadNewYorkTimesConfig() async {
    final Either<Exception, String?> keyResult = await _settingsRepository
        .getNewYorkTimesKey();
    final Either<Exception, bool> enabledResult = await _settingsRepository
        .getNewYorkTimesEnabled();

    final String? key = keyResult.getOrElse((Exception _) => null);
    final bool enabled = enabledResult.getOrElse((Exception _) => true);

    emit(state.copyWith(newYorkTimesKey: key, newYorkTimesEnabled: enabled));
  }

  /// Update New York Times API key
  Future<void> updateNewYorkTimesKey(String key) async {
    final Either<Exception, void> result = await _settingsRepository
        .setNewYorkTimesKey(key);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to save New York Times key: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(newYorkTimesKey: key)),
    );
  }

  /// Toggle New York Times enabled state
  Future<void> toggleNewYorkTimes(bool enabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setNewYorkTimesEnabled(enabled);
    result.fold(
      (Exception error) => AppLogger.error(
        'Failed to toggle New York Times: $error',
        tag: 'SettingsCubit',
        error: error,
      ),
      (_) => emit(state.copyWith(newYorkTimesEnabled: enabled)),
    );
  }

  /// Load all function calling configurations at once
  Future<void> loadFunctionCallingConfigs() async {
    await loadGoogleSearchConfig();
    await loadOpenWeatherConfig();
    await loadNewYorkTimesConfig();
  }
}
