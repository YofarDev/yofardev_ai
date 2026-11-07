import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_passage.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/avatar_passage_box.dart';

/// Counts its paints: stands in for the Rive avatar, which advances only
/// while it is painted.
class _CountingPainter extends CustomPainter {
  _CountingPainter(Listenable frame) : super(repaint: frame);

  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => true;
}

void main() {
  testWidgets('a faded, shrunk, clipped avatar is still painted every frame', (
    WidgetTester tester,
  ) async {
    // the Rive avatar asks for a paint every frame
    final ValueNotifier<int> frame = ValueNotifier<int>(0);
    addTearDown(frame.dispose);
    final _CountingPainter painter = _CountingPainter(frame);
    final ValueNotifier<PaintedPassage> passage = ValueNotifier<PaintedPassage>(
      PaintedPassage.none,
    );
    addTearDown(passage.dispose);
    await tester.pumpWidget(
      AvatarPassageBox(
        passage: passage,
        child: RepaintBoundary(child: CustomPaint(painter: painter)),
      ),
    );
    final int before = painter.paints;
    for (final AvatarPassage p in <AvatarPassage>[
      const AvatarPassage(opacity: 0),
      const AvatarPassage(scaleX: 0.001, scaleY: 0.001, opacity: 0),
      const AvatarPassage(
        planeX: 644,
        window: JourneyPassage.rocketHatch,
        opacity: 0,
      ),
      AvatarPassage.none,
    ]) {
      passage.value = PaintedPassage(p, 0xFF102030);
      frame.value++;
      await tester.pump();
    }
    expect(painter.paints, greaterThanOrEqualTo(before + 4));
  });

  testWidgets('the avatar takes no pointer while the passage acts', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    final ValueNotifier<PaintedPassage> passage = ValueNotifier<PaintedPassage>(
      PaintedPassage.none,
    );
    addTearDown(passage.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AvatarPassageBox(
          passage: passage,
          child: GestureDetector(
            onTap: () => taps++,
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
    passage.value = const PaintedPassage(AvatarPassage(scaleX: 0.5));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
  });
}
