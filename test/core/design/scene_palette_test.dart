import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

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

  group('ScenePalette.fromAccent', () {
    const Color ink = Color(0xFF16121D);

    test('equals the Storybook palette of every scene', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(
          ScenePalette.fromAccent(
            UiLooks.storybook.accents[scene]!,
            ink: UiLooks.storybook.ink,
          ),
          UiLooks.storybook.palette(scene),
          reason: scene.name,
        );
      }
    });

    test('keeps the accent and sets the glow to the accent at 0x59 alpha', () {
      const Color accent = Color(0xFFB79CFF);
      final ScenePalette p = ScenePalette.fromAccent(accent, ink: ink);
      expect(p.accent, accent);
      expect(p.glow, const Color(0x59B79CFF));
    });

    test('onAccent prefers ink when it clears 4.5', () {
      const Color accent = Color(0xFFF4B860);
      expect(contrastRatio(ink, accent), greaterThanOrEqualTo(4.5));
      expect(ScenePalette.fromAccent(accent, ink: ink).onAccent, ink);
    });

    test('onAccent falls back to black, then to white', () {
      const Color midInk = Color(0xFF808080);
      const Color bright = Color(0xFFFFC24B);
      expect(contrastRatio(midInk, bright), lessThan(4.5));
      expect(
        ScenePalette.fromAccent(bright, ink: midInk).onAccent,
        const Color(0xFF000000),
      );
      const Color dark = Color(0xFF2A2A6A);
      expect(contrastRatio(midInk, dark), lessThan(4.5));
      expect(contrastRatio(const Color(0xFF000000), dark), lessThan(4.5));
      expect(
        ScenePalette.fromAccent(dark, ink: midInk).onAccent,
        const Color(0xFFFFFFFF),
      );
    });
  });
}
