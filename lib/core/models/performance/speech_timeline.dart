import 'package:freezed_annotation/freezed_annotation.dart';

import 'viseme.dart';

part 'speech_timeline.freezed.dart';

/// One viseme held from [start] (inclusive) to [end] (exclusive).
@freezed
sealed class VisemeSpan with _$VisemeSpan {
  const factory VisemeSpan({
    required Viseme viseme,
    required Duration start,
    required Duration end,

    /// 0-1, scales the jaw opening for this span.
    @Default(1.0) double weight,
  }) = _VisemeSpan;
}

/// Kinds of prosody events the performer acts on.
enum ProsodyMarkKind { pitchPeak, stress, pause }

/// A prosody event at [at]; [length] is only meaningful for pauses.
@freezed
sealed class ProsodyMark with _$ProsodyMark {
  const factory ProsodyMark({
    required ProsodyMarkKind kind,
    required Duration at,
    @Default(Duration.zero) Duration length,
    @Default(1.0) double strength,

    /// Pitch peaks only: how steeply the voice rose into the peak, 0 (flat)
    /// to 1 (a 60 % rise over the 200 ms before it); null when unknown (a
    /// typical rise).
    double? slope,
  }) = _ProsodyMark;
}

/// What the avatar's mouth and prosody follow while a sentence plays. Sorted,
/// non-overlapping [visemes]; the seam a phoneme source (Kokoro) plugs into.
@freezed
sealed class SpeechTimeline with _$SpeechTimeline {
  const factory SpeechTimeline({
    @Default(<VisemeSpan>[]) List<VisemeSpan> visemes,
    @Default(<ProsodyMark>[]) List<ProsodyMark> marks,
    @Default(Duration.zero) Duration duration,
    @Default(Duration.zero) Duration leadingSilence,
    @Default(false) bool isQuestion,

    /// Loudness per [energyFrame] (0-1, relative to the sentence's loud
    /// frames): the jaw follows it inside long vowels. Empty when unknown.
    @Default(<double>[]) List<double> energy,
    @Default(Duration(milliseconds: 25)) Duration energyFrame,
  }) = _SpeechTimeline;

  const SpeechTimeline._();

  /// Loudness at [t], linearly interpolated between frame centres; null
  /// when the timeline has no envelope.
  double? energyAt(Duration t) {
    if (energy.isEmpty || energyFrame <= Duration.zero) {
      return null;
    }
    final double x = t.inMicroseconds / energyFrame.inMicroseconds - 0.5;
    if (x <= 0) {
      return energy.first;
    }
    final int i = x.floor();
    if (i >= energy.length - 1) {
      return energy.last;
    }
    final double f = x - i;
    return energy[i] + (energy[i + 1] - energy[i]) * f;
  }

  /// The span covering [t] (start inclusive, end exclusive, so a boundary
  /// returns the later span), or null outside every span.
  VisemeSpan? spanAt(Duration t) {
    int lo = 0;
    int hi = visemes.length - 1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      final VisemeSpan span = visemes[mid];
      if (t < span.start) {
        hi = mid - 1;
      } else if (t >= span.end) {
        lo = mid + 1;
      } else {
        return span;
      }
    }
    return null;
  }

  /// Synthesises a timeline from 25 ms style amplitude [frame]s: amplitude 0
  /// is `sil`, anything else `aa` weighted by `amp / 30` (clamped 0.15-1).
  /// Equal neighbouring visemes merge (merged `aa` weight is the mean).
  /// Zero runs of at least 180 ms strictly inside the sentence become `pause`
  /// marks; `stress` marks sit on envelope peaks (top third by amplitude, at
  /// least 600 ms apart). [text] ending with `?` sets [isQuestion].
  static SpeechTimeline fromAmplitudes(
    List<int> amplitudes,
    Duration frame, {
    String? text,
  }) {
    final bool isQuestion = text?.trimRight().endsWith('?') ?? false;
    final int n = amplitudes.length;
    if (n == 0 || frame <= Duration.zero) {
      return SpeechTimeline(isQuestion: isQuestion);
    }

    final List<VisemeSpan> spans = <VisemeSpan>[];
    final List<ProsodyMark> marks = <ProsodyMark>[];
    int i = 0;
    while (i < n) {
      final bool silent = amplitudes[i] <= 0;
      // Frames merge only at the same mouth level (the legacy 0-4 thresholds),
      // so the fallback jaw still follows the loudness inside a voiced run.
      final int level = _level(amplitudes[i]);
      int j = i;
      double weightSum = 0;
      while (j < n && _level(amplitudes[j]) == level) {
        weightSum += silent ? 1.0 : (amplitudes[j] / 30).clamp(0.15, 1.0);
        j++;
      }
      final Duration start = frame * i;
      final Duration end = frame * j;
      spans.add(
        VisemeSpan(
          viseme: silent ? Viseme.sil : Viseme.aa,
          start: start,
          end: end,
          weight: silent ? 1.0 : weightSum / (j - i),
        ),
      );
      final bool inside = i > 0 && j < n;
      if (silent &&
          inside &&
          end - start >= const Duration(milliseconds: 180)) {
        marks.add(
          ProsodyMark(
            kind: ProsodyMarkKind.pause,
            at: start,
            length: end - start,
          ),
        );
      }
      i = j;
    }

    marks.addAll(_stressMarks(amplitudes, frame));
    marks.sort((ProsodyMark a, ProsodyMark b) => a.at.compareTo(b.at));

    final VisemeSpan first = spans.first;
    return SpeechTimeline(
      visemes: spans,
      marks: marks,
      duration: frame * n,
      leadingSilence: first.viseme == Viseme.sil ? first.end : Duration.zero,
      isQuestion: isQuestion,
      energy: <double>[
        for (final int a in amplitudes) (a / 30).clamp(0.0, 1.0),
      ],
      energyFrame: frame,
    );
  }

  static int _level(int amplitude) {
    if (amplitude <= 0) return 0;
    if (amplitude <= 5) return 1;
    if (amplitude <= 12) return 2;
    if (amplitude <= 18) return 3;
    return 4;
  }

  static List<ProsodyMark> _stressMarks(List<int> amps, Duration frame) {
    final List<int> voiced = amps.where((int a) => a > 0).toList()..sort();
    if (voiced.isEmpty) {
      return const <ProsodyMark>[];
    }
    final int threshold = voiced[(voiced.length * 2) ~/ 3];
    final int peak = voiced.last;
    final List<int> candidates = <int>[];
    for (int i = 0; i < amps.length; i++) {
      final int a = amps[i];
      final bool risesToHere = i == 0 || a >= amps[i - 1];
      final bool fallsAfter = i == amps.length - 1 || a >= amps[i + 1];
      if (a > 0 && a >= threshold && risesToHere && fallsAfter) {
        candidates.add(i);
      }
    }
    // Loudest first, earlier frame wins ties.
    candidates.sort((int a, int b) {
      final int byAmp = amps[b].compareTo(amps[a]);
      return byAmp != 0 ? byAmp : a.compareTo(b);
    });
    const Duration minGap = Duration(milliseconds: 600);
    final List<int> accepted = <int>[];
    for (final int c in candidates) {
      final bool farEnough = accepted.every(
        (int k) => (frame * (c - k)).abs() >= minGap,
      );
      if (farEnough) {
        accepted.add(c);
      }
    }
    return <ProsodyMark>[
      for (final int c in accepted)
        ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: frame * c,
          strength: amps[c] / peak,
        ),
    ];
  }
}
