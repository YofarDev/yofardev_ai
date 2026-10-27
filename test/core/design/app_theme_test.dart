import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

const Color _ink = Color(0xFF16121D);
const Color _surface = Color(0xFF211B2B);
const Color _onSurface = Color(0xFFF3EBDD);
const Color _outline = Color(0xFF3A3046);

const Map<AvatarScene, Color> _accents = <AvatarScene, Color>{
  AvatarScene.livingRoom: Color(0xFFF4B860),
  AvatarScene.campfire: Color(0xFFFF8552),
  AvatarScene.beach: Color(0xFFFF9478),
  AvatarScene.deepSpace: Color(0xFFB79CFF),
};

Color _container(Color accent) =>
    Color.alphaBlend(accent.withValues(alpha: 0.25), _surface);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme.dark', () {
    test('is a dark Material 3 theme', () {
      final ThemeData theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('is the living-room theme', () {
      expect(
        identical(AppTheme.dark, AppTheme.forScene(AvatarScene.livingRoom)),
        isTrue,
      );
    });

    test('colorScheme pins every Storybook role', () {
      final ColorScheme s = AppTheme.dark.colorScheme;
      const Color amber = Color(0xFFF4B860);
      const Color violet = Color(0xFFB79CFF);
      const Color red = Color(0xFFFF6B6B);
      expect(s.brightness, Brightness.dark);
      expect(s.primary, amber);
      expect(s.onPrimary, _ink);
      expect(s.primaryContainer, _container(amber));
      expect(s.onPrimaryContainer, _onSurface);
      expect(s.secondary, amber);
      expect(s.onSecondary, _ink);
      expect(s.secondaryContainer, _container(amber));
      expect(s.onSecondaryContainer, _onSurface);
      expect(s.tertiary, violet);
      expect(s.onTertiary, _ink);
      expect(s.tertiaryContainer, _container(violet));
      expect(s.onTertiaryContainer, _onSurface);
      expect(s.error, red);
      expect(s.onError, _ink);
      expect(s.errorContainer, _container(red));
      expect(s.onErrorContainer, _onSurface);
      expect(s.surface, _surface);
      expect(s.onSurface, _onSurface);
      expect(s.onSurfaceVariant, _onSurface.withValues(alpha: 0.7));
      expect(s.surfaceContainerLowest, _ink);
      expect(s.surfaceContainerLow, _surface);
      expect(s.surfaceContainer, _surface);
      expect(s.surfaceContainerHigh, _surface);
      expect(s.surfaceContainerHighest, _surface);
      expect(s.outline, _outline);
      expect(s.outlineVariant, _outline);
    });

    test('carries AppTokens.dark: Storybook living room', () {
      final AppTokens tokens = AppTheme.dark.extension<AppTokens>()!;
      expect(tokens, AppTokens.dark);
      expect(tokens.background, _ink);
      expect(tokens.glassSurface, _surface);
      expect(tokens.glassBorder, _outline);
      expect(tokens.success, const Color(0xFF7BD88F));
      expect(tokens.warning, const Color(0xFFF4B860));
      expect(tokens.scene.accent, const Color(0xFFF4B860));
      expect(tokens.scene.onAccent, _ink);
      expect(tokens.outlineWidth, 1);
      expect(tokens.radiusScale, 1.15);
    });

    test('scaffold background is the ink', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, _ink);
    });

    test('focused input border is a 2px accent outline', () {
      final InputBorder? border =
          AppTheme.dark.inputDecorationTheme.focusedBorder;
      expect(
        border!.borderSide,
        const BorderSide(color: Color(0xFFF4B860), width: 2),
      );
    });

    test('titles use Fraunces and body text uses Manrope', () {
      final TextTheme textTheme = AppTheme.dark.textTheme;
      expect(textTheme.titleLarge!.fontFamily, contains('Fraunces'));
      expect(textTheme.headlineSmall!.fontFamily, contains('Fraunces'));
      expect(textTheme.bodyMedium!.fontFamily, contains('Manrope'));
      expect(textTheme.labelLarge!.fontFamily, contains('Manrope'));
      expect(
        AppTheme.dark.appBarTheme.titleTextStyle!.fontFamily,
        contains('Fraunces'),
      );
    });

    test('app bar title uses the bundled SemiBold Fraunces', () {
      final String? family =
          AppTheme.dark.appBarTheme.titleTextStyle!.fontFamily;
      expect(family, contains('Fraunces'));
      expect(family, contains('600'));
      expect(family, AppTheme.dark.textTheme.headlineSmall!.fontFamily);
    });

    test('component themes keep their values, radii scaled by 1.15', () {
      final ThemeData theme = AppTheme.dark;
      expect(theme.cardTheme.elevation, 4);
      expect(theme.floatingActionButtonTheme.elevation, 12);
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(theme.dividerTheme.thickness, 1);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(
        theme.listTileTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
      final RoundedRectangleBorder card =
          theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        (card.borderRadius as BorderRadius).topLeft.x,
        closeTo(16 * 1.15, 0.001),
      );
    });
  });

  group('AppTheme.forScene', () {
    test('caches one ThemeData per scene', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(
          identical(AppTheme.forScene(scene), AppTheme.forScene(scene)),
          isTrue,
        );
      }
      expect(
        identical(
          AppTheme.forScene(AvatarScene.beach),
          AppTheme.forScene(AvatarScene.campfire),
        ),
        isFalse,
      );
    });

    test('the accent takes the scene light', () {
      expect(
        AppTheme.forScene(
          AvatarScene.beach,
        ).extension<AppTokens>()!.scene.accent,
        const Color(0xFFFF9478),
      );
      for (final AvatarScene scene in AvatarScene.values) {
        final ThemeData theme = AppTheme.forScene(scene);
        final Color accent = _accents[scene]!;
        expect(theme.colorScheme.primary, accent, reason: scene.name);
        expect(theme.colorScheme.secondary, accent, reason: scene.name);
        expect(theme.colorScheme.primaryContainer, _container(accent));
        expect(theme.colorScheme.secondaryContainer, _container(accent));
        expect(theme.extension<AppTokens>()!.scene.accent, accent);
        expect(theme.extension<AppTokens>()!.scene.glow.a, closeTo(0.35, 0.01));
        // Scene-independent roles stay put.
        expect(theme.colorScheme.tertiary, const Color(0xFFB79CFF));
        expect(theme.colorScheme.error, const Color(0xFFFF6B6B));
        expect(theme.colorScheme.surface, _surface);
        expect(theme.scaffoldBackgroundColor, _ink);
      }
    });

    for (final AvatarScene scene in AvatarScene.values) {
      test('${scene.name}: every role pair clears its contrast floor', () {
        final ThemeData theme = AppTheme.forScene(scene);
        final ColorScheme s = theme.colorScheme;
        final AppTokens t = theme.extension<AppTokens>()!;

        void text(Color fg, Color bg, String pair) => expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '${scene.name} $pair',
        );
        void icon(Color fg, Color bg, String pair) => expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(3),
          reason: '${scene.name} $pair',
        );

        expect(contrastRatio(s.onSurface, s.surface), greaterThanOrEqualTo(7));
        text(s.onPrimary, s.primary, 'onPrimary/primary');
        text(s.onSecondary, s.secondary, 'onSecondary/secondary');
        text(s.onTertiary, s.tertiary, 'onTertiary/tertiary');
        text(s.onError, s.error, 'onError/error');
        text(s.onPrimaryContainer, s.primaryContainer, 'onPrimaryContainer');
        text(
          s.onSecondaryContainer,
          s.secondaryContainer,
          'onSecondaryContainer',
        );
        text(s.onTertiaryContainer, s.tertiaryContainer, 'onTertiaryContainer');
        text(s.onErrorContainer, s.errorContainer, 'onErrorContainer');
        text(t.scene.onAccent, t.scene.accent, 'onAccent/accent');
        for (final Color bg in <Color>[
          s.surface,
          s.surfaceContainerLowest,
          s.surfaceContainerLow,
          s.surfaceContainer,
          s.surfaceContainerHigh,
          s.surfaceContainerHighest,
          t.background,
          t.glassSurface,
        ]) {
          final String hex = bg.toARGB32().toRadixString(16);
          text(s.onSurface, bg, 'onSurface/$hex');
          text(s.primary, bg, 'primary/$hex');
          text(s.tertiary, bg, 'tertiary/$hex');
          text(s.error, bg, 'error/$hex');
          icon(t.success, bg, 'success/$hex');
          icon(t.warning, bg, 'warning/$hex');
        }
      });
    }
  });
}
