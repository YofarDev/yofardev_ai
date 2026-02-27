# Architecture Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor Yofardev AI Flutter app from layered architecture to feature-based architecture with proper DI, freezed models, and fixed anti-patterns.

**Architecture:** Feature-based organization with `lib/features/` structure, dependency injection via get_it, freezed for immutable models, and BLoC/Cubit for state management.

**Tech Stack:** Flutter, get_it (DI), freezed (code generation), flutter_bloc (state management)

**Design Document:** `docs/plans/2026-02-27-architecture-refactor-design.md`

---

## Phase 0: Foundation Setup

### Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add freezed dependencies to pubspec.yaml**

Add to `dependencies:` section:
```yaml
dependencies:
  # ... existing dependencies ...
  get_it: ^7.6.4
```

Add to `dev_dependencies:` section:
```yaml
dev_dependencies:
  # ... existing dependencies ...
  freezed: ^2.4.6
  freezed_annotation: ^2.4.1
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

**Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: All dependencies download successfully with no errors.

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(refactor): add freezed and get_it dependencies"
```

---

### Task 2: Create Core Directory Structure

**Files:**
- Create: `lib/core/di/service_locator.dart`

**Step 1: Create core DI directory**

```bash
mkdir -p lib/core/di
```

**Step 2: Create service locator setup file**

Create `lib/core/di/service_locator.dart`:
```dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services will be registered here in subsequent tasks
  // BLoCs will be registered as factories
}
```

**Step 3: Verify syntax**

```bash
flutter analyze lib/core/di/service_locator.dart
```

Expected: No errors.

**Step 4: Commit**

```bash
git add lib/core/di/
git commit -m "feat(refactor): create DI service locator foundation"
```

---

### Task 3: Initialize Service Locator in main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Read current main.dart**

```bash
cat lib/main.dart
```

Note the current app initialization.

**Step 2: Add service locator initialization**

Before `runApp()` call, add:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const YofardevApp());
}
```

**Step 3: Add import**

Add to imports:
```dart
import 'core/di/service_locator.dart';
```

**Step 4: Verify app runs**

```bash
flutter run -d macos
```

Expected: App launches without errors.

**Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(refactor): initialize service locator in main"
```

---

### Task 4: Create Feature Directory Structure

**Step 1: Create all feature directories**

```bash
mkdir -p lib/features/{sound,avatar,settings,demo,chat}/{bloc,screens,widgets}
```

**Step 2: Verify directories created**

```bash
tree lib/features/
```

Expected: All feature directories with bloc/, screens/, widgets/ subdirectories.

**Step 3: Add .gitkeep files**

```bash
touch lib/features/*/{bloc,screens,widgets}/.gitkeep
```

**Step 4: Commit**

```bash
git add lib/features/
git commit -m "feat(refactor): create feature directory structure"
```

---

## Phase 1: Sound Effects Migration

### Task 5: Write Tests for Current SoundService

**Files:**
- Create: `test/features/sound/sound_service_test.dart`
- Read: `lib/services/sound_service.dart`

**Step 1: Read current SoundService implementation**

```bash
cat lib/services/sound_service.dart
```

Note all public methods and their behavior.

**Step 2: Create test file**

Create `test/features/sound/sound_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/services/sound_service.dart';

void main() {
  late SoundService soundService;

  setUp(() {
    soundService = SoundService();
  });

  group('SoundService', () {
    test('should initialize without errors', () {
      expect(soundService, isNotNull);
    });

    test('playSound should complete without error', () async {
      // Add specific tests based on actual implementation
      await expectLater(
        soundService.playSound('test'),
        completes,
      );
    });
  });
}
```

**Step 3: Run tests to verify current behavior**

```bash
flutter test test/features/sound/sound_service_test.dart
```

Expected: Tests pass (baseline).

**Step 4: Commit**

```bash
git add test/features/sound/
git commit -m "test(sound): add baseline tests for SoundService"
```

---

### Task 6: Convert SoundEffects Model to Freezed

**Files:**
- Modify: `lib/models/sound_effects.dart`
- Create: `lib/core/models/sound_effects.dart` (new location)

**Step 1: Read current model**

```bash
cat lib/models/sound_effects.dart
```

**Step 2: Create freezed model in new location**

Create `lib/core/models/sound_effects.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_effects.freezed.dart';
part 'sound_effects.g.dart';

@freezed
class SoundEffect with _$SoundEffect {
  const factory SoundEffect({
    required String name,
    required String path,
    required double volume,
  }) = _SoundEffect;

  factory SoundEffect.fromJson(Map<String, dynamic> json) =>
      _$SoundEffectFromJson(json);
}
```

**Step 3: Run build runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates `.freezed.dart` and `.g.dart` files.

**Step 4: Update tests to use new model**

Update `test/features/sound/sound_service_test.dart`:
```dart
import 'package:yofardev_ai/core/models/sound_effects.dart';
```

**Step 5: Run tests**

```bash
flutter test test/features/sound/
```

**Step 6: Commit**

```bash
git add lib/core/models/sound_effects.dart
git add lib/core/models/sound_effects.freezed.dart
git add lib/core/models/sound_effects.g.dart
git commit -m "refactor(sound): convert SoundEffect to freezed"
```

---

### Task 7: Create Sound Feature Structure

**Files:**
- Create: `lib/features/sound/bloc/sound_cubit.dart`
- Create: `lib/features/sound/bloc/sound_state.dart`

**Step 1: Create sound state**

Create `lib/features/sound/bloc/sound_state.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class SoundState extends Equatable {
  const SoundState();

  @override
  List<Object?> get props => [];
}

class SoundInitial extends SoundState {
  const SoundInitial();
}

class SoundPlaying extends SoundState {
  final String soundName;
  const SoundPlaying(this.soundName);

  @override
  List<Object?> get props => [soundName];
}

class SoundError extends SoundState {
  final String message;
  const SoundError(this.message);

  @override
  List<Object?> get props => [message];
}
```

**Step 2: Create sound cubit**

Create `lib/features/sound/bloc/sound_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_state.dart';
import 'package:yofardev_ai/services/sound_service.dart';

class SoundCubit extends Cubit<SoundState> {
  final SoundService _soundService;

  SoundCubit({required SoundService soundService})
      : _soundService = soundService,
        super(const SoundInitial());

  Future<void> playSound(String soundName) async {
    try {
      emit(SoundPlaying(soundName));
      await _soundService.playSound(soundName);
      emit(const SoundInitial());
    } catch (e) {
      emit(SoundError(e.toString()));
    }
  }
}
```

**Step 3: Verify syntax**

```bash
flutter analyze lib/features/sound/
```

**Step 4: Commit**

```bash
git add lib/features/sound/
git commit -m "feat(sound): create SoundCubit with state"
```

---

### Task 8: Register SoundService and SoundCubit in DI

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update service locator**

Update `lib/core/di/service_locator.dart`:
```dart
import 'package:get_it/get_it.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_cubit.dart';
import 'package:yofardev_ai/services/sound_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  getIt.registerLazySingleton<SoundService>(() => SoundService());

  // BLoCs
  getIt.registerFactory<SoundCubit>(() => SoundCubit(
    soundService: getIt<SoundService>(),
  ));
}
```

**Step 2: Verify syntax**

```bash
flutter analyze lib/core/di/service_locator.dart
```

**Step 3: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(sound): register SoundService and SoundCubit in DI"
```

---

### Task 9: Update SoundCubit Tests

**Files:**
- Create: `test/features/sound/bloc/sound_cubit_test.dart`

**Step 1: Write cubit tests**

Create `test/features/sound/bloc/sound_cubit_test.dart`:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_cubit.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_state.dart';
import 'package:yofardev_ai/services/sound_service.dart';

@GenerateMocks([SoundService])
import 'sound_cubit_test.mocks.dart';

void main() {
  late MockSoundService mockSoundService;
  late SoundCubit cubit;

  setUp(() {
    mockSoundService = MockSoundService();
    cubit = SoundCubit(soundService: mockSoundService);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state is SoundInitial', () {
    expect(cubit.state, equals(const SoundInitial()));
  });

  blocTest<SoundCubit, SoundState>(
    'emits [SoundPlaying, SoundInitial] when playSound succeeds',
    build: () {
      when(() => mockSoundService.playSound('test'))
          .thenAnswer((_) async {});
      return cubit;
    },
    act: (cubit) => cubit.playSound('test'),
    expect: () => [
      const SoundPlaying('test'),
      const SoundInitial(),
    ],
  );

  blocTest<SoundCubit, SoundState>(
    'emits SoundError when playSound fails',
    build: () {
      when(() => mockSoundService.playSound('test'))
          .thenThrow(Exception('Sound not found'));
      return cubit;
    },
    act: (cubit) => cubit.playSound('test'),
    expect: () => [
      const SoundPlaying('test'),
      const SoundError('Exception: Sound not found'),
    ],
  );
}
```

**Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 3: Run tests**

```bash
flutter test test/features/sound/bloc/sound_cubit_test.dart
```

**Step 4: Commit**

```bash
git add test/features/sound/bloc/
git commit -m "test(sound): add SoundCubit tests"
```

---

### Task 10: Update Widget to Use DI

**Files:**
- Find and modify widgets that use SoundService directly

**Step 1: Find widgets using SoundService**

```bash
grep -r "SoundService" lib/ui/widgets/ lib/ui/pages/
```

**Step 2: For each widget found, update to use BlocProvider**

Example update pattern:
```dart
// Before
final soundService = SoundService();
await soundService.playSound('click');

// After
BlocProvider(
  create: (_) => getIt<SoundCubit>(),
  child: MyWidget(),
);

// In widget
context.read<SoundCubit>().playSound('click');
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

**Step 4: Run app to verify**

```bash
flutter run -d macos
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(sound): update widgets to use DI"
```

---

### Task 11: Sound Migration Completion

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

**Step 3: Manual smoke test**

Open app, verify sound effects still work.

**Step 4: Create checkpoint tag**

```bash
git tag -a refactor/sound-complete -m "Sound feature migration complete"
git push origin refactor/sound-complete
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(soundation): complete sound feature migration"
```

---

## Phase 2: Avatar Migration

### Task 12: Analyze Current Avatar Implementation

**Files:**
- Read: `lib/logic/avatar/avatar_cubit.dart`
- Read: `lib/logic/avatar/avatar_state.dart`
- Read: `lib/ui/widgets/avatar/avatar_widgets.dart`

**Step 1: Read existing files**

```bash
cat lib/logic/avatar/avatar_cubit.dart
cat lib/logic/avatar/avatar_state.dart
cat lib/ui/widgets/avatar/avatar_widgets.dart
```

Note: Current implementation, state structure, dependencies.

**Step 2: Count lines**

```bash
wc -l lib/logic/avatar/*.dart lib/ui/widgets/avatar/*.dart
```

**Step 3: Document current structure**

Create `docs/plans/avatar-current-state.md` with notes about current implementation.

**Step 4: Commit**

```bash
git add docs/plans/avatar-current-state.md
git commit -m "docs(avatar): document current implementation"
```

---

### Task 13: Write Avatar Tests (Baseline)

**Files:**
- Create: `test/features/avatar/avatar_cubit_test.dart`

**Step 1: Create baseline test file**

Create `test/features/avatar/avatar_cubit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/logic/avatar/avatar_cubit.dart';
import 'package:yofardev_ai/logic/avatar/avatar_state.dart';

void main() {
  late AvatarCubit cubit;

  setUp(() {
    // Initialize with current dependencies
    cubit = AvatarCubit();
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state is correct', () {
    expect(cubit.state, isA<AvatarInitial>());
  });

  // Add tests for all public methods based on current implementation
}
```

**Step 2: Run tests**

```bash
flutter test test/features/avatar/avatar_cubit_test.dart
```

**Step 3: Commit**

```bash
git add test/features/avatar/
git commit -m "test(avatar): add baseline tests"
```

---

### Task 14: Extract AvatarState to Separate File

**Files:**
- Modify: `lib/logic/avatar/avatar_state.dart` (if inline, extract)
- Create: `lib/features/avatar/bloc/avatar_state.dart`

**Step 1: Read current state**

```bash
cat lib/logic/avatar/avatar_state.dart
```

**Step 2: Create new state file in feature structure**

Create `lib/features/avatar/bloc/avatar_state.dart`:
```dart
import 'package:equatable/equatable.dart';

// Copy current state classes here
// Ensure all states extend Equatable
```

**Step 3: Verify syntax**

```bash
flutter analyze lib/features/avatar/bloc/avatar_state.dart
```

**Step 4: Commit**

```bash
git add lib/features/avatar/bloc/
git commit -m "refactor(avatar): create separate state file"
```

---

### Task 15: Migrate AvatarCubit to New Location

**Files:**
- Create: `lib/features/avatar/bloc/avatar_cubit.dart`

**Step 1: Create new cubit**

Create `lib/features/avatar/bloc/avatar_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_state.dart';
// Add other imports

class AvatarCubit extends Cubit<AvatarState> {
  // Copy implementation from old location
  // Update to use injected dependencies
}
```

**Step 2: Update imports in old location temporarily**

Update `lib/logic/avatar/avatar_cubit.dart`:
```dart
// Re-export from new location
export 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
```

**Step 3: Verify tests still pass**

```bash
flutter test test/features/avatar/
```

**Step 4: Commit**

```bash
git add lib/features/avatar/bloc/avatar_cubit.dart
git add lib/logic/avatar/avatar_cubit.dart
git commit -m "refactor(avatar): migrate cubit to feature structure"
```

---

### Task 16: Convert Avatar Models to Freezed

**Files:**
- Modify: `lib/models/avatar.dart`
- Create: `lib/core/models/avatar_config.dart`

**Step 1: Read current avatar model**

```bash
cat lib/models/avatar.dart
```

**Step 2: Create freezed model**

Create `lib/core/models/avatar_config.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'avatar_config.freezed.dart';
part 'avatar_config.g.dart';

@freezed
class AvatarConfig with _$AvatarConfig {
  const factory AvatarConfig({
    required String id,
    required String name,
    required String imageUrl,
    @Default(1.0) double scale,
  }) = _AvatarConfig;

  factory AvatarConfig.fromJson(Map<String, dynamic> json) =>
      _$AvatarConfigFromJson(json);
}
```

**Step 3: Run build runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 4: Commit**

```bash
git add lib/core/models/avatar_config.dart
git add lib/core/models/avatar_config.*.dart
git commit -m "refactor(avatar): convert models to freezed"
```

---

### Task 17: Register Avatar in DI

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update service locator**

Update `lib/core/di/service_locator.dart`:
```dart
// Add imports
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/repositories/yofardev_repository.dart';

Future<void> setupServiceLocator() async {
  // ... existing registrations ...

  // BLoCs
  getIt.registerFactory<AvatarCubit>(() => AvatarCubit(
    repository: getIt<YofardevRepository>(),
  ));
}
```

**Step 2: Verify syntax**

```bash
flutter analyze
```

**Step 3: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(avatar): register AvatarCubit in DI"
```

---

### Task 18: Split Oversized Avatar Widgets

**Files:**
- Read: `lib/ui/widgets/avatar/avatar_widgets.dart`
- Create: `lib/features/avatar/widgets/`

**Step 1: Check line count**

```bash
wc -l lib/ui/widgets/avatar/*.dart
```

**Step 2: Extract sub-widgets**

For files > 300 lines, extract:
- `lib/features/avatar/widgets/talking_mouth_animation.dart`
- `lib/features/avatar/widgets/avatar_display.dart`
- `lib/features/avatar/widgets/avatar_controls.dart`

**Step 3: Update imports**

Update references to use new widget locations.

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

**Step 5: Commit**

```bash
git add lib/features/avatar/widgets/
git commit -m "refactor(avatar): extract oversized widgets"
```

---

### Task 19: Fix Navigation Anti-patterns in Avatar

**Files:**
- Find and modify avatar widgets with navigation in build()

**Step 1: Find navigation in build**

```bash
grep -r "Navigator.of" lib/ui/widgets/avatar/
```

**Step 2: Refactor to BlocListener**

Example fix:
```dart
// Before
BlocBuilder<AvatarCubit, AvatarState>(
  builder: (context, state) {
    if (state is AvatarNavigated) {
      Navigator.push(...); // BAD
    }
    return ...;
  },
)

// After
BlocListener<AvatarCubit, AvatarState>(
  listener: (context, state) {
    if (state is AvatarNavigated) {
      Navigator.push(...);
    }
  },
  child: BlocBuilder<AvatarCubit, AvatarState>(
    builder: (context, state) => ...,
  ),
)
```

**Step 3: Commit**

```bash
git add -A
git commit -m "fix(avatar): remove navigation from build methods"
```

---

### Task 20: Avatar Migration Completion

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

**Step 3: Manual smoke test**

Open app, verify avatar functionality.

**Step 4: Create checkpoint tag**

```bash
git tag -a refactor/avatar-complete -m "Avatar feature migration complete"
git push origin refactor/avatar-complete
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(avatar): complete avatar feature migration"
```

---

## Phase 3: Settings Migration

### Task 21: Analyze Settings Implementation

**Files:**
- Read: `lib/ui/pages/settings/settings_page.dart`
- Read: `lib/ui/pages/settings/llm/llm_config_page.dart`

**Step 1: Analyze structure**

```bash
find lib/ui/pages/settings/ -name "*.dart" -exec wc -l {} \;
```

**Step 2: Document findings**

Create `docs/plans/settings-current-state.md`.

**Step 3: Commit**

```bash
git add docs/plans/settings-current-state.md
git commit -m "docs(settings): document current implementation"
```

---

### Task 22: Create Settings Feature Structure

**Files:**
- Create: `lib/features/settings/bloc/settings_cubit.dart`
- Create: `lib/features/settings/bloc/settings_state.dart`
- Create: `lib/features/settings/bloc/llm_config_cubit.dart`
- Create: `lib/features/settings/bloc/llm_config_state.dart`

**Step 1: Create settings state**

Create `lib/features/settings/bloc/settings_state.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  final LlmConfig llmConfig;
  const SettingsLoaded(this.llmConfig);

  @override
  List<Object?> get props => [llmConfig];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
```

**Step 2: Create settings cubit**

Create `lib/features/settings/bloc/settings_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/features/settings/bloc/settings_state.dart';
import 'package:yofardev_ai/repositories/yofardev_repository.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final YofardevRepository _repository;

  SettingsCubit({required YofardevRepository repository})
      : _repository = repository,
        super(const SettingsInitial());

  Future<void> loadSettings() async {
    try {
      emit(const SettingsLoading());
      final config = await _repository.getLlmConfig();
      emit(SettingsLoaded(config));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> updateLlmConfig(LlmConfig config) async {
    try {
      await _repository.saveLlmConfig(config);
      emit(SettingsLoaded(config));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }
}
```

**Step 3: Verify syntax**

```bash
flutter analyze lib/features/settings/
```

**Step 4: Commit**

```bash
git add lib/features/settings/bloc/
git commit -m "feat(settings): create settings cubit and state"
```

---

### Task 23: Convert LlmConfig to Freezed

**Files:**
- Modify: `lib/models/llm/llm_config.dart`
- Create: `lib/core/models/llm_config.dart`

**Step 1: Read current config**

```bash
cat lib/models/llm/llm_config.dart
```

**Step 2: Create freezed model**

Create `lib/core/models/llm_config.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_config.freezed.dart';
part 'llm_config.g.dart';

@freezed
class LlmConfig with _$LlmConfig {
  const factory LlmConfig({
    required String provider,
    required String apiKey,
    required String model,
    @Default(0.7) double temperature,
    @Default(2000) int maxTokens,
  }) = _LlmConfig;

  factory LlmConfig.fromJson(Map<String, dynamic> json) =>
      _$LlmConfigFromJson(json);
}
```

**Step 3: Run build runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 4: Commit**

```bash
git add lib/core/models/llm_config.dart
git add lib/core/models/llm_config.*.dart
git commit -m "refactor(settings): convert LlmConfig to freezed"
```

---

### Task 24: Split Oversized Settings Screens

**Files:**
- Modify: `lib/ui/pages/settings/settings_page.dart`
- Create: `lib/features/settings/screens/settings_page.dart`
- Create: `lib/features/settings/widgets/`

**Step 1: Check line counts**

```bash
wc -l lib/ui/pages/settings/*.dart
```

**Step 2: Extract widgets**

For screens > 300 lines, extract sub-widgets:
- `lib/features/settings/widgets/settings_section.dart`
- `lib/features/settings/widgets/llm_config_card.dart`
- `lib/features/settings/widgets/debug_options_card.dart`

**Step 3: Create new screen**

Create `lib/features/settings/screens/settings_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/features/settings/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/widgets/settings_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>()..loadSettings(),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SettingsError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is SettingsLoaded) {
            return ListView(
              children: [
                SettingsSection(config: state.llmConfig),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add lib/features/settings/
git commit -m "refactor(settings): split screens and widgets"
```

---

### Task 25: Fix Navigation in Settings

**Files:**
- Modify: Settings widgets with navigation in build()

**Step 1: Find navigation issues**

```bash
grep -r "Navigator" lib/ui/pages/settings/
```

**Step 2: Fix with BlocListener pattern**

Same pattern as Task 19.

**Step 3: Commit**

```bash
git add -A
git commit -m "fix(settings): remove navigation from build methods"
```

---

### Task 26: Register Settings in DI

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update service locator**

Add:
```dart
getIt.registerFactory<SettingsCubit>(() => SettingsCubit(
  repository: getIt<YofardevRepository>(),
));
```

**Step 2: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(settings): register in DI"
```

---

### Task 27: Settings Migration Completion

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

**Step 3: Manual smoke test**

Open app, verify settings functionality.

**Step 4: Create checkpoint tag**

```bash
git tag -a refactor/settings-complete -m "Settings feature migration complete"
git push origin refactor/settings-complete
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(settings): complete settings feature migration"
```

---

## Phase 4: Demo Migration

### Task 28: Analyze Demo Implementation

**Files:**
- Read: `lib/services/demo_service.dart`
- Read: `lib/services/fake_llm_service.dart`

**Step 1: Analyze demo structure**

```bash
find lib -name "*demo*" -o -name "*fake*" | grep -v ".dart_tool"
```

**Step 2: Document decision**

Create `docs/plans/demo-decision.md` documenting whether demo stays in production or becomes dev-only.

**Step 3: Commit**

```bash
git add docs/plans/demo-decision.md
git commit -m "docs(demo): document demo feature decision"
```

---

### Task 29: Consolidate LLM Services

**Files:**
- Create: `lib/core/services/llm/llm_service_interface.dart`
- Modify: `lib/services/llm_service.dart`
- Modify: `lib/services/fake_llm_service.dart`

**Step 1: Create interface**

Create `lib/core/services/llm/llm_service_interface.dart`:
```dart
abstract class LlmServiceInterface {
  Future<String> completeChat(List<ChatEntry> messages);
  Stream<String> streamChat(List<ChatEntry> messages);
}
```

**Step 2: Implement interface**

Update both services to implement the interface.

**Step 3: Register in DI**

Update `lib/core/di/service_locator.dart`:
```dart
getIt.registerLazySingleton<LlmServiceInterface>(
  () => kDebugMode ? FakeLlmService() : LlmService(),
);
```

**Step 4: Commit**

```bash
git add lib/core/services/llm/
git commit -m "refactor(llm): consolidate services with interface"
```

---

### Task 30: Migrate Demo Feature

**Files:**
- Create: `lib/features/demo/`

**Step 1: Create demo structure**

```bash
mkdir -p lib/features/demo/{bloc,screens,widgets}
```

**Step 2: Migrate demo cubit**

Create `lib/features/demo/bloc/demo_cubit.dart` using same migration pattern as previous features.

**Step 3: Migrate demo widgets**

Extract to `lib/features/demo/widgets/`.

**Step 4: Register in DI**

Update service locator.

**Step 5: Commit**

```bash
git add lib/features/demo/
git add lib/core/di/service_locator.dart
git commit -m "feat(demo): migrate demo feature"
```

---

### Task 31: Demo Migration Completion

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

**Step 3: Create checkpoint tag**

```bash
git tag -a refactor/demo-complete -m "Demo feature migration complete"
git push origin refactor/demo-complete
```

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(demo): complete demo feature migration"
```

---

## Phase 5: Chat Migration (Most Complex)

### Task 32: Analyze Chat Implementation

**Files:**
- Read: `lib/logic/chat/chats_cubit.dart`
- Read: `lib/ui/pages/chat/chat_details_page.dart`
- Read: `lib/ui/widgets/ai_text_input.dart`

**Step 1: Check file sizes**

```bash
wc -l lib/logic/chat/*.dart lib/ui/pages/chat/*.dart lib/ui/widgets/ai_text_input.dart
```

**Step 2: Document dependencies**

Create `docs/plans/chat-dependencies.md`.

**Step 3: Commit**

```bash
git add docs/plans/chat-dependencies.md
git commit -m "docs(chat): document chat implementation"
```

---

### Task 33: Write Chat Tests (Baseline)

**Files:**
- Create: `test/features/chat/chats_cubit_test.dart`

**Step 1: Create comprehensive baseline tests**

Create test file covering all chat functionality.

**Step 2: Run tests**

```bash
flutter test test/features/chat/
```

**Step 3: Commit**

```bash
git add test/features/chat/
git commit -m "test(chat): add baseline tests"
```

---

### Task 34: Split ai_text_input.dart (357 lines)

**Files:**
- Create: `lib/features/chat/widgets/speech_input_button.dart`
- Create: `lib/features/chat/widgets/text_input_field.dart`
- Create: `lib/features/chat/widgets/image_picker_button.dart`
- Create: `lib/features/chat/widgets/ai_text_input.dart` (coordinator)

**Step 1: Extract speech input widget**

Create `lib/features/chat/widgets/speech_input_button.dart` (~60 lines):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Implement speech input logic
```

**Step 2: Extract text input widget**

Create `lib/features/chat/widgets/text_input_field.dart` (~80 lines):
```dart
import 'package:flutter/material.dart';
// Implement text field with submission logic
```

**Step 3: Extract image picker widget**

Create `lib/features/chat/widgets/image_picker_button.dart` (~50 lines):
```dart
import 'package:flutter/material.dart';
// Implement image picking logic
```

**Step 4: Create coordinator widget**

Create `lib/features/chat/widgets/ai_text_input.dart` (~50 lines):
```dart
import 'package:flutter/material.dart';
import 'package:yofardev_ai/features/chat/widgets/speech_input_button.dart';
import 'package:yofardev_ai/features/chat/widgets/text_input_field.dart';
import 'package:yofardev_ai/features/chat/widgets/image_picker_button.dart';

class AiTextInput extends StatelessWidget {
  const AiTextInput({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SpeechInputButton(),
        Expanded(child: TextInputField()),
        ImagePickerButton(),
      ],
    );
  }
}
```

**Step 5: Verify each widget works**

```bash
flutter analyze lib/features/chat/widgets/
```

**Step 6: Commit**

```bash
git add lib/features/chat/widgets/
git commit -m "refactor(chat): split ai_text_input into focused widgets"
```

---

### Task 35: Split chat_details_page.dart (402 lines)

**Files:**
- Create: `lib/features/chat/screens/chat_details_page.dart`
- Create: `lib/features/chat/widgets/message_bubble.dart`
- Create: `lib/features/chat/widgets/message_list.dart`
- Create: `lib/features/chat/widgets/chat_app_bar.dart`

**Step 1: Extract message building logic**

Create `lib/features/chat/widgets/message_bubble.dart` for individual message display.

**Step 2: Extract message list**

Create `lib/features/chat/widgets/message_list.dart` for the list view.

**Step 3: Extract app bar**

Create `lib/features/chat/widgets/chat_app_bar.dart`.

**Step 4: Create simplified screen**

Create `lib/features/chat/screens/chat_details_page.dart` (~150 lines):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/features/chat/widgets/chat_app_bar.dart';
import 'package:yofardev_ai/features/chat/widgets/message_list.dart';
import 'package:yofardev_ai/features/chat/widgets/ai_text_input.dart';

class ChatDetailsPage extends StatelessWidget {
  final String chatId;
  const ChatDetailsPage({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(chatId: chatId),
      body: Column(
        children: [
          Expanded(child: MessageList(chatId: chatId)),
          const AiTextInput(),
        ],
      ),
    );
  }
}
```

**Step 5: Commit**

```bash
git add lib/features/chat/
git commit -m "refactor(chat): split chat_details_page into components"
```

---

### Task 36: Fix Navigation in Chat

**Files:**
- Modify: `lib/features/chat/screens/chat_details_page.dart`

**Step 1: Add BlocListener for navigation**

```dart
BlocListener<ChatsCubit, ChatsState>(
  listener: (context, state) {
    if (state is ChatDeleted) {
      Navigator.of(context).pop();
    } else if (state is ChatError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  child: // existing builder
)
```

**Step 2: Commit**

```bash
git add lib/features/chat/screens/
git commit -m "fix(chat): move navigation to BlocListener"
```

---

### Task 37: Migrate ChatsCubit

**Files:**
- Create: `lib/features/chat/bloc/chats_cubit.dart`
- Create: `lib/features/chat/bloc/chat_state.dart`

**Step 1: Create separate state file**

Create `lib/features/chat/bloc/chat_state.dart` with all chat states.

**Step 2: Migrate cubit**

Create `lib/features/chat/bloc/chats_cubit.dart` in new location.

**Step 3: Update imports**

**Step 4: Commit**

```bash
git add lib/features/chat/bloc/
git commit -m "refactor(chat): migrate cubit to feature structure"
```

---

### Task 38: Convert ChatEntry to Freezed

**Files:**
- Modify: `lib/models/chat_entry.dart`
- Create: `lib/features/chat/models/chat_entry.dart`

**Step 1: Create freezed model with union types**

Create `lib/features/chat/models/chat_entry.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_entry.freezed.dart';
part 'chat_entry.g.dart';

@freezed
class ChatEntry with _$ChatEntry {
  const factory ChatEntry.text({
    required String id,
    required String content,
    required String role,
    DateTime? timestamp,
  }) = ChatEntryText;

  const factory ChatEntry.image({
    required String id,
    required String imageUrl,
    required String role,
    DateTime? timestamp,
  }) = ChatEntryImage;

  const factory ChatEntry.toolCall({
    required String id,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) = ChatEntryToolCall;

  factory ChatEntry.fromJson(Map<String, dynamic> json) =>
      _$ChatEntryFromJson(json);
}
```

**Step 2: Run build runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 3: Update all references**

```bash
grep -r "ChatEntry" lib/ --include="*.dart" | grep import
```

Update imports to new location.

**Step 4: Commit**

```bash
git add lib/features/chat/models/
git commit -m "refactor(chat): convert ChatEntry to freezed with union types"
```

---

### Task 39: Register Chat in DI

**Files:**
- Modify: `lib/core/di/service_locator.dart`

**Step 1: Update service locator**

Add:
```dart
getIt.registerFactory<ChatsCubit>(() => ChatsCubit(
  repository: getIt<YofardevRepository>(),
));
```

**Step 2: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(chat): register ChatsCubit in DI"
```

---

### Task 40: Chat Migration Completion

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

**Step 3: Run integration test**

```bash
flutter test integration_test/chat_flow_test.dart
```

**Step 4: Manual smoke test**

Open app, test full chat flow.

**Step 5: Create checkpoint tag**

```bash
git tag -a refactor/chat-complete -m "Chat feature migration complete"
git push origin refactor/chat-complete
```

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor(chat): complete chat feature migration"
```

---

## Phase 6: Cleanup

### Task 41: Remove Old Structure

**Step 1: Verify new structure works**

```bash
flutter run -d macos
```

Test all features thoroughly.

**Step 2: Remove old directories**

```bash
rm -rf lib/logic/
rm -rf lib/ui/
```

**Step 3: Update any remaining imports**

```bash
grep -r "import 'package:yofardev_ai/logic/" lib/
grep -r "import 'package:yofardev_ai/ui/" lib/
```

Update to new paths.

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(cleanup): remove old directory structure"
```

---

### Task 42: Final Code Quality

**Step 1: Run dart fix**

```bash
dart apply --fix .
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Fix any issues.

**Step 3: Format all code**

```bash
dart format .
```

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(cleanup): apply code fixes and formatting"
```

---

### Task 43: Update All Tests

**Step 1: Run full test suite**

```bash
flutter test
```

**Step 2: Fix any failing tests**

Update tests to use new structure.

**Step 3: Ensure 100% of tests pass**

```bash
flutter test --coverage
```

**Step 4: Commit**

```bash
git add -A
git commit -m "test(refactor): update all tests for new structure"
```

---

### Task 44: Final Verification

**Step 1: Run app on all platforms**

```bash
flutter run -d macos
flutter run -d android
flutter run -d ios
```

**Step 2: Manual feature checklist**

- [ ] Sound effects work
- [ ] Avatar animates correctly
- [ ] Settings save/load
- [ ] Demo mode works (if kept)
- [ ] Chat full flow works
- [ ] All navigation works
- [ ] No console errors

**Step 3: Create final tag**

```bash
git tag -a refactor/complete -m "Architecture refactor complete"
git push origin refactor/complete
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "refactor: complete architecture refactor

- Migrated from layered to feature-based architecture
- Added dependency injection with get_it
- Converted all models to freezed
- Fixed all navigation anti-patterns
- Split all oversized files
- Achieved target architecture from design doc

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Completion Checklist

- [ ] Phase 0: Foundation complete
- [ ] Phase 1: Sound migrated
- [ ] Phase 2: Avatar migrated
- [ ] Phase 3: Settings migrated
- [ ] Phase 4: Demo migrated
- [ ] Phase 5: Chat migrated
- [ ] Phase 6: Cleanup complete
- [ ] All tests pass
- [ ] No analyzer errors
- [ ] Manual verification complete
- [ ] All checkpoints tagged

---

**Total Estimated Timeline:** 6-8 weeks

**Risk Level:** Low (incremental, tested, reversible)

**Rollback:** Can revert to any checkpoint tag if issues arise
