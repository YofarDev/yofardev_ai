// ignore_for_file: join_return_with_assignment

import '../services/agent/yofardev_agent.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/demo_script.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/prompt_service.dart';

class YofardevRepository {
  final YofardevAgent _agent = YofardevAgent();
  final PromptService _promptService = PromptService();
  final FakeLlmService _fakeLlmService = FakeLlmService();

  Future<ChatEntry> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    // Check if fake LLM service has a scripted response
    if (_fakeLlmService.isActive) {
      final FakeLlmResponse? fakeResponse = _fakeLlmService.getNextResponse();
      if (fakeResponse != null) {
        // Wait 600ms to simulate LLM processing
        await Future<void>.delayed(const Duration(milliseconds: 600));

        return ChatEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          entryType: EntryType.yofardev,
          body: fakeResponse.jsonBody,
          timestamp: DateTime.now(),
        );
      }
    }

    // Fall back to real LLM
    return _agent.ask(
      chat: chat,
      userMessage: userMessage,
      systemPrompt: await _promptService.getSystemPrompt(),
      functionCallingEnabled: functionCallingEnabled,
    );
  }
}
