import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/voice_fx/voice_fx.dart';

const int _rate = 24000;

/// One second (unless [seconds]) of a sine at [hz], sampled at [rate].
Float32List _sine(
  double hz, {
  double amplitude = 0.5,
  double seconds = 1,
  int rate = _rate,
}) {
  final int count = (seconds * rate).round();
  final Float32List samples = Float32List(count);
  for (int i = 0; i < count; i++) {
    samples[i] = amplitude * math.sin(2 * math.pi * hz * i / rate);
  }
  return samples;
}

double _peak(Float32List samples) {
  double peak = 0;
  for (final double s in samples) {
    peak = math.max(peak, s.abs());
  }
  return peak;
}

double _rms(Float32List samples) {
  double sum = 0;
  for (final double s in samples) {
    sum += s * s;
  }
  return math.sqrt(sum / samples.length);
}

/// The frequency of [samples] between the sample indices [from] and [to],
/// from its zero crossings (a sine crosses zero twice per period).
double _zeroCrossingHz(Float32List samples, int from, int to) {
  int crossings = 0;
  for (int i = from + 1; i < to; i++) {
    if ((samples[i - 1] < 0) != (samples[i] < 0)) {
      crossings++;
    }
  }
  return crossings / 2 / ((to - from) / _rate);
}

void main() {
  group('VoiceFx.process', () {
    for (final VoiceEffect effect in VoiceEffect.values) {
      group(effect.name, () {
        test('keeps the sample count', () {
          expect(VoiceFx.process(_sine(220), _rate, effect).length, _rate);
        });

        test('keeps silence silent', () {
          final Float32List out = VoiceFx.process(
            Float32List(_rate),
            _rate,
            effect,
          );

          expect(out.every((double s) => s.abs() < 1e-6), isTrue);
        });

        test('returns a new list and leaves its input untouched', () {
          final Float32List input = _sine(220);
          final Float32List before = Float32List.fromList(input);

          final Float32List out = VoiceFx.process(input, _rate, effect);

          expect(identical(out, input), isFalse);
          expect(input, before);
        });

        test('stays finite at 8 kHz (filter corners above Nyquist)', () {
          final Float32List out = VoiceFx.process(
            _sine(220, rate: 8000),
            8000,
            effect,
          );

          expect(out.every((double s) => s.isFinite), isTrue);
        });
      });
    }

    test('none returns the same samples', () {
      final Float32List input = _sine(220);

      expect(VoiceFx.process(input, _rate, VoiceEffect.none), input);
    });

    group('batman', () {
      test('lowers a 220 Hz tone to about 171.6 Hz (ratio 0.78)', () {
        final Float32List out = VoiceFx.process(
          _sine(220),
          _rate,
          VoiceEffect.batman,
        );

        // The middle half second, clear of the delay line's start.
        expect(
          _zeroCrossingHz(out, _rate ~/ 4, _rate * 3 ~/ 4),
          closeTo(171.6, 8),
        );
      });

      test('peaks at 0.89', () {
        final Float32List out = VoiceFx.process(
          _sine(220),
          _rate,
          VoiceEffect.batman,
        );

        expect(_peak(out), closeTo(0.89, 1e-3));
      });
    });

    group('robocop', () {
      test('a 100 Hz tone comes out at least 6 dB below a 1 kHz tone', () {
        final double low = _rms(
          VoiceFx.processUnnormalized(_sine(100), _rate, VoiceEffect.robocop),
        );
        final double high = _rms(
          VoiceFx.processUnnormalized(_sine(1000), _rate, VoiceEffect.robocop),
        );

        expect(20 * math.log(high / low) / math.ln10, greaterThanOrEqualTo(6));
      });

      test('peaks at 0.89', () {
        final Float32List out = VoiceFx.process(
          _sine(440),
          _rate,
          VoiceEffect.robocop,
        );

        expect(_peak(out), closeTo(0.89, 1e-3));
      });
    });
  });
}
