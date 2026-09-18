import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../repositories/settings_repository.dart';
import '../../models/function_info.dart';
import '../../models/llm_config.dart';
import '../llm/llm_service.dart';
import '../../utils/logger.dart';
import 'tool_registry.dart';

class YofardevAgent {
  YofardevAgent({LlmService? llmService, required ToolRegistry toolRegistry})
    : _llmService = llmService ?? LlmService(),
      _toolRegistry = toolRegistry;

  final LlmService _llmService;
  final ToolRegistry _toolRegistry;

  /// Detects and executes tools for the turn. Does NOT generate the final answer.
  ///
  /// [chat] contains the conversation history (including the user's message).
  /// [userMessage] is the new message from the user.
  /// [settingsRepository] repository to access function calling configuration.
  ///
  /// Returns the function-calling entries (empty if no tools were called) and
  /// the user message augmented with tool results (unchanged if no tools were
  /// called).
  Future<(List<ChatEntry> functionEntries, String augmentedUserMessage)>
      checkAndExecuteTools({
    required Chat chat,
    required String userMessage,
    required SettingsRepository settingsRepository,
  }) async {
    // Ensure service is initialized (safe to call multiple times or check internally)
    await _llmService.init();

    final LlmConfig? config = _llmService.getCurrentConfig();
    if (config == null) {
      throw Exception('No LLM Configuration selected');
    }

    // 1. Check if we need to call any tools (Functions)
    final List<FunctionInfo> functionsToCall = <FunctionInfo>[];
    final List<Map<String, dynamic>> toolResults = <Map<String, dynamic>>[];

    AppLogger.debug(
      'Function calling enabled, checking if tools are needed...',
      tag: 'YofardevAgent',
    );

    // Get available tools based on settings
    final List<FunctionInfo> availableFunctions = await _toolRegistry
        .getFunctionInfos(settingsRepository);

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
        final AgentTool? tool = _toolRegistry.getTool(info.name);
        if (tool != null) {
          try {
            final dynamic result = await _toolRegistry.executeTool(
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

    // 3. Augment the user message with tool results (if any)
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

    // Build the list of function call entries (if any)
    final List<ChatEntry> entries = <ChatEntry>[];
    for (final Map<String, dynamic> result in toolResults) {
      // Format as a list containing the function data (as expected by FunctionCallingWidget)
      final List<Map<String, dynamic>> functionDataList =
          <Map<String, dynamic>>[
            <String, dynamic>{
              'name': result['name'] as String,
              'parameters': result['parameters'] as Map<String, dynamic>,
              'result': result['result'],
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

    return (entries, finalUserPrompt.toString());
  }
}
