import 'package:flutter/painting.dart';

/// WCAG 2.x contrast ratio between [a] and [b] (1 to 21), order independent.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
