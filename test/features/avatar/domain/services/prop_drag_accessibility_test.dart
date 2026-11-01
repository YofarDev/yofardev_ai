import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/domain/services/prop_drag_physics.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

PropDragPhysics _physics(AvatarScene scene, {bool reduceMotion = false}) =>
    PropDragPhysics(SceneDrags.of(scene)!, reduceMotion: reduceMotion);

Duration _settle(PropDragPhysics physics, Duration from) {
  Duration t = from;
  while (physics.animating && t - from < const Duration(seconds: 30)) {
    t += _ms(16);
    physics.tick(t);
  }
  return t;
}

/// M11 ruling 17: a screen reader's custom action on a scene's drag handle
/// runs one drag's worth through the same physics and cues as a finger.
void main() {
  group('pull: the threshold action, then the spring back', () {
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.livingRoom,
      AvatarScene.mountainHut,
      AvatarScene.trainCompartment,
    ]) {
      test(scene.name, () {
        final PropDragPhysics p = _physics(scene);
        final String name = p.handle.numbers.first.name;
        p.accessibilityAction(Duration.zero);
        expect(p.takeCues(), <DragCue>[DragCue.start, DragCue.pullFired]);
        expect(p.dragging, isFalse);
        expect(p.values[name], 1);
        expect(p.animating, isTrue);
        _settle(p, Duration.zero);
        expect(p.values[name], 0);
        // the next action fires again
        p.accessibilityAction(_ms(2000));
        expect(p.takeCues(), contains(DragCue.pullFired));
      });
    }

    test('under reduce motion it is back in one frame', () {
      final PropDragPhysics p = _physics(
        AvatarScene.livingRoom,
        reduceMotion: true,
      );
      p.accessibilityAction(Duration.zero);
      expect(p.takeCues(), contains(DragCue.pullFired));
      expect(p.values['cord'], 0);
      expect(p.animating, isFalse);
    });
  });

  group('spin: 1/8 turn, no inertia', () {
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.deepSpace,
      AvatarScene.forestCabin,
    ]) {
      test(scene.name, () {
        final PropDragPhysics p = _physics(scene);
        final String name = p.handle.numbers.first.name;
        p.accessibilityAction(Duration.zero);
        expect(p.values[name], closeTo(0.125, 1e-9));
        expect(p.takeCues(), <DragCue>[DragCue.start, DragCue.tick]);
        expect(p.animating, isFalse, reason: 'no fling');
        for (int i = 1; i < 8; i++) {
          p.accessibilityAction(_ms(500 * i));
        }
        // eight steps: a whole turn, wrapped
        expect(p.values[name], closeTo(0, 1e-9));
      });
    }
  });

  group('aim: steps of 0.25, back the other way at either end', () {
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.rooftop,
      AvatarScene.library,
    ]) {
      test(scene.name, () {
        final PropDragPhysics p = _physics(scene);
        final String name = p.handle.numbers.first.name;
        final List<double> seen = <double>[];
        for (int i = 0; i < 12; i++) {
          p.accessibilityAction(_ms(100 * i));
          seen.add(p.values[name]!);
        }
        expect(seen.map((double v) => (v * 100).round() / 100), <double>[
          0.25, 0.5, 0.75, 1, 0.75, 0.5, 0.25, 0, -0.25, -0.5, -0.75, -1, //
        ]);
        p.accessibilityAction(_ms(2000));
        expect(p.values[name], closeTo(-0.75, 1e-9));
        expect(p.takeCues(), contains(DragCue.tick));
        expect(p.animating, isFalse);
      });
    }
  });

  group('trail: one short stroke inside the handle', () {
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.beach,
      AvatarScene.cafe,
    ]) {
      test(scene.name, () {
        final PropDragPhysics p = _physics(scene);
        p.accessibilityAction(Duration.zero);
        expect(p.values['trailN'], PropDragPhysics.accessibleTrailDots);
        expect(p.values['trailFade'], 0);
        for (int i = 0; i < PropDragPhysics.accessibleTrailDots; i++) {
          final Offset dot = Offset(
            p.values['trailX$i']!,
            p.values['trailY$i']!,
          );
          expect(p.handle.rect.inflate(1e-6).contains(dot), isTrue);
        }
        expect(p.takeCues(), <DragCue>[DragCue.start, DragCue.tick]);
        // the next stroke is a row lower
        p.accessibilityAction(_ms(400));
        expect(
          p.values['trailY${PropDragPhysics.accessibleTrailDots}']!,
          greaterThan(p.values['trailY0']!),
        );
      });
    }
  });

  group('poke: one stir and the flare, cooldown permitting', () {
    test('campfire', () {
      final PropDragPhysics p = _physics(AvatarScene.campfire);
      p.accessibilityAction(Duration.zero);
      final List<DragCue> cues = p.takeCues();
      expect(cues.first, DragCue.start);
      expect(cues, contains(DragCue.tick));
      expect(cues.where((DragCue c) => c == DragCue.flare), hasLength(1));
      // the stick eases out
      expect(p.dragging, isFalse);
      _settle(p, Duration.zero);
      expect(p.values['poke'], 0);
      // within the cooldown: a stir, no flare
      p.accessibilityAction(_ms(1000));
      expect(p.takeCues(), isNot(contains(DragCue.flare)));
      p.accessibilityAction(PropDragPhysics.flareCooldown + _ms(1));
      expect(p.takeCues(), contains(DragCue.flare));
    });
  });

  test('ignored while a finger holds the handle', () {
    final PropDragPhysics p = _physics(AvatarScene.livingRoom);
    final Offset grab = p.handle.rect.topCenter;
    p.start(grab, Duration.zero);
    p.takeCues();
    p.accessibilityAction(_ms(16));
    expect(p.takeCues(), isEmpty);
    expect(p.values['cord'], 0);
    expect(p.dragging, isTrue);
  });
}
