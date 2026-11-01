/// Rule-based English grapheme-to-phone conversion.
///
/// Output is a string of one-character phones (the alphabet documented on
/// `TextPhonemizer`): consonants `p b m f v T D t d k g N n l s z S Z C J r
/// w j h`, vowels `a A e E i I @ o O u U R`. Precision only matters up to
/// the viseme each phone maps to, so the rules are deliberately coarse: an
/// exception lexicon for the common irregular words, digraphs first, the
/// silent final e and its long vowel, r-coloured vowels, and a few suffixes.
abstract final class EnglishG2p {
  /// The phones of one lower- or mixed-case word (Latin letters and
  /// apostrophes).
  static String word(String raw) {
    final String w = _fold(raw.toLowerCase()).replaceAll('’', "'");
    final String? known = _lexicon[w];
    if (known != null) {
      return known;
    }
    if (w.contains("'")) {
      return _contraction(w);
    }
    return _withSuffixes(w);
  }

  static const Map<String, String> _contractionSuffixes = <String, String>{
    "n't": 'nt',
    "'s": 'z',
    "'re": 'R',
    "'ll": 'l',
    "'ve": 'v',
    "'m": 'm',
    "'d": 'd',
  };

  static String _contraction(String w) {
    for (final MapEntry<String, String> e in _contractionSuffixes.entries) {
      if (w.endsWith(e.key) && w.length > e.key.length) {
        return word(w.substring(0, w.length - e.key.length)) + e.value;
      }
    }
    return _withSuffixes(w.replaceAll("'", ''));
  }

  static String _withSuffixes(String w) {
    final int n = w.length;
    if (n > 4 && w.endsWith('ing')) {
      return '${_stem(w.substring(0, n - 3))}IN';
    }
    if (n > 4 && w.endsWith('ed') && !w.endsWith('eed')) {
      final String stem = w.substring(0, n - 2);
      final String last = stem[stem.length - 1];
      return _stem(stem) + (last == 't' || last == 'd' ? '@d' : 'd');
    }
    if (n > 4 && w.endsWith('ly')) {
      return '${_stem(w.substring(0, n - 2))}li';
    }
    if (n > 3 &&
        w.endsWith('s') &&
        !w.endsWith('ss') &&
        !w.endsWith('us') &&
        !w.endsWith('is')) {
      final String stem = w.substring(0, n - 1);
      final String? known = _lexicon[stem];
      if (known != null) {
        return '${known}z';
      }
      if (w.endsWith('es')) {
        final String bare = w.substring(0, n - 2);
        if (bare.endsWith('s') ||
            bare.endsWith('x') ||
            bare.endsWith('z') ||
            bare.endsWith('ch') ||
            bare.endsWith('sh')) {
          return '${_rules(bare)}@z';
        }
      }
      return '${_rules(stem)}z';
    }
    return _rules(w);
  }

  /// A stem left by -ing / -ed / -ly: the lexicon (with or without its
  /// dropped final e), else the rules; a one-vowel stem ending on a single
  /// consonant gets its silent e back ("mak" -> "make").
  static String _stem(String stem) {
    final String? known = _lexicon[stem] ?? _lexicon['${stem}e'];
    if (known != null) {
      return known;
    }
    final int n = stem.length;
    if (n >= 3 &&
        _vowelGroups(stem) == 1 &&
        _isVowelLetter(stem[n - 2]) &&
        !_isVowelLetter(stem[n - 1]) &&
        !_isVowelLetter(stem[n - 3]) &&
        !'wxy'.contains(stem[n - 1])) {
      return _rules('${stem}e');
    }
    return _rules(stem);
  }

  static bool _isVowelLetter(String c) => 'aeiou'.contains(c) && c.isNotEmpty;

  /// Whether the letter at [i] sounds as a vowel (y is a consonant at the
  /// start of a word or before a vowel).
  static bool _isVowelAt(String w, int i) {
    final String c = w[i];
    if (c == 'y') {
      return i > 0 && !(i + 1 < w.length && _isVowelLetter(w[i + 1]));
    }
    return _isVowelLetter(c);
  }

  static int _vowelGroups(String w) {
    int groups = 0;
    bool inVowel = false;
    for (int i = 0; i < w.length; i++) {
      final bool v = _isVowelAt(w, i);
      if (v && !inVowel) {
        groups++;
      }
      inVowel = v;
    }
    // A silent final e does not make a syllable ("fine", "vine").
    if (groups > 1 &&
        w.endsWith('e') &&
        w.length > 2 &&
        !_isVowelAt(w, w.length - 2)) {
      groups--;
    }
    return groups;
  }

  static String _rules(String w) {
    final StringBuffer out = StringBuffer();
    final int groups = _vowelGroups(w);
    int i = 0;
    while (i < w.length) {
      final (String, int) step = _isVowelAt(w, i)
          ? _vowel(w, i, groups)
          : _consonant(w, i);
      out.write(step.$1);
      i += step.$2;
    }
    return out.toString();
  }

  static String _at(String w, int k) => k >= 0 && k < w.length ? w[k] : '';

  static (String, int) _consonant(String w, int i) {
    final int n = w.length;
    final String c = w[i];
    final String next = _at(w, i + 1);
    bool has(String s) => w.startsWith(s, i);

    if (has('tch')) return ('C', 3);
    if (has('sch')) return ('sk', 3);
    if (has('ch')) return (_at(w, i + 2) == 'r' ? 'k' : 'C', 2);
    if (has('sh')) return ('S', 2);
    if (has('th')) return ('T', 2);
    if (has('ph')) return ('f', 2);
    if (has('wh')) return ('w', 2);
    if (has('ck')) return ('k', 2);
    if (has('nge') && i + 3 == n) return ('nJ', 3);
    if (has('ng')) return ('N', 2);
    if (has('nk')) return ('Nk', 2);
    if (has('qu')) return ('kw', 2);
    if (has('gh')) return (i == 0 ? 'g' : '', 2);
    if (i == 0 && has('kn')) return ('n', 2);
    if (i == 0 && has('wr')) return ('r', 2);
    if (has('gn') && (i == 0 || i + 2 == n)) return ('n', 2);
    if (has('mb') && i + 2 == n) return ('m', 2);
    if (has('dg')) return ('J', 2);
    if (has('tion')) return ('S@n', 4);
    if (has('sion')) {
      return (i > 0 && _isVowelLetter(w[i - 1]) ? 'Z@n' : 'S@n', 4);
    }
    if (i > 0 && (has('ti') || has('ci')) && 'ao'.contains(_at(w, i + 2))) {
      if (_at(w, i + 2).isNotEmpty) return ('S', 2);
    }
    if (has('ture') && i + 4 == n) return ('CR', 4);
    if (has('sure') && i + 4 == n) return ('ZR', 4);
    if (c == 'x') return (i == 0 ? 'z' : 'ks', 1);
    if (c == 'c') {
      if (next == 'c') {
        return (
          'eiy'.contains(_at(w, i + 2)) && _at(w, i + 2).isNotEmpty
              ? 'ks'
              : 'k',
          2,
        );
      }
      return ('eiy'.contains(next) && next.isNotEmpty ? 's' : 'k', 1);
    }
    if (c == 'g') {
      if (next == 'g') return ('g', 2);
      return ('eiy'.contains(next) && next.isNotEmpty ? 'J' : 'g', 1);
    }
    if (c == 'l' &&
        next == 'e' &&
        i + 2 == n &&
        i > 0 &&
        !_isVowelLetter(w[i - 1])) {
      return ('@l', 2);
    }
    if (c == 'h') return ('', 1);
    if (c == 'y') return ('j', 1);
    if (c == 'w') return ('w', 1);
    final String phone = _single[c] ?? '';
    return (phone, next == c ? 2 : 1);
  }

  static const Map<String, String> _single = <String, String>{
    'b': 'b',
    'd': 'd',
    'f': 'f',
    'j': 'J',
    'k': 'k',
    'l': 'l',
    'm': 'm',
    'n': 'n',
    'p': 'p',
    'q': 'k',
    'r': 'r',
    's': 's',
    't': 't',
    'v': 'v',
    'z': 'z',
  };

  /// A vowel letter at [i] followed by one consonant and a final silent e
  /// ("fine", "code", "cute").
  static bool _magicE(String w, int i) {
    final int n = w.length;
    if (i + 2 >= n || w[i + 2] != 'e' || i + 3 != n) {
      return false;
    }
    final String cons = w[i + 1];
    return !_isVowelLetter(cons) &&
        !'wxyh'.contains(cons) &&
        (i == 0 || !_isVowelLetter(w[i - 1]));
  }

  static (String, int) _vowel(String w, int i, int groups) {
    final int n = w.length;
    final String c = w[i];
    final String next = _at(w, i + 1);
    bool has(String s) => w.startsWith(s, i);

    if (has('eau')) return ('o', 3);
    if (has('eigh')) return ('ei', 4);
    if (has('igh')) return ('Ai', 3);
    if (has('ough')) return ('O', 4);
    if (has('augh')) return ('O', 4);
    if (has('ould')) return ('Ud', 4);
    if (has('our') && i + 3 == n) return ('AuR', 3);
    if (has('air')) return ('er', 3);
    if (has('ear')) return ('ir', 3);
    if (has('eer')) return ('ir', 3);
    if (has('oor')) return ('Or', 3);
    if (has('are') && i + 3 == n) return ('er', 3);
    if (has('ire') && i + 3 == n) return ('AiR', 3);
    if (has('ore') && i + 3 == n) return ('Or', 3);
    if (has('ure') && i + 3 == n) return ('jUr', 3);
    if (has('ai') || has('ay')) return ('ei', 2);
    if (has('ee')) return ('i', 2);
    if (has('ea')) return ('i', 2);
    if (has('ei')) return ('ei', 2);
    if (has('ey')) return (i + 2 == n ? 'i' : 'ei', 2);
    if (has('ie')) return (i + 2 == n && groups == 1 ? 'Ai' : 'i', 2);
    if (has('oa')) return ('o', 2);
    if (has('oe') && i + 2 == n) return ('o', 2);
    if (has('oo')) return ('u', 2);
    if (has('ou')) return ('Au', 2);
    if (has('ow')) {
      final bool open = i + 2 == n || (i + 3 == n && w[n - 1] == 's');
      return (open ? 'o' : 'Au', 2);
    }
    if (has('oi') || has('oy')) return ('Oi', 2);
    if (has('au') || has('aw')) return ('O', 2);
    if (has('ew') || has('ue') || has('ui')) return ('u', 2);

    // r-coloured vowels (not before a vowel or a second r).
    final bool rColoured =
        next == 'r' &&
        !_isVowelLetter(_at(w, i + 2)) &&
        _at(w, i + 2) != 'r' &&
        _at(w, i + 2) != 'y';
    if (rColoured) {
      if (c == 'a') return ('Ar', 2);
      if (c == 'o') return ('Or', 2);
      if ('eiu'.contains(c)) return ('R', 2);
    }
    if (c == 'a' && (has('all') || has('alk') || has('alt'))) {
      return ('O', 1);
    }
    if (c == 'a' && i > 0 && w[i - 1] == 'w' && !_magicE(w, i)) {
      return ('A', 1);
    }
    if (c == 'i' && (has('ind') || has('ild')) && i + 3 == n) {
      return ('Ai', 1);
    }
    if (c == 'o' && has('old')) return ('o', 1);

    if (c == 'e' && i == n - 1) {
      return (groups <= 1 && n <= 3 ? 'i' : '', 1);
    }
    if (c == 'y') {
      if (i == n - 1) return (groups <= 1 ? 'Ai' : 'i', 1);
      return ('I', 1);
    }
    if (_magicE(w, i)) {
      return (
        switch (c) {
          'a' => 'ei',
          'e' => 'i',
          'i' => 'Ai',
          'o' => 'o',
          _ => i > 0 && 'rlj'.contains(w[i - 1]) ? 'u' : 'ju',
        },
        1,
      );
    }
    if (i == n - 1 && groups <= 1) {
      return (
        switch (c) {
          'a' => 'A',
          'e' => 'i',
          'i' => 'Ai',
          'o' => 'o',
          _ => 'u',
        },
        1,
      );
    }
    // A short vowel.
    return (
      switch (c) {
        'a' => 'a',
        'e' => 'E',
        'i' => 'I',
        'o' => 'A',
        _ => 'A',
      },
      1,
    );
  }

  static String _fold(String w) {
    if (!_accented.hasMatch(w)) {
      return w;
    }
    final StringBuffer out = StringBuffer();
    for (final int rune in w.runes) {
      final String ch = String.fromCharCode(rune);
      out.write(_foldMap[ch] ?? ch);
    }
    return out.toString();
  }

  static final RegExp _accented = RegExp(r'[^a-z’\x27]');

  static const Map<String, String> _foldMap = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', //
    'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', //
    'ô': 'o', 'ö': 'o', 'õ': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', //
    'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  };

  /// Common words the rules get wrong (function words, irregular spellings,
  /// the number words and frequent contractions).
  static const Map<String, String> _lexicon = <String, String>{
    'a': '@',
    'about': '@bAut',
    'above': '@bAv',
    'again': '@gEn',
    'against': '@gEnst',
    'all': 'Ol',
    'also': 'Olso',
    'always': 'Olweiz',
    'an': '@n',
    'and': 'and',
    'another': '@nADR',
    'answer': 'ansR',
    'any': 'Eni',
    'are': 'Ar',
    'area': 'eri@',
    'be': 'bi',
    'because': 'bikAz',
    'been': 'bin',
    'begin': 'bIgIn',
    'billion': 'bIlj@n',
    'blue': 'blu',
    'book': 'bUk',
    'bread': 'brEd',
    'break': 'breik',
    'brother': 'brADR',
    'build': 'bIld',
    'busy': 'bIzi',
    'business': 'bIznEs',
    'buy': 'bAi',
    'by': 'bAi',
    'can': 'kan',
    "can't": 'kant',
    'cannot': 'kanAt',
    'city': 'sIti',
    'come': 'kAm',
    'computer': 'k@mpjutR',
    'could': 'kUd',
    'cow': 'kAu',
    'dead': 'dEd',
    'do': 'du',
    'does': 'dAz',
    "doesn't": 'dAz@nt',
    "didn't": 'dId@nt',
    'done': 'dAn',
    "don't": 'dont',
    'door': 'dOr',
    'earth': 'RT',
    'eight': 'eit',
    'eighteen': 'eitin',
    'eighty': 'eiti',
    'eleven': 'IlEv@n',
    'enough': 'InAf',
    'every': 'Evri',
    'eye': 'Ai',
    'eyes': 'Aiz',
    'father': 'fADR',
    'fifteen': 'fIftin',
    'fifty': 'fIfti',
    'five': 'fAiv',
    'for': 'fOr',
    'forty': 'fOrti',
    'four': 'fOr',
    'fourteen': 'fOrtin',
    'friend': 'frEnd',
    'from': 'frAm',
    'front': 'frAnt',
    'full': 'fUl',
    'get': 'gEt',
    'girl': 'gRl',
    'give': 'gIv',
    'go': 'go',
    'goes': 'goz',
    'gone': 'gOn',
    'good': 'gUd',
    'great': 'greit',
    'guy': 'gAi',
    'had': 'had',
    'has': 'haz',
    'have': 'hav',
    'he': 'hi',
    "he's": 'hiz',
    'head': 'hEd',
    'heart': 'hArt',
    'hello': 'h@lo',
    'here': 'hir',
    'hi': 'hAi',
    'hour': 'AuR',
    'how': 'hAu',
    'hundred': 'hAndr@d',
    'i': 'Ai',
    "i'd": 'Aid',
    "i'll": 'Ail',
    "i'm": 'Aim',
    "i've": 'Aiv',
    'idea': 'Aidi@',
    'is': 'Iz',
    "isn't": 'Iz@nt',
    'island': 'Ail@nd',
    "it's": 'Its',
    'knew': 'nu',
    'know': 'no',
    'known': 'non',
    'laugh': 'laf',
    'learn': 'lRn',
    "let's": 'lEts',
    'listen': 'lIs@n',
    'live': 'lIv',
    'look': 'lUk',
    'love': 'lAv',
    'many': 'mEni',
    'maybe': 'meibi',
    'me': 'mi',
    'million': 'mIlj@n',
    'minute': 'mInIt',
    'money': 'mAni',
    'mother': 'mADR',
    'music': 'mjuzIk',
    'my': 'mAi',
    'new': 'nu',
    'nine': 'nAin',
    'nineteen': 'nAintin',
    'ninety': 'nAinti',
    'no': 'no',
    'none': 'nAn',
    'now': 'nAu',
    'of': 'Av',
    'often': 'Of@n',
    'oh': 'o',
    'ok': 'okei',
    'okay': 'okei',
    'once': 'wAns',
    'one': 'wAn',
    'only': 'onli',
    'or': 'Or',
    'open': 'op@n',
    'other': 'ADR',
    'our': 'AuR',
    'over': 'ovR',
    'own': 'on',
    'people': 'pip@l',
    'please': 'pliz',
    'point': 'pOint',
    'pull': 'pUl',
    'push': 'pUS',
    'put': 'pUt',
    'question': 'kwEsC@n',
    'read': 'rid',
    'said': 'sEd',
    'says': 'sEz',
    'seven': 'sEv@n',
    'seventeen': 'sEv@ntin',
    'seventy': 'sEv@nti',
    'she': 'Si',
    "she's": 'Siz',
    'should': 'SUd',
    'six': 'sIks',
    'sixteen': 'sIkstin',
    'sixty': 'sIksti',
    'so': 'so',
    'some': 'sAm',
    'sorry': 'sAri',
    'sugar': 'SUgR',
    'sure': 'SUr',
    'talk': 'tOk',
    'ten': 'tEn',
    'than': 'Dan',
    'thank': 'TaNk',
    'thanks': 'TaNks',
    'that': 'Dat',
    "that's": 'Dats',
    'the': 'D@',
    'their': 'Der',
    'them': 'DEm',
    'then': 'DEn',
    'there': 'Der',
    "there's": 'Derz',
    'these': 'Diz',
    'they': 'Dei',
    "they're": 'Der',
    'thirteen': 'TRtin',
    'thirty': 'TRti',
    'this': 'DIs',
    'those': 'Doz',
    'though': 'Do',
    'thought': 'TOt',
    'thousand': 'TAuz@nd',
    'three': 'Tri',
    'through': 'Tru',
    'to': 'tu',
    'today': 't@dei',
    'together': 't@gEDR',
    'tomorrow': 't@mAro',
    'tonight': 't@nAit',
    'too': 'tu',
    'took': 'tUk',
    'tough': 'tAf',
    'true': 'tru',
    'twelve': 'twElv',
    'twenty': 'twEnti',
    'two': 'tu',
    'very': 'vEri',
    'view': 'vju',
    'walk': 'wOk',
    'want': 'wAnt',
    'was': 'wAz',
    'water': 'wOtR',
    'we': 'wi',
    "we'll": 'wil',
    "we're": 'wir',
    'weather': 'wEDR',
    'welcome': 'wElk@m',
    'were': 'wR',
    'what': 'wAt',
    "what's": 'wAts',
    'when': 'wEn',
    'where': 'wer',
    'whether': 'wEDR',
    'which': 'wIC',
    'who': 'hu',
    'whom': 'hum',
    'whose': 'huz',
    'why': 'wAi',
    'with': 'wID',
    'without': 'wIDAut',
    'woman': 'wUm@n',
    'women': 'wImIn',
    "won't": 'wont',
    'word': 'wRd',
    'work': 'wRk',
    'world': 'wRld',
    'would': 'wUd',
    'yeah': 'jE',
    'yes': 'jEs',
    'you': 'ju',
    "you'll": 'jul',
    "you're": 'jOr',
    'your': 'jOr',
    'yours': 'jOrz',
    'zero': 'ziro',
  };
}
