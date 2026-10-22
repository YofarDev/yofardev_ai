import 'dart:math';

import 'package:intl/intl.dart';

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
  // Format : '10 mai 2022 - 14:30'
  String toLongLocalDateString({String language = 'en'}) {
    return DateFormat('EEEE d MMMM yyyy - HH:mm', language).format(this);
  }
}

extension StringExtensions on String {
  String getVisiblePrompt() {
    if (contains('"message"')) {
      final RegExp regex = RegExp(r'"message"\s*:\s*"(.+?)"');
      final Match? match = regex.firstMatch(this);
      if (match != null) {
        return match.group(1) ?? this;
      }
    }
    final List<String> parts = split("'''");
    if (parts.length > 1) {
      return parts[1].trim();
    }
    return this;
  }

  String limitWords(int wordLimit) {
    if (isEmpty) return '';
    final List<String> words = split(' ');
    if (words.length <= wordLimit) {
      return this;
    }
    return '${words.take(wordLimit).join(' ')}...';
  }
}

extension EnumByNameExtension on Object {
  static T? enumFromString<T extends Enum>(List<T> values, String name) {
    try {
      return values.firstWhere((T element) => element.name == name);
    } catch (e) {
      return null;
    }
  }
}

extension EnumUtils on Enum {
  String serialize() => name;

  static T deserialize<T extends Enum>(List<T> values, String value) {
    final String enumName = value.split('.').last.replaceAll(']', '');
    return values.firstWhere(
      (T e) => e.name == enumName,
      orElse: () => values.first,
    );
  }

  static T getRandomValue<T extends Enum>(List<T> values) {
    final Random random = Random();
    return values[random.nextInt(values.length)];
  }

  static T? firstOrNull<T extends Enum>(List<T> values, String enumName) {
    return values.any((T e) => e.name == enumName)
        ? values.firstWhere((T e) => e.name == enumName)
        : null;
  }
}
