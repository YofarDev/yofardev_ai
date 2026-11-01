import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/performance/viseme.dart';
import 'package:yofardev_ai/core/services/audio/phoneme_aligner.dart';
import 'package:yofardev_ai/core/services/audio/phonemizer.dart';
import 'package:yofardev_ai/core/services/audio/speech_frames.dart';

const PhonemeAligner _aligner = PhonemeAligner();
const Duration _frame = Duration(milliseconds: 25);

enum _Kind { noise, tone, bright, silence, murmur }

/// Synthetic frame features of each [_Kind] (the shapes the analyzer
/// measures on real speech: sibilant noise, a dark back vowel, an open
/// vowel, silence and a nasal murmur).
SpeechFrames _frames(List<(_Kind, int)> runs) {
  final List<SpeechFrameFeatures> out = <SpeechFrameFeatures>[];
  for (final (_Kind kind, int count) in runs) {
    for (int k = 0; k < count; k++) {
      final Duration start = _frame * out.length;
      out.add(switch (kind) {
        _Kind.noise => SpeechFrameFeatures(
          start: start,
          rms: 0.02,
          db: -16,
          zcr: 0.6,
          bandShares: const <double>[0, 0.01, 0.05, 0.94],
          periodicity: 0.2,
          f0: null,
        ),
        _Kind.tone => SpeechFrameFeatures(
          start: start,
          rms: 0.2,
          db: -1,
          zcr: 0.03,
          bandShares: const <double>[0.85, 0.12, 0.02, 0.01],
          periodicity: 0.95,
          f0: 150,
        ),
        _Kind.bright => SpeechFrameFeatures(
          start: start,
          rms: 0.2,
          db: -1,
          zcr: 0.05,
          bandShares: const <double>[0.2, 0.7, 0.07, 0.03],
          periodicity: 0.95,
          f0: 150,
        ),
        _Kind.silence => SpeechFrameFeatures(
          start: start,
          rms: 0,
          db: -120,
          zcr: 0,
          bandShares: const <double>[0, 0, 0, 0],
          periodicity: 0,
          f0: null,
        ),
        _Kind.murmur => SpeechFrameFeatures(
          start: start,
          rms: 0.04,
          db: -12,
          zcr: 0.02,
          bandShares: const <double>[0.97, 0.02, 0.01, 0],
          periodicity: 0.95,
          f0: 150,
        ),
      });
    }
  }
  return SpeechFrames(features: out, duration: _frame * out.length);
}

PhonemeToken _t(
  Viseme v, {
  bool vowel = false,
  int word = 0,
  bool end = false,
}) => PhonemeToken(viseme: v, vowel: vowel, word: word, wordEnd: end);

void _expectContiguous(AlignedVisemes a, Duration duration) {
  expect(a.spans.first.start, Duration.zero);
  expect(a.spans.last.end, duration);
  for (int i = 1; i < a.spans.length; i++) {
    expect(a.spans[i].start, a.spans[i - 1].end);
    expect(a.spans[i].end, greaterThan(a.spans[i].start));
  }
}

/// The spans that belong to tokens (the inserted silences removed).
List<VisemeSpan> _tokenSpans(AlignedVisemes a) => <VisemeSpan>[
  for (final VisemeSpan s in a.spans)
    if (s.viseme != Viseme.sil) s,
];

void main() {
  test(
    '[ss, oh] over 8 noise then 12 dark-tone frames: boundary at 8 +/- 1',
    () {
      final SpeechFrames frames = _frames(<(_Kind, int)>[
        (_Kind.noise, 8),
        (_Kind.tone, 12),
      ]);
      final AlignedVisemes? a = _aligner.align(<PhonemeToken>[
        _t(Viseme.ss),
        _t(Viseme.oh, vowel: true, end: true),
      ], frames);
      expect(a, isNotNull);
      _expectContiguous(a!, frames.duration);
      final List<VisemeSpan> tokens = _tokenSpans(a);
      expect(tokens.map((VisemeSpan s) => s.viseme), <Viseme>[
        Viseme.ss,
        Viseme.oh,
      ]);
      final int boundary = tokens[1].start.inMilliseconds ~/ 25;
      expect(boundary, inInclusiveRange(7, 9));
      expect(a.costPerFrame, lessThan(0.5));
    },
  );

  test('the spans hold one span per token, in order', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[
      (_Kind.bright, 8),
      (_Kind.murmur, 3),
      (_Kind.tone, 10),
    ]);
    final List<PhonemeToken> tokens = <PhonemeToken>[
      _t(Viseme.aa, vowel: true),
      _t(Viseme.nn),
      _t(Viseme.ou, vowel: true, end: true),
    ];
    final AlignedVisemes a = _aligner.align(tokens, frames)!;
    expect(
      _tokenSpans(a).map((VisemeSpan s) => s.viseme),
      tokens.map((PhonemeToken t) => t.viseme),
    );
    final VisemeSpan nasal = _tokenSpans(a)[1];
    expect(nasal.start.inMilliseconds ~/ 25, inInclusiveRange(7, 9));
    expect(nasal.end.inMilliseconds ~/ 25, inInclusiveRange(10, 12));
  });

  test('a th keeps two frames (50 ms) even where a vowel fits better', () {
    // "the": the audio is all vowel, a classifier would label no th at all
    final SpeechFrames frames = _frames(<(_Kind, int)>[(_Kind.bright, 4)]);
    final AlignedVisemes a = _aligner.align(<PhonemeToken>[
      _t(Viseme.th),
      _t(Viseme.e, vowel: true, end: true),
    ], frames)!;
    final VisemeSpan th = _tokenSpans(a).first;
    expect(th.viseme, Viseme.th);
    expect(th.end - th.start, greaterThanOrEqualTo(_frame * 2));
  });

  test('a lip closure takes the silent gap between two vowels', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[
      (_Kind.bright, 8),
      (_Kind.silence, 3),
      (_Kind.bright, 8),
    ]);
    final AlignedVisemes a = _aligner.align(<PhonemeToken>[
      _t(Viseme.aa, vowel: true),
      _t(Viseme.pp),
      _t(Viseme.aa, vowel: true, end: true),
    ], frames)!;
    final VisemeSpan closure = _tokenSpans(a)[1];
    expect(closure.viseme, Viseme.pp);
    expect(closure.start, _frame * 8);
    expect(closure.end, _frame * 11);
  });

  test('silences are inserted at word ends and at both ends', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[
      (_Kind.silence, 6),
      (_Kind.noise, 5),
      (_Kind.tone, 6),
      (_Kind.silence, 10),
      (_Kind.bright, 8),
      (_Kind.silence, 6),
    ]);
    final AlignedVisemes a = _aligner.align(<PhonemeToken>[
      _t(Viseme.ss),
      _t(Viseme.oh, vowel: true, end: true),
      _t(Viseme.aa, vowel: true, word: 1, end: true),
    ], frames)!;
    _expectContiguous(a, frames.duration);
    expect(a.spans.map((VisemeSpan s) => s.viseme), <Viseme>[
      Viseme.sil,
      Viseme.ss,
      Viseme.oh,
      Viseme.sil,
      Viseme.aa,
      Viseme.sil,
    ]);
    expect(a.spans[3].start, _frame * 17);
    expect(a.spans[3].end, _frame * 27);
  });

  test('no silence is inserted inside a word', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[
      (_Kind.noise, 5),
      (_Kind.silence, 8),
      (_Kind.tone, 6),
    ]);
    final AlignedVisemes a = _aligner.align(<PhonemeToken>[
      _t(Viseme.ss),
      _t(Viseme.oh, vowel: true, end: true),
    ], frames)!;
    expect(a.spans.map((VisemeSpan s) => s.viseme), <Viseme>[
      Viseme.ss,
      Viseme.oh,
    ]);
  });

  test('text that does not fit the audio costs more per frame', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[
      (_Kind.noise, 8),
      (_Kind.tone, 12),
      (_Kind.silence, 4),
      (_Kind.noise, 6),
    ]);
    final AlignedVisemes fit = _aligner.align(<PhonemeToken>[
      _t(Viseme.ss),
      _t(Viseme.oh, vowel: true),
      _t(Viseme.ss, end: true),
    ], frames)!;
    final AlignedVisemes misfit = _aligner.align(<PhonemeToken>[
      _t(Viseme.aa, vowel: true),
      _t(Viseme.nn),
      _t(Viseme.ih, vowel: true),
      _t(Viseme.pp, end: true),
    ], frames)!;
    expect(fit.costPerFrame, lessThan(misfit.costPerFrame * 0.5));
  });

  test('silent padding does not change the cost per frame', () {
    final List<PhonemeToken> misfit = <PhonemeToken>[
      _t(Viseme.aa, vowel: true),
      _t(Viseme.nn),
      _t(Viseme.ih, vowel: true),
      _t(Viseme.pp, end: true),
    ];
    const List<(_Kind, int)> speech = <(_Kind, int)>[
      (_Kind.noise, 8),
      (_Kind.tone, 12),
      (_Kind.silence, 4),
      (_Kind.noise, 6),
    ];
    final double bare = _aligner.align(misfit, _frames(speech))!.costPerFrame;
    final double padded = _aligner
        .align(
          misfit,
          _frames(<(_Kind, int)>[
            (_Kind.silence, 60),
            ...speech,
            (_Kind.silence, 60),
          ]),
        )!
        .costPerFrame;
    expect(padded, closeTo(bare, bare * 0.1));
  });

  test('empty tokens or empty frames give null', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[(_Kind.tone, 10)]);
    expect(_aligner.align(const <PhonemeToken>[], frames), isNull);
    expect(
      _aligner.align(<PhonemeToken>[
        _t(Viseme.aa, vowel: true, end: true),
      ], _frames(const <(_Kind, int)>[])),
      isNull,
    );
  });

  test('more tokens than the frames can hold give null', () {
    final SpeechFrames frames = _frames(<(_Kind, int)>[(_Kind.tone, 5)]);
    final List<PhonemeToken> tokens = <PhonemeToken>[
      for (int i = 0; i < 4; i++)
        _t(Viseme.aa, vowel: true, word: i, end: true),
    ];
    expect(_aligner.align(tokens, frames), isNull);
  });

  test('an oh with an ou glide splits 60/40 once it is 100 ms or longer', () {
    const PhonemeToken o = PhonemeToken(
      viseme: Viseme.oh,
      vowel: true,
      word: 0,
      wordEnd: true,
      glide: Viseme.ou,
    );
    // "know": n then a long o over 12 dark-tone frames (300 ms)
    final SpeechFrames long = _frames(<(_Kind, int)>[
      (_Kind.murmur, 3),
      (_Kind.tone, 12),
    ]);
    final List<VisemeSpan> spans = _tokenSpans(
      _aligner.align(<PhonemeToken>[_t(Viseme.nn), o], long)!,
    );
    expect(spans.map((VisemeSpan s) => s.viseme), <Viseme>[
      Viseme.nn,
      Viseme.oh,
      Viseme.ou,
    ]);
    final Duration vowel = spans[2].end - spans[1].start;
    final int frames = vowel.inMilliseconds ~/ 25;
    // the glide takes the last 40 % (whole frames)
    expect(spans[2].start - spans[1].start, _frame * (frames * 0.6).round());
    expect(spans[2].end, long.duration);
    // a short o keeps one span
    final SpeechFrames short = _frames(<(_Kind, int)>[
      (_Kind.murmur, 3),
      (_Kind.tone, 3),
    ]);
    expect(
      _tokenSpans(
        _aligner.align(<PhonemeToken>[_t(Viseme.nn), o], short)!,
      ).map((VisemeSpan s) => s.viseme),
      <Viseme>[Viseme.nn, Viseme.oh],
    );
  });
}
