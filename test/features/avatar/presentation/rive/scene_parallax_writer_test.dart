import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_parallax_writer.dart';

void main() {
  late List<String> calls;
  late Map<String, double> numbers;
  late SceneParallaxWriter writer;

  setUp(() {
    calls = <String>[];
    numbers = <String, double>{};
    writer = SceneParallaxWriter((String name, double value) {
      calls.add(name);
      numbers[name] = value;
    });
  });

  test('the first write sets both axes', () {
    writer.write(Offset.zero);
    expect(calls, <String>[
      AvatarRiveContract.scenePropParallaxX,
      AvatarRiveContract.scenePropParallaxY,
    ]);
  });

  test('moves under 0.001 are skipped, bigger ones write the axis alone', () {
    writer.write(Offset.zero);
    calls.clear();
    writer.write(const Offset(0.0008, -0.0009));
    expect(calls, isEmpty);
    writer.write(const Offset(0.5, 0));
    expect(calls, <String>[AvatarRiveContract.scenePropParallaxX]);
    expect(numbers[AvatarRiveContract.scenePropParallaxX], 0.5);
  });

  test('values are clamped to -1..1', () {
    writer.write(const Offset(4, -4));
    expect(numbers[AvatarRiveContract.scenePropParallaxX], 1);
    expect(numbers[AvatarRiveContract.scenePropParallaxY], -1);
  });

  test('force and reset write both axes again', () {
    writer.write(const Offset(0.2, 0.2));
    calls.clear();
    writer.write(const Offset(0.2, 0.2), force: true);
    expect(calls, hasLength(2));
    calls.clear();
    writer.reset();
    writer.write(const Offset(0.2, 0.2));
    expect(calls, hasLength(2));
  });
}
