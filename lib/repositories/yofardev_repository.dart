// ignore_for_file: join_return_with_assignment

import '../logic/agent/yofardev_agent.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../services/prompt_service.dart';

class YofardevRepository {
  final YofardevAgent _agent = YofardevAgent();
  final PromptService _promptService = PromptService();

  Future<ChatEntry> askYofardevAi(Chat chat, String userMessage) async {
    return _agent.ask(
      chat: chat,
      userMessage: userMessage,
      systemPrompt: await _promptService.getSystemPrompt(),
    );
  }
}
