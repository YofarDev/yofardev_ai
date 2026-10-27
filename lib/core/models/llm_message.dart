enum LlmMessageRole { system, user, assistant, tool }

class LlmMessage {
  final LlmMessageRole role;
  final String body;
  final String? attachedFile;

  /// For assistant messages that request tool calls (OpenAI format):
  /// `[{'id': ..., 'type': 'function', 'function': {'name': ..., 'arguments': ...}}]`
  final List<Map<String, dynamic>>? toolCalls;

  /// For tool result messages: the id of the tool call this message answers.
  final String? toolCallId;

  /// Chain of thought of a thinking model's assistant reply
  /// (`reasoning_content`, DeepSeek-style). Thinking-mode backends require it
  /// to be replayed verbatim on later requests; providers without the field
  /// never set it, so it never leaks into their payloads.
  final String? reasoningContent;

  const LlmMessage({
    required this.role,
    required this.body,
    this.attachedFile,
    this.toolCalls,
    this.toolCallId,
    this.reasoningContent,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{
      'role': role.name,
      'content': body, // OpenAI uses 'content'
      // attachedFile logic depends on implementation, usually specific handling
    };
    if (toolCalls != null) {
      map['tool_calls'] = toolCalls;
      if (body.isEmpty) {
        // Assistant tool-call messages carry no textual content.
        map['content'] = null;
      }
    }
    if (toolCallId != null) {
      map['tool_call_id'] = toolCallId;
    }
    if (reasoningContent != null && reasoningContent!.isNotEmpty) {
      map['reasoning_content'] = reasoningContent;
    }
    return map;
  }
}
