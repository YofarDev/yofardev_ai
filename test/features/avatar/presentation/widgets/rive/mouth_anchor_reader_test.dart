import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/mouth_anchor_reader.dart';

void main() {
  test('the contract v13 node name', () {
    expect(MouthAnchorReader.node, 'MouthAnchor');
  });

  test('reads the world translation in artboard px', () {
    final Mat2D world = Mat2D.fromTranslate(400, 480);
    expect(
      MouthAnchorReader.translationOf(world, AABB.fromValues(0, 0, 800, 1000)),
      const Offset(400, 480),
    );
  });

  test('ignores the rotation and scale, keeps the translation', () {
    final Mat2D world = Mat2D()
      ..[0] = 0.8
      ..[1] = 0.3
      ..[2] = -0.3
      ..[3] = 0.8
      ..[4] = 412
      ..[5] = 470;
    expect(
      MouthAnchorReader.translationOf(world, AABB.fromValues(0, 0, 800, 1000)),
      const Offset(412, 470),
    );
  });

  test('is relative to the artboard bounds (an artboard with an origin)', () {
    final Mat2D world = Mat2D.fromTranslate(0, 80);
    expect(
      MouthAnchorReader.translationOf(
        world,
        AABB.fromValues(-400, -400, 400, 600),
      ),
      const Offset(400, 480),
    );
  });
}
