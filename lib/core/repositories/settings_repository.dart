// Stays in core: consumed by core/services/agent (ToolRegistry); core may not import features.
import '../models/chat.dart';
import '../models/result.dart';
import '../models/task_llm_config.dart';

abstract class SettingsRepository {
  Future<Result<String?>> getLanguage();
  Future<Result<void>> setLanguage(String language);
  Future<Result<bool>> getSoundEffects();
  Future<Result<void>> setSoundEffects(bool enabled);
  Future<Result<String?>> getUsername();
  Future<Result<void>> setUsername(String username);
  Future<Result<String>> getSystemPrompt();
  Future<Result<void>> setSystemPrompt(String prompt);
  Future<Result<ChatPersona>> getPersona();
  Future<Result<void>> setPersona(ChatPersona persona);

  // NEW METHODS:
  /// Get the task-specific LLM configuration
  Future<Result<TaskLlmConfig>> getTaskLlmConfig();

  /// Save the task-specific LLM configuration
  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config);

  // Function Calling Configuration - Google Search
  Future<Result<String?>> getGoogleSearchKey();
  Future<Result<void>> setGoogleSearchKey(String key);
  Future<Result<String?>> getGoogleSearchEngineId();
  Future<Result<void>> setGoogleSearchEngineId(String id);
  Future<Result<bool>> getGoogleSearchEnabled();
  Future<Result<void>> setGoogleSearchEnabled(bool enabled);

  // Function Calling Configuration - OpenWeather
  Future<Result<String?>> getOpenWeatherKey();
  Future<Result<void>> setOpenWeatherKey(String key);
  Future<Result<bool>> getOpenWeatherEnabled();
  Future<Result<void>> setOpenWeatherEnabled(bool enabled);

  // Function Calling Configuration - New York Times
  Future<Result<String?>> getNewYorkTimesKey();
  Future<Result<void>> setNewYorkTimesKey(String key);
  Future<Result<bool>> getNewYorkTimesEnabled();
  Future<Result<void>> setNewYorkTimesEnabled(bool enabled);

  // Global Memory Configuration
  Future<Result<bool>> getMemoryEnabled();
  Future<Result<void>> setMemoryEnabled(bool enabled);

  // Live captions on the Home stage (default on)
  Future<Result<bool>> getCaptionsEnabled();
  Future<Result<void>> setCaptionsEnabled(bool enabled);
}
