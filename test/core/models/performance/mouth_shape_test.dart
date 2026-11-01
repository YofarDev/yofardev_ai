import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

void main() {
  group('MouthShape', () {
    test('forViseme covers every viseme', () {
      for (final Viseme v in Viseme.values) {
        final MouthShape s = MouthShape.forViseme(v);
        for (final double c in <double>[
          s.jaw,
          s.pucker,
          s.stretch,
          s.press,
          s.lipTuck,
          s.tongueUp,
        ]) {
          expect(c, inInclusiveRange(0.0, 1.0), reason: v.name);
        }
        expect(
          MouthShape.dominance(v),
          inInclusiveRange(0.0, 1.0),
          reason: v.name,
        );
      }
      expect(Viseme.values.length, 15);
    });

    test('sil is rest and pp seals the lips with a closed jaw', () {
      expect(MouthShape.forViseme(Viseme.sil), MouthShape.rest);
      final MouthShape pp = MouthShape.forViseme(Viseme.pp);
      expect(pp.jaw, 0);
      expect(pp.press, 0.6);
    });

    test('table spot checks', () {
      expect(
        MouthShape.forViseme(Viseme.aa),
        const MouthShape(jaw: 0.9, stretch: 0.15),
      );
      // M3 (critique 5): f/v tucks the lower lip under the upper teeth with
      // the lips a little wide; s keeps the teeth together, lip down
      expect(
        MouthShape.forViseme(Viseme.ff),
        const MouthShape(jaw: 0.1, stretch: 0.1, lipTuck: 1),
      );
      expect(
        MouthShape.forViseme(Viseme.ss),
        const MouthShape(jaw: 0.1, stretch: 0.55),
      );
      expect(MouthShape.forViseme(Viseme.th).tongueUp, 1);
      expect(
        MouthShape.forViseme(Viseme.dd),
        const MouthShape(jaw: 0.25, stretch: 0.2, tongueUp: 0.6),
      );
      // critic round 7: kk about half the aa jaw; ch rounded and spread
      expect(
        MouthShape.forViseme(Viseme.kk),
        const MouthShape(jaw: 0.35, stretch: 0.1),
      );
      expect(
        MouthShape.forViseme(Viseme.ch),
        const MouthShape(jaw: 0.15, pucker: 0.7, stretch: 0.38),
      );
      expect(
        MouthShape.forViseme(Viseme.rr),
        const MouthShape(jaw: 0.2, pucker: 0.7),
      );
      // ruling 16b: a rounded /u/ keeps a moderate jaw, fully rounded lips
      expect(
        MouthShape.forViseme(Viseme.ou),
        const MouthShape(jaw: 0.28, pucker: 1),
      );
    });

    test('f/v and s differ in the lower lip, not the jaw', () {
      final MouthShape ff = MouthShape.forViseme(Viseme.ff);
      final MouthShape ss = MouthShape.forViseme(Viseme.ss);
      expect(ff.lipTuck - ss.lipTuck, greaterThanOrEqualTo(0.9));
      expect(ff.press, 0);
      expect(ff.jaw, ss.jaw);
    });

    test('dominance table', () {
      expect(MouthShape.dominance(Viseme.pp), 1);
      expect(MouthShape.dominance(Viseme.sil), 0.2);
      expect(MouthShape.dominance(Viseme.ff), 0.9);
      expect(MouthShape.dominance(Viseme.aa), 0.4);
      expect(MouthShape.dominance(Viseme.ou), 0.6);
    });

    test('lerp at 0, 0.5 and 1', () {
      const MouthShape a = MouthShape(jaw: 0.2, press: 0.8);
      const MouthShape b = MouthShape(jaw: 0.6, tongueUp: 1);
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      final MouthShape mid = a.lerp(b, 0.5);
      expect(mid.jaw, closeTo(0.4, 1e-9));
      expect(mid.press, closeTo(0.4, 1e-9));
      expect(mid.tongueUp, closeTo(0.5, 1e-9));
    });
  });
}
