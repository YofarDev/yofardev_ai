import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/llm_config.dart';
import '../../models/llm_task_type.dart';
import '../../models/task_llm_config.dart';
import '../../utils/logger.dart';
import '../../services/settings_local_datasource.dart';

class LlmConfigManager {
  static const String _configsKey = 'llm_configs';
  static const String _currentConfigIdKey = 'current_llm_config_id';

  final SettingsLocalDatasource _settingsDatasource;

  LlmConfigManager({required SettingsLocalDatasource settingsDatasource})
    : _settingsDatasource = settingsDatasource;

  List<LlmConfig> _configs = <LlmConfig>[];
  String? _currentConfigId;

  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? configsJson = prefs.getString(_configsKey);
    if (configsJson != null) {
      try {
        final List<dynamic> list = json.decode(configsJson) as List<dynamic>;
        _configs = list
            .map((dynamic e) => LlmConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        AppLogger.error(
          'Error loading LLM configs',
          tag: 'LlmConfigManager',
          error: e,
        );
      }
    }

    _currentConfigId = prefs.getString(_currentConfigIdKey);
  }

  List<LlmConfig> getAllConfigs() => List<LlmConfig>.unmodifiable(_configs);

  LlmConfig? getCurrentConfig() {
    if (_currentConfigId == null) {
      if (_configs.isNotEmpty) return _configs.first;
      return null;
    }
    try {
      return _configs.firstWhere((LlmConfig c) => c.id == _currentConfigId);
    } catch (_) {
      if (_configs.isNotEmpty) return _configs.first;
      return null;
    }
  }

  Future<void> saveConfig(LlmConfig config) async {
    final int index = _configs.indexWhere((LlmConfig c) => c.id == config.id);
    if (index >= 0) {
      _configs[index] = config;
    } else {
      _configs.add(config);
    }
    await _saveToPrefs();

    if (_configs.length == 1) {
      await setCurrentConfig(config.id);
    }
  }

  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((LlmConfig c) => c.id == id);
    if (_currentConfigId == id) {
      _currentConfigId = _configs.isNotEmpty ? _configs.first.id : null;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_currentConfigId != null) {
        await prefs.setString(_currentConfigIdKey, _currentConfigId!);
      } else {
        await prefs.remove(_currentConfigIdKey);
      }
    }
    await _saveToPrefs();
  }

  Future<void> setCurrentConfig(String id) async {
    if (_configs.any((LlmConfig c) => c.id == id)) {
      _currentConfigId = id;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentConfigIdKey, id);
    }
  }

  Future<void> _saveToPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      _configs.map((LlmConfig c) => c.toJson()).toList(),
    );
    await prefs.setString(_configsKey, jsonString);
  }

  Future<TaskLlmConfig> _getTaskConfigFromSettings() async {
    try {
      final Either<Exception, TaskLlmConfig> result = await _settingsDatasource
          .getTaskLlmConfig();
      return result.getOrElse((_) => const TaskLlmConfig());
    } catch (e) {
      AppLogger.error(
        'Failed to load task config',
        tag: 'LlmConfigManager',
        error: e,
      );
      return const TaskLlmConfig();
    }
  }

  String? _getConfigIdForTask(LlmTaskType task, TaskLlmConfig config) {
    switch (task) {
      case LlmTaskType.assistant:
        return config.assistantLlmId;
      case LlmTaskType.titleGeneration:
        return config.titleGenerationLlmId;
      case LlmTaskType.functionCalling:
        return config.functionCallingLlmId;
    }
  }

  Future<LlmConfig?> getConfigForTask(LlmTaskType task) async {
    try {
      final TaskLlmConfig taskConfig = await _getTaskConfigFromSettings();
      final String? configId = _getConfigIdForTask(task, taskConfig);

      if (configId != null) {
        try {
          return _configs.firstWhere((LlmConfig c) => c.id == configId);
        } catch (e) {
          AppLogger.warning(
            'Task-specific LLM config not found: $configId for task ${task.name}',
            tag: 'LlmConfigManager',
          );
        }
      }

      final LlmConfig? defaultConfig = getCurrentConfig();
      if (defaultConfig == null) {
        AppLogger.error(
          'No LLM configuration available for task: ${task.name}',
          tag: 'LlmConfigManager',
        );
      }
      return defaultConfig;
    } catch (e) {
      AppLogger.error(
        'Failed to get config for task: ${task.name}',
        tag: 'LlmConfigManager',
        error: e,
      );
      return getCurrentConfig();
    }
  }
}
