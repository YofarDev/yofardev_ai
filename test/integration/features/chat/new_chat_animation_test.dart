import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';

import 'package:yofardev_ai/features/chat/presentation/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chats_state.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/avatar/domain/repositories/avatar_repository.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';

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

void main() {
  group('New Chat Animation Integration', () {
    late MockChatRepository mockChatRepository;
    late MockSettingsRepository mockSettingsRepository;
    late ChatsCubit chatsCubit;
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

      // Create ChatsCubit with mocked dependencies
      chatsCubit = ChatsCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        avatarAnimationService: avatarAnimationService,
      );

      // Initialize the cubit
      await chatsCubit.init();
    });

    tearDown(() {
      chatsCubit.close();
      avatarCubit.close();
    });

    testWidgets('complete animation sequence on new chat', (
      WidgetTester tester,
    ) async {
      // Arrange - Build app with cubits
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <SingleChildWidget>[
              BlocProvider<ChatsCubit>.value(value: chatsCubit),
              BlocProvider<AvatarCubit>.value(value: avatarCubit),
            ],
            child: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<ChatsCubit>().createNewChat();
                    },
                    child: const Text('New Chat'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.initial);

      // Act - Create new chat
      await tester.tap(find.text('New Chat'));
      await tester.pump();

      // Assert - Initial state: avatar dropping
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop to complete (based on AppConstants.changingAvatarDuration)
      await tester.pump(const Duration(seconds: 1));

      // Avatar should now be rising (after background slide)
      await tester.pump(const Duration(milliseconds: 600));
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.rising);

      // Wait for rise to complete
      await tester.pumpAndSettle();

      // Final state - animation complete, chat created successfully
      expect(chatsCubit.state.status, ChatsStatus.success);
      expect(chatsCubit.state.currentChat.id, 'test-chat-id');
    });

    testWidgets('background slides during animation', (
      WidgetTester tester,
    ) async {
      // Arrange - Build app with cubits
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <SingleChildWidget>[
              BlocProvider<ChatsCubit>.value(value: chatsCubit),
              BlocProvider<AvatarCubit>.value(value: avatarCubit),
            ],
            child: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<ChatsCubit>().createNewChat();
                    },
                    child: const Text('New Chat'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final AvatarBackgrounds initialBackground =
          avatarCubit.state.avatar.background;

      // Act - Create new chat
      await tester.tap(find.text('New Chat'));
      await tester.pump();

      // Wait for drop animation to start
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop to complete and background slide to start
      await tester.pump(const Duration(seconds: 1));

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

      // Subscribe to state changes
      avatarCubit.stream.listen((AvatarState state) {
        animationStates.add(state.statusAnimation);
        backgroundTransitions.add(state.backgroundTransition);
      });

      // Act - Create new chat
      await chatsCubit.createNewChat();

      // Wait for animations to complete
      await Future<void>.delayed(const Duration(seconds: 3));

      // Assert - Verify animation sequence
      expect(animationStates, contains(AvatarStatusAnimation.dropping));
      expect(animationStates, contains(AvatarStatusAnimation.rising));

      // Background should have transitioned
      expect(backgroundTransitions, contains(BackgroundTransition.sliding));
      expect(backgroundTransitions, contains(BackgroundTransition.none));

      // Final state should be success
      expect(chatsCubit.state.status, ChatsStatus.success);
    });

    test('avatar cubit receives correct animation states', () async {
      // Act - Create new chat
      await chatsCubit.createNewChat();

      // Immediately after creation, avatar should be dropping
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.dropping);

      // Wait for drop duration + background slide
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      // Avatar should now be rising
      expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.rising);

      // Wait for rise to complete
      await Future<void>.delayed(const Duration(seconds: 1));

      // Verify chat was created successfully
      expect(chatsCubit.state.status, ChatsStatus.success);
      expect(chatsCubit.state.currentChat.id, isNotEmpty);
    });
  });
}
