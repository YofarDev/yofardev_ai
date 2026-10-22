import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';

/// Helper configuration for golden tests
class GoldenTestHelper {
  /// Initialize golden toolkit and load fonts
  static Future<void> init() async {
    // Ensure fonts are loaded before tests
    await loadAppFonts();
  }

  /// Create test wrapper widget with necessary providers
  static Widget makeTestableWidget({
    required Widget child,
    ThemeData? theme,
    Locale? locale,
  }) {
    return MaterialApp(
      theme: theme ?? ThemeData.light(),
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
