import 'extensions.dart';

class AppUtils {
  double getInvertedY({
    required double itemY,
    required double itemHeight,
    required double scaleFactor,
    required double baseOriginalHeight,
  }) {
    return (baseOriginalHeight - itemY - itemHeight) * scaleFactor;
  }

  Map<String, dynamic> splitStringAndAnnotations(String input) {
    final RegExp regExp = RegExp(r'\[(.*?)\]');
    final Iterable<RegExpMatch> matches = regExp.allMatches(input);
    final List<String> annotations =
        matches.map((RegExpMatch match) => match.group(1)!).toList();
    final String textWithoutAnnotations = input.replaceAll(regExp, '').trim();
    return <String, dynamic>{
      'text': textWithoutAnnotations.getVisiblePrompt(),
      'annotations': annotations.map((String a) => '[$a]').toList(),
    };
  }
}
