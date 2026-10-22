import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_splitter.dart';

void main() {
  group('SentenceSplitter', () {
    group('normal behavior (default maxBufferLength)', () {
      test('splits on sentence-ending punctuation', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final List<String> sentences = splitter
            .extractCompleteSentences('Hello there! How are you? Fine.');
        expect(sentences, <String>['Hello there!', 'How are you?', 'Fine.']);
        expect(splitter.incompleteBuffer, isEmpty);
      });

      test('keeps incomplete text in the buffer', () {
        final SentenceSplitter splitter = SentenceSplitter();
        expect(
          splitter.extractCompleteSentences('Hello there! How are'),
          <String>['Hello there!'],
        );
        expect(splitter.incompleteBuffer, ' How are');
      });

      test('ordinary sentences under the cap are unaffected', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final String text =
            "This is a perfectly ordinary sentence that flows along "
            "without any interruption and stays comfortably under the "
            "buffer cap. And here follows a second one.";
        final List<String> sentences = splitter
            .extractCompleteSentences(text);
        expect(sentences.length, 2);
      });
    });

    group('max-length flush', () {
      test('a 400-char unpunctuated run is flushed in bounded chunks', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final String longRun =
            List<String>.generate(80, (int i) => 'word$i').join(' ');
        expect(longRun.length, greaterThan(400));

        final List<String> chunks = <String>[];
        // Simulate streaming: small deltas, as SSE chunks arrive.
        for (int i = 0; i < longRun.length; i += 20) {
          chunks.addAll(
            splitter.extractCompleteSentences(
              longRun.substring(i, (i + 20).clamp(0, longRun.length)),
            ),
          );
        }

        expect(chunks, isNotEmpty);
        for (final String chunk in chunks) {
          expect(
            chunk.length,
            lessThanOrEqualTo(180 + 1), // flush cap plus slack
            reason: 'chunk too long: ${chunk.length}',
          );
        }
        // No content lost: emitted text plus whatever remains buffered.
        final String emitted = chunks.join(' ');
        expect(
          emitted.length + splitter.incompleteBuffer.trim().length,
          greaterThanOrEqualTo(longRun.length - 20),
        );
      });

      test('flushes at the last comma boundary', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final String prefix = 'w' * 70;
        final String longRun =
            '$prefix, and here comes a long tail without any period '
            '${'x' * 120}';
        final List<String> chunks = splitter
            .extractCompleteSentences(longRun);

        expect(chunks, hasLength(1));
        expect(chunks.first, startsWith(prefix));
        // Remainder stays buffered for the next call; only the boundary
        // space is consumed.
        expect(splitter.incompleteBuffer, isNotEmpty);
        expect(
          chunks.first.length + 1 + splitter.incompleteBuffer.length,
          longRun.length,
        );
      });

      test('hard-flushes when no soft boundary exists', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final List<String> chunks = splitter
            .extractCompleteSentences('b' * 200);
        expect(chunks, <String>['b' * 200]);
        expect(splitter.incompleteBuffer, isEmpty);
      });

      test('a custom smaller maxBufferLength is honored', () {
        final SentenceSplitter splitter = SentenceSplitter(maxBufferLength: 50);
        final List<String> chunks = splitter
            .extractCompleteSentences('c' * 120);
        expect(chunks, hasLength(1));
        expect(chunks.first, 'c' * 120);
      });

      test('streaming across multiple calls keeps flushing', () {
        final SentenceSplitter splitter = SentenceSplitter();
        final List<String> all = <String>[];
        for (int i = 0; i < 20; i++) {
          all.addAll(splitter.extractCompleteSentences('word ' * 4));
        }
        // No punctuation anywhere, yet chunks are emitted instead of growing.
        expect(all, isNotEmpty);
        for (final String chunk in all) {
          expect(chunk.length, lessThanOrEqualTo(180 + 1));
        }
      });
    });
  });
}
