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

  /// campfire flicker 1.0, the others 0 (as `SceneLights`).
  double flicker(AvatarScene scene) => scene == AvatarScene.campfire ? 1 : 0;

  AmbientBedService build(FakeAsync async, {AvatarScene? scene}) {
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
      scene: scene ?? AvatarScene.defaultScene,
    );
  }

  setUp(() {
    beds = <_FakeBed>[];
    enabled = ValueNotifier<bool>(true);
    rain = ValueNotifier<double>(0);
    speaking = StreamController<bool>.broadcast(sync: true);
    flares = StreamController<void>.broadcast(sync: true);
  });
  tearDown(() {
    enabled.dispose();
    rain.dispose();
  });

  _FakeBed bed(String name) => beds.firstWhere(
    (_FakeBed b) => b.log.any((String l) => l.contains(name)),
  );

  test('campfire: the crackle eases in to 0.18 × (0.6 + 0.4 × flicker)', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      expect(service.crackleVolumeNow, 0);
      async.elapse(const Duration(milliseconds: 400));
      expect(service.crackleVolumeNow, closeTo(0.09, 0.01));
      async.elapse(const Duration(milliseconds: 450));
      expect(service.crackleVolumeNow, closeTo(0.18, 1e-9));
      expect(bed('crackle').volume, closeTo(0.18, 1e-9));
      expect(service.rainPlaying, isFalse);
      service.dispose();
    });
  });

  test('rain volume per scene: outdoors 0.25 ×, indoors 0.12 ×, space 0', () {
    fakeAsync((FakeAsync async) {
      rain.value = 0.8;
      final AmbientBedService service = build(async);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.096, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.beach);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.2, 1e-9));
      service.setScene(AvatarScene.deepSpace);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, 0);
      expect(service.rainPlaying, isFalse);
      expect(bed('rain').log.last, 'stop');
      service.dispose();
    });
  });

  test('cafe and rooftop rain beds: 0.12 × and 0.25 ×; mountainHut has none '
      '(it snows)', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(async, scene: AvatarScene.cafe);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.12, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.rooftop);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.25, 1e-9));
      expect(service.crackleVolumeNow, 0);
      service.setScene(AvatarScene.mountainHut);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, 0);
      expect(service.rainPlaying, isFalse);
      service.dispose();
    });
  });

  test('the v14 scenes: forestCabin is outdoors (0.25 ×), the train and the '
      'library hear it behind glass (0.12 ×); none crackles', () {
    fakeAsync((FakeAsync async) {
      rain.value = 1;
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.forestCabin,
      );
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.25, 1e-9));
      expect(service.crackleVolumeNow, 0);
      for (final AvatarScene scene in <AvatarScene>[
        AvatarScene.trainCompartment,
        AvatarScene.library,
      ]) {
        service.setScene(scene);
        async.elapse(const Duration(seconds: 1));
        expect(service.rainVolumeNow, closeTo(0.12, 1e-9), reason: scene.name);
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
      expect(service.crackleVolumeNow, closeTo(0.6 * 0.18, 1e-9));
      expect(service.cracklePlaying, isTrue);
      flares.add(null);
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.6 * 0.35, 1e-9));
      service.setScene(AvatarScene.cafe);
      async.elapse(const Duration(seconds: 1));
      expect(service.crackleVolumeNow, 0);
      service.dispose();
    });
  });

  test('a flare swells the crackle to 0.35 for 2 s', () {
    fakeAsync((FakeAsync async) {
      final AmbientBedService service = build(
        async,
        scene: AvatarScene.campfire,
      );
      async.elapse(const Duration(seconds: 1));
      flares.add(null);
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.35, 1e-9));
      async.elapse(const Duration(milliseconds: 1200));
      // past the 2 s: easing back
      async.elapse(const Duration(milliseconds: 900));
      expect(service.crackleVolumeNow, closeTo(0.18, 1e-9));
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
      expect(service.crackleVolumeNow, closeTo(0.09, 1e-9));
      expect(service.rainVolumeNow, closeTo(0.125, 1e-9));
      speaking.add(false);
      async.elapse(const Duration(seconds: 1));
      expect(service.rainVolumeNow, closeTo(0.25, 1e-9));
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
      expect(service.crackleVolumeNow, closeTo(0.09, 0.01));
      expect(service.rainVolumeNow, closeTo(0.185, 0.01));
      async.elapse(const Duration(milliseconds: 450));
      expect(service.crackleVolumeNow, 0);
      expect(service.cracklePlaying, isFalse);
      expect(service.rainVolumeNow, closeTo(0.12, 1e-9));
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
      expect(service.crackleVolumeNow, closeTo(0.18, 1e-9));
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
}
