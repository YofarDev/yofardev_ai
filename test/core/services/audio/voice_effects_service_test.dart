import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/voice_effects_service.dart';
import 'package:yofardev_ai/core/services/audio/wav_pcm.dart';

void main() {
  group('VoiceEffectsService.applyVoiceEffects', () {
    late Directory tempDir;
    late String inputPath;
    late WavPcm dry;
    final VoiceEffectsService service = VoiceEffectsService();

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('voice_effects_test');
      inputPath = '${tempDir.path}/1730000000000.wav';
      final Float32List samples = Float32List(12000);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.5 * math.sin(2 * math.pi * 220 * i / 24000);
      }
      dry = WavPcm(sampleRate: 24000, samples: samples);
      File(inputPath).writeAsBytesSync(dry.encodePcm16());
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    List<String> filesInTempDir() =>
        tempDir.listSync().map((FileSystemEntity e) => e.path).toList();

    test('none returns the input path and writes nothing', () async {
      final String path = await service.applyVoiceEffects(
        inputPath,
        VoiceEffect.none,
      );

      expect(path, inputPath);
      expect(filesInTempDir(), <String>[inputPath]);
    });

    test(
      'batman writes <name>_fx.wav: processed, same count and rate',
      () async {
        final String path = await service.applyVoiceEffects(
          inputPath,
          VoiceEffect.batman,
        );

        expect(path, '${tempDir.path}/1730000000000_fx.wav');
        final WavPcm processed = WavPcm.decode(File(path).readAsBytesSync());
        expect(processed.sampleRate, 24000);
        expect(processed.samples.length, dry.samples.length);
        expect(processed.samples, isNot(orderedEquals(dry.samples)));
      },
    );

    test('a corrupt input returns the input path and writes nothing', () async {
      File(inputPath).writeAsBytesSync(<int>[1, 2, 3, 4]);

      final String path = await service.applyVoiceEffects(
        inputPath,
        VoiceEffect.robocop,
      );

      expect(path, inputPath);
      expect(filesInTempDir(), <String>[inputPath]);
    });
  });
}
