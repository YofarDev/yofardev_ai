/// Rule-based French grapheme-to-phone conversion.
///
/// Same one-character phone alphabet as `EnglishG2p`, plus `y` (the rounded
/// front vowel of "lune") and `2` (the rounded "eu"). Nasal vowels collapse
/// onto their oral viseme class: an/en -> `A`, on -> `o`, in/un/ain -> `E`.
/// Final consonants s, t, d, x, z, p and g are silent, a final e is mute,
/// and the common irregular words come from a lexicon.
abstract final class FrenchG2p {
  /// The phones of one word (Latin letters, accents and apostrophes).
  static String word(String raw) {
    final String w = raw.toLowerCase().replaceAll('’', "'");
    final String? known = _lexicon[w];
    if (known != null) {
      return known;
    }
    // Elision: c'est, l'eau, d'accord, j'ai, qu'il, n'est, s'il, m'a, t'as.
    final int apostrophe = w.indexOf("'");
    if (apostrophe > 0 && apostrophe < w.length - 1) {
      final String head = w.substring(0, apostrophe);
      final String tail = w.substring(apostrophe + 1);
      final String? elided = _elisions[head];
      return (elided ?? _rules(head)) + word(tail);
    }
    return _rules(w.replaceAll("'", ''));
  }

  static const Map<String, String> _elisions = <String, String>{
    'c': 's',
    'l': 'l',
    'd': 'd',
    'j': 'Z',
    'qu': 'k',
    'n': 'n',
    's': 's',
    'm': 'm',
    't': 't',
    'jusqu': 'Zysk',
    'lorsqu': 'lOrsk',
    'puisqu': 'pyisk',
  };

  static const String _vowelLetters = 'aeiouyàâäéèêëîïôöùûüœæ';

  static bool _isVowelLetter(String c) =>
      c.isNotEmpty && _vowelLetters.contains(c);

  /// y is a consonant before a vowel ("yeux", "payer").
  static bool _isVowelAt(String w, int i) {
    final String c = w[i];
    if (c == 'y') {
      return !(i + 1 < w.length && _isVowelLetter(w[i + 1]));
    }
    return _isVowelLetter(c);
  }

  static String _at(String w, int k) => k >= 0 && k < w.length ? w[k] : '';

  static String _rules(String w) {
    final StringBuffer out = StringBuffer();
    int i = 0;
    while (i < w.length) {
      final (String, int) step = _isVowelAt(w, i)
          ? _vowel(w, i)
          : _consonant(w, i);
      out.write(step.$1);
      i += step.$2;
    }
    return out.toString();
  }

  /// Whether a nasal consonant ending at [k] (exclusive) closes the syllable:
  /// the word ends there, or a consonant other than n/m/h follows.
  static bool _nasalCloses(String w, int k) {
    if (k >= w.length) {
      return true;
    }
    final String c = w[k];
    return !_isVowelLetter(c) && c != 'n' && c != 'm' && c != 'h';
  }

  static (String, int) _vowel(String w, int i) {
    final int n = w.length;
    final String c = w[i];
    bool has(String s) => w.startsWith(s, i);

    if (c == 'e' && i == n - 1) return (n <= 2 ? '@' : '', 1);
    if (has('es') && i + 2 == n && n > 3) return ('', 2);
    if (has('ent') && i + 3 == n && n > 5 && !w.endsWith('ment')) {
      // Third-person plural verb ending: mute.
      return ('', 3);
    }
    if ((has('aille') || has('eille')) && i + 5 == n) {
      return (c == 'a' ? 'aj' : 'Ej', 5);
    }
    if ((has('ail') || has('eil')) && i + 3 == n) {
      return (c == 'a' ? 'aj' : 'Ej', 3);
    }
    if (has('euil') && i + 4 == n) return ('2j', 4);
    if (has('eaux')) return ('o', 4);
    if (has('eau')) return ('o', 3);
    if (has('aient') && i + 5 == n) return ('E', 5);
    if ((has('ain') || has('aim') || has('ein') || has('eim')) &&
        _nasalCloses(w, i + 3)) {
      return ('E', 3);
    }
    if (has('oin') && _nasalCloses(w, i + 3)) return ('wE', 3);
    if (has('ien') && _nasalCloses(w, i + 3)) return ('jE', 3);
    if (has('oi') || has('oî')) return ('wa', 2);
    if (has('oy')) return ('waj', 2);
    if (has('ou') || has('où') || has('oû')) return ('u', 2);
    if (has('au')) return ('o', 2);
    if (has('ai') || has('aî') || has('ei') || has('ay')) return ('E', 2);
    if (has('eu') || has('eû') || has('œu')) return ('2', 2);
    if (c == 'œ') return ('2', 1);

    final String next = _at(w, i + 1);
    final bool nasal = (next == 'n' || next == 'm') && _nasalCloses(w, i + 2);
    if (nasal) {
      if (c == 'a' || c == 'e') return ('A', 2);
      if (c == 'o') return ('o', 2);
      if (c == 'i' || c == 'y' || c == 'u') return ('E', 2);
    }

    if (c == 'e') {
      if (i + 2 == n && 'rz'.contains(next) && n > 2) return ('e', 2);
      if (i + 2 == n && 'td'.contains(next)) return ('E', 2);
      return (_openOrSchwa(w, i), 1);
    }
    return (
      switch (c) {
        'a' || 'à' || 'â' || 'ä' => 'a',
        'é' => 'e',
        'è' || 'ê' || 'ë' => 'E',
        'i' || 'î' || 'ï' || 'y' => 'i',
        'o' || 'ô' || 'ö' => 'o',
        'u' || 'û' || 'ù' || 'ü' => 'y',
        'æ' => 'e',
        _ => '',
      },
      1,
    );
  }

  /// A plain e: open (`E`) before two consonants or a final pronounced
  /// consonant, a schwa (`@`) in an open syllable.
  static String _openOrSchwa(String w, int i) {
    int k = i + 1;
    while (k < w.length && !_isVowelLetter(w[k])) {
      k++;
    }
    final int consonants = k - i - 1;
    if (consonants == 0) {
      return '';
    }
    final String pair = w.substring(i + 1, i + 1 + consonants);
    if (consonants >= 2) {
      final bool single =
          consonants == 2 &&
          (const <String>{'ch', 'ph', 'th', 'gn'}.contains(pair) ||
              'rl'.contains(pair[1]) && !'rl'.contains(pair[0]));
      return single ? '@' : 'E';
    }
    // One consonant: before a vowel it opens the next syllable.
    if (k < w.length) {
      return '@';
    }
    return 'E';
  }

  static (String, int) _consonant(String w, int i) {
    final int n = w.length;
    final String c = w[i];
    final String next = _at(w, i + 1);
    final bool last = i == n - 1;
    bool has(String s) => w.startsWith(s, i);
    bool soft(String x) => x.isNotEmpty && 'eiyéèêë'.contains(x);

    if (has('ch')) return ('S', 2);
    if (has('ph')) return ('f', 2);
    if (has('th')) return ('t', 2);
    if (has('gn')) return ('nj', 2);
    if (has('qu')) return ('k', 2);
    if (has('gu') && soft(_at(w, i + 2))) return ('g', 2);
    if (has('ge') && 'aou'.contains(_at(w, i + 2)) && _at(w, i + 2) != '') {
      return ('Z', 2);
    }
    if (has('tion')) return ('sjo', 4);
    if (has('ill') && i > 0 && _isVowelLetter(w[i - 1])) {
      return ('j', _at(w, i + 3) == 'e' && i + 4 == n ? 4 : 3);
    }
    if (has('il') && i + 2 == n && i > 0 && _isVowelLetter(w[i - 1])) {
      return ('j', 2);
    }
    if (c == 'c') {
      if (next == 'c') return (soft(_at(w, i + 2)) ? 'ks' : 'k', 2);
      return (soft(next) ? 's' : 'k', 1);
    }
    if (c == 'ç') return ('s', 1);
    if (c == 'g') {
      if (last) return ('', 1);
      if (next == 'g') return ('g', 2);
      return (soft(next) ? 'Z' : 'g', 1);
    }
    if (c == 's') {
      if (last) return ('', 1);
      if (next == 's') return ('s', 2);
      final bool between =
          i > 0 && _isVowelLetter(w[i - 1]) && _isVowelLetter(next);
      return (between ? 'z' : 's', 1);
    }
    if (last && 'tdxzp'.contains(c)) return ('', 1);
    if (c == 'x') return ('ks', 1);
    if (c == 'h') return ('', 1);
    if (c == 'y' || c == 'j') return (c == 'y' ? 'j' : 'Z', 1);
    if (c == 'w') return ('w', 1);
    final String phone = _single[c] ?? '';
    return (phone, next == c ? 2 : 1);
  }

  static const Map<String, String> _single = <String, String>{
    'b': 'b',
    'd': 'd',
    'f': 'f',
    'k': 'k',
    'l': 'l',
    'm': 'm',
    'n': 'n',
    'p': 'p',
    'q': 'k',
    'r': 'r',
    't': 't',
    'v': 'v',
    'z': 'z',
  };

  /// Common words the rules get wrong (function words, liaison-free forms,
  /// the number words and frequent irregular spellings).
  static const Map<String, String> _lexicon = <String, String>{
    'a': 'a',
    'ai': 'e',
    'alors': 'alOr',
    'an': 'A',
    'ans': 'A',
    'après': 'aprE',
    'as': 'a',
    'au': 'o',
    'aujourd\'hui': 'oZurdyi',
    'aussi': 'osi',
    'autre': 'otr',
    'aux': 'o',
    'avant': 'avA',
    'avec': 'avEk',
    'avez': 'ave',
    'avoir': 'avwar',
    'avons': 'avo',
    'beau': 'bo',
    'beaucoup': 'boku',
    'belle': 'bEl',
    'bien': 'bjE',
    'bon': 'bo',
    'bonjour': 'boZur',
    'bonne': 'bOn',
    'bonsoir': 'boswar',
    'accident': 'aksidA',
    'argent': 'arZA',
    'ça': 'sa',
    'ce': 's@',
    'cent': 'sA',
    'cents': 'sA',
    'ces': 'se',
    'cet': 'sEt',
    'cette': 'sEt',
    'chez': 'Se',
    'chose': 'Soz',
    'cinq': 'sEk',
    'cinquante': 'sEkAt',
    'client': 'klijA',
    'combien': 'kobjE',
    'content': 'kotA',
    'comme': 'kOm',
    'comment': 'kOmA',
    'd\'accord': 'dakOr',
    'dans': 'dA',
    'de': 'd@',
    'demain': 'd@mE',
    'depuis': 'd@pyi',
    'des': 'de',
    'deux': 'd2',
    'dire': 'dir',
    'dit': 'di',
    'dix': 'dis',
    'donc': 'dok',
    'douze': 'duz',
    'du': 'dy',
    'elle': 'El',
    'elles': 'El',
    'en': 'A',
    'encore': 'AkOr',
    'entre': 'Atr',
    'es': 'E',
    'est': 'E',
    'et': 'e',
    'être': 'Etr',
    'êtes': 'Et',
    'eu': 'y',
    'eux': '2',
    'faire': 'fEr',
    'fait': 'fE',
    'faut': 'fo',
    'femme': 'fam',
    'femmes': 'fam',
    'fille': 'fij',
    'fils': 'fis',
    'font': 'fo',
    'gentil': 'ZAti',
    'grand': 'grA',
    'hier': 'jEr',
    'homme': 'Om',
    'huit': 'yit',
    'ici': 'isi',
    'il': 'il',
    'ils': 'il',
    'jamais': 'ZamE',
    'je': 'Z@',
    'jour': 'Zur',
    'la': 'la',
    'le': 'l@',
    'les': 'le',
    'leur': 'l2r',
    'leurs': 'l2r',
    'lui': 'lyi',
    'ma': 'ma',
    'madame': 'madam',
    'mais': 'mE',
    'merci': 'mErsi',
    'mes': 'me',
    'même': 'mEm',
    'mille': 'mil',
    'million': 'miljo',
    'millions': 'miljo',
    'moi': 'mwa',
    'moins': 'mwE',
    'mon': 'mo',
    'monde': 'mod',
    'monsieur': 'm@sj2',
    'ne': 'n@',
    'neuf': 'n2f',
    'non': 'no',
    'nos': 'no',
    'notre': 'nOtr',
    'nous': 'nu',
    'nouveau': 'nuvo',
    'ok': 'oke',
    'on': 'o',
    'ont': 'o',
    'onze': 'oz',
    'ou': 'u',
    'où': 'u',
    'oui': 'wi',
    'parce': 'pars',
    'parent': 'parA',
    'parents': 'parA',
    'pas': 'pa',
    'pays': 'pei',
    'pendant': 'pAdA',
    'petit': 'p@ti',
    'peu': 'p2',
    'peut': 'p2',
    'peux': 'p2',
    'plus': 'ply',
    'pour': 'pur',
    'pourquoi': 'purkwa',
    'quand': 'kA',
    'quarante': 'karAt',
    'quatorze': 'katOrz',
    'quatre': 'katr',
    'que': 'k@',
    'quelque': 'kElk@',
    'qui': 'ki',
    'quinze': 'kEz',
    'quoi': 'kwa',
    'rien': 'rjE',
    'sa': 'sa',
    'sais': 'sE',
    'sait': 'sE',
    'salut': 'saly',
    'sans': 'sA',
    'se': 's@',
    'second': 's@go',
    'seize': 'sEz',
    'sept': 'sEt',
    'ses': 'se',
    'six': 'sis',
    'soixante': 'swasAt',
    'souvent': 'suvA',
    'sommes': 'sOm',
    'son': 'so',
    'sont': 'so',
    'sous': 'su',
    'suis': 'syi',
    'sur': 'syr',
    'sûr': 'syr',
    'ta': 'ta',
    'te': 't@',
    'temps': 'tA',
    'tes': 'te',
    'toi': 'twa',
    'ton': 'to',
    'toujours': 'tuZur',
    'tous': 'tus',
    'tout': 'tu',
    'toute': 'tut',
    'toutes': 'tut',
    'treize': 'trEz',
    'trente': 'trAt',
    'très': 'trE',
    'trois': 'trwa',
    'tu': 'ty',
    'un': 'E',
    'une': 'yn',
    'va': 'va',
    'vais': 'vE',
    'ville': 'vil',
    'vingt': 'vE',
    'vingts': 'vE',
    'virgule': 'virgyl',
    'voilà': 'vwala',
    'vont': 'vo',
    'vos': 'vo',
    'votre': 'vOtr',
    'vous': 'vu',
    'vrai': 'vrE',
    'veut': 'v2',
    'veux': 'v2',
    'y': 'i',
    'zéro': 'zero',
  };
}
