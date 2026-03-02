# Fix Remaining Architecture Migration Issues

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the 3-layer architecture migration by fixing all remaining compilation errors, creating missing repository implementations, updating cubits to use repository interfaces, and ensuring the app compiles and runs.

**Architecture:** Fix imports, create AvatarRepositoryImpl and SettingsRepositoryImpl, update all cubits to inject repository interfaces via constructor, fix service locator registrations.

**Tech Stack:** Flutter 3.8+, Dart, freezed, fpdart, get_it, flutter_bloc

---

## Prerequisites

**Before starting:**

1. Verify current branch:
   ```bash
   git branch --show-current
   ```
   Expected: `refactor/architecture-standardization`

2. Check error count:
   ```bash
   flutter analyze 2>&1 | grep -c "error •"
   ```
   Note the number - we expect to reduce it to 0

---

## Task 1: Fix Imports in Core Model Files

**Goal:** Fix incorrect imports in lib/core/models/ files

**Files:**
- Modify: `lib/core/models/answer.dart`
- Modify: `lib/core/services/agent/yofardev_agent.dart`
- Modify: `lib/core/services/llm/fake_llm_service.dart`

**Step 1: Fix answer.dart imports**

Edit: `lib/core/models/answer.dart`

Change:
```dart
import 'avatar_config.dart';
```

To:
```dart
import '../../features/avatar/domain/models/avatar_config.dart';
```

**Step 2: Fix yofardev_agent.dart imports**

Edit: `lib/core/services/agent/yofardev_agent.dart`

Change:
```dart
import '../../features/chat/domain/models/chat.dart';
import '../../features/chat/domain/models/chat_entry.dart';
```

To:
```dart
import '../../../features/chat/domain/models/chat.dart';
import '../../../features/chat/domain/models/chat_entry.dart';
```

**Step 3: Fix fake_llm_service.dart imports**

Edit: `lib/core/services/llm/fake_llm_service.dart`

Change:
```dart
import '../../features/demo/domain/models/demo_script.dart';
```

To:
```dart
import '../../../../features/demo/domain/models/demo_script.dart';
```

**Step 4: Verify core files compile**

```bash
flutter analyze lib/core/models/ lib/core/services/
```

Expected: No import errors in core files

**Step 5: Commit**

```bash
git add lib/core/
git commit -m "fix: correct imports in core model and service files"
```

---

## Task 2: Fix Avatar Config Imports

**Goal:** Fix all imports in avatar_config.dart domain model

**Files:**
- Modify: `lib/features/avatar/domain/models/avatar_config.dart`

**Step 1: Update imports in avatar_config.dart**

Edit: `lib/features/avatar/domain/models/avatar_config.dart`

Change:
```dart
import 'chat.dart';
import 'sound_effects.dart';
import '../../features/sound/data/datasources/tts_datasource.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import '../utils/platform_utils.dart';
```

To:
```dart
import '../../../chat/domain/models/chat.dart';
import '../../../../core/models/sound_effects.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/platform_utils.dart';
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/avatar/domain/models/avatar_config.dart
```

Expected: No import errors (may still have EnumUtils issues - fixed in next task)

**Step 3: Commit**

```bash
git add lib/features/avatar/domain/models/
git commit -m "fix: correct imports in avatar_config.dart"
```

---

## Task 3: Add EnumUtils Extension

**Goal:** Create EnumUtils extension class used by avatar_config.dart

**Files:**
- Create: `lib/core/utils/enum_utils.dart`

**Step 1: Create EnumUtils class**

Create file: `lib/core/utils/enum_utils.dart`

```dart
/// Extension on Enum to provide utility methods
extension EnumUtils on Enum {
  /// Get the enum value name as a String
  String get name => toString().split('.').last;

  /// Convert string to enum value
  static T fromString<T extends Enum>(List<T> values, String name) {
    return values.firstWhere(
      (e) => e.name == name,
      orElse: () => values.first,
    );
  }

  /// Get all enum names
  static List<String> getAllNames<T extends Enum>(List<T> values) {
    return values.map((e) => e.name).toList();
  }
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/core/utils/enum_utils.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/core/utils/enum_utils.dart
git commit -m "feat: add EnumUtils extension for enum operations"
```

---

## Task 4: Fix Avatar Cubit Imports

**Goal:** Fix imports in avatar_cubit.dart and avatar_state.dart

**Files:**
- Modify: `lib/features/avatar/bloc/avatar_cubit.dart`
- Modify: `lib/features/avatar/bloc/avatar_state.dart`

**Step 1: Fix avatar_cubit.dart imports**

Edit: `lib/features/avatar/bloc/avatar_cubit.dart`

Change:
```dart
import '../../../core/models/avatar_config.dart';
import '../../../core/models/chat.dart';
import '../../../core/services/chat_history_service.dart';
```

To:
```dart
import '../domain/models/avatar_config.dart';
import '../../../chat/domain/models/chat.dart';
import '../../../chat/data/datasources/chat_local_datasource.dart';
```

**Step 2: Fix avatar_state.dart imports**

Edit: `lib/features/avatar/bloc/avatar_state.dart`

Change:
```dart
import '../../../core/models/avatar_config.dart';
```

To:
```dart
import '../../domain/models/avatar_config.dart';
```

**Step 3: Verify files compile**

```bash
flutter analyze lib/features/avatar/bloc/
```

Expected: Import errors fixed (may still have constructor issues)

**Step 4: Commit**

```bash
git add lib/features/avatar/bloc/
git commit -m "fix: correct imports in avatar cubit files"
```

---

## Task 5: Create AvatarRepositoryImpl

**Goal:** Create implementation for AvatarRepository interface

**Files:**
- Create: `lib/features/avatar/data/repositories/avatar_repository_impl.dart`

**Step 1: Create AvatarRepositoryImpl class**

Create file: `lib/features/avatar/data/repositories/avatar_repository_impl.dart`

```dart
import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../domain/models/avatar_config.dart';
import '../../../chat/domain/models/chat.dart';
import '../../../chat/data/datasources/chat_local_datasource.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final ChatLocalDatasource _chatDatasource = ChatLocalDatasource();

  @override
  Future<Either<Exception, Chat>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      if (chat == null) {
        return Left(Exception('Chat not found'));
      }
      return Right(chat);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/avatar/data/repositories/avatar_repository_impl.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/avatar/data/repositories/
git commit -m "feat: implement AvatarRepository"
```

---

## Task 6: Create SettingsRepositoryImpl

**Goal:** Create implementation for SettingsRepository interface

**Files:**
- Create: `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Step 1: Create SettingsRepositoryImpl class**

Create file: `lib/features/settings/data/repositories/settings_repository_impl.dart`

```dart
import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _datasource = SettingsLocalDatasource();

  @override
  Future<Either<Exception, String?>> getLanguage() async {
    try {
      final String? language = await _datasource.getLanguage();
      return Right(language);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    try {
      await _datasource.setLanguage(language);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    try {
      final bool enabled = await _datasource.getSoundEffects();
      return Right(enabled);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool enabled) async {
    try {
      await _datasource.setSoundEffects(enabled);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    try {
      final String? username = await _datasource.getUsername();
      return Right(username);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    try {
      await _datasource.setUsername(username);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    try {
      final String prompt = await _datasource.getSystemPrompt();
      return Right(prompt);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    try {
      await _datasource.setSystemPrompt(prompt);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }
}
```

**Step 2: Verify file compiles**

```bash
flutter analyze lib/features/settings/data/repositories/settings_repository_impl.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/settings/data/repositories/
git commit -m "feat: implement SettingsRepository"
```

---

## Task 7: Update ChatsCubit Constructor

**Goal:** Update ChatsCubit to use repository interfaces

**Files:**
- Modify: `lib/features/chat/bloc/chats_cubit.dart`

**Step 1: Read current ChatsCubit**

```bash
head -100 lib/features/chat/bloc/chats_cubit.dart
```

Note the current constructor signature

**Step 2: Update imports**

Edit: `lib/features/chat/bloc/chats_cubit.dart`

Add/modify imports:
```dart
import '../../domain/repositories/chat_repository.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
```

**Step 3: Update constructor**

Edit: `lib/features/chat/bloc/chats_cubit.dart`

Change constructor to:
```dart
class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AudioAnalyzer audioAnalyzer,
    required LocalizationManager localizationManager,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _audioAnalyzer = audioAnalyzer,
       _localizationManager = localizationManager,
       super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final AudioAnalyzer _audioAnalyzer;
  final LocalizationManager _localizationManager;
```

**Step 4: Update methods to unwrap Either**

Example method update:

Edit: `lib/features/chat/bloc/chats_cubit.dart`

Change methods like:
```dart
void createNewChat() async {
  emit(state.copyWith(status: ChatsStatus.updating));
  final result = await _chatRepository.createNewChat();
  result.fold(
    (error) {
      emit(state.copyWith(status: ChatsStatus.error, errorMessage: error.toString()));
    },
    (newChat) {
      emit(state.copyWith(
        status: ChatsStatus.success,
        chatsList: <Chat>[newChat, ...state.chatsList],
        currentChat: newChat,
        chatCreated: true,
      ));
      emit(state.copyWith(chatCreated: false));
    },
  );
}
```

Repeat for all repository method calls

**Step 5: Verify file compiles**

```bash
flutter analyze lib/features/chat/bloc/chats_cubit.dart
```

Expected: Constructor updated, methods use Either.fold

**Step 6: Commit**

```bash
git add lib/features/chat/bloc/chats_cubit.dart
git commit -m "refactor: update ChatsCubit to use repository interfaces"
```

---

## Task 8: Update AvatarCubit Constructor

**Goal:** Update AvatarCubit to use AvatarRepository interface

**Files:**
- Modify: `lib/features/avatar/bloc/avatar_cubit.dart`

**Step 1: Update imports**

Edit: `lib/features/avatar/bloc/avatar_cubit.dart`

Add:
```dart
import '../../domain/repositories/avatar_repository.dart';
import '../../../chat/data/datasources/chat_local_datasource.dart';
```

**Step 2: Update constructor**

Edit: `lib/features/avatar/bloc/avatar_cubit.dart`

Change constructor to:
```dart
class AvatarCubit extends Emit<AvatarState> {
  AvatarCubit({
    required AvatarRepository avatarRepository,
    required ChatLocalDatasource chatDatasource,
  }) : _avatarRepository = avatarRepository,
       _chatDatasource = chatDatasource,
       super(const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()));

  final AvatarRepository _avatarRepository;
  final ChatLocalDatasource _chatDatasource;
```

**Step 3: Update methods to unwrap Either**

Update methods to use repository and unwrap Either with fold

**Step 4: Verify file compiles**

```bash
flutter analyze lib/features/avatar/bloc/avatar_cubit.dart
```

Expected: Constructor updated, uses repository interface

**Step 5: Commit**

```bash
git add lib/features/avatar/bloc/avatar_cubit.dart
git commit -m "refactor: update AvatarCubit to use AvatarRepository interface"
```

---

## Task 9: Update SoundCubit Constructor

**Goal:** Update SoundCubit to use SoundRepository interface

**Files:**
- Modify: `lib/features/sound/bloc/sound_cubit.dart`

**Step 1: Update imports**

Edit: `lib/features/sound/bloc/sound_cubit.dart`

Add:
```dart
import '../../domain/repositories/sound_repository.dart';
```

**Step 2: Update constructor**

Edit: `lib/features/sound/bloc/sound_cubit.dart`

Change constructor to:
```dart
class SoundCubit extends Cubit<SoundState> {
  SoundCubit({
    required SoundRepository soundRepository,
  }) : _soundRepository = soundRepository,
       super(const SoundState(isSoundEffectsEnabled: false, isPlaying: false));

  final SoundRepository _soundRepository;
```

**Step 3: Update methods to unwrap Either**

Update play/stop methods to use repository and unwrap Either

**Step 4: Verify file compiles**

```bash
flutter analyze lib/features/sound/bloc/sound_cubit.dart
```

Expected: Uses SoundRepository interface

**Step 5: Commit**

```bash
git add lib/features/sound/bloc/sound_cubit.dart
git commit -m "refactor: update SoundCubit to use SoundRepository interface"
```

---

## Task 10: Update Remaining Cubits

**Goal:** Update DemoCubit, HomeCubit, and TalkingCubit if needed

**Files:**
- Modify: `lib/features/demo/bloc/demo_cubit.dart`
- Modify: `lib/features/home/bloc/home_cubit.dart` (if exists)
- Modify: `lib/features/talking/bloc/talking_cubit.dart`

**Step 1: Check each cubit**

```bash
grep -l "Service()" lib/features/*/bloc/*_cubit.dart
```

Identify which cubits still inject services directly

**Step 2: Update identified cubits**

For each cubit that needs updates:
- Update imports to include repository interfaces
- Update constructor to inject repositories
- Update methods to unwrap Either

**Step 3: Verify all cubits compile**

```bash
flutter analyze lib/features/*/bloc/
```

Expected: All cubits use repository interfaces

**Step 4: Commit**

```bash
git add lib/features/*/bloc/
git commit -m "refactor: update remaining cubits to use repository interfaces"
```

---

## Task 11: Update Service Locator Registrations

**Goal:** Fix service locator to use new constructors

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update ChatsCubit registration**

Edit: `lib/core/di/service_locator.dart`

Ensure registration is:
```dart
getIt.registerFactory<ChatsCubit>(
  () => ChatsCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    audioAnalyzer: getIt<AudioAnalyzer>(),
    localizationManager: getIt<LocalizationManager>(),
  ),
);
```

**Step 2: Update AvatarCubit registration**

Edit: `lib/core/di/service_locator.dart`

Ensure:
```dart
getIt.registerFactory<AvatarCubit>(
  () => AvatarCubit(
    avatarRepository: getIt<AvatarRepository>(),
    chatDatasource: getIt<ChatLocalDatasource>(),
  ),
);
```

**Step 3: Update SoundCubit registration**

Edit: `lib/core/di/service_locator.dart`

Ensure:
```dart
getIt.registerFactory<SoundCubit>(
  () => SoundCubit(
    soundRepository: getIt<SoundRepository>(),
  ),
);
```

**Step 4: Verify service locator compiles**

```bash
flutter analyze lib/core/di/service_locator.dart
```

Expected: No registration errors

**Step 5: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "fix: update service locator registrations"
```

---

## Task 12: Fix Remaining Import Errors

**Goal:** Fix any remaining import errors throughout codebase

**Step 1: Check for remaining errors**

```bash
flutter analyze 2>&1 | grep "uri_does_not_exist" | head -20
```

List remaining import errors

**Step 2: Fix each import error systematically**

For each error:
1. Identify the file with the bad import
2. Calculate correct relative path
3. Update the import
4. Verify fix

**Step 3: Run full analyze**

```bash
flutter analyze
```

Expected: No "uri_does_not_exist" errors

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix: resolve remaining import errors"
```

---

## Task 13: Regenerate Freezed Files

**Goal:** Regenerate freezed files after all code changes

**Step 1: Clean build**

```bash
flutter clean
```

Expected: Build cache cleared

**Step 2: Get dependencies**

```bash
flutter pub get
```

Expected: Dependencies resolved

**Step 3: Regenerate code**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: Freezed files generated successfully

**Step 4: Commit generated files**

```bash
git add lib/
git commit -m "chore: regenerate freezed files after architecture fixes"
```

---

## Task 14: Final Verification

**Goal:** Ensure entire codebase compiles without errors

**Step 1: Run full analysis**

```bash
flutter analyze
```

Expected: **No issues found!**

**Step 2: Try building**

```bash
flutter build apk --debug
```

OR for web:
```bash
flutter build web
```

Expected: Build succeeds

**Step 3: Count error reduction**

```bash
echo "Expected: 0 errors (down from 80+ at start)"
```

**Step 4: Final commit if needed**

```bash
git add -A
git commit -m "fix: final compilation fixes"
```

**Step 5: Merge to main**

```bash
git checkout main
git merge refactor/architecture-standardization
```

---

## Success Criteria

✅ `flutter analyze` passes with 0 errors
✅ `flutter build` succeeds
✅ All cubits use repository interfaces (not services directly)
✅ All repositories registered in service locator
✅ All imports use correct relative paths
✅ Freezed files regenerated
✅ All tests pass (if tests exist)

---

## Rollback Plan

If critical issues arise:

```bash
# Reset to before this fix plan
git log --oneline -5
git reset --hard <commit-before-fixes>

# OR start fresh branch
git checkout main
git checkout -b refactor/architecture-fixes-v2
```

---

**End of Implementation Plan**
