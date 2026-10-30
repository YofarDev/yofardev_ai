import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
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
        scene: AvatarScene.deepSpace,
        layout: LabLayout.curtain,
        composer: LabComposerState.thinking,
        tab: LabTab.stage,
        accentHueOverride: 200,
        glassAlphaScale: 1.25,
        radiusScaleOverride: 0.75,
        panelCollapsed: true,
      );
      expect(LabConfig.fromJson(config.toJson()), config);
      expect(config.toJson()['panelCollapsed'], isTrue);
    });

    test('the controls panel starts expanded', () {
      expect(LabConfig.initial.panelCollapsed, isFalse);
      expect(LabConfig.initial.toJson()['panelCollapsed'], isFalse);
      expect(
        LabConfig.initial.copyWith(panelCollapsed: true).panelCollapsed,
        isTrue,
      );
      expect(
        LabConfig.initial.copyWith(panelCollapsed: true),
        isNot(LabConfig.initial),
      );
    });

    test('round-trips the defaults, null overrides included', () {
      expect(LabConfig.fromJson(LabConfig.initial.toJson()), LabConfig.initial);
      expect(LabConfig.initial.toJson()['accentHueOverride'], isNull);
    });

    test('missing keys fall back to the defaults', () {
      expect(
        LabConfig.fromJson(<String, Object?>{'scene': 'beach'}),
        LabConfig.initial.copyWith(scene: AvatarScene.beach),
      );
    });

    test('the look is fixed: lookId is no longer a key', () {
      expect(LabConfig.initial.toJson().containsKey('lookId'), isFalse);
      expect(
        () => LabConfig.fromJson(<String, Object?>{'lookId': 'storybook'}),
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
        <String, Object?>{'panelCollapsed': 'yes'},
        <String, Object?>{'panelCollapsed': null},
      ]) {
        expect(() => LabConfig.fromJson(bad), throwsFormatException);
      }
    });

    test('prop and parallax round-trip, default to none and null', () {
      expect(LabConfig.initial.prop, AvatarProp.none);
      expect(LabConfig.initial.parallax, isNull);
      expect(LabConfig.initial.toJson()['prop'], 'none');
      expect(LabConfig.initial.toJson()['parallax'], isNull);
      final LabConfig config = LabConfig.initial.copyWith(
        prop: AvatarProp.tablet,
        parallax: const Offset(-0.5, 1),
      );
      expect(LabConfig.fromJson(config.toJson()), config);
      expect(config.copyWith(scene: AvatarScene.beach).prop, AvatarProp.tablet);
      expect(config.copyWith(parallax: null).parallax, isNull);
      expect(config, isNot(LabConfig.initial));
    });

    test('shot round-trips and defaults to wide', () {
      expect(LabConfig.initial.shot, Shot.wide);
      expect(LabConfig.initial.toJson()['shot'], 'wide');
      final LabConfig config = LabConfig.initial.copyWith(shot: Shot.closeUp);
      expect(LabConfig.fromJson(config.toJson()), config);
      expect(config.copyWith(scene: AvatarScene.beach).shot, Shot.closeUp);
      expect(config, isNot(LabConfig.initial));
      for (final Object? bad in <Object?>['dolly', 1, null]) {
        expect(
          () => LabConfig.fromJson(<String, Object?>{'shot': bad}),
          throwsFormatException,
        );
      }
    });

    test('rejects an unknown prop and a bad parallax', () {
      for (final Map<String, Object?> bad in <Map<String, Object?>>[
        <String, Object?>{'prop': 'telescope'},
        <String, Object?>{'prop': 1},
        <String, Object?>{'prop': null},
        <String, Object?>{'parallax': 3},
        <String, Object?>{
          'parallax': <String, Object?>{'x': 1.01},
        },
        <String, Object?>{
          'parallax': <String, Object?>{'y': 'up'},
        },
        <String, Object?>{
          'parallax': <String, Object?>{'z': 0},
        },
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
      expect(set.copyWith(scene: AvatarScene.beach).accentHueOverride, 90);
    });
  });

  group('LabConfig face', () {
    test('round-trips a face object by contract names', () {
      final LabConfig config = LabConfig.fromJson(<String, Object?>{
        'face': <String, Object?>{
          'auJawDrop': 0.5,
          'auBrowOuterUpR': 0.3,
          'auLipCornerPullL': -0.25,
          'roll': 0.2,
          'lipTuck': 1,
          'blink': 2,
        },
      });
      final FaceFrame face = config.face!;
      expect(face.au.jawDrop, 0.5);
      expect(face.right.browOuterUp, 0.3);
      expect(face.left.lipCornerPull, -0.25);
      expect(face.roll, 0.2);
      expect(face.lipTuck, 1);
      expect(face.blinkSerial, 2);
      expect(face.autoBlink, isFalse);
      expect(face.au.browLower, 0);

      final Map<String, Object?> json = config.toJson();
      final Map<String, Object> faceJson = json['face']! as Map<String, Object>;
      expect(faceJson.keys, <String>{...LabFace.numberKeys, 'blink'});
      expect(faceJson['auBrowOuterUpR'], 0.3);
      expect(LabConfig.fromJson(json), config);
    });

    test('no face is the live face and round-trips as null', () {
      expect(LabConfig.initial.face, isNull);
      expect(LabConfig.initial.toJson()['face'], isNull);
      expect(LabConfig.fromJson(<String, Object?>{'face': null}).face, isNull);
    });

    test('rejects unknown names, wrong types and out-of-range values', () {
      for (final Object? bad in <Object?>[
        <String, Object?>{'auJawDrop': 2},
        <String, Object?>{'nope': 0},
        <String, Object?>{'auJawDrop': -0.1},
        <String, Object?>{'auBrowOuterUpR': -1.5},
        <String, Object?>{'roll': 1.01},
        <String, Object?>{'auJawDrop': '0.5'},
        <String, Object?>{'auJawDrop': null},
        <String, Object?>{'blink': -1},
        <String, Object?>{'blink': 1.5},
        <String, Object?>{'autoBlink': false},
        <Object?>[0.5],
        'auJawDrop',
      ]) {
        expect(
          () => LabConfig.fromJson(<String, Object?>{'face': bad}),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('side offsets and roll take -1..1, the rest 0..1', () {
      expect(LabFace.range('auBrowLowerL'), (-1.0, 1.0));
      expect(LabFace.range('roll'), (-1.0, 1.0));
      expect(LabFace.range('auBrowLower'), (0.0, 1.0));
      expect(LabFace.range('breath'), (0.0, 1.0));
      expect(LabFace.numberKeys, hasLength(32));
    });

    test('copyWith sets and clears the face', () {
      final LabConfig set = LabConfig.initial.copyWith(face: LabFace.base);
      expect(set.face, LabFace.base);
      expect(set, isNot(LabConfig.initial));
      expect(set.copyWith(scene: AvatarScene.beach).face, LabFace.base);
      expect(set.copyWith(face: null).face, isNull);
    });

    test('a mood preset loads its AUs and side offsets', () {
      final FaceFrame thinking = LabFace.withMood(
        LabFace.withValue(LabFace.base, 'roll', 0.3),
        AvatarMood.thinking,
      );
      expect(thinking.au, actionUnitsForMood(AvatarMood.thinking));
      expect(thinking.right.browOuterUp, 0.35);
      expect(thinking.left.browLower, 0.25);
      expect(thinking.roll, 0.3);
      expect(LabFace.hasMood(thinking, AvatarMood.thinking), isTrue);
      expect(LabFace.hasMood(thinking, AvatarMood.neutral), isFalse);
    });

    test('a viseme writes its mouth shape and keeps the rest', () {
      final FaceFrame happy = LabFace.withMood(LabFace.base, AvatarMood.happy);
      final FaceFrame ff = LabFace.withViseme(happy, Viseme.ff);
      expect(ff.au.jawDrop, 0.1);
      expect(ff.au.lipStretch, 0.1);
      expect(ff.lipTuck, 1);
      expect(ff.tongueUp, 0);
      expect(ff.au.cheekRaise, happy.au.cheekRaise);
      expect(LabFace.hasViseme(ff, Viseme.ff), isTrue);
      final FaceFrame th = LabFace.withViseme(ff, Viseme.th);
      expect(th.lipTuck, 0);
      expect(th.tongueUp, 1);
    });

    test('blink bumps the serial and keeps the pose', () {
      final FaceFrame face = LabFace.withValue(LabFace.base, 'auJawDrop', 0.4);
      final FaceFrame blinked = LabFace.withBlink(face);
      expect(blinked.blinkSerial, face.blinkSerial + 1);
      expect(blinked.au, face.au);
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
