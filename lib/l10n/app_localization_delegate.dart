import 'package:flutter/material.dart';

import 'language_en.dart';
import 'language_fr.dart';
import 'languages.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<Languages> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'fr',
      ].contains(locale.languageCode);

  @override
  Future<Languages> load(Locale locale) => _load(locale);

  static Future<Languages> _load(Locale locale) async {
    switch (locale.languageCode) {
      case 'fr':
        return LanguageFr();
      case 'en':
        return LanguageEn();
      default:
        return LanguageFr();
    }
  }

  @override
  bool shouldReload(LocalizationsDelegate<Languages> old) => false;
}
