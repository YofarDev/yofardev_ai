import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import 'llm_config_manager.dart';
import 'llm_stream_chunk.dart';
import 'llm_streaming_service_interface.dart';

/// Implementation of LLM streaming service
///
/// Handles streaming requests to LLM APIs using Server-Sent Events (SSE).
/// This service focuses solely on streaming logic, separate from
/// configuration management.
class LlmStreamingService implements LlmStreamingServiceInterface {
  LlmStreamingService({
    required http.Client client,
    required LlmConfigManager configManager,
  }) : _client = client,
       _configManager = configManager;

  final http.Client _client;
  final LlmConfigManager _configManager;

  @override
  Stream<LlmStreamChunk> promptModelStream({
    required List<LlmMessage> messages,
    required String systemPrompt,
    LlmConfig? config,
    bool returnJson = false,
    bool debugLogs = false,
  }) async* {
    final LlmConfig? activeConfig = config ?? _configManager.getCurrentConfig();
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
        tag: 'LlmStreamingService',
      );
    }

    AppLogger.info(
      'LLM stream started: model=${activeConfig.model.trim()}, messages=${apiMessages.length}',
      tag: 'LlmStreamingService',
    );

    try {
      final http.StreamedResponse response = await _client.send(
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
          tag: 'LlmStreamingService',
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
          AppLogger.info('LLM stream completed', tag: 'LlmStreamingService');
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
            tag: 'LlmStreamingService',
          );
        }
      }
    } catch (e) {
      AppLogger.error(
        'Exception in streaming request',
        tag: 'LlmStreamingService',
        error: e,
      );
      yield LlmStreamChunk.error('Stream error: ${e.toString()}');
    }
  }
}
