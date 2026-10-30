import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/npc_director.dart';

/// Moonshot M8 ruling 9: the four NPC behaviour trees, on a fake clock and a
/// seeded random.
void main() {
  final DateTime start = DateTime(2026, 10, 31, 20);

  /// Runs [body] with a director on [scene] whose clock is the fake one.
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

  NpcState state(NpcDirector npc) => npc.intent.value.npc;
  double x(NpcDirector npc) => npc.intent.value.npcX;
  double look(NpcDirector npc) => npc.intent.value.npcLook;

  final int walk = NpcDirector.catWalkLength.inMilliseconds;
  final int scuttle = NpcDirector.crabScuttleLength.inMilliseconds;

  const EmotionVector sad = EmotionVector(valence: -0.6, arousal: 0.2);
  const EmotionVector happy = EmotionVector(valence: 0.6, arousal: 0.4);
  const EmotionVector excited = EmotionVector(valence: 0.3, arousal: 0.8);

  test('every NPC but the drifting alien starts at the v10 look', () {
    for (final AvatarScene scene in AvatarScene.values) {
      run(scene, (FakeAsync async, NpcDirector npc) {
        expect(
          npc.intent.value,
          scene == AvatarScene.deepSpace
              ? const NpcIntent(npc: NpcState.idle)
              : NpcIntent.rest,
          reason: scene.name,
        );
      });
    }
  });

  test('the prop of each scene pokes its own NPC', () {
    expect(NpcKind.of(AvatarScene.livingRoom).propId, 'cat');
    expect(NpcKind.of(AvatarScene.campfire).propId, 'owl');
    expect(NpcKind.of(AvatarScene.beach).propId, 'crab');
    expect(NpcKind.of(AvatarScene.deepSpace).propId, 'ufo');
  });

  group('cat', () {
    test('poked: react 1.6 s, then notice 4 s toward the avatar', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.poke('lamp');
        expect(state(npc), NpcState.rest);
        npc.poke('cat');
        expect(state(npc), NpcState.react);
        ms(async, 1599);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.notice);
        expect(look(npc), -NpcDirector.lookAmount);
        ms(async, 3990);
        expect(state(npc), NpcState.notice);
        ms(async, 20);
        // awake now, then calm
        expect(state(npc), NpcState.idle);
      });
    });

    test('its name in a message: notice, then react', () {
      for (final String text in <String>[
        'My cat is sad',
        'what a cute kitty!',
        'Le chat dort',
        'Mon minou',
        'un chaton',
      ]) {
        run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
          npc.onUserText(text);
          expect(state(npc), NpcState.notice, reason: text);
          expect(look(npc), -NpcDirector.lookAmount);
          ms(async, 1501);
          expect(state(npc), NpcState.react, reason: text);
          ms(async, 1600);
          expect(state(npc), NpcState.idle, reason: text);
        });
      }
    });

    test('English "chat" is not the cat; French "chat" after a determiner '
        'is', () {
      for (final String text in <String>[
        "let's chat",
        'start a new chat',
        'chat with me',
      ]) {
        run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
          npc.onUserText(text);
          expect(state(npc), NpcState.rest, reason: text);
        });
      }
      for (final String text in <String>[
        'mon chat dort',
        'tes chats sont là',
        'Chaton!',
      ]) {
        run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
          npc.onUserText(text);
          expect(state(npc), NpcState.notice, reason: text);
        });
      }
    });

    test('a word that only contains the name is not a mention', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.onUserText('the category is concatenated');
        expect(state(npc), NpcState.rest);
        npc.onReplySentence('That cat is lovely.');
        expect(state(npc), NpcState.notice);
      });
    });

    test("the avatar sad: walks to the rug over the cat's walk length, sits "
        'by it', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        expect(state(npc), NpcState.move);
        ms(async, walk ~/ 2);
        expect(state(npc), NpcState.move);
        expect(x(npc), inExclusiveRange(0.2, 0.8));
        ms(async, walk ~/ 2 + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        expect(look(npc), 0);
      });
    });

    test('poke outranks the walk: it stops where it is, then resumes', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, walk ~/ 2);
        final double midway = x(npc);
        npc.poke('cat');
        expect(state(npc), NpcState.react);
        expect(x(npc), closeTo(midway, 0.02));
        ms(async, 6000);
        // sad still: back on its way to the rug
        expect(state(npc), NpcState.move);
        ms(async, walk + 100);
        expect(x(npc), 1);
        expect(state(npc), NpcState.idle);
      });
    });

    test('woken by excited speech, sleeps on the warm spot after 20 s of '
        'calm (lamp on: the rug)', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(excited);
        expect(state(npc), NpcState.rest, reason: 'not speaking yet');
        npc.setSpeaking(true);
        expect(state(npc), NpcState.idle);
        npc.setSpeaking(false);
        ms(async, 19900);
        expect(state(npc), NpcState.idle);
        ms(async, 200);
        // walks to the lamp's pool (the warm rug)
        expect(state(npc), NpcState.move);
        ms(async, walk + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 1);
      });
    });

    test('calm speech does not wake it', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(const EmotionVector(valence: 0.2, arousal: 0.3));
        npc.setSpeaking(true);
        expect(state(npc), NpcState.rest);
      });
    });

    test('lamp off: the warm spot is the cabinet', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, walk + 100);
        expect(x(npc), 1);
        npc.setEmotion(const EmotionVector());
        npc.onSceneEvent(SceneEvent.lightsOff);
        ms(async, 20100);
        expect(state(npc), NpcState.move);
        ms(async, walk + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('catWalksBy suppresses move while it plays', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.catWalksBy);
        npc.setEmotion(sad);
        final List<NpcState> states = <NpcState>[];
        void record() => states.add(state(npc));
        npc.intent.addListener(record);
        ms(async, 10600);
        expect(states, isNot(contains(NpcState.move)));
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
        ms(async, 200);
        expect(state(npc), NpcState.move);
        npc.intent.removeListener(record);
      });
    });

    test('catWalksBy mid-walk sends the NPC away; it reappears at its '
        'target after', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, walk ~/ 3);
        npc.onSceneEvent(SceneEvent.catWalksBy);
        // never two cats: away for the whole walk-by, even once its own
        // walk would have ended
        for (int i = 0; i < 10; i++) {
          expect(state(npc), NpcState.away);
          ms(async, 1000);
        }
        expect(state(npc), NpcState.away);
        ms(async, 800);
        // the walking cat has passed: back at the rug
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
      });
    });
  });

  group('looks and facing', () {
    test('toward the avatar depends on the side the NPC is on', () {
      expect(NpcDirector.lookToAvatar(NpcKind.cat, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.cat, 1), greaterThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.owl, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.crab, 1), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.alien, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.alien, 1), greaterThan(0));
    });

    test('the walking cat faces its way: left to the rug, right back', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, 500);
        expect(state(npc), NpcState.move);
        expect(look(npc), lessThan(0));
        ms(async, 3000);
        npc.setEmotion(const EmotionVector());
        npc.onSceneEvent(SceneEvent.lightsOff);
        ms(async, 20500);
        expect(state(npc), NpcState.move);
        expect(look(npc), greaterThan(0));
        // poked on the rug, it looks right, at the avatar
        npc.poke('cat');
        ms(async, 1700);
        expect(state(npc), NpcState.notice);
      });
    });

    test('the crab scuttles right to the water', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.poke('crab');
        ms(async, 1700);
        expect(state(npc), NpcState.move);
        expect(look(npc), greaterThan(0));
      });
    });
  });

  group('owl', () {
    test('poked: react', () {
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.poke('owl');
        expect(state(npc), NpcState.react);
        ms(async, 1601);
        expect(state(npc), NpcState.rest);
      });
    });

    test('the avatar speaking: notice toward it; night quiet: rest', () {
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.setSpeaking(true);
        expect(state(npc), NpcState.notice);
        expect(look(npc), -NpcDirector.lookAmount);
        npc.setSpeaking(false);
        expect(state(npc), NpcState.rest);
      });
    });

    test('a question in the reply: an idle swivel for 3 s', () {
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.setSpeaking(true);
        npc.onReplySentence('Do you hear the owl?');
        expect(state(npc), NpcState.idle);
        ms(async, 3001);
        expect(state(npc), NpcState.notice);
        // a user question does not count
        npc.onUserText('Is it late?');
        expect(state(npc), NpcState.notice);
      });
    });

    test('rain ≥ 0.5: rest (hunched), a poke still reacts', () {
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.setSpeaking(true);
        npc.setRain(0.6);
        expect(state(npc), NpcState.rest);
        npc.poke('owl');
        expect(state(npc), NpcState.react);
        npc.setRain(0.4);
        ms(async, 1700);
        expect(state(npc), NpcState.notice);
      });
    });
  });

  group('crab', () {
    test('poked: react, scuttles away and back after 8 s', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.poke('crab');
        expect(state(npc), NpcState.react);
        ms(async, 1601);
        expect(state(npc), NpcState.move);
        ms(async, scuttle + 10);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        ms(async, 7890);
        expect(x(npc), 1);
        ms(async, 200);
        expect(state(npc), NpcState.move);
        ms(async, scuttle + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('the avatar happy: idle scuttle dance; rain hides it', () {
      run(AvatarScene.beach, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(happy);
        expect(state(npc), NpcState.idle);
        npc.setRain(0.4);
        expect(state(npc), NpcState.rest);
        npc.setRain(0);
        expect(state(npc), NpcState.idle);
      });
    });
  });

  group('alien', () {
    test('poked: react (wave); its name: notice', () {
      run(AvatarScene.deepSpace, (FakeAsync async, NpcDirector npc) {
        npc.poke('ufo');
        expect(state(npc), NpcState.react);
        ms(async, 1601);
        expect(state(npc), isNot(NpcState.react));
        for (final String text in <String>[
          'Is that an alien?',
          'look, a UFO',
          'un ovni !',
        ]) {
          npc.onUserText(text);
          expect(state(npc), NpcState.notice, reason: text);
          ms(async, 1600);
        }
      });
    });

    test('drifts idly; rests while the avatar thinks', () {
      run(AvatarScene.deepSpace, (FakeAsync async, NpcDirector npc) {
        final Set<NpcState> seen = <NpcState>{};
        final Set<double> xs = <double>{};
        void record() {
          seen.add(state(npc));
          xs.add(x(npc));
        }

        npc.intent.addListener(record);
        npc.setPhase(TalkingPhase.idle);
        ms(async, 60000);
        expect(seen, containsAll(<NpcState>[NpcState.idle, NpcState.move]));
        expect(xs.length, greaterThan(10));
        npc.setPhase(TalkingPhase.generating);
        expect(state(npc), NpcState.rest);
        final double held = x(npc);
        ms(async, 30000);
        expect(state(npc), NpcState.rest);
        expect(x(npc), held);
        npc.intent.removeListener(record);
      });
    });

    test('the same seed drifts the same way', () {
      List<double> drift() {
        final List<double> xs = <double>[];
        run(AvatarScene.deepSpace, (FakeAsync async, NpcDirector npc) {
          for (int k = 0; k < 40; k++) {
            ms(async, 1000);
            xs.add(x(npc));
          }
        });
        return xs;
      }

      expect(drift(), drift());
    });
  });

  group('tiers and accessibility', () {
    test('low tier: nothing runs, the NPC holds rest', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setTier(QualityTier.low);
        npc.poke('cat');
        npc.setEmotion(sad);
        npc.onUserText('my cat');
        ms(async, 5000);
        expect(npc.intent.value, NpcIntent.rest);
        expect(async.pendingTimers, isEmpty);
      });
      run(AvatarScene.deepSpace, (FakeAsync async, NpcDirector npc) {
        npc.setTier(QualityTier.low);
        ms(async, 60000);
        expect(npc.intent.value, NpcIntent.rest);
      });
    });

    test('a walk under way stops at the low tier; back to high it is rest', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, 1000);
        npc.setTier(QualityTier.low);
        expect(npc.intent.value, NpcIntent.rest);
        npc.setEmotion(const EmotionVector());
        npc.setTier(QualityTier.high);
        expect(npc.intent.value, NpcIntent.rest);
      });
    });

    test('reduce motion: no move (a jump while away), no react', () {
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        final List<NpcState> states = <NpcState>[];
        void record() => states.add(state(npc));
        npc.intent.addListener(record);
        npc.poke('cat');
        expect(state(npc), NpcState.notice);
        ms(async, 6000);
        npc.setEmotion(sad);
        expect(state(npc), NpcState.away);
        expect(x(npc), 1);
        ms(async, 401);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        expect(states, isNot(contains(NpcState.move)));
        expect(states, isNot(contains(NpcState.react)));
        npc.intent.removeListener(record);
      });
      run(AvatarScene.deepSpace, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        ms(async, 60000);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
      });
    });
  });

  test('a scene change starts the new NPC over at rest', () {
    run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
      npc.setEmotion(sad);
      ms(async, 1000);
      npc.setScene(AvatarScene.campfire);
      expect(npc.intent.value, NpcIntent.rest);
      npc.poke('cat');
      expect(npc.intent.value, NpcIntent.rest);
    });
  });
}
