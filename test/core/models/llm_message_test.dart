import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';

void main() {
  group('LlmMessage.toMap', () {
    test('includes reasoning_content when present', () {
      const LlmMessage message = LlmMessage(
        role: LlmMessageRole.assistant,
        body: 'answer',
        reasoningContent: 'chain of thought',
      );

      expect(message.toMap()['reasoning_content'], 'chain of thought');
    });

    test('omits reasoning_content when absent or empty', () {
      const LlmMessage plain = LlmMessage(
        role: LlmMessageRole.user,
        body: 'question',
      );
      expect(plain.toMap().containsKey('reasoning_content'), isFalse);

      const LlmMessage emptyReasoning = LlmMessage(
        role: LlmMessageRole.assistant,
        body: 'answer',
        reasoningContent: '',
      );
      expect(emptyReasoning.toMap().containsKey('reasoning_content'), isFalse);
    });

    test('reasoning rides assistant tool-call messages', () {
      const LlmMessage message = LlmMessage(
        role: LlmMessageRole.assistant,
        body: '',
        toolCalls: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'call_1',
            'type': 'function',
            'function': <String, dynamic>{'name': 'getWeather'},
          },
        ],
        reasoningContent: 'chain of thought',
      );

      final Map<String, dynamic> map = message.toMap();
      expect(map['reasoning_content'], 'chain of thought');
      expect(map['tool_calls'], isNotNull);
    });
  });
}
