import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/components/cel_style.dart';
import 'package:yofardev_ai/core/design/components/interactive_surface.dart';
import 'package:yofardev_ai/core/design/design.dart';

void main() {
  final AppTokens tokens = AppTokens.dark;
  const Color base = Color(0xFF2A2545);
  const InteractiveStates idle = (
    hovered: false,
    pressed: false,
    focused: false,
  );

  double luminance(Color c) => c.computeLuminance();

  group('CelStyle', () {
    test('isCel follows surfaceStyle', () {
      expect(tokens.isCel, isFalse);
      expect(tokens.copyWith(surfaceStyle: AppSurfaceStyle.cel).isCel, isTrue);
    });

    test(
      'celFill leaves idle untouched, darkens pressed, lightens hovered',
      () {
        expect(tokens.celFill(base, idle), base);
        final Color pressed = tokens.celFill(base, (
          hovered: false,
          pressed: true,
          focused: false,
        ));
        final Color hovered = tokens.celFill(base, (
          hovered: true,
          pressed: false,
          focused: false,
        ));
        expect(luminance(pressed), lessThan(luminance(base)));
        expect(luminance(hovered), greaterThan(luminance(base)));
        expect(pressed.a, 1);
        expect(hovered.a, 1);
      },
    );

    test('celBorder is the accent when focused and unfilled', () {
      const InteractiveStates focused = (
        hovered: false,
        pressed: false,
        focused: true,
      );
      expect(tokens.celBorder(focused, filled: false), tokens.scene.accent);
      expect(tokens.celBorder(focused, filled: true), tokens.glassBorder);
      expect(tokens.celBorder(idle, filled: false), tokens.glassBorder);
    });

    test('celShadow is a hard 3 px shadow that sinks to 1 px when pressed', () {
      final BoxShadow rest = tokens.celShadow().single;
      final BoxShadow pressed = tokens.celShadow(pressed: true).single;
      expect(rest.offset, const Offset(0, 3));
      expect(pressed.offset, const Offset(0, 1));
      expect(rest.blurRadius, 0);
      expect(rest.color, tokens.shadow.withValues(alpha: 0.6));
    });
  });
}
