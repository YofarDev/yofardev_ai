# Interruption Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a floating stop button that allows users to interrupt the assistant's TTS playback and animation, stopping all audio and clearing the TTS queue while preserving the partial response.

**Architecture:** Create a centralized `InterruptionService` core service that broadcasts interruption events via streams. All components (ChatMessageCubit, TtsQueueManager, TalkingCubit) listen to this stream and handle their own cleanup. UI triggers interruption via a floating button that appears only when streaming.

**Tech Stack:** Flutter, freezed (state management), flutter_bloc (Cubit), get_it (DI), just_audio (audio playback)

---

## Task 1: Create InterruptionService Core Service

**Files:**
- Create: `lib/core/services/audio/interruption_service.dart`
- Test: `test/core/services/audio/interruption_service_test.dart`

**Step 1: Create the test file**

```bash
mkdir -p test/core/services/audio
touch test/core/services/audio/interruption_service_test.dart
```

**Step 2: Write failing tests**

```dart
// test/core/services/audio/interruption_service_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';

void main() {
  group('InterruptionService', () {
    late InterruptionService service;

    setUp(() {
      service = InterruptionService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should not be interrupted initially', () {
      expect(service.isInterrupted, false);
    });

    test('should broadcast interruption event when interrupt() is called', () async {
      final List<void> events = <void>[];
      final StreamSubscription subscription = service.interruptionStream.listen(events.add);

      await service.interrupt();

      expect(events.length, 1);
      expect(service.isInterrupted, true);

      await subscription.cancel();
    });

    test('should reset interruption state when reset() is called', () async {
      await service.interrupt();
      expect(service.isInterrupted, true);

      service.reset();
      expect(service.isInterrupted, false);
    });

    test('should handle multiple interruptions gracefully', () async {
      final List<void> events = <void>[];
      final StreamSubscription subscription = service.interruptionStream.listen(events.add);

      await service.interrupt();
      await service.interrupt();
      await service.interrupt();

      expect(events.length, 3);
      expect(service.isInterrupted, true);

      await subscription.cancel();
    });
  });
}
```

**Step 3: Run tests to verify they fail**

```bash
flutter test test/core/services/audio/interruption_service_test.dart
```

Expected: FAIL with "InterruptionService not found"

**Step 4: Create the service file**

```bash
mkdir -p lib/core/services/audio
touch lib/core/services/audio/interruption_service.dart
```

**Step 5: Implement InterruptionService**

```dart
// lib/core/services/audio/interruption_service.dart

import 'dart:async';
import 'package:yofardev_ai/core/utils/logger.dart';

/// Service for managing assistant interruption state
///
/// Broadcasts interruption events to all listeners via [interruptionStream].
/// Components should listen to this stream and handle their own cleanup.
class InterruptionService {
  final StreamController<void> _interruptionController = StreamController<void>.broadcast();
  bool _isInterrupted = false;

  /// Stream that broadcasts when interruption occurs
  Stream<void> get interruptionStream => _interruptionController.stream;

  /// Check if currently interrupted
  bool get isInterrupted => _isInterrupted;

  /// Trigger interruption (called by UI)
  ///
  /// Broadcasts interruption event to all listeners.
  /// Multiple interruptions are handled gracefully.
  Future<void> interrupt() async {
    try {
      AppLogger.debug('Interruption triggered', tag: 'InterruptionService');
      _isInterrupted = true;
      _interruptionController.add(null);
    } catch (e) {
      AppLogger.error(
        'Failed to trigger interruption',
        tag: 'InterruptionService',
        error: e,
      );
    }
  }

  /// Reset interruption state (called when starting new conversation)
  void reset() {
    AppLogger.debug('Interruption state reset', tag: 'InterruptionService');
    _isInterrupted = false;
  }

  /// Dispose resources
  void dispose() {
    _interruptionController.close();
  }
}
```

**Step 6: Run tests to verify they pass**

```bash
flutter test test/core/services/audio/interruption_service_test.dart
```

Expected: PASS (all 4 tests)

**Step 7: Commit**

```bash
git add lib/core/services/audio/interruption_service.dart test/core/services/audio/interruption_service_test.dart
git commit -m "feat: add InterruptionService core service

- Add InterruptionService for managing assistant interruption
- Broadcast interruption events via stream
- Support multiple interruptions and state reset
- Add comprehensive unit tests

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Add Interrupted State to ChatMessageState

**Files:**
- Modify: `lib/features/chat/bloc/chat_message_state.dart`
- Modify: `lib/features/chat/bloc/chat_message_state.freezed.dart`

**Step 1: Read current ChatMessageState**

```bash
cat lib/features/chat/bloc/chat_message_state.dart
```

**Step 2: Add interrupted state to ChatMessageState**

```dart
// lib/features/chat/bloc/chat_message_state.dart

// Add this to the freezed class after other states:

  /// Streaming was interrupted by user
  const factory ChatMessageState.interrupted() = _Interrupted;
```

**Step 3: Regenerate freezed code**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Step 4: Verify generated code**

```bash
cat lib/features/chat/bloc/chat_message_state.freezed.dart | grep -A 20 "class _Interrupted"
```

Expected: See generated `_Interrupted` class

**Step 5: Commit**

```bash
git add lib/features/chat/bloc/chat_message_state.dart lib/features/chat/bloc/chat_message_state.freezed.dart
git commit -m "feat: add interrupted state to ChatMessageState

- Add _Interrupted state for user interruption
- Regenerate freezed code

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Modify ChatMessageCubit to Handle Interruptions

**Files:**
- Modify: `lib/features/chat/bloc/chat_message_cubit.dart`
- Test: `test/features/chat/bloc/chat_message_cubit_test.dart`

**Step 1: Write failing test for interruption handling**

```dart
// test/features/chat/bloc/chat_message_cubit_test.dart

// Add this test inside the main group:

  group('Interruption', () {
    late MockChatRepository mockChatRepository;
    late MockSettingsRepository mockSettingsRepository;
    late MockLlmService mockLlmService;
    late MockStreamProcessorService mockStreamProcessor;
    late MockPromptDatasource mockPromptDatasource;
    late InterruptionService interruptionService;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockSettingsRepository = MockSettingsRepository();
      mockLlmService = MockLlmService();
      mockStreamProcessor = MockStreamProcessorService();
      mockPromptDatasource = MockPromptDatasource();
      interruptionService = InterruptionService();

      // Setup common mock behaviors
      when(mockSettingsRepository.getLanguage())
          .thenAnswer((_) async => const Right('fr'));
      when(mockPromptDatasource.getSystemPrompt())
          .thenAnswer((_) async => 'system prompt');
    });

    tearDown(() {
      interruptionService.dispose();
    });

    test('should transition to interrupted state when interruption occurs', () async {
      // Arrange
      final cubit = ChatMessageCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        llmService: mockLlmService,
        streamProcessor: mockStreamProcessor,
        promptDatasource: mockPromptDatasource,
        interruptionService: interruptionService,
      );

      // Start streaming
      final controller = StreamController<SentenceChunk>();
      when(mockStreamProcessor.processStream(any))
          .thenAnswer((_) => controller.stream);

      // Start streaming (don't await)
      unawaited(cubit.askYofardev(
        'test',
        onlyText: true,
        avatar: const Avatar.empty(),
        currentChat: const Chat.empty(),
        language: 'fr',
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      // Act
      await interruptionService.interrupt();
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(cubit.state.status, ChatMessageStatus.interrupted);

      await cubit.close();
      await controller.close();
    });
  });
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/chat/bloc/chat_message_cubit_test.dart
```

Expected: FAIL (ChatMessageCubit doesn't accept InterruptionService yet)

**Step 3: Modify ChatMessageCubit to accept InterruptionService**

```dart
// lib/features/chat/bloc/chat_message_cubit.dart

// Add import:
import '../../../core/services/audio/interruption_service.dart';

// Update constructor:
class ChatMessageCubit extends Emit
<ChatMessageState> {
  ChatMessageCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LlmService llmService,
    required StreamProcessorService streamProcessor,
    required PromptDatasource promptDatasource,
    required InterruptionService interruptionService, // ADD THIS
    TtsQueueManager? ttsQueueManager,
    ChatTitleCubit? chatTitleCubit,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _ttsQueueManager = ttsQueueManager,
       _chatTitleCubit = chatTitleCubit,
       _interruptionService = interruptionService, // ADD THIS
       super(ChatMessageState.initial()) {
    // Add interruption listener
    _interruptionSubscription = _interruptionService.interruptionStream.listen((_) {
      if (state.status == ChatMessageStatus.streaming) {
        emit(state.copyWith(
          status: ChatMessageStatus.interrupted,
          streamingContent: '',
        ));
      }
    });
  }

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final LlmService _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final TtsQueueManager? _ttsQueueManager;
  final ChatTitleCubit? _chatTitleCubit;
  final InterruptionService _interruptionService; // ADD THIS

  StreamSubscription? _interruptionSubscription; // ADD THIS

  // Update close method:
  @override
  Future<void> close() async {
    await _interruptionSubscription?.cancel();
    return super.close();
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/chat/bloc/chat_message_cubit_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/chat/bloc/chat_message_cubit.dart test/features/chat/bloc/chat_message_cubit_test.dart
git commit -m "feat: add interruption handling to ChatMessageCubit

- Inject InterruptionService into ChatMessageCubit
- Listen to interruption stream
- Transition to interrupted state when interrupted
- Add unit test for interruption behavior
- Clean up subscription on close

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Modify TtsQueueManager to Handle Interruptions

**Files:**
- Modify: `lib/features/sound/domain/tts_queue_manager.dart`
- Test: `test/features/sound/domain/tts_queue_manager_test.dart`

**Step 1: Write failing test for interruption handling**

```dart
// test/features/sound/domain/tts_queue_manager_test.dart

// Add this test group:

  group('Interruption', () {
    late MockTtsDatasource mockTtsDatasource;
    late InterruptionService interruptionService;
    late TtsQueueManager queueManager;

    setUp(() {
      mockTtsDatasource = MockTtsDatasource();
      interruptionService = InterruptionService();

      when(mockTtsDatasource.textToFrenchMaleVoice(
        text: any,
        language: any,
        voiceEffect: any,
      )).thenAnswer((_) async => '/path/to/audio.mp3');
    });

    tearDown(() {
      queueManager.dispose();
      interruptionService.dispose();
    });

    test('should clear queue when interrupted', () async {
      // Arrange
      queueManager = TtsQueueManager(
        ttsDatasource: mockTtsDatasource,
        interruptionService: interruptionService,
      );

      // Enqueue multiple items
      await queueManager.enqueue(
        text: 'First',
        language: 'fr',
        voiceEffect: const VoiceEffect(pitch: 1.0, speedRate: 1.0),
      );
      await queueManager.enqueue(
        text: 'Second',
        language: 'fr',
        voiceEffect: const VoiceEffect(pitch: 1.0, speedRate: 1.0),
      );

      expect(queueManager.queue.length, greaterThan(0));

      // Act
      await interruptionService.interrupt();
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(queueManager.queue.length, 0);
      expect(queueManager.isProcessing, false);
    });
  });
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/sound/domain/tts_queue_manager_test.dart
```

Expected: FAIL (TtsQueueManager doesn't accept InterruptionService yet)

**Step 3: Modify TtsQueueManager to accept InterruptionService**

```dart
// lib/features/sound/domain/tts_queue_manager.dart

// Add import:
import '../../../../core/services/audio/interruption_service.dart';

// Update constructor:
class TtsQueueManager {
  final TtsDatasource _ttsDatasource;
  final InterruptionService _interruptionService; // ADD THIS
  final List<TtsQueueItem> _queue = <TtsQueueItem>[];
  final StreamController<String> _audioController =
      StreamController<String>.broadcast();
  final Uuid _uuid = const Uuid();

  bool _isProcessing = false;
  bool _isPaused = false;
  Timer? _processingTimer;
  StreamSubscription? _interruptionSubscription; // ADD THIS

  TtsQueueManager({
    required TtsDatasource ttsDatasource,
    required InterruptionService interruptionService, // ADD THIS
  }) : _ttsDatasource = ttsDatasource,
       _interruptionService = interruptionService { // ADD THIS
    // Listen to interruptions
    _interruptionSubscription = _interruptionService.interruptionStream
      .listen((_) => _handleInterruption());
  }

  // Add interruption handler:
  void _handleInterruption() {
    AppLogger.debug(
      'TTS queue interrupted, clearing queue',
      tag: 'TtsQueueManager',
    );
    clear();
    _isProcessing = false;
    _processingTimer?.cancel();
  }

  // Update dispose method:
  void dispose() {
    _processingTimer?.cancel();
    _interruptionSubscription?.cancel(); // ADD THIS
    _audioController.close();
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/sound/domain/tts_queue_manager_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/sound/domain/tts_queue_manager.dart test/features/sound/domain/tts_queue_manager_test.dart
git commit -m "feat: add interruption handling to TtsQueueManager

- Inject InterruptionService into TtsQueueManager
- Clear queue and stop processing when interrupted
- Add unit test for interruption behavior
- Clean up subscription on dispose

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Modify TalkingCubit to Handle Interruptions

**Files:**
- Modify: `lib/features/talking/presentation/bloc/talking_cubit.dart`
- Test: `test/features/talking/presentation/bloc/talking_cubit_test.dart`

**Step 1: Write failing test for interruption handling**

```dart
// test/features/talking/presentation/bloc/talking_cubit_test.dart

// Add this test group:

  group('Interruption', () {
    late MockTalkingRepository mockRepository;
    late InterruptionService interruptionService;
    late TalkingCubit cubit;

    setUp(() {
      mockRepository = MockTalkingRepository();
      interruptionService = InterruptionService();

      when(mockRepository.stop()).thenAnswer((_) async {});
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
    });

    test('should stop animation and TTS when interrupted', () async {
      // Arrange
      cubit = TalkingCubit(
        repository: mockRepository,
        interruptionService: interruptionService,
      );

      // Start speaking
      cubit.setSpeakingState();
      expect(cubit.state, isA<SpeakingState>());

      // Act
      await interruptionService.interrupt();
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(cubit.state, isA<IdleState>());
      verify(mockRepository.stop()).called(1);
    });
  });
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/features/talking/presentation/bloc/talking_cubit_test.dart
```

Expected: FAIL (TalkingCubit doesn't accept InterruptionService yet)

**Step 3: Modify TalkingCubit to accept InterruptionService**

```dart
// lib/features/talking/presentation/bloc/talking_cubit.dart

// Add import:
import '../../../../core/services/audio/interruption_service.dart';

// Update constructor:
class TalkingCubit extends Emit
<TalkingState> {
  TalkingCubit(
    this._repository,
    this._interruptionService, // ADD THIS
  ) : super(const TalkingState.idle()) {
    // Listen to interruptions
    _interruptionSubscription = _interruptionService.interruptionStream
      .listen((_) async {
        await stop();
      });
  }

  final TalkingRepository _repository;
  final InterruptionService _interruptionService; // ADD THIS
  Timer? _animationTimer;
  StreamSubscription? _interruptionSubscription; // ADD THIS

  // Update close method:
  @override
  Future<void> close() async {
    _animationTimer?.cancel();
    await _interruptionSubscription?.cancel(); // ADD THIS
    await super.close();
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/features/talking/presentation/bloc/talking_cubit_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/talking/presentation/bloc/talking_cubit.dart test/features/talking/presentation/bloc/talking_cubit_test.dart
git commit -m "feat: add interruption handling to TalkingCubit

- Inject InterruptionService into TalkingCubit
- Stop animation and TTS when interrupted
- Add unit test for interruption behavior
- Clean up subscription on close

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Create FloatingStopButton Widget

**Files:**
- Create: `lib/features/chat/widgets/floating_stop_button.dart`
- Test: `test/features/chat/widgets/floating_stop_button_test.dart`

**Step 1: Create widget file**

```bash
touch lib/features/chat/widgets/floating_stop_button.dart
```

**Step 2: Write failing widget test**

```dart
// test/features/chat/widgets/floating_stop_button_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_state.dart';
import 'package:yofardev_ai/features/chat/widgets/floating_stop_button.dart';

void main() {
  group('FloatingStopButton', () {
    late InterruptionService interruptionService;
    late ChatMessageCubit chatCubit;

    setUp(() {
      interruptionService = InterruptionService();
      chatCubit = ChatMessageCubit(
        chatRepository: MockChatRepository(),
        settingsRepository: MockSettingsRepository(),
        llmService: MockLlmService(),
        streamProcessor: MockStreamProcessorService(),
        promptDatasource: MockPromptDatasource(),
        interruptionService: interruptionService,
      );
    });

    tearDown(() {
      chatCubit.close();
      interruptionService.dispose();
    });

    testWidgets('should not show when not streaming', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: const Scaffold(
              body: FloatingStopButton(),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show when streaming', (WidgetTester tester) async {
      // Arrange
      chatCubit.emit(state.copyWith(status: ChatMessageStatus.streaming));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: const Scaffold(
              body: FloatingStopButton(),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('should call interrupt when tapped', (WidgetTester tester) async {
      // Arrange
      chatCubit.emit(state.copyWith(status: ChatMessageStatus.streaming));
      bool interrupted = false;

      interruptionService.interruptionStream.listen((_) {
        interrupted = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: Scaffold(
              body: BlocProvider.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Assert
      expect(interrupted, true);
    });
  });
}
```

**Step 3: Run test to verify it fails**

```bash
flutter test test/features/chat/widgets/floating_stop_button_test.dart
```

Expected: FAIL (widget doesn't exist yet)

**Step 4: Implement FloatingStopButton widget**

```dart
// lib/features/chat/widgets/floating_stop_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio/interruption_service.dart';
import '../bloc/chat_message_cubit.dart';
import '../bloc/chat_message_state.dart';

/// Floating stop button that appears when assistant is streaming
///
/// Positioned at bottom-right of screen. Tapping interrupts
/// the assistant's TTS and animation.
class FloatingStopButton extends StatelessWidget {
  const FloatingStopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatMessageCubit, ChatMessageState>(
      builder: (context, state) {
        // Only show when streaming
        final bool shouldShow = state.status == ChatMessageStatus.streaming;

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 100,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () =>
                context.read<InterruptionService>().interrupt(),
            child: const Icon(Icons.stop, color: Colors.white),
          ),
        );
      },
    );
  }
}
```

**Step 5: Run test to verify it passes**

```bash
flutter test test/features/chat/widgets/floating_stop_button_test.dart
```

Expected: PASS

**Step 6: Commit**

```bash
git add lib/features/chat/widgets/floating_stop_button.dart test/features/chat/widgets/floating_stop_button_test.dart
git commit -m "feat: add FloatingStopButton widget

- Create floating stop button widget
- Show only when assistant is streaming
- Call InterruptionService.interrupt() when tapped
- Add comprehensive widget tests
- Position at bottom-right with red background

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Update Dependency Injection

**Files:**
- Modify: `lib/core/di/injection.dart`

**Step 1: Add InterruptionService registration**

```dart
// lib/core/di/injection.dart

// Add import:
import '../services/audio/interruption_service.dart';

// Add registration after other audio services:
getIt.registerLazySingleton<InterruptionService>(
  () => InterruptionService(),
);
```

**Step 2: Update TtsQueueManager registration**

```dart
// lib/core/di/injection.dart

// Find and replace the TtsQueueManager registration:

// OLD:
getIt.registerFactory<TtsQueueManager>(
  () => TtsQueueManager(
    ttsDatasource: getIt<TtsDatasource>(),
  ),
);

// NEW:
getIt.registerFactory<TtsQueueManager>(
  () => TtsQueueManager(
    ttsDatasource: getIt<TtsDatasource>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);
```

**Step 3: Update ChatMessageCubit registration**

```dart
// lib/core/di/injection.dart

// Find and replace the ChatMessageCubit registration:

// OLD:
getIt.registerFactory<ChatMessageCubit>(
  () => ChatMessageCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    llmService: getIt<LlmService>(),
    streamProcessor: getIt<StreamProcessorService>(),
    promptDatasource: getIt<PromptDatasource>(),
    ttsQueueManager: getIt<TtsQueueManager>(),
    chatTitleCubit: getIt<ChatTitleCubit>(),
  ),
);

// NEW:
getIt.registerFactory<ChatMessageCubit>(
  () => ChatMessageCubit(
    chatRepository: getIt<ChatRepository>(),
    settingsRepository: getIt<SettingsRepository>(),
    llmService: getIt<LlmService>(),
    streamProcessor: getIt<StreamProcessorService>(),
    promptDatasource: getIt<PromptDatasource>(),
    ttsQueueManager: getIt<TtsQueueManager>(),
    chatTitleCubit: getIt<ChatTitleCubit>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);
```

**Step 4: Update TalkingCubit registration**

```dart
// lib/core/di/injection.dart

// Find and replace the TalkingCubit registration:

// OLD:
getIt.registerFactory<TalkingCubit>(
  () => TalkingCubit(
    repository: getIt<TalkingRepository>(),
  ),
);

// NEW:
getIt.registerFactory<TalkingCubit>(
  () => TalkingCubit(
    repository: getIt<TalkingRepository>(),
    interruptionService: getIt<InterruptionService>(),
  ),
);
```

**Step 5: Verify no compilation errors**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/core/di/injection.dart
git commit -m "feat: register InterruptionService in DI container

- Register InterruptionService as lazy singleton
- Inject InterruptionService into TtsQueueManager
- Inject InterruptionService into ChatMessageCubit
- Inject InterruptionService into TalkingCubit

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: Integrate FloatingStopButton into Chat Screen

**Files:**
- Modify: `lib/features/chat/presentation/screens/chat_screen.dart`

**Step 1: Locate chat screen file**

```bash
find lib -name "chat_screen.dart" -type f
```

**Step 2: Read current chat screen structure**

```bash
cat lib/features/chat/presentation/screens/chat_screen.dart
```

**Step 3: Add FloatingStopButton to UI**

```dart
// lib/features/chat/presentation/screens/chat_screen.dart

// Add import:
import '../widgets/floating_stop_button.dart';
import '../../../core/services/audio/interruption_service.dart';

// Find the Scaffold widget and wrap body with Stack:

// OLD:
Scaffold(
  body: // existing body content,
  // ...
);

// NEW:
Scaffold(
  body: Stack(
    children: [
      // existing body content,
      const FloatingStopButton(),
    ],
  ),
  // ...
);

// Also add BlocProvider for InterruptionService if not already present:
// Wrap the Scaffold with BlocProvider:

// OLD:
return Scaffold(...);

// NEW:
return BlocProvider.value(
  value: context.read<InterruptionService>(),
  child: Scaffold(...),
);
```

**Step 4: Add MultiBlocListener for interruption feedback**

```dart
// lib/features/chat/presentation/screens/chat_screen.dart

// Wrap the Scaffold with MultiBlocListener:

MultiBlocListener(
  listeners: [
    // Existing listeners...
    BlocListener<ChatMessageCubit, ChatMessageState>(
      listenWhen: (previous, current) =>
        previous.status != current.status,
      listener: (context, state) {
        state.whenOrNull(
          interrupted: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Response interrupted'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      },
    ),
  ],
  child: Scaffold(...),
)
```

**Step 5: Verify no compilation errors**

```bash
flutter analyze
```

Expected: No errors

**Step 6: Commit**

```bash
git add lib/features/chat/presentation/screens/chat_screen.dart
git commit -m "feat: integrate FloatingStopButton into chat screen

- Add FloatingStopButton to chat screen UI
- Wrap body with Stack to support overlay
- Add BlocProvider for InterruptionService
- Show snackbar when response interrupted
- Use MultiBlocListener for state handling

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: Run All Tests and Final Verification

**Step 1: Run all unit tests**

```bash
flutter test
```

Expected: All tests PASS

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

**Step 3: Test on device (manual testing checklist)**

- [ ] Launch app on device/simulator
- [ ] Start a conversation
- [ ] Verify floating stop button appears when assistant starts talking
- [ ] Tap stop button
- [ ] Verify audio stops immediately
- [ ] Verify animation stops
- [ ] Verify partial response remains in chat
- [ ] Verify "Response interrupted" snackbar appears
- [ ] Try multiple interruptions in a row
- [ ] Try interruption when not talking (should be no-op)

**Step 4: Fix any issues found during testing**

**Step 5: Final commit**

```bash
git add .
git commit -m "test: ensure all tests pass and code is analyzed

- Run full test suite
- Run flutter analyze
- Manual device testing completed

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: Reset InterruptionState on New Conversation

**Files:**
- Modify: `lib/features/chat/bloc/chat_message_cubit.dart`

**Step 1: Reset interruption when starting new conversation**

```dart
// lib/features/chat/bloc/chat_message_cubit.dart

// In askYofardev method, at the beginning:

Future<void> askYofardev(
  String prompt, {
  required bool onlyText,
  String? attachedImage,
  required Avatar avatar,
  required Chat currentChat,
  required String language,
  void Function(Chat updatedChat)? onChatUpdated,
}) async {
  // Reset interruption state at start of new conversation
  _interruptionService.reset();

  emit(
    state.copyWith(
      audioPathsWaitingSentences: <Map<String, dynamic>>[],
      status: ChatMessageStatus.streaming,
      streamingContent: '',
      streamingSentenceCount: 0,
    ),
  );

  // ... rest of method
}
```

**Step 2: Run tests**

```bash
flutter test test/features/chat/bloc/chat_message_cubit_test.dart
```

Expected: All tests PASS

**Step 3: Commit**

```bash
git add lib/features/chat/bloc/chat_message_cubit.dart
git commit -m "feat: reset interruption state on new conversation

- Call InterruptionService.reset() when starting new message
- Ensures interruption state doesn't persist across conversations

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Summary

This implementation plan follows TDD principles and the flutter-architecture standards:

✅ **Core Service Pattern**: InterruptionService as centralized service
✅ **Cubit-based State Management**: No BLoC needed
✅ **Stream-based Communication**: Reactive interruption broadcasting
✅ **Dependency Injection**: All components wired via get_it
✅ **Test-Driven Development**: Tests written before implementation
✅ **Clean Architecture**: Core service, feature-specific integration
✅ **Frequent Commits**: Each task committed independently

**Total Estimated Time**: 2-3 hours for full implementation

**Key Files Created**:
- `lib/core/services/audio/interruption_service.dart`
- `lib/features/chat/widgets/floating_stop_button.dart`

**Key Files Modified**:
- `lib/features/chat/bloc/chat_message_state.dart`
- `lib/features/chat/bloc/chat_message_cubit.dart`
- `lib/features/sound/domain/tts_queue_manager.dart`
- `lib/features/talking/presentation/bloc/talking_cubit.dart`
- `lib/core/di/injection.dart`
- `lib/features/chat/presentation/screens/chat_screen.dart`

**Testing Coverage**:
- Unit tests for InterruptionService
- Integration tests for all modified cubits
- Widget tests for FloatingStopButton
- Manual device testing checklist
