# Task 10: Widget Migration Plan - SoundService DI

**Date:** 2026-02-27
**Task:** Update Widget to Use DI
**Status:** Analysis Complete - No Widgets Found in Refactor Project

## Analysis Summary

### Current State

After thorough analysis of both the original and refactor codebases:

1. **Original Codebase (`yofardev_ai`):**
   - Found **1 file** using SoundService directly:
     - `/lib/logic/avatar/avatar_cubit.dart` (line 89)
     - Usage: `SoundService().playSoundEffect(SoundEffects.whoosh, volume: 0.4);`

2. **Refactor Codebase (`yofardev_ai-refactor`):**
   - **No widgets found** using SoundService directly in the UI layer
   - This is expected since widget implementations haven't been migrated yet
   - The refactor project has only the feature structure and DI setup in place

### Key Finding

The SoundService usage is in **AvatarCubit**, not in a widget. This is actually good architecture - business logic is in the BLoC/Cubit layer, not in widgets.

## Migration Plan

### Phase 1: Understanding the Architecture

**Current Implementation (Original):**
```dart
// In AvatarCubit
SoundService().playSoundEffect(SoundEffects.whoosh, volume: 0.4);
```

**Problem with Current Approach:**
1. Singleton pattern (`SoundService()`) makes testing difficult
2. Tight coupling to concrete implementation
3. Can't easily mock or swap implementations

**Target Implementation (Refactor):**
```dart
// In AvatarCubit (after migration)
class AvatarCubit extends Cubit<AvatarState> {
  final SoundCubit _soundCubit;

  AvatarCubit({required SoundCubit soundCubit})
      : _soundCubit = soundCubit,
        super(const AvatarState());

  void _dropAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    // Play whoosh sound effect when dropping starts
    await _soundCubit.playSound('whoosh', volume: 0.4);

    // ... rest of the animation logic
  }
}
```

### Phase 2: Implementation Steps

#### Step 1: Update SoundCubit Interface

The current `SoundCubit` needs to support the same interface as the original `SoundService`:

**Current SoundCubit:**
```dart
Future<void> playSound(String soundName);
```

**Needed Enhancement:**
The original `SoundService.playSoundEffect()` takes:
- `SoundEffects` enum
- Optional `volume` parameter

**Required Changes:**
1. Update `SoundCubit.playSound()` to accept volume parameter
2. Map sound effect names appropriately

#### Step 2: Create SoundService Implementation

Create the actual sound service implementation in the refactor project:

**File:** `/lib/features/sound/data/sound_service_impl.dart`

```dart
import 'package:just_audio/just_audio.dart';
import '../domain/sound_service.dart';

class SoundServiceImpl implements SoundService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playSound(String soundName, {double volume = 1.0}) async {
    try {
      final assetPath = 'assets/sound_effects/$soundName.wav';
      await _player.setAsset(assetPath);
      await _player.setVolume(volume);
      await _player.play();
    } catch (e) {
      // Silently fail if sound file doesn't exist or can't be played
    }
  }
}
```

#### Step 3: Register Services in DI

Update `/lib/core/di/service_locator.dart`:

```dart
Future<void> setupServiceLocator() async {
  // Services
  getIt.registerLazySingleton<SoundService>(() => SoundServiceImpl());

  // BLoCs
  getIt.registerFactory<SoundCubit>(() => SoundCubit(
    soundService: getIt<SoundService>(),
  ));
}
```

#### Step 4: Migrate AvatarCubit

When migrating the AvatarCubit to the refactor project:

**Before (Original):**
```dart
import '../../services/sound_service.dart';

class AvatarCubit extends Emititt<AvatarState> {
  AvatarCubit() : super(const AvatarState());

  void _dropAndComeBack(...) {
    SoundService().playSoundEffect(SoundEffects.whoosh, volume: 0.4);
    // ...
  }
}
```

**After (Refactor):**
```dart
import '../../features/sound/bloc/sound_cubit.dart';

class AvatarCubit extends Cubit<AvatarState> {
  final SoundCubit _soundCubit;

  AvatarCubit({required SoundCubit soundCubit})
      : _soundCubit = soundCubit,
        super(const AvatarState());

  void _dropAndComeBack(...) {
    _soundCubit.playSound('whoosh', volume: 0.4);
    // ...
  }
}
```

### Phase 3: Widget Integration Pattern

When widgets are eventually migrated, they should follow this pattern:

**Pattern 1: Direct Sound Playback in Widgets**

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SoundCubit>(),
      child: _MyWidgetContent(),
    );
  }
}

class _MyWidgetContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        context.read<SoundCubit>().playSound('click');
      },
      child: Text('Play Sound'),
    );
  }
}
```

**Pattern 2: Using SoundCubit in Other BLoCs/Cubits**

```dart
class AvatarCubit extends Cubit<AvatarState> {
  final SoundCubit _soundCubit;

  AvatarCubit({required SoundCubit soundCubit})
      : _soundCubit = soundCubit,
        super(const AvatarState());

  void someMethod() {
    _soundCubit.playSound('whoosh', volume: 0.4);
  }
}

// Registration
getIt.registerFactory<AvatarCubit>(() => AvatarCubit(
  soundCubit: getIt<SoundCubit>(),
));
```

## Migration Checklist

- [x] Analyze original codebase for SoundService usage
- [x] Identify all files that need migration (1 file found: AvatarCubit)
- [x] Document migration approach
- [ ] Implement SoundServiceImpl
- [ ] Update SoundCubit to support volume parameter
- [ ] Register services in DI container
- [ ] Migrate AvatarCubit (part of Task 12-20: Avatar Migration)
- [ ] Test sound playback functionality
- [ ] Update tests to use mocked SoundCubit

## Notes

1. **Why No Widgets Found:** The refactor project is in early stages. UI widgets haven't been migrated yet - only the feature structure and DI setup exist.

2. **Priority:** This task is about planning and setting up the pattern. The actual widget migration will happen during the feature migration tasks (Tasks 12-40).

3. **Good News:** The original codebase already has good separation of concerns - SoundService is only used in business logic (Cubit), not directly in widgets.

4. **Next Steps:**
   - Complete SoundService implementation
   - Update DI registration
   - The actual widget migration will occur during feature-specific migration tasks

## Commit Message for This Task

```
docs(sound): add widget migration plan for SoundService DI

- Documented analysis of SoundService usage in original codebase
- Found 1 usage in AvatarCubit (not directly in widgets)
- Created migration plan with implementation patterns
- Set up DI pattern guidelines for future widget migration
- No widgets found in refactor project (expected at this stage)

Next: Complete SoundService implementation during Avatar migration
```

## Files Created

- `/docs/plans/task-10-widget-migration-plan.md` (this file)

## References

- Original SoundService: `/lib/services/sound_service.dart`
- Original AvatarCubit: `/lib/logic/avatar/avatar_cubit.dart` (line 89)
- Refactor SoundCubit: `/lib/features/sound/bloc/sound_cubit.dart`
- Refactor DI Setup: `/lib/core/di/service_locator.dart`
