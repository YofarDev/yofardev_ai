import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_pcm.dart';

/// Pure-Dart WAV amplitude extraction.
///
/// The `audio_analyzer` plugin ignores `samplesPerSecond` on Android
/// (Amplituda, ~85 ms frames) while iOS/macOS give 25 ms RMS frames. All TTS
/// output in this app is WAV, so we parse the bytes ourselves to get
/// platform-independent 40 fps amplitudes.
class WavAmplitudeExtractor {
  const WavAmplitudeExtractor({this.framesPerSecond = 40});

  /// Number of amplitude frames per second of audio (matches the Swift
  /// plugin's `round(rms * 100).clamp(0, 100)` on 25 ms windows).
  final int framesPerSecond;

  /// Extracts one amplitude value (0-100) per [framesPerSecond] window of
  /// channel 0. Throws [FormatException] on an unsupported or corrupt file.
  List<int> extract(Uint8List wavBytes) =>
      extractFromPcm(WavPcm.decode(wavBytes));

  /// Same as [extract] on already decoded samples.
  List<int> extractFromPcm(WavPcm pcm) {
    final Float32List samples = pcm.samples;
    final int window = math.max(1, pcm.sampleRate ~/ framesPerSecond);
    final int totalSamples = samples.length;
    final int frameCount = (totalSamples + window - 1) ~/ window;
    final List<int> amplitudes = List<int>.filled(frameCount, 0);

    for (int frame = 0; frame < frameCount; frame++) {
      final int start = frame * window;
      final int end = math.min(start + window, totalSamples);
      double sumOfSquares = 0;
      for (int i = start; i < end; i++) {
        final double x = samples[i];
        sumOfSquares += x * x;
      }
      final double rms = math.sqrt(sumOfSquares / (end - start));
      amplitudes[frame] = (rms * 100).round().clamp(0, 100);
    }

    return amplitudes;
  }
}
