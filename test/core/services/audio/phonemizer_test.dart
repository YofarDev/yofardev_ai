import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/viseme.dart';
import 'package:yofardev_ai/core/services/audio/phonemizer.dart';

const TextPhonemizer _phonemizer = TextPhonemizer();

List<Viseme> _visemes(String text, {String language = 'en'}) => <Viseme>[
  for (final PhonemeToken t in _phonemizer.phonemize(text, language: language))
    t.viseme,
];

/// The visemes of each word, in order.
List<List<Viseme>> _words(String text, {String language = 'en'}) {
  final List<List<Viseme>> out = <List<Viseme>>[];
  for (final PhonemeToken t in _phonemizer.phonemize(
    text,
    language: language,
  )) {
    if (out.length <= t.word) {
      out.add(<Viseme>[]);
    }
    out[t.word].add(t.viseme);
  }
  return out;
}

void main() {
  group('diphthong glides (critic round 7)', () {
    test('an English long o glides to ou: "know", "so", "boat"', () {
      for (final String w in <String>['know', 'so', 'boat']) {
        final PhonemeToken o = _phonemizer
            .phonemize(w)
            .firstWhere((PhonemeToken t) => t.viseme == Viseme.oh);
        expect(o.glide, Viseme.ou, reason: w);
      }
      expect(
        _phonemizer
            .phonemize('know')
            .where((PhonemeToken t) => t.viseme != Viseme.oh)
            .every((PhonemeToken t) => t.glide == null),
        isTrue,
      );
    });

    test('a French o is pure', () {
      for (final PhonemeToken t in _phonemizer.phonemize(
        'beau mot',
        language: 'fr',
      )) {
        expect(t.glide, isNull, reason: '$t');
      }
    });

    test('the glide takes part in equality', () {
      const PhonemeToken a = PhonemeToken(
        viseme: Viseme.oh,
        vowel: true,
        word: 0,
        wordEnd: true,
      );
      const PhonemeToken b = PhonemeToken(
        viseme: Viseme.oh,
        vowel: true,
        word: 0,
        wordEnd: true,
        glide: Viseme.ou,
      );
      expect(a, isNot(b));
      expect(b.toString(), contains('ou'));
    });
  });

  group('TextPhonemizer (en)', () {
    test('"blue" starts with a lip closure and ends rounded', () {
      final List<Viseme> v = _visemes('blue');
      expect(v.first, Viseme.pp);
      expect(v.last, Viseme.ou);
      expect(v.length, inInclusiveRange(2, 3));
      expect(v, isNot(contains(Viseme.ih)));
      expect(v, isNot(contains(Viseme.aa)));
    });

    test('"so" ends on oh', () {
      expect(_visemes('so'), <Viseme>[Viseme.ss, Viseme.oh]);
    });

    test('"view" has ff, then ou', () {
      final List<Viseme> v = _visemes('view');
      expect(v.first, Viseme.ff);
      expect(v.indexOf(Viseme.ou), greaterThan(v.indexOf(Viseme.ff)));
      expect(v.last, Viseme.ou);
    });

    test('the irregular words of the lexicon', () {
      final Map<String, List<Viseme>> expected = <String, List<Viseme>>{
        'you': <Viseme>[Viseme.ih, Viseme.ou],
        'do': <Viseme>[Viseme.dd, Viseme.ou],
        'who': <Viseme>[Viseme.ou],
        'two': <Viseme>[Viseme.dd, Viseme.ou],
        'to': <Viseme>[Viseme.dd, Viseme.ou],
        'too': <Viseme>[Viseme.dd, Viseme.ou],
        'through': <Viseme>[Viseme.th, Viseme.rr, Viseme.ou],
        'go': <Viseme>[Viseme.kk, Viseme.oh],
        'no': <Viseme>[Viseme.nn, Viseme.oh],
        'know': <Viseme>[Viseme.nn, Viseme.oh],
        'oh': <Viseme>[Viseme.oh],
        'new': <Viseme>[Viseme.nn, Viseme.ou],
        'one': <Viseme>[Viseme.ou, Viseme.aa, Viseme.nn],
        'was': <Viseme>[Viseme.ou, Viseme.aa, Viseme.ss],
        'would': <Viseme>[Viseme.ou, Viseme.ou, Viseme.dd],
        'could': <Viseme>[Viseme.kk, Viseme.ou, Viseme.dd],
        'should': <Viseme>[Viseme.ch, Viseme.ou, Viseme.dd],
        'of': <Viseme>[Viseme.aa, Viseme.ff],
        'are': <Viseme>[Viseme.aa, Viseme.rr],
        'eye': <Viseme>[Viseme.aa, Viseme.ih],
        'i': <Viseme>[Viseme.aa, Viseme.ih],
      };
      expected.forEach((String word, List<Viseme> visemes) {
        expect(_visemes(word), visemes, reason: word);
      });
      // here / there / their: an r-coloured ending.
      for (final String w in <String>['here', 'there', 'their']) {
        expect(_visemes(w).last, Viseme.rr, reason: w);
      }
      expect(_visemes('there'), _visemes('their'));
    });

    test('the lexicon is case-insensitive ("I", "You")', () {
      expect(_visemes('I'), _visemes('i'));
      expect(_visemes('You'), _visemes('you'));
    });

    test('rules: digraphs and the silent final e', () {
      expect(_visemes('ship').first, Viseme.ch);
      expect(_visemes('phone').first, Viseme.ff);
      expect(_visemes('thin').first, Viseme.th);
      expect(_visemes('moon'), <Viseme>[Viseme.pp, Viseme.ou, Viseme.nn]);
      expect(_visemes('boat'), <Viseme>[Viseme.pp, Viseme.oh, Viseme.dd]);
      expect(_visemes('see'), <Viseme>[Viseme.ss, Viseme.ih]);
      // Magic e: "fine" is f-ai-n, the final e silent.
      expect(_visemes('fine'), <Viseme>[
        Viseme.ff,
        Viseme.aa,
        Viseme.ih,
        Viseme.nn,
      ]);
      expect(_visemes('sky'), <Viseme>[
        Viseme.ss,
        Viseme.kk,
        Viseme.aa,
        Viseme.ih,
      ]);
      expect(_visemes('quick').take(2), <Viseme>[Viseme.kk, Viseme.ou]);
      expect(_visemes('sing').last, Viseme.nn);
    });

    test('every p/b/m gives pp and every f/v/ph gives ff', () {
      final List<Viseme> v = _visemes('A fine view of five vines.');
      expect(v.where((Viseme x) => x == Viseme.ff).length, 6);
      final List<Viseme> p = _visemes('Maybe a big blue boat.');
      expect(p.where((Viseme x) => x == Viseme.pp).length, 5);
    });

    test('tokens carry word indices, word ends and the vowel flag', () {
      final List<PhonemeToken> t = _phonemizer.phonemize('So true.');
      expect(t.map((PhonemeToken x) => x.word).toSet(), <int>{0, 1});
      expect(t.where((PhonemeToken x) => x.wordEnd).length, 2);
      expect(t.last.wordEnd, isTrue);
      expect(t.first.vowel, isFalse); // s
      expect(t[1].vowel, isTrue); // o
      expect(_words('So true, you know.').length, 4);
    });

    test('markdown, emoji and URLs are stripped; digits are spelled out', () {
      expect(_visemes('😀 **hi** 42'), _visemes('hi forty two'));
      expect(
        _visemes('# Title\n- `code` [link](https://x.io/a)'),
        _visemes('Title code link'),
      );
      expect(
        _visemes('see https://example.com/path?q=1 now'),
        _visemes('see now'),
      );
      expect(_visemes('7'), _visemes('seven'));
      expect(_visemes('1,250'), _visemes('one thousand two hundred fifty'));
      expect(_visemes('3.5'), _visemes('three point five'));
    });

    test('no speakable Latin text gives an empty list', () {
      expect(_phonemizer.phonemize(''), isEmpty);
      expect(_phonemizer.phonemize('   '), isEmpty);
      expect(_phonemizer.phonemize('日本'), isEmpty);
      expect(_phonemizer.phonemize('😀 🎉'), isEmpty);
      expect(_phonemizer.phonemize('日本', language: 'fr'), isEmpty);
    });

    test('a locale tag selects the language', () {
      expect(
        _visemes('Bonjour', language: 'fr-FR'),
        _visemes('Bonjour', language: 'fr'),
      );
      expect(_visemes('so', language: 'en_US'), _visemes('so'));
    });
  });

  group('TextPhonemizer (fr)', () {
    test('"Bonjour" has a lip closure and a rounded ou', () {
      final List<Viseme> v = _visemes('Bonjour', language: 'fr');
      expect(v.first, Viseme.pp);
      expect(v, contains(Viseme.ou));
      expect(v, isNot(contains(Viseme.nn))); // the "on" is nasal
    });

    test('grapheme rules', () {
      List<Viseme> fr(String s) => _visemes(s, language: 'fr');
      expect(fr('beau'), <Viseme>[Viseme.pp, Viseme.oh]);
      expect(fr('chat'), <Viseme>[Viseme.ch, Viseme.aa]);
      expect(fr('photo'), <Viseme>[Viseme.ff, Viseme.oh, Viseme.dd, Viseme.oh]);
      expect(fr('maison'), <Viseme>[Viseme.pp, Viseme.e, Viseme.ss, Viseme.oh]);
      expect(fr('vous').last, Viseme.ou);
      expect(fr('parler').last, Viseme.e); // -er: é, the r silent
      expect(fr('lune'), <Viseme>[Viseme.nn, Viseme.ou, Viseme.nn]);
      expect(fr('feu'), <Viseme>[Viseme.ff, Viseme.oh]);
      expect(fr('qui').first, Viseme.kk);
      expect(fr('gens').first, Viseme.ch);
    });

    test('the lexicon covers common irregular words', () {
      List<Viseme> fr(String s) => _visemes(s, language: 'fr');
      expect(fr('est'), <Viseme>[Viseme.e]);
      expect(fr('et'), <Viseme>[Viseme.e]);
      expect(fr('oui'), <Viseme>[Viseme.ou, Viseme.ih]);
      expect(fr('femme'), <Viseme>[Viseme.ff, Viseme.aa, Viseme.pp]);
      expect(fr('monsieur').first, Viseme.pp);
      expect(fr('six'), <Viseme>[Viseme.ss, Viseme.ih, Viseme.ss]);
    });

    test('digits are spelled out in French', () {
      List<Viseme> fr(String s) => _visemes(s, language: 'fr');
      expect(fr('42'), fr('quarante deux'));
      expect(fr('71'), fr('soixante et onze'));
      expect(fr('80'), fr('quatre vingts'));
      expect(fr('2026'), fr('deux mille vingt six'));
    });
  });
}
