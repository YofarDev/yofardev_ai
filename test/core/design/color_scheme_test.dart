import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/theme/app_color_scheme.dart';

/// WCAG contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('buildDarkColorScheme', () {
    final ColorScheme scheme = buildDarkColorScheme();

    test('is a dark scheme', () {
      expect(scheme.brightness, Brightness.dark);
    });

    test('maps palette roles', () {
      expect(scheme.primary, const Color(0xFF00D4FF));
      expect(scheme.tertiary, const Color(0xFF7B61FF));
      expect(scheme.outline, const Color(0xFF2A3148));
      expect(scheme.outlineVariant, const Color(0xFF2A3148));
      expect(scheme.surface, const Color(0xFF141829));
      expect(scheme.surfaceContainerLowest, const Color(0xFF0A0E1A));
      expect(scheme.surfaceContainerHighest, const Color(0xFF1A1F35));
      expect(scheme.error, const Color(0xFFFF4757));
    });

    test('onSurfaceVariant is onSurface at 70% alpha', () {
      expect(scheme.onSurfaceVariant.a, closeTo(0.7, 0.01));
      expect(scheme.onSurfaceVariant.r, scheme.onSurface.r);
    });

    test('onSurface on surface contrast is at least 7.0', () {
      expect(
        contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('onPrimary on primary contrast is at least 4.5', () {
      expect(
        contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
