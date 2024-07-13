import 'dart:ui';

import 'language_en.dart';
import 'language_fr.dart';
import 'languages.dart';

class LocalizationManager {
  static final LocalizationManager _instance = LocalizationManager._internal();
  factory LocalizationManager() => _instance;
  LocalizationManager._internal();

  Languages? _currentLanguage;

  Future<void> initialize(Locale locale) async {
    if (locale.languageCode == 'en' || locale.languageCode == 'fr') {
      _currentLanguage = await _loadLanguage(locale);
    } else {
      _currentLanguage = await _loadLanguage(const Locale('en'));
    }
  }

  Languages get currentLanguage {
    if (_currentLanguage == null) {
      throw Exception('LocalizationManager not initialized');
    }
    return _currentLanguage!;
  }

  Future<Languages> _loadLanguage(Locale locale) async {
    switch (locale.languageCode) {
      case 'fr':
        return LanguageFr();
      case 'en':
        return LanguageEn();
      default:
        return LanguageEn(); // Default to English
    }
  }
}

// Global accessor function
Languages get localized => LocalizationManager().currentLanguage;
