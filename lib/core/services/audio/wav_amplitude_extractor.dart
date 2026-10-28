import 'dart:math' as math;
import 'dart:typed_data';

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
  List<int> extract(Uint8List wavBytes) {
    final _WavFile wav = _parse(wavBytes);
    final int window = math.max(1, wav.sampleRate ~/ framesPerSecond);
    final int totalSamples = wav.sampleCount;
    final int frameCount = (totalSamples + window - 1) ~/ window;
    final List<int> amplitudes = List<int>.filled(frameCount, 0);

    for (int frame = 0; frame < frameCount; frame++) {
      final int start = frame * window;
      final int end = math.min(start + window, totalSamples);
      double sumOfSquares = 0;
      for (int i = start; i < end; i++) {
        final double x = wav.normalizedSample(i);
        sumOfSquares += x * x;
      }
      final double rms = math.sqrt(sumOfSquares / (end - start));
      amplitudes[frame] = (rms * 100).round().clamp(0, 100);
    }

    return amplitudes;
  }

  /// Walks the RIFF chunk tree and reads `fmt ` + `data`.
  _WavFile _parse(Uint8List wavBytes) {
    if (wavBytes.length < 12 ||
        _chunkId(wavBytes, 0) != 'RIFF' ||
        _chunkId(wavBytes, 8) != 'WAVE') {
      throw const FormatException('Not a RIFF/WAVE file');
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    Uint8List? dataBytes;

    int offset = 12;
    while (offset + 8 <= wavBytes.length) {
      final String id = _chunkId(wavBytes, offset);
      final int declaredSize = ByteData.sublistView(
        wavBytes,
        offset + 4,
      ).getUint32(0, Endian.little);
      final int payloadStart = offset + 8;
      // A truncated `data` chunk uses the bytes actually present; every
      // other chunk is skipped (payload plus its pad byte when odd-sized).
      final int availableSize = math.min(
        declaredSize,
        wavBytes.length - payloadStart,
      );

      if (id == 'fmt ' && availableSize >= 16) {
        final ByteData fmt = ByteData.sublistView(wavBytes, payloadStart);
        audioFormat = fmt.getUint16(0, Endian.little);
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bitsPerSample = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataBytes = Uint8List.sublistView(
          wavBytes,
          payloadStart,
          payloadStart + availableSize,
        );
      }

      offset = payloadStart + declaredSize + (declaredSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null || channels == null || sampleRate == null) {
      throw const FormatException('Missing or malformed fmt chunk');
    }
    if (dataBytes == null) {
      throw const FormatException('Missing data chunk');
    }
    final bool isPcm16 = audioFormat == 1 && bitsPerSample == 16;
    final bool isPcm8 = audioFormat == 1 && bitsPerSample == 8;
    final bool isFloat32 = audioFormat == 3 && bitsPerSample == 32;
    if (!isPcm16 && !isPcm8 && !isFloat32) {
      throw FormatException(
        'Unsupported WAV format: audioFormat=$audioFormat, '
        'bitsPerSample=$bitsPerSample',
      );
    }

    return _WavFile(
      bytes: dataBytes,
      channels: channels,
      sampleRate: sampleRate,
      bytesPerSample: (bitsPerSample ?? 16) ~/ 8,
      isFloat: isFloat32,
    );
  }

  String _chunkId(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);
}

class _WavFile {
  _WavFile({
    required this.bytes,
    required this.channels,
    required this.sampleRate,
    required this.bytesPerSample,
    required this.isFloat,
  });

  final Uint8List bytes;
  final int channels;
  final int sampleRate;
  final int bytesPerSample;
  final bool isFloat;

  /// One view over the whole data chunk, shared by every sample read (a view
  /// per sample made extraction of long clips janky on the UI isolate).
  late final ByteData _view = ByteData.sublistView(bytes);

  int get sampleCount {
    final int frameBytes = channels * bytesPerSample;
    if (frameBytes == 0) {
      return 0;
    }
    return bytes.length ~/ frameBytes;
  }

  /// Normalised sample value in [-1, 1] of channel 0 at sample index [i].
  double normalizedSample(int i) {
    final int offset = (i * channels) * bytesPerSample;
    switch (bytesPerSample) {
      case 1:
        // 8-bit PCM is unsigned, centred on 128.
        return (bytes[offset] - 128) / 128;
      case 2:
        return _view.getInt16(offset, Endian.little) / 32768;
      case 4:
        if (isFloat) {
          return _view.getFloat32(offset, Endian.little);
        }
        return _view.getInt32(offset, Endian.little) / 2147483648;
      default:
        throw FormatException('Unsupported sample size: $bytesPerSample');
    }
  }
}
