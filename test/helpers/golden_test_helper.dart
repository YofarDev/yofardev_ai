import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';

/// Helper configuration for golden tests
class GoldenTestHelper {
  /// Initialize golden toolkit and load fonts. The app's bundled Google
  /// fonts must never be fetched at runtime: a missing weight fails loudly.
  static Future<void> init() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Ensure fonts are loaded before tests
    await loadAppFonts();
  }

  /// Waits for the bundled [GoogleFonts] to finish loading, then pumps so the
  /// text re-renders with them. Call it before matching a golden, otherwise
  /// text may be captured in a fallback font.
  static Future<void> settleFonts(WidgetTester tester) async {
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pump();
  }

  /// Matches [name] against its golden file, after the app fonts have loaded.
  static Future<void> matchGolden(
    WidgetTester tester,
    String name, {
    Future<void> Function(WidgetTester)? customPump,
  }) async {
    await settleFonts(tester);
    await screenMatchesGolden(tester, name, customPump: customPump);
  }

  /// Create test wrapper widget with necessary providers
  static Widget makeTestableWidget({
    required Widget child,
    ThemeData? theme,
    Locale? locale,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(child: child),
    );
  }

  /// Wrapper for widgets that need to be tested in a container
  static Widget makeSurfaceTestable({
    required Widget child,
    required Size surfaceSize,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      width: surfaceSize.width,
      height: surfaceSize.height,
      color: backgroundColor,
      child: child,
    );
  }
}
