# Interruption Feature Design

**Date:** 2026-03-06
**Status:** Approved
**Author:** Claude Code

## Overview

Add a feature to allow users to interrupt the assistant when it's speaking. The interruption should stop both the TTS audio playback and the lip-sync animation in a clean way, preserving the partial response that was generated.

## Requirements

### Functional Requirements

1. **Trigger**: User can interrupt via a dedicated floating stop button
2. **Behavior**: When interrupted:
   - Stop current audio playback immediately
   - Stop lip-sync animation
   - Clear all pending TTS generation in the queue
   - Stop LLM message streaming
   - Keep partial response text visible in chat
3. **UI**: Show floating stop button only when assistant is streaming/talking
4. **Feedback**: Show brief message when interruption occurs

### Non-Functional Requirements

1. **Performance**: Interruption should happen within 100ms
2. **Reliability**: Handle edge cases (multiple interruptions, interruption when idle)
3. **Architecture**: Follow flutter-architecture standards
4. **Testability**: All components must be unit testable

## Architecture

### Component: InterruptionService (Core Service)

**Location:** `lib/core/services/audio/interruption_service.dart`

**Responsibilities:**
- Manage interruption state
- Broadcast interruption events via stream
- Provide single source of truth for interruption

**API:**
```dart
class InterruptionService {
  // Stream that broadcasts when interruption occurs
  Stream<void> get interruptionStream;

  // Check if currently interrupted
  bool get isInterrupted;

  // Trigger interruption (called by UI)
  Future<void> interrupt();

  // Reset interruption state (called when starting new conversation)
  void reset();

  void dispose();
}
```

### Modified Components

#### 1. ChatMessageCubit

**Changes:**
- Inject `InterruptionService`
- Listen to `interruptionStream`
- Add `interrupted` state to `ChatMessageState`
- Stop streaming when interrupted

**New State:**
```dart
const factory ChatMessageState.interrupted() = _Interrupted;
```

#### 2. TtsQueueManager

**Changes:**
- Inject `InterruptionService`
- Listen to `interruptionStream`
- Clear queue and cancel generation when interrupted

**Behavior:**
- Stop current TTS generation
- Clear all pending items in queue
- Cancel processing timer
- Set `_isProcessing = false`

#### 3. TalkingCubit

**Changes:**
- Inject `InterruptionService`
- Listen to `interruptionStream`
- Call `stop()` when interrupted

**Behavior:**
- Cancel animation timer
- Stop TTS via repository
- Emit `TalkingState.idle()`

### UI Components

#### 1. FloatingStopButton Widget

**Location:** `lib/features/chat/widgets/floating_stop_button.dart`

**Responsibilities:**
- Show floating stop button only when streaming
- Call `InterruptionService.interrupt()` when tapped
- Position: Bottom-right of screen (similar to phone hangup button)

**Implementation:**
```dart
class FloatingStopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatMessageCubit, ChatMessageState>(
      builder: (context, state) {
        final bool shouldShow = state.status == ChatMessageStatus.streaming;
        if (!shouldShow) return const SizedBox.shrink();

        return Positioned(
          bottom: 100,
          right: 20,
          child: FloatingActionButton(
            onPressed: () => context.read<InterruptionService>().interrupt(),
            child: const Icon(Icons.stop),
          ),
        );
      },
    );
  }
}
```

#### 2. Screen Integration

**Changes:**
- Wrap existing UI with `Stack`
- Add `FloatingStopButton` to stack
- Use `MultiBlocListener` to handle interruption state
- Show snackbar on interruption

### Data Flow

```
User taps stop button
    ↓
UI calls InterruptionService.interrupt()
    ↓
InterruptionService broadcasts interruption event
    ↓
Multiple listeners react simultaneously:
    ├→ ChatMessageCubit: stops streaming, emits interrupted state
    ├→ TtsQueueManager: clears queue, cancels generation
    ├→ TalkingCubit: stops animation, calls stop()
    └→ AudioPlayerService: stops audio (via TalkingCubit.stop())
    ↓
UI updates: hide stop button, show partial response, show snackbar
```

## Dependency Injection

**File:** `lib/core/di/injection.dart`

**Changes:**
```dart
// Register InterruptionService as singleton
getIt.registerLazySingleton<InterruptionService>(
  () => InterruptionService(),
);

// Update TtsQueueManager
getIt.registerFactory<TtsQueueManager>(
  () => TtsQueueManager(
    ttsDatasource: getIt<TtsDatasource>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);

// Update ChatMessageCubit
getIt.registerFactory<ChatMessageCubit>(
  () => ChatMessageCubit(
    // ... existing dependencies
    interruptionService: getIt<InterruptionService>(),
  ),
);

// Update TalkingCubit
getIt.registerFactory<TalkingCubit>(
  () => TalkingCubit(
    repository: getIt<TalkingRepository>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);
```

## Error Handling

- InterruptionService uses try-catch internally
- Logs errors via AppLogger
- Never throws to UI (graceful degradation)
- If interruption fails, UI shows error via snackbar
- Handle multiple interruptions (idempotent)
- Handle interruption when idle (no-op)

## Testing Strategy

### Unit Tests

1. **InterruptionService** (`test/core/services/audio/interruption_service_test.dart`)
   - Test `interrupt()` broadcasts to stream
   - Test `reset()` clears interrupted state
   - Test multiple interruptions
   - Test stream subscription

2. **ChatMessageCubit** (`test/features/chat/bloc/chat_message_cubit_test.dart`)
   - Test streaming stops on interruption
   - Test state changes to interrupted
   - Test interruption when not streaming (no-op)

3. **TtsQueueManager** (`test/features/sound/domain/tts_queue_manager_test.dart`)
   - Test queue cleared on interruption
   - Test processing stopped
   - Test interruption during generation

4. **TalkingCubit** (`test/features/talking/presentation/bloc/talking_cubit_test.dart`)
   - Test animation stopped on interruption
   - Test stop() called
   - Test state changes to idle

### Widget Tests

1. **FloatingStopButton** (`test/features/chat/widgets/floating_stop_button_test.dart`)
   - Test button appears when streaming
   - Test button hidden when not streaming
   - Test button calls `InterruptionService.interrupt()`

2. **Chat Screen Integration**
   - Test snackbar shown on interruption
   - Test partial response preserved

### Integration Tests

- Test full interruption flow
- Test interruption during TTS generation
- Test interruption during LLM streaming

## Implementation Checklist

- [ ] Create `InterruptionService` in `lib/core/services/audio/`
- [ ] Add `interrupted` state to `ChatMessageState`
- [ ] Modify `ChatMessageCubit` to listen to interruptions
- [ ] Modify `TtsQueueManager` to listen to interruptions
- [ ] Modify `TalkingCubit` to listen to interruptions
- [ ] Create `FloatingStopButton` widget
- [ ] Integrate button into chat screen UI
- [ ] Update dependency injection in `injection.dart`
- [ ] Add unit tests for InterruptionService
- [ ] Add unit tests for modified cubits
- [ ] Add widget tests for FloatingStopButton
- [ ] Run `flutter analyze` and fix issues
- [ ] Test on device (iOS/Android)

## File Changes Summary

### New Files
- `lib/core/services/audio/interruption_service.dart`
- `lib/features/chat/widgets/floating_stop_button.dart`
- `test/core/services/audio/interruption_service_test.dart`
- `test/features/chat/widgets/floating_stop_button_test.dart`

### Modified Files
- `lib/features/chat/bloc/chat_message_state.dart` (add interrupted state)
- `lib/features/chat/bloc/chat_message_cubit.dart` (inject service, listen)
- `lib/features/sound/domain/tts_queue_manager.dart` (inject service, listen)
- `lib/features/talking/presentation/bloc/talking_cubit.dart` (inject service, listen)
- `lib/core/di/injection.dart` (register service and update dependencies)
- `lib/features/chat/presentation/screens/chat_screen.dart` (add button, listeners)
- Test files for modified cubits

## Success Criteria

- [ ] Stop button appears only when assistant is talking
- [ ] Tapping button stops audio within 100ms
- [ ] Animation stops immediately
- [ ] TTS queue is cleared
- [ ] LLM streaming stops
- [ ] Partial response remains visible
- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] No `flutter analyze` errors
- [ ] Manual testing on device confirms smooth interruption

## Future Enhancements

- Add haptic feedback on interruption
- Add keyboard shortcut (e.g., Escape key) for desktop
- Add voice command interruption (e.g., "stop")
- Add undo interruption option
- Show interruption count in analytics
