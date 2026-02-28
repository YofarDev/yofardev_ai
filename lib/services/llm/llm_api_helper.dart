import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/llm/llm_config.dart';
import '../../models/llm/llm_message.dart';
import '../../utils/logger.dart';
import 'llm_exceptions.dart';

/// Helper class for making LLM API requests
class LlmApiHelper {
  /// Prompt the LLM model with a specific response format
  static Future<String?> promptModelWithFormat({
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
      AppLogger.debug(
        'response_format set to: ${body['response_format']}',
        tag: 'LlmService',
      );
    }

    if (debugLogs) {
      AppLogger.debug(
        'Sending request to ${config.baseUrl}/chat/completions',
        tag: 'LlmService',
      );
      AppLogger.debug('Model: ${config.model.trim()}', tag: 'LlmService');
      AppLogger.debug('Temperature: ${config.temperature}', tag: 'LlmService');
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
        final String errorBody = response.body;
        AppLogger.error(
          'LLM API Error (Status ${response.statusCode}): $errorBody',
          tag: 'LlmService',
        );
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
      AppLogger.error(
        'Exception calling LLM API: $e',
        tag: 'LlmService',
        stackTrace: stackTrace,
      );
      if (debugLogs) {
        AppLogger.debug('Stack trace: $stackTrace', tag: 'LlmService');
      }
      return null;
    }
  }
}
