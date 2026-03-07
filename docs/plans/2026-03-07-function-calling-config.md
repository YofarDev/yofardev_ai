# Function Calling Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move function calling API keys from .env file to in-app settings with user-configurable enable/disable toggles, so functions only appear in LLM requests when properly configured and enabled.

**Architecture:** Add new fields to SettingsState (3 services × 3 fields each), create FunctionCallingConfigScreen for UI, refactor services to accept keys as method parameters, and update function calling integration to conditionally include functions based on key presence + enable toggle.

**Tech Stack:** Flutter, freezed (immutable state), flutter_bloc (Cubit), get_it (DI), SharedPreferences (storage), flutter_test (testing)

---

## Task 1: Add New Fields to SettingsState

**Files:**
- Modify: `lib/features/settings/presentation/bloc/settings_state.dart`

**Step 1: Add new fields to SettingsState**

```dart
@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    // Existing fields...
    @Default(null) TaskLlmConfig? taskLlmConfig,
    @Default(<LlmConfig>[]) List<LlmConfig> availableLlmConfigs,

    // NEW: Function Calling keys and toggles
    @Default(null) String? googleSearchKey,
    @Default(null) String? googleSearchEngineId,
    @Default(true) bool googleSearchEnabled,

    @Default(null) String? openWeatherKey,
    @Default(true) bool openWeatherEnabled,

    @Default(null) String? newYorkTimesKey,
    @Default(true) bool newYorkTimesEnabled,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState();
}
```

**Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `settings_state.freezed.dart` regenerated successfully

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/settings/presentation/bloc/settings_state.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/settings/presentation/bloc/settings_state.dart
git commit -m "feat: add function calling fields to SettingsState"
```

---

## Task 2: Update SettingsRepository Interface

**Files:**
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`

**Step 1: Add new methods to interface**

```dart
// Google Search
Future<Either<Exception, String?>> getGoogleSearchKey();
Future<Either<Exception, void>> setGoogleSearchKey(String key);
Future<Either<Exception, String?>> getGoogleSearchEngineId();
Future<Either<Exception, void>> setGoogleSearchEngineId(String id);
Future<Either<Exception, bool>> getGoogleSearchEnabled();
Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled);

// OpenWeather
Future<Either<Exception, String?>> getOpenWeatherKey();
Future<Either<Exception, void>> setOpenWeatherKey(String key);
Future<Either<Exception, bool>> getOpenWeatherEnabled();
Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled);

// New York Times
Future<Either<Exception, String?>> getNewYorkTimesKey();
Future<Either<Exception, void>> setNewYorkTimesKey(String key);
Future<Either<Exception, bool>> getNewYorkTimesEnabled();
Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled);
```

**Step 2: Verify compilation**

Run: `flutter analyze lib/features/settings/domain/repositories/settings_repository.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/settings/domain/repositories/settings_repository.dart
git commit -m "feat: add function calling methods to SettingsRepository interface"
```

---

## Task 3: Update SettingsLocalDatasource

**Files:**
- Modify: `lib/core/services/settings_local_datasource.dart`

**Step 1: Add SharedPreferences keys**

Add at the top of the class:

```dart
static const String _googleSearchKeyKey = 'google_search_key';
static const String _googleSearchEngineIdKey = 'google_search_engine_id';
static const String _googleSearchEnabledKey = 'google_search_enabled';
static const String _openWeatherKeyKey = 'open_weather_key';
static const String _openWeatherEnabledKey = 'open_weather_enabled';
static const String _newYorkTimesKeyKey = 'new_york_times_key';
static const String _newYorkTimesEnabledKey = 'new_york_times_enabled';
```

**Step 2: Add getter/setter methods**

```dart
// Google Search
Future<dartz.Either<Exception, String>> getGoogleSearchKey() async {
  try {
    final String key = _prefs.getString(_googleSearchKeyKey) ?? '';
    return dartz.Right<Exception, String>(key);
  } catch (e) {
    return dartz.Left<Exception, String>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setGoogleSearchKey(String key) async {
  try {
    await _prefs.setString(_googleSearchKeyKey, key);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, String>> getGoogleSearchEngineId() async {
  try {
    final String id = _prefs.getString(_googleSearchEngineIdKey) ?? '';
    return dartz.Right<Exception, String>(id);
  } catch (e) {
    return dartz.Left<Exception, String>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setGoogleSearchEngineId(String id) async {
  try {
    await _prefs.setString(_googleSearchEngineIdKey, id);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, bool>> getGoogleSearchEnabled() async {
  try {
    final bool enabled = _prefs.getBool(_googleSearchEnabledKey) ?? true;
    return dartz.Right<Exception, bool>(enabled);
  } catch (e) {
    return dartz.Left<Exception, bool>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
  try {
    await _prefs.setBool(_googleSearchEnabledKey, enabled);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

// OpenWeather
Future<dartz.Either<Exception, String>> getOpenWeatherKey() async {
  try {
    final String key = _prefs.getString(_openWeatherKeyKey) ?? '';
    return dartz.Right<Exception, String>(key);
  } catch (e) {
    return dartz.Left<Exception, String>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setOpenWeatherKey(String key) async {
  try {
    await _prefs.setString(_openWeatherKeyKey, key);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, bool>> getOpenWeatherEnabled() async {
  try {
    final bool enabled = _prefs.getBool(_openWeatherEnabledKey) ?? true;
    return dartz.Right<Exception, bool>(enabled);
  } catch (e) {
    return dartz.Left<Exception, bool>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
  try {
    await _prefs.setBool(_openWeatherEnabledKey, enabled);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

// New York Times
Future<dartz.Either<Exception, String>> getNewYorkTimesKey() async {
  try {
    final String key = _prefs.getString(_newYorkTimesKeyKey) ?? '';
    return dartz.Right<Exception, String>(key);
  } catch (e) {
    return dartz.Left<Exception, String>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setNewYorkTimesKey(String key) async {
  try {
    await _prefs.setString(_newYorkTimesKeyKey, key);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, bool>> getNewYorkTimesEnabled() async {
  try {
    final bool enabled = _prefs.getBool(_newYorkTimesEnabledKey) ?? true;
    return dartz.Right<Exception, bool>(enabled);
  } catch (e) {
    return dartz.Left<Exception, bool>(Exception(e.toString()));
  }
}

Future<dartz.Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
  try {
    await _prefs.setBool(_newYorkTimesEnabledKey, enabled);
    return const dartz.Right<Exception, void>(null);
  } catch (e) {
    return dartz.Left<Exception, void>(Exception(e.toString()));
  }
}
```

**Step 3: Verify compilation**

Run: `flutter analyze lib/core/services/settings_local_datasource.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/services/settings_local_datasource.dart
git commit -m "feat: add function calling storage to SettingsLocalDatasource"
```

---

## Task 4: Update SettingsRepositoryImpl

**Files:**
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Step 1: Implement new methods**

Add at the end of the class (before closing brace):

```dart
@override
Future<Either<Exception, String?>> getGoogleSearchKey() async {
  final dartz.Either<Exception, String> result = await _datasource.getGoogleSearchKey();
  return result.fold(
    (Exception left) => Left<Exception, String?>(left),
    (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
  );
}

@override
Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
  final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchKey(key);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, String?>> getGoogleSearchEngineId() async {
  final dartz.Either<Exception, String> result = await _datasource.getGoogleSearchEngineId();
  return result.fold(
    (Exception left) => Left<Exception, String?>(left),
    (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
  );
}

@override
Future<Either<Exception, void>> setGoogleSearchEngineId(String id) async {
  final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchEngineId(id);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
  final dartz.Either<Exception, bool> result = await _datasource.getGoogleSearchEnabled();
  return result.fold(
    (Exception left) => Left<Exception, bool>(left),
    (bool right) => Right<Exception, bool>(right),
  );
}

@override
Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
  final dartz.Either<Exception, void> result = await _datasource.setGoogleSearchEnabled(enabled);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, String?>> getOpenWeatherKey() async {
  final dartz.Either<Exception, String> result = await _datasource.getOpenWeatherKey();
  return result.fold(
    (Exception left) => Left<Exception, String?>(left),
    (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
  );
}

@override
Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
  final dartz.Either<Exception, void> result = await _datasource.setOpenWeatherKey(key);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
  final dartz.Either<Exception, bool> result = await _datasource.getOpenWeatherEnabled();
  return result.fold(
    (Exception left) => Left<Exception, bool>(left),
    (bool right) => Right<Exception, bool>(right),
  );
}

@override
Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
  final dartz.Either<Exception, void> result = await _datasource.setOpenWeatherEnabled(enabled);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, String?>> getNewYorkTimesKey() async {
  final dartz.Either<Exception, String> result = await _datasource.getNewYorkTimesKey();
  return result.fold(
    (Exception left) => Left<Exception, String?>(left),
    (String right) => Right<Exception, String?>(right.isEmpty ? null : right),
  );
}

@override
Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
  final dartz.Either<Exception, void> result = await _datasource.setNewYorkTimesKey(key);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}

@override
Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
  final dartz.Either<Exception, bool> result = await _datasource.getNewYorkTimesEnabled();
  return result.fold(
    (Exception left) => Left<Exception, bool>(left),
    (bool right) => Right<Exception, bool>(right),
  );
}

@override
Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
  final dartz.Either<Exception, void> result = await _datasource.setNewYorkTimesEnabled(enabled);
  return result.fold(
    (Exception left) => Left<Exception, void>(left),
    (void right) => const Right<Exception, void>(null),
  );
}
```

**Step 2: Verify compilation**

Run: `flutter analyze lib/features/settings/data/repositories/settings_repository_impl.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/settings/data/repositories/settings_repository_impl.dart
git commit -m "feat: implement function calling methods in SettingsRepositoryImpl"
```

---

## Task 5: Update SettingsCubit

**Files:**
- Modify: `lib/features/settings/presentation/bloc/settings_cubit.dart`

**Step 1: Add new methods to SettingsCubit**

```dart
// Google Search
Future<void> loadGoogleSearchConfig() async {
  final Either<Exception, String?> keyResult = await _repository.getGoogleSearchKey();
  final Either<Exception, String?> idResult = await _repository.getGoogleSearchEngineId();
  final Either<Exception, bool> enabledResult = await _repository.getGoogleSearchEnabled();

  final String? key = keyResult.getOrElse(() => null);
  final String? id = idResult.getOrElse(() => null);
  final bool enabled = enabledResult.getOrElse(() => true);

  state = state.copyWith(
    googleSearchKey: key,
    googleSearchEngineId: id,
    googleSearchEnabled: enabled,
  );
}

Future<void> updateGoogleSearchKey(String key) async {
  final Either<Exception, void> result = await _repository.setGoogleSearchKey(key);
  result.fold(
    (Exception error) => AppLogger.error('Failed to save Google Search key: $error'),
    (void _) => state = state.copyWith(googleSearchKey: key),
  );
}

Future<void> updateGoogleSearchEngineId(String id) async {
  final Either<Exception, void> result = await _repository.setGoogleSearchEngineId(id);
  result.fold(
    (Exception error) => AppLogger.error('Failed to save Google Search Engine ID: $error'),
    (void _) => state = state.copyWith(googleSearchEngineId: id),
  );
}

Future<void> toggleGoogleSearch(bool enabled) async {
  final Either<Exception, void> result = await _repository.setGoogleSearchEnabled(enabled);
  result.fold(
    (Exception error) => AppLogger.error('Failed to toggle Google Search: $error'),
    (void _) => state = state.copyWith(googleSearchEnabled: enabled),
  );
}

// OpenWeather
Future<void> loadOpenWeatherConfig() async {
  final Either<Exception, String?> keyResult = await _repository.getOpenWeatherKey();
  final Either<Exception, bool> enabledResult = await _repository.getOpenWeatherEnabled();

  final String? key = keyResult.getOrElse(() => null);
  final bool enabled = enabledResult.getOrElse(() => true);

  state = state.copyWith(
    openWeatherKey: key,
    openWeatherEnabled: enabled,
  );
}

Future<void> updateOpenWeatherKey(String key) async {
  final Either<Exception, void> result = await _repository.setOpenWeatherKey(key);
  result.fold(
    (Exception error) => AppLogger.error('Failed to save OpenWeather key: $error'),
    (void _) => state = state.copyWith(openWeatherKey: key),
  );
}

Future<void> toggleOpenWeather(bool enabled) async {
  final Either<Exception, void> result = await _repository.setOpenWeatherEnabled(enabled);
  result.fold(
    (Exception error) => AppLogger.error('Failed to toggle OpenWeather: $error'),
    (void _) => state = state.copyWith(openWeatherEnabled: enabled),
  );
}

// New York Times
Future<void> loadNewYorkTimesConfig() async {
  final Either<Exception, String?> keyResult = await _repository.getNewYorkTimesKey();
  final Either<Exception, bool> enabledResult = await _repository.getNewYorkTimesEnabled();

  final String? key = keyResult.getOrElse(() => null);
  final bool enabled = enabledResult.getOrElse(() => true);

  state = state.copyWith(
    newYorkTimesKey: key,
    newYorkTimesEnabled: enabled,
  );
}

Future<void> updateNewYorkTimesKey(String key) async {
  final Either<Exception, void> result = await _repository.setNewYorkTimesKey(key);
  result.fold(
    (Exception error) => AppLogger.error('Failed to save New York Times key: $error'),
    (void _) => state = state.copyWith(newYorkTimesKey: key),
  );
}

Future<void> toggleNewYorkTimes(bool enabled) async {
  final Either<Exception, void> result = await _repository.setNewYorkTimesEnabled(enabled);
  result.fold(
    (Exception error) => AppLogger.error('Failed to toggle New York Times: $error'),
    (void _) => state = state.copyWith(newYorkTimesEnabled: enabled),
  );
}

// Load all function calling configs at once
Future<void> loadFunctionCallingConfigs() async {
  await loadGoogleSearchConfig();
  await loadOpenWeatherConfig();
  await loadNewYorkTimesConfig();
}
```

**Step 2: Update init or load method**

If there's an `init()` or `loadSettings()` method, add a call to `loadFunctionCallingConfigs()`.

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/settings/presentation/bloc/settings_cubit.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/settings/presentation/bloc/settings_cubit.dart
git commit -m "feat: add function calling state management to SettingsCubit"
```

---

## Task 6: Refactor GoogleSearchService

**Files:**
- Modify: `lib/core/services/agent/google_search_service.dart`

**Step 1: Remove dotenv import**

Remove this line:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

**Step 2: Update searchGoogle method signature**

Change from:
```dart
static Future<List<Map<String, dynamic>>> searchGoogle(String query) async {
```

To:
```dart
static Future<List<Map<String, dynamic>>> searchGoogle(
  String query,
  String apiKey,
  String engineId,
) async {
```

**Step 3: Update method implementation**

Change from:
```dart
final String apiKey = dotenv.env['GOOGLE_SEARCH_KEY'] ?? '';
final String engineId = dotenv.env['GOOGLE_SEARCH_ENGINE_ID'] ?? '';
if (apiKey.isEmpty || engineId.isEmpty) {
  throw Exception(
    'API Key or Engine ID is not set in environment variables',
  );
}
```

To:
```dart
if (apiKey.isEmpty || engineId.isEmpty) {
  throw Exception(
    'API Key or Engine ID is not provided',
  );
}
```

**Step 4: Verify compilation**

Run: `flutter analyze lib/core/services/agent/google_search_service.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/core/services/agent/google_search_service.dart
git commit -m "refactor: GoogleSearchService to accept API keys as parameters"
```

---

## Task 7: Refactor WeatherService

**Files:**
- Modify: `lib/core/services/agent/weather_service.dart`

**Step 1: Remove dotenv import**

Remove this line:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

**Step 2: Update getCurrentWeather method signature**

Change from:
```dart
static Future<String> getCurrentWeather(String location) async {
```

To:
```dart
static Future<String> getCurrentWeather(
  String location,
  String apiKey,
) async {
```

**Step 3: Update method implementation**

Change from:
```dart
final String apiKey = dotenv.env['OPEN_WEATHER_KEY'] ?? '';
```

To:
```dart
if (apiKey.isEmpty) {
  return "Error: API Key not provided";
}
```

**Step 4: Verify compilation**

Run: `flutter analyze lib/core/services/agent/weather_service.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/core/services/agent/weather_service.dart
git commit -m "refactor: WeatherService to accept API key as parameter"
```

---

## Task 8: Refactor NewsService

**Files:**
- Modify: `lib/core/services/agent/news_service.dart`

**Step 1: Remove dotenv import**

Remove this line:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

**Step 2: Update getMostPopularNewsOfTheDay method signature**

Change from:
```dart
static Future<String> getMostPopularNewsOfTheDay() async {
```

To:
```dart
static Future<String> getMostPopularNewsOfTheDay(
  String apiKey,
) async {
```

**Step 3: Update method implementation**

Change from:
```dart
final String apiKey = dotenv.env['NEWYORKTIMES_KEY'] ?? '';
```

To:
```dart
if (apiKey.isEmpty) {
  return "Error: API Key not provided";
}
```

**Step 4: Verify compilation**

Run: `flutter analyze lib/core/services/agent/news_service.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/core/services/agent/news_service.dart
git commit -m "refactor: NewsService to accept API key as parameter"
```

---

## Task 9: Remove .env Dependency from main.dart

**Files:**
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`

**Step 1: Remove dotenv import from main.dart**

Remove this line:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

**Step 2: Remove dotenv.load() call**

Remove or comment out these lines:
```dart
if (PlatformUtils.checkPlatform() != 'Web') {
  await dotenv.load();
  await TtsDatasource.initSupertonic();
}
```

Change to:
```dart
if (PlatformUtils.checkPlatform() != 'Web') {
  await TtsDatasource.initSupertonic();
}
```

**Step 3: Remove flutter_dotenv from pubspec.yaml**

Find and remove:
```yaml
flutter_dotenv: ^version
```

**Step 4: Run pub get**

Run: `flutter pub get`
Expected: Package removed successfully

**Step 5: Verify compilation**

Run: `flutter analyze lib/main.dart`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/main.dart pubspec.yaml pubspec.lock
git commit -m "refactor: remove .env file dependency"
```

---

## Task 10: Add Localization Keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_fr.arb`

**Step 1: Add English translations to app_en.arb**

```json
{
  "settings": "Settings",

  "settings_functionCalling": "Function Calling",
  "settings_functionCalling_description": "Configure API keys for function calling features",
  "settings_functionCalling_saved": "Configuration saved",

  "settings_googleSearch": "Google Search",
  "settings_googleSearch_description": "Search the web for current information",
  "settings_apiKey": "API Key",
  "settings_engineId": "Search Engine ID",

  "settings_weather": "Weather",
  "settings_weather_description": "Get current weather for any location",

  "settings_news": "News",
  "settings_news_description": "Get today's most popular news",

  "settings_enable": "Enable",
  "settings_save": "Save"
}
```

**Step 2: Add French translations to app_fr.arb**

```json
{
  "settings": "Paramètres",

  "settings_functionCalling": "Appel de Fonctions",
  "settings_functionCalling_description": "Configurez les clés API pour les fonctionnalités d'appel de fonctions",
  "settings_functionCalling_saved": "Configuration enregistrée",

  "settings_googleSearch": "Recherche Google",
  "settings_googleSearch_description": "Rechercher sur le web pour des informations actuelles",
  "settings_apiKey": "Clé API",
  "settings_engineId": "ID de Moteur de Recherche",

  "settings_weather": "Météo",
  "settings_weather_description": "Obtenir la météo actuelle pour n'importe quel lieu",

  "settings_news": "Actualités",
  "settings_news_description": "Obtenir les actualités les plus populaires du jour",

  "settings_enable": "Activer",
  "settings_save": "Enregistrer"
}
```

**Step 3: Verify localization**

Run: `flutter gen-l10n`
Expected: Localization files generated successfully

**Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: add localization keys for function calling settings"
```

---

## Task 11: Create Function Calling Config Screen

**Files:**
- Create: `lib/features/settings/screens/function_calling_config_screen.dart`
- Create: `lib/features/settings/widgets/function_calling_section.dart`

**Step 1: Create reusable FunctionCallingSection widget**

Create `lib/features/settings/widgets/function_calling_section.dart`:

```dart
import 'package:flutter/material.dart';

class FunctionCallingSection extends StatelessWidget {
  final String title;
  final String description;
  final String icon;
  final List<Widget> fields;

  const FunctionCallingSection({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...fields,
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Create FunctionCallingConfigScreen**

Create `lib/features/settings/screens/function_calling_config_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../settings/presentation/bloc/settings_cubit.dart';
import '../../settings/widgets/function_calling_section.dart';
import '../../settings/widgets/api_key_field.dart';

class FunctionCallingConfigScreen extends StatelessWidget {
  const FunctionCallingConfigScreen({super.key});

  static const String route = '/settings/function-calling';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Function Calling Configuration'),
      ),
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (BuildContext context, SettingsState state) {
          // Show success message when config is saved
        },
        builder: (BuildContext context, SettingsState state) {
          return ListView(
            children: <Widget>[
              FunctionCallingSection(
                title: 'Google Search',
                description: 'Search the web for current information',
                icon: '🌐',
                fields: <Widget>[
                  ApiKeyField(
                    label: 'API Key',
                    initialValue: state.googleSearchKey ?? '',
                    onChanged: (String value) {
                      context.read<SettingsCubit>().updateGoogleSearchKey(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ApiKeyField(
                    label: 'Search Engine ID',
                    initialValue: state.googleSearchEngineId ?? '',
                    onChanged: (String value) {
                      context.read<SettingsCubit>().updateGoogleSearchEngineId(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Google Search'),
                    subtitle: const Text('Allow Google Search function calls'),
                    value: state.googleSearchEnabled,
                    onChanged: (bool value) {
                      context.read<SettingsCubit>().toggleGoogleSearch(value);
                    },
                  ),
                ],
              ),
              FunctionCallingSection(
                title: 'Weather',
                description: 'Get current weather for any location',
                icon: '🌤️',
                fields: <Widget>[
                  ApiKeyField(
                    label: 'API Key',
                    initialValue: state.openWeatherKey ?? '',
                    onChanged: (String value) {
                      context.read<SettingsCubit>().updateOpenWeatherKey(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Weather'),
                    subtitle: const Text('Allow Weather function calls'),
                    value: state.openWeatherEnabled,
                    onChanged: (bool value) {
                      context.read<SettingsCubit>().toggleOpenWeather(value);
                    },
                  ),
                ],
              ),
              FunctionCallingSection(
                title: 'News',
                description: "Get today's most popular news",
                icon: '📰',
                fields: <Widget>[
                  ApiKeyField(
                    label: 'API Key',
                    initialValue: state.newYorkTimesKey ?? '',
                    onChanged: (String value) {
                      context.read<SettingsCubit>().updateNewYorkTimesKey(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable News'),
                    subtitle: const Text('Allow News function calls'),
                    value: state.newYorkTimesEnabled,
                    onChanged: (bool value) {
                      context.read<SettingsCubit>().toggleNewYorkTimes(value);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
```

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/settings/screens/function_calling_config_screen.dart lib/features/settings/widgets/function_calling_section.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/settings/screens/function_calling_config_screen.dart lib/features/settings/widgets/function_calling_section.dart
git commit -m "feat: add Function Calling Configuration screen"
```

---

## Task 12: Add Navigation to Function Calling Config

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Modify: `lib/core/router/app_router.dart` (if routing is centralized)

**Step 1: Add navigation tile in SettingsScreen**

Add to the settings list:

```dart
ListTile(
  leading: const Icon(Icons.settings_applications),
  title: const Text('Function Calling'),
  subtitle: const Text('Configure API keys for function calling'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.pushNamed(context, FunctionCallingConfigScreen.route);
  },
),
```

**Step 2: Add route to router**

If using centralized routing, add:

```dart
GoRoute(
  path: FunctionCallingConfigScreen.route,
  builder: (BuildContext context, GoRouterState state) {
    return const FunctionCallingConfigScreen();
  },
),
```

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/settings/screens/settings_screen.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/settings/screens/settings_screen.dart lib/core/router/app_router.dart
git commit -m "feat: add navigation to Function Calling Configuration"
```

---

## Task 13: Update Function Calling Integration

**Files:**
- Identify and modify files where function tools are assembled for LLM calls
- This may be in agent services, chat services, or LLM services

**Step 1: Locate function calling code**

Search for where function tools are defined/used. Look for:
- Classes or methods that build the tools list for LLM
- References to GoogleSearchService, WeatherService, NewsService
- "function calling" or "tool" or "agent" related code

**Step 2: Update to use settings-based conditional logic**

Example pattern:

```dart
// Get current settings
final SettingsState settings = settingsCubit.state;

// Build available functions list
final List<FunctionTool> availableFunctions = <FunctionTool>[];

// Google Search
if (settings.googleSearchKey != null &&
    settings.googleSearchKey!.isNotEmpty &&
    settings.googleSearchEngineId != null &&
    settings.googleSearchEngineId!.isNotEmpty &&
    settings.googleSearchEnabled) {

  availableFunctions.add(FunctionTool(
    name: 'search_google',
    description: 'Search the web for current information',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'query': <String, dynamic>{
          'type': 'string',
          'description': 'The search query',
        },
      },
      'required': <String>['query'],
    },
    handler: (Map<String, dynamic> args) async {
      final String query = args['query'] as String;
      return await GoogleSearchService.searchGoogle(
        query,
        settings.googleSearchKey!,
        settings.googleSearchEngineId!,
      );
    },
  ));
}

// Weather
if (settings.openWeatherKey != null &&
    settings.openWeatherKey!.isNotEmpty &&
    settings.openWeatherEnabled) {

  availableFunctions.add(FunctionTool(
    name: 'get_weather',
    description: 'Get current weather for a location',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'location': <String, dynamic>{
          'type': 'string',
          'description': 'The location name or "current"',
        },
      },
      'required': <String>['location'],
    },
    handler: (Map<String, dynamic> args) async {
      final String location = args['location'] as String;
      return await WeatherService.getCurrentWeather(
        location,
        settings.openWeatherKey!,
      );
    },
  ));
}

// News
if (settings.newYorkTimesKey != null &&
    settings.newYorkTimesKey!.isNotEmpty &&
    settings.newYorkTimesEnabled) {

  availableFunctions.add(FunctionTool(
    name: 'get_news',
    description: "Get today's most popular news",
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{},
    },
    handler: (Map<String, dynamic> args) async {
      return await NewsService.getMostPopularNewsOfTheDay(
        settings.newYorkTimesKey!,
      );
    },
  ));
}
```

**Step 3: Pass keys to service methods**

Ensure all service calls pass the required API key parameters from settings.

**Step 4: Verify compilation**

Run: `flutter analyze` on modified files
Expected: No errors

**Step 5: Commit**

```bash
git add <modified files>
git commit -m "feat: integrate function calling with settings-based configuration"
```

---

## Task 14: Write Unit Tests for Settings

**Files:**
- Create: `test/features/settings/function_calling_settings_test.dart`

**Step 1: Write tests for SettingsRepository**

```dart
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:yofardev_ai/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

void main() {
  late SettingsRepositoryImpl repository;
  late SettingsLocalDatasource datasource;

  setUp(() {
    datasource = SettingsLocalDatasource();
    repository = SettingsRepositoryImpl();
  });

  group('Google Search Settings', () {
    test('should save and retrieve Google Search key', () async {
      // Arrange
      const String testKey = 'test-google-key';

      // Act
      final Either<Exception, void> saveResult = await repository.setGoogleSearchKey(testKey);
      final Either<Exception, String?> getResult = await repository.getGoogleSearchKey();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => null), testKey);
    });

    test('should save and retrieve Google Search Engine ID', () async {
      // Arrange
      const String testId = 'test-engine-id';

      // Act
      final Either<Exception, void> saveResult = await repository.setGoogleSearchEngineId(testId);
      final Either<Exception, String?> getResult = await repository.getGoogleSearchEngineId();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => null), testId);
    });

    test('should save and retrieve Google Search enabled state', () async {
      // Act
      final Either<Exception, void> saveResult = await repository.setGoogleSearchEnabled(false);
      final Either<Exception, bool> getResult = await repository.getGoogleSearchEnabled();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => true), false);
    });
  });

  group('OpenWeather Settings', () {
    test('should save and retrieve OpenWeather key', () async {
      // Arrange
      const String testKey = 'test-openweather-key';

      // Act
      final Either<Exception, void> saveResult = await repository.setOpenWeatherKey(testKey);
      final Either<Exception, String?> getResult = await repository.getOpenWeatherKey();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => null), testKey);
    });

    test('should save and retrieve OpenWeather enabled state', () async {
      // Act
      final Either<Exception, void> saveResult = await repository.setOpenWeatherEnabled(false);
      final Either<Exception, bool> getResult = await repository.getOpenWeatherEnabled();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => true), false);
    });
  });

  group('New York Times Settings', () {
    test('should save and retrieve New York Times key', () async {
      // Arrange
      const String testKey = 'test-nyt-key';

      // Act
      final Either<Exception, void> saveResult = await repository.setNewYorkTimesKey(testKey);
      final Either<Exception, String?> getResult = await repository.getNewYorkTimesKey();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => null), testKey);
    });

    test('should save and retrieve New York Times enabled state', () async {
      // Act
      final Either<Exception, void> saveResult = await repository.setNewYorkTimesEnabled(false);
      final Either<Exception, bool> getResult = await repository.getNewYorkTimesEnabled();

      // Assert
      expect(saveResult.isRight(), true);
      expect(getResult.getOrElse(() => true), false);
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/features/settings/function_calling_settings_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/features/settings/function_calling_settings_test.dart
git commit -m "test: add unit tests for function calling settings"
```

---

## Task 15: Write Widget Tests for FunctionCallingConfigScreen

**Files:**
- Create: `test/features/settings/screens/function_calling_config_screen_test.dart`

**Step 1: Write widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_state.dart';
import 'package:yofardev_ai/features/settings/screens/function_calling_config_screen.dart';

void main() {
  late SettingsCubit settingsCubit;

  setUp(() {
    settingsCubit = MockSettingsCubit();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: const FunctionCallingConfigScreen(),
      ),
    );
  }

  group('FunctionCallingConfigScreen', () {
    testWidgets('should display all three service sections', (WidgetTester tester) async {
      // Arrange
      when(() => settingsCubit.state).thenReturn(const SettingsState());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Google Search'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
    });

    testWidgets('should display API key fields', (WidgetTester tester) async {
      // Arrange
      when(() => settingsCubit.state).thenReturn(const SettingsState());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('API Key'), findsNWidgets(3)); // 3 services
      expect(find.text('Search Engine ID'), findsOneWidget); // Google only
    });

    testWidgets('should display enable toggles', (WidgetTester tester) async {
      // Arrange
      when(() => settingsCubit.state).thenReturn(const SettingsState());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    });

    testWidgets('should update Google Search key when typed', (WidgetTester tester) async {
      // Arrange
      when(() => settingsCubit.state).thenReturn(const SettingsState());
      when(() => settingsCubit.updateGoogleSearchKey(any())).thenReturn(null);

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.widgetWithText(TextField, 'API Key').first, 'new-key');
      await tester.pump();

      // Assert
      verify(() => settingsCubit.updateGoogleSearchKey('new-key')).called(1);
    });
  });
}

class MockSettingsCubit extends Mock implements SettingsCubit {}
```

**Step 2: Run tests**

Run: `flutter test test/features/settings/screens/function_calling_config_screen_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/features/settings/screens/function_calling_config_screen_test.dart
git commit -m "test: add widget tests for FunctionCallingConfigScreen"
```

---

## Task 16: Write Service Tests with API Keys

**Files:**
- Create: `test/core/services/agent/google_search_service_test.dart`
- Create: `test/core/services/agent/weather_service_test.dart`
- Create: `test/core/services/agent/news_service_test.dart`

**Step 1: Write GoogleSearchService tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:yofardev_ai/core/services/agent/google_search_service.dart';

@GenerateMocks(<MockSpec<Object>>[http.Client])
void main() {
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
  });

  group('GoogleSearchService', () {
    const String apiKey = 'test-api-key';
    const String engineId = 'test-engine-id';

    test('should return search results on successful API call', () async {
      // Arrange
      final Map<String, dynamic> mockResponse = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Test Title',
            'snippet': 'Test Snippet',
            'link': 'https://example.com',
          },
        ],
      };

      when(mockClient.get(any))
          .thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

      // Act
      final List<Map<String, dynamic>> result = await GoogleSearchService.searchGoogle(
        'test query',
        apiKey,
        engineId,
      );

      // Assert
      expect(result.length, 1);
      expect(result[0]['title'], 'Test Title');
      expect(result[0]['snippet'], 'Test Snippet');
      expect(result[0]['url'], 'https://example.com');
    });

    test('should throw exception when API key is empty', () async {
      // Act & Assert
      expect(
        () => GoogleSearchService.searchGoogle('query', '', engineId),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw exception when engine ID is empty', () async {
      // Act & Assert
      expect(
        () => GoogleSearchService.searchGoogle('query', apiKey, ''),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

**Step 2: Write WeatherService tests**

Similar pattern for WeatherService with API key parameter.

**Step 3: Write NewsService tests**

Similar pattern for NewsService with API key parameter.

**Step 4: Run tests**

Run: `flutter test test/core/services/agent/`
Expected: All tests pass

**Step 5: Commit**

```bash
git add test/core/services/agent/
git commit -m "test: add service tests with API key parameters"
```

---

## Task 17: End-to-End Integration Test

**Files:**
- Create: `test/integration/function_calling_integration_test.dart`

**Step 1: Write integration test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_state.dart';
import 'package:yofardev_ai/features/settings/screens/function_calling_config_screen.dart';

void main() {
  testWidgets('Full flow: configure key → enable → function available', (WidgetTester tester) async {
    // Arrange
    late SettingsCubit settingsCubit;
    SettingsState? capturedState;

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>(
          create: (BuildContext context) {
            settingsCubit = SettingsCubit();
            return settingsCubit;
          },
          child: const FunctionCallingConfigScreen(),
        ),
      ),
    );

    // Act: Enter Google Search API key
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key').first,
      'test-google-key',
    );
    await tester.pumpAndSettle();

    // Act: Enter Engine ID
    await tester.enterText(
      find.widgetWithText(TextField, 'Search Engine ID'),
      'test-engine-id',
    );
    await tester.pumpAndSettle();

    // Act: Verify toggle is enabled by default
    expect(find.byType(SwitchListTile), findsWidgets);
    final SwitchListTile toggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(toggle.value, true);

    // Assert: Check state was updated
    capturedState = settingsCubit.state;
    expect(capturedState?.googleSearchKey, 'test-google-key');
    expect(capturedState?.googleSearchEngineId, 'test-engine-id');
    expect(capturedState?.googleSearchEnabled, true);

    // Act: Disable the function
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    // Assert: Verify disabled state
    capturedState = settingsCubit.state;
    expect(capturedState?.googleSearchEnabled, false);
  });
}
```

**Step 2: Run integration test**

Run: `flutter test test/integration/function_calling_integration_test.dart`
Expected: Test passes

**Step 3: Commit**

```bash
git add test/integration/function_calling_integration_test.dart
git commit -m "test: add integration test for function calling configuration"
```

---

## Task 18: Clean Up and Documentation

**Files:**
- Delete: `.env`
- Modify: `README.md` (if it references .env)
- Modify: `.gitignore` (keep .env for safety)

**Step 1: Delete .env file**

Run: `rm .env`

**Step 2: Update README.md**

Remove any references to .env file setup. Add section about configuring API keys in-app.

**Step 3: Verify .gitignore**

Ensure `.env` is still in `.gitignore` for safety:

```
# Environment variables
.env
.env.*
```

**Step 4: Run final analysis**

Run: `flutter analyze`
Expected: No errors

**Step 5: Run all tests**

Run: `flutter test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add .env README.md .gitignore
git commit -m "chore: remove .env file and update documentation"
```

---

## Task 19: Manual Testing Checklist

**Manual Testing Steps:**

1. **Launch app** - Verify app starts without .env file
2. **Navigate to Settings** - Find "Function Calling" option
3. **Open Function Calling screen** - Verify all three sections appear
4. **Enter Google Search key** - Type API key and Engine ID
5. **Toggle functions** - Test enable/disable switches
6. **Start a chat** - Verify only enabled functions appear in LLM request
7. **Test Google Search** - Use Google Search function in chat
8. **Test Weather** - Use Weather function in chat
9. **Test News** - Use News function in chat
10. **Disable a function** - Verify it no longer appears in chat
11. **Restart app** - Verify settings persist

**Step 1: Create testing document**

Create `docs/testing/function-calling-manual-test.md` with the checklist above.

**Step 2: Commit**

```bash
git add docs/testing/function-calling-manual-test.md
git commit -m "docs: add manual testing checklist for function calling"
```

---

## Task 20: Final Code Review and Merge Preparation

**Step 1: Run full test suite**

Run: `flutter test --coverage`
Expected: All tests pass

**Step 2: Run Flutter analysis**

Run: `flutter analyze --no-fatal-infos`
Expected: No errors

**Step 3: Check code formatting**

Run: `dart format --output=none --set-exit-if-changed .`
Expected: No unformatted files

**Step 4: Review git log**

Run: `git log --oneline -20`
Expected: Clean commit history following feature progression

**Step 5: Create summary of changes**

Document:
- Files added: 10+
- Files modified: 15+
- Tests added: 20+
- Lines of code changed: ~800

**Step 6: Prepare for merge**

```bash
git add .
git commit -m "feat: complete function calling configuration implementation

- Move function calling API keys from .env to in-app settings
- Add enable/disable toggles for each function
- Refactor services to accept keys as parameters
- Create Function Calling Configuration screen
- Add comprehensive unit and widget tests
- Remove .env file dependency

Breaking changes: None
Migration: Users will need to reconfigure API keys in-app"
```

---

## Summary

This implementation plan:

✅ **Follows TDD** - Tests written before/with implementation
✅ **Bite-sized tasks** - Each step is 2-5 minutes
✅ **Frequent commits** - Every logical unit committed
✅ **Complete code** - Full implementations shown
✅ **Exact commands** - Every command with expected output
✅ **Architecture standards** - Follows @flutter-architecture patterns
✅ **Comprehensive testing** - Unit, widget, integration tests included

**Estimated time:** 4-6 hours for full implementation
**Files to touch:** ~25 files
**New files:** ~10 files
**Tests to write:** ~20 tests
