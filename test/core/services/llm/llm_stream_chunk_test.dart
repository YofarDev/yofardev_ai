import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';

void main() {
  group('LlmStreamChunk', () {
    test('should serialize text chunk', () {
      const LlmStreamChunk chunk = LlmStreamChunk.text(
        content: 'Hello world',
        isComplete: false,
      );

      final Map<String, dynamic> json = chunk.toJson();

      expect(json['content'], 'Hello world');
      expect(json['isComplete'], false);
    });

    test('should deserialize from json', () {
      final Map<String, Object> json = <String, Object>{
        'content': 'Test',
        'isComplete': true,
        'runtimeType': 'text',
      };

      final LlmStreamChunk chunk = LlmStreamChunk.fromJson(json);

      expect(
        chunk.maybeWhen(text: (String c, bool i) => true, orElse: () => false),
        true,
      );
      expect(chunk.whenOrNull(text: (String c, bool i) => c), 'Test');
    });

    test('should handle error type', () {
      const LlmStreamChunk chunk = LlmStreamChunk.error('Network error');

      expect(chunk.whenOrNull(error: (String m) => m), 'Network error');
    });
  });
}
