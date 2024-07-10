import 'package:flutter/material.dart';

class AppUtils {
  static Map<String, double> calculateScaledValues(
    BuildContext context, {
    required int originalWidth,
    required int originalHeight,
    required int eyesWidth,
    required int eyesHeight,
    required double eyesX,
    required double eyesY,
    required int mouthWidth,
    required int mouthHeight,
    required double mouthX,
    required double mouthY,
  }) {
    final Size screenSize = MediaQuery.of(context).size;
    final double scaleFactor = screenSize.width / originalWidth;
    final double newEyesX = eyesX * scaleFactor;
    final double newEyesY = (originalHeight - eyesY - eyesHeight) * scaleFactor;
    final double newEyesWidth = eyesWidth * scaleFactor;
    final double newEyesHeight = eyesHeight * scaleFactor;
    final double newBaseWidth = screenSize.width * scaleFactor;
    final double newBaseHeight = originalHeight * scaleFactor;
    final double newMouthX = mouthX * scaleFactor;
    final double newMouthY = (originalHeight - mouthY - mouthHeight) * scaleFactor;
    final double newMouthWidth = mouthWidth * scaleFactor;
    final double newMouthHeight = mouthHeight * scaleFactor;
    return <String, double>{
      'originalHeight': originalHeight.toDouble(),
      'newHeight': newBaseHeight,
      'eyesY': eyesY,
      'newEyesX': newEyesX,
      'newEyesY': newEyesY,
      'newEyesWidth': newEyesWidth,
      'newEyesHeight': newEyesHeight,
      'newBaseWidth': newBaseWidth,
      'newBaseHeight': newBaseHeight,
      'newMouthX': newMouthX,
      'newMouthY': newMouthY,
      'newMouthWidth': newMouthWidth,
      'newMouthHeight': newMouthHeight,
    
    };
  }

  Map<String, dynamic> splitStringAndAnnotations(String input) {
    final RegExp regExp = RegExp(r'\[(.*?)\]');
    final Iterable<RegExpMatch> matches = regExp.allMatches(input);
    final List<String> annotations =
        matches.map((RegExpMatch match) => match.group(1)!).toList();
    final String textWithoutAnnotations = input.replaceAll(regExp, '').trim();
    return <String, dynamic>{
      'text': textWithoutAnnotations,
      'annotations': annotations.map((String a) => '[$a]').toList(),
    };
  }
}
