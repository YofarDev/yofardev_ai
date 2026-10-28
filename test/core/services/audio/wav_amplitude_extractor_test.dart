import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/wav_amplitude_extractor.dart';

Uint8List _ascii(String value) {
  final Uint8List bytes = Uint8List(value.length);
  for (int i = 0; i < value.length; i++) {
    bytes[i] = value.codeUnitAt(i);
  }
  return bytes;
}

Uint8List _u32(int value) => Uint8List(4)
  ..[0] = value & 0xff
  ..[1] = (value >> 8) & 0xff
  ..[2] = (value >> 16) & 0xff
  ..[3] = (value >> 24) & 0xff;

Uint8List _chunk(String id, Uint8List payload) {
  final int paddedLength = payload.length + (payload.length.isOdd ? 1 : 0);
  final Uint8List bytes = Uint8List(8 + paddedLength);
  bytes.setRange(0, 4, _ascii(id));
  bytes.setRange(4, 8, _u32(payload.length));
  bytes.setRange(8, 8 + payload.length, payload);
  return bytes;
}

/// Builds a RIFF WAVE file. Each entry of [channelSamples] holds the
/// normalised (-1..1) samples of one channel; frames are interleaved.
/// [declaredDataBytes] overrides the declared `data` chunk size (for the
/// truncation test); when [actualDataBytes] is given the payload is cut to it.
Uint8List buildWav({
  required int sampleRate,
  required List<List<double>> channelSamples,
  int audioFormat = 1,
  int bitsPerSample = 16,
  List<Uint8List> extraChunks = const <Uint8List>[],
  int? declaredDataBytes,
  int? actualDataBytes,
}) {
  final int channels = channelSamples.length;
  final int frames = channelSamples.first.length;
  final int bytesPerSample = bitsPerSample ~/ 8;
  final int blockAlign = channels * bytesPerSample;
  final int dataLength = frames * blockAlign;

  final Uint8List data = Uint8List(dataLength);
  final ByteData view = ByteData.view(data.buffer);
  for (int i = 0; i < frames; i++) {
    for (int c = 0; c < channels; c++) {
      final int offset = (i * channels + c) * bytesPerSample;
      final double v = channelSamples[c][i];
      switch (bitsPerSample) {
        case 8:
          data[offset] = ((v * 127.5) + 127.5).round().clamp(0, 255);
        case 16:
          view.setInt16(offset, (v * 32767).round(), Endian.little);
        case 32:
          if (audioFormat == 3) {
            view.setFloat32(offset, v, Endian.little);
          } else {
            view.setInt32(offset, (v * 2147483647).round(), Endian.little);
          }
      }
    }
  }

  final Uint8List dataChunk = _chunk(
    'data',
    actualDataBytes == null
        ? data
        : Uint8List.sublistView(data, 0, actualDataBytes),
  );
  if (declaredDataBytes != null) {
    dataChunk.setRange(4, 8, _u32(declaredDataBytes));
  }

  final Uint8List fmtPayload = Uint8List(16);
  ByteData.view(fmtPayload.buffer)
    ..setUint16(0, audioFormat, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, sampleRate, Endian.little)
    ..setUint32(8, sampleRate * blockAlign, Endian.little)
    ..setUint16(12, blockAlign, Endian.little)
    ..setUint16(14, bitsPerSample, Endian.little);

  final List<Uint8List> chunks = <Uint8List>[
    _chunk('fmt ', fmtPayload),
    ...extraChunks,
    dataChunk,
  ];
  final int riffSize =
      4 + chunks.fold<int>(0, (int sum, Uint8List c) => sum + c.length);
  return <Uint8List>[
    _ascii('RIFF'),
    _u32(riffSize),
    _ascii('WAVE'),
    ...chunks,
  ].fold<BytesBuilder>(BytesBuilder(), (BytesBuilder b, Uint8List part) {
    b.add(part);
    return b;
  }).toBytes();
}

List<double> _silence(int frames) => List<double>.filled(frames, 0);

List<double> _fullScaleSquare(int frames) {
  final List<double> samples = List<double>.filled(frames, 1);
  for (int i = 0; i < frames; i++) {
    samples[i] = i.isEven ? 1 : -1;
  }
  return samples;
}

List<double> _halfAmplitudeSine(int frames, {int sampleRate = 24000}) {
  const int frequencyHz = 440;
  final List<double> samples = List<double>.filled(frames, 0);
  for (int i = 0; i < frames; i++) {
    // 440 Hz spans 11 whole cycles per 25 ms window, so every window's RMS
    // matches 0.5/sqrt(2).
    samples[i] = 0.5 * math.sin(2 * math.pi * frequencyHz * i / sampleRate);
  }
  return samples;
}

void main() {
  const WavAmplitudeExtractor extractor = WavAmplitudeExtractor();

  group('WavAmplitudeExtractor', () {
    test('1 s mono 24 kHz full-scale square wave gives 40 frames of 100', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('silence gives all zeros', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_silence(24000)],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 0), isTrue);
    });

    test('0.5-amplitude sine gives about 35 (±1)', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_halfAmplitudeSine(24000)],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      for (final int a in amplitudes) {
        expect(a, inInclusiveRange(34, 36));
      }
    });

    test('stereo uses channel 0 only', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[
          _fullScaleSquare(24000),
          _silence(24000),
        ],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('skips a LIST chunk before data', () {
      final Uint8List listPayload =
          <Uint8List>[_ascii('INFOIART'), Uint8List(4)].fold<BytesBuilder>(
            BytesBuilder(),
            (BytesBuilder b, Uint8List p) {
              b.add(p);
              return b;
            },
          ).toBytes();
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
        extraChunks: <Uint8List>[_chunk('LIST', listPayload)],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('skips an odd-sized chunk with its pad byte', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
        extraChunks: <Uint8List>[_chunk('cue ', _ascii('abc'))],
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('truncated data chunk uses the bytes present', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
        declaredDataBytes: 24000 * 2,
        actualDataBytes: 600 * 2,
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 1);
      expect(amplitudes.single, 100);
    });

    test('0 samples gives an empty list', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_silence(0)],
      );

      expect(extractor.extract(wav), isEmpty);
    });

    test('non-PCM format throws FormatException', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_silence(600)],
        audioFormat: 7,
      );

      expect(() => extractor.extract(wav), throwsFormatException);
    });

    test('missing fmt chunk throws FormatException', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_silence(600)],
      );
      // Strip the fmt chunk: RIFF header (12 bytes) + fmt chunk (24 bytes).
      final Uint8List stripped = Uint8List.sublistView(wav, 12 + 8 + 16);
      stripped.setRange(0, 4, _ascii('RIFF'));
      stripped.setRange(4, 8, _u32(stripped.length - 8));
      stripped.setRange(8, 12, _ascii('WAVE'));

      expect(() => extractor.extract(stripped), throwsFormatException);
    });

    test('missing data chunk throws FormatException', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_silence(600)],
      );
      // Truncate right after the fmt chunk.
      final Uint8List truncated = Uint8List.sublistView(wav, 0, 12 + 8 + 16);

      expect(() => extractor.extract(truncated), throwsFormatException);
    });

    test('PCM 8-bit unsigned is supported with the same scale', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
        bitsPerSample: 8,
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('32-bit float (format 3) is supported with the same scale', () {
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[_fullScaleSquare(24000)],
        audioFormat: 3,
        bitsPerSample: 32,
      );

      final List<int> amplitudes = extractor.extract(wav);

      expect(amplitudes.length, 40);
      expect(amplitudes.every((int a) => a == 100), isTrue);
    });

    test('a 10 s 24 kHz clip extracts quickly (one data view, no per-sample '
        'allocation)', () {
      final int samples = 24000 * 10;
      final Uint8List wav = buildWav(
        sampleRate: 24000,
        channelSamples: <List<double>>[
          List<double>.generate(samples, (int i) => math.sin(i * 0.05) * 0.5),
        ],
      );
      extractor.extract(wav); // warm-up

      final Stopwatch watch = Stopwatch()..start();
      final List<int> amplitudes = extractor.extract(wav);
      watch.stop();

      expect(amplitudes.length, 400);
      // Measured ~1 ms (vs ~23 ms with a ByteData view per sample); the
      // bound is generous so a slow CI machine does not flake.
      expect(watch.elapsedMilliseconds, lessThan(100));
    });
  });
}
