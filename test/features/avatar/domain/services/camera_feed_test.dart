import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/camera_director.dart';
import 'package:yofardev_ai/features/avatar/domain/services/camera_feed.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

void main() {
  late StreamController<PlaybackEvent> playback;
  late StreamController<PerformanceIntent> intents;
  late StreamController<AvatarAnimation> animations;
  late EmotionVector emotion;

  void run(
    void Function(
      FakeAsync async,
      CameraDirector camera,
      List<CameraShot> shots,
    )
    body,
  ) {
    fakeAsync((FakeAsync async) {
      playback = StreamController<PlaybackEvent>.broadcast();
      intents = StreamController<PerformanceIntent>.broadcast();
      animations = StreamController<AvatarAnimation>.broadcast();
      emotion = const EmotionVector();
      final DateTime base = DateTime(2026, 10, 30, 12);
      final CameraDirector camera = CameraDirector(
        now: () => base.add(async.elapsed),
      );
      final CameraFeed feed = CameraFeed(
        camera: camera,
        playback: playback.stream,
        intents: intents.stream,
        animations: animations.stream,
        emotion: () => emotion,
      );
      final List<CameraShot> shots = <CameraShot>[];
      camera.shot.addListener(() => shots.add(camera.shot.value));
      body(async, camera, shots);
      feed.dispose();
      camera.dispose();
      unawaited(playback.close());
      unawaited(intents.close());
      unawaited(animations.close());
    });
  }

  test('a sentence frames medium with a cut', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('Hello there.'));
      async.flushMicrotasks();
      expect(shots, hasLength(1));
      expect(shots.single.shot, Shot.medium);
      expect(shots.single.move, CameraMove.cut);
    });
  });

  test('the emotion intensity earns a close-up on the second sentence', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      async.flushMicrotasks();
      emotion = const EmotionVector(valence: -0.8, arousal: 0.2);
      playback.add(const CaptionEvent('Two.'));
      async.flushMicrotasks();
      expect(shots.last.shot, Shot.closeUp);
    });
  });

  test('intensity is scaled by the emotion intensity and uses arousal', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      async.flushMicrotasks();
      // 0.9 x 0.5 = 0.45 < 0.6: no close-up
      emotion = const EmotionVector(arousal: 0.9, intensity: 0.5);
      playback.add(const CaptionEvent('Two.'));
      async.flushMicrotasks();
      expect(shots.last.shot, isNot(Shot.closeUp));
    });
  });

  test('a low arousal never counts as intensity', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      async.flushMicrotasks();
      emotion = const EmotionVector(arousal: -0.9);
      playback.add(const CaptionEvent('Two.'));
      async.flushMicrotasks();
      expect(shots.last.shot, isNot(Shot.closeUp));
    });
  });

  test('sentences within the reply gap stay one reply', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      playback.add(const AnimationCompletedEvent());
      async.elapse(const Duration(milliseconds: 800));
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('Is it two?'));
      async.flushMicrotasks();
      // a question, and not the first sentence of a reply: close-up
      expect(shots.last.shot, Shot.closeUp);
    });
  });

  test('a pause longer than the gap ends the reply', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      playback.add(const AnimationCompletedEvent());
      async.elapse(CameraFeed.replyGap + const Duration(milliseconds: 1));
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('Is it two?'));
      async.flushMicrotasks();
      // the first sentence of a new reply: medium, held (same shot)
      expect(shots.last.shot, Shot.medium);
    });
  });

  test('an interruption stops the reply at once', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('One.'));
      playback.add(const SpeakingStoppedEvent(interrupted: true));
      playback.add(const SpeakingStartedEvent());
      playback.add(const CaptionEvent('Is it two?'));
      async.flushMicrotasks();
      expect(shots.last.shot, Shot.medium);
    });
  });

  test('a prop out pushes to the insert, and back', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      intents.add(const PerformanceIntent(prop: AvatarProp.tablet));
      async.flushMicrotasks();
      expect(shots.last.shot, Shot.propInsert);
      expect(shots.last.move, CameraMove.ease);
      intents.add(const PerformanceIntent());
      async.flushMicrotasks();
      async.elapse(CameraDirector.idleDelay);
      expect(shots.last.shot, Shot.wide);
    });
  });

  test('the listening lean is composing: medium', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      intents.add(const PerformanceIntent(lean: 0.6));
      async.flushMicrotasks();
      expect(shots.last.shot, Shot.medium);
      expect(shots.last.duration, CameraDirector.thinkPush);
    });
  });

  test('a scene event pulls back and holds', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      intents.add(const PerformanceIntent(lean: 0.6));
      async.flushMicrotasks();
      animations.add(const AvatarAnimation.sceneEvent(SceneEvent.flare));
      async.flushMicrotasks();
      expect(shots.last.shot, Shot.wide);
      expect(shots.last.duration, CameraDirector.pullBack);
    });
  });

  test('other animations are ignored', () {
    run((FakeAsync async, CameraDirector camera, List<CameraShot> shots) {
      animations.add(const AvatarAnimation.clothes(true));
      async.flushMicrotasks();
      expect(shots, isEmpty);
    });
  });
}
