import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/stream_processor/json_stream_extractor.dart';

void main() {
  group('JsonStreamExtractor (incremental)', () {
    test('only root speech is emitted at every chunk boundary', () {
      const String json =
          r'```json'
          '\n'
          r'{"meta":{"text":"secret","items":[{"message":"hidden"}]},'
          r'"note":"a quoted \"message\": \"trap\"",'
          r'"message":"Bonjour \"ami\". \u00e9\nFin \\ ok!",'
          r'"mood":"happy","background":"beach"}'
          '\n```';
      for (int size = 1; size <= json.length; size++) {
        final JsonStreamExtractor extractor = JsonStreamExtractor();
        final StringBuffer spoken = StringBuffer();
        for (int start = 0; start < json.length; start += size) {
          final int end = start + size > json.length
              ? json.length
              : start + size;
          spoken.write(extractor.extractText(json.substring(start, end)) ?? '');
        }
        expect(
          spoken.toString(),
          'Bonjour "ami". é\nFin \\ ok!',
          reason: 'chunk size $size',
        );
        expect(extractor.getLastFullJson(), isNotNull);
      }
    });

    test('non-speech replies never expose raw metadata', () {
      for (final String json in <String>[
        '{"mood":"happy","meta":{"message":"secret"}}',
        '{"message":null,"mood":"happy"}',
        '{"message":{"text":"secret"},"mood":"happy"}',
        '{"message":["secret"],"mood":"happy"}',
        '{"message":"","mood":"happy"}',
      ]) {
        final JsonStreamExtractor extractor = JsonStreamExtractor();
        expect(extractor.extractText(json), isNull);
        expect(extractor.getLastFullJson(), json);
        extractor.clear();
        expect(extractor.getLastFullJson(), isNull);
      }
    });

    test('each supported root text key streams once', () {
      for (final String key in <String>[
        'text',
        'content',
        'message',
        'response',
      ]) {
        final JsonStreamExtractor extractor = JsonStreamExtractor();
        expect(
          extractor.extractText('{"$key":"Hello!","mood":"happy"}'),
          'Hello!',
        );
        expect(extractor.extractText('{"message":"another reply"}'), isNull);
      }
    });

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
        'a',
      ); // only the incomplete escape is held
      // The escape completes without repeating the previously emitted prefix.
      expect(extractor.extractText('nb'), '\nb');
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

    test('nested objects never emit metadata text', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"meta": {"text": "inner"}, "te'), isNull);
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

    test(
      'regression: 3-char chunking of a full reply emits the whole text',
      () {
        final JsonStreamExtractor extractor = JsonStreamExtractor();
        const String json = '{"text": "Hello world. How are you?"}';
        final StringBuffer emitted = StringBuffer();
        for (int i = 0; i < json.length; i += 3) {
          final String? delta = extractor.extractText(
            json.substring(i, i + 3 > json.length ? json.length : i + 3),
          );
          if (delta != null) {
            emitted.write(delta);
          }
        }
        expect(emitted.toString(), 'Hello world. How are you?');
        expect(extractor.getLastFullJson(), json);
      },
    );

    test('regression: chunk boundary exactly at the colon', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text":'), isNull);
      expect(extractor.extractText(' "Hel'), 'Hel');
      expect(extractor.extractText('lo!"}'), 'lo!');
      expect(extractor.getLastFullJson(), '{"text": "Hello!"}');
    });

    test('regression: split key with close exposes full JSON', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"te'), isNull);
      expect(extractor.extractText('xt": "Done"}'), 'Done');
      expect(extractor.getLastFullJson(), '{"text": "Done"}');
    });

    test('regression: nested text in small chunks emits only outer', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      const String json = '{"meta": {"text": "inner"}, "text": "outer value"}';
      final List<String> deltas = <String>[];
      for (int i = 0; i < json.length; i += 6) {
        final int end = i + 6 > json.length ? json.length : i + 6;
        final String? delta = extractor.extractText(json.substring(i, end));
        if (delta != null) {
          deltas.add(delta);
        }
      }
      expect(deltas.join(), 'outer value');
      expect(extractor.getLastFullJson(), json);
    });
  });
}
