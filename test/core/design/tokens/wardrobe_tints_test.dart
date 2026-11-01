import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/tokens/wardrobe_tints.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';

void main() {
  test('none draws nothing: fully transparent', () {
    expect(WardrobeTints.of(AvatarTint.none).toARGB32(), 0x00000000);
  });

  test('every other tint is a distinct paint at the same amount', () {
    final Set<int> seen = <int>{};
    for (final AvatarTint tint in AvatarTint.values) {
      if (tint == AvatarTint.none) {
        continue;
      }
      final Color c = WardrobeTints.of(tint);
      expect(c.a, closeTo(WardrobeTints.amount, 1e-9), reason: tint.name);
      expect(c.a, inInclusiveRange(0.85, 1.0), reason: tint.name);
      expect(seen.add(c.toARGB32()), isTrue, reason: '${tint.name} unique');
    }
    expect(seen, hasLength(AvatarTint.values.length - 1));
  });

  test(
    'hues are medium-saturation mid tones (color blend keeps lightness)',
    () {
      for (final AvatarTint tint in AvatarTint.values) {
        if (tint == AvatarTint.none || tint == AvatarTint.grey) {
          continue;
        }
        final HSLColor hsl = HSLColor.fromColor(WardrobeTints.of(tint));
        expect(hsl.saturation, inInclusiveRange(0.35, 0.8), reason: tint.name);
        expect(hsl.lightness, inInclusiveRange(0.35, 0.7), reason: tint.name);
      }
      // grey desaturates the garment
      expect(
        HSLColor.fromColor(WardrobeTints.of(AvatarTint.grey)).saturation,
        lessThan(0.1),
      );
    },
  );
}
