import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/prop_drag_controller.dart';

const Size _box = Size(390, 844);

/// A fake `SceneVM` number sink.
class _Sink {
  final List<(String, double)> writes = <(String, double)>[];
  final Map<String, double> vm = <String, double>{};

  void setNumber(String name, double value) {
    writes.add((name, value));
    vm[name] = value;
  }
}

void main() {
  late Duration now;
  late List<VoidCallback> frames;
  late List<DragHaptic> haptics;
  late List<String> sounds;
  late List<SceneEvent> events;
  late PropDragController c;

  /// Runs the scheduled frames, [count] times (each may schedule the next),
  /// [step] apart on the clock.
  void pumpFrames({int count = 1, Duration step = Duration.zero}) {
    for (int i = 0; i < count && frames.isNotEmpty; i++) {
      now += step;
      final List<VoidCallback> due = List<VoidCallback>.of(frames);
      frames.clear();
      for (final VoidCallback f in due) {
        f();
      }
    }
  }

  /// Ticks frames 16 ms apart until nothing is scheduled.
  void settle() {
    for (int i = 0; i < 4000 && frames.isNotEmpty; i++) {
      pumpFrames(step: const Duration(milliseconds: 16));
    }
  }

  setUp(() {
    now = Duration.zero;
    frames = <VoidCallback>[];
    haptics = <DragHaptic>[];
    sounds = <String>[];
    events = <SceneEvent>[];
    c = PropDragController(now: () => now, scheduleFrame: frames.add)
      ..onHaptic = haptics.add
      ..onFoley = sounds.add
      ..onSceneEvent = events.add;
  });

  /// The local point of the artboard point [p] (at parallax 0).
  Offset local(Offset p) => SceneDrags.toLocal(p, _box);

  _Sink attach(AvatarScene scene) {
    final _Sink sink = _Sink();
    c.attach(
      scene,
      setNumber: sink.setNumber,
      readNumber: (String n) => sink.vm[n],
    );
    return sink;
  }

  /// Pulls the cord (or rope) down by [artboardPx] and releases it.
  void pull(SceneDragHandle handle, double artboardPx, {bool release = true}) {
    final Offset top = local(handle.rect.center);
    expect(c.start(top, _box), isTrue);
    now += const Duration(milliseconds: 16);
    c.update(local(handle.rect.center + Offset(0, artboardPx)), _box);
    pumpFrames();
    if (release) {
      now += const Duration(milliseconds: 16);
      c.end();
    }
  }

  group('hit test (Review Focus 4: parallax moves the handle)', () {
    test('lands on the handle rect only, at rest', () {
      attach(AvatarScene.livingRoom);
      final SceneDragHandle cord = c.handle!;
      expect(c.canStart(local(cord.rect.center), _box), isTrue);
      expect(
        c.canStart(local(cord.rect.topLeft - const Offset(4, 4)), _box),
        isFalse,
      );
      expect(
        c.handleCentre(_box),
        offsetMoreOrLessEquals(local(cord.rect.center)),
      );
    });

    for (final double px in <double>[-1, 1]) {
      test('parallax x $px: the handle rides its plane', () {
        attach(AvatarScene.livingRoom);
        c.parallax = () => Offset(px, -1);
        final SceneDragHandle cord = c.handle!;
        final Offset shift = SceneDrags.planeOffset(cord.plane, Offset(px, -1));
        // just inside the moved edge, outside the rest rect
        final Offset lead = px > 0
            ? Offset(cord.rect.right + shift.dx - 2, cord.rect.center.dy)
            : Offset(cord.rect.left + shift.dx + 2, cord.rect.center.dy);
        expect(cord.rect.contains(lead), isFalse);
        expect(c.canStart(local(lead), _box), isTrue);
        // the strip it left
        final Offset left = px > 0
            ? Offset(cord.rect.left + 2, cord.rect.center.dy)
            : Offset(cord.rect.right - 2, cord.rect.center.dy);
        expect(c.canStart(local(left), _box), isFalse);
        expect(
          c.handleCentre(_box),
          offsetMoreOrLessEquals(local(cord.rect.center + shift)),
        );
      });
    }

    test('no scene, no handle, a disabled controller: nothing starts', () {
      expect(c.canStart(const Offset(100, 100), _box), isFalse);
      attach(AvatarScene.livingRoom);
      c.enabled = false;
      expect(c.canStart(c.handleCentre(_box)!, _box), isFalse);
      expect(c.start(c.handleCentre(_box)!, _box), isFalse);
    });
  });

  group('writes', () {
    test('only while something moves; nothing at attach or at rest', () {
      final _Sink sink = attach(AvatarScene.livingRoom);
      expect(sink.writes, isEmpty);
      pull(c.handle!, 50);
      expect(sink.vm['cord'], closeTo(0.5, 1e-9));
      settle();
      expect(sink.vm['cord'], 0);
      expect(frames, isEmpty);
      final int count = sink.writes.length;
      pumpFrames(count: 10, step: const Duration(milliseconds: 16));
      expect(sink.writes.length, count);
    });

    test('one write per frame however many moves arrive', () {
      final _Sink sink = attach(AvatarScene.rooftop);
      final Offset a = c.handleCentre(_box)!;
      c.start(a, _box);
      for (int i = 1; i <= 5; i++) {
        c.update(a + Offset(4.0 * i, 0), _box);
      }
      expect(frames, hasLength(1));
      pumpFrames();
      expect(
        sink.writes.where(((String, double) w) => w.$1 == 'aim'),
        hasLength(1),
      );
      // aim holds: nothing left to tick after release
      c.end();
      pumpFrames();
      expect(frames, isEmpty);
    });

    test('readNumber reads the attached file back', () {
      final _Sink sink = attach(AvatarScene.rooftop);
      sink.vm['aim'] = 0.25;
      expect(c.readNumber('aim'), 0.25);
      c.detach();
      expect(c.readNumber('aim'), isNull);
    });
  });

  group('tap after a drag (Review Focus 2)', () {
    test('a pull ending on the lamp drops its prop_tapped', () {
      attach(AvatarScene.livingRoom);
      final SceneDragHandle cord = c.handle!;
      c.start(local(cord.rect.center), _box);
      expect(c.shouldDropTap(), isFalse, reason: 'not moved yet');
      c.update(local(cord.rect.center + const Offset(0, 80)), _box);
      // Rive reports the tap on pointer-up, before the pan's end
      expect(c.shouldDropTap(), isTrue);
      c.end();
      // or the next frame, after it
      now += const Duration(milliseconds: 249);
      expect(c.shouldDropTap(), isTrue);
      now += const Duration(milliseconds: 2);
      expect(c.shouldDropTap(), isFalse);
    });

    test('a pan that never left the slop keeps the tap', () {
      attach(AvatarScene.livingRoom);
      final Offset a = c.handleCentre(_box)!;
      c.start(a, _box);
      c.update(a + const Offset(0, 3), _box);
      expect(c.shouldDropTap(), isFalse);
      c.end();
      expect(c.shouldDropTap(), isFalse);
    });
  });

  group('scene swap and journey (Review Focus 3)', () {
    test(
      'a swap ends the drag: no writes into the new scene, the spring stops',
      () {
        final _Sink old = attach(AvatarScene.livingRoom);
        pull(c.handle!, 80, release: false);
        expect(old.vm['cord'], closeTo(0.8, 1e-9));
        final int oldWrites = old.writes.length;
        // the view detaches on the swap, then attaches the new file
        c.detach();
        expect(c.dragging, isFalse);
        final _Sink next = attach(AvatarScene.mountainHut);
        // the finger keeps moving and lifts: nothing anywhere
        c.update(const Offset(100, 600), _box);
        c.end();
        settle();
        expect(next.writes, isEmpty);
        expect(old.writes.length, oldWrites);
      },
    );

    test('a swap mid-spring: the old frame callback is dead', () {
      final _Sink old = attach(AvatarScene.livingRoom);
      pull(c.handle!, 80);
      expect(frames, hasLength(1));
      c.detach();
      final _Sink next = attach(AvatarScene.livingRoom);
      settle();
      expect(next.writes, isEmpty);
      expect(old.vm['cord'], closeTo(0.8, 1e-9));
    });

    test('a journey releases the drag; its spring settles; no new drag', () {
      final _Sink sink = attach(AvatarScene.livingRoom);
      pull(c.handle!, 80, release: false);
      c.enabled = false;
      expect(c.dragging, isFalse);
      settle();
      expect(sink.vm['cord'], 0);
      expect(c.start(c.handleCentre(_box)!, _box), isFalse);
      c.enabled = true;
      expect(c.start(c.handleCentre(_box)!, _box), isTrue);
    });
  });

  group('cues', () {
    test(
      'the cord: selection, then impact + click + lightsOff; then lightsOn',
      () {
        attach(AvatarScene.livingRoom);
        pull(c.handle!, 70);
        expect(haptics, <DragHaptic>[DragHaptic.selection, DragHaptic.impact]);
        expect(sounds, <String>['click']);
        expect(events, <SceneEvent>[SceneEvent.lightsOff]);
        // the event played (the view echoes it): the next pull turns them on
        c.onSceneEventPlayed(SceneEvent.lightsOff);
        settle();
        pull(c.handle!, 70);
        expect(events.last, SceneEvent.lightsOn);
        // a short pull does nothing
        c.onSceneEventPlayed(SceneEvent.lightsOn);
        settle();
        events.clear();
        pull(c.handle!, 40);
        expect(events, isEmpty);
      },
    );

    test('a dropped event (a journey) keeps the lamp state', () {
      attach(AvatarScene.livingRoom);
      pull(c.handle!, 70);
      settle();
      // no echo: the lights are still on
      pull(c.handle!, 70);
      expect(events, <SceneEvent>[SceneEvent.lightsOff, SceneEvent.lightsOff]);
    });

    test('the rope rings the bell', () {
      attach(AvatarScene.mountainHut);
      pull(c.handle!, 70);
      expect(sounds, <String>['click', 'bell']);
      expect(events, <SceneEvent>[SceneEvent.bell]);
      expect(haptics, <DragHaptic>[DragHaptic.selection, DragHaptic.impact]);
    });

    test('a fast stir flares the campfire', () {
      attach(AvatarScene.campfire);
      final Offset a = c.handleCentre(_box)!;
      c.start(a, _box);
      for (int i = 1; i <= 12; i++) {
        now += const Duration(milliseconds: 16);
        // 12 local px / 16 ms at scale 0.44: ~1700 artboard px/s
        c.update(
          a + Offset((i ~/ 4).isEven ? 12.0 * (i % 4) : 36 - 12.0 * (i % 4), 0),
          _box,
        );
      }
      expect(events, <SceneEvent>[SceneEvent.flare]);
      expect(haptics.first, DragHaptic.selection);
      expect(haptics, contains(DragHaptic.impact));
    });

    test('a bigWave washes the beach trail; elsewhere it is nothing', () {
      final _Sink sink = attach(AvatarScene.beach);
      final Offset a = c.handleCentre(_box)!;
      c.start(a, _box);
      c.update(a + const Offset(40, 0), _box);
      c.end();
      pumpFrames();
      expect(sink.vm['trailN'], greaterThan(1));
      expect(frames, isEmpty);
      c.onSceneEventPlayed(SceneEvent.bigWave);
      settle();
      expect(sink.vm['trailN'], 0);
      expect(sink.vm['trailFade'], 1);
    });

    test('reduce motion reaches the physics', () {
      final _Sink sink = attach(AvatarScene.livingRoom);
      c.reduceMotion = true;
      pull(c.handle!, 80);
      pumpFrames();
      expect(sink.vm['cord'], 0);
      expect(frames, isEmpty);
      expect(haptics, contains(DragHaptic.impact));
    });
  });

  group('the real arena sequence (accept + first update, one instant)', () {
    late List<String> felt;
    late ValueNotifier<bool> enabled;

    /// A real [FoleyService] (its 60 ms gate and priorities) on fakes.
    FoleyService foley() {
      felt = <String>[];
      enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);
      final DateTime t0 = DateTime(2026, 10, 31);
      return FoleyService(
        createPlayer: _SilentPlayer.new,
        haptics: _Haptics(felt),
        enabled: enabled,
        now: () => t0.add(now),
      );
    }

    test('a poke: no flare, no first-frame tip jump > 0.1', () {
      attach(AvatarScene.campfire);
      const Offset tip = Offset(196, 1130);
      final Offset a = local(tip);
      expect(c.start(a, _box), isTrue);
      // the handle recognizer accepts past 3 logical px
      c.update(a + const Offset(3.5, 0), _box);
      pumpFrames();
      expect((c.values['pokeX']!).abs(), lessThanOrEqualTo(0.1));
      // a slow stir after it: back and forth, 4 px per 16 ms
      for (int i = 1; i <= 40; i++) {
        now += const Duration(milliseconds: 16);
        final int k = i % 16;
        c.update(a + Offset(3.5 + 4.0 * (k < 8 ? k : 16 - k), 0), _box);
        pumpFrames();
      }
      expect(events, isNot(contains(SceneEvent.flare)));
      // even the old 36 px pan slop arriving at once is no stir
      c.end();
      settle();
      events.clear();
      c.start(a, _box);
      c.update(a + const Offset(36, 0), _box);
      now += const Duration(milliseconds: 16);
      c.update(a + const Offset(38, 0), _box);
      expect(events, isEmpty);
    });

    test('a pull: the threshold impact reaches the hand after the start '
        'click, even at once', () {
      final FoleyService f = foley();
      c
        ..onHaptic = f.haptic
        ..onFoley = (String kind) => f.play(kind, haptic: false);
      attach(AvatarScene.livingRoom);
      final Offset a = c.handleCentre(_box)!;
      // a decisive flick: past 0.6 in the accepting update itself
      c.start(a, _box);
      c.update(a + const Offset(0, 36), _box);
      expect(felt, <String>['selection', 'light']);
      c.end();
      settle();
      // a slow pull: accepted at 3.5 px, then 4 px per 16 ms
      now += const Duration(seconds: 1);
      felt.clear();
      c.start(a, _box);
      c.update(a + const Offset(0, 3.5), _box);
      pumpFrames();
      expect(c.values['cord'], lessThan(0.1));
      for (int i = 1; i <= 10; i++) {
        now += const Duration(milliseconds: 16);
        c.update(a + Offset(0, 3.5 + 4.0 * i), _box);
        pumpFrames();
      }
      expect(c.values['cord'], greaterThan(0.6));
      expect(felt, <String>['selection', 'light']);
      expect(events, <SceneEvent>[SceneEvent.lightsOff, SceneEvent.lightsOff]);
    });
  });
}

class _SilentPlayer implements FoleyPlayer {
  @override
  Future<void> play(String asset, double volume) async {}

  @override
  Future<void> dispose() async {}
}

class _Haptics implements HapticsSink {
  _Haptics(this.felt);

  final List<String> felt;

  @override
  void lightImpact() => felt.add('light');

  @override
  void selectionClick() => felt.add('selection');
}
