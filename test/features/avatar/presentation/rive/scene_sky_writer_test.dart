import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_sky_writer.dart';

void main() {
  late List<(String, double)> writes;
  void sink(String name, double value) => writes.add((name, value));

  setUp(() => writes = <(String, double)>[]);

  group('SceneSkyWriter', () {
    test('writes both, then only what moved by more than epsilon', () {
      final SceneSkyWriter writer = SceneSkyWriter(sink);
      writer.write(moonPhase: 0.5, festive: 1);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.5),
        (AvatarRiveContract.scenePropFestive, 1),
      ]);
      writes.clear();
      writer.write(moonPhase: 0.5004, festive: 1);
      expect(writes, isEmpty);
      writer.write(moonPhase: 0.52, festive: 1);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.52),
      ]);
      writes.clear();
      writer.write(moonPhase: 0.52, festive: 0, force: true);
      expect(writes.length, 2);
    });

    test(
      'clamps: below 0 is "as drawn" (-1), above 1 is 1, NaN is default',
      () {
        final SceneSkyWriter writer = SceneSkyWriter(sink);
        writer.write(moonPhase: -0.3, festive: 4);
        expect(writes, <(String, double)>[
          (AvatarRiveContract.scenePropMoonPhase, -1),
          (AvatarRiveContract.scenePropFestive, 1),
        ]);
        writes.clear();
        writer.write(moonPhase: 7, festive: -2);
        expect(writes, <(String, double)>[
          (AvatarRiveContract.scenePropMoonPhase, 1),
          (AvatarRiveContract.scenePropFestive, 0),
        ]);
        writes.clear();
        writer.write(moonPhase: double.nan, festive: double.nan);
        // festive was already 0
        expect(writes, <(String, double)>[
          (AvatarRiveContract.scenePropMoonPhase, -1),
        ]);
      },
    );

    test('the property names are the contract v12 ones', () {
      expect(AvatarRiveContract.scenePropMoonPhase, 'moonPhase');
      expect(AvatarRiveContract.scenePropFestive, 'festive');
    });

    test('a phase that wraps through new (0.999 to 0.001) is written', () {
      final SceneSkyWriter writer = SceneSkyWriter(sink);
      writer.write(moonPhase: 0.9995, festive: 0);
      writes.clear();
      writer.write(moonPhase: 0.0004, festive: 0);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.0004),
      ]);
    });
  });

  group('SceneSkyFollower', () {
    test('a loaded file gets the current moon and festive dressing', () {
      final ValueNotifier<double> moon = ValueNotifier<double>(0.25);
      final ValueNotifier<double> festive = ValueNotifier<double>(1);
      final SceneSkyFollower follower = SceneSkyFollower()
        ..follow(moon, festive);
      expect(writes, isEmpty, reason: 'no file yet');
      follower.load(sink);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.25),
        (AvatarRiveContract.scenePropFestive, 1),
      ]);
      follower.dispose();
    });

    test('changes are written to the loaded file', () {
      final ValueNotifier<double> moon = ValueNotifier<double>(0.1);
      final ValueNotifier<double> festive = ValueNotifier<double>(0);
      final SceneSkyFollower follower = SceneSkyFollower()
        ..follow(moon, festive)
        ..load(sink);
      writes.clear();
      moon.value = 0.3;
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.3),
      ]);
      writes.clear();
      festive.value = 1;
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropFestive, 1),
      ]);
      follower.dispose();
    });

    test('a new file gets both again even when equal; unload stops writes', () {
      final ValueNotifier<double> moon = ValueNotifier<double>(0.6);
      final ValueNotifier<double> festive = ValueNotifier<double>(1);
      final SceneSkyFollower follower = SceneSkyFollower()
        ..follow(moon, festive)
        ..load(sink);
      writes.clear();
      follower.load(sink);
      expect(writes.length, 2);
      writes.clear();
      follower.unload();
      moon.value = 0.9;
      expect(writes, isEmpty);
      follower.dispose();
    });

    test('without sources the moon is as drawn and nothing is festive', () {
      final SceneSkyFollower follower = SceneSkyFollower()..load(sink);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, -1),
        (AvatarRiveContract.scenePropFestive, 0),
      ]);
      follower.dispose();
    });

    test('swapping sources moves the listeners', () {
      final ValueNotifier<double> a = ValueNotifier<double>(0.2);
      final ValueNotifier<double> b = ValueNotifier<double>(0.8);
      final SceneSkyFollower follower = SceneSkyFollower()
        ..follow(a, null)
        ..load(sink);
      writes.clear();
      follower.follow(b, null);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropMoonPhase, 0.8),
      ]);
      writes.clear();
      a.value = 0.4;
      expect(writes, isEmpty);
      follower.dispose();
      b.value = 0.1;
      expect(writes, isEmpty);
    });
  });
}
