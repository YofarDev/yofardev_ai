import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/data/datasources/kokoro_tts_datasource.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_datasource.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/sherpa_kokoro_engine.dart';
import 'package:yofardev_ai/features/sound/domain/services/fallback_tts_synthesizer.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_synthesizer.dart';

void main() {
  test('TtsDatasource satisfies the domain TtsSynthesizer contract', () {
    final TtsSynthesizer synthesizer = TtsDatasource();
    expect(synthesizer, isA<TtsSynthesizer>());
  });

  test('Kokoro and the fallback chain satisfy the contract too', () {
    final TtsSynthesizer kokoro = KokoroTtsDatasource(
      engine: SherpaKokoroEngine(),
    );
    final TtsSynthesizer chain = FallbackTtsSynthesizer(
      primary: kokoro,
      fallback: TtsDatasource(),
    );
    expect(chain, isA<TtsSynthesizer>());
  });

  test('synthesize signature matches the queue call shape', () async {
    // Compile-time contract: the interface exposes exactly what the queue
    // uses. The assignment below fails to compile if the signature drifts.
    final TtsSynthesizer synthesizer = TtsDatasource();
    final Future<String> Function({
      required String text,
      required String language,
      required VoiceEffect voiceEffect,
    })
    synthesize = synthesizer.synthesize;
    expect(synthesize, isNotNull);
  });
}
