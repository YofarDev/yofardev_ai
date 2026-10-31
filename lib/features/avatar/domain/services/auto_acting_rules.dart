import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/performance/performance.dart';

/// The auto gestures of [sentence] in a persona's body language (moonshot
/// M10 ruling 9): the rules' gestures ([gesturesFor]) each swapped through
/// [profile]'s bias, or, on a beat ([isBeat]), the persona's beat gesture.
/// Deterministic: the swap is picked by the sentence's [index]. The normal
/// profile returns [gesturesFor] unchanged. The gesture rate (how many of
/// these fire) is the director's, not this function's.
List<AvatarGesture> personaGesturesFor(
  String sentence,
  BodyLanguageProfile profile,
  int index,
) {
  final List<AvatarGesture> base = gesturesFor(sentence);
  if (profile.gestureBias.isEmpty) {
    return base;
  }
  if (base.isEmpty) {
    final AvatarGesture? beat = isBeat(sentence)
        ? profile.beatFor(index)
        : null;
    return beat == null ? const <AvatarGesture>[] : <AvatarGesture>[beat];
  }
  return <AvatarGesture>[
    for (final AvatarGesture gesture in base) profile.swapFor(gesture, index),
  ];
}

/// A beat: an emphatic sentence (ending on `!`) the rules leave bare.
bool isBeat(String sentence) {
  final String text = sentence.trim();
  return text.endsWith('!') && gesturesFor(text).isEmpty;
}

/// Pure auto-acting rules: which gesture a sentence suggests on its own.
/// Auto requests lose to LLM cues and are rate-limited by the cooldown.
///
/// In order: a question thinks; a list of [minListItems] or more items
/// (ordinal words, numbered or bulleted items, M8 ruling 4) counts; a leading
/// yes nods; a leading no shakes the head.
List<AvatarGesture> gesturesFor(String sentence) {
  final String text = sentence.trim().toLowerCase();
  if (text.isEmpty) {
    return const <AvatarGesture>[];
  }
  if (text.endsWith('?')) {
    return const <AvatarGesture>[AvatarGesture.think];
  }
  if (listItemCount(text) >= minListItems) {
    return const <AvatarGesture>[AvatarGesture.count];
  }
  if (_startsWithWord(text, const <String>[
    'yes',
    'oui',
    'exactly',
    'exactement',
  ])) {
    return const <AvatarGesture>[AvatarGesture.nod];
  }
  if (_startsWithWord(text, const <String>['no', 'non'])) {
    return const <AvatarGesture>[AvatarGesture.headshake];
  }
  return const <AvatarGesture>[];
}

/// Fewest items that make a sentence a list worth counting on the fingers.
const int minListItems = 3;

/// Words that mark a list item (English and French), counted once each.
const Set<String> _ordinals = <String>{
  'first',
  'firstly',
  'second',
  'secondly',
  'third',
  'thirdly',
  'fourth',
  'fourthly',
  'fifth',
  'finally',
  'lastly',
  'premier',
  'première',
  'premièrement',
  'deuxième',
  'deuxièmement',
  'seconde',
  'secondement',
  'troisième',
  'troisièmement',
  'quatrième',
  'cinquième',
  "d'abord",
  'ensuite',
  'enfin',
};

/// `1.` / `2)` items: a one- or two-digit number, its mark, then a space (so
/// a decimal like 3.50 is not an item).
final RegExp _numbered = RegExp(r'(?:^|\s)\d{1,2}[.)](?=\s|$)');

/// `- ` / `• ` / `* ` items at the start of a line.
final RegExp _bullet = RegExp(r'^\s*[-•*]\s+\S', multiLine: true);

/// How many list items [text] (lower case) holds: the largest of its distinct
/// ordinal words, its numbered items and its bullet lines.
int listItemCount(String text) {
  final Set<String> ordinals = <String>{};
  final StringBuffer word = StringBuffer();
  void flush() {
    if (word.isNotEmpty) {
      final String w = word.toString();
      if (_ordinals.contains(w)) {
        ordinals.add(w);
      }
      word.clear();
    }
  }

  for (final int unit in text.codeUnits) {
    if (_isLetter(unit)) {
      word.writeCharCode(unit == 0x2019 ? 0x27 : unit);
    } else {
      flush();
    }
  }
  flush();
  final int numbered = _numbered.allMatches(text).length;
  final int bullets = _bullet.allMatches(text).length;
  int count = ordinals.length;
  if (numbered > count) {
    count = numbered;
  }
  if (bullets > count) {
    count = bullets;
  }
  return count;
}

/// Whether [text] starts with [prefixes] on a word boundary (the prefix
/// followed by a non-letter or at the end of the text).
bool _startsWithWord(String text, List<String> prefixes) {
  for (final String prefix in prefixes) {
    if (!text.startsWith(prefix)) {
      continue;
    }
    final int end = prefix.length;
    if (end == text.length || !_isLetter(text.codeUnitAt(end))) {
      return true;
    }
  }
  return false;
}

bool _isLetter(int codeUnit) =>
    (codeUnit >= 0x61 && codeUnit <= 0x7A) || // a-z
    (codeUnit >= 0xC0 && codeUnit <= 0x24F) || // accented latin
    codeUnit == 0x27 || // apostrophe
    codeUnit == 0x2019; // right single quote
