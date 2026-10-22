import 'package:yofardev_ai/core/models/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/features/settings/data/repositories/locale_repository_impl.dart';

void main() {
  group('LocaleRepositoryImpl', () {
    late LocaleRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocaleRepositoryImpl(prefs: prefs);
    });

    test('getLanguage returns default language when none saved', () async {
      final Result<String> result = await repository.getLanguage();
      expect(result.isOk, true);
      expect(result.getOrNull, 'fr');
    });

    test('setLanguage saves and retrieves language', () async {
      await repository.setLanguage('en');
      final Result<String> result = await repository.getLanguage();
      expect(result.getOrNull, 'en');
    });

    test('getLanguage returns saved language', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'language': 'en',
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocaleRepositoryImpl(prefs: prefs);

      final Result<String> result = await repository.getLanguage();
      expect(result.getOrNull, 'en');
    });
  });
}
