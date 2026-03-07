# Localization System Migration Design

**Date:** 2025-03-07
**Author:** Claude
**Status:** Approved

## Overview

Migrate from custom `LanguageEn`/`LanguageFr` classes with `LocalizationManager` to Flutter's standard ARB-based localization system using `AppLocalizations`.

## Current State

- **Old system**: Custom classes in `lib/l10n/` (now deleted)
- **Problem**: 20+ files import non-existent `localization_manager.dart`
- **Service locator**: Registers non-existent `LocalizationManager`
- **Main.dart**: Uses old `LocalizationManager().initialize()`

## Target State

- **New system**: Flutter ARB files in `lib/core/l10n/`
- **Standard approach**: `AppLocalizations.of(context)` for UI
- **Preference management**: New `LocaleRepository` for SharedPreferences
- **No custom manager**: Removed entirely

## Architecture

### 1. LocaleRepository

A minimal repository for language preference persistence:

```dart
class LocaleRepository {
  Future<Either<Exception, String>> getLanguage();
  Future<Either<Exception, void>> setLanguage(String languageCode);
}
```

**Responsibilities:**
- Read/write language code from SharedPreferences
- Return `Either<Exception, T>` for error handling
- No UI dependencies

### 2. UI Components

Use Flutter's standard `AppLocalizations.of(context)`:

```dart
// Before
LocalizationManager.of(context).appName

// After
AppLocalizations.of(context).appName
```

### 3. Non-UI Services

Pass language code explicitly or use `LocaleRepository`:

```dart
// Before
final language = _localizationManager.currentLanguage;

// After
final language = await _localeRepository.getLanguage();
// OR pass as parameter
```

## Implementation Strategy

**Big bang migration** - Update all files in one go:
1. Create `LocaleRepository`
2. Update service_locator
3. Remove `LocalizationManager` imports
4. Update all usage sites
5. Remove old files

## Files to Modify

### New Files
- `lib/core/repositories/locale_repository.dart`
- `lib/core/repositories/locale_repository_impl.dart`

### Core Changes
- `lib/core/di/service_locator.dart` - Register `LocaleRepository`, remove `LocalizationManager`
- `lib/main.dart` - Remove `LocalizationManager`, use `LocaleRepository`

### Cubits (4 files)
- `lib/features/chat/presentation/bloc/chat_list_cubit.dart`
- `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Remove `LocalizationManager` dependency
- Use `AppLocalizations` passed from UI or `LocaleRepository`

### Widgets (12+ files)
- Replace all `LocalizationManager.of(context)` with `AppLocalizations.of(context)`

### Services
- `lib/core/services/settings_local_datasource.dart` - Use `LocaleRepository`

## Migration Checklist

1. ✅ Create migration script (`scripts/migrate_l10n.py`)
2. ⏳ Create `LocaleRepository` interface and implementation
3. ⏳ Update service_locator
4. ⏳ Update main.dart initialization
5. ⏳ Update all cubits
6. ⏳ Update all widgets
7. ⏳ Update services
8. ⏳ Run migration script to populate ARB files
9. ⏳ Test all screens with both languages
10. ⏳ Remove old localization files

## Testing

- Verify all screens display correctly in French and English
- Test language switching
- Verify system prompts load with correct language
- Check all cubits that depend on localization
- Run widget tests
- Run integration tests

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Big bang may break compilation temporarily | Do all changes in single commit, run migration first |
| Missing translations | Migration script ensures all keys migrated |
| Context not available in services | Use `LocaleRepository` or pass language as parameter |

## Success Criteria

- All files compile without errors
- All screens work in both French and English
- Language switching persists across app restarts
- No references to old `LocalizationManager` remain
- Service locator has no `LocalizationManager` registration
