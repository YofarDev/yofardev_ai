import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/data/datasources/kokoro_tts_datasource.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_spec.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_synthesizer.dart';

import 'kokoro_test_fakes.dart';

void main() {
  late FakeKokoroEngine engine;
  late KokoroTtsDatasource subject;

  setUp(() {
    engine = FakeKokoroEngine(loaded: true);
    subject = KokoroTtsDatasource(
      engine: engine,
      outputPath: () async => '/tmp/1700000000000.wav',
    );
  });

  Future<String> say(String language) => subject.synthesize(
    text: 'Bonjour',
    language: language,
    voiceEffect: VoiceEffect.none,
  );

  test('is a TtsSynthesizer', () {
    expect(subject, isA<TtsSynthesizer>());
  });

  test('French speaks the blended voice slot through espeak fr', () async {
    final String path = await say('fr');

    expect(path, '/tmp/1700000000000.wav');
    final SynthesisCall call = engine.calls.single;
    expect(call.sid, KokoroModelSpec.voiceBlendSlot);
    expect(call.lang, 'fr');
    expect(call.outputPath, path);
    expect(call.text, 'Bonjour');
  });

  test('English (any region) speaks af_heart on the lexicon path', () async {
    await say('en');
    await say('en-US');

    for (final SynthesisCall call in engine.calls) {
      expect(call.sid, KokoroModelSpec.sidEnglish);
      expect(call.lang, isNull);
    }
  });

  test('a language without a Kokoro voice throws', () async {
    await expectLater(
      say('de'),
      throwsA(isA<TtsLanguageUnsupportedException>()),
    );
    expect(engine.calls, isEmpty);
  });

  test('throws TtsEngineNotReadyException until the engine loads', () async {
    final KokoroTtsDatasource notReady = KokoroTtsDatasource(
      engine: FakeKokoroEngine(),
      outputPath: () async => '/tmp/x.wav',
    );

    await expectLater(
      notReady.synthesize(
        text: 'Hi',
        language: 'en',
        voiceEffect: VoiceEffect.none,
      ),
      throwsA(isA<TtsEngineNotReadyException>()),
    );
  });

  test('supports only French and English', () {
    expect(KokoroTtsDatasource.supports('fr'), isTrue);
    expect(KokoroTtsDatasource.supports('fr_FR'), isTrue);
    expect(KokoroTtsDatasource.supports('EN'), isTrue);
    expect(KokoroTtsDatasource.supports('es'), isFalse);
  });
}
