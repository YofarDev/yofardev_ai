import 'dart:ui' show FrameTiming;

/// Frame-time statistics shared by the quality probe, the drift watch and
/// the frame-cost harness (M0 method).
abstract final class FrameStats {
  /// `max(build, raster)` of [timing], in ms: the thread that took longest.
  static double worstMs(FrameTiming timing) {
    final Duration worst = timing.buildDuration > timing.rasterDuration
        ? timing.buildDuration
        : timing.rasterDuration;
    return worst.inMicroseconds / 1000;
  }

  /// Nearest-rank percentile [q] (0..1] of [frameMs]; 0 when empty.
  static double percentileMs(List<double> frameMs, double q) {
    if (frameMs.isEmpty) {
      return 0;
    }
    final List<double> sorted = List<double>.of(frameMs)..sort();
    final int rank = (sorted.length * q).ceil().clamp(1, sorted.length);
    return sorted[rank - 1];
  }

  /// Nearest-rank P95 of [frameMs]; 0 when empty.
  static double p95Ms(List<double> frameMs) => percentileMs(frameMs, 0.95);

  /// The share (0..1) of [frameMs] strictly over [budgetMs]; 0 when empty.
  static double shareOver(List<double> frameMs, double budgetMs) {
    if (frameMs.isEmpty) {
      return 0;
    }
    int over = 0;
    for (final double ms in frameMs) {
      if (ms > budgetMs) {
        over++;
      }
    }
    return over / frameMs.length;
  }
}
