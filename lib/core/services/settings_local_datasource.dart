import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart';
import '../models/task_llm_config.dart';
import '../utils/app_utils.dart';

class SettingsLocalDatasource {
  static const String _keyTaskLlmConfig = 'task_llm_config';

  // Function Calling Configuration Keys
  static const String _googleSearchKeyKey = 'google_search_key';
  static const String _googleSearchEngineIdKey = 'google_search_engine_id';
  static const String _googleSearchEnabledKey = 'google_search_enabled';
  static const String _openWeatherKeyKey = 'open_weather_key';
  static const String _openWeatherEnabledKey = 'open_weather_enabled';
  static const String _newYorkTimesKeyKey = 'new_york_times_key';
  static const String _newYorkTimesEnabledKey = 'new_york_times_enabled';

  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_keyTaskLlmConfig);

      if (json == null) {
        const TaskLlmConfig defaultConfig = TaskLlmConfig();
        return const Right<Exception, TaskLlmConfig>(defaultConfig);
      }

      final Map<String, dynamic> data =
          jsonDecode(json) as Map<String, dynamic>;
      final TaskLlmConfig parsedConfig = TaskLlmConfig.fromJson(data);
      return Right<Exception, TaskLlmConfig>(parsedConfig);
    } catch (e) {
      return Left<Exception, TaskLlmConfig>(
        Exception('Failed to load task LLM config: $e'),
      );
    }
  }

  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(config.toJson());
      await prefs.setString(_keyTaskLlmConfig, json);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(
        Exception('Failed to save task LLM config: $e'),
      );
    }
  }

  Future<void> setPersona(ChatPersona persona) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('persona', persona.name);
  }

  Future<ChatPersona> getPersona() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? persona = prefs.getString('persona');
    return persona != null
        ? ChatPersona.values.byName(persona)
        : ChatPersona.normal;
  }

  Future<void> setUsername(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<void> setLanguage(String language) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
  }

  Future<String?> getLanguage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('language');
  }

  Future<void> setBaseSystemPrompt(String baseSystemPrompt) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseSystemPrompt', baseSystemPrompt);
  }

  Future<String> getBaseSystemPrompt(String languageCode) async {
    final String baseSystemPrompt = await rootBundle.loadString(
      AppUtils.fixAssetsPath('assets/txt/system_prompt_$languageCode.txt'),
    );
    return baseSystemPrompt;
  }

  Future<void> setSoundEffects(bool soundEffects) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEffects', soundEffects);
  }

  Future<bool> getSoundEffects() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('soundEffects') ?? true;
  }

  Future<void> setTtsVoice(String name, String language) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ttsVoice_$language', name);
  }

  // Function Calling Configuration - Google Search
  Future<Either<Exception, String>> getGoogleSearchKey() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = prefs.getString(_googleSearchKeyKey) ?? '';
      return Right<Exception, String>(key);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_googleSearchKeyKey, key);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, String>> getGoogleSearchEngineId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String engineId = prefs.getString(_googleSearchEngineIdKey) ?? '';
      return Right<Exception, String>(engineId);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setGoogleSearchEngineId(
    String engineId,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_googleSearchEngineIdKey, engineId);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool(_googleSearchEnabledKey) ?? true;
      return Right<Exception, bool>(enabled);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_googleSearchEnabledKey, enabled);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  // Function Calling Configuration - OpenWeather
  Future<Either<Exception, String>> getOpenWeatherKey() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = prefs.getString(_openWeatherKeyKey) ?? '';
      return Right<Exception, String>(key);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_openWeatherKeyKey, key);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool(_openWeatherEnabledKey) ?? true;
      return Right<Exception, bool>(enabled);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_openWeatherEnabledKey, enabled);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  // Function Calling Configuration - New York Times
  Future<Either<Exception, String>> getNewYorkTimesKey() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = prefs.getString(_newYorkTimesKeyKey) ?? '';
      return Right<Exception, String>(key);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_newYorkTimesKeyKey, key);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool(_newYorkTimesEnabledKey) ?? true;
      return Right<Exception, bool>(enabled);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }

  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_newYorkTimesEnabledKey, enabled);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }
}
