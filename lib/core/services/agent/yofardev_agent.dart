import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../features/chat/domain/models/chat.dart';
import '../../../features/chat/domain/models/chat_entry.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';
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
  /// [settingsRepository] repository to access function calling configuration.
  ///
  /// Returns a list of [ChatEntry] including:
  /// - One entry per tool called (if any) with EntryType.functionCalling
  /// - One entry for the final response with EntryType.yofardev
  Future<List<ChatEntry>> ask({
    required Chat chat,
    required String userMessage,
    required String systemPrompt,
    bool functionCallingEnabled = true,
    required SettingsRepository settingsRepository,
  }) async {
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
      AppLogger.debug(
        'Function calling enabled, checking if tools are needed...',
        tag: 'YofardevAgent',
      );

      // Get available tools based on settings
      final List<FunctionInfo> availableFunctions =
          await ToolRegistry.getFunctionInfos(settingsRepository);

      final (String, List<FunctionInfo>) functionCheck = await _llmService
          .checkFunctionsCalling(
            api: config,
            functions: availableFunctions,
            messages: chat.llmMessages,
            lastUserMessage: userMessage,
          );

      functionsToCall.addAll(functionCheck.$2);
      AppLogger.debug(
        'LLM returned ${functionsToCall.length} tool calls: ${functionsToCall.map((FunctionInfo f) => f.name).join(", ")}',
        tag: 'YofardevAgent',
      );

      // 2. Execute tools if any were selected
      if (functionsToCall.isNotEmpty) {
        for (final FunctionInfo info in functionsToCall) {
          final AgentTool? tool = ToolRegistry.getTool(info.name);
          if (tool != null) {
            try {
              final dynamic result = await ToolRegistry.executeTool(
                tool,
                info.parametersCalled ?? <String, dynamic>{},
                settingsRepository,
              );
              toolResults.add(<String, dynamic>{
                'name': tool.name,
                'result': result,
                'parameters': info.parametersCalled,
              });
            } catch (e) {
              AppLogger.error(
                'Tool execution error: ${tool.name}',
                tag: 'YofardevAgent',
                error: e,
              );
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
      AppLogger.debug(
        'Function calling is disabled, skipping tool check',
        tag: 'YofardevAgent',
      );
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
    final String? rawResponse = await _llmService.promptModel(
      messages: conversation,
      systemPrompt: systemPrompt,
      config: config,
      returnJson: true,
      debugLogs: false,
    );

    if (rawResponse == null) {
      throw Exception('Failed to get response from LLM');
    }

    // DIAGNOSTIC: Log what we actually received from LLM
    AppLogger.debug(
      'Raw LLM response: "${rawResponse.length > 200 ? "${rawResponse.substring(0, 200)}..." : rawResponse}"',
      tag: 'YofardevAgent',
    );

    String response = rawResponse;

    // 5. Parse JSON
    try {
      final int jsonStart = response.indexOf('{');
      final int jsonEnd = response.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final String extracted = response.substring(jsonStart, jsonEnd + 1);

        // Validate that the extracted JSON is actually valid
        try {
          json.decode(extracted);
          response = extracted;
        } catch (e) {
          AppLogger.warning(
            'Invalid JSON extracted, using raw response',
            tag: 'YofardevAgent',
          );
        }
      }
    } catch (e) {
      AppLogger.error(
        'Failed to extract JSON from response',
        tag: 'YofardevAgent',
        error: e,
      );
    }

    // Build the list of entries to return
    final List<ChatEntry> entries = <ChatEntry>[];

    // Add function call entries first (if any)
    if (toolResults.isNotEmpty) {
      for (final Map<String, dynamic> result in toolResults) {
        // Format as a list containing the function data (as expected by FunctionCallingWidget)
        final List<Map<String, dynamic>> functionDataList =
            <Map<String, dynamic>>[
              <String, dynamic>{
                'name': result['name'] as String,
                'parameters': result['parameters'] as Map<String, dynamic>,
              },
            ];
        entries.add(
          ChatEntry(
            id: const Uuid().v4(),
            entryType: EntryType.functionCalling,
            body: json.encode(functionDataList),
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    // Add the final response entry
    final ChatEntry responseEntry = ChatEntry(
      id: const Uuid().v4(),
      body: response,
      entryType: EntryType.yofardev,
      timestamp: DateTime.now(),
    );

    // DIAGNOSTIC: Log what's being stored in ChatEntry
    AppLogger.debug(
      'Storing in ChatEntry.body: "${response.length > 200 ? "${response.substring(0, 200)}..." : response}"',
      tag: 'YofardevAgent',
    );

    entries.add(responseEntry);

    AppLogger.debug(
      'Returning ${entries.length} entries: ${entries.where((ChatEntry e) => e.entryType == EntryType.functionCalling).length} function calls, 1 response',
      tag: 'YofardevAgent',
    );

    return entries;
  }
}
