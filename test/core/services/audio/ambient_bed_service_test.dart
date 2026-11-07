import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/audio/ambient_bed_service.dart';

class _FakeBed implements BedPlayer {
  final List<String> log = <String>[];
  double volume = 0;
  bool playing = false;

  @override
  Future<void> start(String asset, double volume) async {
    log.add('start $asset');
    playing = true;
    this.volume = volume;
  }

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> stop() async {
    log.add('stop');
    playing = false;
    volume = 0;
  }

  @override
  Future<void> dispose() async => log.add('dispose');
}

void main() {
  late List<_FakeBed> beds;
  late ValueNotifier<bool> enabled;
  late ValueNotifier<double> rain;
  late StreamController<bool> speaking;
  late StreamController<void> flares;
  late ValueNotifier<double?> wind;
  late StreamController<void> gusts;

  /// campfire flicker 1.0, the others 0 (as `SceneLights`).
  double flicker(AvatarScene scene) => scene == AvatarScene.campfire ? 1 : 0;

  AmbientBedService build(
    FakeAsync async, {
    AvatarScene? scene,
    Future<bool> Function(String asset)? assetAvailable,
  }) {
    final DateTime start = DateTime(2026, 10, 31);
    return AmbientBedService(
      createPlayer: () {
        final _FakeBed bed = _FakeBed();
        beds.add(bed);
        return bed;
      },
      enabled: enabled,
      flickerOf: flicker,
      now: () => start.add(async.elapsed),
      rain: rain,
      speaking: speaking.stream,
      flares: flares.stream,
      wind: wind,
      gusts: gusts.stream,
      assetAvailable: assetAvailable,
      scene: scene ?? AvatarScene.defaultScene,
    );
  }

  setUp(() {
    beds = <_FakeBed>[];
    enabled = ValueNotifier<bool>(true);
    rain = ValueNotifier<double>(0);
    speaking = StreamController<bool>.broadcast(sync: true);
    flares = StreamController<void>.broadcast(sync: true);
    wind = ValueNotifier<double?>(null);
    gusts = StreamController<void>.broadcast(sync: true);
  });
  tearDown(() {
    enabled.dispose();
    rain.dispose();
    wind.dispose();
  });

  _FakeBed bed(String name) => beds.firstWhere(
    (_FakeBed b) => b.log.any((String l) => l.contains(name)),
  );

  test('campfire: the crackle eases in to 0.036 × (0.6 + 0.4 × flicker)', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      expect(service.crackleVolumeNow, 0);
      async.elapse(const Duration(milliseconds: 400));
      expect(service.crackleVolumeNow, closeTo(0.018, 0.005));
      async.elapse(const Duration(milliseconds: 450));
      expect(service.crackleVolumeNow, closeTo(0.036, 1e-9));
      expect(bed('crackle').volume, closeTo(0.036, 1e-9));
      expect(service.rainPlaying, isFalse);
      service.dispose();
    });
  });

  test('rain volume per scene: outdoors 0.05 ×, indoors 0.024 ×, space 0', () {
    fakeAsync((FakeAsync async) {
      rain.value = 0.8;
      final AmbientBedService service = build(async);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.0192, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.beach);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.04, 1e-9));
      service.setScene(AvatarScene.deepSpace);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, 0);
      expect(service.rainPlaying, isFalse);
      expect(bed('rain').log.last, 'stop');
      service.dispose();
    });
  });

  test('cafe and rooftop rain beds: 0.024 × and 0.05 ×; mountainHut has none '
      '(it snows)', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(async, scene: AvatarScene.cafe);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.024, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.rooftop);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.05, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.mountainHut);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, 0);
      expect(service.rainPlaying, isFalse);
      service.dispose();
    });
  });

  test('the v14 scenes: forestCabin is outdoors (0.05 ×), the train and the '
      'library hear it behind glass (0.024 ×); none crackles', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.forestCabin,
      );
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.05, 1e-9));
      expect(service.crackleVolumeNow, 0);
      for (final AvatarScene scene in <AvatarScene>[
        AvatarScene.trainCompartment,
        AvatarScene.library,
      ]) {
        service.setScene(scene);
        async.elapse(const Duration(seconds: 1));
        expect(service.rainVolumeNow, closeTo(0.024, 1e-9), reason: scene.name);
        expect(service.crackleVolumeNow, 0, reason: scene.name);
        expect(service.cracklePlaying, isFalse, reason: scene.name);
      }
      // a flare in a scene without a fire does not crackle
      flares.add(null);
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, 0);
      service.dispose();
    });
  });

  test('mountainHut: the stove crackles at 0.6 × the campfire level, a flare '
      'swells it', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.mountainHut,
      );
      async.elapse(const Duration(seconds: 1));
      expect(service.crackleVolumeNow, closeTo(0.6 * 0.036, 1e-9));
      expect(service.cracklePlaying, isTrue);
      flares.add(null);
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.6 * 0.07, 1e-9));
      service.setScene(AvatarScene.cafe);
      async.elapse(const Duration(seconds: 1));
      expect(service.crackleVolumeNow, 0);
      service.dispose();
    });
  });

  test('a flare swells the crackle to 0.07 for 2 s', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 1));
      flares.add(null);
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.07, 1e-9));
      async.elapse(const Duration(milliseconds: 1200));
      // past the 2 s: easing back
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.036, 1e-9));
      // a flare elsewhere does nothing
      service.setScene(AvatarScene.beach);
      flares.add(null);
      async.elapse(const Duration(seconds: 1));
      expect(service.crackleVolumeNow, 0);
      service.dispose();
    });
  });

  test('the beds duck to 50 % while the avatar speaks', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 1));
      speaking.add(true);
      async.elapse(const Duration(seconds: 1));
      expect(service.crackleVolumeNow, closeTo(0.018, 1e-9));
      expect(service.rainVolumeNow, closeTo(0.025, 1e-9));
      speaking.add(false);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.05, 1e-9));
      service.dispose();
    });
  });

  test('a scene change cross-fades: the crackle leaves as the rain grows', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 1));
      service.setScene(AvatarScene.livingRoom);
      async.elapse(const Duration(milliseconds: 400));
      expect(service.crackleVolumeNow, closeTo(0.018, 0.005));
      expect(service.rainVolumeNow, closeTo(0.037, 0.005));
      async.elapse(const Duration(milliseconds: 450));
      expect(service.crackleVolumeNow, 0);
      expect(service.cracklePlaying, isFalse);
      expect(service.rainVolumeNow, closeTo(0.024, 1e-9));
      service.dispose();
    });
  });

  test('pause stops both beds at once; resume eases them back', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 1));
      expect(service.cracklePlaying && service.rainPlaying, isTrue);
      service.setPaused(true);
      expect(service.cracklePlaying || service.rainPlaying, isFalse);
      expect(bed('crackle').playing || bed('rain').playing, isFalse);
      async.elapse(const Duration(seconds: 5));
      expect(bed('crackle').playing, isFalse);
      service.setPaused(false);
      async.elapse(const Duration(seconds: 1));
      expect(service.cracklePlaying, isTrue);
      expect(service.crackleVolumeNow, closeTo(0.036, 1e-9));
      service.dispose();
    });
  });

  test('the setting off: never starts; off while playing stops them', () {
    fakeAsync((FakeAsync async) {
      enabled.value = false;
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 2));
      expect(beds, isEmpty);
      enabled.value = true;
      async.elapse(const Duration(seconds: 1));
      expect(service.cracklePlaying, isTrue);
      enabled.value = false;
      expect(service.cracklePlaying || service.rainPlaying, isFalse);
      expect(async.pendingTimers, isEmpty);
      service.dispose();
    });
  });

  test('dry and outside the campfire: nothing plays, no timer runs', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(async);
      async.elapse(const Duration(seconds: 2));
      expect(beds, isEmpty);
      expect(async.pendingTimers, isEmpty);
      service.dispose();
    });
  });

  group('wind bed (M11 ruling 11)', () {
    test('forestCabin: 0.044 × 0.5 without a report, × (0.5 + 0.5 × wind) '
        'with one', () {
      fakeAsync((FakeAsync async) {
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.forestCabin,
        );
        async.elapse(const Duration(seconds: 1));
        expect(service.windVolumeNow, closeTo(0.022, 1e-9));
        expect(service.windPlaying, isTrue);
        expect(bed('wind').log.first, 'start foley/bed_wind.wav');
        wind.value = 1;
        async.elapse(const Duration(seconds: 1));
        expect(service.windVolumeNow, closeTo(0.044, 1e-9));
        expect(bed('wind').volume, closeTo(0.044, 1e-9));
        wind.value = 0.5;
        async.elapse(const Duration(seconds: 1));
        expect(service.windVolumeNow, closeTo(0.033, 1e-9));
        wind.value = 0;
        async.elapse(const Duration(seconds: 1));
        expect(service.windVolumeNow, closeTo(0.022, 1e-9));
        service.dispose();
      });
    });

    test('per-scene base at full wind; every other scene is silent', () {
      fakeAsync((FakeAsync async) {
        wind.value = 1;
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.rooftop,
        );
        final Map<AvatarScene, double> base = <AvatarScene, double>{
          AvatarScene.rooftop: 0.036,
          AvatarScene.beach: 0.024,
          AvatarScene.campfire: 0.02,
          AvatarScene.mountainHut: 0.012,
          AvatarScene.forestCabin: 0.044,
          AvatarScene.livingRoom: 0,
          AvatarScene.deepSpace: 0,
          AvatarScene.cafe: 0,
          AvatarScene.trainCompartment: 0,
          AvatarScene.library: 0,
        };
        expect(base.keys.toSet(), AvatarScene.values.toSet());
        base.forEach((AvatarScene scene, double expected) {
          service.setScene(scene);
          async.elapse(const Duration(seconds: 1));
          expect(
            service.windVolumeNow,
            closeTo(expected, 1e-9),
            reason: scene.name,
          );
          expect(service.windPlaying, expected > 0, reason: scene.name);
        });
        service.dispose();
      });
    });

    test('a gust swells it to 1.5 × the base for 2 s; elsewhere nothing', () {
      fakeAsync((FakeAsync async) {
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.forestCabin,
        );
        async.elapse(const Duration(seconds: 1));
        gusts.add(null);
        async.elapse(const Duration(milliseconds: 900));
        expect(service.windVolumeNow, closeTo(0.044 * 1.5, 1e-9));
        async.elapse(const Duration(milliseconds: 1200));
        async.elapse(const Duration(milliseconds: 900));
        expect(service.windVolumeNow, closeTo(0.022, 1e-9));
        expect(async.pendingTimers, isEmpty);
        service.setScene(AvatarScene.library);
        async.elapse(const Duration(seconds: 1));
        gusts.add(null);
        async.elapse(const Duration(milliseconds: 900));
        expect(service.windVolumeNow, 0);
        expect(service.windPlaying, isFalse);
        service.dispose();
      });
    });

    test('a gust and a flare overlapping both end', () {
      fakeAsync((FakeAsync async) {
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.campfire,
        );
        async.elapse(const Duration(seconds: 1));
        flares.add(null);
        async.elapse(const Duration(milliseconds: 500));
        gusts.add(null);
        async.elapse(const Duration(milliseconds: 900));
        expect(service.crackleVolumeNow, closeTo(0.07, 1e-9));
        expect(service.windVolumeNow, closeTo(0.02 * 1.5, 1e-9));
        async.elapse(const Duration(seconds: 4));
        expect(service.crackleVolumeNow, closeTo(0.036, 1e-9));
        expect(service.windVolumeNow, closeTo(0.01, 1e-9));
        expect(async.pendingTimers, isEmpty);
        service.dispose();
      });
    });

    test(
      'ducks while the avatar speaks; the setting off and pause stop it',
      () {
        fakeAsync((FakeAsync async) {
          wind.value = 1;
          final AmbientBedService service = build(
            async,
            scene: AvatarScene.forestCabin,
          );
          async.elapse(const Duration(seconds: 1));
          speaking.add(true);
          async.elapse(const Duration(seconds: 1));
          expect(service.windVolumeNow, closeTo(0.022, 1e-9));
          service.setPaused(true);
          expect(service.windPlaying, isFalse);
          expect(bed('wind').playing, isFalse);
          service.setPaused(false);
          async.elapse(const Duration(seconds: 1));
          expect(service.windPlaying, isTrue);
          enabled.value = false;
          expect(service.windPlaying, isFalse);
          expect(async.pendingTimers, isEmpty);
          service.dispose();
        });
      },
    );

    test('a missing asset: the wind bed never starts, the others still do', () {
      fakeAsync((FakeAsync async) {
        final List<String> asked = <String>[];
        rain.value = 1;
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.forestCabin,
          assetAvailable: (String asset) async {
            asked.add(asset);
            return asset != AmbientBedService.windAsset;
          },
        );
        async.elapse(const Duration(seconds: 2));
        expect(asked, <String>[AmbientBedService.windAsset]);
        expect(service.windPlaying, isFalse);
        expect(service.windVolumeNow, 0);
        expect(service.rainPlaying, isTrue);
        expect(
          beds.any((_FakeBed b) => b.log.contains('start foley/bed_wind.wav')),
          isFalse,
        );
        service.dispose();
      });
    });

    test('a found asset starts the bed once the check answers', () {
      fakeAsync((FakeAsync async) {
        final Completer<bool> found = Completer<bool>();
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.forestCabin,
          assetAvailable: (String asset) => found.future,
        );
        async.elapse(const Duration(seconds: 1));
        expect(service.windPlaying, isFalse);
        found.complete(true);
        async.elapse(const Duration(seconds: 1));
        expect(service.windPlaying, isTrue);
        expect(service.windVolumeNow, closeTo(0.022, 1e-9));
        service.dispose();
      });
    });

    test('a failing check counts as missing', () {
      fakeAsync((FakeAsync async) {
        final AmbientBedService service = build(
          async,
          scene: AvatarScene.forestCabin,
          assetAvailable: (String asset) async => throw StateError('no'),
        );
        async.elapse(const Duration(seconds: 1));
        expect(service.windPlaying, isFalse);
        service.dispose();
      });
    });
  });
}
