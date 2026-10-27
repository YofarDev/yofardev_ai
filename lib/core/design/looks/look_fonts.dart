import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui_look.dart';

TextStyle _display(LookFonts fonts, TextStyle style) =>
    GoogleFonts.getFont(fonts.display, textStyle: style);

TextStyle _text(LookFonts fonts, TextStyle style) =>
    GoogleFonts.getFont(fonts.text, textStyle: style);

/// The production `LookTextThemeBuilder`: the app text theme set in a look's
/// fonts. The display font styles display/headline/title and the text font
/// styles body/label. Weights stay within the bundled ones (display
/// 400/500/600, text 400/500).
TextTheme googleFontsTextThemeBuilder(LookFonts fonts, ColorScheme scheme) {
  final Color c = scheme.onSurface;
  return TextTheme(
    displayLarge: _display(
      fonts,
      TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: c,
      ),
    ),
    displayMedium: _display(
      fonts,
      TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: c),
    ),
    displaySmall: _display(
      fonts,
      TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: c),
    ),
    headlineLarge: _display(
      fonts,
      TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: c),
    ),
    headlineMedium: _display(
      fonts,
      TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: c),
    ),
    headlineSmall: _display(
      fonts,
      TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: c),
    ),
    titleLarge: _display(
      fonts,
      TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: c),
    ),
    titleMedium: _display(
      fonts,
      TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c),
    ),
    titleSmall: _display(
      fonts,
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c),
    ),
    bodyLarge: _text(
      fonts,
      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: c),
    ),
    bodyMedium: _text(
      fonts,
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c),
    ),
    bodySmall: _text(
      fonts,
      TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: c.withValues(alpha: 0.7),
      ),
    ),
    labelLarge: _text(
      fonts,
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c),
    ),
    labelMedium: _text(
      fonts,
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c),
    ),
    labelSmall: _text(
      fonts,
      TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c),
    ),
  );
}

/// Debug-only switch for runtime font downloads, used while the UI lab is
/// open (the candidate fonts are not bundled).
abstract final class LabFontFetching {
  static bool? _previous;

  /// Allows runtime font fetching. No-op outside debug builds.
  static void enable() {
    if (!kDebugMode) {
      return;
    }
    _previous ??= GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = true;
  }

  /// Restores the flag value saved by [enable].
  static void restore() {
    final bool? previous = _previous;
    if (previous == null) {
      return;
    }
    GoogleFonts.config.allowRuntimeFetching = previous;
    _previous = null;
  }
}
