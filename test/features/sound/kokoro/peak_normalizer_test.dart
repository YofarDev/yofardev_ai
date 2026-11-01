import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/peak_normalizer.dart';

void main() {
  test('raises the loudest sample to the target', () {
    final Float32List samples = Float32List.fromList(<double>[0.1, -0.4, 0.2]);

    normalizePeak(samples);

    expect(samples[1], closeTo(-0.95, 1e-6));
    expect(samples[0], closeTo(0.2375, 1e-6));
  });

  test('turns a too-loud clip down', () {
    final Float32List samples = Float32List.fromList(<double>[1.0, -0.5]);

    normalizePeak(samples);

    expect(samples[0], closeTo(0.95, 1e-6));
  });

  test('caps the gain on near-silence', () {
    final Float32List samples = Float32List.fromList(<double>[0.01, -0.02]);

    normalizePeak(samples, maxGain: 4);

    expect(samples[1], closeTo(-0.08, 1e-6));
  });

  test('silence stays silence', () {
    final Float32List samples = Float32List(4);

    normalizePeak(samples);

    expect(samples, everyElement(0));
  });
}
