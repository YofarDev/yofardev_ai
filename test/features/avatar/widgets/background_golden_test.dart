import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import '../../../helpers/golden_test_helper.dart';

class MockAvatarAnimationService implements AvatarAnimationService {
  @override
  Stream<AvatarAnimation> get animations =>
      const Stream<AvatarAnimation>.empty();

  @override
  void dispose() {}

  @override
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {}

  @override
  void emitUpdateConfig(String chatId, AvatarConfig config) {}

  @override
  void trigger(AvatarAnimation animation) {}
}

class MockAudioPlayerService implements AudioPlayerService {
  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {}

  @override
  Future<Duration> play(String audioPath) async => Duration.zero;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  Stream<void> get onPlaybackComplete => const Stream<void>.empty();
}

class MockAppLifecycleService implements AppLifecycleService {
  @override
  Stream<AvatarChangeRequested> get avatarChangeRequestedEvents =>
      const Stream<AvatarChangeRequested>.empty();

  @override
  Stream<AvatarMood> get moodEvents => const Stream<AvatarMood>.empty();

  @override
  void emitAvatarChangeRequested(AvatarChangeRequested request) {}

  @override
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      const Stream<NewChatEntryPayload>.empty();

  @override
  Stream<String> get chatChangedEvents => const Stream<String>.empty();

  @override
  Stream<ChatStatus> get streamingStateChangedEvents =>
      const Stream<ChatStatus>.empty();

  @override
  Stream<AvatarStatusAnimation> get avatarAnimationChangedEvents =>
      const Stream<AvatarStatusAnimation>.empty();

  @override
  Stream<TalkingPhase> get talkingStateChangedEvents =>
      const Stream<TalkingPhase>.empty();

  @override
  Stream<DemoScript> get demoScriptChangedEvents =>
      const Stream<DemoScript>.empty();

  @override
  void dispose() {}

  @override
  void emitAvatarAnimationChanged(AvatarStatusAnimation statusAnimation) {}

  @override
  void emitChatChanged(String chatId) {}

  @override
  void emitDemoScriptChanged(DemoScript script) {}

  @override
  void emitNewChatEntry(
    ChatEntry entry,
    String chatId,
    AvatarConfig currentAvatarConfig,
  ) {}

  @override
  void emitStreamingStateChanged(ChatStatus status) {}

  @override
  void emitTalkingStateChanged(TalkingPhase phase) {}
}

class MockAvatarRepository implements AvatarRepository {
  @override
  Future<Result<Chat>> getChat(String chatId) async {
    final Chat chat = Chat(
      id: chatId,
      title: 'Test Chat',
      persona: ChatPersona.assistant,
      avatar: const Avatar(background: AvatarScene.beach),
    );
    return Result<Chat>.ok(chat);
  }

  @override
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar) async {
    return Result<void>.ok(null);
  }
}

void main() {
  group('Background Golden Tests', () {
    late AvatarCubit avatarCubit;
    late MockAvatarAnimationService mockAnimationService;
    late MockAudioPlayerService mockAudioService;
    late MockAppLifecycleService mockLifecycleService;

    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    setUp(() {
      mockAnimationService = MockAvatarAnimationService();
      mockAudioService = MockAudioPlayerService();
      mockLifecycleService = MockAppLifecycleService();
      avatarCubit = AvatarCubit(
        MockAvatarRepository(),
        mockAnimationService,
        mockAudioService,
        mockLifecycleService,
      );
      avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
    });

    tearDown(() {
      avatarCubit.close();
    });

    Widget makeTestableWidget() {
      return BlocProvider<AvatarCubit>.value(
        value: avatarCubit,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 400,
              child: Stack(
                children: const <Widget>[AnimatedBackgroundAvatar()],
              ),
            ),
          ),
        ),
      );
    }

    testGoldens(
      'initial random background state - UI shows random background',
      (WidgetTester tester) async {
        avatarCubit.loadAvatar('test-chat');
        await tester.pumpWidget(makeTestableWidget());
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'background_initial_random');
      },
    );

    testGoldens('after LLM tool call changes background to beach', (
      WidgetTester tester,
    ) async {
      avatarCubit.loadAvatar('test-chat');
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      avatarCubit.updateAvatarConfig(
        'test-chat',
        const AvatarConfig(background: AvatarScene.beach),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'background_changed_to_beach');
    });

    testGoldens('after LLM tool call changes background to forest', (
      WidgetTester tester,
    ) async {
      avatarCubit.loadAvatar('test-chat');
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      avatarCubit.updateAvatarConfig(
        'test-chat',
        const AvatarConfig(background: AvatarScene.campfire),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'background_changed_to_campfire');
    });
  });
}
