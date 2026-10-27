import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/design.dart';

void main() {
  group('AppSpace', () {
    test('matches the spec values', () {
      expect(AppSpace.xs, 4);
      expect(AppSpace.sm, 8);
      expect(AppSpace.md, 12);
      expect(AppSpace.lg, 16);
      expect(AppSpace.xl, 24);
      expect(AppSpace.xxl, 32);
    });
  });

  group('AppRadius', () {
    test('matches the spec values', () {
      expect(AppRadius.sm, 8);
      expect(AppRadius.md, 14);
      expect(AppRadius.lg, 22);
      expect(AppRadius.xl, 32);
      expect(AppRadius.pill, 999);
    });
  });

  group('AppMotion', () {
    test('matches the spec values', () {
      expect(AppMotion.fast, const Duration(milliseconds: 120));
      expect(AppMotion.base, const Duration(milliseconds: 200));
      expect(AppMotion.slow, const Duration(milliseconds: 320));
      expect(AppMotion.max, const Duration(milliseconds: 500));
      expect(AppMotion.standard, Curves.easeOutCubic);
      expect(AppMotion.emphasized, Curves.easeInOutCubicEmphasized);
    });
  });

  group('AppTokens', () {
    test('dark glass levels use blur sigma 6 / 10 / 20', () {
      expect(AppTokens.dark.glass(AppGlassLevel.thin).blurSigma, 6);
      expect(AppTokens.dark.glass(AppGlassLevel.regular).blurSigma, 10);
      expect(AppTokens.dark.glass(AppGlassLevel.thick).blurSigma, 20);
    });

    test('dark glass levels keep today fill and border alphas', () {
      expect(AppTokens.dark.glassThin.fillAlpha, 0.06);
      expect(AppTokens.dark.glassThin.borderAlpha, 0.3);
      expect(AppTokens.dark.glassRegular.fillAlpha, 0.12);
      expect(AppTokens.dark.glassRegular.borderAlpha, 0.3);
      expect(AppTokens.dark.glassThick.fillAlpha, 0.22);
      expect(AppTokens.dark.glassThick.borderAlpha, 0.55);
    });

    test('dark colors match the current palette', () {
      expect(AppTokens.dark.background, const Color(0xFF0A0E1A));
      expect(AppTokens.dark.glassSurface, const Color(0xFF1A1F35));
      expect(AppTokens.dark.glassBorder, const Color(0xFF2A3148));
      expect(AppTokens.dark.success, const Color(0xFF00D68F));
      expect(AppTokens.dark.warning, const Color(0xFFFFB020));
      expect(AppTokens.dark.shadow, const Color(0xFF000000));
      expect(AppTokens.dark.highlight, const Color(0xFFFFFFFF));
    });

    test('lerp interpolates colors', () {
      final AppTokens other = AppTokens.dark.copyWith(
        background: const Color(0xFFFFFFFF),
      );
      final AppTokens result = AppTokens.dark.lerp(other, 0.5);
      expect(
        result.background,
        Color.lerp(AppTokens.dark.background, other.background, 0.5),
      );
    });

    test('lerp interpolates glass styles', () {
      final AppTokens other = AppTokens.dark.copyWith(
        glassThin: const AppGlassStyle(
          blurSigma: 10,
          fillAlpha: 0.1,
          borderAlpha: 0.5,
        ),
      );
      final AppGlassStyle result = AppTokens.dark.lerp(other, 0.5).glassThin;
      expect(result.blurSigma, 8);
      expect(result.fillAlpha, closeTo(0.08, 1e-9));
      expect(result.borderAlpha, closeTo(0.4, 1e-9));
    });

    test('lerp with null returns the same instance', () {
      expect(identical(AppTokens.dark.lerp(null, 0.5), AppTokens.dark), isTrue);
    });

    test('has value equality', () {
      expect(AppTokens.dark.copyWith(), AppTokens.dark);
      expect(AppTokens.dark.copyWith().hashCode, AppTokens.dark.hashCode);
      expect(
        AppTokens.dark.copyWith(success: const Color(0xFF000001)),
        isNot(AppTokens.dark),
      );
    });
  });

  group('AppThemeContext', () {
    testWidgets('context.tokens fails clearly without AppTokens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Builder(
            builder: (BuildContext context) {
              context.tokens;
              return const SizedBox();
            },
          ),
        ),
      );
      final Object? exception = tester.takeException();
      expect(exception, isA<FlutterError>());
      expect((exception! as FlutterError).message, contains('AppTheme.dark'));
    });

    testWidgets('context accessors resolve the theme', (
      WidgetTester tester,
    ) async {
      late AppTokens tokens;
      late ColorScheme colors;
      late TextTheme text;
      final ThemeData theme = ThemeData(
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 77)),
        extensions: const <ThemeExtension<dynamic>>[AppTokens.dark],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (BuildContext context) {
              tokens = context.tokens;
              colors = context.colors;
              text = context.text;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tokens, AppTokens.dark);
      expect(colors, theme.colorScheme);
      expect(text.bodyMedium?.fontSize, 77);
    });
  });
}
