import 'dart:typed_data';

/// Scales [samples] in place so the loudest one reaches [target]: Kokoro
/// speaks at about half of full scale, which under-drives the mouth (the
/// amplitude lip-sync reads RMS × 100) and plays quieter than Supertonic.
/// The gain is capped at [maxGain] so near-silence is not blown up.
void normalizePeak(
  Float32List samples, {
  double target = 0.95,
  double maxGain = 4,
}) {
  double peak = 0;
  for (final double sample in samples) {
    final double magnitude = sample.abs();
    if (magnitude > peak) peak = magnitude;
  }
  if (peak <= 0) return;
  final double gain = (target / peak).clamp(0, maxGain).toDouble();
  if (gain == 1) return;
  for (int i = 0; i < samples.length; i++) {
    samples[i] *= gain;
  }
}
