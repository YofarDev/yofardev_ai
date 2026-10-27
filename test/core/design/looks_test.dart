import 'package:flutter/foundation.dart';
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

    test('onAccent is ink when it clears 4.5, black next, else white', () {
      expect(
        UiLooks.storybook.palette(AvatarScene.livingRoom).onAccent,
        UiLooks.storybook.ink,
      );
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
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
    test('enable then restore returns the flag to its previous value', () {
      final bool before = GoogleFonts.config.allowRuntimeFetching;
      LabFontFetching.enable();
      expect(GoogleFonts.config.allowRuntimeFetching, kDebugMode);
      LabFontFetching.restore();
      expect(GoogleFonts.config.allowRuntimeFetching, before);
    });
  });
}
