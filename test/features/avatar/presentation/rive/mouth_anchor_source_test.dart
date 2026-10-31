import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/mouth_anchor_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MouthAnchorSource source;
  late List<Offset?> heard;

  setUp(() {
    source = MouthAnchorSource();
    heard = <Offset?>[];
    source.anchor.addListener(() => heard.add(source.anchor.value));
  });

  tearDown(() => source.dispose());

  test('starts with no anchor', () {
    expect(source.anchor.value, isNull);
  });

  test('publishes a reading outside a frame at once', () {
    source.report(const Offset(400, 480));
    expect(source.anchor.value, const Offset(400, 480));
    expect(heard, <Offset?>[const Offset(400, 480)]);
  });

  test('a non-finite reading is no anchor', () {
    source.report(const Offset(400, 480));
    source.report(const Offset(double.nan, 480));
    expect(source.anchor.value, isNull);
    source.report(const Offset(400, 480));
    source.report(const Offset(400, double.infinity));
    expect(source.anchor.value, isNull);
  });

  test('a null reading (the file has no MouthAnchor) is no anchor', () {
    source.report(const Offset(400, 480));
    source.report(null);
    expect(source.anchor.value, isNull);
  });

  test('ignores moves below the epsilon (no per-frame noise)', () {
    source.report(const Offset(400, 480));
    source.report(const Offset(400.01, 480.01));
    expect(heard, hasLength(1));
    source.report(const Offset(401, 480));
    expect(heard, hasLength(2));
    expect(source.anchor.value, const Offset(401, 480));
  });

  test('clear forgets the anchor', () {
    source.report(const Offset(400, 480));
    source.clear();
    expect(source.anchor.value, isNull);
  });

  testWidgets('a reading during the paint phase is published after the frame', (
    WidgetTester tester,
  ) async {
    final List<SchedulerPhase> phases = <SchedulerPhase>[];
    await tester.pumpWidget(
      CustomPaint(
        painter: _ReportingPainter(() {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          source.report(const Offset(400, 480));
          // not yet: listeners may rebuild, which paint must never do
          expect(source.anchor.value, isNull);
        }),
      ),
    );
    expect(phases, <SchedulerPhase>[SchedulerPhase.persistentCallbacks]);
    // the post-frame callback of that same frame published it
    expect(source.anchor.value, const Offset(400, 480));
    expect(heard, <Offset?>[const Offset(400, 480)]);
  });

  testWidgets('several readings in one frame publish the last once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CustomPaint(
        painter: _ReportingPainter(() {
          source.report(const Offset(400, 480));
          source.report(const Offset(410, 480));
        }),
      ),
    );
    expect(heard, <Offset?>[const Offset(410, 480)]);
  });

  testWidgets('a disposed source publishes nothing late', (
    WidgetTester tester,
  ) async {
    final MouthAnchorSource late = MouthAnchorSource();
    await tester.pumpWidget(
      CustomPaint(
        painter: _ReportingPainter(() {
          late.report(const Offset(400, 480));
          late.dispose();
        }),
      ),
    );
    // no "used after being disposed" error
    expect(tester.takeException(), isNull);
  });
}

class _ReportingPainter extends CustomPainter {
  _ReportingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_ReportingPainter oldDelegate) => false;
}
