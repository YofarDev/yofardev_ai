import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/llm/function_info.dart';
import '../../models/llm/llm_config.dart';
import '../../models/llm/llm_message.dart';
import '../../utils/logger.dart';

/// Helper class for LLM function calling
class LlmFunctionCallingHelper {
  /// Check if the LLM wants to call any functions
  static Future<(String, List<FunctionInfo>)> checkFunctionsCalling({
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

    AppLogger.debug(
      'checkFunctionsCalling: Requesting with model ${api.model.trim()}',
      tag: 'LlmService',
    );
    AppLogger.debug(
      'Available tools: ${functions.map((FunctionInfo f) => f.name).join(", ")}',
      tag: 'LlmService',
    );

    try {
      final http.Response response = await http.post(
        Uri.parse('${api.baseUrl}/chat/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.apiKey}',
        },
        body: json.encode(body),
      );

      AppLogger.debug(
        'checkFunctionsCalling: Response status ${response.statusCode}',
        tag: 'LlmService',
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
          AppLogger.debug(
            'Tool calls detected: ${message['tool_calls']}',
            tag: 'LlmService',
          );
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
        } else {
          AppLogger.debug(
            'No tool calls, returning text response',
            tag: 'LlmService',
          );
        }

        return (message['content'] as String? ?? '', calledFunctions);
      } else {
        AppLogger.error(
          'LLM API Error (checkFunctions, Status ${response.statusCode}): ${response.body}',
          tag: 'LlmService',
        );
        return ('', <FunctionInfo>[]);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Exception calling LLM API (checkFunctions): $e',
        tag: 'LlmService',
        stackTrace: stackTrace,
      );
      AppLogger.debug('Stack trace: $stackTrace', tag: 'LlmService');
      return ('', <FunctionInfo>[]);
    }
  }
}
