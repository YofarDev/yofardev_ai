import 'package:flutter/material.dart';

import '../design/theme/app_theme.dart' as design;

/// Forwarder to [design.AppTheme.dark]; removed once callers migrate.
class AppTheme {
  static ThemeData get lightTheme => design.AppTheme.dark;
}
