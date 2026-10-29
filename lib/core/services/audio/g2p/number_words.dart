/// Cardinal numbers spelled out in English and French words (space
/// separated, no hyphens), for the phonemizer.
abstract final class NumberWords {
  static const List<String> _enOnes = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];

  static const List<String> _enTens = <String>[
    '',
    '',
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'sixty',
    'seventy',
    'eighty',
    'ninety',
  ];

  static const List<(int, String)> _enScales = <(int, String)>[
    (1000000000, 'billion'),
    (1000000, 'million'),
    (1000, 'thousand'),
  ];

  /// [n] (0 or more) in English: "one thousand two hundred fifty".
  static String english(int n) {
    if (n < 20) {
      return _enOnes[n];
    }
    if (n < 100) {
      final int unit = n % 10;
      return unit == 0
          ? _enTens[n ~/ 10]
          : '${_enTens[n ~/ 10]} ${_enOnes[unit]}';
    }
    if (n < 1000) {
      final int rest = n % 100;
      final String head = '${_enOnes[n ~/ 100]} hundred';
      return rest == 0 ? head : '$head ${english(rest)}';
    }
    for (final (int scale, String name) in _enScales) {
      if (n >= scale) {
        final int rest = n % scale;
        final String head = '${english(n ~/ scale)} $name';
        return rest == 0 ? head : '$head ${english(rest)}';
      }
    }
    return _enOnes[0];
  }

  static const List<String> _frUnits = <String>[
    'zéro',
    'un',
    'deux',
    'trois',
    'quatre',
    'cinq',
    'six',
    'sept',
    'huit',
    'neuf',
    'dix',
    'onze',
    'douze',
    'treize',
    'quatorze',
    'quinze',
    'seize',
  ];

  static const List<String> _frTens = <String>[
    '',
    '',
    'vingt',
    'trente',
    'quarante',
    'cinquante',
    'soixante',
  ];

  /// [n] (0 or more) in French: "soixante et onze", "quatre vingts".
  static String french(int n) {
    if (n <= 16) {
      return _frUnits[n];
    }
    if (n < 20) {
      return 'dix ${_frUnits[n - 10]}';
    }
    if (n < 70) {
      final String tens = _frTens[n ~/ 10];
      final int unit = n % 10;
      if (unit == 0) return tens;
      if (unit == 1) return '$tens et un';
      return '$tens ${_frUnits[unit]}';
    }
    if (n < 80) {
      final int rest = n - 60;
      return rest == 11 ? 'soixante et onze' : 'soixante ${french(rest)}';
    }
    if (n < 100) {
      final int rest = n - 80;
      return rest == 0 ? 'quatre vingts' : 'quatre vingt ${french(rest)}';
    }
    if (n < 1000) {
      final int hundreds = n ~/ 100;
      final int rest = n % 100;
      final String head = hundreds == 1
          ? 'cent'
          : '${_frUnits[hundreds]} cent${rest == 0 ? 's' : ''}';
      return rest == 0 ? head : '$head ${french(rest)}';
    }
    if (n < 1000000) {
      final int thousands = n ~/ 1000;
      final int rest = n % 1000;
      final String head = thousands == 1
          ? 'mille'
          : '${french(thousands)} mille';
      return rest == 0 ? head : '$head ${french(rest)}';
    }
    final bool billions = n >= 1000000000;
    final int scale = billions ? 1000000000 : 1000000;
    final int count = n ~/ scale;
    final int rest = n % scale;
    final String name = billions ? 'milliard' : 'million';
    final String head = '${french(count)} $name${count > 1 ? 's' : ''}';
    return rest == 0 ? head : '$head ${french(rest)}';
  }
}
