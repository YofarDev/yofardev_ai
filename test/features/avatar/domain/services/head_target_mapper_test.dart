import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/avatar_prop.dart';
import 'package:yofardev_ai/core/models/performance/gaze_target.dart';
import 'package:yofardev_ai/features/avatar/domain/models/head_pose.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';

void main() {
  group('headTargetFor', () {
    test('user looks straight at the viewer', () {
      expect(headTargetFor(const GazeTarget.user()), HeadTarget.zero);
      expect(
        headTargetFor(const GazeTarget.user(), activeTool: 'web_search'),
        HeadTarget.zero,
      );
    });

    test('away looks down at the tablet while a tool runs', () {
      expect(
        headTargetFor(const GazeTarget.away(0.6), activeTool: 'web_search'),
        const HeadTarget(0.84, -0.5, reading: true),
      );
    });

    test('only a tool-driven glance reads', () {
      expect(headTargetFor(const GazeTarget.away(0.6)).reading, isFalse);
      expect(headTargetFor(const GazeTarget.caret(0.5)).reading, isFalse);
      expect(
        headTargetFor(
          const GazeTarget.user(),
          activeTool: 'web_search',
        ).reading,
        isFalse,
      );
    });

    test('away looks up (thinking) without a tool', () {
      expect(
        headTargetFor(const GazeTarget.away(-0.4)),
        const HeadTarget(-0.4, 0.2),
      );
    });

    test('a tool glance turns 1.4x further, clamped to -1..1', () {
      final HeadTarget wide = headTargetFor(
        const GazeTarget.away(0.6),
        activeTool: 'web_search',
      );
      expect(wide.yaw, closeTo(0.84, 1e-9));
      expect(wide.pitch, -0.5);
      expect(headTargetFor(const GazeTarget.away(0.9), activeTool: 'x').yaw, 1);
      expect(
        headTargetFor(const GazeTarget.away(-0.6), activeTool: 'x').yaw,
        closeTo(-0.84, 1e-9),
      );
    });

    test('a thinking glance keeps the angle and looks up', () {
      expect(
        headTargetFor(const GazeTarget.away(0.6)),
        const HeadTarget(0.6, 0.2),
      );
    });

    test('away clamps the angle to -1..1', () {
      expect(headTargetFor(const GazeTarget.away(3)).yaw, 1);
      expect(headTargetFor(const GazeTarget.away(-3)).yaw, -1);
    });

    test('caret looks down at the composer', () {
      expect(
        headTargetFor(const GazeTarget.caret(0.5)),
        const HeadTarget(0, -0.8),
      );
    });

    test('caret follows the caret across the field', () {
      expect(headTargetFor(const GazeTarget.caret(0)).yaw, closeTo(-0.2, 1e-9));
      expect(headTargetFor(const GazeTarget.caret(1)).yaw, closeTo(0.2, 1e-9));
      expect(
        headTargetFor(const GazeTarget.caret(0.8)).yaw,
        closeTo(0.12, 1e-9),
      );
      expect(headTargetFor(const GazeTarget.caret(0.8)).pitch, kCaretPitch);
      expect(headTargetFor(const GazeTarget.caret(9)).yaw, closeTo(0.2, 1e-9));
    });

    test('a held tablet overrides the gaze: turned and reading', () {
      const HeadTarget tablet = HeadTarget(0.6, -0.5, reading: true);
      expect(
        headTargetFor(const GazeTarget.user(), prop: AvatarProp.tablet),
        tablet,
      );
      expect(
        headTargetFor(
          const GazeTarget.away(0.6),
          activeTool: 'searchGoogle',
          prop: AvatarProp.tablet,
        ),
        tablet,
      );
      expect(
        headTargetFor(const GazeTarget.user(), prop: AvatarProp.none),
        HeadTarget.zero,
      );
    });

    test('the newspaper reads in the tablet\'s pose', () {
      expect(
        headTargetFor(
          const GazeTarget.away(0.6),
          activeTool: 'getMostPopularNewsOfTheDay',
          prop: AvatarProp.newspaper,
        ),
        const HeadTarget(0.6, -0.5, reading: true),
      );
    });

    test('point maps normalized screen coordinates', () {
      expect(
        headTargetFor(const GazeTarget.point(0.5, 0.5)),
        const HeadTarget(0, 0),
      );
      final HeadTarget right = headTargetFor(const GazeTarget.point(1, 0));
      expect(right.yaw, closeTo(0.6, 1e-9));
      expect(right.pitch, closeTo(0.3, 1e-9));
      final HeadTarget leftDown = headTargetFor(const GazeTarget.point(0, 1));
      expect(leftDown.yaw, closeTo(-0.6, 1e-9));
      expect(leftDown.pitch, closeTo(-0.3, 1e-9));
    });

    test('point clamps coordinates outside 0..1', () {
      final HeadTarget t = headTargetFor(const GazeTarget.point(4, -2));
      expect(t.yaw, closeTo(0.6, 1e-9));
      expect(t.pitch, closeTo(0.3, 1e-9));
    });
  });
}
