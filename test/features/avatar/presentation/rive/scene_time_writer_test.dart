import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_time_writer.dart';

void main() {
  late List<(String, double)> writes;
  void sink(String name, double value) => writes.add((name, value));

  setUp(() => writes = <(String, double)>[]);

  test('a loaded file gets the current daylight and dusk', () {
    final ValueNotifier<double> daylight = ValueNotifier<double>(0.4);
    final ValueNotifier<double> dusk = ValueNotifier<double>(1);
    final SceneTimeFollower follower = SceneTimeFollower()
      ..follow(daylight, dusk);
    expect(writes, isEmpty, reason: 'no file yet');
    follower.load(sink);
    expect(writes, <(String, double)>[
      (AvatarRiveContract.scenePropDaylight, 0.4),
      (AvatarRiveContract.scenePropDusk, 1),
      (AvatarRiveContract.scenePropNight, 0),
    ]);
    follower.dispose();
  });

  test('changes are written, tiny ones skipped, values clamped', () {
    final ValueNotifier<double> daylight = ValueNotifier<double>(0);
    final ValueNotifier<double> dusk = ValueNotifier<double>(0);
    final SceneTimeFollower follower = SceneTimeFollower()
      ..follow(daylight, dusk)
      ..load(sink);
    writes.clear();
    daylight.value = 0.0005;
    expect(writes, isEmpty);
    daylight.value = 1.5;
    expect(writes, <(String, double)>[
      (AvatarRiveContract.scenePropDaylight, 1),
      (AvatarRiveContract.scenePropNight, 0),
    ]);
    follower.dispose();
  });

  test('a new file gets the values again; after unload nothing is written', () {
    final ValueNotifier<double> daylight = ValueNotifier<double>(0.7);
    final SceneTimeFollower follower = SceneTimeFollower()
      ..follow(daylight, null)
      ..load(sink);
    writes.clear();
    follower.load(sink);
    expect(writes.take(2), <(String, double)>[
      (AvatarRiveContract.scenePropDaylight, 0.7),
      (AvatarRiveContract.scenePropDusk, 0),
    ]);
    expect(writes.last.$1, AvatarRiveContract.scenePropNight);
    expect(writes.last.$2, closeTo(0.3, 1e-9));
    writes.clear();
    follower.unload();
    daylight.value = 0.2;
    expect(writes, isEmpty);
    follower.dispose();
  });

  group('night (contract v13)', () {
    test('night = (1 − daylight) × (1 − dusk)', () {
      for (final (double d, double k, double n) c in <(double, double, double)>[
        (0, 0, 1),
        (1, 0, 0),
        (0, 1, 0),
        (0.5, 0, 0.5),
        (0.2, 0.5, 0.4),
        (0.75, 0.75, 0.0625),
        (2, -1, 0), // clamped: full day
      ]) {
        expect(
          SceneTimeFollower.nightOf(c.$1, c.$2),
          closeTo(c.$3, 1e-9),
          reason: 'daylight ${c.$1}, dusk ${c.$2}',
        );
      }
      expect(SceneTimeFollower.nightOf(double.nan, double.nan), 1);
    });

    test('deep night is written as 1 and follows the clock', () {
      final ValueNotifier<double> daylight = ValueNotifier<double>(0);
      final ValueNotifier<double> dusk = ValueNotifier<double>(0);
      final SceneTimeFollower follower = SceneTimeFollower()
        ..follow(daylight, dusk)
        ..load(sink);
      expect(writes.last, (AvatarRiveContract.scenePropNight, 1));
      writes.clear();
      dusk.value = 0.5;
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropDusk, 0.5),
        (AvatarRiveContract.scenePropNight, 0.5),
      ]);
      writes.clear();
      dusk.value = 0.5004;
      expect(writes, isEmpty, reason: 'below epsilon');
      follower.dispose();
    });

    test('without a clock night stays 0: the v12 look (lab, tests)', () {
      final SceneTimeFollower follower = SceneTimeFollower()
        ..follow(null, null)
        ..load(sink);
      expect(writes, <(String, double)>[
        (AvatarRiveContract.scenePropDaylight, 0),
        (AvatarRiveContract.scenePropDusk, 0),
        (AvatarRiveContract.scenePropNight, 0),
      ]);
      follower.dispose();
    });
  });
}
