import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import 'llm_config_manager.dart';
import 'llm_stream_chunk.dart';
import 'llm_streaming_service_interface.dart';
import 'llm_usage_logger.dart';

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
    List<Map<String, dynamic>>? tools,
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
      // Ask OpenAI-compatible providers to send a final usage event so
      // prompt-cache hits are observable. Providers without support are
      // expected to ignore the field.
      'stream_options': <String, bool>{'include_usage': true},
    };

    if (returnJson) {
      body['response_format'] = <String, String>{'type': 'json_object'};
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
      body['tool_choice'] = 'auto';
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

          // The final usage event carries token counts (OpenAI) or cache-hit
          // stats (DeepSeek) and may have an empty choices list.
          final Map<String, dynamic>? usage =
              jsonData['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            logTokenUsage(usage);
          }

          final List<dynamic> choices = jsonData['choices'] as List<dynamic>;
          if (choices.isEmpty) continue;

          final Map<String, dynamic> choice =
              choices[0] as Map<String, dynamic>;
          final Map<String, dynamic>? delta =
              choice['delta'] as Map<String, dynamic>?;

          // Streamed tool calls arrive as fragmented deltas keyed by index.
          final List<dynamic>? toolCallDeltas =
              delta?['tool_calls'] as List<dynamic>?;
          if (toolCallDeltas != null) {
            for (final dynamic tc in toolCallDeltas) {
              final Map<String, dynamic> tcMap = tc as Map<String, dynamic>;
              final Map<String, dynamic>? function =
                  tcMap['function'] as Map<String, dynamic>?;
              yield LlmStreamChunk.toolCallDelta(
                index: (tcMap['index'] as num?)?.toInt() ?? 0,
                id: tcMap['id'] as String?,
                name: function?['name'] as String?,
                argumentsDelta: function?['arguments'] as String?,
              );
            }
            continue;
          }

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
