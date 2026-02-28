import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm/function_info.dart';
import '../models/llm/llm_config.dart';
import '../models/llm/llm_message.dart';
import '../utils/logger.dart';
import 'llm/llm_api_helper.dart';
import 'llm/llm_exceptions.dart';
import 'llm/llm_function_calling.dart';

class LlmService {
  static const String _configsKey = 'llm_configs';
  static const String _currentConfigIdKey = 'current_llm_config_id';
  static const String _detectedFormatsKey = 'llm_detected_formats';

  static final LlmService _instance = LlmService._internal();

  factory LlmService() {
    return _instance;
  }

  LlmService._internal();

  List<LlmConfig> _configs = <LlmConfig>[];
  String? _currentConfigId;
  final Map<String, ResponseFormatType> _detectedFormats =
      <String, ResponseFormatType>{};

  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? configsJson = prefs.getString(_configsKey);
    if (configsJson != null) {
      try {
        final List<dynamic> list = json.decode(configsJson) as List<dynamic>;
        _configs = list
            .map((dynamic e) => LlmConfig.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        AppLogger.error('Error loading LLM configs: $e', tag: 'LlmService');
      }
    }

    _currentConfigId = prefs.getString(_currentConfigIdKey);

    // Load detected response formats
    final String? detectedFormatsJson = prefs.getString(_detectedFormatsKey);
    if (detectedFormatsJson != null) {
      try {
        final Map<String, dynamic> map =
            json.decode(detectedFormatsJson) as Map<String, dynamic>;
        map.forEach((String key, dynamic value) {
          if (value is String) {
            _detectedFormats[key] = ResponseFormatType.values.firstWhere(
              (ResponseFormatType e) => e.name == value,
              orElse: () => ResponseFormatType.jsonSchema,
            );
          }
        });
      } catch (e) {
        AppLogger.error(
          'Error loading detected formats: $e',
          tag: 'LlmService',
        );
      }
    }
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
      _configs.map((LlmConfig c) => c.toMap()).toList(),
    );
    await prefs.setString(_configsKey, jsonString);

    // Save detected formats
    final Map<String, String> formatsMap = <String, String>{};
    _detectedFormats.forEach((String key, ResponseFormatType value) {
      formatsMap[key] = value.name;
    });
    await prefs.setString(_detectedFormatsKey, json.encode(formatsMap));
  }

  Future<void> _saveDetectedFormat(
    String configId,
    ResponseFormatType format,
  ) async {
    _detectedFormats[configId] = format;
    await _saveToPrefs();
    AppLogger.debug(
      'Saved detected format for $configId: ${format.name}',
      tag: 'LlmService',
    );
  }

  /// Prompt the LLM model with optional JSON response and automatic format detection
  Future<String?> promptModel({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  }) async {
    final LlmConfig? activeConfig = config ?? getCurrentConfig();
    if (activeConfig == null) {
      throw Exception('No LLM Configuration selected.');
    }

    // If not requesting JSON, just call directly without response_format
    if (!returnJson) {
      return LlmApiHelper.promptModelWithFormat(
        messages: messages,
        systemPrompt: systemPrompt,
        config: activeConfig,
        responseFormatType: ResponseFormatType.none,
        debugLogs: debugLogs,
      );
    }

    // Determine which format to use
    ResponseFormatType formatToTry;

    // Check if we have a previously detected format for this config
    if (_detectedFormats.containsKey(activeConfig.id)) {
      formatToTry = _detectedFormats[activeConfig.id]!;
      if (debugLogs) {
        AppLogger.debug(
          'Using previously detected format: ${formatToTry.name}',
          tag: 'LlmService',
        );
      }
    } else {
      // Use the configured format
      formatToTry = activeConfig.responseFormatType;
      if (debugLogs) {
        AppLogger.debug(
          'Using configured format: ${formatToTry.name}',
          tag: 'LlmService',
        );
      }
    }

    // Try the initial format
    String? result;
    try {
      result = await LlmApiHelper.promptModelWithFormat(
        messages: messages,
        systemPrompt: systemPrompt,
        config: activeConfig,
        responseFormatType: formatToTry,
        debugLogs: debugLogs,
      );
    } on ResponseFormatException {
      if (debugLogs) {
        AppLogger.debug(
          'Response format not accepted, will try fallback',
          tag: 'LlmService',
        );
      }
      result = null;
    }

    if (result != null) {
      return result;
    }

    // If initial attempt failed and we haven't auto-detected yet, try fallback
    if (!_detectedFormats.containsKey(activeConfig.id)) {
      if (debugLogs) {
        AppLogger.debug(
          'Initial format failed, trying automatic detection...',
          tag: 'LlmService',
        );
      }

      // Try other formats in order
      final List<ResponseFormatType> fallbackFormats = <ResponseFormatType>[
        ResponseFormatType.jsonSchema,
        ResponseFormatType.jsonObject,
        ResponseFormatType.text,
        ResponseFormatType.none,
      ];

      for (final ResponseFormatType format in fallbackFormats) {
        if (format == formatToTry) continue; // Skip the one we already tried

        if (debugLogs) {
          AppLogger.debug(
            'Trying fallback format: ${format.name}',
            tag: 'LlmService',
          );
        }

        String? fallbackResult;
        try {
          fallbackResult = await LlmApiHelper.promptModelWithFormat(
            messages: messages,
            systemPrompt: systemPrompt,
            config: activeConfig,
            responseFormatType: format,
            debugLogs: debugLogs,
          );
        } on ResponseFormatException {
          // This format also doesn't work, try next one
          if (debugLogs) {
            AppLogger.debug(
              'Format ${format.name} not accepted',
              tag: 'LlmService',
            );
          }
          continue;
        }

        if (fallbackResult != null) {
          // Success! Save this format for future use
          await _saveDetectedFormat(activeConfig.id, format);
          if (debugLogs) {
            AppLogger.debug(
              'Auto-detected working format: ${format.name}',
              tag: 'LlmService',
            );
          }
          return fallbackResult;
        }
      }
    }

    // All formats failed
    if (debugLogs) {
      AppLogger.debug('All response format attempts failed', tag: 'LlmService');
    }
    return null;
  }

  /// Check if the LLM wants to call any functions
  Future<(String, List<FunctionInfo>)> checkFunctionsCalling({
    required LlmConfig api,
    required List<FunctionInfo> functions,
    required List<LlmMessage> messages,
    required String lastUserMessage,
  }) async {
    return LlmFunctionCallingHelper.checkFunctionsCalling(
      api: api,
      functions: functions,
      messages: messages,
      lastUserMessage: lastUserMessage,
    );
  }
}
