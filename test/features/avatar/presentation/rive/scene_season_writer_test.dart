import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_season_writer.dart';

void main() {
  late List<(String, double)> writes;
  void sink(String name, double value) => writes.add((name, value));

  setUp(() => writes = <(String, double)>[]);

  group('SceneSeasonWriter', () {
    test('writes both, then only what moved by more than epsilon', () {
      final SceneSeasonWriter writer = SceneSeasonWriter(sink);
      writer.write(spring: 1 / 7, autumn: 0);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 1 / 7),
        (AvatarRiveContract.scenePropAutumn, 0),
      ]);
      writes.clear();
      writer.write(spring: 1 / 7 + 0.0004, autumn: 0);
      expect(writes, isEmpty);
      writer.write(spring: 2 / 7, autumn: 0);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 2 / 7),
      ]);
      writes.clear();
      writer.write(spring: 2 / 7, autumn: 0, force: true);
      expect(writes.length, 2);
    });

    test('clamps to 0..1; NaN is the default 0', () {
      final SceneSeasonWriter writer = SceneSeasonWriter(sink);
      writer.write(spring: -1, autumn: 3);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 0),
        (AvatarRiveContract.scenePropAutumn, 1),
      ]);
      writes.clear();
      writer.write(spring: double.nan, autumn: double.nan);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropAutumn, 0),
      ]);
    });

    test('the property names are the contract v14 ones', () {
      expect(AvatarRiveContract.scenePropSpring, 'spring');
      expect(AvatarRiveContract.scenePropAutumn, 'autumn');
    });
  });

  group('SceneSeasonFollower', () {
    test('a loaded file gets the current seasons in full', () {
      final ValueNotifier<double> spring = ValueNotifier<double>(0.5);
      final ValueNotifier<double> autumn = ValueNotifier<double>(0);
      final SceneSeasonFollower follower = SceneSeasonFollower()
        ..follow(spring, autumn);
      expect(writes, isEmpty, reason: 'no file yet');
      follower.load(sink);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 0.5),
        (AvatarRiveContract.scenePropAutumn, 0),
      ]);
      writes.clear();
      follower.load(sink);
      expect(writes.length, 2, reason: 'a new file gets both again');
      follower.dispose();
    });

    test('changes reach the loaded file; unload stops writes', () {
      final ValueNotifier<double> spring = ValueNotifier<double>(0);
      final ValueNotifier<double> autumn = ValueNotifier<double>(0);
      final SceneSeasonFollower follower = SceneSeasonFollower()
        ..follow(spring, autumn)
        ..load(sink);
      writes.clear();
      autumn.value = 3 / 7;
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropAutumn, 3 / 7),
      ]);
      writes.clear();
      follower.unload();
      spring.value = 1;
      expect(writes, isEmpty);
      follower.dispose();
    });

    test('without sources both are 0 (the v13 look)', () {
      final SceneSeasonFollower follower = SceneSeasonFollower()..load(sink);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 0),
        (AvatarRiveContract.scenePropAutumn, 0),
      ]);
      follower.dispose();
    });

    test('swapping sources moves the listeners; dispose detaches', () {
      final ValueNotifier<double> a = ValueNotifier<double>(0.2);
      final ValueNotifier<double> b = ValueNotifier<double>(0.8);
      final SceneSeasonFollower follower = SceneSeasonFollower()
        ..follow(a, null)
        ..load(sink);
      writes.clear();
      follower.follow(b, null);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropSpring, 0.8),
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
