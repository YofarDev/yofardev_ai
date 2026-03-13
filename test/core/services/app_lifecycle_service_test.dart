import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_cubit.dart';

// Mock classes
class MockHomeCubit extends Mock implements HomeCubit {}

class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

class MockChatCubit extends Mock implements ChatCubit {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(const AvatarConfig());
  });

  late AppLifecycleService service;
  late MockHomeCubit mockHomeCubit;
  late MockAvatarCubit mockAvatarCubit;
  late MockTalkingCubit mockTalkingCubit;
  late MockChatCubit mockChatCubit;

  setUp(() {
    mockHomeCubit = MockHomeCubit();
    mockAvatarCubit = MockAvatarCubit();
    mockTalkingCubit = MockTalkingCubit();
    mockChatCubit = MockChatCubit();

    // Setup default behavior
    when(() => mockHomeCubit.startVolumeFade(any())).thenAnswer((_) async {});
    when(() => mockHomeCubit.startWaitingTtsLoop()).thenReturn(null);
    when(() => mockHomeCubit.stopWaitingTtsLoop()).thenReturn(null);
    when(() => mockAvatarCubit.loadAvatar(any())).thenReturn(null);
    when(
      () => mockAvatarCubit.onNewAvatarConfig(any(), any()),
    ).thenReturn(null);
    when(() => mockTalkingCubit.setLoadingStatus(any())).thenReturn(null);
    when(() => mockTalkingCubit.stop()).thenAnswer((_) async {});
    when(
      () => mockChatCubit.updateAvatarOpenedChat(any()),
    ).thenAnswer((_) async {});

    service = AppLifecycleService(
      homeCubit: mockHomeCubit,
      avatarCubit: mockAvatarCubit,
      talkingCubit: mockTalkingCubit,
      chatCubit: mockChatCubit,
    );
  });

  group('AppLifecycleService', () {
    group('onNewChatEntry', () {
      test('skips non-yofardev entries', () {
        final ChatEntry userEntry = ChatEntry(
          id: '1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        );

        service.onNewChatEntry(userEntry, 'chat1');

        verifyNever(() => mockAvatarCubit.onNewAvatarConfig(any(), any()));
        verifyNever(() => mockChatCubit.updateAvatarOpenedChat(any()));
      });

      test('skips empty yofardev entries', () {
        final ChatEntry emptyEntry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '',
          timestamp: DateTime.now(),
        );

        service.onNewChatEntry(emptyEntry, 'chat1');

        verifyNever(() => mockAvatarCubit.onNewAvatarConfig(any(), any()));
        verifyNever(() => mockChatCubit.updateAvatarOpenedChat(any()));
      });

      test('updates avatar when background changes', () {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{"background": "beach"}',
          timestamp: DateTime.now(),
        );

        when(() => mockAvatarCubit.state).thenReturn(
          AvatarState(
            avatar: const Avatar(
              background: AvatarBackgrounds.lake,
              hat: AvatarHat.noHat,
              top: AvatarTop.pinkHoodie,
              glasses: AvatarGlasses.glasses,
              specials: AvatarSpecials.onScreen,
              costume: AvatarCostume.none,
            ),
            avatarConfig: const AvatarConfig(),
          ),
        );

        service.onNewChatEntry(entry, 'chat1');

        verify(
          () => mockAvatarCubit.onNewAvatarConfig(
            'chat1',
            any(
              that: isA<AvatarConfig>().having(
                (AvatarConfig c) => c.specials,
                'specials',
                AvatarSpecials.leaveAndComeBack,
              ),
            ),
          ),
        );
        verify(() => mockChatCubit.updateAvatarOpenedChat(any()));
      });

      test('updates avatar when clothes change', () {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{"top": "swimsuit"}',
          timestamp: DateTime.now(),
        );

        when(() => mockAvatarCubit.state).thenReturn(
          AvatarState(
            avatar: const Avatar(
              background: AvatarBackgrounds.lake,
              hat: AvatarHat.noHat,
              top: AvatarTop.pinkHoodie,
              glasses: AvatarGlasses.glasses,
              specials: AvatarSpecials.onScreen,
              costume: AvatarCostume.none,
            ),
            avatarConfig: const AvatarConfig(),
          ),
        );

        service.onNewChatEntry(entry, 'chat1');

        verify(
          () => mockAvatarCubit.onNewAvatarConfig(
            'chat1',
            any(
              that: isA<AvatarConfig>().having(
                (AvatarConfig c) => c.specials,
                'specials',
                AvatarSpecials.outOfScreen,
              ),
            ),
          ),
        );
        verify(() => mockChatCubit.updateAvatarOpenedChat(any()));
      });

      test('does not update avatar when config is null', () {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{}',
          timestamp: DateTime.now(),
        );

        when(() => mockAvatarCubit.state).thenReturn(
          AvatarState(
            avatar: const Avatar(
              background: AvatarBackgrounds.lake,
              hat: AvatarHat.noHat,
              top: AvatarTop.pinkHoodie,
              glasses: AvatarGlasses.glasses,
              specials: AvatarSpecials.onScreen,
              costume: AvatarCostume.none,
            ),
            avatarConfig: const AvatarConfig(),
          ),
        );

        service.onNewChatEntry(entry, 'chat1');

        verifyNever(() => mockAvatarCubit.onNewAvatarConfig(any(), any()));
        verifyNever(() => mockChatCubit.updateAvatarOpenedChat(any()));
      });
    });

    group('onStreamingStateChanged', () {
      test('sets loading status when streaming starts', () {
        service.onStreamingStateChanged(ChatStatus.streaming);

        verify(() => mockTalkingCubit.setLoadingStatus(true)).called(1);
      });

      test('sets loading status when typing', () {
        service.onStreamingStateChanged(ChatStatus.typing);

        verify(() => mockTalkingCubit.setLoadingStatus(true)).called(1);
      });

      test('stops on error', () {
        service.onStreamingStateChanged(ChatStatus.error);

        verify(() => mockTalkingCubit.stop()).called(1);
      });

      test('stops on interruption', () {
        service.onStreamingStateChanged(ChatStatus.interrupted);

        verify(() => mockTalkingCubit.stop()).called(1);
      });

      test('does nothing on initial status', () {
        service.onStreamingStateChanged(ChatStatus.initial);

        verifyNever(() => mockTalkingCubit.setLoadingStatus(any()));
        verifyNever(() => mockTalkingCubit.stop());
      });

      test('does nothing on success', () {
        service.onStreamingStateChanged(ChatStatus.success);

        verifyNever(() => mockTalkingCubit.setLoadingStatus(any()));
        verifyNever(() => mockTalkingCubit.stop());
      });
    });

    group('onAvatarAnimationChanged', () {
      test('does nothing on initial animation', () async {
        await service.onAvatarAnimationChanged(AvatarStatusAnimation.initial);

        verifyNever(() => mockHomeCubit.startVolumeFade(any()));
      });

      test('starts volume fade on leaving animation', () async {
        await service.onAvatarAnimationChanged(AvatarStatusAnimation.leaving);

        verify(() => mockHomeCubit.startVolumeFade(false)).called(1);
      });

      test('starts volume fade on non-leaving animation', () async {
        await service.onAvatarAnimationChanged(AvatarStatusAnimation.coming);

        verify(() => mockHomeCubit.startVolumeFade(true)).called(1);
      });
    });

    group('onTalkingStateChanged', () {
      late BuildContext context;

      setUp(() {
        // Create a mock context
        context = MockBuildContext();
      });

      test('stops waiting TTS loop on idle', () {
        const TalkingState state = TalkingState.idle();

        service.onTalkingStateChanged(state, context);

        verify(() => mockHomeCubit.stopWaitingTtsLoop()).called(1);
      });

      test('starts waiting TTS loop on waiting', () {
        const TalkingState state = TalkingState.waiting();

        service.onTalkingStateChanged(state, context);

        verify(() => mockHomeCubit.startWaitingTtsLoop()).called(1);
      });

      test('stops waiting TTS loop on speaking', () {
        const TalkingState state = TalkingState.speaking();

        service.onTalkingStateChanged(state, context);

        verify(() => mockHomeCubit.stopWaitingTtsLoop()).called(1);
      });

      test('stops waiting TTS loop on error', () {
        const TalkingState state = TalkingState.error('Test error');

        // Note: The error state also shows a snackbar, but that requires
        // a properly set up widget tree. We verify the core logic here.
        expect(
          () => service.onTalkingStateChanged(state, context),
          throwsA(isA<TypeError>()),
        );

        // Verify the loop was stopped before the snackbar attempt
        verify(() => mockHomeCubit.stopWaitingTtsLoop()).called(1);
      });

      test('does nothing on generating', () {
        const TalkingState state = TalkingState.generating();

        service.onTalkingStateChanged(state, context);

        verifyNever(() => mockHomeCubit.startWaitingTtsLoop());
        verifyNever(() => mockHomeCubit.stopWaitingTtsLoop());
      });
    });

    group('onChatChanged', () {
      test('stops talking and loads avatar', () {
        service.onChatChanged('chat1');

        verify(() => mockTalkingCubit.stop()).called(1);
        verify(() => mockAvatarCubit.loadAvatar('chat1')).called(1);
      });
    });
  });
}

// Mock BuildContext for testing
class MockBuildContext extends Mock implements BuildContext {
  @override
  bool get mounted => true;
}
