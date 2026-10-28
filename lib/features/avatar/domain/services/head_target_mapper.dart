import '../../../../core/models/performance/gaze_target.dart';
import '../models/head_pose.dart';

/// Pitch used while looking at a tablet / tool (down).
const double kToolPitch = -0.25;

/// Pitch used while glancing away to think (up).
const double kThinkingPitch = 0.2;

/// Pitch used while watching the text caret.
const double kCaretPitch = -0.35;

/// Maps a gaze target to the head target the rig should hold.
///
/// - `user` → (0, 0).
/// - `away(angle)` → yaw = angle (normalized −1..1); looks down at the tablet
///   (and reads: eye saccades) while a tool runs, otherwise up (thinking).
/// - `caret` → straight on, looking down at the composer.
/// - `point(x, y)` with normalized 0..1 screen coordinates.
HeadTarget headTargetFor(GazeTarget gaze, {String? activeTool}) {
  return switch (gaze) {
    GazeUser() => HeadTarget.zero,
    GazeAway(:final double angle) => HeadTarget(
      angle.clamp(-1.0, 1.0),
      activeTool != null ? kToolPitch : kThinkingPitch,
      reading: activeTool != null,
    ),
    GazeCaret() => const HeadTarget(0, kCaretPitch),
    GazePoint(:final double x, :final double y) => HeadTarget(
      ((x.clamp(0.0, 1.0) - 0.5) * 1.2).clamp(-1.0, 1.0),
      ((0.5 - y.clamp(0.0, 1.0)) * 0.6).clamp(-1.0, 1.0),
    ),
  };
}
