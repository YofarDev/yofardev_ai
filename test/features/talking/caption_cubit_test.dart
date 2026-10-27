import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/caption_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/caption_state.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockTalkingRepository extends Mock implements TalkingRepository {}

/// Playback service whose event stream the test drives directly.
class _FakePlaybackService extends TtsPlaybackService {
  _FakePlaybackService() : super(_MockTalkingRepository());

  final StreamController<PlaybackEvent> _events =
      StreamController<PlaybackEvent>.broadcast(sync: true);

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  void add(PlaybackEvent event) => _events.add(event);

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

void main() {
  late _FakePlaybackService playback;
  late InterruptionService interruption;
  late _MockSettingsRepository settings;

  setUp(() {
    playback = _FakePlaybackService();
    interruption = InterruptionService();
    settings = _MockSettingsRepository();
    when(
      () => settings.getCaptionsEnabled(),
    ).thenAnswer((_) async => const Result<bool>.ok(true));
    when(
      () => settings.setCaptionsEnabled(any()),
    ).thenAnswer((_) async => const Result<void>.ok(null));
  });

  tearDown(() {
    playback.dispose();
    interruption.dispose();
  });

  CaptionCubit build() => CaptionCubit(
    playbackService: playback,
    interruptionService: interruption,
    settingsRepository: settings,
  );

  test('initial state has no text, seq 0, captions enabled', () {
    final CaptionCubit cubit = build();
    expect(cubit.state, const CaptionState());
    expect(cubit.state.enabled, isTrue);
    cubit.close();
  });

  blocTest<CaptionCubit, CaptionState>(
    'shows the caption of the sentence that starts speaking',
    build: build,
    act: (_) => playback.add(const CaptionEvent('Hello there.')),
    expect: () => <CaptionState>[
      const CaptionState(text: 'Hello there.', seq: 1),
    ],
  );

  test('stop then a new caption within 1200 ms never clears', () {
    fakeAsync((FakeAsync async) {
      final CaptionCubit cubit = build();
      final List<CaptionState> states = <CaptionState>[];
      final StreamSubscription<CaptionState> sub = cubit.stream.listen(
        states.add,
      );

      playback.add(const CaptionEvent('One.'));
      playback.add(const SpeakingStoppedEvent());
      async.elapse(const Duration(milliseconds: 800));
      playback.add(const CaptionEvent('Two.'));
      async.elapse(const Duration(milliseconds: 2000));
      async.flushMicrotasks();

      expect(states.map((CaptionState s) => s.text), <String?>['One.', 'Two.']);
      expect(cubit.state.text, 'Two.');
      expect(cubit.state.seq, 2);

      sub.cancel();
      cubit.close();
      async.flushMicrotasks();
    });
  });

  test('stop alone clears the caption after 1200 ms', () {
    fakeAsync((FakeAsync async) {
      final CaptionCubit cubit = build();

      playback.add(const CaptionEvent('One.'));
      playback.add(const SpeakingStoppedEvent());
      async.elapse(const Duration(milliseconds: 1199));
      expect(cubit.state.text, 'One.');
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state.text, isNull);
      expect(cubit.state.seq, 1);

      cubit.close();
      async.flushMicrotasks();
    });
  });

  test('an interruption clears the caption at once', () {
    fakeAsync((FakeAsync async) {
      final CaptionCubit cubit = build();

      playback.add(const CaptionEvent('One.'));
      interruption.interrupt();
      async.flushMicrotasks();
      expect(cubit.state.text, isNull);

      cubit.close();
      async.flushMicrotasks();
    });
  });

  blocTest<CaptionCubit, CaptionState>(
    'init() loads the persisted preference',
    setUp: () {
      when(
        () => settings.getCaptionsEnabled(),
      ).thenAnswer((_) async => const Result<bool>.ok(false));
    },
    build: build,
    act: (CaptionCubit cubit) => cubit.init(),
    expect: () => <CaptionState>[const CaptionState(enabled: false)],
  );

  blocTest<CaptionCubit, CaptionState>(
    'init() keeps captions on when the preference cannot be read',
    setUp: () {
      when(
        () => settings.getCaptionsEnabled(),
      ).thenAnswer((_) async => const Result<bool>.err(StorageFailure('boom')));
    },
    build: build,
    act: (CaptionCubit cubit) => cubit.init(),
    expect: () => <CaptionState>[],
  );

  blocTest<CaptionCubit, CaptionState>(
    'toggle() flips enabled and persists it',
    build: build,
    act: (CaptionCubit cubit) => cubit.toggle(),
    expect: () => <CaptionState>[const CaptionState(enabled: false)],
    verify: (_) {
      verify(() => settings.setCaptionsEnabled(false)).called(1);
    },
  );
}
