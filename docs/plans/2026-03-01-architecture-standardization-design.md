# Architecture Standardization - Design Document

**Date:** 2025-03-01
**Status:** Approved
**Author:** Claude Code

## Executive Summary

A comprehensive **big bang migration** to standardize the yofardev_ai Flutter codebase to match the official Flutter architecture template. This refactoring restructures ~70 files across multiple directories, adds tests for safety, and extracts oversized components.

## Problem Statement

The codebase currently has a **mixed architecture** with both `lib/ui/` and `lib/features/` directories, duplicate services, and files that exceed size limits. This violates the standardized feature-based architecture defined in the Flutter architecture skill.

### Current Issues

1. **Mixed directory structure** - `lib/ui/pages/` vs `lib/features/*/screens/`
2. **Duplicate services** - `lib/services/llm_service.dart` and `lib/core/services/llm/llm_service.dart`
3. **Oversized files** - `ai_text_input.dart` (315 lines), `settings_page.dart` (308 lines)
4. **Scattered utilities** - `lib/utils/`, `lib/res/`, `lib/models/`, `lib/repositories/`, `lib/logic/` outside of `lib/core/`
5. **Mixed BLoC file organization** - Some use `part` directives, should be fully separated
6. **Minimal test coverage** - Only 1 test file exists

## Goals

1. **Standardize directory structure** - Everything under `lib/features/` or `lib/core/`
2. **Eliminate duplicates** - Single source of truth for all services, models, utilities
3. **Comply with file size limits** - All files under 300 lines (widgets/screens) or 400 lines (services)
4. **Full BLoC separation** - Every Cubit/BLoC has separate `state.dart` and `event.dart` files
5. **Add test coverage** - Safety net before major refactoring
6. **Maintain functionality** - Zero regressions in user-facing features

## Design

### Phase 1: Safety Net - Add Tests

**Goal:** Ensure current behavior is preserved during migration.

#### Test Files to Create

```
test/
├── features/
│   ├── chat/
│   │   ├── bloc/chats_cubit_test.dart
│   │   ├── screens/chat_details_page_test.dart
│   │   └── widgets/chat_message_item_test.dart
│   ├── avatar/
│   │   └── bloc/avatar_cubit_test.dart
│   └── sound/
│       └── bloc/sound_cubit_test.dart
├── widgets/
│   ├── ai_text_input_test.dart
│   └── glassmorphic_text_field_test.dart
└── integration/
    └── smoke_test.dart
```

#### Test Coverage Targets

- **Cubit unit tests:** `ChatsCubit`, `AvatarCubit`, `TalkingCubit`, `SoundCubit`
- **Widget tests:** `ai_text_input.dart`, `chat_details_page.dart`
- **Integration smoke test:** Basic app flow verification

---

### Phase 2: Extract Oversized Components

**Goal:** Reduce file sizes before migration to simplify the move.

#### 2.1: `ai_text_input.dart` (315 lines)

**Current structure:**
- Speech-to-text handling
- Image picker handling
- Text submission logic
- UI layout

**Extract to:**
```
lib/ui/widgets/ai_text_input/
├── ai_text_input.dart              # Main widget (~150 lines)
├── speech_to_text_handler.dart     # SpeechToText wrapper (~60 lines)
├── image_picker_handler.dart       # Image selection logic (~40 lines)
└── text_submission_handler.dart    # Submit/validation logic (~40 lines)
```

#### 2.2: `settings_page.dart` (308 lines)

**Current structure:**
- Settings loading/saving
- AppBar with save button
- Username field
- Persona dropdown
- Sound effects toggle
- API key button

**Extract to:**
```
lib/ui/pages/settings/
├── settings_page.dart              # Main screen (~150 lines)
└── widgets/
    ├── settings_app_bar.dart       # AppBar + save button (~50 lines)
    ├── username_field.dart         # Username input (~40 lines)
    ├── persona_dropdown.dart       # Persona selector (~30 lines)
    └── sound_effects_toggle.dart   # Sound toggle widget (~30 lines)
```

---

### Phase 3: Directory Restructure (Big Bang)

#### 3.1: `lib/ui/` → `lib/features/` + `lib/core/widgets/`

| Current | New Location |
|---------|--------------|
| `ui/pages/chat/*` | `features/chat/screens/` |
| `ui/pages/settings/*` | `features/settings/screens/` |
| `ui/pages/home.dart` | `features/home/screens/home_screen.dart` |
| `ui/widgets/chat/*` | `features/chat/widgets/` |
| `ui/widgets/settings/*` | `features/settings/widgets/` |
| `ui/widgets/avatar/*` | `features/avatar/widgets/` |
| `ui/widgets/demo/*` | `features/demo/widgets/` |
| `ui/widgets/glassmorphic/*` | `core/widgets/glassmorphic/` |
| `ui/widgets/animations/*` | `core/widgets/animations/` |
| `ui/widgets/ai_text_input/*` | `features/chat/widgets/ai_text_input/` |

**Files:** ~50 files

#### 3.2: `lib/services/` → `lib/core/services/`

| Current | New Location |
|---------|--------------|
| `services/settings_service.dart` | `core/services/settings_service.dart` |
| `services/tts_service.dart` | `core/services/tts_service.dart` |
| `services/chat_history_service.dart` | `core/services/chat_history_service.dart` |
| `services/cache_service.dart` | `core/services/cache_service.dart` |
| `services/llm/llm_*` | `core/services/llm/llm_*` (already there) |
| `services/llm_service.dart` | **DELETE** (duplicate) |
| `services/fake_llm_service.dart` | **DELETE** (duplicate) |
| `services/news_service.dart` | `core/services/agent/news_service.dart` |
| `services/weather_service.dart` | `core/services/agent/weather_service.dart` |
| `services/wikipedia_service.dart` | `core/services/agent/wikipedia_service.dart` |
| `services/google_search_service.dart` | `core/services/agent/google_search_service.dart` |
| `services/alarm_service.dart` | `core/services/agent/alarm_service.dart` |

**Files:** ~15 files moved, 2 deleted

#### 3.3: `lib/models/` → `lib/core/models/`

- Merge all unique models from `lib/models/` into `lib/core/models/`
- Remove duplicates
- Delete `lib/models/` directory after migration

#### 3.4: `lib/repositories/` → `lib/core/repositories/`

```
repositories/yofardev_repository.dart → core/repositories/yofardev_repository.dart
```

#### 3.5: `lib/logic/` → Restructure

| Current | New Location |
|---------|--------------|
| `logic/agent/*` | `core/services/agent/` (agent orchestration) |
| `logic/talking/*` | `features/talking/bloc/` |
| `logic/home/*` | `features/home/bloc/` |

#### 3.6: `lib/utils/` → `lib/core/utils/`

#### 3.7: `lib/res/` → `lib/core/res/`

---

### Phase 4: Split BLoC/Cubit Files

**For every BLoC/Cubit, create separate files:**

**Before (ChatsCubit example):**
```
lib/features/chat/bloc/
├── chats_cubit.dart      # Contains: class ChatsCubit + part 'chat_state.dart'
└── chat_state.dart       # State classes
```

**After:**
```
lib/features/chat/bloc/
├── chats_cubit.dart      # Only the Cubit class
├── chat_state.dart       # State classes (standalone, no part)
└── chat_event.dart       # Event classes (if BLoC pattern)
```

**Files to split:**
- `ChatsCubit` (chat)
- `AvatarCubit` (avatar)
- `TalkingCubit` (talking)
- `DemoCubit` (demo)
- `SoundCubit` (sound)

---

### Phase 5: Update Imports

**Systematic import updates after file moves:**

```dart
// OLD → NEW mappings

'../../ui/pages/chat/...' → '../../features/chat/screens/...'
'../../ui/widgets/chat/...' → '../../features/chat/widgets/...'
'../../services/' → '../../core/services/'
'../../models/' → '../../core/models/'
'../../repositories/' → '../../core/repositories/'
'../../utils/' → '../../core/utils/'
'../../res/' → '../../core/res/'
'../../logic/talking/' → '../../features/talking/bloc/'
'../../logic/agent/' → '../../core/services/agent/'
```

**Automated approach:**
1. Use `sed` or similar for bulk replacements
2. Manual verification for edge cases
3. Run `dart fix --apply` to fix any remaining issues

---

### Phase 6: Verification

**Pre-launch checklist:**

1. **Clean build:**
   ```bash
   flutter clean && flutter pub get
   ```

2. **Regenerate code:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Analyze:**
   ```bash
   flutter analyze
   ```
   - Expected: Zero errors

4. **Format:**
   ```bash
   dart format .
   dart fix --apply
   ```

5. **Run tests:**
   ```bash
   flutter test
   ```
   - All Phase 1 tests must pass

6. **Manual smoke test:**
   - App launches successfully
   - Chat feature works
   - Settings page opens
   - Avatar renders
   - No runtime crashes

---

### Phase 7: Cleanup

**Post-migration cleanup:**

1. Remove empty directories:
   - `lib/ui/`
   - `lib/services/`
   - `lib/models/`
   - `lib/repositories/`
   - `lib/logic/`

2. Remove old generated files:
   - `.freezed.dart` files from old locations
   - `.g.dart` files from old locations

3. Final code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

---

## Migration Order

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1 | Add tests (safety net) | 2-3 hours |
| 2 | Extract oversized files | 1-2 hours |
| 3.1-3.7 | Directory restructure | 2-3 hours |
| 4 | Update imports | 1 hour |
| 5 | Split BLoC files | 1 hour |
| 6 | Verification | 1 hour |
| 7 | Cleanup | 0.5 hours |
| **Total** | | **~9-11 hours** |

---

## Success Criteria

✅ All files under size limits (300 lines for widgets/screens, 400 for services)
✅ Single directory structure: `lib/features/` and `lib/core/`
✅ All BLoC/Cubit files fully separated
✅ Zero `flutter analyze` errors
✅ All tests passing
✅ App runs without crashes
✅ Core features functional (chat, settings, avatar)

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking imports | High | Tests catch regressions; systematic import update |
| Freezed generation errors | Medium | Regenerate after migration; clean build |
| Runtime crashes | High | Smoke tests after each phase |
| Git history complexity | Low | Descriptive commit messages per phase |
| File conflicts | Medium | Work in a dedicated branch |

---

## Deferred Work (Future Enhancements)

**Not included in this refactoring (deferred to future work):**

- SettingsCubit creation (currently uses setState)
- Navigation pattern fixes (move all navigation to BlocListener)
- Comprehensive test coverage (beyond safety net)
- L10n ARB file migration (currently using manual classes)
- Repository pattern implementation

These will be addressed in follow-up tasks once the new structure is stable.

---

## Next Steps

1. **Create implementation plan** - Detailed step-by-step execution guide
2. **Create feature branch** - Isolate migration work
3. **Execute phases 1-7** - Follow the order defined above
4. **Verify and deploy** - Ensure quality before merge

---

**Document Version:** 1.0
**Last Updated:** 2025-03-01
