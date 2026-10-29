/// Acoustic features of one 25 ms analysis frame.
class SpeechFrameFeatures {
  const SpeechFrameFeatures({
    required this.start,
    required this.rms,
    required this.db,
    required this.zcr,
    required this.bandShares,
    required this.periodicity,
    required this.f0,
  });

  /// Start of the frame in the audio.
  final Duration start;

  /// Linear RMS of the frame's samples.
  final double rms;

  /// RMS in dB relative to the sentence's 95th-percentile frame RMS.
  final double db;

  /// Zero-crossing rate (crossings per sample, 0-1).
  final double zcr;

  /// Energy shares of the bands 80-700, 700-1800, 1800-3500 and 3500-8000 Hz
  /// (sum 1, or all 0 when the frame has no energy in them).
  final List<double> bandShares;

  /// Peak of the normalised autocorrelation over 70-400 Hz (0-1).
  final double periodicity;

  /// Fundamental frequency in Hz when the frame is voiced, else null.
  final double? f0;

  bool get isVoiced => f0 != null;
}

/// The analysis frames of one sentence, computed once and shared by the
/// audio classifier and the text aligner.
class SpeechFrames {
  const SpeechFrames({required this.features, required this.duration});

  /// Frames this far under the sentence's p95 RMS are silence.
  static const double silenceDb = -35;

  /// One entry per analysis hop, in time order.
  final List<SpeechFrameFeatures> features;

  /// Length of the audio (the end of the last frame).
  final Duration duration;

  int get length => features.length;

  /// Start of frame [i]; [length] gives the end of the audio.
  Duration startOf(int i) =>
      i >= features.length ? duration : features[i].start;

  bool isSilent(int i) => features[i].db < silenceDb;
}
