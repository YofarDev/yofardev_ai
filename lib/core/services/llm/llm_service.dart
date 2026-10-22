import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../../models/llm_task_type.dart';
import '../settings_local_datasource.dart';
import 'llm_config_manager.dart';
import 'llm_service_interface.dart';
import 'llm_stream_chunk.dart';
import 'llm_streaming_service.dart';
import 'llm_streaming_service_interface.dart';
import 'llm_usage_logger.dart';

/// Real LLM service implementation using OpenAI-compatible APIs
class LlmService implements LlmServiceInterface {
  static final LlmService _instance = LlmService._internal();

  factory LlmService() {
    return _instance;
  }

  LlmService._internal({
    http.Client? client,
    LlmStreamingServiceInterface? streamingService,
  }) : _client = client ?? http.Client(),
       _streamingService = streamingService;

  // Test support: allow injecting a mock client
  static http.Client? _testClient;
  static LlmStreamingServiceInterface? _testStreamingService;

  static void setTestClient(http.Client client) {
    _testClient = client;
  }

  static void setTestStreamingService(LlmStreamingServiceInterface service) {
    _testStreamingService = service;
  }

  static void resetTestClient() {
    _testClient = null;
  }

  static void resetTestStreamingService() {
    _testStreamingService = null;
  }

  http.Client get _httpClient => _testClient ?? _client;
  LlmStreamingServiceInterface get _streaming =>
      _testStreamingService ??
      _streamingService ??
      _createDefaultStreamingService();

  final http.Client _client;
  LlmConfigManager _configManager = LlmConfigManager(
    settingsDatasource: SettingsLocalDatasource(),
  );
  final LlmStreamingServiceInterface? _streamingService;

  /// Set the config manager from DI. Call during service initialization.
  void setConfigManager(LlmConfigManager manager) {
    _configManager = manager;
  }

  LlmStreamingServiceInterface _createDefaultStreamingService() {
    return LlmStreamingService(
      client: _httpClient,
      configManager: _configManager,
    );
  }

  @override
  Future<void> init() async {
    await _configManager.init();
  }

  @override
  List<LlmConfig> getAllConfigs() => _configManager.getAllConfigs();

  @override
  LlmConfig? getCurrentConfig() => _configManager.getCurrentConfig();

  @override
  Future<void> saveConfig(LlmConfig config) async {
    await _configManager.saveConfig(config);
  }

  @override
  Future<void> deleteConfig(String id) async {
    await _configManager.deleteConfig(id);
  }

  @override
  Future<void> setCurrentConfig(String id) async {
    await _configManager.setCurrentConfig(id);
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

    AppLogger.info(
      'LLM request: model=${activeConfig.model.trim()}, messages=${apiMessages.length}',
      tag: 'LlmService',
    );

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
        logTokenUsage(data['usage']);
        final List<dynamic> choices = data['choices'] as List<dynamic>;
        final Map<String, dynamic> firstChoice =
            choices[0] as Map<String, dynamic>;
        final Map<String, dynamic> message =
            firstChoice['message'] as Map<String, dynamic>;
        AppLogger.info('LLM response received: status=200', tag: 'LlmService');
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
    List<Map<String, dynamic>>? tools,
  }) {
    // Delegate to the streaming service
    return _streaming.promptModelStream(
      messages: messages,
      systemPrompt: systemPrompt,
      config: config,
      returnJson: returnJson,
      debugLogs: debugLogs,
      tools: tools,
    );
  }

  @override
  Future<LlmConfig?> getConfigForTask(LlmTaskType task) async {
    return await _configManager.getConfigForTask(task);
  }

  @override
  Future<String?> generateTitle(
    String firstUserMessage, {
    LlmConfig? config,
    String language = 'en',
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

      final String promptText = language == 'fr'
          ? "Générez un titre concis (max 5 mots) pour cette conversation: "
          : 'Generate a concise title (max 5 words) for this chat: ';
      final String systemPromptText = language == 'fr'
          ? "Vous êtes un assistant utile qui génère des titres de conversation courts et descriptifs. Returnz uniquement le titre, sans guillemets ni texte supplémentaire."
          : 'You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.';

      final List<LlmMessage> messages = <LlmMessage>[
        LlmMessage(
          role: LlmMessageRole.user,
          body: '$promptText$firstUserMessage',
        ),
      ];

      final String? result = await promptModel(
        messages: messages,
        systemPrompt: systemPromptText,
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
  Future<String?> extractMemory({
    required String conversationExcerpt,
    required List<String> currentMemory,
    LlmConfig? config,
  }) async {
    try {
      final LlmConfig? activeConfig =
          config ?? await getConfigForTask(LlmTaskType.memoryExtraction);
      if (activeConfig == null) {
        AppLogger.error(
          'No LLM config available for memory extraction',
          tag: 'LlmService',
        );
        return null;
      }

      const String systemPromptText =
          'You maintain the long-term memory of an AI companion app about its '
          'user. You receive the current memory items and a conversation '
          'excerpt. Return the COMPLETE updated memory list as JSON: '
          '{"memory": ["fact 1", "fact 2"]}. Rules: keep only facts about the '
          'user (preferences, life events, ongoing projects, personality); '
          'merge duplicates; drop items contradicted by newer information; '
          'never store facts about the assistant; maximum 30 items; each item '
          'is a plain sentence of at most 200 characters; if the excerpt adds '
          'nothing worth remembering, return the current list unchanged; if '
          'there is nothing memorable at all, return {"memory": []}.';

      final StringBuffer userPrompt = StringBuffer();
      if (currentMemory.isEmpty) {
        userPrompt.writeln('Current memory: (empty)');
      } else {
        userPrompt.writeln('Current memory:');
        for (final String item in currentMemory) {
          userPrompt.writeln('- $item');
        }
      }
      userPrompt.writeln();
      userPrompt.writeln('Conversation excerpt:');
      userPrompt.write(conversationExcerpt);

      final List<LlmMessage> messages = <LlmMessage>[
        LlmMessage(role: LlmMessageRole.user, body: userPrompt.toString()),
      ];

      final String? result = await promptModel(
        messages: messages,
        systemPrompt: systemPromptText,
        config: activeConfig,
        returnJson: true,
      );

      return result?.trim();
    } catch (e) {
      AppLogger.error('Memory extraction failed', tag: 'LlmService', error: e);
      return null;
    }
  }

  @override
  bool get isActive => true; // Real LLM service is always active
}
