# Freezed Migration Design Document

**Date:** 2025-02-28
**Author:** Claude (assisted by user)
**Status:** In Progress

## Progress

- ✅ Phase 1: Answer Migration - Completed 2025-02-28
- ✅ Phase 2: Chat Migration - Completed 2025-02-28
- ⏳ Phase 3: Avatar & AvatarConfig Migration - Pending

## Overview

Migrate all remaining Equatable classes to Freezed for 100% code consistency across the Flutter project.

## Problem Statement

The project has 8 files still using Equatable that need migration to Freezed:

**Files using Equatable:**
- `lib/models/answer.dart`
- `lib/models/chat.dart`
- `lib/models/avatar.dart` (contains Avatar and AvatarConfig classes)
- `lib/features/avatar/bloc/avatar_state.dart`
- `lib/features/chat/bloc/chat_state.dart`
- `lib/features/sound/bloc/sound_state.dart`
- `lib/logic/talking/talking_state.dart`
- `lib/models/llm/llm_config.dart`

**Duplication Issue:**
- `lib/core/models/avatar_config.dart` exists with Freezed Avatar/AvatarConfig but has 0 imports
- `lib/models/avatar.dart` has duplicate Equatable Avatar/AvatarConfig with 14 active imports
- This creates confusion and maintenance burden

## Architecture

### Migration Strategy: Incremental Consolidation

**Approach:** Update imports first, then migrate in-place, delete duplicates last

**Migration Order (Simplest → Most Complex):**
1. Phase 1: Answer (simple Equatable)
2. Phase 2: Chat (moderate - has extension method)
3. Phase 3: Avatar & AvatarConfig (complex - custom serialization, enums)

### Target File Structure

**Before:**
```
models/avatar.dart (Equatable, actively used - 14 imports)
  ├── enums (AvatarBackgrounds, AvatarHat, etc.)
  ├── class Avatar (Equatable)
  └── class AvatarConfig (Equatable)

core/models/avatar_config.dart (Freezed, NOT used - 0 imports)
  ├── enums (DUPLICATE!)
  ├── class Avatar (Freezed)
  └── class AvatarConfig (Freezed)
```

**After:**
```
models/avatar_enums.dart (NEW - shared enums)
core/models/avatar_config.dart (Freezed, actively used)
  ├── enums (consolidated)
  ├── class Avatar (Freezed)
  └── class AvatarConfig (Freezed)

models/avatar.dart (DELETED - classes migrated, enums extracted)
```

## Components

### Classes to Migrate

#### Phase 1: Answer
- **File:** `lib/models/answer.dart`
- **Fields:** chatId, answerText, audioPath, amplitudes, avatarConfig
- **Complexity:** Low - no custom serialization
- **Tests:** Serialization, equality, copyWith, defaults

#### Phase 2: Chat
- **File:** `lib/models/chat.dart`
- **Fields:** id, entries, avatar, language, systemPrompt, persona
- **Complexity:** Medium - has ChatExtension.llmMessages, custom toJson() returning String
- **Tests:** Serialization, equality, copyWith, extension method

#### Phase 3: Avatar & AvatarConfig
- **File:** `lib/models/avatar.dart` (331 lines - also needs splitting!)
- **Classes:** Avatar, AvatarConfig
- **Complexity:** High - custom toString(), weird field mappings, EnumUtils helpers
- **Tests:** Serialization edge cases, enum conversions, getters, copyWith

### File Splitting

Since `avatar.dart` is 331 lines (exceeds 300 line limit), split during Phase 3:
- Extract enums to `models/avatar_enums.dart`
- Consolidate into `core/models/avatar_config.dart`

## Data Flow

### Per-Phase Migration Process

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: Answer                                            │
│ 1. Write test/models/answer_test.dart                   │
│ 2. Add @freezed boilerplate to models/answer.dart        │
│ 3. flutter pub run build_runner                         │
│ 4. Fix issues, run tests                                  │
│ 5. Remove old Equatable Answer class                      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Phase 2: Chat                                              │
│ 1. Write test/models/chat_test.dart                     │
│ 2. Add @freezed boilerplate, preserve ChatExtension      │
│ 3. Keep toMap/fromMap as backward-compat wrappers        │
│ 4. flutter pub run build_runner                         │
│ 5. Fix issues, run tests                                  │
│ 6. Update imports in services                             │
│ 7. Remove old Equatable Chat class                        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Phase 3: Avatar/AvatarConfig                             │
│ 1. Extract enums to models/avatar_enums.dart              │
│ 2. Update core/models/avatar_config.dart                  │
│ 3. Write comprehensive tests                               │
│ 4. Add @freezed with custom methods as extensions       │
│ 5. Use JsonConverter for SoundEffects                     │
│ 6. Update all 14 imports to core/models/                │
│ 7. Remove old Equatable classes                           │
│ 8. Delete duplicate core/models/avatar_config.dart         │
└─────────────────────────────────────────────────────┘
```

### Import Updates

**Pattern:**
```dart
// BEFORE
import '../../../models/avatar.dart';

// AFTER
import '../../../core/models/avatar_config.dart';
```

**Files requiring updates:** 14 files across services, blocs, UI, and tests

## Error Handling

### Expected Issues & Mitigations

| Issue | Likelihood | Mitigation |
|-------|-----------|------------|
| Build runner conflicts | Medium | Run `build_runner clean`, use `--delete-conflicting-outputs` |
| AvatarConfig SoundEffects serialization | High | Use `@JsonConverter` annotation |
| Custom toString() conflicts | Medium | Move to extension method |
| Enum serialization edge cases | Medium | Comprehensive enum value testing |
| Import cycle errors | Low | Use package imports |
| Backward compatibility breaks | Low | Keep toMap/fromMap wrapper methods |

### Rollback Strategy

If a phase fails:
1. Revert Freezed changes
2. Keep tests (still valuable)
3. Document failures
4. Continue to next phase

### Validation Checklist (After Each Phase)

- [ ] `flutter analyze`: 0 errors
- [ ] `flutter test`: all pass
- [ ] App runs without crashes
- [ ] Serialization works end-to-end
- [ ] All extension methods function
- [ ] Git commit with tests + migration

## Testing Strategy

### Test-Driven Workflow

```
BEFORE: Write failing tests for current behavior → Confirm failures
DURING: Migrate to Freezed → Fix failures while preserving behavior
AFTER: All tests pass, analyze clean, commit
```

### Test Files to Create

1. **Phase 1:** `test/models/answer_test.dart`
2. **Phase 2:** `test/models/chat_test.dart`
3. **Phase 3:** `test/models/avatar_test.dart`

### Test Coverage Requirements

**Answer:**
- Serialization round-trips
- Equality and hashCode
- copyWith() all fields
- Default values
- Null safety for AvatarConfig

**Chat:**
- Serialization with both toMap/fromMap and toJson/fromJson
- Freezed toJson/fromJson
- Equality
- copyWith() all fields
- ChatExtension.llmMessages behavior
- ChatPersona enum serialization
- Empty entries list

**Avatar & AvatarConfig:**
- Custom toString() (via extension)
- EnumUtils.deserialize() with all enum values
- Custom getters (hideBlinkingEyes, etc.)
- copyWith() all fields
- AvatarConfig nullable fields
- SoundEffects enum JsonConverter

### State Class Tests

Update existing tests to ensure Freezed classes work:
- `test/features/avatar/avatar_state_test.dart`
- `test/features/chat/chat_state_test.dart`
- `test/logic/talking/talking_state_test.dart`

Freezed provides same equality as Equatable, so tests should pass with minimal updates.

## Success Criteria

**Project is complete when:**
- ✅ All 8 Equatable classes migrated to Freezed with `sealed` keyword
- ✅ All tests pass (new + updated)
- ✅ `flutter analyze` shows 0 errors
- ✅ No duplicate Avatar/AvatarConfig classes
- ✅ All enums consolidated to one location
- ✅ All imports updated to use consolidated classes
- ✅ Custom methods preserved (getters, extensions)
- ✅ Backward compatibility maintained (toMap/fromMap methods)

## Estimated Timeline

- **Phase 1 (Answer):** 1-2 hours
- **Phase 2 (Chat):** 2-3 hours
- **Phase 3 (Avatar/Config):** 3-4 hours

**Total:** 6-9 hours (spread across multiple sessions acceptable)

## Dependencies

- **Required packages:** freezed: ^3.2.5, freezed_annotation: ^3.1.0, build_runner: ^2.11.1
- **Flutter:** 3.41.2 with Dart 3.11.0
- **Test framework:** flutter_test (already in project)

## Migration Complete When...

This design is complete when the following are true:

1. ✅ All Equatable classes use Freezed with `sealed` keyword
2. ✅ No duplicate classes exist
3. ✅ All imports consolidated
4. ✅ Test coverage >80% for migrated classes
5. ✅ Zero analyzer errors
6. ✅ App runs successfully
