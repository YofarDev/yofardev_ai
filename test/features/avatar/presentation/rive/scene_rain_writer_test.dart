import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_rain_writer.dart';

void main() {
  late List<({String name, double value})> writes;
  late SceneRainWriter writer;

  setUp(() {
    writes = <({String name, double value})>[];
    writer = SceneRainWriter((String name, double value) {
      writes.add((name: name, value: value));
    });
  });

  test('the first write sets SceneVM.rain', () {
    writer.write(0);
    expect(writes, hasLength(1));
    expect(writes.single.name, AvatarRiveContract.scenePropRain);
    expect(writes.single.value, 0);
  });

  test('writes once per change, never for an unchanged value', () {
    writer.write(0);
    writer.write(0);
    writer.write(0.0005);
    expect(writes, hasLength(1));
    writer.write(0.5);
    writer.write(0.5);
    expect(writes, hasLength(2));
    expect(writes.last.value, 0.5);
    writer.write(1);
    expect(writes, hasLength(3));
  });

  test('values are clamped to 0..1', () {
    writer.write(4);
    expect(writes.last.value, 1);
    writer.write(-4);
    expect(writes.last.value, 0);
  });

  test('force and reset write the same value again', () {
    writer.write(0.3);
    writer.write(0.3, force: true);
    expect(writes, hasLength(2));
    writer.reset();
    writer.write(0.3);
    expect(writes, hasLength(3));
  });

  group('SceneRainFollower (the scene view\'s rain logic)', () {
    late SceneRainFollower follower;

    void Function(String, double) sink(List<double> into) {
      return (String name, double value) {
        expect(name, AvatarRiveContract.scenePropRain);
        into.add(value);
      };
    }

    setUp(() => follower = SceneRainFollower());
    tearDown(() => follower.dispose());

    test('a scene switch at rain 1 writes 1 to each new file', () {
      final WorldStateService world = WorldStateService()..setRain(1);
      addTearDown(world.dispose);
      follower.follow(world.rain);
      for (int i = 0; i < 3; i++) {
        final List<double> file = <double>[];
        follower.load(sink(file));
        expect(file, <double>[1], reason: 'file $i');
        follower.unload();
      }
    });

    test('a loaded file follows the source, writing changes only', () {
      final ValueNotifier<double> rain = ValueNotifier<double>(0);
      addTearDown(rain.dispose);
      final List<double> file = <double>[];
      follower.follow(rain);
      follower.load(sink(file));
      rain.value = 0.5;
      rain.value = 0.5;
      rain.value = 0.9;
      expect(file, <double>[0, 0.5, 0.9]);
    });

    test('nothing is written before a file is loaded or after unload', () {
      final ValueNotifier<double> rain = ValueNotifier<double>(0);
      addTearDown(rain.dispose);
      final List<double> file = <double>[];
      follower.follow(rain);
      rain.value = 1;
      follower.load(sink(file));
      expect(file, <double>[1]);
      follower.unload();
      rain.value = 0.2;
      expect(file, <double>[1]);
    });

    test('a new source replaces the old listener and is written at once', () {
      final ValueNotifier<double> first = ValueNotifier<double>(0.2);
      final ValueNotifier<double> second = ValueNotifier<double>(0.8);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final List<double> file = <double>[];
      follower.follow(first);
      follower.load(sink(file));
      follower.follow(second);
      expect(file, <double>[0.2, 0.8]);
      first.value = 0.4; // no longer followed
      second.value = 0.6;
      expect(file, <double>[0.2, 0.8, 0.6]);
    });

    test('a null source dries the scene; dispose stops listening', () {
      final ValueNotifier<double> rain = ValueNotifier<double>(0.7);
      addTearDown(rain.dispose);
      final List<double> file = <double>[];
      follower.follow(rain);
      follower.load(sink(file));
      follower.follow(null);
      expect(file, <double>[0.7, 0]);
      follower.follow(rain);
      follower.dispose();
      rain.value = 0.1;
      expect(file, <double>[0.7, 0, 0.7]);
    });
  });
}
