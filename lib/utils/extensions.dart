import 'package:intl/intl.dart';

import '../models/avatar_backgrounds.dart';

extension RemoveEmojis on String {
  String removeEmojis() {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}' // Emoticons
      r'\u{1F300}-\u{1F5FF}' // Miscellaneous Symbols and Pictographs
      r'\u{1F680}-\u{1F6FF}' // Transport and Map Symbols
      r'\u{1F700}-\u{1F77F}' // Alchemical Symbols
      r'\u{1F780}-\u{1F7FF}' // Geometric Shapes Extended
      r'\u{1F800}-\u{1F8FF}' // Supplemental Arrows-C
      r'\u{1F900}-\u{1F9FF}' // Supplemental Symbols and Pictographs
      r'\u{1FA00}-\u{1FA6F}' // Chess Symbols
      r'\u{1FA70}-\u{1FAFF}' // Symbols and Pictographs Extended-A
      r'\u{2600}-\u{26FF}' // Miscellaneous Symbols
      r'\u{2700}-\u{27BF}' // Dingbats
      r'\u{FE00}-\u{FE0F}' // Variation Selectors
      r'\u{1F1E6}-\u{1F1FF}' // Flags
      r'\u{1F900}-\u{1F9FF}]' // Supplemental Symbols and Pictographs
      r'|\u{1F600}-\u{1F64F}', // Emoticons
      unicode: true,
    );

    return replaceAll(emojiRegex, '');
  }
}

extension DateTimeExtension on DateTime {
  // Format : 'Le 10 mai 2022 à 14h30'
  String toLongLocalDateString() {
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(this);
  }
}

extension AnnotationsExtension on List<String> {
  List<AvatarBackgrounds> getBgImages() {
    final List<AvatarBackgrounds> bgImagesList = <AvatarBackgrounds>[];
    for (final String annotation in this) {
      final AvatarBackgrounds? bgImage = annotation.getBgImageFromString();
      if (bgImage != null) {
        bgImagesList.add(bgImage);
      }
    }
    return bgImagesList;
  }
}

extension StringExtensions on String {
  String getVisiblePrompt() {
    final RegExp regex = RegExp(
      r'\{[^}]*\}|\[(?!SoundEffects\.|AvatarBackgrounds\.)[^\]]*\]',
      dotAll: true,
    );
    final String result = replaceAll(regex, '');
    return result.trim();
  }
}

extension EnumByNameExtension on Object {
  static T? enumFromString<T extends Enum>(List<T> values, String name) {
    try {
      return values.firstWhere((element) => element.name == name);
    } catch (e) {
      return null;
    }
  }
}
