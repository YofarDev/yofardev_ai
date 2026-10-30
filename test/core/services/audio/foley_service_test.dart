import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart';

class _FakePlayer implements FoleyPlayer {
  _FakePlayer(this.id, this.log);

  final int id;
  final List<String> log;
  bool disposed = false;

  @override
  Future<void> play(String asset, double volume) async =>
      log.add('$id:$asset@$volume');

  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeHaptics implements HapticsSink {
  final List<String> log = <String>[];

  @override
  void lightImpact() => log.add('light');

  @override
  void selectionClick() => log.add('selection');
}

void main() {
  late List<String> plays;
  late List<_FakePlayer> players;
  late _FakeHaptics haptics;
  late ValueNotifier<bool> enabled;

  FoleyService build(FakeAsync async) {
    final DateTime start = DateTime(2026, 10, 31);
    return FoleyService(
      createPlayer: () {
        final _FakePlayer p = _FakePlayer(players.length, plays);
        players.add(p);
        return p;
      },
      haptics: haptics,
      enabled: enabled,
      now: () => start.add(async.elapsed),
    );
  }

  setUp(() {
    plays = <String>[];
    players = <_FakePlayer>[];
    haptics = _FakeHaptics();
    enabled = ValueNotifier<bool>(true);
  });
  tearDown(() => enabled.dispose());

  test('each kind cycles through its variants at its volume', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      for (int k = 0; k < 5; k++) {
        foley.play('step');
        async.elapse(const Duration(milliseconds: 100));
      }
      foley.play('cloth');
      foley.play('paper');
      foley.play('click');
      expect(
        plays.map((String p) => p.substring(p.indexOf(':') + 1)).toList(),
        <String>[
          'foley/step_0.wav@0.35',
          'foley/step_1.wav@0.35',
          'foley/step_2.wav@0.35',
          'foley/step_3.wav@0.35',
          'foley/step_0.wav@0.35',
          'foley/cloth_0.wav@0.5',
          'foley/paper_0.wav@0.5',
          'foley/click_0.wav@0.5',
        ],
      );
    });
  });

  test('a small pool of players, reused round robin', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      for (int k = 0; k < 7; k++) {
        foley.play('step');
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(players, hasLength(foley.poolSize));
      expect(plays.map((String p) => p.split(':').first).toList(), <String>[
        '0',
        '1',
        '2',
        '0',
        '1',
        '2',
        '0',
      ]);
      foley.dispose();
      async.flushMicrotasks();
      expect(players.every((_FakePlayer p) => p.disposed), isTrue);
    });
  });

  test('a kind repeating within 90 ms is dropped; other kinds are not', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      foley.play('step');
      async.elapse(const Duration(milliseconds: 50));
      foley.play('step');
      foley.play('cloth');
      async.elapse(const Duration(milliseconds: 40));
      foley.play('step');
      expect(plays, hasLength(3));
      // a looping clip firing every frame plays at most once per 90 ms
      for (int k = 0; k < 60; k++) {
        foley.play('paper');
        async.elapse(const Duration(milliseconds: 16));
      }
      expect(
        plays.where((String p) => p.contains('paper')).length,
        lessThanOrEqualTo(11),
      );
    });
  });

  test('click fires a light impact, a tap a selection click', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      foley.play('click');
      foley.propTap();
      foley.play('step');
      expect(haptics.log, <String>['light', 'selection']);
    });
  });

  test('the sound-effects setting off: silent and no haptics', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      enabled.value = false;
      foley.play('click');
      foley.play('step');
      foley.propTap();
      expect(plays, isEmpty);
      expect(haptics.log, isEmpty);
      expect(players, isEmpty);
      enabled.value = true;
      foley.play('step');
      expect(plays, hasLength(1));
    });
  });

  test('paused: silent and no haptics', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      foley.setPaused(true);
      foley.play('click');
      foley.propTap();
      expect(plays, isEmpty);
      expect(haptics.log, isEmpty);
      foley.setPaused(false);
      foley.propTap();
      expect(haptics.log, <String>['selection']);
    });
  });

  test('an unknown kind is ignored', () {
    fakeAsync((FakeAsync async) {
      final FoleyService foley = build(async);
      foley.play('boom');
      expect(plays, isEmpty);
      expect(haptics.log, isEmpty);
    });
  });

  group('drags (M9 ruling 9)', () {
    test('the bell rings bell_0; a drag click keeps its haptic to itself', () {
      fakeAsync((FakeAsync async) {
        final FoleyService foley = build(async);
        foley.play('click', haptic: false);
        foley.play('bell');
        expect(
          plays.map((String p) => p.substring(p.indexOf(':') + 1)).toList(),
          <String>['foley/click_0.wav@0.5', 'foley/bell_0.wav@0.5'],
        );
        expect(haptics.log, isEmpty);
      });
    });

    test('drag haptics: selection and impact, at least 60 ms apart', () {
      fakeAsync((FakeAsync async) {
        final FoleyService foley = build(async);
        foley.haptic(DragHaptic.selection);
        async.elapse(const Duration(milliseconds: 59));
        foley.haptic(DragHaptic.selection);
        expect(haptics.log, <String>['selection']);
        async.elapse(const Duration(milliseconds: 1));
        foley.haptic(DragHaptic.impact);
        expect(haptics.log, <String>['selection', 'light']);
        // a spin ticking every frame: at most one per 60 ms
        for (int k = 0; k < 60; k++) {
          async.elapse(const Duration(milliseconds: 16));
          foley.haptic(DragHaptic.selection);
        }
        expect(haptics.log.length - 2, inInclusiveRange(14, 16));
      });
    });

    test('an impact is never swallowed by a selection click', () {
      fakeAsync((FakeAsync async) {
        final FoleyService foley = build(async);
        // the drag's start click and its threshold impact, one instant
        foley.haptic(DragHaptic.selection);
        foley.haptic(DragHaptic.impact);
        expect(haptics.log, <String>['selection', 'light']);
        // but a click right after the impact, or a second impact, waits
        async.elapse(const Duration(milliseconds: 10));
        foley.haptic(DragHaptic.selection);
        foley.haptic(DragHaptic.impact);
        expect(haptics.log, <String>['selection', 'light']);
        async.elapse(const Duration(milliseconds: 60));
        foley.haptic(DragHaptic.selection);
        expect(haptics.log, <String>['selection', 'light', 'selection']);
      });
    });

    test('drag haptics follow the sound-effects setting and the pause', () {
      fakeAsync((FakeAsync async) {
        final FoleyService foley = build(async);
        enabled.value = false;
        foley.haptic(DragHaptic.selection);
        enabled.value = true;
        foley.setPaused(true);
        foley.haptic(DragHaptic.impact);
        expect(haptics.log, isEmpty);
        foley.setPaused(false);
        foley.haptic(DragHaptic.impact);
        expect(haptics.log, <String>['light']);
      });
    });
  });
}
