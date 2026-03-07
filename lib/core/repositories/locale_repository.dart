import 'package:fpdart/fpdart.dart';

/// Repository for managing language preference persistence
abstract class LocaleRepository {
  /// Get the current saved language code (e.g., 'en', 'fr')
  Future<Either<Exception, String>> getLanguage();

  /// Save the language code
  Future<Either<Exception, void>> setLanguage(String languageCode);
}
