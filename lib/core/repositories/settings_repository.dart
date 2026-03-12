import 'package:fpdart/fpdart.dart';

import '../models/chat.dart';
import '../models/task_llm_config.dart';

abstract class SettingsRepository {
  Future<Either<Exception, String?>> getLanguage();
  Future<Either<Exception, void>> setLanguage(String language);
  Future<Either<Exception, bool>> getSoundEffects();
  Future<Either<Exception, void>> setSoundEffects(bool enabled);
  Future<Either<Exception, String?>> getUsername();
  Future<Either<Exception, void>> setUsername(String username);
  Future<Either<Exception, String>> getSystemPrompt();
  Future<Either<Exception, void>> setSystemPrompt(String prompt);
  Future<Either<Exception, ChatPersona>> getPersona();
  Future<Either<Exception, void>> setPersona(ChatPersona persona);

  // NEW METHODS:
  /// Get the task-specific LLM configuration
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig();

  /// Save the task-specific LLM configuration
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config);

  // Function Calling Configuration - Google Search
  Future<Either<Exception, String?>> getGoogleSearchKey();
  Future<Either<Exception, void>> setGoogleSearchKey(String key);
  Future<Either<Exception, String?>> getGoogleSearchEngineId();
  Future<Either<Exception, void>> setGoogleSearchEngineId(String id);
  Future<Either<Exception, bool>> getGoogleSearchEnabled();
  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled);

  // Function Calling Configuration - OpenWeather
  Future<Either<Exception, String?>> getOpenWeatherKey();
  Future<Either<Exception, void>> setOpenWeatherKey(String key);
  Future<Either<Exception, bool>> getOpenWeatherEnabled();
  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled);

  // Function Calling Configuration - New York Times
  Future<Either<Exception, String?>> getNewYorkTimesKey();
  Future<Either<Exception, void>> setNewYorkTimesKey(String key);
  Future<Either<Exception, bool>> getNewYorkTimesEnabled();
  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled);
}
