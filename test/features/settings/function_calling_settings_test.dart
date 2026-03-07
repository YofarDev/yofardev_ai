import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yofardev_ai/features/settings/data/repositories/settings_repository_impl.dart';

void main() {
  // Initialize Flutter test bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
    repository = SettingsRepositoryImpl();
  });

  group('Google Search Settings', () {
    test('should save and retrieve Google Search key', () async {
      const String testKey = 'test-google-key-12345';

      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchKey(testKey);
      final Either<Exception, String?> getResult =
          await repository.getGoogleSearchKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), testKey);
    });

    test('should save and retrieve Google Search Engine ID', () async {
      const String testId = 'test-engine-id-67890';

      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchEngineId(testId);
      final Either<Exception, String?> getResult =
          await repository.getGoogleSearchEngineId();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), testId);
    });

    test('should save and retrieve Google Search enabled state - false',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchEnabled(false);
      final Either<Exception, bool> getResult =
          await repository.getGoogleSearchEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => true), false);
    });

    test('should save and retrieve Google Search enabled state - true',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchEnabled(true);
      final Either<Exception, bool> getResult =
          await repository.getGoogleSearchEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => false), true);
    });

    test('should handle empty Google Search key', () async {
      const String emptyKey = '';

      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchKey(emptyKey);
      final Either<Exception, String?> getResult =
          await repository.getGoogleSearchKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), isNull);
    });

    test('should handle empty Google Search Engine ID', () async {
      const String emptyId = '';

      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchEngineId(emptyId);
      final Either<Exception, String?> getResult =
          await repository.getGoogleSearchEngineId();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), isNull);
    });
  });

  group('OpenWeather Settings', () {
    test('should save and retrieve OpenWeather key', () async {
      const String testKey = 'test-openweather-key-abcde';

      final Either<Exception, void> saveResult =
          await repository.setOpenWeatherKey(testKey);
      final Either<Exception, String?> getResult =
          await repository.getOpenWeatherKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), testKey);
    });

    test('should save and retrieve OpenWeather enabled state - false',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setOpenWeatherEnabled(false);
      final Either<Exception, bool> getResult =
          await repository.getOpenWeatherEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => true), false);
    });

    test('should save and retrieve OpenWeather enabled state - true',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setOpenWeatherEnabled(true);
      final Either<Exception, bool> getResult =
          await repository.getOpenWeatherEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => false), true);
    });

    test('should handle empty OpenWeather key', () async {
      const String emptyKey = '';

      final Either<Exception, void> saveResult =
          await repository.setOpenWeatherKey(emptyKey);
      final Either<Exception, String?> getResult =
          await repository.getOpenWeatherKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), isNull);
    });
  });

  group('New York Times Settings', () {
    test('should save and retrieve New York Times key', () async {
      const String testKey = 'test-nyt-key-xyz123';

      final Either<Exception, void> saveResult =
          await repository.setNewYorkTimesKey(testKey);
      final Either<Exception, String?> getResult =
          await repository.getNewYorkTimesKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), testKey);
    });

    test('should save and retrieve New York Times enabled state - false',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setNewYorkTimesEnabled(false);
      final Either<Exception, bool> getResult =
          await repository.getNewYorkTimesEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => true), false);
    });

    test('should save and retrieve New York Times enabled state - true',
        () async {
      final Either<Exception, void> saveResult =
          await repository.setNewYorkTimesEnabled(true);
      final Either<Exception, bool> getResult =
          await repository.getNewYorkTimesEnabled();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => false), true);
    });

    test('should handle empty New York Times key', () async {
      const String emptyKey = '';

      final Either<Exception, void> saveResult =
          await repository.setNewYorkTimesKey(emptyKey);
      final Either<Exception, String?> getResult =
          await repository.getNewYorkTimesKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), isNull);
    });
  });

  group('Integration tests - multiple settings', () {
    test('should save and retrieve all Google Search settings together',
        () async {
      const String googleKey = 'google-key-123';
      const String googleEngineId = 'engine-id-456';
      const bool googleEnabled = false;

      await repository.setGoogleSearchKey(googleKey);
      await repository.setGoogleSearchEngineId(googleEngineId);
      await repository.setGoogleSearchEnabled(googleEnabled);

      final Either<Exception, String?> keyResult =
          await repository.getGoogleSearchKey();
      final Either<Exception, String?> idResult =
          await repository.getGoogleSearchEngineId();
      final Either<Exception, bool> enabledResult =
          await repository.getGoogleSearchEnabled();

      expect(keyResult.getOrElse((_) => null), googleKey);
      expect(idResult.getOrElse((_) => null), googleEngineId);
      expect(enabledResult.getOrElse((_) => true), googleEnabled);
    });

    test('should save and retrieve all OpenWeather settings together',
        () async {
      const String openWeatherKey = 'openweather-key-789';
      const bool openWeatherEnabled = false;

      await repository.setOpenWeatherKey(openWeatherKey);
      await repository.setOpenWeatherEnabled(openWeatherEnabled);

      final Either<Exception, String?> keyResult =
          await repository.getOpenWeatherKey();
      final Either<Exception, bool> enabledResult =
          await repository.getOpenWeatherEnabled();

      expect(keyResult.getOrElse((_) => null), openWeatherKey);
      expect(enabledResult.getOrElse((_) => true), openWeatherEnabled);
    });

    test('should save and retrieve all New York Times settings together',
        () async {
      const String nytKey = 'nyt-key-012';
      const bool nytEnabled = false;

      await repository.setNewYorkTimesKey(nytKey);
      await repository.setNewYorkTimesEnabled(nytEnabled);

      final Either<Exception, String?> keyResult =
          await repository.getNewYorkTimesKey();
      final Either<Exception, bool> enabledResult =
          await repository.getNewYorkTimesEnabled();

      expect(keyResult.getOrElse((_) => null), nytKey);
      expect(enabledResult.getOrElse((_) => true), nytEnabled);
    });

    test('should handle all function calling settings independently',
        () async {
      // Set all settings
      await repository.setGoogleSearchKey('google-key');
      await repository.setGoogleSearchEngineId('google-engine');
      await repository.setGoogleSearchEnabled(false);
      await repository.setOpenWeatherKey('openweather-key');
      await repository.setOpenWeatherEnabled(true);
      await repository.setNewYorkTimesKey('nyt-key');
      await repository.setNewYorkTimesEnabled(false);

      // Verify all settings
      expect(
          (await repository.getGoogleSearchKey()).getOrElse((_) => null),
          'google-key');
      expect(
          (await repository.getGoogleSearchEngineId())
              .getOrElse((_) => null),
          'google-engine');
      expect(
          (await repository.getGoogleSearchEnabled()).getOrElse((_) => true),
          false);
      expect(
          (await repository.getOpenWeatherKey()).getOrElse((_) => null),
          'openweather-key');
      expect(
          (await repository.getOpenWeatherEnabled()).getOrElse((_) => false),
          true);
      expect(
          (await repository.getNewYorkTimesKey()).getOrElse((_) => null),
          'nyt-key');
      expect(
          (await repository.getNewYorkTimesEnabled()).getOrElse((_) => true),
          false);
    });
  });

  group('Default values', () {
    test('Google Search enabled should default to true', () async {
      // Clear any existing value by setting to empty
      await repository.setGoogleSearchKey('');
      await repository.setGoogleSearchEngineId('');

      // Get the values (should be null for empty strings)
      final Either<Exception, String?> keyResult =
          await repository.getGoogleSearchKey();
      final Either<Exception, String?> idResult =
          await repository.getGoogleSearchEngineId();

      expect(keyResult.getOrElse((_) => 'not-null'), isNull);
      expect(idResult.getOrElse((_) => 'not-null'), isNull);
    });

    test('OpenWeather enabled should default to true', () async {
      // Clear any existing value
      await repository.setOpenWeatherKey('');

      // Get the value (should be null for empty string)
      final Either<Exception, String?> keyResult =
          await repository.getOpenWeatherKey();

      expect(keyResult.getOrElse((_) => 'not-null'), isNull);
    });

    test('New York Times enabled should default to true', () async {
      // Clear any existing value
      await repository.setNewYorkTimesKey('');

      // Get the value (should be null for empty string)
      final Either<Exception, String?> keyResult =
          await repository.getNewYorkTimesKey();

      expect(keyResult.getOrElse((_) => 'not-null'), isNull);
    });
  });

  group('Special characters and edge cases', () {
    test('should handle special characters in Google Search key', () async {
      const String specialKey = 'key-with-special-chars-!@#\$%^&*()';

      final Either<Exception, void> saveResult =
          await repository.setGoogleSearchKey(specialKey);
      final Either<Exception, String?> getResult =
          await repository.getGoogleSearchKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), specialKey);
    });

    test('should handle long keys for OpenWeather', () async {
      final String longKey = 'a' * 500; // Very long key

      final Either<Exception, void> saveResult =
          await repository.setOpenWeatherKey(longKey);
      final Either<Exception, String?> getResult =
          await repository.getOpenWeatherKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), longKey);
    });

    test('should handle unicode characters in NYT key', () async {
      const String unicodeKey = 'key-with-unicode-🔑-🗽';

      final Either<Exception, void> saveResult =
          await repository.setNewYorkTimesKey(unicodeKey);
      final Either<Exception, String?> getResult =
          await repository.getNewYorkTimesKey();

      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse((_) => null), unicodeKey);
    });

    test('should handle rapid updates to same setting', () async {
      // Rapidly update the same setting multiple times
      for (int i = 0; i < 10; i++) {
        final Either<Exception, void> result =
            await repository.setGoogleSearchEnabled(i % 2 == 0);
        expect(result.isRight(), true);
      }

      // Final value should be false (10th iteration, i=9, 9%2=1, so false)
      final Either<Exception, bool> result =
          await repository.getGoogleSearchEnabled();
      expect(result.getOrElse((_) => true), false);
    });
  });
}
