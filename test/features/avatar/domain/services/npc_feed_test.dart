import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/npc_director.dart';
import 'package:yofardev_ai/features/avatar/domain/services/npc_feed.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

void main() {
  test('the feed carries emotion, sentences, messages, scene events, rain '
      'and the tier to the director', () {
    fakeAsync((FakeAsync async) {
      final DateTime start = DateTime(2026, 10, 31);
      final NpcDirector npc = NpcDirector(
        now: () => start.add(async.elapsed),
        scene: AvatarScene.campfire,
      );
      final StreamController<PerformanceIntent> intents =
          StreamController<PerformanceIntent>.broadcast(sync: true);
      final StreamController<PlaybackEvent> playback =
          StreamController<PlaybackEvent>.broadcast(sync: true);
      final StreamController<AvatarAnimation> animations =
          StreamController<AvatarAnimation>.broadcast(sync: true);
      final StreamController<String> messages =
          StreamController<String>.broadcast(sync: true);
      final StreamController<QualityTier> tiers =
          StreamController<QualityTier>.broadcast(sync: true);
      final ValueNotifier<double> rain = ValueNotifier<double>(0);
      final NpcFeed feed = NpcFeed(
        npc: npc,
        intents: intents.stream,
        playback: playback.stream,
        animations: animations.stream,
        userMessages: messages.stream,
        rain: rain,
        tierChanges: tiers.stream,
      );

      // the owl: speaking → notice; a question sentence → idle; rain → rest
      intents.add(const PerformanceIntent(speaking: true));
      expect(npc.intent.value.npc, NpcState.notice);
      playback.add(const CaptionEvent('Can you hear it?'));
      expect(npc.intent.value.npc, NpcState.idle);
      rain.value = 0.8;
      expect(npc.intent.value.npc, NpcState.rest);
      rain.value = 0;
      async.elapse(const Duration(seconds: 4));
      expect(npc.intent.value.npc, NpcState.notice);

      // the cat: a message naming it, the walking cat's event
      npc.setScene(AvatarScene.livingRoom);
      messages.add('where is the cat?');
      expect(npc.intent.value.npc, NpcState.notice);
      async.elapse(const Duration(seconds: 4));
      animations.add(const AvatarAnimation.sceneEvent(SceneEvent.catWalksBy));
      intents.add(
        const PerformanceIntent(emotion: EmotionVector(valence: -0.8)),
      );
      expect(npc.intent.value.npc, isNot(NpcState.move));

      // the low tier holds rest
      tiers.add(QualityTier.low);
      expect(npc.intent.value, NpcIntent.rest);

      feed.dispose();
      rain.value = 1;
      npc.dispose();
      rain.dispose();
    });
  });
}
