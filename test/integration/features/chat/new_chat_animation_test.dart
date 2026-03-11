import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yofardev_ai/core/services/stream_processor/sentence_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';

import 'package:yofardev_ai/core/res/app_constants.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/features/avatar/domain/repositories/avatar_repository.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';

// Mock repositories
class MockChatRepository extends Mock implements ChatRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAvatarRepository extends Mock implements AvatarRepository {
  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return const Right<Exception, void>(null);
  }
}

class MockInterruptionService implements InterruptionService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get interruptionStream => _controller.stream;

  @override
  Future<void> interrupt() async => _controller.add(null);

  @override
  void reset() {}

  @override
  bool get isInterrupted => false;

  @override
  void dispose() => _controller.close();
}

class MockPromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'Test system prompt';
}

class MockStreamProcessorService implements StreamProcessorService {
  @override
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    // Empty implementation for testing
  }
}

class MockChatEntryService implements ChatEntryService {
  @override
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async {
    return ChatEntry(
      id: 'test-id',
      entryType: EntryType.user,
      body: prompt,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
  }
}

void main() {
  group('New Chat Animation Integration', () {
    late MockChatRepository mockChatRepository;
    late MockSettingsRepository mockSettingsRepository;
    late ChatCubit chatsCubit;
    late AvatarCubit avatarCubit;
    late AvatarAnimationService avatarAnimationService;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(const Chat());
      registerFallbackValue(const AvatarConfig());
    });

    setUp(() async {
      // Initialize mocks
      mockChatRepository = MockChatRepository();
      mockSettingsRepository = MockSettingsRepository();
      final MockAvatarRepository mockAvatarRepository = MockAvatarRepository();

      // Setup mock behaviors for avatar repository
      when(
        () => mockAvatarRepository.getChat(any()),
      ).thenAnswer((_) async => Left<Exception, Chat>(Exception('Not found')));

      // Setup mock behaviors
      when(
        () =>
            mockChatRepository.createNewChat(language: any(named: 'language')),
      ).thenAnswer(
        (_) async => Right<Exception, Chat>(
          Chat(
            id: 'test-chat-id',
            avatar: const Avatar(background: AvatarBackgrounds.forest),
          ),
        ),
      );

      when(
        () => mockSettingsRepository.getLanguage(),
      ).thenAnswer((_) async => const Right<Exception, String?>('en'));
      when(
        () => mockSettingsRepository.getSoundEffects(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));

      when(
        () => mockChatRepository.getCurrentChat(),
      ).thenAnswer((_) async => Right<Exception, Chat>(Chat()));

      // Create AvatarCubit first (AvatarAnimationService depends on it)
      avatarCubit = AvatarCubit(mockAvatarRepository);
      avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);

      // Create AvatarAnimationService
      avatarAnimationService = AvatarAnimationService(avatarCubit);

      // Create mock services
      final MockInterruptionService mockInterruptionService =
          MockInterruptionService();
      final MockPromptDatasource mockPromptDatasource = MockPromptDatasource();
      final MockStreamProcessorService mockStreamProcessorService =
          MockStreamProcessorService();
      final MockChatEntryService mockChatEntryService = MockChatEntryService();

      // Create ChatCubit with mocked dependencies
      chatsCubit = ChatCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        avatarAnimationService: avatarAnimationService,
        chatTitleService: ChatTitleService(
          chatRepository: mockChatRepository,
          llmService: LlmService(),
        ),
        llmService: LlmService(),
        streamProcessor: mockStreamProcessorService,
        promptDatasource: mockPromptDatasource,
        interruptionService: mockInterruptionService,
        chatEntryService: mockChatEntryService,
      );

      // Initialize the cubit
      await chatsCubit.init();
    });

    tearDown(() {
      chatsCubit.close();
      avatarCubit.close();
    });

    /// Helper method to build the test widget
    Widget buildTestWidget() {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<ChatCubit>.value(value: chatsCubit),
            BlocProvider<AvatarCubit>.value(value: avatarCubit),
          ],
          child: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<ChatCubit>().createNewChat();
                  },
                  child: const Text('New Chat'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('complete animation sequence on new chat', (
      WidgetTester tester,
    ) async {
      // Arrange - Build app with cubits
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify initial state
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.initial);

      // Act - Create new chat
      await tester.tap(find.text('New Chat'));
      await tester.pump();

      // Assert - Initial state: avatar dropping
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop to complete (using AppConstants)
      await tester.pump(Duration(seconds: AppConstants.changingAvatarDuration));

      // Avatar should now be rising (after background slide)
      await tester.pump(const Duration(milliseconds: 600));
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.rising);

      // Assert - Background transition should be sliding during animation
      expect(
        avatarCubit.state.backgroundTransition,
        BackgroundTransition.sliding,
      );

      // Wait for rise to complete
      await tester.pumpAndSettle();

      // Final state - animation complete, chat created successfully
      expect(chatsCubit.state.status, ChatStatus.success);
      expect(chatsCubit.state.currentChat.id, 'test-chat-id');
    });

    testWidgets('background slides during animation', (
      WidgetTester tester,
    ) async {
      // Arrange - Build app with cubits
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Act - Create new chat
      await tester.tap(find.text('New Chat'));
      await tester.pump();

      // Wait for drop animation to start
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop to complete and background slide to start (using AppConstants)
      await tester.pump(Duration(seconds: AppConstants.changingAvatarDuration));

      // Assert - Background transition should be sliding
      expect(
        avatarCubit.state.backgroundTransition,
        BackgroundTransition.sliding,
      );

      // Wait for slide to complete
      await tester.pump(const Duration(milliseconds: 600));

      // Background transition should be sliding at this point
      expect(
        avatarCubit.state.backgroundTransition,
        BackgroundTransition.sliding,
      );
    });

    test('animation sequence transitions through correct states', () async {
      // Track state transitions
      final List<AvatarStatusAnimation> animationStates =
          <AvatarStatusAnimation>[];
      final List<BackgroundTransition> backgroundTransitions =
          <BackgroundTransition>[];

      // Subscribe to state changes and store subscription for cleanup
      final StreamSubscription<AvatarState> subscription = avatarCubit.stream
          .listen((AvatarState state) {
            animationStates.add(state.statusAnimation);
            backgroundTransitions.add(state.backgroundTransition);
          });

      // Act - Create new chat
      await chatsCubit.createNewChat();

      // Wait for animations to complete (using AppConstants + buffer)
      await Future<void>.delayed(
        Duration(seconds: AppConstants.changingAvatarDuration + 2),
      );

      // Assert - Verify animation sequence
      expect(animationStates, contains(AvatarStatusAnimation.dropping));
      expect(animationStates, contains(AvatarStatusAnimation.rising));

      // Background should have transitioned
      expect(backgroundTransitions, contains(BackgroundTransition.sliding));
      expect(backgroundTransitions, contains(BackgroundTransition.none));

      // Final state should be success
      expect(chatsCubit.state.status, ChatStatus.success);

      // Clean up subscription
      await subscription.cancel();
    });

    test('avatar cubit receives correct animation states', () async {
      // Act - Create new chat
      await chatsCubit.createNewChat();

      // Immediately after creation, avatar should be dropping
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop duration + background slide (using AppConstants)
      await Future<void>.delayed(
        Duration(
          milliseconds: AppConstants.changingAvatarDuration * 1000 + 600,
        ),
      );

      // Avatar should now be rising
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.rising);

      // Wait for rise to complete (using AppConstants)
      await Future<void>.delayed(
        Duration(seconds: AppConstants.changingAvatarDuration),
      );

      // Assert - Complete state sequence verified
      // Final state should be initial again after animation completes
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.initial);

      // Background should return to none after animation
      expect(avatarCubit.state.backgroundTransition, BackgroundTransition.none);

      // Verify chat was created successfully
      expect(chatsCubit.state.status, ChatStatus.success);
      expect(chatsCubit.state.currentChat.id, isNotEmpty);
    });
  });
}
