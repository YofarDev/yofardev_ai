import '../../models/performance/viseme.dart';
import 'g2p/english_g2p.dart';
import 'g2p/french_g2p.dart';
import 'g2p/number_words.dart';

/// One phone of a sentence, reduced to the viseme the mouth shows for it.
class PhonemeToken {
  const PhonemeToken({
    required this.viseme,
    required this.vowel,
    required this.word,
    required this.wordEnd,
    this.pauseAfter = false,
    this.glide,
  });

  final Viseme viseme;

  /// A diphthong's second target: the vowel glides from [viseme] to it over
  /// its last 40 % (English long o, /oʊ/: oh to ou). Null for a pure phone.
  final Viseme? glide;

  /// A vowel (the syllable nucleus) rather than a consonant or a glide.
  final bool vowel;

  /// Index of the spoken word this phone belongs to (0-based, counting only
  /// words that produced phones).
  final int word;

  /// The last phone of its word (a pause may follow).
  final bool wordEnd;

  /// The last phone of a word followed by punctuation (`,` `.` `?` `!` `;`
  /// `:`, a dash, a bracket, a quote or a line break): where the speaker
  /// most likely pauses.
  final bool pauseAfter;

  @override
  bool operator ==(Object other) =>
      other is PhonemeToken &&
      other.viseme == viseme &&
      other.vowel == vowel &&
      other.word == word &&
      other.wordEnd == wordEnd &&
      other.pauseAfter == pauseAfter &&
      other.glide == glide;

  @override
  int get hashCode =>
      Object.hash(viseme, vowel, word, wordEnd, pauseAfter, glide);

  @override
  String toString() =>
      'PhonemeToken(${viseme.name}${glide == null ? '' : '>${glide!.name}'}'
      '${vowel ? ', vowel' : ''}, word $word'
      '${wordEnd ? ', end' : ''}${pauseAfter ? ', pause' : ''})';
}

/// Rule-based grapheme-to-viseme conversion for English and French (the
/// app's two languages): no dictionary package, no native dependency.
///
/// The text is cleaned first (markdown, emoji and URLs removed, digits spelled
/// out in the language), then each Latin-script word goes through an
/// exception lexicon of common irregular words or the language's letter rules
/// (digraphs first). Words in any other script are skipped, so text with no
/// Latin word gives an empty list.
///
/// Internal phone alphabet (one character each): consonants `p b m` (pp),
/// `f v` (ff), `T D` (th), `t d` (dd), `k g` (kk), `N n l` (nn), `s z` (ss),
/// `S Z C J` (ch: sh, zh, tch, dj), `r` (rr), `w` (ou glide), `j` (ih glide),
/// `h` (silent: the mouth takes the next vowel); vowels `a A` (aa), `e E @`
/// (e), `i I` (ih), `o O 2` (oh), `u U y` (ou), `R` (rr, the r-coloured
/// vowel).
class TextPhonemizer {
  const TextPhonemizer();

  /// Phones of [text] in [language] (`en`, `fr`, or a locale tag such as
  /// `fr-FR`; anything that is not French reads as English).
  List<PhonemeToken> phonemize(String text, {String language = 'en'}) {
    final bool french = isFrench(language);
    final String spelled = _spellNumbers(_stripMarkup(text), french);
    final List<PhonemeToken> out = <PhonemeToken>[];
    int word = 0;
    final List<RegExpMatch> matches = _word.allMatches(spelled).toList();
    for (int mi = 0; mi < matches.length; mi++) {
      final RegExpMatch m = matches[mi];
      final String w = m[0]!;
      final String gap = spelled.substring(
        m.end,
        mi + 1 < matches.length ? matches[mi + 1].start : spelled.length,
      );
      final bool pause = _pause.hasMatch(gap);
      final String phones = french ? FrenchG2p.word(w) : EnglishG2p.word(w);
      final List<String> sounds = <String>[
        for (final String p in phones.split(''))
          if (_phones[p] != null) p,
      ];
      for (int k = 0; k < sounds.length; k++) {
        final (Viseme, bool) sound = _phones[sounds[k]]!;
        out.add(
          PhonemeToken(
            viseme: sound.$1,
            vowel: sound.$2,
            word: word,
            wordEnd: k == sounds.length - 1,
            pauseAfter: pause && k == sounds.length - 1,
            glide: french ? null : _englishGlides[sounds[k]],
          ),
        );
      }
      if (sounds.isNotEmpty) {
        word++;
      }
    }
    return out;
  }

  /// Whether [language] (a code or a locale tag) is French.
  static bool isFrench(String language) =>
      language.toLowerCase().split(RegExp('[-_]')).first == 'fr';

  static const Map<String, (Viseme, bool)> _phones = <String, (Viseme, bool)>{
    'p': (Viseme.pp, false),
    'b': (Viseme.pp, false),
    'm': (Viseme.pp, false),
    'f': (Viseme.ff, false),
    'v': (Viseme.ff, false),
    'T': (Viseme.th, false),
    'D': (Viseme.th, false),
    't': (Viseme.dd, false),
    'd': (Viseme.dd, false),
    'k': (Viseme.kk, false),
    'g': (Viseme.kk, false),
    'N': (Viseme.nn, false),
    'n': (Viseme.nn, false),
    'l': (Viseme.nn, false),
    's': (Viseme.ss, false),
    'z': (Viseme.ss, false),
    'S': (Viseme.ch, false),
    'Z': (Viseme.ch, false),
    'C': (Viseme.ch, false),
    'J': (Viseme.ch, false),
    'r': (Viseme.rr, false),
    'w': (Viseme.ou, false),
    'j': (Viseme.ih, false),
    'a': (Viseme.aa, true),
    'A': (Viseme.aa, true),
    'e': (Viseme.e, true),
    'E': (Viseme.e, true),
    '@': (Viseme.e, true),
    'i': (Viseme.ih, true),
    'I': (Viseme.ih, true),
    'o': (Viseme.oh, true),
    'O': (Viseme.oh, true),
    '2': (Viseme.oh, true),
    'u': (Viseme.ou, true),
    'U': (Viseme.ou, true),
    'y': (Viseme.ou, true),
    'R': (Viseme.rr, true),
  };

  /// English diphthongs written as one phone: the long o is /oʊ/ (French o
  /// is pure). /aʊ/ and /aɪ/ are already two phones (`Au`, `Ai`).
  static const Map<String, Viseme> _englishGlides = <String, Viseme>{
    'o': Viseme.ou,
  };

  /// A run of Latin letters, with inner apostrophes ("don't", "c'est").
  static final RegExp _word = RegExp(
    r"\p{Script=Latin}+(?:['’]\p{Script=Latin}+)*",
    unicode: true,
  );

  /// Punctuation after a word that usually comes with a pause.
  static final RegExp _pause = RegExp(
    '[,.;:!?\u2026\u2013\u2014()"\u00ab\u00bb\n]',
  );

  static final RegExp _image = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
  static final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _url = RegExp(
    r'(?:https?://|www\.)\S+',
    caseSensitive: false,
  );
  static final RegExp _markup = RegExp(r'[*_`#>~|\\]');

  static String _stripMarkup(String text) => text
      .replaceAllMapped(_image, (Match m) => ' ${m[1]} ')
      .replaceAllMapped(_link, (Match m) => ' ${m[1]} ')
      .replaceAll(_url, ' ')
      .replaceAll(_markup, ' ');

  static final RegExp _enNumber = RegExp(
    r'\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?',
  );
  static final RegExp _frNumber = RegExp(r'\d+(?:,\d+)?');

  /// Above this many digits a number is read digit by digit.
  static const int _maxDigits = 12;

  static String _spellNumbers(String text, bool french) {
    final String withSymbols = text
        .replaceAll('%', french ? ' pour cent ' : ' percent ')
        .replaceAll('&', french ? ' et ' : ' and ');
    final RegExp pattern = french ? _frNumber : _enNumber;
    return withSymbols.replaceAllMapped(pattern, (Match m) {
      final String raw = m[0]!;
      final String separator = french ? ',' : '.';
      final int dot = raw.indexOf(separator);
      final String whole = (dot < 0 ? raw : raw.substring(0, dot)).replaceAll(
        ',',
        '',
      );
      final String fraction = dot < 0 ? '' : raw.substring(dot + 1);
      final StringBuffer out = StringBuffer(' ${_cardinal(whole, french)}');
      if (fraction.isNotEmpty) {
        // French reads the decimals as a number, English digit by digit.
        out.write(
          french
              ? ' virgule ${_cardinal(fraction, true)}'
              : ' point ${_digits(fraction, false)}',
        );
      }
      out.write(' ');
      return out.toString();
    });
  }

  static String _cardinal(String digits, bool french) {
    if (digits.length > _maxDigits) {
      return _digits(digits, french);
    }
    final int n = int.parse(digits);
    return french ? NumberWords.french(n) : NumberWords.english(n);
  }

  static String _digits(String digits, bool french) => <String>[
    for (final String d in digits.split(''))
      french
          ? NumberWords.french(int.parse(d))
          : NumberWords.english(int.parse(d)),
  ].join(' ');
}
