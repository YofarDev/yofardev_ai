import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/result.dart';
import '../../domain/repositories/locale_repository.dart';

class LocaleRepositoryImpl implements LocaleRepository {
  const LocaleRepositoryImpl({required this.prefs});

  final SharedPreferences prefs;

  static const String _languageKey = 'language';

  @override
  Future<Result<String>> getLanguage() async {
    try {
      final String? language = prefs.getString(_languageKey);
      return Result<String>.ok(language ?? 'fr');
    } catch (e, st) {
      return Result<String>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LocaleRepository'),
      );
    }
  }

  @override
  Future<Result<void>> setLanguage(String languageCode) async {
    try {
      await prefs.setString(_languageKey, languageCode);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LocaleRepository'),
      );
    }
  }
}
