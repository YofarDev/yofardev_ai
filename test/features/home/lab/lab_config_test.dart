import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';

TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) =>
    ThemeData.dark().textTheme;

ThemeData _base() => buildLookTheme(
  UiLooks.storybook,
  AvatarScene.campfire,
  textThemeBuilder: _fakeTextTheme,
);

void main() {
  group('LabConfig JSON', () {
    test('round-trips every field', () {
      const LabConfig config = LabConfig(
        lookId: 'cel',
        scene: AvatarScene.deepSpace,
        layout: LabLayout.curtain,
        composer: LabComposerState.thinking,
        tab: LabTab.stage,
        accentHueOverride: 200,
        glassAlphaScale: 1.25,
        radiusScaleOverride: 0.75,
      );
      expect(LabConfig.fromJson(config.toJson()), config);
    });

    test('round-trips the defaults, null overrides included', () {
      expect(LabConfig.fromJson(LabConfig.initial.toJson()), LabConfig.initial);
      expect(LabConfig.initial.toJson()['accentHueOverride'], isNull);
    });

    test('missing keys fall back to the defaults', () {
      expect(
        LabConfig.fromJson(<String, Object?>{'lookId': 'cel'}),
        LabConfig.initial.copyWith(lookId: 'cel'),
      );
    });

    test('throws FormatException on an unknown look', () {
      expect(
        () => LabConfig.fromJson(<String, Object?>{'lookId': 'nope'}),
        throwsFormatException,
      );
    });

    test('throws FormatException on unknown keys, values and types', () {
      for (final Map<String, Object?> bad in <Map<String, Object?>>[
        <String, Object?>{'bogus': 1},
        <String, Object?>{'scene': 'mars'},
        <String, Object?>{'layout': 3},
        <String, Object?>{'accentHueOverride': 'red'},
        <String, Object?>{'accentHueOverride': 361},
        <String, Object?>{'glassAlphaScale': null},
        <String, Object?>{'radiusScaleOverride': -1},
      ]) {
        expect(() => LabConfig.fromJson(bad), throwsFormatException);
      }
    });

    test('copyWith can clear an override', () {
      final LabConfig set = LabConfig.initial.copyWith(
        accentHueOverride: 90,
        radiusScaleOverride: 1.5,
      );
      final LabConfig cleared = set.copyWith(
        accentHueOverride: null,
        radiusScaleOverride: null,
      );
      expect(cleared.accentHueOverride, isNull);
      expect(cleared.radiusScaleOverride, isNull);
      expect(set.copyWith(lookId: 'cel').accentHueOverride, 90);
    });
  });

  group('applyLabOverrides', () {
    test('returns the base theme when nothing is overridden', () {
      final ThemeData base = _base();
      expect(
        identical(applyLabOverrides(base, LabConfig.initial), base),
        isTrue,
      );
    });

    test('accent hue keeps saturation and value, scheme follows', () {
      final ThemeData base = _base();
      final HSVColor before = HSVColor.fromColor(
        base.extension<AppTokens>()!.scene.accent,
      );
      final ThemeData out = applyLabOverrides(
        base,
        LabConfig.initial.copyWith(accentHueOverride: 200),
      );
      final AppTokens tokens = out.extension<AppTokens>()!;
      final HSVColor after = HSVColor.fromColor(tokens.scene.accent);
      expect(after.hue, closeTo(200, 1));
      expect(after.saturation, closeTo(before.saturation, 0.01));
      expect(after.value, closeTo(before.value, 0.01));
      expect(out.colorScheme.primary, tokens.scene.accent);
      expect(out.colorScheme.onPrimary, tokens.scene.onAccent);
      expect(tokens.scene.glow.a, closeTo(0.35, 0.01));
      expect(
        contrastRatio(tokens.scene.onAccent, tokens.scene.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('glass alpha scale multiplies the fill alphas and clamps', () {
      final ThemeData base = _base();
      final AppTokens before = base.extension<AppTokens>()!;
      final AppTokens after = applyLabOverrides(
        base,
        LabConfig.initial.copyWith(glassAlphaScale: 2),
      ).extension<AppTokens>()!;
      expect(
        after.glassThin.fillAlpha,
        closeTo(before.glassThin.fillAlpha * 2, 1e-9),
      );
      expect(
        after.glassRegular.fillAlpha,
        closeTo(before.glassRegular.fillAlpha * 2, 1e-9),
      );
      expect(after.glassThick.fillAlpha, closeTo(0.44, 1e-9));
      expect(after.glassThick.blurSigma, before.glassThick.blurSigma);
      expect(after.glassThick.borderAlpha, before.glassThick.borderAlpha);

      final AppTokens clamped = applyLabOverrides(
        base,
        LabConfig.initial.copyWith(glassAlphaScale: 10),
      ).extension<AppTokens>()!;
      expect(clamped.glassThick.fillAlpha, 1);
    });

    test('radius override replaces the look radius scale', () {
      final ThemeData base = _base();
      expect(base.extension<AppTokens>()!.radiusScale, 1.15);
      final AppTokens after = applyLabOverrides(
        base,
        LabConfig.initial.copyWith(radiusScaleOverride: 0.5),
      ).extension<AppTokens>()!;
      expect(after.radiusScale, 0.5);
    });
  });
}
