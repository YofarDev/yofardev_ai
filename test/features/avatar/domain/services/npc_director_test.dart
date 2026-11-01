import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/npc_director.dart';

/// Moonshot M8 ruling 9, M9 ruling 11 and M11 ruling 7: the ten NPC behaviour
/// trees, on a fake clock and a seeded random.
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

  test('only the wandering NPCs start idle; the others start at rest', () {
    const Set<AvatarScene> wanderers = <AvatarScene>{
      AvatarScene.deepSpace,
      AvatarScene.cafe,
      AvatarScene.rooftop,
      AvatarScene.forestCabin,
      AvatarScene.trainCompartment,
    };
    for (final AvatarScene scene in AvatarScene.values) {
      run(scene, (FakeAsync async, NpcDirector npc) {
        expect(
          npc.intent.value,
          wanderers.contains(scene)
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
    expect(NpcKind.of(AvatarScene.cafe).propId, 'fish');
    expect(NpcKind.of(AvatarScene.rooftop).propId, 'pigeon');
    expect(NpcKind.of(AvatarScene.mountainHut).propId, 'dog');
    expect(NpcKind.of(AvatarScene.forestCabin).propId, 'squirrel');
    expect(NpcKind.of(AvatarScene.trainCompartment).propId, 'ladybug');
    expect(NpcKind.of(AvatarScene.library).propId, 'mouse');
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

  group('fish (cafe)', () {
    test('poked: react 1.2 s, then notice 3 s, then idle', () {
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        npc.poke('cup');
        expect(state(npc), NpcState.idle);
        npc.poke('fish');
        expect(state(npc), NpcState.react);
        ms(async, 1199);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.notice);
        expect(look(npc), -NpcDirector.lookAmount);
        ms(async, 2990);
        expect(state(npc), NpcState.notice);
        ms(async, 20);
        expect(state(npc), NpcState.idle);
      });
    });

    test('the avatar speaking: notice toward it', () {
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        npc.setSpeaking(true);
        expect(state(npc), NpcState.notice);
        npc.setSpeaking(false);
        expect(state(npc), NpcState.idle);
      });
    });

    test('swims to a random npcX every 10 to 16 s', () {
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        ms(async, 9900);
        expect(state(npc), NpcState.idle);
        ms(async, 6200);
        expect(state(npc), NpcState.move);
        ms(async, NpcDirector.fishSwimLength.inMilliseconds + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), inExclusiveRange(0, 1));
      });
    });

    test('the same seed swims the same way', () {
      double firstSwim() {
        double result = -1;
        run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
          ms(async, 16100 + NpcDirector.fishSwimLength.inMilliseconds + 100);
          result = x(npc);
        });
        return result;
      }

      expect(firstSwim(), firstSwim());
    });

    test('swim rate 0.5 npcX/s (at least 1 s); faces right while npcLook >= 0, '
        'left while < 0, and keeps the last sign when idle', () {
      expect(NpcDirector.fishSwimRate, 0.5);
      expect(NpcDirector.fishSwimLength, const Duration(seconds: 2));
      expect(
        NpcDirector.travelTime(0.1, 0.5),
        const Duration(milliseconds: 200),
      );
      expect(NpcDirector.facing(NpcKind.fish, 0, 1), NpcDirector.fishMoveLook);
      expect(NpcDirector.facing(NpcKind.fish, 1, 0), -NpcDirector.fishMoveLook);
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        // starts facing right
        expect(look(npc), greaterThanOrEqualTo(0));
        final List<(double x, double look, int at)> moving =
            <(double, double, int)>[];
        double settledX = 0;
        int moves = 0;
        int? swimStart;
        npc.intent.addListener(() {
          final NpcIntent i = npc.intent.value;
          if (i.npc == NpcState.move) {
            swimStart ??= async.elapsed.inMilliseconds;
            moving.add((i.npcX, i.npcLook, async.elapsed.inMilliseconds));
          } else if (swimStart != null) {
            moves++;
            final int took = async.elapsed.inMilliseconds - swimStart!;
            final double distance = (i.npcX - settledX).abs();
            // distance / 0.5 npcX/s, but never under 1 s
            final double expectedMs = math.max(1000, distance / 0.5 * 1000);
            expect(took, inInclusiveRange(expectedMs, expectedMs + 40));
            // every frame of the swim faces the way it goes, small
            for (final (double, double, int) f in moving) {
              expect(f.$2.abs(), NpcDirector.fishMoveLook);
              expect(f.$2 > 0, i.npcX > settledX);
            }
            // idle after the swim keeps that sign
            expect(i.npcLook < 0, i.npcX < settledX);
            settledX = i.npcX;
            moving.clear();
            swimStart = null;
          }
        });
        ms(async, 120000);
        expect(moves, greaterThan(3));
      });
    });

    test('reduce motion: it idles in place and a poke only notices', () {
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        ms(async, 60000);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
        npc.poke('fish');
        expect(state(npc), NpcState.notice);
      });
    });
  });

  group('pigeon (rooftop)', () {
    test('poked: react 0.8 s, walks away, back after 10 s', () {
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        npc.poke('pigeon');
        expect(state(npc), NpcState.react);
        ms(async, 801);
        expect(state(npc), NpcState.move);
        // walking right as npcX grows
        expect(look(npc), NpcDirector.moveLook);
        ms(async, NpcDirector.pigeonWalkLength.inMilliseconds + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        ms(async, 9000);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        ms(async, 1500);
        // back on its way to the spot
        expect(state(npc), NpcState.move);
        ms(async, NpcDirector.pigeonWalkLength.inMilliseconds + 100);
        expect(x(npc), 0);
        expect(state(npc), NpcState.idle);
      });
    });

    test('walk rate 0.354 npcX/s: the whole path in ~2.8 s, facing '
        'right as npcX grows and left as it falls', () {
      expect(NpcDirector.pigeonWalkRate, 0.354);
      expect(
        NpcDirector.pigeonWalkLength.inMilliseconds,
        inInclusiveRange(2824, 2826),
      );
      expect(NpcDirector.facing(NpcKind.pigeon, 0, 1), 0.5);
      expect(NpcDirector.facing(NpcKind.pigeon, 1, 0), -0.5);
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        npc.poke('pigeon');
        ms(async, 800 + 10);
        expect(look(npc), 0.5);
        // half way in time is half way in distance (eased, symmetric)
        ms(async, 1404);
        expect(x(npc), closeTo(0.5, 0.05));
        ms(async, 1500);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        // back after 10 s, walking left
        ms(async, 10500);
        expect(state(npc), NpcState.move);
        expect(look(npc), -0.5);
        ms(async, NpcDirector.pigeonWalkLength.inMilliseconds + 100);
        expect(x(npc), 0);
      });
    });

    test('fireworks startle it like a poke; elsewhere they do nothing', () {
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.fireworks);
        expect(state(npc), NpcState.react);
      });
      run(AvatarScene.cafe, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.fireworks);
        expect(state(npc), NpcState.idle);
      });
    });

    test('rain >= 0.5: rest; a poke still reacts', () {
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        npc.setRain(0.4);
        expect(state(npc), NpcState.idle);
        npc.setRain(0.5);
        expect(state(npc), NpcState.rest);
        ms(async, 60000);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
        npc.poke('pigeon');
        expect(state(npc), NpcState.react);
        npc.setRain(0);
        expect(state(npc), NpcState.react);
      });
    });

    test('walks to a random npcX every 12 to 20 s', () {
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        final List<int> moveStarts = <int>[];
        npc.intent.addListener(() {
          if (state(npc) == NpcState.move && moveStarts.isEmpty) {
            moveStarts.add(async.elapsed.inMilliseconds);
          }
        });
        ms(async, 11900);
        expect(state(npc), NpcState.idle);
        expect(moveStarts, isEmpty);
        ms(async, 8200);
        expect(moveStarts, hasLength(1));
        expect(moveStarts.single, inInclusiveRange(12000, 20100));
        ms(async, NpcDirector.pigeonWalkLength.inMilliseconds + 100);
        expect(state(npc), NpcState.idle);
      });
    });

    test('reduce motion: it idles in place; poked it notices, then goes and '
        'comes back by jumps while away', () {
      run(AvatarScene.rooftop, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        final List<NpcState> states = <NpcState>[];
        void record() => states.add(state(npc));
        npc.intent.addListener(record);
        ms(async, 30000);
        expect(state(npc), NpcState.idle);
        npc.poke('pigeon');
        expect(state(npc), NpcState.notice);
        ms(async, 60000);
        expect(x(npc), 0);
        expect(states, isNot(contains(NpcState.move)));
        expect(states, isNot(contains(NpcState.react)));
        npc.intent.removeListener(record);
      });
    });
  });

  group('dog (mountainHut)', () {
    test('poked: react 1.6 s, then notice 4 s toward the avatar', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.poke('stove');
        expect(state(npc), NpcState.rest);
        npc.poke('dog');
        expect(state(npc), NpcState.react);
        ms(async, 1599);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.notice);
        expect(look(npc), -NpcDirector.lookAmount);
        ms(async, 3990);
        expect(state(npc), NpcState.notice);
        ms(async, 20);
        expect(state(npc), NpcState.idle);
      });
    });

    test('its name in a message: notice 1.5 s, then react', () {
      for (final String text in <String>[
        'My dog is asleep',
        'what a good doggy!',
        'a puppy',
        'Le chien dort',
        'mon toutou',
        'un chiot!',
      ]) {
        run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
          npc.onUserText(text);
          expect(state(npc), NpcState.notice, reason: text);
          ms(async, 1501);
          expect(state(npc), NpcState.react, reason: text);
          ms(async, 1600);
          expect(state(npc), NpcState.idle, reason: text);
        });
      }
    });

    test('a word that only contains the name is not a mention', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.onUserText('the dogma of hotdogs and a chienne');
        expect(state(npc), NpcState.rest);
      });
    });

    test('the avatar sad: trots to the avatar, sits there', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        expect(state(npc), NpcState.move);
        ms(async, NpcDirector.dogTrotLength.inMilliseconds ~/ 2);
        expect(state(npc), NpcState.move);
        expect(x(npc), inExclusiveRange(0.2, 0.8));
        ms(async, NpcDirector.dogTrotLength.inMilliseconds ~/ 2 + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
      });
    });

    test('trot rate 1.042 npcX/s (~0.96 s for the whole path), facing left '
        'toward the avatar and right on the way back', () {
      expect(NpcDirector.dogTrotRate, 1.042);
      expect(
        NpcDirector.dogTrotLength.inMilliseconds,
        inInclusiveRange(958, 961),
      );
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        expect(state(npc), NpcState.move);
        expect(look(npc), -0.5);
        ms(async, 950);
        expect(state(npc), NpcState.move);
        ms(async, 20);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        npc.setEmotion(const EmotionVector());
        ms(async, 20500);
        expect(state(npc), NpcState.move);
        expect(look(npc), 0.5);
        ms(async, 1000);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('woken by excited speech, back to the rug and asleep after 20 s of '
        'calm', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(excited);
        expect(state(npc), NpcState.rest);
        npc.setSpeaking(true);
        expect(state(npc), NpcState.idle);
        npc.setSpeaking(false);
        ms(async, 19900);
        expect(state(npc), NpcState.idle);
        // it was never away from the rug: asleep again at once
        ms(async, 200);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('after trotting to the avatar it goes back to the rug after 20 s', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(sad);
        ms(async, NpcDirector.dogTrotLength.inMilliseconds + 100);
        expect(x(npc), 1);
        npc.setEmotion(const EmotionVector());
        ms(async, 19800);
        expect(state(npc), NpcState.idle);
        ms(async, 400);
        expect(state(npc), NpcState.move);
        ms(async, NpcDirector.dogTrotLength.inMilliseconds + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('calm speech does not wake it', () {
      run(AvatarScene.mountainHut, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(const EmotionVector(valence: 0.2, arousal: 0.3));
        npc.setSpeaking(true);
        expect(state(npc), NpcState.rest);
      });
    });

    test('toward the avatar: like the cat, it faces right at the avatar\'s '
        'feet; moving, it goes left as npcX grows', () {
      expect(NpcDirector.lookToAvatar(NpcKind.dog, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.dog, 1), greaterThan(0));
      expect(NpcDirector.facing(NpcKind.dog, 0, 1), lessThan(0));
      expect(NpcDirector.facing(NpcKind.pigeon, 0, 1), greaterThan(0));
      expect(NpcDirector.facing(NpcKind.fish, 1, 0), lessThan(0));
    });
  });

  group('squirrel (forestCabin)', () {
    final int run_ = NpcDirector.squirrelRunLength.inMilliseconds;

    test('poked: react 0.8 s, scampers to the trunk, back after 8 s', () {
      run(AvatarScene.forestCabin, (FakeAsync async, NpcDirector npc) {
        npc.poke('lantern');
        expect(state(npc), NpcState.idle);
        npc.poke('squirrel');
        expect(state(npc), NpcState.react);
        expect(look(npc), -NpcDirector.lookAmount);
        ms(async, 799);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.move);
        // the trunk is left of the rail: it runs left as npcX grows
        expect(look(npc), -NpcDirector.moveLook);
        ms(async, run_ + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        ms(async, 7500);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        ms(async, 1000);
        // back to the rail, running right
        expect(state(npc), NpcState.move);
        expect(look(npc), NpcDirector.moveLook);
        ms(async, run_ + 100);
        expect(x(npc), 0);
        expect(state(npc), NpcState.idle);
      });
    });

    test('run rate 0.177 npcX/s, measured from the built gallop (~5.6 s for '
        'the whole path)', () {
      expect(NpcDirector.squirrelRunRate, 0.177);
      expect(run_, inInclusiveRange(5648, 5651));
      expect(NpcDirector.facing(NpcKind.squirrel, 0, 1), lessThan(0));
      expect(NpcDirector.facing(NpcKind.squirrel, 1, 0), greaterThan(0));
      // right of the avatar on the rail, left of it up the maple
      expect(NpcDirector.lookToAvatar(NpcKind.squirrel, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.squirrel, 1), greaterThan(0));
    });

    test('a gust: react 0.8 s, then idle; elsewhere nothing', () {
      run(AvatarScene.forestCabin, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.gust);
        expect(state(npc), NpcState.react);
        ms(async, 801);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
      });
      run(AvatarScene.livingRoom, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.gust);
        expect(npc.intent.value, NpcIntent.rest);
      });
    });

    test('rain >= 0.5: to the trunk and rest; a poke still reacts; dry, it '
        'comes back to the rail', () {
      run(AvatarScene.forestCabin, (FakeAsync async, NpcDirector npc) {
        npc.setRain(0.4);
        expect(state(npc), NpcState.idle);
        npc.setRain(0.5);
        expect(state(npc), NpcState.move);
        ms(async, run_ + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 1);
        ms(async, 60000);
        expect(state(npc), NpcState.rest);
        npc.poke('squirrel');
        expect(state(npc), NpcState.react);
        ms(async, 801 + run_ + 8100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 1);
        npc.setRain(0);
        expect(state(npc), NpcState.move);
        ms(async, run_ + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
      });
    });

    test('a dash to a random npcX every 12 to 20 s', () {
      run(AvatarScene.forestCabin, (FakeAsync async, NpcDirector npc) {
        final List<int> moveStarts = <int>[];
        npc.intent.addListener(() {
          if (state(npc) == NpcState.move && moveStarts.isEmpty) {
            moveStarts.add(async.elapsed.inMilliseconds);
          }
        });
        ms(async, 11900);
        expect(state(npc), NpcState.idle);
        expect(moveStarts, isEmpty);
        ms(async, 8200);
        expect(moveStarts, hasLength(1));
        expect(moveStarts.single, inInclusiveRange(12000, 20100));
        ms(async, run_ + 100);
        expect(state(npc), NpcState.idle);
      });
    });

    test('reduce motion: it idles in place; poked it notices, then jumps', () {
      run(AvatarScene.forestCabin, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        final List<NpcState> states = <NpcState>[];
        void record() => states.add(state(npc));
        npc.intent.addListener(record);
        ms(async, 30000);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
        npc.poke('squirrel');
        expect(state(npc), NpcState.notice);
        ms(async, 801);
        expect(state(npc), NpcState.away);
        ms(async, 401);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 1);
        expect(states, isNot(contains(NpcState.move)));
        expect(states, isNot(contains(NpcState.react)));
        npc.intent.removeListener(record);
      });
    });
  });

  group('ladybug (trainCompartment)', () {
    test('poked: react 0.6 s, then idle', () {
      run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
        npc.poke('lamp');
        expect(state(npc), NpcState.idle);
        npc.poke('ladybug');
        expect(state(npc), NpcState.react);
        // left of the avatar on the sill: toward it is right
        expect(look(npc), NpcDirector.lookAmount);
        ms(async, 599);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.idle);
      });
    });

    test('a tunnel: rest until it ends (3 s); elsewhere nothing', () {
      expect(NpcDirector.tunnelLength, const Duration(seconds: 3));
      run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.tunnel);
        expect(state(npc), NpcState.rest);
        ms(async, 2999);
        expect(state(npc), NpcState.rest);
        ms(async, 2);
        expect(state(npc), NpcState.idle);
        // a poke in the dark still reacts
        npc.onSceneEvent(SceneEvent.tunnel);
        npc.poke('ladybug');
        expect(state(npc), NpcState.react);
        ms(async, 601);
        expect(state(npc), NpcState.rest);
      });
      run(AvatarScene.campfire, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.tunnel);
        expect(npc.intent.value, NpcIntent.rest);
      });
    });

    test('walks to a random npcX every 10 to 16 s, facing its way', () {
      // measured from the built walk cycle (scene_train.ladybug_walk_speed)
      expect(NpcDirector.ladybugWalkRate, 0.173);
      expect(NpcDirector.facing(NpcKind.ladybug, 0, 1), greaterThan(0));
      expect(NpcDirector.facing(NpcKind.ladybug, 1, 0), lessThan(0));
      run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
        final List<int> moveStarts = <int>[];
        npc.intent.addListener(() {
          if (state(npc) == NpcState.move && moveStarts.isEmpty) {
            moveStarts.add(async.elapsed.inMilliseconds);
          }
        });
        ms(async, 9900);
        expect(moveStarts, isEmpty);
        ms(async, 6200);
        expect(moveStarts, hasLength(1));
        expect(moveStarts.single, inInclusiveRange(10000, 16100));
        expect(look(npc), isNot(0));
        ms(async, NpcDirector.ladybugWalkLength.inMilliseconds + 100);
        expect(state(npc), NpcState.idle);
        expect(x(npc), inInclusiveRange(0, 1));
      });
    });

    test('the same seed walks the same way', () {
      final List<double> targets = <double>[];
      for (int i = 0; i < 2; i++) {
        run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
          ms(async, 16100 + NpcDirector.ladybugWalkLength.inMilliseconds);
          targets.add(x(npc));
        });
      }
      expect(targets[0], targets[1]);
    });

    test('reduce motion: it idles in place; a poke only notices', () {
      run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        ms(async, 60000);
        expect(state(npc), NpcState.idle);
        expect(x(npc), 0);
        npc.poke('ladybug');
        expect(state(npc), NpcState.notice);
      });
    });
  });

  group('mouse (library)', () {
    final int scurry = NpcDirector.mouseScurryLength.inMilliseconds;

    test('asleep by the shelf; poked: react 0.6 s, then rest at 0', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        expect(npc.intent.value, NpcIntent.rest);
        npc.poke('book');
        expect(state(npc), NpcState.rest);
        npc.poke('mouse');
        expect(state(npc), NpcState.react);
        // right of the avatar all along its path
        expect(look(npc), -NpcDirector.lookAmount);
        ms(async, 599);
        expect(state(npc), NpcState.react);
        ms(async, 2);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('poked away from its shelf: it runs back to 0, then rests', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        npc.onUserText('a little mouse!');
        // awake: it wanders while awake (a scurry every 10 to 16 s)
        // its first scurry starts by 17.5 s and ends before the 20 s calm
        ms(async, 17600);
        ms(async, scurry + 100);
        final double away = x(npc);
        expect(away, greaterThan(0));
        npc.poke('mouse');
        ms(async, 601);
        expect(state(npc), NpcState.move);
        // back toward the shelf: npcX falls; it faces the way its paw line
        // moves on the path (right while it climbs back from below the bend)
        expect(look(npc), NpcDirector.facing(NpcKind.mouse, away, 0));
        ms(async, scurry + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('lightning: react, then rest; elsewhere nothing', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.lightning);
        expect(state(npc), NpcState.react);
        ms(async, 601);
        expect(state(npc), NpcState.rest);
      });
      run(AvatarScene.trainCompartment, (FakeAsync async, NpcDirector npc) {
        npc.onSceneEvent(SceneEvent.lightning);
        expect(state(npc), NpcState.idle);
      });
    });

    test('its name: notice 1.5 s, then awake idle; asleep after 20 s calm', () {
      for (final String text in <String>[
        'Is there a mouse here?',
        'two mice',
        'Une souris !',
      ]) {
        run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
          npc.onUserText(text);
          expect(state(npc), NpcState.notice, reason: text);
          expect(look(npc), -NpcDirector.lookAmount, reason: text);
          ms(async, 1501);
          expect(state(npc), NpcState.idle, reason: text);
          ms(async, 20000);
          // back by the shelf (or already there), asleep
          ms(async, scurry + 100);
          expect(state(npc), NpcState.rest, reason: text);
          expect(x(npc), 0, reason: text);
        });
      }
    });

    test('a word that only contains the name is not a mention', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        npc.onUserText('mousetrap and mouses and sourire');
        expect(state(npc), NpcState.rest);
      });
    });

    test('the avatar speaking with arousal >= 0.6: notice; calm speech does '
        'not wake it', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        npc.setEmotion(const EmotionVector(valence: 0.2, arousal: 0.3));
        npc.setSpeaking(true);
        expect(state(npc), NpcState.rest);
        npc.setEmotion(excited);
        expect(state(npc), NpcState.notice);
        npc.setSpeaking(false);
        expect(state(npc), NpcState.idle);
        ms(async, 19900);
        expect(state(npc), NpcState.idle);
        ms(async, 200 + scurry + 100);
        expect(state(npc), NpcState.rest);
        expect(x(npc), 0);
      });
    });

    test('facing: right as npcX grows, left as it falls; rate', () {
      expect(NpcDirector.facing(NpcKind.mouse, 0, 1), greaterThan(0));
      expect(NpcDirector.facing(NpcKind.mouse, 1, 0), lessThan(0));
      // the path runs left to npcX ~0.58 first (scene_library.mouse_path)
      expect(NpcDirector.facing(NpcKind.mouse, 0, 0.5), lessThan(0));
      expect(NpcDirector.facing(NpcKind.mouse, 0.5, 0), greaterThan(0));
      expect(NpcDirector.facing(NpcKind.mouse, 0.6, 1), greaterThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.mouse, 0), lessThan(0));
      expect(NpcDirector.lookToAvatar(NpcKind.mouse, 1), lessThan(0));
      expect(
        NpcDirector.mouseScurryLength,
        NpcDirector.travelTime(1, NpcDirector.mouseScurryRate),
      );
    });

    test('reduce motion: a poke only notices; no move', () {
      run(AvatarScene.library, (FakeAsync async, NpcDirector npc) {
        npc.setReduceMotion(true);
        final List<NpcState> states = <NpcState>[];
        void record() => states.add(state(npc));
        npc.intent.addListener(record);
        npc.onUserText('mouse');
        ms(async, 60000);
        npc.poke('mouse');
        expect(state(npc), NpcState.notice);
        ms(async, 601);
        expect(state(npc), NpcState.rest);
        expect(states, isNot(contains(NpcState.move)));
        expect(states, isNot(contains(NpcState.react)));
        npc.intent.removeListener(record);
      });
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
      for (final (AvatarScene scene, String prop, SceneEvent event)
          in <(AvatarScene, String, SceneEvent)>[
            (AvatarScene.forestCabin, 'squirrel', SceneEvent.gust),
            (AvatarScene.trainCompartment, 'ladybug', SceneEvent.tunnel),
            (AvatarScene.library, 'mouse', SceneEvent.lightning),
          ]) {
        run(scene, (FakeAsync async, NpcDirector npc) {
          npc.setTier(QualityTier.low);
          npc.poke(prop);
          npc.onSceneEvent(event);
          npc.setRain(1);
          npc.onUserText('mouse');
          ms(async, 60000);
          expect(npc.intent.value, NpcIntent.rest, reason: scene.name);
          expect(async.pendingTimers, isEmpty, reason: scene.name);
        });
      }
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
