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
                r.maybeWhen(sentence: (_, _) => true, orElse: () => false),
          )
          .toList();

      expect(sentences.length, greaterThanOrEqualTo(1));
      final SentenceChunk firstSentence = sentences.first;
      final String sentenceText = firstSentence.maybeWhen(
        sentence: (String text, _) => text,
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
                r.maybeWhen(sentence: (_, _) => true, orElse: () => false),
          )
          .toList();

      expect(sentences.length, greaterThan(0));
      final SentenceChunk firstSentence = sentences.first;
      final String sentenceText = firstSentence.maybeWhen(
        sentence: (String text, _) => text,
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

    test('should emit sentences before full JSON completion', () async {
      final StreamController<LlmStreamChunk> chunksController =
          StreamController<LlmStreamChunk>();
      final List<SentenceChunk> emittedChunks = <SentenceChunk>[];

      final Future<void> done = processor
          .processStream(chunksController.stream)
          .forEach(emittedChunks.add);

      chunksController.add(
        const LlmStreamChunk.text(
          content: '{"text":"Hello there. ',
          isComplete: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      int sentenceCount = emittedChunks.where((SentenceChunk chunk) {
        return chunk.maybeWhen(
          sentence: (String _, int _) => true,
          orElse: () => false,
        );
      }).length;
      expect(sentenceCount, 1);

      chunksController.add(
        const LlmStreamChunk.text(content: 'How are you', isComplete: false),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      sentenceCount = emittedChunks.where((SentenceChunk chunk) {
        return chunk.maybeWhen(
          sentence: (String _, int _) => true,
          orElse: () => false,
        );
      }).length;
      expect(sentenceCount, 1);

      chunksController.add(
        const LlmStreamChunk.text(content: '?"}', isComplete: true),
      );
      await chunksController.close();
      await done;

      sentenceCount = emittedChunks.where((SentenceChunk chunk) {
        return chunk.maybeWhen(
          sentence: (String _, int _) => true,
          orElse: () => false,
        );
      }).length;
      expect(sentenceCount, 2);
    });

    test('concurrent streams do not share sentence buffers', () async {
      final StreamController<LlmStreamChunk> controllerA =
          StreamController<LlmStreamChunk>();
      final StreamController<LlmStreamChunk> controllerB =
          StreamController<LlmStreamChunk>();

      final Stream<SentenceChunk> streamA = processor.processStream(
        controllerA.stream,
        expectJson: false,
      );
      final Stream<SentenceChunk> streamB = processor.processStream(
        controllerB.stream,
        expectJson: false,
      );

      final List<String> sentencesA = <String>[];
      final List<String> sentencesB = <String>[];
      final StreamSubscription<SentenceChunk> subA = streamA.listen(
        (SentenceChunk c) => c.when(
          sentence: (String t, int _) => sentencesA.add(t),
          metadata: (_) => null,
          complete: () => null,
          error: (_) => null,
        ),
      );
      final StreamSubscription<SentenceChunk> subB = streamB.listen(
        (SentenceChunk c) => c.when(
          sentence: (String t, int _) => sentencesB.add(t),
          metadata: (_) => null,
          complete: () => null,
          error: (_) => null,
        ),
      );

      // A ends with an incomplete fragment (no isComplete: true and no
      // complete chunk), so pre-fix it stays buffered in the SHARED splitter
      // and B's completion flush drains it into B's stream.
      controllerA.add(
        const LlmStreamChunk.text(
          content: 'From A. unfinished tail',
          isComplete: false,
        ),
      );
      controllerB.add(
        const LlmStreamChunk.text(content: 'From B. ', isComplete: true),
      );
      await Future<void>.delayed(Duration.zero);
      await controllerA.close();
      await controllerB.close();
      await Future<void>.delayed(Duration.zero);
      await subA.cancel();
      await subB.cancel();

      // Load-bearing: pre-fix, B's flush drains A's leftover into B's list.
      expect(sentencesB, <String>['From B.']);
    });
  });
}
