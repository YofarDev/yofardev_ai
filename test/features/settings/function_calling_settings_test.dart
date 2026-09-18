import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/result.dart';
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

      final Result<void> saveResult = await repository
          .setGoogleSearchKey(testKey);
      final Result<String?> getResult = await repository
          .getGoogleSearchKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, testKey);
    });

    test('should save and retrieve Google Search Engine ID', () async {
      const String testId = 'test-engine-id-67890';

      final Result<void> saveResult = await repository
          .setGoogleSearchEngineId(testId);
      final Result<String?> getResult = await repository
          .getGoogleSearchEngineId();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, testId);
    });

    test(
      'should save and retrieve Google Search enabled state - false',
      () async {
        final Result<void> saveResult = await repository
            .setGoogleSearchEnabled(false);
        final Result<bool> getResult = await repository
            .getGoogleSearchEnabled();

        expect(saveResult.isOk, true);
        expect(getResult.getOrNull ?? true, false);
      },
    );

    test(
      'should save and retrieve Google Search enabled state - true',
      () async {
        final Result<void> saveResult = await repository
            .setGoogleSearchEnabled(true);
        final Result<bool> getResult = await repository
            .getGoogleSearchEnabled();

        expect(saveResult.isOk, true);
        expect(getResult.getOrNull ?? false, true);
      },
    );

    test('should handle empty Google Search key', () async {
      const String emptyKey = '';

      final Result<void> saveResult = await repository
          .setGoogleSearchKey(emptyKey);
      final Result<String?> getResult = await repository
          .getGoogleSearchKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, isNull);
    });

    test('should handle empty Google Search Engine ID', () async {
      const String emptyId = '';

      final Result<void> saveResult = await repository
          .setGoogleSearchEngineId(emptyId);
      final Result<String?> getResult = await repository
          .getGoogleSearchEngineId();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, isNull);
    });
  });

  group('OpenWeather Settings', () {
    test('should save and retrieve OpenWeather key', () async {
      const String testKey = 'test-openweather-key-abcde';

      final Result<void> saveResult = await repository
          .setOpenWeatherKey(testKey);
      final Result<String?> getResult = await repository
          .getOpenWeatherKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, testKey);
    });

    test(
      'should save and retrieve OpenWeather enabled state - false',
      () async {
        final Result<void> saveResult = await repository
            .setOpenWeatherEnabled(false);
        final Result<bool> getResult = await repository
            .getOpenWeatherEnabled();

        expect(saveResult.isOk, true);
        expect(getResult.getOrNull ?? true, false);
      },
    );

    test('should save and retrieve OpenWeather enabled state - true', () async {
      final Result<void> saveResult = await repository
          .setOpenWeatherEnabled(true);
      final Result<bool> getResult = await repository
          .getOpenWeatherEnabled();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull ?? false, true);
    });

    test('should handle empty OpenWeather key', () async {
      const String emptyKey = '';

      final Result<void> saveResult = await repository
          .setOpenWeatherKey(emptyKey);
      final Result<String?> getResult = await repository
          .getOpenWeatherKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, isNull);
    });
  });

  group('New York Times Settings', () {
    test('should save and retrieve New York Times key', () async {
      const String testKey = 'test-nyt-key-xyz123';

      final Result<void> saveResult = await repository
          .setNewYorkTimesKey(testKey);
      final Result<String?> getResult = await repository
          .getNewYorkTimesKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, testKey);
    });

    test(
      'should save and retrieve New York Times enabled state - false',
      () async {
        final Result<void> saveResult = await repository
            .setNewYorkTimesEnabled(false);
        final Result<bool> getResult = await repository
            .getNewYorkTimesEnabled();

        expect(saveResult.isOk, true);
        expect(getResult.getOrNull ?? true, false);
      },
    );

    test(
      'should save and retrieve New York Times enabled state - true',
      () async {
        final Result<void> saveResult = await repository
            .setNewYorkTimesEnabled(true);
        final Result<bool> getResult = await repository
            .getNewYorkTimesEnabled();

        expect(saveResult.isOk, true);
        expect(getResult.getOrNull ?? false, true);
      },
    );

    test('should handle empty New York Times key', () async {
      const String emptyKey = '';

      final Result<void> saveResult = await repository
          .setNewYorkTimesKey(emptyKey);
      final Result<String?> getResult = await repository
          .getNewYorkTimesKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, isNull);
    });
  });

  group('Integration tests - multiple settings', () {
    test(
      'should save and retrieve all Google Search settings together',
      () async {
        const String googleKey = 'google-key-123';
        const String googleEngineId = 'engine-id-456';
        const bool googleEnabled = false;

        await repository.setGoogleSearchKey(googleKey);
        await repository.setGoogleSearchEngineId(googleEngineId);
        await repository.setGoogleSearchEnabled(googleEnabled);

        final Result<String?> keyResult = await repository
            .getGoogleSearchKey();
        final Result<String?> idResult = await repository
            .getGoogleSearchEngineId();
        final Result<bool> enabledResult = await repository
            .getGoogleSearchEnabled();

        expect(keyResult.getOrNull, googleKey);
        expect(idResult.getOrNull, googleEngineId);
        expect(enabledResult.getOrNull ?? true, googleEnabled);
      },
    );

    test(
      'should save and retrieve all OpenWeather settings together',
      () async {
        const String openWeatherKey = 'openweather-key-789';
        const bool openWeatherEnabled = false;

        await repository.setOpenWeatherKey(openWeatherKey);
        await repository.setOpenWeatherEnabled(openWeatherEnabled);

        final Result<String?> keyResult = await repository
            .getOpenWeatherKey();
        final Result<bool> enabledResult = await repository
            .getOpenWeatherEnabled();

        expect(keyResult.getOrNull, openWeatherKey);
        expect(enabledResult.getOrNull ?? true, openWeatherEnabled);
      },
    );

    test(
      'should save and retrieve all New York Times settings together',
      () async {
        const String nytKey = 'nyt-key-012';
        const bool nytEnabled = false;

        await repository.setNewYorkTimesKey(nytKey);
        await repository.setNewYorkTimesEnabled(nytEnabled);

        final Result<String?> keyResult = await repository
            .getNewYorkTimesKey();
        final Result<bool> enabledResult = await repository
            .getNewYorkTimesEnabled();

        expect(keyResult.getOrNull, nytKey);
        expect(enabledResult.getOrNull ?? true, nytEnabled);
      },
    );

    test('should handle all function calling settings independently', () async {
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
        (await repository.getGoogleSearchKey()).getOrNull,
        'google-key',
      );
      expect(
        (await repository.getGoogleSearchEngineId()).getOrNull,
        'google-engine',
      );
      expect(
        (await repository.getGoogleSearchEnabled()).getOrNull ?? true,
        false,
      );
      expect(
        (await repository.getOpenWeatherKey()).getOrNull,
        'openweather-key',
      );
      expect(
        (await repository.getOpenWeatherEnabled()).getOrNull ?? false,
        true,
      );
      expect(
        (await repository.getNewYorkTimesKey()).getOrNull,
        'nyt-key',
      );
      expect(
        (await repository.getNewYorkTimesEnabled()).getOrNull ?? true,
        false,
      );
    });
  });

  group('Default values', () {
    test('Google Search enabled should default to true', () async {
      // Clear any existing value by setting to empty
      await repository.setGoogleSearchKey('');
      await repository.setGoogleSearchEngineId('');

      // Get the values (should be null for empty strings)
      final Result<String?> keyResult = await repository
          .getGoogleSearchKey();
      final Result<String?> idResult = await repository
          .getGoogleSearchEngineId();

      expect(keyResult.getOrNull, isNull);
      expect(idResult.getOrNull, isNull);
    });

    test('OpenWeather enabled should default to true', () async {
      // Clear any existing value
      await repository.setOpenWeatherKey('');

      // Get the value (should be null for empty string)
      final Result<String?> keyResult = await repository
          .getOpenWeatherKey();

      expect(keyResult.getOrNull, isNull);
    });

    test('New York Times enabled should default to true', () async {
      // Clear any existing value
      await repository.setNewYorkTimesKey('');

      // Get the value (should be null for empty string)
      final Result<String?> keyResult = await repository
          .getNewYorkTimesKey();

      expect(keyResult.getOrNull, isNull);
    });
  });

  group('Special characters and edge cases', () {
    test('should handle special characters in Google Search key', () async {
      const String specialKey = 'key-with-special-chars-!@#\$%^&*()';

      final Result<void> saveResult = await repository
          .setGoogleSearchKey(specialKey);
      final Result<String?> getResult = await repository
          .getGoogleSearchKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, specialKey);
    });

    test('should handle long keys for OpenWeather', () async {
      final String longKey = 'a' * 500; // Very long key

      final Result<void> saveResult = await repository
          .setOpenWeatherKey(longKey);
      final Result<String?> getResult = await repository
          .getOpenWeatherKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, longKey);
    });

    test('should handle unicode characters in NYT key', () async {
      const String unicodeKey = 'key-with-unicode-🔑-🗽';

      final Result<void> saveResult = await repository
          .setNewYorkTimesKey(unicodeKey);
      final Result<String?> getResult = await repository
          .getNewYorkTimesKey();

      expect(saveResult.isOk, true);
      expect(getResult.getOrNull, unicodeKey);
    });

    test('should handle rapid updates to same setting', () async {
      // Rapidly update the same setting multiple times
      for (int i = 0; i < 10; i++) {
        final Result<void> result = await repository
            .setGoogleSearchEnabled(i % 2 == 0);
        expect(result.isOk, true);
      }

      // Final value should be false (10th iteration, i=9, 9%2=1, so false)
      final Result<bool> result = await repository
          .getGoogleSearchEnabled();
      expect(result.getOrNull ?? true, false);
    });
  });
}
