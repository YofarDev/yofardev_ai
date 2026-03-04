import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';

void main() {
  group('StreamProcessorService', () {
    late StreamProcessorService processor;

    setUp(() {
      processor = StreamProcessorService();
    });

    test('should extract complete sentences from text chunks', () async {
      final Stream<LlmStreamChunk> chunks =
          Stream<LlmStreamChunk>.fromIterable(<LlmStreamChunk>[
            const LlmStreamChunk.text(
              content: 'Hello world. How are you? ',
              isComplete: false,
            ),
            const LlmStreamChunk.text(content: 'I am fine!', isComplete: true),
          ]);

      final List<SentenceChunk> results = await processor
          .processStream(chunks, expectJson: false)
          .toList();

      final List<SentenceChunk> sentences = results
          .where(
            (SentenceChunk r) =>
                r.maybeWhen(sentence: (_, __) => true, orElse: () => false),
          )
          .toList();

      expect(sentences.length, greaterThanOrEqualTo(1));
      final SentenceChunk firstSentence = sentences.first;
      final String sentenceText = firstSentence.maybeWhen(
        sentence: (String text, __) => text,
        orElse: () => '',
      );
      expect(sentenceText, contains('Hello world'));
    });

    test('should handle JSON streaming', () async {
      final Stream<LlmStreamChunk> chunks =
          Stream<LlmStreamChunk>.fromIterable(<LlmStreamChunk>[
            const LlmStreamChunk.text(
              content: '{"text": "Hello',
              isComplete: false,
            ),
            const LlmStreamChunk.text(
              content: ' world. How are',
              isComplete: false,
            ),
            const LlmStreamChunk.text(content: ' you?"}', isComplete: true),
          ]);

      final List<SentenceChunk> results = await processor
          .processStream(chunks)
          .toList();

      final List<SentenceChunk> sentences = results
          .where(
            (SentenceChunk r) =>
                r.maybeWhen(sentence: (_, __) => true, orElse: () => false),
          )
          .toList();

      expect(sentences.length, greaterThan(0));
      final SentenceChunk firstSentence = sentences.first;
      final String sentenceText = firstSentence.maybeWhen(
        sentence: (String text, __) => text,
        orElse: () => '',
      );
      expect(sentenceText, contains('Hello world'));
    });

    test('should emit complete at end of stream', () async {
      final Stream<LlmStreamChunk> chunks = Stream<LlmStreamChunk>.fromIterable(
        <LlmStreamChunk>[
          const LlmStreamChunk.text(content: 'Test.', isComplete: true),
        ],
      );

      final List<SentenceChunk> results = await processor
          .processStream(chunks, expectJson: false)
          .toList();

      expect(
        results.any(
          (SentenceChunk r) =>
              r.maybeWhen(complete: () => true, orElse: () => false),
        ),
        isTrue,
      );
    });
  });
}
