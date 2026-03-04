import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logger.dart';
import '../../models/function_info.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../../models/llm_task_type.dart';
import '../../models/task_llm_config.dart';
import '../../../features/settings/data/datasources/settings_local_datasource.dart';
import 'llm_service_interface.dart';
import 'llm_stream_chunk.dart';

/// Real LLM service implementation using OpenAI-compatible APIs
class LlmService implements LlmServiceInterface {
  static const String _configsKey = 'llm_configs';
  static const String _currentConfigIdKey = 'current_llm_config_id';

  static final LlmService _instance = LlmService._internal();

  factory LlmService() {
    return _instance;
  }

  LlmService._internal({http.Client? client})
    : _client = client ?? http.Client();

  // Test support: allow injecting a mock client
  static http.Client? _testClient;

  static void setTestClient(http.Client client) {
    _testClient = client;
  }

  static void resetTestClient() {
    _testClient = null;
  }

  http.Client get _httpClient => _testClient ?? _client;

  final http.Client _client;
  List<LlmConfig> _configs = <LlmConfig>[];
  String? _currentConfigId;
  final SettingsLocalDatasource _settingsDatasource = SettingsLocalDatasource();

  @override
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
          tag: 'LlmService',
          error: e,
        );
      }
    }

    _currentConfigId = prefs.getString(_currentConfigIdKey);
  }

  @override
  List<LlmConfig> getAllConfigs() => List<LlmConfig>.unmodifiable(_configs);

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

    final List<Map<String, dynamic>> apiMessages = <Map<String, dynamic>>[
      <String, dynamic>{'role': 'system', 'content': systemPrompt},
      ...messages.map((LlmMessage m) => m.toMap()),
    ];

    final Map<String, dynamic> body = <String, dynamic>{
      'model': activeConfig.model.trim(),
      'messages': apiMessages,
      'temperature': activeConfig.temperature,
    };

    if (returnJson) {
      body['response_format'] = <String, String>{'type': 'json_object'};
    }

    if (debugLogs) {
      AppLogger.debug(
        'Sending request to ${activeConfig.baseUrl}/chat/completions with model ${activeConfig.model.trim()}',
        tag: 'LlmService',
      );
    }

    try {
      final http.Response response = await _httpClient.post(
        Uri.parse('${activeConfig.baseUrl}/chat/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${activeConfig.apiKey}',
        },
        body: json.encode(body),
      );

      if (debugLogs) {
        AppLogger.debug(
          'Response status: ${response.statusCode}',
          tag: 'LlmService',
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
        final List<dynamic> choices = data['choices'] as List<dynamic>;
        final Map<String, dynamic> firstChoice =
            choices[0] as Map<String, dynamic>;
        final Map<String, dynamic> message =
            firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String?;
      } else {
        AppLogger.error('LLM API Error: ${response.body}', tag: 'LlmService');
        return null;
      }
    } catch (e) {
      AppLogger.error('Exception calling LLM API', tag: 'LlmService', error: e);
      return null;
    }
  }

  @override
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  }) async* {
    final LlmConfig? activeConfig = config ?? getCurrentConfig();
    if (activeConfig == null) {
      yield const LlmStreamChunk.error('No LLM Configuration selected.');
      return;
    }

    final List<Map<String, dynamic>> apiMessages = <Map<String, dynamic>>[
      <String, dynamic>{'role': 'system', 'content': systemPrompt},
      ...messages.map((LlmMessage m) => m.toMap()),
    ];

    final Map<String, dynamic> body = <String, dynamic>{
      'model': activeConfig.model.trim(),
      'messages': apiMessages,
      'temperature': activeConfig.temperature,
      'stream': true, // Enable streaming
    };

    if (returnJson) {
      body['response_format'] = <String, String>{'type': 'json_object'};
    }

    if (debugLogs) {
      AppLogger.debug(
        'Starting stream request to ${activeConfig.baseUrl}/chat/completions',
        tag: 'LlmService',
      );
    }

    try {
      final http.StreamedResponse response = await _httpClient.send(
        http.Request(
            'POST',
            Uri.parse('${activeConfig.baseUrl}/chat/completions'),
          )
          ..headers.addAll(<String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${activeConfig.apiKey}',
          })
          ..body = json.encode(body),
      );

      if (response.statusCode != 200) {
        final String errorBody = await response.stream.bytesToString();
        AppLogger.error(
          'Stream API Error: ${response.statusCode} - $errorBody',
          tag: 'LlmService',
        );
        yield LlmStreamChunk.error('HTTP ${response.statusCode}: $errorBody');
        return;
      }

      // Parse SSE (Server-Sent Events) stream
      await for (final String line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (!line.startsWith('data: ')) continue;

        final String data = line.substring(6); // Remove 'data: ' prefix
        if (data.trim() == '[DONE]') {
          yield const LlmStreamChunk.complete();
          break;
        }

        try {
          final Map<String, dynamic> jsonData =
              json.decode(data) as Map<String, dynamic>;
          final List<dynamic> choices = jsonData['choices'] as List<dynamic>;
          if (choices.isEmpty) continue;

          final Map<String, dynamic> choice =
              choices[0] as Map<String, dynamic>;
          final Map<String, dynamic>? delta =
              choice['delta'] as Map<String, dynamic>?;

          final String? content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            final String finishReason =
                choice['finish_reason'] as String? ?? 'null';

            yield LlmStreamChunk.text(
              content: content,
              isComplete: finishReason == 'stop',
            );
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to parse stream chunk: $line',
            tag: 'LlmService',
          );
        }
      }
    } catch (e) {
      AppLogger.error(
        'Exception in streaming request',
        tag: 'LlmService',
        error: e,
      );
      yield LlmStreamChunk.error('Stream error: ${e.toString()}');
    }
  }

  @override
  Future<(String, List<FunctionInfo>)> checkFunctionsCalling({
    required LlmConfig api,
    required List<FunctionInfo> functions,
    required List<LlmMessage> messages,
    required String lastUserMessage,
  }) async {
    final List<Map<String, dynamic>> apiMessages = messages
        .map((LlmMessage m) => m.toMap())
        .toList();
    apiMessages.add(<String, dynamic>{
      'role': 'user',
      'content': lastUserMessage,
    });

    final List<Map<String, dynamic>> tools = functions.map((FunctionInfo f) {
      return <String, dynamic>{
        'type': 'function',
        'function': <String, dynamic>{
          'name': f.name,
          'description': f.description,
          'parameters': <String, dynamic>{
            'type': 'object',
            'properties': Map<String, dynamic>.fromEntries(
              f.parameters.map(
                (Parameter p) => MapEntry<String, dynamic>(p.name, p.toMap()),
              ),
            ),
            'required': f.parameters
                .where((Parameter p) => p.isRequired)
                .map((Parameter p) => p.name)
                .toList(),
          },
        },
      };
    }).toList();

    final Map<String, dynamic> body = <String, dynamic>{
      'model': api.model.trim(),
      'messages': apiMessages,
      'tools': tools,
      'tool_choice': 'auto',
    };

    try {
      final http.Response response = await _httpClient.post(
        Uri.parse('${api.baseUrl}/chat/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.apiKey}',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
        final List<dynamic> choices = data['choices'] as List<dynamic>;
        final Map<String, dynamic> firstChoice =
            choices[0] as Map<String, dynamic>;
        final Map<String, dynamic> message =
            firstChoice['message'] as Map<String, dynamic>;

        final List<FunctionInfo> calledFunctions = <FunctionInfo>[];

        if (message['tool_calls'] != null) {
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
            final FunctionInfo originalFunc = functions.firstWhere(
              (FunctionInfo f) => f.name == funcName,
            );

            // Decode args
            final Map<String, dynamic> args =
                json.decode(argsJson) as Map<String, dynamic>;

            // Return a new FunctionInfo with called parameters
            calledFunctions.add(
              FunctionInfo(
                name: originalFunc.name,
                description: originalFunc.description,
                parameters: originalFunc.parameters,
                function: originalFunc.function,
                parametersCalled: args,
              ),
            );
          }
        }

        return (message['content'] as String? ?? '', calledFunctions);
      } else {
        AppLogger.error(
          'LLM API Error (checkFunctions): ${response.body}',
          tag: 'LlmService',
        );
        return ('', <FunctionInfo>[]);
      }
    } catch (e) {
      AppLogger.error(
        'Exception calling LLM API (checkFunctions)',
        tag: 'LlmService',
        error: e,
      );
      return ('', <FunctionInfo>[]);
    }
  }

  Future<TaskLlmConfig> _getTaskConfigFromSettings() async {
    try {
      final Either<Exception, TaskLlmConfig> result = await _settingsDatasource
          .getTaskLlmConfig();
      return result.getOrElse(() => const TaskLlmConfig());
    } catch (e) {
      AppLogger.error(
        'Failed to load task config',
        tag: 'LlmService',
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

  @override
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
            tag: 'LlmService',
          );
        }
      }

      // Fallback to current/default config
      final LlmConfig? defaultConfig = getCurrentConfig();
      if (defaultConfig == null) {
        AppLogger.error(
          'No LLM configuration available for task: ${task.name}',
          tag: 'LlmService',
        );
      }
      return defaultConfig;
    } catch (e) {
      AppLogger.error(
        'Failed to get config for task: ${task.name}',
        tag: 'LlmService',
        error: e,
      );
      return getCurrentConfig();
    }
  }

  @override
  Future<String?> generateTitle(
    String firstUserMessage, {
    LlmConfig? config,
  }) async {
    try {
      final LlmConfig? activeConfig =
          config ?? await getConfigForTask(LlmTaskType.titleGeneration);
      if (activeConfig == null) {
        AppLogger.error(
          'No LLM config available for title generation',
          tag: 'LlmService',
        );
        return null;
      }

      final List<LlmMessage> messages = <LlmMessage>[
        LlmMessage(
          role: LlmMessageRole.user,
          body:
              'Generate a concise title (max 5 words) for this chat: $firstUserMessage',
        ),
      ];

      final String? result = await promptModel(
        messages: messages,
        systemPrompt:
            'You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.',
        config: activeConfig,
        returnJson: false,
      );

      return result?.trim();
    } catch (e) {
      AppLogger.error('Title generation failed', tag: 'LlmService', error: e);
      return null;
    }
  }

  @override
  bool get isActive => true; // Real LLM service is always active
}
