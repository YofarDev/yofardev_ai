# New Chat Creation Animation Design

**Date:** 2026-03-10
**Status:** Approved
**Author:** Claude Sonnet 4.6

## Overview

When a user creates a new chat, a coordinated animation sequence plays to provide visual feedback and enhance the user experience. The animation combines avatar movement with background transitions for a polished effect.

### Animation Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│ Timeline:                                                        │
├─────────────────────────────────────────────────────────────────┤
│ 0.0s: createNewChat() called                                    │
│       ↓                                                          │
│ 0.0s: AvatarAnimationService.startSequence()                    │
│       ↓                                                          │
│ 0.0s: Avatar drops (AvatarStatusAnimation.dropping)             │
│       ↓                                                          │
│ 0.5s: Avatar fully off-screen                                   │
│       ↓                                                          │
│ 0.5s: Background slides (BackgroundTransition.sliding)          │
│       ↓                                                          │
│ 1.0s: Background slide complete                                 │
│       ↓                                                          │
│ 1.0s: Avatar rises (AvatarStatusAnimation.rising)               │
│       ↓                                                          │
│ 1.5s: Complete → emit success                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

### Dependency Flow

```
chat/presentation (ChatsCubit)
         ↓
core/services (AvatarAnimationService)
         ↓
avatar/presentation (AvatarCubit)
```

**No cross-feature imports** - all coordination happens through the core service.

### File Structure

```
lib/
├── core/
│   ├── di/
│   │   └── injection.dart              # MODIFIED: Register service
│   └── services/
│       └── avatar_animation_service.dart  # NEW: Animation orchestrator
└── features/
    ├── avatar/
    │   └── presentation/
    │       ├── bloc/
    │       │   ├── avatar_cubit.dart         # MODIFIED: Add methods
    │       │   └── avatar_state.dart         # MODIFIED: Add enum
    │       └── widgets/
    │           └── animated_background_avatar.dart  # NEW: Widget
    └── chat/
        └── presentation/
            └── bloc/
                ├── chats_cubit.dart          # MODIFIED: Use service
                └── chats_state.dart          # MODIFIED: Add status
```

## Components

### 1. AvatarAnimationService (Core Service)

**Location:** `lib/core/services/avatar_animation_service.dart`

**Responsibilities:**
- Orchestrate the new chat animation sequence
- Coordinate timing between avatar and background animations
- Play sound effects

**Interface:**
```dart
class AvatarAnimationService {
  final AvatarCubit _avatarCubit;

  AvatarAnimationService(this._avatarCubit);

  Future<void> playNewChatSequence(
    String chatId,
    AvatarConfig config,
  ) async {
    // 1. Avatar drops
    _avatarCubit.onClothesAnimationChanged(true);
    await Future.delayed(
      Duration(seconds: AppConstants.changingAvatarDuration),
    );

    // 2. Background slides
    _avatarCubit.onBackgroundTransitionChanged(
      BackgroundTransition.sliding,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    _avatarCubit.updateAvatarConfig(chatId, config);

    // 3. Avatar rises
    _avatarCubit.onClothesAnimationChanged(false);
  }
}
```

### 2. AvatarState Modifications

**Location:** `lib/features/avatar/presentation/bloc/avatar_state.dart`

**Additions:**
```dart
enum BackgroundTransition {
  none,
  sliding,
}

@freezed
class AvatarState with _$AvatarState {
  const factory AvatarState({
    // ... existing fields
    @Default(BackgroundTransition.none) BackgroundTransition backgroundTransition,
  }) = _AvatarState;
}
```

**AvatarCubit additions:**
```dart
void onBackgroundTransitionChanged(BackgroundTransition transition) {
  _emitIfOpen(
    state.copyWith(backgroundTransition: transition),
  );
}
```

### 3. AnimatedBackgroundAvatar Widget

**Location:** `lib/features/avatar/widgets/animated_background_avatar.dart`

**Responsibilities:**
- Render background with slide transition
- Respond to `BackgroundTransition` state changes

**Implementation:**
```dart
class AnimatedBackgroundAvatar extends StatelessWidget {
  const AnimatedBackgroundAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      buildWhen: (prev, current) =>
          prev.avatar.background != current.avatar.background ||
          prev.backgroundTransition != current.backgroundTransition,
      builder: (context, state) {
        final double computedAvatarWidth =
            AppConstants.avatarWidth * state.scaleFactor;
        final double scaledAvatarWidth =
            computedAvatarWidth.isFinite && computedAvatarWidth > 0
                ? computedAvatarWidth
                : AppConstants.avatarWidth;

        return Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: scaledAvatarWidth,
                  height: constraints.maxHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
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
                      key: ValueKey(state.avatar.background),
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

### 4. ChatsCubit Modifications

**Location:** `lib/features/chat/presentation/bloc/chats_cubit.dart`

**Dependency Injection:**
```dart
class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AvatarAnimationService avatarAnimationService,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       super(ChatsState.initial());

  final AvatarAnimationService _avatarAnimationService;
```

**Updated createNewChat():**
```dart
Future<void> createNewChat() async {
  emit(state.copyWith(status: ChatsStatus.creatingChat));
  final result = await _chatRepository.createNewChat(
    language: state.currentLanguage,
  );

  result.fold(
    (error) => emit(
      state.copyWith(
        status: ChatsStatus.error,
        errorMessage: error.toString(),
      ),
    ),
    (newChat) async {
      emit(state.copyWith(
        status: ChatsStatus.success,
        chatsList: [newChat, ...state.chatsList],
        currentChat: newChat,
        openedChat: newChat,
      ));

      // Trigger animation sequence
      await _avatarAnimationService.playNewChatSequence(
        newChat.id,
        AvatarConfig(background: newChat.avatar.background),
      );
    },
  );
}
```

### 5. ChatsState Modifications

**Location:** `lib/features/chat/presentation/bloc/chats_state.dart`

**Additions:**
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

## Dependency Injection

**Location:** `lib/core/di/injection.dart`

**Registration:**
```dart
final getIt = GetIt.instance;

void configureDependencies() {
  // ... existing registrations

  // Register AvatarAnimationService after AvatarCubit
  getIt.registerLazySingleton<AvatarAnimationService>(
    () => AvatarAnimationService(getIt<AvatarCubit>()),
  );
}
```

## State Management Flow

```
User taps "New Chat"
        ↓
ChatsCubit.createNewChat()
        ↓
Emit ChatsStatus.creatingChat
        ↓
Repository creates new chat
        ↓
Emit ChatsStatus.success with new chat
        ↓
AvatarAnimationService.playNewChatSequence()
        ↓
  ├─ AvatarCubit.onClothesAnimationChanged(true)  // dropping
  ├─ Wait 500ms
  ├─ AvatarCubit.onBackgroundTransitionChanged(sliding)
  ├─ Wait 500ms
  └─ AvatarCubit.onClothesAnimationChanged(false) // rising
        ↓
Animation complete
```

## Anti-Patterns Avoided

| ❌ Anti-Pattern | ✅ Solution |
|----------------|-------------|
| Cross-feature import (`chat/` → `avatar/`) | Route through `core/services/` |
| Navigation in `build()` | Use `MultiBlocListener` |
| Nested BlocListeners | `MultiBlocListener` with flat list |
| Service logic in widgets | `AvatarAnimationService` in core |
| Manual DI | get_it registration in `injection.dart` |

## Testing Strategy

### Unit Tests
- `AvatarAnimationService`: Verify sequence timing and state emissions
- `AvatarCubit`: Verify new methods emit correct states
- `ChatsCubit`: Verify service is called on chat creation

### Widget Tests
- `AnimatedBackgroundAvatar`: Verify slide transition renders correctly
- Verify widget rebuilds on background change

### Integration Tests
- Full chat creation flow with animation
- Verify state transitions at each step

## Constants

**Location:** `lib/core/res/app_constants.dart`

```dart
class AppConstants {
  // ... existing constants
  static const changingAvatarDuration = 1; // seconds
}
```

## Success Criteria

1. ✅ Avatar drops down when new chat is created
2. ✅ Background slides horizontally while avatar is off-screen
3. ✅ Avatar rises back up with new appearance
4. ✅ No cross-feature imports
5. ✅ All states use freezed
6. ✅ DI via get_it
7. ✅ MultiBlocListener used (no nesting)
8. ✅ File sizes within limits (<300 lines for widgets/cubits)

## Next Steps

See implementation plan for detailed steps.
