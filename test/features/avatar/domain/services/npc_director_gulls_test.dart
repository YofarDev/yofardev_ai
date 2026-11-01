import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/gull_flock.dart';
import 'package:yofardev_ai/features/avatar/domain/services/npc_director.dart';

/// Moonshot M9 ruling 10: the beach's gulls (the second NPC slot) inside the
/// director, on a fake clock; the pure tree is covered by `gull_flock_test`.
void main() {
  final DateTime start = DateTime(2026, 10, 31, 20);

  void run(
    AvatarScene scene,
    void Function(FakeAsync async, NpcDirector npc) body,
  ) {
    fakeAsync((FakeAsync async) {
      final NpcDirector npc = NpcDirector(
        now: () => start.add(async.elapsed),
        random: math.Random(3),
        scene: scene,
      );
      body(async, npc);
      npc.dispose();
    });
  }

  void ms(FakeAsync async, int value) =>
      async.elapse(Duration(milliseconds: value));
  void s(FakeAsync async, int value) => async.elapse(Duration(seconds: value));

  NpcState gulls(NpcDirector npc) => npc.gullIntent.value.npc;
  double gullX(NpcDirector npc) => npc.gullIntent.value.npcX;

  /// Lands the gulls (12 s calm and the 2.5 s flight).
  void land(FakeAsync async, NpcDirector npc) {
    s(async, 12);
    ms(async, 2600);
    expect(gulls(npc), NpcState.idle);
  }

  const EmotionVector excited = EmotionVector(valence: 0.3, arousal: 0.8);
  const EmotionVector calmTalk = EmotionVector(valence: 0.3, arousal: 0.4);

  test('away on every scene but the beach, and they never land there', () {
    for (final AvatarScene scene in AvatarScene.values) {
      run(scene, (FakeAsync async, NpcDirector npc) {
        expect(npc.gullIntent.value, NpcIntent.away, reason: scene.name);
        s(async, 60);
        if (scene != AvatarScene.beach) {
          expect(npc.gullIntent.value, NpcIntent.away, reason: scene.name);
        }
      });
    }
  });

  test('on the beach they land after 12 s of calm: move over 2.5 s, idle', () {
    run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
      expect(npc.gullIntent.value, NpcIntent.away);
      ms(async, 11900);
      expect(gulls(npc), NpcState.away);
      ms(async, 200);
      expect(gulls(npc), NpcState.move);
      expect(npc.gullIntent.value.npcLook, GullFlock.landLook);
      ms(async, 1250);
      expect(gullX(npc), inInclusiveRange(0.2, 0.8));
      ms(async, 1300);
      expect(npc.gullIntent.value, const NpcIntent(npc: NpcState.idle));
    });
  });

  test('the crab is not disturbed by the gulls', () {
    run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
      land(async, npc);
      expect(npc.intent.value, NpcIntent.rest);
    });
  });

  group('startles', () {
    test('a seagulls event: react 0.6 s, fly off 1.5 s, away', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.onSceneEvent(SceneEvent.seagulls);
        expect(gulls(npc), NpcState.react);
        ms(async, 500);
        expect(gulls(npc), NpcState.react);
        ms(async, 200);
        expect(gulls(npc), NpcState.move);
        expect(npc.gullIntent.value.npcLook, GullFlock.flyOffLook);
        ms(async, 700);
        expect(gullX(npc), closeTo(0.5, 0.1));
        ms(async, 900);
        expect(npc.gullIntent.value, NpcIntent.away);
      });
    });

    test('a bigWave event does the same', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.onSceneEvent(SceneEvent.bigWave);
        expect(gulls(npc), NpcState.react);
        ms(async, 2200);
        expect(npc.gullIntent.value, NpcIntent.away);
      });
    });

    test('a poke of the seagull prop; the crab keeps resting', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.poke('seagull');
        expect(gulls(npc), NpcState.react);
        expect(npc.intent.value, NpcIntent.rest, reason: 'not the crab');
        ms(async, 2200);
        expect(npc.gullIntent.value, NpcIntent.away);
      });
    });

    test('the crab being poked (its react) startles them too', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.poke('crab');
        expect(npc.intent.value.npc, NpcState.react);
        expect(gulls(npc), NpcState.react);
        ms(async, 2200);
        expect(npc.gullIntent.value, NpcIntent.away);
        // and the crab still does its own scuttle
        expect(npc.intent.value.npc, NpcState.move);
      });
    });

    test('other props and events leave them alone', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.poke('umbrella');
        npc.onSceneEvent(SceneEvent.sunset);
        npc.onSceneEvent(SceneEvent.lightsOff);
        expect(gulls(npc), NpcState.idle);
      });
    });

    test('the same signals mean nothing off the beach', () {
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.poke('seagull');
        npc.poke('crab');
        npc.onSceneEvent(SceneEvent.seagulls);
        s(async, 20);
        expect(npc.gullIntent.value, NpcIntent.away);
      });
    });

    test('they land again 12 s after the startle', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.poke('seagull');
        s(async, 11);
        expect(gulls(npc), NpcState.away);
        s(async, 2);
        expect(gulls(npc), NpcState.move);
        ms(async, 2600);
        expect(gulls(npc), NpcState.idle);
      });
    });

    test('the avatar speaking with arousal >= 0.7 scares and holds them', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.setEmotion(excited);
        npc.setSpeaking(true);
        expect(gulls(npc), NpcState.react);
        s(async, 3);
        expect(npc.gullIntent.value, NpcIntent.away);
        s(async, 60);
        expect(npc.gullIntent.value, NpcIntent.away, reason: 'still talking');
        npc.setSpeaking(false);
        s(async, 11);
        expect(gulls(npc), NpcState.away);
        s(async, 2);
        expect(gulls(npc), NpcState.move);
      });
    });

    test('calmer speech, or arousal without speaking, does not scare them', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.setEmotion(calmTalk);
        npc.setSpeaking(true);
        expect(gulls(npc), NpcState.idle);
        npc.setSpeaking(false);
        npc.setEmotion(excited);
        expect(gulls(npc), NpcState.idle);
      });
    });
  });

  group('rain', () {
    test('rain >= 0.5 keeps them away; they land 12 s after it stops', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.setRain(0.6);
        s(async, 60);
        expect(npc.gullIntent.value, NpcIntent.away);
        npc.setRain(0.2);
        s(async, 11);
        expect(gulls(npc), NpcState.away);
        s(async, 2);
        expect(gulls(npc), NpcState.move);
      });
    });

    test('rain on landed gulls sends them off', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.setRain(0.5);
        expect(gulls(npc), NpcState.react);
        s(async, 3);
        expect(npc.gullIntent.value, NpcIntent.away);
      });
    });

    test('steady rain schedules no timer (no polling while held away)', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.setRain(0.9);
        // the crab hides at rain too; nothing else is pending
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('tiers and accessibility', () {
    test('low tier: the gulls stay away, nothing is scheduled', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.setTier(QualityTier.low);
        npc.onSceneEvent(SceneEvent.seagulls);
        s(async, 60);
        expect(npc.gullIntent.value, NpcIntent.away);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('gulls on the sand go away at the low tier', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        land(async, npc);
        npc.setTier(QualityTier.low);
        expect(npc.gullIntent.value, NpcIntent.away);
        npc.setTier(QualityTier.high);
        expect(npc.gullIntent.value, NpcIntent.away);
        s(async, 11);
        expect(gulls(npc), NpcState.away, reason: 'the calm timer restarts');
        s(async, 2);
        expect(gulls(npc), NpcState.move);
      });
    });

    test('reduce motion: they jump in, jump out, never move or react', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        final List<NpcState> states = <NpcState>[];
        npc.gullIntent.addListener(() => states.add(gulls(npc)));
        s(async, 12);
        ms(async, 100);
        expect(gulls(npc), NpcState.away);
        expect(gullX(npc), 0, reason: 'already at the landing spot');
        ms(async, 400);
        expect(gulls(npc), NpcState.idle);
        npc.poke('seagull');
        expect(npc.gullIntent.value, NpcIntent.away);
        s(async, 14);
        expect(gulls(npc), NpcState.idle);
        expect(states, isNot(contains(NpcState.move)));
        expect(states, isNot(contains(NpcState.react)));
      });
    });
  });

  test('a scene change sends them away and starts the calm over', () {
    run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
      land(async, npc);
      npc.setScene(AvatarScene.campfire);
      expect(npc.gullIntent.value, NpcIntent.away);
      s(async, 30);
      expect(npc.gullIntent.value, NpcIntent.away);
      npc.setScene(AvatarScene.beach);
      s(async, 11);
      expect(gulls(npc), NpcState.away);
      s(async, 2);
      expect(gulls(npc), NpcState.move);
    });
  });

  test('the gull intent notifies only on a change', () {
    run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
      int calls = 0;
      npc.gullIntent.addListener(() => calls++);
      npc.setEmotion(const EmotionVector(valence: 0.1));
      s(async, 5);
      expect(calls, 0);
    });
  });

  test('the named constants are what the ruling says', () {
    expect(NpcDirector.gullPropId, 'seagull');
    expect(GullFlock.excitedArousal, 0.7);
    expect(GullFlock.rainAway, 0.5);
  });
}
