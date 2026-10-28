import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/exception_mapper.dart';
import '../models/chat.dart';
import '../models/result.dart';
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

  // Global Memory Configuration
  static const String _memoryEnabledKey = 'memory_enabled';

  // Live captions
  static const String _captionsEnabledKey = 'captions_enabled';

  // Avatar quality tier probe
  static const String _qualityTierKey = 'quality_tier';
  static const String _qualityTierProbedAtKey = 'quality_tier_probed_at';

  // Generic helper methods to reduce boilerplate
  Future<Result<String>> _getStringKey(String keyName) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String value = prefs.getString(keyName) ?? '';
      return Result<String>.ok(value);
    } catch (e, st) {
      return Result<String>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
      );
    }
  }

  Future<Result<void>> _setStringKey(String keyName, String value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyName, value);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
      );
    }
  }

  Future<Result<bool>> _getBoolKey(String keyName, bool defaultValue) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool value = prefs.getBool(keyName) ?? defaultValue;
      return Result<bool>.ok(value);
    } catch (e, st) {
      return Result<bool>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
      );
    }
  }

  Future<Result<void>> _setBoolKey(String keyName, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyName, value);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
      );
    }
  }

  Future<Result<TaskLlmConfig>> getTaskLlmConfig() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_keyTaskLlmConfig);

      if (json == null) {
        return Result<TaskLlmConfig>.ok(const TaskLlmConfig());
      }

      final Map<String, dynamic> data =
          jsonDecode(json) as Map<String, dynamic>;
      final TaskLlmConfig parsedConfig = TaskLlmConfig.fromJson(data);
      return Result<TaskLlmConfig>.ok(parsedConfig);
    } catch (e, st) {
      return Result<TaskLlmConfig>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
      );
    }
  }

  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(config.toJson());
      await prefs.setString(_keyTaskLlmConfig, json);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'SettingsLocalDatasource',
        ),
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
  Future<Result<String>> getGoogleSearchKey() =>
      _getStringKey(_googleSearchKeyKey);

  Future<Result<void>> setGoogleSearchKey(String key) =>
      _setStringKey(_googleSearchKeyKey, key);

  Future<Result<String>> getGoogleSearchEngineId() =>
      _getStringKey(_googleSearchEngineIdKey);

  Future<Result<void>> setGoogleSearchEngineId(String engineId) =>
      _setStringKey(_googleSearchEngineIdKey, engineId);

  Future<Result<bool>> getGoogleSearchEnabled() =>
      _getBoolKey(_googleSearchEnabledKey, true);

  Future<Result<void>> setGoogleSearchEnabled(bool enabled) =>
      _setBoolKey(_googleSearchEnabledKey, enabled);

  // Function Calling Configuration - OpenWeather
  Future<Result<String>> getOpenWeatherKey() =>
      _getStringKey(_openWeatherKeyKey);

  Future<Result<void>> setOpenWeatherKey(String key) =>
      _setStringKey(_openWeatherKeyKey, key);

  Future<Result<bool>> getOpenWeatherEnabled() =>
      _getBoolKey(_openWeatherEnabledKey, true);

  Future<Result<void>> setOpenWeatherEnabled(bool enabled) =>
      _setBoolKey(_openWeatherEnabledKey, enabled);

  // Function Calling Configuration - New York Times
  Future<Result<String>> getNewYorkTimesKey() =>
      _getStringKey(_newYorkTimesKeyKey);

  Future<Result<void>> setNewYorkTimesKey(String key) =>
      _setStringKey(_newYorkTimesKeyKey, key);

  Future<Result<bool>> getNewYorkTimesEnabled() =>
      _getBoolKey(_newYorkTimesEnabledKey, true);

  Future<Result<void>> setNewYorkTimesEnabled(bool enabled) =>
      _setBoolKey(_newYorkTimesEnabledKey, enabled);

  // Global Memory Configuration
  Future<Result<bool>> getMemoryEnabled() =>
      _getBoolKey(_memoryEnabledKey, true);

  Future<Result<void>> setMemoryEnabled(bool enabled) =>
      _setBoolKey(_memoryEnabledKey, enabled);

  // Live captions
  Future<Result<bool>> getCaptionsEnabled() =>
      _getBoolKey(_captionsEnabledKey, true);

  Future<Result<void>> setCaptionsEnabled(bool enabled) =>
      _setBoolKey(_captionsEnabledKey, enabled);

  Future<Result<String>> getQualityTier() => _getStringKey(_qualityTierKey);

  Future<Result<void>> setQualityTier(String tier) =>
      _setStringKey(_qualityTierKey, tier);

  Future<Result<String>> getQualityTierProbedAt() =>
      _getStringKey(_qualityTierProbedAtKey);

  Future<Result<void>> setQualityTierProbedAt(String probedAt) =>
      _setStringKey(_qualityTierProbedAtKey, probedAt);
}
