import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/stream_processor/json_stream_extractor.dart';

void main() {
  group('JsonStreamExtractor (incremental)', () {
    test('streams text deltas across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "Hel'), 'Hel');
      expect(extractor.extractText('lo wor'), 'lo wor');
      // JSON-correct delta: the trailing `"` in the chunk is the string
      // terminator, not part of the text value ("Hello world. Done!").
      expect(extractor.extractText('ld. Done!"}'), 'ld. Done!');
      // Complete JSON re-emits the decoded value minus what was already
      // emitted: nothing new, so no delta.
      expect(extractor.extractText(''), isNull);
    });

    test('decodes simple escapes split across chunks exactly once', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(
        extractor.extractText('{"text": "a\\'),
        isNull,
      ); // lone backslash held
      // JSON-correct: the held tail re-parses from the first unflushed char,
      // so the "a" buffered before the split backslash is emitted here once.
      expect(extractor.extractText('nb'), 'a\nb');
      expect(extractor.extractText('c"}'), 'c');
    });

    test(r'decodes \uXXXX escapes split across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText(r'{"text": "\u00'), isNull);
      expect(extractor.extractText(r'41\u0042"}'), 'AB');
    });

    test('finds the text key when split across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"te'), isNull);
      expect(extractor.extractText('xt": "Hi"}'), 'Hi');
    });

    test('keeps escaped quotes inside the value', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(
        extractor.extractText(r'{"text": "He said \"hi\"'),
        'He said "hi"',
      );
      expect(extractor.extractText('!"}'), '!');
    });

    test('nested objects: outer text wins at close', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"meta": {"text": "inner"}, "te'), 'inner');
      expect(extractor.extractText('xt": "outer"}'), 'outer');
      expect(
        extractor.getLastFullJson(),
        '{"meta": {"text": "inner"}, "text": "outer"}',
      );
    });

    test('exposes raw content and resets', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      extractor.extractText('{"text": "abc"}');
      expect(extractor.getRawContent(), '{"text": "abc"}');
      extractor.clear();
      expect(extractor.getRawContent(), '');
      expect(extractor.extractText('{"text": "ne'), 'ne');
    });

    test('large reply stays linear: 2k chars in 40 chunks all extracted', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "'), isNull);
      for (int i = 0; i < 40; i++) {
        final String piece = 'chunk$i '.padRight(50, 'x');
        expect(extractor.extractText(piece), piece);
      }
      expect(extractor.extractText('"}'), isNot(contains('chunk')));
    });
  });
}
