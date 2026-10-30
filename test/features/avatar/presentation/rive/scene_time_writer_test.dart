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
    expect(writes, <(String, double)>[
      (AvatarRiveContract.scenePropDaylight, 0.7),
      (AvatarRiveContract.scenePropDusk, 0),
    ]);
    writes.clear();
    follower.unload();
    daylight.value = 0.2;
    expect(writes, isEmpty);
    follower.dispose();
  });
}
