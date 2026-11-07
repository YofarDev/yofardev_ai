import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../models/voice_effect.dart';

// ── Tuning: every value the effects use, to adjust by ear ──────────────────

// Batman: low, gravelly.

/// Pitch ratio of the shifter (0.78 ≈ −4.3 semitones).
const double _batmanPitchRatio = 0.78;

/// Delay window of the shifter, in seconds; its two taps sit half a window
/// apart.
const double _batmanWindowSeconds = 0.050;

/// Corner of the chest low shelf, in Hz.
const double _batmanShelfHz = 180;

/// Boost of that low shelf, in dB.
const double _batmanShelfGainDb = 5;

/// Slope of that low shelf (RBJ S; 1 is the steepest without a bump).
const double _batmanShelfSlope = 1;

/// Corner of the lowpass that darkens the top, in Hz.
const double _batmanLowpassHz = 4500;

/// Q of that lowpass (0.707: Butterworth).
const double _batmanLowpassQ = 0.707;

/// Drive into the grit's tanh.
const double _batmanGritDrive = 2.2;

/// Share of the saturated signal in the grit mix (the rest stays clean).
const double _batmanGritMix = 0.6;

/// Peak of the finished Batman voice.
const double _batmanPeak = 0.89;

// RoboCop: metallic, band-limited, synthetic.

/// Corner of the highpass of the helmet radio band, in Hz.
const double _robocopHighpassHz = 250;

/// Corner of the lowpass of the helmet radio band, in Hz.
const double _robocopLowpassHz = 3800;

/// Q of both band filters (0.707: Butterworth).
const double _robocopBandQ = 0.707;

/// Frequency of the ring modulator, in Hz.
const double _robocopRingHz = 55;

/// Depth of the ring modulation (0: none, 1: full).
const double _robocopRingDepth = 0.5;

/// Delay of the metallic feedback comb, in seconds.
const double _robocopCombSeconds = 0.007;

/// Feedback of that comb (below 1, or it rings on).
const double _robocopCombFeedback = 0.45;

/// Bit depth of the crush.
const int _robocopCrushBits = 10;

/// Peak the crush depth is set for: the clip is quantised as if it peaked
/// here, so a quiet and a loud clip crush alike.
const double _robocopCrushPeak = 0.89;

/// Peak of the finished RoboCop voice.
const double _robocopPeak = 0.89;

// Both.

/// Below this peak a clip is silence and is never normalised.
const double _silencePeak = 1e-6;

/// The costume voice effects, on mono samples in pure Dart. Every effect
/// keeps the sample count (lip-sync timing depends on it).
abstract final class VoiceFx {
  /// [samples] at [sampleRate] Hz with [effect] applied, as a new list of
  /// the same length: a copy for [VoiceEffect.none], else peak-normalised.
  static Float32List process(
    Float32List samples,
    int sampleRate,
    VoiceEffect effect,
  ) {
    final Float32List out = processUnnormalized(samples, sampleRate, effect);
    switch (effect) {
      case VoiceEffect.none:
        break;
      case VoiceEffect.batman:
        _normalizePeak(out, _batmanPeak);
      case VoiceEffect.robocop:
        _normalizePeak(out, _robocopPeak);
    }
    return out;
  }

  /// [process] without its final peak normalisation, so the effect's levels
  /// can be compared.
  @visibleForTesting
  static Float32List processUnnormalized(
    Float32List samples,
    int sampleRate,
    VoiceEffect effect,
  ) => switch (effect) {
    VoiceEffect.none => Float32List.fromList(samples),
    VoiceEffect.batman => _batman(samples, sampleRate),
    VoiceEffect.robocop => _robocop(samples, sampleRate),
  };

  static Float32List _batman(Float32List samples, int sampleRate) {
    final Float32List out = _pitchShift(
      samples,
      sampleRate,
      _batmanPitchRatio,
      _batmanWindowSeconds,
    );
    _Biquad.lowShelf(
      _batmanShelfHz,
      _batmanShelfGainDb,
      _batmanShelfSlope,
      sampleRate,
    ).filter(out);
    _Biquad.lowpass(_batmanLowpassHz, _batmanLowpassQ, sampleRate).filter(out);
    // Grit: a tanh saturation (1 stays 1), mixed with the clean signal.
    final double unity = _tanh(_batmanGritDrive);
    for (int i = 0; i < out.length; i++) {
      final double dry = out[i];
      final double wet = _tanh(_batmanGritDrive * dry) / unity;
      out[i] = (1 - _batmanGritMix) * dry + _batmanGritMix * wet;
    }
    return out;
  }

  static Float32List _robocop(Float32List samples, int sampleRate) {
    final Float32List out = Float32List.fromList(samples);
    _Biquad.highpass(_robocopHighpassHz, _robocopBandQ, sampleRate).filter(out);
    _Biquad.lowpass(_robocopLowpassHz, _robocopBandQ, sampleRate).filter(out);
    final double ringStep = 2 * math.pi * _robocopRingHz / sampleRate;
    for (int i = 0; i < out.length; i++) {
      out[i] *=
          1 - _robocopRingDepth + _robocopRingDepth * math.sin(ringStep * i);
    }
    // In place: out[i - delay] already holds the comb's output there.
    final int delay = (_robocopCombSeconds * sampleRate).round();
    for (int i = delay; i < out.length; i++) {
      out[i] += _robocopCombFeedback * out[i - delay];
    }
    _crush(out, _robocopCrushBits, _robocopCrushPeak);
    return out;
  }

  /// Lowers the pitch of [samples] by [ratio] at the same length: a delay
  /// line read by two taps half a window of [windowSeconds] apart. Each
  /// tap's delay sweeps the window and wraps; a raised-cosine (Hann) gain
  /// fades each tap out at its wrap, and the two gains always sum to 1.
  static Float32List _pitchShift(
    Float32List samples,
    int sampleRate,
    double ratio,
    double windowSeconds,
  ) {
    final Float32List out = Float32List(samples.length);
    final double window = windowSeconds * sampleRate;
    // A delay growing by (1 - ratio) samples per sample reads the input at
    // [ratio] times its speed.
    final double phaseStep = (1 - ratio) / window;
    double phase = 0;
    for (int n = 0; n < out.length; n++) {
      final double otherPhase = (phase + 0.5) % 1;
      final double gain = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
      out[n] =
          gain * _readAt(samples, n - phase * window) +
          (1 - gain) * _readAt(samples, n - otherPhase * window);
      phase = (phase + phaseStep) % 1;
    }
    return out;
  }

  /// [samples] at the fractional index [at], linearly interpolated; silence
  /// outside the clip.
  static double _readAt(Float32List samples, double at) {
    final int i = at.floor();
    final double frac = at - i;
    return _sampleAt(samples, i) * (1 - frac) +
        _sampleAt(samples, i + 1) * frac;
  }

  static double _sampleAt(Float32List samples, int i) =>
      i < 0 || i >= samples.length ? 0 : samples[i];

  /// Quantises [samples] in place to [bits] bits, the steps set for the clip
  /// normalised to [peak]; the clip keeps its own level.
  static void _crush(Float32List samples, int bits, double peak) {
    final double level = _peakOf(samples);
    final double gain = level < _silencePeak ? 1 : peak / level;
    final double steps = (1 << (bits - 1)) * gain;
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * steps).roundToDouble() / steps;
    }
  }

  /// Scales [samples] in place to a peak of [peak]; silence is left as is.
  static void _normalizePeak(Float32List samples, double peak) {
    final double level = _peakOf(samples);
    if (level < _silencePeak) return;
    final double gain = peak / level;
    for (int i = 0; i < samples.length; i++) {
      samples[i] *= gain;
    }
  }

  static double _peakOf(Float32List samples) {
    double level = 0;
    for (final double s in samples) {
      level = math.max(level, s.abs());
    }
    return level;
  }

  /// The hyperbolic tangent (`dart:math` has none), stable for any [x].
  static double _tanh(double x) {
    final double e = math.exp(-2 * x.abs());
    final double t = (1 - e) / (1 + e);
    return x < 0 ? -t : t;
  }
}

/// A biquad from the RBJ Audio EQ Cookbook (coefficients divided by a0),
/// run in Direct Form I from silence on every [filter] call. A corner at or
/// above Nyquist passes the signal through: the filter is unstable there.
final class _Biquad {
  const _Biquad(this._b0, this._b1, this._b2, this._a1, this._a2);

  factory _Biquad._normalised(
    double b0,
    double b1,
    double b2,
    double a0,
    double a1,
    double a2,
  ) => _Biquad(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);

  factory _Biquad.lowpass(double hz, double q, int sampleRate) {
    if (hz >= sampleRate / 2) return _passThrough;
    final double w0 = 2 * math.pi * hz / sampleRate;
    final double cosW0 = math.cos(w0);
    final double alpha = math.sin(w0) / (2 * q);
    return _Biquad._normalised(
      (1 - cosW0) / 2,
      1 - cosW0,
      (1 - cosW0) / 2,
      1 + alpha,
      -2 * cosW0,
      1 - alpha,
    );
  }

  factory _Biquad.highpass(double hz, double q, int sampleRate) {
    if (hz >= sampleRate / 2) return _passThrough;
    final double w0 = 2 * math.pi * hz / sampleRate;
    final double cosW0 = math.cos(w0);
    final double alpha = math.sin(w0) / (2 * q);
    return _Biquad._normalised(
      (1 + cosW0) / 2,
      -(1 + cosW0),
      (1 + cosW0) / 2,
      1 + alpha,
      -2 * cosW0,
      1 - alpha,
    );
  }

  factory _Biquad.lowShelf(
    double hz,
    double gainDb,
    double slope,
    int sampleRate,
  ) {
    if (hz >= sampleRate / 2) return _passThrough;
    final double a = math.pow(10, gainDb / 40).toDouble();
    final double w0 = 2 * math.pi * hz / sampleRate;
    final double cosW0 = math.cos(w0);
    final double alpha =
        math.sin(w0) / 2 * math.sqrt((a + 1 / a) * (1 / slope - 1) + 2);
    final double shelf = 2 * math.sqrt(a) * alpha;
    return _Biquad._normalised(
      a * ((a + 1) - (a - 1) * cosW0 + shelf),
      2 * a * ((a - 1) - (a + 1) * cosW0),
      a * ((a + 1) - (a - 1) * cosW0 - shelf),
      (a + 1) + (a - 1) * cosW0 + shelf,
      -2 * ((a - 1) + (a + 1) * cosW0),
      (a + 1) + (a - 1) * cosW0 - shelf,
    );
  }

  static const _Biquad _passThrough = _Biquad(1, 0, 0, 0, 0);

  final double _b0;
  final double _b1;
  final double _b2;
  final double _a1;
  final double _a2;

  /// Filters [samples] in place.
  void filter(Float32List samples) {
    double x1 = 0;
    double x2 = 0;
    double y1 = 0;
    double y2 = 0;
    for (int i = 0; i < samples.length; i++) {
      final double x0 = samples[i];
      final double y0 = _b0 * x0 + _b1 * x1 + _b2 * x2 - _a1 * y1 - _a2 * y2;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
      samples[i] = y0;
    }
  }
}
