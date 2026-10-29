import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
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

  test('a scene switch while raining writes the rain to every new file', () {
    final WorldStateService world = WorldStateService()..setRain(1);
    addTearDown(world.dispose);
    // The scene view builds a fresh writer for each loaded file and writes
    // the current rain into it with force.
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.campfire,
      AvatarScene.deepSpace,
      AvatarScene.beach,
    ]) {
      writes.clear();
      SceneRainWriter((String n, double v) {
        writes.add((name: n, value: v));
      }).write(world.rain.value, force: true);
      expect(writes, hasLength(1), reason: scene.name);
      expect(writes.single.name, AvatarRiveContract.scenePropRain);
      expect(writes.single.value, 1, reason: scene.name);
    }
  });
}
