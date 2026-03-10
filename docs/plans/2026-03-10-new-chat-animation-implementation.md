# New Chat Creation Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a coordinated animation sequence (avatar drop, background slide, avatar rise) when a user creates a new chat.

**Architecture:** Shared service in `core/services/` coordinates animations between chat and avatar features without cross-feature imports. Uses freezed for immutable state and get_it for DI.

**Tech Stack:** Flutter, flutter_bloc, freezed, get_it, AnimatedSwitcher

**Prerequisites:**
- Read `flutter-architecture` skill for project structure
- Read `flutter-testing` skill for testing patterns

---

## Task 1: Add BackgroundTransition enum to AvatarState

**Files:**
- Modify: `lib/features/avatar/presentation/bloc/avatar_state.dart`

**Step 1: Add the BackgroundTransition enum**

Add the new enum above the `AvatarState` class definition:

```dart
enum BackgroundTransition {
  none,
  sliding,
}
```

**Step 2: Add backgroundTransition field to AvatarState**

In the `@freezed` class factory, add the new field:

```dart
@freezed
class AvatarState with _$AvatarState {
  const factory AvatarState({
    // ... existing fields
    @Default(BackgroundTransition.none) BackgroundTransition backgroundTransition,
  }) = _AvatarState;
  // ... rest of class
}
```

**Step 3: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `avatar_state.freezed.dart` updated successfully

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/avatar/presentation/bloc/avatar_state.dart
git add lib/features/avatar/presentation/bloc/avatar_state.freezed.dart
git commit -m "feat: add BackgroundTransition enum to AvatarState"
```

---

## Task 2: Add onBackgroundTransitionChanged method to AvatarCubit

**Files:**
- Modify: `lib/features/avatar/presentation/bloc/avatar_cubit.dart`
- Test: `test/features/avatar/avatar_cubit_test.dart`

**Step 1: Write the failing test**

Add to `test/features/avatar/avatar_cubit_test.dart`:

```dart
group('onBackgroundTransitionChanged', () {
  test('should update backgroundTransition state', () {
    // Arrange
    const expectedTransition = BackgroundTransition.sliding;

    // Act
    cubit.onBackgroundTransitionChanged(expectedTransition);

    // Assert
    expect(cubit.state.backgroundTransition, expectedTransition);
  });

  test('should emit state with new backgroundTransition', () {
    // Arrange
    const expectedTransition = BackgroundTransition.sliding;
    final expectedStates = [
      AvatarState(
        avatar: const Avatar(),
        avatarConfig: const AvatarConfig(),
        backgroundTransition: expectedTransition,
      ),
    ];

    // Act
    final later = cubit.stream.skip(1).take(1);

    // Assert
    expect(later, emitsInOrder(expectedStates));
    cubit.onBackgroundTransitionChanged(expectedTransition);
  });
});
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/avatar/avatar_cubit_test.dart
```

Expected: FAIL with "method not found"

**Step 3: Write minimal implementation**

Add to `lib/features/avatar/presentation/bloc/avatar_cubit.dart`:

```dart
void onBackgroundTransitionChanged(BackgroundTransition transition) {
  _emitIfOpen(state.copyWith(backgroundTransition: transition));
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/avatar/avatar_cubit_test.dart
```

Expected: PASS

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/avatar/presentation/bloc/avatar_cubit.dart
git add test/features/avatar/avatar_cubit_test.dart
git commit -m "feat: add onBackgroundTransitionChanged to AvatarCubit"
```

---

## Task 3: Create AnimatedBackgroundAvatar widget

**Files:**
- Create: `lib/features/avatar/widgets/animated_background_avatar.dart`
- Test: `test/features/avatar/widgets/animated_background_avatar_test.dart`

**Step 1: Write the widget test**

Create `test/features/avatar/widgets/animated_background_avatar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/avatar/widgets/animated_background_avatar.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';

void main() {
  group('AnimatedBackgroundAvatar', () {
    late AvatarCubit avatarCubit;

    setUp(() {
      avatarCubit = AvatarCubit(MockAvatarRepository());
      avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
    });

    tearDown(() {
      avatarCubit.close();
    });

    Widget makeTestableWidget() {
      return BlocProvider<AvatarCubit>.value(
        value: avatarCubit,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: AnimatedBackgroundAvatar(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders Image.asset with background path',
        (tester) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());

      // Assert
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('uses AnimatedSwitcher for transitions',
        (tester) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());

      // Assert
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('rebuilds when background changes', (tester) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());
      final initialImage = tester.widget<Image>(find.byType(Image));

      // Act
      avatarCubit.loadAvatar('test-chat');
      await tester.pumpAndSettle();

      // Assert - new image with different key
      final newImage = tester.widget<Image>(find.byType(Image));
      expect(
        (initialImage.image as AssetImage).assetName,
        isNot(
          (newImage.image as AssetImage).assetName,
        ),
      );
    });
  });
}

// Mock repository for testing
class MockAvatarRepository implements AvatarRepository {
  @override
  Future<Either<Exception, Avatar>> getAvatar(String chatId) async {
    return Right(const Avatar(background: AvatarBackgrounds.beach));
  }

  @override
  Future<void> updateAvatar(String chatId, Avatar avatar) async {
    // Mock implementation
  }

  @override
  Future<void> clearCache() async {
    // Mock implementation
  }
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/avatar/widgets/animated_background_avatar_test.dart
```

Expected: FAIL with "widget not found"

**Step 3: Write minimal implementation**

Create `lib/features/avatar/widgets/animated_background_avatar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/res/app_constants.dart';
import '../presentation/bloc/avatar_cubit.dart';
import '../presentation/bloc/avatar_state.dart';

class AnimatedBackgroundAvatar extends StatelessWidget {
  const AnimatedBackgroundAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      buildWhen: (AvatarState previous, AvatarState current) =>
          previous.avatar.background != current.avatar.background ||
          previous.backgroundTransition != current.backgroundTransition,
      builder: (BuildContext context, AvatarState state) {
        final double computedAvatarWidth =
            AppConstants.avatarWidth * state.scaleFactor;
        final double scaledAvatarWidth =
            computedAvatarWidth.isFinite && computedAvatarWidth > 0
                ? computedAvatarWidth
                : AppConstants.avatarWidth;

        return Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: scaledAvatarWidth,
                  height: constraints.maxHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(-1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        )),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      state.avatar.background.getPath(),
                      key: ValueKey<AvatarBackgrounds>(state.avatar.background),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/avatar/widgets/animated_background_avatar_test.dart
```

Expected: PASS

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/avatar/widgets/animated_background_avatar.dart
git add test/features/avatar/widgets/animated_background_avatar_test.dart
git commit -m "feat: add AnimatedBackgroundAvatar widget with slide transition"
```

---

## Task 4: Create AvatarAnimationService

**Files:**
- Create: `lib/core/services/avatar_animation_service.dart`
- Test: `test/core/services/avatar_animation_service_test.dart`

**Step 1: Write the failing test**

Create `test/core/services/avatar_animation_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';

void main() {
  group('AvatarAnimationService', () {
    late AvatarAnimationService service;
    late MockAvatarCubit mockAvatarCubit;

    setUp(() {
      mockAvatarCubit = MockAvatarCubit();
      service = AvatarAnimationService(mockAvatarCubit);
    });

    test('playNewChatSequence calls onClothesAnimationChanged with true',
        () async {
      // Arrange
      const chatId = 'test-chat-id';
      const config = AvatarConfig(background: AvatarBackgrounds.beach);

      // Act
      final future = service.playNewChatSequence(chatId, config);

      // Assert - immediate call
      verify(() => mockAvatarCubit.onClothesAnimationChanged(true)).called(1);

      // Wait for completion
      await future;
    });

    test('playNewChatSequence calls onBackgroundTransitionChanged',
        () async {
      // Arrange
      const chatId = 'test-chat-id';
      const config = AvatarConfig(background: AvatarBackgrounds.beach);

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert
      verify(() => mockAvatarCubit.onBackgroundTransitionChanged(
        BackgroundTransition.sliding,
      )).called(1);
    });

    test('playNewChatSequence calls onClothesAnimationChanged with false at end',
        () async {
      // Arrange
      const chatId = 'test-chat-id';
      const config = AvatarConfig(background: AvatarBackgrounds.beach);

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert - final call with false (rising)
      verify(() => mockAvatarCubit.onClothesAnimationChanged(false)).called(1);
    });

    test('playNewChatSequence updates avatar config during animation',
        () async {
      // Arrange
      const chatId = 'test-chat-id';
      const config = AvatarConfig(background: AvatarBackgrounds.beach);

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert
      verify(() => mockAvatarCubit.updateAvatarConfig(chatId, config)).called(1);
    });
  });
}

class MockAvatarCubit extends Mock implements AvatarCubit {}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/core/services/avatar_animation_service_test.dart
```

Expected: FAIL with "service not found" and "method not found"

**Step 3: Write minimal implementation**

Create `lib/core/services/avatar_animation_service.dart`:

```dart
import 'dart:async';

import '../../../../core/res/app_constants.dart';
import '../../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../models/avatar_config.dart';

/// Service for orchestrating avatar animations across features.
///
/// This service provides a centralized way to trigger avatar animations
/// without creating cross-feature dependencies.
class AvatarAnimationService {
  const AvatarAnimationService(this._avatarCubit);

  final AvatarCubit _avatarCubit;

  /// Plays the new chat creation animation sequence.
  ///
  /// Sequence:
  /// 1. Avatar drops down (off-screen)
  /// 2. Background slides horizontally
  /// 3. Avatar rises back up
  Future<void> playNewChatSequence(
    String chatId,
    AvatarConfig config,
  ) async {
    // 1. Avatar drops
    _avatarCubit.onClothesAnimationChanged(true);
    await Future<void>.delayed(
      Duration(seconds: AppConstants.changingAvatarDuration),
    );

    // 2. Background slides (while avatar is off-screen)
    _avatarCubit.onBackgroundTransitionChanged(
      BackgroundTransition.sliding,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _avatarCubit.updateAvatarConfig(chatId, config);

    // 3. Avatar rises
    _avatarCubit.onClothesAnimationChanged(false);
  }
}
```

**Step 4: Add updateAvatarConfig method to AvatarCubit**

Add to `lib/features/avatar/presentation/bloc/avatar_cubit.dart`:

```dart
void updateAvatarConfig(String chatId, AvatarConfig avatarConfig) {
  _updateAvatar(chatId, avatarConfig);
}
```

**Step 5: Run test to verify it passes**

```bash
flutter test test/core/services/avatar_animation_service_test.dart
```

Expected: PASS

**Step 6: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 7: Commit**

```bash
git add lib/core/services/avatar_animation_service.dart
git add lib/features/avatar/presentation/bloc/avatar_cubit.dart
git add test/core/services/avatar_animation_service_test.dart
git add test/features/avatar/avatar_cubit_test.dart
git commit -m "feat: add AvatarAnimationService for coordinating animations"
```

---

## Task 5: Add creatingChat status to ChatsState

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_state.dart`

**Step 1: Add the creatingChat status**

Add to the `ChatsStatus` enum in the freezed class:

```dart
@freezed
sealed class ChatsStatus with _$ChatsStatus {
  const factory ChatsStatus.initial() = ChatsInitial;
  const factory ChatsStatus.loading() = ChatsLoading;
  const factory ChatsStatus.creatingChat() = ChatsCreatingChat;
  const factory ChatsStatus.success() = ChatsSuccess;
  const factory ChatsStatus.error(String message) = ChatsError;
  const factory ChatsStatus.streaming() = ChatsStreaming;
  const factory ChatsStatus.updating() = ChatsUpdating;
}
```

**Step 2: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `chats_state.freezed.dart` updated successfully

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_state.dart
git add lib/features/chat/presentation/bloc/chats_state.freezed.dart
git commit -m "feat: add creatingChat status to ChatsState"
```

---

## Task 6: Inject AvatarAnimationService into ChatsCubit

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Modify: `lib/core/di/injection.dart`

**Step 1: Add AvatarAnimationService dependency to ChatsCubit constructor**

Modify `lib/features/chat/presentation/bloc/chats_cubit.dart`:

```dart
class ChatsCubit extends Emit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AvatarAnimationService avatarAnimationService,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final AvatarAnimationService _avatarAnimationService;
```

**Step 2: Add import**

Add to imports in `lib/features/chat/presentation/bloc/chats_cubit.dart`:

```dart
import '../../../../core/services/avatar_animation_service.dart';
import '../../../../core/models/avatar_config.dart';
```

**Step 3: Register AvatarAnimationService in DI**

Modify `lib/core/di/injection.dart`:

Add after AvatarCubit registration:

```dart
// Register after AvatarCubit
getIt.registerLazySingleton<AvatarAnimationService>(
  () => AvatarAnimationService(getIt<AvatarCubit>()),
);
```

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 5: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_cubit.dart
git add lib/core/di/injection.dart
git commit -m "feat: inject AvatarAnimationService into ChatsCubit"
```

---

## Task 7: Update createNewChat to trigger animation

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chats_cubit.dart`
- Test: `test/features/chat/chats_cubit_test.dart`

**Step 1: Write the failing test**

Add to `test/features/chat/chats_cubit_test.dart`:

```dart
group('createNewChat with animation', () {
  test('should trigger animation sequence after chat creation', () async {
    // Arrange
    when(() => mockChatRepository.createNewChat(language: any(named: 'language')))
        .thenAnswer((_) async => Right(testChat));

    // Act
    await cubit.createNewChat();

    // Assert
    verify(() => mockAvatarAnimationService.playNewChatSequence(
      testChat.id,
      any(named: 'config'),
    )).called(1);
  });

  test('should pass correct background config to animation service', () async {
    // Arrange
    final chatWithBeach = testChat.copyWith(
      avatar: testChat.avatar.copyWith(background: AvatarBackgrounds.beach),
    );
    when(() => mockChatRepository.createNewChat(language: any(named: 'language')))
        .thenAnswer((_) async => Right(chatWithBeach));

    // Act
    await cubit.createNewChat();

    // Assert
    final captured = verify(() => mockAvatarAnimationService.playNewChatSequence(
      any(),
      captureAny(),
    )).captured;
    final config = captured.last as AvatarConfig;
    expect(config.background, AvatarBackgrounds.beach);
  });
});
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/chat/chats_cubit_test.dart
```

Expected: FAIL - "never called" or wrong arguments

**Step 3: Implement animation trigger in createNewChat**

Modify `createNewChat` method in `lib/features/chat/presentation/bloc/chats_cubit.dart`:

```dart
/// Create a new chat
Future<void> createNewChat() async {
  emit(state.copyWith(status: ChatsStatus.creatingChat));
  final Either<Exception, Chat> result = await _chatRepository.createNewChat(
    language: state.currentLanguage,
  );

  result.fold(
    (Exception error) {
      emit(
        state.copyWith(
          status: ChatsStatus.error,
          errorMessage: error.toString(),
        ),
      );
    },
    (Chat newChat) async {
      // If creating chat during initialization, set the flag
      final bool wasInitializing = state.initializing;

      emit(
        state.copyWith(
          status: ChatsStatus.success,
          chatsList: <Chat>[newChat, ...state.chatsList],
          currentChat: newChat,
          openedChat: newChat,
          chatCreated: true,
          functionCallingEnabled: false,
          userCreatedChatDuringInit: wasInitializing,
        ),
      );
      emit(state.copyWith(chatCreated: false));

      // Trigger animation sequence
      await _avatarAnimationService.playNewChatSequence(
        newChat.id,
        AvatarConfig(background: newChat.avatar.background),
      );
    },
  );
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/chat/chats_cubit_test.dart
```

Expected: PASS

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/chat/presentation/bloc/chats_cubit.dart
git add test/features/chat/chats_cubit_test.dart
git commit -m "feat: trigger avatar animation on new chat creation"
```

---

## Task 8: Replace BackgroundAvatar with AnimatedBackgroundAvatar

**Files:**
- Modify: `lib/features/home/widgets/home_content_stack.dart` (or wherever BackgroundAvatar is used)

**Step 1: Find BackgroundAvatar usage**

```bash
grep -r "BackgroundAvatar" lib/ --include="*.dart"
```

Expected: List of files using BackgroundAvatar

**Step 2: Replace import and usage**

In each file that uses `BackgroundAvatar`:

```dart
// Old import
import '../avatar/widgets/background_avatar.dart';

// New import
import '../avatar/widgets/animated_background_avatar.dart';

// Old usage
const BackgroundAvatar(),

// New usage
const AnimatedBackgroundAvatar(),
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 4: Run widget tests**

```bash
flutter test test/features/home/ --reporter expanded
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/features/home/widgets/home_content_stack.dart
git commit -m "refactor: replace BackgroundAvatar with AnimatedBackgroundAvatar"
```

---

## Task 9: Integration testing

**Files:**
- Test: `test/integration/features/chat/new_chat_animation_test.dart`

**Step 1: Write integration test**

Create `test/integration/features/chat/new_chat_animation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chats_state.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/avatar/widgets/animated_background_avatar.dart';
import 'package:yofardev_ai/main.dart' as app;

void main() {
  group('New Chat Animation Integration', () {
    setUpAll(() async {
      // Initialize DI
      await configureDependencies();
    });

    testWidgets('complete animation sequence on new chat', (tester) async {
      // Arrange
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();

      // Find ChatsCubit
      final chatsCubit = tester.state<ChatsCubit>();
      final avatarCubit = tester.state<AvatarCubit>();

      // Act - Create new chat
      await tester.tap(find.text('New Chat')); // or appropriate button
      await tester.pump();

      // Assert - Initial state: avatar dropping
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop to complete
      await tester.pump(Duration(seconds: 1));
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.rising);

      // Wait for rise to complete
      await tester.pumpAndSettle();

      // Final state - animation complete
      expect(chatsCubit.state.status, ChatsStatus.success);
    });

    testWidgets('background slides during animation', (tester) async {
      // Arrange
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();

      final avatarCubit = tester.state<AvatarCubit>();
      final initialBackground = avatarCubit.state.avatar.background;

      // Act
      await tester.tap(find.text('New Chat'));
      await tester.pump(Duration(milliseconds: 600)); // After drop, during slide

      // Assert - Background transition active
      expect(
        avatarCubit.state.backgroundTransition,
        BackgroundTransition.sliding,
      );

      // Wait for completion
      await tester.pumpAndSettle();

      // Background transition complete
      expect(
        avatarCubit.state.backgroundTransition,
        BackgroundTransition.none,
      );
    });
  });
}
```

**Step 2: Run integration test**

```bash
flutter test test/integration/features/chat/new_chat_animation_test.dart
```

Expected: PASS

**Step 3: Commit**

```bash
git add test/integration/features/chat/new_chat_animation_test.dart
git commit -m "test: add integration test for new chat animation"
```

---

## Task 10: Manual testing and documentation

**Step 1: Run the app**

```bash
flutter run
```

**Step 2: Create a new chat and verify:**
- [ ] Avatar drops down smoothly
- [ ] Background slides from left while avatar is off-screen
- [ ] Avatar rises back up
- [ ] Sound effect plays (if enabled)
- [ ] No janky animations

**Step 3: Verify edge cases:**
- [ ] Rapidly tap "New Chat" multiple times
- [ ] Create chat while another operation is loading
- [ ] Create chat with different personas/backgrounds

**Step 4: Update documentation**

Add to `docs/plans/2026-03-10-new-chat-animation-design.md` completion section:

```markdown
## Completion Checklist

- [x] BackgroundTransition enum added
- [x] AvatarCubit methods added
- [x] AnimatedBackgroundAvatar widget created
- [x] AvatarAnimationService created
- [x] ChatsCubit integrated with service
- [x] Integration tests passing
- [x] Manual testing complete
- [x] No flutter analyze errors
```

**Step 5: Final commit**

```bash
git add docs/plans/2026-03-10-new-chat-animation-design.md
git commit -m "docs: mark new chat animation feature as complete"
```

---

## Summary

This implementation plan follows TDD principles with tests written before implementation, maintains clean architecture with no cross-feature imports, and ensures all changes are committed incrementally.

**Total estimated time:** 2-3 hours

**Key files created:**
- `lib/core/services/avatar_animation_service.dart`
- `lib/features/avatar/widgets/animated_background_avatar.dart`

**Key files modified:**
- `lib/features/avatar/presentation/bloc/avatar_state.dart`
- `lib/features/avatar/presentation/bloc/avatar_cubit.dart`
- `lib/features/chat/presentation/bloc/chats_state.dart`
- `lib/features/chat/presentation/bloc/chats_cubit.dart`
- `lib/core/di/injection.dart`
