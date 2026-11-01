import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/tokens/scene_lights.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/light_rig.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_face_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_light_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

class _RecordingSink implements AvatarVmSink {
  final Map<String, double> numbers = <String, double>{};
  final Map<String, int> colors = <String, int>{};
  final List<String> calls = <String>[];

  @override
  void setNumber(String name, double value) {
    numbers[name] = value;
    calls.add('number $name');
  }

  @override
  void setColor(String name, int argb) {
    colors[name] = argb;
    calls.add('color $name');
  }

  @override
  void setBool(String name, bool value) => calls.add('bool $name');

  @override
  void fireTrigger(String name) => calls.add('trigger $name');
}

void main() {
  late _RecordingSink sink;
  late AvatarLightWriter writer;

  setUp(() {
    sink = _RecordingSink();
    writer = AvatarLightWriter(sink);
  });

  test('a switch to campfire writes lightKeyX -0.49, once', () {
    writer.write(SceneLights.of(AvatarScene.livingRoom));
    sink.calls.clear();

    writer.write(SceneLights.of(AvatarScene.campfire));
    expect(sink.numbers[AvatarRiveContract.propLightKeyX], -0.49);
    expect(sink.numbers[AvatarRiveContract.propLightKeyY], -0.872);
    expect(sink.numbers[AvatarRiveContract.propLightFlicker], 1.0);
    expect(
      sink.calls.where((String c) => c == 'number lightKeyX'),
      hasLength(1),
    );

    // Frames and rebuilds that follow write nothing.
    sink.calls.clear();
    for (int i = 0; i < 120; i++) {
      writer.write(SceneLights.of(AvatarScene.campfire));
    }
    expect(sink.calls, isEmpty);
  });

  test('writes the three colours and six numbers of the v7 light rig', () {
    writer.write(SceneLights.of(AvatarScene.beach));
    expect(
      sink.numbers.keys.toSet(),
      AvatarRiveContract.lightNumberProps.toSet(),
    );
    expect(
      sink.colors.keys.toSet(),
      AvatarRiveContract.lightColorProps.toSet(),
    );
    final LightRig rig = SceneLights.of(AvatarScene.beach);
    expect(sink.colors[AvatarRiveContract.propLightKey], rig.keyColor);
    expect(sink.colors[AvatarRiveContract.propLightRim], rig.rimColor);
    expect(sink.colors[AvatarRiveContract.propLightAmbient], rig.ambientColor);
  });

  test('a reset (a fresh binding) writes the same rig again', () {
    writer.write(SceneLights.of(AvatarScene.deepSpace));
    sink.calls.clear();
    writer.reset();
    writer.write(SceneLights.of(AvatarScene.deepSpace));
    expect(sink.calls, hasLength(9));
  });
}
