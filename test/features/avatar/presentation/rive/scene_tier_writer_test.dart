import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_tier_writer.dart';

void main() {
  final List<String> writes = <String>[];
  void setEnum(String name, List<String> values, String value) {
    expect(name, AvatarRiveContract.scenePropTier);
    expect(values, AvatarRiveContract.tierValues);
    writes.add(value);
  }

  setUp(writes.clear);

  test('the contract v14 names', () {
    expect(AvatarRiveContract.scenePropTier, 'tier');
    expect(AvatarRiveContract.tierValues, <String>['low', 'high', 'ultra']);
    expect(AvatarRiveContract.tierDefault, 'ultra');
    expect(
      QualityTier.values.map((QualityTier t) => t.name).toList(),
      AvatarRiveContract.tierValues,
    );
  });

  test('the writer skips an unchanged tier unless forced', () {
    final SceneTierWriter writer = SceneTierWriter(setEnum);
    writer
      ..write(QualityTier.high)
      ..write(QualityTier.high)
      ..write(QualityTier.low)
      ..write(QualityTier.low, force: true);
    expect(writes, <String>['high', 'low', 'low']);
  });

  test('the follower writes on every load and on every change', () {
    final ValueNotifier<QualityTier> tier = ValueNotifier<QualityTier>(
      QualityTier.ultra,
    );
    final SceneTierFollower follower = SceneTierFollower()..follow(tier);
    expect(writes, isEmpty);
    follower.load(setEnum);
    expect(writes, <String>['ultra']);
    tier.value = QualityTier.low;
    expect(writes, <String>['ultra', 'low']);
    // A scene switch: the new file gets the tier in full.
    follower
      ..unload()
      ..load(setEnum);
    expect(writes, <String>['ultra', 'low', 'low']);
    follower.unload();
    tier.value = QualityTier.high;
    expect(writes.length, 3);
    follower.dispose();
  });

  test('without a source nothing is written (the file default)', () {
    final SceneTierFollower follower = SceneTierFollower()..load(setEnum);
    expect(writes, isEmpty);
    expect(follower.value, QualityTier.ultra);
  });
}
