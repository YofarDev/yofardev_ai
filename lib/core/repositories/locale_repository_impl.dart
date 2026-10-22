import 'package:shared_preferences/shared_preferences.dart';

import '../models/failure.dart';
import '../models/result.dart';
import '../repositories/locale_repository.dart';

class LocaleRepositoryImpl implements LocaleRepository {
  const LocaleRepositoryImpl({required this.prefs});

  final SharedPreferences prefs;

  static const String _languageKey = 'language';

  @override
  Future<Result<String>> getLanguage() async {
    try {
      final String? language = prefs.getString(_languageKey);
      return Result<String>.ok(language ?? 'fr');
    } catch (e) {
      return Result<String>.err(
        StorageFailure('Failed to get language', e),
      );
    }
  }

  @override
  Future<Result<void>> setLanguage(String languageCode) async {
    try {
      await prefs.setString(_languageKey, languageCode);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(
        StorageFailure('Failed to set language', e),
      );
    }
  }
}
