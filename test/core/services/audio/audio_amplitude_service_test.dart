import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/wav_amplitude_extractor.dart';

import 'wav_amplitude_extractor_test.dart';

class _MockAudioAnalyzer extends Mock implements AudioAnalyzer {}

void main() {
  group('AudioAmplitudeService.extractAmplitudes', () {
    late _MockAudioAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = _MockAudioAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('wav_service_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'a .wav path goes through the extractor, never the analyzer',
      () async {
        final Uint8List wav = buildWav(
          sampleRate: 24000,
          channelSamples: <List<double>>[List<double>.filled(24000, 0.5)],
        );
        final File file = File('${tempDir.path}/speech.wav')
          ..writeAsBytesSync(wav);

        final AudioAmplitudeService service = AudioAmplitudeService(
          analyzer: analyzer,
        );
        final List<int> amplitudes = await service.extractAmplitudes(file.path);

        // RMS of a constant 0.5 signal is 0.5 -> 50.
        expect(amplitudes.length, 40);
        expect(amplitudes.every((int a) => a == 50), isTrue);
        verifyNever(
          () => analyzer.getAmplitudes(
            any(),
            samplesPerSecond: any(named: 'samplesPerSecond'),
          ),
        );
        verifyNever(() => analyzer.getAmplitudes(any()));
      },
    );

    test('a .mp3 path calls the analyzer', () async {
      final File file = File('${tempDir.path}/speech.mp3')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      when(
        () => analyzer.getAmplitudes(file.path),
      ).thenAnswer((_) async => <int>[7, 8]);

      final AudioAmplitudeService service = AudioAmplitudeService(
        analyzer: analyzer,
      );
      final List<int> amplitudes = await service.extractAmplitudes(file.path);

      expect(amplitudes, <int>[7, 8]);
      verify(() => analyzer.getAmplitudes(file.path)).called(1);
    });

    test('a corrupt .wav falls back to the analyzer', () async {
      final File file = File('${tempDir.path}/broken.wav')
        ..writeAsBytesSync(<int>[0, 1, 2, 3]);
      when(
        () => analyzer.getAmplitudes(file.path),
      ).thenAnswer((_) async => <int>[9]);

      final AudioAmplitudeService service = AudioAmplitudeService(
        analyzer: analyzer,
      );
      final List<int> amplitudes = await service.extractAmplitudes(file.path);

      expect(amplitudes, <int>[9]);
      verify(() => analyzer.getAmplitudes(file.path)).called(1);
    });

    test('frameDuration is 25 ms (40 fps)', () {
      expect(
        AudioAmplitudeService.frameDuration,
        const Duration(milliseconds: 25),
      );
      const WavAmplitudeExtractor extractor = WavAmplitudeExtractor();
      expect(extractor.framesPerSecond, 40);
    });
  });
}
