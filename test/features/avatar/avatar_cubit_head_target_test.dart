import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/avatar_prop.dart';
import 'package:yofardev_ai/core/models/performance/gaze_target.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/services/presence/composer_activity_service.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

class _MockAvatarRepository extends Mock implements AvatarRepository {}

class _MockAudioPlayerService extends Mock implements AudioPlayerService {}

class _FakeAnimationService implements AvatarAnimationService {
  @override
  Stream<AvatarAnimation> get animations =>
      const Stream<AvatarAnimation>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLifecycleService implements AppLifecycleService {
  @override
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      const Stream<NewChatEntryPayload>.empty();

  @override
  Stream<String> get chatChangedEvents => const Stream<String>.empty();

  @override
  Stream<AvatarMood> get moodEvents => const Stream<AvatarMood>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSoundRepository implements SoundRepository {
  @override
  Future<Result<void>> play(String soundPath) async => Result<void>.ok(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('AvatarCubit head target', () {
    late PerformanceDirector director;
    late AvatarCubit cubit;

    setUp(() {
      director = PerformanceDirector(now: DateTime.now);
      cubit = AvatarCubit(
        _MockAvatarRepository(),
        _FakeAnimationService(),
        _MockAudioPlayerService(),
        _FakeLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
        director: director,
      );
    });

    tearDown(() async {
      await cubit.close();
      await director.dispose();
    });

    test('starts facing the viewer', () {
      expect(cubit.state.headTarget, HeadTarget.zero);
    });

    test(
      'looks away and down while a tool runs, then back at the user',
      () async {
        final Future<void> away = expectLater(
          cubit.stream.map((AvatarState s) => s.headTarget),
          emitsInOrder(<Matcher>[
            equals(const HeadTarget(0.84, -0.5, reading: true)),
            equals(HeadTarget.zero),
          ]),
        );
        director.setActiveTool('web_search');
        director.setActiveTool(null);
        await away;
        expect(director.current.gaze, const GazeTarget.user());
      },
    );

    test('turns to the tablet (0.6, -0.5) while a lookup tool runs', () async {
      final Future<void> turned = expectLater(
        cubit.stream.map((AvatarState s) => s.headTarget),
        emitsInOrder(<Matcher>[
          equals(const HeadTarget(0.6, -0.5, reading: true)),
          equals(HeadTarget.zero),
        ]),
      );
      director.setActiveTool('getCurrentWeather');
      director.setActiveTool(null);
      await turned;
    });

    test(
      'holds the tablet while a lookup tool runs, then puts it away',
      () async {
        expect(cubit.state.prop, AvatarProp.none);
        final Future<void> held = expectLater(
          cubit.stream.map((AvatarState s) => s.prop),
          emitsInOrder(<Matcher>[
            equals(AvatarProp.tablet),
            equals(AvatarProp.none),
          ]),
        );
        director.setActiveTool('getCurrentWeather');
        director.setActiveTool(null);
        await held;
      },
    );

    test('watches the caret while the user types', () async {
      final Future<void> watching = expectLater(
        cubit.stream.map((AvatarState s) => s.headTarget),
        emits(
          predicate<HeadTarget>(
            (HeadTarget t) =>
                (t.yaw - 0.12).abs() < 1e-9 && t.pitch == kCaretPitch,
          ),
        ),
      );
      director.setComposer(
        const ComposerActivity(typing: true, caretFraction: 0.8, lastChar: 'a'),
      );
      await watching;
    });

    test('a tap on the avatar or a prop is user activity', () async {
      int signals = 0;
      final StreamSubscription<void> sub = director.activity.listen(
        (_) => signals++,
      );
      cubit.onAvatarTapped('head');
      cubit.onPropTapped(AvatarScene.livingRoom, 'tv');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(signals, 2);
    });

    test('does not emit again when the head target is unchanged', () async {
      director.setActiveTool('web_search');
      await Future<void>.delayed(Duration.zero);
      final List<AvatarState> emitted = <AvatarState>[];
      final StreamSubscription<AvatarState> sub = cubit.stream.listen(
        emitted.add,
      );
      director.setMood(AvatarMood.happy);
      director.setActiveTool('news');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(emitted, isEmpty);
      expect(
        cubit.state.headTarget,
        const HeadTarget(0.84, -0.5, reading: true),
      );
    });

    test('the cubit works without a director', () async {
      final AvatarCubit plain = AvatarCubit(
        _MockAvatarRepository(),
        _FakeAnimationService(),
        _MockAudioPlayerService(),
        _FakeLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
      );
      expect(plain.state.headTarget, HeadTarget.zero);
      await plain.close();
    });

    test(
      'the gesture_done of a prop reaction does not release the director',
      () {
        director.requestGesture(AvatarGesture.wave);
        expect(director.current.pendingGesture, AvatarGesture.wave);

        // A prop tap plays its own gesture, outside the director.
        cubit.onPropTapped(AvatarScene.livingRoom, 'tv');
        expect(cubit.state.gestureEvent.gesture, AvatarGesture.laugh);

        // Its gesture_done must not clear the director's playing wave...
        cubit.onGestureDone();
        expect(director.current.pendingGesture, AvatarGesture.wave);

        // ...while the wave's own gesture_done does.
        cubit.onGestureDone();
        expect(director.current.pendingGesture, isNull);
      },
    );
  });
}
