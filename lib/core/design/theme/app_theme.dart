import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_tokens.dart';
import 'app_color_scheme.dart';
import 'app_text_theme.dart';

/// The app's theme: a cosmic glassmorphic dark palette. Use [dark] for the
/// app and for every widget/golden test harness.
abstract final class AppTheme {
  static ThemeData get dark {
    final ColorScheme scheme = buildDarkColorScheme();
    const AppTokens tokens = AppTokens.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: const <ThemeExtension<dynamic>>[tokens],

      // Typography
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: buildTextTheme(scheme),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // Card Theme - Glassmorphic dark
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: tokens.glassBorder, width: 1),
        ),
        color: tokens.glassSurface.withValues(alpha: 0.6),
        shadowColor: scheme.surface.withValues(alpha: 0.5),
      ),

      // Radio buttons for dark theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.onSurface.withValues(alpha: 0.6);
        }),
        overlayColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.2);
          }
          return scheme.onSurface.withValues(alpha: 0.1);
        }),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.glassSurface.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.hovered)) {
              return tokens.glassSurface;
            }
            if (states.contains(WidgetState.pressed)) {
              return tokens.glassSurface.withValues(alpha: 0.8);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary;
            }
            return scheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.1);
            }
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.2);
            }
            return null;
          }),
        ),
      ),

      // FAB Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // List Tile Theme - Dark glassmorphic
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.onSurface.withValues(alpha: 0.7),
        textColor: scheme.onSurface,
        tileColor: tokens.glassSurface.withValues(alpha: 0.4),
        selectedTileColor: scheme.primary.withValues(alpha: 0.15),
        selectedColor: scheme.primary,
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: scheme.surface,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: scheme.onSurface),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: tokens.glassBorder.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
