import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

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
    for (final UiLook look in UiLooks.all) {
      for (final AvatarScene scene in AvatarScene.values) {
        test('${look.id} / ${scene.name}', () {
          final ScenePalette p = look.palette(scene);
          expect(
            contrastRatio(look.onSurface, look.surface),
            greaterThanOrEqualTo(7),
          );
          expect(
            contrastRatio(p.accent, look.surface),
            greaterThanOrEqualTo(3),
          );
          expect(
            contrastRatio(p.onAccent, p.accent),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  });

  group('palette', () {
    test('glow is the accent at 35% alpha', () {
      for (final UiLook look in UiLooks.all) {
        for (final AvatarScene scene in AvatarScene.values) {
          final ScenePalette p = look.palette(scene);
          expect(p.glow.a, closeTo(0.35, 0.01));
          expect(
            p.glow.toARGB32() & 0x00FFFFFF,
            p.accent.toARGB32() & 0x00FFFFFF,
          );
        }
      }
    });

    UiLook lookWith(Color ink, Color accent) => UiLook(
      id: 'custom',
      name: 'Custom',
      ink: ink,
      surface: const Color(0xFF202020),
      onSurface: Colors.white,
      outline: const Color(0xFF404040),
      surfaceStyle: AppSurfaceStyle.glass,
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

    test('every preset defines an accent for every scene', () {
      for (final UiLook look in UiLooks.all) {
        expect(look.accents.keys.toSet(), AvatarScene.values.toSet());
      }
    });

    test('palette throws a clear error for a scene without accent', () {
      final UiLook partial = UiLook(
        id: 'partial',
        name: 'Partial',
        ink: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        outline: Colors.grey,
        surfaceStyle: AppSurfaceStyle.glass,
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

    test('all three looks are listed in order', () {
      expect(UiLooks.all.map((UiLook l) => l.id).toList(), <String>[
        'neon',
        'storybook',
        'cel',
      ]);
    });
  });

  group('buildLookTheme', () {
    test('neon on livingRoom matches AppTheme.dark core colors and tokens', () {
      final ThemeData theme = buildLookTheme(
        UiLooks.neon,
        AvatarScene.livingRoom,
        textThemeBuilder: _fakeTextTheme,
      );
      final ThemeData ref = AppTheme.dark;
      expect(theme.colorScheme.primary, ref.colorScheme.primary);
      expect(theme.colorScheme.surface, ref.colorScheme.surface);
      expect(theme.colorScheme.onSurface, ref.colorScheme.onSurface);
      expect(theme.colorScheme.outline, ref.colorScheme.outline);
      expect(theme.scaffoldBackgroundColor, ref.scaffoldBackgroundColor);

      final AppTokens t = theme.extension<AppTokens>()!;
      final AppTokens r = ref.extension<AppTokens>()!;
      expect(t.background, r.background);
      expect(t.glassSurface, r.glassSurface);
      expect(t.glassBorder, r.glassBorder);
      expect(t.success, r.success);
      expect(t.warning, r.warning);
      expect(t.scene.accent, r.scene.accent);
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
      expect(theme.colorScheme.tertiary, p.accent);
      expect(theme.colorScheme.surfaceContainer, UiLooks.storybook.surface);
      expect(theme.extension<AppTokens>()!.scene, p);
      expect(theme.extension<AppTokens>()!.background, UiLooks.storybook.ink);
    });

    test('cel look yields cel tokens', () {
      final AppTokens t = buildLookTheme(
        UiLooks.cel,
        AvatarScene.beach,
        textThemeBuilder: _fakeTextTheme,
      ).extension<AppTokens>()!;
      expect(t.surfaceStyle, AppSurfaceStyle.cel);
      expect(t.outlineWidth, 2);
      expect(t.radiusScale, 1.35);
    });

    test('radii are multiplied by radiusScale and fonts are applied', () {
      final ThemeData theme = buildLookTheme(
        UiLooks.cel,
        AvatarScene.beach,
        textThemeBuilder: _fakeTextTheme,
      );
      final RoundedRectangleBorder card =
          theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        (card.borderRadius as BorderRadius).topLeft.x,
        closeTo(16 * 1.35, 0.001),
      );
      expect(theme.textTheme.bodyMedium?.fontFamily, UiLooks.cel.fonts.text);
      expect(
        theme.textTheme.displayLarge?.fontFamily,
        UiLooks.cel.fonts.display,
      );
    });
  });

  group('LabFontFetching', () {
    late bool ambient;

    setUp(() {
      ambient = GoogleFonts.config.allowRuntimeFetching;
      LabFontFetching.restore();
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    tearDown(() {
      LabFontFetching.restore();
      GoogleFonts.config.allowRuntimeFetching = ambient;
    });

    test(
      'enable turns fetching on (debug) and restore returns it to false',
      () {
        LabFontFetching.enable();
        expect(GoogleFonts.config.allowRuntimeFetching, isTrue);
        LabFontFetching.restore();
        expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      },
    );

    test('restore without enable is a no-op', () {
      GoogleFonts.config.allowRuntimeFetching = true;
      LabFontFetching.restore();
      expect(GoogleFonts.config.allowRuntimeFetching, isTrue);
    });

    test('restore twice is a no-op the second time', () {
      LabFontFetching.enable();
      LabFontFetching.restore();
      GoogleFonts.config.allowRuntimeFetching = true;
      LabFontFetching.restore();
      expect(GoogleFonts.config.allowRuntimeFetching, isTrue);
    });

    test('double enable keeps the first saved value', () {
      LabFontFetching.enable();
      LabFontFetching.enable();
      LabFontFetching.restore();
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    });
  });
}
