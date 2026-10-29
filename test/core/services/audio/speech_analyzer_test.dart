import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/performance/viseme.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/phoneme_aligner.dart';
import 'package:yofardev_ai/core/services/audio/phonemizer.dart';
import 'package:yofardev_ai/core/services/audio/speech_analyzer.dart';
import 'package:yofardev_ai/core/services/audio/wav_pcm.dart';

import 'wav_amplitude_extractor_test.dart';

class _MockAudioAnalyzer extends Mock implements AudioAnalyzer {}

/// A phonemizer with a G2P bug: it throws for any text.
class _ThrowingPhonemizer extends TextPhonemizer {
  const _ThrowingPhonemizer();

  @override
  List<PhonemeToken> phonemize(String text, {String language = 'en'}) =>
      throw RangeError('g2p bug');
}

/// An aligner with a bug: it throws for any input.
class _ThrowingAligner extends PhonemeAligner {
  const _ThrowingAligner();

  @override
  AlignedVisemes? align(List<PhonemeToken> tokens, SpeechFrames frames) =>
      throw StateError('aligner bug');
}

const SpeechAnalyzer _analyzer = SpeechAnalyzer();

/// The audio classifier alone (text alignment off): the fallback path,
/// where the text is only a hint for p/b/m and f/v.
const SpeechAnalyzer _classifier = SpeechAnalyzer(alignCostLimit: -1);

/// Harmonics of 140 Hz below 600 Hz (a closed back vowel: oh / ou).
final Map<double, double> _closedVowel = <double, double>{
  140: 1,
  280: 0.5,
  420: 0.33,
  560: 0.25,
};

/// The same tone plus a strong partial near 1.2 kHz (9 x 140 Hz): open `aa`.
final Map<double, double> _openVowel = <double, double>{
  ..._closedVowel,
  1260: 1.5,
};

/// The same tone plus a partial near 2.5 kHz (18 x 140 Hz): front `e`/`ih`.
final Map<double, double> _frontVowel = <double, double>{
  ..._closedVowel,
  2520: 0.8,
};

/// Sum of sinusoids (frequency -> relative amplitude), peak-normalised to
/// [gain]. [glideTo] bends every partial's frequency linearly by the ratio
/// `glideTo / 140` over the last [glideLength] seconds (phase continuous).
List<double> _tone(
  int sampleRate,
  double seconds,
  Map<double, double> partials, {
  double gain = 0.3,
  double? glideTo,
  double glideLength = 0,
}) {
  final int n = (sampleRate * seconds).round();
  final List<double> out = List<double>.filled(n, 0);
  final int glideStart = n - (sampleRate * glideLength).round();
  partials.forEach((double freq, double amp) {
    double phase = 0;
    for (int i = 0; i < n; i++) {
      double ratio = 1;
      if (glideTo != null && i >= glideStart) {
        final double p = (i - glideStart) / (n - glideStart);
        ratio = 1 + (glideTo / 140 - 1) * p;
      }
      phase += 2 * math.pi * freq * ratio / sampleRate;
      out[i] += amp * math.sin(phase);
    }
  });
  final double peak = out.fold<double>(
    0,
    (double m, double v) => math.max(m, v.abs()),
  );
  return <double>[for (final double v in out) v / peak * gain];
}

List<double> _silence(int sampleRate, double seconds) =>
    List<double>.filled((sampleRate * seconds).round(), 0);

/// Seeded noise band-limited to [lo, hi] Hz (a sum of random-phase
/// sinusoids), peak-normalised to [gain].
List<double> _bandNoise(
  int sampleRate,
  double seconds,
  double lo,
  double hi, {
  double gain = 0.2,
  int seed = 42,
}) {
  final math.Random random = math.Random(seed);
  final int n = (sampleRate * seconds).round();
  final List<double> out = List<double>.filled(n, 0);
  for (int c = 0; c < 200; c++) {
    final double freq = lo + random.nextDouble() * (hi - lo);
    final double phase0 = random.nextDouble() * 2 * math.pi;
    final double w = 2 * math.pi * freq / sampleRate;
    for (int i = 0; i < n; i++) {
      out[i] += math.sin(phase0 + w * i);
    }
  }
  final double peak = out.fold<double>(
    0,
    (double m, double v) => math.max(m, v.abs()),
  );
  return <double>[for (final double v in out) v / peak * gain];
}

WavPcm _pcm(List<double> samples, {int sampleRate = 24000}) =>
    WavPcm(sampleRate: sampleRate, samples: Float32List.fromList(samples));

/// Spans are sorted, non-empty, contiguous and cover [0, duration].
void _expectWellFormed(SpeechTimeline t) {
  if (t.visemes.isEmpty) {
    return;
  }
  expect(t.visemes.first.start, Duration.zero);
  expect(t.visemes.last.end, t.duration);
  for (int i = 0; i < t.visemes.length; i++) {
    final VisemeSpan s = t.visemes[i];
    expect(s.end, greaterThan(s.start));
    expect(s.weight, inInclusiveRange(0.15, 1.0));
    if (i > 0) {
      expect(s.start, t.visemes[i - 1].end);
      expect(s.viseme, isNot(t.visemes[i - 1].viseme));
    }
  }
}

/// Fraction of the timeline's duration held by [visemes].
double _share(SpeechTimeline t, Set<Viseme> visemes) {
  int us = 0;
  for (final VisemeSpan s in t.visemes) {
    if (visemes.contains(s.viseme)) {
      us += (s.end - s.start).inMicroseconds;
    }
  }
  return us / t.duration.inMicroseconds;
}

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  group('SpeechAnalyzer.analyze', () {
    test('a 0-sample file gives an empty timeline', () {
      final SpeechTimeline t = _analyzer.analyze(_pcm(<double>[]));
      expect(t.visemes, isEmpty);
      expect(t.marks, isEmpty);
      expect(t.duration, Duration.zero);
    });

    test('pure silence gives one sil span and no marks', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(_silence(24000, 1)),
        text: 'Hello there?',
      );
      expect(t.visemes, hasLength(1));
      expect(t.visemes.single.viseme, Viseme.sil);
      expect(t.visemes.single.end, const Duration(seconds: 1));
      expect(t.marks, isEmpty);
      expect(t.isQuestion, isTrue);
      _expectWellFormed(t);
    });

    test('a 140 Hz tone with harmonics under 600 Hz is mostly oh/ou', () {
      final WavPcm pcm = _pcm(_tone(24000, 1, _closedVowel));
      final SpeechTimeline t = _analyzer.analyze(pcm);
      _expectWellFormed(t);
      expect(_share(t, <Viseme>{Viseme.oh, Viseme.ou}), greaterThan(0.8));

      final List<double> f0 = <double>[
        for (final SpeechFrameFeatures f in _analyzer.features(pcm))
          if (f.f0 != null) f.f0!,
      ];
      expect(f0.length, greaterThan(30));
      for (final double hz in f0) {
        expect(hz, closeTo(140, 6));
      }
    });

    test('a strong 1.2 kHz partial makes it aa', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(_tone(24000, 1, _openVowel)),
      );
      _expectWellFormed(t);
      expect(_share(t, <Viseme>{Viseme.aa}), greaterThan(0.8));
    });

    test('a 2.5 kHz partial makes it e/ih', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(_tone(24000, 1, _frontVowel)),
      );
      _expectWellFormed(t);
      expect(_share(t, <Viseme>{Viseme.e, Viseme.ih}), greaterThan(0.8));
    });

    test('4-8 kHz noise is ss', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(_bandNoise(24000, 0.6, 4000, 8000)),
      );
      _expectWellFormed(t);
      expect(_share(t, <Viseme>{Viseme.ss}), greaterThan(0.8));
    });

    test('weak high-band noise is ff when the text has an f there', () {
      final List<double> signal = <double>[
        ..._bandNoise(24000, 0.15, 4000, 8000, gain: 0.03),
        ..._tone(24000, 0.5, _openVowel),
      ];
      final SpeechTimeline withF = _classifier.analyze(
        _pcm(signal),
        text: 'fa',
      );
      final SpeechTimeline withS = _classifier.analyze(
        _pcm(signal),
        text: 'sa',
      );
      expect(withF.spanAt(_ms(60))?.viseme, Viseme.ff);
      expect(withS.spanAt(_ms(60))?.viseme, Viseme.ss);
    });

    test('a p/b/m letter with no dip in the audio still gets a pp span', () {
      // "I'm a..." said without a pause: no closure in the signal
      final SpeechTimeline t = _classifier.analyze(
        _pcm(_tone(24000, 1.0, _openVowel)),
        text: 'aamaa',
      );
      final List<VisemeSpan> pp = <VisemeSpan>[
        for (final VisemeSpan s in t.visemes)
          if (s.viseme == Viseme.pp) s,
      ];
      expect(pp, hasLength(1));
      // the letter sits in the middle of the text
      expect(pp.single.start.inMilliseconds, inInclusiveRange(300, 650));
      expect(
        (pp.single.end - pp.single.start).inMilliseconds,
        greaterThanOrEqualTo(50),
      );
    });

    group('closures', () {
      final List<double> signal = <double>[
        ..._tone(24000, 0.5, _openVowel),
        ..._silence(24000, 0.08),
        ..._tone(24000, 0.5, _openVowel),
      ];

      VisemeSpan? closureSpan(SpeechTimeline t) {
        for (final VisemeSpan s in t.visemes) {
          if (s.start < _ms(580) && s.end > _ms(500) && s.viseme != Viseme.aa) {
            return s;
          }
        }
        return null;
      }

      test('an 80 ms gap with text "a ba" is a pp of at least 50 ms', () {
        final SpeechTimeline t = _classifier.analyze(
          _pcm(signal),
          text: 'a ba',
        );
        _expectWellFormed(t);
        final VisemeSpan? span = closureSpan(t);
        expect(span, isNotNull);
        expect(span!.viseme, Viseme.pp);
        expect(span.end - span.start, greaterThanOrEqualTo(_ms(50)));
      });

      test('with text "a da" the same gap is dd', () {
        final SpeechTimeline t = _classifier.analyze(
          _pcm(signal),
          text: 'a da',
        );
        _expectWellFormed(t);
        expect(closureSpan(t)?.viseme, Viseme.dd);
        expect(
          t.visemes.where((VisemeSpan s) => s.viseme == Viseme.pp),
          isEmpty,
        );
      });

      test('with no text a silent closure may be p/b/m', () {
        final SpeechTimeline t = _classifier.analyze(_pcm(signal));
        expect(closureSpan(t)?.viseme, Viseme.pp);
      });
    });

    test('two tones 300 ms apart give one pause of 300 ms', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(<double>[
          ..._tone(24000, 0.5, _openVowel),
          ..._silence(24000, 0.3),
          ..._tone(24000, 0.5, _openVowel),
        ]),
      );
      _expectWellFormed(t);
      final List<ProsodyMark> pauses = t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause)
          .toList();
      expect(pauses, hasLength(1));
      expect(pauses.single.length.inMilliseconds, inInclusiveRange(275, 325));
      expect(pauses.single.at.inMilliseconds, inInclusiveRange(475, 525));
      // A gap long enough to be a pause is not a lip closure.
      expect(t.visemes.where((VisemeSpan s) => s.viseme == Viseme.pp), isEmpty);
    });

    test('leading silence is measured to the first sound', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(<double>[
          ..._silence(24000, 0.2),
          ..._tone(24000, 0.5, _openVowel),
        ]),
      );
      expect(t.leadingSilence, _ms(200));
      // Edge silence is not a pause.
      expect(
        t.marks.where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause),
        isEmpty,
      );
    });

    test('a final 140 -> 190 Hz glide is a pitch peak and a question', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(_tone(24000, 1.6, _closedVowel, glideTo: 190, glideLength: 0.4)),
      );
      _expectWellFormed(t);
      final List<ProsodyMark> peaks = t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.pitchPeak)
          .toList();
      expect(peaks.where((ProsodyMark m) => m.at >= _ms(1200)), isNotEmpty);
      expect(peaks.every((ProsodyMark m) => m.strength <= 1), isTrue);
      expect(t.isQuestion, isTrue);
    });

    test('a flat tone is not a question; text decides when given', () {
      final WavPcm flat = _pcm(_tone(24000, 1, _closedVowel));
      expect(_analyzer.analyze(flat).isQuestion, isFalse);
      expect(_analyzer.analyze(flat, text: 'Really?').isQuestion, isTrue);
      final WavPcm rising = _pcm(
        _tone(24000, 1.6, _closedVowel, glideTo: 190, glideLength: 0.4),
      );
      expect(_analyzer.analyze(rising, text: 'Fine.').isQuestion, isFalse);
    });

    group('isQuestion reads the cleaned text', () {
      final WavPcm flat = _pcm(_tone(24000, 1, _closedVowel));
      final WavPcm rising = _pcm(
        _tone(24000, 1.6, _closedVowel, glideTo: 190, glideLength: 0.4),
      );

      for (final String text in <String>[
        'Ready? 😀',
        '**Ready?**',
        '"Ready?"',
        'Ready?!',
        'Ready?)',
        'Ready？',
        'Ready? 👍🏽 ',
        '«Ready ?»',
        '_Ready?_ ~',
      ]) {
        test('"$text" is a question', () {
          expect(_analyzer.analyze(flat, text: text).isQuestion, isTrue);
        });
      }

      for (final String text in <String>['Ready.', 'Ready!', 'Ready! 😀']) {
        test('"$text" is not a question, even on a rising voice', () {
          expect(_analyzer.analyze(rising, text: text).isQuestion, isFalse);
        });
      }

      test('no terminal punctuation: the voice decides', () {
        for (final String text in <String>['Ready', 'Ready 😀', '**Ready**']) {
          expect(
            _analyzer.analyze(rising, text: text).isQuestion,
            isTrue,
            reason: text,
          );
          expect(
            _analyzer.analyze(flat, text: text).isQuestion,
            isFalse,
            reason: text,
          );
        }
      });
    });

    test('a loud syllable among soft ones is a stress mark', () {
      final SpeechTimeline t = _analyzer.analyze(
        _pcm(<double>[
          ..._tone(24000, 0.3, _openVowel, gain: 0.08),
          ..._silence(24000, 0.06),
          ..._tone(24000, 0.3, _openVowel, gain: 0.4),
          ..._silence(24000, 0.06),
          ..._tone(24000, 0.3, _openVowel, gain: 0.08),
        ]),
      );
      final List<ProsodyMark> stress = t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.stress)
          .toList();
      expect(stress, hasLength(1));
      expect(stress.single.at.inMilliseconds, inInclusiveRange(360, 660));
    });

    for (final int rate in <int>[16000, 44100]) {
      test('$rate Hz input gives the same classes as 24 kHz', () {
        for (final Map<double, double> vowel in <Map<double, double>>[
          _closedVowel,
          _openVowel,
          _frontVowel,
        ]) {
          final List<Viseme> at24 = _analyzer
              .analyze(_pcm(_tone(24000, 1, vowel)))
              .visemes
              .map((VisemeSpan s) => s.viseme)
              .toList();
          final SpeechTimeline other = _analyzer.analyze(
            _pcm(_tone(rate, 1, vowel), sampleRate: rate),
          );
          _expectWellFormed(other);
          expect(other.visemes.map((VisemeSpan s) => s.viseme).toList(), at24);
        }
      });
    }

    test('clipped audio still gives a valid timeline', () {
      final List<double> clipped = <double>[
        for (final double v in _tone(24000, 1, _openVowel, gain: 1))
          (v * 5).clamp(-1.0, 1.0),
      ];
      final SpeechTimeline t = _analyzer.analyze(_pcm(clipped), text: 'Ah!');
      _expectWellFormed(t);
      expect(t.visemes, isNotEmpty);
    });

    test('non-finite samples do not throw', () {
      final List<double> broken = _tone(24000, 0.5, _openVowel)
        ..[100] = double.nan
        ..[200] = double.infinity;
      final SpeechTimeline t = _analyzer.analyze(_pcm(broken));
      _expectWellFormed(t);
    });

    test('a 6 s mixed signal analyses in under 150 ms', () {
      final List<double> mixed = <double>[];
      for (int i = 0; i < 4; i++) {
        mixed
          ..addAll(_tone(24000, 0.5, _openVowel))
          ..addAll(_silence(24000, 0.08))
          ..addAll(_tone(24000, 0.3, _frontVowel))
          ..addAll(_bandNoise(24000, 0.12, 4000, 8000, seed: i))
          ..addAll(_tone(24000, 0.4, _closedVowel))
          ..addAll(_silence(24000, 0.1));
      }
      expect(mixed.length, 24000 * 6);
      final WavPcm pcm = _pcm(mixed);
      // The app runs AOT-compiled code; the test runner JITs, so the first
      // call pays for compilation. One warm-up call keeps the budget about
      // the algorithm, with the 150 ms ceiling as the generous CI margin
      // (a typical warm run is a few tens of ms).
      _analyzer.analyze(pcm, text: 'warm up');
      final Stopwatch watch = Stopwatch()..start();
      final SpeechTimeline t = _analyzer.analyze(
        pcm,
        text: 'Maybe we should probably buy a big blue boat?',
      );
      watch.stop();
      _expectWellFormed(t);
      expect(watch.elapsedMilliseconds, lessThan(150));
    });
  });

  group('text alignment on real speech (say fixtures)', () {
    WavPcm fixture(String name) =>
        WavPcm.decode(File('test/fixtures/speech/$name.wav').readAsBytesSync());

    /// Each phonemizer token with the span the aligner gave it (the
    /// aligner's non-silence spans, in token order).
    List<(PhonemeToken, VisemeSpan)> tokenSpans(
      WavPcm pcm,
      String text, {
      String language = 'en',
    }) {
      final List<PhonemeToken> tokens = const TextPhonemizer().phonemize(
        text,
        language: language,
      );
      final AlignedVisemes aligned = _analyzer.align(
        pcm,
        text: text,
        language: language,
      )!;
      final List<VisemeSpan> spans = <VisemeSpan>[
        for (final VisemeSpan s in aligned.spans)
          if (s.viseme != Viseme.sil) s,
      ];
      expect(spans, hasLength(tokens.length));
      return <(PhonemeToken, VisemeSpan)>[
        for (int i = 0; i < tokens.length; i++) (tokens[i], spans[i]),
      ];
    }

    Duration centre(VisemeSpan s) => s.start + (s.end - s.start) ~/ 2;

    const Set<Viseme> rounded = <Viseme>{Viseme.ou, Viseme.oh, Viseme.rr};

    /// Rounded vowels stay rounded, and every lip closure and labiodental
    /// keeps a span of its own of at least 50 ms in the final timeline.
    void expectLabels(
      SpeechTimeline t,
      List<(PhonemeToken, VisemeSpan)> tokens,
      Set<int> roundedWords,
    ) {
      for (final (PhonemeToken token, VisemeSpan span) in tokens) {
        final VisemeSpan? out = t.spanAt(centre(span));
        if (token.vowel && roundedWords.contains(token.word)) {
          expect(
            rounded,
            contains(out?.viseme),
            reason: 'word ${token.word} vowel at ${centre(span)}',
          );
        }
        if (token.viseme == Viseme.ff || token.viseme == Viseme.pp) {
          expect(
            out?.viseme,
            token.viseme,
            reason: 'word ${token.word} at ${centre(span)}',
          );
          expect(out!.end - out.start, greaterThanOrEqualTo(_ms(50)));
        }
      }
    }

    const List<(String, String, Set<int>)> fixtures =
        <(String, String, Set<int>)>[
          ('blue_sky', 'The sky is blue.', <int>{3}),
          ('so_true', 'So true, you know.', <int>{0, 1, 2, 3}),
          ('fine_view', 'A fine view of five vines.', <int>{2}),
        ];

    for (final (String name, String text, Set<int> roundedWords) in fixtures) {
      test('$name: "$text" is aligned and labelled from the text', () {
        final WavPcm pcm = fixture(name);
        expect(
          _analyzer.align(pcm, text: text)!.costPerFrame,
          lessThanOrEqualTo(SpeechAnalyzer.maxAlignCost),
        );
        final SpeechTimeline t = _analyzer.analyze(pcm, text: text);
        _expectWellFormed(t);
        expect(t.visemes, isNot(_classifier.analyze(pcm, text: text).visemes));
        final List<(PhonemeToken, VisemeSpan)> tokens = tokenSpans(pcm, text);
        expect(
          tokens.where(
            ((PhonemeToken, VisemeSpan) x) => x.$1.viseme == Viseme.ff,
          ),
          hasLength(name == 'fine_view' ? 6 : 0),
        );
        expectLabels(t, tokens, roundedWords);
      });
    }

    test('French: "Bonjour, comment allez-vous ?" aligns with language fr', () {
      final WavPcm pcm = fixture('bonjour');
      const String text = 'Bonjour, comment allez-vous ?';
      expect(
        _analyzer.align(pcm, text: text, language: 'fr')!.costPerFrame,
        lessThanOrEqualTo(SpeechAnalyzer.maxAlignCost),
      );
      final SpeechTimeline t = _analyzer.analyze(
        pcm,
        text: text,
        language: 'fr',
      );
      _expectWellFormed(t);
      expect(t.isQuestion, isTrue);
      final List<(PhonemeToken, VisemeSpan)> tokens = tokenSpans(
        pcm,
        text,
        language: 'fr',
      );
      // b and m close the lips; "jour" and "vous" stay rounded.
      expect(
        tokens.where(
          ((PhonemeToken, VisemeSpan) x) => x.$1.viseme == Viseme.pp,
        ),
        hasLength(2),
      );
      final List<(PhonemeToken, VisemeSpan)> ou = <(PhonemeToken, VisemeSpan)>[
        for (final (PhonemeToken, VisemeSpan) x in tokens)
          if (x.$1.vowel && x.$1.viseme == Viseme.ou) x,
      ];
      expect(ou, hasLength(2));
      expectLabels(t, tokens, <int>{
        for (final (PhonemeToken, VisemeSpan) x in ou) x.$1.word,
      });
    });

    test('text that does not match the audio falls back to the classifier', () {
      final WavPcm pcm = fixture('blue_sky');
      const String wrong = 'Completely different words here.';
      expect(
        _analyzer.align(pcm, text: wrong)!.costPerFrame,
        greaterThan(SpeechAnalyzer.maxAlignCost),
      );
      expect(
        _analyzer.analyze(pcm, text: wrong),
        _classifier.analyze(pcm, text: wrong),
      );
    });

    /// [pcm] with [seconds] of digital silence on both ends.
    WavPcm padded(WavPcm pcm, double seconds) => WavPcm(
      sampleRate: pcm.sampleRate,
      samples: Float32List.fromList(<double>[
        ..._silence(pcm.sampleRate, seconds),
        ...pcm.samples,
        ..._silence(pcm.sampleRate, seconds),
      ]),
    );

    test('silent padding does not dilute a wrong caption into a pass', () {
      final WavPcm pcm = padded(fixture('blue_sky'), 1.5);
      const String wrong = 'Completely different words here.';
      expect(
        _analyzer.align(pcm, text: wrong)!.costPerFrame,
        greaterThan(SpeechAnalyzer.maxAlignCost),
      );
      expect(
        _analyzer.analyze(pcm, text: wrong),
        _classifier.analyze(pcm, text: wrong),
      );
      // the right text still aligns on the padded audio
      expect(
        _analyzer.align(pcm, text: 'The sky is blue.')!.costPerFrame,
        lessThanOrEqualTo(SpeechAnalyzer.maxAlignCost),
      );
    });

    for (final (String name, String text) in <(String, String)>[
      ('blue_sky', 'So true, you know.'),
      ('blue_sky', 'A fine view of five vines.'),
      ('so_true', 'The sky is blue.'),
      ('so_true', 'A fine view of five vines.'),
      ('fine_view', 'The sky is blue.'),
      ('fine_view', 'So true, you know.'),
    ]) {
      test('$name with "$text" (another fixture\'s text) falls back', () {
        final WavPcm pcm = fixture(name);
        expect(
          _analyzer.align(pcm, text: text)!.costPerFrame,
          greaterThan(SpeechAnalyzer.maxAlignCost),
        );
        expect(
          _analyzer.analyze(pcm, text: text),
          _classifier.analyze(pcm, text: text),
        );
      });
    }

    test('a French caption read as English on so_true falls back', () {
      final WavPcm pcm = fixture('so_true');
      const String text = 'Bonjour, comment allez-vous ?';
      expect(
        _analyzer.align(pcm, text: text)!.costPerFrame,
        greaterThan(SpeechAnalyzer.maxAlignCost),
      );
      expect(
        _analyzer.analyze(pcm, text: text),
        _classifier.analyze(pcm, text: text),
      );
    });

    test('captions with no phones give the classifier result', () {
      final WavPcm pcm = fixture('so_true');
      for (final String text in <String>[
        '',
        '日本語',
        'https://example.com/a?b=1',
      ]) {
        expect(_analyzer.align(pcm, text: text), isNull, reason: text);
        expect(
          _analyzer.analyze(pcm, text: text),
          _classifier.analyze(pcm, text: text),
          reason: text,
        );
      }
    });

    test('a phonemizer that throws falls back to the classifier', () {
      final WavPcm pcm = fixture('so_true');
      const String text = 'So true, you know.';
      const SpeechAnalyzer broken = SpeechAnalyzer(
        phonemizer: _ThrowingPhonemizer(),
      );
      expect(
        broken.analyze(pcm, text: text),
        _classifier.analyze(pcm, text: text),
      );
      expect(broken.align(pcm, text: text), isNull);
    });

    test('an aligner that throws falls back to the classifier', () {
      final WavPcm pcm = fixture('so_true');
      const String text = 'So true, you know.';
      const SpeechAnalyzer broken = SpeechAnalyzer(aligner: _ThrowingAligner());
      expect(
        broken.analyze(pcm, text: text),
        _classifier.analyze(pcm, text: text),
      );
    });

    test('odd captions never throw and give a well-formed timeline', () {
      final WavPcm pcm = fixture('so_true');
      final List<(String, String)> captions = <(String, String)>[
        ('', 'en'),
        ('   ', 'en'),
        ('😀 **hi** 42', 'en'),
        ('日本語のテキスト', 'en'),
        ('https://example.com/a?b=1', 'en'),
        ('# Title\n- [link](https://x.io) `code`', 'en'),
        ('1234567890123456789012', 'en'),
        ('3,14 % & 1 000', 'fr'),
        ("''' --- ... ?!", 'en'),
        ('Bonjour, comment allez-vous ?', 'en'),
        ('So true, you know.', 'fr'),
        ('So true, you know.', 'xx-YY'),
        ('a' * 400, 'en'),
        ('So true, you know. ' * 20, 'en'),
      ];
      for (final (String text, String language) in captions) {
        final SpeechTimeline t = _analyzer.analyze(
          pcm,
          text: text,
          language: language,
        );
        _expectWellFormed(t);
        expect(t.visemes, isNotEmpty, reason: text);
      }
    });

    test('prosody comes from the audio, aligned or not', () {
      final WavPcm pcm = fixture('so_true');
      const String text = 'So true, you know.';
      final SpeechTimeline aligned = _analyzer.analyze(pcm, text: text);
      final SpeechTimeline classified = _classifier.analyze(pcm, text: text);
      List<ProsodyMark> peaks(SpeechTimeline t) => t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.pitchPeak)
          .toList();
      expect(peaks(aligned), peaks(classified));
      expect(aligned.energy, classified.energy);
      expect(aligned.duration, classified.duration);
      expect(aligned.isQuestion, classified.isQuestion);
      // The comma pause is found either way.
      expect(
        aligned.marks.where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause),
        hasLength(1),
      );
    });

    test('a 6 s sentence of real speech analyses in under 150 ms', () {
      final List<double> samples = <double>[
        for (final String name in <String>[
          'blue_sky',
          'so_true',
          'fine_view',
          'so_true',
        ])
          ...fixture(name).samples,
      ];
      final WavPcm pcm = _pcm(samples, sampleRate: 16000);
      expect(pcm.duration, greaterThanOrEqualTo(const Duration(seconds: 6)));
      const String text =
          'The sky is blue. So true, you know. A fine view of five vines. '
          'So true, you know.';
      expect(
        _analyzer.align(pcm, text: text)!.costPerFrame,
        lessThanOrEqualTo(SpeechAnalyzer.maxAlignCost),
      );
      // One warm-up call (the test runner JITs; the app runs AOT code), then
      // the 150 ms budget with a generous CI margin.
      _analyzer.analyze(pcm, text: text);
      final Stopwatch watch = Stopwatch()..start();
      final SpeechTimeline t = _analyzer.analyze(pcm, text: text);
      watch.stop();
      _expectWellFormed(t);
      expect(watch.elapsedMilliseconds, lessThan(150));
    });
  });

  group('AudioAmplitudeService.analyzeSpeech', () {
    late Directory tempDir;
    late AudioAmplitudeService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('speech_analyzer_test');
      service = AudioAmplitudeService(analyzer: _MockAudioAnalyzer());
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('a WAV file gives a timeline (analysed in an isolate)', () async {
      final File file = File('${tempDir.path}/speech.wav')
        ..writeAsBytesSync(
          buildWav(
            sampleRate: 24000,
            channelSamples: <List<double>>[_tone(24000, 0.5, _openVowel)],
          ),
        );
      final SpeechTimeline? t = await service.analyzeSpeech(
        file.path,
        text: 'Ah?',
      );
      expect(t, isNotNull);
      expect(t!.visemes, isNotEmpty);
      expect(t.duration, _ms(500));
      expect(t.isQuestion, isTrue);
    });

    test('the language reaches the analyzer', () async {
      const String path = 'test/fixtures/speech/bonjour.wav';
      const String text = 'Bonjour, comment allez-vous ?';
      final SpeechTimeline? t = await service.analyzeSpeech(
        path,
        text: text,
        language: 'fr',
      );
      final WavPcm pcm = WavPcm.decode(File(path).readAsBytesSync());
      expect(t, _analyzer.analyze(pcm, text: text, language: 'fr'));
    });

    test('a .mp3 path gives null', () async {
      final File file = File('${tempDir.path}/speech.mp3')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      expect(await service.analyzeSpeech(file.path), isNull);
    });

    test('a corrupt WAV gives null', () async {
      final File file = File('${tempDir.path}/broken.wav')
        ..writeAsBytesSync(<int>[0, 1, 2, 3]);
      expect(await service.analyzeSpeech(file.path), isNull);
    });

    test('a missing file gives null', () async {
      expect(
        await service.analyzeSpeech('${tempDir.path}/missing.wav'),
        isNull,
      );
    });
  });
}
