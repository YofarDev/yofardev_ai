import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/tokens/wardrobe_tints.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_face_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_tint_writer.dart';

class _RecordingSink implements AvatarVmSink {
  final List<(String, int)> colors = <(String, int)>[];

  @override
  void setColor(String name, int argb) => colors.add((name, argb));

  @override
  void setNumber(String name, double value) => fail('number $name');

  @override
  void setBool(String name, bool value) => fail('bool $name');

  @override
  void fireTrigger(String name) => fail('trigger $name');
}

void main() {
  late _RecordingSink sink;
  late AvatarTintWriter writer;
  const String top = AvatarRiveContract.propTopTint;
  const String hat = AvatarRiveContract.propHatTint;
  final int none = WardrobeTints.none.toARGB32();

  setUp(() {
    sink = _RecordingSink();
    writer = AvatarTintWriter(sink);
  });

  test('an untinted avatar writes transparent: identical to v12', () {
    writer.write(const Avatar());
    expect(sink.colors, <(String, int)>[(top, 0), (hat, 0)]);
  });

  test('the tints are the WardrobeTints colours', () {
    writer.write(
      const Avatar(topTint: AvatarTint.teal, hatTint: AvatarTint.red),
    );
    expect(sink.colors, <(String, int)>[
      (top, WardrobeTints.teal.toARGB32()),
      (hat, WardrobeTints.red.toARGB32()),
    ]);
  });

  test('under a costume both are transparent, tints kept in the data', () {
    for (final AvatarCostume costume in AvatarCostume.values.skip(1)) {
      final ({int top, int hat}) c = AvatarTintWriter.colorsFor(
        Avatar(
          costume: costume,
          topTint: AvatarTint.blue,
          hatTint: AvatarTint.pink,
        ),
      );
      expect(c.top, none, reason: costume.name);
      expect(c.hat, none, reason: costume.name);
    }
  });

  test('only changes are written; reset writes again', () {
    const Avatar tinted = Avatar(topTint: AvatarTint.green);
    writer.write(tinted);
    sink.colors.clear();
    writer.write(tinted);
    expect(sink.colors, isEmpty);

    writer.write(tinted.copyWith(costume: AvatarCostume.batman));
    expect(sink.colors, <(String, int)>[(top, none)]);
    sink.colors.clear();

    writer.write(tinted.copyWith(hatTint: AvatarTint.yellow));
    expect(sink.colors, <(String, int)>[
      (top, WardrobeTints.green.toARGB32()),
      (hat, WardrobeTints.yellow.toARGB32()),
    ]);
    sink.colors.clear();

    writer.reset();
    writer.write(tinted.copyWith(hatTint: AvatarTint.yellow));
    expect(sink.colors, hasLength(2));
  });

  test('the low tier writes the tints transparent; high keeps them', () {
    const Avatar tinted = Avatar(
      topTint: AvatarTint.teal,
      hatTint: AvatarTint.red,
    );
    writer.write(tinted, tier: QualityTier.low);
    expect(sink.colors, <(String, int)>[(top, none), (hat, none)]);
    sink.colors.clear();
    writer.write(tinted, tier: QualityTier.high);
    expect(sink.colors, <(String, int)>[
      (top, WardrobeTints.teal.toARGB32()),
      (hat, WardrobeTints.red.toARGB32()),
    ]);
  });
}
