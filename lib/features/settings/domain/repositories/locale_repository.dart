import '../../../../core/models/result.dart';

/// Repository for managing language preference persistence
abstract class LocaleRepository {
  /// Get the current saved language code (e.g., 'en', 'fr')
  Future<Result<String>> getLanguage();

  /// Save the language code
  Future<Result<void>> setLanguage(String languageCode);
}
