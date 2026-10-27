import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/design.dart';

void main() {
  group('ScenePalette', () {
    const ScenePalette a = ScenePalette(
      accent: Color(0xFF00D4FF),
      onAccent: Color(0xFF001F29),
      glow: Color(0x5900D4FF),
    );
    const ScenePalette b = ScenePalette(
      accent: Color(0xFFF4B860),
      onAccent: Color(0xFF16121D),
      glow: Color(0x59F4B860),
    );

    test('lerp halfway interpolates every field like Color.lerp', () {
      final ScenePalette result = ScenePalette.lerp(a, b, 0.5);
      expect(result.accent, Color.lerp(a.accent, b.accent, 0.5));
      expect(result.onAccent, Color.lerp(a.onAccent, b.onAccent, 0.5));
      expect(result.glow, Color.lerp(a.glow, b.glow, 0.5));
    });

    test('lerp at the ends returns the endpoints', () {
      expect(ScenePalette.lerp(a, b, 0), a);
      expect(ScenePalette.lerp(a, b, 1), b);
    });

    test('has value equality', () {
      const ScenePalette same = ScenePalette(
        accent: Color(0xFF00D4FF),
        onAccent: Color(0xFF001F29),
        glow: Color(0x5900D4FF),
      );
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(b));
    });
  });
}
