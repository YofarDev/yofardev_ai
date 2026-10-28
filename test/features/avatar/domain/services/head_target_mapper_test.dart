import 'package:flutter_test/flutter_test.dart';
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
        const HeadTarget(0.6, -0.25),
      );
    });

    test('away looks up (thinking) without a tool', () {
      expect(
        headTargetFor(const GazeTarget.away(-0.4)),
        const HeadTarget(-0.4, 0.2),
      );
    });

    test('away clamps the angle to -1..1', () {
      expect(headTargetFor(const GazeTarget.away(3)).yaw, 1);
      expect(headTargetFor(const GazeTarget.away(-3)).yaw, -1);
    });

    test('caret looks down at the composer', () {
      expect(
        headTargetFor(const GazeTarget.caret()),
        const HeadTarget(0, -0.35),
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
