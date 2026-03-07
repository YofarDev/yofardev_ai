import 'package:dartz/dartz.dart' as dartz;
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/services/settings_local_datasource.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _datasource = SettingsLocalDatasource();

  @override
  Future<Either<Exception, String?>> getLanguage() async {
    try {
      final String? language = await _datasource.getLanguage();
      return Right<Exception, String?>(language);
    } catch (e) {
      return Left<Exception, String?>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    try {
      await _datasource.setLanguage(language);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    try {
      final bool enabled = await _datasource.getSoundEffects();
      return Right<Exception, bool>(enabled);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool enabled) async {
    try {
      await _datasource.setSoundEffects(enabled);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    try {
      final String? username = await _datasource.getUsername();
      return Right<Exception, String?>(username);
    } catch (e) {
      return Left<Exception, String?>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    try {
      await _datasource.setUsername(username);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    try {
      final String prompt = await _datasource.getBaseSystemPrompt();
      return Right<Exception, String>(prompt);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    try {
      await _datasource.setBaseSystemPrompt(prompt);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    try {
      final ChatPersona persona = await _datasource.getPersona();
      return Right<Exception, ChatPersona>(persona);
    } catch (e) {
      return Left<Exception, ChatPersona>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    try {
      await _datasource.setPersona(persona);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    final dartz.Either<Exception, TaskLlmConfig> dartzResult = await _datasource
        .getTaskLlmConfig();
    return dartzResult.fold(
      (Exception left) => Left<Exception, TaskLlmConfig>(left),
      (TaskLlmConfig right) => Right<Exception, TaskLlmConfig>(right),
    );
  }

  @override
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    final dartz.Either<Exception, void> dartzResult = await _datasource
        .setTaskLlmConfig(config);
    return dartzResult.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => Right<Exception, void>(right),
    );
  }

  // Function Calling Configuration - Google Search
  @override
  Future<Either<Exception, String?>> getGoogleSearchKey() async {
    final dartz.Either<Exception, String> result = await _datasource.getGoogleSearchKey();
    return result.fold(
      (Exception left) => Left<Exception, String?>(left),
      (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
    final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchKey(key);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  @override
  Future<Either<Exception, String?>> getGoogleSearchEngineId() async {
    final dartz.Either<Exception, String> result = await _datasource.getGoogleSearchEngineId();
    return result.fold(
      (Exception left) => Left<Exception, String?>(left),
      (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEngineId(String id) async {
    final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchEngineId(id);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  @override
  Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
    final dartz.Either<Exception, bool> result = await _datasource.getGoogleSearchEnabled();
    return result.fold(
      (Exception left) => Left<Exception, bool>(left),
      (bool right) => Right<Exception, bool>(right),
    );
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
    final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchEnabled(enabled);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  // Function Calling Configuration - OpenWeather
  @override
  Future<Either<Exception, String?>> getOpenWeatherKey() async {
    final dartz.Either<Exception, String> result = await _datasource.getOpenWeatherKey();
    return result.fold(
      (Exception left) => Left<Exception, String?>(left),
      (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
    final dartz.Either<Exception, void> result = await _datasource.setOpenWeatherKey(key);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  @override
  Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
    final dartz.Either<Exception, bool> result = await _datasource.getOpenWeatherEnabled();
    return result.fold(
      (Exception left) => Left<Exception, bool>(left),
      (bool right) => Right<Exception, bool>(right),
    );
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
    final dartz.Either<Exception, void> result = await _datasource.setOpenWeatherEnabled(enabled);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  // Function Calling Configuration - New York Times
  @override
  Future<Either<Exception, String?>> getNewYorkTimesKey() async {
    final dartz.Either<Exception, String> result = await _datasource.getNewYorkTimesKey();
    return result.fold(
      (Exception left) => Left<Exception, String?>(left),
      (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
    );
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
    final dartz.Either<Exception, void> result = await _datasource.setNewYorkTimesKey(key);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }

  @override
  Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
    final dartz.Either<Exception, bool> result = await _datasource.getNewYorkTimesEnabled();
    return result.fold(
      (Exception left) => Left<Exception, bool>(left),
      (bool right) => Right<Exception, bool>(right),
    );
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
    final dartz.Either<Exception, void> result = await _datasource.setNewYorkTimesEnabled(enabled);
    return result.fold(
      (Exception left) => Left<Exception, void>(left),
      (void right) => const Right<Exception, void>(null),
    );
  }
}
