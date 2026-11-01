import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_front_follower.dart';

void main() {
  test('the front shows only on a file with one, while it rains', () {
    expect(SceneFrontFollower.shouldShow(hasFront: true, rain: 0), isFalse);
    expect(SceneFrontFollower.shouldShow(hasFront: true, rain: 0.002), isTrue);
    expect(SceneFrontFollower.shouldShow(hasFront: true, rain: 1), isTrue);
    expect(SceneFrontFollower.shouldShow(hasFront: false, rain: 1), isFalse);
    expect(SceneFrontFollower.shouldShow(hasFront: true, rain: 0), isFalse);
  });

  test('attach writes the current rain and parallax to the fresh binding', () {
    final List<({String name, double value})> writes =
        <({String name, double value})>[];
    final SceneFrontFollower front = SceneFrontFollower();
    expect(front.attached, isFalse);
    front.attach(
      (String name, double value) => writes.add((name: name, value: value)),
      rain: 1,
      parallax: const Offset(0.5, -0.25),
    );
    expect(front.attached, isTrue);
    expect(writes, <({String name, double value})>[
      (name: AvatarRiveContract.scenePropRain, value: 1),
      (name: AvatarRiveContract.scenePropParallaxX, value: 0.5),
      (name: AvatarRiveContract.scenePropParallaxY, value: -0.25),
    ]);
    // later changes follow, unchanged values are not rewritten
    front.rain(1);
    front.rain(0.6);
    front.parallax(const Offset(0.5, 1));
    expect(writes.sublist(3), <({String name, double value})>[
      (name: AvatarRiveContract.scenePropRain, value: 0.6),
      (name: AvatarRiveContract.scenePropParallaxY, value: 1),
    ]);
    front.detach();
    expect(front.attached, isFalse);
    front.rain(0.2);
    expect(writes, hasLength(5));
  });

  test('a scene switch while raining attaches only files with a front', () {
    // campfire (front) -> livingRoom (none) -> beach (front), rain 1: each
    // load runs shouldShow, then attach on a fresh binding when it shows.
    final List<String> attachedFor = <String>[];
    final Map<String, List<double>> rainWrites = <String, List<double>>{};
    final SceneFrontFollower front = SceneFrontFollower();
    for (final String scene in <String>['campfire', 'livingRoom', 'beach']) {
      front.detach(); // the previous file's front goes with it
      final bool hasFront = AvatarRiveContract.sceneFrontScenes.contains(scene);
      if (SceneFrontFollower.shouldShow(hasFront: hasFront, rain: 1)) {
        attachedFor.add(scene);
        front.attach(
          (String name, double value) {
            if (name == AvatarRiveContract.scenePropRain) {
              (rainWrites[scene] ??= <double>[]).add(value);
            }
          },
          rain: 1,
          parallax: Offset.zero,
        );
      }
    }
    expect(attachedFor, <String>['campfire', 'beach']);
    expect(rainWrites, <String, List<double>>{
      'campfire': <double>[1],
      'beach': <double>[1],
    });
  });
}
