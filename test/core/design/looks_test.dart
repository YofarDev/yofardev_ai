import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// Fake builder: no font is ever loaded, family names are just applied.
TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) {
  final TextTheme base = ThemeData.dark().textTheme;
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: fonts.display),
    bodyMedium: base.bodyMedium?.copyWith(fontFamily: fonts.text),
    titleLarge: base.titleLarge?.copyWith(fontFamily: fonts.display),
  );
}

void main() {
  group('contrast floors', () {
    const UiLook look = UiLooks.storybook;
    for (final AvatarScene scene in AvatarScene.values) {
      test('${look.id} / ${scene.name}', () {
        final ScenePalette p = look.palette(scene);
        expect(
          contrastRatio(look.onSurface, look.surface),
          greaterThanOrEqualTo(7),
        );
        expect(contrastRatio(p.accent, look.surface), greaterThanOrEqualTo(3));
        expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('storybook roles', () {
    test('binding role values', () {
      const UiLook look = UiLooks.storybook;
      expect(look.error, const Color(0xFFFF6B6B));
      expect(look.onError, const Color(0xFF16121D));
      expect(look.tertiary, const Color(0xFFB79CFF));
      expect(look.onTertiary, const Color(0xFF16121D));
      expect(look.success, const Color(0xFF7BD88F));
      expect(look.warning, const Color(0xFFF4B860));
    });
  });

  group('palette', () {
    test('glow is the accent at 35% alpha', () {
      for (final AvatarScene scene in AvatarScene.values) {
        final ScenePalette p = UiLooks.storybook.palette(scene);
        expect(p.glow.a, closeTo(0.35, 0.01));
        expect(
          p.glow.toARGB32() & 0x00FFFFFF,
          p.accent.toARGB32() & 0x00FFFFFF,
        );
      }
    });

    UiLook lookWith(Color ink, Color accent) => UiLook(
      id: 'custom',
      name: 'Custom',
      ink: ink,
      surface: const Color(0xFF202020),
      onSurface: Colors.white,
      outline: const Color(0xFF404040),
      outlineWidth: 1,
      radiusScale: 1,
      fonts: const LookFonts(display: 'A', text: 'B'),
      accents: <AvatarScene, Color>{
        for (final AvatarScene s in AvatarScene.values) s: accent,
      },
    );

    test('onAccent prefers ink when it clears 4.5', () {
      final UiLook look = lookWith(
        const Color(0xFF16121D),
        const Color(0xFFF4B860),
      );
      expect(
        contrastRatio(look.ink, const Color(0xFFF4B860)),
        greaterThan(4.5),
      );
      expect(look.palette(AvatarScene.beach).onAccent, look.ink);
    });

    test('onAccent falls back to black when ink fails but black clears', () {
      // Mid-grey ink on a mid-bright accent fails; black clears.
      const Color ink = Color(0xFF808080);
      const Color accent = Color(0xFFFFC24B);
      expect(contrastRatio(ink, accent), lessThan(4.5));
      expect(contrastRatio(Colors.black, accent), greaterThanOrEqualTo(4.5));
      expect(
        lookWith(ink, accent).palette(AvatarScene.beach).onAccent,
        Colors.black,
      );
    });

    test('onAccent falls back to white when ink and black both fail', () {
      const Color ink = Color(0xFF808080);
      const Color accent = Color(0xFF2A2A6A);
      expect(contrastRatio(ink, accent), lessThan(4.5));
      expect(contrastRatio(Colors.black, accent), lessThan(4.5));
      expect(
        lookWith(ink, accent).palette(AvatarScene.beach).onAccent,
        Colors.white,
      );
    });

    test('storybook defines an accent for every scene', () {
      expect(
        UiLooks.storybook.accents.keys.toSet(),
        AvatarScene.values.toSet(),
      );
    });

    test('palette throws a clear error for a scene without accent', () {
      final UiLook partial = UiLook(
        id: 'partial',
        name: 'Partial',
        ink: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        outline: Colors.grey,
        outlineWidth: 1,
        radiusScale: 1,
        fonts: const LookFonts(display: 'A', text: 'B'),
        accents: const <AvatarScene, Color>{AvatarScene.beach: Colors.orange},
      );
      expect(
        () => partial.palette(AvatarScene.campfire),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('partial'),
          ),
        ),
      );
    });
  });

  group('buildLookTheme', () {
    test('storybook on livingRoom is AppTheme.dark (scheme and tokens)', () {
      final ThemeData theme = buildLookTheme(
        UiLooks.storybook,
        AvatarScene.livingRoom,
        textThemeBuilder: _fakeTextTheme,
      );
      final ThemeData ref = AppTheme.dark;
      expect(theme.colorScheme, ref.colorScheme);
      expect(theme.scaffoldBackgroundColor, ref.scaffoldBackgroundColor);
      expect(theme.extension<AppTokens>(), AppTokens.dark);
      expect(theme.brightness, Brightness.dark);
    });

    test('colorScheme maps scene palette', () {
      final ThemeData theme = buildLookTheme(
        UiLooks.storybook,
        AvatarScene.campfire,
        textThemeBuilder: _fakeTextTheme,
      );
      final ScenePalette p = UiLooks.storybook.palette(AvatarScene.campfire);
      expect(theme.colorScheme.primary, p.accent);
      expect(theme.colorScheme.onPrimary, p.onAccent);
      expect(theme.colorScheme.secondary, p.accent);
      expect(theme.colorScheme.onSecondary, p.onAccent);
      expect(theme.colorScheme.tertiary, UiLooks.storybook.tertiary);
      expect(theme.colorScheme.onTertiary, UiLooks.storybook.onTertiary);
      expect(theme.colorScheme.error, UiLooks.storybook.error);
      expect(theme.colorScheme.onError, UiLooks.storybook.onError);
      expect(theme.colorScheme.surfaceContainer, UiLooks.storybook.surface);
      expect(theme.extension<AppTokens>()!.scene, p);
      expect(theme.extension<AppTokens>()!.background, UiLooks.storybook.ink);
      expect(theme.extension<AppTokens>()!.success, UiLooks.storybook.success);
      expect(theme.extension<AppTokens>()!.warning, UiLooks.storybook.warning);
    });

    test('storybook tokens carry its outline width and radius scale', () {
      final AppTokens t = buildLookTheme(
        UiLooks.storybook,
        AvatarScene.beach,
        textThemeBuilder: _fakeTextTheme,
      ).extension<AppTokens>()!;
      expect(t.outlineWidth, 1);
      expect(t.radiusScale, 1.15);
    });

    test('radii are multiplied by radiusScale and fonts are applied', () {
      final ThemeData theme = buildLookTheme(
        UiLooks.storybook,
        AvatarScene.beach,
        textThemeBuilder: _fakeTextTheme,
      );
      final RoundedRectangleBorder card =
          theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        (card.borderRadius as BorderRadius).topLeft.x,
        closeTo(16 * 1.15, 0.001),
      );
      expect(
        theme.textTheme.bodyMedium?.fontFamily,
        UiLooks.storybook.fonts.text,
      );
      expect(
        theme.textTheme.displayLarge?.fontFamily,
        UiLooks.storybook.fonts.display,
      );
    });
  });
}
