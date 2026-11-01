import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/domain/services/fallback_tts_synthesizer.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_synthesizer.dart';

class _Synth implements TtsSynthesizer {
  _Synth(this.name, {this.error});

  final String name;
  final Object? error;
  final List<String> spoken = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    final Object? failure = error;
    if (failure != null) throw failure;
    spoken.add('$language:$text');
    return '/$name.wav';
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

void main() {
  Future<String> say(TtsSynthesizer synth) => synth.synthesize(
    text: 'Salut',
    language: 'fr',
    voiceEffect: const VoiceEffect(pitch: 1, speedRate: 1),
  );

  test('speaks with the primary when it works', () async {
    final _Synth kokoro = _Synth('kokoro');
    final _Synth supertonic = _Synth('supertonic');
    final FallbackTtsSynthesizer subject = FallbackTtsSynthesizer(
      primary: kokoro,
      fallback: supertonic,
    );

    expect(await say(subject), '/kokoro.wav');
    expect(supertonic.spoken, isEmpty);
  });

  test('falls back with the same sentence when the primary throws', () async {
    final _Synth supertonic = _Synth('supertonic');
    final FallbackTtsSynthesizer subject = FallbackTtsSynthesizer(
      primary: _Synth('kokoro', error: StateError('not ready')),
      fallback: supertonic,
    );

    expect(await say(subject), '/supertonic.wav');
    expect(supertonic.spoken, <String>['fr:Salut']);
  });

  test('a fallback failure reaches the queue', () async {
    final FallbackTtsSynthesizer subject = FallbackTtsSynthesizer(
      primary: _Synth('kokoro', error: StateError('a')),
      fallback: _Synth('supertonic', error: StateError('b')),
    );

    await expectLater(say(subject), throwsStateError);
  });

  test('delete goes to the shared scratch cleanup', () async {
    final _Synth kokoro = _Synth('kokoro');
    final FallbackTtsSynthesizer subject = FallbackTtsSynthesizer(
      primary: kokoro,
      fallback: _Synth('supertonic'),
    );

    await subject.delete('/a.wav');
    expect(kokoro.deleted, <String>['/a.wav']);
  });

  test('without a fallback the primary error reaches the queue', () async {
    final FallbackTtsSynthesizer subject = FallbackTtsSynthesizer(
      primary: _Synth('kokoro', error: StateError('not ready')),
      fallback: null,
    );

    await expectLater(say(subject), throwsStateError);
  });
}
