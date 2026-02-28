enum LlmMessageRole { system, user, assistant }

class LlmMessage {
  final LlmMessageRole role;
  final String body;
  final String? attachedFile;

  const LlmMessage({required this.role, required this.body, this.attachedFile});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'role': role.name,
      'content': body, // OpenAI uses 'content'
      // attachedFile logic depends on implementation, usually specific handling
    };
  }
}
