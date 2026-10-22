import '../../../../core/models/chat.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _datasource = SettingsLocalDatasource();

  @override
  Future<Result<String?>> getLanguage() async {
    try {
      final String? language = await _datasource.getLanguage();
      return Result<String?>.ok(language);
    } catch (e) {
      return Result<String?>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setLanguage(String language) async {
    try {
      await _datasource.setLanguage(language);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<bool>> getSoundEffects() async {
    try {
      final bool enabled = await _datasource.getSoundEffects();
      return Result<bool>.ok(enabled);
    } catch (e) {
      return Result<bool>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setSoundEffects(bool enabled) async {
    try {
      await _datasource.setSoundEffects(enabled);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<String?>> getUsername() async {
    try {
      final String? username = await _datasource.getUsername();
      return Result<String?>.ok(username);
    } catch (e) {
      return Result<String?>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setUsername(String username) async {
    try {
      await _datasource.setUsername(username);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<String>> getSystemPrompt() async {
    try {
      final String? language = await _datasource.getLanguage();
      final String prompt = await _datasource.getBaseSystemPrompt(
        language ?? 'fr',
      );
      return Result<String>.ok(prompt);
    } catch (e) {
      return Result<String>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setSystemPrompt(String prompt) async {
    try {
      await _datasource.setBaseSystemPrompt(prompt);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<ChatPersona>> getPersona() async {
    try {
      final ChatPersona persona = await _datasource.getPersona();
      return Result<ChatPersona>.ok(persona);
    } catch (e) {
      return Result<ChatPersona>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setPersona(ChatPersona persona) async {
    try {
      await _datasource.setPersona(persona);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<TaskLlmConfig>> getTaskLlmConfig() async {
    return _datasource.getTaskLlmConfig();
  }

  @override
  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return _datasource.setTaskLlmConfig(config);
  }

  // Function Calling Configuration - Google Search
  @override
  Future<Result<String?>> getGoogleSearchKey() async {
    final Result<String> result = await _datasource.getGoogleSearchKey();
    return result.when(
      err: (Failure failure) => Result<String?>.err(failure),
      ok: (String right) => Result<String?>.ok(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Result<void>> setGoogleSearchKey(String key) async {
    final Result<void> result = await _datasource.setGoogleSearchKey(key);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  @override
  Future<Result<String?>> getGoogleSearchEngineId() async {
    final Result<String> result = await _datasource.getGoogleSearchEngineId();
    return result.when(
      err: (Failure failure) => Result<String?>.err(failure),
      ok: (String right) => Result<String?>.ok(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Result<void>> setGoogleSearchEngineId(String id) async {
    final Result<void> result = await _datasource.setGoogleSearchEngineId(id);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  @override
  Future<Result<bool>> getGoogleSearchEnabled() async {
    final Result<bool> result = await _datasource.getGoogleSearchEnabled();
    return result.when(
      err: (Failure failure) => Result<bool>.err(failure),
      ok: (bool right) => Result<bool>.ok(right),
    );
  }

  @override
  Future<Result<void>> setGoogleSearchEnabled(bool enabled) async {
    final Result<void> result = await _datasource.setGoogleSearchEnabled(
      enabled,
    );
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  // Function Calling Configuration - OpenWeather
  @override
  Future<Result<String?>> getOpenWeatherKey() async {
    final Result<String> result = await _datasource.getOpenWeatherKey();
    return result.when(
      err: (Failure failure) => Result<String?>.err(failure),
      ok: (String right) => Result<String?>.ok(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Result<void>> setOpenWeatherKey(String key) async {
    final Result<void> result = await _datasource.setOpenWeatherKey(key);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  @override
  Future<Result<bool>> getOpenWeatherEnabled() async {
    final Result<bool> result = await _datasource.getOpenWeatherEnabled();
    return result.when(
      err: (Failure failure) => Result<bool>.err(failure),
      ok: (bool right) => Result<bool>.ok(right),
    );
  }

  @override
  Future<Result<void>> setOpenWeatherEnabled(bool enabled) async {
    final Result<void> result = await _datasource.setOpenWeatherEnabled(enabled);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  // Function Calling Configuration - New York Times
  @override
  Future<Result<String?>> getNewYorkTimesKey() async {
    final Result<String> result = await _datasource.getNewYorkTimesKey();
    return result.when(
      err: (Failure failure) => Result<String?>.err(failure),
      ok: (String right) => Result<String?>.ok(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Result<void>> setNewYorkTimesKey(String key) async {
    final Result<void> result = await _datasource.setNewYorkTimesKey(key);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  @override
  Future<Result<bool>> getNewYorkTimesEnabled() async {
    final Result<bool> result = await _datasource.getNewYorkTimesEnabled();
    return result.when(
      err: (Failure failure) => Result<bool>.err(failure),
      ok: (bool right) => Result<bool>.ok(right),
    );
  }

  @override
  Future<Result<void>> setNewYorkTimesEnabled(bool enabled) async {
    final Result<void> result = await _datasource.setNewYorkTimesEnabled(
      enabled,
    );
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }

  // Global Memory Configuration
  @override
  Future<Result<bool>> getMemoryEnabled() async {
    final Result<bool> result = await _datasource.getMemoryEnabled();
    return result.when(
      err: (Failure failure) => Result<bool>.err(failure),
      ok: (bool right) => Result<bool>.ok(right),
    );
  }

  @override
  Future<Result<void>> setMemoryEnabled(bool enabled) async {
    final Result<void> result = await _datasource.setMemoryEnabled(enabled);
    return result.when(
      err: (Failure failure) => Result<void>.err(failure),
      ok: (void right) => Result<void>.ok(null),
    );
  }
}
