import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_drag_writer.dart';

void main() {
  late List<(String, double)> sink;
  late SceneDragWriter writer;

  setUp(() {
    sink = <(String, double)>[];
    writer = SceneDragWriter(
      (String name, double value) => sink.add((name, value)),
      defaults: <String, double>{'trailFade': 0},
    );
  });

  test('a 20 s fade at 60 Hz writes far fewer than one number per frame', () {
    const int frames = 20 * 60;
    for (int i = 1; i < frames; i++) {
      writer.write(<String, double>{'trailFade': i / frames}, animating: true);
    }
    writer.write(<String, double>{'trailFade': 1}, animating: false);

    expect(sink.length, lessThan(frames ~/ 2));
    expect(sink.length, greaterThan(100));
    // every skipped value was within epsilon of the one before the next write
    for (int i = 1; i < sink.length; i++) {
      expect(
        sink[i].$2 - sink[i - 1].$2,
        greaterThanOrEqualTo(SceneDragWriter.epsilon - 1e-9),
      );
    }
    expect(sink.last, ('trailFade', 1.0));
  });

  test('a value of exactly 1 is written even while animating', () {
    writer.write(<String, double>{'trailFade': 0.999}, animating: false);
    sink.clear();
    writer.write(<String, double>{'trailFade': 0.9995}, animating: true);
    expect(sink, isEmpty);
    writer.write(<String, double>{'trailFade': 1}, animating: true);
    expect(sink, <(String, double)>[('trailFade', 1.0)]);
  });

  test('a settled write is exact, and an unchanged value writes nothing', () {
    writer.write(<String, double>{'trailFade': 0.001}, animating: true);
    expect(sink, isEmpty);
    writer.write(<String, double>{'trailFade': 0.001}, animating: false);
    expect(sink, <(String, double)>[('trailFade', 0.001)]);
    writer.write(<String, double>{'trailFade': 0.001}, animating: false);
    expect(sink, hasLength(1));
  });
}
