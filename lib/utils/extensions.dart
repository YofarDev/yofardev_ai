import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
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
}

extension ColorfulLogs on String {
  String toRedLog() =>  "'\x1B[31m$this\x1B[0m'";
  String toGreenLog() => "'\x1B[32m$this\x1B[0m'";
  String toYellowLog() =>  "'\x1B[33m$this\x1B[0m'";
  String toBlueLog() =>  "'\x1B[34m$this\x1B[0m'";
  String toWhiteLog() => "'\x1B[37m$this\x1B[0m'";
  String toCyanLog() => "'\x1B[36m$this\x1B[0m'";
  String toMagentaLog() =>"'\x1B[35m$this\x1B[0m'";


  void printRedLog() =>
    split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toRedLog() : element));
  void printGreenLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toGreenLog() : element));
  void printYellowLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toYellowLog() : element));
  void printBlueLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toBlueLog() : element));
  void printWhiteLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toWhiteLog() : element));
  void printCyanLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toCyanLog() : element));
  void printMagentaLog() =>
      split('\n').forEach((String element) => debugPrint(Platform.isAndroid ? element.toMagentaLog() : element));
  

}
