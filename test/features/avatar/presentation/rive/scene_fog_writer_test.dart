import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_fog_writer.dart';

void main() {
  test('writes SceneVM.fog once per change, clamped', () {
    final List<double> writes = <double>[];
    final SceneFogWriter writer = SceneFogWriter((String name, double value) {
      expect(name, AvatarRiveContract.scenePropFog);
      writes.add(value);
    });
    writer.write(0);
    writer.write(0.0005);
    writer.write(0.5);
    writer.write(3);
    writer.write(double.nan);
    writer.write(1, force: true);
    expect(writes, <double>[0, 0.5, 1, 0, 1]);
  });

  test('the follower writes the fog to every fresh file and follows it', () {
    final ValueNotifier<double> fog = ValueNotifier<double>(0.5);
    addTearDown(fog.dispose);
    final SceneFogFollower follower = SceneFogFollower();
    addTearDown(follower.dispose);
    follower.follow(fog);
    final List<double> first = <double>[];
    follower.load((String name, double value) => first.add(value));
    fog.value = 1;
    expect(first, <double>[0.5, 1]);
    follower.unload();
    fog.value = 0.2;
    expect(first, <double>[0.5, 1]);
    final List<double> second = <double>[];
    follower.load((String name, double value) => second.add(value));
    expect(second, <double>[0.2]);
    follower.follow(null);
    expect(second, <double>[0.2, 0]);
  });
}
