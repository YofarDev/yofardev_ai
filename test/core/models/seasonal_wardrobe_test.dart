import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/seasonal_wardrobe.dart';

void main() {
  const Avatar defaults = Avatar();

  test('the default outfit is shown as santa in December', () {
    for (final DateTime day in <DateTime>[
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 24, 20),
      DateTime(2026, 12, 31, 23, 59, 59),
    ]) {
      final Avatar shown = shownWardrobe(defaults, day);
      expect(shown.hat, AvatarHat.santaHat, reason: '$day');
      expect(shown.top, AvatarTop.christmasSweater, reason: '$day');
      // everything else is the stored value
      expect(shown.background, defaults.background);
      expect(shown.glasses, defaults.glasses);
      expect(shown.costume, AvatarCostume.none);
    }
  });

  test('it is not shown the day before or after December', () {
    expect(shownWardrobe(defaults, DateTime(2026, 11, 30, 23, 59)), defaults);
    expect(shownWardrobe(defaults, DateTime(2027, 1, 1)), defaults);
    expect(shownWardrobe(defaults, DateTime(2027, 1, 5)), defaults);
    expect(shownWardrobe(defaults, DateTime(2026, 7, 14)), defaults);
  });

  test('a stored hat, top or costume wins', () {
    final DateTime december = DateTime(2026, 12, 10);
    for (final Avatar chosen in <Avatar>[
      defaults.copyWith(hat: AvatarHat.beanie),
      defaults.copyWith(top: AvatarTop.tshirt),
      defaults.copyWith(costume: AvatarCostume.batman),
      defaults.copyWith(top: AvatarTop.christmasSweater),
      defaults.copyWith(hat: AvatarHat.santaHat),
    ]) {
      expect(shownWardrobe(chosen, december), chosen);
    }
  });

  test('glasses and the scene do not count as an outfit', () {
    final Avatar sunny = defaults.copyWith(glasses: AvatarGlasses.sunglasses);
    final Avatar shown = shownWardrobe(sunny, DateTime(2026, 12, 3));
    expect(shown.hat, AvatarHat.santaHat);
    expect(shown.glasses, AvatarGlasses.sunglasses);
  });

  test('it never changes the stored avatar', () {
    shownWardrobe(defaults, DateTime(2026, 12, 3));
    expect(defaults.hat, AvatarHat.noHat);
    expect(defaults.top, AvatarTop.pinkHoodie);
  });

  test('the prompt note exists in December only', () {
    expect(
      decemberWardrobePromptNote(DateTime(2026, 12, 1)),
      contains('santaHat'),
    );
    expect(
      decemberWardrobePromptNote(DateTime(2026, 12, 31)),
      contains('christmasSweater'),
    );
    expect(decemberWardrobePromptNote(DateTime(2027, 1, 1)), isEmpty);
    expect(decemberWardrobePromptNote(DateTime(2026, 11, 30)), isEmpty);
  });

  test('a tinted default outfit is no longer the default (M10)', () {
    final DateTime december = DateTime(2026, 12, 10);
    for (final Avatar tinted in <Avatar>[
      defaults.copyWith(topTint: AvatarTint.teal),
      defaults.copyWith(hatTint: AvatarTint.red),
      defaults.copyWith(topTint: AvatarTint.grey, hatTint: AvatarTint.pink),
    ]) {
      expect(shownWardrobe(tinted, december), tinted);
    }
    // both tints none: still the December outfit
    final Avatar untinted = defaults.copyWith(
      topTint: AvatarTint.none,
      hatTint: AvatarTint.none,
    );
    expect(shownWardrobe(untinted, december).hat, AvatarHat.santaHat);
    expect(shownWardrobe(untinted, december).topTint, AvatarTint.none);
  });

  test('the December prompt note says a tint replaces it', () {
    expect(decemberWardrobePromptNote(DateTime(2026, 12, 1)), contains('tint'));
  });
}
