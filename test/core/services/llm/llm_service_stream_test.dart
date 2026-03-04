import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';

void main() {
  // Initialize Flutter test bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  late LlmService llmService;

  setUp(() {
    llmService = LlmService();
  });

  group('LlmService.promptModelStream', () {
    final List<LlmMessage> messages = <LlmMessage>[
      const LlmMessage(role: LlmMessageRole.user, body: 'Hello'),
    ];

    test('should emit error when no config is set', () async {
      // Create a new service instance with no configs
      final LlmService newService = LlmService();

      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in newService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
      )) {
        chunks.add(chunk);
      }

      expect(chunks.length, 1);
      expect(
        chunks[0].maybeWhen(
          error: (String msg) => msg.contains('No LLM Configuration'),
          orElse: () => false,
        ),
        isTrue,
      );
    });

    test('should have stream method defined', () {
      // Verify the method signature exists and returns a Stream
      final Stream<LlmStreamChunk> stream = llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'Test',
      );

      expect(stream, isA<Stream<LlmStreamChunk>>());
    });

    test('should accept all required parameters', () {
      // Verify that the stream method accepts all parameters correctly
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      final Stream<LlmStreamChunk> stream = llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
        returnJson: true,
        debugLogs: true,
      );

      expect(stream, isA<Stream<LlmStreamChunk>>());
    });
  });
}
