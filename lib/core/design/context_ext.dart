import 'package:flutter/material.dart';

import 'tokens/app_tokens.dart';

/// Short accessors for theme data, so widgets never reach for `Theme.of`.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  /// The app's [AppTokens]; throws a [FlutterError] if the ambient theme was
  /// not built with them (for example a bare `ThemeData()` in a test).
  AppTokens get tokens {
    final AppTokens? tokens = Theme.of(this).extension<AppTokens>();
    if (tokens == null) {
      throw FlutterError(
        'AppTokens missing from the theme: build the app and tests with '
        'AppTheme.dark',
      );
    }
    return tokens;
  }
}
