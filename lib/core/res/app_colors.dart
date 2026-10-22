import 'package:flutter/material.dart';

/// Modern glassmorphic color palette with cosmic gradient aesthetic
class AppColors {
  // Primary Colors - Electric Cyan
  static const Color primary = Color(0xFF00D4FF);
  static const Color onPrimary = Color(0xFF001F29);
  static const Color primaryContainer = Color(0xFF004E5F);

  // Secondary Colors - Vibrant Magenta
  static const Color secondary = Color(0xFFFF006E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFF94BB);

  // Background - Deep Cosmic Gradient
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141829);
  static const Color onSurface = Color(0xFFF5F5F7);

  // Glassmorphic Surfaces - Dark semi-transparent for cosmic theme
  static const Color glassSurface = Color(0xFF1A1F35);
  static const Color glassBorder = Color(0xFF2A3148);

  // Accent Colors
  static const Color accent = Color(0xFF7B61FF);
  static const Color success = Color(0xFF00D68F);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4757);
  static const Color onError = Color(0xFFFFFFFF);

  // Gradient Mesh Colors
  static const List<Color> gradientMesh = <Color>[
    Color(0xFF7B61FF), // Violet
    Color(0xFF00D4FF), // Cyan
    Color(0xFFFF006E), // Magenta
    Color(0xFF141829), // Deep Blue
  ];

  // Legacy support
  static const Color pink = Color(0xFFFEE6ED);
}
