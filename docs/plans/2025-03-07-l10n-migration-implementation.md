# Localization System Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate from custom LocalizationManager to Flutter's standard AppLocalizations ARB-based system

**Architecture:** Remove LocalizationManager entirely, create LocaleRepository for SharedPreferences, use AppLocalizations.of(context) in UI, update all imports and service_locator in big bang migration

**Tech Stack:** Flutter ARB files, AppLocalizations, SharedPreferences, Either for error handling

---

## Task 1: Create LocaleRepository Interface

**Files:**
- Create: `lib/core/repositories/locale_repository.dart`

**Step 1: Create the repository interface**

```dart
import 'package:fpdart/fpdart.dart';

/// Repository for managing language preference persistence
abstract class LocaleRepository {
  /// Get the current saved language code (e.g., 'en', 'fr')
  Future<Either<Exception, String>> getLanguage();

  /// Save the language code
  Future<Either<Exception, void>> setLanguage(String languageCode);
}
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/core/repositories/locale_repository.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/core/repositories/locale_repository.dart
git commit -m "feat: add LocaleRepository interface"
```

---

## Task 2: Create LocaleRepository Implementation

**Files:**
- Create: `lib/core/repositories/locale_repository_impl.dart`
- Test: `test/core/repositories/locale_repository_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
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
      expect(result.getOrElse(() => ''), 'fr'); // Default to French
    });

    test('setLanguage saves and retrieves language', () async {
      await repository.setLanguage('en');
      final result = await repository.getLanguage();
      expect(result.getOrElse(() => ''), 'en');
    });

    test('getLanguage returns saved language', () async {
      SharedPreferences.setMockInitialValues({'language': 'en'});
      SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocaleRepositoryImpl(prefs: prefs);

      final result = await repository.getLanguage();
      expect(result.getOrElse(() => ''), 'en');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/repositories/locale_repository_test.dart`
Expected: FAIL with "LocaleRepositoryImpl not implemented"

**Step 3: Write minimal implementation**

```dart
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
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/core/repositories/locale_repository_test.dart`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/core/repositories/locale_repository_impl.dart test/core/repositories/locale_repository_test.dart
git commit -m "feat: add LocaleRepository implementation with tests"
```

---

## Task 3: Update Service Locator

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Add LocaleRepository import and registration**

After line 51 (before "// Demo services"), add:

```dart
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../repositories/locale_repository.dart';
import '../repositories/locale_repository_impl.dart';
```

After line 91 (after DemoService registration), add:

```dart
  // Locale
  getIt.registerLazySingleton<LocaleRepository>(
    () => LocaleRepositoryImpl(
      prefs: await SharedPreferences.getInstance(),
    ),
  );
```

**Step 2: Remove LocalizationManager registration**

Remove lines 139-139:

```dart
  // Remove this line:
  getIt.registerLazySingleton<LocalizationManager>(() => LocalizationManager());
```

**Step 3: Update cubit registrations to remove LocalizationManager dependency**

Find these lines (177-178, 184-185) and remove `localizationManager: getIt<LocalizationManager>()`:

```dart
// Before:
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    localizationManager: getIt<LocalizationManager>(), // REMOVE
  ),
);

// After:
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
  ),
);

// Do the same for ChatListCubit
```

**Step 4: Run dart analyze**

Run: `dart analyze lib/core/di/service_locator.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "refactor: register LocaleRepository, remove LocalizationManager from service locator"
```

---

## Task 4: Update main.dart Initialization

**Files:**
- Modify: `lib/main.dart`

**Step 1: Remove LocalizationManager import**

Remove line 29:

```dart
import 'l10n/localization_manager.dart'; // DELETE THIS LINE
```

**Step 2: Update main() to use LocaleRepository**

Replace lines 49-54:

```dart
// Before:
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  final String initialLanguage = savedLanguage ?? deviceLocale.languageCode;
  await LocalizationManager().initialize(initialLanguage);

// After:
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  final String initialLanguage = savedLanguage ?? deviceLocale.languageCode;
  // Language is now handled by AppLocalizations via MaterialApp
```

**Step 3: Update MaterialApp locale to use saved language**

Replace line 117:

```dart
// Before:
        locale: const Locale('fr'),

// After:
        locale: Locale(initialLanguage),
```

**Step 4: Run dart analyze**

Run: `dart analyze lib/main.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "refactor: remove LocalizationManager from main.dart, use saved locale"
```

---

## Task 5: Update ChatsCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`

**Step 1: Remove LocalizationManager import and dependency**

Remove line 5:

```dart
import '../../../../l10n/localization_manager.dart'; // DELETE
```

Remove from constructor (lines 14-24, 29):

```dart
// Remove this parameter:
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LocalizationManager localizationManager, // DELETE
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _localizationManager = localizationManager, // DELETE
       super(ChatsState.initial());

// Also remove:
  final LocalizationManager _localizationManager; // DELETE
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/features/chat/presentation/bloc/chats_cubit.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_cubit.dart
git commit -m "refactor: remove LocalizationManager from ChatsCubit"
```

---

## Task 6: Update ChatListCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_list_cubit.dart`

**Step 1: Remove LocalizationManager dependency**

Same changes as Task 5:

```dart
// Remove import:
import '../../../../l10n/localization_manager.dart'; // DELETE

// Remove from constructor:
  ChatListCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LocalizationManager localizationManager, // DELETE
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _localizationManager = localizationManager, // DELETE
       super(ChatListState.initial());

// Remove field:
  final LocalizationManager _localizationManager; // DELETE
```

**Step 2: Remove _localizationManager.initialize() call**

Remove or update lines 36-38:

```dart
// Before:
    languageResult.fold((Exception error) {}, (String? language) {
      if (language != null) {
        emit(state.copyWith(currentLanguage: language));
        _localizationManager.initialize(language).ignore(); // DELETE THIS
      }
    });

// After:
    languageResult.fold((Exception error) {}, (String? language) {
      if (language != null) {
        emit(state.copyWith(currentLanguage: language));
      }
    });
```

**Step 3: Run dart analyze**

Run: `dart analyze lib/features/chat/presentation/bloc/chat_list_cubit.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/chat/presentation/bloc/chat_list_cubit.dart
git commit -m "refactor: remove LocalizationManager from ChatListCubit"
```

---

## Task 7: Update ChatStreamingCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_streaming_cubit.dart`

**Step 1: Check LocalizationManager usage**

Read file to see how it's used (line 16 import)

**Step 2: Remove or replace usage**

If it's used for getting language, pass language from state or use LocaleRepository

**Step 3: Run dart analyze**

Run: `dart analyze lib/features/chat/presentation/bloc/chat_streaming_cubit.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/chat/presentation/bloc/chat_streaming_cubit.dart
git commit -m "refactor: remove LocalizationManager from ChatStreamingCubit"
```

---

## Task 8: Update SettingsLocalDatasource

**Files:**
- Modify: `lib/core/services/settings_local_datasource.dart`

**Step 1: Remove LocalizationManager import**

Remove line 7:

```dart
import '../../l10n/localization_manager.dart'; // DELETE
```

**Step 2: Update getBaseSystemPrompt method**

The method needs languageCode. Currently it references undefined variable. Fix it:

```dart
// Before (line 104):
AppUtils.fixAssetsPath('assets/txt/system_prompt_$languageCode.txt'),

// After - add languageCode parameter:
  Future<String> getBaseSystemPrompt(String languageCode) async {
    final String baseSystemPrompt = await rootBundle.loadString(
      AppUtils.fixAssetsPath('assets/txt/system_prompt_$languageCode.txt'),
    );
    return baseSystemPrompt;
  }
```

**Step 3: Update all callers to pass language code**

Search for `getBaseSystemPrompt()` calls and update them to pass language code

**Step 4: Run dart analyze**

Run: `dart analyze lib/core/services/settings_local_datasource.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/core/services/settings_local_datasource.dart
git commit -m "refactor: update getBaseSystemPrompt to require languageCode parameter"
```

---

## Task 9: Update All Widget Imports

**Files:**
- Modify: All widget files importing localization_manager.dart (15+ files)

**Step 1: List all files to update**

Run: `grep -r "import.*localization_manager" lib/features --include="*.dart"`

**Step 2: For each widget file, replace import**

```dart
// Before:
import '../../../l10n/localization_manager.dart';

// After:
import '../../../../core/l10n/generated/app_localizations.dart';
```

**Step 3: Replace usage patterns**

```dart
// Before:
LocalizationManager.of(context).appName

// After:
AppLocalizations.of(context).appName
```

**Step 4: Do this for each file:**
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/function_calling_config_tile.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/screens/function_calling_config_screen.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/chats_list_app_bar.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart`

**Step 5: Run dart analyze**

Run: `dart analyze lib/features`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/features
git commit -m "refactor: replace LocalizationManager with AppLocalizations in all widgets"
```

---

## Task 10: Update PromptDatasource

**Files:**
- Modify: `lib/core/services/prompt_datasource.dart`

**Step 1: Check usage pattern**

Read file to see how LocalizationManager is used

**Step 2: Remove import and replace usage**

Similar to previous tasks

**Step 3: Run dart analyze**

Run: `dart analyze lib/core/services/prompt_datasource.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/services/prompt_datasource.dart
git commit -m "refactor: remove LocalizationManager from PromptDatasource"
```

---

## Task 11: Update ChatEntryService

**Files:**
- Modify: `lib/features/chat/domain/services/chat_entry_service.dart`

**Step 1: Check and remove LocalizationManager**

Same pattern as previous tasks

**Step 2: Run dart analyze**

Run: `dart analyze lib/features/chat/domain/services/chat_entry_service.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/chat/domain/services/chat_entry_service.dart
git commit -m "refactor: remove LocalizationManager from ChatEntryService"
```

---

## Task 12: Run Migration Script

**Files:**
- Use: `scripts/migrate_l10n.sh`

**Step 1: Make script executable**

Run: `chmod +x scripts/migrate_l10n.sh`

**Step 2: Run migration script**

Run: `./scripts/migrate_l10n.sh`

This will execute all 44 fstr commands to migrate strings to ARB files

**Step 3: Verify ARB files are populated**

Run: `ls -lh lib/core/l10n/*.arb`
Expected: Both files should be >3KB

**Step 4: Regenerate localization files**

Run: `flutter gen-l10n`

**Step 5: Verify generated files**

Run: `ls lib/core/l10n/generated/`
Expected: app_localizations.dart and other files

**Step 6: Commit**

```bash
git add lib/core/l10n/
git commit -m "chore: migrate all localization strings to ARB files"
```

---

## Task 13: Update Other Services

**Files:**
- Any remaining files with LocalizationManager references

**Step 1: Find remaining references**

Run: `grep -r "LocalizationManager" lib --include="*.dart"`

**Step 2: Update each file**

Follow same pattern: remove import, replace usage

**Step 3: Run dart analyze**

Run: `dart analyze lib`
Expected: No errors

**Step 4: Commit**

```bash
git add lib
git commit -m "refactor: remove remaining LocalizationManager references"
```

---

## Task 14: Final Verification

**Step 1: Run full dart analyze**

Run: `dart analyze`
Expected: No errors

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Check for any remaining old references**

Run: `grep -r "language_en\|language_fr\|languages.dart" lib --include="*.dart"`
Expected: No results (or only in comments)

**Step 4: Build app**

Run: `flutter build apk --debug` or `flutter build macos --debug`
Expected: Build succeeds

**Step 5: Manual testing**

- Launch app
- Test language switching
- Navigate to all screens
- Verify all text displays correctly in both French and English

**Step 6: Final commit**

```bash
git add .
git commit -m "refactor: complete localization migration to ARB system"
```

---

## Testing Checklist

- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] Integration tests pass
- [ ] App builds successfully
- [ ] Language switching works
- [ ] All screens display correctly in French
- [ ] All screens display correctly in English
- [ ] System prompts load with correct language
- [ ] No LocalizationManager references remain
- [ ] Service locator has no LocalizationManager registration

---

## Rollback Plan

If issues arise:
1. Revert to commit before Task 1
2. Run migration script separately to populate ARB files
3. Gradual migration approach may be needed
