import 'language_en.dart';
import 'language_fr.dart';
import 'languages.dart';

class LocalizationManager {
  static final LocalizationManager _instance = LocalizationManager._internal();
  factory LocalizationManager() => _instance;
  LocalizationManager._internal();

  Languages? _currentLanguage;
  static late String code;

  Future<void> initialize(String languageCode) async {
    code = languageCode;
    if (languageCode == 'en' || languageCode == 'fr') {
      _currentLanguage = await _loadLanguage(languageCode);
    } else {
      _currentLanguage = await _loadLanguage('en');
    }
  }

  Languages get currentLanguage {
    if (_currentLanguage == null) {
      throw Exception('LocalizationManager not initialized');
    }
    return _currentLanguage!;
  }

  Future<Languages> _loadLanguage(String languageCode) async {
    switch (languageCode) {
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

String get languageCode => LocalizationManager.code;
