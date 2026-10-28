import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/gaze_target.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
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
            equals(const HeadTarget(0.6, -0.25, reading: true)),
            equals(HeadTarget.zero),
          ]),
        );
        director.setActiveTool('web_search');
        director.setActiveTool(null);
        await away;
        expect(director.current.gaze, const GazeTarget.user());
      },
    );

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
        const HeadTarget(0.6, -0.25, reading: true),
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
  });
}
