import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('Viseme', () {
    test('has the 15 Oculus/MPEG-4 style values in order', () {
      expect(Viseme.values.map((Viseme v) => v.name), <String>[
        'sil',
        'pp',
        'ff',
        'th',
        'dd',
        'kk',
        'ch',
        'ss',
        'nn',
        'rr',
        'aa',
        'e',
        'ih',
        'oh',
        'ou',
      ]);
    });

    test('closed visemes map to openness 0', () {
      expect(Viseme.pp.mouthOpenness, 0);
      expect(Viseme.sil.mouthOpenness, 0);
      expect(Viseme.ff.mouthOpenness, 0);
    });

    test('aa maps to openness 4', () {
      expect(Viseme.aa.mouthOpenness, 4);
    });

    test('mouthOpenness is within 0-4 for every viseme', () {
      for (final Viseme v in Viseme.values) {
        expect(v.mouthOpenness, inInclusiveRange(0, 4));
      }
    });
  });

  group('GazeTarget', () {
    test('has the four union cases', () {
      const GazeTarget user = GazeTarget.user();
      final GazeAway away = GazeTarget.away(0.4) as GazeAway;
      final GazePoint point = GazeTarget.point(0.2, 0.8) as GazePoint;
      const GazeTarget caret = GazeTarget.caret(0.5);

      expect(user, isA<GazeUser>());
      expect(away, isA<GazeAway>());
      expect(away.angle, 0.4);
      expect(point, isA<GazePoint>());
      expect(point.x, 0.2);
      expect(point.y, 0.8);
      expect(caret, isA<GazeCaret>());
    });
  });

  group('Shot', () {
    test('has the four shot values', () {
      expect(Shot.values, <Shot>[
        Shot.wide,
        Shot.medium,
        Shot.closeUp,
        Shot.propInsert,
      ]);
    });
  });

  group('LightRig', () {
    test('neutral is a const value with sensible defaults', () {
      const LightRig rig = LightRig.neutral;
      expect(LightRig.neutral, same(LightRig.neutral));
      expect(rig.keyIntensity, 1);
      expect(rig.rimIntensity, 0.35);
      expect(rig.ambientAmount, 0.35);
      expect(rig.flicker, 0);
    });

    test('holds the documented fields', () {
      const LightRig rig = LightRig(
        keyColor: 0xFFFFFFFF,
        keyIntensity: 0.9,
        keyX: -0.49,
        keyY: -0.872,
        rimColor: 0xFFB79CFF,
        rimIntensity: 0.4,
        ambientColor: 0xFF202028,
        ambientAmount: 0.3,
        fogColor: 0x3320304A,
        flicker: 0.2,
      );
      expect(rig.keyX, -0.49);
      expect(rig.keyY, -0.872);
      expect(rig.keyColor, 0xFFFFFFFF);
      expect(rig.rimColor, 0xFFB79CFF);
      expect(rig.ambientColor, 0xFF202028);
      expect(rig.fogColor, 0x3320304A);
      expect(rig.flicker, 0.2);
    });
  });

  group('QualityTier', () {
    test('has the three tiers', () {
      expect(QualityTier.values, <QualityTier>[
        QualityTier.low,
        QualityTier.high,
        QualityTier.ultra,
      ]);
    });

    test('allowsFeather on high and ultra only', () {
      expect(QualityTier.low.allowsFeather, isFalse);
      expect(QualityTier.high.allowsFeather, isTrue);
      expect(QualityTier.ultra.allowsFeather, isTrue);
    });

    test('allowsShaders on ultra only', () {
      expect(QualityTier.low.allowsShaders, isFalse);
      expect(QualityTier.high.allowsShaders, isFalse);
      expect(QualityTier.ultra.allowsShaders, isTrue);
    });

    test('particle budgets are 0 / 40 / 120', () {
      expect(QualityTier.low.particleBudget, 0);
      expect(QualityTier.high.particleBudget, 40);
      expect(QualityTier.ultra.particleBudget, 120);
    });
  });
}
