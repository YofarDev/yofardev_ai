import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/locale_repository.dart';

class LocaleRepositoryImpl implements LocaleRepository {
  const LocaleRepositoryImpl({required this.prefs});

  final SharedPreferences prefs;

  static const String _languageKey = 'language';

  @override
  Future<Either<Exception, String>> getLanguage() async {
    try {
      final String? language = prefs.getString(_languageKey);
      return Right<Exception, String>(language ?? 'fr');
    } catch (e) {
      return Left<Exception, String>(Exception('Failed to get language: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> setLanguage(String languageCode) async {
    try {
      await prefs.setString(_languageKey, languageCode);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception('Failed to set language: $e'));
    }
  }
}
