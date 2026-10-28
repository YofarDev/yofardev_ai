import '../../../../core/models/avatar_gesture.dart';

/// Pure auto-acting rules: which gesture a sentence suggests on its own.
/// Auto requests lose to LLM cues and are rate-limited by the cooldown.
List<AvatarGesture> gesturesFor(String sentence) {
  final String text = sentence.trim().toLowerCase();
  if (text.isEmpty) {
    return const <AvatarGesture>[];
  }
  if (text.endsWith('?')) {
    return const <AvatarGesture>[AvatarGesture.think];
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
