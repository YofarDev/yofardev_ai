import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'generated/app_localizations.dart';

/// Localization delegates for `MaterialApp` and widget tests.
///
/// Use this instead of the generated `AppLocalizations.localizationsDelegates`:
/// gen-l10n still lists the deprecated `flutter_localizations` Material and
/// Cupertino delegates, which `material_ui` widgets do not read, so every
/// locale other than English fails (no MaterialLocalizations found).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
