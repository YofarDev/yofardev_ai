import 'package:intl/intl.dart';

import '../models/bg_images.dart';

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
    return DateFormat('EEEE d MMMM yyyy à HH:mm').format(this);
  }
}

extension AnnotationsExtension on List<String> {
  List<BgImages> getBgImages()  {
    final List<BgImages> bgImagesList = <BgImages>[];
    for (final String annotation in this) {
      final BgImages? bgImage = annotation.getBgImageFromString();
      if (bgImage != null) {
        bgImagesList.add(bgImage);
      }
    }
    return bgImagesList;
  }
}
