import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/design.dart';

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

    test('carries the AppTokens extension', () {
      expect(AppTheme.dark.extension<AppTokens>(), isNotNull);
      expect(AppTheme.dark.extension<AppTokens>(), AppTokens.dark);
    });

    test('scaffold background comes from the tokens', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, AppTokens.dark.background);
    });

    test('focused input border is a 2px cyan outline', () {
      final InputBorder? border =
          AppTheme.dark.inputDecorationTheme.focusedBorder;
      expect(
        border!.borderSide,
        const BorderSide(color: Color(0xFF00D4FF), width: 2),
      );
    });

    test('titles use Outfit and body text uses Plus Jakarta Sans', () {
      final TextTheme textTheme = AppTheme.dark.textTheme;
      expect(textTheme.titleLarge!.fontFamily, contains('Outfit'));
      expect(textTheme.bodyMedium!.fontFamily, contains('PlusJakartaSans'));
    });

    test('component themes keep their values', () {
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
    });
  });
}
