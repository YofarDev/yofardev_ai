import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_bubble_layout.dart';

/// A landscape stage (1280 x 800), chrome reserved top and bottom.
const Size _wide = Size(1280, 800);
const Rect _wideSafe = Rect.fromLTRB(16, 80, 1264, 660);

/// A portrait phone stage (390 x 844).
const Size _phone = Size(390, 844);
const Rect _phoneSafe = Rect.fromLTRB(16, 100, 374, 700);

void main() {
  group('keepOut', () {
    test('is the head width and brows to chin, scaled, around the mouth', () {
      final Rect k = StageBubbleLayout.keepOut(const Offset(500, 400), 0.5);
      expect(k.left, 500 - 150 * 0.5);
      expect(k.right, 500 + 150 * 0.5);
      expect(k.top, 400 - 190 * 0.5);
      expect(k.bottom, 400 + 70 * 0.5);
    });
  });

  group('keepOut margin and covers', () {
    test('a margin (artboard px) grows the box on every side', () {
      final Rect k = StageBubbleLayout.keepOut(
        const Offset(500, 400),
        0.5,
        margin: 48,
      );
      expect(k.left, 500 - (150 + 48) * 0.5);
      expect(k.right, 500 + (150 + 48) * 0.5);
      expect(k.top, 400 - (190 + 48) * 0.5);
      expect(k.bottom, 400 + (70 + 48) * 0.5);
    });

    test('covers: a gap of tolerance inside the face box', () {
      const Rect face = Rect.fromLTRB(100, 100, 300, 300);
      // touching the face box, or reaching into it by less than the gap
      expect(
        StageBubbleLayout.covers(const Rect.fromLTRB(0, 100, 100, 200), face),
        isFalse,
      );
      expect(
        StageBubbleLayout.covers(
          const Rect.fromLTRB(0, 100, 100 + StageBubbleLayout.gap - 1, 200),
          face,
        ),
        isFalse,
      );
      expect(
        StageBubbleLayout.covers(
          const Rect.fromLTRB(0, 100, 100 + StageBubbleLayout.gap + 1, 200),
          face,
        ),
        isTrue,
      );
    });

    test('plan with a margin leaves less room beside the face', () {
      final BubblePlan bare = StageBubbleLayout.plan(
        stage: _wide,
        safe: _wideSafe,
        anchor: const Offset(900, 384),
        scale: 0.8,
      );
      final BubblePlan held = StageBubbleLayout.plan(
        stage: _wide,
        safe: _wideSafe,
        anchor: const Offset(900, 384),
        scale: 0.8,
        margin: 48,
      );
      expect(held.maxWidth, closeTo(bare.maxWidth - 48 * 0.8, 1e-9));
    });
  });

  group('plan', () {
    test('landscape, mouth centred: beside the face', () {
      final BubblePlan plan = StageBubbleLayout.plan(
        stage: _wide,
        safe: _wideSafe,
        anchor: const Offset(640, 384),
        scale: 0.8,
      );
      expect(plan.side, isNot(BubbleSide.above));
      // the room beside the face, under 72 % of the stage
      final Rect k = StageBubbleLayout.keepOut(const Offset(640, 384), 0.8);
      expect(
        plan.maxWidth,
        closeTo(k.left - StageBubbleLayout.gap - _wideSafe.left, 1e-9),
      );
      expect(plan.maxWidth, lessThan(0.72 * 1280));
    });

    test('takes the side with more room', () {
      final BubblePlan right = StageBubbleLayout.plan(
        stage: _wide,
        safe: _wideSafe,
        anchor: const Offset(400, 384),
        scale: 0.8,
      );
      expect(right.side, BubbleSide.right);
      final BubblePlan left = StageBubbleLayout.plan(
        stage: _wide,
        safe: _wideSafe,
        anchor: const Offset(900, 384),
        scale: 0.8,
      );
      expect(left.side, BubbleSide.left);
      // limited by the room beside the face
      final Rect k = StageBubbleLayout.keepOut(const Offset(900, 384), 0.8);
      expect(
        left.maxWidth,
        closeTo(k.left - StageBubbleLayout.gap - _wideSafe.left, 1e-9),
      );
    });

    test('portrait: no room beside the face, above it', () {
      final BubblePlan plan = StageBubbleLayout.plan(
        stage: _phone,
        safe: _phoneSafe,
        anchor: const Offset(195, 540),
        scale: 390 / 800,
      );
      expect(plan.side, BubbleSide.above);
      expect(plan.maxWidth, closeTo(0.72 * 390, 1e-9));
    });

    test('never wider than 72 % of the stage', () {
      for (final double x in <double>[100, 640, 1180]) {
        final BubblePlan plan = StageBubbleLayout.plan(
          stage: _wide,
          safe: _wideSafe,
          anchor: Offset(x, 384),
          scale: 0.8,
        );
        expect(plan.maxWidth, lessThanOrEqualTo(0.72 * 1280));
      }
    });
  });

  group('place', () {
    const Size bubble = Size(300, 120);

    void expectClear(Rect rect, Rect safe, Rect keepOut) {
      expect(rect.left, greaterThanOrEqualTo(safe.left - 1e-9));
      expect(rect.right, lessThanOrEqualTo(safe.right + 1e-9));
      expect(rect.top, greaterThanOrEqualTo(safe.top - 1e-9));
      expect(rect.bottom, lessThanOrEqualTo(safe.bottom + 1e-9));
      expect(rect.overlaps(keepOut), isFalse, reason: 'over the face');
    }

    test('left: right of the bubble a gap off the face, tail at the mouth', () {
      const Offset a = Offset(900, 384);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      final BubblePlacement p = StageBubbleLayout.place(
        side: BubbleSide.left,
        size: bubble,
        anchor: a,
        keepOut: k,
        safe: _wideSafe,
      )!;
      expect(p.rect.right, closeTo(k.left - StageBubbleLayout.gap, 1e-9));
      expect(p.rect.bottom, closeTo(a.dy, 1e-9));
      expect(p.tailAt, greaterThan(0.5), reason: 'the tail on the face side');
      expectClear(p.rect, _wideSafe, k);
    });

    test('right: mirrored, tail on the face side', () {
      const Offset a = Offset(400, 384);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      final BubblePlacement p = StageBubbleLayout.place(
        side: BubbleSide.right,
        size: bubble,
        anchor: a,
        keepOut: k,
        safe: _wideSafe,
      )!;
      expect(p.rect.left, closeTo(k.right + StageBubbleLayout.gap, 1e-9));
      expect(p.tailAt, lessThan(0.5));
      expectClear(p.rect, _wideSafe, k);
    });

    test('a mouth high on the stage: clamped below the top chips', () {
      const Offset a = Offset(900, 120);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      final BubblePlacement p = StageBubbleLayout.place(
        side: BubbleSide.left,
        size: bubble,
        anchor: a,
        keepOut: k,
        safe: _wideSafe,
      )!;
      expect(p.rect.top, closeTo(_wideSafe.top, 1e-9));
      expectClear(p.rect, _wideSafe, k);
    });

    test('a mouth low on the stage: clamped above the composer', () {
      const Offset a = Offset(900, 760);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      final BubblePlacement p = StageBubbleLayout.place(
        side: BubbleSide.left,
        size: bubble,
        anchor: a,
        keepOut: k,
        safe: _wideSafe,
      )!;
      expect(p.rect.bottom, closeTo(_wideSafe.bottom, 1e-9));
      expectClear(p.rect, _wideSafe, k);
    });

    test('above: over the head, inside the safe area, leaning to the room', () {
      const Offset a = Offset(195, 540);
      const double scale = 390 / 800;
      final Rect k = StageBubbleLayout.keepOut(a, scale);
      final BubblePlacement p = StageBubbleLayout.place(
        side: BubbleSide.above,
        size: const Size(260, 110),
        anchor: a,
        keepOut: k,
        safe: _phoneSafe,
      )!;
      expect(p.rect.bottom, closeTo(k.top - StageBubbleLayout.gap, 1e-9));
      expectClear(p.rect, _phoneSafe, k);
      // the tail comes down beside the mouth, inside the bubble's width
      final double tailX = p.rect.left + p.rect.width * p.tailAt;
      expect(tailX, inInclusiveRange(k.left, k.right));
    });

    test('does not fit: too tall for the room above the head', () {
      const Offset a = Offset(195, 300);
      final Rect k = StageBubbleLayout.keepOut(a, 390 / 800);
      expect(
        StageBubbleLayout.place(
          side: BubbleSide.above,
          size: const Size(260, 200),
          anchor: a,
          keepOut: k,
          safe: _phoneSafe,
        ),
        isNull,
      );
    });

    test('does not fit: wider than the room beside the face', () {
      const Offset a = Offset(300, 384);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      expect(
        StageBubbleLayout.place(
          side: BubbleSide.left,
          size: bubble,
          anchor: a,
          keepOut: k,
          safe: _wideSafe,
        ),
        isNull,
      );
    });

    test('does not fit: taller than the safe area', () {
      const Offset a = Offset(900, 384);
      final Rect k = StageBubbleLayout.keepOut(a, 0.8);
      expect(
        StageBubbleLayout.place(
          side: BubbleSide.left,
          size: const Size(300, 700),
          anchor: a,
          keepOut: k,
          safe: _wideSafe,
        ),
        isNull,
      );
    });
  });

  group('follow', () {
    test('converges on the target without overshoot (critically damped)', () {
      final BubbleFollow f = BubbleFollow(const Offset(0, 0));
      f.target(const Offset(100, 0));
      double last = 0;
      for (int i = 0; i < 60; i++) {
        f.step(const Duration(milliseconds: 16));
        expect(f.position.dx, lessThanOrEqualTo(100 + 1e-9));
        expect(f.position.dx, greaterThanOrEqualTo(last - 1e-9));
        last = f.position.dx;
      }
      expect(f.position.dx, closeTo(100, 0.01));
      expect(f.isSettled, isTrue);
    });

    test('about 8 Hz: most of the way there in ~60 ms', () {
      final BubbleFollow f = BubbleFollow(Offset.zero);
      f.target(const Offset(100, 0));
      f.step(const Duration(milliseconds: 60));
      expect(f.position.dx, greaterThan(70));
      expect(f.position.dx, lessThan(95));
    });

    test('ignores target moves below 1 dp (no jitter)', () {
      final BubbleFollow f = BubbleFollow(const Offset(50, 50));
      expect(f.target(const Offset(50.6, 49.5)), isFalse);
      f.step(const Duration(milliseconds: 16));
      expect(f.position, const Offset(50, 50));
      expect(f.isSettled, isTrue);
      expect(f.target(const Offset(51.2, 50)), isTrue);
    });

    test('a long frame is stable (no blow-up)', () {
      final BubbleFollow f = BubbleFollow(Offset.zero);
      f.target(const Offset(100, 100));
      f.step(const Duration(seconds: 2));
      expect(f.position.dx, closeTo(100, 1e-3));
      expect(f.position.dy, closeTo(100, 1e-3));
    });

    test('aim is the accepted target', () {
      final BubbleFollow f = BubbleFollow(Offset.zero);
      f.target(const Offset(0.5, 0));
      expect(f.aim, Offset.zero);
      f.target(const Offset(5, 0));
      expect(f.aim, const Offset(5, 0));
    });

    test('jump goes there at once', () {
      final BubbleFollow f = BubbleFollow(Offset.zero);
      f.jump(const Offset(10, 20));
      expect(f.position, const Offset(10, 20));
      expect(f.isSettled, isTrue);
    });
  });
}
