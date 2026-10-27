import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/components/components.dart';

void main() {
  const Rect rect = Rect.fromLTWH(10, 20, 200, 80);
  const double body = 80 - SpeechBubbleBorder.tailHeight;

  group('SpeechBubbleBorder', () {
    test('path stays within the bounds and reaches the bottom edge', () {
      final Path path = const SpeechBubbleBorder().getOuterPath(rect);
      final Rect bounds = path.getBounds();
      expect(bounds.left, closeTo(rect.left, 0.01));
      expect(bounds.right, closeTo(rect.right, 0.01));
      expect(bounds.top, closeTo(rect.top, 0.01));
      expect(bounds.bottom, closeTo(rect.bottom, 0.01));
    });

    test('has a tail under the body at tailAt and none elsewhere', () {
      final Path path = const SpeechBubbleBorder(
        tailAt: 0.25,
      ).getOuterPath(rect);
      final double tailX = rect.left + rect.width * 0.25;
      final double belowBody =
          rect.top + body + SpeechBubbleBorder.tailHeight / 2;
      expect(path.contains(Offset(tailX, belowBody)), isTrue);
      expect(
        path.contains(Offset(rect.left + rect.width * 0.75, belowBody)),
        isFalse,
      );
      // The body itself is filled.
      expect(path.contains(rect.center - const Offset(0, 10)), isTrue);
    });

    test('tail position is clamped away from the rounded corners', () {
      final Path path = const SpeechBubbleBorder(
        radius: 20,
        tailAt: 0,
      ).getOuterPath(rect);
      final double belowBody = rect.top + body + 3;
      // The tail base starts after the corner radius, so the very left edge
      // under the body is empty.
      expect(path.contains(Offset(rect.left + 2, belowBody)), isFalse);
      expect(path.contains(Offset(rect.left + 20 + 9, belowBody)), isTrue);
    });

    test('copyWith and scale keep tailAt, and equality is by value', () {
      const SpeechBubbleBorder a = SpeechBubbleBorder(radius: 10, tailAt: 0.3);
      final ShapeBorder scaled = a.scale(2);
      expect(scaled, isA<SpeechBubbleBorder>());
      expect((scaled as SpeechBubbleBorder).radius, 20);
      expect(scaled.tailAt, 0.3);
      final OutlinedBorder withSide = a.copyWith(
        side: const BorderSide(width: 2),
      );
      expect(withSide, isA<SpeechBubbleBorder>());
      expect(withSide.side.width, 2);
      expect(a, const SpeechBubbleBorder(radius: 10, tailAt: 0.3));
      expect(
        a.hashCode,
        const SpeechBubbleBorder(radius: 10, tailAt: 0.3).hashCode,
      );
      expect(a, isNot(const SpeechBubbleBorder(radius: 10, tailAt: 0.4)));
    });
  });
}
