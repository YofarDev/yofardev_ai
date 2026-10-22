import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/llm_config.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/global_memory.dart';
import '../../../../core/models/result.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../../chat/chat.dart';
import '../../../../core/repositories/settings_repository.dart';
import 'settings_state.dart';

/// Cubit for managing application settings
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required LlmServiceInterface llmService,
    GlobalMemoryRepository? globalMemoryRepository,
  }) : _settingsRepository = settingsRepository,
       _llmService = llmService,
       _globalMemoryRepository = globalMemoryRepository,
       super(SettingsState.initial());

  final SettingsRepository _settingsRepository;
  final LlmServiceInterface _llmService;
  final GlobalMemoryRepository? _globalMemoryRepository;

  /// Load all settings
  Future<void> loadSettings() async {
    // Load user settings
    await loadCurrentLanguage();
    await loadUsername();
    await loadSystemPrompt();
    await loadPersona();

    // Load task LLM config
    await loadTaskLlmConfig();

    // Load function calling configurations
    await loadFunctionCallingConfigs();

    // Load global memory state
    await loadMemoryEnabled();
    await loadGlobalMemory();

    // Load available LLM configs
    try {
      await refreshLlmConfigs();
    } catch (e) {
      AppLogger.error(
        'Failed to load available LLM configs',
        tag: 'SettingsCubit',
        error: e,
      );
      emit(
        state.copyWith(
          hasError: true,
          error: ConfigFailure('Failed to load available LLM configs'),
        ),
      );
    }
  }

  /// Initialize the LLM config manager and refresh config-derived state.
  Future<void> refreshLlmConfigs() async {
    await _llmService.init();
    final List<LlmConfig> configs = _llmService.getAllConfigs();
    final String? selectedId = _llmService.getCurrentConfig()?.id;
    emit(
      state.copyWith(
        availableLlmConfigs: configs,
        selectedLlmConfigId: selectedId,
      ),
    );
  }

  /// Delete an LLM config by [id] and refresh the cached config list.
  Future<void> deleteLlmConfig(String id) async {
    await _llmService.deleteConfig(id);
    await refreshLlmConfigs();
  }

  /// Set the currently active LLM config to [id] and refresh state.
  Future<void> setCurrentLlmConfig(String id) async {
    await _llmService.setCurrentConfig(id);
    await refreshLlmConfigs();
  }

  /// Persist [config] and refresh the cached config list.
  Future<void> saveLlmConfig(LlmConfig config) async {
    await _llmService.saveConfig(config);
    await refreshLlmConfigs();
  }

  /// Load the task-specific LLM configuration
  Future<void> loadTaskLlmConfig() async {
    final Result<TaskLlmConfig> result = await _settingsRepository
        .getTaskLlmConfig();
    result.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to load task LLM config',
          tag: 'SettingsCubit',
          error: failure,
        );
        emit(state.copyWith(taskLlmConfig: const TaskLlmConfig()));
      },
      ok: (TaskLlmConfig config) => emit(state.copyWith(taskLlmConfig: config)),
    );
  }

  /// Save the task-specific LLM configuration
  Future<void> setTaskLlmConfig(TaskLlmConfig config) async {
    final Result<void> result = await _settingsRepository.setTaskLlmConfig(
      config,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to save task LLM config',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(taskLlmConfig: config)),
    );
  }

  /// Set the system prompt
  Future<void> setSystemPrompt(String prompt) async {
    final Result<void> result = await _settingsRepository.setSystemPrompt(
      prompt,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to set system prompt',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(systemPrompt: prompt)),
    );
  }

  /// Set the username
  Future<void> setUsername(String username) async {
    final Result<void> result = await _settingsRepository.setUsername(username);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to set username',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(username: username)),
    );
  }

  /// Set the persona
  Future<void> setPersona(ChatPersona persona) async {
    final Result<void> result = await _settingsRepository.setPersona(persona);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to set persona',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(persona: persona)),
    );
  }

  /// Load the username
  Future<void> loadUsername() async {
    final Result<String?> result = await _settingsRepository.getUsername();
    result.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to load username',
          tag: 'SettingsCubit',
          error: failure,
        );
        emit(state.copyWith(username: null));
      },
      ok: (String? username) => emit(state.copyWith(username: username)),
    );
  }

  /// Load the system prompt
  Future<void> loadSystemPrompt() async {
    final Result<String> result = await _settingsRepository.getSystemPrompt();
    result.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to load system prompt',
          tag: 'SettingsCubit',
          error: failure,
        );
        emit(state.copyWith(systemPrompt: null));
      },
      ok: (String prompt) => emit(state.copyWith(systemPrompt: prompt)),
    );
  }

  /// Load the persona
  Future<void> loadPersona() async {
    final Result<ChatPersona> result = await _settingsRepository.getPersona();
    result.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to load persona',
          tag: 'SettingsCubit',
          error: failure,
        );
        emit(state.copyWith(persona: ChatPersona.assistant));
      },
      ok: (ChatPersona persona) => emit(state.copyWith(persona: persona)),
    );
  }

  /// Load Google Search configuration
  Future<void> loadGoogleSearchConfig() async {
    final Result<String?> keyResult = await _settingsRepository
        .getGoogleSearchKey();
    final Result<String?> idResult = await _settingsRepository
        .getGoogleSearchEngineId();
    final Result<bool> enabledResult = await _settingsRepository
        .getGoogleSearchEnabled();

    final String? key = keyResult.getOrNull;
    final String? id = idResult.getOrNull;
    final bool enabled = enabledResult.getOrNull ?? true;

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
    final Result<void> result = await _settingsRepository.setGoogleSearchKey(
      key,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to save Google Search key',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(googleSearchKey: key)),
    );
  }

  /// Update Google Search Engine ID
  Future<void> updateGoogleSearchEngineId(String id) async {
    final Result<void> result = await _settingsRepository
        .setGoogleSearchEngineId(id);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to save Google Search Engine ID',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(googleSearchEngineId: id)),
    );
  }

  /// Toggle Google Search enabled state
  Future<void> toggleGoogleSearch(bool enabled) async {
    final Result<void> result = await _settingsRepository
        .setGoogleSearchEnabled(enabled);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to toggle Google Search',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(googleSearchEnabled: enabled)),
    );
  }

  /// Load OpenWeather configuration
  Future<void> loadOpenWeatherConfig() async {
    final Result<String?> keyResult = await _settingsRepository
        .getOpenWeatherKey();
    final Result<bool> enabledResult = await _settingsRepository
        .getOpenWeatherEnabled();

    final String? key = keyResult.getOrNull;
    final bool enabled = enabledResult.getOrNull ?? true;

    emit(state.copyWith(openWeatherKey: key, openWeatherEnabled: enabled));
  }

  /// Update OpenWeather API key
  Future<void> updateOpenWeatherKey(String key) async {
    final Result<void> result = await _settingsRepository.setOpenWeatherKey(
      key,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to save OpenWeather key',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(openWeatherKey: key)),
    );
  }

  /// Toggle OpenWeather enabled state
  Future<void> toggleOpenWeather(bool enabled) async {
    final Result<void> result = await _settingsRepository.setOpenWeatherEnabled(
      enabled,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to toggle OpenWeather',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(openWeatherEnabled: enabled)),
    );
  }

  /// Load New York Times configuration
  Future<void> loadNewYorkTimesConfig() async {
    final Result<String?> keyResult = await _settingsRepository
        .getNewYorkTimesKey();
    final Result<bool> enabledResult = await _settingsRepository
        .getNewYorkTimesEnabled();

    final String? key = keyResult.getOrNull;
    final bool enabled = enabledResult.getOrNull ?? true;

    emit(state.copyWith(newYorkTimesKey: key, newYorkTimesEnabled: enabled));
  }

  /// Update New York Times API key
  Future<void> updateNewYorkTimesKey(String key) async {
    final Result<void> result = await _settingsRepository.setNewYorkTimesKey(
      key,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to save New York Times key',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(newYorkTimesKey: key)),
    );
  }

  /// Toggle New York Times enabled state
  Future<void> toggleNewYorkTimes(bool enabled) async {
    final Result<void> result = await _settingsRepository
        .setNewYorkTimesEnabled(enabled);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to toggle New York Times',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(newYorkTimesEnabled: enabled)),
    );
  }

  /// Load all function calling configurations at once
  Future<void> loadFunctionCallingConfigs() async {
    await loadGoogleSearchConfig();
    await loadOpenWeatherConfig();
    await loadNewYorkTimesConfig();
  }

  /// Load the current language
  Future<void> loadCurrentLanguage() async {
    final Result<String?> result = await _settingsRepository.getLanguage();
    result.when(
      err: (Failure failure) => emit(state.copyWith(currentLanguage: 'fr')),
      ok: (String? language) =>
          emit(state.copyWith(currentLanguage: language ?? 'fr')),
    );
  }

  /// Set the current language
  Future<void> setCurrentLanguage(String language) async {
    final Result<void> result = await _settingsRepository.setLanguage(language);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to set language',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(currentLanguage: language)),
    );
  }

  /// Load sound effects enabled setting
  Future<void> loadSoundEffects() async {
    final Result<bool> result = await _settingsRepository.getSoundEffects();
    result.when(
      err: (Failure failure) =>
          emit(state.copyWith(soundEffectsEnabled: false)),
      ok: (bool enabled) => emit(state.copyWith(soundEffectsEnabled: enabled)),
    );
  }

  /// Set sound effects enabled setting
  Future<void> setSoundEffects(bool soundEffectsEnabled) async {
    final Result<void> result = await _settingsRepository.setSoundEffects(
      soundEffectsEnabled,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to set sound effects',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled)),
    );
  }

  /// Load the global memory enabled setting
  Future<void> loadMemoryEnabled() async {
    final Result<bool> result = await _settingsRepository.getMemoryEnabled();
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to load memory enabled setting',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (bool enabled) => emit(state.copyWith(memoryEnabled: enabled)),
    );
  }

  /// Toggle the global memory feature
  Future<void> setMemoryEnabled(bool enabled) async {
    final Result<void> result = await _settingsRepository.setMemoryEnabled(
      enabled,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to toggle global memory',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(memoryEnabled: enabled)),
    );
  }

  /// Reload the global memory items from storage
  ///
  /// Memory is also updated in the background by the chat feature, so pages
  /// should call this when shown to refresh potentially stale items.
  Future<void> loadGlobalMemory() async {
    if (_globalMemoryRepository == null) return;
    final Result<GlobalMemory> result = await _globalMemoryRepository
        .getMemory();
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to load global memory',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (GlobalMemory memory) =>
          emit(state.copyWith(memoryItems: memory.items)),
    );
  }

  /// Delete a single global memory item
  Future<void> deleteMemoryItem(String id) async {
    if (_globalMemoryRepository == null) return;
    final Result<GlobalMemory> result = await _globalMemoryRepository
        .deleteItem(id);
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to delete memory item',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (GlobalMemory memory) =>
          emit(state.copyWith(memoryItems: memory.items)),
    );
  }

  /// Clear all global memory items
  Future<void> clearMemory() async {
    if (_globalMemoryRepository == null) return;
    final Result<void> result = await _globalMemoryRepository.clearAll();
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to clear global memory',
        tag: 'SettingsCubit',
        error: failure,
      ),
      ok: (_) => emit(state.copyWith(memoryItems: <GlobalMemoryItem>[])),
    );
  }
}
