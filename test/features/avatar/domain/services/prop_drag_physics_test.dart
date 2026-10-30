import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/domain/services/prop_drag_physics.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

PropDragPhysics _physics(AvatarScene scene, {bool reduceMotion = false}) =>
    PropDragPhysics(SceneDrags.of(scene)!, reduceMotion: reduceMotion);

/// Ticks [physics] every 16 ms from [from] until it rests (or [limit]).
Duration _settle(
  PropDragPhysics physics,
  Duration from, {
  Duration limit = const Duration(seconds: 30),
}) {
  Duration t = from;
  while (physics.animating && t - from < limit) {
    t += _ms(16);
    physics.tick(t);
  }
  return t;
}

void main() {
  group('pull (the cord)', () {
    final Rect rect = SceneDrags.of(AvatarScene.livingRoom)!.rect;
    final Offset grab = Offset(rect.center.dx, rect.top + 20);

    test('follows the finger down, 0..1 over the travel, never up', () {
      final PropDragPhysics p = _physics(AvatarScene.livingRoom);
      p.start(grab, Duration.zero);
      expect(p.takeCues(), <DragCue>[DragCue.start]);
      p.move(grab + const Offset(0, 50), _ms(16));
      expect(p.values['cord'], closeTo(0.5, 1e-9));
      p.move(grab + const Offset(0, -40), _ms(32));
      expect(p.values['cord'], 0);
      p.move(grab + const Offset(0, 400), _ms(48));
      expect(p.values['cord'], 1);
    });

    test('past 0.6 fires once per pull, and again on the next pull', () {
      final PropDragPhysics p = _physics(AvatarScene.livingRoom);
      p.start(grab, Duration.zero);
      p.move(grab + const Offset(0, 59), _ms(16));
      expect(p.takeCues(), <DragCue>[DragCue.start]);
      p.move(grab + const Offset(0, 61), _ms(32));
      expect(p.takeCues(), <DragCue>[DragCue.pullFired]);
      // up and down again within the same pull: nothing more
      p.move(grab, _ms(48));
      p.move(grab + const Offset(0, 90), _ms(64));
      expect(p.takeCues(), isEmpty);
      p.end(_ms(80));
      _settle(p, _ms(80));
      p.start(grab, _ms(2000));
      p.move(grab + const Offset(0, 70), _ms(2016));
      expect(p.takeCues(), <DragCue>[DragCue.start, DragCue.pullFired]);
    });

    test('springs back on release, no overshoot, and rests at exactly 0', () {
      final PropDragPhysics p = _physics(AvatarScene.livingRoom);
      p.start(grab, Duration.zero);
      p.move(grab + const Offset(0, 100), _ms(16));
      p.end(_ms(32));
      expect(p.animating, isTrue);
      double last = 1;
      Duration t = _ms(32);
      while (p.animating) {
        t += _ms(16);
        p.tick(t);
        final double v = p.values['cord']!;
        expect(v, lessThanOrEqualTo(last));
        expect(v, greaterThanOrEqualTo(0));
        last = v;
      }
      expect(p.values['cord'], 0);
      expect(t - _ms(32), lessThan(_ms(600)));
    });

    test('regrabbed mid-spring: no jump', () {
      final PropDragPhysics p = _physics(AvatarScene.livingRoom);
      p.start(grab, Duration.zero);
      p.move(grab + const Offset(0, 100), _ms(16));
      p.end(_ms(32));
      p.tick(_ms(100));
      final double mid = p.values['cord']!;
      expect(mid, inExclusiveRange(0, 1));
      p.start(grab + const Offset(0, 30), _ms(110));
      expect(p.animating, isFalse);
      p.move(grab + const Offset(0, 30), _ms(126));
      expect(p.values['cord'], closeTo(mid, 1e-9));
    });

    test('reduce motion: settles at once', () {
      final PropDragPhysics p = _physics(
        AvatarScene.mountainHut,
        reduceMotion: true,
      );
      final Rect rope = SceneDrags.of(AvatarScene.mountainHut)!.rect;
      p.start(rope.center, Duration.zero);
      p.move(rope.center + const Offset(0, 80), _ms(16));
      expect(p.values['rope'], closeTo(0.8, 1e-9));
      expect(p.takeCues(), <DragCue>[DragCue.start, DragCue.pullFired]);
      p.end(_ms(32));
      expect(p.values['rope'], 0);
      expect(p.animating, isFalse);
    });

    test('halt stops the spring where it is', () {
      final PropDragPhysics p = _physics(AvatarScene.livingRoom);
      p.start(grab, Duration.zero);
      p.move(grab + const Offset(0, 100), _ms(16));
      p.end(_ms(32));
      p.halt();
      expect(p.animating, isFalse);
      expect(p.dragging, isFalse);
    });
  });

  group('poke (the campfire)', () {
    final Rect box = SceneDrags.of(AvatarScene.campfire)!.rect;

    test('the tip sits under the finger, clamped to the tip box', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      // the tip box (88, 1050, 304, 1210): POKE_TIP (196, 1130) +- (108, 80)
      p.start(const Offset(196, 1130), Duration.zero);
      expect(p.values['pokeX'], 0);
      expect(p.values['pokeY'], 0);
      p.move(const Offset(142, 1170), _ms(16));
      expect(p.values['pokeX'], closeTo(-0.5, 1e-9));
      expect(p.values['pokeY'], closeTo(0.5, 1e-9));
      p.move(const Offset(304, 1050), _ms(32));
      expect(p.values['pokeX'], closeTo(1, 1e-9));
      expect(p.values['pokeY'], closeTo(-1, 1e-9));
      // anywhere outside the box: its edge
      p.move(box.bottomLeft + const Offset(5, -5), _ms(48));
      expect(p.values['pokeX'], -1);
      expect(p.values['pokeY'], 1);
      p.move(const Offset(900, 600), _ms(64));
      expect(p.values['pokeX'], 1);
      expect(p.values['pokeY'], -1);
    });

    test('the tip box equals the campfire art (gen_scenes.py)', () {
      final String src = File('rive/tools/gen_scenes.py').readAsStringSync();
      Offset pair(String name) {
        final RegExpMatch m = RegExp(
          '^$name = \\(([-\\d.]+), ([-\\d.]+)\\)',
          multiLine: true,
        ).firstMatch(src)!;
        return Offset(double.parse(m.group(1)!), double.parse(m.group(2)!));
      }

      expect(PropDragPhysics.pokeTip, pair('POKE_TIP'));
      expect(PropDragPhysics.pokeRange, pair('POKE_RANGE'));
    });

    test('the pan accept and its first update in one instant: no flare, '
        'the tip moves with the finger only', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      const Offset a = Offset(196, 1130);
      // the arena: onStart(down) then onUpdate(the slop it waited for), the
      // same instant; even a full 36 px touch slop (~82 artboard px)
      p.start(a, Duration.zero);
      p.move(a + const Offset(82, 0), Duration.zero);
      expect(p.takeCues(), <DragCue>[DragCue.start]);
      // then a slow stir: 4 px per 16 ms (250 px/s)
      Duration t = Duration.zero;
      for (int i = 1; i <= 30; i++) {
        t += _ms(16);
        p.move(a + Offset(82 - 4.0 * (i % 10), 0), t);
      }
      expect(p.takeCues(), isNot(contains(DragCue.flare)));
    });

    test('the stick slides in on start and eases out on release', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      p.start(box.center, Duration.zero);
      expect(p.animating, isTrue);
      p.tick(_ms(60));
      expect(p.values['poke'], closeTo(0.5, 1e-9));
      p.tick(_ms(120));
      expect(p.values['poke'], 1);
      expect(p.animating, isFalse);
      p.move(box.center + const Offset(40, 0), _ms(500));
      p.end(_ms(1000));
      p.tick(_ms(1100));
      final double early = p.values['poke']!;
      // eased out: most of the way down early on, then slowly
      expect(early, inExclusiveRange(0, 0.5));
      _settle(p, _ms(1100));
      expect(p.values, <String, double>{'poke': 0, 'pokeX': 0, 'pokeY': 0});
    });

    test('a stir faster than 900 px/s fires flare, once per 3 s', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      p.start(box.center, Duration.zero);
      p.takeCues();
      // slow: 10 px per 16 ms = 625 px/s
      Duration t = Duration.zero;
      double x = box.center.dx;
      for (int i = 0; i < 10; i++) {
        t += _ms(16);
        x += 10;
        p.move(Offset(x, box.center.dy), t);
      }
      expect(p.takeCues(), isNot(contains(DragCue.flare)));
      // fast: 20 px per 16 ms = 1250 px/s, stirring back and forth
      List<DragCue> stir(int frames) {
        for (int i = 0; i < frames; i++) {
          t += _ms(16);
          x += (i ~/ 5).isEven ? -20 : 20;
          p.move(Offset(x, box.center.dy), t);
        }
        return p.takeCues();
      }

      final List<DragCue> first = stir(20);
      expect(first.where((DragCue c) => c == DragCue.flare), hasLength(1));
      // the same stir for ~2 s more: still one flare per 3 s
      final List<DragCue> more = stir(120);
      expect(more.where((DragCue c) => c == DragCue.flare), hasLength(0));
      final List<DragCue> later = stir(80);
      expect(later.where((DragCue c) => c == DragCue.flare), hasLength(1));
    });

    test('one tick per stir reversal, none for jitter', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      Duration t = Duration.zero;
      final Offset c = box.center;
      p.start(c, t);
      p.takeCues();
      void to(double dx) {
        t += _ms(80);
        p.move(c + Offset(dx, 0), t);
      }

      to(30);
      to(60);
      to(55); // jitter back 5 px: no reversal
      expect(p.takeCues(), isEmpty);
      to(20); // back 40 px: a reversal
      expect(p.takeCues(), <DragCue>[DragCue.tick]);
      to(-20);
      to(30); // forward 50: another
      expect(p.takeCues(), <DragCue>[DragCue.tick]);
    });

    test('reduce motion: shows and hides at once', () {
      final PropDragPhysics p = _physics(
        AvatarScene.campfire,
        reduceMotion: true,
      );
      p.start(box.center, Duration.zero);
      expect(p.values['poke'], 1);
      expect(p.animating, isFalse);
      p.end(_ms(100));
      expect(p.values['poke'], 0);
    });
  });

  group('trail (sand, wipe)', () {
    final Rect sand = SceneDrags.of(AvatarScene.beach)!.rect;

    test('dots 22 px apart, evenly, however far the finger jumps', () {
      final PropDragPhysics p = _physics(AvatarScene.beach);
      final Offset a = sand.center;
      p.start(a, Duration.zero);
      expect(p.values['trailN'], 1);
      expect(p.values['trailFade'], 0);
      expect(p.values['trailX0'], a.dx);
      p.move(a + const Offset(21, 0), _ms(16));
      expect(p.values['trailN'], 1);
      p.move(a + const Offset(70, 0), _ms(32));
      expect(p.values['trailN'], 4);
      expect(p.values['trailX1'], closeTo(a.dx + 22, 1e-9));
      expect(p.values['trailX2'], closeTo(a.dx + 44, 1e-9));
      expect(p.values['trailX3'], closeTo(a.dx + 66, 1e-9));
    });

    test('16 dots, the oldest recycled; a tick per 4 dots', () {
      final PropDragPhysics p = _physics(AvatarScene.beach);
      final Offset a = sand.topCenter + const Offset(0, 10);
      p.start(a, Duration.zero);
      expect(p.takeCues(), <DragCue>[DragCue.start]);
      for (int i = 1; i <= 19; i++) {
        p.move(a + Offset(0, 22.0 * i), _ms(16 * i));
      }
      // 20 dots laid: 5 ticks; 16 shown; dots 16..19 replaced slots 0..3
      expect(
        p.takeCues().where((DragCue c) => c == DragCue.tick),
        hasLength(5),
      );
      expect(p.values['trailN'], 16);
      expect(p.values['trailY0'], closeTo(a.dy + 22 * 16, 1e-9));
      expect(p.values['trailY3'], closeTo(a.dy + 22 * 19, 1e-9));
      expect(p.values['trailY4'], closeTo(a.dy + 22 * 4, 1e-9));
    });

    test('dots stay inside the handle', () {
      final PropDragPhysics p = _physics(AvatarScene.beach);
      p.start(sand.bottomRight - const Offset(5, 5), Duration.zero);
      p.move(sand.bottomRight + const Offset(200, 200), _ms(16));
      for (int i = 0; i < 16; i++) {
        if (i < p.values['trailN']!) {
          expect(p.values['trailX$i'], lessThanOrEqualTo(sand.right));
          expect(p.values['trailY$i'], lessThanOrEqualTo(sand.bottom));
        }
      }
    });

    test('the beach holds its drawing until a bigWave washes it away', () {
      final PropDragPhysics p = _physics(AvatarScene.beach);
      p.start(sand.center, Duration.zero);
      p.move(sand.center + const Offset(100, 0), _ms(16));
      p.end(_ms(32));
      expect(p.animating, isFalse);
      expect(p.values['trailFade'], 0);
      p.wash(_ms(5000));
      p.tick(_ms(5600));
      expect(p.values['trailFade'], closeTo(0.5, 1e-9));
      _settle(p, _ms(5600));
      // back to the contract defaults: nothing drawn
      expect(p.values, SceneDrags.of(AvatarScene.beach)!.defaults);
    });

    test('the cafe mists back over 20 s after the last wipe', () {
      final PropDragPhysics p = _physics(AvatarScene.cafe);
      final Rect window = SceneDrags.of(AvatarScene.cafe)!.rect;
      p.start(window.center, Duration.zero);
      p.move(window.center + const Offset(60, 0), _ms(16));
      p.end(_ms(1000));
      expect(p.animating, isTrue);
      p.tick(_ms(11000));
      expect(p.values['trailFade'], closeTo(0.5, 1e-9));
      // a new wipe clears it back (over 150 ms), keeping the old spots
      p.start(window.center + const Offset(0, 100), _ms(11000));
      expect(p.values['trailN'], 4);
      p.tick(_ms(11075));
      expect(p.values['trailFade'], closeTo(0.25, 1e-9));
      p.tick(_ms(11150));
      expect(p.values['trailFade'], 0);
      p.end(_ms(12000));
      _settle(p, _ms(12000));
      expect(p.values, SceneDrags.of(AvatarScene.cafe)!.defaults);
    });

    test('a nearly misted trail is dropped by a new wipe', () {
      final PropDragPhysics p = _physics(AvatarScene.cafe);
      final Rect window = SceneDrags.of(AvatarScene.cafe)!.rect;
      p.start(window.center, Duration.zero);
      p.move(window.center + const Offset(60, 0), _ms(16));
      p.end(_ms(20));
      p.tick(_ms(20 + 19000));
      p.start(window.topLeft + const Offset(10, 10), _ms(19020));
      expect(p.values['trailN'], 1);
      expect(p.values['trailFade'], 0);
    });

    test('reduce motion: the wave washes at once', () {
      final PropDragPhysics p = _physics(AvatarScene.beach, reduceMotion: true);
      p.start(sand.center, Duration.zero);
      p.end(_ms(16));
      p.wash(_ms(100));
      expect(p.animating, isFalse);
      expect(p.values['trailN'], 0);
      expect(p.values['trailFade'], 1);
    });
  });

  group('spin (the planet)', () {
    final Rect disc = SceneDrags.of(AvatarScene.deepSpace)!.rect;

    test('a horizontal drag turns; it wraps; a tick per 1/8 turn', () {
      final PropDragPhysics p = _physics(AvatarScene.deepSpace);
      final Offset a = disc.centerLeft;
      p.start(a, Duration.zero);
      p.takeCues();
      p.move(a + const Offset(PropDragPhysics.spinPxPerTurn / 4, 0), _ms(500));
      expect(p.values['spin'], closeTo(0.25, 1e-9));
      // one click per move that crosses a step (two in one frame could not
      // be felt apart: the haptics are >= 60 ms apart anyway)
      expect(p.takeCues(), <DragCue>[DragCue.tick]);
      // left past zero: wraps to 0.75
      p.move(a - const Offset(PropDragPhysics.spinPxPerTurn / 4, 0), _ms(1500));
      expect(p.values['spin'], closeTo(0.75, 1e-9));
      // 1/4 -> -1/4 in one move: one click
      expect(p.takeCues(), <DragCue>[DragCue.tick]);
      // step by step: a click per 1/8 turn
      for (int i = 1; i <= 4; i++) {
        p.move(
          a -
              Offset(
                PropDragPhysics.spinPxPerTurn / 4 +
                    PropDragPhysics.spinPxPerTurn / 8 * i,
                0,
              ),
          _ms(1500 + 100 * i),
        );
      }
      expect(p.takeCues(), hasLength(4));
      // a slow finger, then a rest: no inertia
      p.end(_ms(3000));
      expect(p.animating, isFalse);
    });

    test('a fling keeps turning and decays within 1.2 s', () {
      final PropDragPhysics p = _physics(AvatarScene.deepSpace);
      final Offset a = disc.centerLeft;
      p.start(a, Duration.zero);
      for (int i = 1; i <= 6; i++) {
        p.move(a + Offset(30.0 * i, 0), _ms(16 * i));
      }
      final double atRelease = p.values['spin']!;
      p.end(_ms(96));
      expect(p.animating, isTrue);
      p.tick(_ms(96 + 300));
      final double moved = p.values['spin']! - atRelease;
      expect(moved, greaterThan(0.1));
      final Duration end = _settle(p, _ms(396));
      expect(end - _ms(96), lessThanOrEqualTo(_ms(1216)));
      // 30 px / 16 ms = 1875 px/s = 2.08 turns/s; x tau (0.3 s) ~= 0.61
      // turns (98 % of it by 1.2 s): the bands wrap
      expect(p.values['spin'], inInclusiveRange(0, 1));
    });

    test('reduce motion: no inertia', () {
      final PropDragPhysics p = _physics(
        AvatarScene.deepSpace,
        reduceMotion: true,
      );
      final Offset a = disc.centerLeft;
      p.start(a, Duration.zero);
      for (int i = 1; i <= 6; i++) {
        p.move(a + Offset(30.0 * i, 0), _ms(16 * i));
      }
      p.end(_ms(96));
      expect(p.animating, isFalse);
    });
  });

  group('aim (the telescope)', () {
    final Rect stand = SceneDrags.of(AvatarScene.rooftop)!.rect;

    test('a horizontal drag swivels -1..1 and holds; a tick per 0.1', () {
      final PropDragPhysics p = _physics(AvatarScene.rooftop);
      final Offset a = stand.center;
      p.start(a, Duration.zero);
      p.takeCues();
      for (int i = 1; i <= 7; i++) {
        p.move(a + Offset(stand.width * 0.05 * i, 0), _ms(16 * i));
      }
      expect(p.values['aim'], closeTo(0.35, 1e-9));
      // 0.1, 0.2, 0.3 crossed
      expect(p.takeCues(), hasLength(3));
      p.move(a + Offset(stand.width * 3, 0), _ms(32));
      expect(p.values['aim'], 1);
      // the way back answers at once (no dead travel past the stop)
      p.move(a + Offset(stand.width * 2.9, 0), _ms(48));
      expect(p.values['aim'], closeTo(0.9, 1e-9));
      p.end(_ms(64));
      expect(p.animating, isFalse);
      expect(p.values['aim'], closeTo(0.9, 1e-9));
      // a later drag continues from where it held
      p.start(a, _ms(1000));
      p.move(a - Offset(stand.width * 2.5, 0), _ms(1016));
      expect(p.values['aim'], -1);
    });
  });
}
