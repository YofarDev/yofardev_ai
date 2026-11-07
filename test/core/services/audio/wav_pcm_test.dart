import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/wav_pcm.dart';

void main() {
  group('WavPcm.encodePcm16', () {
    test('round-trips through decode: same rate, length and samples', () {
      final Float32List samples = Float32List.fromList(<double>[
        0,
        0.5,
        -0.5,
        0.9,
        -0.9,
        0.123,
        -0.777,
        1,
        -1,
      ]);

      final WavPcm decoded = WavPcm.decode(
        WavPcm(sampleRate: 22050, samples: samples).encodePcm16(),
      );

      expect(decoded.sampleRate, 22050);
      expect(decoded.samples.length, samples.length);
      for (int i = 0; i < samples.length; i++) {
        expect(
          decoded.samples[i],
          closeTo(samples[i], 1 / 32767),
          reason: 'sample $i',
        );
      }
    });

    test('clamps samples outside [-1, 1] to full scale', () {
      final WavPcm decoded = WavPcm.decode(
        WavPcm(
          sampleRate: 24000,
          samples: Float32List.fromList(<double>[1.5, -2]),
        ).encodePcm16(),
      );

      expect(decoded.samples[0], closeTo(1, 1 / 32767));
      expect(decoded.samples[1], -1);
    });

    test('writes the canonical 44-byte mono 16-bit PCM header', () {
      final Uint8List bytes = WavPcm(
        sampleRate: 24000,
        samples: Float32List(3),
      ).encodePcm16();
      final ByteData header = ByteData.sublistView(bytes);

      expect(bytes.length, 44 + 6);
      expect(String.fromCharCodes(bytes, 0, 4), 'RIFF');
      expect(header.getUint32(4, Endian.little), 36 + 6);
      expect(String.fromCharCodes(bytes, 8, 16), 'WAVEfmt ');
      expect(header.getUint32(16, Endian.little), 16);
      expect(header.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(header.getUint32(24, Endian.little), 24000);
      expect(header.getUint32(28, Endian.little), 48000, reason: 'byte rate');
      expect(header.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(header.getUint16(34, Endian.little), 16, reason: 'bits');
      expect(String.fromCharCodes(bytes, 36, 40), 'data');
      expect(header.getUint32(40, Endian.little), 6);
    });
  });
}
