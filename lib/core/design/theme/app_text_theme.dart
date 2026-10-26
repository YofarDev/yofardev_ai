import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's [TextTheme]: Outfit for display/headline/title, Plus Jakarta Sans
/// for body/label. Colors come from [scheme].
TextTheme buildTextTheme(ColorScheme scheme) {
  final Color onSurface = scheme.onSurface;
  return TextTheme(
    // Display styles - Outfit
    displayLarge: GoogleFonts.outfit(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: onSurface,
    ),
    displayMedium: GoogleFonts.outfit(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    displaySmall: GoogleFonts.outfit(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),

    // Headline styles - Outfit
    headlineLarge: GoogleFonts.outfit(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    headlineMedium: GoogleFonts.outfit(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    headlineSmall: GoogleFonts.outfit(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),

    // Title styles - Outfit
    titleLarge: GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    titleMedium: GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    titleSmall: GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),

    // Body styles - Plus Jakarta Sans
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: onSurface.withValues(alpha: 0.7),
    ),

    // Label styles - Plus Jakarta Sans
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
  );
}
