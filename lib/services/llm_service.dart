import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm/function_info.dart';
import '../models/llm/llm_config.dart';
import '../models/llm/llm_message.dart';

class ResponseFormatException implements Exception {
  final String message;
  ResponseFormatException(this.message);

  @override
  String toString() => 'ResponseFormatException: $message';
}

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
        debugPrint('Error loading LLM configs: $e');
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
        debugPrint('Error loading detected formats: $e');
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
      return _configs.firstWhere(
        (LlmConfig c) => c.id == _currentConfigId,
      );
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
    final String jsonString =
        json.encode(_configs.map((LlmConfig c) => c.toMap()).toList());
    await prefs.setString(_configsKey, jsonString);

    // Save detected formats
    final Map<String, String> formatsMap = <String, String>{};
    _detectedFormats.forEach((String key, ResponseFormatType value) {
      formatsMap[key] = value.name;
    });
    await prefs.setString(_detectedFormatsKey, json.encode(formatsMap));
  }

  Future<void> _saveDetectedFormat(String configId, ResponseFormatType format) async {
    _detectedFormats[configId] = format;
    await _saveToPrefs();
    debugPrint('💾 Saved detected format for $configId: ${format.name}');
  }

  // --- API Interaction ---

  Future<String?> _promptModelWithFormat({
    required List<LlmMessage> messages,
    required String systemPrompt,
    required LlmConfig config,
    required ResponseFormatType responseFormatType,
    bool debugLogs = false,
  }) async {
    final List<Map<String, dynamic>> apiMessages = <Map<String, dynamic>>[
      <String, dynamic>{'role': 'system', 'content': systemPrompt},
      ...messages.map((LlmMessage m) => m.toMap()),
    ];

    final Map<String, dynamic> body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': apiMessages,
      'temperature': config.temperature,
    };

    // Apply response format based on the type
    switch (responseFormatType) {
      case ResponseFormatType.jsonObject:
        body['response_format'] = <String, String>{'type': 'json_object'};
      case ResponseFormatType.jsonSchema:
        body['response_format'] = <String, String>{'type': 'json_schema'};
      case ResponseFormatType.text:
        body['response_format'] = <String, String>{'type': 'text'};
      case ResponseFormatType.none:
        // Don't send response_format, rely on prompt instructions
        break;
    }

    if (debugLogs && body.containsKey('response_format')) {
      debugPrint('🔧 response_format set to: ${body['response_format']}');
    }

    if (debugLogs) {
      debugPrint(
          '🌐 Sending request to ${config.baseUrl}/chat/completions');
      debugPrint('📦 Model: ${config.model.trim()}');
      debugPrint('🌡️ Temperature: ${config.temperature}');
    }

    try {
      final http.Response response = await http.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: json.encode(body),
      );

      if (debugLogs) {
        debugPrint('✅ Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json
            .decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final List<dynamic> choices = data['choices'] as List<dynamic>;
        final Map<String, dynamic> firstChoice =
            choices[0] as Map<String, dynamic>;
        final Map<String, dynamic> message =
            firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String?;
      } else {
        final String errorBody = response.body;
        debugPrint('❌ LLM API Error (Status ${response.statusCode}): $errorBody');
        // Return special error marker for response_format issues
        if (response.statusCode == 400 &&
            errorBody.contains('response_format')) {
          throw ResponseFormatException('Invalid response_format type');
        }
        return null;
      }
    } on ResponseFormatException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('💥 Exception calling LLM API: $e');
      if (debugLogs) {
        debugPrint('🔍 Stack trace: $stackTrace');
      }
      return null;
    }
  }

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
      return _promptModelWithFormat(
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
        debugPrint('🔍 Using previously detected format: ${formatToTry.name}');
      }
    } else {
      // Use the configured format
      formatToTry = activeConfig.responseFormatType;
      if (debugLogs) {
        debugPrint('🔍 Using configured format: ${formatToTry.name}');
      }
    }

    // Try the initial format
    String? result;
    try {
      result = await _promptModelWithFormat(
        messages: messages,
        systemPrompt: systemPrompt,
        config: activeConfig,
        responseFormatType: formatToTry,
        debugLogs: debugLogs,
      );
    } on ResponseFormatException {
      if (debugLogs) {
        debugPrint('⚠️ Response format not accepted, will try fallback');
      }
      result = null;
    }

    if (result != null) {
      return result;
    }

    // If initial attempt failed and we haven't auto-detected yet, try fallback
    if (!_detectedFormats.containsKey(activeConfig.id)) {
      if (debugLogs) {
        debugPrint('🔄 Initial format failed, trying automatic detection...');
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
          debugPrint('🔄 Trying fallback format: ${format.name}');
        }

        String? fallbackResult;
        try {
          fallbackResult = await _promptModelWithFormat(
            messages: messages,
            systemPrompt: systemPrompt,
            config: activeConfig,
            responseFormatType: format,
            debugLogs: debugLogs,
          );
        } on ResponseFormatException {
          // This format also doesn't work, try next one
          if (debugLogs) {
            debugPrint('⚠️ Format ${format.name} not accepted');
          }
          continue;
        }

        if (fallbackResult != null) {
          // Success! Save this format for future use
          await _saveDetectedFormat(activeConfig.id, format);
          if (debugLogs) {
            debugPrint('✅ Auto-detected working format: ${format.name}');
          }
          return fallbackResult;
        }
      }
    }

    // All formats failed
    if (debugLogs) {
      debugPrint('❌ All response format attempts failed');
    }
    return null;
  }

  Future<(String, List<FunctionInfo>)> checkFunctionsCalling({
    required LlmConfig api,
    required List<FunctionInfo> functions,
    required List<LlmMessage> messages,
    required String lastUserMessage,
  }) async {
    final List<Map<String, dynamic>> apiMessages =
        messages.map((LlmMessage m) => m.toMap()).toList();
    apiMessages
        .add(<String, dynamic>{'role': 'user', 'content': lastUserMessage});

    final List<Map<String, dynamic>> tools = functions.map((FunctionInfo f) {
      return <String, dynamic>{
        'type': 'function',
        'function': <String, dynamic>{
          'name': f.name,
          'description': f.description,
          'parameters': <String, dynamic>{
            'type': 'object',
            'properties': Map<String, dynamic>.fromEntries(
              f.parameters.map((Parameter p) =>
                  MapEntry<String, dynamic>(p.name, p.toMap())),
            ),
            'required': f.parameters
                .where((Parameter p) => p.isRequired)
                .map((Parameter p) => p.name)
                .toList(),
          },
        }
      };
    }).toList();

    final Map<String, dynamic> body = <String, dynamic>{
      'model': api.model.trim(),
      'messages': apiMessages,
      'tools': tools,
      'tool_choice': 'auto',
    };

    debugPrint('🔧 checkFunctionsCalling: Requesting with model ${api.model.trim()}');
    debugPrint('📋 Available tools: ${functions.map((FunctionInfo f) => f.name).join(", ")}');

    try {
      final http.Response response = await http.post(
        Uri.parse('${api.baseUrl}/chat/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.apiKey}',
        },
        body: json.encode(body),
      );

      debugPrint('✅ checkFunctionsCalling: Response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json
            .decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final List<dynamic> choices = data['choices'] as List<dynamic>;
        final Map<String, dynamic> firstChoice =
            choices[0] as Map<String, dynamic>;
        final Map<String, dynamic> message =
            firstChoice['message'] as Map<String, dynamic>;

        final List<FunctionInfo> calledFunctions = <FunctionInfo>[];

        if (message['tool_calls'] != null) {
          debugPrint('🔧 Tool calls detected: ${message['tool_calls']}');
          final List<dynamic> toolCalls =
              message['tool_calls'] as List<dynamic>;
          for (final dynamic toolCall in toolCalls) {
            final Map<String, dynamic> toolCallMap =
                toolCall as Map<String, dynamic>;
            final Map<String, dynamic> functionMap =
                toolCallMap['function'] as Map<String, dynamic>;
            final String funcName = functionMap['name'] as String;
            final String argsJson = functionMap['arguments'] as String;

            // Find the original function info
            final FunctionInfo originalFunc =
                functions.firstWhere((FunctionInfo f) => f.name == funcName);

            // Decode args
            final Map<String, dynamic> args =
                json.decode(argsJson) as Map<String, dynamic>;

            // Return a new FunctionInfo with called parameters
            calledFunctions.add(FunctionInfo(
              name: originalFunc.name,
              description: originalFunc.description,
              parameters: originalFunc.parameters,
              function: originalFunc.function,
              parametersCalled: args,
            ));
          }
        } else {
          debugPrint('💬 No tool calls, returning text response');
        }

        return (message['content'] as String? ?? '', calledFunctions);
      } else {
        debugPrint('❌ LLM API Error (checkFunctions, Status ${response.statusCode}): ${response.body}');
        return ('', <FunctionInfo>[]);
      }
    } catch (e, stackTrace) {
      debugPrint('💥 Exception calling LLM API (checkFunctions): $e');
      debugPrint('🔍 Stack trace: $stackTrace');
      return ('', <FunctionInfo>[]);
    }
  }
}
