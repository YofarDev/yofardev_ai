import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/repositories/locale_repository_impl.dart';

void main() {
  group('LocaleRepositoryImpl', () {
    late LocaleRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocaleRepositoryImpl(prefs: prefs);
    });

    test('getLanguage returns default language when none saved', () async {
      final result = await repository.getLanguage();
      expect(result.isRight(), true);
      expect(result.getOrElse((e) => ''), 'fr');
    });

    test('setLanguage saves and retrieves language', () async {
      await repository.setLanguage('en');
      final result = await repository.getLanguage();
      expect(result.getOrElse((e) => ''), 'en');
    });

    test('getLanguage returns saved language', () async {
      SharedPreferences.setMockInitialValues({'language': 'en'});
      SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocaleRepositoryImpl(prefs: prefs);

      final result = await repository.getLanguage();
      expect(result.getOrElse((e) => ''), 'en');
    });
  });
}
