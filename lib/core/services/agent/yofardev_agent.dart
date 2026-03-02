import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../features/chat/domain/models/chat.dart';
import '../../features/chat/domain/models/chat_entry.dart';
import '../../models/function_info.dart';
import '../../models/llm_config.dart';
import '../../models/llm_message.dart';
import '../llm/llm_service.dart';
import '../../utils/logger.dart';
import 'tool_registry.dart';

class YofardevAgent {
  final LlmService _llmService = LlmService();

  /// The primary method to interact with the agent.
  ///
  /// [chat] contains the conversation history.
  /// [userMessage] is the new message from the user.
  /// [systemPrompt] is the personality/context instructions.
  /// [functionCallingEnabled] whether to use function calling (default: true).
  Future<ChatEntry> ask({
    required Chat chat,
    required String userMessage,
    required String systemPrompt,
    bool functionCallingEnabled = true,
  }) async {
    final Stopwatch llmStopwatch = Stopwatch()..start();
    AppLogger.info('Starting LLM request...', tag: 'YofardevAgent');

    // Ensure service is initialized (safe to call multiple times or check internally)
    await _llmService.init();

    final LlmConfig? config = _llmService.getCurrentConfig();
    if (config == null) {
      throw Exception('No LLM Configuration selected');
    }

    // 1. Check if we need to call any tools (Functions)
    // ignore: prefer_final_locals
    List<FunctionInfo> functionsToCall = <FunctionInfo>[];
    final List<Map<String, dynamic>> toolResults = <Map<String, dynamic>>[];

    if (functionCallingEnabled) {
      AppLogger.info('Checking for function calls...', tag: 'YofardevAgent');
      final Stopwatch functionCheckStopwatch = Stopwatch()..start();

      final (String, List<FunctionInfo>) functionCheck = await _llmService
          .checkFunctionsCalling(
            api: config,
            functions: ToolRegistry.functionInfos,
            messages: chat.llmMessages,
            lastUserMessage: userMessage,
          );

      functionCheckStopwatch.stop();
      AppLogger.info(
        'Function check completed in ${functionCheckStopwatch.elapsedMilliseconds}ms',
        tag: 'YofardevAgent',
      );

      functionsToCall.addAll(functionCheck.$2);

      // 2. Execute tools if any were selected
      if (functionsToCall.isNotEmpty) {
        AppLogger.info(
          'Agent decided to call ${functionsToCall.length} tools.',
          tag: 'YofardevAgent',
        );

        for (final FunctionInfo info in functionsToCall) {
          final AgentTool? tool = ToolRegistry.getTool(info.name);
          if (tool != null) {
            AppLogger.debug(
              'Executing tool: ${tool.name} with args: ${info.parametersCalled}',
              tag: 'YofardevAgent',
            );
            try {
              final dynamic result = await tool.execute(
                info.parametersCalled ?? <String, dynamic>{},
              );
              toolResults.add(<String, dynamic>{
                'name': tool.name,
                'result': result,
                'parameters': info.parametersCalled,
              });
            } catch (e) {
              toolResults.add(<String, dynamic>{
                'name': tool.name,
                'result': 'Error executing tool: $e',
                'parameters': info.parametersCalled,
              });
            }
          }
        }
      }
    } else {
      AppLogger.info('Function calling is disabled', tag: 'YofardevAgent');
    }

    // 3. Construct the prompt for the final response
    final StringBuffer finalUserPrompt = StringBuffer();
    finalUserPrompt.write(userMessage);
    if (toolResults.isNotEmpty) {
      finalUserPrompt.write(
        '\n\n[System: The following functions were executed based on your request. Use their results to answer the user.]\n',
      );
      for (final Map<String, dynamic> res in toolResults) {
        finalUserPrompt.write(
          'Function: ${res['name']}\nParams: ${res['parameters']}\nResult: ${res['result']}\n---\n',
        );
      }
    }

    final List<LlmMessage> conversation = List<LlmMessage>.from(
      chat.llmMessages,
    );

    if (conversation.isNotEmpty && toolResults.isNotEmpty) {
      // Logic to append context.
      final LlmMessage lastMsg = conversation.last;

      if (lastMsg.role == LlmMessageRole.user) {
        // Replace the last user message with the augmented one
        conversation.removeLast();
        conversation.add(
          LlmMessage(
            role: LlmMessageRole.user,
            body: finalUserPrompt.toString(),
            attachedFile: lastMsg.attachedFile,
          ),
        );
      } else {
        conversation.add(
          LlmMessage(
            role: LlmMessageRole.user,
            body: finalUserPrompt.toString(),
          ),
        );
      }
    } else {
      if (conversation.isNotEmpty &&
          conversation.last.role == LlmMessageRole.user) {
        // Already there
      } else {
        conversation.add(
          LlmMessage(
            role: LlmMessageRole.user,
            body: finalUserPrompt.toString(),
          ),
        );
      }
    }

    // 4. Get the final answer
    AppLogger.info('Generating final response...', tag: 'YofardevAgent');
    final Stopwatch generationStopwatch = Stopwatch()..start();

    final String? rawResponse = await _llmService.promptModel(
      messages: conversation,
      systemPrompt: systemPrompt,
      config: config,
      returnJson: true,
      debugLogs: true,
    );

    generationStopwatch.stop();
    AppLogger.info(
      'LLM generation completed in ${generationStopwatch.elapsedMilliseconds}ms',
      tag: 'YofardevAgent',
    );

    if (rawResponse == null) {
      throw Exception('Failed to get response from LLM');
    }

    String response = rawResponse;

    // 5. Parse JSON
    try {
      final int jsonStart = response.indexOf('{');
      final int jsonEnd = response.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final String extracted = response.substring(jsonStart, jsonEnd + 1);
        AppLogger.debug('Extracted JSON: $extracted', tag: 'YofardevAgent');

        // Validate that the extracted JSON is actually valid
        try {
          json.decode(extracted);
          response = extracted;
        } catch (e) {
          AppLogger.warning(
            'Extracted JSON is invalid: $e',
            tag: 'YofardevAgent',
          );
          AppLogger.warning('Using raw response instead', tag: 'YofardevAgent');
        }
      } else {
        AppLogger.warning(
          'No JSON object found in response',
          tag: 'YofardevAgent',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to extract JSON from response: $e',
        tag: 'YofardevAgent',
      );
    }

    llmStopwatch.stop();
    AppLogger.info(
      'Total LLM time: ${llmStopwatch.elapsedMilliseconds}ms (${llmStopwatch.elapsedMilliseconds / 1000}s)',
      tag: 'YofardevAgent',
    );

    return ChatEntry(
      id: const Uuid().v4(),
      body: response,
      entryType: EntryType.yofardev,
      timestamp: DateTime.now(),
    );
  }
}
